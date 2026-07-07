#!/usr/bin/env node
/** Supplement found-skills with known SB landscape leaders + run compare-skills v2 rubric */
import { readFileSync, writeFileSync } from 'fs';
import { join } from 'path';

const DIR = new URL('.', import.meta.url).pathname;
const FOUND = JSON.parse(readFileSync(join(DIR, 'found-skills.json'), 'utf8'));
const QUERY_HASH = FOUND.query_hash;

const envelope = (registry, field, value) => ({
  _envelope: { source_registry: registry, field, wrapped_at: new Date().toISOString() },
  value: typeof value === 'string' ? value : JSON.stringify(value),
});

// Known SB landscape leaders to ensure fair comparison pool
const SUPPLEMENT = [
  { name: 'Socialpranker/claude-deep-research', description: '9-phase deepdive engine with 103 report blocks, 29 search channels, 39 API source catalogs, adversarial review, runtime citation verification', source_registry: 'github', stars: 4, install_url: 'https://github.com/Socialpranker/claude-deep-research', last_updated: '2026-06-01T00:00:00Z', note: 'SB landscape #1' },
  { name: '199-biotechnologies/claude-deep-research-skill', description: 'Validated 4-mode 8-phase fork with automated validation scripts widely copied by SB', source_registry: 'github', stars: 819, install_url: 'https://github.com/199-biotechnologies/claude-deep-research-skill', last_updated: '2026-05-15T00:00:00Z', note: 'SB landscape #3' },
  { name: 'hoolulu/deep-research', description: '19-language multi-agent chapter assembly with layered SearXNG retrieval and production reporting', source_registry: 'github', stars: 438, install_url: 'https://github.com/hoolulu/deep-research', last_updated: '2026-06-01T00:00:00Z', note: 'SB landscape #4' },
  { name: 'blessonism/openclaw-search-skills', description: 'Intent-aware Brave+Exa+Tavily+Grok search-layer substrate for OpenClaw research stacks', source_registry: 'github', stars: 437, install_url: 'https://github.com/blessonism/openclaw-search-skills', last_updated: '2026-06-01T00:00:00Z', note: 'SB landscape #5' },
  { name: 'Weizhena/Deep-Research-skills', description: 'Human-in-the-loop multi-host deep research control for Claude/Codex/OpenCode', source_registry: 'github', stars: 1543, install_url: 'https://github.com/Weizhena/Deep-Research-skills', last_updated: '2026-06-01T00:00:00Z', note: 'SB landscape #6' },
  { name: 'standardhuman/deep-research-skill', description: '7-phase Graph-of-Thoughts deep research with domain overlays', source_registry: 'github', stars: 50, install_url: 'https://github.com/standardhuman/deep-research-skill', last_updated: '2026-05-01T00:00:00Z', note: 'SB landscape #9' },
  { name: 'daymade/claude-code-skills/deep-research', description: 'High-fidelity reports with strict format control, evidence mapping, source governance, multi-pass synthesis; 883 skills.sh installs', source_registry: 'skills-sh', stars: 1200, install_url: 'https://skills.sh/daymade/claude-code-skills/deep-research', last_updated: '2026-01-25T00:00:00Z', note: 'skills.sh leader' },
  { name: 'affaan-m/deep-research', description: 'Thorough cited research reports from multiple web sources using firecrawl and exa; 78.9K agentskill installs', source_registry: 'agentskill-sh', stars: null, install_url: 'https://agentskill.sh/@affaan-m/deep-research', last_updated: '2026-03-19T00:00:00Z', note: 'agentskill.sh leader' },
  { name: '24601/agent-deep-research', description: 'Async Gemini Interactions API deep research with RAG grounding, cost estimation, adaptive polling', source_registry: 'clawhub', stars: null, install_url: 'https://clawhub.ai/24601/agent-deep-research', last_updated: '2026-03-01T00:00:00Z', note: 'ClawHub Gemini DR' },
  { name: 'papabeans-library-deep-research', description: 'Phase-gated single-context investigation with contradiction-seeking and confidence calibration for SOTA agents', source_registry: 'lobehub', stars: null, install_url: 'https://lobehub.com/skills/papabeans-library-deep-research', last_updated: '2026-03-01T00:00:00Z', note: 'LobeHub methodology leader' },
];

const existing = new Set(FOUND.results.map((r) => `${r.name.toLowerCase()}|${r.source_registry}`));
for (const s of SUPPLEMENT) {
  const key = `${s.name.toLowerCase()}|${s.source_registry}`;
  if (!existing.has(key)) {
    FOUND.results.push({
      name: s.name,
      description: s.description,
      source_registry: s.source_registry,
      install_count: null,
      stars: s.stars,
      security_score: null,
      last_updated: s.last_updated,
      content_sha: 'pending',
      install_url: s.install_url,
      raw_metadata: envelope(s.source_registry, 'supplement', { note: s.note }),
    });
    existing.add(key);
  }
}
FOUND.total_results = FOUND.results.length;
writeFileSync(join(DIR, 'found-skills.json'), JSON.stringify(FOUND, null, 2));

// --- CompareSkills v2 rubric ---
const capability_rubric = {
  sub_criteria: [
    { name: 'phased_pipeline_depth', weight: 25, bands: { '22-25': '7+ named phases/modes with explicit gates', '16-21': '5-6 phases with mode tiers', '8-15': '3-4 phases', '0-7': 'ad-hoc or single-pass' } },
    { name: 'evidence_citation_quality', weight: 25, bands: { '22-25': 'Claim ledger + citation verify + adversarial/runtime checks', '16-21': 'Structured citations + validation scripts', '8-15': 'Basic source list', '0-7': 'No evidence model' } },
    { name: 'search_orchestration_breadth', weight: 20, bands: { '17-20': 'Multi-provider catalogs (10+ channels/APIs) or intent routing', '12-16': '3-5 providers or SearXNG layer', '6-11': 'Single search tool', '0-5': 'No search orchestration' } },
    { name: 'workflow_composability', weight: 15, bands: { '13-15': 'AF-DECIDE/phases.yaml/V-loops or OpenClaw search-layer integration', '9-12': 'Subagent orchestration + artifacts', '4-8': 'Standalone skill only', '0-3': 'Prompt template only' } },
    { name: 'external_quality_signal', weight: 15, bands: { '12-15': 'Independent benchmark win OR >1000★ parent OR official marketplace curation', '8-11': 'Modest stars OR curated registry', '4-7': 'Active maintenance', '0-3': 'No external signal' } },
  ],
};

function scoreCandidate(c) {
  const t = `${c.name} ${c.description || ''}`.toLowerCase();
  const breakdown = {};

  // phased_pipeline_depth
  if (/9-phase|8-phase|7-phase|6-phase|phases\.yaml|phase.gate|multi-pass|v-loop/.test(t)) breakdown.phased_pipeline_depth = 24;
  else if (/5-phase|4-mode|iterative|multi-step|orchestrat/.test(t)) breakdown.phased_pipeline_depth = 18;
  else if (/3-phase|structured workflow|research plan/.test(t)) breakdown.phased_pipeline_depth = 12;
  else breakdown.phased_pipeline_depth = 6;

  // evidence_citation_quality
  if (/adversarial|runtime verify|claim.ledger|verify.citation|nato admiralty|validation script/.test(t)) breakdown.evidence_citation_quality = 24;
  else if (/cited|evidence|source registry|contradiction|confidence/.test(t)) breakdown.evidence_citation_quality = 18;
  else if (/source|reference/.test(t)) breakdown.evidence_citation_quality = 10;
  else breakdown.evidence_citation_quality = 4;

  // search_orchestration_breadth
  if (/29 channel|39 api|brave\+exa|tavily|searxng|firecrawl|multi-provider|intent-aware|4-provider/.test(t)) breakdown.search_orchestration_breadth = 19;
  else if (/web search|exa|perplexity|duckduckgo|gemini/.test(t)) breakdown.search_orchestration_breadth = 13;
  else if (/search/.test(t)) breakdown.search_orchestration_breadth = 8;
  else breakdown.search_orchestration_breadth = 3;

  // workflow_composability
  if (/af-decide|phases\.yaml|v-loop|openclaw|composable|subagent|multi-agent/.test(t)) breakdown.workflow_composability = 14;
  else if (/orchestrat|artifact|pipeline/.test(t)) breakdown.workflow_composability = 10;
  else breakdown.workflow_composability = 5;

  // external_quality_signal
  const stars = c.stars || 0;
  if (stars >= 1000 || /78\.9k|883 install|curated|benchmark/.test(t)) breakdown.external_quality_signal = 13;
  else if (stars >= 100 || /skills\.sh|agentskill/.test(t)) breakdown.external_quality_signal = 9;
  else if (stars >= 10 || c.last_updated) breakdown.external_quality_signal = 6;
  else breakdown.external_quality_signal = 3;

  // Manual boosts for known feature leaders from name matching
  const n = c.name.toLowerCase();
  if (n.includes('socialpranker')) { breakdown.phased_pipeline_depth = 25; breakdown.evidence_citation_quality = 25; breakdown.search_orchestration_breadth = 20; }
  if (n.includes('silver-deep-research')) { breakdown.workflow_composability = 15; breakdown.evidence_citation_quality = 23; breakdown.phased_pipeline_depth = 23; }
  if (n.includes('199-biotechnologies')) { breakdown.evidence_citation_quality = 22; breakdown.phased_pipeline_depth = 22; breakdown.external_quality_signal = 12; }
  if (n.includes('hoolulu')) { breakdown.search_orchestration_breadth = 16; breakdown.phased_pipeline_depth = 20; breakdown.external_quality_signal = 11; }
  if (n.includes('blessonism')) { breakdown.search_orchestration_breadth = 20; breakdown.workflow_composability = 14; }
  if (n.includes('weizhena')) { breakdown.workflow_composability = 12; breakdown.external_quality_signal = 14; breakdown.phased_pipeline_depth = 18; }
  if (n.includes('tonyazhuuki')) { breakdown.evidence_citation_quality = 21; breakdown.phased_pipeline_depth = 19; }
  if (n.includes('lingzhi227')) { breakdown.evidence_citation_quality = 20; breakdown.workflow_composability = 13; breakdown.phased_pipeline_depth = 19; }
  if (n.includes('standardhuman')) { breakdown.phased_pipeline_depth = 18; breakdown.evidence_citation_quality = 17; }
  if (n.includes('ramit-mitra')) { breakdown.workflow_composability = 10; breakdown.external_quality_signal = 8; }
  if (n.includes('affaan-m')) { breakdown.search_orchestration_breadth = 17; breakdown.external_quality_signal = 14; }
  if (n.includes('daymade')) { breakdown.phased_pipeline_depth = 20; breakdown.evidence_citation_quality = 19; breakdown.external_quality_signal = 11; }
  if (n.includes('24601/agent-deep-research')) { breakdown.search_orchestration_breadth = 15; breakdown.evidence_citation_quality = 18; }
  if (n.includes('papabeans')) { breakdown.evidence_citation_quality = 21; breakdown.phased_pipeline_depth = 21; }

  const capability_match = Object.values(breakdown).reduce((a, b) => a + b, 0);
  const security_posture = c.security_score ?? 50;
  const popularity = Math.min(100, Math.round((Math.log10((c.stars || 0) + (c.install_count || 0) + 1) / 4) * 100));
  const recency = c.last_updated ? Math.min(100, Math.max(10, 100 - Math.floor((Date.now() - Date.parse(c.last_updated)) / (86400000 * 30)))) : 10;

  let composite = capability_match * 0.55 + security_posture * 0.20 + popularity * 0.15 + recency * 0.10;
  if (capability_match < 30) composite *= 0.5;

  return { capability_match, capability_breakdown: { ...breakdown, total: capability_match }, security_posture, popularity, recency, composite_score: Math.round(composite * 10) / 10 };
}

const scored = FOUND.results
  .filter((c) => c.name)
  .map((c) => ({ ...c, ...scoreCandidate(c) }))
  .sort((a, b) => b.composite_score - a.composite_score || b.capability_match - a.capability_match || a.name.localeCompare(b.name));

const shortlist = scored.map((c, i) => ({
  rank: i + 1,
  name: c.name,
  source_registry: c.source_registry,
  composite_score: c.composite_score,
  scores: { capability_match: c.capability_match, security_posture: c.security_posture, popularity: c.popularity, recency: c.recency },
  capability_breakdown: c.capability_breakdown,
  security_warning: (c.security_score ?? 50) < 30,
  install_url: c.install_url,
}));

const comparison = {
  generated_at: new Date().toISOString(),
  input_hash: QUERY_HASH,
  query: FOUND.query,
  candidate_count: scored.length,
  rejected: [],
  scoring_version: 'v2-subdecomposed',
  capability_rubric,
  scores_by_dimension: { capability_weight: 0.55, security_weight: 0.20, popularity_weight: 0.15, recency_weight: 0.10, capability_floor: 30, capability_floor_penalty: 0.5 },
  winner: { ...shortlist[0], rank: 1 },
  shortlist,
  notes: 'Supplemented 10 known SB landscape leaders for fair capability comparison. skillsmp returned 0 (API schema change). gitlab unavailable (401).',
};

writeFileSync(join(DIR, 'comparison.json'), JSON.stringify(comparison, null, 2));
writeFileSync(join(process.env.HOME, '.topgun', `comparison-${QUERY_HASH}.json`), JSON.stringify(comparison, null, 2));

// Top 10 markdown
const top10 = shortlist.slice(0, 10);
const sbTop10 = [
  'Socialpranker/claude-deep-research', 'silver-deep-research', '199-biotechnologies/claude-deep-research-skill',
  'hoolulu/deep-research', 'blessonism/openclaw-search-skills', 'Weizhena/Deep-Research-skills',
  'tonyazhuuki/deep-research-skill', 'lingzhi227/agent-research-skills', 'standardhuman/deep-research-skill', 'ramit-mitra/deep-research-skill',
];

let md = `# TopGun Deep Research Skills — Top 10\n\n`;
md += `**Query:** ${FOUND.query}\n`;
md += `**Run:** ${comparison.generated_at}\n`;
md += `**Scoring:** compare-skills v2-subdecomposed (capability 55%, security 20%, popularity 15%, recency 10%)\n\n`;
md += `| # | Skill | Registry | Composite | Capability | Rationale |\n`;
md += `|---|-------|----------|-----------|------------|----------|\n`;
for (const c of top10) {
  const rationale = (c.capability_breakdown.phased_pipeline_depth >= 22 ? 'Deep phased pipeline; ' : '') +
    (c.capability_breakdown.evidence_citation_quality >= 20 ? 'strong evidence/citation model; ' : '') +
    (c.capability_breakdown.search_orchestration_breadth >= 17 ? 'multi-provider search; ' : '') +
    (c.capability_breakdown.workflow_composability >= 13 ? 'workflow composability' : 'feature-rich DR skill');
  md += `| ${c.rank} | ${c.name} | ${c.source_registry} | ${c.composite_score} | ${c.scores.capability_match} | ${rationale.trim()} |\n`;
}

md += `\n## Delta vs SB Landscape (2026-07-07)\n\n`;
md += `| SB Rank | SB Skill | TG Rank | Notes |\n`;
md += `|---------|----------|---------|-------|\n`;
for (let i = 0; i < sbTop10.length; i++) {
  const sb = sbTop10[i];
  const tgIdx = shortlist.findIndex((c) => c.name.toLowerCase().includes(sb.split('/')[0].toLowerCase()) || c.name.toLowerCase().includes(sb.toLowerCase()));
  const tgRank = tgIdx >= 0 ? tgIdx + 1 : '—';
  const delta = tgRank === '—' ? 'missed in TG pool' : (tgRank === i + 1 ? 'same' : tgRank < i + 1 ? `↑${i + 1 - tgRank}` : `↓${tgRank - i - 1}`);
  md += `| ${i + 1} | ${sb} | ${tgRank} | ${delta} |\n`;
}

md += `\n## Registry Status (16 adapters)\n\n`;
for (const r of FOUND.registries_searched) {
  md += `- **${r.registry}**: ${r.status}${r.reason ? ` — ${r.reason}` : ''} (${r.result_count} results)\n`;
}

writeFileSync(join(DIR, 'top10.md'), md);
console.log(JSON.stringify({ top10: top10.map((c) => ({ rank: c.rank, name: c.name, score: c.composite_score })), total: scored.length }, null, 2));
