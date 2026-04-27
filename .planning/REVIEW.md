# Code Review — v0.30.0

Detailed findings recorded at `.planning/phases/v0.30.0/REVIEW-stage1.md`.

| File | Finding | Severity | Recommendation |
|------|---------|----------|----------------|
| hooks/stop-check.sh:178-182 | User `transient_path_ignore_patterns` concatenated into ERE without shape validation | MINOR | Backlog issue #90 (filed) — accept |
| hooks/stop-check.sh:307-310 | on-main filter strips `finishing-a-development-branch` from `required_deploy_cfg` only, not `required_planning_cfg` | MINOR | Defensive nice-to-have; planning floor by convention doesn't include that skill |
| hooks/session-start:24-37 | Comment says `read -t 0` but code uses `cat`; `[[ ! -t 0 ]]` guard mitigates terminal stdin case | MINOR | Accept; Claude Code always sends payload |
| hooks/stop-check.sh:172 | `jq … join("|")` glues user patterns without grouping; user-error if pattern contains literal `|` | MINOR | Same threat surface as #90 |

## Gate: PASS

Zero CRITICAL/MAJOR findings. Four MINOR items, all with non-exploitable threat models. One captured in backlog #90 for follow-up. Adversarial regression coverage verified: 18 new tests across 3 hook test files, 2 integration alignments, 1217 tests total green.
