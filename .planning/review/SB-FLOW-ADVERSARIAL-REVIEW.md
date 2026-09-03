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

---

## Round 3 — Fresh Independent Pass (post-v0.44.3)

**Date:** 2026-06-18  
**Baseline version:** v0.44.3  
**Reviewer:** Independent adversarial subagent (re-run per user request)

### Scope

Same as Round 1 — full bird's-eye + ant's-eye across composable flows, hooks, state machine, templates, install path, cross-flow consistency.

### Findings (Round 3)

| ID | Severity | Issue | Disposition |
|----|----------|-------|-------------|
| R3-01 | **HIGH** | `silver-ui` lacked **Step 1d / mandatory `silver:spec`** when `.planning/SPEC.md` absent — `workflow-chain-guard` and orchestrator queue require `silver-spec` marker (same class as R1-01 validate dead-end) | **FIXED** — added Step 1d + mandatory chain item 5 |
| R3-02 | **MEDIUM** | `silver-ui` step body placed UI design contract **before** Plan Phase while prerequisite and hooks require plan → ui-contract | **FIXED** — reordered Step 5 Plan before FLOW DESIGN CONTRACT |
| R3-03 | **MEDIUM** | `silver-fast` Tier 2 deploy-chain doc omitted `security`, `silver:quality-gates` (pre-ship), and `silver:completion-audit` — users following doc would still hit `completion-audit` deploy gate at PR | **FIXED** — canonical post-exec chain documented |
| R3-04 | **LOW** | `silver-ui` step numbering skips Step 5 label (cosmetic; FLOW block between 4 and 6) | **DEFERRED** — no enforcement impact |
| R3-05 | **INFO** | `silver-devops` Step 8 cites `required_deploy` instead of `required_deploy_devops` for verify-tests | **DEFERRED** — verify-tests is in both lists; no gate mismatch |

### Fixes Applied (Round 3)

- `skills/silver-ui/SKILL.md` — Step 1d spec, mandatory chain, plan → ui-contract ordering
- `skills/silver-fast/SKILL.md` — full Tier 2 deploy chain documentation
- `agents/{codex,cursor,claude}/*` — re-rendered from skills source
- `tests/hooks/test-workflow-chain-guard.sh` — silver-ui conditional silver-spec
- `tests/hooks/test-orchestrator-queue-order.sh` — silver-ui queue silver-spec insertion
- `tests/integration/test-skill-execution-paths.sh` — ui spec + fast deploy-chain guards

---

## Round 4 — Skeptical Re-Review (post-fix)

Re-checked after Round 3 fixes:

| Check | Result |
|-------|--------|
| `test-skill-refs.sh` | PASS (82/82) |
| `test-skill-execution-paths.sh` | PASS (378/378) |
| `test-workflow-chain-guard.sh` | PASS (24/24) |
| `test-orchestrator-queue-order.sh` | PASS (17/17) |
| `test-silver-router-flow-contracts.sh` | PASS (58/58) |
| `test-release-version-alignment.sh` | PASS (7/7) |
| All composable flows vs `orchestrator-state.sh` queues | PASS |
| Hook `required_deploy` vs flow promises | PASS |
| Forbidden skill literals in hooks | PASS |
| silver-feature / silver-bugfix / silver-release / silver-devops validate steps | PASS — unchanged from v0.44.3 |

### Round 4 Findings

**Zero genuine end-user-impacting issues remaining.**

Deferred non-issues: R3-04 (cosmetic numbering), R3-05 (doc precision only).

---

## Test Results (Final — Round 4)

| Suite | Result |
|-------|--------|
| `tests/integration/test-skill-refs.sh` | 82 passed, 0 failed |
| `tests/integration/test-skill-execution-paths.sh` | 378 passed, 0 failed |
| `tests/hooks/test-workflow-chain-guard.sh` | 24 passed, 0 failed |
| `tests/hooks/test-orchestrator-queue-order.sh` | 17 passed, 0 failed |
| `tests/scripts/test-silver-router-flow-contracts.sh` | 58 passed, 0 failed |
| `tests/scripts/test-release-version-alignment.sh` | 7 passed, 0 failed |

---

## Release

**Version:** v0.44.4 (patch)  
**Rationale:** Greenfield UI spec dead-end and Fast Tier 2 incomplete deploy-chain documentation.

---

## Round 5 — Fresh Independent Pass (post-v0.44.4)

**Date:** 2026-06-18  
**Baseline version:** v0.44.4  
**Reviewer:** Independent adversarial subagent (re-run per user request)

### Scope

Full bird's-eye + ant's-eye across composable flows, hooks, orchestrator parent mode, worker templates, state machine, templates, install path, cross-flow consistency.

### Findings (Round 5)

| ID | Severity | Issue | Disposition |
|----|----------|-------|-------------|
| R5-01 | **CRITICAL** | Parent orchestrator missing worker templates for queue skills (`DECIDE`, `SPECIFY`, `DEVOPS-SKILL-ROUTER`, `REVIEW-REQUEST`, `REVIEW-TRIAGE`, `BRANCH-FINISH`, `COMPLETION-AUDIT`) — parent could not spawn workers for research, greenfield spec, devops router, or post-exec delivery tail | **FIXED** — added 7 templates under `templates/orchestrator-workers/` (+ plugin sync) |
| R5-02 | **HIGH** | `sb_orchestrator_flow_to_skill` mapped `devops-quality-gates` → `silver-devops-quality-gates` (invalid skill) via generic `silver-` prefix fallback | **FIXED** — explicit `devops-quality-gates` / `devops-skill-router` cases in `orchestrator-directive.sh` |
| R5-03 | **HIGH** | Worker subagents re-invoking composer skills re-seeded `orchestrator.json` / workflow tracker (queue reset mid-flow) | **FIXED** — `flow-advance.sh` skips composer re-seed in worker sessions |
| R5-04 | **MEDIUM** | `silver-devops` mandatory post-exec chain omitted review triad, branch-finish, completion-audit (deploy gate dead-end risk when following summary only) | **FIXED** — canonical post-exec list added |
| R5-05 | **MEDIUM** | `silver-bugfix` lacked mandatory dependency section documenting pre/post chains vs `workflow-chain-guard` | **FIXED** |
| R5-06 | **LOW** | `silver-devops` Step 8 cited `required_deploy` instead of `required_deploy_devops` for verify-tests | **FIXED** |
| R5-07 | **INFO** | Cosmetic step numbering gaps in `silver-ui` (unchanged from R3-04) | **DEFERRED** |

### Fixes Applied (Round 5)

- `templates/orchestrator-workers/{DECIDE,SPECIFY,DEVOPS-SKILL-ROUTER,REVIEW-REQUEST,REVIEW-TRIAGE,BRANCH-FINISH,COMPLETION-AUDIT}.md` (+ plugin copies)
- `hooks/lib/orchestrator-directive.sh` — devops skill token mapping
- `hooks/lib/orchestrator-parent.sh` — explicit worker template mappings
- `hooks/flow-advance.sh` — worker-session composer guard
- `skills/silver-devops/SKILL.md`, `skills/silver-bugfix/SKILL.md` — mandatory chains / config key
- `agents/{codex,cursor,claude}/*` — re-rendered from skills source
- `tests/hooks/test-orchestrator-worker-templates.sh` — regression coverage for queue→template resolution
- `tests/hooks/test-flow-advance.sh` — worker composer re-seed guard
- `tests/hooks/test-orchestrator-worker-handoff.sh` — devops mapping + DECIDE template asserts
- `tests/integration/test-skill-execution-paths.sh` — invoke-line ordering guards (mandatory-section false positive)

---

## Round 6 — Skeptical Re-Review (post-fix)

Re-checked after Round 5 fixes:

| Check | Result |
|-------|--------|
| `test-skill-refs.sh` | PASS (82/82) |
| `test-skill-execution-paths.sh` | PASS (378/378) |
| `test-workflow-chain-guard.sh` | PASS (24/24) |
| `test-orchestrator-queue-order.sh` | PASS (17/17) |
| `test-silver-router-flow-contracts.sh` | PASS (58/58) |
| `test-release-version-alignment.sh` | PASS (7/7) |
| `test-orchestrator-worker-templates.sh` | PASS (79/79) |
| `test-orchestrator-worker-handoff.sh` | PASS (7/7) |
| `test-flow-advance.sh` | PASS (6/6) |
| All composer queues vs worker templates | PASS |
| Hook forbidden skill literals | PASS |
| Template ↔ live sync (no instruction drift this cycle) | PASS |

### Round 6 Findings

**Zero genuine end-user-impacting issues remaining.**

Deferred non-issues: R5-07 (cosmetic numbering).

---

## Test Results (Final — Round 6)

| Suite | Result |
|-------|--------|
| `tests/integration/test-skill-refs.sh` | 82 passed, 0 failed |
| `tests/integration/test-skill-execution-paths.sh` | 378 passed, 0 failed |
| `tests/hooks/test-workflow-chain-guard.sh` | 24 passed, 0 failed |
| `tests/hooks/test-orchestrator-queue-order.sh` | 17 passed, 0 failed |
| `tests/scripts/test-silver-router-flow-contracts.sh` | 58 passed, 0 failed |
| `tests/scripts/test-release-version-alignment.sh` | 7 passed, 0 failed |
| `tests/hooks/test-orchestrator-worker-templates.sh` | 79 passed, 0 failed |
| `tests/hooks/test-orchestrator-worker-handoff.sh` | 7 passed, 0 failed |
| `tests/hooks/test-flow-advance.sh` | 6 passed, 0 failed |

---

## Release

**Version:** v0.44.5 (patch)  
**Rationale:** Parent orchestrator worker template gaps, devops queue skill mapping bug, and composer re-seed guard in worker sessions.

---

## Round 7 — Fresh Independent Pass (post-v0.44.5)

**Date:** 2026-06-18  
**Baseline version:** v0.44.5  
**Reviewer:** Independent adversarial subagent (re-run per user request)

### Scope

Full bird's-eye + ant's-eye across composable flows, hooks, orchestrator parent/worker handoff, state machine, templates, install path, cross-flow consistency. Question everything fresh — no assumption that Rounds 1–6 caught all issues.

### Findings (Round 7)

| ID | Severity | Issue | Disposition |
|----|----------|-------|-------------|
| R7-01 | **HIGH** | `silver-validate` hard-BLOCKed when `.planning/SPEC.md` absent (VAL-000), but `workflow-chain-guard` requires `silver-validate` pre-exec for `silver:devops` and `silver:fast` Tier 2 — infra/fast paths dead-ended before first implementation edit | **FIXED** — plan-only validate mode in `silver-validate`; devops/fast docs updated |
| R7-02 | **MEDIUM** | `templates/orchestrator-workers/` drifted from `plugins/silver-bullet/templates/orchestrator-workers/` (Cursor-specific "Skill tool" vs host-neutral invocation text) — dogfooding `/silver:init` could stamp host-specific worker prompts | **FIXED** — synced repo templates to plugin copies |
| R7-03 | **LOW** | No regression test for devops pre-exec chain without SPEC.md | **FIXED** — `test-workflow-chain-guard.sh` devops case |
| R7-04 | **INFO** | `silver-research` Step 3 second `silver:clarify` not in orchestrator queue — intentional parent-driven handoff after DECIDE worker | **DEFERRED** |
| R7-05 | **INFO** | Cosmetic step numbering gaps in `silver-ui` (unchanged) | **DEFERRED** |

### Fixes Applied (Round 7)

- `skills/silver-validate/SKILL.md` — plan-only mode (SPEC absent + PLAN present)
- `skills/silver-devops/SKILL.md`, `skills/silver-fast/SKILL.md` — plan-only cross-refs
- `templates/orchestrator-workers/*` — synced to plugin host-neutral wording
- `agents/{codex,cursor,claude}/*` — re-rendered from skills source
- `tests/hooks/test-workflow-chain-guard.sh` — devops without SPEC
- `tests/hooks/test-orchestrator-worker-templates.sh` — repo/plugin template parity
- `tests/integration/test-skill-execution-paths.sh` — plan-only validate guards

---

## Round 8 — Skeptical Re-Review (post-fix)

Re-checked after Round 7 fixes:

| Check | Result |
|-------|--------|
| `test-skill-refs.sh` | PASS (82/82) |
| `test-skill-execution-paths.sh` | PASS (381/381) |
| `test-workflow-chain-guard.sh` | PASS (26/26) |
| `test-orchestrator-queue-order.sh` | PASS (17/17) |
| `test-orchestrator-worker-templates.sh` | PASS (106/106) |
| `test-orchestrator-worker-handoff.sh` | PASS (7/7) |
| `test-flow-advance.sh` | PASS (6/6) |
| `test-silver-router-flow-contracts.sh` | PASS (58/58) |
| `test-release-version-alignment.sh` | PASS (7/7) |
| All composer queues vs worker templates + parity | PASS |
| Hook forbidden skill literals | PASS |
| Devops/fast validate without SPEC path | PASS |

### Round 8 Findings

**Zero genuine end-user-impacting issues remaining.**

---

## Round 9 — Skeptical Re-Review

Independent second clean pass — re-read orchestrator queues, chain-guard markers, mandatory dependency sections, init/migrate template copy paths, and router contracts.

### Round 9 Findings

**Zero genuine end-user-impacting issues remaining.**

Deferred non-issues: R7-04, R7-05.

---

## Round 10 — Final Skeptical Re-Review

Third consecutive clean pass — full ant's-eye re-check of composable flow SKILL.md step ordering vs hooks; no new dead-ends or contradictions found.

### Round 10 Findings

**Zero genuine end-user-impacting issues remaining.**

---

## Test Results (Final — Round 10)

| Suite | Result |
|-------|--------|
| `tests/integration/test-skill-refs.sh` | 82 passed, 0 failed |
| `tests/integration/test-skill-execution-paths.sh` | 381 passed, 0 failed |
| `tests/hooks/test-workflow-chain-guard.sh` | 26 passed, 0 failed |
| `tests/hooks/test-orchestrator-queue-order.sh` | 17 passed, 0 failed |
| `tests/hooks/test-orchestrator-worker-templates.sh` | 106 passed, 0 failed |
| `tests/hooks/test-orchestrator-worker-handoff.sh` | 7 passed, 0 failed |
| `tests/hooks/test-flow-advance.sh` | 6 passed, 0 failed |
| `tests/scripts/test-silver-router-flow-contracts.sh` | 58 passed, 0 failed |
| `tests/scripts/test-release-version-alignment.sh` | 7 passed, 0 failed |

---

## Release

**Version:** v0.44.6 (patch)  
**Rationale:** Plan-only validate mode unblocks DevOps and Fast Tier 2 paths without SPEC.md; orchestrator worker template parity restored.
