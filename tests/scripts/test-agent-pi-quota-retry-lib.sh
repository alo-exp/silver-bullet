#!/usr/bin/env bash
# Unit-level behavior of scripts/lib/agent-pi-quota-retry.sh: plugin-root resolution, hang-vs-quota
# classification, the classify-and-report function (it never schedules and never writes state) and
# the single agent_host_pi_should_continue in scripts/lib/agent-host-exec.sh (quota text gating).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

LIB="$TL_REPO_ROOT/scripts/lib/agent-pi-quota-retry.sh"
# shellcheck source=../../scripts/lib/agent-host-exec.sh
source "$TL_REPO_ROOT/scripts/lib/agent-host-exec.sh"
# shellcheck source=../../scripts/lib/agent-pi-quota-retry.sh
source "$LIB"
unset SB_RFL_QUOTA_HOST SB_RFL_MODEL PI_PROVIDER PI_MODEL _AGENT_HOST_EXEC_DIR _AGENT_DELEGATE_COMMON_DIR 2>/dev/null || true

# ---------- agent_host_pi_quota_plugin_root (never the project) ----------
mkdir -p "$TL_TMP/a/b/scripts/lib"
assert_eq "root: host-exec dir two levels up" "$TL_TMP/a/b" "$(_AGENT_HOST_EXEC_DIR="$TL_TMP/a/b/scripts/lib" agent_host_pi_quota_plugin_root)"
assert_eq "root: delegate-common dir two levels up" "$TL_TMP/a/b" "$(_AGENT_DELEGATE_COMMON_DIR="$TL_TMP/a/b/scripts/lib" agent_host_pi_quota_plugin_root)"
assert_eq "root: default is the plugin the library lives in" "$TL_REPO_ROOT" "$(cd "$TL_TMP" && agent_host_pi_quota_plugin_root)"
assert_eq "root: SB_RFL_PROJECT_ROOT is ignored" "$TL_REPO_ROOT" "$(cd "$TL_TMP" && SB_RFL_PROJECT_ROOT="$TL_TMP/a" agent_host_pi_quota_plugin_root)"

# ---------- agent_host_pi_quota_is_hang_only ----------
hang() { if agent_host_pi_quota_is_hang_only "$@"; then echo yes; else echo no; fi; }
assert_eq "hang: rc 0 is not a hang" no "$(hang 0 'zero-byte-idle kill')"
assert_eq "hang: default args" no "$(hang)"
assert_eq "hang: 124 without kill marker counts as hang" yes "$(hang 124 'plain output')"
assert_eq "hang: 124 with zero-byte kill, no quota text" yes "$(hang 124 'zero-byte-idle kill after 90s')"
assert_eq "hang: 124 with hard-timeout kill and 429 is quota" no "$(hang 124 'hard-timeout kill; HTTP 429')"
assert_eq "hang: 124 with kill and rate limit is quota" no "$(hang 124 'zero-byte-idle kill: rate limit hit')"
assert_eq "hang: 124 with kill and 5-hour text is quota" no "$(hang 124 'hard-timeout kill 5 hour window')"
assert_eq "hang: 124 with kill and quota exhausted is quota" no "$(hang 124 'hard-timeout kill quota exhausted')"

# ---------- agent_host_pi_should_continue ----------
cont() { if agent_host_pi_should_continue "$@"; then echo yes; else echo no; fi; }
assert_eq "continue: success clean output" yes "$(cont 0 'all good')"
assert_eq "continue: non-zero rc" no "$(cont 1 'all good')"
assert_eq "continue: 124" no "$(cont 124 'all good')"
assert_eq "continue: 429 text" no "$(cont 0 'HTTP 429 too many')"
assert_eq "continue: usage limit text" no "$(cont 0 'you hit the usage limit')"
assert_eq "continue: rate_limit_error text" no "$(cont 0 'rate_limit_error')"
agent_host_pi_is_auth_failure() { [[ "$1" == *"AUTHFAIL"* ]]; }
assert_eq "continue: auth failure blocks" no "$(cont 0 'AUTHFAIL here')"
assert_eq "continue: auth helper present but text clean" yes "$(cont 0 'fine')"
unset -f agent_host_pi_is_auth_failure

# ---------- agent_host_pi_maybe_schedule_quota_retry (classify and report only) ----------
FAKE="$TL_TMP/plugin"; mkdir -p "$FAKE/scripts"
cat >"$FAKE/scripts/review-fix-ladder.py" <<'PY'
import json, os, sys
a = sys.argv[1:]
with open(os.environ["FAKE_LOG"], "a") as f:
    f.write(" ".join(a) + "\n")
    for i, x in enumerate(a):
        if x == "--subscription-output-file":
            f.write("blob=" + open(a[i + 1]).read() + "\n")
if os.environ.get("FAKE_CLASSIFY_FAIL"):
    sys.exit(3)
print(os.environ.get("FAKE_CLASSIFY_JSON", "{}"))
PY
export FAKE_LOG="$TL_TMP/fake.log"
export _AGENT_HOST_EXEC_DIR="$FAKE/scripts/lib"; mkdir -p "$_AGENT_HOST_EXEC_DIR"
export TMPDIR="$TL_TMP/tmpd"; mkdir -p "$TMPDIR"
run_sched() { # [env...] -- args...
  local envs=()
  while [[ "$1" != "--" ]]; do envs+=("$1"); shift; done
  shift
  : >"$FAKE_LOG"
  tl_run env "${envs[@]}" bash -c 'source "$1"; shift; agent_host_pi_maybe_schedule_quota_retry "$@"; echo "rc=$?"' _ "$LIB" "$@"
  CALLS="$(cat "$FAKE_LOG")"
}
leftover_blobs() { find "$TMPDIR" -name 'agent-pi-quota-*' | wc -l | tr -d ' '; }

run_sched X=1 -- 124 "plain hang"
assert_contains "hang-only returns 0" "$TL_OUT" "rc=0"
assert_eq "hang-only does not call the resolver" "" "$CALLS"
run_sched X=1 -- 1 ""
assert_eq "empty text does not call the resolver" "" "$CALLS"
mkdir -p "$TL_TMP/bare/scripts/lib"
run_sched _AGENT_HOST_EXEC_DIR="$TL_TMP/bare/scripts/lib" -- 1 "HTTP 429"
assert_eq "missing resolver: nothing called" "" "$CALLS"
assert_contains "missing resolver returns 0" "$TL_OUT" "rc=0"

run_sched FAKE_CLASSIFY_FAIL=1 -- 1 "HTTP 429" claude claude/opus
assert_contains "classify failure returns 0" "$TL_OUT" "rc=0"
assert_eq "classify failure: temp blob removed" 0 "$(leftover_blobs)"
assert_eq "classify failure: silent" "" "$TL_ERR"

run_sched FAKE_CLASSIFY_JSON='{"quota_class":"weekly","should_schedule":false}' -- 1 "weekly limit" claude m
assert_contains "weekly prints HOLD" "$TL_ERR" "[agent-pi] quota weekly; HOLD (no 5h retry)"
run_sched FAKE_CLASSIFY_JSON='{"quota_class":"monthly","should_schedule":false}' -- 1 "monthly limit" claude m
assert_contains "monthly prints HOLD" "$TL_ERR" "quota monthly; HOLD"
run_sched FAKE_CLASSIFY_JSON='{"quota_class":"unknown","should_schedule":false}' -- 1 "mystery" claude m
assert_eq "unknown class is silent" "" "$TL_ERR"
run_sched FAKE_CLASSIFY_JSON='not json' -- 1 "garbled" claude m
assert_eq "unparseable classification is silent" "" "$TL_ERR"

run_sched FAKE_CLASSIFY_JSON='{"quota_class":"five_hour","should_schedule":true,"reset_seconds":9120}' -- 1 "5-hour quota exhausted" claude claude/opus
assert_contains "5h reports the window and that nothing is scheduled" "$TL_ERR" "[agent-pi] quota 5h; window resets in 9120s; no retry is scheduled"
assert_contains "classify call carries host and model" "$CALLS" "--classify-quota-window --quota-host claude --model claude/opus"
assert_contains "blob holds the original output" "$CALLS" "blob=5-hour quota exhausted"
assert_eq "temp blob removed" 0 "$(leftover_blobs)"
run_sched FAKE_CLASSIFY_JSON='{"quota_class":"five_hour","should_schedule":true}' PI_PROVIDER=envhost PI_MODEL=envmodel -- 1 "429"
assert_contains "env host and model flow into classify" "$CALLS" "--quota-host envhost --model envmodel"
assert_contains "no reset parsed: defaults to the 5h window" "$TL_ERR" "resets in 18000s"
run_sched FAKE_CLASSIFY_JSON='{"quota_class":"daily","should_schedule":true,"reset_seconds":60}' SB_RFL_QUOTA_HOST=sbhost SB_RFL_MODEL=sbmodel -- 1 "daily limit"
assert_contains "non-5h class announced with its name" "$TL_ERR" "[agent-pi] quota daily; window resets in 60s"
assert_contains "SB_RFL_QUOTA_HOST and SB_RFL_MODEL are honored" "$CALLS" "--quota-host sbhost --model sbmodel"
if find "$TL_TMP" -name 'quota-retry-schedule.json' -o -name 'agent-pi' -path '*/.planning/*' | grep -q .; then
  tl_fail "no schedule or planning state is ever written"
else tl_pass "no schedule or planning state is ever written"; fi

tl_results
