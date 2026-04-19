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
  count_complete_flow_rows() { grep -cE '^\| [^|]+\| [^|]+\| complete' "$1" 2>/dev/null || echo 0; }
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

# jq is required — silent exit if missing (session-start already warned visibly)
command -v jq >/dev/null 2>&1 || exit 0

# Consume stdin (required by hook protocol)
cat >/dev/null

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
  cache_file="${HOME}/.claude/.silver-bullet/config-cache-${pwd_hash}"

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
    if [[ -f "$search_dir/.silver-bullet.json" ]]; then
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
    cache_file="${HOME}/.claude/.silver-bullet/config-cache-${pwd_hash}"
    _cm=$(stat -f '%m' "$config_file" 2>/dev/null || true)
    if [[ ! "$_cm" =~ ^[0-9]+$ ]]; then _cm=$(stat -c '%Y' "$config_file" 2>/dev/null || true); fi
    if [[ ! "$_cm" =~ ^[0-9]+$ ]]; then _cm="0"; fi
    config_mtime="$_cm"
    _tmp=$(mktemp "${HOME}/.claude/.silver-bullet/config-cache-XXXXXX")
    printf '%s\n%s' "$config_file" "$config_mtime" > "$_tmp"
    mv -f "$_tmp" "$cache_file" || rm -f -- "$_tmp"
  fi
fi

# No config → silent exit (project not set up)
[[ -z "$config_file" ]] && exit 0

# --- Read config values (single jq call for performance) ---
config_vals=$(jq -r '[
  (.state.state_file // "~/.claude/.silver-bullet/state"),
  ((.skills.required_planning // ["silver-quality-gates"]) | join(" ")),
  (.project.active_workflow // "full-dev-cycle")
] | join("\n")' "$config_file")

state_file=$(printf '%s' "$config_vals" | sed -n '1p')
# Expand ~ to $HOME (jq returns literal tilde from config)
state_file="${state_file/#\~/$HOME}"
required_planning=$(printf '%s' "$config_vals" | sed -n '2p')
# active_workflow is read for future per-workflow status formatting
# shellcheck disable=SC2034
active_workflow=$(printf '%s' "$config_vals" | sed -n '3p')

# Env var override
state_file="${SILVER_BULLET_STATE_FILE:-$state_file}"

# Security: validate state file path stays within ~/.claude/ (SB-002/SB-003)
case "$state_file" in
  "$HOME"/.claude/*) ;;
  *) state_file="${HOME}/.claude/.silver-bullet/state" ;;
esac

# Read session mode (default: interactive if missing)
mode_file="${HOME}/.claude/.silver-bullet/mode"
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

# --- WORKFLOW.md path progress (computed before early-exit so it appears in all output paths) ---
# Bug fix: hoisted above the 'no state file' early-exit so PATH N/M shows even in zero-state sessions.
workflow_file="$PWD/.planning/WORKFLOW.md"
path_progress="FLOW: N/A (legacy mode)"
if [[ -f "$workflow_file" && ! -L "$workflow_file" ]]; then
  wf_complete=0
  wf_total=0
  # Bug fix: use '^\ [0-9]+ \|' (digits then space-pipe) to count only Flow Log rows.
  # Previous pattern '^\| [0-9]' matched Phase Iterations ('| 01 (phase)') and
  # Autonomous Decisions ('| 2026-...') rows, inflating the total count.
  if wf_complete=$(grep -cE '^\| [^|]+\| [^|]+\| complete' "$workflow_file" 2>/dev/null) && \
     wf_total=$(count_flow_log_rows "$workflow_file") && \
     [[ "$wf_total" -gt 0 ]]; then
    path_progress="FLOW ${wf_complete}/${wf_total}"
  fi
fi

# If no state file exists → early output with zeros
if [[ ! -f "$state_file" ]]; then
  # Count totals
  plan_total=0
  for _ in $required_planning; do ((plan_total++)) || true; done
  printf '{"hookSpecificOutput":{"message":"Silver Bullet: 0 steps | Mode: %s | %s | GSD 0/5 | PLANNING 0/%d | REVIEW 0/3 | FINALIZATION 0/4 | RELEASE 0/1 | Next: /%s"}}' \
    "$mode" "$path_progress" "$plan_total" \
    "$(printf '%s' "$required_planning" | cut -d' ' -f1)"
  exit 0
fi

# Read state file once
state_contents=$(cat "$state_file")
total_steps=$(printf '%s\n' "$state_contents" | grep -c . || true)

# Helper: check if skill is in state
has_skill() {
  printf '%s\n' "$state_contents" | grep -qx "$1" 2>/dev/null
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
review_skills="code-review requesting-code-review receiving-code-review"
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
final_skills="testing-strategy documentation finishing-a-development-branch deploy-checklist"
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

# --- GSD PHASES (tracked when /gsd:* commands fire via Skill tool) ---
gsd_core_skills="gsd-discuss-phase gsd-plan-phase gsd-execute-phase gsd-verify-work gsd-ship"
gsd_done=0
gsd_total=0
for _ in $gsd_core_skills; do ((gsd_total++)) || true; done
for skill in $gsd_core_skills; do
  if has_skill "$skill"; then
    ((gsd_done++)) || true
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
msg="Silver Bullet: ${total_steps} steps | Mode: ${mode} | ${path_progress} | GSD ${gsd_done}/${gsd_total} | PLANNING ${plan_done}/${plan_total} | REVIEW ${review_done}/${review_total} | FINALIZATION ${final_done}/${final_total} | RELEASE ${release_done}/${release_total}"
if [[ -n "$next_skill" ]]; then
  msg="${msg} | Next: /${next_skill}"
fi

printf '{"hookSpecificOutput":{"message":%s}}' "$(printf '%s' "$msg" | jq -Rs '.')"
