# shellcheck shell=bash
# Context Mode Read/Grep size gate — deny large file reads when opted in.
# Sourced by: context-mode-read-deny.sh

_sb_context_mode_default_read_deny_bytes=5120

if [[ -f "$(dirname "${BASH_SOURCE[0]}")/context-mode-gate.sh" ]]; then
  # shellcheck source=context-mode-gate.sh
  source "$(dirname "${BASH_SOURCE[0]}")/context-mode-gate.sh"
fi
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/tool-input.sh" ]]; then
  # shellcheck source=tool-input.sh
  source "$(dirname "${BASH_SOURCE[0]}")/tool-input.sh"
fi

sb_context_mode_read_deny_bytes() {
  local config_file="${1:-}"
  local bytes="${_sb_context_mode_default_read_deny_bytes}"
  if [[ -n "$config_file" && -f "$config_file" ]]; then
    bytes="$(jq -r --argjson def "$_sb_context_mode_default_read_deny_bytes" \
      '.recommended_tools.context_mode.read_deny_bytes // $def' "$config_file" 2>/dev/null || echo "$_sb_context_mode_default_read_deny_bytes")"
  fi
  if [[ "$bytes" =~ ^[0-9]+$ ]]; then
    printf '%s' "$bytes"
    return 0
  fi
  printf '%s' "$_sb_context_mode_default_read_deny_bytes"
}

sb_context_mode_resolve_read_path() {
  local file_path="${1:-}" project_root="${2:-$PWD}"
  python3 - "$project_root" "$file_path" <<'PY' 2>/dev/null || true
import pathlib
import sys

root = pathlib.Path(sys.argv[1]).resolve()
raw = sys.argv[2]
if not raw:
    raise SystemExit(0)
path = pathlib.Path(raw).expanduser()
if not path.is_absolute():
    path = root / path
print(path.resolve(strict=False))
PY
}

sb_context_mode_file_size_bytes() {
  local file_path="${1:-}"
  [[ -n "$file_path" && -f "$file_path" ]] || return 1
  python3 - "$file_path" <<'PY' 2>/dev/null || return 1
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
if not path.is_file():
    raise SystemExit(1)
print(path.stat().st_size)
PY
}

sb_context_mode_tool_read_path() {
  local input="${1:-}"
  local tool_name
  tool_name="$(sb_tool_name "$input" 2>/dev/null || true)"
  case "$tool_name" in
    Read)
      sb_tool_file_path "$input"
      ;;
    Grep)
      printf '%s' "$input" | jq -r '.tool_input.path // ""' 2>/dev/null || true
      ;;
    *)
      ;;
  esac
}

sb_context_mode_read_path_is_exempt() {
  local file_path="${1:-}"
  local config_file="${2:-}"
  [[ -n "$file_path" ]] || return 1

  if declare -f sb_context_mode_edit_path_is_exempt >/dev/null 2>&1; then
    sb_context_mode_edit_path_is_exempt "$file_path" && return 0
  fi

  case "$file_path" in
    */graphify-out/graph.json|*/graphify-out/wiki/index.md)
      return 0
      ;;
  esac

  if [[ -n "$config_file" && -f "$config_file" ]]; then
    local state_file trivial_file
    state_file="$(jq -r '.state.state_file // ""' "$config_file" 2>/dev/null || true)"
    trivial_file="$(jq -r '.state.trivial_file // ""' "$config_file" 2>/dev/null || true)"
    if [[ -n "$state_file" ]]; then
      state_file="${state_file/#\~/$HOME}"
      if [[ "$file_path" == "$state_file" ]]; then
        return 0
      fi
    fi
    if [[ -n "$trivial_file" ]]; then
      trivial_file="${trivial_file/#\~/$HOME}"
      if [[ "$file_path" == "$trivial_file" ]]; then
        return 0
      fi
    fi
  fi

  return 1
}

# Returns 0 when the Read/Grep should be denied (file over threshold).
sb_context_mode_should_deny_read() {
  local input="${1:-}" config_file="${2:-}" project_root="${3:-$PWD}"
  local tool_name file_path threshold resolved size

  threshold="$(sb_context_mode_read_deny_bytes "$config_file")"
  [[ "$threshold" =~ ^[0-9]+$ && "$threshold" -gt 0 ]] || return 1

  tool_name="$(sb_tool_name "$input" 2>/dev/null || true)"
  case "$tool_name" in
    Read|Grep) ;;
    *) return 1 ;;
  esac

  file_path="$(sb_context_mode_tool_read_path "$input")"
  [[ -n "$file_path" ]] || return 1

  resolved="$(sb_context_mode_resolve_read_path "$file_path" "$project_root")"
  [[ -n "$resolved" && -f "$resolved" ]] || return 1

  if sb_context_mode_read_path_is_exempt "$resolved" "$config_file"; then
    return 1
  fi

  size="$(sb_context_mode_file_size_bytes "$resolved" || true)"
  [[ "$size" =~ ^[0-9]+$ ]] || return 1

  if [[ "$size" -gt "$threshold" ]]; then
    printf '%s' "$resolved"
    return 0
  fi
  return 1
}

sb_context_mode_read_deny_message() {
  local file_path="${1:-}" size="${2:-}" threshold="${3:-}"
  cat <<EOF
🚫 CONTEXT MODE — Read blocked (${size} bytes > ${threshold} byte threshold).

Use Context Mode MCP instead of Read/Grep for large-file analysis:
  • ctx_index + ctx_search — index then query relevant sections
  • ctx_execute_file — sandboxed analysis (only stdout enters context)
  • ctx_batch_execute — batch reads with auto-index

Read is still correct when you will Edit the same file next (exact bytes required).

Path: ${file_path}
See docs/CONTEXT-MODE.md and silver-bullet.md §2g-ii.
EOF
}
