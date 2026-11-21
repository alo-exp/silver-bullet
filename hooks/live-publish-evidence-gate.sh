#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# Stop — live publish evidence for the current HEAD after a site push or a LIVE claim.
umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
[[ -f "$_lib_dir/runtime-paths.sh" ]] && source "$_lib_dir/runtime-paths.sh"
[[ -f "$_lib_dir/site-session.sh" ]] && source "$_lib_dir/site-session.sh"
[[ -f "$_lib_dir/trivial-bypass.sh" ]] && source "$_lib_dir/trivial-bypass.sh"
[[ -f "$_lib_dir/sb-project-gate.sh" ]] && source "$_lib_dir/sb-project-gate.sh"

command -v jq >/dev/null 2>&1 || exit 0

input="$(cat 2>/dev/null || true)"
[[ -n "$input" ]] || exit 0
hook_event="$(printf '%s' "$input" | jq -r '.hook_event_name // "Stop"' 2>/dev/null || echo Stop)"

# The project: the nearest root with a record, else the nearest directory with both contract files.
config_file="$( (source "$(dirname "${BASH_SOURCE[0]}")/lib/integrity-anchor.sh" && sb_integrity_activation_config "$PWD") 2>/dev/null; true)"
search_dir="${config_file:+${config_file%/*}}"
search_dir="${search_dir:-$PWD}"
[[ -n "$config_file" ]] || exit 0
if declare -f sb_project_gate_or_exit >/dev/null 2>&1; then sb_project_gate_or_exit 2>/dev/null; fi
sb_site_profile_load || exit 0
# Nothing to verify without a live URL in the profile.
[[ -n "$SB_SITE_LIVE_URL" ]] || exit 0

SB_STATE_DIR="${SB_RUNTIME_STATE_DIR}"
mkdir -p "$SB_STATE_DIR" 2>/dev/null || true
trivial_file="${SB_STATE_DIR}/trivial"

# Stop only. Live evidence is about the deployed result, so it cannot exist before the push that deploys it: a
# push is recorded (record-site-session.sh, after it ran) and the evidence is demanded at Stop (R9-03, R9-06).
# Stop is always the parent's event (workers end with SubagentStop): no worker skip (R9-05).
[[ "$hook_event" == "Stop" ]] || exit 0
sb_site_session_gates_apply || exit 0
jq -e '.push_intent == true or .live_claim_pending == true' "$(sb_site_session_file)" >/dev/null 2>&1 || exit 0
if declare -f sb_trivial_bypass >/dev/null 2>&1; then
  sb_trivial_bypass "$trivial_file"
fi

if sb_live_publish_evidence_valid; then
  exit 0
fi

if sb_site_stop_loop_release live-publish-evidence-gate "$input"; then exit 0; fi
reason="Live publish evidence required before Stop: this site session pushed or claimed a publish.

After the push has deployed, verify the live page with the plugin's verifier (it fetches ${SB_SITE_LIVE_URL}, matches your markers and records the result for the current HEAD itself; the state directory is protected, so do not write the evidence file by hand):
  bash ${_lib_dir%/hooks/lib}/scripts/site-live-evidence.sh --marker '<text that only the new page contains>'

Evidence is valid for this commit for $((SB_SITE_LIVE_MAX_AGE / 3600)) hour(s). See silver-bullet.md §8.2."
json_reason=$(printf '%s' "$reason" | jq -Rs '.')
printf '{"decision":"block","reason":%s}' "$json_reason"
exit 0
