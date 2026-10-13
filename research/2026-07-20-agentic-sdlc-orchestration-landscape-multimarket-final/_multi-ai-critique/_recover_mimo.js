#!/usr/bin/env node
const fs = require("fs");
const path = require("path");

const critRoot =
  "research/2026-07-20-agentic-sdlc-orchestration-landscape-multimarket-final/_multi-ai-critique";
const rawPath = path.join(
  critRoot,
  "ocg-lite/phases/DR-CRITIQUE/ocg-mimo-v2.5-opencode-go-mimo-v2.5.raw.txt"
);
const raw = fs.readFileSync(rawPath, "utf8");
const fence = raw.match(/```json\s*([\s\S]*?)```/);
let text = fence ? fence[1] : raw;
// strip ANSI / trailing noise
text = text.replace(/\u001b\[[0-9;]*m/g, "");
const start = text.indexOf("{");
let depth = 0;
let end = -1;
for (let i = start; i < text.length; i++) {
  if (text[i] === "{") depth++;
  else if (text[i] === "}") {
    depth--;
    if (depth === 0) {
      end = i;
      break;
    }
  }
}
if (start < 0 || end < 0) {
  console.error("could not extract JSON object");
  process.exit(1);
}
let jsonStr = text.slice(start, end + 1);
// if truncated, try to close arrays/objects heuristically
try {
  JSON.parse(jsonStr);
} catch (e) {
  // truncate at last complete critique object if needed
  const lastComplete = jsonStr.lastIndexOf("},");
  if (lastComplete > 0) {
    jsonStr =
      jsonStr.slice(0, lastComplete + 1) +
      '], "gaps": [], "top_findings": [], "new_information": [], "_recovered": true, "_note": "truncated raw; partial recover" }';
  }
}
const payload = JSON.parse(jsonStr);
const outDir = path.join(critRoot, "ocg-lite/per-contributor");
let md = `# Critique — ocg-mimo-v2.5 (recovered from raw)\n\n`;
md += `backend: ocg\nstatus: completed (payload recovered from fenced JSON in raw_text)\n\n`;
md += `## Critiques (${(payload.critiques || []).length})\n\n`;
for (const c of payload.critiques || []) {
  md += `- **[${c.severity || "?"}][${c.dimension || "?"}]** ${c.target || "(no target)"}: ${c.finding || ""}\n`;
}
md += `\n## Gaps (${(payload.gaps || []).length})\n\n`;
for (const g of payload.gaps || []) {
  md += `- **${g.area || "(area)"}**: ${g.description || ""}\n`;
}
md += `\n## Top findings\n\n`;
for (const t of payload.top_findings || []) md += `- ${t}\n`;
md += `\n## New information\n\n`;
for (const n of payload.new_information || []) {
  if (typeof n === "string") md += `- ${n}\n`;
  else
    md += `- ${n.claim || JSON.stringify(n)} _(source: ${n.source_or_unverified || "n/a"}; confidence: ${n.confidence || "n/a"})_\n`;
}
md += `\n## Recovered payload\n\n\`\`\`json\n${JSON.stringify(payload, null, 2)}\n\`\`\`\n`;
fs.writeFileSync(path.join(outDir, "ocg-mimo-v2.5.md"), md);
fs.writeFileSync(
  path.join(outDir, "ocg-mimo-v2.5.recovered.json"),
  JSON.stringify(payload, null, 2)
);
console.log(
  "recovered critiques",
  (payload.critiques || []).length,
  "gaps",
  (payload.gaps || []).length
);
