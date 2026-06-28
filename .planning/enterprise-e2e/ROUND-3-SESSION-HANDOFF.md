# Round 3 Enterprise E2E — Session Handoff

**Updated:** 2026-06-28 (post–Cursor restart resume)

## SB HEAD

`9f89cfb6` — `fix(e2e): restore hook-delivery preflight bash probe fallback`  
Bypass disclaimer: `398209d3` in `scripts/claude-interactive-invoke.expect`

## Active work

- **Row 1** running: `SB_E2E_MATRIX_FORCE=1 bash scripts/run-enterprise-e2e-matrix.sh 1`
- Log: `.e2e-row1-attempt.log` / terminal batch PID ~62086
- **429:** OpenCode proxy weekly limit (not Cursor dashboard); harness sleeps **600s** and retries (`SB_E2E_MATRIX_QUOTA_RETRY_INTERVAL`)
- **`--resume`:** defer until row 1 PASS

## Matrix snapshot (from `.e2e-matrix-live.log`)

| Pass | 5, 9, 10, 12, 13, 17, 18, 19, 20 |
| Fail (prior) | 1, 7, 8 |
| Current | Row **1** in quota retry loop |

## Env

```bash
export SB_E2E_LEDGER_FILE=/Users/shafqat/projects/silver-bullet/repo/.planning/enterprise-e2e/ROUND-3-LEDGER.md
export SB_ROOT=/Users/shafqat/projects/silver-bullet/repo
export SB_TEST_ENTERPRISE_APP_ROOT=/Users/shafqat/projects/enterprise-grade-test-app
cd "$SB_ROOT"
```

## Resume commands

```bash
RTK_DISABLED=1 bash scripts/run-enterprise-e2e-live-test.sh --preflight-only
# when row 1 PASS:
SB_ENTERPRISE_E2E_LIVE=1 bash scripts/run-enterprise-e2e-live-test.sh --resume
bash scripts/monitor-enterprise-e2e-matrix.sh &
bash scripts/watch-enterprise-e2e-tui.sh &
```

## Policies

- Never `claude auth login/logout`
- `install-claude.sh` after harness fixes (done @ `9f89cfb6`)
- Fixture was re-cloned to default path when missing

