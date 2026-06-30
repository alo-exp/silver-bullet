#!/usr/bin/env node
/** Deep responsive checks: overflow, theme, nav */
import { createRequire } from 'module';
import { readFileSync, writeFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const require = createRequire(join(__dirname, 'package.json'));
const { chromium } = require('playwright');

const manifest = JSON.parse(readFileSync(join(__dirname, '2026-06-30/capture-manifest.json'), 'utf8'));
const BASE = manifest.baseUrl;
const OUT = join(__dirname, '2026-06-30/deep-checks.json');

async function auditPage(page, url, slug) {
  const results = {};
  for (const width of [375, 768, 1280]) {
    await page.setViewportSize({ width, height: 900 });
    for (const theme of ['light', 'dark']) {
      await page.addInitScript((t) => {
        localStorage.setItem('silver-bullet-theme', t);
        document.documentElement.setAttribute('data-theme', t);
      }, theme);
      await page.goto(BASE + (url === '/' ? '/' : url), { waitUntil: 'networkidle', timeout: 60000 });
      await page.waitForTimeout(300);

      const metrics = await page.evaluate(() => {
        const html = document.documentElement;
        const navToggle = document.querySelector('.nav-toggle, #nav-toggle, [aria-label*="menu" i]');
        const themeBtn = document.querySelector('#theme-toggle, .help-theme-btn, .theme-btn');
        const search = document.querySelector('#help-search, .help-search input, input[type="search"]');
        return {
          scrollWidth: html.scrollWidth,
          clientWidth: html.clientWidth,
          pageHScroll: html.scrollWidth > html.clientWidth + 1,
          theme: html.getAttribute('data-theme'),
          hasNavToggle: !!navToggle,
          navToggleVisible: navToggle ? getComputedStyle(navToggle).display !== 'none' : false,
          hasThemeBtn: !!themeBtn,
          hasSearch: !!search,
          tableWraps: [...document.querySelectorAll('.table-wrap')].length,
          codeBlocks: [...document.querySelectorAll('.code-block, pre')].length,
        };
      });

      // Test theme toggle
      let themeToggleWorks = null;
      const themeBtn = page.locator('#theme-toggle, .help-theme-btn, .theme-btn').first();
      if (await themeBtn.count()) {
        const before = await page.evaluate(() => document.documentElement.getAttribute('data-theme'));
        await themeBtn.click();
        await page.waitForTimeout(200);
        const after = await page.evaluate(() => document.documentElement.getAttribute('data-theme'));
        themeToggleWorks = before !== after;
        // restore
        await page.evaluate((t) => {
          localStorage.setItem('silver-bullet-theme', t);
          document.documentElement.setAttribute('data-theme', t);
        }, theme);
      }

      results[`${width}-${theme}`] = { ...metrics, themeToggleWorks };
    }
  }
  return results;
}

async function main() {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  const all = {};
  const sample = manifest.pages;
  for (const p of sample) {
    process.stderr.write(`deep-check ${p.slug}\n`);
    all[p.slug] = await auditPage(page, p.url, p.slug);
  }
  await browser.close();
  writeFileSync(OUT, JSON.stringify(all, null, 2));

  let h375 = 0, themeFail = 0, navMissing375 = 0;
  for (const [slug, checks] of Object.entries(all)) {
    for (const [k, v] of Object.entries(checks)) {
      if (k.startsWith('375') && v.pageHScroll) h375++;
      if (v.themeToggleWorks === false) themeFail++;
      if (k.startsWith('375') && !v.navToggleVisible && v.hasNavToggle) navMissing375++;
    }
  }
  console.log(JSON.stringify({ pages: sample.length, hScroll375: h375, themeToggleFails: themeFail, out: OUT }));
}

main().catch((e) => { console.error(e); process.exit(1); });
