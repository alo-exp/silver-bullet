# Comparator reference

Weighted matrix scoring ported from MultAI (MIT). See `scripts/compare_solutions.py`,
`scripts/matrix_ops.py`, and `scripts/matrix_builder.py`.

## Primary path

1. Union features from all SCR `features.json` files
2. Map priorities from `need_profile.json` (`must_haves` → Critical; optional `persona_id` boosts)
3. Apply ticks (✔) per solution per feature with evidence backing
4. Run `compare_solutions.py --dir $SB_RESEARCH_OUT_DIR` → `comparison/comparison.json`,
   `comparison/comparison-matrix.md`, and `comparison/comparison-matrix.xlsx`
5. Run `generate_report_spa.py --dir $SB_RESEARCH_OUT_DIR` → serverless `report.html`

`comparison.json`, `comparison-matrix.xlsx`, and SPA `report.html` are **required** DR-PACKAGE
outputs for solution-landscape and solution-compare runs.

## XLSX export

`compare_solutions.py` emits `comparison/comparison-matrix.xlsx` by default (MultAI-weighted
COUNTIFS score row). Standalone:

```bash
python3 skills/silver-deep-research/scripts/generate_comparison_xlsx.py --dir "$SB_RESEARCH_OUT_DIR"
```

DR-multi-AI packaging:

```bash
python3 skills/silver-deep-research-multi-ai/scripts/package_solution_outputs.py --dir "$SB_RESEARCH_OUT_DIR"
```

`matrix_ops.py` supports add-platform, reorder-columns, combo, verify on existing matrices.

## Personas

Set optional `persona_id` on `need_profile.json` (`startup` | `enterprise` | `regulated`).
Catalog: `reference/need-profile-personas.json`.

## Weights

| Priority | Weight |
|----------|--------|
| Critical | 5 |
| Very High | 4 |
| High | 3 |
| Medium | 2 |
| Low | 1 |

Unknown priorities default to weight **1** (`matrix_core.priority_weight`).

## Forbidden

- No `http.server` or `launch_report.py` — use `generate_report_spa.py` for HTML

