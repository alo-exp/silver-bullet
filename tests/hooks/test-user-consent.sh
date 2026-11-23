#!/usr/bin/env bash
# Tests for hooks/lib/user-consent.sh (per-user consent store) and scripts/sb-consent.sh.
set -euo pipefail

# shellcheck source=../lib/testlib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

LIB="$TL_REPO_ROOT/hooks/lib/user-consent.sh"
CLI="$TL_REPO_ROOT/scripts/sb-consent.sh"
# shellcheck source=../../hooks/lib/user-consent.sh
source "$LIB"

STORE="$HOME/.config/silver-bullet/consent.json"
PROJ="$TL_TMP/proj"
mkdir -p "$PROJ"
PROJ_KEY="$(cd -P "$PROJ" && pwd -P)"

reset_store() { rm -rf "$HOME/.config/silver-bullet"; }
age() { touch -d '10 minutes ago' "$@" 2>/dev/null || touch -t 200001010000 "$@"; }

echo "=== store location ==="
assert_eq "default store path" "$STORE" "$(sb_consent_store_path)"
assert_eq "absolute XDG_CONFIG_HOME honoured" "/x/cfg/silver-bullet/consent.json" "$(XDG_CONFIG_HOME=/x/cfg sb_consent_store_path)"
assert_eq "relative XDG_CONFIG_HOME ignored" "$STORE" "$(XDG_CONFIG_HOME=rel/cfg sb_consent_store_path)"

echo "=== validation helpers ==="
if sb_consent_tool_valid graphify; then tl_pass "graphify is a tool"; else tl_fail "graphify is a tool"; fi
if sb_consent_tool_valid evil; then tl_fail "unknown tool rejected"; else tl_pass "unknown tool rejected"; fi
if sb_consent_tool_valid ""; then tl_fail "empty tool rejected"; else tl_pass "empty tool rejected"; fi
if sb_consent_capability_valid wire; then tl_pass "wire is a capability"; else tl_fail "wire is a capability"; fi
if sb_consent_capability_valid root; then tl_fail "unknown capability rejected"; else tl_pass "unknown capability rejected"; fi

echo "=== project keys ==="
assert_eq "project key is the physical path" "$PROJ_KEY" "$(sb_consent_project_key "$PROJ")"
if sb_consent_project_key "$TL_TMP/missing" >/dev/null; then tl_fail "missing dir has no key"; else tl_pass "missing dir has no key"; fi
if sb_consent_project_key "" >/dev/null; then tl_fail "empty dir has no key"; else tl_pass "empty dir has no key"; fi
NL_DIR="$TL_TMP/new"$'\n'"line"
mkdir -p "$NL_DIR"
if sb_consent_project_key "$NL_DIR" >/dev/null; then tl_fail "newline path has no key"; else tl_pass "newline path has no key"; fi
MAIN="$TL_TMP/main"
mkdir -p "$MAIN/.git/worktrees/wt1" "$TL_TMP/wt1"
printf 'gitdir: %s/.git/worktrees/wt1\n' "$MAIN" >"$TL_TMP/wt1/.git"
assert_eq "worktree maps to its main checkout" "$(cd -P "$MAIN" && pwd -P)" "$(sb_consent_project_key "$TL_TMP/wt1")"
mkdir -p "$TL_TMP/wt2"
printf 'gitdir: ../main/.git/worktrees/wt2' >"$TL_TMP/wt2/.git"
mkdir -p "$MAIN/.git/worktrees/wt2"
assert_eq "relative gitdir without newline maps too" "$(cd -P "$MAIN" && pwd -P)" "$(sb_consent_project_key "$TL_TMP/wt2")"
mkdir -p "$TL_TMP/wt3"
printf 'gitdir: %s/gone/.git/worktrees/wt3\n' "$TL_TMP" >"$TL_TMP/wt3/.git"
assert_eq "worktree of a missing main checkout keeps its own key" "$(cd -P "$TL_TMP/wt3" && pwd -P)" "$(sb_consent_project_key "$TL_TMP/wt3")"
mkdir -p "$TL_TMP/sub"
printf 'gitdir: %s/main/.git/modules/sub\n' "$TL_TMP" >"$TL_TMP/sub/.git"
assert_eq "submodule gitdir keeps its own key" "$(cd -P "$TL_TMP/sub" && pwd -P)" "$(sb_consent_project_key "$TL_TMP/sub")"

echo "=== decisions ==="
reset_store
assert_eq "no store: unset" "unset" "$(sb_consent_decision graphify enforce "$PROJ")"
if sb_consent_store_mentions graphify; then tl_fail "no store mentions nothing"; else tl_pass "no store mentions nothing"; fi
assert_eq "unknown tool: unset" "unset" "$(sb_consent_decision evil enforce)"
reset_store
assert_eq "pi enable words: no consent -> none" "" "$(sb_consent_pi_enable_words)"
sb_consent_set granted rtk wire machine test >/dev/null
sb_consent_set granted leanctx wire machine test >/dev/null
sb_consent_set granted graphify install machine test >/dev/null
assert_eq "pi enable words: wire only; leanctx needs install too; install alone is not wire" " --enable-tool rtk" "$(sb_consent_pi_enable_words)"
sb_consent_set granted leanctx install,wire machine test >/dev/null
assert_eq "pi enable words: leanctx with install+wire" " --enable-tool leanctx --allow-install --enable-tool rtk" "$(sb_consent_pi_enable_words)"
reset_store
assert_eq "unknown capability: unset" "unset" "$(sb_consent_decision graphify root)"

sb_consent_set granted graphify enforce machine test
assert_eq "machine grant" "granted" "$(sb_consent_decision graphify enforce)"
assert_eq "machine grant applies to a project" "granted" "$(sb_consent_decision graphify enforce "$PROJ")"
assert_eq "other capability stays unset" "unset" "$(sb_consent_decision graphify install)"
if sb_consent_store_mentions graphify; then tl_pass "store mentions graphify"; else tl_fail "store mentions graphify"; fi
if sb_consent_store_mentions rtk; then tl_fail "store does not mention rtk"; else tl_pass "store does not mention rtk"; fi
assert_eq "store mode 0600" "600" "$(stat -c %a "$STORE" 2>/dev/null || stat -f %Lp "$STORE")"
if sb_consent_granted graphify enforce; then tl_pass "sb_consent_granted"; else tl_fail "sb_consent_granted"; fi

sb_consent_set declined graphify enforce "$PROJ" test
assert_eq "project record wins over machine" "declined" "$(sb_consent_decision graphify enforce "$PROJ")"
assert_eq "machine record unchanged" "granted" "$(sb_consent_decision graphify enforce)"
if sb_consent_granted graphify enforce "$PROJ"; then tl_fail "declined is not granted"; else tl_pass "declined is not granted"; fi
assert_eq "project key recorded" "declined" "$(jq -r --arg k "$PROJ_KEY" '.projects[$k].graphify.enforce.decision' "$STORE")"
assert_eq "provenance recorded" "test" "$(jq -r --arg k "$PROJ_KEY" '.projects[$k].graphify.enforce.source' "$STORE")"
assert_match "timestamp recorded" '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z$' "$(jq -r --arg k "$PROJ_KEY" '.projects[$k].graphify.enforce.at' "$STORE")"
assert_file_exists "previous version backed up" "${STORE}.bak"

echo "=== idempotence, log, unknown keys ==="
before="$(cat "$STORE")"
sb_consent_set declined graphify enforce "$PROJ" again
assert_eq "same decision changes nothing" "$before" "$(cat "$STORE")"
jq '.user_note = "keep me"' "$STORE" >"$STORE.tmp" && mv "$STORE.tmp" "$STORE"
sb_consent_set granted rtk install,wire machine test
assert_eq "unknown keys preserved" "keep me" "$(jq -r '.user_note' "$STORE")"
assert_eq "log records each change" "3" "$(jq '.log | length' "$STORE")"
assert_eq "log entry fields" "grant rtk machine install,wire" "$(jq -r '.log[-1] | "\(.action) \(.tool) \(.scope) \(.capabilities | join(","))"' "$STORE")"
chmod 640 "$STORE"
sb_consent_set declined rtk wire machine test
assert_eq "file mode kept across writes" "640" "$(stat -c %a "$STORE" 2>/dev/null || stat -f %Lp "$STORE")"
jq '.log = [range(0; 205) | {n: .}]' "$STORE" >"$STORE.tmp" && mv "$STORE.tmp" "$STORE"
sb_consent_set granted alumnium enforce machine test
assert_eq "log keeps the newest 200" "200" "$(jq '.log | length' "$STORE")"
jq '.log = "broken"' "$STORE" >"$STORE.tmp" && mv "$STORE.tmp" "$STORE"
sb_consent_set granted leanctx enforce machine test
assert_eq "non-array log restarts" "1" "$(jq '.log | length' "$STORE")"

echo "=== revoke and prune ==="
sb_consent_set unset graphify enforce "$PROJ" test
assert_eq "revoked project record falls back to machine" "granted" "$(sb_consent_decision graphify enforce "$PROJ")"
assert_eq "empty project entry pruned" "null" "$(jq -r --arg k "$PROJ_KEY" '.projects[$k]' "$STORE")"
sb_consent_set unset rtk install,wire machine test
assert_eq "empty machine tool pruned" "null" "$(jq -r '.machine.rtk' "$STORE")"
sb_consent_set unset graphify install machine test
assert_eq "revoking a missing record is a no-op" "granted" "$(sb_consent_decision graphify enforce)"

echo "=== provenance labels ==="
sb_consent_set granted context_mode enforce machine $'evil\nline;$(id)`x`'
assert_eq "label stripped to printable safe characters" "evilline(id)x" "$(jq -r '.machine.context_mode.enforce.source' "$STORE")"
sb_consent_set granted agentmemory enforce machine $'\n\n'
assert_eq "empty label becomes cli" "cli" "$(jq -r '.machine.agentmemory.enforce.source' "$STORE")"

echo "=== errors ==="
tl_run sb_consent_set maybe graphify enforce machine
assert_eq "bad decision status" "2" "$TL_STATUS"
assert_contains "bad decision message" "$TL_ERR" "decision must be"
tl_run sb_consent_set granted evil enforce machine
assert_contains "bad tool message" "$TL_ERR" "unknown tool: evil"
tl_run sb_consent_set granted graphify "" machine
assert_contains "no capability message" "$TL_ERR" "no capability given"
tl_run sb_consent_set granted graphify enforce,root machine
assert_contains "bad capability message" "$TL_ERR" "unknown capability: root"
tl_run sb_consent_set granted graphify install "$PROJ"
assert_contains "install is machine-wide" "$TL_ERR" "install is machine-wide"
tl_run sb_consent_set granted graphify enforce "$TL_TMP/missing"
assert_contains "missing project dir" "$TL_ERR" "not a directory"
printf 'not json' >"$TL_TMP/bad.json"
cp "$STORE" "$TL_TMP/good.json"
cp "$TL_TMP/bad.json" "$STORE"
tl_run sb_consent_set granted graphify enforce machine
assert_eq "invalid store refused" "2" "$TL_STATUS"
assert_eq "invalid store left untouched" "not json" "$(cat "$STORE")"
assert_eq "invalid store reads as unset" "unset" "$(sb_consent_decision graphify enforce)"
printf '{"machine": []}' >"$STORE"
tl_run sb_consent_set granted graphify enforce machine
assert_contains "malformed machine section refused" "$TL_ERR" "not a valid consent store"
printf '[]' >"$STORE"
assert_eq "non-object store reads as unset" "unset" "$(sb_consent_decision graphify enforce)"
printf '{"machine":{"graphify":"text"}}' >"$STORE"
tl_run sb_consent_set granted graphify enforce machine
assert_contains "jq update failure reported" "$TL_ERR" "could not update"
rm -f "$STORE"
ln -s "$TL_TMP/good.json" "$STORE"
assert_eq "symlinked store is read" "granted" "$(sb_consent_decision graphify enforce)"
tl_run sb_consent_set granted rtk enforce machine
assert_contains "symlinked store is never written through" "$TL_ERR" "symlink"
rm -f "$STORE"
# The store directory cannot be created (a regular file stands where it must go) ...
printf 'x' >"$TL_TMP/notadir"
tl_run env XDG_CONFIG_HOME="$TL_TMP/notadir" bash -c "source '$LIB'; sb_consent_set granted rtk enforce machine"
assert_contains "uncreatable store dir reported" "$TL_ERR" "cannot create"
# ... or a temp file cannot be made in it (no permission tricks: the tests may run as root)
tl_stub mktemp 'exit 1'; hash -r
tl_run sb_consent_set granted rtk enforce machine
assert_contains "unwritable store dir reported" "$TL_ERR" "cannot write"
rm -f "$TL_BIN/mktemp"; hash -r
tl_stub mv 'exit 1'; hash -r
tl_run sb_consent_set granted rtk enforce machine
assert_contains "failed rename reported" "$TL_ERR" "could not replace"
rm -f "$TL_BIN/mv"; hash -r
assert_eq "failed rename leaves no temp file" "" "$(find "$HOME/.config/silver-bullet" -name '.consent.json.*' 2>/dev/null)"

echo "=== status lines ==="
reset_store
sb_consent_set granted leanctx enforce "$PROJ" test
lines="$(sb_consent_status_lines "$PROJ")"
assert_contains "status lists project grant" "$lines" "leanctx enforce granted"
assert_contains "status lists unset pairs" "$lines" "graphify install unset"
assert_eq "status covers every tool and capability" "21" "$(printf '%s\n' "$lines" | wc -l | tr -d ' ')"

echo "=== CLI ==="
reset_store
tl_run bash "$CLI" path
assert_eq "cli path" "$STORE" "$TL_OUT"
tl_run bash "$CLI" grant graphify --project "$PROJ" --source "sb:init (user said yes)"
assert_eq "cli grant status" "0" "$TL_STATUS"
assert_contains "cli grant summary" "$TL_OUT" "grant graphify: install=granted, wire=granted, enforce=granted"
assert_eq "grant --project: enforce for the project" "granted" "$(jq -r --arg k "$PROJ_KEY" '.projects[$k].graphify.enforce.decision' "$STORE")"
assert_eq "grant --project: install for the machine" "granted" "$(jq -r '.machine.graphify.install.decision' "$STORE")"
assert_eq "grant --project: enforce not machine-wide" "null" "$(jq -r '.machine.graphify.enforce' "$STORE")"
assert_eq "cli source label" "sb:init (user said yes)" "$(jq -r '.machine.graphify.install.source' "$STORE")"
tl_run bash "$CLI" check graphify enforce --project "$PROJ"
assert_eq "cli check granted exit 0" "0" "$TL_STATUS"
assert_eq "cli check prints decision" "granted" "$TL_OUT"
tl_run bash "$CLI" check graphify enforce
assert_eq "cli check unset exit 1" "1" "$TL_STATUS"
tl_run bash "$CLI" decline rtk --project "$PROJ"
assert_contains "decline --project notes untouched capabilities" "$TL_ERR" "records enforce only"
assert_eq "decline --project records enforce" "declined" "$(bash "$CLI" check rtk enforce --project "$PROJ" || true)"
assert_eq "decline --project leaves install unset" "unset" "$(bash "$CLI" check rtk install || true)"
tl_run bash "$CLI" decline leanctx --all-projects --capabilities enforce
assert_eq "decline --all-projects" "declined" "$(bash "$CLI" check leanctx enforce || true)"
tl_run bash "$CLI" grant all --all-projects --capabilities enforce
assert_eq "grant all status" "0" "$TL_STATUS"
assert_eq "grant all covers search_cli" "granted" "$(bash "$CLI" check search_cli enforce || true)"
tl_run bash "$CLI" revoke graphify --project "$PROJ"
assert_eq "revoke --project clears the project grant" "unset" "$(jq -r --arg k "$PROJ_KEY" '.projects[$k].graphify.enforce.decision // "unset"' "$STORE")"
assert_eq "revoke --project clears install" "unset" "$(bash "$CLI" check graphify install || true)"
tl_run bash "$CLI" status --project "$PROJ"
assert_contains "status header" "$TL_OUT" "Consent store: $STORE"
assert_contains "status project" "$TL_OUT" "Project: $PROJ_KEY"
assert_contains "status line" "$TL_OUT" "rtk enforce declined"
tl_run bash "$CLI" status
assert_not_contains "status without project omits project line" "$TL_OUT" "Project:"
tl_run bash "$CLI" --help
assert_contains "help" "$TL_OUT" "Usage: sb-consent.sh"
tl_run bash "$CLI"
assert_eq "no command is a usage error" "64" "$TL_STATUS"
for bad in "frobnicate" "path extra" "status extra" "check graphify" "check evil enforce" "check graphify root" \
  "grant" "grant evil --all-projects" "grant graphify" "grant graphify --all-projects --project $PROJ" \
  "grant graphify --all-projects --capabilities root" "grant graphify --bogus" "grant graphify --project" \
  "grant graphify --capabilities" "grant graphify --source"; do
  # shellcheck disable=SC2086 # word splitting builds the argument list on purpose
  tl_run bash "$CLI" $bad
  assert_eq "usage error: $bad" "64" "$TL_STATUS"
done
tl_run bash "$CLI" grant graphify --project "$TL_TMP/missing"
assert_eq "missing project dir" "2" "$TL_STATUS"
printf 'not json' >"$STORE"
tl_run bash "$CLI" grant rtk --all-projects
assert_eq "store write failure exits 2" "2" "$TL_STATUS"
tl_run bash "$CLI" grant rtk --project "$PROJ" --capabilities enforce
assert_eq "project write failure exits 2" "2" "$TL_STATUS"
rm -f "$STORE"
tl_run env PATH="$(tl_path_without jq)" bash "$CLI" path
assert_eq "jq required" "2" "$TL_STATUS"

echo "=== concurrent writers do not lose updates (lock) ==="
reset_store
pids=()
for t in graphify agentmemory alumnium rtk context_mode leanctx search_cli; do
  bash "$CLI" grant "$t" --all-projects --capabilities enforce >/dev/null 2>&1 &
  pids+=("$!")
done
for pid in "${pids[@]}"; do wait "$pid" || true; done
assert_eq "all seven parallel grants are recorded" "7" "$(jq '[.machine[] | select(.enforce.decision == "granted")] | length' "$STORE")"
[[ ! -d "$(dirname "$STORE")/.consent.lock" ]] && tl_pass "the lock is released" || tl_fail "the lock is released"
reset_store
pids=()
for t in graphify agentmemory alumnium rtk; do
  bash "$CLI" grant "$t" --all-projects --capabilities enforce >/dev/null 2>&1
done
for t in graphify agentmemory alumnium rtk; do
  bash "$CLI" revoke "$t" --all-projects --capabilities enforce >/dev/null 2>&1 &
  pids+=("$!")
done
for pid in "${pids[@]}"; do wait "$pid" || true; done
assert_eq "all four parallel revokes are recorded" "0" "$(jq '[.machine // {} | .[] | .enforce // empty] | length' "$STORE")"

echo "=== lock: a lock released while a writer decides whether it is usable is not refused ==="
# The failure the stress rounds below hit twice on a loaded CI runner: exactly one writer of seven exited 2
# ("is not a plain directory of yours") and its grant was lost. The check ran as separate tests (exists? directory?
# mine?), so a writer descheduled between them while another writer released the lock directory saw a path that
# was a directory a moment ago and is gone now, and refused it. Here the DEBUG trap stands in for the scheduler:
# it removes the lock directory right before the Nth command of the check runs, for every position in it
# (command 1 is the call itself, command 3 is the first test of the old three-test check, command 4 its directory test).
LOCK="$(dirname "$STORE")/.consent.lock"
FORCE_N=0; FORCE_SEEN=0; FORCE_FIRED=0
_force_release() {
  [[ "${FUNCNAME[1]:-}" == _sb_consent_lock_sane ]] || return 0
  FORCE_SEEN=$((FORCE_SEEN + 1))
  if ((FORCE_SEEN == FORCE_N)); then FORCE_FIRED=1; rmdir "$LOCK" 2>/dev/null || true; fi
  return 0
}
for FORCE_N in 1 2 3 4 5; do
  reset_store; mkdir -p "$LOCK"; FORCE_SEEN=0; FORCE_FIRED=0
  set -T; trap _force_release DEBUG
  rc=0; sb_consent_set granted rtk enforce machine test 2>"$TL_TMP/force.err" || rc=$?
  trap - DEBUG; set +T
  assert_eq "release before command $FORCE_N of the check: the writer is not refused" "0" "$rc"
  assert_eq "release before command $FORCE_N of the check: the grant is recorded" "granted" "$(sb_consent_decision rtk enforce)"
  [[ -z "$(cat "$TL_TMP/force.err")" ]] && tl_pass "release before command $FORCE_N of the check: nothing on stderr" || tl_fail "release before command $FORCE_N of the check: nothing on stderr: $(cat "$TL_TMP/force.err")"
  if ((FORCE_N <= 3)); then assert_eq "the release really happened inside the check (command $FORCE_N)" "1" "$FORCE_FIRED"; fi
done
reset_store
# What the check still refuses: a symlink (dangling or not), a plain file, a directory that is not ours.
assert_eq "an absent lock path is usable" "0" "$(_sb_consent_lock_sane "$LOCK" && echo 0 || echo 1)"
mkdir -p "$LOCK"
assert_eq "a directory of ours is usable" "0" "$(_sb_consent_lock_sane "$LOCK" && echo 0 || echo 1)"
rmdir "$LOCK"; ln -s "$TL_TMP/nowhere" "$LOCK"
assert_eq "a dangling symlink is refused" "1" "$(_sb_consent_lock_sane "$LOCK" && echo 0 || echo 1)"
rm -f "$LOCK"; ln -s "$TL_TMP" "$LOCK"
assert_eq "a symlink to a directory is refused" "1" "$(_sb_consent_lock_sane "$LOCK" && echo 0 || echo 1)"
rm -f "$LOCK"; : >"$LOCK"
assert_eq "a plain file is refused" "1" "$(_sb_consent_lock_sane "$LOCK" && echo 0 || echo 1)"
rm -f "$LOCK"
if [[ "$(id -u)" == 0 ]]; then
  mkdir "$TL_TMP/foreign"; chown 12345 "$TL_TMP/foreign"; foreign="$TL_TMP/foreign"
else
  foreign=/
fi
assert_eq "a directory owned by someone else is refused" "1" "$(_sb_consent_lock_sane "$foreign" && echo 0 || echo 1)"
reset_store

echo "=== lock: mutual exclusion and no lost update under stale-lock contention (stress) ==="
# Probes: mktemp is the first command inside the critical section and mv the last, so a stub on
# each brackets it. A second writer entering while the sentinel directory exists is a violation
# of mutual exclusion, whatever the lock does internally. The pause widens the window.
PROBE="$TL_TMP/probe"; mkdir -p "$PROBE"; export PROBE
tl_stub mktemp 'real="$(command -v -p mktemp)"; mkdir "$PROBE/in" 2>/dev/null || echo v >>"$PROBE/violations"; sleep 0.02; exec "$real" "$@"'
tl_stub mv 'real="$(command -v -p mv)"; "$real" "$@"; rc=$?; rmdir "$PROBE/in" 2>/dev/null; exit $rc'
hash -r
# A pid no process can have: above the largest the kernel hands out (Linux 2^22 = 4194304, macOS and the BSDs
# 99999). A literal like 999999 is a live pid on a runner that has forked a million processes since boot.
DEAD_PID=5000000
# Every writer is a background job whose own exit status and stderr go to files, so a failure names its cause (which
# writer, which status, which message) instead of only counting. `wait` is only used to block: a bare `wait` once
# reported "not a child of this shell" on a CI image, so the status file, polled until it exists, says how each ended.
writers=()
start_writer() { # ACTION TOOL: one background writer (maximum wait budget); status and stderr in $PROBE/w.<action>.<tool>.{rc,err}
  local w="$PROBE/w.$1.$2"
  # the wait budget is the maximum allowed (1000 tries): the writers run serially behind each other's process start-up,
  # which a CI runner under heavy load stretches past the default (200 tries); this test proves mutual exclusion
  # and no lost update, not the default budget (the budget rows below prove that)
  ( rc=0; SB_CONSENT_LOCK_TRIES=1000 bash "$CLI" "$1" "$2" --all-projects --capabilities enforce >/dev/null 2>"$w.err" || rc=$?; echo "$rc" >"$w.rc" ) &
  writers+=("$!:$w")
}
join_writers() { # wait for every started writer; list each one that did not exit 0, with its stderr, in $PROBE/failed
  local entry w i
  for entry in "${writers[@]}"; do wait "${entry%%:*}" 2>/dev/null || true; done
  for entry in "${writers[@]}"; do
    w="${entry#*:}"; i=0
    while [[ ! -s "$w.rc" ]] && ((i++ < 2000)); do sleep 0.05; done
    [[ "$(cat "$w.rc" 2>/dev/null)" == 0 ]] || echo "${w##*/w.}: status '$(cat "$w.rc" 2>/dev/null)', stderr: $(cat "$w.err" 2>/dev/null)" >>"$PROBE/failed"
  done
  writers=()
}
stress_round() { # KIND: grant seven tools in parallel, print how many were recorded
  local kind="$1" t lock
  reset_store; rm -rf "$PROBE/in" "$PROBE/violations" "$PROBE/failed" "$PROBE"/w.*
  lock="$(dirname "$STORE")/.consent.lock"
  mkdir -p "$lock"
  case "$kind" in
    stale) printf '%s' "$DEAD_PID" >"$lock/pid" ;;
    ownerless) touch -d '10 minutes ago' "$lock" 2>/dev/null || touch -t 200001010000 "$lock" ;;
  esac
  for t in graphify agentmemory alumnium rtk context_mode leanctx search_cli; do start_writer grant "$t"; done
  join_writers
  jq '[.machine[] | select(.enforce.decision == "granted")] | length' "$STORE"
}
lost=0; viol=0; failed=0; ROUNDS="${SB_CONSENT_STRESS_ROUNDS:-30}"
for ((round = 1; round <= ROUNDS; round++)); do
  kind=stale; ((round % 3 == 0)) && kind=ownerless
  n="$(stress_round "$kind")" || n=0
  [[ "$n" == 7 ]] || { lost=$((lost + 1)); echo "  round $round ($kind): recorded $n of 7: $(jq -c '[.machine // {} | keys[]]' "$STORE" 2>&1)"; }
  [[ ! -e "$PROBE/violations" ]] || { viol=$((viol + 1)); echo "  round $round ($kind): two writers inside the critical section"; }
  [[ ! -e "$PROBE/failed" ]] || { failed=$((failed + 1)); echo "  round $round ($kind): a writer did not exit 0"; sed 's/^/    /' "$PROBE/failed"; }
done
assert_eq "$ROUNDS stress rounds: no grant lost" "0" "$lost"
assert_eq "$ROUNDS stress rounds: never two writers at once" "0" "$viol"
assert_eq "$ROUNDS stress rounds: every writer succeeded within the (maximum) wait" "0" "$failed"
# Revokes racing grants behind a stale lock: a revoke must never be lost (a revoked consent that
# survives is worse than a lost grant), and the grants around it all land.
revoke_lost=0; revoke_viol=0; revoke_failed=0
for ((round = 1; round <= 8; round++)); do
  reset_store; rm -rf "$PROBE/in" "$PROBE/violations" "$PROBE/failed" "$PROBE"/w.*
  bash "$CLI" grant rtk --all-projects --capabilities enforce >/dev/null 2>&1
  bash "$CLI" grant agentmemory --all-projects --capabilities enforce >/dev/null 2>&1
  mkdir -p "$(dirname "$STORE")/.consent.lock"; printf '%s' "$DEAD_PID" >"$(dirname "$STORE")/.consent.lock/pid"
  for t in rtk agentmemory; do start_writer revoke "$t"; done
  for t in graphify alumnium context_mode leanctx search_cli; do start_writer grant "$t"; done
  join_writers
  state="$(jq -r '[(.machine // {}) | to_entries[] | select(.value.enforce.decision == "granted") | .key] | sort | join(",")' "$STORE")"
  [[ "$state" == "alumnium,context_mode,graphify,leanctx,search_cli" ]] || { revoke_lost=$((revoke_lost + 1)); echo "  revoke round $round: granted set is '$state'"; }
  [[ ! -e "$PROBE/violations" ]] || revoke_viol=$((revoke_viol + 1))
  [[ ! -e "$PROBE/failed" ]] || { revoke_failed=$((revoke_failed + 1)); echo "  revoke round $round: a writer did not exit 0"; sed 's/^/    /' "$PROBE/failed"; }
done
assert_eq "8 revoke-vs-grant rounds: both revokes and all five grants recorded" "0" "$revoke_lost"
assert_eq "8 revoke-vs-grant rounds: never two writers at once" "0" "$revoke_viol"
assert_eq "8 revoke-vs-grant rounds: every writer succeeded" "0" "$revoke_failed"
rm -f "$TL_BIN/mktemp" "$TL_BIN/mv"; hash -r

echo "=== lock: reclaim touches only claim files, never follows a symlink ==="
reset_store; mkdir -p "$(dirname "$STORE")"
LOCK="$(dirname "$STORE")/.consent.lock"
VICTIM="$TL_TMP/victim"; mkdir -p "$VICTIM"
printf 'important' >"$VICTIM/notes.txt"; printf '12345678 x' >"$VICTIM/pidlike.txt"; printf '999999' >"$VICTIM/claim.1.1"
age "$VICTIM"/*
ln -s "$VICTIM" "$LOCK"
tl_run env SB_CONSENT_LOCK_TRIES=3 bash "$CLI" grant graphify --all-projects --capabilities enforce
assert_eq "a lock path that is a symlink is refused with status 2" "2" "$TL_STATUS"
assert_contains "and the message names the lock" "$TL_ERR" ".consent.lock"
assert_eq "nothing was recorded" "unset" "$(sb_consent_decision graphify enforce)"
assert_eq "every file in the linked directory is untouched" "claim.1.1 notes.txt pidlike.txt" "$(cd "$VICTIM" && echo *)"
[[ -L "$LOCK" ]] && tl_pass "and the link itself is left alone" || tl_fail "and the link itself is left alone"
rm -f "$LOCK"
printf 'x' >"$LOCK"
tl_run env SB_CONSENT_LOCK_TRIES=3 bash "$CLI" revoke graphify --all-projects --capabilities enforce
assert_eq "a lock path that is a plain file is refused with status 2" "2" "$TL_STATUS"
[[ -f "$LOCK" ]] && tl_pass "and is left alone" || tl_fail "and is left alone"
rm -f "$LOCK"
mkdir -p "$LOCK"; printf 'keep' >"$LOCK/notes.txt"; printf '999999' >"$LOCK/pid.bak"; printf '999999' >"$LOCK/claim.x.y"; age "$LOCK"/*
tl_run env SB_CONSENT_LOCK_TRIES=2 bash "$CLI" grant graphify --all-projects --capabilities enforce
assert_eq "a lock directory holding unrelated old files is not reclaimed: status 2" "2" "$TL_STATUS"
assert_eq "and none of them is removed" "claim.x.y notes.txt pid.bak" "$(cd "$LOCK" && echo *)"
rm -rf "$LOCK"; mkdir -p "$LOCK"; ln -s "$VICTIM/notes.txt" "$LOCK/claim.5.5"
tl_run env SB_CONSENT_LOCK_TRIES=2 bash "$CLI" grant graphify --all-projects --capabilities enforce
assert_eq "a claim that is a symlink is not reclaimed: status 2" "2" "$TL_STATUS"
[[ -L "$LOCK/claim.5.5" && "$(cat "$VICTIM/notes.txt")" == important ]] && tl_pass "and neither it nor its target is touched" || tl_fail "and neither it nor its target is touched"
rm -rf "$LOCK"
# a symlink planted after the writer's first look (here: instead of the lock directory) is not followed either
printf '999999' >"$VICTIM/claim.1.1"; age "$VICTIM"/*
tl_stub mkdir 'for a in "$@"; do case "$a" in *.consent.lock) [ -L "$a" ] || ln -s "$TL_VICTIM" "$a"; exit 1;; esac; done; exec "$(command -v -p mkdir)" "$@"'; hash -r
export TL_VICTIM="$VICTIM"
tl_run env SB_CONSENT_LOCK_TRIES=2 bash "$CLI" grant graphify --all-projects --capabilities enforce
assert_eq "a lock directory swapped for a symlink mid-run: status 2" "2" "$TL_STATUS"
assert_eq "and the linked directory is untouched" "claim.1.1 notes.txt pidlike.txt" "$(cd "$VICTIM" && echo *)"
rm -f "$TL_BIN/mkdir" "$LOCK"; hash -r
# a claim whose pid cannot be signalled (another user's writer) is alive: only a missing process is dead
mkdir -p "$LOCK"; printf '999999' >"$LOCK/claim.3.3"
tl_stub ps 'exit 0'; hash -r
tl_run env SB_CONSENT_LOCK_TRIES=2 bash "$CLI" grant graphify --all-projects --capabilities enforce
assert_eq "a pid that kill cannot signal but ps still lists is alive: status 2" "2" "$TL_STATUS"
[[ -f "$LOCK/claim.3.3" ]] && tl_pass "and its claim stays" || tl_fail "and its claim stays"
rm -f "$TL_BIN/ps"; hash -r
tl_run env SB_CONSENT_LOCK_TRIES=2 bash "$CLI" grant graphify --all-projects --capabilities enforce
assert_eq "once ps no longer lists it the claim is dead and reclaimed" "0" "$TL_STATUS"
rm -rf "$LOCK"

echo "=== lock: a stray entry that appears while the lock is held does not fail the write ==="
reset_store
LOCK="$(dirname "$STORE")/.consent.lock"
tl_stub mktemp 'real="$(command -v -p mktemp)"; printf 999999 >"$TL_LOCK/claim.7.7"; exec "$real" "$@"'; hash -r
export TL_LOCK="$LOCK"
tl_run bash "$CLI" grant rtk --all-projects --capabilities enforce
assert_eq "the write succeeds although another claim appeared (release leaves the directory)" "0" "$TL_STATUS"
assert_eq "and is recorded" "granted" "$(sb_consent_decision rtk enforce)"
rm -f "$TL_BIN/mktemp"; hash -r
[[ -d "$LOCK" && -f "$LOCK/claim.7.7" ]] && tl_pass "the leftover claim stays until a later writer reclaims it" || tl_fail "the leftover claim stays until a later writer reclaims it"
tl_run bash "$CLI" grant graphify --all-projects --capabilities enforce
assert_eq "the next writer reclaims the dead leftover and writes" "0" "$TL_STATUS"
assert_eq "and is recorded" "granted" "$(sb_consent_decision graphify enforce)"
[[ ! -d "$LOCK" ]] && tl_pass "and the lock is gone again" || tl_fail "and the lock is gone again"

echo "=== lock: a lock another writer took after the waiter judged the old one stale is left alone ==="
# The race the stress rounds above hit only rarely: a waiter judges the stale lock abandoned, the
# stale lock is released and another writer (this shell, alive) takes a fresh one, and only then does
# the waiter remove what it judged stale. It must not remove the fresh lock. The stub on rm stands in
# for the scheduler: just before the waiter's removal it swaps the stale lock for the fresh one.
reset_store
LOCK="$(dirname "$STORE")/.consent.lock"
mkdir -p "$LOCK"; printf '999999' >"$LOCK/pid"
tl_stub rm 'real="$(command -v -p rm)"; for a in "$@"; do case "$a" in */.consent.lock|*/.consent.lock/pid) if [ ! -e "$TL_FLAG" ]; then : >"$TL_FLAG"; "$real" -rf "${a%/pid}"; mkdir "${a%/pid}"; printf "%s" "$TL_LIVE_PID" >"${a%/pid}/claim.9.9"; fi;; esac; done; exec "$real" "$@"'; hash -r
export TL_FLAG="$TL_TMP/aba" TL_LIVE_PID="$$"; rm -f "$TL_FLAG"
tl_run env SB_CONSENT_LOCK_TRIES=2 bash "$CLI" grant rtk --all-projects --capabilities enforce
assert_eq "the waiter does not enter a lock another writer just took: status 2" "2" "$TL_STATUS"
assert_eq "and records nothing" "unset" "$(sb_consent_decision rtk enforce)"
[[ "$(cat "$LOCK/claim.9.9" 2>/dev/null)" == "$$" ]] && tl_pass "and the other writer's lock is intact" || tl_fail "and the other writer's lock is intact"
rm -f "$TL_BIN/rm"; hash -r; rm -rf "$LOCK"

echo "=== lock: stale owner taken over, live owner waited on ==="
reset_store
LOCK="$(dirname "$STORE")/.consent.lock"
mkdir -p "$LOCK"; printf '999999' >"$LOCK/pid"
sb_consent_set granted rtk enforce machine test >/dev/null && tl_pass "a lock held by a dead process is taken over" || tl_fail "a lock held by a dead process is taken over"
assert_eq "grant after takeover recorded" "granted" "$(sb_consent_decision rtk enforce)"
mkdir -p "$LOCK"; printf '%s' "$$" >"$LOCK/pid"
tl_run env SB_CONSENT_LOCK_TRIES=2 bash "$CLI" grant graphify --all-projects --capabilities enforce
assert_eq "a live lock owner makes the writer give up with status 2" "2" "$TL_STATUS"
assert_contains "the message names the lock" "$TL_ERR" ".consent.lock"
assert_eq "nothing was written while the lock was held" "unset" "$(sb_consent_decision graphify enforce)"
rm -rf "$LOCK"
# the fresh lock directory is removed under its creator (an empty directory looks abandoned to a
# waiter): the claim cannot land, so the writer retries instead of proceeding unlocked
tl_stub mkdir 'real="$(command -v -p mkdir)"; "$real" "$@" || exit $?; for a in "$@"; do case "$a" in *.consent.lock) if [ ! -e "$TL_FLAG" ]; then : >"$TL_FLAG"; rmdir "$a"; fi;; esac; done'; hash -r
reset_store
export TL_FLAG="$TL_TMP/once"; rm -f "$TL_FLAG"
sb_consent_set granted rtk enforce machine test >/dev/null && tl_pass "a lock directory removed under its creator is retaken" || tl_fail "a lock directory removed under its creator is retaken"
assert_eq "and the grant is recorded" "granted" "$(sb_consent_decision rtk enforce)"
[[ ! -d "$LOCK" ]] && tl_pass "and the lock is released" || tl_fail "and the lock is released"
# another writer's claim lands next to ours (the directory was replaced under us): we are not the
# sole claimant, so we withdraw our claim and write nothing
tl_stub mkdir 'real="$(command -v -p mkdir)"; "$real" "$@" || exit $?; for a in "$@"; do case "$a" in *.consent.lock) printf "%s" "$TL_LIVE_PID" >"$a/claim.1.1";; esac; done'; hash -r
reset_store
export TL_LIVE_PID="$$"
tl_run env SB_CONSENT_LOCK_TRIES=2 bash "$CLI" grant graphify --all-projects --capabilities enforce
assert_eq "a claim that is not alone: the writer gives up with status 2" "2" "$TL_STATUS"
assert_contains "and says nothing was recorded" "$TL_ERR" "nothing was recorded"
assert_eq "and writes nothing" "unset" "$(sb_consent_decision graphify enforce)"
[[ -f "$LOCK/claim.1.1" && "$(find "$LOCK" -type f | wc -l | tr -d ' ')" == 1 ]] && tl_pass "the other claim is untouched and ours is withdrawn" || tl_fail "the other claim is untouched and ours is withdrawn"
rm -rf "$LOCK"
rm -f "$TL_BIN/mkdir"; hash -r
mkdir -p "$LOCK"
(sleep 0.3; rm -rf "$LOCK") &
bgpid=$!
tl_run env SB_CONSENT_LOCK_TRIES=50 bash "$CLI" grant graphify --all-projects --capabilities enforce
wait "$bgpid" || true
assert_eq "a writer waits for a lock that has no claim yet" "0" "$TL_STATUS"
assert_eq "and then records" "granted" "$(sb_consent_decision graphify enforce)"
reset_store
printf 'file' >"$HOME/.config-blocker" 2>/dev/null || true
tl_run env XDG_CONFIG_HOME="$HOME/.config-blocker" bash "$CLI" grant rtk --all-projects --capabilities enforce
assert_eq "an uncreatable store directory is a clean error" "2" "$TL_STATUS"

echo "=== the backup is not written through a symlink ==="
reset_store
sb_consent_set granted rtk enforce machine test >/dev/null
VICTIM_BAK="$TL_TMP/victim-bak"; printf 'precious\n' >"$VICTIM_BAK"
ln -s "$VICTIM_BAK" "${STORE}.bak"
sb_consent_set granted graphify enforce machine test >/dev/null
assert_eq "the symlink target is untouched" "precious" "$(cat "$VICTIM_BAK")"
[[ -f "${STORE}.bak" && ! -L "${STORE}.bak" ]] && tl_pass "the backup is a regular file" || tl_fail "the backup is a regular file"
assert_eq "the backup holds the previous version" "unset" "$(jq -r '.machine.graphify.enforce.decision // "unset"' "${STORE}.bak")"

echo "=== CLI: --project resolves to the project root ==="
reset_store
SUBPROJ="$TL_TMP/sbproj"; mkdir -p "$SUBPROJ/src/deep"; printf '{}' >"$SUBPROJ/.silver-bullet.json"
SUBKEY="$(cd -P "$SUBPROJ" && pwd -P)"
tl_run bash "$CLI" grant rtk --project "$SUBPROJ/src/deep" --capabilities enforce
assert_eq "grant from a subdirectory succeeds" "0" "$TL_STATUS"
assert_eq "the decision is recorded for the project root" "granted" "$(sb_consent_decision rtk enforce "$SUBPROJ")"
assert_eq "no key was recorded for the subdirectory" "false" "$(jq --arg k "$SUBKEY/src/deep" '.projects | has($k)' "$STORE")"
tl_run bash "$CLI" grant graphify --project "$PROJ" --capabilities enforce
assert_eq "a directory outside any SB project is recorded as given" "granted" "$(sb_consent_decision graphify enforce "$PROJ")"

echo "=== lock: abandoned claims, ownerless lock, bad tries ==="
reset_store
LOCK="$(dirname "$STORE")/.consent.lock"
mkdir -p "$LOCK"; age "$LOCK"
tl_run env SB_CONSENT_LOCK_TRIES=3 bash "$CLI" grant graphify --all-projects --capabilities enforce
assert_eq "an old lock directory without any claim is reclaimed" "0" "$TL_STATUS"
assert_eq "and the grant is recorded" "granted" "$(sb_consent_decision graphify enforce)"
mkdir -p "$LOCK"
tl_run env SB_CONSENT_LOCK_TRIES=2 bash "$CLI" grant rtk --all-projects --capabilities enforce
assert_eq "a fresh lock directory without a claim (its creator is mid-write) is waited on: status 2" "2" "$TL_STATUS"
assert_eq "and nothing was recorded" "unset" "$(sb_consent_decision rtk enforce)"
rm -rf "$LOCK"; mkdir -p "$LOCK"; printf 'junk' >"$LOCK/pid"
tl_run env SB_CONSENT_LOCK_TRIES=2 bash "$CLI" grant rtk --all-projects --capabilities enforce
assert_eq "a fresh claim without a pid is not reclaimed: status 2" "2" "$TL_STATUS"
age "$LOCK/pid"
tl_run env SB_CONSENT_LOCK_TRIES=2 bash "$CLI" grant rtk --all-projects --capabilities enforce
assert_eq "an old claim without a pid is reclaimed" "0" "$TL_STATUS"
rm -rf "$LOCK"; mkdir -p "$LOCK"; printf '%s' "$$" >"$LOCK/pid"; age "$LOCK/pid"
tl_run env SB_CONSENT_LOCK_TRIES=2 bash "$CLI" grant agentmemory --all-projects --capabilities enforce
assert_eq "a claim older than ten minutes is reclaimed even when its pid is alive (reused pid)" "0" "$TL_STATUS"
rm -rf "$LOCK"; mkdir -p "$LOCK/pid"
tl_run env SB_CONSENT_LOCK_TRIES=2 bash "$CLI" grant alumnium --all-projects --capabilities enforce
assert_eq "an entry that is not a claim file is never removed: status 2" "2" "$TL_STATUS"
[[ -d "$LOCK/pid" ]] && tl_pass "and it is left in place" || tl_fail "and it is left in place"
rm -rf "$LOCK"
mkdir -p "$LOCK"; printf '999999' >"$LOCK/pid"; printf '%s' "$$" >"$LOCK/claim.2.2"
tl_run env SB_CONSENT_LOCK_TRIES=2 bash "$CLI" grant alumnium --all-projects --capabilities enforce
assert_eq "one dead and one live claim: only the dead one goes, the lock stays held: status 2" "2" "$TL_STATUS"
[[ ! -e "$LOCK/pid" && -e "$LOCK/claim.2.2" ]] && tl_pass "the dead claim was removed by name, the live one kept" || tl_fail "the dead claim was removed by name, the live one kept"
rm -rf "$LOCK"
# SB_CONSENT_LOCK_TRIES: an integer from 1 to 1000, anything else means 200. The wait is one sleep per
# try, so counting the sleeps of a writer that gives up measures the budget without waiting for it.
export TL_SLEEPS="$TL_TMP/sleeps"
tl_stub sleep 'echo s >>"$TL_SLEEPS"'; hash -r
mkdir -p "$LOCK"; printf '%s' "$$" >"$LOCK/pid"
for pair in "5:4" "1000:999" "1001:199" "abc:199" "0:199" "-5:199" "1.5:199" "99999999999999999999:199" ":199"; do
  tries="${pair%%:*}"; want="${pair##*:}"; rm -f "$TL_TMP/sleeps"; : >"$TL_TMP/sleeps"
  tl_run env SB_CONSENT_LOCK_TRIES="$tries" bash "$CLI" grant rtk --all-projects --capabilities enforce
  assert_eq "SB_CONSENT_LOCK_TRIES='$tries': a live lock ends in status 2" "2" "$TL_STATUS"
  assert_eq "SB_CONSENT_LOCK_TRIES='$tries': $want waits" "$want" "$(wc -l <"$TL_TMP/sleeps" | tr -d ' ')"
done
rm -f "$TL_BIN/sleep"; hash -r
rm -rf "$LOCK"
for bad in abc -5 0 "" 1.5 1001 99999999999999999999; do
  tl_run env SB_CONSENT_LOCK_TRIES="$bad" bash "$CLI" grant rtk --all-projects --capabilities enforce
  assert_eq "SB_CONSENT_LOCK_TRIES='$bad' with no lock: grant works" "0" "$TL_STATUS"
done
# a lock that cannot be taken is an error for every command, not a silent success
reset_store
bash "$CLI" grant rtk --all-projects --capabilities enforce >/dev/null
mkdir -p "$LOCK"; printf '%s' "$$" >"$LOCK/pid"
for cmd in grant decline revoke; do
  tl_run env SB_CONSENT_LOCK_TRIES=2 bash "$CLI" "$cmd" rtk --all-projects --capabilities enforce
  assert_eq "$cmd with the lock held: status 2" "2" "$TL_STATUS"
done
assert_eq "the revoke that could not run left the grant as it was" "granted" "$(sb_consent_decision rtk enforce)"
rm -rf "$LOCK"

tl_results
