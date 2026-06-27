(function () {
  function getAnchorOffset() {
    var root = getComputedStyle(document.documentElement);
    var header = parseFloat(root.getPropertyValue('--site-header-h')) || 64;
    var gap = parseFloat(root.getPropertyValue('--anchor-scroll-gap')) || 32;
    var subnav = document.body.classList.contains('has-help-subnav')
      ? (parseFloat(root.getPropertyValue('--help-subnav-h')) || 48)
      : 0;
    return header + subnav + gap;
  }

  function scrollToHash(hash, replace) {
    if (!hash || hash === '#') return false;
    var id = decodeURIComponent(hash.slice(1));
    var target = document.getElementById(id);
    if (!target) return false;
    var y = target.getBoundingClientRect().top + window.pageYOffset - getAnchorOffset();
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
    initAnchorScroll();
    initSidebarActiveState();
    if (window.lucide && typeof window.lucide.createIcons === 'function') {
      window.lucide.createIcons();
    }
  });
})();
