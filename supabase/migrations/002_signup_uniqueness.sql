-- Panchat: reject duplicate usernames at signup (profiles.username is already UNIQUE).
-- Run once in Supabase Dashboard > SQL Editor.

-- 1. Pre-check callable before signup (anon). Returns true if the name is free.
create or replace function public.username_available(uname text)
returns boolean language sql stable security definer set search_path = '' as $$
  select not exists (select 1 from public.profiles where username = lower(btrim(uname)));
$$;
revoke all on function public.username_available(text) from public;
grant execute on function public.username_available(text) to anon, authenticated;

-- 2. Signup trigger: use the requested username exactly. If it is taken, fail the
--    signup with a unique_violation instead of silently adding a random suffix.
create or replace function private.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  want text := lower(regexp_replace(coalesce(new.raw_user_meta_data->>'username', ''), '[^a-z0-9_]', '', 'g'));
  base text;
  uname text;
begin
  if want ~ '^[a-z0-9_]{3,24}$' then
    if exists (select 1 from public.profiles where username = want) then
      raise exception 'username_taken' using errcode = '23505';
    end if;
    uname := want;
  else
    base := lower(regexp_replace(split_part(new.email, '@', 1), '[^a-z0-9_]', '', 'g'));
    if char_length(base) < 3 then base := 'user' || base; end if;
    uname := left(base, 18) || substr(replace(gen_random_uuid()::text, '-', ''), 1, 5);
  end if;
  insert into public.profiles (id, username, display_name)
  values (new.id, uname,
          left(coalesce(nullif(new.raw_user_meta_data->>'display_name', ''), split_part(new.email, '@', 1)), 50));
  return new;
end $$;
