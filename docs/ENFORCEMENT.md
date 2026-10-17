# Enforcement Architecture

Silver Bullet enforces workflow compliance through twelve independent layers. No single layer can be bypassed in isolation — they compose to provide defense-in-depth. The same twelve layers appear in the README and in `silver-bullet.md` §1; [HOOKS.md](HOOKS.md) lists every registered hook, including the gates beside these layers.

## The 12 Layers

| # | Layer | Mechanism | Fires on | What it prevents |
|---|-------|-----------|----------|------------------|
| 1 | **Skill recording** | `record-skill.sh` (PostToolUse `Skill\|Bash\|exec_command`) | Host Skill tool calls; Codex `silver-bullet invoke-skill` receipts | Skills invoked through a supported channel but not tracked |
| 2 | **Planning-floor gate** | `dev-cycle-check.sh` (Pre+PostToolUse), `workflow-chain-guard.sh` (PreToolUse) | Edit, Write, MultiEdit, `apply_patch`, shell commands | Source edits before planning is complete. Uses active `.planning/workflows/<id>.md` admission first, then skill markers when no composed workflow is active |
| 3 | **Compliance status** | `compliance-status.sh` (PostToolUse `.*`) | Every tool call | Silent progress — shows flow progress (FLOW N/M) or recorded-skill count. Informational only |
| 4 | **Planning file guard** | `planning-file-guard.sh` (PreToolUse) | Edit, Write, MultiEdit, `apply_patch` | Direct edits to SB-managed planning artifacts (`ROADMAP.md`, `STATE.md`, phase plans and summaries); forces the owning SB workflow |
| 5 | **Completion audit** | `completion-audit.sh` (PreToolUse and PostToolUse) | `git commit`, `git push`, commit plumbing; `gh pr create/merge`, deploy, `gh release create` | Commits without the planning floor; delivery without the full workflow (two-tier model below) |
| 6 | **CI status check** | `ci-status-check.sh` (PreToolUse and PostToolUse) | `git push`, `gh pr create/merge`, `gh release create`; `git commit` (post only) | Pushing, opening or merging PRs, or releasing while the latest CI run failed. After a commit it only warns |
| 7 | **Session management** | `session-start` (SessionStart), `session-log-init.sh`, `timeout-check.sh` (PostToolUse) | Session start, compaction, every tool call | Stale state across branches and worktrees, missing session logs, runaway autonomous sessions |
| 8 | **Stop gates** | `stop-check.sh` with `outcomes-check.sh`, `instruction-ledger-gate.sh`, `subagent-stop-enforcement.sh` and the site gates (Stop/SubagentStop) | Task-complete declaration | Declaring done while the planning floor, outcomes, ledger items or worker audits are open |
| 9 | **Prompt recorder + reminder** | `record-requested-skill.sh` + `prompt-reminder.sh` (UserPromptSubmit) | Every user message | Requested SB routes are recorded before the next turn; missing steps are re-injected |
| 10 | **Forbidden skill gate** | `forbidden-skill-check.sh` (PreToolUse `Skill`) | Every Skill invocation | Deprecated or forbidden skills (`executing-plans`, `subagent-driven-development`, plus `skills.forbidden`) |
| 11 | **ROADMAP freshness gate** | `roadmap-freshness.sh` (PreToolUse shell) | `git commit` | Committing a phase `SUMMARY.md` without ticking the matching `ROADMAP.md` checkbox |
| 12 | **Redundant instructions** | `silver-bullet.md`, workflow docs and the optional project instruction file (`CLAUDE.md` / `AGENTS.md`) | Every session | Same rules stated on every instruction surface for defense-in-depth |

`record-skill.sh` searches every candidate receipt directory from `sb_runtime_skill_receipt_dirs()` (Claude and Codex homes). Codex adapter receipts land under `~/.codex/.silver-bullet/skill-invocations`; repo-source hooks must not assume the Claude runtime when `CLAUDE_PLUGIN_ROOT` resolves under `/.codex/`.

Beside the twelve layers run further gates: the spec floor (`spec-floor-check.sh`) and UAT gate (`uat-gate.sh`), `phase-archive.sh` and the phase locks, orchestrator parent-mode guards (`orchestrator-directive-guard.sh`, `agent-delegation-guard.sh`), site-session gates, and the opt-in gates for Graphify, agentmemory, RTK, Context Mode, LeanCTX and Alumnium. `hooks/core-rules.md`, which `session-start` injects, counts four of the opt-in gates as layers 13–16.

## Planning-Floor Gate

`dev-cycle-check.sh` enforces pre-execution readiness. When an active `.planning/workflows/<id>.md` exists, the gate requires `SB_WORKFLOW_ID` admission before non-trivial source edits. The skill-based check is the legacy fallback for projects without a composed workflow.

| Stage | Requires | Blocks until |
|-------|----------|--------------|
| A — Planning floor | `required_planning` skills in state | SB pre-execution gates complete |
| B — Implementation window | Planning floor complete | Source edits are allowed; review/verify/ship remain final-delivery gates |
| C — Review recorded | `silver-review` in state | Source edits still allowed; finalization remains gated |
| D — Finalization | All `required_deploy` skills plus expected SB artifacts | Final delivery commands allowed |

The same hook also hard-blocks edits under the host plugin cache (`${SB_RUNTIME_HOME_ROOT}/plugins/cache/`) and direct writes to SB state files.

## Two-Tier Model

Silver Bullet enforces two **distinct** tiers:

| Tier | Trigger | Hook | Requires |
|------|---------|------|----------|
| **Planning floor** | `git commit`, `git push`, commit plumbing (`write-tree`, `commit-tree`, `hash-object -w`, `update-ref refs/heads/*`) | `completion-audit.sh` | `required_planning` skills in state |
| **Planning floor** | Task-complete declaration (Stop/SubagentStop) | `stop-check.sh` | `required_planning` skills in state |
| **Final delivery** | `gh pr create`, `gh pr merge`, a command whose first line contains `deploy`, `gh release create` | `completion-audit.sh` | All `required_deploy` skills + expected artifacts; for `gh release create` also `required_release` and the release gates below |

`stop-check.sh` blocks **only** on the `required_planning` floor — it does **not** require the full `required_deploy` list. This is intentional (v0.30.0 #85): an agent may legitimately end a session mid-implementation as long as the planning floor is recorded. The full `required_deploy` list is enforced by `completion-audit.sh` when an actual delivery command runs. Intermediate commits and pushes need only the planning floor, so execution subagents can commit atomically mid-execution. `hooks/core-rules.md` and `silver-bullet.md` describe the same split — keep all three in sync.

In the `devops-cycle` workflow the `_devops` variants (`required_planning_devops`, `required_deploy_devops`, `required_release_devops`) apply.

### Orchestrator Worker SubagentStop

In orchestrator parent mode, the parent session spawns Task **workers**, each executing one atomic flow. Stop/SubagentStop handling differs by role:

- **Worker (`SB_ORCHESTRATOR_WORKER=1`) on `SubagentStop`:** `stop-check.sh` clears the worker marker and exits 0. Workers are **not** individually subjected to the planning-floor or delivery gates — they perform a single flow and return to the parent. Enforcement is the parent's responsibility.
- **Parent on `Stop` with a pending flow queue:** `stop-check.sh` blocks and instructs the parent to spawn the next Task worker for the next flow before ending the session. The parent cannot declare the composition complete while flows remain queued.

This division means the planning-floor and delivery gates are enforced **once, at the parent level**, against the cumulative state the workers contributed — never redundantly on each worker SubagentStop.

## CI Status Gate

`ci-status-check.sh` reads the latest GitHub Actions run for the current branch (`gh run list`); without `gh` it exits quietly.

| Event | Commands | When CI failed or was cancelled |
|-------|----------|---------------------------------|
| PreToolUse | `git push`, `gh pr create`, `gh pr merge`, `gh release create` | Denied |
| PostToolUse | `git commit` | Warning only (the commit already happened; blocking would deadlock CI fixes) |
| PostToolUse | `git push`, `gh pr create/merge`, `gh release create` | Block message |

A `git push` is let through when the latest commit message starts with `fix(ci):` or `ci:` or contains `[ci-fix]`, or when the pushed diff touches `.github/workflows/`, `tests/` or `package.json`. The flag file `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/ci-red-override` disables the gate entirely. Runs that are in progress are informational. Deploy commands are not checked by this hook; `completion-audit.sh` separately requires the release commit to be green before `gh release create`.

## Composed-Workflow-First Enforcement Pattern

All hooks check active `.planning/workflows/<id>.md` files first, falling back to legacy skill markers when no composed workflow is active.

| Hook | Composed-workflow mode | Legacy fallback |
|------|------------------------|-----------------|
| `dev-cycle-check.sh` | Active workflow exists and `SB_WORKFLOW_ID` matches before non-trivial source edits | 4-stage skill marker check |
| `completion-audit.sh` | `SB_WORKFLOW_ID`-matched workflow file shows all required flow rows complete | `required_deploy` skill list check |
| `compliance-status.sh` | Shows path progress (FLOW N/M) | Shows skill count only |
| `prompt-reminder.sh` | Includes active composed workflow IDs and current position | Omits composition context |
| `spec-floor-check.sh` | Advisory when FLOW 5 excluded from composition | Hard gate always |

Detection: hooks check for `.planning/workflows/` existence and active `.md` files. Present = composed-workflow mode, absent = legacy mode.

## Skill Classification

| List | Purpose | Enforcement |
|------|---------|-------------|
| `all_tracked` | Discovery — hooks record invocation | Observability only |
| `required_planning` | Planning floor | `dev-cycle-check.sh` blocks source edits; `completion-audit.sh` blocks commits and pushes; `stop-check.sh` blocks Stop |
| `required_deploy` | Final delivery floor | `completion-audit.sh` blocks `gh pr create/merge`, deploy and `gh release create` |
| `required_release` | Release-only additions (default `silver-create-release`) | `completion-audit.sh` on `gh release create` |

Current `required_deploy` (canonical source: `templates/silver-bullet.config.json.default`) includes SB quality gates, SB lifecycle markers (`silver-context`, `silver-plan`, `silver-execute`, `silver-verify`, `silver-ship`, review/security/validation), review framing, finalization, completion audit, TDD where applicable, and `verify-tests`. Legacy GSD/Superpowers marker names are accepted only as compatibility aliases during migration. [CONFIGURATION.md](CONFIGURATION.md) describes every list.

Conditional skills (NOT in `required_deploy`): `accessibility-review` (UI only), `incident-response` (DevOps only)

## Enterprise Policy Delivery Block

Before the delivery floor, `completion-audit.sh` applies the enterprise policy (`hooks/lib/enterprise-policy.sh`). When the active profile's `production_deploy_requires_human` is true — as in every shipped profile, and by default when no profile is configured — `gh pr create`, `gh pr merge`, `gh release create` and deploy commands are blocked with `ENTERPRISE POLICY BLOCK` until a human creates `${SB_RUNTIME_STATE_DIR}/enterprise-human-deploy-approved` from their own terminal. Agents must not create that marker. A profile with `non_production_deploy_autonomy: true` (the shipped `internal_dogfood`) exempts commands that name a non-production target (staging, preview, non-prod, sandbox, dogfood, internal). `SB_ENTERPRISE_HUMAN_DEPLOY_APPROVAL=1` exists for audited automation tests only. See [CONFIGURATION.md](CONFIGURATION.md#enterprise_policy).

## Release Gates

On `gh release create`, `completion-audit.sh` adds the release gates the project config enables (`release.require_*`, all `true` in the template):

- **Plugin runtime matrix** (`require_plugin_runtime_matrix`) — matching `matrix=` markers from `scripts/run-release-live-matrix.sh`, `tests/e2e-live/run-e2e-live-tests.sh` and the enterprise inline journey in the runtime state dir.
- **Pre-release quality gate** (`require_pre_release_quality_gate`) — the markers `adversarial-review-clean`, `sentinel-skills-clean`, `quality-gate-stage-3` and `full-test-suite-rerun` in the quality-gate state file, plus `scripts/validate-launch-review.sh` and `scripts/validate-sentinel-skills-manifest.sh` when present.
- **RC validation matrix** (`require_rc_matrix`) — the six operator-local markers written by `scripts/run-rc-validation-matrix.sh`.
- **Green CI** on the release commit (always).

The stages behind these markers, and the order to run them in, are described in [RELEASE.md](RELEASE.md). The quality-gate state file is cleared on session start, so markers cannot carry over from an earlier session. The full-suite rerun runs through `verify-tests`, which also writes `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/verify-tests-state` so final delivery can detect stale source changes.

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `SILVER_BULLET_STATE_FILE` | `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/state` | Override the state file path used by all hooks. Intended for testing — lets test suites point hooks at a temp file instead of the real state. Must resolve to a path inside `${SB_RUNTIME_HOME_ROOT}/` (security guard enforced by `hooks/session-start`). Paths outside `${SB_RUNTIME_HOME_ROOT}/` are rejected and fall back to the default. |
| `SILVER_BULLET_QUALITY_GATE_STATE_FILE` | `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/quality-gate-state` | Override the release-quality-gate marker file used by `completion-audit.sh` and `session-start`. Intended for testing. Must resolve to a path inside `${SB_RUNTIME_HOME_ROOT}/` (security guard enforced by `session-start`); other paths fall back to the default. |
| `SILVER_BULLET_VERIFY_TESTS_STATE_FILE` | `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/verify-tests-state` | Override the test-execution freshness marker used by `completion-audit.sh`, `dev-cycle-check.sh`, `session-start`, and `/verify-tests`. Intended for testing. Must resolve to a path inside `${SB_RUNTIME_HOME_ROOT}/` (security guard enforced by the hooks); other paths fall back to the default. |

## Bypass Detection

Silver Bullet detects and blocks:
- Out-of-order skill invocation (finalization before review)
- State file tampering (direct writes to state files are blocked by `dev-cycle-check.sh`; `session-start` validates paths)
- Hook skip attempts (hooks fire on every tool call, not just session start)
- Trivial-mode abuse (agents cannot create the legacy trivial marker — `trivial-file-guard.sh` — and `session-start` deletes stale markers)

The audited escape hatch for orchestrator directives is `SB OVERRIDE: <reason>` in a user message; it is logged to `.planning/orchestrator-override-log.jsonl`.

## Scalability

**Fixed** — this document describes structural layers that change only when enforcement architecture changes. Dual-mode hooks support both composed-workflow projects (`.planning/workflows/<id>.md`) and legacy projects (skill markers). Not append-only.
