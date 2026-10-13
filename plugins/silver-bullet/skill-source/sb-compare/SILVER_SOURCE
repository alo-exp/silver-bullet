---
name: "sb:compare"
title: "Compare"
description: >
  Compare N>=2 named solutions via deep-research engine (research_type=solution-compare).
  Runs mandatory need-profile interview, SCR extraction per solution, weighted matrix, serverless report.html.
argument-hint: "<solution-1> <solution-2> [...solution-N] [--mode deep|ultradeep] [--auto]"
version: 1.0.0
---

# /sb:compare — Named Solution Comparison

Thin orchestrator route into **`silver-deep-research`** with
`research_type=solution-compare`. Does **not** invoke MultAI or multi-AI orchestration.

## Usage

```bash
/sb:compare Backstage Port Cortex [--mode deep]
```

## Behavior

1. Parse **N ≥ 2** solution names (optional URLs/repos in parentheses).
2. Reject if N < 2.
3. Soft-warn if N > 12 (continue unless user confirms).
4. Run **need-profile interview** (`reference/need-profile-interview.md` via clarify discipline).
5. Create output directory:

```bash
export SB_RESEARCH_OUT_DIR="research/$(date -u +%Y-%m-%d)-compare-<slug>"
mkdir -p "$SB_RESEARCH_OUT_DIR/validation"
```

6. Write `run_manifest.json` with `research_type: solution-compare`.
7. Write `solutions_requested.json` with the named list.
8. Delegate all DR-* phases to **`skills/silver-deep-research/SKILL.md`** — do not duplicate the engine.
9. Skip market shortlist — user list is the research set.
10. Produce SCR per solution → `compare_solutions.py` → `generate_report_spa.py`.
11. Open `report.html` in host browser MCP and system browser (`open report.html`) — **no HTTP server**.

## `--auto`

Only when user explicitly passes `--auto`: record assumed defaults in `need_profile.json`
with `"auto_assumed": true`. Never silently invent must-haves.

## Validation

```bash
python3 skills/silver-deep-research/scripts/validate_compare.py --dir "$SB_RESEARCH_OUT_DIR"
python3 skills/silver-deep-research/scripts/validate_spa_report.py --report "$SB_RESEARCH_OUT_DIR/report.html"
```

## Catalog

Workflow entry: specialized path into `FS-SILVER_DEEP_RESEARCH` (not a new multi-AI flow).
