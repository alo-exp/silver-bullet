#!/usr/bin/env bash
# Tests for hooks/review-fix-ladder-guard.sh — ladder state machine enforcement.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="${REPO_ROOT}/hooks/review-fix-ladder-guard.sh"
# shellcheck source=hooks/lib/runtime-paths.sh
source "${REPO_ROOT}/hooks/lib/runtime-paths.sh"
# shellcheck source=hooks/lib/review-fix-ladder-state.sh
source "${REPO_ROOT}/hooks/lib/review-fix-ladder-state.sh"

PASS=0
FAIL=0
TEST_RUN_ID="$$"
export SB_RUNTIME_PRESERVE_STATE_DIR=1
export SB_RUNTIME_STATE_DIR="${SB_RUNTIME_HOME_ROOT}/.silver-bullet/rfl-guard-${TEST_RUN_ID}"
export SILVER_BULLET_RUNTIME=cursor
export SB_REVIEW_FIX_LADDER_GUARD=1
mkdir -p "$SB_RUNTIME_STATE_DIR"

cleanup() {
  sb_rfl_deactivate 2>/dev/null || true
  rm -rf "$SB_RUNTIME_STATE_DIR" 2>/dev/null || true
}
trap cleanup EXIT

check() {
  local desc="$1" result="$2"
  if [[ "$result" == pass ]]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
  fi
}

is_denied() {
  local output="$1"
  [[ -n "$output" ]] && printf '%s' "$output" | grep -qE '"permissionDecision"\s*:\s*"deny"|"decision"\s*:\s*"block"'
}

run_hook() {
  local event="$1" tool="$2" json="$3"
  (cd "$WORK" && printf '%s' "$json" | env SILVER_BULLET_RUNTIME=cursor bash "$HOOK" 2>/dev/null)
}

WORK=$(mktemp -d)
cat >"$WORK/silver-bullet.md" <<'EOF'
# Silver Bullet test
EOF
cat >"$WORK/.silver-bullet.json" <<EOF
{
  "sb_initiated": true,
  "state": {"state_file": "${SB_RUNTIME_STATE_DIR}/state"}
}
EOF
touch "${SB_RUNTIME_STATE_DIR}/state"
mkdir -p "$WORK/scripts"
ln -sf "$REPO_ROOT/scripts/review-fix-ladder.py" "$WORK/scripts/review-fix-ladder.py"

echo "=== review-fix-ladder guard tests ==="

sb_rfl_deactivate
out_inactive=$(run_hook PreToolUse Task "$(jq -n --arg p 'fix files' '{hook_event_name:"PreToolUse",tool_name:"Task",tool_input:{prompt:$p,model:"composer-2.5"}}')")
check "inactive ladder does not deny Task" "$(is_denied "$out_inactive" && echo fail || echo pass)"

sb_rfl_activate 1 "" composer-2.5
sb_rfl_is_active && check "activate sets active state" pass || check "activate sets active state" fail
total_rungs="$(sb_rfl_read_field total_rungs "")"
if [[ "$total_rungs" -ge 6 ]]; then
  check "activate total_rungs >= 6" pass
else
  check "activate total_rungs >= 6" fail
fi
[[ "$(sb_rfl_read_field subagent_name "")" == "sb-composer-2-5-medium" ]] && check "activate subagent_name" pass || check "activate subagent_name" fail

sb_rfl_reset 1 composer-2.5 composer-2.5
sb_rfl_set_field phase review
out_review_no_subagent=$(run_hook PreToolUse Task "$(jq -n '{hook_event_name:"PreToolUse",tool_name:"Task",tool_input:{prompt:"rung_1_review raw findings only",model:"composer-2.5"}}')")
is_denied "$out_review_no_subagent" && check "blocks review without subagent_type" pass || check "blocks review without subagent_type" fail

sb_rfl_reset 1 composer-2.5 composer-2.5
sb_rfl_set_field phase review
out_review_wrong_subagent=$(run_hook PreToolUse Task "$(jq -n '{hook_event_name:"PreToolUse",tool_name:"Task",tool_input:{prompt:"rung_1_review raw findings",model:"composer-2.5",subagent_type:"sb-grok-4-5-medium"}}')")
is_denied "$out_review_wrong_subagent" && check "blocks review wrong subagent_type" pass || check "blocks review wrong subagent_type" fail

sb_rfl_reset 1 composer-2.5 composer-2.5
sb_rfl_set_field phase review
out_review_ok=$(run_hook PreToolUse Task "$(jq -n '{hook_event_name:"PreToolUse",tool_name:"Task",tool_input:{prompt:"rung_1_review raw findings",subagent_type:"sb-composer-2-5-medium"}}')")
is_denied "$out_review_ok" && check "allows review with correct subagent_type (no model)" fail || check "allows review with correct subagent_type (no model)" pass

sb_rfl_reset 1 composer-2.5 composer-2.5
sb_rfl_set_field phase verify_1
out_verify_subagent=$(run_hook PreToolUse Task "$(jq -n '{hook_event_name:"PreToolUse",tool_name:"Task",tool_input:{prompt:"rung_1_verify_1 verify-only",readonly:true,subagent_type:"sb-composer-2-5-medium"}}')")
is_denied "$out_verify_subagent" && check "allows verify with correct subagent_type (no model)" fail || check "allows verify with correct subagent_type (no model)" pass

sb_rfl_reset 1 composer-2.5 composer-2.5

out_triage_in_review=$(run_hook PreToolUse Task "$(jq -n '{hook_event_name:"PreToolUse",tool_name:"Task",tool_input:{prompt:"/sb:triage classify VALID-NONBLOCKER",model:"composer-2.5"}}')")
is_denied "$out_triage_in_review" && check "blocks triage Task during review phase" pass || check "blocks triage Task during review phase" fail

sb_rfl_reset 1 composer-2.5 gpt-5.5
sb_rfl_set_field phase triage
sb_rfl_set_field rung_model composer-2.5
sb_rfl_set_field host_model gpt-5.5

out_rung_model_triage=$(run_hook PreToolUse Task "$(jq -n '{hook_event_name:"PreToolUse",tool_name:"Task",tool_input:{prompt:"/sb:triage on findings",model:"composer-2.5"}}')")
is_denied "$out_rung_model_triage" && check "blocks triage at rung model when host differs" pass || check "blocks triage at rung model when host differs" fail

sb_rfl_reset 1 composer-2.5 composer-2.5
sb_rfl_set_field phase fix_parallel
sb_rfl_set_bool pm_filed false

out_fix_before_file=$(run_hook PreToolUse Task "$(jq -n '{hook_event_name:"PreToolUse",tool_name:"Task",tool_input:{prompt:"rung_1_fix_parallel fix divide()",model:"composer-2.5"}}')")
is_denied "$out_fix_before_file" && check "blocks fix before PM filed" pass || check "blocks fix before PM filed" fail

sb_rfl_reset 1 composer-2.5 composer-2.5
sb_rfl_set_field phase file_valid_issues
sb_rfl_mark_pm_filed
[[ "$(sb_rfl_read_field phase "")" == "fix_parallel" ]] && check "pm_filed advances to fix_parallel" pass || check "pm_filed advances to fix_parallel" fail

sb_rfl_reset 1 composer-2.5 composer-2.5
out_combined_verify=$(run_hook PreToolUse Task "$(jq -n '{hook_event_name:"PreToolUse",tool_name:"Task",tool_input:{prompt:"verify_1 and verify_2 two consecutive verify passes",model:"composer-2.5",readonly:true}}')")
is_denied "$out_combined_verify" && check "blocks combined verify passes" pass || check "blocks combined verify passes" fail

sb_rfl_reset 1 composer-2.5 composer-2.5
sb_rfl_set_field phase verify_1
out_verify_no_readonly=$(run_hook PreToolUse Task "$(jq -n '{hook_event_name:"PreToolUse",tool_name:"Task",tool_input:{prompt:"verify-only pass",model:"composer-2.5"}}')")
is_denied "$out_verify_no_readonly" && check "blocks verify without readonly" pass || check "blocks verify without readonly" fail

sb_rfl_reset 1 composer-2.5 composer-2.5
sb_rfl_set_field phase verify_1
sb_rfl_set_field rung 2
out_wrong_rung=$(run_hook PreToolUse Task "$(jq -n '{hook_event_name:"PreToolUse",tool_name:"Task",tool_input:{prompt:"rung_1_verify_1 verify-only",model:"composer-2.5",readonly:true}}')")
is_denied "$out_wrong_rung" && check "blocks parallel rung in prompt" pass || check "blocks parallel rung in prompt" fail

sb_rfl_deactivate
run_hook PostToolUse Skill "$(jq -n '{hook_event_name:"PostToolUse",tool_name:"Skill",tool_input:{skill:"silver-review-fix-ladder"}}')" >/dev/null
sb_rfl_is_active && check "skill invoke activates ladder" pass || check "skill invoke activates ladder" fail

sb_rfl_reset 1 composer-2.5 composer-2.5
sb_rfl_set_field phase file_valid_issues
run_hook PostToolUse Bash "$(jq -n '{hook_event_name:"PostToolUse",tool_name:"Bash",tool_input:{command:"gh issue create --title test"}}')" >/dev/null
[[ "$(sb_rfl_read_field pm_filed "")" == "true" ]] && check "gh issue create marks pm_filed" pass || check "gh issue create marks pm_filed" fail

[[ -x "$HOOK" ]] && check "guard hook executable" pass || check "guard hook executable" fail
grep -q 'review-fix-ladder-guard.sh' "$REPO_ROOT/hooks/hooks.json" && check "registered in hooks.json" pass || check "registered in hooks.json" fail
grep -q 'review-fix-ladder-guard.sh' "$REPO_ROOT/hooks/cursor-hooks.json" && check "registered in cursor-hooks.json" pass || check "registered in cursor-hooks.json" fail
bash -n "$HOOK" && check "guard shell syntax" pass || check "guard shell syntax" fail

sb_rfl_deactivate
sb_rfl_activate 1 "" composer-2.5
sb_rfl_advance_rung
[[ "$(sb_rfl_read_field rung "")" == "2" ]] && check "advance rung 2" pass || check "advance rung 2" fail
[[ "$(sb_rfl_read_field subagent_name "")" == "sb-composer-2-5-high" ]] && check "advance subagent_name" pass || check "advance subagent_name" fail

# Subscription-first: GPT/Claude Cursor Task blocked until quota is recorded
sb_rfl_reset 1 gpt-5.6-sol composer-2.5
sb_rfl_set_field subagent_name sb-gpt-5-6-sol-high
sb_rfl_set_field phase review
out_gpt_no_quota=$(run_hook PreToolUse Task "$(jq -n '{hook_event_name:"PreToolUse",tool_name:"Task",tool_input:{prompt:"rung_1_review raw findings",subagent_type:"sb-gpt-5-6-sol-high"}}')")
is_denied "$out_gpt_no_quota" && check "blocks GPT Task without quota fallback" pass || check "blocks GPT Task without quota fallback" fail

sb_rfl_reset 1 opus-5 composer-2.5
sb_rfl_set_field subagent_name sb-opus-5-high
sb_rfl_set_field phase review
out_opus_no_quota=$(run_hook PreToolUse Task "$(jq -n '{hook_event_name:"PreToolUse",tool_name:"Task",tool_input:{prompt:"rung_1_review raw findings",subagent_type:"sb-opus-5-high"}}')")
is_denied "$out_opus_no_quota" && check "blocks Opus Task without quota fallback" pass || check "blocks Opus Task without quota fallback" fail

sb_rfl_reset 1 gpt-5.6-sol composer-2.5
sb_rfl_set_field subagent_name sb-gpt-5-6-sol-high
sb_rfl_set_field phase review
sb_rfl_mark_subscription_quota_fallback "codex" "quota retries exhausted"
out_gpt_quota=$(run_hook PreToolUse Task "$(jq -n '{hook_event_name:"PreToolUse",tool_name:"Task",tool_input:{prompt:"rung_1_review raw findings",subagent_type:"sb-gpt-5-6-sol-high"}}')")
is_denied "$out_gpt_quota" && check "allows GPT Task after quota fallback" fail || check "allows GPT Task after quota fallback" pass

sb_rfl_reset 1 composer-2.5 composer-2.5
sb_rfl_set_field phase review
out_composer_ok=$(run_hook PreToolUse Task "$(jq -n '{hook_event_name:"PreToolUse",tool_name:"Task",tool_input:{prompt:"rung_1_review raw findings",subagent_type:"sb-composer-2-5-medium"}}')")
is_denied "$out_composer_ok" && check "Composer Task still allowed without quota gate" fail || check "Composer Task still allowed without quota gate" pass

# ── Fail-open regression: the deny must survive a failed state write ─────────
# sb_rfl_compliance_stop() bubbles up sb_rfl_set_bool/set_field's exit code.
# When the state dir is not writable that is non-zero, which — left bare under
# `set -e` + `trap 'exit 0' ERR` — aborted the hook with exit 0 (ALLOW) before
# emit_deny ever ran, silently failing the gate OPEN.
if [[ "$(id -u)" != "0" ]]; then
  sb_rfl_reset 1 composer-2.5 composer-2.5
  sb_rfl_set_field phase review
  # GNU stat first. BSD's `-f FORMAT` means `--file-system` on GNU coreutils,
  # which prints a filesystem report and exits 0 — so probing BSD-first never
  # reaches the fallback on Linux and hands chmod a multi-line junk "mode".
  # That is exactly how this test broke CI while passing on macOS.
  _rfl_saved_mode=$(stat -c '%a' "$SB_RUNTIME_STATE_DIR" 2>/dev/null \
    || stat -f '%Lp' "$SB_RUNTIME_STATE_DIR" 2>/dev/null)
  [[ "$_rfl_saved_mode" =~ ^[0-7]{3,4}$ ]] || _rfl_saved_mode=700
  chmod 0500 "$SB_RUNTIME_STATE_DIR"
  # `|| true` so a regressed hook (which exits non-zero with no output) reports
  # a clean FAIL here instead of killing this `set -e` harness.
  out_unwritable=$(run_hook PreToolUse Task "$(jq -n '{hook_event_name:"PreToolUse",tool_name:"Task",tool_input:{prompt:"/sb:triage on findings",model:"composer-2.5"}}')" || true)
  chmod "$_rfl_saved_mode" "$SB_RUNTIME_STATE_DIR"
  is_denied "$out_unwritable" \
    && check "still denies when compliance-stop state write fails" pass \
    || check "still denies when compliance-stop state write fails" fail
else
  echo "  SKIP: running as root — chmod-based unwritable-state case not meaningful"
fi

rm -rf "$WORK"
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
