#!/usr/bin/env bash
# sb-diagnostics.sh — Silver Bullet install/runtime diagnostics
# Verifies jq, hooks, Graphify, package version, and runtime capability tier.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FORMAT="${SB_DIAG_FORMAT:-text}"
PASS=0
FAIL=0
WARN=0

json_escape() {
  python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' <<<"$1"
}

record() {
  local level="$1" check="$2" detail="$3"
  case "$level" in
    pass)
      [[ "$FORMAT" == "json" ]] || echo "PASS: $check — $detail"
      (( PASS++ )) || true
      ;;
    warn)
      [[ "$FORMAT" == "json" ]] || echo "WARN: $check — $detail"
      (( WARN++ )) || true
      ;;
    fail)
      [[ "$FORMAT" == "json" ]] || echo "FAIL: $check — $detail"
      (( FAIL++ )) || true
      ;;
  esac
}

detect_runtime_home() {
  if [[ -f "${REPO_ROOT}/hooks/lib/runtime-paths.sh" ]]; then
    # shellcheck source=../hooks/lib/runtime-paths.sh
    source "${REPO_ROOT}/hooks/lib/runtime-paths.sh"
    printf '%s' "${SB_RUNTIME_HOME_ROOT}"
    return
  fi
  if [[ -f "${HOME}/.cursor/hooks.json" ]] && grep -q 'silver-bullet' "${HOME}/.cursor/hooks.json" 2>/dev/null; then
    printf '%s' "${HOME}/.cursor"
    return
  fi
  if [[ -n "${CODEX_HOME:-}" && -d "${CODEX_HOME}" ]]; then
    printf '%s' "$CODEX_HOME"
    return
  fi
  if [[ -n "${CLAUDE_CONFIG_DIR:-}" && -d "${CLAUDE_CONFIG_DIR}" ]]; then
    printf '%s' "$CLAUDE_CONFIG_DIR"
    return
  fi
  if [[ -d "${HOME}/.cursor" ]]; then
    printf '%s' "${HOME}/.cursor"
    return
  fi
  if [[ -d "${HOME}/.codex" ]]; then
    printf '%s' "${HOME}/.codex"
    return
  fi
  if [[ -d "${HOME}/.claude" ]]; then
    printf '%s' "${HOME}/.claude"
    return
  fi
  printf '%s' "${HOME}/.codex"
}

runtime_tier() {
  local hooks_present="$1" state_dir="$2"
  if [[ "$hooks_present" == "yes" && -d "$state_dir" ]]; then
    printf 'hook-enforced'
    return
  fi
  if [[ -d "$state_dir" ]]; then
    printf 'state-tracked'
    return
  fi
  printf 'guidance-only'
}

main() {
  local runtime_home hooks_present="no" graphify="no" jq_ok="no"
  local sb_version="unknown" capability_tier="guidance-only"
  local state_dir=""

  if command -v jq >/dev/null 2>&1; then
    jq_ok="yes"
    record pass "jq" "installed ($(jq --version 2>/dev/null | head -1))"
  else
    record fail "jq" "missing — SB hooks fail-open without jq"
  fi

  runtime_home="$(detect_runtime_home)"
  # detect_runtime_home sources runtime-paths in a subshell when invoked via $();
  # re-source here so SB_RUNTIME_NAME/SB_RUNTIME_STATE_DIR persist for reporting.
  if [[ -f "${REPO_ROOT}/hooks/lib/runtime-paths.sh" ]]; then
    # shellcheck source=../hooks/lib/runtime-paths.sh
    source "${REPO_ROOT}/hooks/lib/runtime-paths.sh"
    runtime_home="${SB_RUNTIME_HOME_ROOT}"
  fi
  state_dir="${SB_RUNTIME_STATE_DIR:-${runtime_home}/.silver-bullet}"

  if [[ -f "${runtime_home}/config.toml" ]] && grep -q 'silver-bullet' "${runtime_home}/config.toml" 2>/dev/null; then
    hooks_present="yes"
    record pass "hooks" "Silver Bullet hooks referenced in ${runtime_home}/config.toml"
  elif [[ -f "${HOME}/.cursor/hooks.json" ]] && grep -q 'silver-bullet' "${HOME}/.cursor/hooks.json" 2>/dev/null; then
    hooks_present="yes"
    record pass "hooks" "Silver Bullet hooks referenced in Cursor hooks.json"
  elif [[ -f "${HOME}/.claude/settings.json" ]] && grep -q 'silver-bullet' "${HOME}/.claude/settings.json" 2>/dev/null; then
    hooks_present="yes"
    record pass "hooks" "Silver Bullet hooks referenced in Claude settings"
  else
    record warn "hooks" "no SB hook config detected — enforcement may not fire"
  fi

  if [[ -f "${REPO_ROOT}/hooks/lib/recommended-tools.sh" ]]; then
    # shellcheck source=../hooks/lib/recommended-tools.sh
    source "${REPO_ROOT}/hooks/lib/recommended-tools.sh"
  fi
  if [[ -f "${REPO_ROOT}/hooks/lib/graphify-gate.sh" ]]; then
    # shellcheck source=../hooks/lib/graphify-gate.sh
    source "${REPO_ROOT}/hooks/lib/graphify-gate.sh"
  fi
  if [[ -f "${REPO_ROOT}/hooks/lib/agentmemory-gate.sh" ]]; then
    # shellcheck source=../hooks/lib/agentmemory-gate.sh
    source "${REPO_ROOT}/hooks/lib/agentmemory-gate.sh"
  fi

  local sb_config="${REPO_ROOT}/.silver-bullet.json"
  local graphify_consent="pending"
  local graphify_suspended="false"
  local agentmemory="no"
  local agentmemory_consent="pending"
  local agentmemory_suspended="false"
  if [[ -f "$sb_config" ]] && declare -f sb_recommended_tool_consent >/dev/null 2>&1; then
    graphify_consent="$(sb_recommended_tool_consent "$sb_config" "graphify")"
  fi
  if [[ -f "$sb_config" ]] && declare -f sb_recommended_tool_enforcement_suspended >/dev/null 2>&1; then
    if sb_recommended_tool_enforcement_suspended "$sb_config" "graphify"; then
      graphify_suspended="true"
    fi
  fi

  if command -v graphify >/dev/null 2>&1 || [[ -x "${HOME}/.local/bin/graphify" ]]; then
    graphify="yes"
    if [[ "$graphify_consent" == "enabled" && "$graphify_suspended" != "true" ]]; then
      record pass "graphify-cli" "CLI available (opted in)"
      graph_path="${REPO_ROOT}/graphify-out/graph.json"
      if [[ -f "$sb_config" ]] && declare -f sb_graphify_abs_graph_path >/dev/null 2>&1; then
        graph_path="$(sb_graphify_abs_graph_path "$REPO_ROOT" "$sb_config")"
      fi
      if [[ -f "$graph_path" && ! -L "$graph_path" ]]; then
        record pass "graphify-index" "index present at ${graph_path#"${REPO_ROOT}"/}"
      else
        record fail "graphify-index" "index missing — run: graphify update . --no-cluster"
      fi
      if declare -f sb_runtime_host >/dev/null 2>&1 && declare -f sb_graphify_platform_artifact_present >/dev/null 2>&1; then
        local gf_host artifact_path
        gf_host="$(sb_runtime_host)"
        artifact_path="$(sb_graphify_platform_artifact_path "$REPO_ROOT" "$gf_host")"
        if sb_graphify_platform_artifact_present "$REPO_ROOT" "$gf_host"; then
          record pass "graphify-platform" "platform artifact present (${artifact_path#"${REPO_ROOT}"/}, host=${gf_host})"
        else
          record warn "graphify-platform" "platform artifact missing for ${gf_host} — run post-index install (see docs/GRAPHIFY.md)"
        fi
      fi
    else
      record pass "graphify-cli" "CLI available (consent: ${graphify_consent})"
    fi
  else
    if [[ "$graphify_consent" == "enabled" && "$graphify_suspended" == "true" ]]; then
      record warn "graphify" "opted in but install failed — enforcement suspended; retry on /silver:update"
    elif [[ "$graphify_consent" == "enabled" ]]; then
      record fail "graphify-cli" "not on PATH — user opted in; install: uv tool install graphifyy"
    else
      record warn "graphify" "not on PATH — tier-1 code intelligence unavailable (consent: ${graphify_consent})"
    fi
  fi

  if [[ -f "$sb_config" ]] && declare -f sb_recommended_tool_consent >/dev/null 2>&1; then
    agentmemory_consent="$(sb_recommended_tool_consent "$sb_config" "agentmemory")"
  fi
  if [[ -f "$sb_config" ]] && declare -f sb_recommended_tool_enforcement_suspended >/dev/null 2>&1; then
    if sb_recommended_tool_enforcement_suspended "$sb_config" "agentmemory"; then
      agentmemory_suspended="true"
    fi
  fi

  if command -v agentmemory >/dev/null 2>&1; then
    agentmemory="yes"
    if [[ "$agentmemory_consent" == "enabled" && "$agentmemory_suspended" != "true" ]]; then
      record pass "agentmemory-cli" "CLI available (opted in)"
      if declare -f sb_agentmemory_server_healthy >/dev/null 2>&1; then
        if sb_agentmemory_server_healthy "$sb_config"; then
          record pass "agentmemory-server" "health check OK"
        else
          record fail "agentmemory-server" "server not healthy — start: nohup agentmemory > ~/.agentmemory/server.log 2>&1 &"
        fi
      fi
      if declare -f sb_agentmemory_export_exists >/dev/null 2>&1; then
        if sb_agentmemory_export_exists "$REPO_ROOT" "$sb_config"; then
          record pass "agentmemory-export" ".agentmemory/ export root present"
        else
          record fail "agentmemory-export" "export root missing — mkdir -p .agentmemory/memory"
        fi
      fi
      if declare -f sb_runtime_host >/dev/null 2>&1 && declare -f sb_agentmemory_platform_artifact_present >/dev/null 2>&1; then
        local am_host am_artifact
        am_host="$(sb_runtime_host)"
        am_artifact="$(sb_agentmemory_platform_artifact_path "$REPO_ROOT" "$am_host")"
        if sb_agentmemory_platform_artifact_present "$REPO_ROOT" "$am_host"; then
          record pass "agentmemory-platform" "MCP wired (${am_artifact}, host=${am_host})"
        else
          record warn "agentmemory-platform" "MCP not wired for ${am_host} — see docs/AGENTMEMORY.md"
        fi
      fi
    else
      record pass "agentmemory-cli" "CLI available (consent: ${agentmemory_consent})"
    fi
  else
    if [[ "$agentmemory_consent" == "enabled" && "$agentmemory_suspended" == "true" ]]; then
      record warn "agentmemory" "opted in but install failed — enforcement suspended; retry on /silver:update"
    elif [[ "$agentmemory_consent" == "enabled" ]]; then
      record fail "agentmemory-cli" "not on PATH — user opted in; install: npm install -g @agentmemory/agentmemory"
    else
      record warn "agentmemory" "not on PATH — session capture unavailable (consent: ${agentmemory_consent})"
    fi
  fi

  if [[ -f "${REPO_ROOT}/.codex-plugin/plugin.json" ]]; then
    sb_version="$(jq -r '.version // "unknown"' "${REPO_ROOT}/.codex-plugin/plugin.json" 2>/dev/null || echo unknown)"
  elif [[ -f "${REPO_ROOT}/plugins/silver-bullet/.codex-plugin/plugin.json" ]]; then
    sb_version="$(jq -r '.version // "unknown"' "${REPO_ROOT}/plugins/silver-bullet/.codex-plugin/plugin.json" 2>/dev/null || echo unknown)"
  fi
  record pass "package-version" "$sb_version"

  capability_tier="$(runtime_tier "$hooks_present" "$state_dir")"
  runtime_name="${SB_RUNTIME_NAME:-${SILVER_BULLET_RUNTIME:-unknown}}"
  record pass "runtime-capability-tier" "$capability_tier (${runtime_name}; see docs/RUNTIME-COMPATIBILITY.md)"

  if [[ -d "$state_dir" ]]; then
    record pass "state-root" "$state_dir"
  else
    record warn "state-root" "$state_dir not found yet"
  fi

  if [[ "$FORMAT" == "json" && "$jq_ok" == "yes" ]]; then
    jq -n \
      --arg jq_ok "$jq_ok" \
      --arg hooks "$hooks_present" \
      --arg graphify "$graphify" \
      --arg agentmemory "$agentmemory" \
      --arg version "$sb_version" \
      --arg tier "$capability_tier" \
      --arg runtime_home "$runtime_home" \
      --arg state_dir "$state_dir" \
      --argjson fail "$FAIL" \
      --argjson warn "$WARN" \
      --argjson pass "$PASS" \
      '{jq:$jq_ok, hooks:$hooks, graphify:$graphify, agentmemory:$agentmemory, package_version:$version, capability_tier:$tier, runtime_home:$runtime_home, state_dir:$state_dir, passed:$pass, failures:$fail, warnings:$warn}'
    exit "$([[ "$FAIL" -gt 0 ]] && echo 1 || echo 0)"
  fi

  echo "Results: ${PASS} passed, ${FAIL} failed, ${WARN} warnings"
  if [[ "$FAIL" -gt 0 ]]; then
    exit 1
  fi
}

main "$@"
