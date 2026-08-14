import { chromium } from 'playwright';
import fs from 'fs';
import path from 'path';
import { fileURLToPath, pathToFileURL } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '..');
const htmlPath = path.join(root, 'landscape-report.html');
const fileUrl = pathToFileURL(htmlPath).href;
const outDir = __dirname;

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
const errors = [];
page.on('pageerror', e => errors.push(String(e)));
page.on('console', msg => { if (msg.type() === 'error') errors.push(msg.text()); });

await page.goto(fileUrl, { waitUntil: 'domcontentloaded', timeout: 60000 });
await page.waitForTimeout(2500);

const bodyFw = await page.evaluate(() => getComputedStyle(document.body).fontWeight);
const pFw = await page.evaluate(() => {
  const p = document.querySelector('p, .md-body, article p, #content p, main p');
  return p ? getComputedStyle(p).fontWeight : null;
});
const h1Fw = await page.evaluate(() => {
  const h = document.querySelector('h1');
  return h ? getComputedStyle(h).fontWeight : null;
});

const linkStats = await page.evaluate(() => {
  const links = [...document.querySelectorAll('a.vc-name-link, a.vname-link, .vendor-card a[href^="http"], a[href^="http"].card-title')];
  const sample = links.slice(0, 15).map(a => ({
    text: (a.textContent||'').trim().slice(0,40),
    href: a.href,
    target: a.target,
    rel: a.rel,
    td: getComputedStyle(a).textDecorationLine,
  }));
  const underlined = sample.filter(s => s.td && s.td !== 'none');
  const badTarget = sample.filter(s => s.href.startsWith('http') && s.target !== '_blank');
  return { count: links.length, sample, underlined: underlined.length, badTarget: badTarget.length };
});

const cardIds = await page.evaluate(() => {
  const nodes = [...document.querySelectorAll('[id^="vendor-"]')];
  const ids = nodes.map(n => n.id);
  const sb = ids.filter(id => id.includes('silver-bullet'));
  return { total: ids.length, unique: new Set(ids).size, sb, hasDup: ids.length !== new Set(ids).size };
});

const marked = await page.evaluate(() => {
  const s = [...document.scripts].map(x => x.src).find(u => u && u.includes('marked'));
  return s || null;
});

await page.screenshot({ path: path.join(outDir, 'spa-light-1280.png'), fullPage: false });

await page.evaluate(() => {
  document.documentElement.setAttribute('data-theme', 'dark');
  document.documentElement.classList.add('dark');
  document.body.classList.add('theme-dark', 'dark');
});
await page.waitForTimeout(400);
const darkLink = await page.evaluate(() => {
  const a = document.querySelector('a.vc-name-link, a.vname-link, .vendor-card a[href^="http"]');
  if (!a) return null;
  return { color: getComputedStyle(a).color, href: a.href, text: (a.textContent||'').trim().slice(0,30) };
});
await page.screenshot({ path: path.join(outDir, 'spa-dark-1280.png'), fullPage: false });

const result = {
  pass: errors.filter(e => !/favicon|cdn|font/i.test(e)).length === 0
    && linkStats.underlined === 0
    && bodyFw === '300'
    && (cardIds.sb.length >= 1)
    && !cardIds.hasDup
    && marked && marked.includes('marked@11.1.1'),
  fileUrl,
  errors,
  bodyFw, pFw, h1Fw,
  linkStats,
  cardIds,
  marked,
  darkLink,
};
fs.writeFileSync(path.join(outDir, 'playwright-verify.json'), JSON.stringify(result, null, 2));
console.log(JSON.stringify(result, null, 2));
await browser.close();
process.exit(result.pass ? 0 : 2);
