# Comparator reference

Weighted matrix scoring ported from MultAI (MIT). See `scripts/compare_solutions.py`,
`scripts/matrix_ops.py`, and `scripts/matrix_builder.py`.

## Primary path

1. Union features from all SCR `features.json` files
2. Map priorities from `need_profile.json` (`must_haves` → Critical)
3. Apply ticks (✔) per solution per feature with evidence backing
4. Run `compare_solutions.py --dir $SB_RESEARCH_OUT_DIR` → `comparison/comparison.json`
5. Run `generate_report_spa.py --dir $SB_RESEARCH_OUT_DIR` → serverless `report.html`

`comparison.json` + SPA `report.html` are the **required** DR-PACKAGE outputs for
solution-landscape and solution-compare runs.

## Optional XLSX export

`matrix_builder.py` and `matrix_ops.py` provide optional CLI XLSX export/manipulation.
They are **not** required for DR-PACKAGE validation — use only when a spreadsheet
artifact is explicitly requested.

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
