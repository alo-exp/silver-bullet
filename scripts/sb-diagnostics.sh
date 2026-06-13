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
  if [[ -n "${CODEX_HOME:-}" && -d "${CODEX_HOME}" ]]; then
    printf '%s' "$CODEX_HOME"
    return
  fi
  if [[ -n "${CLAUDE_CONFIG_DIR:-}" && -d "${CLAUDE_CONFIG_DIR}" ]]; then
    printf '%s' "$CLAUDE_CONFIG_DIR"
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
  state_dir="${runtime_home}/.silver-bullet"

  if [[ -f "${runtime_home}/config.toml" ]] && grep -q 'silver-bullet' "${runtime_home}/config.toml" 2>/dev/null; then
    hooks_present="yes"
    record pass "hooks" "Silver Bullet hooks referenced in ${runtime_home}/config.toml"
  elif [[ -f "${HOME}/.claude/settings.json" ]] && grep -q 'silver-bullet' "${HOME}/.claude/settings.json" 2>/dev/null; then
    hooks_present="yes"
    record pass "hooks" "Silver Bullet hooks referenced in Claude settings"
  else
    record warn "hooks" "no SB hook config detected — enforcement may not fire"
  fi

  if command -v graphify >/dev/null 2>&1 || [[ -x "${HOME}/.local/bin/graphify" ]]; then
    graphify="yes"
    record pass "graphify" "CLI available"
  else
    record warn "graphify" "not on PATH — tier-1 code intelligence unavailable"
  fi

  if [[ -f "${REPO_ROOT}/.codex-plugin/plugin.json" ]]; then
    sb_version="$(jq -r '.version // "unknown"' "${REPO_ROOT}/.codex-plugin/plugin.json" 2>/dev/null || echo unknown)"
  elif [[ -f "${REPO_ROOT}/plugins/silver-bullet/.codex-plugin/plugin.json" ]]; then
    sb_version="$(jq -r '.version // "unknown"' "${REPO_ROOT}/plugins/silver-bullet/.codex-plugin/plugin.json" 2>/dev/null || echo unknown)"
  fi
  record pass "package-version" "$sb_version"

  capability_tier="$(runtime_tier "$hooks_present" "$state_dir")"
  record pass "runtime-capability-tier" "$capability_tier (see docs/RUNTIME-COMPATIBILITY.md)"

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
      --arg version "$sb_version" \
      --arg tier "$capability_tier" \
      --arg runtime_home "$runtime_home" \
      --arg state_dir "$state_dir" \
      --argjson fail "$FAIL" \
      --argjson warn "$WARN" \
      --argjson pass "$PASS" \
      '{jq:$jq_ok, hooks:$hooks, graphify:$graphify, package_version:$version, capability_tier:$tier, runtime_home:$runtime_home, state_dir:$state_dir, passed:$pass, failures:$fail, warnings:$warn}'
    exit "$([[ "$FAIL" -gt 0 ]] && echo 1 || echo 0)"
  fi

  echo "Results: ${PASS} passed, ${FAIL} failed, ${WARN} warnings"
  if [[ "$FAIL" -gt 0 ]]; then
    exit 1
  fi
}

main "$@"
