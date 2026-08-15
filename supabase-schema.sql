-- ================================================================
-- CAD Inventory Dashboard — กองบริหารงานกลาง มช.
-- Supabase Schema Setup v1.1
-- ================================================================
-- วิธีใช้:
-- 1. ไปที่ Supabase Dashboard > SQL Editor > New query
-- 2. Copy ทั้งหมดนี้ Paste แล้วกด Run
-- ================================================================

-- ตรวจสอบและลบ table เก่าก่อน (ถ้ามี) เพื่อ clean install
-- ⚠️ ถ้ามีข้อมูลอยู่แล้วอย่า DROP
-- DROP TABLE IF EXISTS assets CASCADE;
-- DROP TABLE IF EXISTS upload_batches CASCADE;
-- DROP TABLE IF EXISTS user_roles CASCADE;

-- 1. ตารางผู้ใช้และสิทธิ์ (สร้างก่อน เพราะ assets อ้างอิง)
CREATE TABLE IF NOT EXISTS user_roles (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  role       TEXT NOT NULL CHECK (role IN ('admin', 'staff', 'executive')),
  full_name  TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. ตารางประวัติการอัปโหลด
CREATE TABLE IF NOT EXISTS upload_batches (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  filename    TEXT NOT NULL,
  uploaded_by UUID REFERENCES auth.users(id),
  total_rows  INT DEFAULT 0,
  note        TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 3. ตารางข้อมูลครุภัณฑ์หลัก
--    ใช้ serial pk เพื่อรองรับ id ซ้ำระหว่าง batch
CREATE TABLE IF NOT EXISTS assets (
  pk              BIGSERIAL PRIMARY KEY,  -- auto-increment key
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
  upload_batch_id UUID REFERENCES upload_batches(id) ON DELETE CASCADE,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ================================================================
-- Row Level Security (RLS)
-- ================================================================

ALTER TABLE upload_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;

-- upload_batches: ทุกคน login แล้วอ่านได้
CREATE POLICY "Authenticated users can read upload_batches"
  ON upload_batches FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Admins can insert upload_batches"
  ON upload_batches FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

CREATE POLICY "Admins can delete upload_batches"
  ON upload_batches FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- assets: ทุกคน login แล้วอ่านได้, admin เท่านั้นที่เขียน/ลบได้
CREATE POLICY "Authenticated users can read assets"
  ON assets FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Admins can insert assets"
  ON assets FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

CREATE POLICY "Admins can delete assets"
  ON assets FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- user_roles: ผู้ใช้อ่านของตัวเองได้, admin อ่านทั้งหมดได้
CREATE POLICY "Users can read own role"
  ON user_roles FOR SELECT
  TO authenticated
  USING (user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM user_roles ur2
      WHERE ur2.user_id = auth.uid() AND ur2.role = 'admin'
    )
  );

-- ================================================================
-- Indexes สำหรับ Query ที่ใช้บ่อย
-- ================================================================
CREATE INDEX IF NOT EXISTS idx_assets_department      ON assets(department);
CREATE INDEX IF NOT EXISTS idx_assets_condition       ON assets(condition);
CREATE INDEX IF NOT EXISTS idx_assets_building        ON assets(building);
CREATE INDEX IF NOT EXISTS idx_assets_registered_date ON assets(registered_date);
CREATE INDEX IF NOT EXISTS idx_assets_upload_batch    ON assets(upload_batch_id);
CREATE INDEX IF NOT EXISTS idx_assets_name            ON assets(name);
CREATE INDEX IF NOT EXISTS idx_assets_id              ON assets(id);

-- ================================================================
-- Helper Function: ดึง role ของ user ปัจจุบัน
-- ================================================================
CREATE OR REPLACE FUNCTION get_current_user_role()
RETURNS TEXT AS $$
  SELECT role FROM user_roles WHERE user_id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER;

-- ================================================================
-- ✅ หลังรัน Schema นี้แล้ว ให้ดำเนินการต่อ:
--
-- STEP 1: ไปที่ Authentication > Users > Add User
--         ใส่ Email + Password สำหรับ Admin แล้วคัดลอก UUID
--
-- STEP 2: รัน SQL นี้ (เปลี่ยน UUID และชื่อให้ถูกต้อง):
--
--   INSERT INTO user_roles (user_id, role, full_name)
--   VALUES ('<UUID>', 'admin', 'ผู้ดูแลระบบ');
--
-- STEP 3: เปิดไฟล์ index.html แล้ว Login ได้เลย!
-- ================================================================
