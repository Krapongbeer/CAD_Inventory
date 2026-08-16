-- ============================================================
-- SQL Script: Admin Create User RPC
-- Run this script in the Supabase SQL Editor
-- This allows admins to create users directly without logging out
-- ============================================================

create or replace function public.admin_create_user(
  email text,
  password text,
  full_name text,
  user_role text
) returns jsonb as $$
declare
  new_user_id uuid;
  result jsonb;
begin
  -- 1. ตรวจสอบสิทธิ์ว่าคนที่เรียกฟังก์ชันนี้เป็น Admin หรือไม่
  if not exists (
    select 1 from public.user_roles 
    where user_id = auth.uid() and role = 'admin'
  ) then
    raise exception 'Unauthorized: Only admins can create new users.';
  end if;

  -- 2. สร้างผู้ใช้ใหม่ใน auth.users (Supabase Admin API)
  -- เราใช้ supabase_admin schema หรือเรียกตรงไม่ได้ถ้าสิทธิ์ไม่พอ 
  -- วิธีที่ดีที่สุดใน RPC แบบนี้คือการแทรกข้อมูลลง auth.users (ถ้ามีสิทธิ์ SUPERUSER)
  
  insert into auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at
  ) values (
    '00000000-0000-0000-0000-000000000000',
    gen_random_uuid(),
    'authenticated',
    'authenticated',
    email,
    crypt(password, gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}',
    jsonb_build_object('full_name', full_name),
    now(),
    now()
  ) returning id into new_user_id;

  -- 3. อัปเดต Role ให้ตรงกับที่เลือก
  update public.user_roles 
  set role = user_role, full_name = full_name
  where user_id = new_user_id;

  result := jsonb_build_object('success', true, 'user_id', new_user_id);
  return result;

exception when others then
  return jsonb_build_object('success', false, 'error', sqlerrm);
end;
$$ language plpgsql security definer;
