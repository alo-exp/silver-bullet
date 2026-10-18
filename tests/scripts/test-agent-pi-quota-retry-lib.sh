#!/usr/bin/env bash
# Unit-level behavior of scripts/lib/agent-pi-quota-retry.sh: root/run-dir/rung resolution,
# hang-vs-quota classification, continue gating and the retry scheduling flow. The ladder
# resolver (review-fix-ladder.py) is replaced by a stub in a fake project root.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

LIB="$TL_REPO_ROOT/scripts/lib/agent-pi-quota-retry.sh"
# shellcheck source=../../scripts/lib/agent-pi-quota-retry.sh
source "$LIB"
unset SB_RFL_PROJECT_ROOT SB_RFL_RUN_DIR SB_RFL_RUNG_ID SB_RFL_RUN_ID SB_RFL_QUOTA_HOST SB_RFL_MODEL \
  WORK_DIR PI_WORK_DIR PI_PROVIDER PI_MODEL _AGENT_HOST_EXEC_DIR _AGENT_DELEGATE_COMMON_DIR 2>/dev/null || true

# ---------- agent_host_pi_quota_repo_root ----------
FAKE="$TL_TMP/fakeproj"; mkdir -p "$FAKE/scripts"
assert_eq "root: SB_RFL_PROJECT_ROOT wins" "$FAKE" "$(SB_RFL_PROJECT_ROOT="$FAKE" agent_host_pi_quota_repo_root)"
mkdir -p "$TL_TMP/a/b/scripts/lib" "$TL_TMP/c/d/lib"
assert_eq "root: host-exec dir two levels up" "$TL_TMP/a/b" "$(_AGENT_HOST_EXEC_DIR="$TL_TMP/a/b/scripts/lib" agent_host_pi_quota_repo_root)"
assert_eq "root: delegate-common dir two levels up" "$TL_TMP/a/b" "$(_AGENT_DELEGATE_COMMON_DIR="$TL_TMP/a/b/scripts/lib" agent_host_pi_quota_repo_root)"
assert_eq "root: missing SB_RFL_PROJECT_ROOT dir falls through to cwd" "$TL_TMP/c" \
  "$(cd "$TL_TMP/c" && SB_RFL_PROJECT_ROOT="$TL_TMP/nonexistent" agent_host_pi_quota_repo_root)"

# ---------- agent_host_pi_resolve_quota_run_dir ----------
RD="$TL_TMP/explicit/run"
assert_eq "run dir: SB_RFL_RUN_DIR created and returned" "$RD" "$(SB_RFL_RUN_DIR="$RD" agent_host_pi_resolve_quota_run_dir)"
assert_file_exists "run dir: SB_RFL_RUN_DIR exists" "$RD"
mkdir -p "$TL_TMP/w/rfl-9/rung-3" "$TL_TMP/w/rung-1" "$TL_TMP/w/rfl-7"
assert_eq "run dir: rung-N inside rfl-* resolves to the rfl parent" "$TL_TMP/w/rfl-9" "$(agent_host_pi_resolve_quota_run_dir "$TL_TMP/w/rfl-9/rung-3")"
assert_eq "run dir: rfl-* itself" "$TL_TMP/w/rfl-7" "$(WORK_DIR="$TL_TMP/w/rfl-7" agent_host_pi_resolve_quota_run_dir)"
assert_eq "run dir: PI_WORK_DIR default" "$TL_TMP/w/rfl-7" "$(PI_WORK_DIR="$TL_TMP/w/rfl-7" agent_host_pi_resolve_quota_run_dir)"
out="$(SB_RFL_PROJECT_ROOT="$FAKE" agent_host_pi_resolve_quota_run_dir "$TL_TMP/w/rung-1")"
assert_eq "run dir: rung-* without rfl parent falls back to repo planning dir" "$FAKE/.planning/agent-pi/quota-retry" "$out"
assert_file_exists "run dir: fallback dir created" "$FAKE/.planning/agent-pi/quota-retry"
out="$(SB_RFL_PROJECT_ROOT="$FAKE" agent_host_pi_resolve_quota_run_dir "$TL_TMP/nonexistent")"
assert_eq "run dir: nonexistent work dir falls back" "$FAKE/.planning/agent-pi/quota-retry" "$out"

# ---------- agent_host_pi_resolve_quota_rung ----------
assert_eq "rung: SB_RFL_RUNG_ID wins" "rung-42" "$(SB_RFL_RUNG_ID=rung-42 agent_host_pi_resolve_quota_rung /x/rung-1)"
assert_eq "rung: derived from dir name" "rung-12" "$(agent_host_pi_resolve_quota_rung /x/rung-12-extra)"
assert_eq "rung: default" "agent-pi" "$(agent_host_pi_resolve_quota_rung /x/other)"
assert_eq "rung: empty work dir default" "agent-pi" "$(agent_host_pi_resolve_quota_rung)"

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

# ---------- agent_host_pi_maybe_schedule_quota_retry ----------
PROJ="$TL_TMP/proj"; mkdir -p "$PROJ/scripts"
cat >"$PROJ/scripts/review-fix-ladder.py" <<'PY'
import json, os, sys
a = sys.argv[1:]
with open(os.environ["FAKE_LOG"], "a") as f:
    f.write(" ".join(a) + "\n")
    for i, x in enumerate(a):
        if x == "--subscription-output-file":
            f.write("blob=" + open(a[i + 1]).read() + "\n")
mode = "classify" if "--classify-quota-window" in a else "schedule"
if os.environ.get("FAKE_" + mode.upper() + "_FAIL"):
    sys.exit(3)
print(os.environ.get("FAKE_" + mode.upper() + "_JSON", "{}"))
PY
export FAKE_LOG="$TL_TMP/fake.log"
export SB_RFL_PROJECT_ROOT="$PROJ"
export TMPDIR="$TL_TMP/tmpd"; mkdir -p "$TMPDIR"
run_sched() { # [env...] -- args...
  local envs=()
  while [[ "$1" != "--" ]]; do envs+=("$1"); shift; done
  shift
  : >"$FAKE_LOG"
  tl_run env "${envs[@]}" bash -c 'source "$1"; shift; eval "${PRE_SNIPPET:-:}"; agent_host_pi_maybe_schedule_quota_retry "$@"; echo "rc=$?"' _ "$LIB" "$@"
  CALLS="$(cat "$FAKE_LOG")"
  NCALLS="$(grep -c -e '--classify-quota-window' -e '--schedule-quota-retry' "$FAKE_LOG" || true)"
}
leftover_blobs() { find "$TMPDIR" -name 'agent-pi-quota-*' | wc -l | tr -d ' '; }

# hang-only and empty text: nothing runs
run_sched X=1 -- 124 "plain hang"
assert_contains "hang-only returns 0" "$TL_OUT" "rc=0"
assert_eq "hang-only does not call resolver" "" "$CALLS"
run_sched X=1 -- 1 ""
assert_eq "empty text does not call resolver" "" "$CALLS"
# resolver missing
mkdir -p "$TL_TMP/bare/scripts"
run_sched SB_RFL_PROJECT_ROOT="$TL_TMP/bare" -- 1 "HTTP 429"
assert_contains "missing resolver returns 0" "$TL_OUT" "rc=0"
assert_eq "missing resolver: nothing called" "" "$CALLS"

# classify failure: blob removed, returns 0, no schedule
run_sched FAKE_CLASSIFY_FAIL=1 -- 1 "HTTP 429" claude claude/opus
assert_contains "classify failure returns 0" "$TL_OUT" "rc=0"
assert_eq "classify failure: only classify attempted" 1 "$NCALLS"
assert_eq "classify failure: temp blob removed" 0 "$(leftover_blobs)"

# weekly: hold message, no schedule
run_sched FAKE_CLASSIFY_JSON='{"quota_class":"weekly","should_schedule":false}' -- 1 "weekly limit" claude m
assert_contains "weekly prints HOLD" "$TL_ERR" "[agent-pi] quota weekly; HOLD (no 5h retry)"
assert_not_contains "weekly never schedules" "$CALLS" "--schedule-quota-retry"
assert_eq "weekly: temp blob removed" 0 "$(leftover_blobs)"
run_sched FAKE_CLASSIFY_JSON='{"quota_class":"monthly","should_schedule":false}' -- 1 "monthly limit" claude m
assert_contains "monthly prints HOLD" "$TL_ERR" "quota monthly; HOLD"
# unknown class: silent
run_sched FAKE_CLASSIFY_JSON='{"quota_class":"unknown","should_schedule":false}' -- 1 "mystery" claude m
assert_eq "unknown class is silent" "" "$TL_ERR"
run_sched FAKE_CLASSIFY_JSON='not json' -- 1 "garbled" claude m
assert_eq "unparseable classification is silent and non-scheduling" "" "$TL_ERR"
assert_eq "unparseable classification: only classify call" 1 "$NCALLS"

# five-hour: schedule with run dir/rung/model, announce wake time
RUNDIR="$TL_TMP/runs/rfl-demo"
run_sched FAKE_CLASSIFY_JSON='{"quota_class":"five_hour","should_schedule":true}' \
  FAKE_SCHEDULE_JSON='{"job":{"wake_at":"2026-01-01T05:00:00Z"}}' SB_RFL_RUN_DIR="$RUNDIR" SB_RFL_RUNG_ID=rung-4 \
  -- 1 "5-hour quota exhausted" claude claude/opus
assert_contains "5h announces retry" "$TL_ERR" "[agent-pi] quota 5h; retry at 2026-01-01T05:00:00Z"
assert_contains "schedule call carries run dir, id, rung, model, host" "$CALLS" \
  "--schedule-quota-retry --run-dir $RUNDIR --run-id rfl-demo --rung-id rung-4 --model claude/opus --quota-host claude"
assert_contains "blob holds the original output" "$CALLS" "blob=5-hour quota exhausted"
assert_eq "5h: temp blob removed" 0 "$(leftover_blobs)"
assert_contains "5h returns 0" "$TL_OUT" "rc=0"

# explicit run id, defaults for host/model from env, model fallback
run_sched FAKE_CLASSIFY_JSON='{"quota_class":"five_hour","should_schedule":true}' \
  FAKE_SCHEDULE_JSON='{"job":{"fire_at":"2026-01-02T00:00:00Z"}}' SB_RFL_RUN_DIR="$RUNDIR" SB_RFL_RUN_ID=custom-id \
  PI_PROVIDER=envhost PI_MODEL=envmodel -- 1 "429"
assert_contains "env host and model flow into classify" "$CALLS" "--classify-quota-window --quota-host envhost --model envmodel"
assert_contains "explicit run id used" "$CALLS" "--run-id custom-id"
assert_contains "fire_at accepted as wake time" "$TL_ERR" "retry at 2026-01-02T00:00:00Z"
run_sched FAKE_CLASSIFY_JSON='{"quota_class":"five_hour","should_schedule":true}' \
  FAKE_SCHEDULE_JSON='{"wake_at":"2026-01-03T00:00:00Z"}' SB_RFL_RUN_DIR="$RUNDIR" -- 1 "429"
assert_contains "no model anywhere falls back to claude/unknown" "$CALLS" "--model claude/unknown"
assert_contains "top-level wake_at accepted" "$TL_ERR" "retry at 2026-01-03T00:00:00Z"
run_sched FAKE_CLASSIFY_JSON='{"quota_class":"five_hour","should_schedule":true}' \
  FAKE_SCHEDULE_JSON='{"wake_at":"x"}' SB_RFL_RUN_DIR="$RUNDIR" SB_RFL_QUOTA_HOST=sbhost SB_RFL_MODEL=sbmodel -- 1 "429"
assert_contains "SB_RFL_QUOTA_HOST and SB_RFL_MODEL are honored" "$CALLS" "--quota-host sbhost --model sbmodel"

# non-5h class that is scheduled prints its own class name
run_sched FAKE_CLASSIFY_JSON='{"quota_class":"daily","should_schedule":true}' \
  FAKE_SCHEDULE_JSON='{"job":{"wake_at":"2026-02-01T00:00:00Z"}}' SB_RFL_RUN_DIR="$RUNDIR" -- 1 "daily limit" h m
assert_contains "non-5h class announced with its name" "$TL_ERR" "[agent-pi] quota daily; retry at 2026-02-01T00:00:00Z"

# scheduled but no wake time: no announcement
run_sched FAKE_CLASSIFY_JSON='{"quota_class":"five_hour","should_schedule":true}' FAKE_SCHEDULE_JSON='{}' \
  SB_RFL_RUN_DIR="$RUNDIR" -- 1 "429" h m
assert_eq "no wake time: nothing announced" "" "$TL_ERR"
assert_contains "no wake time still returns 0" "$TL_OUT" "rc=0"

# schedule failure: swallowed, blob removed
run_sched FAKE_CLASSIFY_JSON='{"quota_class":"five_hour","should_schedule":true}' FAKE_SCHEDULE_FAIL=1 \
  SB_RFL_RUN_DIR="$RUNDIR" -- 1 "429" h m
assert_contains "schedule failure returns 0" "$TL_OUT" "rc=0"
assert_eq "schedule failure announces nothing" "" "$TL_ERR"
assert_eq "schedule failure removes blob" 0 "$(leftover_blobs)"

# run-dir resolution failure (injected: the resolver function fails)
run_sched FAKE_CLASSIFY_JSON='{"quota_class":"five_hour","should_schedule":true}' \
  PRE_SNIPPET='agent_host_pi_resolve_quota_run_dir() { return 1; }' -- 1 "429" h m
assert_contains "unresolvable run dir returns 0" "$TL_OUT" "rc=0"
assert_not_contains "unresolvable run dir never schedules" "$CALLS" "--schedule-quota-retry"
assert_eq "unresolvable run dir removes blob" 0 "$(leftover_blobs)"

tl_results
