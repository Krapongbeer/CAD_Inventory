# ระบบบริหารจัดการครุภัณฑ์ — กองบริหารงานกลาง มช.
**CAD Inventory Dashboard v1.0**

---

## 📁 โครงสร้างไฟล์

```
CAD-Inventory-Dashboard/
├── index.html              ← หน้า Login
├── dashboard.html          ← Dashboard ภาพรวม (กราฟ + KPI)
├── inventory.html          ← ตารางรายการครุภัณฑ์ทั้งหมด
├── upload.html             ← อัปโหลดไฟล์ Excel (Admin)
├── report.html             ← รายงานสำหรับผู้บริหาร
├── supabase-schema.sql     ← SQL สำหรับสร้าง Database
├── assets/images/cmu_logo.jpg            ← โลโก้มหาวิทยาลัย
├── css/
│   └── style.css           ← Design system ทั้งหมด
└── js/
    ├── config.js           ← ⚠️ ต้องแก้ไข Supabase Keys ที่นี่
    ├── auth.js             ← ระบบ Login / Role management
    └── excel-parser.js     ← อ่านไฟล์ Excel (SheetJS)
```

---

## 🚀 ขั้นตอนการตั้งค่า

### ขั้นที่ 1: สร้าง Supabase Project

1. ไปที่ [supabase.com](https://supabase.com) → Sign In → New Project
2. ตั้งชื่อ Project เช่น `cmu-inventory`
3. เลือก Region: **Southeast Asia (Singapore)**
4. ตั้ง Database Password (จดไว้)
5. รอ Project สร้างเสร็จ (~2 นาที)

### ขั้นที่ 2: รัน SQL Schema

1. ไปที่ Supabase Dashboard → **SQL Editor**
2. คลิก **New query**
3. Copy เนื้อหาจากไฟล์ `supabase-schema.sql` แล้ว Paste
4. คลิก **Run** (Ctrl+Enter)

### ขั้นที่ 3: ดึง API Keys

1. ไปที่ Supabase Dashboard → **Settings** → **API**
2. Copy ค่า 2 อย่าง:
   - **Project URL** (เช่น `https://abcxyz.supabase.co`)
   - **anon/public key** (ยาวมาก)

### ขั้นที่ 4: แก้ไขไฟล์ config.js

เปิดไฟล์ `js/config.js` และแก้ไขบรรทัด:

```javascript
const SUPABASE_URL = 'https://YOUR_PROJECT_ID.supabase.co';
const SUPABASE_ANON_KEY = 'YOUR_SUPABASE_ANON_KEY';
```

เปลี่ยนเป็น URL และ Key จริงของคุณ

### ขั้นที่ 5: สร้างผู้ใช้ Admin

1. ไปที่ Supabase Dashboard → **Authentication** → **Users** → **Add user**
2. กรอก Email และ Password สำหรับ Admin
3. คัดลอก **User UID** (จะใช้ในขั้นถัดไป)
4. ไปที่ **SQL Editor** แล้วรัน:

```sql
INSERT INTO user_roles (user_id, role, full_name)
VALUES ('UID-จาก-Supabase', 'admin', 'ชื่อผู้ดูแลระบบ');
```

### ขั้นที่ 6: เพิ่มผู้ใช้อื่น

ทำซ้ำขั้นที่ 5 สำหรับผู้ใช้อื่น โดยเปลี่ยน role เป็น:
- `admin` — ผู้ดูแลระบบ (อัปโหลดได้, จัดการได้)
- `staff` — เจ้าหน้าที่ (ดู Dashboard, Export ได้)
- `executive` — ผู้บริหาร (ดู Dashboard, รายงาน)

### ขั้นที่ 7: เปิดใช้งาน

เปิดไฟล์ `index.html` ใน Browser แล้ว Login ด้วย Email/Password ที่สร้างไว้

---

## 📊 ขั้นตอนการนำเข้าข้อมูล (ครั้งแรก)

1. Login ด้วย account **Admin**
2. ไปที่เมนู **อัปโหลดข้อมูล**
3. ลากไฟล์ `ครุภัณฑ์ คอมพิวเตอร์ (ไฟล์กองคลัง).xlsx` มาวาง
4. ตรวจสอบ Preview ข้อมูล 5 แถวแรก
5. คลิก **นำเข้าข้อมูล**
6. รอจนเสร็จ (ประมาณ 30-60 วินาที)

---

## 🌐 Deploy บน GitHub Pages (ฟรี)

```bash
# 1. Push โค้ดขึ้น GitHub
git add .
git commit -m "initial setup"
git push origin main

# 2. ไปที่ GitHub Repository → Settings → Pages
# 3. เลือก Source: "Deploy from a branch"
# 4. เลือก Branch: main, Folder: / (root)
# 5. Save → รอ 2-3 นาที
# URL จะเป็น: https://username.github.io/CAD-Inventory-Dashboard/
```

---

## 🎨 สิทธิ์ผู้ใช้แต่ละประเภท

| หน้า | Admin | Staff | Executive |
|---|:---:|:---:|:---:|
| Login | ✅ | ✅ | ✅ |
| Dashboard | ✅ | ✅ | ✅ |
| รายการครุภัณฑ์ | ✅ | ✅ | ✅ |
| รายงานผู้บริหาร | ✅ | ✅ | ✅ |
| อัปโหลดข้อมูล | ✅ | ❌ | ❌ |
| Export Excel/PDF | ✅ | ✅ | ✅ |

---

## 📋 เกณฑ์อายุครุภัณฑ์ (กรมบัญชีกลาง)

| ประเภท | เกณฑ์แจ้งเตือน 🟡 | เกณฑ์วิกฤต 🔴 |
|---|:---:|:---:|
| คอมพิวเตอร์/อุปกรณ์ IT | 3 ปี | 5 ปี |
| ครุภัณฑ์สำนักงานทั่วไป | 7 ปี | 12 ปี |
| ครุภัณฑ์ไฟฟ้า | 5 ปี | 10 ปี |
| เครื่องเสียง/โสตทัศน์ | 5 ปี | 10 ปี |

---

## 🔧 เทคโนโลยีที่ใช้ (ฟรี 100%)

| ส่วน | เทคโนโลยี | ราคา |
|---|---|---|
| Frontend | HTML + Vanilla JS + CSS | ฟรี |
| Auth | Supabase Auth | ฟรี |
| Database | Supabase PostgreSQL | ฟรี (500MB) |
| กราฟ | Chart.js | ฟรี |
| Excel | SheetJS (xlsx) | ฟรี |
| Hosting | GitHub Pages | ฟรี |

---

## 📞 ติดต่อ

กองบริหารงานกลาง สำนักงานมหาวิทยาลัย  
มหาวิทยาลัยเชียงใหม่  
239 ถนนห้วยแก้ว ตำบลสุเทพ อำเภอเมือง จังหวัดเชียงใหม่ 50200
