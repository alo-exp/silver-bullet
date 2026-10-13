# Self-Verification: RTK + Context Mode in Codex (Global)

Machine-level audit for **OpenAI Codex CLI** — no Silver Bullet prerequisite.

**Purpose:** Verify the **RTK + Context Mode** global stack only. This is **not** Graphify+agentmemory verification — see `docs/graphify-am/verification/` for that stack.

**Setup script:** `bash scripts/optimize-rtk-context-mode.sh --host codex`

---

## Phase 1 — Pre-flight

```bash
which codex && which rtk && which context-mode
node --version   # >= 22.5
```

**Pass:** all binaries on PATH.

---

## Phase 2 — Global artifacts

### 2.1 RTK awareness layer

```bash
grep -qi rtk ~/.codex/AGENTS.md 2>/dev/null && echo OK-agents
test -f ~/.codex/RTK.md && echo OK-rtk-md
```

**Pass:** `AGENTS.md` references RTK.

**Fail:** `rtk init -g --codex`

> **Limitation:** Codex PreToolUse lacks `updatedInput` — RTK does not transparently rewrite shell commands. Savings depend on model following `AGENTS.md` guidance ([openai/codex#18491](https://github.com/openai/codex/issues/18491)).

### 2.2 Context Mode MCP (`~/.codex/config.toml`)

```bash
grep -A3 '^\[mcp_servers\.context-mode\]' ~/.codex/config.toml
grep -q 'hooks = true' ~/.codex/config.toml && echo OK-hooks-feature
```

**Pass:** `[mcp_servers.context-mode]` with `command = "context-mode"`.

**Fail:** `bash scripts/optimize-rtk-context-mode.sh --host codex`

### 2.3 Context Mode hooks (`~/.codex/hooks.json`)

```bash
jq '.hooks.PreToolUse[]?.hooks[]? | select(.command | contains("context-mode"))' ~/.codex/hooks.json
```

**Pass:** at least one `context-mode hook codex` command.

**Fail:** re-run optimizer or copy from `$(npm root -g)/context-mode/configs/codex/hooks.json`

---

## Phase 3 — Doctor

```bash
CONTEXT_MODE_PLATFORM=codex context-mode doctor 2>&1 | grep -E 'PASS|FAIL|WARN' | head -20
```

**Pass:** MCP and hook checks PASS.

---

## Phase 4 — Live session (manual)

1. Restart Codex after config changes.
2. Run shell-heavy task; confirm model uses `ctx_execute` for large reads.
3. `context-mode doctor` shows session activity.

---

## Verdict

| Check | Result |
|-------|--------|
| RTK AGENTS.md | ✅ / ❌ |
| CM config.toml MCP | ✅ / ❌ |
| CM hooks.json | ✅ / ❌ |
| Doctor | ✅ / ❌ |

**Overall:** 🟢 · 🟡 · 🔴

## Known gaps

- RTK on Codex is **prompt-layer only** — no automatic `git status` → `rtk git status` rewrite.
- Context Mode hooks are fully supported.
