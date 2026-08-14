#!/usr/bin/env node
/**
 * Surgical chart-data + catalog_audit membership fix (no score re-derive).
 * Transfers existing APO coords for plugin-class vendors; unique-X/Y jitter only.
 */
import fs from "fs";

const RUN = new URL("../../", import.meta.url).pathname.replace(/\/$/, "");
const CHART = `${RUN}/landscape/chart-data.json`;
const AUDIT = `${RUN}/landscape/catalog_audit.json`;

const REMOVE_APO = [
  "agenthub",
  "ateam",
  "cc10x",
  "cavekit-v31",
  "barkain-workflow-orchestrator",
];
const PLUGIN_SLUGS = ["cc10x", "cavekit-v31", "barkain-workflow-orchestrator"];
const HOSTING_IDX = 4;

function quadrant(x, y) {
  if (x >= 5.5 && y >= 5.5) return "Leaders";
  if (x < 5.5 && y >= 5.5) return "Challengers";
  if (x >= 5.5) return "Visionaries";
  return "Niche Players";
}

function uniqueNudge(pts, x, y) {
  const xs = new Set(pts.map((p) => p.x));
  const ys = new Set(pts.map((p) => p.y));
  let nx = x;
  let ny = y;
  while (xs.has(nx)) nx = Math.round((nx + 0.1) * 10) / 10;
  while (ys.has(ny)) ny = Math.round((ny + 0.1) * 10) / 10;
  return { x: nx, y: ny };
}

function hostingFix(series) {
  if (!series || !Array.isArray(series.data)) return series;
  const next = { ...series, data: [...series.data] };
  if (next.data[HOSTING_IDX] === 3) next.data[HOSTING_IDX] = 1;
  return next;
}

function rebuildMembership(core, adjacent, extraUnplotted = []) {
  const listed = [...new Set([...core, ...adjacent])].sort();
  const unplotted = adjacent.map((slug) => {
    const extra = extraUnplotted.find((u) => u.slug === slug);
    return extra || { slug, reason: "adjacent competitor — listed for the market, not MQ/Wave core" };
  });
  return { core: [...core].sort(), adjacent: [...adjacent].sort(), listed, unplotted };
}

const cd = JSON.parse(fs.readFileSync(CHART, "utf8"));
const apo = cd.markets.apo;
const plugins = cd.markets["sdlc-plugins"];
const saas = cd.markets["agentic-sdlc-saas"];

const apoMqKeep = apo.mq_data.filter((p) => !REMOVE_APO.includes(p.slug));
const apoGmqKeep = apo.gmq_data.filter((p) => !REMOVE_APO.includes(p.slug));
const apoWaveKeep = apo.wave_data.filter((p) => !REMOVE_APO.includes(p.slug));
const removedMq = Object.fromEntries(apo.mq_data.filter((p) => PLUGIN_SLUGS.includes(p.slug)).map((p) => [p.slug, p]));
const removedGmq = Object.fromEntries(apo.gmq_data.filter((p) => PLUGIN_SLUGS.includes(p.slug)).map((p) => [p.slug, p]));

const pluginAddsMq = [];
const pluginAddsGmq = [];
for (const slug of PLUGIN_SLUGS) {
  const srcM = removedMq[slug];
  const srcG = removedGmq[slug];
  const mqXY = uniqueNudge(plugins.mq_data.concat(pluginAddsMq), srcM.x, srcM.y);
  const gmqXY = uniqueNudge(plugins.gmq_data.concat(pluginAddsGmq), srcG.x, srcG.y);
  pluginAddsMq.push({
    slug,
    label: srcM.label,
    x: mqXY.x,
    y: mqXY.y,
    q: quadrant(mqXY.x, mqXY.y),
  });
  pluginAddsGmq.push({
    slug,
    label: srcG.label,
    x: gmqXY.x,
    y: gmqXY.y,
    q: quadrant(gmqXY.x, gmqXY.y),
  });
}

apo.mq_data = apoMqKeep;
apo.gmq_data = apoGmqKeep;
apo.wave_data = apoWaveKeep;
plugins.mq_data = [...plugins.mq_data, ...pluginAddsMq].sort((a, b) => a.slug.localeCompare(b.slug));
plugins.gmq_data = [...plugins.gmq_data, ...pluginAddsGmq].sort((a, b) => a.slug.localeCompare(b.slug));

const apoCore = apoMqKeep.map((p) => p.slug).sort();
const apoAdj = [...new Set([...apo.membership.adjacent, "agenthub", "devin"])].sort();
apo.membership = rebuildMembership(apoCore, apoAdj, [
  {
    slug: "agenthub",
    reason: "adjacent client-automation CRM (agenthub.ai) — not an SDLC process orchestrator; not MQ/Wave core",
  },
  {
    slug: "devin",
    reason: "APO-adjacent autonomous SWE; agentic-sdlc-saas core (plotted there) — not an APO process-orchestrator peer",
  },
]);

const pluginCore = [...new Set([...plugins.membership.core, ...PLUGIN_SLUGS])].sort();
plugins.membership = rebuildMembership(pluginCore, plugins.membership.adjacent);

function syncPlotFields(market) {
  const mqSlugs = (market.mq_data || []).map((p) => p.slug).filter(Boolean).sort();
  market.membership.core = [...new Set([...(market.membership.core || []), ...mqSlugs])].sort();
  market.plotted_slugs = mqSlugs;
  market.listed_slugs = [...(market.membership.listed || [])].sort();
  market.unplotted = market.membership.unplotted || [];
}
syncPlotFields(apo);
syncPlotFields(plugins);
syncPlotFields(saas);

function bucketsFrom(mq, commercialLabels, ossLabels) {
  const leaders = mq.filter((p) => p.q === "Leaders").map((p) => p.label).sort();
  return {
    commercial: commercialLabels.sort(),
    oss: ossLabels.sort(),
    leaders,
    challengers: [],
  };
}

apo.vendor_buckets = bucketsFrom(
  apo.mq_data,
  ["Deepwork", "Turboshovel", "Workflow Manager"],
  ["AgentSys", "AI-DLC", "Director", "MetaGPT", "Silver Bullet"],
);
plugins.vendor_buckets = bucketsFrom(
  plugins.mq_data,
  [],
  [
    ...plugins.vendor_buckets.oss,
    "cc10x",
    "Cavekit v3.1",
    "Barkain Workflow Orchestrator",
  ].filter((v, i, a) => a.indexOf(v) === i),
);

apo.vc_oss = (apo.vc_oss || []).filter((s) => ["Silver Bullet", "AI-DLC"].includes(s.label)).map(hostingFix);
apo.vc_commercial = [];
plugins.vc_oss = (plugins.vc_oss || []).map(hostingFix);
plugins.vc_commercial = [];
saas.vc_oss = saas.vc_oss || [];
saas.vc_commercial = saas.vc_commercial || [];

cd.mq_data = apo.mq_data;
cd.gmq_data = apo.gmq_data;
cd.wave_data = apo.wave_data;
cd.vc_oss = apo.vc_oss;
cd.vc_commercial = apo.vc_commercial;
cd.membership = apo.membership;
cd.plotted_slugs = apo.membership.core;
cd.listed_slugs = apo.membership.listed;
cd.unplotted = apo.membership.unplotted;
cd.vendor_buckets = {
  commercial: [
    "Augment Cosmos",
    "Deepwork",
    "Devin",
    "Factory.ai",
    "Magic.dev",
    "Turboshovel",
    "Workflow Manager",
    "AxonFlow",
    "Cavekit v4",
    "Claude Code",
    "Codex",
    "Cognition Scout",
    "Conductor",
    "Cursor",
    "GitHub Copilot",
    "Replit Agent",
    "Tembo",
    "AgentHub",
  ].sort(),
  oss: [
    "AgentSys",
    "AI-DLC",
    "BMAD-METHOD",
    "Barkain Workflow Orchestrator",
    "Cavekit v3.1",
    "Claude Harness",
    "Director",
    "GSD (Get Shit Done)",
    "MetaGPT",
    "Oh My Pi (OMP)",
    "Ruflo / Claude Flow",
    "Silver Bullet",
    "GitHub Spec Kit",
    "SuperClaude",
    "Superpowers",
    "Zuvo",
    "cc10x",
    "CrewAI",
    "LangChain",
    "LangGraph",
  ].sort(),
  leaders: apo.vendor_buckets.leaders,
  challengers: [],
};

function assertUnique(label, pts) {
  const xs = pts.map((p) => p.x);
  const ys = pts.map((p) => p.y);
  if (xs.length !== new Set(xs).size || ys.length !== new Set(ys).size) {
    throw new Error(`shared axis in ${label}: x=${xs} y=${ys}`);
  }
}
assertUnique("apo.mq", apo.mq_data);
assertUnique("apo.gmq", apo.gmq_data);
assertUnique("plugins.mq", plugins.mq_data);
assertUnique("plugins.gmq", plugins.gmq_data);
assertUnique("saas.mq", saas.mq_data);
assertUnique("saas.gmq", saas.gmq_data);

fs.writeFileSync(CHART, JSON.stringify(cd, null, 2) + "\n");

const audit = JSON.parse(fs.readFileSync(AUDIT, "utf8"));
audit.core = apoCore;
audit.markets.apo.core = apoCore;
audit.markets.apo.adjacent = apoAdj;
audit.markets.apo.excluded = [...new Set([...audit.markets.apo.excluded.filter((s) => !apoCore.includes(s) && !apoAdj.includes(s)), "ateam"])].sort();
audit.markets["sdlc-plugins"].core = pluginCore;
audit.markets["sdlc-plugins"].excluded = audit.markets["sdlc-plugins"].excluded.filter((s) => !PLUGIN_SLUGS.includes(s)).sort();
if (!audit.by_slug) audit.by_slug = {};
audit.by_slug.agenthub = {
  classification: "adjacent",
  reason: "client-automation CRM — APO adjacent, not core",
};
audit.by_slug.ateam = {
  classification: "excluded",
  reason: "FDE / professional services — not APO",
};
audit.by_slug.cc10x = { classification: "core", reason: "sdlc-plugins market_core (Claude Code plugin class)" };
audit.by_slug["cavekit-v31"] = { classification: "core", reason: "sdlc-plugins market_core (Claude Code plugin class)" };
audit.by_slug["barkain-workflow-orchestrator"] = {
  classification: "core",
  reason: "sdlc-plugins market_core (Claude Code plugin class)",
};
audit.by_slug.devin = {
  classification: "core",
  reason: "agentic-sdlc-saas market_core; APO adjacent (not APO core)",
};
audit.counts = {
  ...audit.counts,
  core: apoCore.length,
  adjacent: apoAdj.length,
};
fs.writeFileSync(AUDIT, JSON.stringify(audit, null, 2) + "\n");

const named = ["devin", "agenthub", "ateam", "cc10x", "cavekit-v31", "barkain-workflow-orchestrator"];
const after = {};
for (const s of named) {
  after[s] = {
    apo_core: apo.membership.core.includes(s),
    apo_adjacent: apo.membership.adjacent.includes(s),
    plugins_core: plugins.membership.core.includes(s),
    saas_core: saas.membership.core.includes(s),
    apo_mq: (apo.mq_data.find((p) => p.slug === s) || {}).q || null,
    plugins_mq: (plugins.mq_data.find((p) => p.slug === s) || {}).q || null,
    saas_mq: (saas.mq_data.find((p) => p.slug === s) || {}).q || null,
  };
}
console.log(JSON.stringify({ after, pluginAddsMq, pluginAddsGmq, apoCore, pluginCore, apoLeaders: apo.vendor_buckets.leaders }, null, 2));
