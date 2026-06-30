#!/usr/bin/env node
/**
 * Responsive visual QA capture matrix for sb.alolabs.dev
 * Usage: node .visual-audit/responsive-full/capture-matrix.mjs
 */
import { createRequire } from 'module';
import { readdirSync, statSync, mkdirSync, writeFileSync } from 'fs';
import { join, relative, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const require = createRequire(join(__dirname, 'package.json'));
const { chromium } = require('playwright');

const REPO_ROOT = join(__dirname, '../..');
const SITE_ROOT = join(REPO_ROOT, 'site');
const OUT_DIR = process.env.CAPTURE_OUT_DIR
  ? join(REPO_ROOT, process.env.CAPTURE_OUT_DIR)
  : join(REPO_ROOT, '.visual-audit/responsive-full/2026-06-30-post-fix');
const BASE_URL = 'https://sb.alolabs.dev';
const WIDTHS = [375, 768, 1280];
const THEMES = ['light', 'dark'];
const MAX_FULL_PAGE_HEIGHT = 12000;

function discoverPages() {
  const skip = new Set([
    'site/_chrome/footer.html',
    'site/_chrome/nav.html',
    'site/_chrome/help-subnav.html',
    'site/og-card.html',
    'site/graphify-out/graph.html',
  ]);

  function walk(dir, acc = []) {
    for (const ent of readdirSync(dir)) {
      const full = join(dir, ent);
      if (statSync(full).isDirectory()) {
        walk(full, acc);
      } else if (ent.endsWith('.html')) {
        const rel = relative(REPO_ROOT, full).replace(/\\/g, '/');
        if (!skip.has(rel)) acc.push(rel);
      }
    }
    return acc;
  }

  return walk(SITE_ROOT).sort();
}

function fileToUrl(relPath) {
  const siteRel = relPath.replace(/^site\//, '');
  if (siteRel === 'index.html') return '/';
  if (siteRel.endsWith('/index.html')) {
    return '/' + siteRel.slice(0, -'index.html'.length);
  }
  return '/' + siteRel;
}

function fileToSlug(relPath) {
  let s = relPath.replace(/^site\//, '').replace(/\.html$/, '');
  if (s === 'index') return 'home';
  if (s.endsWith('/index')) s = s.slice(0, -'/index'.length) || 'home';
  return s.replace(/\//g, '-');
}

async function setTheme(page, theme) {
  await page.addInitScript((t) => {
    localStorage.setItem('silver-bullet-theme', t);
    localStorage.setItem('sb-theme', t);
    document.documentElement.setAttribute('data-theme', t);
  }, theme);
}

async function capturePage(page, url, slug, width, theme, metrics) {
  await setTheme(page, theme);
  await page.setViewportSize({ width, height: 900 });
  const fullUrl = BASE_URL + (url === '/' ? '/' : url);
  const response = await page.goto(fullUrl, { waitUntil: 'networkidle', timeout: 60000 });
  if (!response || !response.ok()) {
    metrics.push({ url: fullUrl, width, theme, error: `HTTP ${response?.status() ?? 'fail'}` });
    return;
  }
  await page.waitForTimeout(400);

  const scrollInfo = await page.evaluate(() => ({
    scrollWidth: document.documentElement.scrollWidth,
    clientWidth: document.documentElement.clientWidth,
    scrollHeight: document.documentElement.scrollHeight,
  }));

  const hasHScroll = scrollInfo.scrollWidth > scrollInfo.clientWidth + 1;
  const filename = `${slug}-${theme}-${width}px.png`;
  const outPath = join(OUT_DIR, filename);

  if (scrollInfo.scrollHeight <= MAX_FULL_PAGE_HEIGHT) {
    await page.screenshot({ path: outPath, fullPage: true });
    metrics.push({
      url: fullUrl, slug, width, theme, filename,
      capture: 'full-page',
      scrollHeight: scrollInfo.scrollHeight,
      hasHScroll,
    });
  } else {
    // Pragmatic: hero + mid content + footer sections
    const sections = [
      { suffix: 'hero', y: 0 },
      { suffix: 'mid', y: Math.floor(scrollInfo.scrollHeight * 0.45) },
      { suffix: 'footer', y: Math.max(0, scrollInfo.scrollHeight - 900) },
    ];
    for (const sec of sections) {
      await page.evaluate((y) => window.scrollTo(0, y), sec.y);
      await page.waitForTimeout(200);
      const secName = `${slug}-${theme}-${width}px-${sec.suffix}.png`;
      await page.screenshot({ path: join(OUT_DIR, secName), fullPage: false });
    }
    metrics.push({
      url: fullUrl, slug, width, theme,
      filename: `${slug}-${theme}-${width}px-{hero,mid,footer}.png`,
      capture: 'sectioned',
      scrollHeight: scrollInfo.scrollHeight,
      hasHScroll,
    });
  }
}

async function main() {
  mkdirSync(OUT_DIR, { recursive: true });
  const pages = discoverPages();
  const manifest = { baseUrl: BASE_URL, capturedAt: new Date().toISOString(), pages: [], metrics: [] };

  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ deviceScaleFactor: 1 });

  let count = 0;
  const total = pages.length * WIDTHS.length * THEMES.length;

  for (const rel of pages) {
    const url = fileToUrl(rel);
    const slug = fileToSlug(rel);
    manifest.pages.push({ rel, url, slug });

    for (const width of WIDTHS) {
      for (const theme of THEMES) {
        count++;
        process.stderr.write(`[${count}/${total}] ${slug} ${width}px ${theme}\n`);
        const page = await context.newPage();
        try {
          await capturePage(page, url, slug, width, theme, manifest.metrics);
        } catch (err) {
          manifest.metrics.push({ url: BASE_URL + url, slug, width, theme, error: String(err.message || err) });
        } finally {
          await page.close();
        }
      }
    }
  }

  await browser.close();
  writeFileSync(join(OUT_DIR, 'capture-manifest.json'), JSON.stringify(manifest, null, 2));
  console.log(JSON.stringify({ outDir: OUT_DIR, pages: pages.length, captures: count, hScrollIssues: manifest.metrics.filter(m => m.hasHScroll).length }));
}

main().catch((e) => { console.error(e); process.exit(1); });
