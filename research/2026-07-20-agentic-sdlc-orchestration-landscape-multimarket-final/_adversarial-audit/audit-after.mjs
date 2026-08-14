#!/usr/bin/env node
import { chromium } from 'playwright';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const OUT = __dirname;
const URL = process.env.AUDIT_URL || 'http://127.0.0.1:8877/landscape-report.html';

async function main() {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
  const pageErrors = [];
  const consoleErrors = [];
  const failed = [];
  page.on('pageerror', (e) => pageErrors.push(String(e)));
  page.on('console', (m) => { if (m.type() === 'error') consoleErrors.push(m.text()); });
  page.on('response', (r) => { if (r.status() === 404) failed.push(r.url()); });

  await page.goto(URL, { waitUntil: 'networkidle', timeout: 60000 });
  await page.waitForTimeout(1800);
  await page.screenshot({ path: path.join(OUT, 'AFTER-1280.png') });

  // Dark theme
  await page.click('#themeToggle');
  await page.waitForTimeout(400);
  await page.screenshot({ path: path.join(OUT, 'AFTER-dark-1280.png') });

  const evidence = await page.evaluate(() => {
    const body = document.body?.innerText || '';
    const fail = /render failed|parseInline|TypeError/i.test(body);
    const banner = document.getElementById('matrixFillGapBanner')?.textContent || '';
    const marked = [...document.querySelectorAll('script[src]')].map((s) => s.src).find((s) => /marked/i.test(s));
    const fonts = [...document.querySelectorAll('link[rel="stylesheet"]')].map((l) => l.href);
    const sdlcLinks = [...document.querySelectorAll('a')].filter((a) => /^SDLC Plugin$/i.test(a.textContent.trim()));
    const challengerBtn = [...document.querySelectorAll('.vfbtn')].find((b) => /Challengers/i.test(b.textContent));
    // Leaders filter — should not include Cavekit when on APO (scroll to 3.1)
    const h = [...document.querySelectorAll('h2,h3')].find((x) => /3\.1 Primary market/i.test(x.textContent));
    h?.scrollIntoView();
    return {
      h1: document.querySelector('h1')?.textContent?.trim(),
      fail,
      bodyLen: body.length,
      banner: banner.slice(0, 300),
      marked,
      fonts,
      sdlcLinkCount: sdlcLinks.length,
      sdlcHrefs: [...new Set(sdlcLinks.map((a) => a.getAttribute('href')))],
      challengerDisabled: !!challengerBtn?.disabled,
      challengerClass: challengerBtn?.className,
      httpMeta: (() => {
        const all = [...document.querySelectorAll('a[href^="http"]')];
        return {
          count: all.length,
          missingBlank: all.filter((a) => a.target !== '_blank').length,
          missingRel: all.filter((a) => a.target === '_blank' && !/noopener/i.test(a.rel || '')).length,
        };
      })(),
      nameLinkCount: document.querySelectorAll('a.vc-name-link').length,
      hasAPO: /3\.1 Primary market/i.test(body),
      hasSDLC: /3\.2 Secondary market/i.test(body),
      hasSaaS: /3\.3 Tertiary market/i.test(body),
    };
  });

  await page.waitForTimeout(500);
  // Click Leaders and capture visible card titles
  const leadersVisible = await page.evaluate(() => {
    const btn = [...document.querySelectorAll('.vfbtn')].find((b) => /Leaders/i.test(b.textContent));
    btn?.click();
    return [...document.querySelectorAll('.vendor-card:not(.is-filtered-out) a.vc-name-link, .vc-card:not(.is-filtered-out) a.vc-name-link')]
      .map((a) => a.textContent.trim())
      .filter(Boolean);
  });

  await page.setViewportSize({ width: 375, height: 812 });
  await page.waitForTimeout(400);
  const overflow375 = await page.evaluate(() => ({
    overflow: document.documentElement.scrollWidth - window.innerWidth,
  }));
  await page.screenshot({ path: path.join(OUT, 'AFTER-375.png') });

  // light theme shot of cards area at 1280
  await page.setViewportSize({ width: 1280, height: 900 });
  await page.click('#themeToggle'); // back to light if was dark — toggle twice from dark=light
  await page.waitForTimeout(300);

  const pass =
    !evidence.fail &&
    pageErrors.length === 0 &&
    /marked@11\.1\.1/.test(evidence.marked || '') &&
    evidence.sdlcHrefs.every((h) => !h || !/claude\.com\/plugins/i.test(h)) &&
    evidence.banner.includes('Self-serve signup') &&
    evidence.challengerDisabled &&
    !leadersVisible.some((n) => /Cavekit|Barkain|Claude Code Expert/i.test(n)) &&
    evidence.httpMeta.missingBlank === 0 &&
    overflow375.overflow <= 2;

  const report = {
    pass,
    pageErrors,
    consoleErrors: consoleErrors.slice(0, 15),
    failed404: failed.filter((u) => !/favicon/i.test(u)).slice(0, 20),
    evidence,
    leadersVisible,
    overflow375,
    screenshots: {
      after1280: path.join(OUT, 'AFTER-1280.png'),
      afterDark: path.join(OUT, 'AFTER-dark-1280.png'),
      after375: path.join(OUT, 'AFTER-375.png'),
    },
  };
  fs.writeFileSync(path.join(OUT, 'audit-AFTER.json'), JSON.stringify(report, null, 2));
  console.log(JSON.stringify(report, null, 2));
  await browser.close();
  process.exit(pass ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
