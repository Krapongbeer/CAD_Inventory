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
function getAssetAgeStatus(registeredDate, assetName) {
  if (!registeredDate) return { ageYears: 0, status: 'unknown', label: 'ไม่ทราบ' };

  // แปลงวันที่
  let date;
  try {
    const cleaned = registeredDate.toString().replace(/[\u202d\u202c]/g, '').trim();
    const parts = cleaned.split('-');
    if (parts.length === 3) {
      let [day, month, year] = parts;
      year = parseInt(year);
      if (year < 100) year += year < 50 ? 2000 : 1900;
      date = new Date(year, parseInt(month) - 1, parseInt(day));
    } else {
      date = new Date(cleaned);
    }
  } catch {
    return { ageYears: 0, status: 'unknown', label: 'ไม่ทราบ' };
  }

  const ageMs = Date.now() - date.getTime();
  const ageYears = ageMs / (1000 * 60 * 60 * 24 * 365.25);

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
