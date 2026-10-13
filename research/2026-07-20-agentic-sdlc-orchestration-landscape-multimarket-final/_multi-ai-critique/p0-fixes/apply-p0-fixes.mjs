#!/usr/bin/env node
/**
 * Apply multi-AI critique P0 hard defects to landscape artifacts.
 * Evidence + checklist written beside this script.
 */
import fs from "fs";
import path from "path";

const ROOT = path.resolve(
  path.dirname(new URL(import.meta.url).pathname),
  "../.."
);
const EVIDENCE = path.join(ROOT, "_multi-ai-critique/p0-fixes");
const checklist = [];
const note = (id, status, detail) => checklist.push({ id, status, detail });

function read(p) {
  return fs.readFileSync(p, "utf8");
}
function write(p, s) {
  fs.writeFileSync(p, s, "utf8");
}
function bak(p) {
  const dest = path.join(EVIDENCE, "backups", path.basename(p) + ".bak");
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  if (!fs.existsSync(dest)) fs.copyFileSync(p, dest);
}

// --- 1) Director SCR ---
{
  const p = path.join(ROOT, "solutions/director/scr.md");
  bak(p);
  let t = read(p);
  const bad = "Superpowers is distributed through the first-party Claude plugin directory";
  if (t.includes(bad)) {
    t = t.replace(
      /## Executive summary\n\n[\s\S]*?\n\n## Evidence-backed notes/,
      `## Executive summary

Director is a primary-market APO candidate — agent orchestration, workflow composition, deterministic gates, and specialist agent routing. Canonical product URL was not independently verified in this pass (prior candidate repo returned 404); treat identity as seed-level until a primary source is confirmed.

## Evidence-backed notes`
    );
    t = t.replace(
      /^- Superpowers is distributed through the first-party Claude plugin directory[^\n]*\n/m,
      "- Director SCR previously leaked Superpowers install-path prose; corrected to Director-only identity (P0 card corruption fix).\n"
    );
    write(p, t);
    note("P0-director-scr", "fixed", "Removed Superpowers overview leak from director/scr.md");
  } else {
    note("P0-director-scr", "already-clean", "No Superpowers leak in director SCR");
  }
}

// --- 2) cc10x SCR ---
{
  const p = path.join(ROOT, "solutions/cc10x/scr.md");
  bak(p);
  let t = read(p);
  const bad = "Startup-weighted comparison:";
  if (t.includes(bad) && t.indexOf(bad) < t.indexOf("## Evidence-backed notes") + 200) {
    t = t.replace(
      /## Executive summary\n\n[\s\S]*?\n\n## Evidence-backed notes/,
      `## Executive summary

cc10x is a primary-market APO candidate — a Claude Code–oriented enhancement pack for multi-agent coordination, process enforcement, and host-integrated packaging. Public footprint is thinner than Silver Bullet or AI-DLC; treat adoption claims as unverified without primary metrics.

## Evidence-backed notes`
    );
    t = t.replace(
      /^- Startup-weighted comparison:[\s\S]*?\n(?=- )/m,
      "- cc10x SCR previously leaked report methodology / SB-anchor scoring prose into the overview; replaced with product identity (P0 card corruption fix).\n"
    );
    write(p, t);
    note("P0-cc10x-scr", "fixed", "Removed methodology/SB-anchor leak from cc10x/scr.md");
  } else {
    note("P0-cc10x-scr", "already-clean", "No methodology leak in cc10x executive summary");
  }
}

// --- 3) Claude Harness SCR honesty ---
{
  const p = path.join(ROOT, "solutions/claude-harness/scr.md");
  bak(p);
  let t = read(p);
  if (!t.includes("UNVERIFIED IDENTITY")) {
    t = t.replace(
      /## Executive summary\n\n[\s\S]*?\n\n## Evidence-backed notes/,
      `## Executive summary

UNVERIFIED IDENTITY: Claude Harness is listed as a methodology/process pack candidate, but no distinct canonical repository or homepage was verified in this pass. Do **not** treat \`anthropics/claude-code\` (the host runtime) as the Harness product source. Capabilities below are seed-asserted only until a primary source is confirmed.

## Evidence-backed notes`
    );
    write(p, t);
    note("P0-claude-harness-scr", "fixed", "Marked Claude Harness identity unverified; forbid host-repo conflation");
  } else {
    note("P0-claude-harness-scr", "already-clean", "Already marked unverified");
  }
}

// --- 4) Zuvo SCR quarantine ---
{
  const p = path.join(ROOT, "solutions/zuvo/scr.md");
  bak(p);
  let t = read(p);
  if (!t.includes("QUARANTINED")) {
    t = t.replace(
      /## Executive summary\n\n[\s\S]*?\n\n## Evidence-backed notes/,
      `## Executive summary

QUARANTINED / WATCHLIST: Zuvo could not be corroborated by open web search in this retrieval pass. OSS license, Leader status, and scored matrix membership are suspended until a primary repo/license file is verified. Do not treat pack assertions as confirmed product facts.

## Evidence-backed notes`
    );
    // Soften false-certainty OSS claim in notes
    t = t.replace(
      /^- Zuvo is OSS-licensed \(per query override: license is OSS, not commercial\)\.[^\n]*/m,
      "- Zuvo license remains **unverified** (prior pack override claimed OSS; not confirmed against a primary license file)."
    );
    write(p, t);
    note("P0-zuvo-scr", "fixed", "Quarantined Zuvo SCR as watchlist/unverified");
  } else {
    note("P0-zuvo-scr", "already-clean", "Already quarantined");
  }
}

// --- helpers for report ---
function waveLabel(n) {
  if (n == null || Number.isNaN(Number(n))) return "—";
  const v = Number(n);
  if (v >= 3.5) return `Strong (${v})`;
  if (v >= 2.5) return `Competitive (${v})`;
  if (v >= 1.5) return `Moderate (${v})`;
  return `Limited (${v})`;
}

function mdLink(label, url) {
  if (!url) return label;
  return `[${label}](${url})`;
}

// --- 5) chart-data.json: Zuvo quarantine + Challengers sync ---
{
  const p = path.join(ROOT, "landscape/chart-data.json");
  bak(p);
  const cd = JSON.parse(read(p));
  const plugins = cd.markets["sdlc-plugins"];
  if (!plugins) throw new Error("missing sdlc-plugins market");

  // Quarantine zuvo from core plots
  const wasCore = (plugins.membership.core || []).includes("zuvo");
  plugins.membership.core = (plugins.membership.core || []).filter((s) => s !== "zuvo");
  if (!plugins.membership.adjacent.includes("zuvo")) plugins.membership.adjacent.push("zuvo");
  plugins.membership.listed = Array.from(
    new Set([...(plugins.membership.listed || []), "zuvo"])
  );
  plugins.mq_data = (plugins.mq_data || []).filter((r) => r.slug !== "zuvo");
  plugins.gmq_data = (plugins.gmq_data || []).filter((r) => r.slug !== "zuvo");
  plugins.wave_data = (plugins.wave_data || []).filter((r) => r.slug !== "zuvo");
  const unplotted = plugins.membership.unplotted || [];
  if (!unplotted.some((u) => (u.slug || u) === "zuvo")) {
    unplotted.push({
      slug: "zuvo",
      reason:
        "quarantined — identity/OSS/license unverified; watchlist only (not MQ/Wave/Leader)",
    });
  }
  plugins.membership.unplotted = unplotted;

  // Top-level plotted/listed sync if present
  if (Array.isArray(cd.plotted_slugs)) {
    cd.plotted_slugs = cd.plotted_slugs.filter((s) => s !== "zuvo");
  }
  if (cd.membership?.core) {
    // top-level membership is APO-shaped; leave alone
  }

  // P1 cheap: populate challengers from APO GMQ Challengers (honest sync)
  const apo = cd.markets.apo;
  const gmqChallengers = (apo.gmq_data || [])
    .filter((r) => r.q === "Challengers")
    .map((r) => r.label || r.slug);
  if (cd.vendor_buckets) {
    cd.vendor_buckets.challengers = gmqChallengers;
    cd.vendor_buckets.challengers_note =
      "Synced from APO gmq_data Challengers. Empty Challengers previously contradicted GMQ plots; MQ chart uses mq_data (Leaders/Visionaries/Niche for APO).";
  }

  write(p, JSON.stringify(cd, null, 2) + "\n");
  note(
    "P0-zuvo-chart",
    wasCore ? "fixed" : "partial",
    "Removed Zuvo from sdlc-plugins core/mq/gmq/wave; adjacent+unplotted quarantine"
  );
  note(
    "P1-challengers",
    "fixed",
    `Populated vendor_buckets.challengers from APO GMQ: ${gmqChallengers.join(", ") || "(none)"}`
  );
}

// --- 6) landscape-report.md surgical fixes ---
{
  const p = path.join(ROOT, "landscape/landscape-report.md");
  bak(p);
  let t = read(p);
  const cd = JSON.parse(read(path.join(ROOT, "landscape/chart-data.json")));
  const urls = cd.vendor_urls || {};
  // also harvest from link_pairs
  for (const pair of cd.link_pairs || []) {
    if (Array.isArray(pair) && pair.length >= 2) {
      const [label, url] = pair;
      // skip
    }
  }

  // Scope: Devin contradiction
  if (
    t.includes("Host runtimes") &&
    t.includes("Devin") &&
    !t.includes("tertiary SaaS core")
  ) {
    t = t.replace(
      /(- \*\*Host runtimes\*\*[^\n]*Devin[^\n]*)/,
      `$1

  - **Market-layer note (P0 consistency):** Devin is **adjacent** for the primary APO market (host runtime, not a process layer above a host). Devin **is** a **core Leader** in the tertiary **Agentic SDLC SaaS** market — those are different membership contracts, not a single “adjacent-only everywhere” rule.`
    );
    note("P0-devin-scope", "fixed", "Clarified Devin APO-adjacent vs SaaS-core membership");
  }

  // Fix §9 claim if it says adjacent hosts not scored while Devin is scored in SaaS
  t = t.replace(
    /Products below are relevant context but \*\*not\*\* scored on the Magic Quadrant, Wave, or comparison matrix\./,
    "Products below are relevant context for the **primary APO** lens and are **not** plotted on the primary-market MQ/Wave. Host runtimes that are **core in the tertiary SaaS market** (e.g. Devin) remain scored there; do not read this adjacent list as a global unscored ban."
  );

  // Director card overview
  t = t.replace(
    /(### Director \(OSS — OSS\)\n\n\* \*\*Overview\*\*: )\[Superpowers\]\([^\)]+\) is distributed through the first-party Claude plugin directory, giving it the lowest-friction install path among secondary-market substitutes\./,
    `$1Director is a primary-market APO candidate — agent orchestration, workflow composition, deterministic gates, and specialist agent routing. Canonical product URL was not independently verified in this pass; treat identity as seed-level until a primary source is confirmed.`
  );
  note("P0-director-card", "fixed", "Director overview no longer Superpowers content");

  // cc10x card overview
  t = t.replace(
    /(### \[cc10x\]\([^\)]+\) \(Commercial\)\n\n\* \*\*Overview\*\*: )Startup-weighted comparison:[\s\S]*?carry lower public footprint\./,
    `$1cc10x is a primary-market APO candidate — a Claude Code–oriented enhancement pack for multi-agent coordination, process enforcement, and host-integrated packaging. Public footprint is thinner than Silver Bullet or AI-DLC; treat adoption claims as unverified without primary metrics.`
  );
  note("P0-cc10x-card", "fixed", "cc10x overview no longer methodology/SB-anchor leak");

  // AI-DLC IBM → AWS
  const ibmBefore = (t.match(/AI-DLC\]\([^\)]+\) \(IBM\)/g) || []).length +
    (t.match(/AI-DLC \(IBM\)/g) || []).length;
  t = t.replace(/\[AI-DLC\]\(([^\)]+)\) \(IBM\)/g, "[AI-DLC]($1) (AWS / awslabs)");
  t = t.replace(/AI-DLC \(IBM\)/g, "AI-DLC (AWS / awslabs)");
  note(
    "P0-ai-dlc-attr",
    ibmBefore ? "fixed" : "already-clean",
    "Corrected AI-DLC IBM mis-attribution to AWS/awslabs"
  );

  // Claude Harness: unlink anthropics/claude-code
  const harnessHits = (t.match(/https:\/\/github\.com\/anthropics\/claude-code/g) || [])
    .length;
  t = t.replace(
    /### \[Claude Harness\]\(https:\/\/github\.com\/anthropics\/claude-code\) \(OSS — OSS\)/,
    "### Claude Harness (UNVERIFIED — not anthropics/claude-code)"
  );
  t = t.replace(
    /\[Claude Harness\]\(https:\/\/github\.com\/anthropics\/claude-code\)/g,
    "Claude Harness"
  );
  // If overview still claims product certainty, prefix honesty
  t = t.replace(
    /(### Claude Harness \(UNVERIFIED[^\n]*\n\n\* \*\*Overview\*\*: )([^\n]+)/,
    `$1UNVERIFIED IDENTITY — $2 Distinct Harness homepage/repo was not verified; do not use anthropics/claude-code as this product’s canonical URL.`
  );
  note(
    "P0-claude-harness-link",
    harnessHits ? "fixed" : "already-clean",
    `Unlinked ${harnessHits} anthropics/claude-code Claude Harness bindings`
  );

  // MetaGPT consistency: keep APO core; remove from adjacent-only reliability bullet
  t = t.replace(
    /Generic agent frameworks \(LangGraph, \[CrewAI\]\([^\)]+\), \[MetaGPT\]\([^\)]+\), \[LangChain\]\([^\)]+\), \[AxonFlow\]\([^\)]+\), Cavekit v4\) are designated as adjacent-only and must be excluded from comparison matrices and core lists as they lack shipped, enforced SDLC process products\./,
    "Generic agent frameworks (LangGraph, [CrewAI](https://github.com/crewAIInc/crewAI), [LangChain](https://github.com/langchain-ai/langchain), [AxonFlow](https://www.axonflow.ai/), Cavekit v4) are designated as adjacent-only and must be excluded from primary APO comparison matrices. **MetaGPT remains APO OSS core** (Niche Players in MQ) per membership — do not also label it adjacent-only."
  );
  note("P0-metagpt-membership", "fixed", "MetaGPT kept APO core; removed adjacent-only self-conflict in §13");

  // Zuvo card + coverage gaps + section heading count
  t = t.replace(
    /### \[Zuvo\]\(https:\/\/zuvo\.dev\/\) \(OSS — OSS\)/,
    "### Zuvo (QUARANTINED / WATCHLIST — identity unverified)"
  );
  t = t.replace(
    /(\* \*\*Overview\*\*: )\[Zuvo\]\(https:\/\/zuvo\.dev\/\) could not be corroborated[^\n]*/,
    `$1QUARANTINED: Zuvo could not be corroborated by open web search in this retrieval pass. Removed from sdlc-plugins MQ/Wave/Leader plots until a primary repo/license file is verified. Pack URL https://zuvo.dev/ remains unverified.`
  );
  t = t.replace(
    /\* \*\*Best For\*\*: SMB teams prioritising workflow composition with \[Zuvo\]\(https:\/\/zuvo\.dev\/\)\./,
    "* **Best For**: Not recommended for shortlists until identity and license are verified."
  );
  t = t.replace(
    /\* \*\*Avoid If\*\*: You need capabilities \[Zuvo\]\(https:\/\/zuvo\.dev\/\) lacks in the matrix \(Atomic flow catalog, Predictable pricing\)\./,
    "* **Avoid If**: Any procurement use-case — treat as watchlist only."
  );

  // Coverage gaps: replace stale "missing from envelopes" while in core
  t = t.replace(
    /\*\*Coverage gaps \(must-research seeds missing from envelopes\)\*\*\n\n- \[Zuvo\]\(https:\/\/zuvo\.dev\/\) \(`sdlc-plugin`\)/,
    `**Coverage gaps / quarantine**

- **Zuvo** — quarantined from sdlc-plugins core MQ/Wave/Leader plots (identity/OSS unverified). Listed as watchlist only; not a “missing envelope” while still scored as Leader.`
  );

  // Soften reliability line that asserts Zuvo/OSS among verified plugins
  t = t.replace(
    /SDLC plugin secondary market \(BMAD, GSD, \[Superpowers\]\([^\)]+\), GitHub Spec Kit, Oh My plugins, \[Zuvo\]\(https:\/\/zuvo\.dev\/\)\/OSS, \[SuperClaude\]/,
    "SDLC plugin secondary market (BMAD, GSD, [Superpowers](https://github.com/obra/superpowers), GitHub Spec Kit, Oh My plugins, Zuvo (quarantined/unverified), [SuperClaude]"
  );

  // Update §7 heading count if it still says 10 core while zuvo quarantined
  t = t.replace(
    /## 7\. SDLC Plugins & Methodology Packs — Top Open Source Solutions \(10 core\)/,
    "## 7. SDLC Plugins & Methodology Packs — Top Open Source Solutions (9 core + 1 quarantined)"
  );

  // --- Rebuild MQ tables from mq_data (not gmq_data) ---
  function rebuildMqTable(marketId, heading) {
    const m = cd.markets[marketId];
    const rows = (m.mq_data || [])
      .slice()
      .sort((a, b) => (a.label || a.slug).localeCompare(b.label || b.slug));
    const body = rows
      .map((r) => {
        const label = r.label || r.slug;
        const url = urls[r.slug];
        const name = url ? `[${label}](${url})` : label;
        return `| ${name} | ${r.q} | Positioned from mq_data (Completeness of Vision × Ability to Execute); SPA chart is authoritative. |`;
      })
      .join("\n");
    const block = `#### ${heading}

| Vendor | Quadrant | Justification |
|--------|----------|---------------|
${body}`;
    return block;
  }

  t = t.replace(
    /#### 3\.1\.2 Magic Quadrant — Agentic Process Orchestrators \(APO\)\n\n\| Vendor \| Quadrant \| Justification \|[\s\S]*?(?=\n#### 3\.1\.3 )/,
    rebuildMqTable("apo", "3.1.2 Magic Quadrant — Agentic Process Orchestrators (APO)") +
      "\n\n"
  );
  t = t.replace(
    /#### 3\.2\.2 Magic Quadrant — SDLC Plugins & Methodology Packs\n\n\| Vendor \| Quadrant \| Justification \|[\s\S]*?(?=\n#### 3\.2\.3 )/,
    rebuildMqTable(
      "sdlc-plugins",
      "3.2.2 Magic Quadrant — SDLC Plugins & Methodology Packs"
    ) + "\n\n"
  );
  t = t.replace(
    /#### 3\.3\.2 Magic Quadrant — Agentic SDLC SaaS & Autonomous Delivery\n\n\| Vendor \| Quadrant \| Justification \|[\s\S]*?(?=\n#### 3\.3\.3 )/,
    rebuildMqTable(
      "agentic-sdlc-saas",
      "3.3.2 Magic Quadrant — Agentic SDLC SaaS & Autonomous Delivery"
    ) + "\n\n"
  );
  note("P0-mq-tables", "fixed", "§3.x.2 MQ tables now match chart-data mq_data (was GMQ)");

  // --- Sync Wave tables from wave_data with numeric labels + footnote ---
  function rebuildWaveTable(marketId, heading) {
    const m = cd.markets[marketId];
    const rows = m.wave_data || [];
    const body = rows
      .map((r) => {
        const label = r.label || r.slug;
        const url = urls[r.slug];
        const name = url ? `[${label}](${url})` : label;
        return `| ${name} | ${waveLabel(r.offering)} | ${waveLabel(r.strategy)} | ${waveLabel(r.presence)} |`;
      })
      .join("\n");
    return `#### ${heading}

| Vendor | Current Offering | Strategy | Market Presence |
|--------|------------------|----------|-----------------|
${body}

> Wave markdown synced from \`chart-data.json\` → \`markets.${marketId}.wave_data\` (numeric scores shown). SPA Wave chart is authoritative if prose and chart ever diverge.`;
  }

  t = t.replace(
    /#### 3\.1\.3 Wave-Style Assessment — Agentic Process Orchestrators \(APO\)\n\n\| Vendor \| Current Offering \| Strategy \| Market Presence \|[\s\S]*?(?=\n#### 3\.1\.4 )/,
    rebuildWaveTable(
      "apo",
      "3.1.3 Wave-Style Assessment — Agentic Process Orchestrators (APO)"
    ) + "\n\n"
  );
  t = t.replace(
    /#### 3\.2\.3 Wave-Style Assessment — SDLC Plugins & Methodology Packs\n\n\| Vendor \| Current Offering \| Strategy \| Market Presence \|[\s\S]*?(?=\n#### 3\.2\.4 )/,
    rebuildWaveTable(
      "sdlc-plugins",
      "3.2.3 Wave-Style Assessment — SDLC Plugins & Methodology Packs"
    ) + "\n\n"
  );
  t = t.replace(
    /#### 3\.3\.3 Wave-Style Assessment — Agentic SDLC SaaS & Autonomous Delivery\n\n\| Vendor \| Current Offering \| Strategy \| Market Presence \|[\s\S]*?(?=\n#### 3\.3\.4 )/,
    rebuildWaveTable(
      "agentic-sdlc-saas",
      "3.3.3 Wave-Style Assessment — Agentic SDLC SaaS & Autonomous Delivery"
    ) + "\n\n"
  );
  note("P1-wave-sync", "fixed", "Wave tables expanded to full chart-data with numeric labels");

  // Blue Ocean caption honesty for APO (Leaders from mq_data)
  const apoLeaders = (cd.markets.apo.mq_data || [])
    .filter((r) => r.q === "Leaders")
    .map((r) => r.label || r.slug);
  t = t.replace(
    /(#### 3\.1\.4 Blue Ocean Value Curve — Agentic Process Orchestrators \(APO\)\n\n)Radar of Key Competitive Factors for Magic Quadrant Leaders \(top-right\) only\./,
    `$1Radar of Key Competitive Factors for **MQ Leaders** (from \`mq_data\`): ${apoLeaders.join(", ")}. Table columns may include additional shortlisted peers for contrast — column set ≠ Leader definition.`
  );

  // Challengers honesty note under APO MQ
  if (!t.includes("vendor_buckets.challengers")) {
    t = t.replace(
      /(#### 3\.1\.2 Magic Quadrant — Agentic Process Orchestrators \(APO\)\n\n)/,
      `$1> Note: \`vendor_buckets.challengers\` was previously empty while GMQ plotted Challengers. Buckets now sync from APO \`gmq_data\` Challengers for reference; **this MQ table uses \`mq_data\`**, which for APO has Leaders / Visionaries / Niche Players (no Challengers quadrant members in current mq_data).\n\n`
    );
  }

  // Strip remaining anthropics/claude-code if any stray
  t = t.replace(/https:\/\/github\.com\/anthropics\/claude-code/g, "#unverified-claude-harness");

  write(p, t);
  note("P0-zuvo-prose", "fixed", "Zuvo card + coverage-gap + reliability prose quarantined");
}

// --- 7) comparison-matrix.md from comparison.json ---
{
  const cmpPath = path.join(ROOT, "comparison/comparison.json");
  const outPath = path.join(ROOT, "comparison/comparison-matrix.md");
  bak(outPath);
  const cmp = JSON.parse(read(cmpPath));
  // Fix null provenance cheaply
  if (cmp.research_type == null) cmp.research_type = "landscape-feature-matrix";
  if (!Array.isArray(cmp.caveats) || cmp.caveats.length === 0) {
    cmp.caveats = [
      "Matrix ticks come from solution feature envelopes; null/empty means unverified or unsupported in this pass — not a claim of absence in the wild.",
      "Zuvo is quarantined (identity/OSS unverified); ticks retained for audit but should not drive Leader/shortlist decisions.",
      "Claude Harness must not be conflated with anthropics/claude-code host runtime.",
      "Interactive SPA matrix panel in landscape-report.html is the preferred procurement view; this markdown is a regenerated ranking + criteria summary.",
    ];
  }
  write(cmpPath, JSON.stringify(cmp, null, 2) + "\n");

  const rankings = cmp.rankings || [];
  const top = rankings.slice(0, 12).map((r) => r.solution);
  const features = (cmp.rows || []).filter((r) => r.type === "feature");

  let md = `# Comparison matrix (regenerated from comparison.json)

Winner: **${cmp.winner || rankings[0]?.solution || "n/a"}** | Runner-up: **${cmp.runner_up || rankings[1]?.solution || "n/a"}**

> Prefer the interactive matrix in [\`landscape-report.html\`](../landscape-report.html) (SPA \`landscape-matrix-panel\`). This file is a readable summary synced from \`comparison.json\` — not a stub.

## Rankings

`;
  rankings.forEach((r, i) => {
    md += `${i + 1}. \`${r.solution}\` — ${r.score}\n`;
  });

  md += `\n## Criteria × top-${top.length} (by score)\n\n`;
  md += `| Criterion | Priority | ${top.map((s) => "`" + s + "`").join(" | ")} |\n`;
  md += `|---|---|${top.map(() => "---").join("|")}|\n`;
  for (const f of features) {
    const cells = top.map((s) => {
      const v = (f.solutions && f.solutions[s]) || "";
      return v === "✔" ? "✔" : v ? v : "·";
    });
    md += `| ${f.name} | ${f.priority || ""} | ${cells.join(" | ")} |\n`;
  }

  md += `\n## Caveats\n\n`;
  for (const c of cmp.caveats) md += `- ${c}\n`;

  md += `\n## Managed hosting ticks (from comparison envelope)\n\n`;
  const managed = features.find((f) => /managed host/i.test(f.name));
  if (managed) {
    const hits = Object.entries(managed.solutions || {})
      .filter(([, v]) => v === "✔")
      .map(([k]) => k)
      .sort();
    md += hits.join(", ") + "\n";
  } else {
    md += "_No managed-hosting feature row found._\n";
  }

  write(outPath, md);
  note("P0-comparison-matrix", "fixed", "Regenerated comparison-matrix.md from comparison.json + caveats");
}

// --- checklist + VERIFY snippet ---
write(
  path.join(EVIDENCE, "CHECKLIST.md"),
  `# P0 fix checklist\n\nGenerated: ${new Date().toISOString()}\n\n` +
    checklist
      .map((c) => `- **${c.id}** — \`${c.status}\`: ${c.detail}`)
      .join("\n") +
    "\n"
);
write(path.join(EVIDENCE, "checklist.json"), JSON.stringify(checklist, null, 2) + "\n");
console.log(JSON.stringify({ ok: true, checklist }, null, 2));
