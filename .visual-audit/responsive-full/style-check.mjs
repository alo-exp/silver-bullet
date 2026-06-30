#!/usr/bin/env node
/**
 * Playwright computed-style gates for known visual markers.
 * Usage: node style-check.mjs [--base URL] [paths...]
 */
import { createRequire } from 'module';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const require = createRequire(join(__dirname, 'package.json'));
const { chromium } = require('playwright');

const BASE = process.env.STYLE_BASE_URL || 'https://sb.alolabs.dev';

const MARKERS = [
  { selector: '.hero-tagline-thin', property: 'fontWeight', expected: '400', page: '/', kind: 'exact' },
  { selector: '.hero-tagline-thin', property: 'letterSpacing', page: '/', kind: 'letter-spacing-em', emFactor: 0.26 },
];

async function setTheme(page, theme = 'light') {
  await page.addInitScript((t) => {
    localStorage.setItem('silver-bullet-theme', t);
    localStorage.setItem('sb-theme', t);
    document.documentElement.setAttribute('data-theme', t);
  }, theme);
}

async function main() {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  await setTheme(page, 'light');
  await page.setViewportSize({ width: 1280, height: 900 });
  let failures = 0;

  for (const marker of MARKERS) {
    await page.goto(BASE + marker.page, { waitUntil: 'networkidle', timeout: 60000 });
    await page.waitForTimeout(300);
    let pass;
    let detail;
    if (marker.kind === 'letter-spacing-em') {
      const result = await page.evaluate(({ selector, emFactor }) => {
        const el = document.querySelector(selector);
        if (!el) return { pass: false, detail: 'MISSING' };
        const cs = getComputedStyle(el);
        const fontSize = parseFloat(cs.fontSize);
        const expectedPx = fontSize * emFactor;
        const actualPx = cs.letterSpacing === 'normal' ? 0 : parseFloat(cs.letterSpacing);
        return {
          pass: Math.abs(actualPx - expectedPx) < 0.5,
          detail: `letter-spacing=${actualPx}px (expected ~${expectedPx.toFixed(2)}px from ${emFactor}em)`,
        };
      }, marker);
      pass = result.pass;
      detail = result.detail;
    } else {
      const actual = await page.evaluate(({ selector, property }) => {
        const el = document.querySelector(selector);
        if (!el) return null;
        return getComputedStyle(el)[property];
      }, marker);
      const norm = (v) => (v == null ? 'MISSING' : String(v).trim());
      pass = norm(actual) === marker.expected;
      detail = `${marker.property}=${norm(actual)} (expected ${marker.expected})`;
    }
    if (!pass) failures++;
    console.log(`${pass ? 'PASS' : 'FAIL'} ${marker.selector} ${detail}`);
  }

  await browser.close();
  process.exit(failures > 0 ? 1 : 0);
}

main().catch((e) => { console.error(e); process.exit(1); });
