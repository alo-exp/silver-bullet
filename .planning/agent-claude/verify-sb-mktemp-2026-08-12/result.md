# Result — SB mktemp pipeline 2026-08-12

**Branch:** `fix/sb-mktemp-site-regression`  
**Base:** `origin/main` @ `ca511139`

## Issues

| ID | Issue | Disposition |
|----|-------|-------------|
| SB-BUG-1 residual | [#267](https://github.com/alo-exp/silver-bullet/issues/267) | Fixed in this PR |
| SB-BUG-1a | [#268](https://github.com/alo-exp/silver-bullet/issues/268) | Fixed in this PR |
| SB-BUG-1b | [#269](https://github.com/alo-exp/silver-bullet/issues/269) | Fixed in this PR |
| SB-FRICTION-4 | [#270](https://github.com/alo-exp/silver-bullet/issues/270) | Fixed in this PR |
| SB-FRICTION-3 | [#271](https://github.com/alo-exp/silver-bullet/issues/271) | Fixed in this PR |
| SB-FRICTION-1 | [#272](https://github.com/alo-exp/silver-bullet/issues/272) | Deferred (design) |
| SB-FRICTION-6 | [#273](https://github.com/alo-exp/silver-bullet/issues/273) | Deferred (docs/design) |
| SB-FRICTION-2 | #258/#266 | Already fixed — not re-filed |
| SB-FRICTION-5 | #249/#250/#255/#265 | Already fixed — not re-filed |

## TDD

- RED: OLD `…XXXXXX.log` template — second call rc=1 (BSD EEXIST). See [tdd-portability.log](tdd-portability.log).
- GREEN: live function — two distinct `.log` paths, no literal `XXXXXX`; fallback under unwritable state dir. Same log.
- Complement: [test-site-regression-log-path.sh](../../../tests/scripts/test-site-regression-log-path.sh) still green (13/13).

## Local tests (pre-PR)

- `tests/hooks/test-site-session-mktemp-portability.sh` — 10/10
- `tests/scripts/test-site-regression-log-path.sh` — 13/13
- `tests/hooks/test-session-start.sh` — 51/51 (includes Test 1d)
- `tests/scripts/test-enterprise-e2e-certification-status.sh` — 18/18
- `tests/hooks/test-site-session-gates.sh` — 35/35
