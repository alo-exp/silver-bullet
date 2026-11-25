#!/usr/bin/env bash
# Config walk-ups in session-start (trivial-file lookup) and stop-check (transient-path
# patterns) must terminate when the project config disappears after the hook located the
# project (a project deleted while a backgrounded hook still runs). Without their .git /
# "/" stop the walks spin on `dirname /` forever.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$TL_REPO_ROOT/tests/lib/e-core-helpers.sh"

HOOK="$TL_REPO_ROOT/hooks/session-start"
STOP_HOOK="$TL_REPO_ROOT/hooks/stop-check.sh"
export SILVER_BULLET_TEST_HOOK_ENFORCED=1
export SILVER_BULLET_UPDATE_CHECK_DISABLED=1
unset SILVER_BULLET_SESSION_SOURCE SILVER_BULLET_PROMPT_FILE SB_ORCHESTRATOR_WORKER SB_ORCHESTRATOR_PARENT
unset SB_E2E_ENTERPRISE_MATRIX

mkdir -p "$SB_RUNTIME_PLUGIN_CACHE_ROOT/alo-labs/silver-bullet/test"
ec_project

# ---- session-start ----------------------------------------------------------
# With a numeric session-start time and a .planning/workflows directory, the first
# `date +%s` is the workflow-archive clock: after the project lookup and the prerequisite
# probe, before the trivial-file walk. The stub deletes the config there, then answers as
# the real date.
date +%s >"${SB_RUNTIME_STATE_DIR:?}/session-start-time"
mkdir -p "$EC_PROJ/.planning/workflows"
real_date="$(ec_real date)"
tl_stub date "if [[ \"\$*\" == '+%s' && -f '$EC_PROJ/.silver-bullet.json' ]]; then rm -f '$EC_PROJ/.silver-bullet.json'; fi; exec $real_date \"\$@\""
hash -r

tl_run_stdin '{"source":"startup"}' timeout 20 bash -c 'cd "$1" && exec bash "$2"' _ "$EC_PROJ" "$HOOK"
assert_file_absent "config removed mid-hook" "$EC_PROJ/.silver-bullet.json"
if [[ "$TL_STATUS" == 124 ]]; then
  tl_fail "session-start terminates when the config vanishes mid-run (timed out after 20 s)"
else
  tl_pass "session-start terminates when the config vanishes mid-run"
fi
assert_eq "session-start exits 0 when the config vanishes mid-run" 0 "$TL_STATUS"
rm -f "$TL_BIN/date"
hash -r

# ---- stop-check ---------------------------------------------------------------
# A dirty tree sends stop-check into the transient-pattern walk; the git stub deletes the
# config when stop-check reads the porcelain status, then answers as the real git.
ec_cfg '{"config_version":"0.40.0","sb_initiated":true,"project":{"src_pattern":"/src/","active_workflow":"full-dev-cycle"},"skills":{}}'
printf 'silver-context\n' >"${SB_RUNTIME_STATE_DIR:?}/state"
: >"$EC_PROJ/dirty.txt"
real_git="$(ec_real git)"
tl_stub git "if [[ \"\$*\" == *'status --porcelain'* ]]; then rm -f '$EC_PROJ/.silver-bullet.json'; fi; exec $real_git \"\$@\""
hash -r
tl_run_stdin '{"hook_event_name":"Stop"}' timeout 20 bash -c 'cd "$1" && exec bash "$2"' _ "$EC_PROJ" "$STOP_HOOK"
assert_file_absent "stop-check: config removed mid-hook" "$EC_PROJ/.silver-bullet.json"
if [[ "$TL_STATUS" == 124 ]]; then
  tl_fail "stop-check terminates when the config vanishes mid-run (timed out after 20 s)"
else
  tl_pass "stop-check terminates when the config vanishes mid-run"
fi
rm -f "$TL_BIN/git"
hash -r

tl_results
