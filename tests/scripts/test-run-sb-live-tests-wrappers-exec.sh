#!/usr/bin/env bash
# Execute scripts/run-sb-live-tests-{claude,kay}.sh from a staged tree whose live suites are
# stubs that record the environment they were launched with. Verifies defaults, caller
# overrides, ordering and that a failing first suite stops the wrapper.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

stage() { # <dir> <wrapper>
  local d="$1" w="$2"
  mkdir -p "$d/scripts" "$d/tests/live" "$d/tests/e2e-live"
  cp "$TL_REPO_ROOT/scripts/$w" "$d/scripts/"
  local suite
  for suite in live e2e-live; do
    local name=run-live-tests.sh; [[ "$suite" == e2e-live ]] && name=run-e2e-live-tests.sh
    cat >"$d/tests/$suite/$name" <<EOS
#!/usr/bin/env bash
{
  echo "suite=$suite"
  env | grep -E '^(SB_LIVE_|SB_E2E_|SB_DISABLE_|CODEX_REASONING)' | sort
} >>"\${STUB_LOG:?}"
[[ "\${STUB_FAIL_SUITE:-}" == "$suite" ]] && exit 7
exit 0
EOS
  done
}

run_wrapper() { # <staged dir> <wrapper> [env...]
  local d="$1" w="$2"; shift 2
  : >"$TL_TMP/stub.log"
  tl_run env -u SB_LIVE_AGENT -u SB_E2E_LIVE_AGENT -u SB_LIVE_RUNTIMES -u SB_E2E_LIVE_RUNTIMES \
    -u SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT -u SB_DISABLE_MINIMAX_IO_TESTS -u SB_LIVE_CODEX_MODEL_PROVIDER \
    -u SB_LIVE_CODEX_MODEL -u SB_LIVE_CODEX_REASONING_EFFORT -u CODEX_REASONING_EFFORT \
    STUB_LOG="$TL_TMP/stub.log" "$@" bash "$d/scripts/$w"
  LOG="$(cat "$TL_TMP/stub.log")"
}

# ---- claude ----
C="$TL_TMP/claude"; stage "$C" run-sb-live-tests-claude.sh
run_wrapper "$C" run-sb-live-tests-claude.sh
assert_eq "claude: exits 0" 0 "$TL_STATUS"
assert_contains "claude: live suite first" "$LOG" "suite=live"
assert_contains "claude: e2e suite second" "$LOG" "suite=e2e-live"
assert_eq "claude: live suite runs before e2e" "suite=live" "$(grep -m1 '^suite=' <<<"$LOG")"
assert_contains "claude: agent default" "$LOG" "SB_LIVE_AGENT=claude"
assert_contains "claude: e2e agent default" "$LOG" "SB_E2E_LIVE_AGENT=claude"
assert_contains "claude: runtimes default" "$LOG" "SB_LIVE_RUNTIMES=claude"
assert_contains "claude: e2e runtimes default" "$LOG" "SB_E2E_LIVE_RUNTIMES=claude"
assert_contains "claude: settings export skipped by default" "$LOG" "SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT=1"
assert_eq "claude: both suites ran once" 2 "$(grep -c '^suite=' <<<"$LOG")"

run_wrapper "$C" run-sb-live-tests-claude.sh SB_LIVE_AGENT=other SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT=0
assert_contains "claude: caller agent override kept" "$LOG" "SB_LIVE_AGENT=other"
assert_contains "claude: caller skip-export override kept" "$LOG" "SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT=0"

run_wrapper "$C" run-sb-live-tests-claude.sh STUB_FAIL_SUITE=live
assert_eq "claude: failing live suite propagates exit 7" 7 "$TL_STATUS"
assert_eq "claude: e2e suite skipped after live failure" 1 "$(grep -c '^suite=' <<<"$LOG")"

# ---- kay ----
K="$TL_TMP/kay"; stage "$K" run-sb-live-tests-kay.sh
run_wrapper "$K" run-sb-live-tests-kay.sh
assert_eq "kay: exits 0" 0 "$TL_STATUS"
assert_contains "kay: agent default" "$LOG" "SB_LIVE_AGENT=kay"
assert_contains "kay: e2e agent default" "$LOG" "SB_E2E_LIVE_AGENT=kay"
assert_contains "kay: runtimes default" "$LOG" "SB_LIVE_RUNTIMES=kay"
assert_contains "kay: e2e runtimes default" "$LOG" "SB_E2E_LIVE_RUNTIMES=kay"
assert_contains "kay: minimax io tests enabled" "$LOG" "SB_DISABLE_MINIMAX_IO_TESTS=0"
assert_contains "kay: codex provider" "$LOG" "SB_LIVE_CODEX_MODEL_PROVIDER=minimax"
assert_contains "kay: codex model" "$LOG" "SB_LIVE_CODEX_MODEL=MiniMax-M3"
assert_contains "kay: reasoning effort" "$LOG" "SB_LIVE_CODEX_REASONING_EFFORT=low"
assert_contains "kay: codex reasoning effort follows" "$LOG" "CODEX_REASONING_EFFORT=low"

run_wrapper "$K" run-sb-live-tests-kay.sh SB_LIVE_CODEX_REASONING_EFFORT=high
assert_contains "kay: CODEX effort derives from overridden live effort" "$LOG" "CODEX_REASONING_EFFORT=high"
run_wrapper "$K" run-sb-live-tests-kay.sh SB_LIVE_CODEX_REASONING_EFFORT=high CODEX_REASONING_EFFORT=medium
assert_contains "kay: explicit CODEX effort wins" "$LOG" "CODEX_REASONING_EFFORT=medium"

run_wrapper "$K" run-sb-live-tests-kay.sh STUB_FAIL_SUITE=live
assert_eq "kay: failing live suite propagates" 7 "$TL_STATUS"
run_wrapper "$K" run-sb-live-tests-kay.sh STUB_FAIL_SUITE=e2e-live
assert_eq "kay: failing e2e suite propagates" 7 "$TL_STATUS"
assert_eq "kay: both suites ran before e2e failure" 2 "$(grep -c '^suite=' <<<"$LOG")"

tl_results
