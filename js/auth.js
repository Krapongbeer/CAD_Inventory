// ============================================================
// auth.js — Authentication & Role Management
// ============================================================

const { supabase } = window.CAD;

/**
 * Sign in with email/password
 */
async function signIn(email, password) {
  const { data, error } = await supabase.auth.signInWithPassword({ email, password });
  return { data, error };
}

/**
 * Sign out
 */
async function signOut() {
  const { error } = await supabase.auth.signOut();
  if (!error) window.location.href = 'index.html';
}

/**
 * Get current session
 */
async function getSession() {
  const { data: { session } } = await supabase.auth.getSession();
  return session;
}

/**
 * Get current user role from user_roles table
 */
async function getCurrentUserRole() {
  const session = await getSession();
  if (!session) return null;

  const { data, error } = await supabase
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
 * @param {string[]} allowedRoles - e.g. ['admin', 'staff', 'executive']
 */
async function requireAuth(allowedRoles = ['admin', 'staff', 'executive']) {
  const session = await getSession();
  if (!session) {
    window.location.href = 'index.html';
    return null;
  }

  const userRole = await getCurrentUserRole();
  if (!userRole) {
    window.location.href = 'index.html';
    return null;
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

  const nameEl = document.getElementById('navUserName');
  const roleEl = document.getElementById('navUserRole');
  const emailEl = document.getElementById('navUserEmail');

  const roleLabels = {
    admin: 'ผู้ดูแลระบบ',
    staff: 'เจ้าหน้าที่',
    executive: 'ผู้บริหาร'
  };

  if (nameEl) nameEl.textContent = userRole?.full_name || session?.user?.email || '-';
  if (roleEl) roleEl.textContent = roleLabels[userRole?.role] || '-';
  if (emailEl) emailEl.textContent = session?.user?.email || '-';
}

// Expose globally
window.signIn = signIn;
window.signOut = signOut;
window.getSession = getSession;
window.getCurrentUserRole = getCurrentUserRole;
window.requireAuth = requireAuth;
window.populateNavUser = populateNavUser;
