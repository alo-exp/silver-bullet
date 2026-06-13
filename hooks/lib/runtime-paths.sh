# shellcheck shell=bash
# Silver Bullet runtime-aware host paths.
#
# Codex sessions should use the Codex runtime home root for SB state and
# plugin caches. Claude sessions should use the Claude runtime home root.
# Cursor sessions should use the Cursor runtime home root (~/.cursor).
# Tests can force any host by exporting SILVER_BULLET_RUNTIME.

if [[ -z "${SILVER_BULLET_RUNTIME:-}" ]]; then
  _sb_runtime_source="${BASH_SOURCE[0]:-$0}"
  if [[ -n "${CODEX_CI:-}" || -n "${CODEX_THREAD_ID:-}" || -n "${CODEX_INTERNAL_ORIGINATOR_OVERRIDE:-}" || "$_sb_runtime_source" == *"/.codex/"* || ( -n "${CLAUDE_PLUGIN_ROOT:-}" && "$CLAUDE_PLUGIN_ROOT" == *"/.codex/"* ) ]]; then
    SILVER_BULLET_RUNTIME="codex"
  elif [[ -n "${CURSOR_PLUGIN_ROOT:-}" || "$_sb_runtime_source" == *"/.cursor/"* || ( -n "${CLAUDE_PLUGIN_ROOT:-}" && "$CLAUDE_PLUGIN_ROOT" == *"/.cursor/"* ) ]]; then
    SILVER_BULLET_RUNTIME="cursor"
  else
    SILVER_BULLET_RUNTIME="claude"
  fi
fi

case "$SILVER_BULLET_RUNTIME" in
  claude|codex|cursor) ;;
  *) SILVER_BULLET_RUNTIME="claude" ;;
esac

SB_RUNTIME_NAME="$SILVER_BULLET_RUNTIME"
_sb_runtime_base_home="${HOME}"
if [[ "$SB_RUNTIME_NAME" == "codex" && -n "${KAY_HOME:-}" ]]; then
  _sb_runtime_base_home="${KAY_HOME}"
fi
SB_RUNTIME_HOME_ROOT="${_sb_runtime_base_home}/.${SB_RUNTIME_NAME}"
SB_RUNTIME_STATE_DIR="${SB_RUNTIME_HOME_ROOT}/.silver-bullet"
SB_RUNTIME_PLUGIN_CACHE_ROOT="${SB_RUNTIME_HOME_ROOT}/plugins/cache"

sb_runtime_path_is_state_scoped() {
  local candidate="$1"
  local extra_root
  [[ -n "$candidate" ]] || return 1

  case "$candidate" in
    "$SB_RUNTIME_HOME_ROOT"/.silver-bullet/*) return 0 ;;
  esac

  # Kay live tests run Codex-compatible hooks against an isolated .kay state
  # root. Keep that exception explicit; never accept arbitrary .codex/.kay
  # looking paths just because their names match.
  if [[ -n "${SB_RUNTIME_EXTRA_STATE_ROOTS:-}" ]]; then
    IFS=':' read -r -a _sb_extra_state_roots <<< "$SB_RUNTIME_EXTRA_STATE_ROOTS"
    for extra_root in "${_sb_extra_state_roots[@]}"; do
      [[ -n "$extra_root" ]] || continue
      extra_root="${extra_root%/}"
      case "$extra_root" in
        */.silver-bullet) ;;
        *) continue ;;
      esac
      case "$candidate" in
        "$extra_root"/*) return 0 ;;
      esac
    done
  fi

  return 1
}

sb_runtime_skill_receipt_dirs() {
  local seen="" candidate base_home runtime extra_root

  _sb_append_receipt_dir() {
    local state_dir="${1%/}"
    [[ -n "$state_dir" ]] || return 0
    candidate="${state_dir}/skill-invocations"
    case ":${seen}:" in
      *":${candidate}:"*) return 0 ;;
    esac
    seen="${seen:+$seen:}${candidate}"
    printf '%s\n' "$candidate"
  }

  _sb_append_receipt_dir "$SB_RUNTIME_STATE_DIR"

  for base_home in "$HOME" "${KAY_HOME:-}"; do
    [[ -n "$base_home" ]] || continue
    for runtime in codex claude cursor; do
      _sb_append_receipt_dir "${base_home}/.${runtime}/.silver-bullet"
    done
  done

  if [[ -n "${SB_RUNTIME_EXTRA_STATE_ROOTS:-}" ]]; then
    IFS=':' read -r -a _sb_extra_state_roots <<< "${SB_RUNTIME_EXTRA_STATE_ROOTS}"
    for extra_root in "${_sb_extra_state_roots[@]}"; do
      [[ -n "$extra_root" ]] || continue
      extra_root="${extra_root%/}"
      case "$extra_root" in
        */.silver-bullet) _sb_append_receipt_dir "$extra_root" ;;
        *) _sb_append_receipt_dir "${extra_root}/.silver-bullet" ;;
      esac
    done
  fi
}

export SILVER_BULLET_RUNTIME SB_RUNTIME_NAME SB_RUNTIME_HOME_ROOT SB_RUNTIME_STATE_DIR SB_RUNTIME_PLUGIN_CACHE_ROOT
unset _sb_runtime_base_home
