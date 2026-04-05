# Technical Debt Register

Items are appended newest-first per phase. Format: `| Item | Severity | Effort | Phase introduced |`

Priority score = (Impact + Risk) × (6 − Effort)  where Impact/Risk/Effort are 1–5.

---

## Phase 2 — Skill Enforcement Expansion (2026-04-05)

| Item | Severity | Effort | Phase introduced |
|------|----------|--------|-----------------|
| `.silver-bullet.json` `required_deploy` and `all_tracked` correctness not validated in CI — `completion-audit.sh` silently enforces wrong skill list if arrays drift; a `jq` assertion in CI would catch this immediately | High | Low | Phase 2 |
| No CI step enforcing template parity — `docs/workflows/` and `templates/workflows/` byte-identity is currently verified only during code review; a `diff` step in CI would prevent silent template drift for new projects | High | Low | Phase 2 |
| `hooks/dev-cycle-check.sh` has no test file — all four stage routing paths (A/B/C/D), phase-skip detection, and the trivial-file bypass are completely untested; bash test patterns already exist in `tests/hooks/` for reference | High | Medium | Phase 2 |
| `finalization_skills` in `dev-cycle-check.sh` is a hardcoded string that must be manually kept in sync with `required_deploy` in `.silver-bullet.json` — adding a future skill to `required_deploy` without updating `finalization_skills` silently breaks phase-skip detection | Medium | Medium | Phase 2 |

### Prioritized Remediation Plan

| Priority | Item | Score | Suggested phase |
|----------|------|-------|-----------------|
| 1 | Add `jq` CI assertions for `required_deploy` and `all_tracked` | (3+4)×(6−1)=35 | Next CI improvement pass |
| 2 | Add `diff` CI step for `docs/` vs `templates/` parity | (3+3)×(6−1)=30 | Next CI improvement pass |
| 3 | Create `tests/hooks/test-dev-cycle-check.sh` covering all 4 stages + trivial bypass | (4+4)×(6−3)=24 | Phase 3 or dedicated test hardening sprint |
| 4 | Derive `finalization_skills` from `.silver-bullet.json` at hook runtime instead of hardcoding | (3+3)×(6−3)=18 | When next skill is added to `required_deploy` |

Items 1 and 2 can be done alongside feature work in under an hour total. Item 3 requires ~2 hours to write comprehensive bash test cases. Item 4 requires a small refactor of `dev-cycle-check.sh` startup to read and parse the JSON config.
