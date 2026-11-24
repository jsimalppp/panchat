-- Panchat: Supabase schema (free tier compatible)
-- Run once in Supabase Dashboard > SQL Editor.
-- Design rules:
--   * RLS enabled on every table. anon role has NO table access.
--   * Clients never insert conversations/participants directly; they call RPCs.
--   * Helper functions live in schema "private" (not exposed by the REST API).

create extension if not exists pgcrypto;

create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

-- ---------------------------------------------------------------- enums
do $$ begin
  create type public.conversation_type as enum ('direct', 'group');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.message_type as enum ('text', 'image', 'voice');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.participant_role as enum ('member', 'admin');
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------- tables
create table if not exists public.profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  username      text not null unique
                check (username ~ '^[a-z0-9_]{3,24}$'),
  display_name  text not null check (char_length(display_name) between 1 and 50),
  avatar_path   text,                       -- path in 'avatars' bucket
  about         text check (char_length(about) <= 140),
  last_seen_at  timestamptz,
  created_at    timestamptz not null default now()
);

create table if not exists public.conversations (
  id               uuid primary key default gen_random_uuid(),
  type             public.conversation_type not null,
  title            text check (char_length(title) <= 80),
  avatar_path      text,
  created_by       uuid not null references public.profiles(id),
  direct_key       text unique,             -- 'minUuid:maxUuid' prevents duplicate 1:1 chats
  created_at       timestamptz not null default now(),
  last_message_at  timestamptz not null default now(),
  check ((type = 'direct' and direct_key is not null and title is null)
      or (type = 'group'  and direct_key is null     and title is not null))
);

create table if not exists public.participants (
  conversation_id  uuid not null references public.conversations(id) on delete cascade,
  user_id          uuid not null references public.profiles(id) on delete cascade,
  role             public.participant_role not null default 'member',
  joined_at        timestamptz not null default now(),
  last_read_at     timestamptz not null default now(),
  muted            boolean not null default false,
  primary key (conversation_id, user_id)
);

create table if not exists public.messages (
  id                uuid primary key default gen_random_uuid(),
  conversation_id   uuid not null references public.conversations(id) on delete cascade,
  sender_id         uuid not null references public.profiles(id),
  type              public.message_type not null default 'text',
  body              text check (char_length(body) <= 4000),
  media_path        text,                    -- path in 'chat-media' bucket
  media_duration_ms integer check (media_duration_ms is null or media_duration_ms between 1 and 300000),
  reply_to          uuid references public.messages(id) on delete set null,
  created_at        timestamptz not null default now(),
  deleted_at        timestamptz,             -- soft delete ("deleted for everyone")
  check ((type = 'text'  and body is not null and char_length(btrim(body)) > 0 and media_path is null)
      or (type <> 'text' and media_path is not null))
);

create table if not exists public.message_reads (
  message_id       uuid not null references public.messages(id) on delete cascade,
  user_id          uuid not null references public.profiles(id) on delete cascade,
  conversation_id  uuid not null references public.conversations(id) on delete cascade,
  read_at          timestamptz not null default now(),
  primary key (message_id, user_id)
);

-- ---------------------------------------------------------------- indexes
create index if not exists participants_user_idx      on public.participants (user_id, conversation_id);
create index if not exists messages_conv_created_idx  on public.messages (conversation_id, created_at desc);
create index if not exists messages_sender_idx        on public.messages (sender_id, created_at desc);
create index if not exists message_reads_conv_idx     on public.message_reads (conversation_id, user_id);
create index if not exists conversations_last_msg_idx on public.conversations (last_message_at desc);
create index if not exists profiles_username_trgm_idx on public.profiles (username text_pattern_ops);

-- ---------------------------------------------------------------- helpers
create or replace function private.is_participant(conv uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.participants
                 where conversation_id = conv and user_id = (select auth.uid()));
$$;

create or replace function private.is_admin(conv uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.participants
                 where conversation_id = conv and user_id = (select auth.uid())
                   and role = 'admin');
$$;

revoke all on function private.is_participant(uuid), private.is_admin(uuid) from public, anon;
grant execute on function private.is_participant(uuid), private.is_admin(uuid) to authenticated;

-- ---------------------------------------------------------------- triggers
-- Auto-create profile on signup (the email code flow still creates the auth user first).
create or replace function private.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  base text := lower(regexp_replace(coalesce(new.raw_user_meta_data->>'username',
                                             split_part(new.email, '@', 1)), '[^a-z0-9_]', '', 'g'));
  uname text;
begin
  if char_length(base) < 3 then base := 'user' || base; end if;
  uname := left(base, 18) || substr(replace(gen_random_uuid()::text, '-', ''), 1, 5);
  insert into public.profiles (id, username, display_name)
  values (new.id, uname,
          left(coalesce(nullif(new.raw_user_meta_data->>'display_name', ''), split_part(new.email, '@', 1)), 50));
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function private.handle_new_user();

-- Bump conversation ordering, and basic flood control (30 msgs / 10 s per user).
create or replace function private.before_message_insert()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if (select count(*) from public.messages
      where sender_id = new.sender_id and created_at > now() - interval '10 seconds') >= 30 then
    raise exception 'rate_limited' using errcode = 'P0001';
  end if;
  return new;
end $$;

create or replace function private.after_message_insert()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  update public.conversations set last_message_at = new.created_at where id = new.conversation_id;
  return null;
end $$;

drop trigger if exists messages_before_insert on public.messages;
create trigger messages_before_insert before insert on public.messages
  for each row execute function private.before_message_insert();
drop trigger if exists messages_after_insert on public.messages;
create trigger messages_after_insert after insert on public.messages
  for each row execute function private.after_message_insert();

-- ---------------------------------------------------------------- RPCs (client entry points)
create or replace function public.create_direct_conversation(other uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  k text;
  cid uuid;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if other is null or other = me then raise exception 'invalid_user'; end if;
  if not exists (select 1 from public.profiles where id = other) then raise exception 'user_not_found'; end if;
  k := least(me::text, other::text) || ':' || greatest(me::text, other::text);
  select id into cid from public.conversations where direct_key = k;
  if cid is not null then return cid; end if;
  insert into public.conversations (type, created_by, direct_key) values ('direct', me, k) returning id into cid;
  insert into public.participants (conversation_id, user_id) values (cid, me), (cid, other);
  return cid;
end $$;

create or replace function public.create_group_conversation(group_title text, member_ids uuid[])
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  cid uuid;
  m uuid;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if group_title is null or char_length(btrim(group_title)) = 0 then raise exception 'title_required'; end if;
  if coalesce(array_length(member_ids, 1), 0) > 255 then raise exception 'too_many_members'; end if;
  insert into public.conversations (type, title, created_by) values ('group', btrim(group_title), me) returning id into cid;
  insert into public.participants (conversation_id, user_id, role) values (cid, me, 'admin');
  foreach m in array coalesce(member_ids, '{}') loop
    if m <> me and exists (select 1 from public.profiles where id = m) then
      insert into public.participants (conversation_id, user_id) values (cid, m) on conflict do nothing;
    end if;
  end loop;
  return cid;
end $$;

create or replace function public.add_group_member(conv uuid, member uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not private.is_admin(conv) then raise exception 'forbidden'; end if;
  if not exists (select 1 from public.conversations where id = conv and type = 'group') then
    raise exception 'not_a_group';
  end if;
  insert into public.participants (conversation_id, user_id) values (conv, member) on conflict do nothing;
end $$;

create or replace function public.remove_group_member(conv uuid, member uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not private.is_admin(conv) then raise exception 'forbidden'; end if;
  if member = auth.uid() then raise exception 'use_leave'; end if;
  delete from public.participants where conversation_id = conv and user_id = member;
end $$;

create or replace function public.mark_conversation_read(conv uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not private.is_participant(conv) then raise exception 'forbidden'; end if;
  insert into public.message_reads (message_id, user_id, conversation_id)
  select m.id, auth.uid(), conv from public.messages m
  where m.conversation_id = conv and m.sender_id <> auth.uid()
    and not exists (select 1 from public.message_reads r where r.message_id = m.id and r.user_id = auth.uid())
  on conflict do nothing;
  update public.participants set last_read_at = now()
  where conversation_id = conv and user_id = auth.uid();
end $$;

create or replace function public.touch_presence()
returns void language sql security definer set search_path = '' as $$
  update public.profiles set last_seen_at = now() where id = auth.uid();
$$;

-- Lock RPC execution: authenticated only, never anon.
revoke all on function
  public.create_direct_conversation(uuid), public.create_group_conversation(text, uuid[]),
  public.add_group_member(uuid, uuid), public.remove_group_member(uuid, uuid),
  public.mark_conversation_read(uuid), public.touch_presence()
  from public, anon;
grant execute on function
  public.create_direct_conversation(uuid), public.create_group_conversation(text, uuid[]),
  public.add_group_member(uuid, uuid), public.remove_group_member(uuid, uuid),
  public.mark_conversation_read(uuid), public.touch_presence()
  to authenticated;

-- ---------------------------------------------------------------- RLS
alter table public.profiles       enable row level security;
alter table public.conversations  enable row level security;
alter table public.participants   enable row level security;
alter table public.messages       enable row level security;
alter table public.message_reads  enable row level security;

-- Table privileges: nothing for anon; minimal for authenticated.
revoke all on public.profiles, public.conversations, public.participants,
              public.messages, public.message_reads from anon, authenticated;

grant select on public.profiles to authenticated;
grant update (username, display_name, avatar_path, about) on public.profiles to authenticated;
grant select on public.conversations to authenticated;
grant update (title, avatar_path) on public.conversations to authenticated;
grant select on public.participants to authenticated;
grant update (muted) on public.participants to authenticated;
grant delete on public.participants to authenticated;       -- leave a conversation
grant select, insert on public.messages to authenticated;
grant update (deleted_at) on public.messages to authenticated;
grant select on public.message_reads to authenticated;

-- profiles: any signed-in user can look up profiles (needed for search and chat headers).
-- If Panchat becomes community-only, tighten this policy.
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles for select to authenticated using (true);
drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

-- conversations: only members read; group admins edit title/avatar.
drop policy if exists conversations_select on public.conversations;
create policy conversations_select on public.conversations for select to authenticated
  using (private.is_participant(id));
drop policy if exists conversations_update_admin on public.conversations;
create policy conversations_update_admin on public.conversations for update to authenticated
  using (type = 'group' and private.is_admin(id)) with check (type = 'group' and private.is_admin(id));

-- participants: see members of conversations you are in; edit/leave only your own row.
drop policy if exists participants_select on public.participants;
create policy participants_select on public.participants for select to authenticated
  using (private.is_participant(conversation_id));
drop policy if exists participants_update_own on public.participants;
create policy participants_update_own on public.participants for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
drop policy if exists participants_delete_own on public.participants;
create policy participants_delete_own on public.participants for delete to authenticated
  using (user_id = (select auth.uid()));

-- messages: members read; send only as yourself into your conversations; delete-for-everyone only own.
drop policy if exists messages_select on public.messages;
create policy messages_select on public.messages for select to authenticated
  using (private.is_participant(conversation_id));
drop policy if exists messages_insert on public.messages;
create policy messages_insert on public.messages for insert to authenticated
  with check (sender_id = (select auth.uid()) and private.is_participant(conversation_id));
drop policy if exists messages_soft_delete_own on public.messages;
create policy messages_soft_delete_own on public.messages for update to authenticated
  using (sender_id = (select auth.uid())) with check (sender_id = (select auth.uid()));

-- message_reads: members see receipts; rows are written only by mark_conversation_read().
drop policy if exists message_reads_select on public.message_reads;
create policy message_reads_select on public.message_reads for select to authenticated
  using (private.is_participant(conversation_id));

-- ---------------------------------------------------------------- Realtime
-- Postgres Changes honour the RLS policies above (users only receive rows they can select).
do $$ begin
  alter publication supabase_realtime add table public.messages;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.message_reads;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.participants;
exception when duplicate_object then null; end $$;
alter table public.messages      replica identity full;
alter table public.message_reads replica identity full;

-- Online status and "typing..." use Realtime Presence/Broadcast (ephemeral, no table).
-- Use PRIVATE channels named 'conv:<conversation_id>' and authorize them here:
drop policy if exists realtime_conv_read on realtime.messages;
create policy realtime_conv_read on realtime.messages for select to authenticated
  using (
    realtime.messages.extension in ('broadcast', 'presence')
    and private.is_participant(nullif(split_part((select realtime.topic()), ':', 2), '')::uuid)
  );
drop policy if exists realtime_conv_write on realtime.messages;
create policy realtime_conv_write on realtime.messages for insert to authenticated
  with check (
    realtime.messages.extension in ('broadcast', 'presence')
    and private.is_participant(nullif(split_part((select realtime.topic()), ':', 2), '')::uuid)
  );

-- ---------------------------------------------------------------- Storage
-- Free tier global per-file cap is 50 MB; we set tighter limits.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('avatars',    'avatars',    true,  2097152,  array['image/jpeg','image/png','image/webp']),
  ('chat-media', 'chat-media', false, 10485760, array['image/jpeg','image/png','image/webp',
                                                      'audio/mp4','audio/aac','audio/mpeg','audio/ogg','audio/webm'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- avatars: path '<user_id>/<file>'. Public read (profile pictures only); write own folder.
drop policy if exists avatars_read on storage.objects;
create policy avatars_read on storage.objects for select to authenticated
  using (bucket_id = 'avatars');
drop policy if exists avatars_write_own on storage.objects;
create policy avatars_write_own on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);
drop policy if exists avatars_update_own on storage.objects;
create policy avatars_update_own on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);
drop policy if exists avatars_delete_own on storage.objects;
create policy avatars_delete_own on storage.objects for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);

-- chat-media: PRIVATE. path '<conversation_id>/<user_id>/<uuid>.<ext>'.
-- Read: conversation members only. Write: members, into their own sub-folder. Delete: uploader.
-- The app reads via short-lived signed URLs (createSignedUrl, 60 s), never public URLs.
drop policy if exists chat_media_read on storage.objects;
create policy chat_media_read on storage.objects for select to authenticated
  using (bucket_id = 'chat-media'
         and private.is_participant(nullif((storage.foldername(name))[1], '')::uuid));
drop policy if exists chat_media_insert on storage.objects;
create policy chat_media_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'chat-media'
              and private.is_participant(nullif((storage.foldername(name))[1], '')::uuid)
              and (storage.foldername(name))[2] = (select auth.uid())::text);
drop policy if exists chat_media_delete_own on storage.objects;
create policy chat_media_delete_own on storage.objects for delete to authenticated
  using (bucket_id = 'chat-media'
         and (storage.foldername(name))[2] = (select auth.uid())::text);
