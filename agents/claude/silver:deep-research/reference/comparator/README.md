# Comparator reference

Weighted matrix scoring ported from MultAI (MIT). See `scripts/matrix_ops.py` and
`scripts/matrix_builder.py`.

## Weights

| Priority | Weight |
|----------|--------|
| Critical | 5 |
| Very High | 4 |
| High | 3 |
| Medium | 2 |
| Low | 1 |

## Workflow

1. Union features from all SCR `features.json` files
2. Map priorities from `need_profile.json` (`must_haves` → Critical)
3. Apply ticks (✔) per solution per feature with evidence backing
4. Run `compare_solutions.py --dir $SB_RESEARCH_OUT_DIR`
5. Optional: `matrix_builder.py` for XLSX export

## Forbidden

- No `http.server` or `launch_report.py` — use `generate_report_spa.py` for HTML
