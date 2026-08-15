-- ============================================================
-- SQL Script: Auto Create User Role on Signup
-- Run this script in the Supabase SQL Editor
-- ============================================================

-- 1. Create a function to handle new user signups
create or replace function public.handle_new_user()
returns trigger as $$
begin
  -- Automatically insert a 'viewer' role for the new user
  insert into public.user_roles (user_id, role, full_name)
  values (new.id, 'viewer', coalesce(new.raw_user_meta_data->>'full_name', new.email));
  
  return new;
end;
$$ language plpgsql security definer;

-- 2. Create a trigger that calls the function whenever a new user is created in auth.users
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
