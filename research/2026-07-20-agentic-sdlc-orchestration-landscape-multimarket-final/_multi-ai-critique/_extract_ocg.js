#!/usr/bin/env node
const fs = require("fs");
const path = require("path");

const critRoot =
  "research/2026-07-20-agentic-sdlc-orchestration-landscape-multimarket-final/_multi-ai-critique";
const envPath = path.join(
  critRoot,
  "ocg-lite/contributions/work-e3341b367f137dd92e48c6ff5b930183.json"
);
const envelopes = JSON.parse(fs.readFileSync(envPath, "utf8"));
const outDir = path.join(critRoot, "ocg-lite/per-contributor");
fs.mkdirSync(outDir, { recursive: true });

const allCritiques = [];
const allGaps = [];
const allTop = [];
const allNew = [];
const summary = [];

for (const env of envelopes) {
  const id = env.logical_model_id;
  const payload = env.payload || {};
  const critiques = payload.critiques || [];
  const gaps = payload.gaps || [];
  const top = payload.top_findings || [];
  const neu = payload.new_information || payload.new_info || [];
  allCritiques.push(...critiques.map((c) => ({ ...c, source: id })));
  allGaps.push(...gaps.map((g) => ({ ...g, source: id })));
  allTop.push(...top.map((t) => ({ text: t, source: id })));
  allNew.push(
    ...(Array.isArray(neu) ? neu : []).map((n) => ({ ...n, source: id }))
  );

  let md = `# Critique — ${id}\n\n`;
  md += `backend: ocg\nstatus: completed\nattempt: ${env.attempt_id || ""}\nrun_id: ${env.run_id || ""}\n\n`;
  md += `## Critiques (${critiques.length})\n\n`;
  for (const c of critiques) {
    md += `- **[${c.severity || "?"}][${c.dimension || "?"}]** ${c.target || "(no target)"}: ${c.finding || c.description || JSON.stringify(c)}\n`;
  }
  md += `\n## Gaps (${gaps.length})\n\n`;
  for (const g of gaps) {
    md += `- **${g.area || "(area)"}**: ${g.description || ""}${g.suggested_action ? ` → _${g.suggested_action}_` : ""}\n`;
  }
  md += `\n## Top findings\n\n`;
  for (const t of top) md += `- ${t}\n`;
  md += `\n## New information\n\n`;
  for (const n of neu) {
    if (typeof n === "string") md += `- ${n}\n`;
    else
      md += `- ${n.claim || JSON.stringify(n)} _(source: ${n.source_or_unverified || n.source || "n/a"}; confidence: ${n.confidence || "n/a"})_\n`;
  }
  md += `\n## Raw payload\n\n\`\`\`json\n${JSON.stringify(payload, null, 2).slice(0, 50000)}\n\`\`\`\n`;
  fs.writeFileSync(path.join(outDir, `${id}.md`), md);
  summary.push({
    id,
    critiques: critiques.length,
    gaps: gaps.length,
    top: top.length,
    new_info: Array.isArray(neu) ? neu.length : 0,
  });
}

fs.writeFileSync(
  path.join(outDir, "_index.json"),
  JSON.stringify({ summary, envelope_count: envelopes.length }, null, 2)
);
fs.writeFileSync(
  path.join(critRoot, "ocg-lite/merged-findings.json"),
  JSON.stringify(
    {
      critiques: allCritiques,
      gaps: allGaps,
      top_findings: allTop,
      new_information: allNew,
    },
    null,
    2
  )
);
console.log(
  JSON.stringify(
    {
      summary,
      totals: {
        critiques: allCritiques.length,
        gaps: allGaps.length,
        top: allTop.length,
        new_info: allNew.length,
      },
    },
    null,
    2
  )
);
