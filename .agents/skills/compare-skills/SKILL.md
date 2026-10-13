---
name: compare-skills
description: >
  Sub-skill of TopGun. Evaluates skill candidates across capability, security,
  popularity, and recency dimensions. Capability is scored against a domain-specific
  rubric synthesized from observed candidate features. Not normally invoked directly.
  The topgun orchestrator dispatches this via the topgun-comparator agent.
---

# CompareSkills

**Status:** Phase 3 — Complete

## Overview

Evaluates skill candidates from FindSkills output across four scoring dimensions. Before any scoring, all metadata passes through structural envelope enforcement and pre-filters per REQ-09 and NFR-01.

**Scoring methodology:** Capability_match is **not** a flat keyword-hit count. The agent first reads candidate features, synthesizes a domain-specific rubric of 5 weighted sub-criteria summing to 100, then scores each candidate against each sub-criterion. This produces meaningful differentiation even between architecturally similar candidates and prevents ties caused by coarse single-bucket scoring.

## Pre-Filter Rules

Candidates are rejected before scoring if any string field contains:
1. **Base64 blobs** — sequences of 100+ base64 characters
2. **Zero-width characters** — U+200B-U+200F, U+2028-U+202F, U+FEFF
3. **Abuse-prone Unicode** — Variation Selectors (U+FE00-U+FE0F), Tag chars (U+E0000-U+E007F), Variation Selectors Supplement (U+E0100-U+E01EF), Bidi-isolate controls (U+2066-U+2069), Bidi-override controls (U+202A-U+202E), Private Use Area (U+E000-U+F8FF)
4. **Unicode density** — > 30% non-printable-ASCII codepoints AND > 200 chars long. Local-source skills are exempt.

Regular emoji, CJK characters, and accented Latin are NOT rejected — only abuse-prone codepoint ranges. Rejected candidates are logged with reason and excluded from scoring.

## Structural Envelope

All string metadata fields (name, description, raw_metadata values) are wrapped in `<structural_envelope>` tags with source registry and field name attributes before any agent context injection.

Numeric fields (install_count, stars, security_score) pass through unwrapped.

## Scoring Rubric

Each candidate is scored 0-100 on four dimensions:

| Dimension | Weight | Source Field | Null Default |
|-----------|--------|-------------|--------------|
| Capability Match | 55% | rubric-decomposed score (see below) | 0 |
| Security Posture | 20% | security_score | 50 |
| Popularity | 15% | stars + install_count | 0 |
| Recency | 10% | last_updated | 10 |

**Composite (raw):** `(capability_match * 0.55) + (security_posture * 0.20) + (popularity * 0.15) + (recency * 0.10)`

**Capability floor:** if `capability_match < 30`, the composite is multiplied by `0.5`. Low-fit candidates are heavily demoted so popular/recent skills can't displace true matches just because the true match has zero stars.

**Tie-breaking:** composite DESC, then capability_match DESC, then security_posture DESC, then recency DESC, then name ASC.

**Security Warning:** Candidates with security_score < 30 are flagged with `security_warning: true` and a logged warning. They are NOT disqualified — the user sees the warning in output.

## Capability Match — Rubric-First Scoring

Capability_match is computed in three deterministic phases. The agent does NOT score capability against the raw query — it scores against a structured rubric synthesized from the candidate field itself.

### Phase A — Feature extraction

Scan every non-rejected candidate's `name`, `description`, and `raw_metadata`. Extract the union of distinguishing features observed:

- Pipeline / phase / mode signals (named phases, iteration loops, depth tiers)
- Output / artifact signals (file formats, persistence, deliverable shape)
- Quality / verification signals (citation tracking, validation passes, hallucination detection, critique loops)
- Operational signals (mode control, time bounds, depth tiers)
- Credibility signals (benchmark placements, parent-repo stars, registry curation)

This step is observational only — no scoring yet.

### Phase B — Rubric synthesis

From the extracted feature set + the user's task query, synthesize 5 weighted sub-criteria that sum to weight 100. Each sub-criterion has explicit bands. The exact sub-criteria depend on the domain (e.g. deep-research-report, dev-tool, deployment-skill); the synthesis follows this template:

```yaml
sub_criteria:
  - name: <domain-specific architecture criterion>
    weight: <typically 20-25>
    bands:
      "X-Y": "what counts as top-band evidence"
      ...
  - name: <domain-specific quality / output criterion>
    weight: <typically 20-25>
    bands: { ... }
  - name: <domain-specific format / artifact criterion>
    weight: <typically 15-20>
    bands: { ... }
  - name: <domain-specific control / mode criterion>
    weight: <typically 10-15>
    bands: { ... }
  - name: external_quality_signal
    weight: <typically 10-15>
    bands:
      "12-15": "Independent benchmark win OR >1000★ parent-repo OR official-marketplace curation"
      "8-11":  "Modest stars OR curated registry placement"
      "4-7":   "Active maintenance, low traction"
      "0-3":   "No external signal"
```

The 5th sub-criterion (`external_quality_signal`) is **always present** with a 10-15 weight cap. This prevents bench placements / parent-repo stars from dominating a sparse-pipeline candidate (the v1 `research-cog` failure mode). Stars and benchmark wins are credibility signals, not architecture.

The first 4 sub-criteria are domain-specific — derived from what features actually distinguish candidates in this query.

Write the synthesized rubric to `capability_rubric` in the comparison output JSON for audit.

### Phase C — Per-candidate scoring

For each candidate, score each sub-criterion against its bands using the candidate's extracted features. Sum the sub-scores → `capability_match` (0-100).

For each candidate, the comparison output JSON records `capability_breakdown`: a dict mapping sub-criterion name → integer score, plus `total`. This makes the rubric auditable and explains why two architecturally-different candidates landed at different scores.

### When the candidate field is too small to synthesize a rubric

If fewer than 3 candidates remain after pre-filter, fall back to keyword-hit scoring (per the v1 method): split query, count hits, `min(100, hits/total * 100)`. Single candidates and pairs don't have enough variance to support a sub-decomposed rubric.

Log the fallback in `notes` of the output JSON.

## Determinism

- Pre-filter, structural envelope, security_posture, popularity, recency: deterministic arithmetic. Identical input always produces identical output.
- Capability_match (rubric-first): the **rubric synthesis** uses LLM judgment over the candidate field, but is constrained by the 5-sub-criterion template + the always-present `external_quality_signal` slot. The same candidate field yields the same rubric within rounding noise.
- Per-candidate sub-criterion scoring is bounded by explicit bands (e.g. "20-25"); scores are integers; LLM noise is bounded to ~±2 per sub-criterion.
- Tie-breaking is deterministic (lexicographic on name).

## Output

Writes `~/.topgun/comparison-{hash}.json` containing:
- `generated_at` — ISO 8601 timestamp
- `scoring_version` — `"v2-subdecomposed"` (current) or `"v1-keyword"` (fallback)
- `capability_rubric` — the synthesized 5-sub-criterion rubric (Phase B output). Omitted under v1 fallback.
- Winner with full score breakdown including `capability_breakdown`. Omitted under v1 fallback.
- `shortlist` — ranked list of all non-rejected candidates, each with `capability_breakdown` (omitted under v1)
- `rejected` — array of rejected candidates with their rejection reasons
- `scores_by_dimension` — weight configuration: `{"capability_weight": 0.55, "security_weight": 0.20, "popularity_weight": 0.15, "recency_weight": 0.10, "capability_floor": 30, "capability_floor_penalty": 0.5}`
- `notes` — optional free-text field. **Required** when `scoring_version` is `"v1-keyword"` to explain why fallback was used (e.g. "fewer than 3 candidates after pre-filter"). Optional otherwise.

Updates `~/.topgun/state.json` with `comparison_path`, `winner_name`, `winner_registry`.

## Completion

On success, outputs:

```
## COMPARE COMPLETE

Compared {N} candidates ({M} rejected by pre-filter).
Scoring: {scoring_version}
Rubric: {sub_criterion_1}, {sub_criterion_2}, {sub_criterion_3}, {sub_criterion_4}, external_quality_signal
Winner: {name} from {registry} (score: {composite}).
```

Under the v1-keyword fallback path, the `Rubric:` line is omitted (no rubric was synthesized).

## Dispatch

This skill is dispatched by the topgun orchestrator via the topgun-comparator agent. Not normally invoked directly.
