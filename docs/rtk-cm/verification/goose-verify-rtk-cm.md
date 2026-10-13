# Self-Verification: RTK + Context Mode in Goose — UNSUPPORTED (SKIP)

Machine-level audit for **Goose** (Block) — documents honest upstream limitations.

**Purpose:** Verify RTK + Context Mode support status only. This is **not** Graphify+agentmemory verification — see `docs/graphify-am/verification/` for that stack.

**Status: UNSUPPORTED** — Neither [rtk-ai/rtk](https://github.com/rtk-ai/rtk) nor [context-mode](https://github.com/mksglu/context-mode) ship Goose integrations as of 2026-06. Do **not** write fake `~/.config/goose/` wiring — Goose will not read it.

**Setup script:** `bash scripts/optimize-rtk-context-mode.sh --host goose` — logs SKIP only.

---

## Phase 1 — Confirm unsupported (expected PASS for honesty)

```bash
# RTK hooks index — no goose/ directory
curl -fsSL https://api.github.com/repos/rtk-ai/rtk/contents/hooks 2>/dev/null | jq -r '.[].name' | grep -i goose || echo "EXPECTED: no goose in RTK hooks"

# Context Mode npm package — no configs/goose/
CM_PKG="$(npm root -g 2>/dev/null)/context-mode"
test -d "$CM_PKG/configs/goose" && echo UNEXPECTED || echo "EXPECTED: no goose in context-mode"
```

**Pass (for SKIP):** both commands show no Goose integration.

---

## Phase 2 — Do NOT run

The optimizer **must not** create:

- `~/.config/goose/config.yaml` entries for RTK or Context Mode
- Hook scripts fetched from non-existent URLs
- MCP blocks that Goose does not load

If prior sessions wrote such files, remove them to avoid false confidence.

---

## Workarounds (manual, outside RTK/CM stack)

| Approach | Notes |
|----------|-------|
| Use **Pi** runtime | Goose maps to Pi upstream for some tools; RTK supports `rtk init --agent pi` for Pi-native sessions |
| Shell discipline | Run `rtk git status` manually in terminal before pasting to Goose |
| Wait for upstream | File issues on rtk-ai/rtk and mksglu/context-mode for Goose hook/plugin support |

For Graphify+agentmemory on Goose, see `docs/graphify-am/verification/goose-verify-graphify-am.md`.

---

## Verdict

| Check | Result |
|-------|--------|
| RTK upstream Goose support | SKIP (unsupported) |
| CM upstream Goose support | SKIP (unsupported) |
| Optimizer skips goose | ✅ / ❌ |
| No fake config files | ✅ / ❌ |

**Overall:** ⏭️ **SKIP** — use Claude, Codex, Cursor, or OpenCode for full RTK+CM stack.

## Cross-reference

- [docs/rtk-cm/README.md](../README.md) — supported hosts
- [docs/RTK.md](../../RTK.md) — Pi/Goose note
