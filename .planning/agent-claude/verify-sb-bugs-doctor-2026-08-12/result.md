# Verification — doctor newline + F1–F10 (2026-08-12)

**Baseline:** `origin/main` @ `62234d74` (PR #255 merged)  
**Branch:** `fix/sb-bugs-doctor-newline`  
**SOURCE:** host-fallback (Claude OAuth not required for this pass; Report 1 reproduced locally)

## Report 1

| Item | Verdict | Action |
|------|---------|--------|
| Trailing newline strip via `sb_enforcement_tier_persist` | **GENUINE** | Fixed + [#256](https://github.com/alo-exp/silver-bullet/issues/256) |
| Same-class orchestrator / `rt_atomic_write_json` writers | **GENUINE** | Fixed (`printf '%s\n'`) |
| stack-optimizer / sb-migrate / enterprise-policy | out of scope | Untouched |

## Report 2 F1–F10

| ID | Verdict | Action |
|----|---------|--------|
| F1 | GENUINE | Filed [#258](https://github.com/alo-exp/silver-bullet/issues/258) |
| F2 | GENUINE | Filed [#259](https://github.com/alo-exp/silver-bullet/issues/259) |
| F3 | PARTIAL (copy) | Filed [#260](https://github.com/alo-exp/silver-bullet/issues/260) |
| F4 | GENUINE | Filed [#261](https://github.com/alo-exp/silver-bullet/issues/261) |
| F5 | FIXED_BY_PRIOR (#249/#255) | Skip |
| F6 | GENUINE | Filed [#262](https://github.com/alo-exp/silver-bullet/issues/262) |
| F7 | GENUINE | Filed [#263](https://github.com/alo-exp/silver-bullet/issues/263) |
| F8 | GENUINE | Filed [#257](https://github.com/alo-exp/silver-bullet/issues/257) + fixed |
| F9 | NOT_GENUINE (upstream CM) | Skip |
| F10 | PARTIAL (resolve residual) | Filed [#264](https://github.com/alo-exp/silver-bullet/issues/264) |

## Fixes in this PR

1. `printf '%s\n'` for JSON write sites (Report 1 / #256)
2. `SB_HOOK_SMOKE=1` no-op in `sb_enforcement_tier_persist`; `run_hook_smoke` sets it (#257)
3. Skip D11 hook smoke under `--dry-run`; prefer `REPO_ROOT` hooks for non-dry smoke (#257)
4. TDD in `tests/scripts/test-silver-doctor.sh` — persist newline + dry-run byte-identical

## Tests

- `bash tests/scripts/test-silver-doctor.sh` → **58 passed, 0 failed**
- Related orchestrator / bash -n suites → see `related-tests.md`

## Deferred (filed, not implemented)

F1, F2, F3, F4, F6, F7, F10 — issue-only.

## Issues filed

# Issues filed 2026-08-12 doctor/frictions
R1_newline=https://github.com/alo-exp/silver-bullet/issues/256
F8_dry_run=https://github.com/alo-exp/silver-bullet/issues/257
F1=https://github.com/alo-exp/silver-bullet/issues/258
F2=https://github.com/alo-exp/silver-bullet/issues/259
F3=https://github.com/alo-exp/silver-bullet/issues/260
F4=https://github.com/alo-exp/silver-bullet/issues/261
F6=https://github.com/alo-exp/silver-bullet/issues/262
F7=https://github.com/alo-exp/silver-bullet/issues/263
F10=https://github.com/alo-exp/silver-bullet/issues/264
SKIP_F5=fixed_by_249_255
SKIP_F9=upstream_context_mode
