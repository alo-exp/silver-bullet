import playwrightPkg from '/Users/shafqat/.cursor/worktrees/repo/3ht3/research/2026-07-20-agentic-sdlc-orchestration-landscape-multimarket-final/_adversarial-audit/node_modules/playwright/index.js';
const { chromium } = playwrightPkg;
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const htmlPath = path.resolve(__dirname, '../landscape-report.html');
const out = __dirname;
const url = 'file://' + htmlPath;
const BAD = [
  'cc10x.dev',
  'barkain.com',
  'cavekit.ai',
  'agentsys.ai',
  'aws.amazon.com/ai-dlc',
  'ibm.com',
];

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
const consoleErrors = [];
const pageErrors = [];
const failed = [];
page.on('console', (m) => {
  if (m.type() === 'error') consoleErrors.push(m.text());
});
page.on('pageerror', (e) => pageErrors.push(String(e)));
page.on('requestfailed', (r) => failed.push({ url: r.url(), err: r.failure()?.errorText }));
await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 60000 });
await page.waitForTimeout(2500);

const ev = await page.evaluate((bad) => {
  const h1 = document.querySelector('h1')?.innerText?.trim() || '';
  const fail = /render failed|parseInline|TypeError/i.test(document.body?.innerText || '');
  const http = [...document.querySelectorAll('a[href^="http"]')].map((a) => ({
    text: (a.textContent || '').trim().slice(0, 80),
    href: a.href,
  }));
  const uniq = [...new Set(http.map((x) => x.href))];
  const challengerBtn = [...document.querySelectorAll('button, .vfbtn')].map((b) => ({
    t: (b.textContent || '').trim(),
    disabled: b.disabled,
    cls: b.className,
    title: b.getAttribute('title'),
  }));
  const canvases = [...document.querySelectorAll('canvas')].map((c) => ({
    w: c.width,
    h: c.height,
    parent: c.parentElement?.className,
  }));
  const charts = [...document.querySelectorAll('.chart-wrap, [data-chart], canvas, svg.fig')];
  const labels = [...document.querySelectorAll('.chart-wrap text, svg text, .chartjs-tooltip')];
  const oobLabels = [];
  for (const el of labels) {
    const r = el.getBoundingClientRect();
    const parent = el.closest('.chart-wrap, .chart-card, canvas, svg') || el.parentElement;
    if (!parent) continue;
    const pr = parent.getBoundingClientRect();
    if (r.width === 0 && r.height === 0) continue;
    if (r.left < pr.left - 2 || r.right > pr.right + 2 || r.top < pr.top - 2 || r.bottom > pr.bottom + 2) {
      oobLabels.push({
        t: (el.textContent || '').trim().slice(0, 40),
        dx: Math.round(r.left - pr.left),
        dy: Math.round(r.top - pr.top),
      });
    }
  }
  return {
    h1,
    fail,
    httpCount: http.length,
    uniqCount: uniq.length,
    hrefs: uniq.sort(),
    bad: uniq.filter((u) => bad.some((n) => u.includes(n))),
    sampleLinks: http
      .filter((x) =>
        /cc10x|Barkain|Cavekit|AgentSys|AI-DLC|Zuvo|Harness|Tembo|Conductor|MetaGPT|Silver Bullet|Claude Code Expert/i.test(
          x.text + ' ' + x.href,
        ),
      )
      .slice(0, 50),
    challengerBtn: challengerBtn
      .filter((b) => /challenger|leader|commercial|oss/i.test(b.t + b.cls))
      .slice(0, 20),
    canvases,
    chartCount: charts.length,
    oobLabels: oobLabels.slice(0, 20),
    overflow: document.documentElement.scrollWidth > document.documentElement.clientWidth + 1,
    scrollW: document.documentElement.scrollWidth,
    clientW: document.documentElement.clientWidth,
    contentLen: (document.getElementById('content')?.innerText || '').length,
    expert: /Claude Code Expert/i.test(document.body.innerText),
    divergences: /Notable divergences/i.test(document.body.innerText),
    buying: /Buying Guidance/i.test(document.body.innerText),
  };
}, BAD);

await page.screenshot({ path: path.join(out, 'fileurl-1280.png'), fullPage: false });
await page.setViewportSize({ width: 375, height: 812 });
await page.waitForTimeout(400);
const ov375 = await page.evaluate(() => ({
  overflow: document.documentElement.scrollWidth - document.documentElement.clientWidth,
  scrollW: document.documentElement.scrollWidth,
  clientW: document.documentElement.clientWidth,
}));
await page.screenshot({ path: path.join(out, 'fileurl-375.png'), fullPage: false });

const result = {
  url,
  ev,
  ov375,
  consoleErrors: consoleErrors.slice(0, 20),
  pageErrors,
  failed: failed.slice(0, 40),
};
fs.writeFileSync(path.join(out, 'playwright-fileurl.json'), JSON.stringify(result, null, 2));
console.log(
  JSON.stringify(
    {
      h1: ev.h1,
      fail: ev.fail,
      http: ev.httpCount,
      uniq: ev.uniqCount,
      bad: ev.bad,
      overflow1280: ev.overflow,
      ov375,
      expert: ev.expert,
      divergences: ev.divergences,
      buying: ev.buying,
      contentLen: ev.contentLen,
      canvases: ev.canvases.length,
      chartCount: ev.chartCount,
      oobLabels: ev.oobLabels,
      challengerBtn: ev.challengerBtn,
      sampleLinks: ev.sampleLinks,
      consoleErrors: consoleErrors.slice(0, 10),
      pageErrors,
      failed: failed.slice(0, 15),
    },
    null,
    2,
  ),
);
await browser.close();
