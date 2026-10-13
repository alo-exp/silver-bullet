# Research output contract

Canonical output root for SB deep research:

```text
research/<YYYY-MM-DD>-<slug>/
```

Migrated from legacy `.planning/research/` (archived under `.planning/archive/research/`).

## Research types

| Type | Entry | Key artifacts |
|------|-------|---------------|
| `default` | `/silver:deep-research` general questions | Standard DR-* artifacts |
| `solution-landscape` | AF-DECIDE category/tool decisions | `shortlist.json` (5), SCRs, matrix, `report.html` |
| `solution-compare` | `/silver:compare` | `solutions_requested.json`, SCRs × N, matrix, `report.html` |

## Gates

- **Need profile:** `need_profile.json` with `interview_complete` before retrieval (solution types)
- **SCR naming:** `solutions/<slug>/scr.md` — never `cir.md` in SB surfaces
- **HTML:** serverless `report.html` with inline JSON — no local HTTP server

## Smoke fixtures

- [`2026-07-09-fixture-landscape/`](2026-07-09-fixture-landscape/) — landscape smoke
- [`2026-07-09-fixture-compare/`](2026-07-09-fixture-compare/) — compare smoke

Run validators:

```bash
python3 skills/silver-deep-research/scripts/validate_landscape.py --dir research/2026-07-09-fixture-landscape
python3 skills/silver-deep-research/scripts/validate_compare.py --dir research/2026-07-09-fixture-compare
python3 skills/silver-deep-research/scripts/validate_spa_report.py --report research/2026-07-09-fixture-landscape/report.html
```
