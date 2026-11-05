#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# Security: restrict file creation permissions (user-only)
umask 0077

# Source runtime path selector so the CI override and trivial files follow the host.
_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
if [[ -f "$_lib_dir/runtime-paths.sh" ]]; then
  # shellcheck source=lib/runtime-paths.sh
  source "$_lib_dir/runtime-paths.sh"
fi
if [[ -f "$_lib_dir/sb-project-gate.sh" ]]; then
  # shellcheck source=lib/sb-project-gate.sh
  source "$_lib_dir/sb-project-gate.sh"
  sb_project_active_or_exit
fi
if [[ -f "$_lib_dir/tool-input.sh" ]]; then
  # shellcheck source=lib/tool-input.sh
  source "$_lib_dir/tool-input.sh"
fi

# PreToolUse + PostToolUse hook (matcher: Bash)
# Checks last completed CI run status before/after git push and deploy commands.
# BLOCKING on failure — outputs decision:block and instructs immediate /sb:debug.
# Non-blocking for in_progress (informational only).
# Scoped to current branch when possible to avoid cross-branch false positives.
#
# Trigger scope differs by event:
#   PreToolUse:  git push, gh pr create/merge, gh release create
#                (NOT git commit — blocking local commits creates a deadlock when
#                 Claude needs to commit a CI fix; commits never touch the remote)
#   PostToolUse: git commit, git push, gh pr create/merge, gh release create
#                (warn after committing so Claude knows CI is red before pushing)

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

if declare -f sb_tool_name >/dev/null 2>&1; then
  tool_name="$(sb_tool_name "$input")"
else
  tool_name=$(printf '%s' "$input" | jq -r '.tool_name // ""') || true
fi
# Shell tools and MCP tools (the GitHub server's create/merge/push tools) are judged by the shell analysis
# helper, not by text matching: aliases, global options, wrappers, gh api writes and MCP spellings all count.
_ci_gate_tool=false
case "$tool_name" in
  mcp__* | CallMcpTool | MCP) _ci_gate_tool=true ;;
  Bash | Shell | shell | exec_command) _ci_gate_tool=true ;;
  *)
    # without the tool-input library the tool name cannot be classified: treat the call as a shell call
    if ! declare -f sb_tool_is_shell_like >/dev/null 2>&1; then
      _ci_gate_tool=true
    fi
    ;;
esac
[[ "$_ci_gate_tool" == true ]] || exit 0
SB_TI_STATUS="helper_unavailable"
! declare -f sb_tool_input_load >/dev/null 2>&1 || sb_tool_input_load "$input"
[[ "$SB_TI_STATUS" != "empty" ]] || exit 0

# Trigger scope differs by event (see header comment above). When the helper could not read the payload the
# call counts as gated: the CI check is the safe default.
if [[ "$SB_TI_STATUS" == "ok" ]]; then
  _ci_trigger=false
  for _ci_action in push pr_create pr_merge release_create remote_write unseen; do
    ! sb_shell_analysis_may_deliver "$_ci_action" || _ci_trigger=true
  done
  [[ "$hook_event" == "PreToolUse" ]] || ! sb_shell_analysis_may_deliver commit || _ci_trigger=true
  [[ "$_ci_trigger" == true ]] || exit 0
else
  # the helper could not read the payload (python3 or the library is missing): fall back to the plain
  # verbs so unrelated commands are not held, while the common spellings stay covered
  _ci_cmd=""
  ! declare -f sb_tool_command_string >/dev/null 2>&1 || _ci_cmd="$(sb_tool_command_string "$input")"
  [[ -n "$_ci_cmd" ]] || _ci_cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""') || true
  if [[ "$hook_event" == "PreToolUse" ]]; then
    grep -qE '\bgit push\b|\bgh pr (create|merge)\b|\bgh release create\b' <<<"$_ci_cmd" || exit 0
  else
    grep -qE '\bgit (commit|push)\b|\bgh pr (create|merge)\b|\bgh release create\b' <<<"$_ci_cmd" || exit 0
  fi
fi

# ── Resolve config file — exit silently if not a Silver Bullet project ───────
config_file=""
search_dir="$PWD"
while true; do
  if [[ -f "$search_dir/.silver-bullet.json" ]] && [[ -f "$search_dir/silver-bullet.md" ]]; then
    config_file="$search_dir/.silver-bullet.json"
    break
  fi
  if [[ -d "$search_dir/.git" ]] || [[ "$search_dir" == "/" ]]; then
    break
  fi
  search_dir=$(dirname "$search_dir")
done
[[ -z "$config_file" ]] && exit 0

if declare -f sb_project_active >/dev/null 2>&1; then
  sb_project_active "$config_file" || exit 0
elif declare -f sb_project_is_initiated >/dev/null 2>&1; then
  sb_project_is_initiated "$config_file" || exit 0
fi

# ── CI-red override bypass ────────────────────────────────────────────────────
# Separate from trivial-session bypass — allows commits when CI is red so the
# user can push a fix. Uses a dedicated flag to avoid semantic conflation (#31).
_sb_state_dir="${SB_RUNTIME_STATE_DIR}"
_ci_override_file="${_sb_state_dir}/ci-red-override"
# Default trivial path — used by backward compat check (always hardcoded
# because that check specifically detects old-style usage of the default path).
_trivial_file="${_sb_state_dir}/trivial"
# Config-driven trivial path for the real trivial-session bypass; allows
# projects to specify a custom state.trivial_file in .silver-bullet.json.
_bypass_trivial="${_trivial_file}"
_cfg_trivial=$(jq -r '.state.trivial_file // ""' "$config_file" 2>/dev/null || true)
# shellcheck source=lib/trivial-bypass.sh
source "$_lib_dir/trivial-bypass.sh"
if [[ -n "$_cfg_trivial" ]]; then
  _cfg_trivial="$(sb_expand_state_config_path "$_cfg_trivial")"
  # only the state directory's own `trivial` file may stand for a trivial session (R3-02, R1-21)
  ! sb_trivial_path_trusted "$_cfg_trivial" "$_trivial_file" || _bypass_trivial="$_cfg_trivial"
fi
# The CI-red override is a short-lived human decision: it expires after SB_CI_OVERRIDE_TTL_MINUTES
# (default 30), so it can no longer waive CI checks for good (R1-21).
_ci_override_ttl="${SB_CI_OVERRIDE_TTL_MINUTES:-30}"
[[ "$_ci_override_ttl" =~ ^[0-9]+$ ]] || _ci_override_ttl=30
if [[ -f "$_ci_override_file" && ! -L "$_ci_override_file" ]]; then
  if [[ -n "$(find "$_ci_override_file" -mmin "-${_ci_override_ttl}" -print 2>/dev/null)" ]]; then
    exit 0
  fi
  rm -f -- "$_ci_override_file"
fi
# Backward compat (v0.23.6 → v0.24): always checks the hardcoded default path —
# detects when the old default trivial file is used as CI-red override.
# trivial-bypass helper exits 0 silently, which would swallow this notice.
# Remove this block in v0.25.
if [[ -f "$_trivial_file" && ! -L "$_trivial_file" ]]; then
  printf '{"hookSpecificOutput":{"message":"[deprecation] host-runtime/.silver-bullet/trivial used as CI-red override. This flag moved to ci-red-override in v0.23.6 and will stop working in v0.25. See silver-bullet#31."}}'
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

# gh CLI required for real runs; test override bypasses it (sandbox only: GH_STATUS_OVERRIDE would
# otherwise let an environment variable replace CI status, R1-36)
# shellcheck source=lib/github-run-list.sh
source "$_lib_dir/github-run-list.sh"
if [[ -n "${GH_STATUS_OVERRIDE:-}" ]] && sb_github_overrides_allowed; then
  run_json="$GH_STATUS_OVERRIDE"
else
  if ! command -v gh >/dev/null 2>&1; then
    printf '{"hookSpecificOutput":{"message":"ℹ️ ci-status-check: the gh CLI is not installed, so CI status was not checked for this command."}}'
    exit 0
  fi
  current_branch=$(git branch --show-current 2>/dev/null || echo "")
  branch_args=()
  [[ -n "$current_branch" ]] && branch_args=(--branch "$current_branch")
  # The newest commit's runs, one per workflow (latest attempt): a red workflow is not hidden behind a
  # later green run of another workflow (R1-21c). Bounded by the gh timeout; "cannot determine" is said out loud.
  _ci_tmp="$(mktemp -d "${TMPDIR:-/tmp}/sb-ci-status.XXXXXX")"
  _ci_rc=0
  sb_run_hooked_command "${SB_GH_TIMEOUT_SECONDS:-8}" /dev/null "$_ci_tmp/out" "$_ci_tmp/err" \
    gh run list --limit 30 ${branch_args[@]+"${branch_args[@]}"} --json status,conclusion,name,headBranch,headSha,createdAt || _ci_rc=$?
  run_json=""
  if [[ "$_ci_rc" -eq 0 ]]; then
    run_json=$(jq -r '
      (.[0].headSha // "") as $sha
      | [.[] | select((.headSha // "") == $sha)]
      | group_by(.name) | map(max_by(.createdAt // ""))
      | ((map(select(.conclusion == "failure" or .conclusion == "cancelled")) | .[0])
         // (map(select(.status == "in_progress")) | .[0])
         // .[0] // empty)' "$_ci_tmp/out" 2>/dev/null) || true
  fi
  rm -rf -- "$_ci_tmp"
  if [[ "$_ci_rc" -ne 0 ]]; then
    printf '{"hookSpecificOutput":{"message":"ℹ️ ci-status-check: CI status could not be determined (gh failed or timed out), so it was not checked for this command."}}'
    exit 0
  fi
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
  # ── CI-fix bypass (issue #95): allow pushes that ARE the fix ─────────────
  # The push may only change CI/test files (every changed path); a commit-message convention is
  # agent-controlled text and no longer waives the block (R1-21a).
  if [[ "${SB_SA_ACTIONS:-}" == "push" && -z "${SB_SA_POSSIBLE_ACTIONS:-}" ]]; then
    if git rev-parse "@{u}" >/dev/null 2>&1; then
      _changed=$(git diff "@{u}..HEAD" --name-only 2>/dev/null || true)
      if [[ -n "$_changed" ]] && ! grep -qvE '^\.github/workflows/|^tests/|^package\.json$' <<<"$_changed"; then
        printf '{"hookSpecificOutput":{"message":"ℹ️ CI is red but the push only touches CI/test files — allowing push (suspected CI fix)."}}'
        exit 0
      fi
    fi
  fi
  msg="🛑 CI FAILURE DETECTED — conclusion=${conclusion}.

STOP all other work immediately. Do NOT proceed to any other step.
Invoke /sb:debug now to investigate the failing CI run before continuing.
Run: gh run list --limit 3 --json status,conclusion,name,headBranch
Then: gh run view <run-id> --log-failed

If you need to push a CI fix: a push whose every changed file is under .github/workflows/, tests/ or
package.json is allowed. A human can also waive the block for ${_ci_override_ttl} minutes from their own terminal:
  touch ${SB_RUNTIME_HOME_ROOT}/.silver-bullet/ci-red-override"

  # PostToolUse/git commit: warn only — the commit already happened; emitting
  # decision:block here confuses the model about whether the commit succeeded and
  # can cause deadlock (can't commit the CI fix because PostToolUse blocks it).
  # Push, PR, and release operations are still hard-blocked (remote-state mutations).
  if [[ "$hook_event" == "PostToolUse" && "${SB_SA_ACTIONS:-}" == "commit" && -z "${SB_SA_POSSIBLE_ACTIONS:-}" ]]; then
    json_msg=$(printf '%s' "$msg" | jq -Rs '.')
    printf '{"hookSpecificOutput":{"message":%s}}' "$json_msg"
  else
    emit_block "$msg"
  fi

elif [[ "$status" == "in_progress" ]]; then
  printf '{"hookSpecificOutput":{"message":"ℹ️ CI in progress. Step 17 will poll for result before deploy."}}'
fi
# success or unknown: silent exit
