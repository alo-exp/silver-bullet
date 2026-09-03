---
name: silver-deep-research-multi-ai
description: >
  Opt-in multi-model deep research. Composes canonical silver-deep-research engine,
  new /silver:multi-ai-task primitive, and Cursor/OCG backends. Dual serverless HTML reports.
argument-hint: "<research question> [--mode deep|ultradeep] [--research-type default|solution-landscape|solution-compare] [--dry-run]"
version: 1.0.0
---

# /silver:deep-research-multi-ai — Multi-Model Deep Research

**Catalog:** workflow `WF-SILVER-DEEP-RESEARCH-MULTI-AI` · flow step
`FS-SILVER_DEEP_RESEARCH_MULTI_AI` · composes `AF-MULTI-AI-TASK` per eligible phase.

Opt-in sibling of [`silver-deep-research`](../silver-deep-research/SKILL.md). Does **not**
replace single-agent `/silver:deep-research` or revive removed `FS-SILVER_MULTI_AI` MultAI surfaces.

## Architecture (locked)

```text
Host DR controller (silver-deep-research instructions)
  → per eligible phase: /silver:multi-ai-task (parallel lanes)
  → host validation + gates
  → DR-multi-AI deterministic consolidation
  → consolidated/ intermediates + report.html (+ landscape-report.html)
  → comparison/comparison-matrix.xlsx for solution-landscape / solution-compare
```

**One** canonical DR engine. Workers return phase-scoped contributions only.

## Explicit opt-in

Every run requires this route. `preferences.json` may default pools only — it never
auto-starts multi-AI research.

## Usage

```bash
python3 skills/silver-deep-research-multi-ai/scripts/dr_multi_ai_cli.py \
  "Which event streaming platform for our scale?" \
  --mode deep \
  --research-type default \
  --output-root "research/$(date -u +%Y-%m-%d)-multi-ai-kafka" \
  --dry-run
```

## Parallel phases

Canonical IDs: `DR-RETRIEVE`, `DR-TRIANGULATE`, `DR-CRITIQUE`.
See [`reference/parallel-phases-v1.json`](reference/parallel-phases-v1.json).

| research_type | mode | Parallel phases |
|---------------|------|-----------------|
| default | deep / ultradeep | RETRIEVE, TRIANGULATE, CRITIQUE |
| solution-landscape | deep | RETRIEVE, TRIANGULATE |
| solution-compare | deep | RETRIEVE, TRIANGULATE |

## Manifest

Sole runtime authority: `run_manifest.json` v4 (`spine: multi-ai-task-v2`).
Migrates from strict-v3 or host-v3 copy-on-write only.

## Consolidation

```bash
python3 skills/silver-deep-research-multi-ai/scripts/consolidate.py \
  --envelopes contributions.json \
  --index result-index.json \
  --resolved-pool 11 \
  --output consolidated/consensus.json
```

Accepts **only** host-validated `DR-*` contribution envelopes + matching result index.
Forbidden: reports, synthesis, V-loop artifacts, worker state.

## Reports (dual)

| File | Profile | When |
|------|---------|------|
| `report.html` | `--profile general` | All supported research types |
| `landscape-report.html` | `--profile landscape` | `solution-landscape` / `solution-compare` only |
| `comparison/comparison-matrix.xlsx` | — | `solution-landscape` / `solution-compare` (weighted matrix) |

**Landscape viewer:** MultAI-parity SPA (`render_landscape_outputs()` in `landscape_preview_render.py` + `assets/landscape-preview.template.html`) — sidebar TOC, Chart.js 2×2/Wave/Value Curve, COMMERCIAL/OSS nav, Copy/PDF/Compare/Matrix. Self-contained (`file://`); no `http.server`. `generate_landscape_report.py` is a compatibility wrapper around that function (not the retired general SPA).

**General DR:** unchanged tabbed `generate_spa_report.py:general` — no MultAI chart sections.

## Landscape / solution prompts (MultAI parity, SB engine only)

For `research_type` `solution-landscape` or `solution-compare` only — **do not** alter default deep-research prompts.

| Asset | Path | Use |
|-------|------|-----|
| Landscape researcher prompt | [`../silver-deep-research/reference/landscape/prompt-template.md`](../silver-deep-research/reference/landscape/prompt-template.md) | DR-RETRIEVE per-model landscape research |
| Consolidation guide (9 sections + chart-data) | [`../silver-deep-research/reference/landscape/consolidation-guide.md`](../silver-deep-research/reference/landscape/consolidation-guide.md) | DR-TRIANGULATE → `landscape/landscape-report.md` + `landscape/chart-data.json` |
| Comparator framework | [`../silver-deep-research/reference/comparator/capability-framework.md`](../silver-deep-research/reference/comparator/capability-framework.md) | Matrix build via `compare_solutions.py` |

Host controller must pass consolidation guide to synthesis workers; `consolidate.py` remains deterministic claim merge for `consolidated/consolidation.json` only.

## Solution packaging (landscape / compare)

After consolidation and SCR `features.json` artifacts exist:

```bash
python3 skills/silver-deep-research-multi-ai/scripts/package_solution_outputs.py \
  --dir "$SB_RESEARCH_OUT_DIR"
```

Runs `compare_solutions.py` (JSON + MD + XLSX), then both SPA reports.
For `solution-landscape` / `solution-compare`, packaging **always** re-runs
`materialize_solution_artifacts` and `synthesize_landscape` (force) before the landscape SPA
and `validate_landscape_content` gate — engine fixes apply without manual fullpool edits.
Skip steps with `--skip-compare`, `--skip-xlsx`, or `--skip-spa`.

## GLM-5.2 routing

Subscription-gated: Cursor pool if subscribed; OCG pool otherwise. `unknown` blocks dispatch.

## Validation

```bash
python3 skills/silver-deep-research/scripts/validate_spa_report.py \
  --report "$SB_RESEARCH_OUT_DIR/report.html" --profile general
python3 skills/silver-deep-research/scripts/validate_spa_report.py \
  --report "$SB_RESEARCH_OUT_DIR/landscape-report.html" --profile landscape
```

Open reports in external browser (`open report.html`) — no HTTP server.
