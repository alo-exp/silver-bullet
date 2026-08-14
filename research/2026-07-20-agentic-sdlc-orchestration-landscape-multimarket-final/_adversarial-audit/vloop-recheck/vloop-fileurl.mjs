#!/usr/bin/env node
/**
 * Independent V-loop recheck — canonical view mode is file:// (no localhost required).
 */
import { chromium } from 'playwright';
import fs from 'fs';
import path from 'path';
import { fileURLToPath, pathToFileURL } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const OUT = __dirname;
const REPORT = path.resolve(
  __dirname,
  '../../landscape-report.html'
);
const FILE_URL = pathToFileURL(REPORT).href;

async function main() {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
  const pageErrors = [];
  const consoleErrors = [];
  const failed = [];
  const responses = [];

  page.on('pageerror', (e) => pageErrors.push(String(e.message || e)));
  page.on('console', (m) => {
    if (m.type() === 'error') consoleErrors.push(m.text());
  });
  page.on('response', (r) => {
    responses.push({ url: r.url(), status: r.status() });
    if (r.status() === 404) failed.push(r.url());
  });

  await page.goto(FILE_URL, { waitUntil: 'domcontentloaded', timeout: 90000 });
  // file:// may not fire networkidle the same way; wait for SPA content
  await page.waitForFunction(
    () => {
      const h1 = document.querySelector('h1');
      const body = document.body?.innerText || '';
      return !!(h1 && body.length > 2000) || /render failed|parseInline/i.test(body);
    },
    { timeout: 45000 }
  );
  await page.waitForTimeout(2000);

  await page.screenshot({ path: path.join(OUT, 'VLOOP-1280.png'), fullPage: false });

  // Dark theme
  const themeBtn = await page.$('#themeToggle');
  if (themeBtn) {
    await themeBtn.click();
    await page.waitForTimeout(500);
  }
  await page.screenshot({ path: path.join(OUT, 'VLOOP-dark-1280.png'), fullPage: false });

  const evidence = await page.evaluate(() => {
    const body = document.body?.innerText || '';
    const fail = /render failed|parseInline|TypeError/i.test(body);
    const bannerEl = document.getElementById('matrixFillGapBanner');
    const banner = bannerEl?.textContent || '';
    const bannerVisible = !!(
      bannerEl &&
      getComputedStyle(bannerEl).display !== 'none' &&
      bannerEl.offsetParent !== null
    );
    const marked = [...document.querySelectorAll('script[src]')]
      .map((s) => s.src)
      .find((s) => /marked/i.test(s));
    const fonts = [...document.querySelectorAll('link[rel="stylesheet"]')].map((l) => l.href);

    // Check #3: SDLC Plugin links must not go to claude.com/plugins
    const sdlcAnchors = [...document.querySelectorAll('a')].filter((a) =>
      /^SDLC Plugin$/i.test((a.textContent || '').trim())
    );
    const sdlcLike = [...document.querySelectorAll('a')].filter((a) =>
      /SDLC\s*Plugin/i.test((a.textContent || '').trim())
    );

    const challengerBtn = [...document.querySelectorAll('.vfbtn')].find((b) =>
      /Challengers/i.test(b.textContent || '')
    );

    // Homepage title links
    const nameLinks = [...document.querySelectorAll('a.vc-name-link')];
    const nameLinkMeta = {
      count: nameLinks.length,
      missingBlank: nameLinks.filter((a) => a.target !== '_blank').length,
      missingRel: nameLinks.filter(
        (a) => a.target === '_blank' && !/noopener/i.test(a.rel || '')
      ).length,
      sample: nameLinks.slice(0, 5).map((a) => ({
        text: a.textContent.trim(),
        href: a.getAttribute('href'),
        target: a.target,
        rel: a.rel,
      })),
    };

    const httpLinks = [...document.querySelectorAll('a[href^="http"]')];
    const httpMeta = {
      count: httpLinks.length,
      missingBlank: httpLinks.filter((a) => a.target !== '_blank').length,
      missingRel: httpLinks.filter(
        (a) => a.target === '_blank' && !/noopener/i.test(a.rel || '')
      ).length,
    };

    // Spot MQ quadrant for Cavekit if present in chart data / cards
    let cavekitMq = null;
    try {
      const scripts = [...document.querySelectorAll('script')].map((s) => s.textContent || '');
      for (const t of scripts) {
        if (/Cavekit/i.test(t) && /"q"\s*:/.test(t)) {
          const m = t.match(/"label"\s*:\s*"Cavekit[^"]*"\s*,\s*"x"\s*:\s*[^,]+,\s*"y"\s*:\s*[^,]+,\s*"q"\s*:\s*"([^"]+)"/);
          if (m) {
            cavekitMq = m[1];
            break;
          }
        }
      }
    } catch (_) {}

    return {
      h1: document.querySelector('h1')?.textContent?.trim() || null,
      fail,
      bodyLen: body.length,
      contentChildCount: document.getElementById('content')?.children?.length ?? -1,
      banner: banner.slice(0, 400),
      bannerVisible,
      bannerHtmlPresent: !!bannerEl,
      marked,
      fonts,
      sdlcLinkCount: sdlcAnchors.length,
      sdlcHrefs: [...new Set(sdlcAnchors.map((a) => a.getAttribute('href')))],
      sdlcLikeCount: sdlcLike.length,
      sdlcLikeHrefs: [...new Set(sdlcLike.map((a) => a.getAttribute('href')))],
      challengerDisabled: !!challengerBtn?.disabled,
      challengerClass: challengerBtn?.className || null,
      challengerAria: challengerBtn?.getAttribute('aria-disabled'),
      httpMeta,
      nameLinkMeta,
      hasAPO: /3\.1 Primary market/i.test(body),
      hasSDLC: /3\.2 Secondary market/i.test(body),
      hasSaaS: /3\.3 Tertiary market/i.test(body),
      cavekitMq,
      locationHref: location.href,
      protocol: location.protocol,
    };
  });

  // Leaders filter — capture visible card titles (APO section context)
  await page.evaluate(() => {
    const h = [...document.querySelectorAll('h2,h3')].find((x) =>
      /3\.1 Primary market/i.test(x.textContent || '')
    );
    h?.scrollIntoView();
  });
  await page.waitForTimeout(300);

  const leadersProbe = await page.evaluate(() => {
    const btn = [...document.querySelectorAll('.vfbtn')].find((b) =>
      /Leaders/i.test(b.textContent || '')
    );
    if (!btn) return { error: 'no Leaders button', leadersVisible: [] };
    btn.click();
    // wait a tick inside evaluate
    const cards = [
      ...document.querySelectorAll(
        '.vendor-card:not(.is-filtered-out) a.vc-name-link, .vc-card:not(.is-filtered-out) a.vc-name-link, .vendor-card:not(.is-filtered-out) .vc-name, .vc-card:not(.is-filtered-out) .vc-name'
      ),
    ];
    const names = [
      ...new Set(
        cards
          .map((a) => (a.textContent || '').trim())
          .filter(Boolean)
      ),
    ];
    // Also check any visible card titles more broadly
    const allVisible = [
      ...document.querySelectorAll('.vendor-card:not(.is-filtered-out), .vc-card:not(.is-filtered-out)'),
    ].map((c) => {
      const t =
        c.querySelector('a.vc-name-link, .vc-name, h3, h4')?.textContent?.trim() ||
        c.textContent?.trim()?.slice(0, 80);
      return t;
    });
    return {
      leadersVisible: names,
      allVisibleCardTitles: allVisible.slice(0, 40),
      leadersBtnClass: btn.className,
    };
  });

  // Reset filter if possible
  await page.evaluate(() => {
    const all = [...document.querySelectorAll('.vfbtn')].find((b) =>
      /^All$/i.test((b.textContent || '').trim())
    );
    all?.click();
  });

  // 375 overflow
  await page.setViewportSize({ width: 375, height: 812 });
  await page.waitForTimeout(500);
  const overflow375 = await page.evaluate(() => ({
    scrollWidth: document.documentElement.scrollWidth,
    innerWidth: window.innerWidth,
    overflow: document.documentElement.scrollWidth - window.innerWidth,
  }));
  await page.screenshot({ path: path.join(OUT, 'VLOOP-375.png'), fullPage: false });

  const failed404 = failed.filter((u) => !/favicon/i.test(u));
  const fontsource404 = failed404.filter((u) => /fontsource/i.test(u));
  const googleFontsOk = responses.some(
    (r) => /fonts\.googleapis\.com/i.test(r.url) && r.status >= 200 && r.status < 400
  );

  const blankingErrors = [
    ...pageErrors,
    ...consoleErrors,
  ].filter((e) => /parseInline|marked|TypeError|ReferenceError|is not a function/i.test(e));

  const sdlcBad =
    (evidence.sdlcHrefs || []).some((h) => h && /claude\.com\/plugins/i.test(h)) ||
    (evidence.sdlcLikeHrefs || []).some((h) => h && /claude\.com\/plugins/i.test(h));

  const visionariesInLeaders = (leadersProbe.leadersVisible || []).filter((n) =>
    /Cavekit|Barkain|Claude Code Expert/i.test(n)
  );

  const checks = {
    '1_renders_file_url': {
      pass:
        !evidence.fail &&
        pageErrors.length === 0 &&
        blankingErrors.length === 0 &&
        evidence.bodyLen > 5000 &&
        !!evidence.h1,
      detail: {
        protocol: evidence.protocol,
        bodyLen: evidence.bodyLen,
        h1: evidence.h1,
        pageErrors,
        blankingErrors,
        failFlag: evidence.fail,
      },
    },
    '2_marked_pinned_11_1_1': {
      pass: /marked@11\.1\.1/.test(evidence.marked || ''),
      detail: { marked: evidence.marked },
    },
    '3_zero_sdlc_to_claude_plugins': {
      pass: !sdlcBad && (evidence.sdlcHrefs || []).every((h) => !h || !/claude\.com\/plugins/i.test(h)),
      detail: {
        sdlcLinkCount: evidence.sdlcLinkCount,
        sdlcHrefs: evidence.sdlcHrefs,
        sdlcLikeHrefs: evidence.sdlcLikeHrefs,
      },
    },
    '4_critical_fill_gap_banner': {
      pass:
        /Self-serve signup/i.test(evidence.banner) &&
        /Managed hosting/i.test(evidence.banner) &&
        (evidence.bannerVisible || evidence.bannerHtmlPresent),
      detail: {
        banner: evidence.banner,
        bannerVisible: evidence.bannerVisible,
        bannerHtmlPresent: evidence.bannerHtmlPresent,
      },
    },
    '5_challengers_empty_handled': {
      pass: evidence.challengerDisabled === true || /is-empty/i.test(evidence.challengerClass || ''),
      detail: {
        challengerDisabled: evidence.challengerDisabled,
        challengerClass: evidence.challengerClass,
      },
    },
    '6_vc_name_link_blank_noopener': {
      pass:
        evidence.nameLinkMeta.count > 0 &&
        evidence.nameLinkMeta.missingBlank === 0 &&
        evidence.nameLinkMeta.missingRel === 0 &&
        evidence.httpMeta.missingBlank === 0 &&
        evidence.httpMeta.missingRel === 0,
      detail: { nameLinkMeta: evidence.nameLinkMeta, httpMeta: evidence.httpMeta },
    },
    '7_fontsource_404s_gone': {
      pass: fontsource404.length === 0 && googleFontsOk,
      detail: {
        fontsource404,
        googleFontsOk,
        fonts: evidence.fonts,
        failed404Sample: failed404.slice(0, 15),
      },
    },
    '8_overflow_375_approx_0': {
      pass: overflow375.overflow <= 2,
      detail: overflow375,
    },
    '9_claimed_artifacts_exist': {
      pass: false, // filled below after fs checks
      detail: {},
    },
    '10_leaders_not_mq_visionaries': {
      pass: visionariesInLeaders.length === 0,
      detail: {
        leadersVisible: leadersProbe.leadersVisible,
        visionariesInLeaders,
        cavekitMq: evidence.cavekitMq,
        allVisibleSample: (leadersProbe.allVisibleCardTitles || []).slice(0, 20),
      },
    },
  };

  // Check 9: prior claimed artifacts
  const auditDir = path.resolve(__dirname, '..');
  const claimed = [
    'AFTER-1280.png',
    'AFTER-375.png',
    'AFTER-dark-1280.png',
    'audit-AFTER.json',
    'FINDINGS.md',
  ];
  const artifactStatus = claimed.map((f) => {
    const p = path.join(auditDir, f);
    const exists = fs.existsSync(p);
    let size = 0;
    if (exists) size = fs.statSync(p).size;
    return { file: f, exists, size };
  });
  let afterJsonMatches = false;
  try {
    const after = JSON.parse(fs.readFileSync(path.join(auditDir, 'audit-AFTER.json'), 'utf8'));
    afterJsonMatches =
      after?.evidence?.marked?.includes('marked@11.1.1') &&
      after?.evidence?.sdlcLinkCount === 0 &&
      after?.overflow375?.overflow === 0 &&
      !!after?.evidence?.banner;
  } catch (_) {}
  checks['9_claimed_artifacts_exist'] = {
    pass: artifactStatus.every((a) => a.exists && a.size > 0) && afterJsonMatches,
    detail: { artifactStatus, afterJsonMatches },
  };

  const passAll = Object.values(checks).every((c) => c.pass);

  const report = {
    mode: 'file://',
    fileUrl: FILE_URL,
    reportPath: REPORT,
    passAll,
    pageErrors,
    consoleErrors: consoleErrors.slice(0, 20),
    failed404: failed404.slice(0, 30),
    evidence,
    leadersProbe,
    overflow375,
    checks,
    screenshots: {
      vloop1280: path.join(OUT, 'VLOOP-1280.png'),
      vloopDark: path.join(OUT, 'VLOOP-dark-1280.png'),
      vloop375: path.join(OUT, 'VLOOP-375.png'),
    },
  };

  fs.writeFileSync(path.join(OUT, 'vloop-recheck.json'), JSON.stringify(report, null, 2));

  // Human table
  const lines = [
    '# V-loop recheck (file://)',
    '',
    `URL: \`${FILE_URL}\``,
    `passAll: **${passAll ? 'PASS' : 'FAIL'}**`,
    '',
    '| # | Check | Result |',
    '|---|-------|--------|',
  ];
  const order = Object.keys(checks);
  order.forEach((k, i) => {
    lines.push(`| ${i + 1} | ${k} | ${checks[k].pass ? 'PASS' : 'FAIL'} |`);
  });
  fs.writeFileSync(path.join(OUT, 'VLOOP-RECHECK.md'), lines.join('\n') + '\n');

  console.log(JSON.stringify({ passAll, checks: Object.fromEntries(Object.entries(checks).map(([k, v]) => [k, v.pass])), fileUrl: FILE_URL, pageErrors, consoleErrors: consoleErrors.slice(0, 8), failed404: failed404.slice(0, 10), overflow375, leaders: leadersProbe.leadersVisible?.slice(0, 15), banner: evidence.banner?.slice(0, 120) }, null, 2));
  await browser.close();
  process.exit(passAll ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
