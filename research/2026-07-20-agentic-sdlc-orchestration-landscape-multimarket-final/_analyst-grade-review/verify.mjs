import { chromium } from '../_adversarial-audit/node_modules/playwright/index.mjs';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const report = path.resolve(__dirname, '../landscape-report.html');
const fileUrl = 'file://' + report;
const out = { fileUrl, pass: false, checks: {}, errors: [], screenshots: [] };

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
page.on('pageerror', e => out.errors.push(String(e)));
page.on('console', msg => { if (msg.type() === 'error') out.errors.push('console:' + msg.text()); });

await page.goto(fileUrl, { waitUntil: 'domcontentloaded', timeout: 60000 });
await page.waitForTimeout(2500);

const content = await page.locator('#content').innerText().catch(() => '');
out.checks.hasContent = content.length > 5000;
out.checks.markedPinned = await page.evaluate(() => {
  const s = [...document.scripts].map(x => x.src).join(' ');
  return s.includes('marked@11.1.1') || s.includes('@11.1.1');
});
out.checks.noAgentsysAi = !(await page.content()).includes('agentsys.ai');
out.checks.hasAgentSysGithub = (await page.content()).includes('github.com/agent-sh/agentsys');
out.checks.noAwsAiDlc = !(await page.content()).includes('aws.amazon.com/ai-dlc');
out.checks.noDeepworkAi = !(await page.content()).includes('deepwork.ai');
out.checks.hasMetaGPT = content.includes('MetaGPT');
out.checks.hasClaudeHarness = content.includes('Claude Harness');
out.checks.noHarnessApoCandidate = !content.includes('Claude Harness is a primary-market APO candidate');
out.checks.saasSectionMentionsFactory = content.includes('Factory.ai') || content.includes('Factory.ai');
out.checks.underlines = await page.evaluate(() => {
  const links = [...document.querySelectorAll('#content a, .vname-link')].slice(0, 40);
  return links.filter(a => getComputedStyle(a).textDecorationLine.includes('underline')).length;
});
out.checks.overflow375 = null;

const shot = async (name, w, colorScheme='light') => {
  const ctx = await browser.newContext({ viewport: { width: w, height: 900 }, colorScheme });
  const p = await ctx.newPage();
  await p.goto(fileUrl, { waitUntil: 'domcontentloaded' });
  await p.waitForTimeout(2000);
  const fp = path.join(__dirname, name);
  await p.screenshot({ path: fp, fullPage: false });
  out.screenshots.push(name);
  if (w === 375) {
    out.checks.overflow375 = await p.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
  }
  await ctx.close();
};

await page.screenshot({ path: path.join(__dirname, 'AFTER-1280.png'), fullPage: false });
out.screenshots.push('AFTER-1280.png');
await shot('AFTER-375.png', 375);
await shot('AFTER-dark-1280.png', 1280, 'dark');

// membership from embedded payload
const membership = await page.evaluate(() => {
  const data = window.__SB_REPORT__ || JSON.parse(document.getElementById('report-data').textContent);
  const markets = data.chart_data.markets || {};
  const out = {};
  for (const [id, m] of Object.entries(markets)) {
    out[id] = {
      mq: (m.mq_data||[]).map(p => p.label + ':' + p.q),
      commercial: m.vendor_buckets?.commercial || [],
      oss: m.vendor_buckets?.oss || [],
      leaders: m.vendor_buckets?.leaders || [],
    };
  }
  out.rankings = (data.comparison?.rankings||[]).map(r => r.solution);
  return out;
});
fs.writeFileSync(path.join(__dirname, 'AFTER-membership.json'), JSON.stringify(membership, null, 2));
out.membership = membership;
out.checks.noCursorInSaasMq = !(membership['agentic-sdlc-saas']?.mq || []).some(x => x.startsWith('Cursor'));
out.checks.metaGptInApoMq = (membership.apo?.mq || []).some(x => x.startsWith('MetaGPT'));
out.checks.harnessInPluginsOss = (membership['sdlc-plugins']?.oss || []).includes('Claude Harness');
out.checks.noClaudeCodeExpertInRankings = !(membership.rankings || []).includes('claude-code-expert');
out.checks.pageErrors = out.errors.length;

out.pass = out.checks.hasContent && out.checks.markedPinned && out.checks.noAgentsysAi &&
  out.checks.hasAgentSysGithub && out.checks.noAwsAiDlc && out.checks.metaGptInApoMq &&
  out.checks.noCursorInSaasMq && out.checks.harnessInPluginsOss &&
  out.checks.noClaudeCodeExpertInRankings && out.checks.underlines === 0 &&
  (out.checks.overflow375 === 0 || out.checks.overflow375 === null) &&
  out.errors.length === 0;

fs.writeFileSync(path.join(__dirname, 'verify-result.json'), JSON.stringify(out, null, 2));
console.log(JSON.stringify(out, null, 2));
await browser.close();
process.exit(out.pass ? 0 : 1);
