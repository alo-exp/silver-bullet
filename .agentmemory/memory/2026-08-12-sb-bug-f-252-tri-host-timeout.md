# SB-BUG-F / #252 tri-host timeout

Decision: Add portable `scripts/lib/command-timeout.sh` (GNU timeout → gtimeout → python3 killpg → background watchdog) and wire overall/per-command timeouts into `scripts/run-tri-host-install-smoke.sh` via `SB_TRIHOST_OVERALL_TIMEOUT` / `SB_TRIHOST_CMD_TIMEOUT` / `SB_TRIHOST_DIAG_TIMEOUT`. Loud FAIL on hang (exit 124).

Verified: helper kills 30s stub in ~1s (rc 124); overall timeout=2 loud-fails; `tests/scripts/test-tri-host-install-smoke.sh` 19/19 PASS.
