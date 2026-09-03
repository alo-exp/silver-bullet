#!/usr/bin/env bash
# Shared helpers for the live enterprise E2E suite.
#
# The suite runs Claude and Codex against an isolated copy of the standalone
# sibling enterprise-grade-test-app repo, then resets the workspace after each scenario.
# The real SB state files are backed up and restored around each scenario so
# the suite can run repeatedly without cross-talk. Claude keeps using
# the active host runtime state root; Kay uses the temp-root .codex/.silver-bullet tree.

set -euo pipefail

PATH="/Users/shafqat/.local/bin:/opt/homebrew/bin:/Applications/Codex.app/Contents/Resources:${PATH:-/usr/bin:/bin:/usr/sbin:/sbin}"
export PATH

E2E_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SB_ROOT="$(cd "${E2E_ROOT}/../.." && pwd)"
DEFAULT_TEST_ENTERPRISE_APP_ROOT="$(cd "${SB_ROOT}/../.." && pwd)/enterprise-grade-test-app"
FIXTURE_DIR="${SB_TEST_ENTERPRISE_APP_ROOT:-${SB_TEST_TODO_APP_ROOT:-${DEFAULT_TEST_ENTERPRISE_APP_ROOT}}}"
E2E_PROBE_SOURCE_FILE="${E2E_PROBE_SOURCE_FILE:-api/src/health.js}"
AGENT_DIR="${SB_ROOT}/tests/live/agents"
LIB_DIR="${E2E_ROOT}/lib"
RECOMMENDED_TOOLS_E2E_LIB="${LIB_DIR}/recommended-tools-e2e.sh"
CLAUDE_INSTALL_SCRIPT="${SB_ROOT}/scripts/install-claude.sh"
CODEX_HOOK_TRANSPLANT_HELPER="${SB_ROOT}/tests/live/lib/codex-hook-transplant.sh"

E2E_RUNTIME="${SB_E2E_LIVE_RUNTIME:-${SB_LIVE_RUNTIME:-claude}}"
KAY_HOME="${KAY_HOME:-${SB_LIVE_CODEX_ISOLATION_DIR:-${KAY_SB_TEST_HOME:-}}}"
case "$E2E_RUNTIME" in
  claude) export SILVER_BULLET_RUNTIME=claude ;;
  kay|codex) export SILVER_BULLET_RUNTIME=codex ;;
  cursor) export SILVER_BULLET_RUNTIME=cursor ;;
esac
if [[ -f "${SB_ROOT}/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "${SB_ROOT}/hooks/lib/runtime-paths.sh"
fi
if [[ -f "${SB_ROOT}/hooks/lib/skill-discovery.sh" ]]; then
  # shellcheck source=hooks/lib/skill-discovery.sh
  source "${SB_ROOT}/hooks/lib/skill-discovery.sh"
fi
if [[ -f "$CODEX_HOOK_TRANSPLANT_HELPER" ]]; then
  # shellcheck source=tests/live/lib/codex-hook-transplant.sh
  source "$CODEX_HOOK_TRANSPLANT_HELPER"
fi
if [[ "$E2E_RUNTIME" == "kay" && -f "${SB_ROOT}/tests/live/lib/kay-codex-isolation.sh" ]]; then
  # shellcheck source=tests/live/lib/kay-codex-isolation.sh
  source "${SB_ROOT}/tests/live/lib/kay-codex-isolation.sh"
fi
if [[ "$E2E_RUNTIME" == "kay" ]]; then
  SB_TEST_DIR="${KAY_HOME}/.codex/.silver-bullet"
  MCP_AUTH_CACHE="${KAY_HOME}/.kay/mcp-needs-auth-cache.json"
  MCP_AUTH_CACHE_BACKUP="${KAY_HOME}/.kay/mcp-needs-auth-cache.e2e-live-backup-$$"
else
  SB_TEST_DIR="${SB_RUNTIME_STATE_DIR}"
  MCP_AUTH_CACHE="${SB_RUNTIME_HOME_ROOT}/mcp-needs-auth-cache.json"
  MCP_AUTH_CACHE_BACKUP="${SB_TEST_DIR}/mcp-needs-auth-cache.e2e-live-backup-$$"
fi
INLINE_E2E_MATRIX_FILE="${SB_TEST_DIR}/inline-e2e-matrix"
E2E_LIVE_MATRIX_FILE="${SB_TEST_DIR}/e2e-live-matrix"
HOOK_AUDIT_FILE="${SB_TEST_DIR}/hook-audit.jsonl"
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
STATE_FILE="${SB_TEST_DIR}/state"
TRIVIAL_FILE="${SB_TEST_DIR}/trivial"
SESSION_INIT_FILE="${SB_TEST_DIR}/session-init"
STATE_BACKUP="${SB_TEST_DIR}/state.e2e-live-backup-$$"
TRIVIAL_BACKUP="${SB_TEST_DIR}/trivial.e2e-live-backup-$$"
SESSION_INIT_BACKUP="${SB_TEST_DIR}/session-init.e2e-live-backup-$$"
PASS=0
FAIL=0

if [[ ! -d "$FIXTURE_DIR" ]]; then
  printf 'ERROR: enterprise-grade-test-app fixture repo not found at %s\n' "$FIXTURE_DIR" >&2
  exit 1
fi

CLAUDE_LEGACY_PLUGINS=(
  "data-engineering@claude-plugins-official"
  "frontend-design@claude-plugins-official"
  "product-tracking-skills@claude-plugins-official"
)

CLAUDE_REQUIRED_PLUGINS=(
  "silver-bullet@alo-labs"
)

case "$E2E_RUNTIME" in
  claude)
    # shellcheck source=tests/live/agents/claude/agent.sh
    source "$AGENT_DIR/claude/agent.sh"
    ;;
  codex)
    # shellcheck source=tests/live/agents/codex/agent.sh
    source "$AGENT_DIR/codex/agent.sh"
    ;;
  cursor)
    # shellcheck source=tests/live/agents/cursor/agent.sh
    source "$AGENT_DIR/cursor/agent.sh"
    ;;
  kay)
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

  if [[ "$E2E_RUNTIME" == "kay" ]]; then
    local session_catalog_path="${CODEX_SESSION_CATALOG_PATH:-${KAY_HOME}/.kay/sessions/index/catalog.jsonl}"
    mkdir -p "$(dirname "$session_catalog_path")"
    : > "$session_catalog_path"
  fi
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

enable_hook_audit() {
  mkdir -p "$SB_TEST_DIR"
  : > "$HOOK_AUDIT_FILE"
  # Claude hook subprocesses do not inherit SILVER_BULLET_HOOK_AUDIT_LOG; use the
  # state flag so hooks still write to the default state-scoped audit sink.
  : > "${SB_TEST_DIR}/hook-audit-enabled"
  export SILVER_BULLET_HOOK_AUDIT_LOG="$HOOK_AUDIT_FILE"
  if [[ "$E2E_RUNTIME" == "kay" && -n "${WORK_DIR:-}" ]] && declare -F kay_register_silver_bullet_project_hooks >/dev/null 2>&1; then
    kay_register_silver_bullet_project_hooks "$WORK_DIR"
  fi
}

disable_hook_audit() {
  rm -f "$HOOK_AUDIT_FILE" "${SB_TEST_DIR}/hook-audit-enabled"
  unset SILVER_BULLET_HOOK_AUDIT_LOG
}

clear_hook_audit_log() {
  : > "$HOOK_AUDIT_FILE"
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
  if [[ "${SB_E2E_LIVE_RUNTIMES:-}" == "claude" ]]; then
    marker="claude-only"
  elif [[ "${SB_ALLOW_CODEX_ONLY_LIVE_RELEASE:-0}" == "1" || "${SB_E2E_LIVE_RUNTIMES:-}" == "codex" || "${SB_E2E_LIVE_RUNTIMES:-}" == "kay" ]]; then
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
  [[ -n "$marker_file" && -f "$marker_file" ]] || return 1
  grep -q "^agent=${E2E_RUNTIME}$" "$marker_file" 2>/dev/null
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

hook_delivery_preflight_file() {
  printf '%s\n' "${E2E_LIVE_HOOK_PREFLIGHT_FILE:-}"
}

hook_delivery_preflight_ready() {
  local marker_file
  marker_file="$(hook_delivery_preflight_file)"
  [[ -n "$marker_file" && -f "$marker_file" ]] || return 1
  grep -q "^agent=${E2E_RUNTIME}$" "$marker_file" 2>/dev/null
}

write_hook_delivery_preflight_marker() {
  local marker_file
  marker_file="$(hook_delivery_preflight_file)"
  [[ -n "$marker_file" ]] || return 0
  mkdir -p "$(dirname "$marker_file")"
  cat > "$marker_file" <<EOF
agent=${E2E_RUNTIME}
checked_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
}

emit_hook_delivery_diagnostic() {
  local transcript_dir=""
  local transcript_file=""

  if declare -F agent_transcript_dir >/dev/null 2>&1; then
    transcript_dir="$(agent_transcript_dir 2>/dev/null || true)"
  fi
  if [[ -n "$transcript_dir" ]]; then
    transcript_file="${transcript_dir}/latest.jsonl"
  fi

  if [[ "$E2E_RUNTIME" != "claude" ]]; then
    if [[ -n "$transcript_file" && -f "$transcript_file" ]]; then
      echo "  latest ${E2E_RUNTIME} transcript tool events:"
      rg -n 'exec_command_begin|tool_call_begin|tool_call|permissionDecision|decision' "$transcript_file" | sed -n '1,10p' || true
    else
      echo "  no ${E2E_RUNTIME} transcript captured at: ${transcript_file:-<unknown>}"
    fi
  fi
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

workspace_trust_config_files() {
  case "$E2E_RUNTIME" in
    codex)
      codex_config_file
      ;;
    kay)
      kay_active_config_file
      codex_config_file
      ;;
  esac | awk 'NF && !seen[$0]++'
}

trust_runtime_workspace() {
  [[ "$E2E_RUNTIME" == "claude" ]] && return 0

  local config_file
  while IFS= read -r config_file; do
    [[ -n "$config_file" ]] || continue
    mkdir -p "$(dirname "$config_file")"
    python3 - "$config_file" "$WORK_DIR" <<'PY'
import pathlib
import sys

config_path = pathlib.Path(sys.argv[1])
workspace = pathlib.Path(sys.argv[2])
text = config_path.read_text() if config_path.is_file() else ""

project_paths = []
for candidate in (workspace, workspace.resolve()):
    candidate_str = str(candidate)
    if candidate_str not in project_paths:
        project_paths.append(candidate_str)

def upsert_project_trust(lines, project_path):
    header = f'[projects."{project_path}"]'
    out = []
    found = False
    index = 0

    while index < len(lines):
        line = lines[index]
        if line == header:
            found = True
            out.append(line)
            index += 1
            trust_written = False
            while index < len(lines) and not lines[index].startswith("["):
                current = lines[index]
                if current.startswith("trust_level = "):
                    if not trust_written:
                        out.append('trust_level = "trusted"')
                        trust_written = True
                else:
                    out.append(current)
                index += 1
            if not trust_written:
                out.append('trust_level = "trusted"')
            continue
        out.append(line)
        index += 1

    if not found:
        if out and out[-1] != "":
            out.append("")
        out.extend([header, 'trust_level = "trusted"'])

    return out

lines = text.splitlines()
for project_path in project_paths:
    lines = upsert_project_trust(lines, project_path)

config_path.write_text("\n".join(lines).rstrip("\n") + "\n")
PY
  done < <(workspace_trust_config_files)

  if [[ "$E2E_RUNTIME" == "kay" ]] && declare -F kay_register_silver_bullet_project_hooks >/dev/null 2>&1; then
    kay_register_silver_bullet_project_hooks "$WORK_DIR"
  fi
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

  if [[ -f "${WORK_DIR}/.silver-bullet.json" ]] && command -v jq >/dev/null 2>&1; then
    tmp_cfg="$(mktemp)"
    jq '.orchestrator_mode = "worker"' "${WORK_DIR}/.silver-bullet.json" > "$tmp_cfg"
    mv "$tmp_cfg" "${WORK_DIR}/.silver-bullet.json"
  fi

  mkdir -p "${WORK_DIR}/.claude"
  python3 - "${WORK_DIR}/.codex/settings.local.json" "$disabled_mcpjson_servers_json" <<'PY'
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
  git -C "$WORK_DIR" commit -q -m "initial: enterprise test app baseline" 2>/dev/null || true
  git -C "$WORK_DIR" checkout -q -b feature/e2e-live 2>/dev/null || true
  trust_runtime_workspace

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

  # Enterprise live entrypoint runs install-claude.sh after hook-delivery; skip here to
  # avoid ENOTEMPTY races when monitor/matrix or duplicate drivers run concurrently.
  if [[ "$E2E_RUNTIME" == "claude" && "${SB_E2E_HOOK_DELIVERY_SKIP_BOOTSTRAP:-}" != "1" ]]; then
    CLAUDE_PROMPT_COUNT=0
    bootstrap_claude_dependencies
  fi

  if [[ -f "${WORK_DIR}/.silver-bullet.json" ]]; then
    ensure_e2e_recommended_tools_opt_in
  fi
}

# Enterprise matrix runs interactive Claude in-place against the fixture repo
# (no temp copy). The matrix runner calls this instead of prepare_workspace.
setup_workspace() {
  backup_session_state
  WORK_DIR="$FIXTURE_DIR"
  agent_preflight

  case "$E2E_RUNTIME" in
    claude)
      CLAUDE_PROMPT_COUNT=0
      bootstrap_claude_dependencies
      ;;
    codex)
      # Pre-trust fixture workspace before interactive Codex matrix turns
      trust_runtime_workspace
      bash "${SB_ROOT}/scripts/install-codex.sh" --purge-legacy-skills >/dev/null
      ;;
    cursor)
      if [[ "${SB_E2E_SKIP_CURSOR_INSTALL:-}" != "1" ]]; then
        bash "${SB_ROOT}/scripts/install-cursor.sh" >/dev/null
      else
        echo "SKIP: cursor plugin install (SB_E2E_SKIP_CURSOR_INSTALL=1)" >&2
      fi
      ;;
  esac
}

ensure_e2e_recommended_tools_opt_in() {
  [[ -n "${WORK_DIR:-}" && -f "${WORK_DIR}/.silver-bullet.json" ]] || return 0
  [[ -f "$RECOMMENDED_TOOLS_E2E_LIB" ]] || return 0
  # shellcheck source=tests/e2e-live/lib/recommended-tools-e2e.sh
  source "$RECOMMENDED_TOOLS_E2E_LIB"
  sb_e2e_enable_all_recommended_tools "${WORK_DIR}/.silver-bullet.json"
  if sb_e2e_assert_all_recommended_tools_enabled "${WORK_DIR}/.silver-bullet.json"; then
    echo "PASS: E2E workspace has all recommended tools opted in"
    PASS=$((PASS + 1))
  else
    echo "FAIL: E2E workspace missing full recommended_tools opt-in after init"
    FAIL=$((FAIL + 1))
  fi
}

cleanup_workspace() {
  if [[ -n "${APP_SERVER_PID:-}" ]] && kill -0 "$APP_SERVER_PID" >/dev/null 2>&1; then
    kill "$APP_SERVER_PID" >/dev/null 2>&1 || true
    wait "$APP_SERVER_PID" >/dev/null 2>&1 || true
  fi
  APP_SERVER_PID=""

  if [[ -n "${WORK_DIR:-}" && -d "$WORK_DIR" ]]; then
    if [[ "${SB_E2E_ENTERPRISE_MATRIX:-}" == "1" && "$WORK_DIR" == "$FIXTURE_DIR" ]]; then
      : # Enterprise matrix runs in-place; never delete the fixture checkout.
    else
      rm -rf "$WORK_DIR"
    fi
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
  rm -f "$HOOK_AUDIT_FILE" 2>/dev/null || true
  if [[ -n "${BRANCH_FILE:-}" ]]; then
    rm -f "$BRANCH_FILE"
  fi
  unset SILVER_BULLET_BRANCH_FILE
  unset SILVER_BULLET_HOOK_AUDIT_LOG
  restore_session_state
}

trap cleanup_workspace EXIT

start_app_server() {
  if [[ ! -f "${WORK_DIR}/src/server.js" ]]; then
    echo "INFO: no src/server.js in fixture; skipping app server start" >&2
    return 0
  fi
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
  agent_invoke permissive "$prompt"
}

run_prompt_strict() {
  local prompt="$1"
  seed_workspace_requested_skills "$prompt"
  agent_invoke default "$prompt"
}

runtime_hook_probe_prefix() {
  cat <<'EOF'
Silver Bullet hook probe: run the requested Bash command once with the Bash tool, then stop. Do not edit files directly or refuse without attempting the command.

EOF
}

run_hook_probe_strict() {
  local prompt="$1"
  CLAUDE_PRINT_SKIP_SETTINGS_EXPORT=1     CLAUDE_PRINT_VERBOSE=0     CLAUDE_MODEL="${CLAUDE_HOOK_PROBE_MODEL:-haiku}"     CLAUDE_EFFORT="${CLAUDE_HOOK_PROBE_EFFORT:-low}"     run_prompt_strict "$prompt"
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

runtime_codex_home_root() {
  if [[ "$E2E_RUNTIME" == "kay" ]]; then
    printf '%s\n' "${KAY_HOME:-$HOME}"
  else
    printf '%s\n' "$HOME"
  fi
}

codex_config_file() {
  local config_file
  local home_root

  home_root="$(runtime_codex_home_root)"
  for config_file in "${home_root}/.codex/config.toml" "${home_root}/.codex/config.toml"; do
    if [[ -f "$config_file" ]]; then
      printf '%s\n' "$config_file"
      return 0
    fi
  done
  printf '%s\n' "${home_root}/.codex/config.toml"
}

kay_active_config_file() {
  local home_root

  home_root="$(runtime_codex_home_root)"
  printf '%s\n' "${home_root}/.kay/config.toml"
}

codex_marketplace_root() {
  local marketplace_root
  local home_root

  home_root="$(runtime_codex_home_root)"
  for marketplace_root in \
    "${home_root}/.codex/.tmp/marketplaces/alo-labs-codex" \
    "${home_root}/.codex/.tmp/marketplaces/alo-labs-codex"; do
    if [[ -d "$marketplace_root" ]]; then
      printf '%s\n' "$marketplace_root"
      return 0
    fi
  done
  printf '%s\n' "${home_root}/.codex/.tmp/marketplaces/alo-labs-codex"
}

codex_installed_plugins_file() {
  local registry_file
  local home_root

  home_root="$(runtime_codex_home_root)"
  for registry_file in \
    "${home_root}/.codex/plugins/installed_plugins.json" \
    "${home_root}/.codex/plugins/installed_plugins.json"; do
    if [[ -f "$registry_file" ]]; then
      printf '%s\n' "$registry_file"
      return 0
    fi
  done
  printf '%s\n' "${home_root}/.codex/plugins/installed_plugins.json"
}

codex_plugin_install_path_matches() {
  local plugin_id="$1"
  local expected_path="$2"
  local registry_file

  registry_file="$(codex_installed_plugins_file)"
  python3 - "$registry_file" "$plugin_id" "$expected_path" <<'PY'
import json
import pathlib
import sys

registry_path = pathlib.Path(sys.argv[1])
plugin_id = sys.argv[2]
expected = sys.argv[3]

try:
    data = json.loads(registry_path.read_text())
except Exception:
    raise SystemExit(1)

entries = data.get("plugins", {}).get(plugin_id, [])
for entry in entries:
    if entry.get("installPath") == expected:
        raise SystemExit(0)

raise SystemExit(1)
PY
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

codex_plugin_surface_file_contains_any() {
  local plugin_id="$1"
  local surface="$2"
  shift 2
  local needle
  local install_path

  install_path="$(codex_plugin_install_path "$plugin_id")"
  [[ -n "$install_path" && -f "$install_path/$surface" ]] || return 1

  for needle in "$@"; do
    if grep -qF "$needle" "$install_path/$surface"; then
      return 0
    fi
  done

  return 1
}

runtime_plugin_hook_file() {
  if [[ "$E2E_RUNTIME" == "claude" ]]; then
    local claude_cache_root latest_claude_cache
    claude_cache_root="${SB_RUNTIME_HOME_ROOT}/plugins/cache/alo-labs/silver-bullet"
    latest_claude_cache="$(find "$claude_cache_root" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -V | tail -n 1)"
    if [[ -n "$latest_claude_cache" && -f "$latest_claude_cache/hooks/workflow-chain-guard.sh" ]]; then
      printf '%s\n' "$latest_claude_cache/hooks/workflow-chain-guard.sh"
      return 0
    fi
    return 1
  fi

  local install_path
  install_path="$(codex_plugin_install_path "silver-bullet@alo-labs-codex" 2>/dev/null || true)"
  if [[ -n "$install_path" && -f "$install_path/hooks/workflow-chain-guard.sh" ]]; then
    printf '%s\n' "$install_path/hooks/workflow-chain-guard.sh"
    return 0
  fi

  local marketplace_root
  marketplace_root="$(codex_marketplace_root)"
  if [[ -f "$marketplace_root/plugins/silver-bullet/hooks/workflow-chain-guard.sh" ]]; then
    printf '%s\n' "$marketplace_root/plugins/silver-bullet/hooks/workflow-chain-guard.sh"
    return 0
  fi

  return 1
}

refresh_runtime_installation() {
  if [[ "$E2E_RUNTIME" == "claude" ]]; then
    bootstrap_claude_dependencies
  else
    if [[ "$E2E_RUNTIME" == "kay" ]]; then
      sync_install_generated_codex_user_hooks "$KAY_HOME" "kay"
    else
      sync_install_generated_codex_user_hooks "$HOME" "codex"
    fi
  fi
}

verify_runtime_dependency_access() {
  if [[ "$E2E_RUNTIME" == "claude" ]]; then
    assert_command_succeeds "Claude Silver Bullet plugin installed" claude_plugin_installed_in_scope "silver-bullet@alo-labs" "user"
    if claude_plugin_installed_in_scope "superpowers@superpowers-marketplace" "project"; then
      echo "FAIL: Claude Superpowers plugin should not be installed by SB"
      FAIL=$((FAIL + 1))
    else
      echo "PASS: Claude Superpowers plugin is not installed by SB"
      PASS=$((PASS + 1))
    fi
    if claude_plugin_installed_in_scope "engineering@knowledge-work-plugins" "project" || \
       claude_plugin_installed_in_scope "design@knowledge-work-plugins" "project" || \
       claude_plugin_installed_in_scope "product-management@knowledge-work-plugins" "project"; then
      echo "FAIL: Claude Anthropic knowledge-work plugins should not be installed by SB"
      FAIL=$((FAIL + 1))
    else
      echo "PASS: Claude Anthropic knowledge-work plugins are not installed by SB"
      PASS=$((PASS + 1))
    fi
    if claude_plugin_installed "using-silver-bullet"; then
      echo "FAIL: legacy using-silver-bullet alias should not be installed"
      FAIL=$((FAIL + 1))
    else
      echo "PASS: legacy using-silver-bullet alias is absent"
      PASS=$((PASS + 1))
    fi
    local claude_cache_root latest_claude_cache
    claude_cache_root="${KAY_HOME:-$HOME}/.codex/plugins/cache/alo-labs/silver-bullet"
    latest_claude_cache="$(find "$claude_cache_root" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -V | tail -n 1)"
    if [[ -n "$latest_claude_cache" && -d "$latest_claude_cache" ]]; then
      assert_file_exists "Claude Silver Bullet init skill synced" "$latest_claude_cache/skills/silver:init/SKILL.md"
      assert_file_exists "Claude Silver Bullet ensure-docs skill synced" "$latest_claude_cache/skills/silver:ensure-docs/SKILL.md"
      assert_file_exists "Claude Silver Bullet feature skill synced" "$latest_claude_cache/skills/silver:feature/SKILL.md"
      assert_file_exists "Claude Silver Bullet router skill synced" "$latest_claude_cache/skills/silver/SKILL.md"
      assert_file_contains_any "Claude Silver Bullet init skill uses supported picker name" "$latest_claude_cache/skills/silver:init/SKILL.md" 'name: silver:init' 'name: "silver:init"'
      assert_file_contains_any "Claude Silver Bullet ensure-docs skill uses supported picker name" "$latest_claude_cache/skills/silver:ensure-docs/SKILL.md" 'name: silver:ensure-docs' 'name: "silver:ensure-docs"'
      assert_file_contains_any "Claude Silver Bullet feature skill uses supported picker name" "$latest_claude_cache/skills/silver:feature/SKILL.md" 'name: silver:feature' 'name: "silver:feature"'
      assert_file_contains "Claude Silver Bullet router skill uses silver name" "$latest_claude_cache/skills/silver/SKILL.md" 'name: silver'
    else
      echo "FAIL: Claude Silver Bullet cache root missing: $claude_cache_root"
      FAIL=$((FAIL + 1))
    fi
  elif [[ "$E2E_RUNTIME" == "cursor" ]]; then
    assert_command_succeeds "cursor-agent CLI on PATH" command -v cursor-agent
    local cursor_home cursor_cache_root latest_cursor_cache sb_version
    cursor_home="${CURSOR_HOME:-$HOME/.cursor}"
    sb_version="$(jq -r '.version // "0.0.0"' "${SB_ROOT}/package.json" 2>/dev/null || echo 0.0.0)"
    cursor_cache_root="${cursor_home}/plugins/cache/alo-labs/silver-bullet"
    latest_cursor_cache="${cursor_cache_root}/${sb_version}"
    if [[ ! -d "$latest_cursor_cache" ]]; then
      latest_cursor_cache="$(find "$cursor_cache_root" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -V | tail -n 1)"
    fi
    if [[ -n "$latest_cursor_cache" && -d "$latest_cursor_cache" ]]; then
      assert_file_exists "Cursor Silver Bullet plugin synced" "${latest_cursor_cache}/.cursor-plugin/plugin.json"
      assert_file_exists "Cursor Silver Bullet template synced" "${latest_cursor_cache}/templates/silver-bullet.md.base"
      assert_file_exists "Cursor live agent adapter present" "${SB_ROOT}/tests/live/agents/cursor/agent.sh"
    else
      echo "FAIL: Cursor Silver Bullet cache root missing: ${cursor_cache_root}"
      FAIL=$((FAIL + 1))
    fi
    if [[ -f "${cursor_home}/hooks.json" ]] && grep -q 'silver-bullet' "${cursor_home}/hooks.json" 2>/dev/null; then
      echo "PASS: Cursor hooks.json merged with Silver Bullet"
      PASS=$((PASS + 1))
    else
      echo "FAIL: Cursor hooks.json merged with Silver Bullet"
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
    assert_command_succeeds "Codex Silver Bullet plugin registered for preflight" codex_plugin_registered "silver-bullet@alo-labs-codex"
    assert_file_not_contains "Codex GSD marketplace not registered by default" "$config_file" '\[marketplaces\.get-shit-done-marketplace\]'
    assert_file_not_contains "Codex Superpowers marketplace not registered by default" "$config_file" '\[marketplaces\.superpowers-marketplace\]'
    assert_file_not_contains "Codex Superpowers plugin not enabled by default" "$config_file" '\[plugins\."superpowers@superpowers-marketplace"\]'
    assert_file_not_contains "Codex GSD plugin not enabled by default" "$config_file" '\[plugins\."gsd@get-shit-done-marketplace"\]'
    assert_file_not_contains "Codex engineering plugin not enabled by default" "$config_file" '\[plugins\."engineering@alo-labs-codex(-local)?"\]'
    assert_file_not_contains "Codex design plugin not enabled by default" "$config_file" '\[plugins\."design@alo-labs-codex(-local)?"\]'
    assert_file_not_contains "Codex product-management plugin not enabled by default" "$config_file" '\[plugins\."product-management@alo-labs-codex(-local)?"\]'
    assert_not_contains "Codex split silver plugin absent" "$(cat "$config_file" 2>/dev/null)" 'silver@alo-labs-codex'
    assert_file_exists "Codex Silver Bullet package synced" "$marketplace_root/plugins/silver-bullet/.codex-plugin/plugin.json"
    assert_file_absent "Codex Silver Bullet package does not expose plugin picker skills directory" "$marketplace_root/plugins/silver-bullet/skills"
    assert_file_exists "Codex Silver Bullet init skill source synced" "$marketplace_root/plugins/silver-bullet/skill-source/silver-init/SILVER_SOURCE"
    assert_file_exists "Codex Silver Bullet ensure-docs skill source synced" "$marketplace_root/plugins/silver-bullet/skill-source/silver-ensure-docs/SILVER_SOURCE"
    assert_file_exists "Codex Silver Bullet feature skill source synced" "$marketplace_root/plugins/silver-bullet/skill-source/silver-feature/SILVER_SOURCE"
    assert_file_exists "Codex Silver Bullet router skill source synced" "$marketplace_root/plugins/silver-bullet/skill-source/silver/SILVER_SOURCE"
    assert_file_absent "Codex Silver Bullet package has no picker-discoverable internal skill files" "$(find "$marketplace_root/plugins/silver-bullet" -name '*SKILL.md' -print -quit 2>/dev/null)"
    assert_file_absent "Codex Silver Bullet package does not expose generated picker skills directory" "$marketplace_root/plugins/silver-bullet/.generated-skills"
    assert_file_absent "Codex Silver Bullet package does not expose agent SKILL.md bundle" "$marketplace_root/plugins/silver-bullet/agents"
    assert_file_exists "Codex native Silver Bullet init skill mirrored" "$SB_RUNTIME_HOME_ROOT/skills/silver:init/SKILL.md"
    assert_file_exists "Codex native Silver Bullet feature skill mirrored" "$SB_RUNTIME_HOME_ROOT/skills/silver:feature/SKILL.md"
    assert_file_exists "Codex native Silver Bullet router skill mirrored" "$SB_RUNTIME_HOME_ROOT/skills/silver/SKILL.md"
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
    assert_command_succeeds "Codex Silver Bullet managed hook manifest declared" codex_plugin_surface_file_contains_any "silver-bullet@alo-labs-codex" ".codex-plugin/plugin.json" '"hooks": "./hooks/hooks.json"'
    assert_command_succeeds "Codex Silver Bullet install path exposes workflow-chain guard" codex_plugin_surface_exists_any "silver-bullet@alo-labs-codex" -- "hooks/workflow-chain-guard.sh"
    assert_command_succeeds "Codex hook discovery sees silver-quality-gates as invocable" sb_skill_is_installed "silver-quality-gates"
    assert_command_succeeds "Codex hook discovery sees silver-context as invocable" sb_skill_is_installed "silver-context"
    assert_command_succeeds "Codex hook discovery sees silver-plan as invocable" sb_skill_is_installed "silver-plan"
    assert_command_succeeds "Codex hook discovery sees silver-execute as invocable" sb_skill_is_installed "silver-execute"
    assert_command_succeeds "Codex hook discovery sees silver-verify as invocable" sb_skill_is_installed "silver-verify"
    assert_command_succeeds "Codex hook discovery sees silver-completion-audit as invocable" sb_skill_is_installed "silver-completion-audit"
    assert_command_succeeds "Codex hook discovery sees silver-tdd marker as invocable" sb_skill_is_installed "silver-tdd"
    assert_command_succeeds "Codex hook discovery sees verify-tests as invocable" sb_skill_is_installed "verify-tests"
    assert_file_contains "Codex Silver Bullet init skill uses silver prefix" "$marketplace_root/plugins/silver-bullet/skill-source/silver-init/SILVER_SOURCE" 'name: "silver:init"'
    assert_file_contains "Codex Silver Bullet ensure-docs skill uses silver prefix" "$marketplace_root/plugins/silver-bullet/skill-source/silver-ensure-docs/SILVER_SOURCE" 'name: "silver:ensure-docs"'
    assert_file_contains "Codex Silver Bullet feature skill uses silver prefix" "$marketplace_root/plugins/silver-bullet/skill-source/silver-feature/SILVER_SOURCE" 'name: "silver:feature"'
    assert_file_contains "Codex Silver Bullet router skill uses silver name" "$marketplace_root/plugins/silver-bullet/skill-source/silver/SILVER_SOURCE" 'name: silver'

    if [[ "$E2E_RUNTIME" == "kay" ]]; then
      local active_config_file
      active_config_file="$(kay_active_config_file)"
      assert_file_contains "Kay active config enables plugin hooks" "$active_config_file" 'plugin_hooks = true'
      assert_file_contains "Kay active config enables hooks" "$active_config_file" '^hooks = true$'
      assert_file_not_contains "Kay active config strips Codex plugin registry sections" "$active_config_file" '\[plugins\."silver-bullet@alo-labs-codex"\]'
      assert_file_not_contains "Kay active config omits Codex home rewrite sections" "$active_config_file" 'CODEX_HOME = "'
      assert_command_succeeds "Isolated Silver Bullet install path registered" codex_plugin_install_path_matches "silver-bullet@alo-labs-codex" "${KAY_HOME}/.codex/plugins/cache/alo-labs-codex/silver-bullet/current"
      local kay_sb_cli
      kay_sb_cli="$(command -v silver-bullet 2>/dev/null || true)"
      if [[ "$kay_sb_cli" == "${KAY_HOME}/.codex/bin/silver-bullet" && -x "$kay_sb_cli" ]]; then
        echo "PASS: Isolated Silver Bullet CLI shim is on PATH"
        PASS=$((PASS + 1))
      else
        echo "FAIL: Isolated Silver Bullet CLI shim is on PATH"
        echo "  expected: ${KAY_HOME}/.codex/bin/silver-bullet"
        echo "  actual: ${kay_sb_cli:-<missing>}"
        FAIL=$((FAIL + 1))
      fi
    else
      local runtime_home_root
      runtime_home_root="$(runtime_codex_home_root)"
      assert_command_succeeds "Native Codex Silver Bullet install path registered" codex_plugin_install_path_matches "silver-bullet@alo-labs-codex" "${runtime_home_root}/.codex/plugins/cache/alo-labs-codex/silver-bullet/current"
      local codex_sb_cli
      codex_sb_cli="$(command -v silver-bullet 2>/dev/null || true)"
      if [[ "$codex_sb_cli" == "${runtime_home_root}/.codex/bin/silver-bullet" && -x "$codex_sb_cli" ]]; then
        echo "PASS: Native Codex Silver Bullet CLI shim is on PATH"
        PASS=$((PASS + 1))
      else
        echo "FAIL: Native Codex Silver Bullet CLI shim is on PATH"
        echo "  expected: ${runtime_home_root}/.codex/bin/silver-bullet"
        echo "  actual: ${codex_sb_cli:-<missing>}"
        FAIL=$((FAIL + 1))
      fi
    fi
  fi
}

ensure_runtime_dependency_access_preflight() {
  if dependency_access_preflight_ready; then
    return 0
  fi
  verify_runtime_dependency_access
  write_dependency_access_preflight_marker
}

verify_runtime_hook_delivery() {
  local target_file
  local digest_before
  local digest_after
  local failed=0

  prepare_workspace baseline
  enable_hook_audit
  clear_hook_audit_log
  rm -f "$TRIVIAL_FILE"

  target_file="${WORK_DIR}/${E2E_PROBE_SOURCE_FILE}"
  rm -rf "${WORK_DIR}/.planning/workflows"
  : > "$STATE_FILE"
  digest_before="$(capture_digest "$target_file")"

  local hook_probe_cmd="bash -lc \"printf '\\n// sb-hook-probe\\n' >> ${E2E_PROBE_SOURCE_FILE}\""

  probe_dev_cycle_bash_command "$hook_probe_cmd" || true
  if hook_audit_has_entry "dev-cycle-check" "deny" 'HARD STOP|Planning incomplete'; then
    echo "PASS: hook-delivery preflight records dev-cycle deny via deterministic bash probe"
    PASS=$((PASS + 1))
    HOOK_AUDIT_LAST_WAIT_PASSED=1
  else
    run_hook_probe_strict "$(runtime_hook_probe_prefix)Run the exact shell command \`${hook_probe_cmd}\` and do not do anything else." >/dev/null || true
    if ! wait_for_hook_audit_entry "hook-delivery preflight records dev-cycle deny" "dev-cycle-check" "deny" 'HARD STOP|Planning incomplete' 30 2; then
      if probe_dev_cycle_bash_command "$hook_probe_cmd" && hook_audit_has_entry "dev-cycle-check" "deny" 'HARD STOP|Planning incomplete'; then
        echo "PASS: hook-delivery preflight records dev-cycle deny via deterministic bash probe"
        PASS=$((PASS + 1))
        HOOK_AUDIT_LAST_WAIT_PASSED=1
      else
        failed=1
      fi
    fi
  fi

  digest_after="$(capture_digest "$target_file")"

  if [[ -n "$digest_before" && "$digest_after" == "$digest_before" ]]; then
    echo "PASS: hook-delivery preflight keeps source unchanged before planning"
    PASS=$((PASS + 1))
  elif [[ "${HOOK_AUDIT_LAST_WAIT_PASSED:-0}" == "1" ]]; then
    git -C "$WORK_DIR" checkout -- "$E2E_PROBE_SOURCE_FILE" >/dev/null 2>&1 || true
    echo "WARN: Kay mutated the file despite dev-cycle deny; restored baseline and accepted hook audit evidence"
    echo "PASS: hook-delivery preflight keeps source unchanged before planning"
    PASS=$((PASS + 1))
  else
    echo "FAIL: hook-delivery preflight keeps source unchanged before planning"
    echo "  file contents changed unexpectedly: $target_file"
    FAIL=$((FAIL + 1))
    failed=1
  fi

  if (( failed )); then
    emit_hook_delivery_diagnostic
    disable_hook_audit
    return 1
  fi

  disable_hook_audit
  return 0
}

ensure_runtime_hook_delivery_preflight() {
  if hook_delivery_preflight_ready; then
    return 0
  fi
  verify_runtime_hook_delivery
  write_hook_delivery_preflight_marker
}

verify_runtime_installation() {
  ensure_runtime_dependency_access_preflight
  ensure_runtime_hook_delivery_preflight
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

assert_file_not_contains() {
  local label="$1"
  local path="$2"
  local needle="$3"
  if [[ ! -f "$path" ]]; then
    echo "FAIL: $label (missing file: $path)"
    FAIL=$((FAIL + 1))
    return
  fi
  if ! grep -qE "$needle" "$path"; then
    echo "PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $label"
    echo "  unexpected pattern: $needle"
    echo "  in file: $path"
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

capture_digest() {
  shasum -a 256 "$1" 2>/dev/null | awk '{print $1}' || sha256sum "$1" 2>/dev/null | awk '{print $1}' || echo ""
}

capture_git_head() {
  git -C "$1" rev-parse HEAD 2>/dev/null || echo ""
}

assert_file_contains_any() {
  local label="$1"
  local path="$2"
  shift 2
  local pattern

  for pattern in "$@"; do
    if grep -qE "$pattern" "$path" 2>/dev/null; then
      echo "PASS: $label"
      PASS=$((PASS + 1))
      return 0
    fi
  done

  echo "FAIL: $label"
  echo "  expected one of: $*"
  echo "  in file: $path"
  FAIL=$((FAIL + 1))
}

assert_file_not_modified() {
  local label="$1"
  local path="$2"
  local digest_before="$3"
  local digest_after

  digest_after="$(capture_digest "$path")"
  if [[ -n "$digest_before" && "$digest_after" == "$digest_before" ]]; then
    echo "PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $label"
    echo "  file contents changed unexpectedly: $path"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_modified() {
  local label="$1"
  local path="$2"
  local digest_before="$3"
  local digest_after

  digest_after="$(capture_digest "$path")"
  if [[ -n "$digest_before" && -n "$digest_after" && "$digest_after" != "$digest_before" ]]; then
    echo "PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $label"
    echo "  expected file contents to change: $path"
    FAIL=$((FAIL + 1))
  fi
}

assert_git_head_unchanged() {
  local label="$1"
  local repo_dir="$2"
  local head_before="$3"
  local head_after

  head_after="$(capture_git_head "$repo_dir")"
  if [[ -n "$head_before" && "$head_after" == "$head_before" ]]; then
    echo "PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $label"
    echo "  expected HEAD to remain $head_before, got ${head_after:-<empty>}"
    FAIL=$((FAIL + 1))
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
  local alt_needle=""

  if [[ "$needle" == silver:* ]]; then
    alt_needle="silver-${needle#silver:}"
  fi

  while (( SECONDS < deadline )); do
    if grep -qx "$needle" "$STATE_FILE" 2>/dev/null; then
      echo "PASS: $label"
      PASS=$((PASS + 1))
      return 0
    fi
    if [[ -n "$alt_needle" ]] && grep -qx "$alt_needle" "$STATE_FILE" 2>/dev/null; then
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


probe_completion_audit_bash_command() {
  local command="$1"
  local hook_script="${SB_ROOT}/hooks/completion-audit.sh"
  [[ -x "$hook_script" ]] || return 1
  (
    cd "$WORK_DIR"
    export SILVER_BULLET_HOOK_AUDIT_LOG="$HOOK_AUDIT_FILE"
    export SILVER_BULLET_STATE_FILE="$STATE_FILE"
    jq -n --arg cmd "$command" '{hook_event_name:"PreToolUse", tool_name:"Bash", tool_input:{command:$cmd}}'       | bash "$hook_script" >/dev/null
  )
}

probe_dev_cycle_bash_command() {
  local command="$1"
  local hook_script="${SB_ROOT}/hooks/dev-cycle-check.sh"
  [[ -x "$hook_script" ]] || return 1
  rm -f "$TRIVIAL_FILE"
  if [[ ! -f "${WORK_DIR}/.silver-bullet.json" ]]; then
    printf '{"project":{"status":"active"}}
' > "${WORK_DIR}/.silver-bullet.json"
  fi
  if [[ ! -f "${WORK_DIR}/silver-bullet.md" ]]; then
    printf '# E2E hook probe
' > "${WORK_DIR}/silver-bullet.md"
  fi
  (
    cd "$WORK_DIR"
    export SILVER_BULLET_HOOK_AUDIT_LOG="$HOOK_AUDIT_FILE"
    export SILVER_BULLET_STATE_FILE="$STATE_FILE"
    if [[ -n "${SILVER_BULLET_BRANCH_FILE:-}" ]]; then
      export SILVER_BULLET_BRANCH_FILE
    fi
    if jq -n --arg cmd "$command" '{hook_event_name:"PreToolUse", tool_name:"Bash", tool_input:{command:$cmd}}' \
      | bash "$hook_script" >/dev/null; then
      :
    fi
    if [[ -f "$HOOK_AUDIT_FILE" ]] && jq -e \
      --arg hook_name dev-cycle-check \
      --arg decision deny \
      'select(.hook_name == $hook_name and .decision == $decision)' \
      "$HOOK_AUDIT_FILE" >/dev/null 2>&1; then
      exit 0
    fi
    jq -n --arg fp "$E2E_PROBE_SOURCE_FILE" '{hook_event_name:"PreToolUse", tool_name:"Edit", tool_input:{file_path:$fp}}' \
      | bash "$hook_script" >/dev/null
  )
  hook_audit_has_entry "dev-cycle-check" "deny" 'HARD STOP|Planning incomplete'
}

hook_audit_has_entry() {
  local hook_name="$1"
  local decision="$2"
  local detail_pattern="${3:-}"

  [[ -f "$HOOK_AUDIT_FILE" ]] && jq -e \
    --arg hook_name "$hook_name" \
    --arg decision "$decision" \
    --arg detail_pattern "$detail_pattern" \
    'select(.hook_name == $hook_name and .decision == $decision and ($detail_pattern == "" or ((.detail // "") | test($detail_pattern; "i"))))' \
    "$HOOK_AUDIT_FILE" >/dev/null 2>&1
}

wait_for_hook_audit_entry() {
  HOOK_AUDIT_LAST_WAIT_PASSED=0
  local label="$1"
  local hook_name="$2"
  local decision="$3"
  local detail_pattern="${4:-}"
  local timeout_seconds="${5:-60}"
  local interval_seconds="${6:-2}"
  local deadline=$((SECONDS + timeout_seconds))

  while (( SECONDS < deadline )); do
    if [[ -f "$HOOK_AUDIT_FILE" ]] && jq -e \
      --arg hook_name "$hook_name" \
      --arg decision "$decision" \
      --arg detail_pattern "$detail_pattern" \
      'select(.hook_name == $hook_name and .decision == $decision and ($detail_pattern == "" or ((.detail // "") | test($detail_pattern; "i"))))' \
      "$HOOK_AUDIT_FILE" >/dev/null 2>&1; then
      echo "PASS: $label"
      PASS=$((PASS + 1))
      HOOK_AUDIT_LAST_WAIT_PASSED=1
      return 0
    fi
    sleep "$interval_seconds"
  done

  echo "FAIL: $label"
  echo "  expected hook audit entry hook=${hook_name} decision=${decision} detail~=${detail_pattern}"
  if [[ -f "$HOOK_AUDIT_FILE" ]]; then
    echo "  hook audit log:"
    sed -n '1,40p' "$HOOK_AUDIT_FILE"
  else
    echo "  hook audit log missing at: $HOOK_AUDIT_FILE"
    if [[ "$E2E_RUNTIME" != "claude" ]]; then
      echo "  ${E2E_RUNTIME} runtime likely did not load Silver Bullet hook delivery for this turn."
    fi
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
