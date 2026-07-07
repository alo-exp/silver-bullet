# Self-Verification: Graphify + agentmemory in Codex (Global)

Machine-level audit for **OpenAI Codex CLI** — no Silver Bullet prerequisite. Produces a pass/fail report per check.

**Setup script:** `bash scripts/graphify-am-global-setup.sh --host codex --apply`
**Host detection:** `~/.codex/config.toml` exists ⇒ host is `codex`. Setup script skips silently otherwise.

---

## Phase 1 — Pre-flight (read-only)

```bash
which graphify
which agentmemory
which codex
which gitleaks && gitleaks version 2>/dev/null | head -1
```

**Pass:** all four binaries on PATH.

**Fail (Graphify):** `uv tool install graphifyy` or `pipx install graphifyy`.
**Fail (agentmemory):** `npm install -g @agentmemory/agentmemory`.
**Fail (Codex):** install per upstream docs (`brew install --cask codex` or `npm i -g @openai/codex`).
**Fail (gitleaks):** `brew install gitleaks` (macOS) — required for bridge second-line secret scan; global setup attempts install on `--apply`.

---

## Phase 2 — Global config artifacts

### 2.1 Graphify skill (global)

```bash
test -f ~/.codex/skills/graphify/SKILL.md && grep -q graphify ~/.codex/skills/graphify/SKILL.md && echo OK
```

**Pass:** `OK` printed — skill file exists and contains `graphify` content.

**Fail:** `graphify install --platform codex`.

### 2.2 Graphify always-on (Codex rules)

```bash
test -f ~/.codex/AGENTS.md && grep -q graphify ~/.codex/AGENTS.md && echo OK
```

**Pass:** `~/.codex/AGENTS.md` references `graphify` (written by `graphify codex install`).

**Fail:** `graphify codex install`.

### 2.3 agentmemory MCP server

```bash
grep -A2 '^\[mcp_servers\.agentmemory\]' ~/.codex/config.toml >/dev/null 2>&1 && \
  grep -q '@agentmemory/mcp' ~/.codex/config.toml && \
  grep -q 'AGENTMEMORY_URL\s*=' ~/.codex/config.toml && echo OK
```

**Pass:** `OK` — `[mcp_servers.agentmemory]` TOML table present, command args include `@agentmemory/mcp`, and `AGENTMEMORY_URL` env var is set.

**Fail:** `agentmemory connect codex --with-hooks` (preferred — also wires hooks.json), or:

```bash
codex plugin marketplace add rohitg00/agentmemory
codex plugin add agentmemory@agentmemory
```

### 2.4 agentmemory always-on hooks (Codex hooks.json)

```bash
jq -e '.hooks.PreToolUse // .hooks.UserPromptSubmit // .hooks.SessionStart' \
  ~/.codex/hooks.json 2>/dev/null | grep -q agentmemory && echo OK
```

**Pass:** `OK` — at least one of `PreToolUse` / `UserPromptSubmit` / `SessionStart` invokes an agentmemory script.

**Fail:** `agentmemory connect codex --with-hooks` (re-applies the hooks layer idempotently).

### 2.5 synergy_max `.env`

```bash
test -f ~/.agentmemory/.env && grep -q '^AGENTMEMORY_INJECT_CONTEXT=true' ~/.agentmemory/.env && grep -q '^AGENTMEMORY_EXPORT_ROOT=' ~/.agentmemory/.env && echo OK
```

**Pass:** `OK` printed; `AGENTMEMORY_EXPORT_ROOT` value is absolute.

**Fail:** `bash scripts/graphify-am-global-setup.sh --host codex --apply`.

---

## Phase 3 — Server and persistence

### 3.1 Health

```bash
curl -sf http://localhost:3111/agentmemory/health | python3 -c "import sys,json; print(json.load(sys.stdin)['status'])"
```

**Pass:** `healthy`.

**Fail:** `nohup agentmemory > ~/.agentmemory/server.log 2>&1 &` or re-run global setup.

### 3.2 launchd (macOS)

```bash
launchctl list 2>/dev/null | grep com.agentmemory.server
```

**Pass:** server PID listed. To enable auto-start at login:

```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.agentmemory.server.plist
```

**Warn if missing:** the plist exists at `~/Library/LaunchAgents/com.agentmemory.server.plist` but is not loaded. Bootstrap it manually (see command above).

### 3.3 Git hooks (global template)

```bash
git rev-parse --is-inside-work-tree >/dev/null 2>&1 && graphify hook status
```

**Pass:** `post-commit` and `post-checkout` installed (run inside any repo).

**Fail:** `graphify hook install` (writes to global `init.templateDir`).

### 3.4 Codex bridge (project-bound)

```bash
launchctl list 2>/dev/null | grep com.agentmemory.bridge
```

**Pass:** bridge PID listed. The bridge auto-commits `.agentmemory/memory/` snapshots to the repo pointed at by `AGENTMEMORY_REPO_ROOT` in `~/Library/LaunchAgents/com.agentmemory.bridge.plist`.

**Warn if missing:** bridge only applies when `--repo <path>` was passed to global setup. To enable later:

```bash
bash scripts/graphify-am-global-setup.sh --host codex --apply --repo /path/to/project
```

---

## Phase 4 — Manual synergy test (Codex UI)

1. Open a git repo with code. The repo's `.gitignore` must whitelist `.agentmemory/memory/`, `.agentmemory/snapshots/`, and `.agentmemory/profile.md` (Silver Bullet's `.gitignore` already does this in the managed block).
2. In Codex, use agentmemory MCP tools to capture a short note (e.g. "we use jq for all JSON in this repo").
3. Wait for the bridge (or trigger a manual export constrained to the global agentmemory home):

   ```bash
   curl -sf -X POST http://localhost:3111/agentmemory/obsidian/export \
     -H 'Content-Type: application/json' \
     -d '{"vaultDir":"'"$HOME"'/.agentmemory/default-export/memory"}'
   ```

   > **API constraint:** `obsidian/export` rejects `vaultDir` outside `~/.agentmemory/`. To get memories into the repo's `.agentmemory/memory/` (the whitelisted git path), rely on the `com.agentmemory.bridge` auto-snapshot OR copy from `~/.agentmemory/default-export/memory/` into the repo's `.agentmemory/memory/`.
4. From repo root: `graphify update . --no-cluster`
5. `graphify query "agentmemory vault" --budget 1500` — expect `.agentmemory/memory/MOC.md` nodes.

**Pass:** query returns memory-related nodes (e.g. `agentmemory vault`, `MOC.md`, `Sessions`, `Memories`).

---

## Appendix — If Silver Bullet is active in a repo

- `SILVER_BULLET_RUNTIME=codex bash scripts/sb-optimize-stack.sh --apply --host codex` adds project-level optimization (gitignore block, index refresh, consent timestamps).
- Hooks (`graphify-gate`, `agentmemory-gate`) apply only when `recommended_tools.*.enabled_by_user: true`.
- Global setup remains authoritative for `~/.agentmemory/.env`, `~/.codex/config.toml` (MCP), and `~/.codex/hooks.json`.
- Codex is in `multi_agent.identity_tags`; SB project wiring is opt-in, not required for global verification.

## Notes

- The verification doc mirrors the Claude Code verification doc 1:1 except for host-specific paths and command substitutions (`~/.codex/` vs `~/.codex/`, `[mcp_servers.X]` TOML vs JSON, `AGENTS.md` vs `CLAUDE.md`).
- See `docs/graphify-am/PLATFORM-MATRIX.md` for the canonical install command set and artifact paths.