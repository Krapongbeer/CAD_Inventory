// ============================================================
// excel-parser.js — Excel File Parser (SheetJS)
// ============================================================

/**
 * Parse Excel file → Array of asset objects
 * รองรับโครงสร้างไฟล์ "ครุภัณฑ์ คอมพิวเตอร์ (ไฟล์กองคลัง).xlsx"
 */
async function parseExcelFile(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();

    reader.onload = (e) => {
      try {
        const data = new Uint8Array(e.target.result);
        const workbook = XLSX.read(data, { type: 'array', cellDates: true });

        // หา sheet ข้อมูลหลัก (sheet แรก หรือชื่อ "ข้อมูลครุภัณฑ์")
        let sheetName = workbook.SheetNames[0];
        for (const name of workbook.SheetNames) {
          if (name.includes('ข้อมูลครุภัณฑ์') || name.includes('ครุภัณฑ์')) {
            sheetName = name;
            break;
          }
        }

        const sheet = workbook.Sheets[sheetName];
        const rawRows = XLSX.utils.sheet_to_json(sheet, {
          header: 1,
          defval: null,
          raw: false
        });

        // หา header row (row แรกที่มี "คีย์สินทรัพย์" หรือ "วันที่")
        let dataStartRow = 0;
        for (let i = 0; i < Math.min(10, rawRows.length); i++) {
          const row = rawRows[i];
          if (row && row.some(cell => cell && (
            String(cell).includes('คีย์สินทรัพย์') ||
            String(cell).includes('วันที่ขึ้นทะเบียน')
          ))) {
            dataStartRow = i + 1;
            break;
          }
        }

        // Map column positions dynamically based on header
        const headerRow = rawRows[dataStartRow - 1] || [];
        const colMap = detectColumns(headerRow, rawRows);

        const assets = [];
        let skipped = 0;

        for (let i = dataStartRow; i < rawRows.length; i++) {
          const row = rawRows[i];
          if (!row || !row[colMap.id]) { skipped++; continue; }

          const id = parseInt(row[colMap.id]);
          if (isNaN(id)) { skipped++; continue; }

          const asset = {
            // pk จะถูก auto-generate โดย Supabase (BIGSERIAL)
            id,                                                    // ID จากไฟล์ Excel (ข้อมูล)
            asset_key:       cleanStr(row[colMap.asset_key]),
            registered_date: parseDate(row[colMap.registered_date]),
            cost:            parseNum(row[colMap.cost]),
            description_sys: cleanStr(row[colMap.description_sys]),
            name:            cleanStr(row[colMap.name]) || 'ไม่ระบุชื่อ',
            detail:          cleanStr(row[colMap.detail]),
            brand:           cleanStr(row[colMap.brand]),
            model:           cleanStr(row[colMap.model]),
            serial_number:   cleanStr(row[colMap.serial_number]),
            warranty_years:  parseNum(row[colMap.warranty_years]),
            department:      cleanStr(row[colMap.department]),
            condition:       cleanStr(row[colMap.condition]),
            building:        cleanStr(row[colMap.building]),
            floor:           cleanStr(row[colMap.floor]),
            room:            cleanStr(row[colMap.room]),
            storage_detail:  cleanStr(row[colMap.storage_detail]),
            owner:           cleanStr(row[colMap.owner]),
            assignee:        cleanStr(row[colMap.assignee]),
            note:            cleanStr(row[colMap.note])
          };

          assets.push(asset);
        }

        resolve({
          assets,
          totalRows: assets.length,
          skipped,
          sheetName
        });
      } catch (err) {
        reject(new Error('ไม่สามารถอ่านไฟล์ Excel ได้: ' + err.message));
      }
    };

    reader.onerror = () => reject(new Error('ไม่สามารถอ่านไฟล์ได้'));
    reader.readAsArrayBuffer(file);
  });
}

/**
 * Detect column positions from header rows
 * รองรับทั้งโครงสร้าง merge cell และ single header
 */
function detectColumns(headerRow, allRows) {
  // Default column map สำหรับไฟล์มาตรฐาน
  // (อ้างอิงจากโครงสร้างไฟล์ที่วิเคราะห์)
  const defaultMap = {
    id: 0,
    asset_key: 1,
    registered_date: 2,
    cost: 3,
    description_sys: 4,
    name: 5,
    detail: 6,
    brand: 7,
    model: 8,
    serial_number: 9,
    warranty_years: 10,
    department: 11,
    condition: 12,
    building: 13,
    floor: 14,
    room: 15,
    storage_detail: 16,
    owner: 17,
    assignee: 18,
    note: 19
  };

  // พยายาม detect จาก header
  const keywords = {
    id: ['id', 'ลำดับ', 'running', 'no.'],
    asset_key: ['คีย์', 'key', 'รหัส'],
    registered_date: ['วันที่', 'date', 'ขึ้นทะเบียน'],
    cost: ['ราคา', 'cost', 'มูลค่า'],
    name: ['ชื่อ', 'name'],
    department: ['งาน', 'หน่วยงาน', 'department'],
    condition: ['สภาพ', 'condition'],
    building: ['อาคาร', 'building'],
    owner: ['ผู้ครอบครอง', 'owner'],
    assignee: ['ผู้ที่ได้รับ', 'assignee', 'ดูแล']
  };

  const map = { ...defaultMap };

  // Scan all header rows (rows 0-4)
  for (let ri = 0; ri < Math.min(5, allRows.length); ri++) {
    const row = allRows[ri];
    if (!row) continue;
    row.forEach((cell, ci) => {
      if (!cell) return;
      const cellStr = String(cell).toLowerCase();
      for (const [key, kws] of Object.entries(keywords)) {
        if (kws.some(kw => cellStr.includes(kw))) {
          // EXCLUSION GUARD: Prevent "ชื่อ" keyword from matching building, owner, assignee, or other columns
          if (key === 'name') {
            if (cellStr.includes('อาคาร') || cellStr.includes('ผู้') || cellStr.includes('บัญชี') || cellStr.includes('ชั้น') || cellStr.includes('ห้อง') || cellStr.includes('แก้ไข') || cellStr.includes('จัดเก็บ') || cellStr.includes('ที่อยู่')) {
              continue;
            }
          }
          map[key] = ci;
        }
      }
    });
  }

  return map;
}

// ---- Helpers ----

function cleanStr(val) {
  if (val === null || val === undefined) return null;
  const s = String(val).replace(/[\u202d\u202c\u200b]/g, '').trim();
  return s || null;
}

function parseDate(val) {
  if (!val) return null;
  try {
    const s = String(val).replace(/[\u202d\u202c]/g, '').trim();
    // DD-MM-YY or DD-MM-YYYY
    const parts = s.split('-');
    if (parts.length === 3) {
      let [d, m, y] = parts;
      y = parseInt(y);
      if (y < 100) y += y < 50 ? 2000 : 1900;
      const isoDate = `${y}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
      if (isNaN(new Date(isoDate).getTime())) return null;
      return isoDate;
    }
    // Try ISO
    const d = new Date(s);
    if (!isNaN(d.getTime())) return d.toISOString().split('T')[0];
    return null;
  } catch {
    return null;
  }
}

function parseNum(val) {
  if (val === null || val === undefined || val === '') return null;
  const n = parseFloat(String(val).replace(/,/g, ''));
  return isNaN(n) ? null : n;
}

window.parseExcelFile = parseExcelFile;
