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

# A task id is a file-name component under .planning/agent-<host>/: keep letters, digits, dot,
# underscore and hyphen, at most 64 characters (R4-32). Anything else becomes "_".
sb_agent_delegation_clean_task_id() {
  local id="$1"
  id="$(printf '%s' "$id" | LC_ALL=C tr -c 'A-Za-z0-9._-' '_' | cut -c1-64)"
  [[ -n "$id" ]] || id="task"
  printf '%s' "$id"
}

# Write the state atomically (temp file in the same directory, then rename) with jq-built JSON.
# Refuses a symlinked state file or directory. jq is a required prerequisite: without it (or with an
# invalid ownership-scope JSON) activation fails (non-zero) instead of writing a hand-built file.
sb_agent_delegation_activate() {
  local host="$1" task_id="$2" work_dir="$3" ownership_scope_json="${4:-[]}" log_path="${5:-}"
  local file dir start_time tmp
  command -v jq >/dev/null 2>&1 || return 1
  task_id="$(sb_agent_delegation_clean_task_id "$task_id")"
  file="$(sb_agent_delegation_state_file)"
  dir="$(dirname "$file")"
  start_time="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  mkdir -p "$dir"
  if [[ -L "$file" || -L "$dir" ]]; then
    printf 'ERROR: refusing to write delegation state through a symlink: %s\n' "$file" >&2
    return 1
  fi
  tmp="$(mktemp "${dir}/.agent-delegation-active.XXXXXX")" || return 1
  if jq -n \
    --arg host "$host" \
    --arg task_id "$task_id" \
    --arg work_dir "$work_dir" \
    --arg log_path "$log_path" \
    --arg start_time "$start_time" \
    --argjson ownership "$ownership_scope_json" \
    '{active:true,host:$host,task_id:$task_id,work_dir:$work_dir,ownership_scope:$ownership,log_path:$log_path,start_time:$start_time,failure_class:""}' \
    >"$tmp" 2>/dev/null && mv -f -- "$tmp" "$file"; then
    return 0
  fi
  rm -f -- "$tmp"
  return 1
}

sb_agent_delegation_deactivate() {
  local file
  file="$(sb_agent_delegation_state_file)"
  rm -f -- "$file" 2>/dev/null || true
}

sb_agent_delegation_normalize_path() {
  local path="$1" repo_root="${2:-$PWD}" depth="${3:-0}"
  [[ -n "$path" ]] || return 1
  # Symlink chains/loops: give up (callers treat failure as in scope).
  [[ "$depth" -lt 20 ]] || return 1
  if [[ "$path" != /* ]]; then
    path="${repo_root%/}/$path"
  fi
  # Walk the components left to right. While every component exists, resolve it physically
  # (symlinks followed, so the real location is compared); once one does not exist, the rest is
  # applied lexically ("." dropped, ".." popping one component, never above /).
  local -a parts=() tail=()
  local part cur="/" next link
  IFS=/ read -ra parts <<<"$path"
  for part in "${parts[@]}"; do
    case "$part" in
      ""|.) continue ;;
      ..)
        if [[ ${#tail[@]} -gt 0 ]]; then
          unset 'tail[${#tail[@]}-1]'
        else
          cur="$(dirname "$cur")"
        fi
        continue
        ;;
    esac
    if [[ ${#tail[@]} -eq 0 && -d "${cur%/}/$part" ]]; then
      next="$(cd "${cur%/}/$part" 2>/dev/null && pwd -P)" || return 1
      cur="$next"
    elif [[ ${#tail[@]} -eq 0 && -L "${cur%/}/$part" ]]; then
      # A symlink that is not a directory (a file link, or dangling): follow it once.
      link="$(readlink "${cur%/}/$part" 2>/dev/null || true)"
      [[ -n "$link" ]] || return 1
      [[ "$link" == /* ]] || link="${cur%/}/$link"
      sb_agent_delegation_normalize_path "$link" "$cur" "$((depth + 1))"
      return $?
    else
      tail+=("$part")
    fi
  done
  path="${cur%/}"
  if [[ ${#tail[@]} -gt 0 ]]; then
    path="${path}/$(IFS=/; printf '%s' "${tail[*]}")"
  fi
  [[ -n "$path" ]] || path="/"
  printf '%s' "$path"
}

sb_agent_delegation_path_in_scope() {
  local target="$1" repo_root="${2:-$PWD}"
  sb_agent_delegation_is_active || return 1
  local file scope norm_target
  repo_root="$(sb_agent_delegation_normalize_path "$repo_root" "$PWD" 2>/dev/null || printf '%s' "$repo_root")"
  file="$(sb_agent_delegation_state_file)"
  norm_target="$(sb_agent_delegation_normalize_path "$target" "$repo_root" 2>/dev/null || true)"
  # Fail closed: a target that cannot be normalized while a delegation is active is treated as in scope.
  [[ -n "$norm_target" ]] || return 0

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
