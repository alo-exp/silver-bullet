# Self-Verification: RTK + Context Mode in Hermes (Global) — PARTIAL

Machine-level audit for **Hermes Agent** — no Silver Bullet prerequisite.

**Purpose:** Verify the **RTK + Context Mode** global stack only. This is **not** Graphify+agentmemory verification — see `docs/graphify-am/verification/` for that stack.

**Status: PARTIAL** — RTK has an official Python plugin; Context Mode has **no Hermes adapter** (no `configs/hermes/` in npm package). MCP merge is best-effort only.

**Setup script:** `bash scripts/optimize-rtk-context-mode.sh --host hermes`

**Config root:** `~/.hermes/config.yaml`

---

## Phase 1 — Pre-flight

```bash
which hermes 2>/dev/null || test -d ~/.hermes && echo OK-hermes-home
which rtk && rtk --version
which context-mode
node --version
```

---

## Phase 2 — RTK (supported)

### 2.1 RTK rewrite plugin

```bash
test -d ~/.hermes/plugins/rtk-rewrite && echo OK-plugin-dir
grep -A5 'rtk-rewrite' ~/.hermes/config.yaml
```

**Pass:** `plugins.rtk-rewrite` block with `path: ~/.hermes/plugins/rtk-rewrite`.

**Fail:** `rtk init --agent hermes`

### 2.2 Enable plugin (Hermes v0.11+ opt-in)

```bash
grep -A10 '^plugins:' ~/.hermes/config.yaml | grep -E 'enabled:|rtk-rewrite'
```

**Pass:** `rtk-rewrite` under `plugins.enabled` (or legacy auto-load).

**Fail:** add to `~/.hermes/config.yaml`:

```yaml
plugins:
  enabled:
    - rtk-rewrite
```

---

## Phase 3 — Context Mode (partial / experimental)

### 3.1 MCP block in config.yaml

```bash
grep -A6 'context-mode:' ~/.hermes/config.yaml
```

**Pass:** `mcp_servers.context-mode` with `command: context-mode`.

**Fail:** `bash scripts/optimize-rtk-context-mode.sh --host hermes` (appends managed YAML block)

### 3.2 Doctor — SKIP

```bash
CONTEXT_MODE_PLATFORM=hermes context-mode doctor 2>&1 | head -5
```

**Expected:** no Hermes adapter — **SKIP this check**. Verify MCP manually in a Hermes session.

---

## Phase 4 — Live session (manual)

1. Restart Hermes.
2. Run terminal command `git status` — RTK should rewrite via `pre_tool_call`.
3. If MCP wired, invoke context-mode tools; confirm sandbox works.

---

## Verdict

| Check | Result |
|-------|--------|
| RTK plugin installed | ✅ / ❌ |
| RTK enabled in config | ✅ / ❌ |
| CM MCP YAML (best-effort) | ✅ / ❌ / SKIP |
| CM doctor | SKIP |
| Live RTK rewrite | ✅ / ❌ |

**Overall:** 🟢 RTK only · 🟡 RTK + MCP unverified · 🔴 not wired

## Known gaps

- No `context-mode doctor` platform for Hermes.
- No official Context Mode hooks (`pre_tool_call` routing is MCP-only if at all).
- Remote terminal backends need RTK installed inside the backend (`RTK_HERMES_BACKENDS`).
- Optional PyPI package `rtk-hermes` exists upstream; `rtk init --agent hermes` is canonical.
