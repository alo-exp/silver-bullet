#!/usr/bin/env bash
# Mandatory pre-release host smoke — Claude, Codex, and Cursor skill surface + routing.
#
# Isolation policy: each host uses a dedicated temp root (SB_PRE_RELEASE_SMOKE_ROOT);
# never reads or writes ~/.claude, ~/.codex, or ~/.cursor.
#
# Stage 1 (structural): validate-host-skill-surface.sh — all three hosts.
# Stage 2 (route): per-host invoke-skill / install / CLI smoke without full E2E matrix.
#
# Cursor CLI isolation (official): fake HOME, CURSOR_CONFIG_DIR, --plugin-dir, --workspace.
# Cursor CLI auth: CURSOR_API_KEY env only + AGENT_CLI_CREDENTIAL_STORE=memory.
# Never uses macOS Keychain (cursor-user) or cursor-agent login/status.
#
# Usage:
#   CURSOR_API_KEY=... (or HOST_API_KEY=...) RTK_DISABLED=1 bash scripts/run-pre-release-host-smoke.sh
#   RTK_DISABLED=1 bash scripts/run-pre-release-host-smoke.sh --host cursor
#
# Claude host is skipped only when claude CLI is unavailable (first-class when present).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export SB_PRE_RELEASE_REPO_ROOT="$REPO_ROOT"
INVOKE_ADAPTER="${REPO_ROOT}/scripts/silver-bullet"
SMOKE_SKILL="silver:verify"
SMOKE_SKILL_CANONICAL="silver-verify"

# shellcheck source=scripts/lib/pre-release-host-isolation.sh
source "${SCRIPT_DIR}/lib/pre-release-host-isolation.sh"
# shellcheck source=scripts/lib/agent-bundle-paths.sh
source "${SCRIPT_DIR}/lib/agent-bundle-paths.sh"

# Pin smoke root once for the whole run (subscripts must not create sibling roots).
SB_PRE_RELEASE_SMOKE_ROOT="$(sb_smoke_root)"
export SB_PRE_RELEASE_SMOKE_ROOT

HOST_FILTER="${1:-all}"
if [[ "$HOST_FILTER" == --host ]]; then
  HOST_FILTER="${2:-all}"
fi

PASS=0
FAIL=0
SKIP=0

smoke_pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
smoke_fail() { printf 'FAIL: %s\n' "$1"; FAIL=$((FAIL + 1)); }
smoke_skip() { printf 'SKIP: %s\n' "$1"; SKIP=$((SKIP + 1)); }

trap sb_smoke_cleanup EXIT

assert_invoke_route() {
  local host="$1"
  local agent_root="$2"
  local out=""

  if [[ ! -d "$agent_root" ]]; then
    smoke_fail "${host}: missing agent bundle at ${agent_root}"
    return
  fi

  out="$(
    cd "$REPO_ROOT" && \
      SILVER_BULLET_SKILL_ROOTS="${agent_root}" \
      SB_PLUGIN_ROOT="${REPO_ROOT}/plugins/silver-bullet" \
      bash "$INVOKE_ADAPTER" invoke-skill "$SMOKE_SKILL" 2>&1
  )" || true

  if printf '%s' "$out" | grep -qiE "BEGIN SKILL ${SMOKE_SKILL_CANONICAL}|Skill: ${SMOKE_SKILL_CANONICAL}"; then
    smoke_pass "${host}: invoke-skill routes ${SMOKE_SKILL}"
  else
    smoke_fail "${host}: invoke-skill routes ${SMOKE_SKILL}"
    printf '  snippet: %s\n' "$(printf '%s' "$out" | head -c 300)"
  fi
}

smoke_codex() {
  printf '\n=== Codex host smoke (isolated) ===\n'
  assert_invoke_route "codex" "$(sb_agent_bundle_root "$REPO_ROOT" codex)"

  sb_smoke_begin_codex
  local root
  root="$(sb_smoke_host_root codex)"
  printf '  isolated root: %s\n' "$root"

  if bash "${REPO_ROOT}/scripts/install-codex.sh" >/dev/null 2>&1; then
    smoke_pass "codex: install-codex.sh"
  else
    smoke_fail "codex: install-codex.sh"
    return
  fi
  if SB_DIAG_SMOKE=1 SILVER_BULLET_RUNTIME=codex bash "${REPO_ROOT}/scripts/sb-diagnostics.sh" >/dev/null 2>&1; then
    smoke_pass "codex: sb-diagnostics.sh"
  else
    smoke_fail "codex: sb-diagnostics.sh"
  fi
}

smoke_claude() {
  printf '\n=== Claude host smoke (isolated) ===\n'
  assert_invoke_route "claude" "${REPO_ROOT}/agents/claude"

  local claude_bin="${CLAUDE_BIN:-$(command -v claude 2>/dev/null || true)}"
  if [[ -z "$claude_bin" || ! -x "$claude_bin" ]]; then
    smoke_skip "claude: CLI not available — install claude CLI or set CLAUDE_BIN"
    return
  fi

  sb_smoke_begin_claude
  local root
  root="$(sb_smoke_host_root claude)"
  export CLAUDE_BIN="$claude_bin"
  printf '  isolated root: %s\n' "$root"

  if CLAUDE_BIN="$claude_bin" bash "${REPO_ROOT}/scripts/install-claude.sh" >/dev/null 2>&1; then
    smoke_pass "claude: install-claude.sh"
  else
    smoke_fail "claude: install-claude.sh"
    return
  fi
  if SB_DIAG_SMOKE=1 SILVER_BULLET_RUNTIME=claude bash "${REPO_ROOT}/scripts/sb-diagnostics.sh" >/dev/null 2>&1; then
    smoke_pass "claude: sb-diagnostics.sh"
  else
    smoke_fail "claude: sb-diagnostics.sh"
  fi
}

smoke_cursor() {
  printf '\n=== Cursor host smoke (isolated) ===\n'
  assert_invoke_route "cursor" "$(sb_agent_bundle_root "$REPO_ROOT" cursor)"

  sb_smoke_begin_cursor
  export SB_CURSOR_SMOKE_USE_CURRENT_ENV=1
  printf '  isolated fake-home: %s
' "${SB_SMOKE_CURSOR_FAKE_HOME:-$HOME}"
  printf '  CURSOR_CONFIG_DIR: %s
' "${CURSOR_CONFIG_DIR:-}"
  printf '  workspace: %s
' "${SB_SMOKE_CURSOR_WORKSPACE:-}"
  printf '  plugin-dir: %s
' "${SB_SMOKE_CURSOR_PLUGIN_DIR:-}"

  if SB_CURSOR_SMOKE_USE_CURRENT_ENV=1 bash "${REPO_ROOT}/scripts/release-live-matrix-cursor-smoke.sh"; then
    smoke_pass "cursor: release-live-matrix-cursor-smoke.sh"
  else
    smoke_fail "cursor: release-live-matrix-cursor-smoke.sh"
  fi

  if bash "${REPO_ROOT}/scripts/pre-release-cursor-cli-smoke.sh"; then
    smoke_pass "cursor: pre-release-cursor-cli-smoke.sh"
  else
    smoke_fail "cursor: pre-release-cursor-cli-smoke.sh"
  fi
}

printf '=== Pre-release host smoke ===\n'
printf 'REPO_ROOT=%s\n' "$REPO_ROOT"
printf 'SB_PRE_RELEASE_SMOKE_ROOT=%s\n' "$(sb_smoke_root)"

printf '\n=== Host-agnostic core (SB contract) ===\n'
if bash "${REPO_ROOT}/scripts/validate-host-agnostic-core.sh" --repo-root "$REPO_ROOT"; then
  smoke_pass "structural: validate-host-agnostic-core.sh"
else
  smoke_fail "structural: validate-host-agnostic-core.sh"
fi

printf '\n=== Structural install surface (all hosts) ===\n'
if bash "${REPO_ROOT}/scripts/validate-host-install-surface.sh" --repo-root "$REPO_ROOT"; then
  smoke_pass "structural: validate-host-install-surface.sh"
else
  smoke_fail "structural: validate-host-install-surface.sh"
fi

printf '\n=== Structural skill surface (all hosts) ===\n'
if bash "${REPO_ROOT}/scripts/validate-host-skill-surface.sh" --repo-root "$REPO_ROOT"; then
  smoke_pass "structural: validate-host-skill-surface.sh"
else
  smoke_fail "structural: validate-host-skill-surface.sh"
fi

case "$HOST_FILTER" in
  all)
    smoke_codex
    smoke_cursor
    smoke_claude
    ;;
  codex) smoke_codex ;;
  cursor) smoke_cursor ;;
  claude) smoke_claude ;;
  *)
    printf 'Unknown host: %s (use all|codex|cursor|claude)\n' "$HOST_FILTER" >&2
    exit 2
    ;;
esac

total=$((PASS + FAIL + SKIP))
printf '\nPre-release host smoke: %s passed, %s failed, %s skipped (%s checks)\n' \
  "$PASS" "$FAIL" "$SKIP" "$total"

if [[ "$FAIL" -eq 0 ]]; then
  marker_root="$(sb_smoke_host_root codex)"
  marker_file="${marker_root}/.silver-bullet/pre-release-host-smoke"
  mkdir -p "$(dirname "$marker_file")"
  printf 'hosts=codex,cursor,claude\nstructural=validate-host-skill-surface\ncursor_auth=env-api-key-memory\ncursor_isolation=fake-home,CURSOR_CONFIG_DIR,--plugin-dir,--workspace\n' >"$marker_file"
  printf 'Wrote isolated marker %s\n' "$marker_file"

  if [[ -f "${REPO_ROOT}/hooks/lib/runtime-paths.sh" ]]; then
    # shellcheck source=hooks/lib/runtime-paths.sh
    source "${REPO_ROOT}/hooks/lib/runtime-paths.sh"
    mkdir -p "$(dirname "${SB_RUNTIME_STATE_DIR}/pre-release-host-smoke")"
    dest_marker="${SB_RUNTIME_STATE_DIR}/pre-release-host-smoke"
    if [[ "$marker_file" -ef "$dest_marker" ]]; then
      printf 'Marker already at %s (isolated runtime state)\n' "$dest_marker"
    else
      cp "$marker_file" "$dest_marker"
      printf 'Copied marker to %s\n' "$dest_marker"
    fi
  fi
fi

[[ "$FAIL" -eq 0 ]]
