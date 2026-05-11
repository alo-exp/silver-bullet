# Enforcement Architecture

Silver Bullet enforces workflow compliance through 12 independent layers. No single layer can be bypassed in isolation — they compose to provide defense-in-depth.

## The 12 Layers

| # | Layer | Mechanism | Fires On | What It Prevents |
|---|-------|-----------|----------|-----------------|
| 1 | **Skill Recording** | `record-skill.sh` (PostToolUse) | Every Skill tool call | Skills invoked but not tracked |
| 2 | **Dev Cycle Gate** | `dev-cycle-check.sh` (PreToolUse) | Edit, Write, MultiEdit, Bash | Code changes before planning is complete. Uses active `.planning/workflows/<id>.md` admission control first, then legacy skill markers when no composed workflow is active. |
| 3 | **Planning File Guard** | `planning-file-guard.sh` (PreToolUse) | Edit, Write, MultiEdit | Direct edits to GSD-managed planning artifacts (ROADMAP.md, STATE.md, etc.); forces use of owning GSD skill |
| 4 | **Completion Audit** | `completion-audit.sh` (PostToolUse) | git commit/push/deploy/release | Shipping without required paths/skills. Uses `SB_WORKFLOW_ID`-matched `.planning/workflows/<id>.md` first, then legacy fallback when no composed workflow is active. |
| 5 | **CI Status Check** | `ci-status-check.sh` (PostToolUse) | git commit/push | Committing while CI is red |
| 6 | **Compliance Score** | `compliance-status.sh` (PostToolUse) | Every tool call | Silent progress — shows path progress (FLOW N/M) or skill count (legacy) |
| 7 | **Phase Archive** | `phase-archive.sh` (PreToolUse) | `gsd-tools phases clear` | Data loss on milestone clear |
| 8 | **Stop Hook** | `stop-check.sh` (Stop/SubagentStop) | Task-complete declaration | Declaring done before required planning skills are in state |
| 9 | **Prompt Recorder + Reminder** | `record-requested-skill.sh` + `prompt-reminder.sh` (UserPromptSubmit) | Every user message | Requested SB/GSD routes are recorded before the next turn; missing skills are re-injected |
| 10 | **Forbidden Skill Gate** | `forbidden-skill-check.sh` (PreToolUse/Skill) | Every Skill invocation | Deprecated/forbidden skills (`executing-plans`, `subagent-driven-development`) |
| 11 | **ROADMAP Freshness Gate** | `roadmap-freshness.sh` (PreToolUse/Bash) | git commit | Committing SUMMARY.md without ticking the corresponding ROADMAP.md checkbox |
| 12 | **Redundant Instructions** | `silver-bullet.md` + optional project instruction file (`CLAUDE.md` / `AGENTS.md`, if present) | Every session | Same rules enforced across multiple surfaces for defense-in-depth |

## Dev Cycle Gate (4-Stage)

`dev-cycle-check.sh` enforces a sequential workflow. When an active `.planning/workflows/<id>.md` exists, the dev-cycle gate requires `SB_WORKFLOW_ID` admission before non-trivial source edits. The 4-stage skill-based check is the legacy fallback for projects without a composed workflow.

| Stage | Requires | Blocks Until |
|-------|----------|-------------|
| A — Quality Gates | `quality-gates` in state | Design-phase quality review done |
| B — Planning | Planning skills in state | GSD planning complete |
| C — Code Review | `code-review` in state | Review before finalization |
| D — Finalization | All `required_deploy` skills | All required skills invoked |

## Composed-Workflow-First Enforcement Pattern

All hooks check active `.planning/workflows/<id>.md` files first, falling back to legacy skill markers when no composed workflow is active.

| Hook | Composed-Workflow Mode | Legacy Fallback |
|------|-----------------|-----------------|
| `dev-cycle-check.sh` | Active workflow exists and `SB_WORKFLOW_ID` matches before non-trivial source edits | 4-stage skill marker check |
| `completion-audit.sh` | `SB_WORKFLOW_ID`-matched workflow file shows all required flow rows complete | `required_deploy` skill list check |
| `compliance-status.sh` | Shows path progress (FLOW N/M) | Shows skill count only |
| `prompt-reminder.sh` | Includes active composed workflow IDs and current position | Omits composition context |
| `spec-floor-check.sh` | Advisory when FLOW 4 excluded from composition | Hard gate always |

Detection: hooks check for `.planning/workflows/` existence and active `.md` files. Present = composed-workflow mode, absent = legacy mode.

## Skill Classification

| List | Purpose | Enforcement |
|------|---------|-------------|
| `all_tracked` | Discovery — hooks record invocation | Observability only |
| `required_deploy` | Hard gate — must be in state before shipping | `completion-audit.sh` blocks commit/push/release |

Current `required_deploy` (canonical source: `templates/silver-bullet.config.json.default`):
`silver-quality-gates`, `code-review`, `requesting-code-review`, `receiving-code-review`,
`finishing-a-development-branch`, `silver-create-release`, `verification-before-completion`,
`test-driven-development`, `verify-tests`

Conditional skills (NOT in `required_deploy`): `accessibility-review` (UI only), `incident-response` (DevOps only)

## Pre-Release Quality Gate (4-Stage)

Before any release, 4 stages must pass in the current session:

| Stage | What | Enforcement |
|-------|------|-------------|
| 1 | Code Review Triad | Loop until zero accepted issues |
| 2 | Big-Picture Consistency Audit | Two consecutive clean passes |
| 3 | Public-Facing Content Refresh | All user surfaces current |
| 4 | Security Audit (SENTINEL) | Two consecutive clean passes |

Each stage requires explicit `/superpowers:verification-before-completion` invocation. The sidekick quality-gate file is cleared on session start — no stale markers.
The shared Claude/Codex live matrix (`tests/live/run-live-tests.sh`) and the
todo-app live E2E suite (`tests/e2e-live/run-e2e-live-tests.sh`) are additional
mandatory release prerequisites. The live todo-app suite now runs one inline
full-surface journey and must also write `matrix=inline-full-surface` to
`~/.claude/.silver-bullet/inline-e2e-matrix`. Both live markers must succeed
in the current session before `gh release create` is allowed. The stage markers
and the mandatory post-gate full-suite rerun marker live in
`~/.claude/.sidekick/quality-gate-state`. The full-suite rerun itself now runs
through `/verify-tests`, which also writes `~/.claude/.silver-bullet/verify-tests-state`
so final delivery can detect stale source changes.

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `SILVER_BULLET_STATE_FILE` | `~/.claude/.silver-bullet/state` | Override the state file path used by all hooks. Intended for testing — lets test suites point hooks at a temp file instead of the real state. Must resolve to a path inside `~/.claude/` (security guard enforced by `session-start.sh`). Paths outside `~/.claude/` are rejected and fall back to the default. |
| `SILVER_BULLET_QUALITY_GATE_STATE_FILE` | `~/.claude/.sidekick/quality-gate-state` | Override the release-quality-gate marker file used by `completion-audit.sh` and `session-start`. Intended for testing — lets test suites point hooks at a temp file instead of the real sidekick file. Must resolve to a path inside `~/.claude/` (security guard enforced by `session-start.sh`). Paths outside `~/.claude/` are rejected and fall back to the default. |
| `SILVER_BULLET_VERIFY_TESTS_STATE_FILE` | `~/.claude/.silver-bullet/verify-tests-state` | Override the test-execution freshness marker used by `completion-audit.sh`, `dev-cycle-check.sh`, `session-start`, and `/verify-tests`. Intended for testing — lets test suites point the gate at a temp file instead of the real freshness marker. Must resolve to a path inside `~/.claude/` (security guard enforced by the hooks). Paths outside `~/.claude/` are rejected and fall back to the default. |

## Bypass Detection

Silver Bullet detects and blocks:
- Out-of-order skill invocation (finalization before review)
- State file tampering (session-start validation)
- Hook skip attempts (hooks fire on every tool call, not just session start)
- Trivial-mode abuse (requires explicit user confirmation)

## Scalability

**Fixed** — this document describes structural layers that change only when enforcement architecture changes. Dual-mode hooks support both composed-workflow projects (`.planning/workflows/<id>.md`) and legacy projects (skill markers). Not append-only.
