---
name: "silver:deep-research-multi-ai"
title: "Deep Research Multi AI"
description: >
  Opt-in multi-model deep research. Composes canonical silver-deep-research engine,
  new /silver:multi-ai-task primitive, and Cursor/OCG backends. Dual serverless HTML reports.
argument-hint: "<research question> [--mode deep|ultradeep] [--research-type default|solution-landscape|solution-compare] [--dry-run]"
version: 1.0.0
user-invocable: false
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

Intermediates live under `consolidated/` only.

## Solution packaging (landscape / compare)

After consolidation and SCR `features.json` artifacts exist:

```bash
python3 skills/silver-deep-research-multi-ai/scripts/package_solution_outputs.py \
  --dir "$SB_RESEARCH_OUT_DIR"
```

Runs `compare_solutions.py` (JSON + MD + XLSX), then both SPA reports.
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
