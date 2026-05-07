#!/usr/bin/env bash
# Shared helpers for the live todo-app E2E suite.
#
# The suite runs Claude and Codex against an isolated copy of tests/test-app,
# then resets the workspace after each scenario. The real SB state files under
# ~/.claude/.silver-bullet are backed up and restored around each scenario so
# the suite can run repeatedly without cross-talk.

set -euo pipefail

PATH="/Users/shafqat/.local/bin:/opt/homebrew/bin:/Applications/Codex.app/Contents/Resources:${PATH:-/usr/bin:/bin:/usr/sbin:/sbin}"
export PATH

E2E_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SB_ROOT="$(cd "${E2E_ROOT}/../.." && pwd)"
FIXTURE_DIR="${SB_ROOT}/tests/test-app"
RUNTIME_DIR="${SB_ROOT}/tests/live/runtimes"
SB_TEST_DIR="${HOME}/.claude/.silver-bullet"
CLAUDE_INSTALL_SCRIPT="${SB_ROOT}/scripts/install-claude.sh"

E2E_RUNTIME="${SB_E2E_LIVE_RUNTIME:-${SB_LIVE_RUNTIME:-claude}}"
MAX_BUDGET="${SB_E2E_LIVE_BUDGET_USD:-10.00}"
APP_PORT="${SB_E2E_LIVE_PORT:-3456}"

WORK_DIR=""
APP_SERVER_PID=""
APP_SERVER_LOG=""
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
    # shellcheck source=tests/live/runtimes/claude.sh
    source "$RUNTIME_DIR/claude.sh"
    ;;
  codex)
    # shellcheck source=tests/live/runtimes/codex.sh
    source "$RUNTIME_DIR/codex.sh"
    ;;
  *)
    printf 'ERROR: unsupported e2e live runtime: %s\n' "$E2E_RUNTIME" >&2
    exit 2
    ;;
esac

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
}

prepare_workspace() {
  local mode="${1:-baseline}"

  WORK_DIR="$(mktemp -d)"
  APP_SERVER_LOG="${WORK_DIR}/server.log"

  cp -R "${FIXTURE_DIR}/." "${WORK_DIR}/"

  mkdir -p "${WORK_DIR}/.claude"
  cat > "${WORK_DIR}/.claude/settings.local.json" <<'EOF'
{
  "permissions": {
    "defaultMode": "auto"
  }
}
EOF

  if [[ "$mode" == "clean-sb" ]]; then
    rm -rf \
      "${WORK_DIR}/.planning" \
      "${WORK_DIR}/.silver-bullet.json" \
      "${WORK_DIR}/silver-bullet.md" \
      "${WORK_DIR}/CLAUDE.md" \
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

  git -C "$WORK_DIR" init -q --bare "${WORK_DIR}/.remote.git"
  git -C "$WORK_DIR" remote add origin "${WORK_DIR}/.remote.git"
  git -C "$WORK_DIR" push -u origin feature/e2e-live >/dev/null 2>&1 || true

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

  runtime_preflight

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

  restore_session_state
}

trap cleanup_workspace EXIT

start_app_server() {
  local ready=0
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

run_prompt() {
  local prompt="$1"
  if [[ "$E2E_RUNTIME" == "claude" ]]; then
    claude_interactive_invoke permissive "$prompt"
  else
    runtime_invoke permissive "$prompt"
  fi
}

run_prompt_strict() {
  local prompt="$1"
  if [[ "$E2E_RUNTIME" == "claude" ]]; then
    claude_interactive_invoke default "$prompt"
  else
    runtime_invoke default "$prompt"
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
    permission_mode="bypassPermissions"
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

  cli="$(runtime_cli_path)"
  (cd "$WORK_DIR" && "$cli" plugin list --json 2>/dev/null \
    | jq -e --arg id "$plugin_id" 'any(.[]?; .id == $id)' >/dev/null 2>&1)
}

claude_plugin_installed_in_scope() {
  local plugin_id="$1"
  local scope="$2"
  local cli

  cli="$(runtime_cli_path)"
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

wait_for_file_exists() {
  local label="$1"
  local path="$2"
  local timeout_seconds="${3:-120}"
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
  local timeout_seconds="${4:-120}"
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

wait_for_state_contains() {
  local label="$1"
  local needle="$2"
  local timeout_seconds="${3:-120}"
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
