# SB IF Reduction — Wave Progress

**Updated:** 2026-06-28  
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
| 9 | `test-site-session-gates.sh` | **done** | expanded to 20/20 |

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

---

## Wave 4 — DONE

| Item | Status | Files |
|------|--------|-------|
| Expand `test-site-session-gates.sh` | **done** | 20 tests incl. chrome regression integration |
| Alpha Honesty dedupe | **done** | `site/index.html` #proof — single callout |

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

## Tests (final run)

```text
bash tests/hooks/test-site-session-gates.sh          # 20 passed, 0 failed
bash tests/scripts/test-silver-bullet-template-parity.sh  # 2 passed, 0 failed
bash scripts/sb-doctor.sh                          # 16 PASS, OVERALL PASS
bash tests/scripts/test-silver-doctor.sh           # 22 passed, 0 failed
bash tests/scripts/test-site-chrome-regression.sh  # 14 passed, 0 failed
```
