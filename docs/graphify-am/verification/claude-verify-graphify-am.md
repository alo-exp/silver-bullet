# Self-Verification: Graphify + agentmemory in Claude Code (Global)

Machine-level audit for **Claude Code** — no Silver Bullet prerequisite. Produces a pass/fail report per check.

**Setup script:** `bash scripts/graphify-am-global-setup.sh --host claude --apply`

---

## Phase 1 — Pre-flight (read-only)

### 1.1 Graphify CLI

```bash
which graphify && graphify --version 2>/dev/null | head -1
```

**Pass:** path under `/opt/homebrew`, `/usr/local`, or `~/.local` and version present.

**Fail:** install `uv tool install graphifyy` or `pipx install graphifyy`.

### 1.2 agentmemory CLI

```bash
which agentmemory && agentmemory --version 2>/dev/null | head -1
```

**Pass:** binary on PATH.

**Fail:** `npm install -g @agentmemory/agentmemory`

### 1.3 gitleaks

```bash
which gitleaks && gitleaks version 2>/dev/null | head -1
```

**Pass:** binary on PATH (bridge second-line secret scan).

**Fail:** `brew install gitleaks` (macOS) or apt/GitHub releases on Linux — `graphify-am-global-setup.sh --apply` attempts install.

---

## Phase 2 — Global config artifacts

### 2.1 Graphify skill (global)

```bash
test -f ~/.codex/skills/graphify/SKILL.md && grep -q graphify ~/.codex/skills/graphify/SKILL.md && echo OK
```

**Pass:** skill file exists with graphify content.

**Fail:** `graphify install` (no `--project`).

### 2.2 Graphify always-on hooks

```bash
grep -r graphify ~/.codex/CLAUDE.md ~/.codex/settings.json 2>/dev/null | head -3
```

**Pass:** graphify PreToolUse or rules reference present.

**Fail:** `graphify claude install` (global).

### 2.3 agentmemory MCP

```bash
jq '.mcpServers | keys[]' ~/.claude.json 2>/dev/null | grep -i agentmemory
```

**Pass:** `agentmemory` key in `~/.claude.json` mcpServers.

**Fail:** `agentmemory connect claude-code`

### 2.4 synergy_max `.env`

```bash
test -f ~/.agentmemory/.env && grep -q '^AGENTMEMORY_INJECT_CONTEXT=true' ~/.agentmemory/.env && grep -q '^AGENTMEMORY_EXPORT_ROOT=' ~/.agentmemory/.env && echo OK
```

**Pass:** `OK` printed; `AGENTMEMORY_EXPORT_ROOT` value is absolute.

**Fail:** `bash scripts/graphify-am-global-setup.sh --host claude --apply`

---

## Phase 3 — Server and persistence

### 3.1 Health

```bash
curl -sf http://localhost:3111/agentmemory/health && echo OK
```

### 3.2 launchd (macOS)

```bash
launchctl list 2>/dev/null | grep com.agentmemory.server
```

**Warn if missing:** `nohup agentmemory > ~/.agentmemory/server.log 2>&1 &` or re-run global setup.

### 3.3 Git hooks (global template)

```bash
graphify hook status
```

**Pass:** post-commit and post-checkout installed.

---

## Phase 4 — Manual synergy test (in Claude Code UI)

1. Open a git repo with code. Optionally pass `--repo` to global setup for export root.
2. Ask Claude to **save a decision** via agentmemory MCP (e.g. "Remember: we use jq for all JSON in this repo").
3. The `com.agentmemory.bridge` launch agent watches `.agentmemory/` and auto-commits memories to git — wait ~30s for the bridge to snapshot and commit, OR trigger a manual export constrained to the global agentmemory home:
   ```bash
   curl -sf -X POST http://localhost:3111/agentmemory/obsidian/export \
     -H 'Content-Type: application/json' \
     -d '{"vaultDir":"'"$HOME"'/.agentmemory/default-export/memory"}'
   ```
   > **API constraint:** `obsidian/export` rejects `vaultDir` outside `~/.agentmemory/`. To get memories into the repo's `.agentmemory/memory/` (the whitelisted git path), rely on the bridge auto-snapshot OR copy from `~/.agentmemory/default-export/memory/` into the repo's `.agentmemory/memory/`.
4. From repo root: `graphify update . --no-cluster`
5. `graphify query "agentmemory vault" --budget 1500` — result should include `.agentmemory/memory/MOC.md` nodes.

**Pass:** query returns memory-related nodes (e.g. `agentmemory vault`, `MOC.md`, `Sessions`, `Memories`).

---

## Appendix — If Silver Bullet is active in a repo

- SB may run `bash scripts/sb-optimize-stack.sh --apply --host claude` for project gitignore, index, and consent timestamps.
- Hooks (`graphify-gate`, `agentmemory-gate`) apply only when `recommended_tools.*.enabled_by_user: true`.
- Global setup remains authoritative for `~/.agentmemory/.env` and `~/.claude.json` MCP.
