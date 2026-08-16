// ============================================================
// auth.js — Authentication & Role Management
// ============================================================


/**
 * Sign in with email/password
 */
async function signIn(email, password) {
  const { data, error } = await window.CAD.supabase.auth.signInWithPassword({ email, password });
  if (!error && data?.user) {
    await logActivity('login', 'เข้าสู่ระบบสำเร็จ', data.user.id);
  }
  return { data, error };
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
 * Get current user role from user_roles table
 */
async function getCurrentUserRole() {
  const session = await getSession();
  if (!session) return null;

  const { data, error } = await window.CAD.supabase
    .from('user_roles')
    .select('role, full_name')
    .eq('user_id', session.user.id)
    .single();

  if (error) return null;
  return data;
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

  // Superadmin has absolute supreme permission across all pages and features!
  if (userRole.role === 'superadmin') {
    return { session, ...userRole };
  }

  if (!allowedRoles.includes(userRole.role)) {
    alert('คุณไม่มีสิทธิ์เข้าถึงหน้านี้');
    window.location.href = 'dashboard.html';
    return null;
  }

  return { session, ...userRole };
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
});

// Admin User Management RPC Calls
async function adminCreateUser(email, password, fullName, userRole) {
  const { data, error } = await window.CAD.supabase.rpc('admin_create_user', {
    email: email,
    password: password,
    full_name: fullName,
    user_role: userRole
  });
  return { data, error };
}

async function adminUpdateUser(targetUserId, newFullName, newRole, newPassword = null) {
  const { data, error } = await window.CAD.supabase.rpc('admin_update_user', {
    target_user_id: targetUserId,
    new_full_name: newFullName,
    new_role: newRole,
    new_password: newPassword || null
  });
  return { data, error };
}

async function adminDeleteUser(targetUserId) {
  const { data, error } = await window.CAD.supabase.rpc('admin_delete_user', {
    target_user_id: targetUserId
  });
  return { data, error };
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
