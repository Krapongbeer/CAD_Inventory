-- ================================================================
-- SmartCAD Inventory — กองบริหารงานกลาง สำนักงานมหาวิทยาลัย มหาวิทยาลัยเชียงใหม่
-- MASTER DATABASE SCHEMA & RPC FUNCTIONS (All-In-One Setup)
-- ================================================================
-- วิธีใช้งาน:
-- 1. เข้าไปที่ Supabase Dashboard > SQL Editor > New query
-- 2. คัดลอกคำสั่งทั้งหมดในไฟล์นี้ไปวาง แล้วกด Run
-- ================================================================

-- ================================================================
-- 1. ตารางข้อมูลหลัก (Tables Definition)
-- ================================================================

-- 1.1 ตารางผู้ใช้งานและสิทธิ์ (user_roles)
CREATE TABLE IF NOT EXISTS public.user_roles (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  role        TEXT NOT NULL CHECK (role IN ('superadmin', 'admin', 'staff', 'executive', 'editor', 'viewer')),
  full_name   TEXT,
  email       TEXT,
  department  TEXT DEFAULT 'กองบริหารงานกลาง',
  status      TEXT DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'pending')),
  created_at  TIMESTAMPTZ DEFAULT NOW()
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
EXCEPTION
  WHEN OTHERS THEN NULL;
END $$;

-- ซิงค์อีเมลจาก auth.users มายัง user_roles สำหรับบัญชีที่มีอยู่เดิม
UPDATE public.user_roles ur
SET email = au.email
FROM auth.users au
WHERE ur.user_id = au.id AND (ur.email IS NULL OR ur.email = '');


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
  pk              BIGSERIAL PRIMARY KEY,  -- Auto-increment Primary Key
  id              BIGINT,                 -- ID จากไฟล์ Excel
  asset_key       TEXT,                   -- คีย์สินทรัพย์
  registered_date DATE,                   -- วันที่ขึ้นทะเบียน
  cost            NUMERIC(15,2),          -- ราคาทุน (บาท)
  description_sys TEXT,                   -- คำอธิบายระบบ
  name            TEXT NOT NULL,          -- ชื่อครุภัณฑ์
  detail          TEXT,                   -- รายละเอียดเพิ่มเติม
  brand           TEXT,                   -- ยี่ห้อ
  model           TEXT,                   -- รุ่น
  serial_number   TEXT,                   -- ซีเรียลนัมเบอร์
  warranty_years  NUMERIC(5,1),           -- ปีรับประกัน
  department      TEXT,                   -- งาน/หน่วยงาน
  condition       TEXT,                   -- สภาพ (ดี/ปานกลาง/ชำรุด)
  building        TEXT,                   -- อาคาร
  floor           TEXT,                   -- ชั้น
  room            TEXT,                   -- ห้อง
  storage_detail  TEXT,                   -- รายละเอียดการจัดเก็บ
  owner           TEXT,                   -- ผู้ครอบครอง
  assignee        TEXT,                   -- ผู้ดูแล
  note            TEXT,                   -- หมายเหตุ
  upload_batch_id UUID REFERENCES public.upload_batches(id) ON DELETE CASCADE,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);


-- 1.4 ตารางประวัติการทำงานของระบบ (activity_logs / Audit Trail)
CREATE TABLE IF NOT EXISTS public.activity_logs (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  action      TEXT NOT NULL,
  details     TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);


-- ================================================================
-- 2. Indexes เพื่อเพิ่มประสิทธิภาพการค้นหา (Performance Indexing)
-- ================================================================
CREATE INDEX IF NOT EXISTS idx_assets_department      ON public.assets(department);
CREATE INDEX IF NOT EXISTS idx_assets_condition       ON public.assets(condition);
CREATE INDEX IF NOT EXISTS idx_assets_building        ON public.assets(building);
CREATE INDEX IF NOT EXISTS idx_assets_registered_date ON public.assets(registered_date);
CREATE INDEX IF NOT EXISTS idx_assets_upload_batch    ON public.assets(upload_batch_id);
CREATE INDEX IF NOT EXISTS idx_assets_name            ON public.assets(name);
CREATE INDEX IF NOT EXISTS idx_assets_id              ON public.assets(id);
CREATE INDEX IF NOT EXISTS idx_activity_logs_created  ON public.activity_logs(created_at DESC);


-- ================================================================
-- 3. ระบบความปลอดภัยระดับแถวข้อมูล (Row Level Security - RLS)
-- ================================================================

ALTER TABLE public.upload_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;

-- Helper Function: ดึง Role ของ User ปัจจุบัน
CREATE OR REPLACE FUNCTION public.get_current_user_role()
RETURNS TEXT AS $$
  SELECT role FROM public.user_roles WHERE user_id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER;


-- 3.1 RLS Policies สำหรับ upload_batches
DROP POLICY IF EXISTS "Authenticated users can read upload_batches" ON public.upload_batches;
CREATE POLICY "Authenticated users can read upload_batches"
  ON public.upload_batches FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Admins can insert upload_batches" ON public.upload_batches;
CREATE POLICY "Admins can insert upload_batches"
  ON public.upload_batches FOR INSERT
  TO authenticated
  WITH CHECK (public.get_current_user_role() IN ('admin', 'superadmin'));

DROP POLICY IF EXISTS "Admins can delete upload_batches" ON public.upload_batches;
CREATE POLICY "Admins can delete upload_batches"
  ON public.upload_batches FOR DELETE
  TO authenticated
  USING (public.get_current_user_role() IN ('admin', 'superadmin'));


-- 3.2 RLS Policies สำหรับ assets
DROP POLICY IF EXISTS "Authenticated users can read assets" ON public.assets;
CREATE POLICY "Authenticated users can read assets"
  ON public.assets FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Admins can insert assets" ON public.assets;
CREATE POLICY "Admins can insert assets"
  ON public.assets FOR INSERT
  TO authenticated
  WITH CHECK (public.get_current_user_role() IN ('admin', 'superadmin'));

DROP POLICY IF EXISTS "Admins can delete assets" ON public.assets;
CREATE POLICY "Admins can delete assets"
  ON public.assets FOR DELETE
  TO authenticated
  USING (public.get_current_user_role() IN ('admin', 'superadmin'));


-- 3.3 RLS Policies สำหรับ user_roles
DROP POLICY IF EXISTS "Users can read own role" ON public.user_roles;
CREATE POLICY "Users can read own role"
  ON public.user_roles FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Admins can read all roles" ON public.user_roles;
CREATE POLICY "Admins can read all roles"
  ON public.user_roles FOR SELECT
  TO authenticated
  USING (public.get_current_user_role() IN ('admin', 'superadmin'));

DROP POLICY IF EXISTS "Admins can update roles" ON public.user_roles;
CREATE POLICY "Admins can update roles"
  ON public.user_roles FOR UPDATE
  TO authenticated
  USING (public.get_current_user_role() IN ('admin', 'superadmin'));


-- 3.4 RLS Policies สำหรับ activity_logs
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


-- ================================================================
-- 4. ฟังก์ชันจัดการผู้ใช้หลังบ้าน (Secure Admin RPC Functions)
-- ================================================================

-- 4.1 RPC: สร้างผู้ใช้งานใหม่โดย Admin / Superadmin
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
    new_user_id,
    new_user_id,
    jsonb_build_object('sub', new_user_id::text, 'email', admin_create_user.email),
    'email',
    new_user_id::text,
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


-- 4.2 RPC: แก้ไขข้อมูลบัญชีผู้ใช้ (Superadmin / Admin Full RBAC)
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


-- 4.3 RPC: ลบบัญชีผู้ใช้ออกจากระบบ (Superadmin / Admin)
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


-- 4.4 ให้สิทธิ์ Execute แก่ Authenticated Users
GRANT EXECUTE ON FUNCTION public.admin_create_user(TEXT, TEXT, TEXT, TEXT) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.admin_update_user(UUID, TEXT, TEXT, TEXT, TEXT) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.admin_delete_user(UUID) TO authenticated, service_role, anon;

-- ================================================================
-- 5. ตั้งค่าสิทธิ์ Superadmin สำหรับบัญชีแรก
-- ================================================================
UPDATE public.user_roles 
SET role = 'superadmin' 
WHERE user_id = auth.uid();
