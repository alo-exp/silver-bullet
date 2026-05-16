# Silver Bullet v0.35.4 Agents Directory Reorg

## Goal

Reorganize Silver Bullet's generated agent-specific skill bundles under
`agents/<agent-name>/...`, with canonical source content remaining in `skills/`
and agent-specific runtime variants generated for Claude and Codex.

## Working Plan

1. Build a shared renderer for agent bundles from `skills/` into
   `agents/claude` and `agents/codex`.
2. Rewire the Codex and Claude installer/sync flows to consume the new
   `agents/<agent>/` layout while keeping compatibility aliases where needed.
3. Update docs, tests, and bundle-surface assertions to verify the new layout.
4. Run focused tests, then the full verification suite and live e2e smoke.

## Notes

- Preserve the canonical `skills/` source tree.
- Keep runtime-specific behavior isolated to generated bundles and installer
  wiring.
- Do not remove historical planning artifacts yet; this milestone is about the
  active reorg only.
