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
    if (!links.length) return;

    var sections = [];
    links.forEach(function (link) {
      var id = link.getAttribute('href').slice(1);
      var el = document.getElementById(id);
      if (el) sections.push({ link: link, el: el });
    });
    if (!sections.length) return;

    var clickLock = false;
    var clickLockTimer = null;

    function setActive(link) {
      links.forEach(function (l) { l.classList.remove('active'); });
      if (link) link.classList.add('active');
    }

    function updateActiveFromScroll() {
      if (clickLock) return;
      var pos = window.pageYOffset + getAnchorOffset() + 2;
      var current = sections[0].link;
      sections.forEach(function (item) {
        if (item.el.offsetTop <= pos) current = item.link;
      });
      setActive(current);
    }

    document.addEventListener('click', function (event) {
      var link = event.target.closest && event.target.closest('.sidebar-nav a[href^="#"]');
      if (!link) return;
      setActive(link);
      clickLock = true;
      clearTimeout(clickLockTimer);
      clickLockTimer = setTimeout(function () {
        clickLock = false;
        updateActiveFromScroll();
      }, 700);
    });

    window.addEventListener('scroll', updateActiveFromScroll, { passive: true });
    window.addEventListener('resize', updateActiveFromScroll);
    updateActiveFromScroll();
  }

  document.addEventListener('DOMContentLoaded', function () {
    initAnchorScroll();
    initSidebarActiveState();
    if (window.lucide && typeof window.lucide.createIcons === 'function') {
      window.lucide.createIcons();
    }
  });
})();
