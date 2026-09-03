#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# Security: restrict file creation permissions (user-only)
umask 0077

# Load shared workflow utilities (TD-1: single source of truth for Flow Log regex)
_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
if [[ -n "$_lib_dir" && -f "$_lib_dir/workflow-utils.sh" ]]; then
  source "$_lib_dir/workflow-utils.sh"
fi
if ! declare -f count_flow_log_rows >/dev/null 2>&1; then
  count_flow_log_rows() { grep -cE '^\| [0-9]+ \|' "$1" 2>/dev/null || echo 0; }
  count_complete_flow_rows() { grep -cE '^\| [^|]+\| [^|]+\| (complete|skipped)' "$1" 2>/dev/null || echo 0; }
fi

# PostToolUse hook (matcher: .*)
# Shows a compact compliance progress score on every tool use.
# PERFORMANCE CRITICAL: must complete in <100ms. Minimal I/O.

# Source symlink-write guard (SEC-02)
if [[ -n "$_lib_dir" && -f "$_lib_dir/nofollow-guard.sh" ]]; then
  # shellcheck source=lib/nofollow-guard.sh
  source "$_lib_dir/nofollow-guard.sh"
else
  sb_guard_nofollow() { [[ -L "$1" ]] && { printf 'ERROR: refusing to write through symlink: %s\n' "$1" >&2; exit 1; }; return 0; }
  sb_safe_write()    { [[ -L "$1" ]] && rm -f -- "$1"; return 0; }
fi
if [[ -f "$_lib_dir/runtime-paths.sh" ]]; then
  # shellcheck source=lib/runtime-paths.sh
  source "$_lib_dir/runtime-paths.sh"
fi
if [[ -f "$_lib_dir/required-skills.sh" ]]; then
  # shellcheck source=lib/required-skills.sh
  # shellcheck disable=SC1091
  source "$_lib_dir/required-skills.sh"
fi
if [[ -f "$_lib_dir/sb-project-gate.sh" ]]; then
  # shellcheck source=lib/sb-project-gate.sh
  source "$_lib_dir/sb-project-gate.sh"
fi
if [[ -f "$_lib_dir/hook-output.sh" ]]; then
  # shellcheck source=lib/hook-output.sh
  source "$_lib_dir/hook-output.sh"
fi
DEFAULT_PLANNING="${DEFAULT_PLANNING:-silver-quality-gates silver-context silver-plan}"
DEVOPS_DEFAULT_PLANNING="${DEVOPS_DEFAULT_PLANNING:-silver-blast-radius devops-quality-gates silver-context silver-plan}"

# jq is required — silent exit if missing (session-start already warned visibly)
command -v jq >/dev/null 2>&1 || exit 0

debug_hook_events() {
  [[ "${SILVER_BULLET_DEBUG_HOOK_EVENTS:-0}" == "1" ]] || return 0
  local payload="$1"
  local dbg_dir="${SB_RUNTIME_STATE_DIR}"
  mkdir -p "$dbg_dir" 2>/dev/null || true
  local dbg_file="${dbg_dir}/hook-events.debug.log"
  local hook_event tool_name
  hook_event=$(printf '%s' "$payload" | jq -r '.hook_event_name // .hookEventName // ""' 2>/dev/null || true)
  tool_name=$(printf '%s' "$payload" | jq -r '.tool_name // ""' 2>/dev/null || true)
  {
    printf '--- %s ---\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date)"
    printf 'pwd=%s\n' "$PWD"
    printf 'hook_event=%s\n' "$hook_event"
    printf 'tool_name=%s\n' "$tool_name"
  } >>"$dbg_file" 2>/dev/null || true
}

# Consume stdin (required by hook protocol). Keep the fast path fast: only
# parse and log when explicitly enabled.
if [[ "${SILVER_BULLET_DEBUG_HOOK_EVENTS:-0}" == "1" ]]; then
  _sb_payload="$(cat 2>/dev/null || true)"
  debug_hook_events "$_sb_payload"
else
  cat >/dev/null
fi

# --- Resolve config file with caching ---
# Compute PWD hash for cache key (avoid word-splitting by branching explicitly)
pwd_hash=""
if command -v md5 >/dev/null 2>&1; then
  pwd_hash=$(printf '%s' "$PWD" | md5 -q)
elif command -v md5sum >/dev/null 2>&1; then
  pwd_hash=$(printf '%s' "$PWD" | md5sum | cut -d' ' -f1)
fi

config_file=""

if [[ -n "$pwd_hash" ]]; then
  cache_file="${SB_RUNTIME_STATE_DIR}/config-cache-${pwd_hash}"

  # Check cache
  if [[ -f "$cache_file" ]]; then
    cached_path=$(sed -n '1p' "$cache_file")
    cached_mtime=$(sed -n '2p' "$cache_file")
    if [[ -n "$cached_path" && -f "$cached_path" ]]; then
      _cm=$(stat -f '%m' "$cached_path" 2>/dev/null || true)
      if [[ ! "$_cm" =~ ^[0-9]+$ ]]; then _cm=$(stat -c '%Y' "$cached_path" 2>/dev/null || true); fi
      if [[ ! "$_cm" =~ ^[0-9]+$ ]]; then _cm="0"; fi
      current_mtime="$_cm"
      if [[ "$cached_mtime" == "$current_mtime" ]]; then
        config_file="$cached_path"
      else
        rm -f -- "$cache_file"
      fi
    else
      rm -f -- "$cache_file"
    fi
  fi
fi

# Walk up to find config if not cached
if [[ -z "$config_file" ]]; then
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

  # Cache result (only when config was actually found)
  if [[ -n "${pwd_hash:-}" && -n "$config_file" ]]; then
    cache_file="${SB_RUNTIME_STATE_DIR}/config-cache-${pwd_hash}"
    _cm=$(stat -f '%m' "$config_file" 2>/dev/null || true)
    if [[ ! "$_cm" =~ ^[0-9]+$ ]]; then _cm=$(stat -c '%Y' "$config_file" 2>/dev/null || true); fi
    if [[ ! "$_cm" =~ ^[0-9]+$ ]]; then _cm="0"; fi
    config_mtime="$_cm"
    _tmp=$(mktemp "${SB_RUNTIME_STATE_DIR}/config-cache-XXXXXX")
    printf '%s\n%s' "$config_file" "$config_mtime" > "$_tmp"
    mv -f "$_tmp" "$cache_file" || rm -f -- "$_tmp"
  fi
fi

# No config → silent exit (project not set up)
[[ -z "$config_file" ]] && exit 0

if declare -f sb_project_active >/dev/null 2>&1; then
  sb_project_active "$config_file" || exit 0
elif declare -f sb_project_is_initiated >/dev/null 2>&1; then
  sb_project_is_initiated "$config_file" || exit 0
fi

# --- Read config values (single jq call for performance) ---
config_vals=$(jq -r '[
  (.state.state_file // env.SB_RUNTIME_STATE_DIR + "/state"),
  ((.skills.required_planning // []) | join(" ")),
  (.project.active_workflow // "full-dev-cycle"),
  ((.skills.required_planning_devops // []) | join(" "))
] | join("\n")' "$config_file")

state_file=$(printf '%s' "$config_vals" | sed -n '1p')
# Expand ~ to $HOME (jq returns literal tilde from config)
state_file="${state_file/#\~/$HOME}"
required_planning=$(printf '%s' "$config_vals" | sed -n '2p')
# active_workflow is read for future per-workflow status formatting
# shellcheck disable=SC2034
active_workflow=$(printf '%s' "$config_vals" | sed -n '3p')
required_planning_devops=$(printf '%s' "$config_vals" | sed -n '4p')

default_planning="$DEFAULT_PLANNING"
configured_planning="$required_planning"
if [[ "$active_workflow" == "devops-cycle" ]]; then
  default_planning="$DEVOPS_DEFAULT_PLANNING"
  configured_planning="${required_planning_devops:-$required_planning}"
fi
if declare -F sb_required_skills_normalize_configured_list >/dev/null 2>&1; then
  required_planning="$(sb_required_skills_normalize_configured_list "$config_file" "$configured_planning" "$default_planning")"
else
  required_planning="${configured_planning:-$default_planning}"
fi

# Env var override
state_file="${SILVER_BULLET_STATE_FILE:-$state_file}"

# Security: validate state file path stays within the host runtime state root
if ! sb_runtime_path_is_state_scoped "$state_file"; then
  state_file="${SB_RUNTIME_STATE_DIR}/state"
fi

# Read session mode (default: interactive if missing)
mode_file="${SB_RUNTIME_STATE_DIR}/mode"
if [[ -f "$mode_file" ]]; then
  mode=$(cat "$mode_file" 2>/dev/null || echo "interactive")
  mode="${mode:-interactive}"
else
  mode="interactive"
fi
# Validate mode value against allowlist (prevents JSON injection via mode file)
case "$mode" in
  interactive|autonomous) ;;
  *) mode="interactive" ;;
esac

# --- Composed-workflow status (Pass 2: per-instance files + flow progress) ---
# When SB_WORKFLOW_ID matches an active workflow file, surface its Flow Log
# progress as `FLOW <complete>/<total>`. Otherwise fall back to a count of
# active workflow files.
workflows_dir="$PWD/.planning/workflows"
path_progress="FLOW: N/A"
if [[ -d "$workflows_dir" && ! -L "$workflows_dir" ]]; then
  active_count=0
  shopt -s nullglob
  for _wf in "$workflows_dir"/*.md; do
    [[ -f "$_wf" ]] && active_count=$((active_count + 1))
  done
  shopt -u nullglob

  active_id="${SB_WORKFLOW_ID:-}"
  if [[ -n "$active_id" ]] \
     && [[ "$active_id" =~ ^[0-9]{8}T[0-9]{6}Z-[a-z0-9]+-[a-z0-9-]+$ ]] \
     && [[ -f "$workflows_dir/$active_id.md" && ! -L "$workflows_dir/$active_id.md" ]]; then
    _wf_total=$(count_flow_log_rows "$workflows_dir/$active_id.md")
    _wf_done=$(count_complete_flow_rows "$workflows_dir/$active_id.md")
    _wf_total=${_wf_total:-0}
    _wf_done=${_wf_done:-0}
    path_progress="FLOW ${_wf_done}/${_wf_total} (id=${active_id})"
  elif [[ "$active_count" -gt 0 ]]; then
    path_progress="WORKFLOWS: ${active_count} active (SB_WORKFLOW_ID unset)"
  fi
fi

# If no state file exists → early output with zeros
if [[ ! -f "$state_file" ]]; then
  # Count totals
  plan_total=0
  for _ in $required_planning; do ((plan_total++)) || true; done
  sb_emit_hook_message "PostToolUse" "Silver Bullet: 0 steps | Mode: ${mode} | ${path_progress} | LIFECYCLE 0/5 | PLANNING 0/${plan_total} | REVIEW 0/3 | FINALIZATION 0/4 | RELEASE 0/1 | Next: /$(printf '%s' "$required_planning" | cut -d' ' -f1)"
  exit 0
fi

# Read state file once
state_contents=$(cat "$state_file")
total_steps=$(printf '%s\n' "$state_contents" | grep -c . || true)

# Helper: check if skill is in state
has_skill() {
  if declare -F sb_required_skill_is_recorded >/dev/null 2>&1; then
    sb_required_skill_is_recorded "$state_contents" "$1"
    return $?
  fi
  printf '%s\n' "$state_contents" | grep -Fqx -- "$1" 2>/dev/null
}

# --- PLANNING phase ---
plan_done=0
plan_total=0
first_missing_plan=""
for skill in $required_planning; do
  ((plan_total++)) || true
  if has_skill "$skill"; then
    ((plan_done++)) || true
  elif [[ -z "$first_missing_plan" ]]; then
    first_missing_plan="$skill"
  fi
done

# --- REVIEW phase ---
review_skills="silver-review-request silver-review silver-review-triage"
review_done=0
review_total=0
for _ in $review_skills; do ((review_total++)) || true; done
first_missing_review=""
for skill in $review_skills; do
  if has_skill "$skill"; then
    ((review_done++)) || true
  elif [[ -z "$first_missing_review" ]]; then
    first_missing_review="$skill"
  fi
done

# --- FINALIZATION phase ---
final_skills="silver-branch-finish silver-completion-audit tdd verify-tests"
final_done=0
final_total=0
for _ in $final_skills; do ((final_total++)) || true; done
first_missing_final=""
for skill in $final_skills; do
  if has_skill "$skill"; then
    ((final_done++)) || true
  elif [[ -z "$first_missing_final" ]]; then
    first_missing_final="$skill"
  fi
done

# --- SB LIFECYCLE PHASES (legacy GSD markers still satisfy these aliases) ---
lifecycle_skills="silver-context silver-plan silver-execute silver-verify silver-ship"
lifecycle_done=0
lifecycle_total=0
for _ in $lifecycle_skills; do ((lifecycle_total++)) || true; done
for skill in $lifecycle_skills; do
  if has_skill "$skill"; then
    ((lifecycle_done++)) || true
  fi
done

# --- RELEASE phase ---
release_skills="silver-create-release"
release_done=0
release_total=0
for _ in $release_skills; do ((release_total++)) || true; done
first_missing_release=""
for skill in $release_skills; do
  if has_skill "$skill"; then
    ((release_done++)) || true
  elif [[ -z "$first_missing_release" ]]; then
    first_missing_release="$skill"
  fi
done

# --- Find NEXT required skill (first missing across phases in order) ---
next_skill=""
if [[ -n "$first_missing_plan" ]]; then
  next_skill="$first_missing_plan"
elif [[ -n "$first_missing_review" ]]; then
  next_skill="$first_missing_review"
elif [[ -n "$first_missing_final" ]]; then
  next_skill="$first_missing_final"
elif [[ -n "$first_missing_release" ]]; then
  next_skill="$first_missing_release"
fi

# --- Build output ---
msg="Silver Bullet: ${total_steps} steps | Mode: ${mode} | ${path_progress} | LIFECYCLE ${lifecycle_done}/${lifecycle_total} | PLANNING ${plan_done}/${plan_total} | REVIEW ${review_done}/${review_total} | FINALIZATION ${final_done}/${final_total} | RELEASE ${release_done}/${release_total}"
if [[ -n "$next_skill" ]]; then
  msg="${msg} | Next: /${next_skill}"
fi

sb_emit_hook_message "PostToolUse" "$msg"
