# Self-Verification: Graphify + agentmemory in OpenCode (Global)

Machine-level audit for **OpenCode** — no Silver Bullet prerequisite.

**Setup script:** `bash scripts/graphify-am-global-setup.sh --host opencode --apply`

---

## Phase 1 — Pre-flight

```bash
which graphify && which agentmemory && which opencode 2>/dev/null || which oc 2>/dev/null
```

---

## Phase 2 — Global config artifacts

### 2.1 OpenCode config exists

```bash
test -f ~/.config/opencode/opencode.json && jq . ~/.config/opencode/opencode.json >/dev/null && echo OK
```

### 2.2 Graphify plugin + skill

```bash
jq '.plugin // .plugins // empty' ~/.config/opencode/opencode.json 2>/dev/null
ls ~/.config/opencode/skills/graphify/SKILL.md 2>/dev/null || ls ~/.opencode/skills/graphify/SKILL.md 2>/dev/null
```

**Apply:** `graphify install --platform opencode` && `graphify opencode install`

### 2.3 agentmemory MCP (manual — no `connect opencode`)

```bash
jq '.mcp.agentmemory // .mcpServers.agentmemory // empty' ~/.config/opencode/opencode.json
```

**Pass:** stdio MCP block with `npx -y @agentmemory/mcp` and `AGENTMEMORY_URL`.

**Fail:** re-run global setup or merge manually:

```bash
bash scripts/graphify-am-global-setup.sh --host opencode --apply
```

### 2.4 synergy_max `.env`

```bash
grep AGENTMEMORY_EXPORT_ROOT ~/.agentmemory/.env
```

---

## Phase 3 — Server

```bash
curl -sf http://localhost:3111/agentmemory/health
graphify hook status
```

---

## Phase 4 — Manual synergy test (OpenCode UI)

1. Confirm agentmemory MCP tools appear in OpenCode tool list.
2. Save a constraint via MCP.
3. Export + `graphify update . --no-cluster` in your working repo.
4. `graphify query` for the saved topic.

---

## Appendix — If Silver Bullet is active

OpenCode is listed in `multi_agent.identity_tags`. SB project hooks are optional; global `~/.config/opencode/opencode.json` is authoritative for MCP.
