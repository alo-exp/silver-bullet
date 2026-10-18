#!/usr/bin/env bash
# Edge cases of .planning/scripts/phase-lock.sh that test-phase-lock.sh does not reach:
# help and usage errors, preconditions (jq, git, planning dir), config resolution
# order, phase normalisation, corrupt lock files, the sidecar failure, the atomic-mkdir
# mutex used when flock(1) is missing, and same-owner re-claim.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

SCRIPT="$TL_REPO_ROOT/.planning/scripts/phase-lock.sh"
DEFAULT_CFG="$TL_REPO_ROOT/templates/silver-bullet.config.json.default"
WORK="$TL_TMP/work"
mkdir -p "$WORK/.planning"
export SB_PHASE_LOCK_FILE="$WORK/.planning/locks.json"
export SB_DEFAULT_CONFIG="$DEFAULT_CFG"
unset SB_PHASE_LOCK_INHERITED
NOFLOCK_PATH="$(tl_path_without flock)"
NOJQ_PATH="$(tl_path_without jq)"

reset() { rm -rf "$SB_PHASE_LOCK_FILE" "$SB_PHASE_LOCK_FILE.lock" "$SB_PHASE_LOCK_FILE.lock.d"; }
pl() { tl_run bash "$SCRIPT" "$@"; }
# in_dir DIR cmd...: run a command (typically tl_run ...) from DIR without a subshell, so TL_* survive.
in_dir() { local d="$1" old="$PWD"; shift; cd "$d"; "$@"; cd "$old"; }
export GIT_CEILING_DIRECTORIES="$TL_TMP"
HOST="$(hostname -s 2>/dev/null || hostname)"

# --- help ---------------------------------------------------------------
for arg in "" "-h" "--help"; do
  if [[ -z "$arg" ]]; then pl; else pl "$arg"; fi
  assert_eq "help '$arg' exits 0" "0" "$TL_STATUS"
  assert_contains "help '$arg' prints usage" "$TL_OUT" "Usage: phase-lock.sh <op> <phase>"
done

# --- unknown op and usage errors ----------------------------------------
pl frobnicate
assert_eq "unknown op exits 4" "4" "$TL_STATUS"
assert_contains "unknown op message" "$TL_ERR" "unknown op 'frobnicate'"
pl claim 1 claude
assert_eq "claim with 2 args exits 4" "4" "$TL_STATUS"
assert_contains "claim usage" "$TL_ERR" "Usage: phase-lock.sh claim <phase> <runtime> <intent>"
pl heartbeat 1
assert_eq "heartbeat with 1 arg exits 4" "4" "$TL_STATUS"
assert_contains "heartbeat usage" "$TL_ERR" "Usage: phase-lock.sh heartbeat <phase> <runtime>"
pl release
assert_eq "release with 0 args exits 4" "4" "$TL_STATUS"
assert_contains "release usage" "$TL_ERR" "Usage: phase-lock.sh release <phase> <runtime>"
pl peek 1 2
assert_eq "peek with 2 args exits 4" "4" "$TL_STATUS"
assert_contains "peek usage" "$TL_ERR" "Usage: phase-lock.sh peek <phase>"
pl claim 1 martian why
assert_eq "unknown runtime exits 3" "3" "$TL_STATUS"
assert_contains "unknown runtime message" "$TL_ERR" "unknown runtime tag 'martian'"
assert_file_absent "unknown runtime writes no lock" "$SB_PHASE_LOCK_FILE"

# --- preconditions ------------------------------------------------------
PATH="$NOJQ_PATH" tl_run bash "$SCRIPT" peek 1
assert_eq "missing jq exits 1" "1" "$TL_STATUS"
assert_contains "missing jq message" "$TL_ERR" "jq is required"

NOGIT="$TL_TMP/nogit"
mkdir -p "$NOGIT"
in_dir "$NOGIT" tl_run env -u SB_PHASE_LOCK_FILE bash "$SCRIPT" peek 1
assert_eq "outside git without lock file exits 1" "1" "$TL_STATUS"
assert_contains "outside git message" "$TL_ERR" "must be run inside a git repository"
in_dir "$NOGIT" tl_run bash "$SCRIPT" peek 1
assert_eq "outside git with SB_PHASE_LOCK_FILE works" "0" "$TL_STATUS"
assert_eq "outside git peek of free phase is empty" "" "$TL_OUT"

SB_PHASE_LOCK_FILE="$TL_TMP/absent-dir/locks.json" tl_run bash "$SCRIPT" peek 1
assert_eq "missing planning dir exits 1" "1" "$TL_STATUS"
assert_contains "missing planning dir message" "$TL_ERR" "planning directory not found"

# --- default lock path inside a git repo --------------------------------
REPO="$TL_TMP/repo"
tl_git_repo "$REPO"
mkdir -p "$REPO/.planning"
in_dir "$REPO" tl_run env -u SB_PHASE_LOCK_FILE bash "$SCRIPT" claim 7 claude "default path"
assert_eq "claim in repo exits 0" "0" "$TL_STATUS"
assert_file_exists "lock written under repo .planning" "$REPO/.planning/.phase-locks.json"
assert_eq "repo lock records phase 007" "default path" "$(jq -r '."007".intent' "$REPO/.planning/.phase-locks.json")"

# --- phase normalisation ------------------------------------------------
reset
pl claim 0 claude zero
assert_eq "claim phase 0" "0" "$TL_STATUS"
assert_eq "phase 0 is stored as 000" "zero" "$(jq -r '."000".intent' "$SB_PHASE_LOCK_FILE")"
pl claim 070 claude octal
assert_eq "phase 070 is stored as 070 (not octal)" "octal" "$(jq -r '."070".intent' "$SB_PHASE_LOCK_FILE")"
pl claim v1.2-alpha claude named
assert_eq "non-numeric phase kept verbatim" "named" "$(jq -r '."v1.2-alpha".intent' "$SB_PHASE_LOCK_FILE")"
pl peek 00
assert_eq "peek 00 normalises to 000" "zero" "$(jq -r '.intent' <<<"$TL_OUT")"

# --- corrupt lock file --------------------------------------------------
reset
printf '{not json' >"$SB_PHASE_LOCK_FILE"
pl peek 1
assert_eq "corrupt lock file makes peek fail" "1" "$TL_STATUS"
assert_contains "corrupt lock message" "$TL_ERR" "corrupt lock file"

# --- heartbeat on a free phase -----------------------------------------
reset
pl heartbeat 5 claude
assert_eq "heartbeat without lock exits 2" "2" "$TL_STATUS"
assert_contains "heartbeat without lock message" "$TL_ERR" "has no active lock"

# --- config resolution --------------------------------------------------
# Project config without multi_agent: template default supplies tags and ttl.
CFG_REPO="$TL_TMP/cfgrepo"
tl_git_repo "$CFG_REPO"
mkdir -p "$CFG_REPO/.planning"
printf '{}\n' >"$CFG_REPO/.silver-bullet.json"
CUSTOM_DEF="$TL_TMP/custom-default.json"
printf '{"multi_agent":{"identity_tags":["alpha","beta"],"stale_lock_ttl_seconds":5}}\n' >"$CUSTOM_DEF"
CFGLOCK="$CFG_REPO/.planning/locks.json"
in_dir "$CFG_REPO" tl_run env SB_PHASE_LOCK_FILE="$CFGLOCK" SB_DEFAULT_CONFIG="$CUSTOM_DEF" bash "$SCRIPT" claim 1 beta work
assert_eq "tag from SB_DEFAULT_CONFIG accepted when project has none" "0" "$TL_STATUS"
in_dir "$CFG_REPO" tl_run env SB_PHASE_LOCK_FILE="$CFGLOCK" SB_DEFAULT_CONFIG="$CUSTOM_DEF" bash "$SCRIPT" claim 2 claude work
assert_eq "tag outside default config rejected" "3" "$TL_STATUS"
assert_contains "allowed tags listed from default config" "$TL_ERR" "allowed: alpha beta"
# ttl 5s from the default config: a 10-second-old heartbeat reads as expired.
old_ts="$(date -u -d '10 seconds ago' +%Y-%m-%dT%H:%M:%SZ)"
jq --arg ts "$old_ts" '."001".last_heartbeat_at = $ts' "$CFG_REPO/.planning/locks.json" >"$CFG_REPO/.planning/l2" \
  && mv "$CFG_REPO/.planning/l2" "$CFG_REPO/.planning/locks.json"
in_dir "$CFG_REPO" tl_run env SB_PHASE_LOCK_FILE="$CFGLOCK" SB_DEFAULT_CONFIG="$CUSTOM_DEF" bash "$SCRIPT" peek 1
assert_eq "ttl from default config marks lock expired" "true" "$(jq -r '.expired' <<<"$TL_OUT")"

# Without SB_DEFAULT_CONFIG the repo template is used.
mkdir -p "$CFG_REPO/templates"
printf '{"multi_agent":{"identity_tags":["gamma"],"stale_lock_ttl_seconds":3600}}\n' >"$CFG_REPO/templates/silver-bullet.config.json.default"
in_dir "$CFG_REPO" tl_run env -u SB_DEFAULT_CONFIG SB_PHASE_LOCK_FILE="$CFG_REPO/.planning/l3.json" bash "$SCRIPT" claim 1 gamma t
assert_eq "repo template tags used" "0" "$TL_STATUS"
in_dir "$CFG_REPO" tl_run env -u SB_DEFAULT_CONFIG SB_PHASE_LOCK_FILE="$CFG_REPO/.planning/l3.json" bash "$SCRIPT" claim 2 claude t
assert_contains "repo template tag list in error" "$TL_ERR" "allowed: gamma"

# Outside git, no SB_DEFAULT_CONFIG: the template next to the script tree is used.
in_dir "$NOGIT" tl_run env -u SB_DEFAULT_CONFIG bash "$SCRIPT" claim 1 forge t
assert_eq "template beside script is found outside git (forge not in template)" "3" "$TL_STATUS"
assert_contains "template beside script supplies the tag list" "$TL_ERR" "allowed: claude codex opencode"
reset

# No template anywhere (script copied to a tree without templates/): hard fallback tags and ttl.
ISO="$TL_TMP/iso"
mkdir -p "$ISO/.planning/scripts"
cp "$SCRIPT" "$ISO/.planning/scripts/phase-lock.sh"
iso() { in_dir "$NOGIT" tl_run env -u SB_DEFAULT_CONFIG bash "$ISO/.planning/scripts/phase-lock.sh" "$@"; }
iso claim 1 opencode t
assert_eq "hard fallback accepts opencode" "0" "$TL_STATUS"
iso claim 2 martian t
assert_eq "hard fallback rejects unknown tag" "3" "$TL_STATUS"
assert_contains "hard fallback tag list" "$TL_ERR" "allowed: claude forge codex opencode"
iso peek 1
assert_eq "hard fallback ttl keeps fresh lock unexpired" "null" "$(jq -r '.expired // "null"' <<<"$TL_OUT")"
reset

# An unparsable heartbeat timestamp reads as epoch 0: the lock is stale and stolen.
printf '{"001":{"owner_id":"codex-other-1","agent_runtime":"codex","host":"other","last_heartbeat_at":"garbage","intent":"x"}}\n' >"$SB_PHASE_LOCK_FILE"
pl peek 1
assert_eq "garbage heartbeat peeks as expired" "true" "$(jq -r '.expired' <<<"$TL_OUT")"
pl claim 1 claude steal
assert_eq "stale claim succeeds" "0" "$TL_STATUS"
assert_contains "stale claim warns" "$TL_ERR" "stealing stale lock from codex-other-1"
assert_eq "stolen lock now owned by claude" "claude" "$(jq -r '."001".agent_runtime' "$SB_PHASE_LOCK_FILE")"

# --- flock sidecar cannot be created -----------------------------------
reset
mkdir -p "$SB_PHASE_LOCK_FILE.lock"
pl claim 1 claude x
assert_eq "unusable sidecar exits 1" "1" "$TL_STATUS"
assert_contains "sidecar message" "$TL_ERR" "cannot create flock sidecar"
assert_file_absent "no lock file written without sidecar" "$SB_PHASE_LOCK_FILE"
rmdir "$SB_PHASE_LOCK_FILE.lock"

# --- same-process re-claim is idempotent --------------------------------
# $$ of a sourced script is the sourcing shell, so seed the lock with that pid.
reset
reset
RECLAIM="$TL_TMP/reclaim.sh"
cat >"$RECLAIM" <<'INNER'
printf '{"001":{"owner_id":"claude-%s-%s","agent_runtime":"claude","host":"h","last_heartbeat_at":"%s","intent":"first"}}\n' \
  "$(hostname -s 2>/dev/null || hostname)" "$$" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$SB_PHASE_LOCK_FILE"
SCRIPT_PATH="$1"
set -- claim 1 claude second
source "$SCRIPT_PATH"
INNER
tl_run bash "$RECLAIM" "$SCRIPT"
assert_eq "same-owner re-claim exits 0" "0" "$TL_STATUS"
assert_not_contains "same-owner re-claim does not warn of theft" "$TL_ERR" "stealing"
assert_eq "same-owner re-claim refreshes intent" "second" "$(jq -r '."001".intent' "$SB_PHASE_LOCK_FILE")"

# --- atomic-mkdir mutex (flock missing) --------------------------------
reset
PATH="$NOFLOCK_PATH" tl_run bash "$SCRIPT" claim 3 claude nolock
assert_eq "claim without flock exits 0" "0" "$TL_STATUS"
assert_eq "claim without flock writes lock" "nolock" "$(jq -r '."003".intent' "$SB_PHASE_LOCK_FILE")"
assert_file_absent "mkdir mutex released after claim" "$SB_PHASE_LOCK_FILE.lock.d"
PATH="$NOFLOCK_PATH" tl_run bash "$SCRIPT" heartbeat 3 claude
assert_eq "heartbeat without flock exits 0" "0" "$TL_STATUS"
PATH="$NOFLOCK_PATH" tl_run bash "$SCRIPT" release 3 claude
assert_eq "release without flock exits 0" "0" "$TL_STATUS"
assert_eq "release without flock drops entry" "{}" "$(jq -c . "$SB_PHASE_LOCK_FILE")"

# A mutex directory older than 60s is cleared as stale.
mkdir -p "$SB_PHASE_LOCK_FILE.lock.d"
touch -d '5 minutes ago' "$SB_PHASE_LOCK_FILE.lock.d"
PATH="$NOFLOCK_PATH" tl_run bash "$SCRIPT" claim 4 claude stale-mutex
assert_eq "stale mutex dir is cleared" "0" "$TL_STATUS"
assert_eq "claim after stale mutex clear writes lock" "stale-mutex" "$(jq -r '."004".intent' "$SB_PHASE_LOCK_FILE")"
assert_file_absent "stale-mutex run leaves no mutex dir" "$SB_PHASE_LOCK_FILE.lock.d"

# A fresh mutex held by another process is waited for (sleep is a function that frees it).
mkdir -p "$SB_PHASE_LOCK_FILE.lock.d"
WAIT_RUN="$TL_TMP/wait-run.sh"
cat >"$WAIT_RUN" <<'INNER'
sleep() {
  if [[ "$1" == "0.01" ]]; then return 1; fi   # first sleep fails: exercise the `sleep 1` fallback
  echo "slept $1" >>"$WAIT_LOG"
  rmdir "$SB_PHASE_LOCK_FILE.lock.d"
}
export -f sleep
exec bash "$SCRIPT" claim 5 claude waited
INNER
WAIT_LOG="$TL_TMP/wait.log"; : >"$WAIT_LOG"
PATH="$NOFLOCK_PATH" WAIT_LOG="$WAIT_LOG" SCRIPT="$SCRIPT" tl_run bash "$WAIT_RUN"
assert_eq "claim waits for a held mutex" "0" "$TL_STATUS"
assert_eq "waiter fell back to sleep 1" "slept 1" "$(cat "$WAIT_LOG")"
assert_eq "waiter wrote the lock" "waited" "$(jq -r '."005".intent' "$SB_PHASE_LOCK_FILE")"

# stat(1) failing in both flavours reads as mtime 0: the held mutex is not treated as stale.
mkdir -p "$SB_PHASE_LOCK_FILE.lock.d"
STAT_RUN="$TL_TMP/stat-run.sh"
cat >"$STAT_RUN" <<'INNER'
stat() { return 1; }
sleep() { command rmdir "$SB_PHASE_LOCK_FILE.lock.d"; }
export -f stat sleep
exec bash "$SCRIPT" claim 7 claude statless
INNER
PATH="$NOFLOCK_PATH" SCRIPT="$SCRIPT" tl_run bash "$STAT_RUN"
assert_eq "claim proceeds when stat is unusable" "0" "$TL_STATUS"
assert_eq "statless claim wrote the lock" "statless" "$(jq -r '."007".intent' "$SB_PHASE_LOCK_FILE")"

# A stale mutex that cannot be removed (rm fails) is retried, not fatal.
mkdir -p "$SB_PHASE_LOCK_FILE.lock.d"
touch -d '5 minutes ago' "$SB_PHASE_LOCK_FILE.lock.d"
RMFAIL_RUN="$TL_TMP/rmfail-run.sh"
cat >"$RMFAIL_RUN" <<'INNER'
rm() { command rm "$@"; return 1; }   # removes the dir but reports failure
export -f rm
exec bash "$SCRIPT" claim 8 claude rmfail
INNER
PATH="$NOFLOCK_PATH" SCRIPT="$SCRIPT" tl_run bash "$RMFAIL_RUN"
assert_eq "failing rm of a stale mutex is tolerated" "0" "$TL_STATUS"
assert_eq "claim after failing rm wrote the lock" "rmfail" "$(jq -r '."008".intent' "$SB_PHASE_LOCK_FILE")"

# mkdir that "succeeds" without creating the dir: the pid note and the cleanup both fail softly.
NOPID_RUN="$TL_TMP/nopid-run.sh"
cat >"$NOPID_RUN" <<'INNER'
mkdir() { return 0; }
rm() { return 1; }
export -f mkdir rm
exec bash "$SCRIPT" claim 9 claude nopid
INNER
PATH="$NOFLOCK_PATH" SCRIPT="$SCRIPT" tl_run bash "$NOPID_RUN"
assert_eq "unwritable mutex pid note and failing cleanup are tolerated" "0" "$TL_STATUS"
assert_eq "claim with phantom mutex wrote the lock" "nopid" "$(jq -r '."009".intent' "$SB_PHASE_LOCK_FILE")"

# The mutex cannot be taken at all: gives up after the retry budget with exit 1.
FAIL_RUN="$TL_TMP/fail-run.sh"
cat >"$FAIL_RUN" <<'INNER'
mkdir() { return 1; }
sleep() { return 0; }
export -f mkdir sleep
exec bash "$SCRIPT" claim 6 claude never
INNER
PATH="$NOFLOCK_PATH" SCRIPT="$SCRIPT" tl_run bash "$FAIL_RUN"
assert_eq "unobtainable mutex exits 1" "1" "$TL_STATUS"
assert_contains "mutex timeout message" "$TL_ERR" "could not acquire mkdir lock"
assert_eq "no phase 6 lock written" "null" "$(jq -r '."006" // "null"' "$SB_PHASE_LOCK_FILE")"

# --- inherited lock is a no-op for claim, but peek still reads ----------
reset
SB_PHASE_LOCK_INHERITED=true tl_run bash "$SCRIPT" claim 1 claude x
assert_eq "inherited claim exits 0" "0" "$TL_STATUS"
assert_contains "inherited claim is announced" "$TL_ERR" "skipped"
assert_file_absent "inherited claim writes nothing" "$SB_PHASE_LOCK_FILE"

tl_results
