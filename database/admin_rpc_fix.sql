-- ================================================================
-- SmartCAD Inventory: Comprehensive Auth & Identity Repair (NIST Compliant)
-- คัดลอกคำสั่งทั้งหมดในไฟล์นี้ไปรันใน Supabase Dashboard > SQL Editor
-- เพื่อซ่อมแซมบัญชี kequiv@hotmail.com และทุกบัญชีในระบบให้ล็อกอินได้ทันที
-- ================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. เพิ่มคอลัมน์ในตาราง user_roles สำหรับ NIST Onboarding
ALTER TABLE public.user_roles ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE public.user_roles ADD COLUMN IF NOT EXISTS department TEXT DEFAULT 'กองบริหารงานกลาง';
ALTER TABLE public.user_roles ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active';
ALTER TABLE public.user_roles ADD COLUMN IF NOT EXISTS must_change_password BOOLEAN DEFAULT true;
ALTER TABLE public.user_roles ADD COLUMN IF NOT EXISTS last_password_change TIMESTAMPTZ DEFAULT NOW();

-- 2. สร้าง/ซ่อมแซมบัญชี kequiv@hotmail.com ใน auth.users
DO $$
DECLARE
  v_uid UUID;
BEGIN
  SELECT id INTO v_uid FROM auth.users WHERE lower(email) = 'kequiv@hotmail.com';
  
  IF v_uid IS NULL THEN
    v_uid := gen_random_uuid();
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
      is_sso_user,
      is_anonymous,
      created_at,
      updated_at
    ) VALUES (
      '00000000-0000-0000-0000-000000000000',
      v_uid,
      'authenticated',
      'authenticated',
      'kequiv@hotmail.com',
      crypt('fQzi=2fM@9*W', gen_salt('bf')),
      NOW(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      '{"full_name":"Kequiv"}'::jsonb,
      false,
      false,
      NOW(),
      NOW()
    );
  ELSE
    UPDATE auth.users
    SET encrypted_password = crypt('fQzi=2fM@9*W', gen_salt('bf')),
        email_confirmed_at = NOW(),
        aud = 'authenticated',
        role = 'authenticated',
        raw_app_meta_data = '{"provider":"email","providers":["email"]}'::jsonb,
        is_sso_user = false,
        is_anonymous = false,
        updated_at = NOW()
    WHERE id = v_uid;
  END IF;

  -- ซิงค์ใน user_roles
  INSERT INTO public.user_roles (user_id, role, full_name, email, department, status, must_change_password)
  VALUES (v_uid, 'staff', 'Kequiv', 'kequiv@hotmail.com', 'กองบริหารงานกลาง', 'active', true)
  ON CONFLICT (user_id) DO UPDATE
  SET email = 'kequiv@hotmail.com',
      must_change_password = true,
      status = 'active';
END $$;

-- 3. ซ่อมแซม auth.identities สำหรับทุกบัญชีใน auth.users ทั้งหมด
DELETE FROM auth.identities;
INSERT INTO auth.identities (
  id,
  user_id,
  identity_data,
  provider,
  provider_id,
  last_sign_in_at,
  created_at,
  updated_at
)
SELECT 
  u.id,
  u.id,
  jsonb_build_object(
    'sub', u.id::text,
    'email', lower(trim(u.email)),
    'email_verified', true,
    'phone_verified', false
  ),
  'email',
  u.id::text,
  NOW(),
  u.created_at,
  u.updated_at
FROM auth.users u;

-- 4. อัปเดตสถานะยืนยันอีเมลและบทบาทของทุกบัญชีใน auth.users
UPDATE auth.users
SET email_confirmed_at = NOW(),
    aud = 'authenticated',
    role = 'authenticated',
    raw_app_meta_data = '{"provider":"email","providers":["email"]}'::jsonb,
    is_sso_user = false,
    is_anonymous = false,
    updated_at = NOW()
WHERE email_confirmed_at IS NULL OR is_sso_user IS NULL;

-- 5. RPC: สร้างผู้ใช้งานใหม่ (admin_create_user)
CREATE OR REPLACE FUNCTION public.admin_create_user(
  email TEXT,
  password TEXT,
  full_name TEXT,
  user_role TEXT,
  temp_password_flag BOOLEAN DEFAULT true
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
    is_sso_user,
    is_anonymous,
    created_at,
    updated_at
  ) VALUES (
    '00000000-0000-0000-0000-000000000000',
    gen_random_uuid(),
    'authenticated',
    'authenticated',
    lower(trim(admin_create_user.email)),
    crypt(admin_create_user.password, gen_salt('bf')),
    NOW(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    jsonb_build_object('full_name', admin_create_user.full_name),
    false,
    false,
    NOW(),
    NOW()
  ) RETURNING id INTO new_user_id;

  -- สร้าง Identity ใน auth.identities
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
    new_user_id,
    new_user_id,
    jsonb_build_object(
      'sub', new_user_id::text,
      'email', lower(trim(admin_create_user.email)),
      'email_verified', true,
      'phone_verified', false
    ),
    'email',
    new_user_id::text,
    NOW(),
    NOW(),
    NOW()
  ) ON CONFLICT DO NOTHING;

  -- เพิ่มสิทธิ์ใน user_roles
  INSERT INTO public.user_roles (
    user_id, role, full_name, email, department, status, must_change_password, last_password_change
  )
  VALUES (
    new_user_id,
    admin_create_user.user_role,
    admin_create_user.full_name,
    lower(trim(admin_create_user.email)),
    'กองบริหารงานกลาง',
    'active',
    COALESCE(admin_create_user.temp_password_flag, true),
    NOW()
  )
  ON CONFLICT (user_id) DO UPDATE
  SET role = EXCLUDED.role,
      full_name = EXCLUDED.full_name,
      email = EXCLUDED.email,
      department = COALESCE(user_roles.department, EXCLUDED.department),
      status = COALESCE(user_roles.status, EXCLUDED.status),
      must_change_password = EXCLUDED.must_change_password,
      last_password_change = NOW();

  -- บันทึก Audit Log
  INSERT INTO public.activity_logs (user_id, action, details)
  VALUES (
    auth.uid(),
    'create_user',
    'สร้างผู้ใช้ใหม่: ' || admin_create_user.full_name || ' (' || admin_create_user.user_role || ') อีเมล: ' || admin_create_user.email || ' [รหัสผ่านชั่วคราว - รอเปลี่ยนรหัส]'
  );

  RETURN jsonb_build_object('success', true, 'user_id', new_user_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 6. RPC: แก้ไขข้อมูลบัญชีผู้ใช้ (admin_update_user)
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
  SELECT role INTO caller_role FROM public.user_roles WHERE user_roles.user_id = auth.uid();
  IF caller_role NOT IN ('superadmin', 'admin') THEN
    RAISE EXCEPTION 'Unauthorized: Only admins and superadmins can modify users.';
  END IF;

  SELECT full_name, role INTO v_old_name, v_old_role FROM public.user_roles WHERE user_roles.user_id = target_user_id;

  UPDATE public.user_roles 
  SET full_name = new_full_name,
      role = new_role,
      email = COALESCE(lower(trim(new_email)), user_roles.email),
      must_change_password = CASE WHEN new_password IS NOT NULL THEN true ELSE user_roles.must_change_password END
  WHERE user_roles.user_id = target_user_id;

  UPDATE auth.users 
  SET raw_user_meta_data = jsonb_set(COALESCE(raw_user_meta_data, '{}'::jsonb), '{full_name}', to_jsonb(new_full_name)),
      email = COALESCE(lower(trim(new_email)), auth.users.email)
  WHERE auth.users.id = target_user_id;

  IF new_password IS NOT NULL AND length(trim(new_password)) >= 6 THEN
    UPDATE auth.users
    SET encrypted_password = crypt(new_password, gen_salt('bf')),
        updated_at = NOW()
    WHERE auth.users.id = target_user_id;
  END IF;

  INSERT INTO public.activity_logs (user_id, action, details)
  VALUES (auth.uid(), 'update_user', 'แก้ไขผู้ใช้: ' || COALESCE(v_old_name, '') || ' -> ' || new_full_name || ' (Role: ' || COALESCE(v_old_role, '') || ' -> ' || new_role || ')');

  RETURN jsonb_build_object('success', true, 'message', 'User updated successfully');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 7. RPC: ผู้ใช้เปลี่ยนรหัสผ่านของตนเอง (user_change_own_password)
CREATE OR REPLACE FUNCTION public.user_change_own_password(
  new_password TEXT
) RETURNS JSONB AS $$
DECLARE
  current_uid UUID;
  user_name TEXT;
BEGIN
  current_uid := auth.uid();
  IF current_uid IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: User is not authenticated.';
  END IF;

  IF new_password IS NULL OR length(trim(new_password)) < 8 THEN
    RAISE EXCEPTION 'Password does not meet NIST requirements: Minimum 8 characters required.';
  END IF;

  UPDATE auth.users
  SET encrypted_password = crypt(new_password, gen_salt('bf')),
      updated_at = NOW()
  WHERE id = current_uid;

  UPDATE public.user_roles
  SET must_change_password = false,
      last_password_change = NOW()
  WHERE user_id = current_uid
  RETURNING full_name INTO user_name;

  INSERT INTO public.activity_logs (user_id, action, details)
  VALUES (current_uid, 'reset_password', 'ผู้ใช้เปลี่ยนรหัสผ่านใหม่สำเร็จ (NIST First-Login Setup): ' || COALESCE(user_name, 'User'));

  RETURN jsonb_build_object('success', true, 'message', 'Password updated successfully');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 8. RPC: ลบบัญชีผู้ใช้ (admin_delete_user)
CREATE OR REPLACE FUNCTION public.admin_delete_user(
  target_user_id UUID
) RETURNS JSONB AS $$
DECLARE
  caller_role TEXT;
  v_target_name TEXT;
BEGIN
  SELECT role INTO caller_role FROM public.user_roles WHERE user_roles.user_id = auth.uid();
  IF caller_role NOT IN ('superadmin', 'admin') THEN
    RAISE EXCEPTION 'Unauthorized: Only admins and superadmins can delete users.';
  END IF;

  IF target_user_id = auth.uid() THEN
    RAISE EXCEPTION 'Cannot delete your own active account.';
  END IF;

  SELECT full_name INTO v_target_name FROM public.user_roles WHERE user_roles.user_id = target_user_id;

  DELETE FROM public.user_roles WHERE user_roles.user_id = target_user_id;
  DELETE FROM auth.identities WHERE user_id = target_user_id;
  DELETE FROM auth.users WHERE auth.users.id = target_user_id;

  INSERT INTO public.activity_logs (user_id, action, details)
  VALUES (auth.uid(), 'delete_user', 'ลบบัญชีผู้ใช้: ' || COALESCE(v_target_name, target_user_id::text));

  RETURN jsonb_build_object('success', true, 'message', 'User deleted successfully');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 9. ให้สิทธิ์ Execute แก่ Authenticated Users
GRANT EXECUTE ON FUNCTION public.admin_create_user(TEXT, TEXT, TEXT, TEXT, BOOLEAN) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.admin_update_user(UUID, TEXT, TEXT, TEXT, TEXT) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.user_change_own_password(TEXT) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.admin_delete_user(UUID) TO authenticated, service_role, anon;
