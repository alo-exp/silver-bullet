# shellcheck shell=bash
# Schema-v1 heartbeat contract for SB bridge arbitration.

RT_HEARTBEAT_SCHEMA="v1"
RT_HEARTBEAT_TTL_SECONDS=300
RT_HEARTBEAT_CADENCE_SECONDS=60
RT_HEARTBEAT_CLEANUP_AGE_SECONDS=86400

# shellcheck source=paths.sh
source "$(dirname "${BASH_SOURCE[0]}")/paths.sh"
# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
rt_init_paths

rt_current_session_id() {
  local sid="${SILVER_BULLET_SESSION_ID:-${CURSOR_SESSION_ID:-}}"
  if [[ -z "$sid" && -f "${SB_RUNTIME_STATE_DIR:-}/session-start-time" ]]; then
    sid="sb-$(cat "${SB_RUNTIME_STATE_DIR}/session-start-time" 2>/dev/null || true)"
  fi
  [[ -n "$sid" ]] || sid="unknown-$(date +%s)"
  rt_sanitize_session_id "$sid"
}

rt_heartbeat_consent_summary() {
  local cfg tool consent
  cfg="$(rt_project_config)" || { printf '{}'; return 0; }
  local -a parts=()
  for tool in graphify agentmemory rtk context_mode leanctx; do
    consent="$(sb_recommended_tool_consent "$cfg" "$tool")"
    parts+=("\"${tool}\":\"${consent}\"")
  done
  printf '{%s}' "$(IFS=,; printf '%s' "${parts[*]}")"
}

rt_heartbeat_build_json() {
  local project_root="${1:-${RT_PROJECT_ROOT:-}}"
  local host="${2:-${RT_HOST:-cursor}}"
  local session_id
  session_id="$(rt_current_session_id)"
  local project_id worktree_id now expires
  project_id="$(rt_project_id)"
  worktree_id="$(rt_worktree_id "$project_root")"
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  expires="$(date -u -v+${RT_HEARTBEAT_TTL_SECONDS}S +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
    || date -u -d "+${RT_HEARTBEAT_TTL_SECONDS} seconds" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
    || date -u +%Y-%m-%dT%H:%M:%SZ)"
  local cfg sb_initiated consent_json suspended=false
  # The explicit project root is authoritative during reconciler/repair
  # calls; relying only on RT_PROJECT_ROOT made a heartbeat written by a
  # host wrapper lose sb_initiated=true and immediately fail validation.
  if [[ -n "$project_root" && -f "${project_root%/}/.silver-bullet.json" ]]; then
    cfg="${project_root%/}/.silver-bullet.json"
  else
    cfg="$(rt_project_config)" || true
  fi
  if [[ -n "$cfg" ]]; then
    sb_initiated="$(jq -r '.sb_initiated // false' "$cfg" 2>/dev/null || echo false)"
    for tool in graphify agentmemory rtk context_mode leanctx; do
      if sb_recommended_tool_enforcement_suspended "$cfg" "$tool" 2>/dev/null; then
        suspended=true
        break
      fi
    done
  else
    sb_initiated=false
  fi
  consent_json="$(rt_heartbeat_consent_summary)"
  jq -n \
    --arg schema "$RT_HEARTBEAT_SCHEMA" \
    --arg host "$host" \
    --arg project_root "$project_root" \
    --arg worktree_root "$project_root" \
    --arg project_id "${project_id:-unknown}" \
    --arg worktree_id "${worktree_id:-unknown}" \
    --arg session_id "$session_id" \
    --arg bridge_version "$RT_RECONCILER_VERSION" \
    --argjson sb_initiated "${sb_initiated:-false}" \
    --argjson consent "$consent_json" \
    --argjson suspended "$suspended" \
    --arg written_at "$now" \
    --arg expires_at "$expires" \
    '{
      schema: $schema,
      host: $host,
      project_root: $project_root,
      worktree_root: $worktree_root,
      project_id: $project_id,
      worktree_id: $worktree_id,
      session_id: $session_id,
      bridge_version: $bridge_version,
      sb_initiated: $sb_initiated,
      consent: $consent,
      suspended: $suspended,
      written_at: $written_at,
      expires_at: $expires_at
    }'
}

rt_heartbeat_last_write_epoch() {
  local path="${1:-}"
  [[ -f "$path" && ! -L "$path" ]] || return 1
  jq -r '.written_at // ""' "$path" 2>/dev/null | {
    read -r ts
    [[ -n "$ts" ]] || return 1
    date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$ts" +%s 2>/dev/null \
      || date -u -d "$ts" +%s 2>/dev/null \
      || return 1
  }
}

rt_heartbeat_cadence_due() {
  local path="${1:-}"
  [[ -f "$path" ]] || return 0
  local last now
  last="$(rt_heartbeat_last_write_epoch "$path" 2>/dev/null || echo 0)"
  now="$(date +%s)"
  (( now - last >= RT_HEARTBEAT_CADENCE_SECONDS ))
}

rt_heartbeat_write() {
  local project_root="${1:-${RT_PROJECT_ROOT:-}}"
  local host="${2:-${RT_HOST:-cursor}}"
  local session_id project_id worktree_id path lock_dir payload
  session_id="$(rt_current_session_id)"
  project_id="$(rt_project_id)"
  worktree_id="$(rt_worktree_id "$project_root")"
  path="$(rt_heartbeat_path "$project_id" "$worktree_id" "$session_id")"
  rt_heartbeat_cadence_due "$path" || return 0
  payload="$(rt_heartbeat_build_json "$project_root" "$host")"
  lock_dir="$(dirname "$path")/.lock"
  rt_with_lock "$lock_dir" 10 rt_atomic_write_json "$path" "$payload"
}

rt_heartbeat_is_valid() {
  local path="${1:-}" expected_host="${2:-}" expected_project="${3:-}" expected_worktree="${4:-}"
  [[ -f "$path" && ! -L "$path" ]] || return 1
  jq -e --arg host "$expected_host" --arg proj "$expected_project" --arg wt "$expected_worktree" '
    .schema == "v1"
    and (.host == $host or $host == "")
    and (.project_root == $proj or $proj == "")
    and (.worktree_root == $wt or $wt == "")
    and (.session_id | type == "string" and length > 0)
    and (.sb_initiated == true)
    and (.suspended == false)
    and (.expires_at | type == "string")
  ' "$path" >/dev/null 2>&1 || return 1
  local expires now
  expires="$(jq -r '.expires_at' "$path" 2>/dev/null)"
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  [[ -n "$expires" && "$expires" > "$now" ]] || return 1
  return 0
}

rt_heartbeat_cleanup_expired() {
  local root="${1:-$(rt_heartbeat_root)}"
  [[ -d "$root" ]] || return 0
  local now cutoff f mtime
  now="$(date +%s)"
  cutoff=$((now - RT_HEARTBEAT_CLEANUP_AGE_SECONDS))
  find "$root" -name '*.json' -type f 2>/dev/null | while read -r f; do
    mtime="$(stat -f '%m' "$f" 2>/dev/null || stat -c '%Y' "$f" 2>/dev/null || echo 0)"
    if [[ "$mtime" -lt "$cutoff" ]]; then
      rm -f -- "$f" 2>/dev/null || true
    fi
  done
}
