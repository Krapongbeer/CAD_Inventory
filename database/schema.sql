-- ================================================================
-- SmartCAD Inventory: Master Database Schema (v3 - NIST Compliant)
-- กองบริหารงานกลาง สำนักงานมหาวิทยาลัย มหาวิทยาลัยเชียงใหม่
-- ================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1.1 ตารางสิทธิ์และข้อมูลผู้ใช้งาน (user_roles)
CREATE TABLE IF NOT EXISTS public.user_roles (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               UUID UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  role                  TEXT NOT NULL CHECK (role IN ('superadmin', 'admin', 'staff', 'executive', 'editor', 'viewer')),
  full_name             TEXT,
  email                 TEXT,
  department            TEXT DEFAULT 'กองบริหารงานกลาง',
  status                TEXT DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'pending')),
  must_change_password  BOOLEAN DEFAULT true,
  last_password_change  TIMESTAMPTZ DEFAULT NOW(),
  created_at            TIMESTAMPTZ DEFAULT NOW()
);

-- ปลดล็อกและอัปเดต Constraint & Column หากตารางมีอยู่เดิม
DO $$
BEGIN
  ALTER TABLE public.user_roles DROP CONSTRAINT IF EXISTS user_roles_role_check;
  ALTER TABLE public.user_roles ADD CONSTRAINT user_roles_role_check 
    CHECK (role IN ('superadmin', 'admin', 'staff', 'executive', 'editor', 'viewer'));
  ALTER TABLE public.user_roles ADD COLUMN IF NOT EXISTS email TEXT;
  ALTER TABLE public.user_roles ADD COLUMN IF NOT EXISTS department TEXT DEFAULT 'กองบริหารงานกลาง';
  ALTER TABLE public.user_roles ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active';
  ALTER TABLE public.user_roles ADD COLUMN IF NOT EXISTS must_change_password BOOLEAN DEFAULT true;
  ALTER TABLE public.user_roles ADD COLUMN IF NOT EXISTS last_password_change TIMESTAMPTZ DEFAULT NOW();
EXCEPTION
  WHEN OTHERS THEN NULL;
END $$;


-- 1.2 ตารางประวัติชุดการนำเข้าไฟล์ Excel (upload_batches)
CREATE TABLE IF NOT EXISTS public.upload_batches (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  filename    TEXT NOT NULL,
  uploaded_by UUID REFERENCES auth.users(id),
  total_rows  INT DEFAULT 0,
  note        TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);


-- 1.3 ตารางข้อมูลครุภัณฑ์หลัก (assets)
CREATE TABLE IF NOT EXISTS public.assets (
  pk              BIGSERIAL PRIMARY KEY,
  id              BIGINT,
  asset_key       TEXT,
  registered_date DATE,
  cost            NUMERIC(15,2),
  description_sys TEXT,
  name            TEXT NOT NULL,
  detail          TEXT,
  brand           TEXT,
  model           TEXT,
  serial_number   TEXT,
  warranty_years  NUMERIC(5,1),
  department      TEXT,
  condition       TEXT,
  building        TEXT,
  floor           TEXT,
  room            TEXT,
  storage_detail  TEXT,
  owner           TEXT,
  assignee        TEXT,
  note            TEXT,
  upload_batch_id UUID REFERENCES public.upload_batches(id) ON DELETE CASCADE,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);


-- 1.4 ตารางบันทึกประวัติการใช้งาน (activity_logs)
CREATE TABLE IF NOT EXISTS public.activity_logs (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  action      TEXT NOT NULL,
  details     TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);


-- 2. ดัชนีเพื่อประสิทธิภาพการค้นหา (Performance Indexing)
CREATE INDEX IF NOT EXISTS idx_assets_department      ON public.assets(department);
CREATE INDEX IF NOT EXISTS idx_assets_condition       ON public.assets(condition);
CREATE INDEX IF NOT EXISTS idx_assets_building        ON public.assets(building);
CREATE INDEX IF NOT EXISTS idx_assets_registered_date ON public.assets(registered_date);
CREATE INDEX IF NOT EXISTS idx_assets_upload_batch    ON public.assets(upload_batch_id);
CREATE INDEX IF NOT EXISTS idx_assets_name            ON public.assets(name);
CREATE INDEX IF NOT EXISTS idx_user_roles_user_id     ON public.user_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_activity_logs_created  ON public.activity_logs(created_at DESC);


-- 3. Row Level Security (RLS)
ALTER TABLE public.user_roles     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assets         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.upload_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_logs  ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow authenticated read user_roles" ON public.user_roles;
DROP POLICY IF EXISTS "Allow user update own role" ON public.user_roles;
DROP POLICY IF EXISTS "Allow admin all user_roles" ON public.user_roles;
DROP POLICY IF EXISTS "Allow all read assets" ON public.assets;
DROP POLICY IF EXISTS "Allow admin insert assets" ON public.assets;
DROP POLICY IF EXISTS "Allow admin update assets" ON public.assets;
DROP POLICY IF EXISTS "Allow admin delete assets" ON public.assets;
DROP POLICY IF EXISTS "Allow authenticated read batches" ON public.upload_batches;
DROP POLICY IF EXISTS "Allow admin insert batches" ON public.upload_batches;
DROP POLICY IF EXISTS "Allow admin delete batches" ON public.upload_batches;
DROP POLICY IF EXISTS "Allow authenticated read activity" ON public.activity_logs;
DROP POLICY IF EXISTS "Allow authenticated insert activity" ON public.activity_logs;

CREATE POLICY "Allow authenticated read user_roles" ON public.user_roles FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow admin all user_roles" ON public.user_roles FOR ALL TO authenticated USING (
  EXISTS (SELECT 1 FROM public.user_roles ur WHERE ur.user_id = auth.uid() AND ur.role IN ('superadmin', 'admin'))
);
CREATE POLICY "Allow all read assets" ON public.assets FOR SELECT TO authenticated, anon USING (true);
CREATE POLICY "Allow admin insert assets" ON public.assets FOR INSERT TO authenticated WITH CHECK (
  EXISTS (SELECT 1 FROM public.user_roles ur WHERE ur.user_id = auth.uid() AND ur.role IN ('superadmin', 'admin', 'editor'))
);
CREATE POLICY "Allow admin update assets" ON public.assets FOR UPDATE TO authenticated USING (
  EXISTS (SELECT 1 FROM public.user_roles ur WHERE ur.user_id = auth.uid() AND ur.role IN ('superadmin', 'admin', 'editor'))
);
CREATE POLICY "Allow admin delete assets" ON public.assets FOR DELETE TO authenticated USING (
  EXISTS (SELECT 1 FROM public.user_roles ur WHERE ur.user_id = auth.uid() AND ur.role IN ('superadmin', 'admin'))
);
CREATE POLICY "Allow authenticated read batches" ON public.upload_batches FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow admin insert batches" ON public.upload_batches FOR INSERT TO authenticated WITH CHECK (
  EXISTS (SELECT 1 FROM public.user_roles ur WHERE ur.user_id = auth.uid() AND ur.role IN ('superadmin', 'admin'))
);
CREATE POLICY "Allow admin delete batches" ON public.upload_batches FOR DELETE TO authenticated USING (
  EXISTS (SELECT 1 FROM public.user_roles ur WHERE ur.user_id = auth.uid() AND ur.role IN ('superadmin', 'admin'))
);
CREATE POLICY "Allow authenticated read activity" ON public.activity_logs FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow authenticated insert activity" ON public.activity_logs FOR INSERT TO authenticated WITH CHECK (true);


-- 4. Secure RPC Stored Procedures

-- 4.1 RPC: สร้างผู้ใช้ใหม่
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
  SELECT role INTO caller_role FROM public.user_roles WHERE user_roles.user_id = auth.uid();
  IF caller_role NOT IN ('superadmin', 'admin') THEN
    RAISE EXCEPTION 'Unauthorized: Only admins and superadmins can create users.';
  END IF;

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

  INSERT INTO public.activity_logs (user_id, action, details)
  VALUES (auth.uid(), 'create_user', 'สร้างผู้ใช้ใหม่: ' || admin_create_user.full_name || ' (' || admin_create_user.user_role || ') อีเมล: ' || admin_create_user.email || ' [รหัสผ่านชั่วคราว - รอเปลี่ยนรหัส]');

  RETURN jsonb_build_object('success', true, 'user_id', new_user_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 4.2 RPC: แก้ไขข้อมูลผู้ใช้
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


-- 4.3 RPC: ผู้ใช้เปลี่ยนรหัสผ่านของตนเอง
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


-- 4.4 RPC: ลบบัญชีผู้ใช้
CREATE OR REPLACE FUNCTION public.admin_delete_user(
  target_user_id UUID
) RETURNS JSONB AS $$
DECLARE
  caller_role TEXT;
  target_role TEXT;
  v_target_name TEXT;
BEGIN
  SELECT role INTO caller_role FROM public.user_roles WHERE user_roles.user_id = auth.uid();
  IF caller_role NOT IN ('superadmin', 'admin') THEN
    RAISE EXCEPTION 'Unauthorized: Only admins and superadmins can delete users.';
  END IF;

  SELECT role, full_name INTO target_role, v_target_name FROM public.user_roles WHERE user_roles.user_id = target_user_id;

  IF target_role = 'superadmin' AND caller_role != 'superadmin' THEN
    RAISE EXCEPTION 'Unauthorized: Admin cannot delete a superadmin user.';
  END IF;

  IF target_user_id = auth.uid() THEN
    RAISE EXCEPTION 'Cannot delete your own active account.';
  END IF;

  DELETE FROM public.user_roles WHERE user_roles.user_id = target_user_id;
  DELETE FROM auth.identities WHERE user_id = target_user_id;
  DELETE FROM auth.users WHERE auth.users.id = target_user_id;

  INSERT INTO public.activity_logs (user_id, action, details)
  VALUES (auth.uid(), 'delete_user', 'ลบบัญชีผู้ใช้: ' || COALESCE(v_target_name, target_user_id::text));

  RETURN jsonb_build_object('success', true, 'message', 'User deleted successfully');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;



-- 4.5 สิทธิ์การ Execute ฟังก์ชัน
GRANT EXECUTE ON FUNCTION public.admin_create_user(TEXT, TEXT, TEXT, TEXT, BOOLEAN) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.admin_update_user(UUID, TEXT, TEXT, TEXT, TEXT) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.user_change_own_password(TEXT) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.admin_delete_user(UUID) TO authenticated, service_role, anon;
