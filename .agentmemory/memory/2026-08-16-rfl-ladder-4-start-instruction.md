# Decision — RFL ladder-4 start instruction filed (not started)

Process + Cursor agent-def worker. Stay on `main`. Ladder 4 **not** started. Ladder 3 still owned by parent after ACCEPT `067eb2ce-4301-433e-9aa3-205ca711a0a7`. Frozen plan copies not edited.

## Artifacts

- Instruction: `.planning/rfl-router-subagent-surfaces-85bf9f09-20260812/RFL-LADDER-4-START.md`

## User lock (not executed)

After ladder 3 is 100% complete, parent starts ladder 4 with the same High+ rungs and order as ladder 3. Codex/Claude quota → Cursor Task with existing `subagent_type`, `model` inherit, `run_in_background: true`. Do not QUOTA-ABORT.

## Agent defs (inventory)

Already present in `~/.cursor/agents/` (none added):

- `sb-opus-5-high` → `claude-opus-5-thinking-high`
- `sb-opus-5-xhigh` → `claude-opus-5-thinking-xhigh`
- `sb-opus-5-max` → `claude-opus-5-thinking-max`
- `sb-gpt-5-6-sol-high` → `gpt-5.6-sol-high`
- `sb-gpt-5-6-sol-xhigh` → `gpt-5.6-sol-xhigh`
- `sb-gpt-5-6-sol-max` → `gpt-5.6-sol-max`

No Fast. Tests not run (no def/lib change). `include_max: false` still keeps these max defs because `rfl_effort_maps` keys include `max` for opus-5 and gpt-5.6-sol.
