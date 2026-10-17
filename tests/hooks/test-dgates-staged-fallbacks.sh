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

# ---- uat-gate: failing count pipelines (file modified between the check and the count) ----
mkdir -p "$P/.planning"
printf '| 1 | a | FAIL |\n' >"$P/.planning/UAT.md"
real_grep="$(command -v grep)"
tl_stub grep "if [[ \"\$1\" == -cvE ]]; then echo 0; exit 1; fi; exec $real_grep \"\$@\""; hash -r
dg_run "$P" hooks/uat-gate.sh '{"hook_event_name":"PreToolUse","tool_name":"Skill","tool_input":{"skill":"silver-release"}}'
assert_contains "uat-gate: FAIL block survives a failing count" "$TL_OUT" "UAT GATE: 0 criterion/criteria marked FAIL"
printf '| 1 | a | NOT-RUN |\n' >"$P/.planning/UAT.md"
dg_run "$P" hooks/uat-gate.sh '{"hook_event_name":"PreToolUse","tool_name":"Skill","tool_input":{"skill":"silver-release"}}'
assert_contains "uat-gate: NOT-RUN block survives a failing count" "$TL_OUT" "UAT GATE: 0 criterion/criteria marked NOT-RUN"
rm -f "$TL_BIN/grep"; hash -r

# ---- outcomes-check without jq: event extraction pipeline failing -> defaults to Stop ----
OST="$ST/state-x"; printf 'silver-quality-gates\n' >"$OST"
rm -f "$ST/outcomes-session.json" "$ST/stop-coalesce-block"
echo '{"outcomes":[{"id":"route","label":"R","status":"pending","evidence":""}]}' >"$ST/outcomes-session.json"
tl_stub grep "if [[ \"\$1\" == -oE ]]; then exit 1; fi; exec $real_grep \"\$@\""; hash -r
dg_run_nojq "$P" hooks/outcomes-check.sh '{"hook_event_name":"SubagentStop"}' SILVER_BULLET_STATE_FILE="$OST"
rm -f "$TL_BIN/grep"; hash -r
assert_eq "outcomes-check (no jq): failing event extraction defaults to Stop and blocks" "block" "$(jq -r .decision <<<"$TL_OUT")"
rm -f "$ST/outcomes-session.json" "$ST/stop-coalesce-block"

# ---- workflow-chain-guard: only the generic jq enforcement helper available ----
S4="$TL_TMP/s4"; dg_stage_hooks "$S4" jq-gate.sh
mkdir -p "$P/.planning/workflows"; printf 'composer: /sb:release\n' >"$P/.planning/workflows/w.md"
: >"$ST/state"
GENERIC='sb_jq_enforcement_block() { printf "{\"hookSpecificOutput\":{\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"generic: %s\"}}" "$1"; exit 0; }; export -f sb_jq_enforcement_block'
dg_run_with_fn "$P" "$S4/hooks/workflow-chain-guard.sh" '{"hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{"file_path":"x"}}' "$GENERIC" SILVER_BULLET_STATE_FILE="$ST/state"
assert_contains "workflow-chain-guard: falls back to the generic jq helper" "$TL_OUT" "generic: workflow-chain-guard"
rm -rf "$P/.planning/workflows"

# ---- instruction-ledger-gate: pending-summary helper failing ----
S5="$TL_TMP/s5"; dg_stage_hooks "$S5" instruction-ledger.sh
LEDGER_FNS='sb_instruction_ledger_seed_from_prompt() { :; }; sb_instruction_ledger_pending_summary() { return 1; }; export -f sb_instruction_ledger_seed_from_prompt sb_instruction_ledger_pending_summary'
dg_run_with_fn "$P" "$S5/hooks/instruction-ledger-gate.sh" '{"hook_event_name":"UserPromptSubmit","prompt":"- a\n- b\n- c"}' "$LEDGER_FNS"
assert_eq "instruction-ledger-gate: failing summary helper => no context, exit 0" "" "$TL_OUT"

tl_results
