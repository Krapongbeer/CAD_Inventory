// ============================================================
// theme.js — Theme Manager (Day / Night / Auto)
// ============================================================

(function() {
  const THEME_KEY = 'cad_theme_preference';

  function applyTheme(theme) {
    if (theme === 'auto') {
      const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
      document.documentElement.setAttribute('data-theme', prefersDark ? 'dark' : 'light');
    } else {
      document.documentElement.setAttribute('data-theme', theme);
    }
    const sel = document.getElementById('themeSelectDropdown');
    if (sel) sel.value = theme;
  }

  // Load initial theme instantly to prevent flash
  const savedTheme = localStorage.getItem(THEME_KEY) || 'auto';
  applyTheme(savedTheme);

  // Sidebar Collapse Manager
  const SIDEBAR_COLLAPSED_KEY = 'cad_sidebar_collapsed';

  function applySidebarState(collapsed) {
    if (window.innerWidth > 768) {
      if (collapsed === 'true') {
        document.body.classList.add('sidebar-collapsed');
      } else {
        document.body.classList.remove('sidebar-collapsed');
      }
    } else {
      document.body.classList.remove('sidebar-collapsed');
    }
  }

  // Load initial sidebar state instantly to prevent layout shift
  const savedSidebarState = localStorage.getItem(SIDEBAR_COLLAPSED_KEY) || 'false';
  applySidebarState(savedSidebarState);

  document.addEventListener('DOMContentLoaded', () => {
    const sel = document.getElementById('themeSelectDropdown');
    if (sel) sel.value = savedTheme;
    applySidebarState(localStorage.getItem(SIDEBAR_COLLAPSED_KEY) || 'false');
  });

  window.addEventListener('resize', () => {
    applySidebarState(localStorage.getItem(SIDEBAR_COLLAPSED_KEY) || 'false');
  });

  // Listen for system theme changes
  window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', (e) => {
    if (localStorage.getItem(THEME_KEY) === 'auto') {
      applyTheme('auto');
    }
  });

  window.ThemeManager = {
    setTheme: (theme) => {
      localStorage.setItem(THEME_KEY, theme);
      applyTheme(theme);
    },
    getTheme: () => localStorage.getItem(THEME_KEY) || 'auto'
  };

  // Unified global toggle sidebar function
  window.toggleSidebar = function() {
    if (window.innerWidth > 768) {
      const isCollapsed = document.body.classList.contains('sidebar-collapsed');
      const newState = !isCollapsed;
      localStorage.setItem(SIDEBAR_COLLAPSED_KEY, newState ? 'true' : 'false');
      applySidebarState(newState ? 'true' : 'false');
    } else {
      const sidebar = document.getElementById('sidebar');
      const overlay = document.getElementById('sidebarOverlay');
      if (sidebar) sidebar.classList.toggle('open');
      if (overlay) overlay.classList.toggle('hidden');
    }
  };

  // Unified global close sidebar function
  window.closeSidebar = function() {
    const sidebar = document.getElementById('sidebar');
    const overlay = document.getElementById('sidebarOverlay');
    if (sidebar) sidebar.classList.remove('open');
    if (overlay) overlay.classList.add('hidden');
  };
})();

