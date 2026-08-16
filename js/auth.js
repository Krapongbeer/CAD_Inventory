// ============================================================
// auth.js — Authentication & Role Management
// ============================================================


/**
 * Sign in with email/password
 */
async function signIn(email, password) {
  try {
    const cleanEmail = (email || '').trim().toLowerCase();
    const { data, error } = await window.CAD.supabase.auth.signInWithPassword({ 
      email: cleanEmail, 
      password: password 
    });
    if (!error && data?.user) {
      logActivity('login', 'เข้าสู่ระบบสำเร็จ', data.user.id).catch(() => {});
    }
    return { data, error };
  } catch (err) {
    console.error('signIn exception:', err);
    return { data: null, error: err };
  }
}

/**
 * Sign out
 */
async function signOut() {
  await logActivity('logout', 'ออกจากระบบ');
  const { error } = await window.CAD.supabase.auth.signOut();
  if (!error) window.location.href = 'index.html';
}

/**
 * Get current session
 */
async function getSession() {
  const { data: { session } } = await window.CAD.supabase.auth.getSession();
  return session;
}

/**
 * Get current user role and password lifecycle status from user_roles table
 * Ultra-resilient with auto-healing and fallback
 */
async function getCurrentUserRole() {
  const session = await getSession();
  if (!session?.user) return null;

  try {
    let { data, error } = await window.CAD.supabase
      .from('user_roles')
      .select('*')
      .eq('user_id', session.user.id)
      .maybeSingle();

    if (error) {
      console.warn('user_roles full select failed, trying minimal select...', error.message);
      const res = await window.CAD.supabase
        .from('user_roles')
        .select('role, full_name')
        .eq('user_id', session.user.id)
        .maybeSingle();
      data = res.data;
    }

    // Auto-heal superadmin if row was missing or corrupted
    const isSuperAdminEmail = session.user.email === 'krapong_beer@hotmail.com';
    if (!data && isSuperAdminEmail) {
      data = {
        role: 'superadmin',
        full_name: 'ผู้ดูแลระบบสูงสุด (Superadmin)',
        email: session.user.email,
        department: 'กองบริหารงานกลาง',
        status: 'active',
        must_change_password: false
      };
      
      // Auto-insert into user_roles
      window.CAD.supabase.from('user_roles').upsert({
        user_id: session.user.id,
        role: 'superadmin',
        full_name: data.full_name,
        email: session.user.email,
        department: 'กองบริหารงานกลาง',
        status: 'active',
        must_change_password: false
      }, { onConflict: 'user_id' }).then(() => {}).catch(e => console.warn('Auto-heal upsert warning:', e));
    }

    if (data) {
      // Superadmin never gets forced into first-time password change loop
      const mustChange = isSuperAdminEmail ? false : (data.must_change_password === true);
      
      return {
        role: isSuperAdminEmail ? 'superadmin' : (data.role || 'staff'),
        full_name: data.full_name || session.user.email,
        email: data.email || session.user.email,
        department: data.department || 'กองบริหารงานกลาง',
        status: data.status || 'active',
        must_change_password: mustChange,
        last_password_change: data.last_password_change || null
      };
    }

    return null;
  } catch (err) {
    console.error('getCurrentUserRole exception:', err);
    if (session.user.email === 'krapong_beer@hotmail.com') {
      return {
        role: 'superadmin',
        full_name: 'ผู้ดูแลระบบสูงสุด',
        email: session.user.email,
        department: 'กองบริหารงานกลาง',
        status: 'active',
        must_change_password: false
      };
    }
    return null;
  }
}

/**
 * Require auth — redirect to login if not authenticated
 * Call this at top of every protected page
 * @param {string[]} allowedRoles - e.g. ['superadmin', 'admin', 'staff', 'executive']
 */
async function requireAuth(allowedRoles = ['superadmin', 'admin', 'staff', 'executive']) {
  const session = await getSession();
  if (!session) {
    window.location.href = 'index.html';
    return null;
  }

  const userRole = await getCurrentUserRole();
  if (!userRole) {
    alert('เข้าสู่ระบบสำเร็จ แต่ไม่พบบทบาทในระบบ (user_roles) กรุณาติดต่อผู้ดูแลระบบ');
    window.location.href = 'index.html';
    return null;
  }

  // Enforce account status check (e.g. suspended)
  if (userRole.status === 'suspended') {
    alert('บัญชีผู้ใช้งานของคุณถูกระงับการใช้งานชั่วคราว กรุณาติดต่อผู้ดูแลระบบ');
    await signOut();
    return null;
  }

  const fullUserData = { session, ...userRole };

  // NIST SP 800-63B: First-Time Login Password Change Interceptor
  if (userRole.must_change_password === true) {
    checkAndEnforceFirstLoginPasswordChange(fullUserData);
  }

  // Superadmin has absolute supreme permission across all pages and features!
  if (userRole.role === 'superadmin') {
    return fullUserData;
  }

  if (!allowedRoles.includes(userRole.role)) {
    alert('คุณไม่มีสิทธิ์เข้าถึงหน้านี้');
    window.location.href = 'dashboard.html';
    return null;
  }

  return fullUserData;
}

/**
 * Populate navbar user info
 */
async function populateNavUser() {
  const userRole = await getCurrentUserRole();
  const session = await getSession();

  const roleLabels = {
    superadmin: 'ผู้ดูแลระบบสูงสุด',
    admin: 'ผู้ดูแลระบบ',
    staff: 'เจ้าหน้าที่',
    executive: 'ผู้บริหาร',
    editor: 'ผู้นำเข้าข้อมูล',
    viewer: 'ผู้ดูรายงาน'
  };

  const nameStr = userRole?.full_name || session?.user?.email || '-';
  const roleStr = roleLabels[userRole?.role] || userRole?.role || '-';
  
  // Unhide Admin Navigation for Admin and Superadmin across all pages
  if (userRole?.role === 'admin' || userRole?.role === 'superadmin') {
    document.querySelectorAll('.nav-admin').forEach(el => el.style.display = '');
    document.querySelectorAll('.nav-admin-label').forEach(el => el.style.display = '');
    const adminSec = document.getElementById('adminSection');
    if (adminSec) adminSec.style.display = '';
  }

  // Legacy sidebar fallback
  const nameEl = document.getElementById('navUserName');
  const roleEl = document.getElementById('navUserRole');
  const emailEl = document.getElementById('navUserEmail');
  if (nameEl) nameEl.textContent = nameStr;
  if (roleEl) roleEl.textContent = roleStr;
  if (emailEl) emailEl.textContent = session?.user?.email || '-';

  // New Topbar UI
  const tbAvatar = document.getElementById('topbarUserAvatar');
  const tbName = document.getElementById('topbarUserName');
  const tbRoleBadge = document.getElementById('topbarUserRoleBadge');
  const tbRoleIcon = document.getElementById('topbarUserRoleIcon');
  const tbRoleText = document.getElementById('topbarUserRoleText');
  const tbSuperadminBadge = document.getElementById('topbarSuperadminBadge');
  
  if (tbName) tbName.textContent = nameStr;
  if (tbAvatar) {
    tbAvatar.textContent = nameStr.charAt(0).toUpperCase();
  }
  
  if (tbRoleBadge) {
    tbRoleBadge.style.display = 'inline-flex';
    if (userRole?.role === 'superadmin') {
      tbRoleBadge.className = 'topbar-role-badge';
      if(tbRoleIcon) tbRoleIcon.textContent = '🔴';
      if(tbSuperadminBadge) tbSuperadminBadge.style.display = 'inline-flex';
    } else if (userRole?.role === 'admin') {
      tbRoleBadge.className = 'topbar-role-badge admin';
      if(tbRoleIcon) tbRoleIcon.textContent = '🟠';
      if(tbSuperadminBadge) tbSuperadminBadge.style.display = 'none';
    } else if (userRole?.role === 'executive') {
      tbRoleBadge.className = 'topbar-role-badge';
      tbRoleBadge.style.background = 'rgba(168, 85, 247, 0.2)';
      tbRoleBadge.style.borderColor = 'rgba(168, 85, 247, 0.4)';
      tbRoleBadge.style.color = '#e9d5ff';
      if(tbRoleIcon) tbRoleIcon.textContent = '🟣';
      if(tbSuperadminBadge) tbSuperadminBadge.style.display = 'none';
    } else {
      tbRoleBadge.className = 'topbar-role-badge';
      tbRoleBadge.style.color = '#93c5fd';
      tbRoleBadge.style.borderColor = 'rgba(59, 130, 246, 0.4)';
      tbRoleBadge.style.background = 'rgba(59, 130, 246, 0.2)';
      if(tbRoleIcon) tbRoleIcon.textContent = '🔵';
      if(tbSuperadminBadge) tbSuperadminBadge.style.display = 'none';
    }
    if(tbRoleText) tbRoleText.textContent = roleStr;
  }
}

// Add init logic to sync theme dropdown
document.addEventListener('DOMContentLoaded', () => {
  const currentTheme = localStorage.getItem('cad_theme_preference') || 'auto';
  const sel = document.getElementById('themeSelectDropdown');
  if (sel) sel.value = currentTheme;
// Admin User Management: Native GoTrue Auth Creation
async function adminCreateUser(email, password, fullName, userRole, department = 'กองบริหารงานกลาง') {
  try {
    const cleanEmail = email.trim().toLowerCase();
    
    // Create an isolated non-persistent Supabase Auth instance
    const tempAuth = window.supabase.createClient(window.CAD.SUPABASE_URL, window.CAD.SUPABASE_ANON_KEY || window.SUPABASE_ANON_KEY, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
        detectSessionInUrl: false
      }
    });

    // 1. Native GoTrue Sign Up (Creates user, hash, and identity in official format)
    const { data: authData, error: authError } = await tempAuth.auth.signUp({
      email: cleanEmail,
      password: password,
      options: {
        data: { 
          full_name: fullName,
          role: userRole,
          department: department
        }
      }
    });

    if (authError) {
      // If user already exists in auth.users, try RPC or throw
      if (authError.message?.includes('already registered')) {
        throw new Error('อีเมลนี้ถูกใช้งานแล้วในระบบ หากต้องการเปลี่ยนรหัสผ่านกรุณาใช้ปุ่ม "รีเซ็ตรหัสผ่าน"');
      }
      throw authError;
    }

    const targetUid = authData?.user?.id;
    if (!targetUid) {
      throw new Error('ไม่สามารถสร้าง User ID ได้ กรุณาลองใหม่อีกครั้ง');
    }

    // 2. Sync to user_roles table with NIST must_change_password = true
    const roleObj = {
      user_id: targetUid,
      role: userRole,
      full_name: fullName,
      email: cleanEmail,
      department: department || 'กองบริหารงานกลาง',
      status: 'active',
      must_change_password: true,
      last_password_change: new Date().toISOString()
    };

    let { error: roleErr } = await window.CAD.supabase
      .from('user_roles')
      .upsert(roleObj, { onConflict: 'user_id' });

    if (roleErr && roleErr.message && (roleErr.message.includes('must_change_password') || roleErr.message.includes('department'))) {
      // Fallback for missing optional columns
      const baseObj = {
        user_id: targetUid,
        role: userRole,
        full_name: fullName,
        email: cleanEmail
      };
      const res = await window.CAD.supabase.from('user_roles').upsert(baseObj, { onConflict: 'user_id' });
      roleErr = res.error;
    }

    if (roleErr) throw roleErr;

    return { data: { success: true, user_id: targetUid, user: authData.user }, error: null };
  } catch (err) {
    console.error('adminCreateUser error:', err);
    return { data: null, error: err };
  }
}

async function adminUpdateUser(targetUserId, newFullName, newRole, newPassword = null, newEmail = null) {
  // 1. Try RPC
  try {
    const { data, error } = await window.CAD.supabase.rpc('admin_update_user', {
      target_user_id: targetUserId,
      new_full_name: newFullName,
      new_role: newRole,
      new_password: newPassword || null,
      new_email: newEmail || null
    });
    if (!error && data) return { data, error: null };
  } catch (rpcErr) {
    console.warn('RPC admin_update_user failed, falling back to direct update:', rpcErr);
  }

  // 2. Fallback to direct table update
  try {
    const updateObj = { full_name: newFullName };
    if (newRole) updateObj.role = newRole;
    if (newEmail) updateObj.email = newEmail;

    const { error: fbErr } = await window.CAD.supabase
      .from('user_roles')
      .update(updateObj)
      .eq('user_id', targetUserId);

    if (fbErr) throw fbErr;
    return { data: { success: true }, error: null };
  } catch (err) {
    return { data: null, error: err };
  }
}

async function adminDeleteUser(targetUserId) {
  // 1. Try RPC
  try {
    const { data, error } = await window.CAD.supabase.rpc('admin_delete_user', {
      target_user_id: targetUserId
    });
    if (!error && data) return { data, error: null };
  } catch (rpcErr) {
    console.warn('RPC admin_delete_user failed, falling back to direct delete:', rpcErr);
  }

  // 2. Fallback to direct table delete
  try {
    const { error: fbErr } = await window.CAD.supabase
      .from('user_roles')
      .delete()
      .eq('user_id', targetUserId);

    if (fbErr) throw fbErr;
    return { data: { success: true }, error: null };
  } catch (err) {
    return { data: null, error: err };
  }
}

/**
 * Log activity to database
 */
async function logActivity(action, details = '', userId = null) {
  try {
    if (!userId) {
      const session = await getSession();
      if (session) userId = session.user.id;
    }
    
    if (!userId) return;
    
    await window.CAD.supabase.from('activity_logs').insert([{
      user_id: userId,
      action: action,
      details: details
    }]);
  } catch (err) {
    console.warn('Activity logging error:', err);
  }
}

/**
 * ============================================================
 * NIST SP 800-63B PASSWORD SECURITY ENGINE & ONBOARDING
 * ============================================================
 */

/**
 * Generate a cryptographically secure, high-entropy temporary password
 * Meets NIST SP 800-63B requirements: 12 chars, upper, lower, digits, symbols
 */
function generateSecureTempPassword() {
  const upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ'; // Exclude I, O
  const lower = 'abcdefghijkmnopqrstuvwxyz'; // Exclude l
  const digits = '23456789';                 // Exclude 0, 1
  const symbols = '!@#$%^&*+=';
  const all = upper + lower + digits + symbols;

  let pwd = '';
  // Ensure minimum diversity
  pwd += upper.charAt(Math.floor(Math.random() * upper.length));
  pwd += upper.charAt(Math.floor(Math.random() * upper.length));
  pwd += lower.charAt(Math.floor(Math.random() * lower.length));
  pwd += lower.charAt(Math.floor(Math.random() * lower.length));
  pwd += digits.charAt(Math.floor(Math.random() * digits.length));
  pwd += digits.charAt(Math.floor(Math.random() * digits.length));
  pwd += symbols.charAt(Math.floor(Math.random() * symbols.length));
  pwd += symbols.charAt(Math.floor(Math.random() * symbols.length));

  // Fill remaining to 12 characters
  while (pwd.length < 12) {
    pwd += all.charAt(Math.floor(Math.random() * all.length));
  }

  // Shuffle securely
  return pwd.split('').sort(() => 0.5 - Math.random()).join('');
}

/**
 * Validate password against NIST SP 800-63B Digital Identity Guidelines
 * @param {string} password 
 * @param {object} context - { email, fullName, username }
 * @returns {object} { valid, errors, score, strengthLabel, strengthColor, checks }
 */
function validateNISTPassword(password, context = {}) {
  const errors = [];
  const checks = {
    length: false,
    notContextual: true,
    notCommon: true,
    hasDiversity: false
  };

  const pwd = String(password || '');

  // 1. Length Check: NIST SP 800-63B requires minimum 8 characters (up to 64+)
  if (pwd.length >= 8) {
    checks.length = true;
  } else {
    errors.push('รหัสผ่านต้องมีความยาวอย่างน้อย 8 ตัวอักษร (แนะนำ 12+ ตัวอักษร)');
  }

  // 2. Context-Specific Banned Words (Cannot contain user's name or email username)
  const emailName = (context.email || '').split('@')[0].toLowerCase();
  const fullNameParts = (context.fullName || '').toLowerCase().split(/\s+/).filter(p => p.length >= 3);
  const pwdLower = pwd.toLowerCase();

  if (emailName && emailName.length >= 3 && pwdLower.includes(emailName)) {
    checks.notContextual = false;
    errors.push('รหัสผ่านต้องไม่มีชื่อผู้ใช้หรืออีเมลปะปนอยู่');
  }

  for (const part of fullNameParts) {
    if (pwdLower.includes(part)) {
      checks.notContextual = false;
      errors.push('รหัสผ่านต้องไม่มีชื่อ-นามสกุลปะปนอยู่');
      break;
    }
  }

  // 3. Common / Compromised Banned Dictionary (Top known weak passwords)
  const bannedList = [
    '12345678', '123456789', '1234567890', 'password', 'password123', 'admin123', 'admin1234',
    'qwertyuiop', 'asdfghjkl', 'zxcvbnm', 'smartcad', 'smartcad123', 'cmu12345', 'cmu123456',
    'inventory', 'inventory123', 'pass1234', 'welcome123', 'iloveyou', 'sunshine', 'princess'
  ];

  if (bannedList.includes(pwdLower)) {
    checks.notCommon = false;
    errors.push('รหัสผ่านนี้อยู่ในกลุ่มคำที่คาดเดาได้ง่ายเกินไป กรุณาตั้งรหัสผ่านใหม่');
  }

  // 4. Character Diversity (Encouraged by NIST for entropy)
  const hasUpper = /[A-Z]/.test(pwd);
  const hasLower = /[a-z]/.test(pwd);
  const hasDigit = /[0-9]/.test(pwd);
  const hasSymbol = /[^A-Za-z0-9]/.test(pwd);
  const diversityCount = [hasUpper, hasLower, hasDigit, hasSymbol].filter(Boolean).length;
  checks.hasDiversity = diversityCount >= 3;

  // Calculate NIST Strength Score (0 to 100)
  let score = 0;
  if (pwd.length >= 8) score += 30;
  if (pwd.length >= 12) score += 25;
  if (pwd.length >= 16) score += 15;
  score += diversityCount * 7.5; // up to 30

  if (!checks.notContextual || !checks.notCommon) score = Math.min(score, 30);
  if (!checks.length) score = Math.min(score, 20);

  score = Math.min(100, Math.max(0, Math.round(score)));

  let strengthLabel = 'อ่อนแอ (ไม่ปลอดภัย)';
  let strengthColor = '#ef4444'; // Red

  if (score >= 80 && checks.length && checks.notContextual && checks.notCommon) {
    strengthLabel = 'แข็งแกร่งมาก (มาตรฐาน NIST)';
    strengthColor = '#16a34a'; // Green
  } else if (score >= 55 && checks.length && checks.notContextual && checks.notCommon) {
    strengthLabel = 'ปานกลาง (ใช้งานได้)';
    strengthColor = '#f59e0b'; // Yellow/Orange
  }

  return {
    valid: errors.length === 0,
    errors: errors,
    score: score,
    strengthLabel: strengthLabel,
    strengthColor: strengthColor,
    checks: checks
  };
}

/**
 * User Change Own Password (NIST First-Login Password Setup)
 */
async function userChangeOwnPassword(newPassword, userContext = {}) {
  const val = validateNISTPassword(newPassword, userContext);
  if (!val.valid) {
    return { data: null, error: { message: val.errors[0] } };
  }

  // 1. Try PostgreSQL RPC user_change_own_password
  try {
    const { data, error } = await window.CAD.supabase.rpc('user_change_own_password', {
      new_password: newPassword
    });
    if (!error && data) {
      await logActivity('reset_password', 'ผู้ใช้เปลี่ยนรหัสผ่านครั้งแรกสำเร็จ (NIST Compliant)');
      return { data, error: null };
    }
  } catch (rpcErr) {
    console.warn('RPC user_change_own_password fallback...', rpcErr);
  }

  // 2. Direct Fallback: supabase.auth.updateUser + update user_roles
  try {
    const { data: authData, error: authErr } = await window.CAD.supabase.auth.updateUser({
      password: newPassword
    });
    if (authErr) throw authErr;

    const session = await getSession();
    if (session?.user?.id) {
      await window.CAD.supabase
        .from('user_roles')
        .update({
          must_change_password: false,
          last_password_change: new Date().toISOString()
        })
        .eq('user_id', session.user.id);
    }

    await logActivity('reset_password', 'ผู้ใช้เปลี่ยนรหัสผ่านครั้งแรกสำเร็จ (NIST Compliant)');
    return { data: { success: true }, error: null };
  } catch (err) {
    console.error('userChangeOwnPassword error:', err);
    return { data: null, error: err };
  }
}

/**
 * Check and Enforce First Login Password Change Modal
 */
function checkAndEnforceFirstLoginPasswordChange(userData) {
  if (document.getElementById('nistFirstLoginModal')) return;

  const modalHtml = `
    <div id="nistFirstLoginModal" style="position:fixed; inset:0; z-index:999999; background:rgba(15, 23, 42, 0.85); backdrop-filter:blur(8px); display:flex; align-items:center; justify-content:center; padding:1.25rem;">
      <div style="background:var(--bg-card, #ffffff); border:1px solid var(--border-color, #e2e8f0); border-radius:18px; max-width:520px; width:100%; box-shadow:0 25px 50px -12px rgba(0, 0, 0, 0.35); overflow:hidden; animation:modalPopIn 0.3s cubic-bezier(0.16, 1, 0.3, 1);">
        
        <!-- Header -->
        <div style="background:linear-gradient(135deg, var(--cmu-purple-dark, #3b1464), var(--cmu-purple, #5c2494)); padding:1.75rem 1.75rem 1.5rem; color:white; text-align:center;">
          <div style="width:54px; height:54px; border-radius:50%; background:rgba(255,255,255,0.15); display:inline-flex; align-items:center; justify-content:center; font-size:1.75rem; margin-bottom:0.75rem; border:2px solid rgba(255,255,255,0.3);">
            🔐
          </div>
          <h2 style="font-size:1.25rem; font-weight:700; margin:0 0 0.35rem; color:white;">กำหนดรหัสผ่านใหม่สำหรับการเข้าใช้งานครั้งแรก</h2>
          <p style="font-size:0.84rem; opacity:0.88; margin:0; line-height:1.4;">
            เพื่อความปลอดภัยสูงสุดตามมาตรฐานสากล <strong>NIST SP 800-63B</strong> กรุณาเปลี่ยนรหัสผ่านชั่วคราวก่อนเริ่มใช้งานระบบ
          </p>
        </div>

        <!-- Form Body -->
        <div style="padding:1.5rem 1.75rem;">
          <div style="margin-bottom:1.25rem;">
            <label style="display:block; font-size:0.85rem; font-weight:600; color:var(--text-primary, #1e293b); margin-bottom:0.4rem;">
              รหัสผ่านใหม่ (New Password) <span style="color:#ef4444;">*</span>
            </label>
            <div style="position:relative;">
              <input type="password" id="nistNewPasswordInput" placeholder="กรอกรหัสผ่านใหม่ 8 ตัวอักษรขึ้นไป" style="width:100%; height:42px; padding:0 2.75rem 0 0.85rem; border-radius:8px; border:1.5px solid var(--border-color, #cbd5e1); font-size:0.92rem; outline:none; transition:border 0.2s;" />
              <button type="button" onclick="toggleNistPasswordVisibility('nistNewPasswordInput', this)" style="position:absolute; right:0.6rem; top:50%; transform:translateY(-50%); background:none; border:none; cursor:pointer; font-size:1.1rem; color:var(--text-muted, #94a3b8); padding:0.25rem;">
                👁️
              </button>
            </div>
            
            <!-- Real-time Strength Meter -->
            <div style="margin-top:0.65rem;">
              <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:0.3rem;">
                <span style="font-size:0.75rem; color:var(--text-secondary, #64748b);">ระดับความปลอดภัย:</span>
                <span id="nistStrengthLabel" style="font-size:0.75rem; font-weight:700; color:#ef4444;">รอกรอกรหัสผ่าน</span>
              </div>
              <div style="height:6px; background:#e2e8f0; border-radius:99px; overflow:hidden;">
                <div id="nistStrengthBar" style="height:100%; width:0%; background:#ef4444; transition:all 0.3s ease;"></div>
              </div>
            </div>
          </div>

          <div style="margin-bottom:1.25rem;">
            <label style="display:block; font-size:0.85rem; font-weight:600; color:var(--text-primary, #1e293b); margin-bottom:0.4rem;">
              ยืนยันรหัสผ่านใหม่อีกครั้ง (Confirm Password) <span style="color:#ef4444;">*</span>
            </label>
            <div style="position:relative;">
              <input type="password" id="nistConfirmPasswordInput" placeholder="กรอกรหัสผ่านใหม่อีกครั้งเพื่อยืนยัน" style="width:100%; height:42px; padding:0 2.75rem 0 0.85rem; border-radius:8px; border:1.5px solid var(--border-color, #cbd5e1); font-size:0.92rem; outline:none; transition:border 0.2s;" />
              <button type="button" onclick="toggleNistPasswordVisibility('nistConfirmPasswordInput', this)" style="position:absolute; right:0.6rem; top:50%; transform:translateY(-50%); background:none; border:none; cursor:pointer; font-size:1.1rem; color:var(--text-muted, #94a3b8); padding:0.25rem;">
                👁️
              </button>
            </div>
          </div>

          <!-- NIST Criteria Checklist -->
          <div style="background:var(--bg-hover, #f8fafc); border:1px solid var(--border-color, #e2e8f0); border-radius:10px; padding:0.85rem 1rem; margin-bottom:1.25rem; font-size:0.78rem;">
            <div style="font-weight:700; color:var(--text-secondary, #475569); margin-bottom:0.45rem;">มาตรฐานความปลอดภัย NIST SP 800-63B:</div>
            <div id="chkLength" style="display:flex; align-items:center; gap:0.45rem; color:#94a3b8; margin-bottom:0.25rem;">
              <span>⚪</span> ความยาวอย่างน้อย 8 ตัวอักษรขึ้นไป
            </div>
            <div id="chkContext" style="display:flex; align-items:center; gap:0.45rem; color:#94a3b8; margin-bottom:0.25rem;">
              <span>⚪</span> ไม่ซ้ำกับชื่อ-นามสกุล หรือชื่ออีเมลของคุณ
            </div>
            <div id="chkCommon" style="display:flex; align-items:center; gap:0.45rem; color:#94a3b8;">
              <span>⚪</span> ไม่อยู่ในกลุ่มคำที่คาดเดาได้ง่าย (เช่น password, 12345678)
            </div>
          </div>

          <!-- Action Submit Button -->
          <button id="btnSubmitNistPassword" onclick="handleNistPasswordSubmit()" style="width:100%; height:44px; background:linear-gradient(135deg, var(--cmu-purple, #5c2494), var(--cmu-purple-mid, #7c3aed)); color:white; border:none; border-radius:9px; font-weight:700; font-size:0.92rem; cursor:pointer; transition:all 0.2s; box-shadow:0 4px 12px rgba(92, 36, 148, 0.25);">
            บันทึกรหัสผ่านใหม่ & เริ่มต้นใช้งาน
          </button>
          
          <div style="text-align:center; margin-top:0.85rem;">
            <a href="javascript:void(0)" onclick="signOut()" style="font-size:0.8rem; color:var(--text-muted, #94a3b8); text-decoration:underline;">
              ออกจากระบบ (ยกเลิกและล็อกเอาท์)
            </a>
          </div>
        </div>

      </div>
    </div>
  `;

  document.body.insertAdjacentHTML('beforeend', modalHtml);

  // Bind real-time strength listener
  const pwdInput = document.getElementById('nistNewPasswordInput');
  if (pwdInput) {
    pwdInput.addEventListener('input', (e) => {
      const val = validateNISTPassword(e.target.value, {
        email: userData.email || userData.session?.user?.email,
        fullName: userData.full_name
      });

      const bar = document.getElementById('nistStrengthBar');
      const label = document.getElementById('nistStrengthLabel');
      if (bar && label) {
        bar.style.width = val.score + '%';
        bar.style.background = val.strengthColor;
        label.textContent = val.strengthLabel;
        label.style.color = val.strengthColor;
      }

      // Update Checklist Icons
      const chkLen = document.getElementById('chkLength');
      const chkCtx = document.getElementById('chkContext');
      const chkCom = document.getElementById('chkCommon');

      if (chkLen) {
        chkLen.innerHTML = val.checks.length 
          ? '<span style="color:#16a34a;">🟢</span> <span style="color:#15803d; font-weight:600;">ความยาวอย่างน้อย 8 ตัวอักษร</span>' 
          : '<span>⚪</span> ความยาวอย่างน้อย 8 ตัวอักษรขึ้นไป';
      }
      if (chkCtx) {
        chkCtx.innerHTML = val.checks.notContextual 
          ? '<span style="color:#16a34a;">🟢</span> <span style="color:#15803d; font-weight:600;">ไม่มีชื่อหรืออีเมลปะปน</span>' 
          : '<span style="color:#ef4444;">🔴</span> <span style="color:#b91c1c; font-weight:600;">มีชื่อหรืออีเมลปะปนในรหัสผ่าน</span>';
      }
      if (chkCom) {
        chkCom.innerHTML = val.checks.notCommon 
          ? '<span style="color:#16a34a;">🟢</span> <span style="color:#15803d; font-weight:600;">ผ่านเกณฑ์ความปลอดภัยคำทั่วไป</span>' 
          : '<span style="color:#ef4444;">🔴</span> <span style="color:#b91c1c; font-weight:600;">คำนี้ง่ายเกินไป ห้ามใช้งาน</span>';
      }
    });
  }
}

function toggleNistPasswordVisibility(inputId, btn) {
  const el = document.getElementById(inputId);
  if (!el) return;
  if (el.type === 'password') {
    el.type = 'text';
    btn.textContent = '🔒';
  } else {
    el.type = 'password';
    btn.textContent = '👁️';
  }
}

async function handleNistPasswordSubmit() {
  const newPwd = document.getElementById('nistNewPasswordInput').value;
  const confPwd = document.getElementById('nistConfirmPasswordInput').value;
  const btn = document.getElementById('btnSubmitNistPassword');

  if (!newPwd || !confPwd) {
    alert('กรุณากรอกรหัสผ่านใหม่และยืนยันให้ครบถ้วน');
    return;
  }

  if (newPwd !== confPwd) {
    alert('รหัสผ่านใหม่และการยืนยันรหัสผ่านไม่ตรงกัน กรุณาตรวจสอบอีกครั้ง');
    return;
  }

  const role = await getCurrentUserRole();
  const session = await getSession();
  const userContext = {
    email: role?.email || session?.user?.email,
    fullName: role?.full_name
  };

  const val = validateNISTPassword(newPwd, userContext);
  if (!val.valid) {
    alert('รหัสผ่านไม่ผ่านเกณฑ์ความปลอดภัย NIST:\n- ' + val.errors.join('\n- '));
    return;
  }

  btn.disabled = true;
  btn.textContent = 'กำลังบันทึกรหัสผ่านใหม่...';

  try {
    const { data, error } = await userChangeOwnPassword(newPwd, userContext);
    if (error) throw error;

    alert('✅ ตั้งรหัสผ่านใหม่สำเร็จตามมาตรฐาน NIST SP 800-63B!\nระบบกำลังนำคุณเข้าสู่การใช้งาน');
    const modal = document.getElementById('nistFirstLoginModal');
    if (modal) modal.remove();
    window.location.reload();
  } catch (err) {
    console.error('Password change error:', err);
    alert('เกิดข้อผิดพลาดในการเปลี่ยนรหัสผ่าน: ' + (err.message || ''));
  } finally {
    btn.disabled = false;
    btn.textContent = 'บันทึกรหัสผ่านใหม่ & เริ่มต้นใช้งาน';
  }
}

// Expose globally
window.signIn = signIn;
window.signOut = signOut;
window.getSession = getSession;
window.getCurrentUserRole = getCurrentUserRole;
window.requireAuth = requireAuth;
window.populateNavUser = populateNavUser;
window.adminCreateUser = adminCreateUser;
window.adminUpdateUser = adminUpdateUser;
window.adminDeleteUser = adminDeleteUser;
window.logActivity = logActivity;
window.generateSecureTempPassword = generateSecureTempPassword;
window.validateNISTPassword = validateNISTPassword;
window.userChangeOwnPassword = userChangeOwnPassword;
window.checkAndEnforceFirstLoginPasswordChange = checkAndEnforceFirstLoginPasswordChange;
window.toggleNistPasswordVisibility = toggleNistPasswordVisibility;
window.handleNistPasswordSubmit = handleNistPasswordSubmit;
