# Make cloud sessions of this project match my local Claude Code setup

Project-agnostic prompt: paste it into a LOCAL Claude Code session started in the checkout of any project.

You are running in a LOCAL Claude Code session on my machine, in a checkout of a project (identify it with `git remote get-url origin` and `git rev-parse --show-toplevel`). Goal: every future **cloud** session of this project (claude.ai/code, Claude Code on the web, the desktop app's cloud sessions) behaves as identically as possible to my local sessions — same global instructions, plugins, hooks, subagents, skills, commands, MCP servers, CLI tools and settings — without leaking secrets or personal data.

Design for reuse across projects: user-level configuration goes into ONE private bootstrap shared by all my projects; only project-specific configuration goes into this project's repository. If the bootstrap already exists (from an earlier project), update and reuse it instead of creating another.

You may use the Claude Code CLI, the shell, the GitHub CLI, and computer use to drive the Claude desktop app, or claude.ai in the built-in browser, where no CLI exists. Ask me before any action that stores a secret, changes account-wide or environment settings, deletes anything, or pushes to a shared branch.

## Ground rules

- Never put secrets (tokens, API keys, Keychain values, cookies, `.credentials.json`, OAuth state) in a repository, gist, log or the chat. Secret values go only into the cloud environment's secret/environment-variable settings, entered by me or with my explicit approval.
- Check whether this project's repository is public (`gh repo view --json visibility`). Commit only non-personal, project-relevant configuration to it; everything personal goes to the private bootstrap.
- Do not switch the current git branch of my checkout. Make repository changes on a new branch only after asking me, and deliver them as a pull request.
- Follow my global CLAUDE.md (TDD for executable changes, subagent policy, etc.). The bootstrap installer is executable code: write its tests first.
- No Fast mode.

## Facts about cloud sessions (verify; they may have changed)

- Container: Ubuntu 24.04, runs as `root`, `HOME=/root`, with bash, Python 3, Node, git and jq preinstalled; outbound traffic goes through a proxy governed by the environment's network policy. GitHub API calls from inside a session are limited to the session's own repositories, so the bootstrap should be fetched with git or raw HTTPS, not arbitrary API paths.
- Each cloud environment has a name, a network access level/allowlist, environment variables and secrets, and a **setup script** that runs before Claude starts in every new session. Edit them from the cloud environment menu in a session's title bar → Edit, or the claude.ai/code environment settings. Ask me which environment this project uses (or should use).
- Cloud sessions see only the container: no `~/.claude/CLAUDE.md`, user-level plugins, hooks, agents or MCP servers unless the setup script or the repository provides them. Plugins and CLAUDE.md load when a session starts, so they must be in place before Claude launches — changes never reach an already-running session.
- The project's committed `.claude/settings.json`, `.claude/agents|skills|commands`, `.mcp.json` and `CLAUDE.md` load in both local and cloud sessions.

## Step 1 — Inventory everything that shapes my local sessions of this project

Produce a table in the chat (no secret values) with: item, location, scope (user / project / local-only), purpose, external dependencies, contains secrets? (y/n), OS-specific? (y/n).

Cover at least:
1. `claude --version`; `claude plugin list`; `claude plugin marketplace list`; `~/.claude/plugins/known_marketplaces.json`.
2. `~/.claude/settings.json` and `~/.claude/settings.local.json`: `enabledPlugins`, `extraKnownMarketplaces`, `hooks` (every command and the scripts it calls), `permissions`, `env`, `statusLine`, `model`, `outputStyle`, `apiKeyHelper`, sandbox settings.
3. `~/.claude/CLAUDE.md` and every file it imports (`@file` lines), recursively.
4. `~/.claude/agents/`, `~/.claude/skills/`, `~/.claude/commands/`, `~/.claude/output-styles/`, and hook scripts referenced by settings.
5. User-scope MCP servers in `~/.claude.json` (`mcpServers`) and project-scope entries for this project; note which need local apps, local ports or credentials.
6. This project's `.claude/` (settings.json, settings.local.json, agents, skills, commands), `CLAUDE.md`, `CLAUDE.local.md`, `.mcp.json`.
7. CLI tools that hooks, skills, MCP servers and CLAUDE.md rely on (search them for binary names), with versions and install methods.
8. Environment variables those tools and hooks need (names only).
9. Plugins I asked to remove: none of the Forge plugins may be installed (`claude plugin list | grep -i forge` → confirm with me → `claude plugin uninstall …`, and remove an unused marketplace). Remind me to delete any claude.ai personal preference that refers to a removed plugin.

## Step 2 — Decide where each item lives

- **Project (commit to this repo):** project-relevant plugin enablement (`extraKnownMarketplaces` + `enabledPlugins` in `.claude/settings.json`), project hooks using `$CLAUDE_PROJECT_DIR`, project subagents/skills/commands. Merge with what the repo already has; never overwrite. If a plugin installs enforcement hooks (for example a workflow/quality-gate plugin), point out that enabling it here applies it to every session in this repo, and confirm with me.
- **User-level (private bootstrap):** global CLAUDE.md and imports, user settings/hooks/agents/skills/commands, user plugin list, CLI tool installs, user-scope MCP servers that can run in the cloud.
- **Secrets:** names in the bootstrap, values as environment secrets I enter.
- **Not portable:** OS-specific items (macOS Keychain `security`, launchd, `/opt/homebrew`, `/Users/...` paths, desktop-only or computer-use features, MCP servers that need local apps). Find a Linux/cloud equivalent where one exists (e.g. replace a Keychain lookup with an environment secret); otherwise list it as a known difference.

Show me the classification and wait for my approval before writing anything.

## Step 3 — Build or update the private bootstrap (shared by all projects)

Location: a private GitHub repository (ask me for owner/name; suggest `<my-user-or-org>/claude-cloud-bootstrap`), or a secret gist if I prefer. Contents:
- `home/.claude/...` — sanitized copies of CLAUDE.md (+ imports), settings fragments, agents, skills, commands, hook scripts, with OS-specific paths rewritten to `$HOME`-relative Linux paths.
- `install.sh` — idempotent installer for Ubuntu as root that:
  - installs the CLI tools at pinned versions (prefer `uv tool install`, `npm i -g`, release binaries with checksum verification),
  - places the `~/.claude` files, **merging** settings JSON with `jq` instead of overwriting what the cloud image already has,
  - registers marketplaces and installs/enables plugins with `claude plugin marketplace add …` / `claude plugin install …` (check current syntax with `claude plugin --help`; if `claude` is not on PATH when the setup script runs, write `enabledPlugins`/`extraKnownMarketplaces` into `~/.claude/settings.json` instead),
  - adds cloud-capable MCP servers with `claude mcp add --scope user …` (or the equivalent `~/.claude.json` edit),
  - reads secrets only from environment variables and fails with a clear message when a required one is missing,
  - logs to `~/.claude/cloud-bootstrap.log`, uses timeouts, and never blocks session start indefinitely.
- `tests/` — tests for install.sh, written first: run it in a fresh `ubuntu:24.04` container or a throwaway HOME; assert placed files, merged settings, installed tools, and idempotency on a second run.
- `README.md` — what it installs, how to update it, how to roll back, and how a new project opts in.
- `sync-from-local.sh` (optional but recommended) — regenerates `home/.claude` from my local `~/.claude` with the same sanitizing rules, so the bootstrap stays current.

## Step 4 — Wire this project's cloud environment

Using the environment settings UI (computer use on the Claude desktop app, or claude.ai/code in the built-in browser), confirming each save with me:
1. Network policy: allow every host the bootstrap and tools need (GitHub, raw.githubusercontent.com, PyPI, npm, release download hosts, plugin marketplace hosts, MCP endpoints). Prefer a specific allowlist over full access.
2. Environment variables/secrets: a read-only fine-grained GitHub token scoped to the private bootstrap repository (if private), plus the secrets from Step 2. I type the values.
3. Setup script: fetch the bootstrap at a pinned ref and run it, e.g.
   ```bash
   set -euo pipefail
   git clone --depth 1 --branch <pinned-tag> "https://x-access-token:${BOOTSTRAP_TOKEN}@github.com/<owner>/claude-cloud-bootstrap.git" /opt/claude-bootstrap
   bash /opt/claude-bootstrap/install.sh
   ```
   If several projects share one environment, the same setup script serves all of them; otherwise copy it into each project's environment.
4. Commit the project-level changes from Step 2 on a new branch and open a pull request; don't merge without me.

## Step 5 — Verify parity in a real cloud session

Start a NEW cloud session of this project in that environment (desktop app or claude.ai/code; or the CLI if it can launch cloud sessions — check `claude --help`), on the branch that carries the project-level changes. Ask it:

> Report, without secrets: `claude --version`; plugins and marketplaces loaded in this session; skills/commands/agents available to you; hooks active (user and project) and whether each one fires (trigger a harmless Bash, Read, Edit and Stop event); whether `~/.claude/CLAUDE.md` and its imports are loaded (quote their first heading); MCP servers connected; versions of the CLI tools from the inventory; contents of `~/.claude/cloud-bootstrap.log`.

Compare the report with the local inventory. Fix every difference (bootstrap, repository config or environment settings) and re-verify in a fresh cloud session until only documented, unavoidable differences remain.

## Deliverables

1. Inventory and classification tables.
2. The private bootstrap (URL), with tests passing.
3. Environment settings changed: variable/secret names (never values), network allowlist, setup script text.
4. The pull request URL for this project's changes.
5. The final parity report from a fresh cloud session and the remaining unavoidable differences with reasons.
6. A short "keep in sync" note: what to update when I add a plugin, hook, agent or skill locally, and how to onboard another project (normally: point its environment at the same setup script and commit its project-level `.claude/` settings).
