# Architecture and Design

This document captures **high-level architecture and general design principles** only.
Detailed phase-level designs live in `docs/specs/YYYY-MM-DD-<topic>-design.md`.

## System Overview

Silver Bullet ships two first-class plugin surfaces: a Claude Code plugin (`.claude-plugin/`)
and a Codex bundle (`plugins/silver-bullet/`). Both are composed of shell hook scripts, slash-command
markdown files, skill markdown files, JSON configuration, and workflow documentation. SB owns
the lifecycle authority for default software-engineering workflows and calls optional provider,
DevOps, design, research, or issue-tracker plugins only when a selected flow needs their external
capability. Its enforcement layer prevents the runtime from skipping required workflow steps.

Claude packaging remains the canonical host-integrated surface. The Codex bundle is SB-only and
is synchronized from the repo root. Optional extension plugins that do not publish Codex artifacts
are represented by thin wrappers in the unified `alo-labs/agent-plugins` marketplace, which fetches
upstream content at install time instead of vendoring it here.

No server, no database — all state lives in flat files under `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/`.

## Core Components

| Component | Path | Responsibility |
|-----------|------|----------------|
| Hook scripts | `hooks/*.sh` | PostToolUse/PreToolUse enforcement — fire on every tool call |
| Skill files | `skills/*/SKILL.md` | Declarative workflow instructions loaded through the active host's supported skill channel |
| Workflow docs | `docs/workflows/` | Full per-session step-by-step procedures (active copies) |
| Commands | `plugins/silver-bullet/commands/` | `/sb:*` slash-command wrappers for the Cursor package surface; Codex uses the native skill-source mirror |
| Templates | `templates/` | Bootstrap files copied during `/sb:init` setup |
| Codex bundle | `plugins/silver-bullet/` | Curated SB-only Codex package snapshot, refreshed from the repo root |
| Codex installer | `scripts/install-codex.sh` | Registers the shared Codex marketplace and bootstraps official dependencies |
| Unified agent marketplace | `https://github.com/alo-labs/agent-plugins` | Thin tri-host manifests; Codex entries fetch upstream at install time |
| Live runtime matrix | `tests/live/` | Shared Claude/Codex E2E harness with runtime adapters |
| Config | `.silver-bullet.json` | Project-level list of tracked/required skills |
| State file | `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/state` | Flat file recording invoked skills in this session |
| Trivial flag | `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/trivial` | Legacy compatibility marker. Codex agents should route trivial work through `/sb:fast` instead of using the touch-file bypass. |

### Key hooks

| Hook | Trigger | Behavior |
|------|---------|----------|
| `record-skill.sh` | PostToolUse (Claude Skill calls or Codex SB adapter receipts) | Appends normalized skill name to state file |
| `record-requested-skill.sh` | UserPromptSubmit | Records requested SB route markers before the next turn starts |
| `dev-cycle-check.sh` | PreToolUse (Edit/Write/Bash) | 4-stage gate: blocks source edits if planning incomplete |
| `compliance-status.sh` | PostToolUse (all tools) | Emits live progress score per tool call |
| `completion-audit.sh` | PostToolUse (Bash) | Two-tier: blocks `git commit/push` if `required_planning` skills missing; blocks `gh pr create/deploy/gh release` if full `required_deploy` list missing |
| `planning-file-guard.sh` | PreToolUse (Edit/Write/MultiEdit) | Blocks direct edits to guarded planning artifacts (ROADMAP.md, STATE.md, etc.); requires the owning SB workflow path instead |
| `ci-status-check.sh` | PostToolUse (Bash) | Warns on commit/push if CI is failing |
| `prompt-reminder.sh` | UserPromptSubmit | Re-injects missing skills list before every user message and surfaces current workflow context |
| `stop-check.sh` | Stop / SubagentStop | Requires `required_planning` skills (planning floor) before session ends. Full `required_deploy` is enforced by `completion-audit.sh` at delivery commands |
| *(hooks.json entry)* | SessionStart | Clears any stale `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/trivial` marker at session start; does not auto-create it |
| *(hooks.json entry)* | PostToolUse (Write\|Edit\|MultiEdit) | Clears `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/trivial` when files are modified |

### Fast Path

Silver Bullet routes trivial changes through `/sb:fast`, which classifies the change
and dispatches to SB's fast path without the full workflow overhead. The legacy touch-file
marker remains only as a compatibility detail for older sessions, not as the supported
Codex entry point.

## Design Principles

1. **Never modify third-party plugins.** All enforcement is additive to the host project.
2. **12 layers, no single bypass.** Enforcement survives context window resets because hooks
   re-fire on every tool call, not just at session start.
3. **User instructions always take precedence.** Any existing project instruction file (`CLAUDE.md` / `AGENTS.md`) overrides SB defaults, but SB does not require one to exist.
4. **Non-destructive file operations.** Hooks are read-only except for the state/mode files they
   own. Setup commands create new files; update mode overwrites only `silver-bullet.md`.
5. **Flat-file state.** No process, no daemon, no server. State is a text file. Any tool that
   writes to it or reads from it can be independently audited.
6. **Template parity.** `templates/workflows/` must remain byte-identical to `docs/workflows/`
   so new projects get the same enforcement rules as the current project.
7. **Packaging boundaries.** SB-owned plugin bundles never vendor optional extension plugins or
   project instance artifacts. The Codex bundle stays SB-only; non-native Codex support for
   external extensions lives in the shared marketplace.

### Packaging Boundaries

- `/.planning/` and `/.codex/` are project-instance artifacts, not plugin content.
- `silver-bullet.md` is the project copy; `templates/silver-bullet.md.base` is the source template.
- `plugins/silver-bullet/` is a curated Codex snapshot, not a mirror of the whole repository.
- `plugins/silver-bullet/commands/` ships inside the shared package for Cursor's command surface; the Codex manifest intentionally omits `commands` so Codex does not migrate stubs into `source-command-*` skills.
- Third-party Codex wrappers for optional extensions belong in the shared marketplace and fetch upstream content at install time.

## Technology Choices

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Language | Bash | Pure Bash hooks and scripts; `jq` for JSON parsing (no Node.js runtime required) |
| Config format | JSON | Machine-readable by hooks and CI; human-readable for customization |
| Skill format | Markdown | Loaded through the active host's skill surface; Codex mirrors SB skills into the native `/SB:` picker and records via the SB adapter |
| State format | Line-delimited text | `grep -q` lookups; append-only; trivially auditable |
| CI | GitHub Actions | Target audience is GitHub repos; `gh` CLI integrates release workflow |
| Codex packaging | Thin wrapper + install-time fetch | Keeps SB bundle SB-only while supporting third-party plugins that lack native Codex packaging |
