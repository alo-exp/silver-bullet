# shellcheck shell=bash
# Session-scoped active delegation state for AF-AGENT-DELEGATE.

sb_agent_delegation_state_file() {
  printf '%s/agent-delegation-active.json' "${SB_RUNTIME_STATE_DIR:-/tmp}"
}

sb_agent_delegation_guard_disabled() {
  [[ "${SB_AGENT_DELEGATE_GUARD:-1}" == "0" ]]
}

# Default-on (stage 5): unset → V2 enabled. Explicit SB_AGENT_DELEGATE_V2=0 rolls back worker path.
sb_agent_delegation_v2_enabled() {
  [[ "${SB_AGENT_DELEGATE_V2:-1}" != "0" ]]
}

sb_agent_delegation_is_active() {
  sb_agent_delegation_guard_disabled && return 1
  local file
  file="$(sb_agent_delegation_state_file)"
  [[ -f "$file" ]] || return 1
  if command -v jq >/dev/null 2>&1; then
    [[ "$(jq -r '.active // false' "$file" 2>/dev/null)" == "true" ]]
    return $?
  fi
  grep -q '"active"[[:space:]]*:[[:space:]]*true' "$file" 2>/dev/null
}

sb_agent_delegation_read_field() {
  local field="$1" default="${2:-}"
  local file
  file="$(sb_agent_delegation_state_file)"
  [[ -f "$file" ]] || { printf '%s' "$default"; return 0; }
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg f "$field" --arg d "$default" '.[$f] // $d' "$file" 2>/dev/null || printf '%s' "$default"
    return 0
  fi
  printf '%s' "$default"
}

sb_agent_delegation_activate() {
  local host="$1" task_id="$2" work_dir="$3" ownership_scope_json="${4:-[]}" log_path="${5:-}"
  local file start_time
  file="$(sb_agent_delegation_state_file)"
  start_time="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  mkdir -p "$(dirname "$file")"
  if command -v jq >/dev/null 2>&1; then
    jq -n \
      --arg host "$host" \
      --arg task_id "$task_id" \
      --arg work_dir "$work_dir" \
      --arg log_path "$log_path" \
      --arg start_time "$start_time" \
      --argjson ownership "$ownership_scope_json" \
      '{active:true,host:$host,task_id:$task_id,work_dir:$work_dir,ownership_scope:$ownership,log_path:$log_path,start_time:$start_time,failure_class:""}' \
      >"$file"
  else
    printf '{"active":true,"host":"%s","task_id":"%s","work_dir":"%s","start_time":"%s"}\n' \
      "$host" "$task_id" "$work_dir" "$start_time" >"$file"
  fi
}

sb_agent_delegation_deactivate() {
  local file
  file="$(sb_agent_delegation_state_file)"
  rm -f -- "$file" 2>/dev/null || true
}

sb_agent_delegation_normalize_path() {
  local path="$1" repo_root="${2:-$PWD}"
  [[ -n "$path" ]] || return 1
  if [[ "$path" != /* ]]; then
    path="${repo_root%/}/$path"
  fi
  path="$(cd "$(dirname "$path")" 2>/dev/null && pwd)/$(basename "$path")" || return 1
  if [[ "$path" == *".."* ]]; then
    return 1
  fi
  printf '%s' "$path"
}

sb_agent_delegation_path_in_scope() {
  local target="$1" repo_root="${2:-$PWD}"
  sb_agent_delegation_is_active || return 1
  local file scopes scope norm_target
  file="$(sb_agent_delegation_state_file)"
  norm_target="$(sb_agent_delegation_normalize_path "$target" "$repo_root" 2>/dev/null || true)"
  [[ -n "$norm_target" ]] || return 1

  local task_id host
  task_id="$(sb_agent_delegation_read_field task_id "")"
  host="$(sb_agent_delegation_read_field host "")"

  # Always allow evidence dir and harness repair paths for parent.
  case "$norm_target" in
    "${repo_root%/}"/.planning/agent-"${host}"/"${task_id}"/*) return 1 ;;
    "${repo_root%/}"/hooks/*|"${repo_root%/}"/scripts/*) return 1 ;;
  esac

  if command -v jq >/dev/null 2>&1 && [[ -f "$file" ]]; then
    while IFS= read -r scope; do
      [[ -n "$scope" ]] || continue
      scope="$(sb_agent_delegation_normalize_path "$scope" "$repo_root" 2>/dev/null || true)"
      [[ -n "$scope" ]] || continue
      case "$norm_target" in
        "$scope"|"$scope"/*) return 0 ;;
      esac
    done < <(jq -r '.ownership_scope[]? // empty' "$file" 2>/dev/null)
  else
    local work_dir
    work_dir="$(sb_agent_delegation_read_field work_dir "$repo_root")"
    case "$norm_target" in
      "${work_dir%/}"|"${work_dir%/}"/*) return 0 ;;
    esac
  fi
  return 1
}

sb_agent_delegation_parent_host_tier() {
  case "${SILVER_BULLET_RUNTIME:-claude}" in
    cursor) printf 'advise' ;;
    *) printf 'block' ;;
  esac
}
