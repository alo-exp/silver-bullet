# shellcheck shell=bash
# Shared reconciliation helpers — consent, state precedence, authorization.
# Sourced only by scripts/reconcile-recommended-tools.sh and sibling libs (not executable).

# shellcheck disable=SC2034  # read by the sibling heartbeat.sh
RT_RECONCILER_VERSION="1.0.0"
# shellcheck disable=SC2034  # read by scripts/reconcile-recommended-tools.sh
RT_RESULT_SCHEMA_VERSION="1.0.0"

# shellcheck disable=SC2034  # read by scripts/reconcile-recommended-tools.sh
RT_COMPONENT_IDS=(graphify agentmemory rtk context_mode leanctx alumnium search_cli cross_tool)
# shellcheck disable=SC2034  # read by the sibling probe-cross-tool.sh
RT_FIVE_TOOL_ROUTES=(
  sb_wire:leanctx sb_read:leanctx sb_grep:context_mode sb_shell:rtk
  sb_slice:context_mode sb_webfetch:context_mode sb_graph:graphify
  sb_remember:agentmemory sb_pathjail:leanctx sb_injection:leanctx
)
RT_VALID_HOSTS=(cursor claude codex opencode pi goose hermes)

_rt_repo_root() {
  local lib_dir candidate
  lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  candidate="$(cd "${lib_dir}/../../.." && pwd)"
  if [[ -f "${candidate}/scripts/reconcile-recommended-tools.sh" ]]; then
    printf '%s' "$candidate"
    return 0
  fi
  if [[ -f "${HOME}/.cursor/state/toolstack/repo-root" ]]; then
    tr -d '\n' <"${HOME}/.cursor/state/toolstack/repo-root"
    return 0
  fi
  printf '%s' "$candidate"
}

rt_init_paths() {
  RT_REPO_ROOT="${RT_REPO_ROOT:-$(_rt_repo_root)}"
  RT_HOOKS_LIB="${RT_REPO_ROOT}/hooks/lib"
  if [[ -f "${RT_HOOKS_LIB}/runtime-paths.sh" ]]; then
    # shellcheck source=/dev/null
    source "${RT_HOOKS_LIB}/runtime-paths.sh"
  fi
  if [[ -f "${RT_HOOKS_LIB}/recommended-tools.sh" ]]; then
    # shellcheck source=/dev/null
    source "${RT_HOOKS_LIB}/recommended-tools.sh"
  fi
  if [[ -f "${RT_HOOKS_LIB}/graphify-gate.sh" ]]; then
    # shellcheck source=/dev/null
    source "${RT_HOOKS_LIB}/graphify-gate.sh"
  fi
  if [[ -f "${RT_HOOKS_LIB}/agentmemory-gate.sh" ]]; then
    # shellcheck source=/dev/null
    source "${RT_HOOKS_LIB}/agentmemory-gate.sh"
  fi
  if [[ -f "${RT_HOOKS_LIB}/rtk-gate.sh" ]]; then
    # shellcheck source=/dev/null
    source "${RT_HOOKS_LIB}/rtk-gate.sh"
  fi
  if [[ -f "${RT_HOOKS_LIB}/context-mode-gate.sh" ]]; then
    # shellcheck source=/dev/null
    source "${RT_HOOKS_LIB}/context-mode-gate.sh"
  fi
  if [[ -f "${RT_HOOKS_LIB}/leanctx-gate.sh" ]]; then
    # shellcheck source=/dev/null
    source "${RT_HOOKS_LIB}/leanctx-gate.sh"
  fi
  if [[ -f "${RT_HOOKS_LIB}/alumnium-gate.sh" ]]; then
    # shellcheck source=/dev/null
    source "${RT_HOOKS_LIB}/alumnium-gate.sh"
  fi
}

rt_project_config() {
  local root="${RT_PROJECT_ROOT:-}"
  [[ -n "$root" && -f "${root}/.silver-bullet.json" ]] && printf '%s' "${root}/.silver-bullet.json"
}

# The user's consent for a tool: pending | enabled | disabled. It comes only from the per-user
# consent store (hooks/lib/user-consent.sh, docs/CONSENT.md): the project file may turn a tool
# off, but a recommendation in it ("enabled_by_user": true) is never consent.
#   disabled  the project file turns the tool off, or the user declined it
#   enabled   the user granted install, wire or enforce (machine-wide, or enforce for this project)
#   pending   no decision
rt_consent_for() {
  local tool_id="${1:-}" cfg="" cap decision granted=0 declined=0
  cfg="$(rt_project_config)" || cfg=""
  if [[ -n "$cfg" && "$(sb_recommended_tool_project_preference "$cfg" "$tool_id")" == "disabled" ]]; then
    printf 'disabled'
    return 0
  fi
  for cap in install wire enforce; do
    decision="$(sb_consent_decision "$tool_id" "$cap" "${RT_PROJECT_ROOT:-}")"
    case "$decision" in
      granted) granted=1 ;;
      declined) declined=1 ;;
    esac
  done
  if ((granted)); then
    printf 'enabled'
  elif ((declined)); then
    printf 'disabled'
  else
    printf 'pending'
  fi
}

rt_is_suspended() {
  local tool_id="${1:-}"
  local cfg
  cfg="$(rt_project_config)" || return 1
  sb_recommended_tool_enforcement_suspended "$cfg" "$tool_id"
}

# rt_run_registry_command LINE PROGRAM...: run one line of Silver Bullet's built-in command table
# without a shell. Status 2: not runnable (shell syntax, prose, or a program other than the listed
# ones); 3: the program is not installed; otherwise the program's status. No eval, no bash -c.
rt_run_registry_command() {
  local line="${1:-}" prog allowed=0
  local -a argv
  shift
  case "$line" in
    *[!A-Za-z0-9\ ._/=:@-]*) return 2 ;;
  esac
  read -r -a argv <<<"$line"
  prog="${argv[0]:-}"
  for line in "$@"; do
    [[ "$prog" == "$line" ]] && allowed=1
  done
  ((allowed)) || return 2
  command -v "$prog" >/dev/null 2>&1 || return 3
  "${argv[@]}"
}

# rt_run_registry_chain LINE PROGRAM...: run "cmd1 && cmd2 && ..." from the built-in table, each
# part through rt_run_registry_command; stop at the first failure and return its status.
rt_run_registry_chain() {
  local line="${1:-}" part rc=0
  local -a parts
  shift
  [[ -n "$line" ]] || return 2
  while [[ "$line" == *" && "* ]]; do
    parts+=("${line%% && *}")
    line="${line#* && }"
  done
  parts+=("$line")
  for part in "${parts[@]}"; do
    rt_run_registry_command "$part" "$@" || { rc=$?; break; }
  done
  return "$rc"
}

rt_validate_host() {
  local host="${1:-}"
  local h
  for h in "${RT_VALID_HOSTS[@]}"; do
    [[ "$host" == "$h" ]] && return 0
  done
  return 1
}

rt_host_supported() {
  local host="${1:-}"
  case "$host" in
    cursor|claude|codex|opencode|pi) return 0 ;;
    *) return 1 ;;
  esac
}

rt_five_tool_host_supported() {
  rt_host_supported "${1:-}"
}

rt_host_mcp_config_path() {
  local host="${1:-${RT_HOST:-cursor}}"
  case "$host" in
    cursor) printf '%s/.cursor/mcp.json' "${HOME}" ;;
    claude) printf '%s/.claude.json' "${HOME}" ;;
    codex)
      if declare -f sb_runtime_codex_home >/dev/null 2>&1; then
        printf '%s/config.toml' "$(sb_runtime_codex_home)"
      else
        printf '%s/.codex/config.toml' "${HOME}"
      fi
      ;;
    opencode) printf '%s/.config/opencode/opencode.json' "${HOME}" ;;
    pi)
      printf '%s/extensions/silver-bullet-five-tool-stack/config.json' \
        "${PI_CODING_AGENT_DIR:-${HOME}/.pi/agent}"
      ;;
    *) return 1 ;;
  esac
}

# rt_codex_toml_has_server FILE NAME: FILE declares the table [mcp_servers.NAME] in any valid
# header spelling (spaces around the dots, a quoted key, a trailing comment). A sub-table such as
# [mcp_servers.NAME.env] alone does not define a server.
rt_codex_toml_has_server() {
  local path="${1:-}" name="${2:-}" esc
  esc="${name//./\\.}"
  grep -qE "^[[:space:]]*\\[[[:space:]]*mcp_servers[[:space:]]*\\.[[:space:]]*(${esc}|\"${esc}\"|'${esc}')[[:space:]]*\\][[:space:]]*(#.*)?\$" "$path" 2>/dev/null
}

rt_host_mcp_server_configured() {
  local host="${1:-${RT_HOST:-cursor}}" server="${2:-}" path
  [[ -n "$server" ]] || return 1
  path="$(rt_host_mcp_config_path "$host")" || return 1
  [[ -f "$path" && ! -L "$path" ]] || return 1
  case "$host" in
    cursor|claude)
      jq -e --arg server "$server" '.mcpServers[$server] // empty' "$path" >/dev/null 2>&1
      ;;
    opencode)
      if [[ "$server" == "context-mode" ]]; then
        jq -e '(.plugin // [] | any(.[]?; (type == "string") and (. == "context-mode" or startswith("context-mode@") or endswith("/build/adapters/opencode/plugin.js")))) or (.mcp["context-mode"] // .mcp["user-context-mode"] // empty)' \
          "$path" >/dev/null 2>&1
      else
        jq -e --arg server "$server" '.mcp[$server] // empty' "$path" >/dev/null 2>&1
      fi
      ;;
    pi)
      local key="$server"
      [[ "$key" == "context-mode" ]] && key="context_mode"
      jq -e --arg server "$key" '.servers[$server].enabled == true' "$path" >/dev/null 2>&1
      ;;
    codex)
      rt_codex_toml_has_server "$path" "$server"
      ;;
    *) return 1 ;;
  esac
}

rt_stable_id() {
  local input="${1:-}"
  [[ -n "$input" ]] || return 1
  if command -v shasum >/dev/null 2>&1; then
    printf '%s' "$input" | shasum -a 256 | awk '{print substr($1,1,16)}'
  else
    printf '%s' "$input" | sha256sum | awk '{print substr($1,1,16)}'
  fi
}

rt_git_toplevel() {
  local start="${1:-${RT_PROJECT_ROOT:-$PWD}}"
  git -C "$start" rev-parse --show-toplevel 2>/dev/null || true
}

rt_git_main_worktree_root() {
  local start="${1:-${RT_PROJECT_ROOT:-$PWD}}"
  local main_root
  main_root="$(git -C "$start" worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2; exit}')"
  if [[ -z "$main_root" ]]; then
    main_root="$(rt_git_toplevel "$start")"
  fi
  [[ -n "$main_root" ]] || return 1
  (cd "$main_root" && pwd -P)
}

rt_worktree_id() {
  local root="${1:-}"
  [[ -n "$root" ]] || root="$(rt_git_toplevel)"
  [[ -n "$root" ]] || return 1
  root="$(cd "$root" && pwd -P)"
  rt_stable_id "$root"
}

rt_project_id() {
  local root
  root="$(rt_git_main_worktree_root "${RT_PROJECT_ROOT:-}")" || return 1
  rt_stable_id "$root"
}

rt_cross_tool_batch_active() {
  [[ "${RT_CROSS_TOOL_BATCH:-}" == "1" ]]
}

rt_evidence_json_array() {
  if [[ $# -eq 0 ]]; then
    jq -n '[]'
  else
    printf '%s\n' "$@" | jq -R -s 'split("\n")|map(select(length>0))'
  fi
}

rt_emit_probe_result() {
  local tool_id="$1" consent="$2" canonical="$3" activation="$4" repairable="${5:-0}"
  shift 5 || true
  local extra="${RT_PROBE_EXTRA_JSON:-null}"
  jq -n \
    --arg id "$tool_id" --arg consent "$consent" --arg state "$canonical" \
    --arg activation "$activation" \
    --argjson repairable "$([[ "${repairable}" -eq 1 ]] && echo true || echo false)" \
    --argjson evidence "$(rt_evidence_json_array "$@")" \
    --argjson extra "$extra" \
    '({component:$id,consent:$consent,canonical_state:$state,activation_status:$activation,
      evidence:$evidence,repairable:$repairable,actions:[],failures:[]}
      + (if $extra == null then {} else $extra end))'
}

rt_derive_canonical_state() {
  # Args: unsupported disabled pending suspended failed reload_required repairable ready (0|1 each)
  local u="${1:-0}" d="${2:-0}" p="${3:-0}" s="${4:-0}" f="${5:-0}" rr="${6:-0}" rp="${7:-0}" r="${8:-0}"
  [[ "$u" -eq 1 ]] && { printf 'unsupported'; return 0; }
  [[ "$d" -eq 1 ]] && { printf 'disabled'; return 0; }
  [[ "$p" -eq 1 ]] && { printf 'pending'; return 0; }
  [[ "$s" -eq 1 ]] && { printf 'suspended'; return 0; }
  [[ "$f" -eq 1 ]] && { printf 'failed'; return 0; }
  [[ "$rr" -eq 1 ]] && { printf 'reload_required'; return 0; }
  [[ "$rp" -eq 1 ]] && { printf 'repairable'; return 0; }
  [[ "$r" -eq 1 ]] && { printf 'ready'; return 0; }
  printf 'ready'
}

rt_validate_authorization() {
  local mode="${RT_MODE:-verify}"
  local entry="${RT_ENTRY_POINT:-}"
  local scope="${RT_SCOPE:-all}"

  if [[ -n "$entry" && "$mode" != "apply" ]]; then
    RT_AUTH_ERROR="entry-point supplied with mode=${mode}; fail closed"
    return 1
  fi
  if [[ "$mode" == "apply" ]]; then
    if [[ -z "$entry" ]]; then
      RT_AUTH_ERROR="apply requires exactly one --entry-point"
      return 1
    fi
    case "$entry" in
      init|update|installer|doctor-fix) ;;
      *) RT_AUTH_ERROR="unknown entry-point: ${entry}"; return 1 ;;
    esac
    case "$entry" in
      init|update)
        case "$scope" in project|host|packages|all) ;; *)
          RT_AUTH_ERROR="${entry} scope must be project|host|packages|all"
          return 1 ;;
        esac
        ;;
      installer)
        case "$scope" in host|packages) ;;
          project|all)
            if [[ -z "${RT_PROJECT_ROOT:-}" || ! -f "${RT_PROJECT_ROOT}/.silver-bullet.json" ]]; then
              RT_AUTH_ERROR="installer scope ${scope} requires canonical project root"
              return 1
            fi
            ;;
          *)
            RT_AUTH_ERROR="installer scope must be host|packages|project|all"
            return 1
            ;;
        esac
        ;;
      doctor-fix)
        case "$scope" in project|host|packages|all) ;; *)
          RT_AUTH_ERROR="doctor-fix scope must be project|host|packages|all"
          return 1 ;;
        esac
        ;;
    esac
  fi
  # shellcheck disable=SC2034  # read by scripts/reconcile-recommended-tools.sh
  RT_AUTH_ERROR=""
  return 0
}

rt_scope_includes_component() {
  local component="${1:-}"
  local scope="${RT_SCOPE:-all}"
  case "$scope" in
    all) return 0 ;;
    project)
      case "$component" in
        graphify|agentmemory|cross_tool) return 0 ;;
        *) return 1 ;;
      esac
      ;;
    host)
      case "$component" in
        rtk|context_mode|leanctx|alumnium|cross_tool) return 0 ;;
        *) return 1 ;;
      esac
      ;;
    packages)
      case "$component" in
        graphify|agentmemory|rtk|context_mode|leanctx|alumnium|search_cli) return 0 ;;
        *) return 1 ;;
      esac
      ;;
    *) return 1 ;;
  esac
}

# rt_mutation_allowed TOOL [CAPABILITY]: may this run change the machine for TOOL? Only in apply
# mode with a valid entry point, when the user granted CAPABILITY (install or wire; default:
# either) and neither the user nor the project file turned the tool off. Package installs pass
# install, host-configuration writes pass wire.
rt_mutation_allowed() {
  local tool_id="${1:-}" cap="${2:-}"
  [[ "${RT_MODE:-verify}" == "apply" ]] || return 1
  rt_validate_authorization || return 1
  [[ "$(rt_consent_for "$tool_id")" == "enabled" ]] || return 1
  rt_is_suspended "$tool_id" && return 1
  if [[ -n "$cap" ]]; then
    sb_consent_granted "$tool_id" "$cap" || return 1
  else
    sb_consent_granted "$tool_id" install || sb_consent_granted "$tool_id" wire || return 1
  fi
  return 0
}

# rt_wire_skipped_notice TOOL: tell the user a host-config step was skipped for lack of consent.
rt_wire_skipped_notice() {
  printf 'skipped: no consent (capability wire) for %s\n' "${1:-}" >&2
}

rt_any_five_tool_mutation_allowed() {
  local tool
  for tool in graphify agentmemory rtk context_mode leanctx; do
    rt_mutation_allowed "$tool" && return 0
  done
  return 1
}

rt_atomic_write_json() {
  local dest="${1:-}" content="${2:-}"
  [[ -n "$dest" && -n "$content" ]] || return 1
  if [[ -L "$dest" ]]; then
    return 1
  fi
  local dir tmp
  dir="$(dirname "$dest")"
  mkdir -p "$dir" 2>/dev/null || true
  tmp="$(mktemp "${dir}/.rt-atomic.XXXXXX")"
  printf '%s\n' "$content" >"$tmp"
  mv -f "$tmp" "$dest"
}

# rt_lock_is_stale LOCK: the lock directory names a process that is gone or, with no pid
# recorded, was created more than two minutes ago.
rt_lock_is_stale() {
  local lock_path="${1:-}" holder=""
  [[ -d "$lock_path" ]] || return 1
  if [[ -f "${lock_path}/pid" ]]; then
    if IFS= read -r holder <"${lock_path}/pid"; then :; fi
    if [[ "$holder" =~ ^[0-9]{1,9}$ ]]; then
      kill -0 "$holder" 2>/dev/null && return 1
      return 0
    fi
  fi
  [[ -n "$(find "$lock_path" -maxdepth 0 -mmin +2 2>/dev/null)" ]]
}

# rt_reclaim_stale_lock LOCK: remove a lock whose owner died. Waiters that all judged the same lock
# stale must not each delete it (the second delete would remove the lock the first waiter just took),
# so removal is serialized by a second mkdir lock and the staleness is checked again under it.
rt_reclaim_stale_lock() {
  local lock_path="${1:-}" guard="${1:-}.reclaim"
  if mkdir "$guard" 2>/dev/null; then
    if rt_lock_is_stale "$lock_path"; then
      rm -rf -- "$lock_path" 2>/dev/null || { rmdir "$guard" 2>/dev/null; return 1; }
    fi
    rmdir "$guard" 2>/dev/null || true
  elif [[ -n "$(find "$guard" -maxdepth 0 -mmin +2 2>/dev/null)" ]]; then
    # a reclaimer that died holding the guard: clear it so the next pass can proceed
    rmdir "$guard" 2>/dev/null || true
  fi
  return 0
}

# rt_with_lock LOCK TIMEOUT COMMAND...: run COMMAND holding the mkdir lock. The lock is released
# when COMMAND returns (no RETURN trap: it would outlive this call and fire again when the
# caller returns, deleting a lock somebody else holds), and a lock whose owner died is recovered.
rt_with_lock() {
  local lock_path="${1:-}" timeout_s="${2:-30}" rc=0 start now
  shift 2
  [[ -n "$lock_path" ]] || return 1
  # A parent that cannot be created is a permanent error, not contention: fail at once.
  mkdir -p "$(dirname "$lock_path")" 2>/dev/null || return 1
  start="$(date +%s)"
  while ! mkdir "$lock_path" 2>/dev/null; do
    if rt_lock_is_stale "$lock_path"; then
      rt_reclaim_stale_lock "$lock_path" || return 1
      # Retry at once only when the stale lock is gone; otherwise another waiter is reclaiming it,
      # so fall through to the timeout check and the sleep.
      [[ -d "$lock_path" ]] || continue
    fi
    now="$(date +%s)"
    if (( now - start > timeout_s )); then
      return 1
    fi
    sleep 0.1
  done
  if printf '%s\n' "$$" >"${lock_path}/pid" 2>/dev/null; then :; fi
  "$@" || rc=$?
  if rm -rf -- "$lock_path" 2>/dev/null; then :; fi
  return "$rc"
}
