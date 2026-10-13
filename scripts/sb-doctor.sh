#!/usr/bin/env bash
# sb-doctor.sh — Silver Bullet install + project activation audit (sb:doctor)
# Exit 0 only when zero FAIL checks (WARN allowed).
#
# Usage:
#   bash scripts/sb-doctor.sh [PROJECT_ROOT]
#   bash scripts/sb-doctor.sh --deep [PROJECT_ROOT]
#   bash scripts/sb-doctor.sh --dry-run [PROJECT_ROOT]
#   bash scripts/sb-doctor.sh --fix[=local|host|packages|all] [PROJECT_ROOT]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/agent-bundle-paths.sh
source "${REPO_ROOT}/scripts/lib/agent-bundle-paths.sh"
DOCTOR_FIX="${SB_DOCTOR_FIX:-0}"
DOCTOR_FIX_SCOPE="${SB_DOCTOR_FIX_SCOPE:-}"
DOCTOR_DEEP="${SB_DOCTOR_DEEP:-0}"
DOCTOR_DRY_RUN="${SB_DOCTOR_DRY_RUN:-0}"
DOCTOR_FIX_APPLIED=0
DOCTOR_FIX_DENIED=0
DOCTOR_UNKNOWN_KEY=0
RECONCILER_JSON=""
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
      --deep) DOCTOR_DEEP=1; shift ;;
      --dry-run) DOCTOR_DRY_RUN=1; shift ;;
      --fix)
        DOCTOR_FIX=1
        DOCTOR_FIX_SCOPE="${DOCTOR_FIX_SCOPE:-all}"
        shift
        ;;
      --fix=*)
        DOCTOR_FIX=1
        DOCTOR_FIX_SCOPE="${1#--fix=}"
        shift
        ;;
      -h|--help)
        sed -n '1,12p' "$0"
        echo "  --deep          Bounded expensive probes (read-only)"
        echo "  --dry-run       Reconciler plan mode (no writes)"
        echo "  --fix[=SCOPE]   Apply repair: local|host|packages|all (default all)"
        exit 0
        ;;
      *) PROJ_ROOT="$1"; shift ;;
    esac
  done
  case "${DOCTOR_FIX_SCOPE:-}" in
    ""|all) DOCTOR_FIX_SCOPE="all" ;;
    local|host|packages) ;;
    *)
      echo "ERROR: --fix scope must be local|host|packages|all" >&2
      exit 2
      ;;
  esac
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
  SB_RUNTIME_STATE_DIR="${SB_RUNTIME_HOME_ROOT}/.silver-bullet"
  SB_RUNTIME_PLUGIN_CACHE_ROOT="${SB_RUNTIME_HOME_ROOT}/plugins/cache"
  return 0
}

plugin_registry_path() {
  printf '%s/plugins/installed_plugins.json' "${SB_RUNTIME_HOME_ROOT}"
}

plugin_cache_root() {
  case "${SB_RUNTIME_NAME:-${SILVER_BULLET_RUNTIME:-claude}}" in
    codex) printf '%s/alo-labs-codex/silver-bullet' "${SB_RUNTIME_PLUGIN_CACHE_ROOT}" ;;
    *) printf '%s/alo-labs/silver-bullet' "${SB_RUNTIME_PLUGIN_CACHE_ROOT}" ;;
  esac
}

# Codex can carry SB as a skills-only mirror.  This is an intentional
# installation mode: the skills remain available through the native picker,
# while SB does not register a second plugin/hook stack in Codex.
codex_skills_only_surface_present() {
  [[ "${SB_RUNTIME_NAME:-${SILVER_BULLET_RUNTIME:-}}" == "codex" ]] || return 1
  local codex_root="${SB_RUNTIME_HOME_ROOT:-${HOME}/.codex}"
  [[ -f "${codex_root}/skills/silver/SKILL.md" ]] || return 1
  [[ -f "${codex_root}/skills/silver:agent-codex/SKILL.md" ]] || return 1
  local registry="${codex_root}/plugins/installed_plugins.json"
  if [[ -f "$registry" ]] && jq -e '
    (.plugins // {})
    | keys[]?
    | select(test("^silver-bullet@"))
  ' "$registry" >/dev/null 2>&1; then
    return 1
  fi
  local config="${codex_root}/config.toml"
  if [[ -f "$config" ]] && grep -qE \
    '^\[(plugins|hooks\.state)\."silver-bullet@alo-labs-codex' "$config" 2>/dev/null; then
    return 1
  fi
  local hooks="${codex_root}/hooks.json"
  if [[ -f "$hooks" ]] && grep -q 'silver-bullet' "$hooks" 2>/dev/null; then
    return 1
  fi
  return 0
}

# Return only supported foreign-host plugin path fragments for a runtime.
# D13 must not mistake the active host's own plugin path for contamination.
foreign_host_plugin_path_pattern() {
  local current_host="${1:-}" host
  local patterns=()
  for host in claude codex cursor; do
    [[ "$host" == "$current_host" ]] && continue
    patterns+=("\\.${host}/plugins")
  done
  local IFS='|'
  printf '%s' "${patterns[*]}"
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
  # SB_HOOK_SMOKE: session-start must not persist/mutate project config during doctor smoke (#257).
  if ( cd "$PROJ_ROOT" && printf '%s' "$payload" | env SB_HOOK_SMOKE=1 bash "$hook_path" >/dev/null 2>&1 ); then
    return 0
  fi
  return 1
}

doctor_host_install_script() {
  case "${1:-}" in
    claude) printf '%s\n' "${REPO_ROOT}/scripts/install-claude.sh" ;;
    codex) printf '%s\n' "${REPO_ROOT}/scripts/install-codex.sh" ;;
    cursor) printf '%s\n' "${REPO_ROOT}/scripts/install-cursor.sh" ;;
    *) return 1 ;;
  esac
}

doctor_reconciler_scope() {
  case "${DOCTOR_FIX_SCOPE:-all}" in
    local) printf '%s' "project" ;;
    host) printf '%s' "host" ;;
    packages) printf '%s' "packages" ;;
    all) printf '%s' "all" ;;
    *) printf '%s' "all" ;;
  esac
}

doctor_generic_manifest_path() {
  if [[ -n "${SB_GLOBAL_TOOLSTACK_MANIFEST:-}" ]]; then
    printf '%s' "${SB_GLOBAL_TOOLSTACK_MANIFEST}"
  elif [[ -n "${SB_GLOBAL_TOOLSTACK_HOME:-}" ]]; then
    # Read/write compatibility for pre-generic SB installations and fixtures.
    printf '%s/instances.json' "${SB_GLOBAL_TOOLSTACK_HOME}"
  else
    printf '%s/manifest.json' "${FIVE_TOOL_STACK_HOME:-${XDG_STATE_HOME:-${XDG_DATA_HOME:-${HOME}/.local/state}}/five-tool-stack}"
  fi
}

doctor_record_generic_stack() {
  local manifest_path="$(doctor_generic_manifest_path)"
  if [[ ! -f "$manifest_path" ]]; then
    record warn D10-generic "generic stack absent (${manifest_path}); SB integration remains separate"
    return 0
  fi
  local diagnostic valid detail
  diagnostic="$(PYTHONPATH="${REPO_ROOT}/scripts/lib" python3 - "$manifest_path" <<'PY'
import sys
from pathlib import Path
from five_tool_runtime.runtime import load_manifest, validate_manifest

path = Path(sys.argv[1])
result = validate_manifest(load_manifest(path), require_commands=False)
print("{}|{}".format("valid" if result["valid"] else "invalid", "; ".join(result["errors"] + result["warnings"])))
PY
  )" || diagnostic="invalid|runtime validation unavailable"
  valid="${diagnostic%%|*}"
  detail="${diagnostic#*|}"
  if [[ "$valid" == "valid" ]]; then
    record pass D10-generic "generic manifest valid (${manifest_path})${detail:+ — ${detail}}"
  else
    record fail D10-generic "generic manifest malformed or partial (${manifest_path})${detail:+ — ${detail}}"
  fi
}

doctor_repair_generic_stack() {
  [[ "$DOCTOR_FIX" -eq 1 && "$DOCTOR_DRY_RUN" -eq 0 ]] || return 0
  case "${DOCTOR_FIX_SCOPE:-all}" in
    local) return 0 ;;
  esac
  local manifest_path="$(doctor_generic_manifest_path)"
  local legacy_path="${HOME}/.silver-bullet/five-tool-stack/instances.json"
  local output rc=0
  output="$(PYTHONPATH="${REPO_ROOT}/scripts/lib" python3 "${REPO_ROOT}/scripts/lib/five_tool_runtime/cli.py" repair \
    --manifest "$manifest_path" --legacy-manifest "$legacy_path" 2>&1)" || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    record fail D10-generic "generic repair failed: ${output##*$'\n'}"
    return 1
  fi
  printf '%s\n' "$output" | tail -1 >&2
  return 0
}

doctor_run_reconciler() {
  local mode="$1"
  local reconciler="${SB_DOCTOR_RECONCILER:-${REPO_ROOT}/scripts/reconcile-recommended-tools.sh}"
  [[ -f "$reconciler" ]] || return 1
  local host="${SB_RUNTIME_NAME:-${SILVER_BULLET_RUNTIME:-cursor}}"
  local scope="all"
  if [[ "$mode" == "apply" ]]; then
    scope="$(doctor_reconciler_scope)"
  fi
  local -a args=(--project-root "$PROJ_ROOT" --host "$host" --mode "$mode" --scope "$scope" --format json)
  if [[ "$mode" == "apply" ]]; then
    args+=(--entry-point doctor-fix)
  fi
  local errf rc=0
  errf="$(mktemp)"
  set +e
  RECONCILER_JSON="$(bash "$reconciler" "${args[@]}" 2>"$errf")"
  rc=$?
  set -e
  if [[ -s "$errf" ]]; then
    cat "$errf" >&2
  fi
  rm -f "$errf"
  if [[ -z "$RECONCILER_JSON" ]] || ! printf '%s' "$RECONCILER_JSON" | jq -e . >/dev/null 2>&1; then
    RECONCILER_JSON=""
    return 1
  fi
  return "$rc"
}

doctor_fix_needs_confirm() {
  case "${DOCTOR_FIX_SCOPE:-all}" in
    packages|all) ;;
    *) return 1 ;;
  esac
  [[ -n "${RECONCILER_JSON:-}" ]] || return 0
  if printf '%s' "$RECONCILER_JSON" | jq -e '
      .components[]? | select(.repairable == true and (.consent == "enabled") and
        (.component == "search_cli" or .component == "graphify" or .component == "agentmemory"
         or .component == "rtk" or .component == "context_mode" or .component == "leanctx" or .component == "alumnium"))
    ' >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

doctor_confirm_fix_if_needed() {
  doctor_fix_needs_confirm || return 0
  [[ "${SB_DOCTOR_ASSUME_YES:-0}" == "1" ]] && return 0
  if [[ ! -t 0 ]]; then
    printf 'sb-doctor: confirmation required for --fix=%s (set SB_DOCTOR_ASSUME_YES=1)\n' "${DOCTOR_FIX_SCOPE:-all}" >&2
    return 1
  fi
  printf 'sb-doctor: apply --fix=%s? [y/N] ' "${DOCTOR_FIX_SCOPE:-all}" >&2
  local reply=""
  read -r reply || return 1
  case "$reply" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}
doctor_record_reconciler_d10() {
  local reconciler="${REPO_ROOT}/scripts/reconcile-recommended-tools.sh"
  [[ -f "$reconciler" ]] || {
    record pass D10 "reconciler unavailable; skipped"
    return 0
  }
  local mode="verify"
  [[ "$DOCTOR_DRY_RUN" -eq 1 ]] && mode="plan"
  doctor_run_reconciler "$mode" || true
  [[ -n "$RECONCILER_JSON" ]] || {
    record warn D10 "reconciler returned no JSON"
    return 0
  }
  [[ "$DOCTOR_DRY_RUN" -eq 1 ]] && record pass D10 "dry-run plan complete (no writes)"
  local tool state activation consent any_fail=0
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    tool="${line%%:*}"
    rest="${line#*:}"
    state="${rest%%:*}"
    activation="${rest##*:}"
    [[ "$tool" == "cross_tool" ]] && continue
    consent="$(printf '%s' "$RECONCILER_JSON" | jq -r --arg t "$tool" '.components[]? | select(.component==$t) | .consent' 2>/dev/null || true)"
    case "$state" in
      ready)
        local ev
        ev="$(printf '%s' "$RECONCILER_JSON" | jq -r --arg t "$tool" '.components[]? | select(.component==$t) | .evidence[]?' 2>/dev/null || true)"
        if printf '%s\n' "$ev" | grep -qxE 'provider_missing|version_drift|unsupported_package_manager|vendor_skip|skill_package_skew|health_identity_unproven'; then
          record warn "D10-${tool}" "${tool} ready with advisory ($(printf '%s' "$ev" | paste -sd ',' -)) (activation=${activation})"
        else
          record pass "D10-${tool}" "${tool} ready (activation=${activation})"
        fi
        ;;
      disabled|pending|unsupported) record pass "D10-${tool}" "${tool} ${state} (consent=${consent:-n/a})" ;;
      suspended) record warn "D10-${tool}" "${tool} suspended — retry /sb:init or /sb:update" ;;
      reload_required) record warn "D10-${tool}" "${tool} reload_required (activation=${activation})" ;;
      repairable) record fail "D10-${tool}" "${tool} repairable — run /sb:doctor --fix"; any_fail=1 ;;
      failed) record fail "D10-${tool}" "${tool} failed"; any_fail=1 ;;
      *) record warn "D10-${tool}" "${tool} state=${state}" ;;
    esac
  done < <(printf '%s' "$RECONCILER_JSON" | jq -r '.components[]? | select(.component != "cross_tool") | "\(.component):\(.canonical_state):\(.activation_status)"' 2>/dev/null)
  local cross cross_activation
  cross="$(printf '%s' "$RECONCILER_JSON" | jq -r '.components[]? | select(.component=="cross_tool") | .canonical_state' 2>/dev/null || true)"
  cross_activation="$(printf '%s' "$RECONCILER_JSON" | jq -r '.components[]? | select(.component=="cross_tool") | .activation_status' 2>/dev/null || true)"
  if [[ -n "$cross" ]]; then
    if [[ "$cross" == "ready" && "$cross_activation" == "full" ]]; then
      record pass D10-routes "ten route owners + heartbeat OK"
    elif [[ "$cross" == "ready" ]] && printf '%s' "$RECONCILER_JSON" | jq -e '.components[]? | select(.component=="cross_tool") | .evidence[]? | select(. == "no_five_tool_consent")' >/dev/null 2>&1; then
      record pass D10-routes "cross_tool N/A until five-tool opt-in (no consent)"
    elif [[ "$cross" == "ready" ]]; then
      record pass D10-routes "cross_tool ready (activation=${cross_activation:-none})"
    else
      record fail D10-routes "cross_tool ${cross} (activation=${cross_activation:-none}) — run --fix=host"
      any_fail=1
    fi
  else
    record warn D10-routes "cross_tool component missing from reconciler output — run reconcile or /sb:doctor --fix=host"
  fi
  local unknown_keys
  unknown_keys="$(printf '%s' "$RECONCILER_JSON" | jq -r '.unknown_keys[]? // empty' 2>/dev/null || true)"
  if [[ -n "$unknown_keys" ]]; then
    DOCTOR_UNKNOWN_KEY=1
    record warn D10 "unknown_key ($(printf '%s' "$unknown_keys" | paste -sd ',' -)); other components not FAIL-poisoned"
  fi
  if [[ "$DOCTOR_DEEP" -eq 1 ]]; then
    # Context Mode vendor doctor runs on the default D10 probe path (FAIL when
    # opted in). --deep keeps the Graphify MCP stdio handshake as WARN only.
    if command -v graphify-mcp >/dev/null 2>&1; then
      timeout 5 graphify-mcp --transport stdio </dev/null >/dev/null 2>&1 \
        && record pass D10-deep-graphify "graphify-mcp stdio handshake OK" \
        || record warn D10-deep-graphify "graphify-mcp stdio handshake failed"
    fi
  fi
  [[ "$any_fail" -eq 0 ]]
}

doctor_apply_fixes() {
  local runtime="$1" check_id install_script fixed=0 recon_rc=0
  [[ "$DOCTOR_FIX" -eq 1 ]] || return 0
  [[ "$DOCTOR_DRY_RUN" -eq 1 ]] && return 0
  if ! doctor_confirm_fix_if_needed; then
    DOCTOR_FIX_APPLIED=0
    DOCTOR_FIX_DENIED=1
    record fail D10 "confirmation unobtainable; --fix not applied"
    return 0
  fi
  doctor_repair_generic_stack || true
  if [[ -f "${SB_DOCTOR_RECONCILER:-${REPO_ROOT}/scripts/reconcile-recommended-tools.sh}" ]]; then
    printf 'sb-doctor: --fix=%s running reconciler doctor-fix apply\n' "${DOCTOR_FIX_SCOPE:-all}" >&2
    doctor_run_reconciler apply || recon_rc=$?
    if [[ -z "${RECONCILER_JSON:-}" ]] || ! printf '%s' "$RECONCILER_JSON" | jq -e . >/dev/null 2>&1; then
      DOCTOR_FIX_APPLIED=0
      record fail D10 "reconciler apply returned empty or malformed JSON"
      return 0
    fi
    if [[ "$recon_rc" -ne 0 ]] || printf '%s' "$RECONCILER_JSON" | jq -e '.ok == false' >/dev/null 2>&1; then
      DOCTOR_FIX_APPLIED=0
      record fail D10 "reconciler apply failed (receipt not success)"
      return 0
    fi
    DOCTOR_FIX_APPLIED=1
    fixed=1
  fi
  [[ "$FAIL" -eq 0 && "$fixed" -eq 1 ]] && return 0
  [[ "$FAIL" -eq 0 ]] && return 0
  for check_id in "${FAILED_CHECK_IDS[@]}"; do
    if [[ "${DOCTOR_FIX_SCOPE:-all}" == "local" ]]; then
      case "$check_id" in
        D4|D13|D14|D16|D18|D19|D21) continue ;;
      esac
    fi
    if [[ -n "${SB_DOCTOR_STUB_HOST_INSTALL:-}" ]]; then
      case "$check_id" in
        D4|D13|D14|D16|D18|D19|D21)
          printf '%s
' "$check_id" >> "${SB_DOCTOR_STUB_HOST_INSTALL}"
          fixed=1
          continue
          ;;
      esac
    fi
    case "$check_id" in
      D13|D14|D16|D18|D19)
        install_script="$(doctor_host_install_script "$runtime" || true)"
        if [[ -n "$install_script" && -x "$install_script" ]]; then
          printf 'sb-doctor: --fix running %s for %s\n' "$install_script" "$check_id" >&2
          bash "$install_script" >&2 || true
          fixed=1
        fi
        ;;
      D20)
        if [[ -f "${REPO_ROOT}/hooks/lib/stack-compression-coordinator.sh" ]]; then
          # shellcheck source=../hooks/lib/stack-compression-coordinator.sh
          source "${REPO_ROOT}/hooks/lib/stack-compression-coordinator.sh"
          sb_stack_clear_mutex_violations
        fi
        if [[ -f "${REPO_ROOT}/hooks/lib/agentmemory-gate.sh" ]]; then
          # shellcheck source=../hooks/lib/agentmemory-gate.sh
          source "${REPO_ROOT}/hooks/lib/agentmemory-gate.sh"
          local cfg="${PROJ_ROOT}/.silver-bullet.json"
          if [[ -f "$cfg" ]] && sb_agentmemory_required "$cfg" 2>/dev/null; then
            sb_agentmemory_scaffold_export_root "$PROJ_ROOT" "$cfg" || true
          fi
        fi
        fixed=1
        ;;
      D15)
        printf 'sb-doctor: --fix D15 requires shortening Claude agent descriptions\n' >&2
        ;;
      D4)
        case "$runtime" in
          cursor) bash "${REPO_ROOT}/scripts/install-cursor.sh" --merge-hooks-only >&2 || true; fixed=1 ;;
          *)
            install_script="$(doctor_host_install_script "$runtime" || true)"
            [[ -n "$install_script" && -x "$install_script" ]] && bash "$install_script" >&2 || true
            fixed=1
            ;;
        esac
        ;;
      D21)
        local csba_fix_scope="global"
        if [[ -f "${PROJ_ROOT}/.silver-bullet.json" ]]; then
          csba_fix_scope="$(jq -r '.cursor_sb_agents.agents_install_scope // "global"' "${PROJ_ROOT}/.silver-bullet.json")"
        fi
        local csba_fix_flags=(--fix)
        if [[ "$csba_fix_scope" == "project" ]]; then
          csba_fix_flags+=(--project)
        else
          csba_fix_flags+=(--global)
        fi
        printf 'sb-doctor: --fix running install-cursor-sb-agents.sh for D21\n' >&2
        # Target the project being doctored, not this checkout — the D21 probe
        # above already scopes itself with CSBA_REPO_ROOT, and without the same
        # scoping here --fix writes its config and agents into Silver Bullet.
        CSBA_REPO_ROOT="$PROJ_ROOT" \
          bash "${REPO_ROOT}/scripts/install-cursor-sb-agents.sh" "${csba_fix_flags[@]}" >&2 || true
        fixed=1
        ;;
    esac
  done
  [[ "$fixed" -eq 1 ]] && DOCTOR_FIX_APPLIED=1
}

run_doctor_checks() {
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
    elif codex_skills_only_surface_present; then
      record pass D2 "Codex skills-only Silver Bullet surface active (plugin registry intentionally absent)"
    else
      record fail D2 "no silver-bullet plugin entry in ${reg}"
    fi
  else
    if codex_skills_only_surface_present; then
      record pass D2 "Codex skills-only Silver Bullet surface active (plugin registry intentionally absent)"
    else
      record fail D2 "plugin registry missing: ${reg}"
    fi
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
      if [[ -f "${HOME}/.codex/config.toml" ]] && grep -qE \
        '^\[(plugins|hooks\.state)\."silver-bullet@alo-labs-codex' "${HOME}/.codex/config.toml" 2>/dev/null; then
        record pass D4 "Codex config.toml references silver-bullet hooks"
      elif codex_skills_only_surface_present; then
        record pass D4 "Codex skills-only surface active; SB hooks intentionally absent"
      else
        record fail D4 "Codex config.toml missing SB hook entries"
      fi
      ;;
    claude)
      if [[ -f "${HOME}/.claude/settings.json" ]] && grep -q 'silver-bullet' "${HOME}/.claude/settings.json" 2>/dev/null; then
        record pass D4 "Claude settings.json references silver-bullet hooks"
      else
        record fail D4 "Claude settings.json missing SB hook entries"
      fi
      ;;
    *)
      record fail D4 "unsupported host runtime: ${runtime}"
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
      record fail D8 ".cursor/rules/silver-orchestrator.mdc missing (run sb:migrate or sb:init on Cursor)"
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

  # D10 — five-tool reconciler (all components + routes)
  # D10-generic is deliberately separate from SB hooks/enforcement readiness.
  doctor_record_generic_stack || true
  doctor_record_reconciler_d10 || true


  # D11 — hook smoke
  # --dry-run must not mutate project files via live session-start persist (#257 / F8).
  if [[ "$DOCTOR_DRY_RUN" -eq 1 ]]; then
    record pass D11 "hook smoke skipped (dry-run)"
  else
    local hook_root hook_name
    # Prefer source-tree hooks when present so smoke matches this checkout (not stale plugin cache).
    if [[ -f "${REPO_ROOT}/hooks/session-start" ]]; then
      hook_root="${REPO_ROOT}"
    else
      hook_root="$(readlink -f "${cache_root}/current" 2>/dev/null || echo "${REPO_ROOT}")"
    fi
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
  fi

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

  # D13 — cross-host plugin path contamination (host-scoped manifest paths)
  local skill_root hooks_manifest_path agent_cache_dir install_surface_script foreign_plugin_pattern
  install_surface_script="${REPO_ROOT}/scripts/validate-host-install-surface.sh"
  skill_root="$(readlink -f "${cache_root}/current" 2>/dev/null || true)"
  foreign_plugin_pattern="$(foreign_host_plugin_path_pattern "$runtime")"
  case "$runtime" in
    cursor)
      hooks_manifest_path="${SB_RUNTIME_HOME_ROOT}/hooks.json"
      agent_cache_dir="$(sb_agent_cache_rel cursor)"
      if [[ -f "$hooks_manifest_path" ]] && grep -qE "$foreign_plugin_pattern" "$hooks_manifest_path" 2>/dev/null; then
        record fail D13 "${hooks_manifest_path} contains foreign host plugin paths"
      else
        record pass D13 "no foreign host plugin paths in Cursor hooks"
      fi
      ;;
    claude)
      hooks_manifest_path="${SB_RUNTIME_HOME_ROOT}/settings.json"
      agent_cache_dir="$(sb_agent_cache_rel claude)"
      if [[ -f "$hooks_manifest_path" ]] && grep -qE "$foreign_plugin_pattern" "$hooks_manifest_path" 2>/dev/null; then
        record fail D13 "${hooks_manifest_path} contains foreign host plugin paths"
      else
        record pass D13 "no cross-host plugin paths in Claude settings"
      fi
      ;;
    codex)
      hooks_manifest_path="${SB_RUNTIME_HOME_ROOT}/config.toml"
      agent_cache_dir="$(sb_agent_cache_rel codex)"
      if [[ -f "$hooks_manifest_path" ]] && grep -qE "$foreign_plugin_pattern" "$hooks_manifest_path" 2>/dev/null; then
        record fail D13 "${hooks_manifest_path} contains foreign host plugin paths"
      else
        record pass D13 "no cross-host plugin paths in Codex config"
      fi
      ;;
    *)
      record pass D13 "cross-host contamination check N/A (host=${runtime})"
      agent_cache_dir=""
      ;;
  esac
  if [[ -n "$agent_cache_dir" && -n "$skill_root" ]]; then
    if [[ -d "${skill_root}/${agent_cache_dir}" ]]; then
      record pass D13 "active install has ${agent_cache_dir}/"
    else
      record fail D13 "${agent_cache_dir}/ missing in active plugin cache (${cache_root}/current)"
    fi
  fi

  # D14 — foreign agent namespaces in active plugin cache
  if [[ -n "$skill_root" && -d "$skill_root" && -x "$install_surface_script" ]]; then
    if bash "$install_surface_script" --cache-root "$skill_root" --host "$runtime" >/dev/null 2>&1; then
      record pass D14 "plugin cache has no foreign host agent namespaces"
    else
      record fail D14 "plugin cache cross-host bleed — run: bash scripts/install-${runtime}.sh"
    fi
  else
    record warn D14 "plugin cache surface check skipped (no active install)"
  fi

  # D15 — Claude agent description token budget
  if [[ "$runtime" == "claude" ]]; then
    local token_script="${REPO_ROOT}/scripts/validate-claude-agent-token-budget.sh"
    if [[ -x "$token_script" ]] && bash "$token_script" --repo-root "$REPO_ROOT" >/dev/null 2>&1; then
      record pass D15 "Claude agent description token budget within limit"
    elif [[ -x "$token_script" ]]; then
      record fail D15 "Claude agent descriptions exceed token budget"
    else
      record warn D15 "validate-claude-agent-token-budget.sh not found; skipped"
    fi
  else
    record pass D15 "Claude token budget N/A (host=${runtime})"
  fi

  # D16 — repo install surface
  if [[ -x "$install_surface_script" ]] && bash "$install_surface_script" --repo-root "$REPO_ROOT" --host "$runtime" >/dev/null 2>&1; then
    record pass D16 "repo install surface clean for host=${runtime}"
  elif [[ -x "$install_surface_script" ]]; then
    record fail D16 "repo install surface bleed — run: bash scripts/install-${runtime}.sh"
  else
    record warn D16 "validate-host-install-surface.sh not found; skipped"
  fi

  # D17 — host-agnostic SB core (repo checkout)
  local agnostic_script="${REPO_ROOT}/scripts/validate-host-agnostic-core.sh"
  if [[ -x "$agnostic_script" ]] && bash "$agnostic_script" --repo-root "$REPO_ROOT" >/dev/null 2>&1; then
    record pass D17 "SB core is host-agent agnostic"
  elif [[ -x "$agnostic_script" ]]; then
    record fail D17 "host-specific bleed in SB core — run: bash scripts/validate-host-agnostic-core.sh"
  else
    record warn D17 "validate-host-agnostic-core.sh not found; skipped"
  fi

  # D18 — Cursor marketplace gitPath (required for /sb command discovery after restart)
  if [[ "$runtime" == "cursor" ]]; then
    local registry_sha backend_sha gitpath_root market_cache_link backend_cache_path resolved_current
    registry_sha="$(resolve_registry_plugin_field "$reg" "silver-bullet@alo-labs" "gitCommitSha")"
    resolved_current="$(readlink -f "${cache_root}/current" 2>/dev/null || true)"
    backend_sha="$(find "${HOME}/Library/Application Support/Cursor/logs" -name 'Cursor Plugins*.log' -type f -print0 2>/dev/null \
      | xargs -0 grep -h 'Adding enabled plugin: silver-bullet from ' 2>/dev/null \
      | sed -n 's/.*silver-bullet from \([0-9a-f]\{40\}\).*/\1/p' | tail -1 || true)"
    [[ -n "$backend_sha" ]] || backend_sha="$registry_sha"
    if [[ -n "$backend_sha" && "$backend_sha" != "null" ]]; then
      gitpath_root="${HOME}/.cursor/plugins/marketplaces/github.com/alo-exp/silver-bullet/${backend_sha}"
      market_cache_link="${HOME}/.cursor/plugins/cache/alo-labs-cursor/silver-bullet/${backend_sha}"
      backend_cache_path="${HOME}/.cursor/plugins/cache/alo-labs-agent-plugins/silver-bullet/${backend_sha}"
      if [[ -d "${gitpath_root}/.git" ]] && git -C "$gitpath_root" cat-file -e "${backend_sha}^{commit}" >/dev/null 2>&1; then
        if [[ -d "$backend_cache_path" && -f "${backend_cache_path}/.cache-complete" && -f "${backend_cache_path}/commands/sb.md" ]]; then
          record pass D18 "Cursor backend cache + gitPath ready (${backend_sha:0:8})"
        elif [[ -L "$market_cache_link" ]] && [[ "$(readlink -f "$market_cache_link" 2>/dev/null || true)" == "$resolved_current" ]]; then
          record fail D18 "missing alo-labs-agent-plugins materialized cache for ${backend_sha:0:8} — run: bash scripts/install-cursor.sh"
        else
          record fail D18 "missing alo-labs-cursor cache symlink for ${backend_sha:0:8} — run: bash scripts/install-cursor.sh"
        fi
      else
        record fail D18 "missing Cursor gitPath for ${backend_sha:0:8} — /sb commands fail to load — run: bash scripts/install-cursor.sh"
      fi
    else
      record warn D18 "no gitCommitSha in installed_plugins.json — run: bash scripts/install-cursor.sh"
    fi
    if [[ -f "${resolved_current}/commands/sb.md" ]]; then
      record pass D19 "composer /sb:* command stubs present in plugin cache"
    else
      record fail D19 "commands/ missing from plugin cache — slash menu will be empty"
    fi
  else
    record pass D18 "Cursor gitPath check N/A (host=${runtime})"
    record pass D19 "Cursor command stubs N/A (host=${runtime})"
  fi

  # D20 — stack compression mutex (five-tool coordinator)
  local stack_cfg="${PROJ_ROOT}/.silver-bullet.json"
  if [[ -f "${REPO_ROOT}/hooks/lib/stack-compression-coordinator.sh" ]]; then
    # shellcheck source=../hooks/lib/stack-compression-coordinator.sh
    source "${REPO_ROOT}/hooks/lib/stack-compression-coordinator.sh"
    if [[ -f "$stack_cfg" ]] && sb_stack_coordinator_needed "$stack_cfg" 2>/dev/null; then
      if sb_stack_mutual_exclusion_is_clean "$stack_cfg"; then
        record pass D20 "stack compression mutex clean"
      else
        record fail D20 "stack compression mutex dirty — run: bash scripts/sb-doctor.sh --fix"
      fi
    else
      record pass D20 "stack coordinator N/A (five-tool not active)"
    fi
  else
    record warn D20 "stack-compression-coordinator lib missing; skipped"
  fi

  # D21 — Cursor SB custom subagents (cursor_sb_agents; global or project scope)
  if [[ "$runtime" == "cursor" ]]; then
    local csba_probe="${REPO_ROOT}/scripts/lib/cursor-sb-agents/probe-global-agents.sh"
    local csba_check=0 csba_scope="global" csba_agents_dir=""
    if [[ -f "$sb_config" ]]; then
      csba_check="$(jq -r '
        if (.cursor_sb_agents.enabled // false) == true then 1
        elif (.cursor_sb_agents.enabled_by_user // null) == true
             and (.cursor_sb_agents.enforcement_suspended // false) != true then 1
        else 0 end' "$sb_config" 2>/dev/null || echo 0)"
      csba_scope="$(jq -r '.cursor_sb_agents.agents_install_scope // "global"' "$sb_config" 2>/dev/null || echo global)"
    fi
    if [[ "$csba_check" -eq 0 ]]; then
      record pass D21 "cursor_sb_agents not enabled (N/A)"
    elif [[ ! -x "$csba_probe" ]]; then
      record warn D21 "probe-global-agents.sh missing; skipped"
    else
      if [[ "$csba_scope" == "project" ]]; then
        csba_agents_dir="${PROJ_ROOT}/.cursor/agents"
      else
        csba_agents_dir="${HOME}/.cursor/agents"
      fi
      if CSBA_REPO_ROOT="$PROJ_ROOT" bash "$csba_probe" \
        --agents-dir "$csba_agents_dir" --repo-root "$PROJ_ROOT" --quiet 2>/dev/null; then
        record pass D21 "SB custom subagents (${csba_scope}): managed set matches config"
      else
        record fail D21 "SB custom subagents missing or stale — run: bash scripts/install-cursor-sb-agents.sh --fix"
      fi
    fi
  else
    record pass D21 "cursor_sb_agents N/A (host=${runtime})"
  fi


  # D22 — Cursor duplicate LeanCTX MCP servers (lean-ctx + leanctx)
  if [[ "$runtime" == "cursor" ]]; then
    local cursor_mcp="${HOME}/.cursor/mcp.json"
    if [[ -f "$cursor_mcp" ]] \
      && jq -e '.mcpServers["lean-ctx"] and .mcpServers.leanctx' "$cursor_mcp" >/dev/null 2>&1; then
      record warn D22 "duplicate LeanCTX MCP servers (lean-ctx + leanctx) — remove lean-ctx, keep leanctx; run: RT_PATCH_LEANCTX=1 python3 scripts/lib/global-toolstack/patch-mcp.py"
    else
      record pass D22 "no duplicate LeanCTX MCP servers"
    fi
  else
    record pass D22 "duplicate LeanCTX MCP check N/A (host=${runtime})"
  fi

  doctor_apply_fixes "$runtime"
}

doctor_print_summary() {
  if [[ "$FORMAT" == "json" ]]; then
    local recon='null'
    if [[ -n "${RECONCILER_JSON:-}" ]]; then
      recon="$(printf '%s' "$RECONCILER_JSON" | jq -c '.' 2>/dev/null || echo null)"
    fi
    jq -n \
      --arg schema "2.0.0" \
      --argjson pass "$PASS" --argjson fail "$FAIL" --argjson warn "$WARN" \
      --argjson deep "$([[ "$DOCTOR_DEEP" -eq 1 ]] && echo true || echo false)" \
      --argjson dry_run "$([[ "$DOCTOR_DRY_RUN" -eq 1 ]] && echo true || echo false)" \
      --arg fix_scope "${DOCTOR_FIX_SCOPE:-}" \
      --argjson reconciler "$recon" \
      --argjson fix_applied "$([[ "$DOCTOR_FIX_APPLIED" -eq 1 ]] && echo true || echo false)" \
      --arg lines "$(printf '%s\n' "${REPORT_LINES[@]}")" \
      '{schema:$schema,pass:$pass,fail:$fail,warn:$warn,deep:$deep,dry_run:$dry_run,fix_applied:$fix_applied,fix_scope:(if $fix_scope=="" then null else $fix_scope end),reconciler:$reconciler,lines:($lines|split("\n"))}'
  else
    echo
    echo "Silver Bullet doctor: ${PASS} PASS, ${WARN} WARN, ${FAIL} FAIL"
    if [[ "$FAIL" -eq 0 ]]; then
      echo "OVERALL: PASS"
    else
      echo "OVERALL: FAIL"
    fi
  fi
}

main() {
  parse_args "$@"
  run_doctor_checks
  if [[ "$DOCTOR_FIX_APPLIED" -eq 1 && "$DOCTOR_DRY_RUN" -eq 0 ]]; then
    [[ "$FORMAT" != "json" ]] && echo && echo "sb-doctor: re-running checks after --fix"
    PASS=0; FAIL=0; WARN=0; REPORT_LINES=(); FAILED_CHECK_IDS=()
    RECONCILER_JSON=""
    DOCTOR_UNKNOWN_KEY=0
    run_doctor_checks
  fi
  doctor_print_summary
  if [[ "${DOCTOR_FIX_DENIED:-0}" -eq 1 ]]; then
    return 1
  fi
  if [[ "${DOCTOR_UNKNOWN_KEY:-0}" -eq 1 ]]; then
    return 1
  fi
  [[ "$FAIL" -eq 0 ]]
}

parse_args "$@"
main
