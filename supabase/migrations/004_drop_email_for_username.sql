-- Panchat: login is email only. Remove the username -> email lookup (privacy).
-- Run once in Supabase Dashboard > SQL Editor. Safe if the function never existed.
drop function if exists public.email_for_username(text);
