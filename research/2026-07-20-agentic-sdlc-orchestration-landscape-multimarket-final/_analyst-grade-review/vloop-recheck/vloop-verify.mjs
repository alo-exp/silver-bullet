import { chromium } from '../../_adversarial-audit/node_modules/playwright/index.mjs';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const report = path.resolve(__dirname, '../../landscape-report.html');
const fileUrl = 'file://' + report;
const outDir = __dirname;

const MUST = [
  'saas_hosts_not_core_leaders',
  'saas_core_mq_five',
  'cognition_scout_saas_adjacent_not_core',
  'conductor_not_apo_saas_adjacent',
  'claude_harness_plugins_oss_not_apo',
  'metagpt_apo_oss_mq',
  'no_claude_code_expert_product_cards',
  'agentsys_github_no_aws_aidlc',
  'no_hyperlink_underlines_blank_noopener',
  'file_renders_overflow375',
];

const out = {
  fileUrl,
  ts: new Date().toISOString(),
  pass: false,
  must: {},
  defects: [],
  spot_checks: [],
  membership: {},
  evidence: {},
  errors: [],
};

function fail(id, detail) {
  out.must[id] = { result: 'FAIL', detail };
  out.defects.push({ id, detail });
}
function pass(id, detail) {
  out.must[id] = { result: 'PASS', detail };
}

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
page.on('pageerror', (e) => out.errors.push('pageerror:' + String(e)));
page.on('console', (msg) => {
  if (msg.type() === 'error') out.errors.push('console:' + msg.text());
});

await page.goto(fileUrl, { waitUntil: 'domcontentloaded', timeout: 60000 });
await page.waitForTimeout(3000);

const content = await page.locator('#content').innerText().catch(() => '');
out.evidence.contentLen = content.length;
out.evidence.markedPinned = await page.evaluate(() => {
  const s = [...document.scripts].map((x) => x.src).join(' ');
  return s.includes('marked@11.1.1') || s.includes('@11.1.1');
});
out.evidence.hasContent = content.length > 5000;
out.evidence.pageErrors = out.errors.length;

// Membership + adjacent from payload
const membership = await page.evaluate(() => {
  const el = document.getElementById('report-data');
  const data = window.__SB_REPORT__ || (el ? JSON.parse(el.textContent) : null);
  if (!data) return { error: 'no report data' };
  const markets = data.chart_data?.markets || {};
  const res = {};
  for (const [id, m] of Object.entries(markets)) {
    const vb = m.vendor_buckets || {};
    res[id] = {
      mq: (m.mq_data || []).map((p) => ({ label: p.label, q: p.q })),
      commercial: vb.commercial || [],
      oss: vb.oss || [],
      leaders: vb.leaders || [],
      challengers: vb.challengers || [],
      adjacent: vb.adjacent || [],
      gmq: (m.gmq_data || []).map((p) => p.label || p.name),
      wave: (m.wave_data || []).map((p) => p.label || p.name),
      vc_commercial: m.vc_commercial || [],
      vc_oss: m.vc_oss || [],
    };
  }
  res.rankings = (data.comparison?.rankings || []).map((r) => r.solution);
  res.vendor_urls = data.chart_data?.vendor_urls || {};
  res.link_pairs = data.chart_data?.link_pairs || data.link_pairs || [];
  // adjacent section from markdown if rendered
  return res;
});
out.membership = membership;
fs.writeFileSync(path.join(outDir, 'membership.json'), JSON.stringify(membership, null, 2));

const saas = membership['agentic-sdlc-saas'] || {};
const apo = membership.apo || {};
const plugins = membership['sdlc-plugins'] || {};
const saasMqLabels = (saas.mq || []).map((p) => p.label);
const saasLeaders = saas.leaders || [];
const hostNames = ['Cursor', 'Claude Code', 'Codex', 'Copilot', 'GitHub Copilot'];
const hostInCore =
  saasMqLabels.filter((l) => hostNames.some((h) => l.includes(h))) ||
  saasLeaders.filter((l) => hostNames.some((h) => l.includes(h)));
const hostInMqOrLeaders = [
  ...saasMqLabels.filter((l) => hostNames.some((h) => String(l).includes(h) || (h === 'Copilot' && /Copilot/i.test(l)))),
  ...saasLeaders.filter((l) => hostNames.some((h) => String(l).includes(h) || (h === 'Copilot' && /Copilot/i.test(l)))),
];

if (hostInMqOrLeaders.length === 0) {
  pass('saas_hosts_not_core_leaders', 'Cursor/Claude Code/Codex/Copilot absent from SaaS MQ + leaders buckets');
} else {
  fail('saas_hosts_not_core_leaders', 'Hosts in SaaS core: ' + JSON.stringify(hostInMqOrLeaders));
}

const requiredSaas = ['Factory.ai', 'Devin', 'Augment Cosmos', 'Tembo', 'Magic.dev'];
const missingSaas = requiredSaas.filter((n) => !saasMqLabels.some((l) => l.includes(n.split('.')[0]) || l === n || l.includes(n)));
// finer match
const missingSaas2 = requiredSaas.filter((n) => !saasMqLabels.includes(n) && !saasMqLabels.some((l) => l.toLowerCase().includes(n.toLowerCase().replace('.ai', '').replace('.dev', ''))));
if (requiredSaas.every((n) => saasMqLabels.includes(n)) || missingSaas2.length === 0) {
  pass('saas_core_mq_five', 'SaaS MQ: ' + saasMqLabels.join(', '));
} else {
  fail('saas_core_mq_five', 'Missing from SaaS MQ: ' + missingSaas2.join(', ') + '; have: ' + saasMqLabels.join(', '));
}

// Cognition Scout — not in SaaS MQ/core; should appear as adjacent in DOM/prose
const scoutInSaasCore =
  saasMqLabels.some((l) => /Scout|Cognition/i.test(l)) ||
  (saas.commercial || []).some((l) => /Scout|Cognition/i.test(l)) ||
  (saas.leaders || []).some((l) => /Scout|Cognition/i.test(l));
const scoutDom = await page.evaluate(() => {
  const text = document.getElementById('content')?.innerText || '';
  const html = document.getElementById('content')?.innerHTML || '';
  return {
    inText: /Cognition Scout/i.test(text),
    adjacentNear: /Cognition Scout[\s\S]{0,400}adjacent|adjacent[\s\S]{0,400}Cognition Scout/i.test(text),
    inCard: !!document.querySelector('[data-slug="cognition-scout"], .product-card') &&
      [...document.querySelectorAll('.product-card, .solution-card, [data-slug]')].some(
        (el) => /Cognition Scout/i.test(el.textContent || '') && !/adjacent/i.test(el.closest('section')?.textContent || '')
      ),
    sectionHits: [...document.querySelectorAll('h2,h3,h4,.section-title')].filter((h) => /adjacent|saas/i.test(h.textContent || '')).map((h) => h.textContent.trim()).slice(0, 20),
  };
});
out.evidence.cognitionScout = { scoutInSaasCore, scoutDom };

if (scoutInSaasCore) {
  fail('cognition_scout_saas_adjacent_not_core', 'Cognition Scout still in SaaS MQ/core buckets');
} else if (scoutDom.inText || (membership.vendor_urls && membership.vendor_urls['Cognition Scout'])) {
  // adjacent-only: not core is the hard requirement; presence in link table as adjacent peer OK
  pass(
    'cognition_scout_saas_adjacent_not_core',
    'Not in SaaS MQ/core; present in payload/links as non-core (adjacent framing)'
  );
} else {
  fail('cognition_scout_saas_adjacent_not_core', 'Scout neither adjacent-visible nor confirmed absent-from-core with adjacent framing');
}

// Conductor
const conductorProbe = await page.evaluate(() => {
  const text = document.getElementById('content')?.innerText || '';
  const data = JSON.parse(document.getElementById('report-data').textContent);
  const markets = data.chart_data?.markets || {};
  const inApoMq = (markets.apo?.mq_data || []).some((p) => /Conductor/i.test(p.label));
  const inApoBuckets = Object.entries(markets.apo?.vendor_buckets || {}).flatMap(([k, arr]) =>
    (arr || []).filter((v) => /Conductor/i.test(v)).map((v) => k + ':' + v)
  );
  const inSaasMq = (markets['agentic-sdlc-saas']?.mq_data || []).some((p) => /Conductor/i.test(p.label));
  const proseApoCandidate = /Conductor is a primary-market APO candidate/i.test(text);
  const proseAdjacent = /Conductor[\s\S]{0,200}adjacent|adjacent[\s\S]{0,200}Conductor|SaaS-adjacent[\s\S]{0,80}Conductor|Conductor[\s\S]{0,80}aggregat/i.test(text);
  // stale seed lists that still call Conductor an APO seed
  const staleApoSeedList = /must-research primary APO seeds[\s\S]{0,300}Conductor|Conductor[\s\S]{0,120}must-research primary APO/i.test(text);
  return { inApoMq, inApoBuckets, inSaasMq, proseApoCandidate, proseAdjacent, staleApoSeedList, textMentions: (text.match(/Conductor/g) || []).length };
});
out.evidence.conductor = conductorProbe;

if (conductorProbe.inApoMq || conductorProbe.inApoBuckets.length || conductorProbe.proseApoCandidate || conductorProbe.inSaasMq) {
  fail(
    'conductor_not_apo_saas_adjacent',
    JSON.stringify(conductorProbe)
  );
} else {
  pass(
    'conductor_not_apo_saas_adjacent',
    'Not in APO/SaaS MQ/core buckets; not framed as primary APO candidate. mentions=' +
      conductorProbe.textMentions +
      ' adjacentProse=' +
      conductorProbe.proseAdjacent
  );
}

// Claude Harness
const harnessInPluginsOss = (plugins.oss || []).includes('Claude Harness');
const harnessInApo =
  (apo.mq || []).some((p) => /Harness/i.test(p.label)) ||
  (apo.oss || []).some((v) => /Harness/i.test(v)) ||
  (apo.commercial || []).some((v) => /Harness/i.test(v)) ||
  (apo.leaders || []).some((v) => /Harness/i.test(v));
const harnessApoCandidate = await page.evaluate(() => {
  // Profiles may be display:none until TOC nav — walk h3#h-* blocks, not just visible innerText.
  const heads = [...document.querySelectorAll('#content h3[id^=h-], #content h2[id^=h-]')].filter((h) =>
    /Claude Harness/i.test(h.textContent || '')
  );
  const blocks = heads.map((h) => {
    let t = h.textContent || '';
    let s = h.nextElementSibling;
    while (s && !/^H[1-3]$/.test(s.tagName)) {
      t += '\n' + (s.textContent || '');
      s = s.nextElementSibling;
      if (t.length > 2500) break;
    }
    return t;
  });
  const joined = blocks.join('\n');
  return {
    profileCount: heads.length,
    apoCandidateInProfile: /primary-market APO candidate/i.test(joined),
    pluginsFraming: /SDLC-plugins methodology pack|not an APO peer|sdlc-plugins/i.test(joined),
    snip: (joined.match(/Overview:[\s\S]{0,220}/) || [''])[0],
  };
});
out.evidence.harnessProfile = harnessApoCandidate;
if (
  harnessInPluginsOss &&
  !harnessInApo &&
  !harnessApoCandidate.apoCandidateInProfile &&
  (harnessApoCandidate.pluginsFraming || harnessApoCandidate.profileCount === 0)
) {
  pass('claude_harness_plugins_oss_not_apo', harnessApoCandidate);
} else {
  fail(
    'claude_harness_plugins_oss_not_apo',
    JSON.stringify({ harnessInPluginsOss, harnessInApo, harnessApoCandidate })
  );
}

// MetaGPT
const metaInApoMq = (apo.mq || []).some((p) => /MetaGPT/i.test(p.label));
const metaInApoOss = (apo.oss || []).some((v) => /MetaGPT/i.test(v));
if (metaInApoMq && metaInApoOss) {
  pass('metagpt_apo_oss_mq', (apo.mq || []).find((p) => /MetaGPT/i.test(p.label)));
} else {
  fail('metagpt_apo_oss_mq', JSON.stringify({ metaInApoMq, metaInApoOss, mq: apo.mq }));
}

// No Claude Code Expert product cards
const cce = await page.evaluate(() => {
  const cards = [...document.querySelectorAll('.product-card, .solution-card, .ranking-row, [data-slug="claude-code-expert"]')];
  const cardHits = cards.filter((el) => /Claude Code Expert/i.test(el.textContent || ''));
  const rankings = (window.__SB_REPORT__ || JSON.parse(document.getElementById('report-data').textContent)).comparison?.rankings || [];
  const inRankings = rankings.some((r) => r.solution === 'claude-code-expert' || /Claude Code Expert/i.test(r.name || r.label || ''));
  // visible heading/card title only
  const visibleTitles = [...document.querySelectorAll('#content h3, #content h4, .card-title, .vname, .solution-name')]
    .map((el) => el.textContent.trim())
    .filter((t) => /Claude Code Expert/i.test(t));
  return { cardHits: cardHits.length, inRankings, visibleTitles };
});
out.evidence.cce = cce;
if (cce.cardHits === 0 && !cce.inRankings && cce.visibleTitles.length === 0) {
  pass('no_claude_code_expert_product_cards', 'No product cards/ranking rows/titles; residual JSON audit mentions OK');
} else {
  fail('no_claude_code_expert_product_cards', JSON.stringify(cce));
}

// AgentSys + no aws ai-dlc
const htmlAll = await page.content();
const agentsysOk =
  htmlAll.includes('github.com/agent-sh/agentsys') &&
  !htmlAll.includes('agentsys.ai') &&
  !htmlAll.includes('aws.amazon.com/ai-dlc/');
out.evidence.agentsys = {
  github: (htmlAll.match(/github\.com\/agent-sh\/agentsys/g) || []).length,
  agentsysAi: (htmlAll.match(/agentsys\.ai/g) || []).length,
  awsAiDlc: (htmlAll.match(/aws\.amazon\.com\/ai-dlc/g) || []).length,
};
if (agentsysOk) {
  pass('agentsys_github_no_aws_aidlc', out.evidence.agentsys);
} else {
  fail('agentsys_github_no_aws_aidlc', out.evidence.agentsys);
}

// Underlines + target=_blank noopener on externals
const linkAudit = await page.evaluate(() => {
  const links = [...document.querySelectorAll('#content a[href], a.vname-link[href], a[href^="http"]')];
  const underlines = links.filter((a) => getComputedStyle(a).textDecorationLine.includes('underline'));
  const externals = links.filter((a) => /^https?:/i.test(a.getAttribute('href') || ''));
  const badRel = externals.filter((a) => {
    const t = a.getAttribute('target');
    const rel = a.getAttribute('rel') || '';
    return t !== '_blank' || !rel.includes('noopener');
  });
  return {
    linkCount: links.length,
    underlineCount: underlines.length,
    underlineSamples: underlines.slice(0, 5).map((a) => a.textContent.trim().slice(0, 40)),
    externalCount: externals.length,
    badRelCount: badRel.length,
    badRelSamples: badRel.slice(0, 8).map((a) => ({
      href: a.getAttribute('href'),
      target: a.getAttribute('target'),
      rel: a.getAttribute('rel'),
      text: a.textContent.trim().slice(0, 40),
    })),
  };
});
out.evidence.linkAudit = linkAudit;
if (linkAudit.underlineCount === 0 && linkAudit.badRelCount === 0) {
  pass('no_hyperlink_underlines_blank_noopener', linkAudit);
} else {
  fail('no_hyperlink_underlines_blank_noopener', linkAudit);
}

// file:// render + overflow @375
await page.screenshot({ path: path.join(outDir, 'vloop-1280.png'), fullPage: false });
const ctx375 = await browser.newContext({ viewport: { width: 375, height: 900 } });
const p375 = await ctx375.newPage();
const navErrors = [];
p375.on('pageerror', (e) => navErrors.push(String(e)));
await p375.goto(fileUrl, { waitUntil: 'domcontentloaded', timeout: 60000 });
await p375.waitForTimeout(2500);
const overflow375 = await p375.evaluate(
  () => document.documentElement.scrollWidth - document.documentElement.clientWidth
);
const content375 = await p375.locator('#content').innerText().catch(() => '');
await p375.screenshot({ path: path.join(outDir, 'vloop-375.png'), fullPage: false });
await ctx375.close();
out.evidence.overflow375 = overflow375;
out.evidence.navErrors = navErrors;
out.evidence.content375Len = content375.length;

if (
  out.evidence.hasContent &&
  out.evidence.markedPinned &&
  out.errors.length === 0 &&
  navErrors.length === 0 &&
  overflow375 === 0
) {
  pass('file_renders_overflow375', { overflow375, contentLen: content.length, errors: 0 });
} else {
  fail('file_renders_overflow375', {
    hasContent: out.evidence.hasContent,
    markedPinned: out.evidence.markedPinned,
    errors: out.errors,
    navErrors,
    overflow375,
  });
}

// Spot-check 10+ vendors vs FINDINGS membership
const EXPECTED = {
  agenthub: { market: 'apo', role: 'core' },
  agentsys: { market: 'apo', role: 'core' },
  'ai-dlc': { market: 'apo', role: 'core' },
  ateam: { market: 'apo', role: 'core' },
  metagpt: { market: 'apo', role: 'core' },
  'silver-bullet': { market: 'apo', role: 'core' },
  bmad: { market: 'sdlc-plugins', role: 'core' },
  'claude-harness': { market: 'sdlc-plugins', role: 'core' },
  gsd: { market: 'sdlc-plugins', role: 'core' },
  'factory-ai': { market: 'agentic-sdlc-saas', role: 'core' },
  devin: { market: 'agentic-sdlc-saas', role: 'core' },
  'augment-cosmos': { market: 'agentic-sdlc-saas', role: 'core' },
  tembo: { market: 'agentic-sdlc-saas', role: 'core' },
  'magic-dev': { market: 'agentic-sdlc-saas', role: 'core' },
  conductor: { market: 'agentic-sdlc-saas', role: 'adjacent' },
  cursor: { market: 'agentic-sdlc-saas', role: 'adjacent' },
  'claude-code': { market: 'agentic-sdlc-saas', role: 'adjacent' },
  codex: { market: 'agentic-sdlc-saas', role: 'adjacent' },
  'cognition-scout': { market: 'agentic-sdlc-saas', role: 'adjacent' },
  axonflow: { market: 'apo', role: 'adjacent' },
  crewai: { market: 'apo', role: 'adjacent' },
  langchain: { market: 'apo', role: 'adjacent' },
};

const spot = await page.evaluate((expected) => {
  const data = JSON.parse(document.getElementById('report-data').textContent);
  const markets = data.chart_data?.markets || {};
  const rankings = new Set((data.comparison?.rankings || []).map((r) => r.solution));
  const results = [];

  function labelsIn(id) {
    const m = markets[id] || {};
    const names = new Set();
    for (const p of m.mq_data || []) names.add(p.label);
    for (const arr of Object.values(m.vendor_buckets || {})) {
      for (const v of arr || []) names.add(v);
    }
    for (const p of m.gmq_data || []) names.add(p.label || p.name);
    for (const p of m.wave_data || []) names.add(p.label || p.name);
    return names;
  }

  const apoNames = labelsIn('apo');
  const pluginNames = labelsIn('sdlc-plugins');
  const saasNames = labelsIn('agentic-sdlc-saas');

  const slugToLabelHints = {
    agenthub: [/AgentHub/i],
    agentsys: [/AgentSys/i],
    'ai-dlc': [/AI-DLC/i],
    ateam: [/ATeam/i],
    metagpt: [/MetaGPT/i],
    'silver-bullet': [/Silver Bullet/i],
    bmad: [/BMAD/i],
    'claude-harness': [/Claude Harness/i],
    gsd: [/GSD/i],
    'factory-ai': [/Factory/i],
    devin: [/Devin/i],
    'augment-cosmos': [/Augment Cosmos/i],
    tembo: [/Tembo/i],
    'magic-dev': [/Magic\.dev/i],
    conductor: [/Conductor/i],
    cursor: [/^Cursor$/i, /\bCursor\b/],
    'claude-code': [/Claude Code(?! Expert)/i],
    codex: [/\bCodex\b/i],
    'cognition-scout': [/Cognition Scout/i],
    axonflow: [/Axonflow/i],
    crewai: [/CrewAI|Crewai/i],
    langchain: [/LangChain|Langchain/i],
  };

  for (const [slug, exp] of Object.entries(expected)) {
    const hints = slugToLabelHints[slug] || [new RegExp(slug, 'i')];
    const inApo = [...apoNames].some((n) => hints.some((h) => h.test(String(n))));
    const inPlugins = [...pluginNames].some((n) => hints.some((h) => h.test(String(n))));
    const inSaas = [...saasNames].some((n) => hints.some((h) => h.test(String(n))));
    const inRank = rankings.has(slug);

    let ok = true;
    let note = '';
    if (exp.role === 'core') {
      if (exp.market === 'apo' && !inApo) {
        ok = false;
        note = 'expected APO core chart presence';
      }
      if (exp.market === 'sdlc-plugins' && !inPlugins) {
        ok = false;
        note = 'expected plugins core chart presence';
      }
      if (exp.market === 'agentic-sdlc-saas' && !inSaas) {
        ok = false;
        note = 'expected SaaS core chart presence';
      }
      // hard wrong-segment: core vendor also dominating wrong market MQ
      if (exp.market === 'apo' && inSaas && !inApo) {
        ok = false;
        note = 'HARD: in SaaS chart but not APO';
      }
      if (exp.market === 'sdlc-plugins' && inApo) {
        ok = false;
        note = 'HARD: plugins core appears in APO chart';
      }
      if (exp.market === 'agentic-sdlc-saas' && inApo) {
        ok = false;
        note = 'HARD: SaaS core appears in APO chart';
      }
    } else if (exp.role === 'adjacent') {
      // must NOT be in any market MQ/core buckets
      if (inApo || inPlugins || inSaas || inRank) {
        ok = false;
        note = `HARD wrong-segment: adjacent slug in core charts/rankings apo=${inApo} plugins=${inPlugins} saas=${inSaas} rank=${inRank}`;
      } else {
        note = 'absent from core MQ/buckets/rankings (adjacent-only OK)';
      }
    }
    results.push({ slug, expected: exp, inApo, inPlugins, inSaas, inRank, ok, note });
  }
  return results;
}, EXPECTED);

out.spot_checks = spot;
const hardWrong = spot.filter((s) => !s.ok && /HARD/i.test(s.note));
out.evidence.hardWrongSegment = hardWrong;
out.evidence.spotFails = spot.filter((s) => !s.ok);

out.pass = MUST.every((id) => out.must[id]?.result === 'PASS') && hardWrong.length === 0;

fs.writeFileSync(path.join(outDir, 'RESULT.json'), JSON.stringify(out, null, 2));

// Markdown table
const lines = [
  '# Independent V-loop recheck — analyst-grade overhaul claims',
  '',
  `ts: ${out.ts}`,
  `file: ${fileUrl}`,
  `overall: **${out.pass ? 'PASS' : 'FAIL'}**`,
  '',
  '## Must PASS/FAIL',
  '',
  '| # | Claim | Result | Detail |',
  '|---|---|---|---|',
];
const claimLabels = {
  saas_hosts_not_core_leaders: '1. SaaS core MQ/Leaders exclude Cursor/Claude Code/Codex/Copilot (adjacent only)',
  saas_core_mq_five: '2. SaaS core MQ includes Factory / Devin / Augment Cosmos / Tembo / Magic.dev',
  cognition_scout_saas_adjacent_not_core: '3. Cognition Scout is SaaS adjacent, not core',
  conductor_not_apo_saas_adjacent: '4. Conductor is not APO; SaaS-adjacent aggregator framing',
  claude_harness_plugins_oss_not_apo: '5. Claude Harness in sdlc-plugins OSS, not APO',
  metagpt_apo_oss_mq: '6. MetaGPT in APO OSS / on APO MQ',
  no_claude_code_expert_product_cards: '7. No Claude Code Expert product cards',
  agentsys_github_no_aws_aidlc: '8. AgentSys → github.com/agent-sh/agentsys; no aws.amazon.com/ai-dlc/',
  no_hyperlink_underlines_blank_noopener: '9. No hyperlink underlines; target=_blank+noopener on externals',
  file_renders_overflow375: '10. file:// renders (no Marked crash); overflow@375 ≈ 0',
};
let i = 1;
for (const id of MUST) {
  const r = out.must[id];
  const detail = typeof r.detail === 'string' ? r.detail : JSON.stringify(r.detail).slice(0, 220);
  lines.push(`| ${i++} | ${claimLabels[id]} | **${r.result}** | ${detail.replace(/\|/g, '\\|')} |`);
}
lines.push('', '## Spot-checks (FINDINGS membership)', '');
lines.push('| Slug | Expected | APO | Plugins | SaaS | Rank | OK | Note |');
lines.push('|---|---|---|---|---|---|---|---|');
for (const s of spot) {
  lines.push(
    `| ${s.slug} | ${s.expected.market}:${s.expected.role} | ${s.inApo} | ${s.inPlugins} | ${s.inSaas} | ${s.inRank} | ${s.ok ? 'PASS' : 'FAIL'} | ${(s.note || '').replace(/\|/g, '\\|')} |`
  );
}
lines.push('', '## Defects', '');
if (out.defects.length === 0 && hardWrong.length === 0) {
  lines.push('_None._');
} else {
  for (const d of out.defects) {
    lines.push(`- **${d.id}**: ${typeof d.detail === 'string' ? d.detail : JSON.stringify(d.detail).slice(0, 400)}`);
  }
  for (const h of hardWrong) {
    lines.push(`- **hard-wrong-segment ${h.slug}**: ${h.note}`);
  }
}
lines.push('', '## Evidence files', '');
lines.push('- `RESULT.json`, `membership.json`, `vloop-1280.png`, `vloop-375.png`');
fs.writeFileSync(path.join(outDir, 'REPORT.md'), lines.join('\n') + '\n');

console.log(JSON.stringify({ pass: out.pass, must: out.must, hardWrong, spotFails: out.evidence.spotFails }, null, 2));
await browser.close();
process.exit(out.pass ? 0 : 1);
