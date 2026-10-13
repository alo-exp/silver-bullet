#!/usr/bin/env node
/**
 * Independent V-loop fix: per-market plotted_slugs / listed_slugs / unplotted
 * must lockstep membership + mq_data. Prior apply only updated top-level fields.
 */
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const RUN = path.resolve(__dirname, "../../..");
const CHART = path.join(RUN, "landscape/chart-data.json");

const cd = JSON.parse(fs.readFileSync(CHART, "utf8"));

function syncPlotFields(market) {
  const mqSlugs = (market.mq_data || []).map((p) => p.slug).filter(Boolean).sort();
  const beforePlotted = [...(market.plotted_slugs || [])];
  const beforeCore = [...(market.membership?.core || [])];
  market.membership.core = [...new Set([...(market.membership.core || []), ...mqSlugs])].sort();
  market.plotted_slugs = mqSlugs;
  market.listed_slugs = [...(market.membership.listed || [])].sort();
  market.unplotted = market.membership.unplotted || [];
  return {
    plottedNotCore: beforePlotted.filter((s) => !beforeCore.includes(s)),
    coreNotPlotted: beforeCore.filter((s) => !beforePlotted.includes(s)),
    plotted: market.plotted_slugs,
  };
}

const report = {};
for (const [id, market] of Object.entries(cd.markets || {})) {
  report[id] = syncPlotFields(market);
}
const apo = cd.markets.apo;
cd.plotted_slugs = apo.plotted_slugs;
cd.listed_slugs = apo.listed_slugs;
cd.unplotted = apo.unplotted;
cd.membership = apo.membership;

fs.writeFileSync(CHART, JSON.stringify(cd, null, 2) + "\n");
fs.writeFileSync(
  path.join(__dirname, "sync-plotted-slugs-report.json"),
  JSON.stringify(report, null, 2) + "\n",
);
console.log(JSON.stringify(report, null, 2));
