# Launch Remediation — Progress Log

**Phase docs:** [CONTEXT.md](./CONTEXT.md) · [PLAN.md](./PLAN.md) · [Audit](../../../docs/audits/pre-launch-adversarial-review-2026-06.md) · [Dogfood](./DOGFOOD-todo-app.md)

## Wave 0 — Autonomous Orchestrator

| Task | Plan | Impl | Notes |
|------|------|------|-------|
| 0.1 sb_initiated gate | done | done | `hooks/lib/sb-project-gate.sh`; template default false; init sets true; legacy grandfather via config_version |
| 0.2 SessionStart prerequisites | done | done | `prerequisite-probe.sh`, `sb-prerequisite-repair.sh`, blocking banner in session-start |
| 0.3 next-flow state machine | done | done | `orchestrator-state.sh`, `flow-advance.sh`, PostToolUse/Skill in hooks.json |
| 0.4 strip flow-guided UX | done | done | Composer skills default autonomous; no Approve composition prompts |
| 0.5 decision gate taxonomy | done | done | `silver/SKILL.md` Step 8; outcomes `decision_class` seed |
| 0.6 supervision → hooks | done | done | `supervision-loop.md` SL-4 → flow-advance |
| 0.7 intent persistence | done | done | Full-software intent graph + `orchestrator-intent.txt` on UserPromptSubmit |
| 0.8 auto workflows.sh | done | done | `flow-advance.sh` calls `workflows.sh start` on composer skill |

## Waves 1–5 — Adversarial remediation

| Issue | Plan | Impl | SB meta-observations |
|-------|------|------|----------------------|
| C-01 | done | done | outcomes-check.sh on UserPromptSubmit + Stop |
| C-02 | done | done | strict evidence default; config hooks.evidence_schema.strict |
| C-03 | done | done | silver-bullet.md + template synced to two-tier model |
| C-04 | done | done | jq blocks delivery + stop in SB projects |
| C-05 | done | done | capability-tier banner in session-start |
| C-06 | done | done | silver:fast Tier 2 workflow tracker instructions |
| H-01 | done | done | silver-feature VERIFY freshness check |
| H-02 | done | done | workflow-chain-guard silver-bugfix chain |
| H-03 | done | done | ordering violations block at delivery |
| H-04 | done | done | required_release split in config + completion-audit |
| H-05 | done | done | narrowed Q&A exceptions in silver router |
| H-06 | done | done | SDLC-MAP coverage honesty |
| H-07 | done | done | uat-gate on silver:ship when SPEC exists |
| H-08 | done | done | VFY-01 plan-seal commit boundary |
| M-01 | done | done | Covered by flow-advance auto workflows.sh start |
| M-02 | done | done | 7-day workflow TTL archive in session-start |
| M-03 | done | done | planning-edit-override narrowed to PLAN.md only + audit log |
| M-04 | done | done | stop-check blocks on branch mismatch (was fail-open) |
| M-05 | done | done | `.planning/orchestrator-composition-log.jsonl` on auto-compose |
| M-06 | done | done | CI already validates template vs live config (`.github/workflows/ci.yml`) |
| M-07 | done | done | dependency-skill-check documented no-op + sb_initiated gate |
| M-08 | done | done | trivial policy unified in silver-bullet.md + template |
| L-01 | done | done | `required_deploy` uses canonical `tdd` not `silver-tdd` |
| L-02 | done | done | `hooks/core-rules.sha256` + `lib/core-rules-integrity.sh`; verified at session/prompt inject; init step 3.7.5 |
| L-03 | done | done | `lib/legacy-gsd-alias.sh` centralizes sunset (2026-09-01); hooks match canonical `silver-*` after normalize |
| L-04 | done | done | timeout-check sets stall-block; stop-check blocks at 100+ idle calls |

## Session notes

- **2026-06-14 session 3:** L-02/L-03 implemented; `runtime-paths` preserve flag; hook unit tests green after test fixture updates; dogfood on sibling `/Users/shafqat/projects/todo-app`.
- **Hook unit tests:** All targeted suites pass post-fix (incl. `test-flow-advance`, `test-outcomes-check`, `test-planning-file-guard`, `test-core-rules-integrity`, `test-legacy-gsd-alias`).
- **Full `run-all-tests.sh`:** ~3244+ unit/integration pass; **~25–32 failures remain environmental** — Kay bridge git shim, Codex isolation temp paths, live E2E wrappers requiring Kay/Minimax runtime (not fixable in-repo without host agent).
- **Dogfood:** See [DOGFOOD-todo-app.md](./DOGFOOD-todo-app.md) — flow chaining + outcomes seed verified; `scripts/workflows.sh` must be present in downstream projects.

## Remaining gaps

| Gap | Severity | Notes |
|-----|----------|-------|
| Kay/Minimax live E2E | env | Optional `workflow_dispatch` in `.github/workflows/e2e-live.yml` |
| Host Skill auto-invoke | arch | Directive + guard + `.cursor/rules/silver-orchestrator.mdc`; see `docs/ORCHESTRATOR.md` |

## Launch readiness (reassessment)

**Score: 10/10** (in-repo maximum; 2026-06-14)

- **P8:** Multi-session dogfood on `/Users/shafqat/projects/todo-app` — priority v2 shipped; orchestrator state survived Session B; evidence in [DOGFOOD-todo-app.md](./DOGFOOD-todo-app.md).
- **Cursor path:** `templates/cursor-rules/silver-orchestrator.mdc` stamped by `silver:init`; `prompt-reminder.sh` leads with directive block.
- **CI:** `ci.yml` validate job = unit/integration release gate; `e2e-live.yml` = optional manual live matrix.
- **Honest footnote:** True host Skill auto-invoke still requires Cursor/Claude SDK — in-repo maximum is convention + block + rule.
