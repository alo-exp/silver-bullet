#!/usr/bin/env node
/**
 * Independent P1 membership V-loop — do not trust prior PASS.
 */
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const RUN = path.resolve(__dirname, "../../..");
const html = fs.readFileSync(path.join(RUN, "landscape-report.html"), "utf8");
const md = fs.readFileSync(path.join(RUN, "landscape/landscape-report.md"), "utf8");
const chart = JSON.parse(fs.readFileSync(path.join(RUN, "landscape/chart-data.json"), "utf8"));

const rdMatch = html.match(/<script type="application\/json" id="report-data">([\s\S]*?)<\/script>/);
if (!rdMatch) throw new Error("missing #report-data");
const rd = JSON.parse(rdMatch[1]);
const rdMd = typeof rd.markdown === "string" ? rd.markdown : "";
const cd = rd.chart_data || {};

function s1(src) {
  const m = src.match(/^## 1\. Market Definition & Scope\s*$/m);
  if (!m) return "";
  const start = m.index;
  const rest = src.slice(start);
  const next = rest.slice(m[0].length).search(/^## /m);
  return rest.slice(0, next < 0 ? rest.length : m[0].length + next);
}

function mqSlugs(market) {
  return new Set((market.mq_data || []).map((p) => p.slug));
}
function leaders(market) {
  return new Set((market.mq_data || []).filter((p) => p.q === "Leaders").map((p) => p.slug));
}
function hostingAt(series) {
  return (series || []).map((s) => ({ label: s.label, v: (s.data || [])[4] }));
}

const apo = chart.markets.apo;
const plugins = chart.markets["sdlc-plugins"];
const saas = chart.markets["agentic-sdlc-saas"];
const htmlApo = cd.markets?.apo || {};
const htmlPlugins = cd.markets?.["sdlc-plugins"] || {};
const htmlSaas = cd.markets?.["agentic-sdlc-saas"] || {};

const section1 = s1(md);
const rows = [];

function add(id, pass, evidence) {
  rows.push({ id, result: pass ? "PASS" : "FAIL", evidence });
}

const devinSaasCore = (saas.membership.core || []).includes("devin");
const devinSaasPlotted = (saas.plotted_slugs || []).includes("devin") && mqSlugs(saas).has("devin");
const s1AdjacentOnlyHost = /Devin/.test(section1) && /adjacent-only host/i.test(section1) && !/not an adjacent-only host/i.test(section1);
const s1SaysNotAdjacentOnly = /Devin[\s\S]{0,400}not an adjacent-only host|not an adjacent-only host[\s\S]{0,80}Devin|\*\*Devin\*\* is \*\*agentic-sdlc-saas core\*\*/i.test(section1);
add(
  "1 Devin SaaS core plotted; §1 does NOT call Devin adjacent-only host",
  devinSaasCore && devinSaasPlotted && s1SaysNotAdjacentOnly && !s1AdjacentOnlyHost,
  `saas.core=${devinSaasCore} saas.plotted+mq=${devinSaasPlotted} s1NotAdjacentOnly=${s1SaysNotAdjacentOnly} s1LumpsAsAdjacentOnlyHost=${s1AdjacentOnlyHost}`,
);

const ahMq = mqSlugs(apo).has("agenthub");
const ahLeaders = leaders(apo).has("agenthub");
const ahCore = (apo.membership.core || []).includes("agenthub");
const ahPlotted = (apo.plotted_slugs || []).includes("agenthub");
const htmlAhPlotted = (htmlApo.plotted_slugs || []).includes("agenthub");
add(
  "2 AgentHub NOT in APO MQ Leaders/core plotted",
  !ahMq && !ahLeaders && !ahCore && !ahPlotted && !htmlAhPlotted,
  `mq=${ahMq} leaders=${ahLeaders} core=${ahCore} plotted_slugs=${ahPlotted} html.plotted=${htmlAhPlotted} adjacent=${(apo.membership.adjacent || []).includes("agenthub")}`,
);

const atMq = mqSlugs(apo).has("ateam");
const atCore = (apo.membership.core || []).includes("ateam");
const atPlotted = (apo.plotted_slugs || []).includes("ateam");
const htmlAtPlotted = (htmlApo.plotted_slugs || []).includes("ateam");
add(
  "3 A.Team/ATeam NOT in APO core plotted",
  !atMq && !atCore && !atPlotted && !htmlAtPlotted,
  `mq=${atMq} core=${atCore} plotted_slugs=${atPlotted} html.plotted=${htmlAtPlotted}`,
);

const pluginNeedles = ["cc10x", "cavekit-v31", "barkain-workflow-orchestrator"];
const inPlugins = pluginNeedles.every(
  (s) => (plugins.membership.core || []).includes(s) && mqSlugs(plugins).has(s) && (plugins.plotted_slugs || []).includes(s),
);
const notApoCore = pluginNeedles.every(
  (s) => !(apo.membership.core || []).includes(s) && !mqSlugs(apo).has(s) && !(apo.plotted_slugs || []).includes(s),
);
const apoComm = JSON.stringify(apo.vendor_buckets?.commercial || []);
const inApoCommercial = /cc10x|Cavekit|Barkain/i.test(apoComm);
add(
  "4 cc10x, Cavekit, Barkain in sdlc-plugins (not APO commercial core)",
  inPlugins && notApoCore && !inApoCommercial,
  `pluginsCore+mq+plotted=${inPlugins} notApoCore+mq+plotted=${notApoCore} apoCommercialHasThem=${inApoCommercial}`,
);

const ossHosting = [
  ...hostingAt(apo.vc_oss),
  ...hostingAt(plugins.vc_oss),
  ...hostingAt(chart.vc_oss),
];
const ossBad = ossHosting.filter((x) => x.v === 3);
const ossOk = ossHosting.length > 0 && ossHosting.every((x) => x.v === 1);
const apoCommEmpty = (apo.vc_commercial || []).length === 0;
add(
  "5 Value-curve Managed hosting for OSS is not 3 if matrix empty (expect 1)",
  ossOk && ossBad.length === 0 && apoCommEmpty,
  `ossHosting=${JSON.stringify(ossHosting)} apo.vc_commercial.len=${(apo.vc_commercial || []).length}`,
);

const mdEq = rdMd === md;
add(
  "6 HTML #report-data still locksteps with landscape-report.md",
  mdEq,
  `rd.markdown.len=${rdMd.length} md.len=${md.length} equal=${mdEq}`,
);

const pwPath = path.join(__dirname, "playwright-fileurl.json");
let pw = null;
if (fs.existsSync(pwPath)) {
  pw = JSON.parse(fs.readFileSync(pwPath, "utf8"));
}
const file7Pass = !!(
  pw &&
  pw.fileRenderPass &&
  !pw.renderFailed &&
  (pw.canvases || 0) > 0 &&
  (pw.pageErrors || []).length === 0
);
add(
  "7 file:// renders",
  file7Pass,
  pw
    ? `fileRenderPass=${pw.fileRenderPass} canvases=${pw.canvases} renderFailed=${pw.renderFailed} pageErrors=${(pw.pageErrors || []).length} consoleErrors=${(pw.consoleErrors || []).length}`
    : "playwright-fileurl.json missing — run playwright-p1.mjs",
);

const allPass = rows.every((r) => r.result === "PASS");
const out = { allPass, rows };
fs.writeFileSync(path.join(__dirname, "vloop-result.json"), JSON.stringify(out, null, 2) + "\n");
console.log(rows.map((r) => `${r.result}\t${r.id}\t${r.evidence}`).join("\n"));
console.log(allPass ? "OVERALL PASS" : "OVERALL FAIL");
process.exit(allPass ? 0 : 1);
