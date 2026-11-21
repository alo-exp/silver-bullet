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

  # The log must belong to the SB project enclosing the current directory. Without one (a prompt
  # typed in an unrelated repository) nothing is logged, so it cannot land in the last SB project's
  # log (R3-12). Containment is judged on physical paths, so `..` and symlinks cannot escape.
  project_root="$(sb_session_ledger_project_root 2>/dev/null || true)"
  [[ -n "$project_root" ]] || return 1
  local real_root real_dir
  real_root="$(cd -P -- "$project_root" 2>/dev/null && pwd)" || real_root=""
  real_dir="$(cd -P -- "$(dirname "$log_path")" 2>/dev/null && pwd)" || real_dir=""
  [[ -n "$real_root" && -n "$real_dir" ]] || return 1
  case "$real_dir/" in
    "$real_root"/*) ;;
    *) return 1 ;;
  esac

  printf '%s' "$log_path"
}

# Token-like secrets are masked before a prompt is written into a log that is usually committed.
sb_session_ledger_redact() {
  sed -E \
    -e 's/gh[pousr]_[A-Za-z0-9]{20,}/[REDACTED]/g' \
    -e 's/github_pat_[A-Za-z0-9_]{20,}/[REDACTED]/g' \
    -e 's/sk-[A-Za-z0-9_-]{16,}/[REDACTED]/g' \
    -e 's/AKIA[0-9A-Z]{16}/[REDACTED]/g' \
    -e 's/xox[abprs]-[A-Za-z0-9-]{10,}/[REDACTED]/g' \
    -e 's/(([Pp][Aa][Ss][Ss]([Ww][Oo][Rr])?[Dd]|[Ss][Ee][Cc][Rr][Ee][Tt]|[Tt][Oo][Kk][Ee][Nn]|[Aa][Pp][Ii][_-]?[Kk][Ee][Yy])[ \t]*[:=][ \t]*)[^ \t]+/\1[REDACTED]/g'
}

sb_session_ledger_request_block() {
  local prompt="$1"
  shift
  local timestamp
  timestamp=$(date -u '+%Y-%m-%d %H:%M:%SZ' 2>/dev/null || date)

  printf -- '- Request [%s]\n' "$timestamp"
  if [[ -n "$prompt" ]]; then
    while IFS= read -r line; do
      printf '  > %s\n' "$line"
    done < <(printf '%s\n' "$prompt" | sb_session_ledger_redact)
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
  shift
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

  local tmp
  tmp=$(mktemp)
  # The skill name is compared literally and passed through the environment: awk -v
  # processes backslash escapes, which gawk and mawk treat differently.
  if SB_LEDGER_SKILL="$skill" awk '
    {
      line = $0
      if (match(line, /^[[:space:]]*- \[ \] /) && substr(line, RLENGTH + 1) == ENVIRON["SB_LEDGER_SKILL"]) {
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
