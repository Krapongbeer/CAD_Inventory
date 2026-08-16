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
├── users.html              ← จัดการผู้ใช้ & Audit Log (Superadmin/Admin)
├── database/
│   └── schema.sql          ← Master Database Schema & Secure RPC Functions
├── assets/images/          ← โลโก้และรูปภาพระบบ
├── css/
│   └── style.css           ← Design system ทั้งหมด
└── js/
    ├── config.js           ← ⚠️ ต้องแก้ไข Supabase Keys ที่นี่
    ├── auth.js             ← ระบบ Login / Role management
    ├── theme.js            ← จัดการโหมดกลางวัน/กลางคืน
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

### ขั้นที่ 2: รัน Master SQL Schema

1. ไปที่ Supabase Dashboard → **SQL Editor**
2. คลิก **New query**
3. Copy เนื้อหาจากไฟล์ `database/schema.sql` แล้ว Paste
4. คลิก **Run** (Ctrl+Enter / Cmd+Enter)

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

## 🎨 สิทธิ์ผู้ใช้แต่ละประเภท (Role-Based Access Control)

| หน้า / ฟังก์ชัน | Super Admin | Admin | Executive | Staff |
|---|:---:|:---:|:---:|:---:|
| Login (NIST Authentication) | ✅ | ✅ | ✅ | ✅ |
| Dashboard ภาพรวม (Overview) | ✅ | ✅ | ✅ | ✅ |
| Dashboard วิเคราะห์เชิงลึก (Deep Analytics) | ✅ | ✅ | ✅ | ❌ |
| ทะเบียนครุภัณฑ์ (Inventory) | ✅ | ✅ | ✅ | ✅ |
| รายงานผู้บริหาร (Executive Report) | ✅ | ✅ | ✅ | ❌ |
| อัปโหลดไฟล์ Excel (Data Ingestion) | ✅ | ✅ | ❌ | ❌ |
| จัดการผู้ใช้ & สิทธิ์ (User Management) | ✅ | ✅ | ❌ | ❌ |
| ประวัติการทำงาน (Audit Activity Logs) | ✅ | ✅ | ❌ | ❌ |
| Export Excel / PDF | ✅ | ✅ | ✅ | ✅ |

---

## 🔒 มาตรฐานความมั่นคงปลอดภัย (NIST SP 800-63B Compliance)

ระบบรองรับมาตรฐาน **NIST SP 800-63B: Digital Identity Guidelines**:
- **สุ่มรหัสผ่านชั่วคราวความปลอดภัยสูง (High-Entropy Temp Password):** 12 ตัวอักษร ผสมตัวพิมพ์ใหญ่ เล็ก ตัวเลข สัญลักษณ์
- **ระบบ Onboarding Dispatch:** สรุปข้อมูลส่งผ่าน LINE / Chat หรือคลิกส่งอีเมลผ่าน Mail Client ทันที
- **ระบบบังคับเปลี่ยนรหัสผ่านครั้งแรก (Forced First-Login Reset):** ล็อกหน้าจอทันทีจนกว่าผู้ใช้จะตั้งรหัสผ่านใหม่ถาวร
- **Real-time Password Strength Meter:** ตรวจสอบความยาว 8+ ตัวอักษร, ป้องกันชื่อ/อีเมลในรหัสผ่าน, ป้องกันคำง่ายในพจนานุกรม
- **Self-Account Protection Guard:** ป้องกันผู้ดูแลระบบเผลอลบหรือระงับการใช้งานบัญชีตนเอง

---

## 📚 เอกสารงานวิจัยและรายงานฉบับสมบูรณ์ (Research Documentation)

ระบบมีเอกสารงานวิจัย 5 บท และรายงานสรุปการพัฒนารองรับมาตรฐาน APA 7th Edition ในโฟลเดอร์ [`research_docs/`](research_docs/):
- [`research_docs/Chapter_1_Introduction.md`](research_docs/Chapter_1_Introduction.md) — บทที่ 1: บทนำ ความเป็นมา และวัตถุประสงค์
- [`research_docs/Chapter_2_Literature.md`](research_docs/Chapter_2_Literature.md) — บทที่ 2: วรรณกรรมและทฤษฎีที่เกี่ยวข้อง
- [`research_docs/Chapter_3_Methodology.md`](research_docs/Chapter_3_Methodology.md) — บทที่ 3: ระเบียบวิธีวิจัยและสถาปัตยกรรมระบบ
- [`research_docs/Chapter_4_Results.md`](research_docs/Chapter_4_Results.md) — บทที่ 4: ผลการศึกษาและการทดสอบระบบ
- [`research_docs/Chapter_5_Conclusion.md`](research_docs/Chapter_5_Conclusion.md) — บทที่ 5: สรุปผล อภิปราย และข้อเสนอแนะ
- [`research_docs/Update_Report_NIST_Onboarding.md`](research_docs/Update_Report_NIST_Onboarding.md) — รายงานสรุปการอัปเดตระบบ NIST SP 800-63B
- [`research_docs/References_APA.md`](research_docs/References_APA.md) — เอกสารอ้างอิงมาตรฐาน APA 7th Edition

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
| Frontend | HTML5 + Vanilla JavaScript (ES6+) + CSS3 | ฟรี |
| Auth & Backend | Supabase GoTrue Auth + PostgreSQL 15+ | ฟรี (500MB) |
| Security Framework | NIST SP 800-63B + OWASP Top 10 + RBAC | มาตรฐานสากล |
| กราฟและการแสดงผล | Chart.js 4.4.1 | ฟรี (MIT) |
| Excel Parser | SheetJS (xlsx 0.18.5) | ฟรี (Apache 2.0) |
| Hosting | GitHub Pages | ฟรี |

---

## 📞 ติดต่อ

กองบริหารงานกลาง สำนักงานมหาวิทยาลัย  
มหาวิทยาลัยเชียงใหม่  
239 ถนนห้วยแก้ว ตำบลสุเทพ อำเภอเมือง จังหวัดเชียงใหม่ 50200

