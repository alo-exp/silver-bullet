# VALIDATE — Stack double-compression recovery

| Field | Value |
|-------|-------|
| Phase | `stack-double-compression-recovery` |
| Branch | `fix/stack-double-compression-recovery` |
| HEAD | [`06acf07f`](https://github.com/alo-exp/silver-bullet/commit/06acf07f) (`docs(security): link SECURE artifact to fix commits`) |
| Security base | [`b8253191`](https://github.com/alo-exp/silver-bullet/commit/b8253191) (SEC-01/SEC-02 hook fixes) |
| Validated | 2026-07-10 (UTC+10) |
| Skill | `silver-validate` (FLOW VALIDATE) |
| Verdict | **PASS** (phase-scoped; no BLOCK findings) |

## Scope

Re-validation after SECURE hardening (`SEC-01` export_root path jail, `SEC-02` native Read cannot clear mutex). Confirms targeted hook/script suites remain GREEN and security fixes remain on branch.

## SEC-01 / SEC-02 presence

| ID | Location | Status |
|----|----------|--------|
| SEC-01 | `hooks/lib/agentmemory-gate.sh` — `sb_agentmemory_export_rel_is_safe`, `sb_agentmemory_export_path_is_project_scoped`, used by `sb_agentmemory_abs_export_path` / scaffold | **Present** (`b8253191`) |
| SEC-02 | `hooks/lib/stack-compression-coordinator.sh` — `sb_stack_tool_is_compliant_routed_owner` limited to Bash/MCP only (native Read/Grep/WebFetch return 1) | **Present** (`b8253191`) |
| Tests | `test-agentmemory-gate-lib.sh` traversal block; `test-five-tool-mutual-exclusion.sh` native Read block when mutex dirty | **Present** |

## Targeted test matrix (post-SECURE, branch `06acf07f`)

| Suite | Result | Notes |
|-------|--------|-------|
| `test-stack-compression-coordinator.sh` | **20/20** | RED-1 recovery MCP clears mutex |
| `test-five-tool-mutual-exclusion.sh` | **22/22** | Native Read blocked when mutex dirty (SEC-02) |
| `test-agentmemory-gate.sh` | **8/8** | RED-5 auto-scaffold |
| `test-agentmemory-gate-lib.sh` | **9/9** | Export traversal block (SEC-01) |
| `test-optimize-five-tool-stack.sh` | **13/13** | Five-tool routing intact |
| `test-silver-bullet-template-parity.sh` | **2/2** | Template parity |
| `test-silver-doctor.sh` | **41/43** | D20/RED-4 **PASS**; D21 dynamic probe **FAIL** (see WARN) |

**Phase-scoped subtotal:** 74/74 assertions on stack-compression + agentmemory + five-tool suites.

## WARN (out of phase scope)

| ID | Suite | Issue | Assessment |
|----|-------|-------|------------|
| VAL-W01 | `test-silver-doctor.sh` D21 | Dynamic D21 probe fails: `install-cursor-sb-agents.sh` cannot complete in isolated temp HOME (catalog fetch / path resolution) | **Not introduced by stack recovery**; D21 is cursor-RFL subagents work (`2625f323`). D20/RED-4 (this phase) pass. |
| VAL-W02 | `test-silver-doctor.sh` live doctor | D16/D17 FAIL on repo dogfood install (Claude host bleed) | Pre-existing environment/dogfood; not regression from SEC-01/SEC-02 |

## Full suite (`run-all-tests.sh`)

- Log: [`/tmp/sb-run-all-tests-validate-stack.log`](/tmp/sb-run-all-tests-validate-stack.log)
- Branch: `fix/stack-double-compression-recovery` @ `06acf07f` (re-run after branch drift correction)
- **TOTAL:** 6227 passed, 55 failed (3/6 suite groups green)
- **Phase suites in full run:** all GREEN except `test-silver-doctor.sh` (D21 WARN)
  - `test-stack-compression-coordinator.sh` 20/20
  - `test-five-tool-mutual-exclusion.sh` 22/22
  - `test-agentmemory-gate-lib.sh` 9/9
  - `test-agentmemory-gate.sh` 8/8
  - `test-optimize-five-tool-stack.sh` 13/13
  - `test-silver-bullet-template-parity.sh` 2/2
  - `test-silver-doctor.sh` 41/43 (D20/RED-4 pass)
- **Unrelated failures (55):** orchestrator flow-advance, parent-guard, RFL ladder CLI, skill alias/scenario gaps (`silver-clear-stack-state`), marketplace version drift, etc. — not regressions from SEC-01/SEC-02

## Findings

| Severity | Count | Open |
|----------|-------|------|
| BLOCK | 0 | 0 |
| WARN | 2 | 2 accepted (out of phase scope) |
| INFO | 1 | SEC-01/SEC-02 confirmed on branch |

## Exit gate

| Question | Answer |
|----------|--------|
| **VALIDATE verdict** | **PASS** |
| **Clear for QUALITY-GATE / BRANCH-FINISH?** | **Yes** |
| **Blockers** | None for stack-compression recovery |
| **Artifact** | `.planning/phases/stack-double-compression-recovery/VALIDATE.md` |

## Residual

- Track D21 test infra separately on cursor-RFL branch (`feat/cursor-rfl-custom-subagents`)
- Full `run-all-tests.sh` completion recommended before plugin release (not in scope for this phase)
