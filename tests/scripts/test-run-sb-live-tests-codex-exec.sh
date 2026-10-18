#!/usr/bin/env bash
# run-sb-live-tests-codex.sh executed against stub live runners (never the real
# live suites): environment defaults, caller overrides, ordering and failure
# propagation.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

T="$TL_TMP/tree"
mkdir -p "$T/scripts" "$T/tests/live" "$T/tests/e2e-live"
cp "$TL_REPO_ROOT/scripts/run-sb-live-tests-codex.sh" "$T/scripts/"
LOG="$TL_TMP/runs.log"

make_runner() {
  local path="$1" name="$2" rc="${3:-0}"
  cat >"$path" <<RUN
#!/usr/bin/env bash
{
  echo "$name"
  for v in SB_LIVE_AGENT SB_E2E_LIVE_AGENT SB_LIVE_RUNTIMES SB_E2E_LIVE_RUNTIMES \\
    SB_DISABLE_MINIMAX_IO_TESTS SB_LIVE_CODEX_MODEL_PROVIDER SB_LIVE_CODEX_MODEL \\
    SB_LIVE_CODEX_REASONING_EFFORT CODEX_REASONING_EFFORT; do
    echo "\$v=\${!v-<unset>}"
  done
} >>"$LOG"
exit $rc
RUN
  chmod +x "$path"
}
make_runner "$T/tests/live/run-live-tests.sh" live
make_runner "$T/tests/e2e-live/run-e2e-live-tests.sh" e2e

unset SB_LIVE_AGENT SB_E2E_LIVE_AGENT SB_LIVE_RUNTIMES SB_E2E_LIVE_RUNTIMES SB_DISABLE_MINIMAX_IO_TESTS \
  SB_LIVE_CODEX_MODEL_PROVIDER SB_LIVE_CODEX_MODEL SB_LIVE_CODEX_REASONING_EFFORT CODEX_REASONING_EFFORT

# Defaults.
tl_run bash "$T/scripts/run-sb-live-tests-codex.sh"
assert_eq "defaults: exits 0" 0 "$TL_STATUS"
out="$(<"$LOG")"
assert_eq "both runners ran, live suite first" "live e2e" "$(grep -E '^(live|e2e)$' <<<"$out" | tr '\n' ' ' | sed 's/ $//')"
assert_eq "live agent defaults to codex" 2 "$(grep -c '^SB_LIVE_AGENT=codex$' <<<"$out")"
assert_eq "e2e agent defaults to codex" 2 "$(grep -c '^SB_E2E_LIVE_AGENT=codex$' <<<"$out")"
assert_eq "live runtimes default to codex" 2 "$(grep -c '^SB_LIVE_RUNTIMES=codex$' <<<"$out")"
assert_eq "e2e runtimes default to codex" 2 "$(grep -c '^SB_E2E_LIVE_RUNTIMES=codex$' <<<"$out")"
assert_eq "minimax io tests disabled by default" 2 "$(grep -c '^SB_DISABLE_MINIMAX_IO_TESTS=1$' <<<"$out")"
assert_eq "model provider exported empty" 2 "$(grep -c '^SB_LIVE_CODEX_MODEL_PROVIDER=$' <<<"$out")"
assert_eq "model exported empty" 2 "$(grep -c '^SB_LIVE_CODEX_MODEL=$' <<<"$out")"
assert_eq "reasoning effort exported empty" 2 "$(grep -c '^CODEX_REASONING_EFFORT=$' <<<"$out")"

# Caller overrides win, and the live reasoning effort feeds CODEX_REASONING_EFFORT.
: >"$LOG"
tl_run env SB_LIVE_AGENT=other SB_E2E_LIVE_AGENT=other2 SB_LIVE_RUNTIMES=claude,codex \
  SB_E2E_LIVE_RUNTIMES=claude SB_DISABLE_MINIMAX_IO_TESTS=0 SB_LIVE_CODEX_MODEL_PROVIDER=prov \
  SB_LIVE_CODEX_MODEL=gpt-x SB_LIVE_CODEX_REASONING_EFFORT=high \
  bash "$T/scripts/run-sb-live-tests-codex.sh"
assert_eq "overrides: exits 0" 0 "$TL_STATUS"
out="$(<"$LOG")"
assert_contains "agent override kept" "$out" "SB_LIVE_AGENT=other"
assert_contains "e2e agent override kept" "$out" "SB_E2E_LIVE_AGENT=other2"
assert_contains "runtime override kept" "$out" "SB_LIVE_RUNTIMES=claude,codex"
assert_contains "e2e runtime override kept" "$out" "SB_E2E_LIVE_RUNTIMES=claude"
assert_contains "minimax override kept" "$out" "SB_DISABLE_MINIMAX_IO_TESTS=0"
assert_contains "provider override kept" "$out" "SB_LIVE_CODEX_MODEL_PROVIDER=prov"
assert_contains "model override kept" "$out" "SB_LIVE_CODEX_MODEL=gpt-x"
assert_contains "effort override kept" "$out" "SB_LIVE_CODEX_REASONING_EFFORT=high"
assert_contains "effort propagates to CODEX_REASONING_EFFORT" "$out" "CODEX_REASONING_EFFORT=high"

# An explicit CODEX_REASONING_EFFORT beats the live effort.
: >"$LOG"
tl_run env SB_LIVE_CODEX_REASONING_EFFORT=high CODEX_REASONING_EFFORT=low \
  bash "$T/scripts/run-sb-live-tests-codex.sh"
assert_contains "explicit CODEX_REASONING_EFFORT wins" "$(<"$LOG")" "CODEX_REASONING_EFFORT=low"

# A failing live suite stops the wrapper before the e2e suite.
: >"$LOG"
make_runner "$T/tests/live/run-live-tests.sh" live 3
tl_run bash "$T/scripts/run-sb-live-tests-codex.sh"
assert_eq "live failure propagates" 3 "$TL_STATUS"
assert_not_contains "e2e suite skipped after live failure" "$(<"$LOG")" "e2e"

# A failing e2e suite fails the wrapper.
: >"$LOG"
make_runner "$T/tests/live/run-live-tests.sh" live 0
make_runner "$T/tests/e2e-live/run-e2e-live-tests.sh" e2e 4
tl_run bash "$T/scripts/run-sb-live-tests-codex.sh"
assert_eq "e2e failure propagates" 4 "$TL_STATUS"

tl_results
