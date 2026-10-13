# agentmemory — Cursor subagent defs for Opus XHigh/Max + Grok 4.6 Extra High (2026-08-16)

Decision: Task Extra High / Max rungs must launch via custom `subagent_type` (`sb-opus-5-xhigh`, `sb-opus-5-max`, `sb-grok-4-6-xhigh`), not Task `model:` (enum only has High for those families). No Fast slugs.

Live Cursor CLI slugs verified with `agent --list-models`:
- `claude-opus-5-thinking-high` / `thinking-xhigh` / `thinking-max`
- `cursor-grok-4.6-high` / `cursor-grok-4.6-xhigh` (no unprefixed `grok-4.6-xhigh`)
- `glm-5.2-max`, `kimi-k3-max` (no `*-xhigh` slug; xhigh maps to max)

Created/kept under `~/.cursor/agents/` matching High frontmatter. Source of truth: `scripts/lib/cursor-sb-agents/cursor_sb_agents_lib.py` + `.silver-bullet.json` `cursor_sb_agents.rfl_effort_maps`. Stayed on main. Did not commit. Did not launch Extra High/Max reviews.
