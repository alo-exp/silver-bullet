#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# PreToolUse — single chrome source + tokens.css/font-face guard (Wave 3).
umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
[[ -f "$_lib_dir/runtime-paths.sh" ]] && source "$_lib_dir/runtime-paths.sh"
[[ -f "$_lib_dir/tool-input.sh" ]] && source "$_lib_dir/tool-input.sh"
[[ -f "$_lib_dir/sb-project-gate.sh" ]] && source "$_lib_dir/sb-project-gate.sh"

command -v jq >/dev/null 2>&1 || exit 0

input="$(cat 2>/dev/null || true)"
[[ -n "$input" ]] || exit 0
hook_event="$(printf '%s' "$input" | jq -r '.hook_event_name // "PreToolUse"' 2>/dev/null || echo PreToolUse)"
[[ "$hook_event" == "PreToolUse" ]] || exit 0

tool_name="$(sb_tool_name "$input" 2>/dev/null || true)"
case "$tool_name" in
  Edit|Write|MultiEdit) ;;
  *) exit 0 ;;
esac

config_file=""
search_dir="$PWD"
while true; do
  if [[ -f "$search_dir/.silver-bullet.json" && -f "$search_dir/silver-bullet.md" ]]; then
    config_file="$search_dir/.silver-bullet.json"
    # repo_root reserved for future site-root resolution
    : "${search_dir:?}"
    break
  fi
  if [[ -d "$search_dir/.git" ]] || [[ "$search_dir" == "/" ]]; then
    break
  fi
  search_dir="$(dirname "$search_dir")"
done
[[ -n "$config_file" ]] || exit 0
sb_project_gate_or_exit 2>/dev/null || exit 0

file_path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.path // ""' 2>/dev/null || true)"
new_string="$(printf '%s' "$input" | jq -r '.tool_input.new_string // .tool_input.content // ""' 2>/dev/null || true)"
[[ -n "$file_path" ]] || exit 0

emit_deny() {
  local reason="$1"
  local json_reason
  json_reason=$(printf '%s' "$reason" | jq -Rs '.')
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}' "$json_reason"
  [[ "${SB_KAY_HOOK_BRIDGE_INVOKED:-}" == "1" ]] && { printf '%s\n' "$reason" >&2; exit 2; }
  exit 0
}

case "$file_path" in
  */site/tokens.css|site/tokens.css)
    if printf '%s' "$new_string" | grep -qE '@font-face|font-family:[[:space:]]*[^v]'; then
      if ! printf '%s' "$new_string" | grep -q 'SB FONT TOKEN OVERRIDE'; then
        emit_deny "Site tokens guard — tokens.css @font-face / font-family edits require explicit SB FONT TOKEN OVERRIDE marker in the diff.

Prefer design-system/DESIGN.md tokens. For intentional font changes, include the override marker and run apply-site-chrome.py parity checks."
      fi
    fi
    ;;
esac

if sb_site_session_path_is_site "$file_path" 2>/dev/null || [[ "$file_path" == */site/help/* ]] || [[ "$file_path" == site/help/* ]]; then
  if printf '%s' "$new_string" | grep -qE '<nav[^>]*class="[^"]*nav-inner|<footer[^>]*class="[^"]*footer-inner'; then
    emit_deny "Site chrome single-source guard — inline <nav>/<footer> fragments are forbidden in site/help HTML.

Regenerate chrome via: python3 scripts/apply-site-chrome.py
Canonical fragments: site/_chrome/{nav,footer,help-subnav}.html"
  fi
fi

exit 0
