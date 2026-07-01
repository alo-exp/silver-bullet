# Round Cursor-1 — Gate checklist

**Updated:** 2026-07-01T09:35Z  
**SB HEAD:** `2e44b65c` (`enterprise-e2e/cursor`)  
**Ledger:** [ROUND-CURSOR-1-LEDGER.md](./ROUND-CURSOR-1-LEDGER.md)

## Status: **NOT STRICT-CLEAN**

| Metric | Value |
|--------|-------|
| Matrix ledger | **22 / 22** — reconcile **COMPLETE** |
| T1 FORCE×2 | **PASS** 2/2 |
| Phase A ladder | **PASS** 8/8 ([cursor-ladder-live.log](cursor-ladder-live.log)) |
| `run-all-tests` | **IN FLIGHT** (tmux `cursor-runall`; 3 suite fails so far) |
| RCS trihost | **83/100** (ladder credit pending `SB_E2E_RCS_LADDER=8/8`) |

### Phase C

| Check | Status |
|-------|--------|
| Validation `--live` | **PASS** 6/6 |
| Pre-release `--live` | **PASS** 40/40 |
| `run-all-tests` | **IN FLIGHT** → `/tmp/cursor-phasec-run-all-r2.log` |
| RCS `SB_E2E_RCS_TRIHOST=full` | **83** (target ≥85 after run-all green) |

### Gates

| Gate | Status |
|------|--------|
| Matrix 22/22 live | **PASS** |
| Ledger reconcile | **COMPLETE** |
| T1 FORCE×2 | **PASS** |
| Phase A ladder 8/8 | **PASS** (1× clean; need 2× for strict-clean) |
| `run-all-tests` | **PENDING** |
| Strict-clean | **NO** |

### Next

1. `run-all-tests` green on `enterprise-e2e/cursor`
2. RCS ≥85 with `SB_E2E_RCS_LADDER=8/8`
3. Ladder 8/8 × 2 consecutive clean rounds
