# Round Cursor-2 — Gate checklist

**Host:** Cursor agent TUI — **confirmation round**  
**Updated:** 2026-07-01T13:45Z  
**SB HEAD:** `26cf687f` (`enterprise-e2e/cursor`)  
**Test app HEAD:** `enterprise-e2e/round-1-cursor` @ `8482e60` (worktree)  
**Ledger:** [ROUND-CURSOR-2-LEDGER.md](./ROUND-CURSOR-2-LEDGER.md)  
**Prior round:** [ROUND-CURSOR-1-GATES.md](./ROUND-CURSOR-1-GATES.md) — strict-clean **Pass** @ `e9236365`

## Status: **IN PROGRESS** (T0 PASS · T1 PASS · Phase A PASS · matrix in flight)

**Policy (2026-07-01):** **Single-pass-at-install-version** — do not repeat matrix/ladder/T1 rows already Pass @ `SB_INSTALL_VERSION_KEY` (`SB_CURSOR_PLUGIN_VERSION` + install SHA). See [ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md](../../docs/testing/ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md) §11. T1 FORCE×2 **replaced** by single FORCE when not already green. Harness: `matrix.sh` logs `SKIP: row N already pass @ install <ver>`; overrides `SB_E2E_MATRIX_FORCE=1` / `SB_E2E_FORCE_ROW=1`.

**Release pair:** Round Cursor-2 completes the **2/2** consecutive strict-clean requirement for Cursor host release sign-off.

**Strict-clean NOT claimed** until full Tier A→B→C on this round.

### Bootstrap (2026-07-01)

| Step | Status |
|------|--------|
| Ledger reset from template | **DONE** |
| Worktree `enterprise-grade-test-app-cursor` @ `round-1-cursor` | **DONE** |
| Cherry-pick CI from main | **DONE** (`6ab2e26f` `7cf34b14` `a455aeb8`; v0.49.1 release merge deferred) |
| T0 structural suite | **PASS** 189/0 |
| T0 outcome harness | **PASS** 59/0 |
| T0 surface validation | **PASS** |
| T0 branch assert | **PASS** 13/0 |
| T1 row 1 FORCE (single @ install version) | **PASS** 1/1 *(legacy log: 2/2 before policy)* |
| Phase A ladder | **PASS** 8/8 @ `12:58Z` |
| T2 smoke (rows 1,3,6) | **PASS** (2/0/1 skip) |
| Full matrix 22/22 | **IN PROGRESS** (row 8) |

### Round gates

| Gate | Status |
|------|--------|
| Tier A (T0) structural preflight | **PASS** |
| T1 row 1 FORCE (single @ install version) | **PASS** |
| review-fix-ladder 8/8 (single pass per rung @ install version) | **PASS** |
| Matrix ledger 22/22 (zero new friction) | **PENDING** |
| Outcome assessment harness | **PENDING** (live rows) |
| All outcome criteria + blocking autonomy gates | **PENDING** |
| Phase C (`run-all-tests`, overlays, reconcile, RCS, CLI smoke) | **PENDING** |
| New issues vs baseline 76 | **PENDING** |
| Round strict-clean | **PENDING** |
| **2 consecutive strict clean rounds** | **PENDING (1/2 → 2/2)** |

## Release verdict

**Cursor host release readiness:** **BLOCKED** until Cursor-2 strict-clean → **2/2**.

**Current pair progress:** **1/2** (Cursor-1 strict-clean; Cursor-2 bootstrap in flight).
