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

---

## Phase 2 — Global config artifacts

### 2.1 Graphify skill (global)

```bash
test -f ~/.claude/skills/graphify/SKILL.md && grep -q graphify ~/.claude/skills/graphify/SKILL.md && echo OK
```

**Pass:** skill file exists with graphify content.

**Fail:** `graphify install` (no `--project`).

### 2.2 Graphify always-on hooks

```bash
grep -r graphify ~/.claude/CLAUDE.md ~/.claude/settings.json 2>/dev/null | head -3
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
grep AGENTMEMORY_INJECT_CONTEXT=true ~/.agentmemory/.env
grep AGENTMEMORY_EXPORT_ROOT ~/.agentmemory/.env
```

**Pass:** both lines present; export root is absolute.

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
3. Trigger export: `curl -sf -X POST http://localhost:3111/agentmemory/obsidian/export -H 'Content-Type: application/json' -d '{"vaultDir":"'"$(grep AGENTMEMORY_EXPORT_ROOT ~/.agentmemory/.env | cut -d= -f2)"'/memory"}'`
4. From repo root: `graphify update . --no-cluster`
5. `graphify query "jq JSON decision" --budget 2000` — result should include `.agentmemory` nodes.

**Pass:** query returns memory-related nodes.

---

## Appendix — If Silver Bullet is active in a repo

- SB may run `bash scripts/sb-optimize-stack.sh --apply --host claude` for project gitignore, index, and consent timestamps.
- Hooks (`graphify-gate`, `agentmemory-gate`) apply only when `recommended_tools.*.enabled_by_user: true`.
- Global setup remains authoritative for `~/.agentmemory/.env` and `~/.claude.json` MCP.
