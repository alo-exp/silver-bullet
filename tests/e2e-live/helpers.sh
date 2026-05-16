#!/usr/bin/env bash
# Shared helpers for the live todo-app E2E suite.
#
# The suite runs Claude and Codex against an isolated copy of the standalone
# sibling test-todo-app repo, then resets the workspace after each scenario.
# The real SB state files are backed up and restored around each scenario so
# the suite can run repeatedly without cross-talk. Claude keeps using
# ~/.claude/.silver-bullet; Kay uses the temp-root .kay/.silver-bullet tree.

set -euo pipefail

PATH="/Users/shafqat/.local/bin:/opt/homebrew/bin:/Applications/Codex.app/Contents/Resources:${PATH:-/usr/bin:/bin:/usr/sbin:/sbin}"
export PATH

E2E_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SB_ROOT="$(cd "${E2E_ROOT}/../.." && pwd)"
DEFAULT_TEST_TODO_APP_ROOT="$(cd "${SB_ROOT}/../.." && pwd)/test-todo-app"
FIXTURE_DIR="${SB_TEST_TODO_APP_ROOT:-${DEFAULT_TEST_TODO_APP_ROOT}}"
AGENT_DIR="${SB_ROOT}/tests/live/agents"
LIB_DIR="${E2E_ROOT}/lib"
CLAUDE_INSTALL_SCRIPT="${SB_ROOT}/scripts/install-claude.sh"

E2E_RUNTIME="${SB_E2E_LIVE_RUNTIME:-${SB_LIVE_RUNTIME:-claude}}"
KAY_SB_TEST_HOME="${KAY_SB_TEST_HOME:-${SB_LIVE_CODEX_ISOLATION_DIR:-}}"
if [[ "$E2E_RUNTIME" == "kay" || "$E2E_RUNTIME" == "codex" ]]; then
  SB_TEST_DIR="${KAY_SB_TEST_HOME}/.kay/.silver-bullet"
  MCP_AUTH_CACHE="${KAY_SB_TEST_HOME}/.kay/mcp-needs-auth-cache.json"
  MCP_AUTH_CACHE_BACKUP="${KAY_SB_TEST_HOME}/.kay/mcp-needs-auth-cache.e2e-live-backup-$$"
else
  SB_TEST_DIR="${HOME}/.claude/.silver-bullet"
  MCP_AUTH_CACHE="${HOME}/.claude/mcp-needs-auth-cache.json"
  MCP_AUTH_CACHE_BACKUP="${SB_TEST_DIR}/mcp-needs-auth-cache.e2e-live-backup-$$"
fi
INLINE_E2E_MATRIX_FILE="${SB_TEST_DIR}/inline-e2e-matrix"
E2E_LIVE_MATRIX_FILE="${SB_TEST_DIR}/e2e-live-matrix"
# shellcheck disable=SC2034 # Reserved for live-run budget enforcement.
MAX_BUDGET="${SB_E2E_LIVE_BUDGET_USD:-10.00}"
APP_PORT="${SB_E2E_LIVE_PORT:-3456}"
export APP_PORT

WORK_DIR=""
REMOTE_DIR=""
RELEASE_WORK_DIR=""
APP_SERVER_PID=""
APP_SERVER_LOG=""
BRANCH_FILE=""
CLAUDE_PROMPT_COUNT=0
CLAUDE_INTERACTIVE_INVOKE="${SB_ROOT}/scripts/claude-interactive-invoke.expect"
STATE_FILE="${SB_TEST_DIR}/state"
TRIVIAL_FILE="${SB_TEST_DIR}/trivial"
SESSION_INIT_FILE="${SB_TEST_DIR}/session-init"
STATE_BACKUP="${SB_TEST_DIR}/state.e2e-live-backup-$$"
TRIVIAL_BACKUP="${SB_TEST_DIR}/trivial.e2e-live-backup-$$"
SESSION_INIT_BACKUP="${SB_TEST_DIR}/session-init.e2e-live-backup-$$"
PASS=0
FAIL=0

if [[ ! -d "$FIXTURE_DIR" ]]; then
  printf 'ERROR: todo-app fixture repo not found at %s\n' "$FIXTURE_DIR" >&2
  exit 1
fi

CLAUDE_LEGACY_PLUGINS=(
  "data-engineering@claude-plugins-official"
  "frontend-design@claude-plugins-official"
  "product-tracking-skills@claude-plugins-official"
)

CLAUDE_REQUIRED_PLUGINS=(
  "superpowers@superpowers-marketplace"
  "engineering@knowledge-work-plugins"
  "design@knowledge-work-plugins"
  "product-management@knowledge-work-plugins"
  "silver-bullet@alo-labs"
)

case "$E2E_RUNTIME" in
  claude)
    # shellcheck source=tests/live/agents/claude/agent.sh
    source "$AGENT_DIR/claude/agent.sh"
    ;;
  kay|codex)
    # shellcheck source=tests/live/agents/kay/agent.sh
    source "$AGENT_DIR/kay/agent.sh"
    ;;
  *)
    printf 'ERROR: unsupported e2e live agent: %s\n' "$E2E_RUNTIME" >&2
    exit 2
    ;;
esac

if [[ -f "${LIB_DIR}/coverage-ledger.sh" ]]; then
  # shellcheck disable=SC1090
  source "${LIB_DIR}/coverage-ledger.sh"
fi
if [[ -f "${LIB_DIR}/turn-driver.sh" ]]; then
  # shellcheck disable=SC1090
  source "${LIB_DIR}/turn-driver.sh"
fi

backup_session_state() {
  mkdir -p "$SB_TEST_DIR"
  if [[ -f "$STATE_FILE" ]]; then
    cp "$STATE_FILE" "$STATE_BACKUP"
  else
    rm -f "$STATE_BACKUP"
  fi

  if [[ -f "$TRIVIAL_FILE" ]]; then
    cp "$TRIVIAL_FILE" "$TRIVIAL_BACKUP"
  else
    rm -f "$TRIVIAL_BACKUP"
  fi

  if [[ -f "$SESSION_INIT_FILE" ]]; then
    cp "$SESSION_INIT_FILE" "$SESSION_INIT_BACKUP"
  else
    rm -f "$SESSION_INIT_BACKUP"
  fi

  if [[ -f "$MCP_AUTH_CACHE" ]]; then
    cp "$MCP_AUTH_CACHE" "$MCP_AUTH_CACHE_BACKUP"
  else
    rm -f "$MCP_AUTH_CACHE_BACKUP"
  fi
  printf '{}\n' > "$MCP_AUTH_CACHE"
}

restore_session_state() {
  if [[ -f "$STATE_BACKUP" ]]; then
    mv "$STATE_BACKUP" "$STATE_FILE"
  else
    rm -f "$STATE_FILE"
  fi

  if [[ -f "$TRIVIAL_BACKUP" ]]; then
    mv "$TRIVIAL_BACKUP" "$TRIVIAL_FILE"
  else
    rm -f "$TRIVIAL_FILE"
  fi

  if [[ -f "$SESSION_INIT_BACKUP" ]]; then
    mv "$SESSION_INIT_BACKUP" "$SESSION_INIT_FILE"
  else
    rm -f "$SESSION_INIT_FILE"
  fi

  if [[ -f "$MCP_AUTH_CACHE_BACKUP" ]]; then
    mv "$MCP_AUTH_CACHE_BACKUP" "$MCP_AUTH_CACHE"
  else
    rm -f "$MCP_AUTH_CACHE"
  fi
}

write_inline_e2e_matrix_marker() {
  mkdir -p "$SB_TEST_DIR"
  cat > "$INLINE_E2E_MATRIX_FILE" <<'EOF'
matrix=inline-full-surface
EOF
}

write_e2e_live_matrix_marker() {
  mkdir -p "$SB_TEST_DIR"
  local marker="full-claude-codex"
  if [[ "${SB_ALLOW_CODEX_ONLY_LIVE_RELEASE:-0}" == "1" || "${SB_E2E_LIVE_RUNTIMES:-}" == "codex" ]]; then
    marker="codex-only"
  fi
  cat > "$E2E_LIVE_MATRIX_FILE" <<EOF
matrix=${marker}
EOF
}

dependency_access_preflight_file() {
  printf '%s\n' "${E2E_LIVE_DEPENDENCY_PREFLIGHT_FILE:-}"
}

dependency_access_preflight_ready() {
  local marker_file
  marker_file="$(dependency_access_preflight_file)"
  [[ -n "$marker_file" && -f "$marker_file" ]]
}

write_dependency_access_preflight_marker() {
  local marker_file
  marker_file="$(dependency_access_preflight_file)"
  [[ -n "$marker_file" ]] || return 0
  mkdir -p "$(dirname "$marker_file")"
  cat > "$marker_file" <<EOF
agent=${E2E_RUNTIME}
checked_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
}

clear_inline_e2e_matrix_marker() {
  rm -f "$INLINE_E2E_MATRIX_FILE"
}

port_is_available() {
  local port="$1"
  python3 - "$port" <<'PY'
import socket
import sys

port = int(sys.argv[1])
sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
try:
    sock.bind(("127.0.0.1", port))
except OSError:
    sys.exit(1)
finally:
    sock.close()
sys.exit(0)
PY
}

pick_free_port() {
  python3 - <<'PY'
import socket

sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.bind(("127.0.0.1", 0))
print(sock.getsockname()[1])
sock.close()
PY
}

write_quality_gate_state_marker() {
  local gate_file="${SB_TEST_DIR}/quality-gate-state"
  mkdir -p "$(dirname "$gate_file")"
  cat > "$gate_file" <<'EOF'
quality-gate-stage-1
quality-gate-stage-2
quality-gate-stage-3
quality-gate-stage-4
full-test-suite-rerun
EOF
}

prepare_workspace() {
  local mode="${1:-baseline}"
  local disabled_mcpjson_servers_json="[]"

  if [[ -f "$MCP_AUTH_CACHE" ]]; then
    disabled_mcpjson_servers_json="$(jq -c 'keys' "$MCP_AUTH_CACHE" 2>/dev/null || printf '[]')"
  fi

  backup_session_state
  WORK_DIR="$(mktemp -d)"
  APP_SERVER_LOG="${WORK_DIR}/server.log"

  rsync -a --exclude '.git' "${FIXTURE_DIR}/" "${WORK_DIR}/"

  mkdir -p "${WORK_DIR}/.claude"
  python3 - "${WORK_DIR}/.claude/settings.local.json" "$disabled_mcpjson_servers_json" <<'PY'
from pathlib import Path
import json
import sys

path = Path(sys.argv[1])
disabled = json.loads(sys.argv[2]) if len(sys.argv) > 2 else []
payload = {
    "permissions": {"defaultMode": "auto"},
    "enableAllProjectMcpServers": False,
    "disabledMcpjsonServers": disabled,
}
path.write_text(json.dumps(payload, indent=2) + "\n")
PY

  if [[ "$mode" == "clean-sb" ]]; then
    rm -rf \
      "${WORK_DIR}/.planning" \
      "${WORK_DIR}/.silver-bullet.json" \
      "${WORK_DIR}/silver-bullet.md" \
      "${WORK_DIR}/CLAUDE.md" \
      "${WORK_DIR}/AGENTS.md" \
      "${WORK_DIR}/AGENTS.override.md" \
      "${WORK_DIR}/docs/workflows" \
      "${WORK_DIR}/docs/sessions" \
      "${WORK_DIR}/docs/silver-forensics" \
      "${WORK_DIR}/docs/CHANGELOG.md" \
      "${WORK_DIR}/docs/KNOWLEDGE.md" \
      "${WORK_DIR}/docs/PRD-Overview.md" \
      "${WORK_DIR}/docs/Architecture-and-Design.md" \
      "${WORK_DIR}/docs/Testing-Strategy-and-Plan.md" \
      "${WORK_DIR}/docs/CICD.md"
  fi

  git -C "$WORK_DIR" init -q
  git -C "$WORK_DIR" config user.email "e2e-live@silver-bullet.test"
  git -C "$WORK_DIR" config user.name "E2E Live"
  git -C "$WORK_DIR" add -A
  git -C "$WORK_DIR" commit -q -m "initial: todo app baseline" 2>/dev/null || true
  git -C "$WORK_DIR" checkout -q -b feature/e2e-live 2>/dev/null || true

  REMOTE_DIR="$(mktemp -d "${WORK_DIR%/*}/remote.XXXXXX")"
  git -C "$WORK_DIR" init -q --bare "$REMOTE_DIR"
  git -C "$WORK_DIR" remote add origin "$REMOTE_DIR"
  git -C "$WORK_DIR" push -u origin feature/e2e-live >/dev/null 2>&1 || true

  mkdir -p "$SB_TEST_DIR"
  BRANCH_FILE="${SB_TEST_DIR}/test-branch-e2e-live-$$"
  printf 'feature/e2e-live\n' > "$BRANCH_FILE"
  export SILVER_BULLET_BRANCH_FILE="$BRANCH_FILE"

  if [[ -f "$STATE_FILE" ]]; then
    cp "$STATE_FILE" "$STATE_BACKUP"
  else
    rm -f "$STATE_BACKUP"
  fi
  : > "$STATE_FILE"

  if [[ -f "$TRIVIAL_FILE" ]]; then
    cp "$TRIVIAL_FILE" "$TRIVIAL_BACKUP"
    rm -f "$TRIVIAL_FILE"
  else
    rm -f "$TRIVIAL_BACKUP"
  fi

  rm -f "$SESSION_INIT_FILE"

  agent_preflight

  if [[ -f "${WORK_DIR}/package-lock.json" || -f "${WORK_DIR}/package.json" ]]; then
    (cd "$WORK_DIR" && npm install --silent >/dev/null 2>&1)
  fi

  if [[ "$E2E_RUNTIME" == "claude" ]]; then
    CLAUDE_PROMPT_COUNT=0
    bootstrap_claude_dependencies
  fi
}

cleanup_workspace() {
  if [[ -n "${APP_SERVER_PID:-}" ]] && kill -0 "$APP_SERVER_PID" >/dev/null 2>&1; then
    kill "$APP_SERVER_PID" >/dev/null 2>&1 || true
    wait "$APP_SERVER_PID" >/dev/null 2>&1 || true
  fi
  APP_SERVER_PID=""

  if [[ -n "${WORK_DIR:-}" && -d "$WORK_DIR" ]]; then
    rm -rf "$WORK_DIR"
  fi
  WORK_DIR=""

  if [[ -n "${REMOTE_DIR:-}" && -d "$REMOTE_DIR" ]]; then
    rm -rf "$REMOTE_DIR"
  fi
  REMOTE_DIR=""

  if [[ -n "${RELEASE_WORK_DIR:-}" && -d "$RELEASE_WORK_DIR" && "$RELEASE_WORK_DIR" != "$WORK_DIR" ]]; then
    rm -rf "$RELEASE_WORK_DIR"
  fi
  RELEASE_WORK_DIR=""

  rm -rf "${SB_TEST_DIR}"/turn-logs-* 2>/dev/null || true
  rm -f "${SB_TEST_DIR}"/dependency-access-preflight-* 2>/dev/null || true
  if [[ -n "${BRANCH_FILE:-}" ]]; then
    rm -f "$BRANCH_FILE"
  fi
  unset SILVER_BULLET_BRANCH_FILE
  restore_session_state
}

trap cleanup_workspace EXIT

start_app_server() {
  local ready=0
  local requested_port="$APP_PORT"
  if ! port_is_available "$requested_port"; then
    APP_PORT="$(pick_free_port)"
    export APP_PORT
    echo "INFO: requested app port ${requested_port} was busy; using ${APP_PORT}" >&2
  fi
  (cd "$WORK_DIR" && PORT="$APP_PORT" node src/server.js >"$APP_SERVER_LOG" 2>&1 & echo $! > "${WORK_DIR}/server.pid")
  APP_SERVER_PID="$(cat "${WORK_DIR}/server.pid")"

  for _ in $(seq 1 30); do
    if curl -fsS "http://127.0.0.1:${APP_PORT}/api/health" >/dev/null 2>&1; then
      ready=1
      break
    fi
    sleep 1
  done

  if [[ $ready -ne 1 ]]; then
    printf 'ERROR: app server failed to start.\n' >&2
    if [[ -f "$APP_SERVER_LOG" ]]; then
      tail -n 80 "$APP_SERVER_LOG" >&2 || true
    fi
    return 1
  fi
}

stop_app_server() {
  if [[ -n "${APP_SERVER_PID:-}" ]] && kill -0 "$APP_SERVER_PID" >/dev/null 2>&1; then
    kill "$APP_SERVER_PID" >/dev/null 2>&1 || true
    wait "$APP_SERVER_PID" >/dev/null 2>&1 || true
  fi
  APP_SERVER_PID=""
}

seed_workspace_requested_skills() {
  local prompt="$1"
  local payload

  [[ -x "${SB_ROOT}/hooks/record-requested-skill.sh" ]] || return 0
  payload="$(jq -n --arg p "$prompt" '{hook_event_name:"UserPromptSubmit", prompt:$p}')"

  (
    cd "$WORK_DIR"
    SILVER_BULLET_STATE_FILE="$STATE_FILE" \
      bash "${SB_ROOT}/hooks/record-requested-skill.sh" <<<"$payload" >/dev/null 2>&1 || true
  )
}

run_prompt() {
  local prompt="$1"
  seed_workspace_requested_skills "$prompt"
  if [[ "$E2E_RUNTIME" == "claude" ]]; then
    claude_interactive_invoke permissive "$prompt"
  else
    agent_invoke permissive "$prompt"
  fi
}

run_prompt_strict() {
  local prompt="$1"
  seed_workspace_requested_skills "$prompt"
  if [[ "$E2E_RUNTIME" == "claude" ]]; then
    claude_interactive_invoke default "$prompt"
  else
    agent_invoke default "$prompt"
  fi
}

claude_interactive_invoke() {
  local mode="$1"
  local prompt="$2"
  local prompt_file
  local permission_mode
  local continue_flag
  local output

  prompt_file="$(mktemp "${WORK_DIR}/claude-prompt.XXXXXX")"
  printf '%s' "$prompt" > "$prompt_file"

  permission_mode="${CLAUDE_PERMISSION_MODE:-default}"
  if [[ "$mode" == "permissive" ]]; then
    permission_mode="acceptEdits"
  fi

  continue_flag=0
  if [[ "${CLAUDE_PROMPT_COUNT:-0}" -gt 0 ]]; then
    continue_flag=1
  fi

  output=$(
    cd "$WORK_DIR" && \
      CLAUDE_WORK_DIR="$WORK_DIR" \
      CLAUDE_PROMPT_FILE="$prompt_file" \
      CLAUDE_MODEL="${CLAUDE_MODEL:-sonnet}" \
      CLAUDE_EFFORT="${CLAUDE_EFFORT:-low}" \
      CLAUDE_PERMISSION_MODE="$permission_mode" \
      CLAUDE_INTERACTIVE_QUIET_TIMEOUT="${CLAUDE_INTERACTIVE_QUIET_TIMEOUT:-600}" \
      CLAUDE_CONTINUE="$continue_flag" \
      expect "$CLAUDE_INTERACTIVE_INVOKE"
  ) || true

  rm -f "$prompt_file"
  printf '%s' "$output"

  CLAUDE_PROMPT_COUNT=$((CLAUDE_PROMPT_COUNT + 1))
}

claude_plugin_installed() {
  local plugin_id="$1"
  local cli

  cli="$(agent_cli_path)"
  (cd "$WORK_DIR" && "$cli" plugin list --json 2>/dev/null \
    | jq -e --arg id "$plugin_id" 'any(.[]?; .id == $id)' >/dev/null 2>&1)
}

claude_plugin_installed_in_scope() {
  local plugin_id="$1"
  local scope="$2"
  local cli

  cli="$(agent_cli_path)"
  (cd "$WORK_DIR" && "$cli" plugin list --json 2>/dev/null \
    | jq -e --arg id "$plugin_id" --arg scope "$scope" 'any(.[]?; .id == $id and .scope == $scope)' >/dev/null 2>&1)
}

claude_bootstrap_needed() {
  local plugin_id

  for plugin_id in "${CLAUDE_LEGACY_PLUGINS[@]}"; do
    if claude_plugin_installed "$plugin_id"; then
      return 0
    fi
  done

  for plugin_id in "${CLAUDE_REQUIRED_PLUGINS[@]}"; do
    if ! claude_plugin_installed_in_scope "$plugin_id" "user"; then
      return 0
    fi
  done

  return 1
}

bootstrap_claude_dependencies() {
  if [[ ! -x "$CLAUDE_INSTALL_SCRIPT" ]]; then
    printf 'ERROR: Claude installer script missing at %s\n' "$CLAUDE_INSTALL_SCRIPT" >&2
    return 1
  fi
  "$CLAUDE_INSTALL_SCRIPT" --purge-legacy-plugins >/dev/null
}

codex_config_file() {
  local config_file
  for config_file in "${HOME}/.codex/config.toml" "${HOME}/.codex/config.toml"; do
    if [[ -f "$config_file" ]]; then
      printf '%s\n' "$config_file"
      return 0
    fi
  done
  printf '%s\n' "${HOME}/.codex/config.toml"
}

codex_marketplace_root() {
  local marketplace_root
  for marketplace_root in \
    "${HOME}/.codex/.tmp/marketplaces/alo-labs-codex" \
    "${HOME}/.codex/.tmp/marketplaces/alo-labs-codex"; do
    if [[ -d "$marketplace_root" ]]; then
      printf '%s\n' "$marketplace_root"
      return 0
    fi
  done
  printf '%s\n' "${HOME}/.codex/.tmp/marketplaces/alo-labs-codex"
}

codex_installed_plugins_file() {
  local registry_file
  for registry_file in \
    "${HOME}/.codex/plugins/installed_plugins.json" \
    "${HOME}/.codex/plugins/installed_plugins.json"; do
    if [[ -f "$registry_file" ]]; then
      printf '%s\n' "$registry_file"
      return 0
    fi
  done
  printf '%s\n' "${HOME}/.codex/plugins/installed_plugins.json"
}

codex_plugin_registered() {
  local plugin_id="$1"
  local registry_file

  registry_file="$(codex_installed_plugins_file)"
  [[ -f "$registry_file" ]] || return 1

  jq -e --arg id "$plugin_id" '.plugins | has($id)' "$registry_file" >/dev/null 2>&1
}

codex_plugin_registered_any() {
  local plugin_id
  for plugin_id in "$@"; do
    if codex_plugin_registered "$plugin_id"; then
      return 0
    fi
  done
  return 1
}

codex_plugin_install_path() {
  local plugin_id="$1"
  local registry_file

  registry_file="$(codex_installed_plugins_file)"
  [[ -f "$registry_file" ]] || return 1

  jq -r --arg id "$plugin_id" '.plugins[$id][0].installPath // empty' "$registry_file" 2>/dev/null
}

codex_plugin_surface_exists_any() {
  local registry_file
  local plugin_id
  local install_path
  local surface
  local plugin_ids=()
  local surfaces=()

  registry_file="$(codex_installed_plugins_file)"
  [[ -f "$registry_file" ]] || return 1

  while [[ $# -gt 0 && "$1" != "--" ]]; do
    plugin_ids+=("$1")
    shift
  done
  [[ "${1:-}" == "--" ]] || return 1
  shift
  surfaces=("$@")

  for plugin_id in "${plugin_ids[@]}"; do
    if ! codex_plugin_registered "$plugin_id"; then
      continue
    fi

    install_path="$(codex_plugin_install_path "$plugin_id")"
    [[ -n "$install_path" && -d "$install_path" ]] || continue

    for surface in "${surfaces[@]}"; do
      if [[ -e "$install_path/$surface" ]]; then
        return 0
      fi
    done
  done

  return 1
}

refresh_runtime_installation() {
  if [[ "$E2E_RUNTIME" == "claude" ]]; then
    bootstrap_claude_dependencies
  else
    (cd "$SB_ROOT" && ./scripts/install-codex.sh --purge-legacy-skills >/dev/null)
  fi
}

verify_runtime_dependency_access() {
  if [[ "$E2E_RUNTIME" == "claude" ]]; then
    assert_command_succeeds "Claude Silver Bullet plugin installed" claude_plugin_installed_in_scope "silver-bullet@alo-labs" "user"
    assert_command_succeeds "Claude Superpowers plugin installed" claude_plugin_installed_in_scope "superpowers@superpowers-marketplace" "user"
    assert_command_succeeds "Claude engineering plugin installed" claude_plugin_installed_in_scope "engineering@knowledge-work-plugins" "user"
    assert_command_succeeds "Claude design plugin installed" claude_plugin_installed_in_scope "design@knowledge-work-plugins" "user"
    assert_command_succeeds "Claude product-management plugin installed" claude_plugin_installed_in_scope "product-management@knowledge-work-plugins" "user"
    if claude_plugin_installed "using-silver-bullet"; then
      echo "FAIL: legacy using-silver-bullet alias should not be installed"
      FAIL=$((FAIL + 1))
    else
      echo "PASS: legacy using-silver-bullet alias is absent"
      PASS=$((PASS + 1))
    fi
    local claude_cache_root latest_claude_cache
    claude_cache_root="${HOME}/.claude/plugins/cache/alo-labs/silver-bullet"
    latest_claude_cache="$(find "$claude_cache_root" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -V | tail -n 1)"
    if [[ -n "$latest_claude_cache" && -d "$latest_claude_cache" ]]; then
      assert_file_exists "Claude Silver Bullet init skill synced" "$latest_claude_cache/skills/silver-init/SKILL.md"
      assert_file_exists "Claude Silver Bullet ensure-docs skill synced" "$latest_claude_cache/skills/silver-ensure-docs/SKILL.md"
      assert_file_exists "Claude Silver Bullet feature skill synced" "$latest_claude_cache/skills/silver-feature/SKILL.md"
      assert_file_exists "Claude Silver Bullet router skill synced" "$latest_claude_cache/skills/silver/SKILL.md"
      assert_file_contains "Claude Silver Bullet init skill uses silver prefix" "$latest_claude_cache/skills/silver-init/SKILL.md" 'name: silver:init'
      assert_file_contains "Claude Silver Bullet ensure-docs skill uses silver prefix" "$latest_claude_cache/skills/silver-ensure-docs/SKILL.md" 'name: silver:ensure-docs'
      assert_file_contains "Claude Silver Bullet feature skill uses silver prefix" "$latest_claude_cache/skills/silver-feature/SKILL.md" 'name: silver:feature'
      assert_file_contains "Claude Silver Bullet router skill uses silver name" "$latest_claude_cache/skills/silver/SKILL.md" 'name: silver'
    else
      echo "FAIL: Claude Silver Bullet cache root missing: $claude_cache_root"
      FAIL=$((FAIL + 1))
    fi
  else
    local config_file
    local marketplace_root
    local installed_plugins_file
    config_file="$(codex_config_file)"
    marketplace_root="$(codex_marketplace_root)"
    installed_plugins_file="$(codex_installed_plugins_file)"

    assert_file_contains "Codex plugin hooks feature enabled" "$config_file" 'plugin_hooks = true'
    assert_file_contains "Codex Silver Bullet marketplace registered" "$config_file" '\[marketplaces\.alo-labs-codex\]'
    assert_file_contains "Codex GSD marketplace registered" "$config_file" '\[marketplaces\.get-shit-done-marketplace\]'
    assert_file_contains "Codex Superpowers marketplace registered" "$config_file" '\[marketplaces\.superpowers-marketplace\]'
    assert_command_succeeds "Codex Silver Bullet plugin registered for preflight" codex_plugin_registered "silver-bullet@alo-labs-codex"
    assert_file_contains "Codex Superpowers plugin enabled" "$config_file" '\[plugins\."superpowers@superpowers-marketplace"\]'
    assert_file_contains "Codex GSD plugin enabled" "$config_file" '\[plugins\."gsd@get-shit-done-marketplace"\]'
    assert_file_contains "Codex engineering plugin enabled" "$config_file" '\[plugins\."engineering@alo-labs-codex(-local)?"\]'
    assert_file_contains "Codex design plugin enabled" "$config_file" '\[plugins\."design@alo-labs-codex(-local)?"\]'
    assert_file_contains "Codex product-management plugin enabled" "$config_file" '\[plugins\."product-management@alo-labs-codex(-local)?"\]'
    assert_not_contains "Codex split silver plugin absent" "$(cat "$config_file" 2>/dev/null)" 'silver@alo-labs-codex'
    assert_file_exists "Codex Silver Bullet package synced" "$marketplace_root/plugins/silver-bullet/.codex-plugin/plugin.json"
    assert_file_exists "Codex Silver Bullet init skill synced" "$marketplace_root/plugins/silver-bullet/skills/silver-init/SKILL.md"
    assert_file_exists "Codex Silver Bullet ensure-docs skill synced" "$marketplace_root/plugins/silver-bullet/skills/silver-ensure-docs/SKILL.md"
    assert_file_exists "Codex Silver Bullet feature skill synced" "$marketplace_root/plugins/silver-bullet/skills/silver-feature/SKILL.md"
    assert_file_exists "Codex Silver Bullet router skill synced" "$marketplace_root/plugins/silver-bullet/skills/silver/SKILL.md"
    assert_file_exists "Codex Silver Bullet workflow-chain guard synced" "$marketplace_root/plugins/silver-bullet/hooks/workflow-chain-guard.sh"
    assert_file_exists "Codex Silver Bullet template synced" "$marketplace_root/plugins/silver-bullet/templates/silver-bullet.md.base"
    assert_command_succeeds "Codex installed plugin registry exists" test -f "$installed_plugins_file"
    assert_command_succeeds "Codex Silver Bullet plugin registered" codex_plugin_registered "silver-bullet@alo-labs-codex"
    if codex_plugin_registered "silver-bullet@alo-labs-codex-local"; then
      echo "FAIL: Codex Silver Bullet local alias should not be installed"
      FAIL=$((FAIL + 1))
    else
      echo "PASS: Codex Silver Bullet local alias is absent"
      PASS=$((PASS + 1))
    fi
    assert_command_succeeds "Codex Silver Bullet install path exposes package manifest" codex_plugin_surface_exists_any "silver-bullet@alo-labs-codex" -- ".codex-plugin/plugin.json"
    assert_command_succeeds "Codex Silver Bullet install path exposes workflow-chain guard" codex_plugin_surface_exists_any "silver-bullet@alo-labs-codex" -- "hooks/workflow-chain-guard.sh"
    assert_command_succeeds "Codex Superpowers plugin registered" codex_plugin_registered_any "superpowers@superpowers-marketplace"
    assert_command_succeeds "Codex Superpowers install path exposes verification skill" codex_plugin_surface_exists_any "superpowers@superpowers-marketplace" -- "skills/verification-before-completion/SKILL.md" "skills/brainstorming/SKILL.md"
    assert_command_succeeds "Codex GSD plugin registered" codex_plugin_registered_any "gsd@get-shit-done-marketplace"
    assert_command_succeeds "Codex GSD install path exposes package manifest" codex_plugin_surface_exists_any "gsd@get-shit-done-marketplace" -- ".codex-plugin/plugin.json"
    assert_command_succeeds "Codex engineering plugin registered" codex_plugin_registered_any "engineering@alo-labs-codex" "engineering@alo-labs-codex-local"
    assert_command_succeeds "Codex engineering install path exposes package manifest" codex_plugin_surface_exists_any "engineering@alo-labs-codex" "engineering@alo-labs-codex-local" -- ".codex-plugin/plugin.json"
    assert_command_succeeds "Codex design plugin registered" codex_plugin_registered_any "design@alo-labs-codex" "design@alo-labs-codex-local"
    assert_command_succeeds "Codex design install path exposes package manifest" codex_plugin_surface_exists_any "design@alo-labs-codex" "design@alo-labs-codex-local" -- ".codex-plugin/plugin.json"
    assert_command_succeeds "Codex product-management plugin registered" codex_plugin_registered_any "product-management@alo-labs-codex" "product-management@alo-labs-codex-local"
    assert_command_succeeds "Codex product-management install path exposes package manifest" codex_plugin_surface_exists_any "product-management@alo-labs-codex" "product-management@alo-labs-codex-local" -- ".codex-plugin/plugin.json"
    assert_file_contains "Codex Silver Bullet init skill uses silver prefix" "$marketplace_root/plugins/silver-bullet/skills/silver-init/SKILL.md" 'name: silver:init'
    assert_file_contains "Codex Silver Bullet ensure-docs skill uses silver prefix" "$marketplace_root/plugins/silver-bullet/skills/silver-ensure-docs/SKILL.md" 'name: silver:ensure-docs'
    assert_file_contains "Codex Silver Bullet feature skill uses silver prefix" "$marketplace_root/plugins/silver-bullet/skills/silver-feature/SKILL.md" 'name: silver:feature'
    assert_file_contains "Codex Silver Bullet router skill uses silver name" "$marketplace_root/plugins/silver-bullet/skills/silver/SKILL.md" 'name: silver'
  fi
}

ensure_runtime_dependency_access_preflight() {
  if dependency_access_preflight_ready; then
    return 0
  fi
  verify_runtime_dependency_access
  write_dependency_access_preflight_marker
}

verify_runtime_installation() {
  ensure_runtime_dependency_access_preflight
}

assert_contains() {
  local label="$1"
  local haystack="$2"
  local needle="$3"
  if printf '%s' "$haystack" | grep -qE "$needle"; then
    echo "PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $label"
    echo "  expected pattern: $needle"
    echo "  snippet: $(printf '%s' "$haystack" | head -c 300)"
    FAIL=$((FAIL + 1))
  fi
}

assert_not_contains() {
  local label="$1"
  local haystack="$2"
  local needle="$3"
  if ! printf '%s' "$haystack" | grep -qE "$needle"; then
    echo "PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $label"
    echo "  unexpected pattern: $needle"
    echo "  snippet: $(printf '%s' "$haystack" | head -c 300)"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_exists() {
  local label="$1"
  local path="$2"
  if [[ -e "$path" ]]; then
    echo "PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $label (missing: $path)"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_absent() {
  local label="$1"
  local path="$2"
  if [[ -e "$path" ]]; then
    echo "FAIL: $label (unexpectedly present: $path)"
    FAIL=$((FAIL + 1))
  else
    echo "PASS: $label"
    PASS=$((PASS + 1))
  fi
}

wait_for_file_exists() {
  local label="$1"
  local path="$2"
  local timeout_seconds="${3:-600}"
  local interval_seconds="${4:-2}"
  local deadline=$((SECONDS + timeout_seconds))

  while (( SECONDS < deadline )); do
    if [[ -e "$path" ]]; then
      echo "PASS: $label"
      PASS=$((PASS + 1))
      return 0
    fi
    sleep "$interval_seconds"
  done

  echo "FAIL: $label (missing after ${timeout_seconds}s: $path)"
  FAIL=$((FAIL + 1))
  return 1
}

wait_for_file_contains() {
  local label="$1"
  local path="$2"
  local needle="$3"
  local timeout_seconds="${4:-600}"
  local interval_seconds="${5:-2}"
  local deadline=$((SECONDS + timeout_seconds))

  while (( SECONDS < deadline )); do
    if grep -qE "$needle" "$path" 2>/dev/null; then
      echo "PASS: $label"
      PASS=$((PASS + 1))
      return 0
    fi
    sleep "$interval_seconds"
  done

  echo "FAIL: $label"
  echo "  expected pattern: $needle"
  echo "  in file: $path"
  FAIL=$((FAIL + 1))
  return 1
}

wait_for_file_or_git_head_contains() {
  local label="$1"
  local repo_dir="$2"
  local path="$3"
  local needle="$4"
  local timeout_seconds="${5:-600}"
  local interval_seconds="${6:-2}"
  local file_path="${repo_dir}/${path}"
  local deadline=$((SECONDS + timeout_seconds))

  while (( SECONDS < deadline )); do
    if grep -qE "$needle" "$file_path" 2>/dev/null; then
      echo "PASS: $label"
      PASS=$((PASS + 1))
      return 0
    fi
    if git -C "$repo_dir" show "HEAD:$path" 2>/dev/null | grep -qE "$needle"; then
      echo "PASS: $label"
      PASS=$((PASS + 1))
      return 0
    fi
    sleep "$interval_seconds"
  done

  echo "FAIL: $label"
  echo "  expected pattern: $needle"
  echo "  in file or HEAD path: $file_path"
  FAIL=$((FAIL + 1))
  return 1
}

wait_for_state_contains() {
  local label="$1"
  local needle="$2"
  # Live Claude turns can take several minutes before the skill-state marker
  # lands, especially for research / blast-radius / feature-style turns.
  # Give the harness a much wider default window so it waits for the actual
  # record rather than timing out while the model is still working.
  local timeout_seconds="${3:-600}"
  local interval_seconds="${4:-2}"
  local deadline=$((SECONDS + timeout_seconds))

  while (( SECONDS < deadline )); do
    if grep -qx "$needle" "$STATE_FILE" 2>/dev/null; then
      echo "PASS: $label"
      PASS=$((PASS + 1))
      return 0
    fi
    sleep "$interval_seconds"
  done

  echo "FAIL: $label"
  echo "  expected state entry: $needle"
  if [[ -f "$STATE_FILE" ]]; then
    echo "  state: $(tr '\n' ' ' < "$STATE_FILE")"
  fi
  FAIL=$((FAIL + 1))
  return 1
}

assert_file_contains() {
  local label="$1"
  local path="$2"
  local needle="$3"
  if grep -qE "$needle" "$path" 2>/dev/null; then
    echo "PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $label"
    echo "  expected pattern: $needle"
    echo "  in file: $path"
    FAIL=$((FAIL + 1))
  fi
}

assert_state_contains() {
  local label="$1"
  local needle="$2"
  if grep -qx "$needle" "$STATE_FILE" 2>/dev/null; then
    echo "PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $label"
    echo "  expected state entry: $needle"
    if [[ -f "$STATE_FILE" ]]; then
      echo "  state: $(tr '\n' ' ' < "$STATE_FILE")"
    fi
    FAIL=$((FAIL + 1))
  fi
}

assert_state_not_contains() {
  local label="$1"
  local needle="$2"
  if ! grep -qx "$needle" "$STATE_FILE" 2>/dev/null; then
    echo "PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $label"
    echo "  unexpected state entry: $needle"
    FAIL=$((FAIL + 1))
  fi
}

assert_command_succeeds() {
  local label="$1"
  shift
  if "$@"; then
    echo "PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $label"
    FAIL=$((FAIL + 1))
  fi
}

print_results() {
  echo ""
  echo "Results: ${PASS} passed, ${FAIL} failed"
  [[ $FAIL -eq 0 ]]
}
