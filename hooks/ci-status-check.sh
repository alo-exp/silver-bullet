#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# Security: restrict file creation permissions (user-only)
umask 0077

# PostToolUse hook (matcher: Bash)
# After git commit or push, checks last completed CI run status.
# BLOCKING on failure — outputs decision:block and instructs immediate /gsd:debug.
# Non-blocking for in_progress (informational only).
# Scoped to current branch when possible to avoid cross-branch false positives.

# jq required — session-start already warns visibly if missing
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)

# Detect hook event type (PreToolUse vs PostToolUse)
hook_event=$(printf '%s' "$input" | jq -r '.hook_event_name // "PostToolUse"')

# Emit a block in the correct format for the hook event type
emit_block() {
  local reason="$1"
  local json_reason
  json_reason=$(printf '%s' "$reason" | jq -Rs '.')
  if [[ "$hook_event" == "PreToolUse" ]]; then
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}' "$json_reason"
  else
    printf '{"decision":"block","reason":%s,"hookSpecificOutput":{"message":%s}}' "$json_reason" "$json_reason"
  fi
}

cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""') || true
[[ -z "$cmd" ]] && exit 0

# Only fire on commit, push, PR create/merge, or release create
printf '%s' "$cmd" | grep -qE '\bgit (commit|push)\b|\bgh pr (create|merge)\b|\bgh release create\b' || exit 0

# ── Resolve config file — exit silently if not a Silver Bullet project ───────
config_file=""
search_dir="$PWD"
while true; do
  if [[ -f "$search_dir/.silver-bullet.json" ]]; then
    config_file="$search_dir/.silver-bullet.json"
    break
  fi
  if [[ -d "$search_dir/.git" ]] || [[ "$search_dir" == "/" ]]; then
    break
  fi
  search_dir=$(dirname "$search_dir")
done
[[ -z "$config_file" ]] && exit 0

# ── CI-red override bypass ────────────────────────────────────────────────────
# Separate from trivial-session bypass — allows commits when CI is red so the
# user can push a fix. Uses a dedicated flag to avoid semantic conflation (#31).
_sb_state_dir="${HOME}/.claude/.silver-bullet"
_ci_override_file="${_sb_state_dir}/ci-red-override"
# Default trivial path — used by backward compat check (always hardcoded
# because that check specifically detects old-style usage of the default path).
_trivial_file="${_sb_state_dir}/trivial"
# Config-driven trivial path for the real trivial-session bypass; allows
# projects to specify a custom state.trivial_file in .silver-bullet.json.
_bypass_trivial="${_trivial_file}"
_cfg_trivial=$(jq -r '.state.trivial_file // ""' "$config_file" 2>/dev/null || true)
[[ -n "$_cfg_trivial" ]] && _bypass_trivial="$_cfg_trivial"
if [[ -f "$_ci_override_file" && ! -L "$_ci_override_file" ]]; then
  exit 0
fi
# Backward compat (v0.23.6 → v0.24): always checks the hardcoded default path —
# detects when the old default trivial file is used as CI-red override.
# trivial-bypass helper exits 0 silently, which would swallow this notice.
# Remove this block in v0.25.
if [[ -f "$_trivial_file" && ! -L "$_trivial_file" ]]; then
  printf '{"hookSpecificOutput":{"message":"[deprecation] ~/.claude/.silver-bullet/trivial used as CI-red override. This flag moved to ci-red-override in v0.23.6 and will stop working in v0.25. See silver-bullet#31."}}'
  exit 0
fi

# ── Trivial bypass (sourced from shared helper — REF-01) ────────────────────
# shellcheck source=lib/trivial-bypass.sh
_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)"
if [[ -f "$_lib_dir/trivial-bypass.sh" ]]; then
  # shellcheck disable=SC1090
  source "$_lib_dir/trivial-bypass.sh"
  sb_trivial_bypass "$_bypass_trivial"
fi

# gh CLI required for real runs; test override bypasses it
if [[ -n "${GH_STATUS_OVERRIDE:-}" ]]; then
  run_json="$GH_STATUS_OVERRIDE"
else
  command -v gh >/dev/null 2>&1 || exit 0
  current_branch=$(git branch --show-current 2>/dev/null || echo "")
  branch_args=()
  [[ -n "$current_branch" ]] && branch_args=(--branch "$current_branch")
  run_json=$(gh run list --limit 1 "${branch_args[@]}" --json status,conclusion,name,headBranch 2>/dev/null \
    | jq -r '.[0] // empty' 2>/dev/null) || true
fi

[[ -z "${run_json:-}" ]] && exit 0

conclusion=$(printf '%s' "$run_json" | jq -r '.conclusion // ""' 2>/dev/null) || true
status=$(printf '%s' "$run_json"    | jq -r '.status // ""'     2>/dev/null) || true

# Validate extracted values against known-good sets (defense-in-depth)
case "$conclusion" in
  success|failure|cancelled|skipped|"") ;;
  *) conclusion="unknown" ;;
esac
case "$status" in
  completed|in_progress|queued|waiting|"") ;;
  *) status="unknown" ;;
esac

if [[ "$conclusion" == "failure" ]] || [[ "$conclusion" == "cancelled" ]]; then
  msg="🛑 CI FAILURE DETECTED — conclusion=${conclusion}.

STOP all other work immediately. Do NOT proceed to any other step.
Invoke /gsd:debug now to investigate the failing CI run before continuing.
Run: gh run list --limit 3 --json status,conclusion,name,headBranch
Then: gh run view <run-id> --log-failed

If you need to commit a CI fix: create the override file in your terminal (not in Claude):
  touch ~/.claude/.silver-bullet/ci-red-override
This lets you commit your fix while CI is red. Remove it once CI is green."

  emit_block "$msg"

elif [[ "$status" == "in_progress" ]]; then
  printf '{"hookSpecificOutput":{"message":"ℹ️ CI in progress. Step 17 will poll for result before deploy."}}'
fi
# success or unknown: silent exit
