#!/usr/bin/env node
/**
 * Extract visible page text (innerText) for OCR/text-grounding gates.
 * Usage: node golden-strings.mjs [--base URL] [--out DIR] [paths...]
 */
import { createRequire } from 'module';
import { mkdirSync, writeFileSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const require = createRequire(join(__dirname, 'package.json'));
const { chromium } = require('playwright');

const REPO_ROOT = join(__dirname, '../..');
const BASE = process.env.GOLDEN_BASE_URL || 'https://sb.alolabs.dev';
const OUT_DIR = process.env.GOLDEN_OUT_DIR || join(REPO_ROOT, '.visual-audit/responsive-full/golden-strings');

const DEFAULT_PAGES = [
  { path: '/', slug: 'home', theme: 'light', width: 1280 },
  { path: '/help/getting-started/', slug: 'help-getting-started', theme: 'light', width: 375 },
];

function parseArgs() {
  const args = process.argv.slice(2);
  const pages = [];
  let base = BASE;
  let out = OUT_DIR;
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--base' && args[i + 1]) { base = args[++i]; continue; }
    if (args[i] === '--out' && args[i + 1]) { out = join(REPO_ROOT, args[++i]); continue; }
    if (args[i].startsWith('--')) continue;
    const path = args[i].startsWith('/') ? args[i] : `/${args[i]}`;
    const slug = path.replace(/^\//, '').replace(/\/$/, '').replace(/\//g, '-') || 'home';
    pages.push({ path, slug, theme: 'light', width: 1280 });
  }
  return { base, out, pages: pages.length ? pages : DEFAULT_PAGES };
}

function tokenizeVisible(text) {
  const lines = text
    .split(/\n+/)
    .map((l) => l.trim())
    .filter((l) => l.length >= 2);
  const strings = new Set(lines);
  for (const line of lines) {
    for (const part of line.split(/(?<=[.!?])\s+|\s{2,}/)) {
      const p = part.trim();
      if (p.length >= 3) strings.add(p);
    }
  }
  return [...strings].sort((a, b) => b.length - a.length);
}

async function setTheme(page, theme) {
  await page.addInitScript((t) => {
    localStorage.setItem('silver-bullet-theme', t);
    localStorage.setItem('sb-theme', t);
    document.documentElement.setAttribute('data-theme', t);
  }, theme);
}

async function extractPage(page, { path, slug, theme, width }, base) {
  await setTheme(page, theme);
  await page.setViewportSize({ width, height: 900 });
  const url = base + (path === '/' ? '/' : path);
  const response = await page.goto(url, { waitUntil: 'networkidle', timeout: 60000 });
  if (!response?.ok()) throw new Error(`HTTP ${response?.status() ?? 'fail'} for ${url}`);
  await page.waitForTimeout(400);
  const innerText = await page.evaluate(() => document.body?.innerText ?? '');
  const strings = tokenizeVisible(innerText);
  return { slug, path, url, theme, width, extractedAt: new Date().toISOString(), strings, lineCount: strings.length };
}

async function main() {
  const { base, out, pages } = parseArgs();
  mkdirSync(out, { recursive: true });
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext();
  const manifest = { baseUrl: base, pages: [] };

  for (const spec of pages) {
    const page = await context.newPage();
    try {
      const result = await extractPage(page, spec, base);
      const outFile = join(out, `${spec.slug}-golden-strings.json`);
      writeFileSync(outFile, JSON.stringify(result, null, 2));
      manifest.pages.push({ ...spec, file: outFile, stringCount: result.strings.length });
      console.log(`OK ${spec.slug} strings=${result.strings.length}`);
    } catch (err) {
      console.error(`FAIL ${spec.slug}: ${err.message}`);
      manifest.pages.push({ ...spec, error: String(err.message || err) });
    } finally {
      await page.close();
    }
  }

  await browser.close();
  writeFileSync(join(out, 'golden-manifest.json'), JSON.stringify(manifest, null, 2));
}

main().catch((e) => { console.error(e); process.exit(1); });
