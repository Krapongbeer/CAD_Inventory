-- ================================================================
-- SmartCAD Inventory: 1-Click Master Clean & Auto-Trigger Setup
-- คัดลอกคำสั่งทั้งหมดนี้ไปรันใน Supabase > SQL Editor 1 ครั้งจบ
-- ================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. เตรียมคอลัมน์ในตาราง user_roles
ALTER TABLE public.user_roles ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE public.user_roles ADD COLUMN IF NOT EXISTS department TEXT DEFAULT 'กองบริหารงานกลาง';
ALTER TABLE public.user_roles ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active';
ALTER TABLE public.user_roles ADD COLUMN IF NOT EXISTS must_change_password BOOLEAN DEFAULT true;
ALTER TABLE public.user_roles ADD COLUMN IF NOT EXISTS last_password_change TIMESTAMPTZ DEFAULT NOW();

-- 2. ล้างบัญชีที่ค้างข้อผิดพลาด (เช่น kequiv) เพื่อให้ระบบสร้างใหม่แบบ Official สะอาด 100%
DELETE FROM auth.users WHERE lower(email) = 'kequiv@hotmail.com';
DELETE FROM public.user_roles WHERE lower(email) = 'kequiv@hotmail.com';

-- 3. ซ่อมแซม Identity และยืนยันอีเมลให้ทุกบัญชีเดิมที่ยังคงอยู่
UPDATE auth.users
SET email_confirmed_at = NOW(),
    aud = 'authenticated',
    role = 'authenticated',
    raw_app_meta_data = '{"provider":"email","providers":["email"]}'::jsonb,
    is_sso_user = false,
    is_anonymous = false
WHERE email_confirmed_at IS NULL OR is_sso_user IS NULL;

-- 4. ติดตั้ง Database Trigger อัตโนมัติ (Official Supabase Pattern)
-- ทุกครั้งที่มีการสร้าง User ผ่านเว็บ จะซิงค์ลง user_roles อัตโนมัติทันที
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.user_roles (user_id, role, full_name, email, department, status, must_change_password)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'role', 'staff'),
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'department', 'กองบริหารงานกลาง'),
    'active',
    true
  )
  ON CONFLICT (user_id) DO UPDATE
  SET full_name = EXCLUDED.full_name,
      email = EXCLUDED.email,
      department = COALESCE(user_roles.department, EXCLUDED.department),
      status = 'active';
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 5. ฟังก์ชันเปลี่ยนรหัสผ่านครั้งแรก (NIST First Login)
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

GRANT EXECUTE ON FUNCTION public.user_change_own_password(TEXT) TO authenticated, service_role, anon;
