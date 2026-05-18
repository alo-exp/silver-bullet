#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# UserPromptSubmit hook helper for Codex.
#
# Rationale:
# - Codex CLI hook tool events are currently Bash-only, and agents don't always
#   read the target SKILL.md file explicitly.
# - SB's E2E and enforcement rely on a durable "state file" trail of which
#   SB/GSD steps were invoked.
# - This hook records the *requested* SB/GSD route directly from the user prompt,
#   which is deterministic and independent of agent behavior.
#
# Output:
# - Intentionally emits nothing (stdout empty) to avoid adding hook context noise.

umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""

command -v jq >/dev/null 2>&1 || exit 0

input="$(cat 2>/dev/null || true)"
[[ -n "$input" ]] || exit 0

prompt="$(printf '%s' "$input" | jq -r '.prompt // ""' 2>/dev/null || true)"
[[ -n "$prompt" ]] || exit 0

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

# ── Resolve state file path ─────────────────────────────────────────────────
SB_STATE_DIR="${HOME}/.claude/.silver-bullet"
mkdir -p "$SB_STATE_DIR" 2>/dev/null || true

STATE_FILE="${SILVER_BULLET_STATE_FILE:-}"
if [[ -z "$STATE_FILE" ]]; then
  # Expand ~ to $HOME (config stores literal tilde)
  STATE_FILE="$(jq -r '.state.state_file // ""' "$config_file" 2>/dev/null || true)"
  STATE_FILE="${STATE_FILE/#\~/$HOME}"
fi
STATE_FILE="${STATE_FILE:-${SB_STATE_DIR}/state}"

# Security: keep SB state inside ~/.claude/
case "$STATE_FILE" in
  "$HOME"/.claude/*) ;;
  *) STATE_FILE="${SB_STATE_DIR}/state" ;;
esac

if [[ -n "$_lib_dir" && -f "$_lib_dir/session-ledger.sh" ]]; then
  # shellcheck source=lib/session-ledger.sh
  source "$_lib_dir/session-ledger.sh"
fi

# ── Extract requested route(s) from prompt ──────────────────────────────────
#
# We record two kinds of markers:
# - SB routes: `silver:init`, `silver:feature`, etc → requested marker `silver-init`, ...
# - GSD phase names mentioned in text: `gsd-discuss-phase`, `gsd-plan-phase`, ...
#
# We keep this intentionally conservative: only record SB and GSD markers.
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
    silver:*|gsd:*) skills+=("$tok") ;;
  esac
done < <(printf '%s' "$prompt" | grep -oE "$backtick_regex" 2>/dev/null | head -n 50 || true)

# Explicit gsd-* mentions in plain text (no backticks).
while IFS= read -r tok; do
  [[ -n "$tok" ]] || continue
  skills+=("$tok")
done < <(printf '%s' "$prompt" | grep -oE '\\bgsd-[a-zA-Z0-9-]+\\b' 2>/dev/null | head -n 50 || true)

[[ ${#skills[@]} -gt 0 ]] || exit 0

REQUESTED_FILE="${STATE_FILE}.requested"

# Ensure file exists (SEC-02: do not follow symlinks).
if [[ -L "$REQUESTED_FILE" ]]; then
  exit 0
fi
touch -- "$REQUESTED_FILE" 2>/dev/null || true

canonicalize() {
  local raw="$1"
  # Convert gsd:* -> gsd-*, silver:* -> silver-*
  if [[ "$raw" == *:* ]]; then
    printf '%s' "$raw" | sed 's/:/-/g'
  else
    printf '%s' "$raw"
  fi
}

for raw in "${skills[@]}"; do
  skill="$(canonicalize "$raw")"
  case "$skill" in
    silver-*) ;;
    gsd-*) ;;
    *) continue ;;
  esac
  ledger_skills+=("$skill")

  # No duplicates.
  if ! grep -qx "$skill" "$REQUESTED_FILE" 2>/dev/null; then
    printf '%s\n' "$skill" >>"$REQUESTED_FILE" 2>/dev/null || true
  fi
done

if declare -F sb_session_ledger_append_request >/dev/null 2>&1; then
  sb_session_ledger_append_request "$prompt" "${ledger_skills[@]}" || true
fi

exit 0
