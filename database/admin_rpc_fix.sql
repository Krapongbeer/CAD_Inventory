-- ================================================================
-- SmartCAD Inventory: Admin Management RPC & Permissions Fix (v2)
-- คัดลอกคำสั่งทั้งหมดในไฟล์นี้ไปรันใน Supabase Dashboard > SQL Editor
-- เพื่อเปิดใช้งานฟังก์ชันจัดการผู้ใช้งาน (สร้าง / แก้ไข / รีเซ็ตรหัส / ลบ)
-- ================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 0. เพิ่มคอลัมน์ department และ status ในตาราง user_roles (ถ้ายังไม่มี)
ALTER TABLE public.user_roles ADD COLUMN IF NOT EXISTS department TEXT DEFAULT 'กองบริหารงานกลาง';
ALTER TABLE public.user_roles ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active';

-- 1. ฟังก์ชันสร้างผู้ใช้งานใหม่ (admin_create_user)
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
  SELECT role INTO caller_role FROM public.user_roles WHERE user_roles.user_id = auth.uid();
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
    admin_create_user.email,
    crypt(admin_create_user.password, gen_salt('bf')),
    NOW(),
    '{"provider":"email","providers":["email"]}',
    jsonb_build_object('full_name', admin_create_user.full_name),
    NOW(),
    NOW()
  ) RETURNING id INTO new_user_id;

  -- สร้าง Identity ใน auth.identities เพื่อให้ GoTrue Auth ค้นหาและเข้าสู่ระบบได้
  INSERT INTO auth.identities (
    id,
    user_id,
    identity_data,
    provider,
    provider_id,
    last_sign_in_at,
    created_at,
    updated_at
  ) VALUES (
    new_user_id::text,
    new_user_id,
    jsonb_build_object('sub', new_user_id::text, 'email', admin_create_user.email),
    'email',
    admin_create_user.email,
    NOW(),
    NOW(),
    NOW()
  ) ON CONFLICT DO NOTHING;

  -- เพิ่มสิทธิ์ใน user_roles
  INSERT INTO public.user_roles (user_id, role, full_name, email, department, status)
  VALUES (new_user_id, admin_create_user.user_role, admin_create_user.full_name, admin_create_user.email, 'กองบริหารงานกลาง', 'active')
  ON CONFLICT (user_id) DO UPDATE
  SET role = EXCLUDED.role,
      full_name = EXCLUDED.full_name,
      email = EXCLUDED.email,
      department = COALESCE(user_roles.department, EXCLUDED.department),
      status = COALESCE(user_roles.status, EXCLUDED.status);

  -- บันทึก Audit Log
  INSERT INTO public.activity_logs (user_id, action, details)
  VALUES (auth.uid(), 'create_user', 'สร้างผู้ใช้ใหม่: ' || admin_create_user.full_name || ' (' || admin_create_user.user_role || ') อีเมล: ' || admin_create_user.email);

  RETURN jsonb_build_object('success', true, 'user_id', new_user_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 2. ฟังก์ชันแก้ไขข้อมูลผู้ใช้ (admin_update_user)
CREATE OR REPLACE FUNCTION public.admin_update_user(
  target_user_id UUID,
  new_full_name TEXT,
  new_role TEXT,
  new_password TEXT DEFAULT NULL,
  new_email TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
  caller_role TEXT;
  v_old_name TEXT;
  v_old_role TEXT;
BEGIN
  -- ตรวจสอบสิทธิ์ผู้เรียก
  SELECT role INTO caller_role FROM public.user_roles WHERE user_roles.user_id = auth.uid();
  IF caller_role NOT IN ('superadmin', 'admin') THEN
    RAISE EXCEPTION 'Unauthorized: Only admins and superadmins can modify users.';
  END IF;

  SELECT full_name, role INTO v_old_name, v_old_role FROM public.user_roles WHERE user_roles.user_id = target_user_id;

  -- 1. อัปเดตใน user_roles
  UPDATE public.user_roles 
  SET full_name = new_full_name,
      role = new_role,
      email = COALESCE(new_email, user_roles.email)
  WHERE user_roles.user_id = target_user_id;

  -- 2. อัปเดต metadata ใน auth.users
  UPDATE auth.users 
  SET raw_user_meta_data = jsonb_set(COALESCE(raw_user_meta_data, '{}'::jsonb), '{full_name}', to_jsonb(new_full_name)),
      email = COALESCE(new_email, auth.users.email)
  WHERE auth.users.id = target_user_id;

  -- 3. หากมีการระบุรหัสผ่านใหม่ (Password Reset)
  IF new_password IS NOT NULL AND length(trim(new_password)) >= 6 THEN
    UPDATE auth.users
    SET encrypted_password = crypt(new_password, gen_salt('bf')),
        updated_at = NOW()
    WHERE auth.users.id = target_user_id;
  END IF;

  -- บันทึก Audit Log
  INSERT INTO public.activity_logs (user_id, action, details)
  VALUES (auth.uid(), 'update_user', 'แก้ไขผู้ใช้: ' || COALESCE(v_old_name, '') || ' -> ' || new_full_name || ' (Role: ' || COALESCE(v_old_role, '') || ' -> ' || new_role || ')');

  RETURN jsonb_build_object('success', true, 'message', 'User updated successfully');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 3. ฟังก์ชันลบบัญชีผู้ใช้ (admin_delete_user)
CREATE OR REPLACE FUNCTION public.admin_delete_user(
  target_user_id UUID
) RETURNS JSONB AS $$
DECLARE
  caller_role TEXT;
  v_target_name TEXT;
BEGIN
  -- ตรวจสอบสิทธิ์ผู้เรียก
  SELECT role INTO caller_role FROM public.user_roles WHERE user_roles.user_id = auth.uid();
  IF caller_role NOT IN ('superadmin', 'admin') THEN
    RAISE EXCEPTION 'Unauthorized: Only admins and superadmins can delete users.';
  END IF;

  -- ห้ามลบบัญชีตัวเอง
  IF target_user_id = auth.uid() THEN
    RAISE EXCEPTION 'Cannot delete your own active account.';
  END IF;

  SELECT full_name INTO v_target_name FROM public.user_roles WHERE user_roles.user_id = target_user_id;

  -- ลบจาก user_roles และ auth.users
  DELETE FROM public.user_roles WHERE user_roles.user_id = target_user_id;
  DELETE FROM auth.users WHERE auth.users.id = target_user_id;

  -- บันทึก Audit Log
  INSERT INTO public.activity_logs (user_id, action, details)
  VALUES (auth.uid(), 'delete_user', 'ลบบัญชีผู้ใช้: ' || COALESCE(v_target_name, target_user_id::text));

  RETURN jsonb_build_object('success', true, 'message', 'User deleted successfully');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 4. สิทธิ์การ Execute ฟังก์ชัน
GRANT EXECUTE ON FUNCTION public.admin_create_user(TEXT, TEXT, TEXT, TEXT) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.admin_update_user(UUID, TEXT, TEXT, TEXT, TEXT) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.admin_delete_user(UUID) TO authenticated, service_role, anon;


-- 5. RLS Policies สำหรับตาราง user_roles
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow select for authenticated" ON public.user_roles;
CREATE POLICY "Allow select for authenticated"
  ON public.user_roles FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Allow insert for authenticated" ON public.user_roles;
CREATE POLICY "Allow insert for authenticated"
  ON public.user_roles FOR INSERT
  TO authenticated
  WITH CHECK (true);

DROP POLICY IF EXISTS "Allow update for authenticated" ON public.user_roles;
CREATE POLICY "Allow update for authenticated"
  ON public.user_roles FOR UPDATE
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Allow delete for authenticated" ON public.user_roles;
CREATE POLICY "Allow delete for authenticated"
  ON public.user_roles FOR DELETE
  TO authenticated
  USING (true);

-- 6. ยืนยันสถานะ Email Confirmed ให้กับทุกบัญชีในระบบอัตโนมัติ
UPDATE auth.users SET email_confirmed_at = NOW() WHERE email_confirmed_at IS NULL;
