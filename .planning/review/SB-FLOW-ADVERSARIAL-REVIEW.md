# SB Flow Adversarial Review

**Date:** 2026-06-18  
**Reviewer:** Independent adversarial subagent (launch-readiness gate)  
**Baseline version:** v0.44.2  
**Release target:** v0.44.3

---

## Round 1 — Bird's Eye + Ant's Eye

### Scope

- Composable flows: `silver-feature`, `silver-ui`, `silver-bugfix`, `silver-release`, `silver-devops`, `silver-fast`, `silver-ingest`, `silver-migrate`, `silver-research`, `silver-spec`, `silver-validate`, `silver` (router)
- Hook enforcement: two-tier `required_planning` / `required_deploy`, `workflow-chain-guard`, `completion-audit`, `stop-check`, `forbidden-skill-check`, `uat-gate`, `planning-file-guard`, `record-skill`, `prompt-reminder`
- Template ↔ live sync invariants (`silver-bullet.md`, config defaults)
- Cross-flow consistency vs `hooks/lib/orchestrator-state.sh` queues

### Findings (Round 1)

| ID | Severity | Issue | Disposition |
|----|----------|-------|-------------|
| R1-01 | **HIGH** | `silver-ui` documents `silver:validate` in the mandatory pre-execution chain but lacked **Step 6b Pre-Build Validation** before execute — `workflow-chain-guard` blocks edits until `silver-validate` is recorded, causing user dead-end | **FIXED** — added Step 6b mirroring `silver-feature` |
| R1-02 | **HIGH** | `silver-devops` had no `silver:validate` steps despite orchestrator queue and `workflow-chain-guard` requiring pre-build validate; post-exec queue also includes validate after secure | **FIXED** — added Step 5b (pre-build) and Step 9b (post-ship validate) |
| R1-03 | **HIGH** | `silver-fast` Tier 2 treated `silver:validate` as optional (signal table) while `workflow-chain-guard` and orchestrator queue **always** require it — users blocked at first implementation edit | **FIXED** — validate mandatory for Tier 2; workflow tracker flows updated |
| R1-04 | **MEDIUM** | `silver-fast` claimed "SessionStart creates the trivial marker" — contradicts `session-start` (clears stale marker) and `silver-bullet.md` §1 | **FIXED** |
| R1-05 | **LOW** | `silver-ui` step numbering skips Step 5 (FLOW DESIGN CONTRACT between Step 4 and Step 6) | **DEFERRED** — intentional FLOW block label; no enforcement impact |
| R1-06 | **INFO** | `silver-brainstorm-idea` referenced in prior audits but not present in repo — skill absorbed into `silver-clarify` / `silver-research` | **NO ACTION** — not a shipped skill |
| R1-07 | **INFO** | `tech-debt` external skill referenced optionally in flows; retired from `required_deploy` — optional "when available" invocation is correct | **NO ACTION** |
| R1-08 | **INFO** | `silver-bullet.md` vs `templates/silver-bullet.md.base` differ by design (placeholders, host paths) | **NO ACTION** — expected template deltas |

### Fixes Applied (Round 1)

- `skills/silver-ui/SKILL.md` — Step 6b Pre-Build Validation
- `skills/silver-devops/SKILL.md` — mandatory dependency section, Step 5b + 9b validate
- `skills/silver-fast/SKILL.md` — Tier 2 validate mandatory, trivial marker correction, workflow flows CSV
- `agents/{codex,cursor,claude}/*` — re-rendered from skills source
- `tests/integration/test-skill-execution-paths.sh` — regression guards for validate ordering

---

## Round 2 — Skeptical Re-Review

Re-checked after fixes:

| Check | Result |
|-------|--------|
| `test-skill-refs.sh` — all Invoke references resolve | PASS (80/80) |
| `test-skill-execution-paths.sh` — flow ordering + new validate guards | PASS (374/374) |
| `test-orchestrator-queue-order.sh` — queue prefixes unchanged | PASS |
| `test-workflow-chain-guard.sh` — pre-exec markers | PASS |
| `test-silver-router-flow-contracts.sh` — router/contracts | PASS |
| `silver-feature` / `silver-bugfix` / `silver-release` validate steps | PASS — already correct |
| Hook `required_deploy` vs flow promises | PASS — config authoritative |
| Forbidden skill literals in hooks | PASS — `required-skills.sh` only |
| Trivial bypass semantics across docs | PASS after R1-04 fix |

### Round 2 Findings

**Zero genuine end-user-impacting issues remaining.**

Deferred non-issues: R1-05 (cosmetic step numbering), R1-06–R1-08 (informational).

---

## Test Results (Final)

| Suite | Result |
|-------|--------|
| `tests/integration/test-skill-refs.sh` | 80 passed, 0 failed |
| `tests/integration/test-skill-execution-paths.sh` | 374 passed, 0 failed |
| `tests/hooks/test-orchestrator-queue-order.sh` | PASS |
| `tests/hooks/test-workflow-chain-guard.sh` | PASS |
| `tests/scripts/test-silver-router-flow-contracts.sh` | PASS |
| Full `run-all-tests.sh` (incl. e2e-live) | Not run — e2e-live requires isolated Kay harness (>10 min); hooks/scripts/integration targeted run used instead |

---

## Remaining Known Limitations

None deferred for this release. E2E live harness not executed in this review cycle (environment constraint only).

---

## Release

**Version:** v0.44.3 (patch)  
**Rationale:** Flow instruction gaps that caused `workflow-chain-guard` dead-ends for UI, DevOps, and Fast Tier 2 paths.
