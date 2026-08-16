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

  document.addEventListener('DOMContentLoaded', () => {
    const sel = document.getElementById('themeSelectDropdown');
    if (sel) sel.value = savedTheme;
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
})();
