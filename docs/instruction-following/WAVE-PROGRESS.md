# SB IF Reduction — Wave Progress

**Updated:** 2026-06-29  
**Phase 0:** COMPLETE (E0–E8, sb-doctor 16/16, plugin 0.48.6)  
**Waves 1–4:** COMPLETE  
**Evidence:** [PHASE0-PREFLIGHT-EVIDENCE.md](./PHASE0-PREFLIGHT-EVIDENCE.md) · [PLAN-EXECUTION-COMPLETE.md](./PLAN-EXECUTION-COMPLETE.md)

---

## Wave 1 — DONE (committed)

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | `instruction-ledger-gate.sh` + nested ledger schema | **done** | `hooks/lib/instruction-ledger.sh` |
| 2 | `site-regression-gate.sh` | **done** | Stop + PreToolUse `git push` |
| 3 | `live-publish-evidence-gate.sh` | **done** | push-to-main / publish Stop |
| 4 | §3c subagent Stop enforcement | **done** | `subagent-stop-enforcement.sh` |
| 5 | `silver:update` Step 9 | **done** | migrate + init update mode |
| 6 | AGENTS.md → template parity | **done** | §8.2 in templates |
| 7 | `silver-content` site batch + router | **done** | V-loop table in skill |
| 8 | Hook registration | **done** | `hooks/hooks.json`, `cursor-hooks.json` |
| 9 | `test-site-session-gates.sh` | **done** | expanded to 27/27 |

---

## Wave 2 — DONE

| Item | Status | Files |
|------|--------|-------|
| `v-loop-rollup-gate.sh` | **done** | `hooks/v-loop-rollup-gate.sh`, `hooks/lib/site-session.sh` |
| `site-visual-evidence-gate.sh` + recorder | **done** | `site-visual-evidence-gate.sh`, `record-site-visual-evidence.sh` |
| Catalog→runtime gap doc | **done** | [VLOOP-CATALOG-RUNTIME-GAP.md](./VLOOP-CATALOG-RUNTIME-GAP.md) |

---

## Wave 3 — DONE

| Item | Status | Files |
|------|--------|-------|
| Preview preflight | **done** | `hooks/site-preview-preflight.sh` |
| MCP recorders | **done** | `hooks/record-recommended-mcp.sh` (+ existing graphify/agentmemory shell recorders) |
| Chrome single-source + tokens guard | **done** | `hooks/site-chrome-guard.sh` |
| Wave 3 hook tests | **done** | `tests/hooks/test-site-session-gates.sh` (preview, chrome, MCP sections) |

---

## Wave 4 — DONE

| Item | Status | Files |
|------|--------|-------|
| Expand `test-site-session-gates.sh` | **done** | 27 tests incl. Wave 3 + chrome regression integration |
| Alpha Honesty dedupe | **done** | `site/index.html` #proof — single callout |
| Hook coverage matrix | **done** | 55/55 hooks covered (`tests/integration/coverage-matrix.sh`) |

---

## Audit closure — DONE

| Item | Status | Files |
|------|--------|-------|
| `subagentStart` worker banner | **done** | `hooks/subagent-start.sh` |
| outcomes-check worker skip | **done** | `hooks/outcomes-check.sh` |
| Per-Task completion-audit | **done** | `subagent-stop-enforcement.sh` PreToolUse/PostToolUse/beforeSubmitPrompt |
| All Task spawn logging | **done** | PreToolUse on parent (not orchestrator-only) |
| Worker template tooling | **done** | all `templates/orchestrator-workers/*.md` |

See [SB-SUBAGENT-ENGAGEMENT-AUDIT.md](./SB-SUBAGENT-ENGAGEMENT-AUDIT.md) for CLOSED table.

---

## Tests (final run — 2026-06-29)

```text
bash tests/run-all-tests.sh                          # 4818 passed, 0 failed, exit 0
bash tests/integration/coverage-matrix.sh            # 55/55 hooks covered
bash tests/hooks/test-site-session-gates.sh          # 27 passed, 0 failed
bash scripts/validate-launch-review.sh               # OK
bash scripts/validate-sentinel-skills-manifest.sh    # OK (87/87)
bash scripts/verify-tests.sh                         # OK
bash tests/scripts/test-silver-bullet-template-parity.sh  # 2 passed, 0 failed
bash scripts/sb-doctor.sh                            # 16 PASS, OVERALL PASS
bash tests/scripts/test-site-chrome-regression.sh    # 14 passed, 0 failed
```
