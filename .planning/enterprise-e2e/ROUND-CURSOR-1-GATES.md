# Round Cursor-1 — Gate checklist

**Updated:** 2026-07-01T12:00Z  
**SB HEAD:** `e2b6800` (`enterprise-e2e/cursor`)  
**Ledger:** [ROUND-CURSOR-1-LEDGER.md](./ROUND-CURSOR-1-LEDGER.md)

## Status: **NOT STRICT-CLEAN**

| Metric | Value |
|--------|-------|
| Matrix ledger | **18 / 22** |
| Blocker rows cleared | 3–4, 6–7, 14, 20–22 ✓ |
| Remaining fail rows | **12, 15, 16, 18** |
| `run-all-tests` | **5194 pass / 15 fail** (pre-retry3f) |
| Ladder | **0 / 8** (deferred until 22/22 live) |

### Latest

- **retry3f complete:** tmux `cursor-e2e-retry3f` dead; ~2h45m; log [`.e2e-matrix-cursor-retry3f.log`](../../.e2e-matrix-cursor-retry3f.log)
- **Live PASS:** rows **6, 7, 14**
- **Live FAIL:** rows **12, 15, 16, 18** (substantive logs; no rescore uplift)
- Pre-flight rescore PASS on 15/16/18 **not** counted — live sessions failed

### Gates

| Gate | Status |
|------|--------|
| Matrix 22/22 live | **FAIL** 18/22 |
| `test-outcome-assessment.sh` | **PASS** 81/81 |
| `run-all-tests` | **FAIL** 15 |
| Ledger reconcile | **FAIL** LEDGER_MISMATCH 18/22 |
| Phase A ladder 8/8 | **NOT STARTED** |
| Strict-clean | **NO** |

### Next

1. Harness fix or **retry3g** live on rows **12, 15, 16, 18**
2. Phase C: `run-all-tests` green + RCS ≥85
3. Phase A: ladder 8/8 × 2 consecutive clean rounds
