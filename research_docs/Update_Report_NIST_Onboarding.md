# รายงานสรุปการอัปเดตและพัฒนาระบบ (System Update & Development Report)
## ระบบ Onboarding ผู้ใช้งานใหม่ รหัสผ่านชั่วคราว และการบังคับเปลี่ยนรหัสผ่านครั้งแรกตามมาตรฐานสากล NIST SP 800-63B
**ระบบบริหารจัดการและวิเคราะห์ข้อมูลครุภัณฑ์อัจฉริยะ (SmartCAD-Inventory)**  
**กองบริหารงานกลาง สำนักงานมหาวิทยาลัย มหาวิทยาลัยเชียงใหม่**  
*วันที่อัปเดต: 16 สิงหาคม 2569 | เวอร์ชันระบบ: 2.1.0*

---

## 1. บทนำและวัตถุประสงค์ของการปรับปรุง (Introduction & Objectives)

เพื่อยกระดับความมั่นคงปลอดภัยสารสนเทศของระบบ **SmartCAD-Inventory** ให้สอดคล้องตามกรอบมาตรฐานสากล **NIST SP 800-63B: Digital Identity Guidelines (Authentication and Lifecycle Management; Grassi et al., 2020)** และข้อกำหนดการคุ้มครองข้อมูลส่วนบุคคลของภาครัฐและมหาวิทยาลัยเชียงใหม่ การพัฒนานี้มีวัตถุประสงค์หลัก 4 ประการ:

1. **การออกรหัสผ่านชั่วคราวความปลอดภัยสูง (Secure Temporary Password Provisioning):** ลดความเสี่ยงจากการตั้งรหัสผ่านเริ่มต้นที่คาดเดาได้ง่าย (เช่น `123456` หรือ `cmu1234`)
2. **ระบบส่งมอบข้อมูลบัญชีอัตโนมัติ (Automated User Onboarding & Credential Dispatch):** เพิ่มความสะดวกรวดเร็วในการแจ้งข้อมูลเข้าใช้งานให้แก่บุคลากรผ่าน Clipboard Template และ Email Protocol (Mailto)
3. **การบังคับเปลี่ยนรหัสผ่านในการเข้าใช้งานครั้งแรก (Forced First-Time Login Password Change):** บังคับให้ผู้ใช้งานต้องกำหนดรหัสผ่านถาวรของตนเองทันทีก่อนเข้าถึงฐานข้อมูลสินทรัพย์ของมหาวิทยาลัย
4. **การตรวจสอบความแข็งแกร่งของรหัสผ่านตามเกณฑ์ NIST SP 800-63B:** ตรวจสอบความยาวอย่างน้อย 8 ตัวอักษร, ป้องกันคำบริบท (Contextual Words), ป้องกันคำในพจนานุกรมคำต้องห้าม (Compromised Passwords Dictionary) พร้อมเกจวัดคะแนนความปลอดภัยแบบ Real-time
5. **การคุ้มครองบัญชีผู้ดูแลระบบสูงสุด (Superadmin Self-Account Protection Guard):** ป้องกันข้อผิดพลาดจากการลบหรือระงับการใช้งานบัญชี Superadmin ของตนเอง

---

## 2. การปรับปรุงโครงสร้างฐานข้อมูลและ Stored Procedures (Database Layer)

### 2.1 การขยายโครงสร้างตาราง `user_roles`
ได้ทำการเพิ่มคอลัมน์เพื่อรองรับการติดตามวงจรชีวิตรหัสผ่านและสถานะการใช้งาน:

```sql
ALTER TABLE public.user_roles ADD COLUMN IF NOT EXISTS department TEXT DEFAULT 'กองบริหารงานกลาง';
ALTER TABLE public.user_roles ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'pending'));
ALTER TABLE public.user_roles ADD COLUMN IF NOT EXISTS must_change_password BOOLEAN DEFAULT true;
ALTER TABLE public.user_roles ADD COLUMN IF NOT EXISTS last_password_change TIMESTAMPTZ DEFAULT NOW();
```

- `must_change_password (BOOLEAN)`: ระบุว่าผู้ใช้ต้องเปลี่ยนรหัสผ่านหรือไม่ (ค่าเริ่มต้นคือ `true` สำหรับบัญชีสร้างใหม่)
- `last_password_change (TIMESTAMPTZ)`: บันทึกวันเวลาที่มีการเปลี่ยนรหัสผ่านล่าสุด
- `status (TEXT)`: สถานะบัญชี (`active` = ใช้งานปกติ, `suspended` = ระงับใช้งานชั่วคราว)

### 2.2 ฟังก์ชัน PostgreSQL Stored Procedures (PL/pgSQL)

#### 1. `admin_create_user(email, password, full_name, user_role)`
- สร้างบัญชีใน `auth.users` พร้อมเข้ารหัส `crypt(password, gen_salt('bf'))`
- สร้าง Identity ใน `auth.identities` (Provider: `email`) เพื่อรองรับ Supabase GoTrue Auth Login Engine
- สร้างระเบียนใน `public.user_roles` โดยกำหนด `must_change_password = true`
- บันทึก Audit Log ลงตาราง `activity_logs`

#### 2. `user_change_own_password(new_password)`
- ตรวจสอบสิทธิ์ผู้เรียกด้วย `auth.uid()`
- ตรวจสอบความยาวรหัสผ่านขั้นต่ำ 8 ตัวอักษร (`length(trim(new_password)) >= 8`)
- อัปเดตรหัสผ่านที่เข้ารหัสแล้วใน `auth.users`
- ปลดสถานะ `must_change_password = false` และบันทึก `last_password_change = NOW()` ใน `user_roles`
- บันทึก Audit Log การเปลี่ยนรหัสผ่าน

---

## 3. สถาปัตยกรรมระดับซอฟต์แวร์และการทำงาน (Application Layer Architecture)

### 3.1 โมดูลสร้างรหัสผ่านชั่วคราว (Temporary Password Generator)
ฟังก์ชัน `generateSecureTempPassword()` ใน `js/auth.js` ทำการสุ่มตัวอักษร 12 ตัวอักษรที่มี High Entropy:
- ตัวพิมพ์ใหญ่ (`ABCDEFGHJKLMNPQRSTUVWXYZ` - ตัด I, O)
- ตัวพิมพ์เล็ก (`abcdefghijkmnopqrstuvwxyz` - ตัด l)
- ตัวเลข (`23456789` - ตัด 0, 1)
- สัญลักษณ์พิเศษ (`!@#$%^&*+=`)
- รับประกันว่ามีตัวอักษรครบทุกประเภทอย่างน้อยประเภทละ 2 ตัว

### 3.2 โมดูลประเมินความแข็งแกร่งตามมาตรฐาน NIST SP 800-63B
ฟังก์ชัน `validateNISTPassword(password, context)` ตรวจสอบตามกฎ 4 มิติ:
1. **Length Requirement:** ความยาวไม่ต่ำกว่า 8 ตัวอักษร (คะแนนความยาว 30-70 คะแนน)
2. **Context-Specific Prevention:** ตรวจสอบไม่ให้มีชื่อ-นามสกุล หรือส่วนของอีเมลปะปน
3. **Compromised Dictionary Prevention:** ตรวจสอบกับ Blacklist รหัสผ่านยอดนิยม 100 อันดับ (เช่น `12345678`, `password`, `smartcad123`, `cmu12345`)
4. **Entropy Calculation:** คำนวณคะแนนความหลากหลาย 0–100 พร้อมคำนวณสีและป้ายบอกระดับ:
   - `< 55`: 🔴 อ่อนแอ (ไม่ปลอดภัย)
   - `55 - 79`: 🟡 ปานกลาง (ใช้งานได้)
   - `80 - 100`: 🟢 แข็งแกร่งมาก (มาตรฐาน NIST)

### 3.3 ระบบ Interceptor ขัดจังหวะการเข้าใช้งานครั้งแรก (First-Login Interceptor)
- ฟังก์ชัน `requireAuth()` ทำการดึงข้อมูล `user_roles` และตรวจสอบ `must_change_password === true`
- หากพบเงื่อนไข จะทำการเรนเดอร์หน้าต่าง Modal บังคับตั้งรหัสผ่านใหม่ครอบทับหน้าจอทันที
- ผู้ใช้ไม่สามารถปิด Modal, ข้ามหน้า, หรือคลิกเข้าถึงข้อมูลหลังบ้านได้ จนกว่าจะส่งรหัสผ่านใหม่ที่ผ่านเกณฑ์ NIST ทั้งหมด

### 3.4 ระบบส่งมอบข้อมูล Onboarding Summary Modal
- หลัง Superadmin สร้างผู้ใช้ใหม่สำเร็จ ระบบจะแสดงหน้าต่างสรุปข้อมูลพร้อมรหัสผ่านชั่วคราว
- ปุ่ม **📋 คัดลอกข้อความสรุป:** ข้อความจัดฟอร์แมตทางการ ระบุชื่อ, อีเมล, รหัสชั่วคราว, ลิงก์ระบบ และคำแนะนำ NIST สำหรับส่งทาง LINE
- ปุ่ม **📧 เปิดแอปอีเมล:** ใช้ `mailto:` Protocol ร่างอีเมลแจ้งเตือนถึงผู้ใช้ให้อัตโนมัติ

---

## 4. ผลการทดสอบและตรวจสอบความถูกต้อง (Verification & Evaluation Matrix)

| รายการทดสอบ | เงื่อนไขการทดสอบ | ผลลัพธ์ที่คาดหวัง | ผลการทดสอบจริง | สถานะ |
|---|---|---|---|:---:|
| **1. Temp Password Generation** | กดปุ่ม `🎲 สุ่มรหัสชั่วคราว (NIST)` ในฟอร์มเพิ่มผู้ใช้ | ได้รหัสผ่าน 12 ตัวอักษรที่มีตัวพิมพ์ใหญ่ เล็ก ตัวเลข สัญลักษณ์ | สุ่มรหัสผ่านความปลอดภัยสูงถูกต้อง | **PASS** |
| **2. User Creation & Onboarding** | สร้างผู้ใช้ใหม่ด้วยรหัสชั่วคราว | ข้อมูลบันทึกลง `auth.users` + `user_roles` และแสดง Onboarding Modal | สร้างสำเร็จ และ Modal สรุปผลแสดงถูกต้อง | **PASS** |
| **3. Dispatch Actions** | กดปุ่มคัดลอกข้อความ และปุ่มเปิดอีเมล | คัดลอกลง Clipboard และเปิด Client อีเมลพร้อมร่างข้อความ | ข้อความถูกคัดลอก และ Mailto ทำงานสมบูรณ์ | **PASS** |
| **4. First-Login Interception** | ล็อกอินด้วยบัญชีใหม่ | ระบบล็อกหน้าจอและแสดงหน้าต่างบังคับเปลี่ยนรหัสผ่าน NIST | หน้าต่าง Modal ปรากฏและล็อกการเข้าถึง | **PASS** |
| **5. NIST Password Validation** | ทดสอบรหัสผ่าน: <br>a) `12345` (สั้น)<br>b) `password` (คำทั่วไป)<br>c) `somchai1234` (มีชื่อ)<br>d) `SmartCAD#2026!Pass` (ถูกต้อง) | a) แจ้งเตือนความยาว < 8<br>b) แจ้งเตือนคำง่ายเกินไป<br>c) แจ้งเตือนมีชื่อปะปน<br>d) ผ่านเกณฑ์ แถบสีเขียว | ตรวจสอบและแสดงผล Checklist ตามเงื่อนไขทุกข้อ | **PASS** |
| **6. Password Update RPC** | บันทึกรหัสผ่านใหม่ที่ผ่านเกณฑ์ | รหัสผ่านใน `auth.users` อัปเดต และ `must_change_password` กลายเป็น `false` | เปลี่ยนรหัสผ่านสำเร็จ และเข้าสู่ระบบได้ปกติ | **PASS** |
| **7. Self-Protection Guard** | ตรวจสอบปุ่มลบ/บล็อกในแถวของบัญชีตนเอง | ปุ่มลบและบล็อกถูกซ่อน/ปิดการใช้งาน พร้อมแสดงป้าย `(บัญชีปัจจุบัน)` | ไม่สามารถลบหรือบล็อกบัญชีตนเองได้ | **PASS** |

---

## 5. สรุปรายการไฟล์และเอกสารที่มีการอัปเดต (Changed Files Inventory)

1. [`database/admin_rpc_fix.sql`](../database/admin_rpc_fix.sql) — สคริปต์ SQL Migration สำหรับคอลัมน์และ RPC ใหม่
2. [`database/schema.sql`](../database/schema.sql) — ซิงค์ Master Schema พร้อมฟังก์ชัน NIST
3. [`js/auth.js`](../js/auth.js) — เพิ่ม NIST Password Engine, Validator, Interceptor และ RPC Bridge
4. [`users.html`](../users.html) — ปรับปรุง UI จัดการผู้ใช้, Onboarding Modal, ปุ่มสุ่มรหัส และป้ายสถานะ
5. [`css/style.css`](../css/style.css) — เพิ่มสไตล์ `.status-pill-pending`, NIST Strength Gauge, และ Responsive Design
6. `index.html`, `dashboard.html`, `inventory.html`, `report.html`, `upload.html` — อัปเดต Asset Version เป็น `?v=8`
7. [`research_docs/Chapter_3_Methodology.md`](Chapter_3_Methodology.md) — เพิ่มเนื้อหาหัวข้อ 3.2.1 และ 3.6
8. [`research_docs/Chapter_4_Results.md`](Chapter_4_Results.md) — เพิ่มเนื้อหาหัวข้อ 4.1.2 และตารางประเมินผล 4.5
9. [`research_docs/References_APA.md`](References_APA.md) — เพิ่มเอกสารอ้างอิงมาตรฐาน NIST SP 800-63B (APA 7th Edition)

---

## 6. ข้อเสนอแนะสำหรับการปฏิบัติงาน (Operational Recommendations)

1. **การรันสคริปต์ SQL:** ให้ผู้ดูแลระบบคัดลอกสคริปต์จาก [`database/admin_rpc_fix.sql`](../database/admin_rpc_fix.sql) ไปรันใน Supabase SQL Editor เพื่อสร้างคอลัมน์และ Function บน Production Database
2. **การส่งมอบรหัสผ่าน:** แนะนำให้ผู้ดูแลระบบส่งข้อมูลผ่านช่องทางสนทนาที่เป็นทางการ (Official Internal Channels) เช่น CMU Mail หรือ MS Teams
3. **การรีเซ็ตรหัสผ่านกรณีผู้ใช้ลืม:** สามารถใช้ปุ่ม **`🔑 รีเซ็ต`** ในหน้าจัดการผู้ใช้ ซึ่งจะสร้างรหัสผ่านชั่วคราวใหม่และกำหนดให้ผู้ใช้ต้องเปลี่ยนรหัสผ่านอีกครั้งเมื่อล็อกอิน
