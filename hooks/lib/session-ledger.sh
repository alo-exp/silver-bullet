# shellcheck shell=bash
# Silver Bullet — session intent ledger helpers.
#
# Runtime paths are host-specific; source the selector so sessions store
# the ledger under the active host runtime root.

_sb_runtime_paths_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$_sb_runtime_paths_dir/runtime-paths.sh" ]]; then
  # shellcheck source=lib/runtime-paths.sh
  source "$_sb_runtime_paths_dir/runtime-paths.sh"
fi

sb_session_ledger_state_dir="${SB_RUNTIME_STATE_DIR}"
sb_session_ledger_anchor="## Agent Teams dispatched"
sb_session_ledger_placeholder="(filled during the session as active requests are intercepted)"

sb_session_ledger_project_root() {
  local root="${PROJECT_ROOT_OVERRIDE:-}"
  if [[ -n "$root" ]]; then
    printf '%s' "$root"
    return 0
  fi

  local search_dir="$PWD"
  while true; do
    if [[ -f "$search_dir/.silver-bullet.json" ]] && [[ -f "$search_dir/silver-bullet.md" ]]; then
      printf '%s' "$search_dir"
      return 0
    fi
    if [[ -d "$search_dir/.git" ]] || [[ "$search_dir" == "/" ]]; then
      break
    fi
    search_dir=$(dirname "$search_dir")
  done

  return 1
}

sb_session_ledger_log_path_file() {
  local file="${SILVER_BULLET_SESSION_LOG_PATH_FILE:-${sb_session_ledger_state_dir}/session-log-path}"
  printf '%s' "$file"
}

sb_session_ledger_log_path() {
  local path_file log_path project_root
  path_file="$(sb_session_ledger_log_path_file)"
  [[ -f "$path_file" && ! -L "$path_file" ]] || return 1

  log_path="$(cat "$path_file" 2>/dev/null || true)"
  [[ -n "$log_path" ]] || return 1
  case "$log_path" in
    /*) ;;
    *) return 1 ;;
  esac

  if project_root="$(sb_session_ledger_project_root 2>/dev/null || true)"; then
    if [[ -n "$project_root" ]]; then
      case "$log_path" in
        "$project_root"/*) ;;
        *) return 1 ;;
      esac
    fi
  fi

  printf '%s' "$log_path"
}

sb_session_ledger_request_block() {
  local prompt="$1"
  shift || true
  local timestamp
  timestamp=$(date -u '+%Y-%m-%d %H:%M:%SZ' 2>/dev/null || date)

  printf -- '- Request [%s]\n' "$timestamp"
  if [[ -n "$prompt" ]]; then
    while IFS= read -r line; do
      printf '  > %s\n' "$line"
    done <<<"$prompt"
  else
    printf '  > (empty)\n'
  fi

  local skill
  for skill in "$@"; do
    [[ -n "$skill" ]] || continue
    printf '  - [ ] %s\n' "$skill"
  done
}

sb_session_ledger_append_block() {
  local log_path="$1"
  local block="$2"
  local tmp tmp_block

  [[ -f "$log_path" && ! -L "$log_path" ]] || return 0

  tmp=$(mktemp)
  tmp_block=$(mktemp)
  printf '%s\n' "$block" > "$tmp_block"
  if grep -qF "$sb_session_ledger_placeholder" "$log_path" 2>/dev/null; then
    if awk -v ph="$sb_session_ledger_placeholder" -v block_file="$tmp_block" '
      function print_block(file,   line) {
        while ((getline line < file) > 0) {
          print line
        }
        close(file)
      }
      $0 == ph {
        print_block(block_file)
        print ""
        next
      }
      { print }
    ' "$log_path" > "$tmp"; then
      mv "$tmp" "$log_path"
      rm -f -- "$tmp_block"
      return 0
    fi
  elif grep -qF "$sb_session_ledger_anchor" "$log_path" 2>/dev/null; then
    if awk -v anchor="$sb_session_ledger_anchor" -v block_file="$tmp_block" '
      function print_block(file,   line) {
        while ((getline line < file) > 0) {
          print line
        }
        close(file)
      }
      $0 == anchor {
        print_block(block_file)
        print ""
      }
      { print }
    ' "$log_path" > "$tmp"; then
      mv "$tmp" "$log_path"
      rm -f -- "$tmp_block"
      return 0
    fi
  else
    printf '%s\n\n' "$block" >> "$log_path"
    rm -f -- "$tmp"
    rm -f -- "$tmp_block"
    return 0
  fi

  rm -f -- "$tmp"
  rm -f -- "$tmp_block"
  return 1
}

sb_session_ledger_append_request() {
  local prompt="$1"
  shift || true
  local log_path block

  log_path="$(sb_session_ledger_log_path 2>/dev/null || true)"
  [[ -n "$log_path" ]] || return 0

  block="$(sb_session_ledger_request_block "$prompt" "$@")"
  sb_session_ledger_append_block "$log_path" "$block"
}

sb_session_ledger_mark_completed() {
  local skill="${1:-}"
  [[ -n "$skill" ]] || return 0

  local log_path
  log_path="$(sb_session_ledger_log_path 2>/dev/null || true)"
  [[ -n "$log_path" && -f "$log_path" && ! -L "$log_path" ]] || return 0

  local escaped_skill tmp
  escaped_skill=$(printf '%s' "$skill" | sed 's/[][(){}.^$*+?|\\/]/\\&/g')
  tmp=$(mktemp)
  if awk -v skill="$escaped_skill" '
    {
      line = $0
      pattern = "^[[:space:]]*- \\[ \\] " skill "$"
      if (line ~ pattern) {
        sub(/\[ \]/, "[x]", line)
      }
      print line
    }
  ' "$log_path" > "$tmp"; then
    mv "$tmp" "$log_path"
    return 0
  fi

  rm -f -- "$tmp"
  return 1
}
