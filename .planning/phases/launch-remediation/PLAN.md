---
phase: launch-remediation
plan: 01
type: implementation
autonomous: true
wave: 1
requirements:
  - C-01
  - C-02
  - C-03
  - C-04
  - C-05
  - C-06
  - H-01
  - H-02
  - H-03
  - H-04
  - H-05
  - H-06
  - H-07
  - H-08
---

# Launch Remediation — Master Plan

## Objective

Close pre-launch adversarial review findings C-01–C-06, H-01–H-08, then M-01–M-08 and L-01–L-04; then align runtime with **Autonomous Orchestration Vision** (CONTEXT.md locked section).

## Waves

### Wave 0 — Autonomous Orchestrator (design epic)

**Prerequisite for:** marketing SB as autonomous lifecycle engine (vision 2026-06-14).  
**Does not block:** Waves 1–5 (adversarial remediation) — those close honesty and bypass holes first.

| Task | Vision # | Deliverable | Files / surfaces |
|------|----------|-------------|------------------|
| 0.1 | 7 | `sb_initiated: true` in `.silver-bullet.json`; set only by `silver:init`; `session-start` + all gates exit 0 when absent or false | `templates/silver-bullet.config.json.default`, `hooks/session-start`, `hooks/lib/required-skills.sh`, `skills/silver-init/SKILL.md` |
| 0.2 | 6 | SessionStart prerequisite probe: jq, plugin cache presence, host hooks merged; auto-run repair script or inject blocking banner + `silver:init` replay | `hooks/session-start`, new `hooks/lib/prerequisite-probe.sh`, `scripts/sb-prerequisite-repair.sh` |
| 0.3 | 4 | **Next-flow state machine** — persist `active_intent`, `flow_queue`, `current_flow` in `${SB_RUNTIME_STATE_DIR}/orchestrator.json`; advance on `PostToolUse/Skill` when composer skill completes a flow atom | `hooks/record-skill.sh` or new `hooks/flow-advance.sh`, `hooks/hooks.json`, `hooks/lib/orchestrator-state.sh` |
| 0.4 | 1, 3 | Strip flow-guided UX from composer skills — remove composition Y/n, step banners; orchestrator emits single status line | `skills/silver-feature/SKILL.md`, `silver-ui`, `silver-devops`, `silver-bugfix`, `templates` sync |
| 0.5 | 2 | **Decision gate taxonomy** — `blocking` vs `autonomous_default` in clarify/spec; router invokes clarify only when `decision_class: blocking` | `skills/silver/SKILL.md`, `skills/silver-clarify/SKILL.md`, `hooks/outcomes-check.sh` seed rules |
| 0.6 | 4 | Wire supervision loop to hooks — SL-4 advance calls flow-advance, not inline agent logic | `skills/silver-feature/references/supervision-loop.md`, hook integration tests |
| 0.7 | 5 | Intent persistence — seed `intent_graph` from first prompt; auto-chain `silver:spec` → `silver:feature` → `silver:ship` → `silver:release` across sessions via orchestrator queue | `hooks/lib/orchestrator-state.sh`, `skills/silver/SKILL.md` Step 7 |
| 0.8 | 4, 5 | Auto `workflows.sh start` on composer route (M-01) — hook or orchestrator, not agent bash | `hooks/flow-advance.sh`, `scripts/workflows.sh` |

**Acceptance:**

- [ ] Opening arbitrary repo without `sb_initiated` produces no SB enforcement or context injection.
- [ ] SessionStart on SB-initiated project with missing jq attempts repair or blocks with actionable message (not warn-only).
- [ ] Completing a flow atom in `silver:feature` triggers next queued flow without agent choosing it (integration test with mocked skill completion).
- [ ] Composer skills contain no `Approve composition?` or per-step user prompts in autonomous default mode.
- [ ] Full-software intent ("build me X app") produces multi-session queue visible in `orchestrator.json`.

**Gap analysis reference:** CONTEXT.md § Autonomous Orchestration Vision; audit § Post-Review Design Direction.

### Wave 1 — Docs truth + config schema (C-03, H-06)

| Task | Issue | Files |
|------|-------|-------|
| 1.1 | C-03 | `silver-bullet.md`, `templates/silver-bullet.md.base` — two-tier Stop vs delivery |
| 1.2 | H-06 | `docs/SDLC-MAP.md` — enforcement column honesty |

**Acceptance:** Stop hook description matches `stop-check.sh`; SDLC map distinguishes skill-available vs hook-required.

### Wave 2 — jq + capability tier (C-04, C-05)

| Task | Issue | Files |
|------|-------|-------|
| 2.1 | C-04 | `hooks/lib/jq-gate.sh`; wire into `completion-audit.sh`, `stop-check.sh` |
| 2.2 | C-05 | `hooks/lib/capability-tier.sh`; `session-start` banner |

**Acceptance:** PR/release blocked without jq; session injects tier when hooks absent.

### Wave 3 — Outcomes + substance (C-01, C-02)

| Task | Issue | Files |
|------|-------|-------|
| 3.1 | C-01 | `hooks/outcomes-check.sh`, `hooks/lib/outcomes-gate.sh`, `hooks/hooks.json` |
| 3.2 | C-02 | `completion-audit.sh` strict evidence default; config key |

**Acceptance:** Stop blocks incomplete outcomes on non-trivial sessions; delivery blocks hollow finding tables.

### Wave 4 — Workflow bypass seals (C-06, H-01, H-02)

| Task | Issue | Files |
|------|-------|-------|
| 4.1 | C-06 | `skills/silver-fast/SKILL.md` — workflow tracker Tier 2+ |
| 4.2 | H-01 | `skills/silver-feature/SKILL.md` — VERIFY freshness |
| 4.3 | H-02 | `hooks/workflow-chain-guard.sh` — silver-bugfix chain |

### Wave 5 — Delivery gates (H-03, H-04, H-07, H-08)

| Task | Issue | Files |
|------|-------|-------|
| 5.1 | H-03 | `completion-audit.sh` — ordering blocks |
| 5.2 | H-04 | `templates/silver-bullet.config.json.default`, `hooks/lib/required-skills.sh`, `.silver-bullet.json` |
| 5.3 | H-07 | `hooks/uat-gate.sh` |
| 5.4 | H-08 | `completion-audit.sh` plan-seal boundary |
| 5.5 | H-05 | `skills/silver/SKILL.md` — narrow Q&A |

### Wave 6 — MEDIUM + LOW (M-01–M-08, L-01–L-04)

Deferred to follow-on session unless capacity remains. See PROGRESS.md.

## TDD policy

- Hook/script changes: add or update tests in `tests/hooks/` before behavior change where feasible.
- Docs-only waves: `bash -n` + targeted hook tests.

## Verification

```bash
bash tests/hooks/test-completion-audit.sh
bash tests/hooks/test-stop-check.sh
bash tests/hooks/test-workflow-chain-guard.sh  # if exists
bash tests/run-all-tests.sh
```

## Success criteria

- [ ] All CRITICAL and HIGH issue IDs have implemented evidence or explicit deferral with rationale
- [ ] `silver-bullet.md` ↔ `templates/silver-bullet.md.base` in sync
- [ ] Config template authoritative for skill lists
- [ ] Full test suite passes
