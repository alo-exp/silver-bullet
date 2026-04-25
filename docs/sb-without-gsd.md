# Silver Bullet Without GSD

Silver Bullet's enforcement layer runs independently of GSD. The hooks, compliance gates, and
most standalone skills activate the moment you install the plugin and run `/silver:init`. GSD is
the multi-agent execution engine that powers the composable workflow skills — it is not required
to get enforcement.

This page documents exactly what you get when you install only Silver Bullet, and what is
unavailable without GSD.

---

## Install (SB-only)

```
/plugin install alo-exp/silver-bullet
```

Install `jq` if you do not have it:

```bash
brew install jq    # macOS
apt install jq     # Linux
```

Then initialize your project:

```
/silver:init
```

All enforcement hooks activate immediately. No GSD install is required for any of the hooks
or standalone skills described below.

---

## What Works Without GSD

### Enforcement Hooks (all active)

All 18 hook scripts fire on their configured Claude Code events regardless of whether GSD is
installed. These are the Silver Bullet enforcement layer.

| Hook | Event | What it enforces |
|------|-------|-----------------|
| `session-start` | SessionStart | Injects Superpowers + Design context; injects `core-rules.md` at session open; resets branch-scoped state |
| `spec-session-record.sh` | SessionStart | Records spec version at session open for UAT gate staleness detection |
| `record-skill.sh` | PostToolUse/Skill | Records every skill invocation to the state file; powers compliance display |
| `dev-cycle-check.sh` | PreToolUse + PostToolUse / Edit, Write, Bash | HARD STOP if planning quality gates are incomplete before source code edits |
| `compliance-status.sh` | PostToolUse/\* | Displays workflow progress score on every tool use (informational) |
| `completion-audit.sh` | PreToolUse/Bash + PostToolUse/Bash | Blocks `git commit`, `git push`, `gh pr create`, and `deploy` if workflow is incomplete |
| `ci-status-check.sh` | PreToolUse/Bash + PostToolUse/Bash | Blocks `git push`, `gh pr create`, and `gh release create` when CI is failing; warns on `git commit` |
| `stop-check.sh` | Stop / SubagentStop | Blocks task-complete declaration if required skills are missing; survives context compaction |
| `prompt-reminder.sh` | UserPromptSubmit | Re-injects missing-skill list and core enforcement rules before Claude processes each message |
| `forbidden-skill-check.sh` | PreToolUse/Skill | Blocks deprecated or forbidden skills before they execute |
| `roadmap-freshness.sh` | PreToolUse/Bash | Blocks `git commit` if a phase `SUMMARY.md` is staged but the corresponding ROADMAP.md checkbox is not ticked |
| `phase-archive.sh` | PreToolUse/Bash | Archives GSD planning artifacts when a git commit includes a phase SUMMARY |
| `semantic-compress.sh` | PostToolUse/Skill | TF-IDF context compression after skill invocations to manage context window |
| `session-log-init.sh` | PostToolUse/Bash | Creates a session log file on the first Bash use |
| `timeout-check.sh` | PostToolUse/* | Monitors for stall conditions and fires an anti-stall warning |
| `pr-traceability.sh` | PostToolUse/Bash | Appends spec reference, requirement IDs, and deferred items to PR descriptions |
| `spec-floor-check.sh` | PreToolUse/Bash | Verifies SPEC.md is present and at minimum version before spec-gated operations |
| `uat-gate.sh` | PreToolUse/Skill | Blocks `gsd-complete-milestone` if UAT.md is missing, contains failures, or was run against a stale spec |

### Standalone Skills (all active without GSD)

These Silver Bullet skills do not invoke any `gsd-*` steps as required calls. They work
fully without a GSD install.

| Skill | Purpose |
|-------|---------|
| `/silver` | Main entry point — routes freeform text to the best SB or GSD skill |
| `/silver:init` | Once per project — initializes `CLAUDE.md`, config, CI, and docs scaffold |
| `/silver-quality-gates` | Pre-planning quality check across 9 dimensions (modularity, reusability, scalability, security, reliability, usability, testability, extensibility) |
| `/devops-quality-gates` | 7 IaC-adapted quality dimensions for infrastructure work (usability excluded) |
| `/silver-blast-radius` | Maps change scope, dependencies, failure scenarios, and rollback plan for DevOps changes |
| `/silver-forensics` | Structured root-cause investigation for failed or stalled sessions; handles session-level issues directly, routes GSD-workflow-level issues to `/gsd:forensics` if GSD is installed |
| `/silver-add` | Classify and file an issue or backlog item to GitHub Issues + project board, or to local `docs/issues/` |
| `/silver-remove` | Remove an issue or backlog item by ID |
| `/silver-rem` | Capture a knowledge or lessons-learned insight into monthly docs (`docs/knowledge/` or `docs/lessons/`) |
| `/silver-scan` | Retrospective session scanner — detects deferred items and insights from session logs, files survivors via `/silver-add` and `/silver-rem` |
| `/silver-create-release` | Generates release notes and creates GitHub Release — **partial**: the final step calls `gsd-complete-milestone`; milestone archival is unavailable without GSD, but the release notes and GitHub Release creation work |

---

## What Requires GSD

### Composable Workflow Skills (disabled without GSD)

These seven Silver Bullet workflow skills call into GSD at every major step. Without GSD
installed, they stall immediately at the first `gsd-*` invocation.

| Skill | GSD steps required | What breaks without GSD |
|-------|--------------------|-------------------------|
| `/silver:feature` | `gsd-discuss-phase`, `gsd-plan-phase`, `gsd-execute-phase`, `gsd-verify-work`, `gsd-ship` | Discussion, planning, execution, verification, and shipping all fail |
| `/silver:bugfix` | `gsd-debug`, `gsd-execute-phase`, `gsd-verify-work`, `gsd-ship` | Parallel debug dispatch, execution, verification, and shipping all fail |
| `/silver:ui` | `gsd-ui-phase`, `gsd-ui-review`, `gsd-execute-phase`, `gsd-verify-work` | UI design capture, visual review, execution, and verification all fail |
| `/silver:devops` | `gsd-execute-phase`, `gsd-verify-work`, `gsd-ship` | Execution, verification, and shipping all fail |
| `/silver:research` | `gsd-explore` (via `silver:explore`); receiving workflow (`silver:feature` / `silver:devops`) also requires GSD | Fuzzy clarification and the receiving implementation workflow fail; MultAI research and brainstorm steps still run |
| `/silver:release` | `gsd-ship`, `gsd-complete-milestone`, `gsd-audit-milestone`, `gsd-audit-uat` | Phase shipping, UAT gate, milestone completion, and audit all fail |
| `/silver:fast` | `gsd-fast` | The quick-task execution mode is unavailable |

### GSD Skills (not available)

The following skills are provided by GSD and are not available unless GSD is installed:
`gsd-discuss-phase`, `gsd-plan-phase`, `gsd-execute-phase`, `gsd-verify-work`, `gsd-ship`,
`gsd-fast`, `gsd-debug`, `gsd-new-project`, `gsd-new-milestone`, `gsd-brainstorm`,
`gsd-intel`, `gsd-ui-phase`, `gsd-ui-review`, `gsd-secure`, `gsd-complete-milestone`,
`gsd-audit-milestone`, `gsd-audit-uat`, `gsd-progress`, `gsd-resume`, `gsd-pause`.

---

## When to Use SB-Only

1. **Enforcement without structured planning** — you have your own planning workflow and want
   Silver Bullet's quality gates and compliance tracking layered on top of it.
2. **Adding compliance gates to an existing project** — the hooks fire on your existing commits,
   PRs, and deployments without requiring you to adopt GSD's planning artifacts.
3. **DevOps-only work** — `silver-blast-radius`, `devops-quality-gates`, and the enforcement
   hooks cover the full DevOps quality layer. GSD's app-development planner is not needed.
4. **Evaluating Silver Bullet's enforcement layer** — install SB alone to see what the hooks
   enforce before committing to the full four-plugin stack.

---

## Full Stack Install

For the full workflow experience including multi-agent execution, wave-based parallel execution,
and plan-driven development, see the
[Installation section of README.md](../README.md#install).
