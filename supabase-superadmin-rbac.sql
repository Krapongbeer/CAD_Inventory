-- ================================================================
-- Supabase Superadmin RBAC & Audit Log Migration
-- Run this entire script in Supabase Dashboard > SQL Editor > New query
-- ================================================================

-- 1. อัปเดต Table & Check Constraint ของ user_roles ให้รองรับทุก Role และเพิ่มคอลัมน์ email
ALTER TABLE public.user_roles DROP CONSTRAINT IF EXISTS user_roles_role_check;
ALTER TABLE public.user_roles ADD CONSTRAINT user_roles_role_check 
  CHECK (role IN ('superadmin', 'admin', 'staff', 'executive', 'editor', 'viewer'));

ALTER TABLE public.user_roles ADD COLUMN IF NOT EXISTS email TEXT;

-- ซิงค์อีเมลจาก auth.users มายัง user_roles สำหรับบัญชีที่มีอยู่เดิม
UPDATE public.user_roles ur
SET email = au.email
FROM auth.users au
WHERE ur.user_id = au.id AND (ur.email IS NULL OR ur.email = '');

-- 2. สร้างตาราง activity_logs (Audit Log) หากยังไม่มี
CREATE TABLE IF NOT EXISTS public.activity_logs (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  action      TEXT NOT NULL,
  details     TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- เปิดใช้งาน RLS สำหรับ activity_logs
ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;

-- Helper Function: ดึง Role ของผู้ใช้งานปัจจุบัน
CREATE OR REPLACE FUNCTION public.get_current_user_role()
RETURNS TEXT AS $$
  SELECT role FROM public.user_roles WHERE user_id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER;

-- RLS Policies สำหรับ activity_logs
DROP POLICY IF EXISTS "Users can insert logs" ON public.activity_logs;
CREATE POLICY "Users can insert logs"
  ON public.activity_logs FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Admins can read logs" ON public.activity_logs;
CREATE POLICY "Admins can read logs"
  ON public.activity_logs FOR SELECT
  TO authenticated
  USING (public.get_current_user_role() IN ('admin', 'superadmin'));

-- 3. ฟังก์ชัน RPC: เพิ่มผู้ใช้ใหม่โดย Admin / Superadmin
CREATE OR REPLACE FUNCTION public.admin_create_user(
  email TEXT,
  password TEXT,
  full_name TEXT,
  user_role TEXT
) RETURNS JSONB AS $$
DECLARE
  new_user_id UUID;
  caller_role TEXT;
BEGIN
  -- ตรวจสอบสิทธิ์ผู้เรียก
  SELECT role INTO caller_role FROM public.user_roles WHERE user_id = auth.uid();
  IF caller_role NOT IN ('superadmin', 'admin') THEN
    RAISE EXCEPTION 'Unauthorized: Only admins and superadmins can create users.';
  END IF;

  -- สร้างผู้ใช้ใน auth.users
  INSERT INTO auth.users (
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
  ) VALUES (
    '00000000-0000-0000-0000-000000000000',
    gen_random_uuid(),
    'authenticated',
    'authenticated',
    email,
    crypt(password, gen_salt('bf')),
    NOW(),
    '{"provider":"email","providers":["email"]}',
    jsonb_build_object('full_name', full_name),
    NOW(),
    NOW()
  ) RETURNING id INTO new_user_id;

  -- อัปเดต/แทรกใน user_roles
  INSERT INTO public.user_roles (user_id, role, full_name, email)
  VALUES (new_user_id, user_role, full_name, email)
  ON CONFLICT (user_id) DO UPDATE
  SET role = user_role, full_name = full_name, email = email;

  -- บันทึก Audit Log
  INSERT INTO public.activity_logs (user_id, action, details)
  VALUES (auth.uid(), 'create_user', 'สร้างผู้ใช้ใหม่: ' || full_name || ' (' || user_role || ') อีเมล: ' || email);

  RETURN jsonb_build_object('success', true, 'user_id', new_user_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. ฟังก์ชัน RPC: แก้ไขข้อมูลบัญชีผู้ใช้ทุกอย่าง (Superadmin / Admin Full RBAC)
CREATE OR REPLACE FUNCTION public.admin_update_user(
  target_user_id UUID,
  new_full_name TEXT,
  new_role TEXT,
  new_password TEXT DEFAULT NULL,
  new_email TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
  caller_role TEXT;
  old_name TEXT;
  old_role TEXT;
BEGIN
  -- ตรวจสอบสิทธิ์ผู้เรียก
  SELECT role INTO caller_role FROM public.user_roles WHERE user_id = auth.uid();
  IF caller_role NOT IN ('superadmin', 'admin') THEN
    RAISE EXCEPTION 'Unauthorized: Only admins and superadmins can modify users.';
  END IF;

  SELECT full_name, role INTO old_name, old_role FROM public.user_roles WHERE user_id = target_user_id;

  -- 1. อัปเดตใน user_roles
  UPDATE public.user_roles 
  SET full_name = new_full_name,
      role = new_role,
      email = COALESCE(new_email, email)
  WHERE user_id = target_user_id;

  -- 2. อัปเดต metadata ใน auth.users
  UPDATE auth.users 
  SET raw_user_meta_data = jsonb_set(COALESCE(raw_user_meta_data, '{}'::jsonb), '{full_name}', to_jsonb(new_full_name)),
      email = COALESCE(new_email, email)
  WHERE id = target_user_id;

  -- 3. หากมีการระบุรหัสผ่านใหม่ (Password Reset)
  IF new_password IS NOT NULL AND length(trim(new_password)) >= 6 THEN
    UPDATE auth.users
    SET encrypted_password = crypt(new_password, gen_salt('bf')),
        updated_at = NOW()
    WHERE id = target_user_id;
  END IF;

  -- บันทึก Audit Log
  INSERT INTO public.activity_logs (user_id, action, details)
  VALUES (auth.uid(), 'update_user', 'แก้ไขผู้ใช้: ' || old_name || ' -> ' || new_full_name || ' (Role: ' || old_role || ' -> ' || new_role || CASE WHEN new_email IS NOT NULL THEN ', อีเมล: ' || new_email ELSE '' END || CASE WHEN new_password IS NOT NULL AND length(trim(new_password)) >= 6 THEN ', รีเซ็ตรหัสผ่านใหม่' ELSE '' END || ')');

  RETURN jsonb_build_object('success', true, 'message', 'User updated successfully');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. ฟังก์ชัน RPC: ลบบัญชีผู้ใช้ออกจากระบบ (Superadmin / Admin)
CREATE OR REPLACE FUNCTION public.admin_delete_user(
  target_user_id UUID
) RETURNS JSONB AS $$
DECLARE
  caller_role TEXT;
  target_name TEXT;
BEGIN
  -- ตรวจสอบสิทธิ์ผู้เรียก
  SELECT role INTO caller_role FROM public.user_roles WHERE user_id = auth.uid();
  IF caller_role NOT IN ('superadmin', 'admin') THEN
    RAISE EXCEPTION 'Unauthorized: Only admins and superadmins can delete users.';
  END IF;

  -- ห้ามลบบัญชีตัวเอง
  IF target_user_id = auth.uid() THEN
    RAISE EXCEPTION 'Cannot delete your own active account.';
  END IF;

  SELECT full_name INTO target_name FROM public.user_roles WHERE user_id = target_user_id;

  -- ลบจาก user_roles และ auth.users
  DELETE FROM public.user_roles WHERE user_id = target_user_id;
  DELETE FROM auth.users WHERE id = target_user_id;

  -- บันทึก Audit Log
  INSERT INTO public.activity_logs (user_id, action, details)
  VALUES (auth.uid(), 'delete_user', 'ลบบัญชีผู้ใช้: ' || COALESCE(target_name, target_user_id::text));

  RETURN jsonb_build_object('success', true, 'message', 'User deleted successfully');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. อัปเดตบัญชีผู้ใช้ปัจจุบันเป็น superadmin ทันที
UPDATE public.user_roles 
SET role = 'superadmin' 
WHERE user_id = auth.uid();
