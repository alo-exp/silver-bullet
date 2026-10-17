#!/usr/bin/env bash
# Library-fallback paths of the D-gates hooks, exercised by running a staged copy of hooks/
# with individual libraries (or tool-input helpers) removed.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/dgates-helpers.sh"
tl_init

P="$TL_TMP/proj"
dg_project "$P"
mkdir -p "$P/.planning/scripts" "$P/.planning/phases/099-x" "$TL_TMP/outside"
ST="$SB_RUNTIME_STATE_DIR"
dec() { [[ -n "$TL_OUT" ]] && jq -r '.hookSpecificOutput.permissionDecision // .decision // "none"' <<<"$TL_OUT" 2>/dev/null || echo none; }

# ---- phase-lock-claim: nofollow-guard.sh missing -> inline sb_safe_write ----
cat >"$P/.planning/scripts/phase-lock.sh" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
chmod +x "$P/.planning/scripts/phase-lock.sh"
S1="$TL_TMP/s1"; dg_stage_hooks "$S1" nofollow-guard.sh
CLAIM="$(jq -cn --arg p "$P/.planning/phases/099-x/a.md" '{tool_name:"Edit",tool_input:{file_path:$p},session_id:"sa"}')"
dg_run "$P" "$S1/hooks/phase-lock-claim.sh" "$CLAIM"
assert_eq "claim(no nofollow-guard): still claims" "099" "$(cat "$ST/claimed-phases-sa.txt")"
rm -f "$ST/claimed-phases-sa.txt"; ln -s "$TL_TMP/victim" "$ST/claimed-phases-sa.txt"
dg_run "$P" "$S1/hooks/phase-lock-claim.sh" "$CLAIM"
assert_file_absent "claim(no nofollow-guard): symlinked manifest replaced, not followed" "$TL_TMP/victim"
assert_eq "claim(no nofollow-guard): manifest now regular" "yes" "$([[ -f "$ST/claimed-phases-sa.txt" && ! -L "$ST/claimed-phases-sa.txt" ]] && echo yes || echo no)"
rm -f "$ST/claimed-phases-sa.txt"

# ---- phase-lock-claim: tool-input.sh missing -> jq file_path extraction ----
S2="$TL_TMP/s2"; dg_stage_hooks "$S2" tool-input.sh
dg_run "$P" "$S2/hooks/phase-lock-claim.sh" "$CLAIM"
assert_eq "claim(no tool-input): jq extraction claims the phase" "099" "$(cat "$ST/claimed-phases-sa.txt")"
rm -f "$ST/claimed-phases-sa.txt"

# ---- site hooks: tool-input helpers missing / failing ----
SESS="$ST/site-session.json"
echo '{"active":true,"touch_reason":"site-intent","push_intent":true}' >"$SESS"
mkdir -p "$P/tests/scripts"
for s in chrome-regression doc-freshness content-freshness; do printf '#!/usr/bin/env bash\nexit 0\n' >"$P/tests/scripts/test-site-$s.sh"; done
S3="$TL_TMP/s3"; dg_stage_hooks "$S3" tool-input.sh
PRE='{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git push origin main"}}'
dg_run_with_fn "$P" "$S3/hooks/site-regression-gate.sh" "$PRE" 'sb_tool_name() { return 1; }; export -f sb_tool_name'
assert_eq "regression gate: failing tool-name helper => ignored" "" "$TL_OUT"
dg_run_with_fn "$P" "$S3/hooks/site-regression-gate.sh" "$PRE" 'sb_tool_name() { echo Bash; }; export -f sb_tool_name'
assert_eq "regression gate: missing command helper => ignored" "" "$TL_OUT"
dg_run_with_fn "$P" "$S3/hooks/live-publish-evidence-gate.sh" "$PRE" 'sb_tool_name() { return 1; }; export -f sb_tool_name'
assert_eq "live gate: failing tool-name helper => ignored" "" "$TL_OUT"
dg_run_with_fn "$P" "$S3/hooks/live-publish-evidence-gate.sh" "$PRE" 'sb_tool_name() { echo Bash; }; export -f sb_tool_name'
assert_eq "live gate: missing command helper => ignored" "" "$TL_OUT"

# live gate: state dir not creatable / jq failing on the flags
echo blocker >"$TL_TMP/blocker"
dg_run "$P" hooks/live-publish-evidence-gate.sh '{"hook_event_name":"Stop"}' SB_RUNTIME_PRESERVE_STATE_DIR=1 SB_RUNTIME_STATE_DIR="$TL_TMP/blocker/sub"
assert_eq "live gate: unusable state dir tolerated" 0 "$TL_STATUS"
dg_stub_real jq 'push_intent // false'
dg_run "$P" hooks/live-publish-evidence-gate.sh '{"hook_event_name":"Stop"}'
assert_eq "live gate: flag extraction failing defaults to no evidence needed" "" "$TL_OUT"
rm -f "$TL_BIN/jq"
dg_stub_real jq 'live_claim_pending // false'
dg_run "$P" hooks/live-publish-evidence-gate.sh '{"hook_event_name":"Stop"}'
assert_eq "live gate: push intent alone still needs evidence" "block" "$(dec)"
rm -f "$TL_BIN/jq"

tl_results
