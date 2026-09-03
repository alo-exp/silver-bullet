# shellcheck shell=bash
# Shared reconciliation helpers — consent, state precedence, authorization.
# Sourced only by scripts/reconcile-recommended-tools.sh and sibling libs (not executable).

RT_RECONCILER_VERSION="1.0.0"
RT_RESULT_SCHEMA_VERSION="1.0.0"

RT_COMPONENT_IDS=(graphify agentmemory rtk context_mode leanctx alumnium search_cli cross_tool)
RT_FIVE_TOOL_ROUTES=(
  sb_wire:leanctx sb_read:leanctx sb_grep:context_mode sb_shell:rtk
  sb_slice:context_mode sb_webfetch:context_mode sb_graph:graphify
  sb_remember:agentmemory sb_pathjail:leanctx sb_injection:leanctx
)
RT_VALID_HOSTS=(cursor claude codex opencode goose hermes)
RT_VALID_MODES=(verify plan apply)
RT_VALID_SCOPES=(project host packages all)
RT_VALID_ENTRY_POINTS=(init update installer doctor-fix)
RT_STATE_PRECEDENCE=(unsupported disabled pending suspended failed reload_required repairable ready)

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
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

rt_consent_for() {
  local tool_id="${1:-}"
  local cfg
  cfg="$(rt_project_config)" || { printf 'pending'; return 0; }
  sb_recommended_tool_consent "$cfg" "$tool_id"
}

rt_is_suspended() {
  local tool_id="${1:-}"
  local cfg
  cfg="$(rt_project_config)" || return 1
  sb_recommended_tool_enforcement_suspended "$cfg" "$tool_id"
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
    cursor) return 0 ;;
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

rt_json_escape() {
  local s="${1:-}"
  printf '%s' "$s" | jq -Rs '.'
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

rt_mutation_allowed() {
  local tool_id="${1:-}"
  [[ "${RT_MODE:-verify}" == "apply" ]] || return 1
  rt_validate_authorization || return 1
  [[ "$(rt_consent_for "$tool_id")" == "enabled" ]] || return 1
  rt_is_suspended "$tool_id" && return 1
  return 0
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

rt_with_lock() {
  local lock_path="${1:-}" timeout_s="${2:-30}"
  shift 2
  [[ -n "$lock_path" ]] || return 1
  mkdir -p "$(dirname "$lock_path")" 2>/dev/null || true
  local start now
  start="$(date +%s)"
  while ! mkdir "$lock_path" 2>/dev/null; do
    now="$(date +%s)"
    if (( now - start > timeout_s )); then
      return 1
    fi
    sleep 0.1
  done
  # shellcheck disable=SC2064
  trap "rm -rf -- $(printf '%q' "$lock_path") 2>/dev/null || true" RETURN
  "$@"
}
