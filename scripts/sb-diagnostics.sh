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
      if [[ "${SB_DIAG_SMOKE:-}" == "1" ]]; then
        case "$check" in
          graphify-*|agentmemory-*|rtk-*|context-mode-*|optimize-*)
            [[ "$FORMAT" == "json" ]] || echo "WARN: $check — $detail"
            (( WARN++ )) || true
            return 0
            ;;
        esac
      fi
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
  if [[ -f "${REPO_ROOT}/hooks/lib/rtk-gate.sh" ]]; then
    # shellcheck source=../hooks/lib/rtk-gate.sh
    source "${REPO_ROOT}/hooks/lib/rtk-gate.sh"
  fi
  if [[ -f "${REPO_ROOT}/hooks/lib/context-mode-gate.sh" ]]; then
    # shellcheck source=../hooks/lib/context-mode-gate.sh
    source "${REPO_ROOT}/hooks/lib/context-mode-gate.sh"
  fi
  if [[ -f "${REPO_ROOT}/hooks/lib/stack-optimizer.sh" ]]; then
    # shellcheck source=../hooks/lib/stack-optimizer.sh
    source "${REPO_ROOT}/hooks/lib/stack-optimizer.sh"
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

  if declare -f sb_optimization_score >/dev/null 2>&1 && [[ -f "$sb_config" ]]; then
    if [[ "$graphify_consent" == "enabled" || "$agentmemory_consent" == "enabled" ]]; then
      local opt_score opt_fails
      opt_score="$(sb_optimization_score "$REPO_ROOT" "$sb_config")"
      opt_fails="${SB_STACK_SCORE_FAILS:-0}"
      if [[ "$opt_fails" -eq 0 && "$opt_score" -ge 60 ]]; then
        record pass "optimize-score" "stack optimization ${opt_score}/100"
      elif [[ "$opt_fails" -eq 0 ]]; then
        record warn "optimize-score" "stack optimization ${opt_score}/100 — run sb-optimize-stack.sh --apply"
      else
        record fail "optimize-score" "stack optimization ${opt_score}/100 with ${opt_fails} critical gap(s)"
      fi
      if [[ "$graphify_consent" == "enabled" && "$graphify_suspended" != "true" ]]; then
        if declare -f sb_stack_graphify_hooks_installed >/dev/null 2>&1 && sb_stack_graphify_hooks_installed "$REPO_ROOT"; then
          record pass "optimize-graphify-hooks" "git hooks installed"
        else
          record warn "optimize-graphify-hooks" "git hooks missing"
        fi
      fi
      if [[ "$agentmemory_consent" == "enabled" && "$agentmemory_suspended" != "true" ]]; then
        if declare -f sb_stack_server_persistence_ok >/dev/null 2>&1 && sb_stack_server_persistence_ok "$sb_config"; then
          record pass "optimize-agentmemory-persistence" "server persistence OK"
        else
          record warn "optimize-agentmemory-persistence" "launchd/systemd not detected"
        fi
        if declare -f sb_stack_bridge_running >/dev/null 2>&1 && sb_stack_bridge_running; then
          record pass "optimize-agentmemory-bridge" "bridge running"
        else
          record warn "optimize-agentmemory-bridge" "bridge not running"
        fi
        if declare -f sb_stack_gitleaks_required >/dev/null 2>&1 \
          && sb_stack_gitleaks_required "$sb_config" \
          && declare -f sb_stack_gitleaks_path >/dev/null 2>&1; then
          if sb_stack_gitleaks_path >/dev/null; then
            record pass "optimize-gitleaks" "gitleaks installed ($(sb_stack_gitleaks_path))"
          else
            record warn "optimize-gitleaks" "gitleaks required but missing — brew install gitleaks"
          fi
        fi
      fi
      if [[ "$graphify_consent" == "enabled" && "$agentmemory_consent" == "enabled" ]]; then
        if declare -f sb_stack_graph_has_agentmemory_refs >/dev/null 2>&1 && sb_stack_graph_has_agentmemory_refs "$REPO_ROOT" "$sb_config"; then
          record pass "optimize-synergy-index" "graph indexes .agentmemory"
        else
          record fail "optimize-synergy-index" "graph missing .agentmemory refs — run sb-optimize-stack.sh --apply"
        fi
      fi
    fi
  fi

  local rtk_consent="pending" rtk_suspended="false"
  local cm_consent="pending" cm_suspended="false"
  if [[ -f "$sb_config" ]] && declare -f sb_recommended_tool_consent >/dev/null 2>&1; then
    rtk_consent="$(sb_recommended_tool_consent "$sb_config" "rtk")"
    cm_consent="$(sb_recommended_tool_consent "$sb_config" "context_mode")"
  fi
  if [[ -f "$sb_config" ]] && declare -f sb_recommended_tool_enforcement_suspended >/dev/null 2>&1; then
    sb_recommended_tool_enforcement_suspended "$sb_config" "rtk" && rtk_suspended="true"
    sb_recommended_tool_enforcement_suspended "$sb_config" "context_mode" && cm_suspended="true"
  fi

  if declare -f sb_rtk_cli_available >/dev/null 2>&1; then
    if sb_rtk_cli_path >/dev/null 2>&1 && ! sb_rtk_cli_available 2>/dev/null; then
      record warn "rtk-wrong-binary" "wrong rtk on PATH (Rust Type Kit?) — install rtk-ai/rtk"
    elif sb_rtk_cli_available 2>/dev/null; then
      if [[ "$rtk_consent" == "enabled" && "$rtk_suspended" != "true" ]]; then
        record pass "rtk-cli" "CLI available (opted in)"
        if sb_rtk_version_ok "$sb_config" 2>/dev/null; then
          record pass "rtk-version" "version OK (v0.4x)"
        else
          record fail "rtk-version" "version too old — upgrade rtk-ai/rtk"
        fi
        local rtk_host
        rtk_host="$(sb_runtime_host)"
        if sb_rtk_platform_hook_present "$REPO_ROOT" "$rtk_host" 2>/dev/null; then
          record pass "rtk-hook" "host hook wired (host=${rtk_host})"
        else
          record fail "rtk-hook" "host hook missing — run rtk init for ${rtk_host}"
        fi
      else
        record pass "rtk-cli" "CLI available (consent: ${rtk_consent})"
      fi
    else
      if [[ "$rtk_consent" == "enabled" && "$rtk_suspended" == "true" ]]; then
        record warn "rtk" "opted in but install failed — enforcement suspended"
      elif [[ "$rtk_consent" == "enabled" ]]; then
        record fail "rtk-cli" "not on PATH — user opted in; see docs/RTK.md"
      else
        record warn "rtk" "not on PATH (consent: ${rtk_consent})"
      fi
    fi
  fi

  if declare -f sb_context_mode_cli_available >/dev/null 2>&1; then
    if [[ "$cm_consent" == "enabled" && "$cm_suspended" == "true" ]]; then
      record warn "context-mode" "opted in but install failed — enforcement suspended"
    elif [[ "$cm_consent" == "enabled" ]]; then
      if declare -f sb_context_mode_node_ok >/dev/null 2>&1 && ! sb_context_mode_node_ok "$sb_config" 2>/dev/null; then
        record fail "context-mode-node" "Node < 22.5 — upgrade before Context Mode"
      elif sb_context_mode_cli_available 2>/dev/null; then
        record pass "context-mode-cli" "CLI or plugin present (opted in)"
        local cm_host
        cm_host="$(sb_runtime_host)"
        if sb_context_mode_platform_artifact_present "$REPO_ROOT" "$cm_host" 2>/dev/null; then
          record pass "context-mode-mcp" "platform wired (host=${cm_host})"
        else
          record fail "context-mode-mcp" "MCP/plugin not wired — see docs/CONTEXT-MODE.md"
        fi
        if sb_context_mode_instruction_fragment_present "$REPO_ROOT" 2>/dev/null; then
          record pass "context-mode-fragment" "instruction fragment present"
        else
          record warn "context-mode-fragment" "hint fragment missing — run init scaffold"
        fi
      else
        record fail "context-mode-cli" "not installed — npm install -g context-mode"
      fi
    elif sb_context_mode_cli_available 2>/dev/null; then
      record pass "context-mode-cli" "CLI available (consent: ${cm_consent})"
    else
      record warn "context-mode" "not installed (consent: ${cm_consent})"
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
