#!/usr/bin/env node
import { chromium } from 'playwright';
import { mkdirSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const outDir = join(__dirname, 'sticky-screenshots');
mkdirSync(outDir, { recursive: true });

const url = process.argv[2] || 'http://localhost:9876/feature-coverage-matrix.html';
const label = process.argv[3] || 'before';

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
await page.goto(url, { waitUntil: 'networkidle' });

// Scroll so first table header is sticky below page header
await page.evaluate(() => {
  const section = document.querySelector('#core-purpose-architecture');
  if (section) section.scrollIntoView({ block: 'start' });
});
await page.waitForTimeout(300);
await page.evaluate(() => window.scrollBy(0, 120));
await page.waitForTimeout(300);

const metrics = await page.evaluate(() => {
  const header = document.querySelector('header');
  const th = document.querySelector('#core-purpose-architecture thead th');
  const rows = [...document.querySelectorAll('#core-purpose-architecture tbody tr')].slice(0, 3);
  const hr = header?.getBoundingClientRect();
  const thr = th?.getBoundingClientRect();
  const rowRects = rows.map((r, i) => {
    const rect = r.getBoundingClientRect();
    const firstCell = r.querySelector('td');
    return {
      row: i + 1,
      top: rect.top,
      bottom: rect.bottom,
      text: firstCell?.textContent?.slice(0, 50),
      overlapsHeader: thr ? rect.top < thr.bottom && rect.bottom > thr.top : false,
    };
  });
  return {
    pageHeaderHeight: hr?.height,
    pageHeaderBottom: hr?.bottom,
    theadTop: thr?.top,
    theadBottom: thr?.bottom,
    theadStickyTop: th ? getComputedStyle(th).top : null,
    rowRects,
  };
});

console.log(JSON.stringify(metrics, null, 2));

await page.screenshot({ path: join(outDir, `${label}-section1-scroll.png`), fullPage: false });

// Second section mid-scroll
await page.evaluate(() => {
  const section = document.querySelector('#compression-token-reduction-shell-read-mcp-wire-fetch-batch');
  if (section) section.scrollIntoView({ block: 'start' });
});
await page.waitForTimeout(300);
await page.evaluate(() => window.scrollBy(0, 80));
await page.waitForTimeout(300);
await page.screenshot({ path: join(outDir, `${label}-section2-scroll.png`), fullPage: false });

await browser.close();
console.log(`Screenshots saved to ${outDir}/${label}-*.png`);
