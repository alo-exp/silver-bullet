#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# PreToolUse — single chrome source + tokens.css/font-face guard (Wave 3). It reads the new content of the file
# tools (Edit, Write, MultiEdit edits[], apply_patch added lines); shell writes are not inspected (the hook is
# not registered for them), which docs/HOOKS.md notes.
umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
[[ -f "$_lib_dir/runtime-paths.sh" ]] && source "$_lib_dir/runtime-paths.sh"
[[ -f "$_lib_dir/site-session.sh" ]] && source "$_lib_dir/site-session.sh"
[[ -f "$_lib_dir/tool-input.sh" ]] && source "$_lib_dir/tool-input.sh"
[[ -f "$_lib_dir/sb-project-gate.sh" ]] && source "$_lib_dir/sb-project-gate.sh"

command -v jq >/dev/null 2>&1 || exit 0

input="$(cat 2>/dev/null || true)"
[[ -n "$input" ]] || exit 0
hook_event="$(printf '%s' "$input" | jq -r '.hook_event_name // "PreToolUse"' 2>/dev/null || echo PreToolUse)"
[[ "$hook_event" == "PreToolUse" ]] || exit 0

tool_name="$(sb_tool_name "$input" 2>/dev/null || true)"
case "$tool_name" in
  Edit|Write|MultiEdit|apply_patch) ;;
  *) exit 0 ;;
esac

# The project: the nearest root with a record, else the nearest directory with both contract files.
config_file="$( (source "$(dirname "${BASH_SOURCE[0]}")/lib/integrity-anchor.sh" && sb_integrity_activation_config "$PWD") 2>/dev/null; true)"
[[ -n "$config_file" ]] || exit 0
sb_project_gate_or_exit 2>/dev/null || exit 0
sb_site_profile_load || exit 0
sb_site_set_cwd "$input"

# Every file this call writes, and all the new content it carries.
paths="$({ sb_tool_file_path "$input"; printf '%s\n' "$input" | jq -r '.tool_input.path // empty | strings'; sb_tool_patch_paths "$input"; })"
new_string="$(printf '%s' "$input" | jq -r '
  .tool_input | objects
  | [ .new_string?, .content?, (.edits[]? | .new_string?),
      ((.input? // .patch? // .command? // "") | strings | split("\n") | map(select(startswith("+"))) | join("\n")) ]
  | map(strings) | join("\n")')"
[[ -n "$paths" ]] || exit 0

emit_deny() {
  local reason="$1"
  local json_reason
  json_reason=$(printf '%s' "$reason" | jq -Rs '.')
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}' "$json_reason"
  [[ "${SB_KAY_HOOK_BRIDGE_INVOKED:-}" == "1" ]] && { printf '%s\n' "$reason" >&2; exit 2; }
  exit 0
}

while IFS= read -r file_path; do
  if sb_site_session_path_is_site "$file_path"; then
    case "$file_path" in
      */tokens.css | tokens.css)
        # Only token references (font-family: var(--x)) are allowed; any other value is a raw font.
        font_decls="$(grep -oE 'font-family:[[:space:]]*[^;}]*' <<<"$new_string" || true)"
        if grep -qE '@font-face' <<<"$new_string" || { [[ -n "$font_decls" ]] && grep -qvE '^font-family:[[:space:]]*var\(' <<<"$font_decls"; }; then
          if ! grep -q 'SB FONT TOKEN OVERRIDE' <<<"$new_string"; then
            emit_deny "Site tokens guard — tokens.css @font-face / font-family edits require explicit SB FONT TOKEN OVERRIDE marker in the diff.

Prefer design-system/DESIGN.md tokens. For intentional font changes, include the override marker and run apply-site-chrome.py parity checks."
          fi
        fi
        ;;
    esac
    if grep -qE '<nav[^>]*class="[^"]*nav-inner|<footer[^>]*class="[^"]*footer-inner' <<<"$new_string"; then
      emit_deny "Site chrome single-source guard — inline <nav>/<footer> fragments are forbidden in site HTML.

Regenerate chrome via: python3 scripts/apply-site-chrome.py
Canonical fragments: site/_chrome/{nav,footer,help-subnav}.html"
    fi
  fi
done <<<"$paths"

exit 0
