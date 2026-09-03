# Self-Verification: RTK + Context Mode in Cursor (Global)

Machine-level audit for **Cursor** — global `~/.cursor/` config only (not project `.cursor/`).

**Purpose:** Verify the **RTK + Context Mode** global stack only. This is **not** Graphify+agentmemory verification — see `docs/graphify-am/verification/` for that stack.

**Setup script:** `bash scripts/optimize-rtk-context-mode.sh --host cursor`

Extended reference: [rtk-cm-cursor-verification.md](../rtk-cm-cursor-verification.md)

---

## Phase 1 — Pre-flight

```bash
which rtk && rtk --version && rtk gain --help >/dev/null && echo OK-rtk
which context-mode
node --version
```

**Pass:** RTK >= 0.42, Context Mode CLI present, Node >= 22.5.

---

## Phase 2 — Global artifacts

### 2.1 Context Mode MCP (`~/.cursor/mcp.json`)

```bash
jq '.mcpServers | keys[]' ~/.cursor/mcp.json | grep -x context-mode
```

**Fail fix:** `bash scripts/optimize-rtk-context-mode.sh --host cursor`

### 2.2 Context Mode hooks

```bash
jq '.hooks.preToolUse[] | select(.command | contains("context-mode"))' ~/.cursor/hooks.json
```

### 2.3 RTK hook + allow-list

```bash
jq '.hooks.preToolUse[] | select(.command | contains("rtk"))' ~/.cursor/hooks.json
jq '.permissions.allow | length' ~/.cursor/cli-config.json
echo '{"tool_name":"Shell","tool_input":{"command":"git status"}}' | rtk hook cursor
```

**Pass:** RTK entry with matcher `Shell`; allow-list >= 50 entries; hook returns `updated_input.command` with `rtk git status`.

### 2.4 Global rules

```bash
ls ~/.cursor/rules/ | grep -E 'context-mode|token-compression'
```

**Fail fix:** `bash scripts/install-recommended-tools-global.sh --host cursor --global`

### 2.5 Hook ordering

```bash
jq '.hooks.preToolUse | to_entries[] | {idx: .key, cmd: (.value.command | split(" ")[0])}' ~/.cursor/hooks.json | head -10
```

**Pass:** `rtk` index < `context-mode` index.

---

## Phase 3 — Doctor

```bash
CONTEXT_MODE_PLATFORM=cursor context-mode doctor 2>&1 | grep -E 'PASS|FAIL|WARN'
```

Always set `CONTEXT_MODE_PLATFORM=cursor` — doctor may guess wrong platform otherwise.

---

## Phase 4 — Live session (manual)

Ask Cursor: "Run `git status`, then `mcp__context-mode__ctx_stats`."

**Pass:** compressed git output; ctx_stats succeeds.

---

## Verdict

| Check | Result |
|-------|--------|
| RTK binary + hook | ✅ / ❌ |
| Allow-list coupling | ✅ / ❌ |
| CM MCP + hooks | ✅ / ❌ |
| Global rules | ✅ / ❌ |
| Hook order | ✅ / ❌ |
| Doctor + live | ✅ / ❌ |

## Known gaps

- Cursor does not surface hook `additional_context` ([#155689](https://forum.cursor.com/t/native-posttooluse-hooks-accept-and-log-additional-context-successfully-but-the-injected-context-is-not-surfaced-to-the-model/155689)) — rules required.
- Repo-local `.cursor/hooks.json` overrides global — remove for personal global wiring.
