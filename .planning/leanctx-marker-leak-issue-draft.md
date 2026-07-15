# LeanCTX upstream issue draft — compression markers written to durable files

**Repo:** https://github.com/yvgude/lean-ctx  
**Status:** Resolved in lean-ctx **v3.9.9** — https://github.com/yvgude/lean-ctx/issues/805 (closed 2026-07-14). Upstream PreToolUse deny for `[lean-ctx:` in Write/Edit payloads; SB keeps `compression-marker-guard.sh` as belt-and-suspenders.

## Title

`bug: PreToolUse should deny Write/Edit payloads containing ctx_read compression markers`

## Summary

When agents use compressed `ctx_read` output as the source for `Write`/`Edit` tool calls, LeanCTX omission placeholders (`... [lean-ctx: omitted N lines]`) and ctx_read file headers (`filename.plan.md [316L]`) are persisted to disk. This corrupts durable documents (e.g. Cursor plan files under `~/.cursor/plans/`).

LeanCTX rules say compression is reversible via `ctx_read(raw=true)` or native Read, but nothing prevents the write path. Global `lean-ctx hook deny` only matches Grep/Glob — not Write/Edit.

## Reproduction

1. Enable LeanCTX MCP + Cursor hooks (`lean-ctx hook redirect` on Read, etc.).
2. Create a multi-section markdown file (e.g. 300+ line plan).
3. As an agent, call `ctx_read(path=..., mode=lines:63-96)` (compressed, `raw=false`).
4. Assemble full file content from compressed slices still containing `[lean-ctx: omitted N lines]` markers.
5. Call `Write` with that assembled string.

**Actual:** File on disk contains omission placeholders and duplicate ctx_read headers; YAML frontmatter may be destroyed.

**Expected:** Either (a) PreToolUse hook denies writes containing `[lean-ctx:` patterns, or (b) ctx_read output is clearly non-persistable (structured metadata separating display text from editable bytes).

## Evidence (Silver Bullet incident)

- Corrupted file: `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md`
- Hook audit: 92 `Write` calls with `[lean-ctx:` markers passed PreToolUse unchecked
- First corruption immediately after `MCP:ctx_read` with `mode=lines:63-96` / `lines:133-176` (`raw=false`), then `Write` with header `router_subagent_surfaces_85bf9f09.plan.md [316L]`

## Suggested fixes (upstream)

1. **Hook deny for Edit|Write|MultiEdit** when payload matches `\[lean-ctx:` (and optionally ctx_read header `\.plan\.md \[\d+L\]`).
2. **Rule template update** in `install_hermes_rules` — explicit "never edit from compressed ctx_read; use raw=true before Write/Edit".
3. **Optional:** `ctx_patch` / write helpers that always expand references before disk write.

## Workaround (downstream)

Silver Bullet adds `hooks/compression-marker-guard.sh` and documents the raw-read-before-edit contract in `docs/LEANCTX.md` and `.cursor/rules/leanctx.mdc`.

## Environment

- lean-ctx 3.9.9+ (fix); 3.9.8 (incident)
- Cursor host, five-tool parallel stack (LeanCTX + RTK + Context Mode)
- macOS
