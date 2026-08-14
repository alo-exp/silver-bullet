#!/usr/bin/env node
/**
 * Adversarial DOM/runtime audit for landscape SPA report.
 * Serves via http://127.0.0.1:8877/landscape-report.html
 */
import { chromium } from 'playwright';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const OUT = __dirname;
const URL = process.env.AUDIT_URL || 'http://127.0.0.1:8877/landscape-report.html';

const findings = [];
function add(id, severity, description, evidence) {
  findings.push({ id, severity, description, evidence });
}

async function shot(page, name) {
  const p = path.join(OUT, name);
  await page.screenshot({ path: p, fullPage: false });
  return p;
}

async function main() {
  const browser = await chromium.launch({ headless: true });
  const consoleErrors = [];
  const pageErrors = [];
  const failedReqs = [];

  const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
  page.on('console', (msg) => {
    if (msg.type() === 'error') consoleErrors.push(msg.text());
  });
  page.on('pageerror', (err) => pageErrors.push(String(err)));
  page.on('requestfailed', (req) => failedReqs.push({ url: req.url(), err: req.failure()?.errorText }));

  await page.goto(URL, { waitUntil: 'networkidle', timeout: 60000 });
  await page.waitForTimeout(1500);

  const before1280 = await shot(page, 'BEFORE-1280.png');

  const meta = await page.evaluate(() => {
    const h1 = document.querySelector('h1')?.textContent?.trim() || '';
    const bodyText = document.body?.innerText || '';
    const fail = /render failed|parseInline|TypeError/i.test(bodyText);
    const markedSrc = [...document.querySelectorAll('script[src]')].map((s) => s.src).find((s) => /marked/i.test(s)) || '';
    const nameLinks = [...document.querySelectorAll('a.vc-name-link')].map((a) => ({
      text: a.textContent.trim(),
      href: a.getAttribute('href'),
      target: a.getAttribute('target'),
      rel: a.getAttribute('rel'),
    }));
    const allHttp = [...document.querySelectorAll('a[href^="http"]')];
    const httpMeta = {
      count: allHttp.length,
      missingBlank: allHttp.filter((a) => a.target !== '_blank').length,
      missingRel: allHttp.filter((a) => a.target === '_blank' && !/noopener/i.test(a.rel || '')).length,
      jsHref: allHttp.filter((a) => /^javascript:/i.test(a.href)).length,
    };
    const cards = [...document.querySelectorAll('.vc-card, .vendor-card, [data-vendor]')].length;
    const filterBtns = [...document.querySelectorAll('.vfbtn')].map((b) => b.textContent.trim());
    const snav = [...document.querySelectorAll('.snav-btn, #sidebar a')].slice(0, 30).map((a) => a.textContent.trim());
    const sections = [...document.querySelectorAll('section[id], .section[id], [id^="sec"]')].map((s) => s.id);
    const marketTabs = [...document.querySelectorAll('[data-market], .market-tab, .mtab')].map((el) => ({
      text: el.textContent.trim().slice(0, 60),
      market: el.getAttribute('data-market'),
    }));
    // fill / critical empty indicators
    const emptyCritical = [...document.querySelectorAll('tr')].filter((tr) => {
      const t = tr.innerText || '';
      return /Self-serve signup|Managed hosting/i.test(t);
    }).map((tr) => tr.innerText.replace(/\s+/g, ' ').slice(0, 200));
    // chart canvases
    const canvases = [...document.querySelectorAll('canvas')].map((c) => ({
      id: c.id,
      w: c.width,
      h: c.height,
      visible: c.offsetParent !== null || c.getBoundingClientRect().height > 0,
    }));
    // link colors sample
    const sampleLink = document.querySelector('a.vc-name-link, #content a[href^="http"]');
    let linkColor = null;
    if (sampleLink) {
      const cs = getComputedStyle(sampleLink);
      linkColor = { color: cs.color, bg: getComputedStyle(document.body).backgroundColor };
    }
    // dark theme?
    const bg = getComputedStyle(document.body).backgroundColor;
    return {
      h1,
      fail,
      bodyLen: bodyText.length,
      markedSrc,
      nameLinks: nameLinks.slice(0, 15),
      nameLinkCount: nameLinks.length,
      httpMeta,
      cards,
      filterBtns,
      snav,
      sections: sections.slice(0, 40),
      marketTabs,
      emptyCritical,
      canvases,
      linkColor,
      bg,
      hasAPO: /APO|Process Orchestrat/i.test(bodyText),
      hasSDLC: /SDLC Plugin|Methodology/i.test(bodyText),
      hasSaaS: /SaaS|Factory|Devin/i.test(bodyText),
    };
  });

  if (pageErrors.length) add('P0-JS', 'P0', 'Page JS errors on load', pageErrors.slice(0, 10));
  if (consoleErrors.length) add('P1-CONSOLE', 'P1', 'Console errors on load', consoleErrors.slice(0, 15));
  if (meta.fail) add('P0-RENDER', 'P0', 'Report render failed banner', { h1: meta.h1, bodyLen: meta.bodyLen });
  if (!/marked@11\.1\.1/.test(meta.markedSrc)) {
    add('P0-MARKED', 'P0', 'Marked CDN not pinned to 11.1.1', meta.markedSrc);
  }
  if (meta.httpMeta.missingBlank > 0) {
    add('P1-TARGET', 'P1', 'HTTP links missing target=_blank', meta.httpMeta);
  }
  if (meta.httpMeta.missingRel > 0) {
    add('P1-REL', 'P1', 'target=_blank without noopener', meta.httpMeta);
  }
  if (meta.nameLinkCount === 0) {
    add('P1-TITLELINKS', 'P1', 'No .vc-name-link homepage title links rendered', meta);
  }

  // Filter Leaders — check Visionaries appear
  const leadersFilter = await page.evaluate(() => {
    const btn = [...document.querySelectorAll('.vfbtn')].find((b) => /Leaders/i.test(b.textContent));
    if (!btn) return { error: 'no Leaders btn' };
    btn.click();
    const visible = [...document.querySelectorAll('.vc-card, .vendor-card')]
      .filter((c) => c.offsetParent !== null || getComputedStyle(c).display !== 'none')
      .map((c) => (c.querySelector('.vc-name-link, .vc-name, h3, h4')?.textContent || c.textContent).trim().split('\n')[0])
      .filter(Boolean);
    // also try data-hidden
    const hiddenCount = [...document.querySelectorAll('.vc-card, .vendor-card')].filter((c) => c.hidden || c.classList.contains('filtered-out') || getComputedStyle(c).display === 'none').length;
    return { visible: visible.slice(0, 30), visibleCount: visible.length, hiddenCount };
  });

  const challengersFilter = await page.evaluate(() => {
    const btn = [...document.querySelectorAll('.vfbtn')].find((b) => /Challengers/i.test(b.textContent));
    if (!btn) return { error: 'no Challengers btn' };
    btn.click();
    const visible = [...document.querySelectorAll('.vc-card, .vendor-card')]
      .filter((c) => {
        const st = getComputedStyle(c);
        return st.display !== 'none' && st.visibility !== 'hidden' && !c.hidden;
      })
      .map((c) => (c.querySelector('.vc-name-link, .vc-name, h3, h4')?.textContent || '').trim())
      .filter(Boolean);
    return { visible, count: visible.length };
  });

  // Reset to All
  await page.evaluate(() => {
    const btn = [...document.querySelectorAll('.vfbtn')].find((b) => /All/i.test(b.textContent));
    btn?.click();
  });

  // Market switching
  const marketSwitch = await page.evaluate(async () => {
    const results = [];
    const tabs = [...document.querySelectorAll('[data-market], .market-tab, button')].filter((el) =>
      /APO|SDLC|SaaS|Primary|Secondary|Tertiary/i.test(el.textContent || '')
    );
    for (const tab of tabs.slice(0, 6)) {
      tab.click();
      await new Promise((r) => setTimeout(r, 300));
      const title = document.querySelector('h2, .chart-title, #mq-title, [id*="mq"]')?.textContent || '';
      const h = [...document.querySelectorAll('h2,h3')].map((x) => x.textContent.trim()).filter((t) => /3[A-D]|Primary|Secondary|Tertiary|Matrix|Quadrant|Wave/i.test(t)).slice(0, 6);
      results.push({ tab: tab.textContent.trim().slice(0, 40), titles: h });
    }
    return { tabCount: tabs.length, results };
  });

  // Snav clicks shouldn't preventDefault incorrectly
  const snavTest = await page.evaluate(() => {
    const links = [...document.querySelectorAll('#sidebar a[href^="#"], .snav-btn')].slice(0, 5);
    const info = links.map((a) => ({
      text: a.textContent.trim().slice(0, 40),
      href: a.getAttribute('href'),
      tag: a.tagName,
    }));
    // click first hash link and see if hash changes
    const first = links.find((a) => (a.getAttribute('href') || '').startsWith('#'));
    let hashBefore = location.hash;
    first?.click();
    return { info, hashBefore, hashAfter: location.hash, firstHref: first?.getAttribute('href') };
  });

  // Contrast: sample vendor link on dark bg
  const contrast = await page.evaluate(() => {
    function parseRGB(c) {
      const m = c.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)/);
      return m ? [+m[1], +m[2], +m[3]] : [0, 0, 0];
    }
    function lum([r, g, b]) {
      const a = [r, g, b].map((v) => {
        v /= 255;
        return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
      });
      return 0.2126 * a[0] + 0.7152 * a[1] + 0.0722 * a[2];
    }
    function ratio(fg, bg) {
      const L1 = lum(parseRGB(fg));
      const L2 = lum(parseRGB(bg));
      const [hi, lo] = L1 > L2 ? [L1, L2] : [L2, L1];
      return (hi + 0.05) / (lo + 0.05);
    }
    const link = document.querySelector('a.vc-name-link');
    if (!link) return { error: 'no link' };
    const fg = getComputedStyle(link).color;
    const bg = getComputedStyle(document.body).backgroundColor;
    return { fg, bg, ratio: Math.round(ratio(fg, bg) * 100) / 100 };
  });

  // Overflow at 375
  await page.setViewportSize({ width: 375, height: 812 });
  await page.waitForTimeout(500);
  const overflow375 = await page.evaluate(() => {
    const docW = document.documentElement.scrollWidth;
    const winW = window.innerWidth;
    return { docW, winW, overflow: docW - winW };
  });
  const before375 = await shot(page, 'BEFORE-375.png');

  await page.setViewportSize({ width: 768, height: 900 });
  await page.waitForTimeout(400);
  const overflow768 = await page.evaluate(() => ({
    docW: document.documentElement.scrollWidth,
    winW: window.innerWidth,
    overflow: document.documentElement.scrollWidth - window.innerWidth,
  }));
  await shot(page, 'BEFORE-768.png');

  // Self-serve / managed hosting matrix cells
  await page.setViewportSize({ width: 1280, height: 900 });
  const matrixFill = await page.evaluate(() => {
    const rows = [...document.querySelectorAll('tr')].filter((tr) =>
      /Self-serve signup|Managed hosting/i.test(tr.innerText || '')
    );
    return rows.map((tr) => {
      const cells = [...tr.querySelectorAll('td,th')].map((c) => c.textContent.trim());
      const checks = (tr.innerText.match(/✔|✓|✅/g) || []).length;
      const empties = [...tr.querySelectorAll('td')].filter((td) => !td.textContent.trim()).length;
      return { label: cells[0], checks, empties, cellCount: cells.length, preview: cells.slice(0, 8) };
    });
  });

  // Wave vs MQ fill colors via chart plugin regions if exposed
  const chartTheme = await page.evaluate(() => {
    const out = {};
    try {
      if (typeof sbWaveZoneFills === 'function') out.wave = sbWaveZoneFills();
      if (typeof sbQuadrantFills === 'function') out.quad = sbQuadrantFills();
      if (typeof sbChartTheme === 'function') out.theme = { zones: sbChartTheme().zones, quad: sbChartTheme().quad };
    } catch (e) {
      out.error = String(e);
    }
    return out;
  });

  // XSS: javascript: in DOM after render
  const xss = await page.evaluate(() => {
    const bad = [...document.querySelectorAll('a[href]')].filter((a) =>
      /^(javascript:|data:text\/html)/i.test(a.getAttribute('href') || '')
    );
    return bad.map((a) => a.getAttribute('href')).slice(0, 10);
  });
  if (xss.length) add('P0-XSS', 'P0', 'javascript:/data: hrefs present', xss);

  // Leaders including known Visionaries
  const visionariesInLeaders = (leadersFilter.visible || []).filter((n) =>
    /Cavekit|Conductor|Director|Barkain|Claude Code Expert/i.test(n)
  );
  if (visionariesInLeaders.length) {
    add(
      'P1-LEADERS-FILTER',
      'P1',
      'Leaders filter shows MQ Visionaries (GMQ/MQ quadrant disagreement)',
      { visionariesInLeaders, leadersVisible: leadersFilter.visible }
    );
  }
  if (challengersFilter.count === 0) {
    add('P2-CHALLENGERS-EMPTY', 'P2', 'Challengers filter yields zero vendors across markets', challengersFilter);
  }

  if (contrast.ratio != null && contrast.ratio < 4.5) {
    add('P1-CONTRAST', 'P1', 'Vendor link contrast below WCAG AA 4.5:1', contrast);
  }

  if (overflow375.overflow > 2) {
    add('P2-OVERFLOW-375', 'P2', 'Horizontal overflow at 375px', overflow375);
  }

  if (matrixFill.some((r) => r.checks === 0 && r.empties > 5)) {
    add(
      'P1-CRITICAL-EMPTY',
      'P1',
      'Critical matrix rows Self-serve signup / Managed hosting are fully empty (0% fill) — risk of silent data gap',
      matrixFill
    );
  }

  // Section numbering collision across markets
  const numbering = await page.evaluate(() => {
    const titles = [...document.querySelectorAll('h2,h3,h4')].map((h) => h.textContent.trim()).filter((t) => /^3[A-D]/.test(t));
    return titles;
  });
  const dup3A = numbering.filter((t) => t.startsWith('3A'));
  if (dup3A.length > 1) {
    add('P2-SECTION-NUM', 'P2', 'Multiple 3A section titles visible (market switch may leave duplicates or shared numbering)', dup3A);
  }

  const report = {
    url: URL,
    ts: new Date().toISOString(),
    pageErrors,
    consoleErrors: consoleErrors.slice(0, 20),
    failedReqs: failedReqs.slice(0, 20),
    meta,
    leadersFilter,
    challengersFilter,
    marketSwitch,
    snavTest,
    contrast,
    overflow375,
    overflow768,
    matrixFill,
    chartTheme,
    numbering,
    screenshots: { before1280, before375 },
    findings,
  };

  fs.writeFileSync(path.join(OUT, 'audit-BEFORE.json'), JSON.stringify(report, null, 2));
  console.log(JSON.stringify({ findingsCount: findings.length, findings, pageErrors, consoleErrors: consoleErrors.slice(0, 5), meta: { h1: meta.h1, fail: meta.fail, nameLinkCount: meta.nameLinkCount, httpMeta: meta.httpMeta, markedSrc: meta.markedSrc, contrast, overflow375 }, leadersFilter, challengersFilter, matrixFill, marketSwitch: { tabCount: marketSwitch.tabCount, sample: marketSwitch.results.slice(0, 3) } }, null, 2));

  await browser.close();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
