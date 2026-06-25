# Self-Verification: Graphify + agentmemory in Hermes (Global)

Machine-level audit for **Hermes Agent** — no Silver Bullet prerequisite. Produces a pass/fail report per check.

**Setup script:** `bash scripts/graphify-am-global-setup.sh --host hermes --apply`
**Host detection:** `~/.hermes/config.yaml` exists OR `~/.hermes/` directory exists ⇒ host is `hermes`. Setup script skips silently otherwise.

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

### 1.3 Hermes CLI

```bash
which hermes 2>/dev/null
```

**Pass:** binary on PATH.

**Fail:** install per upstream docs (`curl -fsSL https://install.hermes-agent.dev | sh` or similar).

### 1.4 Hermes home exists

```bash
test -d ~/.hermes && echo OK
```

**Pass:** `OK` printed.

**Fail:** install Hermes or create `~/.hermes/` manually.

### 1.5 gitleaks

```bash
which gitleaks && gitleaks version 2>/dev/null | head -1
```

**Pass:** binary on PATH (bridge second-line secret scan).

**Fail:** `brew install gitleaks` (macOS) — global setup attempts install on `--apply`.

---

## Phase 2 — Global config artifacts

### 2.1 Graphify skill

```bash
test -f ~/.hermes/skills/graphify/SKILL.md && grep -q graphify ~/.hermes/skills/graphify/SKILL.md && echo OK
```

**Pass:** `OK` — skill file exists and contains graphify content.

> Hermes loads skills on demand from `~/.hermes/skills/`. There is no separate `CLAUDE.md` / `AGENTS.md` "always-on" hook — the skill itself is the wiring.

**Fail:** `graphify install --platform hermes`.

### 2.2 Graphify always-on (skill manifest)

```bash
ls ~/.hermes/skills/graphify/.graphify_version 2>/dev/null && cat ~/.hermes/skills/graphify/.graphify_version 2>/dev/null
```

**Pass:** version file present (e.g. `0.8.37`). This confirms the install wrote the skill to the **global** path, not the cwd.

**Warn if missing:** the upstream `graphify hermes install` may have written to `./.hermes/skills/` (cwd) instead of `~/.hermes/skills/` — same upstream bug as `codex install` / `opencode install`. If this happens, move the files:

```bash
mkdir -p ~/.hermes/skills/graphify
mv ./.hermes/skills/graphify/* ~/.hermes/skills/graphify/
```

### 2.3 agentmemory MCP (YAML merge)

```bash
grep -q '^\s*mcp_servers:' ~/.hermes/config.yaml 2>/dev/null && \
  grep -A 10 '^\s*mcp_servers:' ~/.hermes/config.yaml 2>/dev/null | grep -q 'agentmemory:' && \
  grep -A 10 '^\s*mcp_servers:' ~/.hermes/config.yaml 2>/dev/null | grep -q '@agentmemory/mcp' && \
  echo OK
```

**Pass:** `OK` — `mcp_servers.agentmemory` block present with `command: npx` and `args: ["-y", "@agentmemory/mcp"]`.

**Fail (manual YAML merge — `agentmemory connect hermes` reports "yaml-merge-not-implemented"):**

```bash
# Backup first
cp ~/.hermes/config.yaml ~/.hermes/config.yaml.bak

# Append (or merge with yq if installed) the agentmemory MCP block:
cat >> ~/.hermes/config.yaml <<'YAML'

mcp_servers:
  agentmemory:
    command: npx
    args: ["-y", "@agentmemory/mcp"]

memory:
  provider: agentmemory
YAML
```

> **Why manual?** As of agentmemory 0.9.27, `agentmemory connect hermes` reports: *"Hermes uses YAML config. Automated merge isn't implemented yet — manual install required."*

### 2.4 synergy_max `.env`

```bash
test -f ~/.agentmemory/.env && grep -q '^AGENTMEMORY_INJECT_CONTEXT=true' ~/.agentmemory/.env && grep -q '^AGENTMEMORY_EXPORT_ROOT=' ~/.agentmemory/.env && echo OK
```

**Pass:** `OK` printed; `AGENTMEMORY_EXPORT_ROOT` value is absolute.

**Fail:** `bash scripts/graphify-am-global-setup.sh --host hermes --apply`.

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

**Warn if missing:** the plist exists at `~/Library/LaunchAgents/com.agentmemory.server.plist` but is not loaded. Bootstrap it manually.

### 3.3 Git hooks (global template)

```bash
git rev-parse --is-inside-work-tree >/dev/null 2>&1 && graphify hook status
```

**Pass:** `post-commit` and `post-checkout` installed (run inside any repo).

**Fail:** `graphify hook install`.

### 3.4 Bridge (project-bound)

```bash
launchctl list 2>/dev/null | grep com.agentmemory.bridge
```

**Pass:** bridge PID listed. The bridge auto-commits `.agentmemory/memory/` snapshots to the repo pointed at by `AGENTMEMORY_REPO_ROOT` in `~/Library/LaunchAgents/com.agentmemory.bridge.plist`.

**Warn if missing:** bridge only applies when `--repo <path>` was passed to global setup. To enable later:

```bash
bash scripts/graphify-am-global-setup.sh --host hermes --apply --repo /path/to/project
```

---

## Phase 4 — Manual synergy test (Hermes UI)

1. Open a git repo with code. The repo's `.gitignore` must whitelist `.agentmemory/memory/`, `.agentmemory/snapshots/`, and `.agentmemory/profile.md` (Silver Bullet's `.gitignore` already does this in the managed block).
2. In Hermes, invoke the graphify skill (`/graphify`) and use the agentmemory MCP tools to capture a short note (e.g. "we use jq for all JSON in this repo").
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

> If the Hermes CLI is not installed (Phase 1.3 warning), invoke `graphify update` and `graphify query` from a regular terminal — they read the same `graphify-out/graph.json`.

---

## Appendix — If Silver Bullet is active in a repo

- Hermes is in `multi_agent.identity_tags`. SB project hooks are optional; global `~/.hermes/config.yaml` and `~/.hermes/skills/` are independent of `.silver-bullet.json`.
- `SILVER_BULLET_RUNTIME=hermes bash scripts/sb-optimize-stack.sh --apply --host hermes` adds project-level optimization (gitignore block, index refresh, consent timestamps) when opted in.
- Hooks (`graphify-gate`, `agentmemory-gate`) apply only when `recommended_tools.*.enabled_by_user: true`.
- Global setup remains authoritative for `~/.agentmemory/.env` and `~/.hermes/config.yaml` (MCP merge).

## Notes

- Hermes loads skills on demand from `~/.hermes/skills/`. There is no separate `CLAUDE.md` / `AGENTS.md` "always-on" hook — the skill is the wiring.
- agentmemory uses **MCP** in Hermes (the `mcp_servers.agentmemory` block in `~/.hermes/config.yaml`). The setup script does not auto-merge for Hermes — see Phase 2.3 for the manual YAML snippet.
- The `memory.provider: agentmemory` line under the `memory:` key is recommended by `agentmemory connect hermes` so Hermes's built-in memory layer delegates to agentmemory. It's optional but recommended for unified recall.
- The verification doc mirrors the Claude/Codex/OpenCode verification docs 1:1 except for the skill-loading mechanism (Hermes loads skills, others use rules/plugins) and the manual YAML-merge requirement.
- See `docs/graphify-am/PLATFORM-MATRIX.md` for the canonical install command set and artifact paths.