(function () {
  function setIconState(dark) {
    var sun = document.getElementById('icon-sun');
    var moon = document.getElementById('icon-moon');
    if (!sun || !moon) return;
    sun.style.display = dark ? 'none' : '';
    moon.style.display = dark ? '' : 'none';
  }

  function applyTheme(dark) {
    document.documentElement.setAttribute('data-theme', dark ? 'dark' : 'light');
    setIconState(dark);
    try {
      localStorage.setItem('silver-bullet-theme', dark ? 'dark' : 'light');
      localStorage.setItem('sb-theme', dark ? 'dark' : 'light');
    } catch (e) { /* storage unavailable */ }
  }

  window.toggleTheme = function () {
    applyTheme(document.documentElement.getAttribute('data-theme') !== 'dark');
  };

  function initThemeToggle() {
    var btn = document.getElementById('theme-toggle') || document.getElementById('theme-btn');
    if (!btn) return;
    if (!btn.getAttribute('aria-label')) btn.setAttribute('aria-label', 'Toggle light/dark mode');
    if (!btn.onclick) btn.addEventListener('click', window.toggleTheme);
  }

  function initMobileNav() {
    document.querySelectorAll('.nav-links a').forEach(function (a) {
      a.addEventListener('click', function () {
        var links = document.querySelector('.nav-links');
        if (links) links.classList.remove('active');
      });
    });
  }

  document.addEventListener('DOMContentLoaded', function () {
    initThemeToggle();
    initMobileNav();
    var saved = 'light';
    try {
      saved = localStorage.getItem('silver-bullet-theme') || localStorage.getItem('sb-theme') || 'light';
    } catch (e) {
      saved = document.documentElement.getAttribute('data-theme') || 'light';
    }
    applyTheme(saved === 'dark');
    if (window.lucide && typeof window.lucide.createIcons === 'function') {
      window.lucide.createIcons();
    }
  });
})();
