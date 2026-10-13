#!/usr/bin/env bash
# Shared helpers for live AI agent tests
# These tests invoke real claude CLI with stored credentials.
# Each invocation costs ~$0.01-0.05.

set -euo pipefail

SB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEFAULT_TEST_ENTERPRISE_APP_ROOT="$(cd "${SB_ROOT}/../.." && pwd)/enterprise-grade-test-app"
DEFAULT_TEST_TODO_APP_ROOT="$DEFAULT_TEST_ENTERPRISE_APP_ROOT"
MAX_BUDGET="1.00"
PASS=0
FAIL=0
TEST_RUN_ID="$$"

if [[ -z "${SILVER_BULLET_RUNTIME:-}" ]]; then
  case "${SB_LIVE_AGENT:-${SB_LIVE_RUNTIME:-claude}}" in
    kay|codex) SILVER_BULLET_RUNTIME="codex" ;;
    cursor) SILVER_BULLET_RUNTIME="cursor" ;;
    *) SILVER_BULLET_RUNTIME="claude" ;;
  esac
fi
if [[ -f "$SB_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$SB_ROOT/hooks/lib/runtime-paths.sh"
fi

LIVE_AGENT="${SB_LIVE_AGENT:-${SB_LIVE_RUNTIME:-claude}}"
KAY_HOME="${KAY_HOME:-${SB_LIVE_CODEX_ISOLATION_DIR:-${KAY_SB_TEST_HOME:-}}}"
if [[ "$LIVE_AGENT" == "kay" && -f "$SB_ROOT/tests/live/lib/kay-codex-isolation.sh" ]]; then
  # shellcheck source=tests/live/lib/kay-codex-isolation.sh
  source "$SB_ROOT/tests/live/lib/kay-codex-isolation.sh"
fi

AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/agents" && pwd)"
case "$LIVE_AGENT" in
  claude)
    # shellcheck source=tests/live/agents/claude/agent.sh
    source "$AGENT_DIR/claude/agent.sh"
    ;;
  codex)
    # shellcheck source=tests/live/agents/codex/agent.sh
    source "$AGENT_DIR/codex/agent.sh"
    ;;
  kay)
    # shellcheck source=tests/live/agents/kay/agent.sh
    source "$AGENT_DIR/kay/agent.sh"
    ;;
  cursor)
    SILVER_BULLET_RUNTIME="${SILVER_BULLET_RUNTIME:-cursor}"
    # shellcheck source=tests/live/agents/cursor/agent.sh
    source "$AGENT_DIR/cursor/agent.sh"
    ;;
  *)
    printf 'ERROR: unsupported live agent: %s\n' "$LIVE_AGENT" >&2
    exit 2
    ;;
esac

# The REAL state path that hooks always write to.
if [[ "$LIVE_AGENT" == "kay" ]]; then
  SB_TEST_DIR="${KAY_HOME}/.codex/.silver-bullet"
  REAL_MCP_AUTH_CACHE="${KAY_HOME}/.kay/mcp-needs-auth-cache.json"
  REAL_MCP_AUTH_CACHE_BACKUP="${KAY_HOME}/.kay/mcp-needs-auth-cache.live-test-backup-${TEST_RUN_ID}"
else
  SB_TEST_DIR="${SB_RUNTIME_HOME_ROOT}/.silver-bullet"
  REAL_MCP_AUTH_CACHE="${SB_RUNTIME_HOME_ROOT}/mcp-needs-auth-cache.json"
  REAL_MCP_AUTH_CACHE_BACKUP="${SB_RUNTIME_HOME_ROOT}/mcp-needs-auth-cache.live-test-backup-${TEST_RUN_ID}"
fi
REAL_STATE="${SB_TEST_DIR}/state"
REAL_STATE_BACKUP="${SB_TEST_DIR}/state.live-test-backup-${TEST_RUN_ID}"
REAL_TRIVIAL="${SB_TEST_DIR}/trivial"
REAL_TRIVIAL_BACKUP="${SB_TEST_DIR}/trivial.live-test-backup-${TEST_RUN_ID}"

# Paths set by live_setup (kept for compatibility but assertions use REAL_STATE)
WORK_DIR=""
TMPSTATE=""
TMPTRIVIAL=""

live_setup() {
  agent_preflight
  # Reset per-scenario Claude session state so fresh workspaces do not
  # accidentally inherit `--continue` from a previous live setup.
  CLAUDE_PROMPT_COUNT=0
  WORK_DIR=$(mktemp -d)
  # TMPSTATE points to REAL_STATE so assert_state_* helpers work correctly
  TMPSTATE="$REAL_STATE"
  TMPTRIVIAL="$REAL_TRIVIAL"

  # Backup and clear the real state file so each test starts clean
  mkdir -p "$SB_TEST_DIR"
  if [[ -f "$REAL_STATE" ]]; then
    cp "$REAL_STATE" "$REAL_STATE_BACKUP"
  fi
  : > "$REAL_STATE"
  if [[ "${SB_LIVE_DEBUG_DUMP:-0}" == "1" ]]; then
    : > "${SB_TEST_DIR}/debug-dump"
    : > "${SB_TEST_DIR}/hook-dump.jsonl"
  else
    rm -f "${SB_TEST_DIR}/debug-dump" "${SB_TEST_DIR}/hook-dump.jsonl"
  fi

  if [[ -f "$REAL_TRIVIAL" ]]; then
    cp "$REAL_TRIVIAL" "$REAL_TRIVIAL_BACKUP"
    rm -f "$REAL_TRIVIAL"
  fi

  if [[ -f "$REAL_MCP_AUTH_CACHE" ]]; then
    cp "$REAL_MCP_AUTH_CACHE" "$REAL_MCP_AUTH_CACHE_BACKUP"
  else
    rm -f "$REAL_MCP_AUTH_CACHE_BACKUP"
  fi
  printf '{}\n' > "$REAL_MCP_AUTH_CACHE"

  if [[ "$LIVE_AGENT" == "kay" ]]; then
    local session_catalog_path="${CODEX_SESSION_CATALOG_PATH:-${KAY_HOME}/.kay/sessions/index/catalog.jsonl}"
    mkdir -p "$(dirname "$session_catalog_path")"
    : > "$session_catalog_path"
  fi

  # Initialize git repo in workspace
  git -C "$WORK_DIR" init -q
  git -C "$WORK_DIR" config user.email "live-test@silver-bullet.test"
  git -C "$WORK_DIR" config user.name "Live Test"
  cat > "$WORK_DIR/silver-bullet.md" <<'EOF'
# Silver Bullet
EOF
  touch "$WORK_DIR/.gitkeep"
  git -C "$WORK_DIR" add .gitkeep
  git -C "$WORK_DIR" commit -q -m "init"
  git -C "$WORK_DIR" checkout -q -b feature/live-test

  if [[ "$LIVE_AGENT" == "kay" ]]; then
    python3 - "${KAY_HOME}/.kay/config.toml" "$WORK_DIR" <<'PY'
import pathlib
import sys

config_path = pathlib.Path(sys.argv[1])
workspace = pathlib.Path(sys.argv[2]).resolve()
text = config_path.read_text() if config_path.is_file() else ""
header = f'[projects."{workspace}"]'
lines = text.splitlines()
out = []
index = 0
found = False

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

config_path.write_text("\n".join(out).rstrip("\n") + "\n")
PY
    if declare -F kay_register_silver_bullet_project_hooks >/dev/null 2>&1; then
      kay_register_silver_bullet_project_hooks "$WORK_DIR"
    fi
  fi

  # Copy enterprise fixture app tree into workspace from the sibling repo when available.
  local fixture_root="${SB_TEST_ENTERPRISE_APP_ROOT:-${SB_TEST_TODO_APP_ROOT:-${DEFAULT_TEST_ENTERPRISE_APP_ROOT}}}"
  if [[ -d "${fixture_root}/api" ]]; then
    cp -r "${fixture_root}/api" "${WORK_DIR}/api"
  fi
  if [[ -d "${fixture_root}/ui" ]]; then
    cp -r "${fixture_root}/ui" "${WORK_DIR}/ui"
  fi
  if [[ -d "${fixture_root}/src" ]]; then
    cp -r "${fixture_root}/src" "${WORK_DIR}/src"
  elif [[ ! -d "${WORK_DIR}/api" ]]; then
    mkdir -p "${WORK_DIR}/src"
    echo "// placeholder" > "${WORK_DIR}/src/index.js"
  fi

  local disabled_mcpjson_servers_json="[]"
  if [[ -f "$REAL_MCP_AUTH_CACHE" ]]; then
    disabled_mcpjson_servers_json="$(jq -c 'keys' "$REAL_MCP_AUTH_CACHE" 2>/dev/null || printf '[]')"
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

  # Write .silver-bullet.json pointing to REAL state paths
  cat > "${WORK_DIR}/.silver-bullet.json" << EOJSON
{
  "project": {"name":"live-test","src_pattern":"/src/","src_exclude_pattern":"__tests__|\\\\.test\\\\.","active_workflow":"full-dev-cycle"},
  "skills": {
    "required_planning": ["silver-quality-gates"],
    "required_deploy": ["silver-quality-gates","silver-review","requesting-code-review","receiving-code-review","finishing-a-development-branch","silver-create-release","verification-before-completion","test-driven-development","verify-tests"],
    "all_tracked": ["silver-quality-gates","silver-init","silver-ingest","silver-scan","silver-deep-research","silver-blast-radius","silver-spec","silver-add","silver-feature","silver-ui","silver-fast","silver-forensics","silver-bugfix","silver-validate","silver-create-release","silver-release","silver-update","silver-remove","silver-rem","silver-ensure-docs","code-review","requesting-code-review","receiving-code-review","testing-strategy","documentation","finishing-a-development-branch","deploy-checklist","verification-before-completion","test-driven-development","tech-debt","silver-context","silver-plan","silver-execute","silver-verify","silver-ui-contract","silver-ui-review"]
  },
  "state": {"state_file":"${REAL_STATE}","trivial_file":"${REAL_TRIVIAL}"}
}
EOJSON

  # Commit the config
  git -C "$WORK_DIR" add -A
  git -C "$WORK_DIR" commit -q -m "setup"

  if [[ "$LIVE_AGENT" == "kay" && "${SB_LIVE_CODEX_GUARD:-0}" == "1" ]]; then
    cat > "$WORK_DIR/AGENTS.md" <<'EOF'
# Silver Bullet Live Test Override

This workspace is governed by Silver Bullet. Before any direct file edit, inspect
`.silver-bullet.json` and the current state file.

If the planning state does not yet include the required planning skill(s), refuse
the edit and say that planning is incomplete or blocked.

If the planning state shows the required planning skill(s) have been recorded for
the scenario, proceed with the requested edit normally.

Do not guess about the state. Do not edit first and check later.
EOF
    cat > "$WORK_DIR/AGENTS.override.md" <<'EOF'
# Silver Bullet Live Test Override

This workspace is governed by Silver Bullet. Before any direct file edit, inspect
`.silver-bullet.json` and the current state file.

If the planning state does not yet include the required planning skill(s), refuse
the edit and say that planning is incomplete or blocked.

If the planning state shows the required planning skill(s) have been recorded for
the scenario, proceed with the requested edit normally.

Do not guess about the state. Do not edit first and check later.
EOF
  fi
}

live_teardown() {
  rm -rf "$WORK_DIR"

  # Restore backed-up state file (or remove if it didn't exist before)
  if [[ -f "$REAL_STATE_BACKUP" ]]; then
    mv "$REAL_STATE_BACKUP" "$REAL_STATE"
  else
    rm -f "$REAL_STATE"
  fi

  if [[ -f "$REAL_TRIVIAL_BACKUP" ]]; then
    mv "$REAL_TRIVIAL_BACKUP" "$REAL_TRIVIAL"
  fi

  if [[ -f "$REAL_MCP_AUTH_CACHE_BACKUP" ]]; then
    mv "$REAL_MCP_AUTH_CACHE_BACKUP" "$REAL_MCP_AUTH_CACHE"
  else
    rm -f "$REAL_MCP_AUTH_CACHE"
  fi

  rm -f "${SB_TEST_DIR}/config-cache-"*
}

# invoke_claude: default invocation — hook denials (permissionDecision:deny) are enforced.
# Use this for enforcement tests (S1, S2, S3, S4) where blocking behavior must be observed.
invoke_claude() {
  local prompt="$1"
  agent_invoke default "$prompt"
}

# invoke_claude_permissive: bypasses file-read permission prompts.
# Use this for skill-invocation tests where the skill reads files (silver-quality-gates, etc.)
# but hook deny decisions (permissionDecision:deny) are also bypassed — do NOT use
# for enforcement tests.
invoke_claude_permissive() {
  local prompt="$1"
  agent_invoke permissive "$prompt"
}

assert_response_contains() {
  local label="$1"
  local response="$2"
  local needle="$3"
  if printf '%s' "$response" | grep -iE "$needle" >/dev/null 2>&1; then
    PASS=$((PASS + 1))
    printf 'PASS: %s\n' "$label"
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL: %s\n  (expected pattern "%s" in response)\n' "$label" "$needle"
    printf '  Response snippet: %s\n' "$(printf '%s' "$response" | head -c 400)"
  fi
}

assert_response_not_contains() {
  local label="$1"
  local response="$2"
  local needle="$3"
  if ! printf '%s' "$response" | grep -iE "$needle" >/dev/null 2>&1; then
    PASS=$((PASS + 1))
    printf 'PASS: %s\n' "$label"
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL: %s\n  (unexpected pattern "%s" found in response)\n' "$label" "$needle"
    printf '  Response snippet: %s\n' "$(printf '%s' "$response" | head -c 400)"
  fi
}

assert_state_contains() {
  local label="$1"
  local skill_name="$2"
  if [[ -f "$TMPSTATE" ]] && grep -qx "$skill_name" "$TMPSTATE" 2>/dev/null; then
    PASS=$((PASS + 1))
    printf 'PASS: %s\n' "$label"
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL: %s\n  (skill "%s" not found in state file %s)\n' "$label" "$skill_name" "$TMPSTATE"
    if [[ -f "$TMPSTATE" ]]; then
      printf '  State contents: %s\n' "$(cat "$TMPSTATE")"
    else
      printf '  State file does not exist.\n'
    fi
  fi
}

assert_state_not_contains() {
  local label="$1"
  local skill_name="$2"
  if [[ ! -f "$TMPSTATE" ]] || ! grep -qx "$skill_name" "$TMPSTATE" 2>/dev/null; then
    PASS=$((PASS + 1))
    printf 'PASS: %s\n' "$label"
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL: %s\n  (unexpected skill "%s" found in state file)\n' "$label" "$skill_name"
  fi
}

assert_file_exists() {
  local label="$1"
  local filepath="$2"
  if [[ -e "$filepath" ]]; then
    PASS=$((PASS + 1))
    printf 'PASS: %s\n' "$label"
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL: %s\n  (file/dir not found: %s)\n' "$label" "$filepath"
  fi
}

print_results() {
  printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
  [[ $FAIL -eq 0 ]] && exit 0 || exit 1
}

capture_mtime() {
  stat -f "%m" "$1" 2>/dev/null || stat --format="%Y" "$1" 2>/dev/null || echo "0"
}

capture_digest() {
  shasum -a 256 "$1" 2>/dev/null | awk '{print $1}' || sha256sum "$1" 2>/dev/null | awk '{print $1}' || echo ""
}

assert_file_contains() {
  local label="$1" filepath="$2" needle="$3"
  if grep -qiE "$needle" "$filepath" 2>/dev/null; then
    PASS=$((PASS + 1))
    printf 'PASS: %s\n' "$label"
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL: %s\n  (expected pattern "%s" in %s)\n' "$label" "$needle" "$filepath"
    printf '  File snippet: %s\n' "$(head -c 400 "$filepath" 2>/dev/null || echo '(file not found)')"
  fi
}

assert_file_not_contains() {
  local label="$1" filepath="$2" needle="$3"
  if ! grep -qiE "$needle" "$filepath" 2>/dev/null; then
    PASS=$((PASS + 1))
    printf 'PASS: %s\n' "$label"
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL: %s\n  (unexpected pattern "%s" found in %s)\n' "$label" "$needle" "$filepath"
    printf '  File snippet: %s\n' "$(head -c 400 "$filepath" 2>/dev/null)"
  fi
}

assert_file_modified() {
  local label="$1" filepath="$2" mtime_before="$3"
  local mtime_after
  mtime_after=$(capture_mtime "$filepath")
  if [[ "$mtime_after" -gt "$mtime_before" ]]; then
    PASS=$((PASS + 1))
    printf 'PASS: %s\n' "$label"
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL: %s\n  (file mtime not updated: before=%s after=%s)\n' "$label" "$mtime_before" "$mtime_after"
  fi
}

assert_file_not_modified() {
  local label="$1" filepath="$2" digest_before="$3"
  local digest_after
  digest_after=$(capture_digest "$filepath")
  if [[ -n "$digest_before" ]] && [[ "$digest_after" == "$digest_before" ]]; then
    PASS=$((PASS + 1))
    printf 'PASS: %s\n' "$label"
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL: %s\n  (file contents changed unexpectedly)\n' "$label"
  fi
}

assert_file_changed() {
  local label="$1" filepath="$2" digest_before="$3"
  local digest_after
  digest_after=$(capture_digest "$filepath")
  if [[ -z "$digest_before" ]]; then
    if [[ -n "$digest_after" ]]; then
      PASS=$((PASS + 1))
      printf 'PASS: %s\n' "$label"
      return 0
    fi
  elif [[ "$digest_after" != "$digest_before" ]]; then
    PASS=$((PASS + 1))
    printf 'PASS: %s\n' "$label"
    return 0
  fi

  FAIL=$((FAIL + 1))
  printf 'FAIL: %s\n  (file contents did not change as expected)\n' "$label"
}

seed_state() {
  # Write given skill names (one per line) to the real state file
  mkdir -p "$(dirname "$REAL_STATE")"
  : > "$REAL_STATE"
  for skill in "$@"; do
    printf '%s\n' "$skill" >> "$REAL_STATE"
  done
}
