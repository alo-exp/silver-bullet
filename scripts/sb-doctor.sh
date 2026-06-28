#!/usr/bin/env bash
# sb-doctor.sh — Silver Bullet install + project activation audit (silver:doctor)
# Exit 0 only when zero FAIL checks (WARN allowed).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJ_ROOT="${1:-$PWD}"
FORMAT="${SB_DOCTOR_FORMAT:-text}"
PASS=0
FAIL=0
WARN=0
REPORT_LINES=()

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
  SB_RUNTIME_STATE_DIR="${SB_RUNTIME_HOME_ROOT}/.silver-bullet"
  SB_RUNTIME_PLUGIN_CACHE_ROOT="${SB_RUNTIME_HOME_ROOT}/plugins/cache"
  return 0
}

plugin_registry_path() {
  printf '%s/plugins/installed_plugins.json' "${SB_RUNTIME_HOME_ROOT}"
}

plugin_cache_root() {
  printf '%s/alo-labs/silver-bullet' "${SB_RUNTIME_PLUGIN_CACHE_ROOT}"
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

main() {
  local runtime template_ver proj_ver plugin_ver install_path cache_root current_link
  local hooks_manifest sb_config

  source_runtime_paths
  runtime="${SB_RUNTIME_NAME:-${SILVER_BULLET_RUNTIME:-claude}}"
  template_ver="$(resolve_template_config_version)"
  sb_config="${PROJ_ROOT}/.silver-bullet.json"
  cache_root="$(plugin_cache_root)"

  # D1 — jq
  if command -v jq >/dev/null 2>&1; then
    record pass D1 "jq on PATH ($(jq --version 2>/dev/null | head -1))"
  else
    record fail D1 "jq missing — SB hooks fail-open without jq"
  fi

  # D2 — plugin registry
  local reg
  reg="$(plugin_registry_path)"
  if [[ -f "$reg" ]]; then
    plugin_ver="$(resolve_registry_plugin_field "$reg" "silver-bullet@alo-labs" "version")"
    install_path="$(resolve_registry_plugin_field "$reg" "silver-bullet@alo-labs" "installPath")"
    if [[ -z "$plugin_ver" || "$plugin_ver" == "null" ]]; then
      for _fallback_id in "silver-bullet@alo-labs-codex" "silver-bullet@silver-bullet"; do
        plugin_ver="$(resolve_registry_plugin_field "$reg" "$_fallback_id" "version")"
        install_path="$(resolve_registry_plugin_field "$reg" "$_fallback_id" "installPath")"
        [[ -n "$plugin_ver" && "$plugin_ver" != "null" ]] && break
      done
    fi
    if [[ -n "$plugin_ver" && "$plugin_ver" != "null" ]]; then
      if version_lt "$plugin_ver" "$template_ver"; then
        record fail D2 "plugin version ${plugin_ver} < template config_version ${template_ver}"
      else
        record pass D2 "silver-bullet@alo-labs version ${plugin_ver} (install: ${install_path:-unknown}, registry: ${reg})"
      fi
    else
      record fail D2 "no silver-bullet plugin entry in ${reg}"
    fi
  else
    record fail D2 "plugin registry missing: ${reg}"
  fi

  # D3 — plugin cache
  current_link="${cache_root}/current"
  if [[ -L "$current_link" && -d "$(readlink -f "$current_link" 2>/dev/null || true)" ]]; then
    local resolved
    resolved="$(readlink -f "$current_link")"
    if [[ -f "${resolved}/hooks/hooks.json" ]]; then
      record pass D3 "current symlink → ${resolved}"
    else
      record fail D3 "hooks/hooks.json missing under ${resolved}"
    fi
  else
    record fail D3 "broken or missing current symlink at ${current_link}"
  fi

  # D4 — host hooks manifest
  case "$runtime" in
    cursor)
      if [[ -f "${HOME}/.cursor/hooks.json" ]] && grep -q 'silver-bullet' "${HOME}/.cursor/hooks.json" 2>/dev/null; then
        if grep -q 'cursor-hook-bridge.sh' "${HOME}/.cursor/hooks.json" 2>/dev/null; then
          record pass D4 "Cursor hooks.json references silver-bullet via cursor-hook-bridge.sh"
        else
          record fail D4 "Cursor hooks.json has silver-bullet entries without cursor-hook-bridge.sh"
        fi
      else
        record fail D4 "Cursor hooks.json missing SB hook entries"
      fi
      ;;
    codex)
      if [[ -f "${HOME}/.codex/config.toml" ]] && grep -q 'silver-bullet' "${HOME}/.codex/config.toml" 2>/dev/null; then
        record pass D4 "Codex config.toml references silver-bullet hooks"
      else
        record fail D4 "Codex config.toml missing SB hook entries"
      fi
      ;;
    *)
      if [[ -f "${HOME}/.claude/settings.json" ]] && grep -q 'silver-bullet' "${HOME}/.claude/settings.json" 2>/dev/null; then
        record pass D4 "Claude settings.json references silver-bullet hooks"
      else
        record fail D4 "Claude settings.json missing SB hook entries"
      fi
      ;;
  esac

  # D5 — project activation
  if [[ -f "$sb_config" && -f "${PROJ_ROOT}/silver-bullet.md" ]]; then
    if jq -e '.sb_initiated == true' "$sb_config" >/dev/null 2>&1; then
      record pass D5 "project activated (.silver-bullet.json + silver-bullet.md, sb_initiated: true)"
    else
      record fail D5 "sb_initiated is not true in ${sb_config}"
    fi
  else
    record fail D5 "missing .silver-bullet.json or silver-bullet.md under ${PROJ_ROOT}"
  fi

  # D6 — config freshness
  if [[ -f "$sb_config" ]]; then
    proj_ver="$(jq -r '.config_version // .version // "0.0.0"' "$sb_config")"
    if version_lt "$proj_ver" "$template_ver"; then
      record fail D6 "project config_version ${proj_ver} < template ${template_ver}"
    else
      record pass D6 "config_version ${proj_ver} (template ${template_ver})"
    fi
  else
    record fail D6 "no .silver-bullet.json to compare"
  fi

  # D7 — template parity
  local parity_script="${REPO_ROOT}/tests/scripts/test-silver-bullet-template-parity.sh"
  if [[ -x "$parity_script" ]] || [[ -f "$parity_script" ]]; then
    if ( cd "$REPO_ROOT" && bash "$parity_script" >/dev/null 2>&1 ); then
      record pass D7 "silver-bullet.md template parity test passed"
    else
      record fail D7 "template parity test failed — run: bash tests/scripts/test-silver-bullet-template-parity.sh"
    fi
  else
    record warn D7 "parity test script not found; skipped"
  fi

  # D8 — Cursor orchestrator rule (Cursor host only; not required on Claude/Codex)
  if [[ "$runtime" == "cursor" ]]; then
    if [[ -f "${PROJ_ROOT}/.cursor/rules/silver-orchestrator.mdc" ]]; then
      record pass D8 ".cursor/rules/silver-orchestrator.mdc present"
    else
      record fail D8 ".cursor/rules/silver-orchestrator.mdc missing (run silver:migrate or silver:init on Cursor)"
    fi
  else
    record pass D8 "orchestrator rule N/A (host=${runtime})"
  fi

  # D9 — workflow tracker
  if [[ -x "${PROJ_ROOT}/scripts/workflows.sh" && -d "${PROJ_ROOT}/docs/workflows" ]]; then
    record pass D9 "scripts/workflows.sh executable; docs/workflows/ present"
  else
    record fail D9 "workflow tracker incomplete (scripts/workflows.sh or docs/workflows/)"
  fi

  # D10 — recommended tools (when opted in)
  if [[ -f "$sb_config" ]] && [[ -f "${REPO_ROOT}/hooks/lib/recommended-tools.sh" ]]; then
    # shellcheck source=../hooks/lib/recommended-tools.sh
    source "${REPO_ROOT}/hooks/lib/recommended-tools.sh"
    local tool suspended consent
    for tool in graphify agentmemory rtk context_mode alumnium; do
      if declare -f sb_recommended_tool_enabled_by_user >/dev/null 2>&1; then
        if sb_recommended_tool_enabled_by_user "$sb_config" "$tool" 2>/dev/null; then
          consent="enabled"
          suspended="false"
          if declare -f sb_recommended_tool_enforcement_suspended >/dev/null 2>&1; then
            if sb_recommended_tool_enforcement_suspended "$sb_config" "$tool"; then
              suspended="true"
            fi
          fi
          if [[ "$suspended" == "true" ]]; then
            record warn D10 "${tool} ${consent} but enforcement suspended"
          else
            record pass D10 "${tool} ${consent} (enforcement active)"
          fi
        fi
      fi
    done
    if ! grep -q 'D10' <(printf '%s\n' "${REPORT_LINES[@]}"); then
      record pass D10 "no recommended_tools enabled_by_user (opt-in checks skipped)"
    fi
  else
    record pass D10 "recommended tools config unavailable; skipped"
  fi

  # D11 — hook smoke
  local hook_root hook_name
  hook_root="$(readlink -f "${cache_root}/current" 2>/dev/null || echo "${REPO_ROOT}")"
  hooks_manifest="${hook_root}/hooks"
  for hook_name in session-start outcomes-check stop-check; do
    local hook_path smoke_event="Stop"
    case "$hook_name" in
      session-start) smoke_event="SessionStart" ;;
      outcomes-check) smoke_event="UserPromptSubmit" ;;
    esac
    if hook_path="$(resolve_hook_path "$hooks_manifest" "$hook_name")"; then
      if run_hook_smoke "$hook_path" "$smoke_event"; then
        record pass D11 "${hook_name} smoke exit 0"
      else
        record fail D11 "${hook_name} smoke failed"
      fi
    else
      record fail D11 "${hook_name} not found under ${hooks_manifest}"
    fi
  done

  # D12 — state paths writable
  export SILVER_BULLET_RUNTIME="$runtime"
  if [[ -f "${REPO_ROOT}/hooks/lib/runtime-paths.sh" ]]; then
    # shellcheck source=../hooks/lib/runtime-paths.sh
    source "${REPO_ROOT}/hooks/lib/runtime-paths.sh"
    mkdir -p "${SB_RUNTIME_STATE_DIR}"
    if [[ -w "${SB_RUNTIME_STATE_DIR}" ]]; then
      record pass D12 "${SB_RUNTIME_STATE_DIR} writable"
    else
      record fail D12 "${SB_RUNTIME_STATE_DIR} not writable"
    fi
  else
    local fallback="${HOME}/.silver-bullet"
    mkdir -p "$fallback"
    if [[ -w "$fallback" ]]; then
      record pass D12 "${fallback} writable (fallback)"
    else
      record fail D12 "state dir not writable"
    fi
  fi

  # D13 — cross-host plugin path contamination (host-scoped)
  local skill_root hooks_manifest_path agent_bundle_dir
  skill_root="$(readlink -f "${cache_root}/current" 2>/dev/null || true)"
  case "$runtime" in
    cursor)
      hooks_manifest_path="${SB_RUNTIME_HOME_ROOT}/hooks.json"
      agent_bundle_dir="agents/cursor"
      if [[ -f "$hooks_manifest_path" ]] && grep -q '\.claude/plugins' "$hooks_manifest_path" 2>/dev/null; then
        record fail D13 "${hooks_manifest_path} contains .claude/plugins paths"
      else
        record pass D13 "no .claude/plugins contamination in Cursor hooks"
      fi
      ;;
    claude)
      hooks_manifest_path="${SB_RUNTIME_HOME_ROOT}/settings.json"
      agent_bundle_dir="agents/claude"
      if [[ -f "$hooks_manifest_path" ]] && grep -qE '\.cursor/plugins|\.codex/plugins' "$hooks_manifest_path" 2>/dev/null; then
        record fail D13 "${hooks_manifest_path} contains foreign host plugin paths"
      else
        record pass D13 "no cross-host plugin paths in Claude settings"
      fi
      ;;
    codex)
      hooks_manifest_path="${SB_RUNTIME_HOME_ROOT}/config.toml"
      agent_bundle_dir="agents/codex"
      if [[ -f "$hooks_manifest_path" ]] && grep -qE '\.cursor/plugins|\.claude/plugins' "$hooks_manifest_path" 2>/dev/null; then
        record fail D13 "${hooks_manifest_path} contains foreign host plugin paths"
      else
        record pass D13 "no cross-host plugin paths in Codex config"
      fi
      ;;
    *)
      record pass D13 "cross-host contamination check N/A (host=${runtime})"
      agent_bundle_dir=""
      ;;
  esac
  if [[ -n "$agent_bundle_dir" ]]; then
    if [[ -d "${skill_root}/${agent_bundle_dir}" ]]; then
      record pass D13 "active install has ${agent_bundle_dir}/"
    else
      record fail D13 "${agent_bundle_dir}/ missing in active plugin cache (${cache_root}/current)"
    fi
  fi

  if [[ "$FORMAT" == "json" ]]; then
    jq -n \
      --argjson pass "$PASS" --argjson fail "$FAIL" --argjson warn "$WARN" \
      --arg lines "$(printf '%s\n' "${REPORT_LINES[@]}")" \
      '{pass:$pass,fail:$fail,warn:$warn,lines:($lines|split("\n"))}'
  else
    echo
    echo "Silver Bullet doctor: ${PASS} PASS, ${WARN} WARN, ${FAIL} FAIL"
    if [[ "$FAIL" -eq 0 ]]; then
      echo "OVERALL: PASS"
    else
      echo "OVERALL: FAIL"
    fi
  fi

  [[ "$FAIL" -eq 0 ]]
}

main "$@"
