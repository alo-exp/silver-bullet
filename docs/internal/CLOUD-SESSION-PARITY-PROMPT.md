# Make cloud sessions of silver-bullet match my local Claude Code setup

You are running in a LOCAL Claude Code session on my machine, in my checkout of `alo-exp/silver-bullet`. Goal: every future **cloud** session of this project (claude.ai/code, Claude Code on the web and the desktop app's cloud sessions) should behave as identically as possible to my local sessions — same global instructions, plugins, hooks, subagents, skills, commands, MCP servers, CLI tools and settings — without leaking secrets or personal data into the public repository.

You may use the Claude Code CLI, the shell, the GitHub CLI, and computer use to drive the Claude desktop app or claude.ai in the built-in browser where no CLI exists. Ask me before any action that stores a secret, changes account-wide settings, deletes anything, or pushes to a shared branch.

## Ground rules

- Never put secrets (tokens, API keys, Keychain values, cookies, `.credentials.json`, OAuth state) in the repo, a gist, a log, or the chat. Secrets go only into the cloud environment's secret/environment-variable settings, entered by me or with my explicit approval.
- `alo-exp/silver-bullet` is public. Only project-relevant, non-personal configuration may be committed there. Personal/user-level configuration goes into a **private** bootstrap location (step 3).
- Do not switch the current git branch of my checkout. Do the repo changes on a new branch only after asking me, and deliver them as a pull request.
- Follow my global CLAUDE.md (TDD for executable changes, subagent policy, etc.). The bootstrap installer is executable code: write tests for it first.
- No Fast mode.

## Facts about the cloud environment (verify, they may have changed)

- Container: Ubuntu 24.04, runs as `root`, `HOME=/root`, bash, Python 3, Node 22, git, jq preinstalled; outbound traffic goes through a proxy governed by the environment's network policy.
- Each cloud environment has: a name, a network access level/allowlist, environment variables and secrets, and a **setup script** that runs before Claude starts in every new session. These are edited in the environment settings (cloud environment menu in a session's title bar → Edit, or claude.ai/code environment settings). Identify the environment this project's cloud sessions use from the cloud environment menu in a session's title bar.
- Cloud sessions see only the container: no `~/.claude/CLAUDE.md`, no user-level plugins, hooks, agents or MCP servers unless the setup script or the repo provides them. Plugins and `CLAUDE.md` are loaded when the session starts, so they must be in place before Claude launches.
- The repo's own `.claude/settings.json` (committed) is loaded in both local and cloud sessions.

## Step 1 — Inventory everything that shapes my local sessions

Produce a table (in the chat, no secrets) with: item, location, scope (user / project / local-only), purpose, external dependencies, contains secrets? (y/n), macOS-specific? (y/n).

Cover at least:
1. `claude --version`; `claude plugin list`; `claude plugin marketplace list`; `~/.claude/plugins/known_marketplaces.json`.
2. `~/.claude/settings.json` and `~/.claude/settings.local.json`: `enabledPlugins`, `extraKnownMarketplaces`, `hooks` (every command and the scripts they call), `permissions`, `env`, `statusLine`, `model`, `outputStyle`, `apiKeyHelper`, sandbox settings.
3. `~/.claude/CLAUDE.md` and every file it imports (e.g. `@RTK.md`), recursively.
4. `~/.claude/agents/`, `~/.claude/skills/`, `~/.claude/commands/`, `~/.claude/output-styles/`, and any hook scripts under `~/.claude/` or elsewhere referenced by settings.
5. User-scope MCP servers in `~/.claude.json` (`mcpServers`) and any project-scope entries for this repo; note which need local apps, local ports or credentials.
6. The repo's `.claude/` (settings.json, settings.local.json, agents, skills, commands), `CLAUDE.md`, `CLAUDE.local.md`, `.mcp.json`.
7. CLI tools the hooks, skills and CLAUDE.md rely on, with versions and install method: at least `rtk`, `lean-ctx`, Context Mode (`context-mode`), `graphify` (PyPI `graphifyy`), `agentmemory`, `jq`, `gh`, `uv`, plus anything else referenced (search hook commands and CLAUDE.md for binaries).
8. Environment variables those tools and hooks need (names only).
9. Forge: remove every Forge plugin (`claude plugin list | grep -i forge` → `claude plugin uninstall …`, and its marketplace if unused) and confirm with me before uninstalling. Remind me to delete the claude.ai personal preference that says "Use the /forge:delegate skill for all tasks on session start".

## Step 2 — Decide where each item lives

Classify every inventory item:
- **Project (commit to the repo):** project-relevant plugin enablement (`extraKnownMarketplaces` + `enabledPlugins` in `.claude/settings.json`), project hooks using `$CLAUDE_PROJECT_DIR`, project subagents/skills/commands that are not personal. Check the repo's existing `.claude/settings.json` (it already has Graphify hooks) and merge, don't overwrite. Note: enabling the Silver Bullet plugin here makes its enforcement hooks apply to every session in this repo — confirm with me.
- **User-level (private bootstrap):** global CLAUDE.md and imports, user settings/hooks/agents/skills/commands, user plugin list, CLI tool installs.
- **Secrets:** only names go into the bootstrap; values become environment secrets that I enter.
- **Not portable:** macOS-only items (Keychain `security`, launchd, `/opt/homebrew`, `/Users/...` paths, Desktop-app-only or computer-use features, MCP servers that need local apps). For each, find a Linux/cloud equivalent if one exists (e.g. replace `security find-generic-password` with an environment secret), otherwise list it as a known difference.

Show me the classification and wait for my approval before writing anything.

## Step 3 — Build the private bootstrap

Create a private location for user-level config — preferred: a private GitHub repo (e.g. `alo-exp/claude-cloud-bootstrap`; ask me for the name/owner), alternative: a secret gist. Contents:
- `home/.claude/...` — sanitized copies of CLAUDE.md (+ imports), settings fragments, agents, skills, commands, hook scripts, with macOS paths rewritten to `$HOME`-relative Linux paths.
- `install.sh` — idempotent installer for Ubuntu as root that:
  - installs the CLI tools at pinned versions (prefer `uv tool install`, `npm i -g`, release binaries; verify checksums where available),
  - places the `~/.claude` files, **merging** settings JSON with `jq` instead of overwriting what the cloud image already has,
  - registers marketplaces and installs/enables plugins with `claude plugin marketplace add …` and `claude plugin install …` (check the current CLI syntax with `claude plugin --help`; if the CLI is not on PATH in the container at setup time, write `enabledPlugins`/`extraKnownMarketplaces` into `~/.claude/settings.json` instead),
  - configures MCP servers with `claude mcp add --scope user …` where they can run in the cloud,
  - reads secrets only from environment variables and fails with a clear message when a required one is missing,
  - logs what it did to `~/.claude/cloud-bootstrap.log` and exits non-zero on real failures but never blocks session start forever (timeouts).
- `tests/` — tests for install.sh (run it in a fresh `ubuntu:24.04` container or a throwaway HOME; assert files, merged settings, installed tools, idempotency on second run). Write them first (TDD).
- `README.md` — what it installs, how to update it, how to roll back.

## Step 4 — Wire the cloud environment

Using the environment settings UI (computer use on the Claude desktop app, or claude.ai/code in the built-in browser), with my confirmation at each save:
1. Network policy: allow every host the bootstrap and the tools need (GitHub, raw.githubusercontent.com, PyPI, npm, crates/GitHub releases, any plugin marketplace hosts, MCP endpoints). Prefer a specific allowlist over full access.
2. Environment variables/secrets: a read-only fine-grained GitHub token scoped to the private bootstrap repo (if private), plus the secrets from Step 2. I type the values.
3. Setup script: fetch the bootstrap at a pinned ref and run `install.sh`, e.g.
   ```bash
   set -euo pipefail
   git clone --depth 1 --branch <pinned-tag> "https://x-access-token:${BOOTSTRAP_TOKEN}@github.com/<owner>/claude-cloud-bootstrap.git" /opt/claude-bootstrap
   bash /opt/claude-bootstrap/install.sh
   ```
   Keep the existing environment or create a dedicated environment for this project — ask me.
4. Commit the project-level changes (Step 2) to the repo on a branch and open a PR; don't merge without me.

## Step 5 — Verify parity in a real cloud session

Start a new cloud session of this repo in that environment (desktop app or claude.ai/code; or the CLI if it can launch cloud sessions — check `claude --help`). Give it this check and collect its answer:

> Report, without secrets: `claude --version`; plugins and marketplaces loaded in this session; skills/commands/agents available to you; hooks active (user and project) and whether each one fires (trigger a harmless Bash, Read, Edit and Stop event); whether `~/.claude/CLAUDE.md` and its imports are loaded (quote their first heading); MCP servers connected; versions of rtk, lean-ctx, context-mode, graphify, agentmemory, jq, gh, uv; contents of `~/.claude/cloud-bootstrap.log`.

Compare that report with the local inventory. For every difference, fix it (bootstrap, repo config or environment settings) and re-verify in a fresh cloud session until only the documented, unavoidable differences remain.

## Deliverables

1. Inventory and classification tables.
2. The private bootstrap (repo or secret gist) with tests passing, plus its URL.
3. The environment settings you changed (names of variables/secrets, never values; network allowlist; setup script text).
4. The repo PR URL for project-level changes.
5. The final parity report from a fresh cloud session and the list of remaining unavoidable differences with reasons.
6. A short "how to keep this in sync" note: when I add a plugin, hook, agent or skill locally, what to update (and, if worthwhile, a script that regenerates the bootstrap from my local `~/.claude`).
