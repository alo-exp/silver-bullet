#!/usr/bin/env bash
# sb-doctor module — auto-split from sb-doctor.sh
DOCTOR_FIX="${SB_DOCTOR_FIX:-0}"
DOCTOR_FIX_APPLIED=0
PROJ_ROOT="${PWD}"
FORMAT="${SB_DOCTOR_FORMAT:-text}"
PASS=0
FAIL=0
WARN=0
REPORT_LINES=()
FAILED_CHECK_IDS=()

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --fix) DOCTOR_FIX=1; shift ;;
      -h|--help) sed -n '1,8p' "${REPO_ROOT}/scripts/sb-doctor.sh"; exit 0 ;;
      *) PROJ_ROOT="$1"; shift ;;
    esac
  done
}

record() {
  local level="$1" id="$2" detail="$3"
  local line=""
  case "$level" in
    pass)
      line="PASS: ${id} — ${detail}"
      ((PASS++)) || true
      ;;
    warn)
      line="WARN: ${id} — ${detail}"
      ((WARN++)) || true
      ;;
    fail)
      line="FAIL: ${id} — ${detail}"
      ((FAIL++)) || true
      FAILED_CHECK_IDS+=("$id")
      ;;
  esac
  REPORT_LINES+=("$line")
  [[ "$FORMAT" == "json" ]] || printf '%s\n' "$line"
}

version_to_int() {
  local v="${1%%-*}"
  local maj min patch
  IFS='.' read -r maj min patch <<<"$v"
  maj="${maj:-0}"; min="${min:-0}"; patch="${patch:-0}"
  printf '%d' $((10#$maj * 1000000 + 10#$min * 1000 + 10#$patch))
}

version_lt() {
  [[ "$(version_to_int "$1")" -lt "$(version_to_int "$2")" ]]
}

source_runtime_paths() {
  if [[ -f "${REPO_ROOT}/hooks/lib/runtime-paths.sh" ]]; then
    # shellcheck source=../hooks/lib/runtime-paths.sh
    source "${REPO_ROOT}/hooks/lib/runtime-paths.sh"
    return 0
  fi
  export SILVER_BULLET_RUNTIME="${SILVER_BULLET_RUNTIME:-claude}"
  SB_RUNTIME_NAME="$SILVER_BULLET_RUNTIME"
  SB_RUNTIME_HOME_ROOT="${HOME}/.${SILVER_BULLET_RUNTIME}"
  SB_RUNTIME_STATE_DIR="$HOME/.codex/.silver-bullet"
  SB_RUNTIME_PLUGIN_CACHE_ROOT="$HOME/.codex/plugins/cache"
  return 0
}

plugin_registry_path() {
  printf '%s/plugins/installed_plugins.json' "$HOME/.codex"
}

plugin_cache_root() {
  case "${SB_RUNTIME_NAME:-${SILVER_BULLET_RUNTIME:-claude}}" in
    codex) printf '%s/alo-labs-codex/silver-bullet' "$HOME/.codex/plugins/cache" ;;
    *) printf '%s/alo-labs/silver-bullet' "$HOME/.codex/plugins/cache" ;;
  esac
}

# Claude v2 registry stores plugin entries as arrays; Cursor/Codex may use objects.
resolve_registry_plugin_field() {
  local reg="$1" plugin_id="$2" field="$3"
  jq -r --arg id "$plugin_id" --arg f "$field" '
    .plugins[$id] as $entry
    | if $entry == null then empty
      elif ($entry | type) == "array" then ($entry[0][$f] // empty)
      else ($entry[$f] // empty)
      end
  ' "$reg" 2>/dev/null || true
}

resolve_template_config_version() {
  local template="${REPO_ROOT}/templates/silver-bullet.config.json.default"
  if [[ -f "$PROJ_ROOT/templates/silver-bullet.config.json.default" ]]; then
    template="${PROJ_ROOT}/templates/silver-bullet.config.json.default"
  fi
  if [[ -f "$template" ]]; then
    jq -r '.config_version // .version // "0.0.0"' "$template"
  else
    jq -r '.version // "0.0.0"' "${REPO_ROOT}/package.json" 2>/dev/null || echo "0.0.0"
  fi
}

resolve_hook_path() {
  local dir="$1" base="$2"
  if [[ -f "${dir}/${base}" ]]; then
    printf '%s' "${dir}/${base}"
    return 0
  fi
  if [[ -f "${dir}/${base}.sh" ]]; then
    printf '%s' "${dir}/${base}.sh"
    return 0
  fi
  return 1
}

run_hook_smoke() {
  local hook_path="$1" event="$2"
  local payload
  payload="$(jq -n --arg e "$event" '{hook_event_name:$e, prompt:"sb-doctor smoke"}')"
  if ( cd "$PROJ_ROOT" && printf '%s' "$payload" | bash "$hook_path" >/dev/null 2>&1 ); then
    return 0
  fi
  return 1
}
