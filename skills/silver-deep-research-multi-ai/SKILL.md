---
name: silver-deep-research-multi-ai
description: >
  Opt-in multi-model deep research. Composes canonical silver-deep-research engine,
  new /sb:multi-ai-task primitive, and Cursor/OCG backends. Dual serverless HTML reports.
argument-hint: "<research question> [--mode deep|ultradeep] [--research-type default|solution-landscape|solution-compare] [--dry-run]"
version: 1.0.0
---

# /sb:deep-research-multi-ai — Multi-Model Deep Research

**Catalog:** workflow `WF-SILVER-DEEP-RESEARCH-MULTI-AI` · flow step
`FS-SILVER_DEEP_RESEARCH_MULTI_AI` · composes `AF-MULTI-AI-TASK` per eligible phase.

Opt-in sibling of [`silver-deep-research`](../silver-deep-research/SKILL.md). Does **not**
replace single-agent `/sb:deep-research` or revive removed `FS-SILVER_MULTI_AI` MultAI surfaces.

## Architecture (locked)

```text
Host DR controller (silver-deep-research instructions)
  → per eligible phase: /sb:multi-ai-task (parallel lanes)
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

Without `--output-root` the run directory is `<cwd>/research/<date>-<slug>` (never inside the
skill's install tree). An existing run is never overwritten; `--force` moves a previous run
aside as `<name>.replaced-<UTC>` instead of deleting it, and refuses `/`, `$HOME`, the working
directory and its parents. The tool writes only inside the run directory and never deletes
user files: folders it did not generate, and `scr.md` / `features.json` / landscape files you
or the host wrote, are left alone and listed under `preserved` / `stale_solution_dirs`.

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
  --output consolidated/consolidation.json
```

Takes `DR-*` contribution envelopes + the matching result index. The host is responsible for
validating envelopes against the schema before this step; `consolidate.py` itself is tolerant,
not a validator: a malformed claim item is counted in `coverage.malformed_items` and skipped.
The consensus pool is the result index's agent count, and `--resolved-pool` is rejected when
it disagrees. Claims are merged by wording only; a "consensus" row means that many families
said the same claim, not that the claim is true. Forbidden inputs: reports, synthesis, V-loop
artifacts, worker state.

## Reports (dual)

| File | Profile | When |
|------|---------|------|
| `report.html` | `--profile general` | All supported research types |
| `landscape-report.html` | `--profile landscape` | `solution-landscape` / `solution-compare` only |
| `comparison/comparison-matrix.xlsx` | — | `solution-landscape` / `solution-compare` (weighted matrix) |

**Landscape viewer:** MultAI-parity SPA (`render_landscape_outputs()` in `landscape_preview_render.py` + `assets/landscape-preview.template.html`) — sidebar TOC, Chart.js 2×2/Wave/Value Curve, COMMERCIAL/OSS nav, Copy/PDF/Compare/Matrix. Open it from `file://`; no `http.server`. The page text, table of contents, vendor cards and
tables are static HTML and work offline. Charts use Chart.js, chartjs-plugin-datalabels and
lucide from version-pinned CDN URLs carrying SRI (`integrity=sha384-…`) hashes, so offline the
charts fall back to their data tables; Google Fonts is also fetched when online. It is
therefore *not* fully self-contained. The PDF is rendered by `render_landscape_pdf.cjs` in a
sandboxed, JavaScript-free, offline Chromium; where the sandbox cannot start (root in a
container) it fails with a clear message and `SB_LANDSCAPE_PDF_NO_SANDBOX=1` is the explicit
opt-out. `generate_landscape_report.py` is a compatibility wrapper around that function (not the retired general SPA).

**General DR:** unchanged tabbed `generate_spa_report.py:general` — no MultAI chart sections.

## Landscape / solution prompts (MultAI parity, SB engine only)

For `research_type` `solution-landscape` or `solution-compare` only — **do not** alter default deep-research prompts.

| Asset | Path | Use |
|-------|------|-----|
| Landscape researcher prompt | [`../silver-deep-research/reference/landscape/prompt-template.md`](../silver-deep-research/reference/landscape/prompt-template.md) | DR-RETRIEVE per-model landscape research |
| Consolidation guide (9 sections + chart-data) | [`../silver-deep-research/reference/landscape/consolidation-guide.md`](../silver-deep-research/reference/landscape/consolidation-guide.md) | DR-TRIANGULATE → `landscape/landscape-report.md` + `landscape/chart-data.json` |
| Comparator framework | [`../silver-deep-research/reference/comparator/capability-framework.md`](../silver-deep-research/reference/comparator/capability-framework.md) | Matrix build via `compare_solutions.py` |

Host controller passes the consolidation guide to synthesis workers. Note that packaging
(below) regenerates `landscape/landscape-report.md` and `landscape/chart-data.json` from the
run's data with `synthesize_landscape`; a file the host wrote is preserved and reported rather
than overwritten. `consolidate.py` remains a deterministic claim merge for
`consolidated/consolidation.json` only.

**Matrix ticks.** Workers return `matrix_entries` (`{vendor, feature, supported, source_ref}`;
optional in the envelope schema). A model casts one vote per (vendor, feature) (its latest row
wins); the cell follows the majority, a tie is not a tick, and split cells are written to
`landscape/disputed-cells.json` and listed in the report. A vendor must match a known name or
alias exactly (a blank or partial name never matches); without a category pack an unnamed
vendor becomes its own column, so any topic works with no built-in catalogue. Claim prose is
parsed heuristically only for cells no worker voted on, resolving vendors from the run's own set
(pack names plus the vendors workers named). Feature names are folded (case, spacing,
punctuation) before voting and shown in the user's must-have spelling, else the most common one.
A run whose need profile names no must-have that matches the matrix gets a derived
`weights_override` (the most-ticked features as Critical, flagged `weights_override_derived`) so
the content gate has Critical rows; a must-have no vendor offers is still reported by the gate.

**Category packs.** Category-specific prose (market overview, trends, buying guidance,
consensus themes, vendor notes) is data in `reference/category-pack-overlays/<pack>.json` and
applies only when the need profile selects that pack. The same holds for the feature rubric and
aliases, Leader rules, scoring weights, key competitive factors, the inclusion ledger,
brand-rename policies and URL rewrites: they sit under the overlay's `vocabulary` key
(`scripts/pack_vocabulary.py`) and the code defaults are neutral. The only pack shipped is
`agentic-sdlc-process-orchestrator` (the pack itself lives in `silver-deep-research`). For any
other topic the report is built only from the run's own envelopes, matrix and audit; no vendor
is built in or special-cased.

## Solution packaging (landscape / compare)

After consolidation and SCR `features.json` artifacts exist:

```bash
python3 skills/silver-deep-research-multi-ai/scripts/package_solution_outputs.py \
  --dir "$SB_RESEARCH_OUT_DIR"
```

Runs `compare_solutions.py` (JSON + MD + XLSX), then both SPA reports.
For `solution-landscape` / `solution-compare`, packaging **always** re-runs
`materialize_solution_artifacts` and `synthesize_landscape` (force) before the landscape SPA
and `validate_landscape_content` gate. Host-written files are preserved, not replaced.
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
