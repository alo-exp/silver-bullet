#!/usr/bin/env node
// Render the landscape print HTML to a PDF in a sandboxed, script-free, offline Chromium.
//
// usage: node render_landscape_pdf.cjs <file:// print.html> <out.pdf> <timeout-ms> <wait-selector>
//
// Unlike `playwright pdf` (which launches Chromium with --no-sandbox), this launches with
// chromiumSandbox:true, disables JavaScript and aborts every request that is not file://.
// SB_LANDSCAPE_PDF_NO_SANDBOX=1 is an explicit, logged opt-out for containers running as root.
'use strict';

const [, , url, out, timeoutArg, selector] = process.argv;
const timeout = Number(timeoutArg) || 120000;

function load() {
  try {
    return require('playwright');
  } catch (err) {
    console.error('playwright module not found (set NODE_PATH or npm install playwright): ' + err.message);
    process.exit(3);
  }
}

(async () => {
  const { chromium } = load();
  const noSandbox = process.env.SB_LANDSCAPE_PDF_NO_SANDBOX === '1';
  if (noSandbox) console.error('WARNING: rendering the landscape PDF without the Chromium sandbox (SB_LANDSCAPE_PDF_NO_SANDBOX=1)');
  let browser;
  try {
    browser = await chromium.launch({ chromiumSandbox: !noSandbox });
  } catch (err) {
    console.error(
      'Chromium could not start with its sandbox: ' + String(err.message).split('\n')[0] +
      '\nInstall Chromium for Playwright and run as a non-root user, or set SB_LANDSCAPE_PDF_NO_SANDBOX=1 to accept an unsandboxed render.'
    );
    process.exit(4);
  }
  try {
    const context = await browser.newContext({ javaScriptEnabled: false, offline: true });
    await context.route('**/*', (route) => (route.request().url().startsWith('file://') ? route.continue() : route.abort()));
    const page = await context.newPage();
    await page.goto(url, { timeout, waitUntil: 'load' });
    if (selector) await page.waitForSelector(selector, { timeout });
    await page.pdf({ path: out, format: 'A4', printBackground: true });
  } finally {
    await browser.close();
  }
})().catch((err) => {
  console.error(String(err && err.stack || err));
  process.exit(1);
});
