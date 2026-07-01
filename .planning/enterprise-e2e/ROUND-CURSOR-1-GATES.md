# Round Cursor-1 — Gate checklist

**Updated:** 2026-07-01T02:15Z  
**SB HEAD:** `098f48c6` (`enterprise-e2e/cursor`)  
**Ledger:** [ROUND-CURSOR-1-LEDGER.md](./ROUND-CURSOR-1-LEDGER.md)

## Status: **NOT STRICT-CLEAN**

| Metric | Value |
|--------|-------|
| Matrix ledger | **15 / 22** |
| Blocker rows cleared | 3–4, 20–22 ✓ |
| Remaining fail rows | 6, 7, 12, 14–16, 18 |
| `run-all-tests` | **5194 pass / 15 fail** |
| Ladder | **0 / 8** (deferred) |

### Latest

- **retry3d:** rows 4, 20 live PASS; 21–22 internal FAIL (markers wiped)
- **retry3e @098f48c6:** rows **21–22 internal PASS** (parent-log/ledger seed fix)
- DNS `agentn.global.api5.cursor.sh` restored

### Gates

| Gate | Status |
|------|--------|
| Matrix 22/22 | **FAIL** 15/22 |
| `test-outcome-assessment.sh` | **PASS** 81/81 |
| `run-all-tests` | **FAIL** 15 |
| Ledger reconcile | **FAIL** 15/22 |
| Strict-clean | **NO** |
