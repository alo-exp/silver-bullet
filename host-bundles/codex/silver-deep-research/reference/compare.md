# Solution Compare Reference

Named solution comparison (`research_type=solution-compare`) evaluates **N ≥ 2**
solutions the user already chose — no market shortlist step.

## When to use

- You know the candidate solutions (e.g. Backstage, Port, Cortex).
- You need SCR-backed capability matrices and a weighted recommendation.
- You want a serverless `report.html` under `research/<date>-<slug>/`.

For market surveys and top-5 shortlists, use `solution-landscape` via
`/silver:deep-research` instead. For named head-to-head comparison, use
`/silver:compare`.

## Artifacts

| Artifact | Purpose |
|----------|---------|
| `need_profile.json` | Mandatory interview output; gates `DR-SCOPE` and `DR-RETRIEVE` |
| `solutions_requested.json` | User-named solution list |
| `solutions/<slug>/scr.md` | Solution Capability Report per candidate |
| `solutions/<slug>/features.json` | Structured features for matrix scoring |
| `comparison/comparison.json` | Weighted rankings from `compare_solutions.py` |
| `report.html` | Serverless SPA from `generate_report_spa.py` |

## Validation

```bash
python3 skills/silver-deep-research/scripts/validate_compare.py --dir "$SB_RESEARCH_OUT_DIR"
python3 skills/silver-deep-research/scripts/validate_spa_report.py --report "$SB_RESEARCH_OUT_DIR/report.html"
```

## Mode requirements

`solution-compare` and `solution-landscape` require **`deep`** or **`ultradeep`**
mode. `quick` and `standard` are rejected by `phase_gate.py`.
