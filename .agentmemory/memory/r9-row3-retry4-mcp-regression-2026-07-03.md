# R9 row3 retry4 MCP regression (2026-07-03)

## Root cause
- Retry3 and retry4 both ran `enterprise_e2e_prepare_matrix_mcp_env` (23 disabled servers; settings on disk correct).
- Regression: harness wrote **populated** `~/.codex/mcp-needs-auth-cache.json` (timestamps) instead of **{}**, contradicting mitigation doc; `enterprise_e2e_verify_matrix_mcp_env` called `claude mcp list` which re-filled cache before spawn.
- `matrix-claude-settings.json` was a full clone of user `settings.json` (hooks noise); `--settings` path inconsistent with slim env+disable overlay.
- Retry4: MCP banner + 0 tokens; expect dismiss did not log (digit-prefixed banner). Retry3: resumed task menu (~824 tokens) — non-deterministic session state.

## Fix
- Clear cache to `{}`; slim matrix settings (env + disabledMcp* only); per-row prepare+verify; re-clear cache after verify; expect regex for `N MCP servers`; CLAUDE_SETTINGS_FILE in clean-env spawn.
- Dry-run: `matrix MCP verify: OK`, `CACHE_AFTER={}`.

## Pilot
- Full row3 re-run deferred; operator runbook: `.planning/enterprise-e2e/.r9-mcp-operator-runbook.md`.
