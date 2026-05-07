# Architecture and Design

This document captures **high-level architecture and general design principles** only.
Detailed phase-level designs live in `docs/specs/YYYY-MM-DD-<topic>-design.md`.

## System Overview

Silver Bullet ships two first-class plugin surfaces: a Claude Code plugin (`.claude-plugin/`)
and a Codex bundle (`plugins/silver-bullet/`). Both are composed of shell hook scripts, slash-command
markdown files, skill markdown files, JSON configuration, and workflow documentation. SB wraps the
GSD, Superpowers, Engineering, and Design plugins with an enforcement layer that prevents the
runtime from skipping required workflow steps.

Claude packaging remains the canonical host-integrated surface. The Codex bundle is SB-only and
is synchronized from the repo root. Third-party plugins that do not publish Codex artifacts are
represented by thin wrappers in the shared `alo-labs/codex-plugins` marketplace, which fetches
upstream content at install time instead of vendoring it here.

No server, no database — all state lives in flat files under `~/.claude/.silver-bullet/`.

## Core Components

| Component | Path | Responsibility |
|-----------|------|----------------|
| Hook scripts | `hooks/*.sh` | PostToolUse/PreToolUse enforcement — fire on every tool call |
| Skill files | `skills/*/SKILL.md` | Declarative workflow instructions loaded via the Skill tool |
| Workflow docs | `docs/workflows/` | Full per-session step-by-step procedures (active copies) |
| Commands | `commands/` | `/silver:*` slash-command wrappers shipped inside the SB Codex bundle |
| Templates | `templates/` | Bootstrap files copied during `/silver:init` setup |
| Codex bundle | `plugins/silver-bullet/` | Curated SB-only Codex package snapshot, refreshed from the repo root |
| Codex installer | `scripts/install-codex.sh` | Registers the shared Codex marketplace and bootstraps official dependencies |
| Shared Codex marketplace | `https://github.com/alo-labs/codex-plugins` | Thin wrappers for third-party plugins that lack native Codex packaging |
| Live runtime matrix | `tests/live/` | Shared Claude/Codex E2E harness with runtime adapters |
| Config | `.silver-bullet.json` | Project-level list of tracked/required skills |
| State file | `~/.claude/.silver-bullet/state` | Flat file recording invoked skills in this session |
| Trivial flag | `~/.claude/.silver-bullet/trivial` | Touch-file that suspends enforcement for trivial changes |

### Key hooks

| Hook | Trigger | Behavior |
|------|---------|----------|
| `record-skill.sh` | PostToolUse (Skill tool) | Appends normalized skill name to state file |
| `dev-cycle-check.sh` | PreToolUse (Edit/Write/Bash) | 4-stage gate: blocks source edits if planning incomplete |
| `compliance-status.sh` | PostToolUse (all tools) | Emits live progress score per tool call |
| `completion-audit.sh` | PostToolUse (Bash) | Two-tier: blocks `git commit/push` if `required_planning` skills missing; blocks `gh pr create/deploy/gh release` if full `required_deploy` list missing |
| `planning-file-guard.sh` | PreToolUse (Edit/Write/MultiEdit) | Blocks direct edits to GSD-managed planning artifacts (ROADMAP.md, STATE.md, etc.); requires the owning GSD skill instead |
| `ci-status-check.sh` | PostToolUse (Bash) | Warns on commit/push if CI is failing |
| `stop-check.sh` | Stop / SubagentStop | Requires `required_planning` skills (planning floor) before session ends; skipped when `trivial` file exists. Full `required_deploy` is enforced by `completion-audit.sh` at delivery commands |
| *(hooks.json entry)* | SessionStart | Creates `~/.claude/.silver-bullet/trivial` — marks every new session trivial by default |
| *(hooks.json entry)* | PostToolUse (Write\|Edit\|MultiEdit) | Removes `~/.claude/.silver-bullet/trivial` — clears trivial flag when files are modified |

### Trivial-Session Bypass

The trivial bypass is a touch-file mechanism that allows enforcement hooks to stand down for
non-code-producing sessions. The file lives at `~/.claude/.silver-bullet/trivial`.

**Lifecycle:**
1. **Session start** — `SessionStart` hook creates the file unconditionally. Every session begins as "trivial" (no dev work assumed).
2. **First file edit** — `PostToolUse` on Write/Edit/MultiEdit removes the file. The session is now marked as a dev session; enforcement activates.
3. **Session end** — `stop-check.sh` checks: if the file exists, skips the skill checklist (non-dev session). If absent, enforces `required_planning` skills.

**Which hooks check the trivial file:**
- `stop-check.sh` — skips skill checklist
- `ci-status-check.sh` — skips CI failure block
- `completion-audit.sh` — skips planning completeness gate

**Manual escape hatch:**
If the bypass file was removed (because a file was edited) but you need to commit without full workflow compliance (e.g. committing a CI fix), recreate it in your terminal:
```bash
touch ~/.claude/.silver-bullet/trivial
```
The file will be cleared again on the next file edit, so the bypass is temporary.

**Security:**
The hooks validate that the trivial file is a regular file (`-f`) and not a symlink (`! -L`) before honoring it, preventing symlink-based bypass attacks.

## Design Principles

1. **Never modify third-party plugins.** All enforcement is additive to the host project.
2. **12 layers, no single bypass.** Enforcement survives context window resets because hooks
   re-fire on every tool call, not just at session start.
3. **User instructions always take precedence.** `CLAUDE.md` user rules override SB defaults.
4. **Non-destructive file operations.** Hooks are read-only except for the state/mode files they
   own. Setup commands create new files; update mode overwrites only `silver-bullet.md`.
5. **Flat-file state.** No process, no daemon, no server. State is a text file. Any tool that
   writes to it or reads from it can be independently audited.
6. **Template parity.** `templates/workflows/` must remain byte-identical to `docs/workflows/`
   so new projects get the same enforcement rules as the current project.
7. **Packaging boundaries.** SB-owned plugin bundles never vendor dependency plugins or project
   instance artifacts. The Codex bundle stays SB-only; dependency plugins are installed from
   their official sources, and non-native Codex support lives in the shared marketplace.

### Packaging Boundaries

- `/.planning/`, `/.claude/`, and `/.forge/` are project-instance artifacts, not plugin content.
- `silver-bullet.md` is the project copy; `templates/silver-bullet.md.base` is the source template.
- `plugins/silver-bullet/` is a curated Codex snapshot, not a mirror of the whole repository.
- `commands/` ships inside the SB bundle so Codex sees one Silver Bullet plugin, not a split command plugin.
- Third-party Codex wrappers belong in the shared marketplace and fetch upstream content at install time.

## Technology Choices

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Language | Bash | Pure Bash hooks and scripts; `jq` for JSON parsing (no Node.js runtime required) |
| Config format | JSON | Machine-readable by hooks and CI; human-readable for customization |
| Skill format | Markdown | Loaded natively by Claude Code's Skill tool |
| State format | Line-delimited text | `grep -q` lookups; append-only; trivially auditable |
| CI | GitHub Actions | Target audience is GitHub repos; `gh` CLI integrates release workflow |
| Codex packaging | Thin wrapper + install-time fetch | Keeps SB bundle SB-only while supporting third-party plugins that lack native Codex packaging |
