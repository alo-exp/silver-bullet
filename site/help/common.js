(function () {
  var sunIcon = '<span id="icon-sun" aria-hidden="true"><svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M6.34 17.66l-1.41 1.41M19.07 4.93l-1.41 1.41"/></svg></span>';
  var moonIcon = '<span id="icon-moon" aria-hidden="true"><svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/></svg></span>';
  var anchorOffset = 96;

  function setIconState(theme) {
    var sun = document.getElementById('icon-sun');
    var moon = document.getElementById('icon-moon');
    if (!sun || !moon) return;
    sun.style.display = theme === 'dark' ? '' : 'none';
    moon.style.display = theme === 'dark' ? 'none' : '';
  }

  function applyTheme(theme) {
    var next = theme === 'dark' ? 'dark' : 'light';
    document.documentElement.setAttribute('data-theme', next);
    try {
      localStorage.setItem('sb-theme', next);
    } catch (error) {
      /* Theme still applies when storage is unavailable. */
    }
    setIconState(next);
  }

  window.toggleTheme = function () {
    applyTheme(document.documentElement.getAttribute('data-theme') === 'dark' ? 'light' : 'dark');
  };

  function normalizeThemeButton() {
    var btn = document.getElementById('theme-btn');
    if (!btn) return;
    btn.classList.add('help-theme-btn');
    btn.setAttribute('type', 'button');
    btn.setAttribute('aria-label', 'Toggle theme');
    btn.innerHTML = sunIcon + moonIcon;
    btn.addEventListener('click', window.toggleTheme);
  }

  function scrollToHash(hash, replace) {
    if (!hash || hash === '#') return false;
    var id = decodeURIComponent(hash.slice(1));
    var target = document.getElementById(id);
    if (!target) return false;
    var y = target.getBoundingClientRect().top + window.pageYOffset - anchorOffset;
    window.scrollTo({ top: Math.max(0, y), behavior: replace ? 'auto' : 'smooth' });
    if (!replace) history.pushState(null, '', hash);
    return true;
  }

  function initAnchorScroll() {
    document.addEventListener('click', function (event) {
      var link = event.target.closest && event.target.closest('a[href^="#"]');
      if (!link) return;
      var hash = link.getAttribute('href');
      if (scrollToHash(hash, false)) event.preventDefault();
    });
    if (window.location.hash) {
      window.setTimeout(function () { scrollToHash(window.location.hash, true); }, 80);
    }
    window.addEventListener('hashchange', function () {
      window.setTimeout(function () { scrollToHash(window.location.hash, true); }, 0);
    });
  }

  function initSidebarActiveState() {
    var links = Array.prototype.slice.call(document.querySelectorAll('.sidebar-nav a[href^="#"]'));
    if (!links.length || !('IntersectionObserver' in window)) return;
    var byId = {};
    links.forEach(function (link) {
      byId[link.getAttribute('href').slice(1)] = link;
    });
    var observer = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return;
        links.forEach(function (link) { link.classList.remove('active'); });
        var active = byId[entry.target.id];
        if (active) active.classList.add('active');
      });
    }, { rootMargin: '-25% 0px -65% 0px', threshold: 0 });
    Object.keys(byId).forEach(function (id) {
      var section = document.getElementById(id);
      if (section) observer.observe(section);
    });
  }

  document.addEventListener('DOMContentLoaded', function () {
    normalizeThemeButton();
    var savedTheme = 'light';
    try {
      savedTheme = localStorage.getItem('sb-theme') || 'light';
    } catch (error) {
      savedTheme = document.documentElement.getAttribute('data-theme') || 'light';
    }
    applyTheme(savedTheme);
    initAnchorScroll();
    initSidebarActiveState();
    if (window.lucide && typeof window.lucide.createIcons === 'function') {
      window.lucide.createIcons();
    }
  });
})();
