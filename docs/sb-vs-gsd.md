# Silver Bullet vs GSD: Integration Guide

Silver Bullet and GSD are separate tools with distinct responsibilities that together cover
the full development lifecycle. Silver Bullet orchestrates workflows and enforces compliance
at every step. GSD is the multi-agent execution engine that runs inside those workflow steps.
Neither tool fully replaces the other — they are designed to be used together.

---

## Mental Model: Two Distinct Layers

**Silver Bullet** is the enforcement and orchestration layer. Its hooks fire on every Claude
Code tool use — every file edit, every Bash command, every skill invocation. Silver Bullet
owns quality gates, compliance state, skill sequencing, and the check that confirms each step
actually ran before the next one is permitted. It runs inside the active Claude Code session.

**GSD** is the multi-agent execution engine. It manages `.planning/` artifacts, spawns subagents
with fresh 200K-token contexts per plan, runs wave-based parallel execution across dependency
graphs, and produces atomic per-task commits. GSD prevents context rot by isolating each
execution unit in its own clean context window.

Silver Bullet calls GSD skills from within its composable workflow steps. GSD does not call
Silver Bullet skills. The direction of control is one-way: SB orchestrates, GSD executes.

The boundary: Silver Bullet owns the "what and when" — quality gates, compliance state, and
workflow sequencing. GSD owns the "how" — execution phases, plan files, wave structure, and
git commits.

---

## Feature Mapping Table

| Feature | Silver Bullet | GSD |
|---------|--------------|-----|
| Enforcement / compliance gates | `dev-cycle-check.sh`, `stop-check.sh`, `completion-audit.sh` fire on every tool use | None — GSD has no enforcement hooks |
| Workflow routing | `/silver` routes freeform instructions to the correct workflow skill | `/gsd:*` commands for specific execution tasks |
| Quality gates | `/silver-quality-gates` (9 dimensions), `/devops-quality-gates` (7 IaC dimensions) | None |
| Planning artifacts | Reads `.planning/` for position awareness but does not write planning files | ROADMAP.md, PLANS.md, STATE.md, REQUIREMENTS.md, CONTEXT.md — all GSD-owned |
| Multi-agent execution | Dispatches via Agent tool inside `silver:*` workflow steps | Wave-based parallel execution with dependency graphs and fresh 200K-token contexts per agent |
| Context rot prevention | None | Fresh 200K-token context per subagent — GSD's core value |
| Blast radius assessment | `/silver-blast-radius` — maps scope, dependencies, failure scenarios, rollback plan | None |
| Release creation | `/silver-create-release` — generates release notes and creates GitHub Release | `/gsd:ship` — phase-level merge and tag (different level; SB disambiguates at routing time) |
| Session forensics | `/silver-forensics` — investigates SB enforcement failures and session-level issues | `/gsd:forensics` — plan-drift, execution anomalies, stuck loops, missing artifacts |
| Knowledge capture | `/silver-rem` — captures insights into monthly `docs/knowledge/` or `docs/lessons/` docs | None |
| Issue filing | `/silver-add`, `/silver-remove` — GitHub Issues + project board or local `docs/issues/` | None |
| Retrospective scanning | `/silver-scan` — detects deferred items and insights from session logs | None |
| Skill recording | `record-skill.sh` tracks all skill invocations to a branch-scoped state file | Tracks GSD-specific skill usage as `gsd-*` markers in the SB state file |
| CI gate | `ci-status-check.sh` blocks push / PR / release when CI is failing | None |
| Prompt injection | `prompt-reminder.sh` re-injects missing-skill list before every user message | None |

---

## Integration Points

This table shows exactly where Silver Bullet hands off to GSD inside each composable workflow.

| Workflow | SB Step | Calls GSD | Notes |
|----------|---------|-----------|-------|
| `silver:feature` | Discussion phase | `/gsd:discuss-phase` | Captures requirements as CONTEXT.md |
| `silver:feature` | Quality gate (pre-plan) | `/silver-quality-gates` | SB gate runs before GSD planning begins |
| `silver:feature` | Planning | `/gsd:plan-phase` | Produces PLAN.md files with wave structure |
| `silver:feature` | Execution | `/gsd:execute-phase` | Wave-based subagent execution with atomic commits |
| `silver:feature` | Verification | `/gsd:verify-work` | Checks must-haves; produces VERIFICATION.md |
| `silver:feature` | Shipping | `/gsd:ship` | Push, CI verify, PR creation |
| `silver:bugfix` | Debug dispatch | `/gsd:debug` | Spawns parallel agents for root-cause diagnosis |
| `silver:bugfix` | Execution | `/gsd:execute-phase` | Implements the fix from debug findings |
| `silver:bugfix` | Verification | `/gsd:verify-work` | Confirms fix; produces VERIFICATION.md |
| `silver:bugfix` | Shipping | `/gsd:ship` | Push, CI verify, PR creation |
| `silver:ui` | UI design capture | `/gsd:ui-phase` | Captures design context and tokens |
| `silver:ui` | Visual review | `/gsd:ui-review` | Reviews component implementation against design |
| `silver:ui` | Execution | `/gsd:execute-phase` | Implements UI components |
| `silver:ui` | Verification | `/gsd:verify-work` | Verifies UI correctness |
| `silver:devops` | Execution | `/gsd:execute-phase` | Implements infrastructure changes |
| `silver:devops` | Verification | `/gsd:verify-work` | Verifies IaC correctness |
| `silver:devops` | Shipping | `/gsd:ship` | Push, CI verify, PR creation |
| `silver:research` | Research dispatch | `/gsd:brainstorm` | Multi-AI research spike |
| `silver:research` | Intelligence | `/gsd:intel` | Codebase intelligence gathering |
| `silver:research` | Planning | `/gsd:plan-phase` | Translates findings into execution plans |
| `silver:release` | Milestone audit | `/gsd:audit-milestone` | Aggregates phase verifications |
| `silver:release` | Milestone completion | `/gsd:complete-milestone` | Marks milestone done, archives artifacts, tags release |
| `silver:fast` | Quick execution | `/gsd:fast` | Inline execution for trivial tasks |
| `/silver-create-release` | Final step | `/gsd:complete-milestone` | Milestone archival after release notes are published |

---

## What SB Covers That GSD Does Not

- **18-hook enforcement layer** — hooks fire on every Claude Code tool use; GSD has no equivalent enforcement layer
- **Pre-code-edit quality gate** — `dev-cycle-check.sh` issues a HARD STOP if planning quality gates are incomplete before any source file is touched
- **Post-session skill checklist** — `stop-check.sh` blocks task-complete if required skills are missing, and survives context compaction
- **Prompt re-injection** — `prompt-reminder.sh` re-injects the missing-skill list before every user message, preventing drift in long sessions
- **Blast radius assessment** — `/silver-blast-radius` maps DevOps change scope, dependencies, failure scenarios, and rollback plan before any infrastructure work begins
- **Knowledge and lessons capture** — `/silver-rem` and `/silver-scan` build a persistent knowledge base from session observations
- **GitHub Issue filing and board management** — `/silver-add` and `/silver-remove` file and manage backlog items directly from the Claude session
- **Session forensics for enforcement failures** — `/silver-forensics` investigates SB-specific issues (timeouts, stalls, hook failures); routes GSD-workflow-level anomalies to `/gsd:forensics`
- **CI gate on commit operations** — `ci-status-check.sh` blocks push and PR creation when CI is red; GSD has no CI enforcement
- **ROADMAP freshness gate** — `roadmap-freshness.sh` blocks commits where a SUMMARY.md is staged but the ROADMAP.md checkbox is not ticked

---

## What GSD Covers That SB Does Not

- **Planning artifact lifecycle** — ROADMAP.md, PLANS.md, STATE.md, REQUIREMENTS.md, CONTEXT.md are entirely GSD-owned and written; SB reads them but does not produce them
- **Wave-based parallel agent execution** — GSD manages dependency graphs between plans and runs independent plans in parallel within each wave
- **Context rot prevention** — each GSD subagent starts with a fresh 200K-token context window, isolated from session history; SB subagents run inside the existing session
- **Atomic per-task git commits** — GSD's executor produces a commit for each completed task within a plan; SB does not own the commit cadence
- **SUMMARY.md generation and phase archival** — GSD executors write SUMMARY.md per plan; SB reads these to advance STATE.md
- **ROADMAP.md checkbox tracking** — GSD writes and checks off ROADMAP.md milestones; SB enforces that they are checked before commit but does not write them
- **Plan-drift and execution anomaly forensics** — `/gsd:forensics` analyzes `.planning/` artifacts for stuck loops, missing outputs, and plan vs. execution divergence
- **Multi-phase roadmap management** — `/gsd:new-milestone`, `/gsd:add-phase`, `/gsd:insert-phase` manage the roadmap structure; SB has no equivalent

---

## When to Install Both

Install both when building application features or doing DevOps work that benefits from
structured multi-agent execution. The 7 Silver Bullet composable workflow skills
(`silver:feature`, `silver:bugfix`, `silver:ui`, `silver:devops`, `silver:research`,
`silver:release`, `silver:fast`) require GSD to function. Without GSD, these workflows
stall at the first `gsd-*` step. The full stack — GSD for execution, Silver Bullet for
enforcement — is the intended production configuration.
