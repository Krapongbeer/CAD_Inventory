// ============================================================
// config.js — Supabase Configuration
// กองบริหารงานกลาง มช.
// ============================================================
// ⚠️ ให้เปลี่ยน SUPABASE_URL และ SUPABASE_ANON_KEY
// ด้วยค่าจาก Supabase Project ของคุณ
// Settings > API > Project URL และ anon/public key
// ============================================================

const SUPABASE_URL = 'https://undafgcijvuhvdmyjatk.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_WGFEQiopY91Fxi5o_-McKw_iwTRS5yn';

// Initialize Supabase client
const dbClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: true
  }
});

// ============================================================
// มาตรฐานการจำแนกประเภทและหมวดหมู่ครุภัณฑ์ (กรมบัญชีกลาง กระทรวงการคลัง)
// ============================================================
const CGD_CATEGORIES = {
  computer: {
    id: 'computer',
    label: 'ครุภัณฑ์คอมพิวเตอร์และสารสนเทศ',
    shortLabel: 'คอมพิวเตอร์และ IT',
    icon: '💻',
    color: '#3b82f6',
    bg: 'rgba(59, 130, 246, 0.12)',
    border: 'rgba(59, 130, 246, 0.3)',
    warningYears: 3,
    criticalYears: 5,
    keywords: [
      'คอมพิวเตอร์', 'computer', 'notebook', 'โน้ตบุ๊ก', 'โน๊ตบุ๊ค', 'laptop', 'เซิร์ฟเวอร์', 'server',
      'pc', 'all-in-one', 'ipad', 'แท็บเล็ต', 'tablet', 'printer', 'เครื่องพิมพ์', 'scanner', 'สแกนเนอร์',
      'ups', 'สำรองไฟ', 'switch', 'router', 'access point', 'hub', 'nas', 'จอภาพ', 'monitor', 'ฮาร์ดดิสก์',
      'harddisk', 'storage', 'workstation', 'คอมพิวเตอร์กระเป๋าหิ้ว', 'ประมวลผล', 'คอมฯ'
    ]
  },
  office: {
    id: 'office',
    label: 'ครุภัณฑ์สำนักงานและเฟอร์นิเจอร์',
    shortLabel: 'ครุภัณฑ์สำนักงาน',
    icon: '🪑',
    color: '#f59e0b',
    bg: 'rgba(245, 158, 11, 0.12)',
    border: 'rgba(245, 158, 11, 0.3)',
    warningYears: 8,
    criticalYears: 12,
    keywords: [
      'โต๊ะ', 'เก้าอี้', 'ตู้', 'พาร์ทิชั่น', 'พาทิชั่น', 'บอร์ด', 'ไวท์บอร์ด', 'โซฟา', 'ชั้นวาง',
      'ชั้นเหล็ก', 'ม้านั่ง', 'โพเดียม', 'เคาน์เตอร์', 'กระดาน', 'ตู้เซฟ', 'ตู้ล็อกเกอร์', 'ตู้เหล็ก',
      'ตู้เอกสาร', 'ตู้บานเลื่อน', 'ตู้ลิ้นชัก', 'เก้าอี้ทำงาน', 'เก้าอี้ประชุม', 'โต๊ะทำงาน', 'โต๊ะประชุม',
      'โต๊ะพับ', 'เก้าอี้เลคเชอร์', 'ชุดรับแขก', 'ตู้เก็บ'
    ]
  },
  audio: {
    id: 'audio',
    label: 'ครุภัณฑ์โสตทัศนูปกรณ์และมัลติมีเดีย',
    shortLabel: 'โสตทัศนูปกรณ์',
    icon: '📽️',
    color: '#8b5cf6',
    bg: 'rgba(139, 92, 246, 0.12)',
    border: 'rgba(139, 92, 246, 0.3)',
    warningYears: 5,
    criticalYears: 8,
    keywords: [
      'เครื่องเสียง', 'ไมโครโฟน', 'ไมค์', 'ลำโพง', 'โทรทัศน์', 'ทีวี', 'tv', 'กล้อง', 'camera',
      'โปรเจกเตอร์', 'โปรเจคเตอร์', 'projector', 'จอรับภาพ', 'แอมป์', 'amplifier', 'มิกเซอร์', 'mixer',
      'ขาตั้งกล้อง', 'เครื่องเล่น', 'จอled', 'จอแสดงผล', 'เครื่องขยายเสียง', 'วิทยุ', 'เครื่องบันทึกภาพ',
      'เครื่องฉาย', 'visualizer', 'sound', 'microphone', 'speaker'
    ]
  },
  electrical: {
    id: 'electrical',
    label: 'ครุภัณฑ์ไฟฟ้าและวิทยุ / เครื่องปรับอากาศ',
    shortLabel: 'เครื่องใช้ไฟฟ้า & แอร์',
    icon: '❄️',
    color: '#06b6d4',
    bg: 'rgba(6, 182, 212, 0.12)',
    border: 'rgba(6, 182, 212, 0.3)',
    warningYears: 5,
    criticalYears: 8,
    keywords: [
      'ปรับอากาศ', 'แอร์', 'air', 'พัดลม', 'ตู้เย็น', 'กาต้มน้ำ', 'เครื่องฟอกอากาศ', 'ไมโครเวฟ',
      'เครื่องทำน้ำร้อน', 'เครื่องทำน้ำเย็น', 'เครื่องกดน้ำ', 'เครื่องดูดฝุ่น', 'เครื่องกำเนิดไฟฟ้า',
      'หม้อหุงข้าว', 'เตาอบ', 'เครื่องทำความเย็น', 'ปั๊มน้ำ', 'เครื่องสูบน้ำ', 'เครื่องตัดหญ้า'
    ]
  },
  vehicle: {
    id: 'vehicle',
    label: 'ครุภัณฑ์ยานพาหนะและขนส่ง',
    shortLabel: 'ยานพาหนะและขนส่ง',
    icon: '🚗',
    color: '#10b981',
    bg: 'rgba(16, 185, 129, 0.12)',
    border: 'rgba(16, 185, 129, 0.3)',
    warningYears: 6,
    criticalYears: 10,
    keywords: [
      'รถ', 'ยานพาหนะ', 'vehicle', 'รถยนต์', 'จักรยานยนต์', 'มอเตอร์ไซค์', 'มอเตอร์ไซด์',
      'รถกอล์ฟ', 'รถตู้', 'รถบรรทุก', 'เรือ', 'จักรยาน', 'รถเข็น', 'รถลาก'
    ]
  },
  scientific: {
    id: 'scientific',
    label: 'ครุภัณฑ์การศึกษา วิทยาศาสตร์ และการแพทย์',
    shortLabel: 'วิทยาศาสตร์ & การศึกษา',
    icon: '🔬',
    color: '#ec4899',
    bg: 'rgba(236, 72, 153, 0.12)',
    border: 'rgba(236, 72, 153, 0.3)',
    warningYears: 5,
    criticalYears: 8,
    keywords: [
      'กล้องจุลทรรศน์', 'เครื่องมือวัด', 'ทดลอง', 'แล็บ', 'lab', 'หุ่นจำลอง', 'วิทยาศาสตร์',
      'การแพทย์', 'ชั่ง', 'วัด', 'วิเคราะห์', 'ตู้อบ', 'เครื่องปั่นเหวี่ยง', 'autoclave', 'spectrophotometer'
    ]
  },
  other: {
    id: 'other',
    label: 'ครุภัณฑ์อื่นๆ',
    shortLabel: 'ครุภัณฑ์อื่นๆ',
    icon: '📦',
    color: '#64748b',
    bg: 'rgba(100, 116, 139, 0.12)',
    border: 'rgba(100, 116, 139, 0.3)',
    warningYears: 5,
    criticalYears: 10,
    keywords: []
  }
};

const ASSET_AGE_THRESHOLDS = CGD_CATEGORIES;

/**
 * ระบุหมวดหมู่ครุภัณฑ์ตามมาตรฐานกรมบัญชีกลาง
 * @param {string} assetName - ชื่อครุภัณฑ์
 * @param {string} assetDetail - รายละเอียดครุภัณฑ์
 * @param {string} assetBrand - ยี่ห้อ
 * @returns {object} Category metadata object
 */
function getAssetCategory(assetName, assetDetail = '', assetBrand = '') {
  const combinedText = `${assetName || ''} ${assetDetail || ''} ${assetBrand || ''}`.toLowerCase();

  for (const [key, cat] of Object.entries(CGD_CATEGORIES)) {
    if (key === 'other') continue;
    if (cat.keywords.some(kw => combinedText.includes(kw.toLowerCase()))) {
      return cat;
    }
  }

  return CGD_CATEGORIES.other;
}

/**
 * คำนวณอายุการใช้งานและ status
 * @param {string} registeredDate - วันที่ขึ้นทะเบียน (DD-MM-YY หรือ ISO)
 * @param {string} assetName - ชื่อครุภัณฑ์
 * @param {string} assetId - รหัสครุภัณฑ์
 * @returns {{ ageYears: number, status: 'normal'|'warning'|'critical'|'unknown', label: string, category: object, threshold: object }}
 */
function getAssetAgeStatus(registeredDate, assetName, assetId, assetDetail = '', assetBrand = '') {
  let date = null;

  // 1. ลองแปลงจากวันที่ขึ้นทะเบียน (ถ้ามี)
  if (registeredDate) {
    try {
      const cleaned = registeredDate.toString().replace(/[\u202d\u202c]/g, '').trim();
      const parts = cleaned.split('-');
      if (parts.length === 3) {
        let year, month, day;
        if (parts[0].length >= 4) {
          // YYYY-MM-DD (e.g. from database)
          year = parseInt(parts[0]);
          month = parseInt(parts[1]);
          day = parseInt(parts[2]);
        } else {
          // DD-MM-YYYY (e.g. raw from Excel string)
          day = parseInt(parts[0]);
          month = parseInt(parts[1]);
          year = parseInt(parts[2]);
        }
        
        if (year < 100) year += year < 50 ? 2000 : 1900;
        if (year > 2400) year -= 543; // แปลง พ.ศ. เป็น ค.ศ.
        date = new Date(year, month - 1, day);
      } else {
        const d = new Date(cleaned);
        if (d.getFullYear() > 2400) {
          d.setFullYear(d.getFullYear() - 543);
        }
        date = d;
      }
      if (isNaN(date.getTime())) date = null;
    } catch {
      date = null;
    }
  }

  // 2. ถ้าไม่มีวันที่ หรือแปลงไม่ได้ ให้ลองดึงจาก รหัสครุภัณฑ์ (เช่น .ร60 = ปี 2560)
  if (!date && assetId) {
    const match = assetId.toString().match(/\.ร(\d{2})/);
    if (match) {
      const thaiYearStr = match[1]; // e.g. "60"
      const thaiYear = 2500 + parseInt(thaiYearStr, 10); // 2560
      const adYear = thaiYear - 543; // 2017
      date = new Date(adYear, 0, 1);
    }
  }

  const category = getAssetCategory(assetName, assetDetail, assetBrand);
  const threshold = category;

  if (!date) {
    return { ageYears: 0, status: 'unknown', label: 'ไม่ทราบ', category, threshold };
  }

  const now = new Date();
  const ageMs = now.getTime() - date.getTime();
  let ageYears = ageMs / (1000 * 60 * 60 * 24 * 365.25);
  if (ageYears < 0) ageYears = 0;

  let status, label;
  if (ageYears >= threshold.criticalYears) {
    status = 'critical';
    label = `${Math.floor(ageYears)} ปี (เกินกำหนด)`;
  } else if (ageYears >= threshold.warningYears) {
    status = 'warning';
    label = `${Math.floor(ageYears)} ปี (ใกล้ครบกำหนด)`;
  } else {
    status = 'normal';
    label = `${Math.floor(ageYears)} ปี`;
  }

  return { ageYears: Math.round(ageYears * 10) / 10, status, label, category, threshold };
}

window.CAD = {
  supabase: dbClient,
  SUPABASE_URL,
  getAssetAgeStatus,
  getAssetCategory,
  CGD_CATEGORIES,
  ASSET_AGE_THRESHOLDS
};
