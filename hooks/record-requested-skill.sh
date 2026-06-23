#!/usr/bin/env bash
set -euo pipefail

emit_noop_json() {
  printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit"}}'
}

finish_noop() {
  emit_noop_json
  exit 0
}

trap 'finish_noop' ERR

# UserPromptSubmit hook helper for Codex.
#
# Rationale:
# - Codex CLI hook tool events are currently Bash-only, and agents don't always
#   read the target SKILL.md file explicitly.
# - SB's E2E and enforcement rely on a durable "state file" trail of which
#   SB steps were invoked.
# - This hook records the *requested* SB route directly from the user prompt,
#   which is deterministic and independent of agent behavior.
#
# Output:
# - Emits an empty hookSpecificOutput object so Codex accepts the hook result
#   without adding any visible prompt context.

umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""

if [[ -n "$_lib_dir" && -f "$_lib_dir/runtime-paths.sh" ]]; then
  # shellcheck source=lib/runtime-paths.sh
  source "$_lib_dir/runtime-paths.sh"
fi

# jq is required — return a no-op payload if missing.
if [[ -f "$_lib_dir/jq-gate.sh" ]]; then
  # shellcheck source=lib/jq-gate.sh
  source "$_lib_dir/jq-gate.sh"
fi
if declare -f sb_jq_enforcement_warn >/dev/null 2>&1; then
  sb_jq_enforcement_warn "record-requested-skill"
fi

input="$(cat 2>/dev/null || true)"
[[ -n "$input" ]] || finish_noop

prompt="$(printf '%s' "$input" | jq -r '.prompt // ""' 2>/dev/null || true)"
[[ -n "$prompt" ]] || finish_noop

# ── Resolve optional project config ──────────────────────────────────────────
#
# Bootstrap requests such as `silver:init` happen before a project scaffold
# exists, so we must still record route markers even when there is no local
# `.silver-bullet.json` yet. If a project config exists, we use it to honor a
# custom state file path; otherwise we fall back to the shared SB state file.
config_file=""
search_dir="$PWD"
while true; do
  if [[ -f "$search_dir/.silver-bullet.json" ]] || [[ -f "$search_dir/silver-bullet.md" ]]; then
    config_file="$search_dir/.silver-bullet.json"
    break
  fi
  if [[ -d "$search_dir/.git" ]] || [[ "$search_dir" == "/" ]]; then
    break
  fi
  search_dir=$(dirname "$search_dir")
done

if [[ -n "$config_file" && -f "$config_file" ]]; then
  if [[ -f "$_lib_dir/sb-project-gate.sh" ]]; then
    # shellcheck source=lib/sb-project-gate.sh
    source "$_lib_dir/sb-project-gate.sh"
  fi
  if declare -f sb_project_active >/dev/null 2>&1; then
    sb_project_active "$config_file" || finish_noop
  elif declare -f sb_project_is_initiated >/dev/null 2>&1; then
    sb_project_is_initiated "$config_file" || finish_noop
  fi
fi

# ── Resolve state file path ─────────────────────────────────────────────────
SB_STATE_DIR="${SB_RUNTIME_STATE_DIR}"
mkdir -p "$SB_STATE_DIR" 2>/dev/null || true

STATE_FILE="${SILVER_BULLET_STATE_FILE:-}"
if [[ -z "$STATE_FILE" ]]; then
  # Expand ~ to $HOME (config stores literal tilde)
  STATE_FILE="$(jq -r '.state.state_file // ""' "$config_file" 2>/dev/null || true)"
  STATE_FILE="${STATE_FILE/#\~/$HOME}"
fi
STATE_FILE="${STATE_FILE:-${SB_STATE_DIR}/state}"

# Security: keep SB state inside the host runtime state root
if ! sb_runtime_path_is_state_scoped "$STATE_FILE"; then
  STATE_FILE="${SB_STATE_DIR}/state"
fi

if [[ -n "$_lib_dir" && -f "$_lib_dir/session-ledger.sh" ]]; then
  # shellcheck source=lib/session-ledger.sh
  source "$_lib_dir/session-ledger.sh"
fi
if [[ -n "$_lib_dir" && -f "$_lib_dir/prompt-classifier.sh" ]]; then
  # shellcheck source=lib/prompt-classifier.sh
  source "$_lib_dir/prompt-classifier.sh"
fi

# ── Extract requested route(s) from prompt ──────────────────────────────────
#
# We record SB routes: `silver:init`, `silver:feature`, etc → requested marker `silver-init`, ...
#
# Requested routes are intentionally stored separately from completed state so
# prompt text cannot satisfy workflow gates.

skills=()
ledger_skills=()

backtick_regex="\`[^\`]+\`"

# Backtick-quoted route markers commonly used by SB test harness prompts.
while IFS= read -r tok; do
  [[ -n "$tok" ]] || continue
  tok="${tok#\`}"
  tok="${tok%\`}"
  case "$tok" in
    silver:*) skills+=("$tok") ;;
  esac
done < <(printf '%s' "$prompt" | grep -oE "$backtick_regex" 2>/dev/null | head -n 50 || true)

if [[ ${#skills[@]} -eq 0 ]] && declare -F sb_prompt_is_bare_work_request >/dev/null 2>&1; then
  if sb_prompt_is_bare_work_request "$prompt"; then
    skills+=("silver")
  fi
fi

[[ ${#skills[@]} -gt 0 ]] || finish_noop

REQUESTED_FILE="${STATE_FILE}.requested"

# Ensure file exists (SEC-02: do not follow symlinks).
if [[ -L "$REQUESTED_FILE" ]]; then
  finish_noop
fi
touch -- "$REQUESTED_FILE" 2>/dev/null || true

canonicalize() {
  local raw="$1"
  # Convert silver:* -> silver-*
  if [[ "$raw" == *:* ]]; then
    printf '%s' "$raw" | sed 's/:/-/g'
  else
    printf '%s' "$raw"
  fi
}

for raw in "${skills[@]}"; do
  skill="$(canonicalize "$raw")"
  case "$skill" in
    silver) ;;
    silver-*) ;;
    *) continue ;;
  esac
  ledger_skills+=("$skill")

  # No duplicates.
  if ! grep -Fqx -- "$skill" "$REQUESTED_FILE" 2>/dev/null; then
    printf '%s\n' "$skill" >>"$REQUESTED_FILE" 2>/dev/null || true
  fi
done

if declare -F sb_session_ledger_append_request >/dev/null 2>&1; then
  sb_session_ledger_append_request "$prompt" "${ledger_skills[@]}" || true
fi

emit_noop_json
exit 0
