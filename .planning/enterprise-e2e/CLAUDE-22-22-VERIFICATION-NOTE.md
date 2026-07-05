# Claude 22/22 strict-clean claim — verification note

**Date:** 2026-07-06  
**Verifier:** certification-status subagent (parent orchestrator)  
**Verdict:** **NOT VERIFIED** — do not upgrade Claude proof level on main.

## Claim

"Claude had lastly reported 22/22 strict clean."

## Latest narrative source

R9 Gate 3 closure on branch `enterprise-e2e/multi-host` (commits `c556da54`, `094cf2cd`, `37195d52`) — **not merged to `main`**. Worktree `/private/tmp/sb-multi-host-policy-commit` is **gone**.

Agentmemory: [`.agentmemory/memory/r9-gate3-closure-verify-20260704.md`](../../.agentmemory/memory/r9-gate3-closure-verify-20260704.md) claims scorer/registry 22/22 and `strict-clean-check.sh` exit 0.

## Machine checks on current `main` @ `1cd89e4f0c25`

| Check | Result |
|-------|--------|
| `strict-clean-check.sh --ledger ROUND-9-LEDGER.md` | **FAIL** — ledger STALE 0/22; registry 0/22 @ current install_fp |
| `.row-pass-registry.json` best Claude install | **6/22** @ `claude@ba77d1b0ed19+596e99deab17` (smoke rows 1,3,6,11,21,22) |
| `ROUND-9-LEDGER.md` | Gate 3 **IN FLIGHT**; smoke 6/6 only |
| `ROUND-9-GATES.md` | Gate 2 closure GREEN; Gate 3 full matrix **NOT STARTED** on main |
| `scripts/enterprise-e2e-certification-status.sh` | Claude `live_e2e_partial` 6/22 |

## Orphan branch evidence (not on main ancestry)

Commit `37195d527da7` registry `claude@46aea89b60cf+ff940b08e724`: 22 rows, source **`matrix-log-reconcile`** (not live `matrix` per row).

Follow-up outcomes audit (transcript subagent `39539d2d`, 2026-07-04): **`enterprise_e2e_outcome_row_passes` 16/22** — rows **1, 3, 6, 11, 21, 22** FAIL on migrated/pilot logs. Timeline DONE line appended with **`strict-clean=0`**.

`ROUND-6-GATES.md` on main: row **22 outcome FAIL** (`OUT-SKILL-01` partial); round strict-clean **FAIL**.

## Blockers vs methodology

1. **Branch drift** — closure artifacts never landed on canonical `main` ledger/gates/registry.
2. **Registry-only / migrate sources** — `r9-ledger-migrate`, `matrix-log-reconcile`; not live TUI @ pinned install_fp.
3. **Outcome scorer gap** — 16/22 canonical passes even when strict-clean script exited 0 on worktree (fallback/registry merge).
4. **Ledger reconcile** — main `ROUND-9-LEDGER.md` has no COMPLETE 22/22 matrix table with graphify/agentmemory refs.
5. **Consecutive strict-clean** — R6+R9 pair not closed on main; R6 row 22 blocks.

## Required before certification upgrade

1. Merge or replay Gate 3 on `main` with live rows @ single `install_fp` (no mid-matrix SHA drift).
2. Per-row `enterprise_e2e_outcome_row_passes` **22/22** on retained live logs (not migrate-only).
3. Update `ROUND-9-LEDGER.md` + `ROUND-9-GATES.md` to CLOSED with ledger reconcile COMPLETE.
4. `strict-clean-check.sh` exit 0 @ main HEAD install_fp.
5. Optional: Claude product audit (§5b) per Codex pattern.

**Action taken:** Certification artifacts left conservative; `CERTIFICATION-STATUS.json` regenerated from sources.

---

## Phase A closure attempt (2026-07-06)

**Verifier:** Phase A subagent @ `609ee0a1812c`

| Check | Result |
|-------|--------|
| `/private/tmp/sb-main-row11-fp` | **MISSING** — Gate 3 drivers defaulted to stale path |
| `round9-gate3-driver.sh --preflight-only` | **Implemented** — SB_ROOT resolves to main repo |
| Registry @ current `install_fp` | **0/22** (`claude@609ee0a1812c+2717f916398e`) |
| Best registry (prior FP) | **6/22** @ `claude@ba77d1b0ed19+596e99deab17` (different surface hash — not strict-clean eligible without re-run) |
| Live Gate 3 matrix | **NOT RUN** — requires multi-hour Claude TUI + token gateway + tmux |
| `public_autonomous_enterprise_claim_ready` | **false** (unchanged) |

**Harness fixes landed:** `enterprise-e2e-sb-root-resolve.sh`, `round9-gate3-driver.sh`, `registry-migrate-install.sh`, `hosts.json` Claude R9 fixture pins, `round9-matrix-driver.sh` SB_ROOT fix.

**Operator unblock:** `RTK_DISABLED=1 bash scripts/enterprise-e2e/round9-gate3-driver.sh --tmux` after cc-switch + agentmemory preflight per [CLAUDE-TUI-PROTOCOL.md](./CLAUDE-TUI-PROTOCOL.md).
