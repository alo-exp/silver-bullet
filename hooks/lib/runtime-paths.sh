# shellcheck shell=bash
# Silver Bullet runtime-aware host paths.
#
# Codex sessions should use the Codex runtime home root for SB state and
# plugin caches. Claude sessions should use the Claude runtime home root.
# Tests can force any host by exporting SILVER_BULLET_RUNTIME.

if [[ -z "${SILVER_BULLET_RUNTIME:-}" ]]; then
  _sb_runtime_source="${BASH_SOURCE[0]:-$0}"
  if [[ -n "${CODEX_CI:-}" || -n "${CODEX_THREAD_ID:-}" || -n "${CODEX_INTERNAL_ORIGINATOR_OVERRIDE:-}" || "$_sb_runtime_source" == *"/.codex/"* || ( -n "${CLAUDE_PLUGIN_ROOT:-}" && "$CLAUDE_PLUGIN_ROOT" == *"/.codex/"* ) ]]; then
    SILVER_BULLET_RUNTIME="codex"
  elif [[ -n "${PI_CODING_AGENT_DIR:-}" || "$_sb_runtime_source" == *"/.pi/"* ]]; then
    SILVER_BULLET_RUNTIME="pi"
  elif [[ -n "${OPENCODE:-}" || -n "${OPENCODE_PID:-}" || "$_sb_runtime_source" == *"/.config/opencode/"* ]]; then
    SILVER_BULLET_RUNTIME="opencode"
  else
    SILVER_BULLET_RUNTIME="claude"
  fi
fi

case "$SILVER_BULLET_RUNTIME" in
  claude|codex|opencode|pi|goose|hermes) ;;
  *) SILVER_BULLET_RUNTIME="claude" ;;
esac

SB_RUNTIME_NAME="$SILVER_BULLET_RUNTIME"
_sb_runtime_base_home="${HOME}"
if [[ "$SB_RUNTIME_NAME" == "codex" && -n "${KAY_HOME:-}" ]]; then
  _sb_runtime_base_home="${KAY_HOME}"
fi
case "$SB_RUNTIME_NAME" in
  opencode) SB_RUNTIME_HOME_ROOT="${HOME}/.config/opencode" ;;
  pi) SB_RUNTIME_HOME_ROOT="${PI_CODING_AGENT_DIR:-${HOME}/.pi/agent}" ;;
  goose) SB_RUNTIME_HOME_ROOT="${HOME}/.config/goose" ;;
  hermes) SB_RUNTIME_HOME_ROOT="${HOME}/.hermes" ;;
  *) SB_RUNTIME_HOME_ROOT="${_sb_runtime_base_home}/.${SB_RUNTIME_NAME}" ;;
esac
# Tests/hooks may pin state dir via SB_RUNTIME_STATE_DIR when SB_RUNTIME_PRESERVE_STATE_DIR=1.
if [[ "${SB_RUNTIME_PRESERVE_STATE_DIR:-}" == "1" && -n "${SB_RUNTIME_STATE_DIR:-}" ]]; then
  :
else
  SB_RUNTIME_STATE_DIR="${SB_RUNTIME_HOME_ROOT}/.silver-bullet"
fi
SB_RUNTIME_PLUGIN_CACHE_ROOT="${SB_RUNTIME_HOME_ROOT}/plugins/cache"

# Canonical path resolution for the state-root containment checks below. Without the
# library every containment check fails closed (callers fall back to their defaults).
_sb_runtime_lib_src="${BASH_SOURCE[0]:-$0}"
_sb_runtime_lib_dir="${_sb_runtime_lib_src%/*}"
[[ "$_sb_runtime_lib_dir" != "$_sb_runtime_lib_src" ]] || _sb_runtime_lib_dir="."
if [[ -f "$_sb_runtime_lib_dir/path-canonical.sh" ]]; then
  # shellcheck source=path-canonical.sh
  source "$_sb_runtime_lib_dir/path-canonical.sh"
fi
unset _sb_runtime_lib_dir _sb_runtime_lib_src

# _sb_runtime_state_root_contains CANONICAL_PATH: strictly below a canonical state root.
# Roots: $SB_RUNTIME_HOME_ROOT/.silver-bullet, plus SB_RUNTIME_EXTRA_STATE_ROOTS entries that
# are absolute and end in /.silver-bullet (Kay live tests run Codex-compatible hooks against
# an isolated .kay state root; never accept arbitrary .codex/.kay looking paths by name).
_sb_runtime_state_root_contains() {
  local path="$1" list root
  list="${SB_RUNTIME_EXTRA_STATE_ROOTS:-}"
  root="${SB_RUNTIME_HOME_ROOT}/.silver-bullet"
  while :; do
    while [[ "$root" == */ ]]; do root="${root%/}"; done
    if [[ "$root" == /*/.silver-bullet ]] && _sb_path_phys "$root" && [[ "$_SB_PATH_OUT" != "/" && "$path" == "$_SB_PATH_OUT"/* ]]; then
      return 0
    fi
    [[ -n "$list" ]] || return 1
    root="${list%%:*}"
    if [[ "$list" == *:* ]]; then
      list="${list#*:}"
    else
      list=""
    fi
  done
}

# sb_runtime_state_path PATH: the single safe resolver for configured or overridden state
# paths. Prints PATH's canonical form and returns 0 only when it lies strictly inside a
# state root: a leading ~ is expanded, the directory part is resolved physically ('.', '..',
# '//', symlinked parents), trailing '/' is dropped, and a leaf symlink must point inside a
# root too (the leaf itself is kept, so deleting the result removes the link). Prints nothing
# and returns 1 for empty, relative or control-character paths and for anything escaping.
sb_runtime_state_path() {
  local candidate="${1:-}" path leaf
  case "$candidate" in
    '' | *$'\n'* | *$'\r'*) return 1 ;;
  esac
  declare -f _sb_path_phys >/dev/null 2>&1 || return 1
  _sb_path_host "$candidate"
  path="$_SB_PATH_OUT"
  [[ "$path" == /* ]] || return 1
  while [[ "$path" == */ && "$path" != "/" ]]; do path="${path%/}"; done
  leaf="${path##*/}"
  case "$leaf" in
    . | ..)
      _sb_path_phys "$path" || return 1
      path="$_SB_PATH_OUT"
      ;;
    *)
      _sb_path_phys "${path%/*}" || return 1
      path="${_SB_PATH_OUT%/}/$leaf"
      ;;
  esac
  _sb_runtime_state_root_contains "$path" || return 1
  if [[ -L "$path" ]]; then
    _sb_path_phys "$path" || return 1
    _sb_runtime_state_root_contains "$_SB_PATH_OUT" || return 1
  fi
  printf '%s' "$path"
}

# sb_runtime_path_is_state_scoped PATH: true when the literal absolute PATH (as the caller
# will use it, so no ~ or drive-letter translation) resolves inside a state root.
sb_runtime_path_is_state_scoped() {
  [[ "${1:-}" == /* ]] || return 1
  sb_runtime_state_path "$1" >/dev/null
}

# Resolve the active host's config root at the runtime boundary so shared
# reconciliation code does not embed a vendor-specific environment variable.
sb_runtime_codex_home() {
  printf '%s' "${CODEX_HOME:-${HOME}/.codex}"
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
    for runtime in codex claude; do
      _sb_append_receipt_dir "${base_home}/.${runtime}/.silver-bullet"
    done
    _sb_append_receipt_dir "${base_home}/.config/opencode/.silver-bullet"
    _sb_append_receipt_dir "${PI_CODING_AGENT_DIR:-${base_home}/.pi/agent}/.silver-bullet"
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
