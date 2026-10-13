# Self-Verification: Graphify + agentmemory in OpenCode (Global)

Machine-level audit for **OpenCode** — no Silver Bullet prerequisite. Produces a pass/fail report per check.

**Setup script:** `bash scripts/graphify-am-global-setup.sh --host opencode --apply`
**Host detection:** `~/.config/opencode/opencode.json` exists ⇒ host is `opencode`. Setup script skips silently otherwise.

---

## Phase 1 — Pre-flight (read-only)

### 1.1 Graphify CLI

```bash
which graphify && graphify --version 2>/dev/null | head -1
```

**Pass:** binary on PATH.

**Fail:** `uv tool install graphifyy` or `pipx install graphifyy`.

### 1.2 agentmemory CLI

```bash
which agentmemory && agentmemory --version 2>/dev/null | head -1
```

**Pass:** binary on PATH.

**Fail:** `npm install -g @agentmemory/agentmemory`.

### 1.3 OpenCode CLI

```bash
which opencode 2>/dev/null || which oc 2>/dev/null
```

**Pass:** binary on PATH (either `opencode` or `oc`).

**Fail:** install per upstream docs.

> **Warn (acceptable):** the OpenCode binary is not required to PASS global setup — config files alone are authoritative. The CLI is only needed to invoke `opencode` for the manual synergy test (Phase 4). The setup script writes to `~/.config/opencode/opencode.json` and `~/.config/opencode/skills/` regardless.

### 1.4 OpenCode home exists

```bash
test -d ~/.config/opencode && echo OK
```

**Pass:** `OK` printed.

**Fail:** install OpenCode or create `~/.config/opencode/` manually.

### 1.5 gitleaks

```bash
which gitleaks && gitleaks version 2>/dev/null | head -1
```

**Pass:** binary on PATH (bridge second-line secret scan).

**Fail:** `brew install gitleaks` (macOS) — global setup attempts install on `--apply`.

---

## Phase 2 — Global config artifacts

### 2.1 OpenCode config valid

```bash
test -f ~/.config/opencode/opencode.json && jq . ~/.config/opencode/opencode.json >/dev/null && echo OK
```

**Pass:** `OK` — file parses as valid JSON.

**Fail:** back up the existing file, then re-run global setup:

```bash
bash scripts/graphify-am-global-setup.sh --host opencode --apply
```

> Note: `opencode.jsonc` is a separate optional stub (commented JSON). The authoritative config is `opencode.json`.

### 2.2 Graphify skill (global)

```bash
test -f ~/.config/opencode/skills/graphify/SKILL.md && grep -q graphify ~/.config/opencode/skills/graphify/SKILL.md && echo OK
```

**Pass:** `OK` — skill file exists with graphify content.

**Fail:** `graphify install --platform opencode`.

### 2.3 Graphify always-on (plugin)

```bash
grep -q 'graphify' ~/.config/opencode/opencode.json 2>/dev/null && echo OK-plugin-ref || echo OK-plugin-missing
```

**Pass (full):** `OK-plugin-ref` — `opencode.json` references graphify (the `graphify opencode install` command appends a graphify section to the `plugin` array and registers a `tool.execute.before` hook).

**Pass (partial):** `OK-plugin-missing` — only the skill is present; the auto-trigger before tool calls is not wired. Acceptable if you invoke `graphify query` manually.

**Fail:** `graphify opencode install` to wire the plugin layer.

### 2.4 agentmemory MCP server (manual merge)

```bash
jq -e '.mcp.agentmemory // .mcpServers.agentmemory // empty' ~/.config/opencode/opencode.json 2>/dev/null | \
  grep -q '@agentmemory/mcp' && \
  jq -e '.mcp.agentmemory.env.AGENTMEMORY_URL // .mcpServers.agentmemory.env.AGENTMEMORY_URL // empty' ~/.config/opencode/opencode.json 2>/dev/null | grep -q localhost:3111 && echo OK
```

**Pass:** `OK` — stdio MCP block for agentmemory is present with `npx -y @agentmemory/mcp` args and `AGENTMEMORY_URL` pointing at the local server.

**Fail (no `agentmemory connect opencode` — must merge manually):**

```bash
bash scripts/graphify-am-global-setup.sh --host opencode --apply
# or manually:
jq '.mcp.agentmemory = {
  "type": "stdio",
  "command": "npx",
  "args": ["-y", "@agentmemory/mcp"],
  "env": { "AGENTMEMORY_URL": "http://localhost:3111" }
}' ~/.config/opencode/opencode.json > /tmp/opencode.json && mv /tmp/opencode.json ~/.config/opencode/opencode.json
```

### 2.5 synergy_max `.env`

```bash
test -f ~/.agentmemory/.env && grep -q '^AGENTMEMORY_INJECT_CONTEXT=true' ~/.agentmemory/.env && grep -q '^AGENTMEMORY_EXPORT_ROOT=' ~/.agentmemory/.env && echo OK
```

**Pass:** `OK` printed; `AGENTMEMORY_EXPORT_ROOT` value is absolute.

**Fail:** `bash scripts/graphify-am-global-setup.sh --host opencode --apply`.

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

### 3.4 Bridge (project-bound)

```bash
launchctl list 2>/dev/null | grep com.agentmemory.bridge
```

**Pass:** bridge PID listed. The bridge auto-commits `.agentmemory/memory/` snapshots to the repo pointed at by `AGENTMEMORY_REPO_ROOT` in `~/Library/LaunchAgents/com.agentmemory.bridge.plist`.

**Warn if missing:** bridge only applies when `--repo <path>` was passed to global setup. To enable later:

```bash
bash scripts/graphify-am-global-setup.sh --host opencode --apply --repo /path/to/project
```

---

## Phase 4 — Manual synergy test (OpenCode UI)

1. Open a git repo with code. The repo's `.gitignore` must whitelist `.agentmemory/memory/`, `.agentmemory/snapshots/`, and `.agentmemory/profile.md` (Silver Bullet's `.gitignore` already does this in the managed block).
2. In OpenCode, use agentmemory MCP tools to capture a short note (e.g. "we use jq for all JSON in this repo").
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

> If the OpenCode CLI is not installed (Phase 1.3 warning), invoke `graphify update` and `graphify query` from a regular terminal — they read the same `graphify-out/graph.json`.

---

## Appendix — If Silver Bullet is active in a repo

- OpenCode is listed in `multi_agent.identity_tags`. SB project hooks are optional; global `~/.config/opencode/opencode.json` is authoritative for MCP.
- `SILVER_BULLET_RUNTIME=opencode bash scripts/sb-optimize-stack.sh --apply --host opencode` adds project-level optimization (gitignore block, index refresh, consent timestamps) when opted in.
- Hooks (`graphify-gate`, `agentmemory-gate`) apply only when `recommended_tools.*.enabled_by_user: true`.
- Global setup remains authoritative for `~/.agentmemory/.env` and `~/.config/opencode/opencode.json` (MCP merge).

## Notes

- Unlike Claude/Codex, OpenCode has **no `agentmemory connect opencode`** installer — the agentmemory MCP block must be merged into `opencode.json` manually or via the global setup script's `ga_opencode_merge_agentmemory_mcp` helper. The check in Phase 2.4 validates the final merged shape.
- `opencode.jsonc` (commented JSON) is supported by OpenCode but rarely used — treat `opencode.json` as authoritative.
- The verification doc mirrors the Claude/Codex verification docs 1:1 except for the JSON config shape (vs TOML vs YAML/MD) and the manual-MCP requirement.
- See `docs/graphify-am/PLATFORM-MATRIX.md` for the canonical install command set and artifact paths.