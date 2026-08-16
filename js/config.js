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
// เกณฑ์อายุการใช้งานครุภัณฑ์ (กรมบัญชีกลาง)
// ============================================================
const ASSET_AGE_THRESHOLDS = {
  // คอมพิวเตอร์และอุปกรณ์ IT
  computer: {
    keywords: ['คอมพิวเตอร์', 'notebook', 'โน๊ตบุ๊ค', 'laptop', 'เครื่องพิมพ์', 'printer', 'scanner', 'สแกนเนอร์', 'ups', 'สำรองไฟ', 'โปรเจกเตอร์', 'projector'],
    warningYears: 3,
    criticalYears: 5
  },
  // เครื่องเสียงและโสตทัศนูปกรณ์
  audio: {
    keywords: ['เครื่องเสียง', 'ไมโครโฟน', 'ลำโพง', 'จอ', 'monitor', 'โทรทัศน์', 'กล้อง'],
    warningYears: 5,
    criticalYears: 10
  },
  // เครื่องใช้สำนักงานทั่วไป
  office: {
    keywords: ['โต๊ะ', 'เก้าอี้', 'ตู้', 'พาร์ทิชั่น', 'พาทิชั่น', 'บอร์ด'],
    warningYears: 7,
    criticalYears: 12
  },
  // เครื่องใช้ไฟฟ้า
  electrical: {
    keywords: ['ปรับอากาศ', 'พัดลม', 'ตู้เย็น', 'กาต้มน้ำ', 'เครื่องฟอกอากาศ', 'ไมโครเวฟ'],
    warningYears: 5,
    criticalYears: 10
  },
  // ทั่วไป (default)
  general: {
    keywords: [],
    warningYears: 5,
    criticalYears: 10
  }
};

/**
 * คำนวณอายุการใช้งานและ status
 * @param {string} registeredDate - วันที่ขึ้นทะเบียน (DD-MM-YY หรือ ISO)
 * @param {string} assetName - ชื่อครุภัณฑ์
 * @returns {{ ageYears: number, status: 'normal'|'warning'|'critical', label: string }}
 */
function getAssetAgeStatus(registeredDate, assetName, assetId) {
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
        // บางครั้ง Excel ส่งมาเป็น string ธรรมดา
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
    const match = assetId.match(/\.ร(\d{2})/);
    if (match) {
      const thaiYearStr = match[1]; // e.g. "60"
      const thaiYear = 2500 + parseInt(thaiYearStr, 10); // 2560
      const adYear = thaiYear - 543; // 2017
      // สมมติให้เป็นวันที่ 1 มกราคม ของปีนั้น
      date = new Date(adYear, 0, 1);
    }
  }

  // 3. ถ้าหาจากทั้งสองอย่างไม่ได้เลย ให้ตีเป็น ไม่ทราบ
  if (!date) {
    return { ageYears: 0, status: 'unknown', label: 'ไม่ทราบ' };
  }

  const now = new Date();
  const ageMs = now.getTime() - date.getTime();
  let ageYears = ageMs / (1000 * 60 * 60 * 24 * 365.25);
  if (ageYears < 0) ageYears = 0;

  // หาประเภทครุภัณฑ์
  const nameLower = (assetName || '').toLowerCase();
  let threshold = ASSET_AGE_THRESHOLDS.general;

  for (const [, config] of Object.entries(ASSET_AGE_THRESHOLDS)) {
    if (config.keywords.some(kw => nameLower.includes(kw.toLowerCase()))) {
      threshold = config;
      break;
    }
  }

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

  return { ageYears: Math.round(ageYears * 10) / 10, status, label, threshold };
}

window.CAD = {
  supabase: dbClient,
  SUPABASE_URL,
  getAssetAgeStatus,
  ASSET_AGE_THRESHOLDS
};
