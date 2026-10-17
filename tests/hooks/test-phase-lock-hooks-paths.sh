#!/usr/bin/env bash
# Path coverage for hooks/phase-lock-{claim,heartbeat,release}.sh and hooks/lib/phase-path.sh,
# driven against a stub .planning/scripts/phase-lock.sh helper with scripted exit codes.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/dgates-helpers.sh"
tl_init

P="$TL_TMP/proj"
dg_project "$P"
mkdir -p "$P/.planning/scripts" "$P/.planning/phases/099-x" "$TL_TMP/outside"
LOG="$TL_TMP/helper.log"
cat >"$P/.planning/scripts/phase-lock.sh" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$PL_LOG"
case "$1" in
  claim) [[ -n "${PL_CLAIM_ERR:-}" ]] && echo "$PL_CLAIM_ERR" >&2; exit "${PL_CLAIM_RC:-0}" ;;
  peek) printf '%s' "${PL_PEEK:-}"; exit "${PL_PEEK_RC:-0}" ;;
  heartbeat) exit "${PL_HB_RC:-0}" ;;
  release) [[ -n "${PL_REL_ERR:-}" ]] && echo "$PL_REL_ERR" >&2; exit "${PL_REL_RC:-0}" ;;
esac
STUB
chmod +x "$P/.planning/scripts/phase-lock.sh"
ST="$SB_RUNTIME_STATE_DIR"
export PL_LOG="$LOG"

edit() { jq -cn --arg p "$1" --arg s "${2:-}" '{hook_event_name:"PreToolUse",tool_name:"Edit",tool_input:{file_path:$p},session_id:$s}'; }
manifest() { printf '%s/claimed-phases-%s.txt' "$ST" "$1"; }
reset() { rm -f "$ST"/claimed-phases-* "$ST"/heartbeat-* "$LOG"; }

# ======================= hooks/lib/phase-path.sh =========================
# shellcheck source=../../hooks/lib/phase-path.sh
source "$TL_REPO_ROOT/hooks/lib/phase-path.sh"
assert_eq "resolve: relative phase dir" "071" "$(_resolve_phase_from_path ".planning/phases/071-foo/bar.md")"
assert_eq "resolve: absolute bare phase dir" "071" "$(_resolve_phase_from_path "/abs/.planning/phases/071/")"
assert_eq "resolve: non-phase path" "" "$(_resolve_phase_from_path "/etc/passwd")"
assert_eq "resolve: non-numeric phase" "" "$(_resolve_phase_from_path ".planning/phases/abc-foo/")"
assert_eq "resolve: empty arg" "" "$(_resolve_phase_from_path "")"

peek_run() { # cwd -> stderr text of the EXIT-trap helper
  local err
  err="$(cd "$1" && PL_PEEK="${2:-}" PL_PEEK_RC="${3:-0}" bash -c 'source "$0/hooks/lib/runtime-paths.sh"; source "$0/hooks/lib/phase-path.sh"; _phase_lock_peek_on_exit; echo "rc=$?"' "$TL_REPO_ROOT" 2>&1 >/dev/null || true)"
  printf '%s' "$err"
}
peek_rc() {
  (cd "$1" && bash -c 'source "$0/hooks/lib/runtime-paths.sh"; source "$0/hooks/lib/phase-path.sh"; (exit 7); _phase_lock_peek_on_exit' "$TL_REPO_ROOT") >/dev/null 2>&1 || echo $?
}
mkdir -p "$P/.planning/phases/099-x/sub"
assert_eq "peek: outside a phase dir is silent" "" "$(peek_run "$P")"
assert_contains "peek: no active lock warns" "$(peek_run "$P/.planning/phases/099-x/sub" "")" "phase 099 has no active lock"
assert_contains "peek: foreign owner warns with owner id" "$(peek_run "$P/.planning/phases/099-x" '{"agent_runtime":"other","owner_id":"abc"}')" "locked by abc"
assert_not_contains "peek: own runtime stays quiet" "$(peek_run "$P/.planning/phases/099-x" "{\"agent_runtime\":\"$SB_RUNTIME_NAME\",\"owner_id\":\"me\"}")" "WARN"
assert_not_contains "peek: no helper in any ancestor is silent" "$(peek_run "$TL_TMP/outside")" "WARN"
mkdir -p "$TL_TMP/nohelper/.planning/phases/050-y"
assert_not_contains "peek: phase dir without helper is silent" "$(peek_run "$TL_TMP/nohelper/.planning/phases/050-y")" "WARN"
assert_contains "peek: failing helper counts as no lock" "$(peek_run "$P/.planning/phases/099-x" '' 1)" "has no active lock"
assert_eq "peek: preserves the caller's exit status" 7 "$(peek_rc "$P/.planning/phases/099-x")"
assert_eq "peek: jq missing preserves status quietly" "rc=0" "$(cd "$P/.planning/phases/099-x" && PATH="$(tl_path_without jq)" bash -c 'source "$0/hooks/lib/runtime-paths.sh"; source "$0/hooks/lib/phase-path.sh"; _phase_lock_peek_on_exit; echo "rc=$?"' "$TL_REPO_ROOT" 2>/dev/null)"
assert_contains "peek: unparsable owner JSON falls back to ?" "$(peek_run "$P/.planning/phases/099-x" 'not json')" "locked by ?"

# ======================= phase-lock-claim.sh =============================
H=hooks/phase-lock-claim.sh
reset
dg_run "$P" "$H" "$(edit "$P/.planning/phases/099-x/a.md" s1)" SB_PHASE_LOCK_INHERITED=true
assert_eq "claim: inherited lock short-circuits" 0 "$TL_STATUS"
assert_file_absent "claim: inherited writes no manifest" "$(manifest s1)"
dg_run_nojq "$P" "$H" "$(edit "$P/.planning/phases/099-x/a.md" s1)"
assert_contains "claim: no jq warns" "$TL_OUT" "ENFORCEMENT INACTIVE"
dg_run "$TL_TMP/outside" "$H" "$(edit "$P/.planning/phases/099-x/a.md" s1)"
assert_eq "claim: outside project" 0 "$TL_STATUS"
rm -f "$ST/project-root"
dg_run_nolib_in "$P" "$H" "$(edit "$P/.planning/phases/099-x/a.md" s1)"
assert_contains "claim: missing libs reports and skips" "$TL_OUT" "phase-path.sh missing"
dg_run "$P" "$H" "$(edit "" s1)"
assert_eq "claim: empty file path ignored" "" "$TL_OUT"
dg_assert_ok "claim: empty file path ignored: exits 0"
dg_run "$P" "$H" "$(edit "$P/src/a.sh" s1)"
assert_file_absent "claim: non-phase path ignored" "$(manifest s1)"

dg_run "$P" "$H" "$(edit "$P/.planning/phases/099-x/a.md" s1)"
assert_eq "claim: success exits 0" 0 "$TL_STATUS"
assert_eq "claim: manifest records phase" "099" "$(cat "$(manifest s1)")"
assert_contains "claim: helper called with runtime and intent" "$(cat "$LOG")" "claim 099 $SB_RUNTIME_NAME Edit a.md"
: >"$LOG"
dg_run "$P" "$H" "$(edit "$P/.planning/phases/099-x/b.md" s1)"
assert_eq "claim: second claim in same session is idempotent" "" "$(cat "$LOG")"
assert_eq "claim: manifest not duplicated" "1" "$(wc -l <"$(manifest s1)" | tr -d ' ')"

reset
dg_run "$P" "$H" "$(edit "$P/.planning/phases/099-x/a.md" 'we/ird id')"
assert_file_exists "claim: session id sanitised for manifest name" "$(manifest we_ird_id)"
reset
dg_run "$P" "$H" "$(jq -cn --arg p "$P/.planning/phases/099-x/a.md" '{tool_name:"Edit",tool_input:{file_path:$p}}')"
assert_eq "claim: missing session id still claims" 0 "$TL_STATUS"
assert_match "claim: fallback session manifest created" 'claimed-phases-[0-9]+-[0-9]+\.txt' "$(ls "$ST")"
reset

dg_run "$P" "$H" "$(edit "$P/.planning/phases/099-x/a.md" s2)" PL_CLAIM_RC=2 PL_CLAIM_ERR=owned-elsewhere PL_PEEK='{"agent_runtime":"codex","owner_id":"o-1"}'
assert_eq "claim: conflict exits 2" 2 "$TL_STATUS"
assert_contains "claim: conflict names owner" "$TL_ERR" "locked by codex (owner_id=o-1)"
assert_contains "claim: conflict shows intent" "$TL_ERR" "Attempted intent: Edit a.md"
assert_contains "claim: conflict relays helper stderr" "$TL_ERR" "owned-elsewhere"
assert_contains "claim: conflict hint" "$TL_ERR" "phase-lock.sh peek 099"
assert_file_absent "claim: conflict writes no manifest" "$(manifest s2)"
dg_run "$P" "$H" "$(edit "$P/.planning/phases/099-x/a.md" s2)" PL_CLAIM_RC=2 PL_PEEK='garbage'
assert_contains "claim: unparsable owner falls back to ?" "$TL_ERR" "locked by ? (owner_id=?)"
assert_not_contains "claim: no helper stderr line when empty" "$TL_ERR" "owned-elsewhere"
dg_run "$P" "$H" "$(edit "$P/.planning/phases/099-x/a.md" s2)" PL_CLAIM_RC=2 PL_PEEK_RC=1
assert_contains "claim: failing peek still reports the conflict" "$TL_ERR" "PHASE LOCK CONFLICT"
assert_eq "claim: failing peek still exits 2" 2 "$TL_STATUS"
dg_run "$P" "$H" "$(edit "$P/.planning/phases/099-x/a.md" s2)" PL_CLAIM_RC=4
assert_eq "claim: unexpected helper rc fails open" 0 "$TL_STATUS"
assert_contains "claim: unexpected rc is reported" "$TL_OUT" "helper exit 4"
assert_file_absent "claim: unexpected rc writes no manifest" "$(manifest s2)"

chmod -x "$P/.planning/scripts/phase-lock.sh"
dg_run "$P" "$H" "$(edit "$P/.planning/phases/099-x/a.md" s3)"
assert_contains "claim: non-executable helper skipped" "$TL_OUT" "not executable"
chmod +x "$P/.planning/scripts/phase-lock.sh"

dg_run "$P" "$H" "$(edit "$P/.planning/phases/099-x/a.md" s3)" SB_RUNTIME_PRESERVE_STATE_DIR=1 SB_RUNTIME_STATE_DIR="$TL_TMP/escape"
assert_contains "claim: manifest path outside runtime root refused" "$TL_OUT" "escaped the host runtime state root"
assert_eq "claim: no manifest written outside runtime root" "" "$(ls "$TL_TMP"/escape/claimed-phases-* 2>/dev/null || true)"

# manifest append goes through sb_safe_write: a symlinked manifest is replaced, not followed
ln -s "$TL_TMP/victim" "$(manifest s4)"
dg_run "$P" "$H" "$(edit "$P/.planning/phases/099-x/a.md" s4)"
assert_file_absent "claim: symlinked manifest is not written through" "$TL_TMP/victim"
rm -f "$(manifest s4)"

# unwritable state dir does not break the hook
echo blocker >"$SB_RUNTIME_HOME_ROOT/.silver-bullet/blocker"
dg_run "$P" "$H" "$(edit "$P/.planning/phases/099-x/a.md" s5)" SB_RUNTIME_PRESERVE_STATE_DIR=1 SB_RUNTIME_STATE_DIR="$SB_RUNTIME_HOME_ROOT/.silver-bullet/blocker/sub"
assert_eq "claim: unusable state dir tolerated" 0 "$TL_STATUS"
rm -f "$SB_RUNTIME_HOME_ROOT/.silver-bullet/blocker"

# native Codex apply_patch payloads resolve the phase from the patch header
dg_run "$P" "$H" "$(jq -cn --arg i "*** Begin Patch
*** Update File: .planning/phases/099-x/patched.md
@@
+x
*** End Patch" '{hook_event_name:"PreToolUse",tool_name:"apply_patch",tool_input:{input:$i},session_id:"s6"}')"
assert_eq "claim: apply_patch header drives phase resolution" "099" "$(cat "$(manifest s6)" 2>/dev/null || true)"
reset

# ======================= phase-lock-heartbeat.sh =========================
H=hooks/phase-lock-heartbeat.sh
hb_json() { jq -cn --arg s "$1" '{hook_event_name:"PostToolUse",session_id:$s}'; }
printf '099\n' >"$(manifest h1)"
dg_run "$P" "$H" "$(hb_json h1)" SB_PHASE_LOCK_INHERITED=true
assert_eq "heartbeat: inherited short-circuits" "" "$(cat "$LOG" 2>/dev/null || true)"
dg_run_nojq "$P" "$H" "$(hb_json h1)"
assert_contains "heartbeat: no jq warns" "$TL_OUT" "ENFORCEMENT INACTIVE"
dg_run "$TL_TMP/outside" "$H" "$(hb_json h1)"
assert_eq "heartbeat: outside project is inert" "" "$(cat "$LOG" 2>/dev/null || true)"
rm -f "$ST/project-root"
chmod -x "$P/.planning/scripts/phase-lock.sh"
dg_run "$P" "$H" "$(hb_json h1)"
assert_eq "heartbeat: missing helper is a no-op" "" "$(cat "$LOG" 2>/dev/null || true)"
chmod +x "$P/.planning/scripts/phase-lock.sh"
dg_run "$P" "$H" "$(hb_json nomanifest)"
assert_eq "heartbeat: no manifest is a no-op" "" "$(cat "$LOG" 2>/dev/null || true)"
dg_run "$P" "$H" '{"hook_event_name":"PostToolUse"}'
assert_eq "heartbeat: no session id uses a fresh one (no manifest)" 0 "$TL_STATUS"
: >"$(manifest empty)"
dg_run "$P" "$H" "$(hb_json empty)"
assert_eq "heartbeat: empty manifest is a no-op" "" "$(cat "$LOG" 2>/dev/null || true)"
dg_run "$P" "$H" "$(hb_json h1)" SB_RUNTIME_PRESERVE_STATE_DIR=1 SB_RUNTIME_STATE_DIR="$TL_TMP/escape"
assert_eq "heartbeat: manifest outside runtime root ignored" "" "$(cat "$LOG" 2>/dev/null || true)"
ln -s "$(manifest h1)" "$(manifest linked)"
dg_run "$P" "$H" "$(hb_json linked)"
assert_eq "heartbeat: symlinked manifest ignored" "" "$(cat "$LOG" 2>/dev/null || true)"
rm -f "$(manifest linked)"

printf '\nabc\n099\n' >"$(manifest h2)"
dg_run "$P" "$H" "$(hb_json h2)"
assert_eq "heartbeat: blank and malformed entries skipped, valid phase beaten" "heartbeat 099 $SB_RUNTIME_NAME" "$(cat "$LOG")"
assert_file_exists "heartbeat: throttle file created" "$ST/heartbeat-099"
: >"$LOG"
dg_run "$P" "$H" "$(hb_json h2)"
assert_eq "heartbeat: throttled within 300s" "" "$(cat "$LOG")"
touch -d '2001-01-01' "$ST/heartbeat-099"
dg_run "$P" "$H" "$(hb_json h2)"
assert_eq "heartbeat: stale throttle beats again" "heartbeat 099 $SB_RUNTIME_NAME" "$(cat "$LOG")"

# stat fallbacks
: >"$LOG"; touch "$ST/heartbeat-099"
tl_stub stat 'exit 1'
dg_run "$P" "$H" "$(hb_json h2)"
assert_eq "heartbeat: stat unavailable treats throttle as expired" "heartbeat 099 $SB_RUNTIME_NAME" "$(cat "$LOG")"
tl_stub stat 'if [[ "$1" == "-c" ]]; then exit 1; fi; date +%s'
: >"$LOG"; touch "$ST/heartbeat-099"
dg_run "$P" "$H" "$(hb_json h2)"
assert_eq "heartbeat: BSD stat -f fallback throttles" "" "$(cat "$LOG")"
rm -f "$TL_BIN/stat"
hash -r

dg_run "$P" "$H" "$(hb_json h2)" PL_HB_RC=2
rm -f "$ST/heartbeat-099"
dg_run "$P" "$H" "$(hb_json h2)" PL_HB_RC=2
assert_contains "heartbeat: helper failure is reported" "$TL_ERR" "heartbeat skipped for phase 099 (helper rc=2)"
assert_file_absent "heartbeat: failure leaves no throttle file" "$ST/heartbeat-099"
assert_eq "heartbeat: failure still exits 0" 0 "$TL_STATUS"

# no libs: inline sb_safe_write replaces a symlinked throttle file
rm -f "$ST/heartbeat-099"
ln -s "$TL_TMP/hb-victim" "$ST/heartbeat-099"
dg_run_nolib_in "$P" "$H" "$(hb_json h2)"
assert_eq "heartbeat(no libs): exits 0" 0 "$TL_STATUS"
assert_file_absent "heartbeat(no libs): symlink target untouched" "$TL_TMP/hb-victim"
assert_eq "heartbeat(no libs): throttle is now a regular file" "yes" "$([[ -f "$ST/heartbeat-099" && ! -L "$ST/heartbeat-099" ]] && echo yes || echo no)"
reset

# ======================= phase-lock-release.sh ===========================
H=hooks/phase-lock-release.sh
printf '099\n\nxyz\n098\n' >"$(manifest r1)"
dg_run "$P" "$H" "$(hb_json r1)" SB_PHASE_LOCK_INHERITED=true
assert_file_exists "release: inherited leaves manifest" "$(manifest r1)"
dg_run_nojq "$P" "$H" "$(hb_json r1)"
assert_contains "release: no jq warns" "$TL_OUT" "ENFORCEMENT INACTIVE"
dg_run "$TL_TMP/outside" "$H" "$(hb_json r1)"
assert_file_exists "release: outside project is inert" "$(manifest r1)"
rm -f "$ST/project-root"
chmod -x "$P/.planning/scripts/phase-lock.sh"
dg_run "$P" "$H" "$(hb_json r1)"
assert_file_exists "release: missing helper leaves manifest" "$(manifest r1)"
chmod +x "$P/.planning/scripts/phase-lock.sh"
dg_run "$P" "$H" "$(hb_json none)"
assert_eq "release: no manifest exits 0" 0 "$TL_STATUS"
dg_run "$P" "$H" '{}'
assert_eq "release: no session id exits 0" 0 "$TL_STATUS"
dg_run "$P" "$H" "$(hb_json r1)" SB_RUNTIME_PRESERVE_STATE_DIR=1 SB_RUNTIME_STATE_DIR="$TL_TMP/escape"
assert_file_exists "release: manifest outside runtime root ignored" "$(manifest r1)"
: >"$LOG"
dg_run "$P" "$H" "$(hb_json r1)" PL_REL_RC=2 PL_REL_ERR=not-owner
assert_eq "release: valid entries released, junk skipped" "release 099 $SB_RUNTIME_NAME
release 098 $SB_RUNTIME_NAME" "$(cat "$LOG")"
assert_contains "release: non-zero rc reported with helper stderr" "$TL_ERR" "phase 099 rc=2: not-owner"
assert_contains "release: continues past a failing entry" "$TL_ERR" "phase 098 rc=2"
assert_file_absent "release: manifest removed afterwards" "$(manifest r1)"

printf '099\n' >"$(manifest r2)"
dg_run "$P" "$H" "$(hb_json r2)"
assert_eq "release: clean release is quiet" "" "$TL_ERR"
assert_file_absent "release: manifest cleared" "$(manifest r2)"
printf '099\n' >"$TL_TMP/real-manifest"
ln -s "$TL_TMP/real-manifest" "$(manifest r3)"
dg_run "$P" "$H" "$(hb_json r3)"
assert_file_exists "release: symlinked manifest is skipped entirely" "$TL_TMP/real-manifest"
rm -f "$(manifest r3)"
printf '099\n' >"$(manifest r4)"
dg_run_nolib_in "$P" "$H" "$(hb_json r4)"
assert_file_absent "release(no libs): still releases and clears" "$(manifest r4)"

tl_results
