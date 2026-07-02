# R9 smoke retry 2 triage (2026-07-03)

## Verdict
RED 2/4 workflow fail; 0 §5b commits on `enterprise-grade-test-app-round9-claude@8482e60`.

## Root cause (evidence)
- Row attempt logs (`SB_ROOT/.e2e-row{1,3,6,11}-attempt.log`): Claude TUI stayed at **0 tokens**; sessions ended in ~25–30s without creating `.planning/workflows/*` evidence files at matrix gate.
- **Not** evidence mtime race: `matrix_evidence_ready` was never satisfied because files were absent.
- **MCP:** TUI showed **17 MCP servers need authentication** — graphify/agentmemory tool gates could not run (row 6 grep hits were skill rule text in UI, not MCP).
- **Harness:** `CLAUDE_PROMPT_COUNT` carried `--continue` across smoke rows after aborted row 1; monitor loop fired **SMOKE_DONE** on stale pre-retry `=== Matrix summary ===`.

## Fixes landed (repo)
- `scripts/enterprise-e2e/matrix.sh`: `export CLAUDE_PROMPT_COUNT=0` per row attempt.
- `.e2e-r9-claude-monitor-loop.sh`: SMOKE_DONE only on retry-slice of matrix log.

## Next
Pilot row 3 only after MCP auth; sync SB_ROOT; then retry 3 smoke — do not auto-launch.
