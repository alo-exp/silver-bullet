# Silver Bullet Parity Matrix — Claude Desktop ↔ Forge

This document maps every Silver Bullet capability on Claude Desktop to its equivalent on Forge. Use it to understand what changes when migrating from one runtime to the other.

## Runtime Capabilities

| Capability | Claude Desktop SB | Forge SB |
|---|---|---|
| Skill format | `~/.claude/skills/<name>/SKILL.md` (YAML frontmatter `name`/`description`) | `~/forge/skills/<name>/SKILL.md` — same format, no conversion |
| Skill auto-loading | At session start | At session start (per `forgecode.dev/docs/skills`) |
| Plugin installation | `/plugin install <repo>` | `bash forge-sb-install.sh` (idempotent) |
| Hook system | `settings.json` hooks fire on events (PreToolUse, PostToolUse, Stop, etc.) | **No hooks.** Hook gates are replaced with custom agents the main agent invokes as tools at the gating moment. |
| Subagent system | `Task(subagent_type="X")` spawns isolated context | Forge custom agents at `~/forge/agents/<id>.md` with `tool_supported: true` (per `forgecode.dev/docs/creating-agents`) |
| Skill nesting | `Skill(skill="X")` invokes another skill | Skill body just describes what to do; Forge auto-applies dependent skills |
| AskUserQuestion | First-class UI primitive | Plain conversational prompt — same outcome |

## Hook → Custom Agent Map

Each SB hook becomes a Forge custom agent. The main agent invokes them as tools at the same moment Claude Desktop's hook would fire.

| SB hook (`hooks/*.sh`) | Fires on | Forge agent (`forge/agents/*.md`) | Invoked by main agent at |
|---|---|---|---|
| `completion-audit.sh` (intermediate) | `PreToolUse: git commit` | `forge-pre-commit-audit` | Before any `git commit` |
| `completion-audit.sh` (final) | `PreToolUse: gh pr create / gh release create / deploy` | `forge-pre-pr-audit` | Before PR / release / deploy |
| `stop-check.sh` | `Stop` / `SubagentStop` | `forge-task-complete-check` | Before declaring task complete |
| `roadmap-freshness.sh` | `PreToolUse: git commit` (when SUMMARY.md staged) | `forge-roadmap-freshness` | Before commit when staging phase SUMMARY.md |
| `spec-floor-check.sh` | `PreToolUse: production build` | `forge-spec-floor-check` | Before any production build |
| `uat-gate.sh` | `PreToolUse: gh pr create` (UAT-eligible) | `forge-uat-gate` | Before PR for user-facing phases |
| `pr-traceability.sh` | `PostToolUse: gh pr create` | `forge-pr-traceability` | When creating a PR |
| `ci-status-check.sh` | `PreToolUse / PostToolUse: Bash` | `forge-ci-status-check` | After push, before next commit |
| `forbidden-skill-check.sh` | `PreToolUse: Skill` | `forge-forbidden-skill-check` | Before applying any skill |
| `session-start` + `session-log-init.sh` + `spec-session-record.sh` | SessionStart | `forge-session-init` | At session start |

Hooks **not ported** (intentional): `dev-cycle-check.sh` (no plugin cache in Forge), `timeout-check.sh` (different timeout model), `compliance-status.sh` / `prompt-reminder.sh` / `semantic-compress.sh` / `ensure-model-routing.sh` / `record-skill.sh` / `phase-archive.sh` (informational or auto-handled by Forge).

## Subagent → Custom Agent Map

All 31 GSD subagents are ported as Forge custom agents with the same `id` for parity.

### Planning stage
- `gsd-roadmapper`, `gsd-planner`, `gsd-plan-checker`, `gsd-phase-researcher`, `gsd-pattern-mapper`, `gsd-project-researcher`, `gsd-research-synthesizer`, `gsd-advisor-researcher`, `gsd-assumptions-analyzer`

### Execution stage
- `gsd-executor`, `gsd-verifier`, `gsd-integration-checker`, `gsd-nyquist-auditor`

### Review stage
- `gsd-code-reviewer`, `gsd-code-fixer`, `gsd-security-auditor`, `gsd-doc-writer`, `gsd-doc-verifier`

### Specialized
- `gsd-debugger`, `gsd-debug-session-manager`, `gsd-codebase-mapper`, `gsd-intel-updater`, `gsd-user-profiler`

### AI integration
- `gsd-eval-auditor`, `gsd-eval-planner`, `gsd-domain-researcher`, `gsd-ai-researcher`, `gsd-framework-selector`

### UI
- `gsd-ui-auditor`, `gsd-ui-checker`, `gsd-ui-researcher`

## Skill Map

### Silver Bullet skills (61) — copied verbatim
Format identical; copied with no content changes except for 3 skills with Claude Code-only references:

- `silver-update` — replaces `claude mcp install` with `forge-sb-install.sh`
- `silver-init` — replaces Claude Code plugin checks with Forge install verification
- `silver-migrate` — documents Claude Desktop → Forge migration path

### Superpowers skills (14) — copied from cache
Sourced from `~/.claude/plugins/cache/superpowers-marketplace/superpowers/<v>/skills/`.

### Anthropic knowledge-work-plugins skills (33) — namespaced
Sourced from `https://github.com/anthropics/knowledge-work-plugins`. Namespaced with `<plugin>-` prefix to avoid collisions:

- `engineering-*` (10 skills)
- `design-*` (7 skills)
- `product-management-*` (8 skills)
- `marketing-*` (8 skills)

## Workflow Parity

Each major SB workflow runs end-to-end on Forge with the same artifact outputs:

| Workflow | Skills + agents involved | Output artifacts (parity-checked in Phase 69) |
|---|---|---|
| `silver-feature` | brainstorming, silver-spec, silver-quality-gates, gsd-planner, gsd-executor, gsd-code-reviewer, gsd-verifier, finishing-a-development-branch | CONTEXT.md, RESEARCH.md, PLAN.md, REVIEW.md, VERIFICATION.md, SECURITY.md, SUMMARY.md |
| `silver-bugfix` | systematic-debugging, gsd-debugger, gsd-planner, gsd-executor, gsd-verifier | DEBUG.md, PLAN.md, VERIFICATION.md, SUMMARY.md |
| `silver-ui` | silver-feature path + gsd-ui-researcher, gsd-ui-checker, gsd-ui-auditor | UI-SPEC.md, UI-REVIEW.md + standard artifacts |
| `silver-devops` | silver-blast-radius, devops-quality-gates, devops-skill-router, gsd-planner, gsd-executor | BLAST-RADIUS.md, IAC-REVIEW.md + standard artifacts |
| `silver-release` | review-cross-artifact, silver-create-release, finishing-a-development-branch, gsd-pr-creator | RELEASE-NOTES.md, CHANGELOG.md, GitHub release + tag |

## Behavioural Gaps (Acceptable)

These are gaps that exist by design and require AGENTS.md guidance to mitigate:

1. **No automatic hook firing** — gates depend on the main agent invoking the right hook-agent at the right moment. AGENTS.md is the central enforcement layer.
2. **No silent state recording** — Claude Desktop SB writes a state file as skills run. Forge does not. Parity is achieved by gating agents reading the project's artifact state directly (PLAN.md, VERIFICATION.md, etc.) rather than a state file.
3. **No `/compact` integration** — Forge has its own context engine; SB's `/compact` invocation is unused.

## How to Verify Parity in Your Project

After running `forge-sb-install.sh`:

1. Run `:skill` in Forge — confirm ~106 skills loaded
2. Run `:agent` in Forge — confirm ~41 custom agents available (10 hook + 31 GSD)
3. Run a small `silver-feature` task end-to-end and check the produced `.planning/phases/<NNN>/` artifacts match the same workflow on Claude Desktop SB
4. Compare against Phase 69's `forge/PARITY-REPORT.md` (generated during end-to-end verification)
