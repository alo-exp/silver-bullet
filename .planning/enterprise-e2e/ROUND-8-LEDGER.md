# Round 8 Ledger — Enterprise E2E Matrix

> **Working branch:** `enterprise-e2e/multi-host` @ `e2f72ac6` — Round 8 **0/22** live matrix launched with `SB_E2E_SURFACE_SKIP=0`. See [ROUND-8-GATES.md](./ROUND-8-GATES.md).

---

## Round metadata

| Field | Value |
|-------|-------|
| Round | 8 |
| SB repo SHA | `e2f72ac6` |
| Test app SHA | `565e825` |
| Claude plugin install | `e2f72ac6` — install-claude.sh @ round start |
| Outcome assessment | pending |
| Claude model (frozen) | `haiku` (matrix default) |
| Operator | Cursor agent (`SB_E2E_MONITOR_AUTO_RESTART=0`) |
| Start date | 2026-07-01 |
| End date | *in progress* |
| Round clean? | **PENDING** — `OUT-SURFACE-01` **live** (`SB_E2E_SURFACE_SKIP=0`) |

**Round 8 context:** Host-bundles install fix cherry-picked from `main`; surface test **6/6 PASS** pre- and post-`install-claude.sh` @ `e2f72ac6`.

---

## Workflow matrix (22 rows)

| # | WF slug | Session date | Claude model | Pass/Fail | failure_class | Issues | SB fix commit | graphify_query_ref | agentmemory_export_ref |
|---|---------|--------------|--------------|-----------|---------------|--------|---------------|--------------------|------------------------|
| 1 | `silver-router` | | haiku | **Pending** | | | | | |
| 2 | `silver-research` | | haiku | **Pending** | | | | | |
| 3 | `silver-feature` | | haiku | **Pending** | | | | | |
| 4 | `silver-bugfix` | | haiku | **Pending** | | | | | |
| 5 | `silver-ui` | | haiku | **Pending** | | | | | |
| 6 | `silver-fast` | | haiku | **Pending** | | | | | |
| 7 | `silver-test` | | haiku | **Pending** | | | | | |
| 8 | `silver-refactor` | | haiku | **Pending** | | | | | |
| 9 | `silver-benchmark` | | haiku | **Pending** | | | | | |
| 10 | `silver-content` | | haiku | **Pending** | | | | | |
| 11 | `silver-devops` | | haiku | **Pending** | | | | | |
| 12 | `silver-deploy` | | haiku | **Pending** | | | | | |
| 13 | `silver-canary` | | haiku | **Pending** | | | | | |
| 14 | `silver-release` | | haiku | **Pending** | | | | | |
| 15 | `review-triad` | | haiku | **Pending** | | | | | |
| 16 | `ship-readiness` | | haiku | **Pending** | | | | | |
| 17 | `silver-incident` | | haiku | **Pending** | | | | | |
| 18 | `silver-retro` | | haiku | **Pending** | | | | | |
| 19 | `silver-forensics` | | haiku | **Pending** | | | | | |
| 20 | `process-maintenance` | | haiku | **Pending** | | | | | |
| 21 | `post-exec-gates` | | haiku | **Pending** | harness-only (parent row 3) | | | | |
| 22 | `validate-substep` | | haiku | **Pending** | harness-only (parent row 4) | | | | |

**Matrix progress:** **0 / 22** live outcome PASS.
