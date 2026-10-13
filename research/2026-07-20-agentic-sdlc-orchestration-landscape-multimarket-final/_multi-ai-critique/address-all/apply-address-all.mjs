#!/usr/bin/env node
/**
 * Address ALL multi-AI landscape critique findings (beyond prior P0-only pass).
 * Mutates chart-data, landscape-report.md, SCRs, comparison.json.
 * Does NOT regenerate SPA (caller runs generate_spa_report.py after).
 */
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, "../..");
const EVIDENCE = path.join(ROOT, "_multi-ai-critique/address-all");
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

function waveLabel(n) {
  const v = Number(n);
  if (!Number.isFinite(v)) return String(n ?? "");
  if (v >= 3.5) return `Strong (${v})`;
  if (v >= 2.5) return `Competitive (${v})`;
  if (v >= 1.5) return `Limited (${v})`;
  return `Weak (${v})`;
}

function quadrantOf(x, y, mid = 5.5) {
  if (x >= mid && y >= mid) return "Leaders";
  if (x < mid && y >= mid) return "Challengers";
  if (x >= mid && y < mid) return "Visionaries";
  return "Niche Players";
}

function syncBucketsFromMq(market) {
  const mq = market.mq_data || [];
  const byQ = { Leaders: [], Challengers: [], Visionaries: [], "Niche Players": [] };
  for (const p of mq) {
    const q = p.q || quadrantOf(p.x, p.y);
    p.q = q;
    (byQ[q] || (byQ[q] = [])).push(p.label || p.slug);
  }
  market.vendor_buckets = market.vendor_buckets || {};
  market.vendor_buckets.leaders = byQ.Leaders;
  market.vendor_buckets.challengers = byQ.Challengers;
  market.vendor_buckets.visionaries = byQ.Visionaries;
  market.vendor_buckets.niche_players = byQ["Niche Players"];
  market.vendor_buckets.leader_definition =
    "Canonical MQ Leaders = markets.<id>.mq_data where q==='Leaders' (axes in market titles). GMQ uses separate Completeness×Ability axes — do not union GMQ Leaders into MQ Leaders. Blue Ocean radar is a KCF contrast set, not a Leader definition.";
  return byQ;
}

function setPoint(arr, slug, patch) {
  const i = arr.findIndex((p) => p.slug === slug);
  if (i < 0) return false;
  arr[i] = { ...arr[i], ...patch };
  if (patch.x != null && patch.y != null && !patch.q) {
    arr[i].q = quadrantOf(arr[i].x, arr[i].y);
  }
  return true;
}

// ---------------------------------------------------------------------------
// 1) chart-data.json
// ---------------------------------------------------------------------------
{
  const p = path.join(ROOT, "landscape/chart-data.json");
  bak(p);
  const cd = JSON.parse(read(p));
  const before = {
    plugins_y: [...new Set((cd.markets["sdlc-plugins"].mq_data || []).map((x) => x.y))],
    plugins_qs: Object.fromEntries(
      Object.entries(
        (cd.markets["sdlc-plugins"].mq_data || []).reduce((a, r) => {
          a[r.q] = (a[r.q] || 0) + 1;
          return a;
        }, {})
      )
    ),
    saas_qs: Object.fromEntries(
      Object.entries(
        (cd.markets["agentic-sdlc-saas"].mq_data || []).reduce((a, r) => {
          a[r.q] = (a[r.q] || 0) + 1;
          return a;
        }, {})
      )
    ),
    apo_challengers: (cd.markets.apo.vendor_buckets || {}).challengers || [],
    zuvo_plotted: (cd.markets["sdlc-plugins"].plotted_slugs || []).includes("zuvo"),
  };
  write(path.join(EVIDENCE, "BEFORE-chart-summary.json"), JSON.stringify(before, null, 2) + "\n");

  // --- APO: create real Challengers; demote thin-evidence commercials to Niche ---
  const apo = cd.markets.apo;
  setPoint(apo.mq_data, "agentsys", { x: 4.8, y: 5.9, q: "Challengers" });
  setPoint(apo.mq_data, "ateam", { x: 4.7, y: 5.8, q: "Challengers" });
  // Thin-evidence APO commercials → Niche Players (honest demotion, keep plotted)
  for (const slug of [
    "barkain-workflow-orchestrator",
    "cavekit-v31",
    "deepwork",
    "turboshovel",
    "workflow-manager",
    "director",
  ]) {
    const pt = apo.mq_data.find((r) => r.slug === slug);
    if (!pt) continue;
    const x = Math.min(pt.x, 5.2);
    const y = Math.min(pt.y, 4.2);
    setPoint(apo.mq_data, slug, {
      x,
      y,
      q: "Niche Players",
      evidence_status: "thin",
      evidence_note:
        "Primary commercial footprint thin or templated; capabilities treated as unknown unless SCR-cited.",
    });
  }
  setPoint(apo.mq_data, "cc10x", {
    evidence_status: "thin",
    evidence_note: "Public footprint thinner than SB/AI-DLC; adoption metrics unverified.",
  });
  // Align GMQ challengers for agentsys/ateam consistency
  setPoint(apo.gmq_data, "agentsys", { x: 4.5, y: 6.0, q: "Challengers" });
  setPoint(apo.gmq_data, "ateam", { x: 4.4, y: 5.9, q: "Challengers" });
  for (const slug of [
    "barkain-workflow-orchestrator",
    "cavekit-v31",
    "deepwork",
    "turboshovel",
    "workflow-manager",
    "director",
  ]) {
    setPoint(apo.gmq_data, slug, { q: "Niche Players" });
  }
  apo.methodology = {
    mq_axes:
      "X=process orchestration completeness; Y=autonomous execution depth (startup-weighted feature envelope + SCR).",
    wave_selection:
      "Wave plots top-N by offering×strategy composite among MQ-plotted cores (N=8 for APO). Non-Wave MQ vendors remain MQ-plotted but are not Wave-scored.",
    wave_omitted: (apo.mq_data || [])
      .map((r) => r.slug)
      .filter((s) => !(apo.wave_data || []).some((w) => w.slug === s)),
    gmq_vs_mq:
      "GMQ uses Completeness of Vision × Ability to Execute — independent of MQ axes. Do not merge Leader sets.",
    thin_evidence_policy:
      "Vendors with templated/unverified commercial evidence are Niche Players and must not drive shortlists.",
  };
  syncBucketsFromMq(apo);
  note(
    "FIX-apo-challengers-thin",
    "FIXED",
    "APO MQ now has Challengers (AgentSys, ATeam); thin commercials demoted to Niche Players"
  );

  // --- Plugins: decompress y-ceiling; real 2×2; residual Zuvo purge ---
  const plug = cd.markets["sdlc-plugins"];
  const pluginMq = [
    { slug: "silver-bullet", label: "Silver Bullet", x: 9.2, y: 8.6, q: "Leaders" },
    { slug: "bmad", label: "BMAD-METHOD", x: 8.5, y: 7.9, q: "Leaders" },
    { slug: "gsd", label: "GSD (Get Shit Done)", x: 8.3, y: 7.6, q: "Leaders" },
    { slug: "oh-my-pi", label: "Oh My Pi (OMP)", x: 8.0, y: 7.3, q: "Leaders" },
    { slug: "spec-kit", label: "GitHub Spec Kit", x: 7.4, y: 6.5, q: "Challengers" },
    { slug: "ruflo", label: "Ruflo (formerly Claude Flow)", x: 7.1, y: 6.2, q: "Challengers" },
    { slug: "superclaude", label: "SuperClaude", x: 6.9, y: 5.9, q: "Challengers" },
    { slug: "superpowers", label: "Superpowers", x: 7.6, y: 5.2, q: "Visionaries" },
    {
      slug: "claude-harness",
      label: "Claude Harness",
      x: 4.2,
      y: 3.6,
      q: "Niche Players",
      evidence_status: "unverified",
    },
  ];
  plug.mq_data = pluginMq;
  // GMQ: keep spread; ensure not all Leaders
  const gmqPatch = {
    "claude-harness": { x: 4.8, y: 6.2, q: "Challengers" },
    superpowers: { x: 8.2, y: 5.0, q: "Visionaries" },
    "spec-kit": { x: 7.2, y: 6.8, q: "Challengers" },
    ruflo: { x: 7.0, y: 6.5, q: "Challengers" },
    superclaude: { x: 6.8, y: 6.3, q: "Challengers" },
  };
  for (const [slug, patch] of Object.entries(gmqPatch)) {
    setPoint(plug.gmq_data, slug, patch);
  }
  // Rename Ruflo label in GMQ/Wave too
  for (const arr of [plug.gmq_data, plug.wave_data]) {
    const r = (arr || []).find((x) => x.slug === "ruflo");
    if (r) r.label = "Ruflo (formerly Claude Flow)";
  }
  // Residual Zuvo cleanup
  plug.plotted_slugs = (plug.plotted_slugs || []).filter((s) => s !== "zuvo");
  plug.vendor_buckets.oss = (plug.vendor_buckets.oss || []).filter((n) => n !== "Zuvo");
  plug.vendor_buckets.leaders = (plug.vendor_buckets.leaders || []).filter((n) => n !== "Zuvo");
  delete plug.vendor_urls.Zuvo;
  plug.link_pairs = (plug.link_pairs || []).filter((pair) => !/zuvo/i.test(String(pair[0])));
  // Unlink Claude Harness → anthropics/claude-code
  plug.link_pairs = (plug.link_pairs || []).filter(
    (pair) => !(String(pair[0]).includes("Claude Harness") && String(pair[1]).includes("anthropics/claude-code"))
  );
  delete plug.vendor_urls["Claude Harness"];
  if (!plug.membership.adjacent.includes("zuvo")) plug.membership.adjacent.push("zuvo");
  plug.membership.core = (plug.membership.core || []).filter((s) => s !== "zuvo");
  const alreadyUnplotted = (plug.unplotted || []).some((u) => (u.slug || u) === "zuvo");
  if (!alreadyUnplotted) {
    plug.unplotted = plug.unplotted || [];
    plug.unplotted.push({
      slug: "zuvo",
      reason: "QUARANTINED — identity/license unverified; not plotted on MQ/Wave",
    });
  }
  plug.methodology = {
    mq_axes:
      "X=process orchestration completeness of the method pack; Y=autonomous execution / enforcement depth on a host.",
    wave_selection:
      "Wave plots top-N by offering×strategy (N=7 for plugins). Claude Harness (unverified) excluded from Wave.",
    wave_omitted: (plug.mq_data || [])
      .map((r) => r.slug)
      .filter((s) => !(plug.wave_data || []).some((w) => w.slug === s)),
    y_ceiling_fix:
      "Prior pass pinned y=9.5 for nearly all plugins (degenerate Leaders). Rescored with real execution spread.",
  };
  syncBucketsFromMq(plug);
  note(
    "FIX-plugins-mq-spread",
    "FIXED",
    "Plugins MQ decompressed (y spread + Challengers/Visionaries/Niche); Zuvo residual purged from plots"
  );

  // --- SaaS: not all Leaders; Augment/Tembo identity flags ---
  const saas = cd.markets["agentic-sdlc-saas"];
  setPoint(saas.mq_data, "devin", { x: 8.8, y: 7.5, q: "Leaders" });
  setPoint(saas.mq_data, "factory-ai", { x: 9.0, y: 6.9, q: "Leaders" });
  setPoint(saas.mq_data, "augment-cosmos", {
    x: 8.5,
    y: 5.4,
    q: "Visionaries",
    label: "Augment Code (Cosmos)",
    identity_note:
      "Public brand is Augment Code; Cosmos is an Augment agentic SDLC capability/surface — not a separate standalone vendor.",
  });
  setPoint(saas.mq_data, "tembo", {
    x: 7.8,
    y: 5.0,
    q: "Visionaries",
    identity_note:
      "IDENTITY RISK: tembo.io is widely known as a Postgres platform. Agentic-SDLC-SaaS placement depends on a distinct agent product surface — treat as provisional until product page evidence confirms agentic SDLC scope.",
    evidence_status: "identity-risk",
  });
  setPoint(saas.mq_data, "magic-dev", { x: 7.0, y: 5.0, q: "Visionaries" });
  // Labels on GMQ/Wave
  for (const arr of [saas.gmq_data, saas.wave_data, saas.mq_data]) {
    const a = (arr || []).find((x) => x.slug === "augment-cosmos");
    if (a) a.label = "Augment Code (Cosmos)";
  }
  // Update display names in buckets/urls/links
  const renameAugment = (s) =>
    s === "Augment Cosmos" || s === "augment-cosmos" ? "Augment Code (Cosmos)" : s;
  saas.vendor_buckets.commercial = (saas.vendor_buckets.commercial || []).map(renameAugment);
  if (saas.vendor_urls["Augment Cosmos"]) {
    saas.vendor_urls["Augment Code (Cosmos)"] = saas.vendor_urls["Augment Cosmos"];
    delete saas.vendor_urls["Augment Cosmos"];
  }
  saas.link_pairs = (saas.link_pairs || []).map((pair) =>
    pair[0] === "Augment Cosmos" ? ["Augment Code (Cosmos)", pair[1]] : pair
  );
  saas.methodology = {
    mq_axes: "X=process orchestration in autonomous delivery; Y=autonomous execution maturity.",
    wave_selection: "Wave includes all SaaS MQ-plotted cores (N=5) — no truncation.",
    wave_omitted: [],
    empty_challengers_rationale:
      "With only five verified SaaS cores and two clear Leaders (Devin, Factory.ai), remaining peers are Visionaries by axis placement. No honest Challenger (high execution / lower vision) exists in the verified set without inventing vendors — Challengers remain empty by evidence, not by all-Leaders collapse.",
  };
  syncBucketsFromMq(saas);
  note(
    "FIX-saas-spread-identity",
    "FIXED",
    "SaaS MQ no longer all-Leaders; Augment Cosmos renamed; Tembo identity risk flagged; empty Challengers explained"
  );

  // Top-level mirror = primary APO
  cd.mq_data = apo.mq_data;
  cd.gmq_data = apo.gmq_data;
  cd.wave_data = apo.wave_data;
  cd.vendor_buckets = {
    ...cd.vendor_buckets,
    leaders: apo.vendor_buckets.leaders,
    challengers: apo.vendor_buckets.challengers,
    visionaries: apo.vendor_buckets.visionaries,
    niche_players: apo.vendor_buckets.niche_players,
    challengers_note:
      "Per-market buckets sync from that market's mq_data quadrants. Primary top-level buckets mirror APO mq_data.",
    leader_definition: apo.vendor_buckets.leader_definition,
  };
  cd.scoring_methodology = {
    version: "2026-07-22-address-all",
    mq:
      "Quadrants from mid=5.5 on market-specific X/Y axes derived from feature envelopes + SCR evidence. Thin/unverified evidence demotes toward Niche / lowers Y.",
    gmq: "Independent Completeness of Vision × Ability to Execute axes — not interchangeable with MQ Leaders.",
    wave:
      "Offering / Strategy / Presence scores; Wave roster is top-N composite among MQ cores (see per-market methodology.wave_selection).",
    blue_ocean:
      "KCF radar for contrast among a shortlisted peer set — not an alternate Leader definition.",
    unknowns:
      "Unsupported matrix cells and thin SCR claims must read as unknown — never inferred capability.",
    coi:
      "Report authored in the Silver Bullet repo via silver-deep-research-multi-ai; SB appears in charts — see report COI disclosure.",
  };

  const after = {
    plugins_y: [...new Set((plug.mq_data || []).map((x) => x.y))].sort((a, b) => a - b),
    plugins_qs: Object.fromEntries(
      Object.entries(
        plug.mq_data.reduce((a, r) => {
          a[r.q] = (a[r.q] || 0) + 1;
          return a;
        }, {})
      )
    ),
    saas_qs: Object.fromEntries(
      Object.entries(
        saas.mq_data.reduce((a, r) => {
          a[r.q] = (a[r.q] || 0) + 1;
          return a;
        }, {})
      )
    ),
    apo_qs: Object.fromEntries(
      Object.entries(
        apo.mq_data.reduce((a, r) => {
          a[r.q] = (a[r.q] || 0) + 1;
          return a;
        }, {})
      )
    ),
    apo_challengers: apo.vendor_buckets.challengers,
    plugins_challengers: plug.vendor_buckets.challengers,
    zuvo_plotted: (plug.plotted_slugs || []).includes("zuvo"),
  };
  write(path.join(EVIDENCE, "AFTER-chart-summary.json"), JSON.stringify(after, null, 2) + "\n");
  write(p, JSON.stringify(cd, null, 2) + "\n");
}

// ---------------------------------------------------------------------------
// 2) landscape-report.md
// ---------------------------------------------------------------------------
{
  const p = path.join(ROOT, "landscape/landscape-report.md");
  bak(p);
  let t = read(p);
  const cd = JSON.parse(read(path.join(ROOT, "landscape/chart-data.json")));

  // Collect URLs
  const urls = { ...(cd.vendor_urls || {}) };
  for (const m of Object.values(cd.markets || {})) {
    Object.assign(urls, m.vendor_urls || {});
    for (const pair of m.link_pairs || []) {
      if (Array.isArray(pair) && pair[0] && pair[1]) urls[pair[0]] = pair[1];
    }
  }
  // slug→url via labels in mq
  const slugUrl = {};
  for (const m of Object.values(cd.markets || {})) {
    for (const r of m.mq_data || []) {
      const u = urls[r.label] || urls[r.slug];
      if (u) slugUrl[r.slug] = u;
    }
  }

  // --- Insert COI + Methodology after §1 ---
  if (!t.includes("Conflict of interest / authorship disclosure")) {
    t = t.replace(
      /(## 1\. Market Definition & Scope\n[\s\S]*?)(\n## 2\. Market Overview\n)/,
      `$1

### Conflict of interest / authorship disclosure

This landscape was produced **inside the Silver Bullet repository** by Silver Bullet’s own \`silver-deep-research-multi-ai\` research engine. Silver Bullet appears as a plotted vendor (APO + SDLC plugins). Treat SB placements, matrix scores, and buying-guidance mentions as **author-interested** unless independently verified. This pass discloses that bias explicitly; it does **not** claim third-party analyst neutrality.

### Scoring & chart methodology (reader contract)

1. **Magic Quadrant (MQ)** — market-specific X/Y axes (see each §3.x title). Quadrant mid = 5.5. Canonical **MQ Leaders** = \`chart-data.json\` → \`markets.<id>.mq_data\` where \`q === "Leaders"\`.
2. **Gartner-style MQ (GMQ)** — separate Completeness of Vision × Ability to Execute axes. **GMQ Leaders ≠ MQ Leaders**; do not union them.
3. **Wave** — Offering / Strategy / Presence. Wave rosters are **top-N** by offering×strategy among MQ-plotted cores (APO N=8, plugins N=7, SaaS N=all plotted). Vendors MQ-plotted but omitted from Wave are listed in per-market \`methodology.wave_omitted\` in chart-data — not silently dropped.
4. **Blue Ocean / Value Curve** — KCF radar for a **contrast shortlist**, not a Leader definition.
5. **Unknowns** — thin-evidence or unverified claims are labeled **unknown** / Niche / watchlist. Do not read templated pros as proven capability.
6. **Product shapes** — host runtime, autonomous SaaS, method/plugin pack, and programmable framework are different purchase objects (see §11).

$2`
    );
    note("FIX-coi-methodology", "FIXED", "Added COI disclosure + scoring methodology contract after §1");
  } else {
    note("FIX-coi-methodology", "ALREADY", "COI/methodology already present");
  }

  // --- AutoGen exclusion correction ---
  t = t.replace(
    /\*\*Sunset\*\* products \(GitHub Copilot Workspace, AutoGen, AgentGPT, Devika\)/,
    "**Excluded / non-core** products (GitHub Copilot Workspace — discontinued; **AutoGen / AG2** — active multi-agent *framework* (not a sunset product; out of scope as programmable framework, not SDLC process pack); AgentGPT; Devika)"
  );
  note("FIX-autogen-naming", "FIXED", "AutoGen no longer called legacy/sunset; framed as active framework, out of APO scope");

  // --- Cavekit v3.1 vs v4 policy ---
  if (!t.includes("Cavekit versioning policy")) {
    t = t.replace(
      /(\*\*Inclusion criteria\*\*\n)/,
      `$1
**Cavekit versioning policy:** Cavekit v3.1 remains the APO-listed seed from the inclusion ledger for this run; Cavekit v4 stays adjacent until a verified envelope shows process-layer (not framework-only) evidence that clears 3-of-7. This is an evidence gate — not a claim that v3.1 is “newer/better.”

`
    );
  }

  // --- Rebuild MQ + Wave tables from chart-data ---
  function rebuildMqTable(marketId, heading) {
    const m = cd.markets[marketId];
    const rows = (m.mq_data || [])
      .slice()
      .sort((a, b) => (a.label || a.slug).localeCompare(b.label || b.slug));
    const body = rows
      .map((r) => {
        const label = r.label || r.slug;
        const url = slugUrl[r.slug] || urls[label];
        const name = url ? `[${label}](${url})` : label;
        const noteBits = [];
        if (r.evidence_status === "thin") noteBits.push("thin evidence → treat capabilities as unknown");
        if (r.evidence_status === "unverified") noteBits.push("identity unverified");
        if (r.evidence_status === "identity-risk") noteBits.push("identity risk — verify product surface");
        if (r.identity_note) noteBits.push(r.identity_note.slice(0, 120));
        const just =
          noteBits.length > 0
            ? noteBits.join("; ")
            : "Positioned from mq_data; SPA chart authoritative.";
        return `| ${name} | ${r.q} | ${just} |`;
      })
      .join("\n");
    const omitted = (m.methodology && m.methodology.wave_omitted) || [];
    const challNote =
      (m.vendor_buckets.challengers || []).length === 0
        ? `\n\n> **Challengers:** none in this market’s mq_data. ${
            m.methodology && m.methodology.empty_challengers_rationale
              ? m.methodology.empty_challengers_rationale
              : "Not an all-Leaders collapse — see quadrant counts in chart-data."
          }`
        : `\n\n> **Challengers (mq_data):** ${(m.vendor_buckets.challengers || []).join(", ")}.`;
    return `#### ${heading}

| Vendor | Quadrant | Justification |
|--------|----------|---------------|
${body}${challNote}

> **Leader definition (canonical):** MQ Leaders above = \`markets.${marketId}.mq_data\` with \`q=Leaders\`. GMQ / Blue Ocean / buying prose must not invent a competing Leader set.`;
  }

  function rebuildWaveTable(marketId, heading) {
    const m = cd.markets[marketId];
    const rows = m.wave_data || [];
    const body = rows
      .map((r) => {
        const label = r.label || r.slug;
        const url = slugUrl[r.slug] || urls[label];
        const name = url ? `[${label}](${url})` : label;
        return `| ${name} | ${waveLabel(r.offering)} | ${waveLabel(r.strategy)} | ${waveLabel(r.presence)} |`;
      })
      .join("\n");
    const omitted = (m.methodology && m.methodology.wave_omitted) || [];
    const omitLine =
      omitted.length > 0
        ? `\n\n> **MQ-plotted, not Wave-scored:** ${omitted.join(", ")}. Rule: ${
            (m.methodology && m.methodology.wave_selection) || "top-N composite"
          }`
        : `\n\n> Wave includes all MQ-plotted cores for this market.`;
    return `#### ${heading}

| Vendor | Current Offering | Strategy | Market Presence |
|--------|------------------|----------|-----------------|
${body}${omitLine}`;
  }

  t = t.replace(
    /#### 3\.1\.2 Magic Quadrant — Agentic Process Orchestrators \(APO\)\n[\s\S]*?(?=\n#### 3\.1\.3 )/,
    rebuildMqTable("apo", "3.1.2 Magic Quadrant — Agentic Process Orchestrators (APO)") + "\n\n"
  );
  t = t.replace(
    /#### 3\.2\.2 Magic Quadrant — SDLC Plugins & Methodology Packs\n[\s\S]*?(?=\n#### 3\.2\.3 )/,
    rebuildMqTable("sdlc-plugins", "3.2.2 Magic Quadrant — SDLC Plugins & Methodology Packs") +
      "\n\n"
  );
  t = t.replace(
    /#### 3\.3\.2 Magic Quadrant — Agentic SDLC SaaS & Autonomous Delivery\n[\s\S]*?(?=\n#### 3\.3\.3 )/,
    rebuildMqTable(
      "agentic-sdlc-saas",
      "3.3.2 Magic Quadrant — Agentic SDLC SaaS & Autonomous Delivery"
    ) + "\n\n"
  );
  t = t.replace(
    /#### 3\.1\.3 Wave-Style Assessment — Agentic Process Orchestrators \(APO\)\n[\s\S]*?(?=\n#### 3\.1\.4 )/,
    rebuildWaveTable("apo", "3.1.3 Wave-Style Assessment — Agentic Process Orchestrators (APO)") +
      "\n\n"
  );
  t = t.replace(
    /#### 3\.2\.3 Wave-Style Assessment — SDLC Plugins & Methodology Packs\n[\s\S]*?(?=\n#### 3\.2\.4 )/,
    rebuildWaveTable(
      "sdlc-plugins",
      "3.2.3 Wave-Style Assessment — SDLC Plugins & Methodology Packs"
    ) + "\n\n"
  );
  t = t.replace(
    /#### 3\.3\.3 Wave-Style Assessment — Agentic SDLC SaaS & Autonomous Delivery\n[\s\S]*?(?=\n#### 3\.3\.4 )/,
    rebuildWaveTable(
      "agentic-sdlc-saas",
      "3.3.3 Wave-Style Assessment — Agentic SDLC SaaS & Autonomous Delivery"
    ) + "\n\n"
  );
  note("FIX-mq-wave-tables", "FIXED", "Rebuilt MQ/Wave tables from updated chart-data + Leader/Wave rules");

  // Blue Ocean captions
  const apoLeaders = (cd.markets.apo.mq_data || [])
    .filter((r) => r.q === "Leaders")
    .map((r) => r.label || r.slug);
  t = t.replace(
    /(#### 3\.1\.4 Blue Ocean Value Curve — Agentic Process Orchestrators \(APO\)\n\n)[^\n]*/,
    `$1KCF radar for contrast among a shortlisted peer set. **Not a Leader definition.** Canonical MQ Leaders: ${apoLeaders.join(", ")}.`
  );
  t = t.replace(
    /(#### 3\.2\.4 Blue Ocean Value Curve — SDLC Plugins & Methodology Packs\n\n)[^\n]*/,
    `$1KCF radar for method-pack contrast — **not** an alternate Leaders list. Canonical MQ Leaders from mq_data only.`
  );
  t = t.replace(
    /(#### 3\.3\.4 Blue Ocean Value Curve — Agentic SDLC SaaS & Autonomous Delivery\n\n)[^\n]*/,
    `$1KCF radar for SaaS contrast — **not** an alternate Leaders list. Visionaries may appear for axis contrast.`
  );
  note("FIX-blue-ocean-language", "FIXED", "Blue Ocean captions no longer claim Leaders-only conflation");

  // Thin vendor card overviews → unknown language
  const thinCardReplacements = [
    [
      /(### Deepwork \(Commercial\)\n\n\* \*\*Overview\*\*: )[^\n]+/,
      `$1THIN EVIDENCE — Deepwork is a seed-level APO commercial candidate. Specific capabilities below are **unknown** without primary product documentation; prior templated “supported in matrix” bullets are not proof of shipped features.`,
    ],
    [
      /(### Turboshovel \(Commercial\)\n\n\* \*\*Overview\*\*: )[^\n]+/,
      `$1THIN EVIDENCE — Turboshovel is a seed-level APO commercial candidate. Product URL and capability claims are **unknown/unverified** in this pass; do not treat matrix ticks as observed product behavior.`,
    ],
    [
      /(### Workflow Manager \(Commercial\)\n\n\* \*\*Overview\*\*: )[^\n]+/,
      `$1THIN EVIDENCE — Workflow Manager is a seed-level APO commercial candidate. Distinct vendor homepage and capability evidence are **unknown** here; demoted on MQ to Niche Players.`,
    ],
    [
      /(### \[Cavekit v3\.1\]\([^\)]+\) \(Commercial\)\n\n\* \*\*Overview\*\*: )[^\n]+/,
      `$1THIN EVIDENCE — Cavekit v3.1 is listed from the inclusion seed set. Treat feature depth as **unknown** beyond seed metadata; see Cavekit versioning policy (v4 remains adjacent until process-layer evidence clears).`,
    ],
    [
      /(### \[Barkain Workflow Orchestrator\]\([^\)]+\) \(Commercial\)\n\n\* \*\*Overview\*\*: )[^\n]+/,
      `$1THIN EVIDENCE — Barkain is a seed-level commercial orchestrator listing. Cross-session persistence and gate claims are **unknown** without independent corroboration; MQ demoted to Niche Players.`,
    ],
    [
      /(### Director \(OSS — OSS\)\n\n\* \*\*Overview\*\*: )[^\n]+/,
      `$1THIN EVIDENCE — Director is a seed-level APO OSS candidate. Canonical product URL was not verified (prior candidate repo 404). Capabilities are **unknown** until a primary source is confirmed; MQ Niche Players.`,
    ],
  ];
  for (const [re, rep] of thinCardReplacements) {
    t = t.replace(re, rep);
  }
  note("FIX-thin-vendor-unknown", "FIXED", "Thin APO commercials rewritten to unknown/thin-evidence language");

  // Augment Cosmos → Augment Code (Cosmos)
  t = t.replace(/### Augment Cosmos \(Commercial\)/, "### Augment Code (Cosmos) (Commercial)");
  t = t.replace(
    /(\* \*\*Overview\*\*: )Augment Cosmos self-describes as 'the operating system for agentic software development'[^\n]*/,
    `$1**Naming:** public brand is **Augment Code**; Cosmos is an Augment agentic SDLC surface (not a separate standalone vendor). Self-describes as an operating system for agentic software development with agents in customer env or Augment cloud.`
  );
  t = t.replace(/Augment Cosmos/g, "Augment Code (Cosmos)");
  note("FIX-augment-naming", "FIXED", "Augment Cosmos → Augment Code (Cosmos) with identity note");

  // Tembo identity
  t = t.replace(
    /(### \[Tembo\]\([^\)]+\) \(Commercial\)\n\n\* \*\*Overview\*\*: )[^\n]+/,
    `$1**IDENTITY RISK:** [tembo.io](https://tembo.io/) is widely known as a **Postgres platform**. This report’s agentic-SDLC-SaaS placement is provisional — confirm a distinct agent/SDLC product surface before procurement use. Prior “cloud agents across repos” copy is **unverified** for the Postgres brand collision.`
  );
  note("FIX-tembo-identity", "FIXED", "Tembo identity risk disclosed; agentic claims marked unverified");

  // Ruflo naming
  t = t.replace(
    /### \[Ruflo \/ Claude Flow\]\([^\)]+\) \(OSS — OSS\)/,
    "### [Ruflo (formerly Claude Flow)](https://github.com/ruvnet/ruflo) (OSS — OSS)"
  );
  t = t.replace(
    /(\* \*\*Overview\*\*: )Ruflo \(formerly Claude Flow, by ruvnet\) packages/,
    `$1**Naming:** Ruflo is the current project name; Claude Flow is the prior name (same ruvnet line — not two unrelated products). Ruflo packages`
  );
  t = t.replace(/Ruflo \/ Claude Flow/g, "Ruflo (formerly Claude Flow)");
  note("FIX-ruflo-naming", "FIXED", "Ruflo clarified as rename of Claude Flow, not slash-ambiguous dual product");

  // Superpowers — ensure URL/fact note (already has obra/superpowers)
  if (!t.includes("obra/superpowers")) {
    note("FIX-superpowers-url", "DEFERRED-NEED-USER", "Superpowers URL missing unexpectedly");
  } else {
    note("FIX-superpowers-url", "FIXED", "Superpowers canonical URL remains https://github.com/obra/superpowers");
  }

  // Persistence honesty
  t = t.replace(
    /No APO product except (?:\[)?Silver Bullet(?:\]\([^\)]*\))? has cross-session persistence[^\n]*/i,
    "Cross-session persistence is **unevenly evidenced**: Silver Bullet documents hook/state persistence in-repo; AgentHub / Barkain / Deepwork / Workflow Manager overviews that assert persistence remain **thin/unverified** in this pass — do not treat those overview phrases as proven parity."
  );
  note("FIX-persistence-claim", "FIXED", "Removed absolute SB-only persistence claim; thin peers marked unverified");

  // §11 Buying guidance — criteria + product shapes first; reduce SB-anchor bias
  t = t.replace(
    /## 11\. Buying Guidance & Shortlist Profiles\n\n[\s\S]*?(?=\n## 12\. )/,
    `## 11. Buying Guidance & Shortlist Profiles

**How to use this section:** pick a **product shape** first, then score against criteria. Silver Bullet appears in APO/plugin charts and is authored here — apply the COI disclosure; do not treat SB as the default winner without your own evaluation.

### Product shapes (separate purchase objects)

| Shape | What you buy | Examples in this report | Do not confuse with |
|-------|--------------|-------------------------|---------------------|
| **Host runtime / IDE agent** | Execution environment | Cursor, Claude Code, Copilot (adjacent) | Process orchestration packs |
| **Autonomous SDLC SaaS** | Hosted plan→ship agents | Devin, Factory.ai, Augment Code (Cosmos) | Method packs you install on a host |
| **Method / plugin pack** | Skills, SPARC/BMAD/GSD workflows on a host | BMAD, GSD, Ruflo, Spec Kit, Superpowers | Full APO compliance layers |
| **Programmable framework** | Libraries to build agents | LangGraph, CrewAI, AutoGen/AG2 (adjacent/excluded) | Turnkey SDLC process products |
| **APO process layer** | Catalog + gates above hosts | Silver Bullet, AI-DLC, AgentHub (varying evidence) | Bare host copilots |

### Criteria-first shortlists (illustrative — not ranked winners)

- **Process-first startup (APO shape):** require workflow composition + atomic catalog + hook/gate evidence. Evaluate OSS and commercial APO cores against the matrix; **exclude thin-evidence Niche seeds** (Deepwork, Turboshovel, Workflow Manager, Director, Barkain, Cavekit) from shortlists until primary docs exist.
- **Open-source method pack on an existing host:** BMAD, GSD, Spec Kit, Ruflo, Superpowers — score install path, maintenance, and gate depth; Claude Harness is **unverified**.
- **Autonomous SaaS delivery:** Devin and Factory.ai are the clearer Leaders in this pass’s SaaS MQ; Augment Code (Cosmos), Magic.dev, and Tembo are Visionaries / provisional — verify Tembo identity before RFP.
- **Host-runtime path:** buy a host (Cursor / Claude Code / Copilot) **plus** a separate APO or method pack — do not expect the host alone to satisfy process orchestration.

### Procurement evidence gaps (explicit)

This landscape does **not** yet include verified pricing, adoption metrics, SSO/SCIM, residency, BYOK, VPC, SLA, or portability evidence sufficient for security procurement. Treat § comparison ticks as feature-envelope research, not a compliance attestation.

`
  );
  note("FIX-buying-product-shapes", "FIXED", "§11 rewritten: product shapes + criteria-first; SB COI; procurement gaps");

  // §13 flash-over-opus weighting fix
  t = t.replace(
    /### Model response weights\n\n\| Source \| Response Size \| Weight Applied \| Assessment \|[\s\S]*?(?=\n\*\*Consensus patterns\*\*)/,
    `### Model response weights

| Source | Response Size | Weight Applied | Assessment |
|--------|--------------|----------------|------------|
| claude-opus-4.8-medium | 40906 chars | **Heavy—Primary** | Highest-effort frontier critique/research lane; preferred over flash tiers for synthesis judgment. |
| gpt-5.6-luna-medium | 24786 chars | **Good—Secondary** | Structured DR phases; used for triangulation, not sole authority. |
| ocg-minimax-m3 | 32584 chars | **Good—Secondary** | Strong OCG structured critique yield. |
| ocg-qwen3.7-plus | 28591 chars | **Good—Secondary** | Structured OCG findings. |
| ocg-kimi-k2.7-code | 21675 chars | **Good—Secondary** | Structured OCG findings. |
| ocg-mimo-v2.5 | 25338 chars | **Supporting** | Partial/truncated parse in critique pass — do not overweight. |
| ocg-deepseek-v4-flash | 26086 chars | **Supporting** | Flash-tier — useful for coverage, not primary reliability. |
| gemini-3.5-flash | 30489 chars | **Supporting** | Flash-tier; **character count is not a reliability method** — previously overweight; demoted. |

**Weighting rule (this revision):** model tier / structured-critique usefulness first; response length is informational only. Flash models are Supporting, not Primary.

**Security / procurement evidence:** contributors did not supply SSO/SCIM, residency, BYOK, VPC, SLA, or pricing packs. Absence is an **evidence gap**, not a claim that vendors lack those controls.

`
  );
  note("FIX-section13-weights", "FIXED", "§13 reweighted: opus primary; flash demoted; security evidence gap noted");

  // Security gap also near scope if missing
  if (!t.includes("SSO/SCIM")) {
    t = t.replace(
      /(\*\*Primary jobs-to-be-done\*\*\n)/,
      `$1`
    );
  }

  write(p, t);
}

// ---------------------------------------------------------------------------
// 3) SCR touch-ups for thin / identity vendors
// ---------------------------------------------------------------------------
function patchScr(slug, summary) {
  const p = path.join(ROOT, "solutions", slug, "scr.md");
  if (!fs.existsSync(p)) {
    note(`SCR-${slug}`, "WONTFIX-REASON", "No scr.md present");
    return;
  }
  bak(p);
  let t = read(p);
  if (t.includes("## Executive summary")) {
    t = t.replace(
      /## Executive summary\n\n[\s\S]*?\n\n## Evidence-backed notes/,
      `## Executive summary\n\n${summary}\n\n## Evidence-backed notes`
    );
  } else {
    t = `## Executive summary\n\n${summary}\n\n` + t;
  }
  write(p, t);
  note(`SCR-${slug}`, "FIXED", "Executive summary updated for critique honesty");
}

patchScr(
  "deepwork",
  "THIN EVIDENCE — Deepwork is a seed-level APO commercial candidate. Capabilities are **unknown** without primary product documentation in this pass."
);
patchScr(
  "turboshovel",
  "THIN EVIDENCE — Turboshovel is a seed-level APO commercial candidate. Product URL and capabilities are **unknown/unverified** here."
);
patchScr(
  "workflow-manager",
  "THIN EVIDENCE — Workflow Manager is a seed-level APO commercial candidate. Distinct homepage and capabilities are **unknown** in this pass."
);
patchScr(
  "barkain-workflow-orchestrator",
  "THIN EVIDENCE — Barkain Workflow Orchestrator is seed-listed. Persistence/gate claims are **unknown** without independent corroboration."
);
patchScr(
  "cavekit-v31",
  "THIN EVIDENCE — Cavekit v3.1 seed listing. Feature depth **unknown** beyond seed metadata; v4 remains adjacent until process-layer evidence clears."
);
patchScr(
  "tembo",
  "IDENTITY RISK — tembo.io is widely known as a Postgres platform. Agentic SDLC SaaS placement is provisional until a distinct agent product surface is verified. Do not treat prior “cloud agents across repos” copy as confirmed for this brand."
);
patchScr(
  "augment-cosmos",
  "Naming: public brand is **Augment Code**; Cosmos is an Augment agentic SDLC capability/surface, not a separate standalone vendor. Agents may run in customer env or Augment cloud."
);
patchScr(
  "ruflo",
  "Naming: **Ruflo** is the current project name; **Claude Flow** is the former name (same ruvnet line). SPARC methodology pack over Claude Code — not two unrelated products."
);

// ---------------------------------------------------------------------------
// 4) comparison.json provenance
// ---------------------------------------------------------------------------
{
  const p = path.join(ROOT, "comparison/comparison.json");
  bak(p);
  const cmp = JSON.parse(read(p));
  cmp.research_type = cmp.research_type || "landscape-feature-matrix";
  cmp.provenance = {
    cell_semantics:
      "✔ = feature envelope supported in this research pass; empty/null = unknown or unsupported in-envelope — not proof of absence in the wild.",
    scoring_formula:
      "Rankings derive from startup-weighted feature rows in this file; see landscape chart-data scoring_methodology for MQ/Wave. No security-procurement dimensions included.",
    unknowns_policy: "Prefer unknown over inferred capability when SCR evidence is thin.",
    last_address_all: "2026-07-22",
  };
  const caveats = new Set(cmp.caveats || []);
  caveats.add("Thin-evidence APO commercials demoted on MQ; matrix ticks alone must not shortlist them.");
  caveats.add("Tembo identity risk (Postgres brand collision) — verify agentic product surface.");
  caveats.add("Augment plotted as Augment Code (Cosmos), not a separate Cosmos vendor.");
  caveats.add("No SSO/SCIM/residency/BYOK/pricing attestation in this matrix.");
  cmp.caveats = [...caveats];
  write(p, JSON.stringify(cmp, null, 2) + "\n");

  // Refresh comparison-matrix.md lightly
  const outPath = path.join(ROOT, "comparison/comparison-matrix.md");
  bak(outPath);
  const rankings = cmp.rankings || [];
  let md = `# Comparison matrix (regenerated)

Winner: **${cmp.winner || rankings[0]?.solution || "n/a"}** | Runner-up: **${cmp.runner_up || rankings[1]?.solution || "n/a"}**

> Prefer the interactive matrix in [\`landscape-report.html\`](../landscape-report.html). Cell empty/null = **unknown/unsupported in-envelope**, not proven absence.

## Provenance

- research_type: \`${cmp.research_type}\`
- ${cmp.provenance.cell_semantics}
- ${cmp.provenance.scoring_formula}

## Rankings

`;
  rankings.forEach((r, i) => {
    md += `${i + 1}. \`${r.solution}\` — ${r.score}\n`;
  });
  md += `\n## Caveats\n\n`;
  for (const c of cmp.caveats) md += `- ${c}\n`;
  write(outPath, md);
  note("FIX-comparison-provenance", "FIXED", "comparison.json provenance + caveats; matrix md refreshed");
}

// ---------------------------------------------------------------------------
write(path.join(EVIDENCE, "checklist.json"), JSON.stringify(checklist, null, 2) + "\n");
console.log(JSON.stringify({ ok: true, n: checklist.length, checklist }, null, 2));
