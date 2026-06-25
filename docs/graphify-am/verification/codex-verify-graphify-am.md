# Self-Verification: Graphify + agentmemory in Codex (Global)

Machine-level audit for **OpenAI Codex CLI** — no Silver Bullet prerequisite.

**Setup script:** `bash scripts/graphify-am-global-setup.sh --host codex --apply`

---

## Phase 1 — Pre-flight

```bash
which graphify && which agentmemory && which codex
```

Install gaps: `uv tool install graphifyy`, `npm install -g @agentmemory/agentmemory`, Codex per upstream docs.

---

## Phase 2 — Global config artifacts

### 2.1 Graphify skill + always-on

```bash
test -f ~/.codex/skills/graphify/SKILL.md 2>/dev/null || ls ~/.codex/skills/graphify/ 2>/dev/null
grep -i graphify ~/.codex/AGENTS.md 2>/dev/null | head -2
```

**Apply:** `graphify install --platform codex` then `graphify codex install` (no `--project`).

### 2.2 agentmemory plugin + MCP

```bash
grep -i agentmemory ~/.codex/config.toml
codex plugin list 2>/dev/null | grep -i agentmemory
```

**Apply:**

```bash
codex plugin marketplace add rohitg00/agentmemory
codex plugin add agentmemory@agentmemory
agentmemory connect codex --with-hooks
```

### 2.3 `multi_agent` feature (parallel extraction)

```bash
grep -E '^multi_agent\s*=\s*true' ~/.codex/config.toml
```

**Fail:** add under `[features]`: `multi_agent = true`

### 2.4 synergy_max `.env`

```bash
grep AGENTMEMORY_INJECT_CONTEXT=true ~/.agentmemory/.env
```

---

## Phase 3 — Server and hooks

```bash
curl -sf http://localhost:3111/agentmemory/health
graphify hook status
launchctl list 2>/dev/null | grep com.agentmemory.server || true
```

---

## Phase 4 — Manual synergy test (Codex UI)

1. In a repo, use agentmemory tools to capture a short note.
2. Export obsidian vault to `AGENTMEMORY_EXPORT_ROOT/memory`.
3. `graphify update . --no-cluster`
4. `graphify query "<note topic>" --budget 2000` — expect `.agentmemory` in results.

---

## Appendix — If Silver Bullet is active

`SILVER_BULLET_RUNTIME=codex bash scripts/sb-optimize-stack.sh --apply --host codex` adds project-level optimization when opted in. Global `~/.codex/config.toml` wiring is unchanged.
