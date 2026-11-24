-- Panchat: log in with username OR email. Resolves username -> auth email before signInWithPassword.
-- Run once in Supabase Dashboard > SQL Editor.
-- Privacy note: this lets anyone who knows a username look up that account's email.
create or replace function public.email_for_username(uname text)
returns text language sql stable security definer set search_path = '' as $$
  select u.email::text
  from public.profiles p
  join auth.users u on u.id = p.id
  where p.username = lower(btrim(uname))
  limit 1;
$$;
revoke all on function public.email_for_username(text) from public;
grant execute on function public.email_for_username(text) to anon, authenticated;
