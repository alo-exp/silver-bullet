#!/usr/bin/env node
import { createRequire } from 'module';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const require = createRequire(join(__dirname, 'package.json'));
const { chromium } = require('playwright');

const BASE = process.env.OVERFLOW_BASE_URL || 'https://sb.alolabs.dev';
const pages = process.argv.slice(2).length
  ? process.argv.slice(2)
  : [
      '/help/workflows/',
      '/help/concepts/routing-logic.html',
      '/help/concepts/composable-workflow.html',
      '/help/workflows/silver-ship-readiness.html',
      '/help/workflows/silver-review-triad.html',
      '/help/reference/',
      '/help/concepts/',
      '/help/concepts/documentation.html',
      '/help/workflows/silver-forensics.html',
      '/help/workflows/silver-process-maintenance.html',
      '/help/workflows/silver-incident.html',
      '/help/workflows/silver-research.html',
      '/help/workflows/silver-retro.html',
      '/help/workflows/silver-feature.html',
      '/help/concepts/cost-optimization.html',
      '/help/concepts/preferences.html',
      '/help/troubleshooting/',
      '/help/dev-workflow/',
      '/help/workflows/silver-benchmark.html',
      '/gaps/',
      '/changelog/',
    ];

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage();
let issues = 0;

for (const url of pages) {
  await page.setViewportSize({ width: 375, height: 900 });
  await page.goto(BASE + url, { waitUntil: 'networkidle', timeout: 60000 });
  const overflow = await page.evaluate(
    () => document.documentElement.scrollWidth - document.documentElement.clientWidth
  );
  const flag = overflow > 1 ? 'FAIL' : 'PASS';
  if (overflow > 1) issues++;
  console.log(`${flag} ${url} overflow=${overflow}px`);
}

await browser.close();
console.log(`Total failures: ${issues}`);
process.exit(issues > 0 ? 1 : 0);
