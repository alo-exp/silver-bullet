# R9 MCP unblock operator run (2026-07-03)

## MCP gate
- **Cleared (automated):** `enterprise_e2e_prepare_matrix_mcp_env` + isolated `CLAUDE_CONFIG_DIR` at SB_ROOT `.planning/enterprise-e2e/.r9-claude-config/` — `claude mcp list` shows agentmemory-only Connected; pilot logs **0** hits on 「MCP servers need authentication」.

## Pilot row 3
- **FAIL:** Interactive TUI stuck in first-run onboarding (API key disclaimer → login method / OAuth browser URL) before `/silver` prompt; no `feature-currency.md`; §5b commits 0 @ baseline 8482e60.

## Harness fixes
- `test-app-branch.sh`: set -e safe baseline/branch export.
- `.r9-resume-after-mcp.sh`: `export SB_TEST_ENTERPRISE_APP_ROOT="$WT"`.
- `claude-interactive-invoke.expect`: onboarding dismiss (Esc login method; OAuth detect).
- `.r9-pilot-row3-launch-inner.sh`: durable driver script.

## Next
- Token gateway + expect: reach ❯ with tokens >0 without OAuth; re-pilot row 3; then smoke retry 3.
