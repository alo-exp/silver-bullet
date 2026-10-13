#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — expected [$expected], got [$actual]"
    (( FAIL++ )) || true
  fi
}

assert_file_contains() {
  local desc="$1" path="$2" needle="$3"
  if grep -qF "$needle" "$path"; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — missing [$needle] in $path"
    (( FAIL++ )) || true
  fi
}

assert_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — missing [$needle]"
    (( FAIL++ )) || true
  fi
}

assert_file_not_contains() {
  local desc="$1" path="$2" needle="$3"
  if grep -qF "$needle" "$path"; then
    echo "FAIL: $desc — unexpected [$needle] in $path"
    (( FAIL++ )) || true
  else
    echo "PASS: $desc"
    (( PASS++ )) || true
  fi
}

assert_file_exists() {
  local desc="$1" path="$2"
  if [[ -e "$path" ]]; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — missing [$path]"
    (( FAIL++ )) || true
  fi
}

assert_command_succeeds() {
  local desc="$1"
  shift
  if "$@"; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc"
    (( FAIL++ )) || true
  fi
}

capture_digest() {
  local path="$1"
  [[ -e "$path" ]] || return 0
  # Kay bridge denial shims may shadow awk on PATH; prefer system tools for digests.
  PATH="/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"
  shasum -a 256 "$path" | awk '{print $1}'
}

reset_bridge_denial_state() {
  find "$ACTIVE_SHIM_DIR" -mindepth 1 -delete 2>/dev/null || true
  if [[ -e "$BRIDGE_TARGET" ]]; then
    chmod u+w "$BRIDGE_TARGET" 2>/dev/null || true
    if command -v chflags >/dev/null 2>&1; then
      chflags nouchg "$BRIDGE_TARGET" 2>/dev/null || true
    fi
  fi
  chmod u+w "$BRIDGE_WORKSPACE" 2>/dev/null || true
  if command -v chflags >/dev/null 2>&1; then
    chflags nouchg "$BRIDGE_WORKSPACE" 2>/dev/null || true
    if [[ -d "$BRIDGE_WORKSPACE/.git" ]]; then
      chflags -R nouchg "$BRIDGE_WORKSPACE/.git" 2>/dev/null || true
    fi
  fi
  if [[ -d "$BRIDGE_WORKSPACE/.git" ]]; then
    chmod -R u+w "$BRIDGE_WORKSPACE/.git" 2>/dev/null || true
  fi
  : > "$KAY_HOME/.codex/.silver-bullet/state"
}

assert_file_unchanged() {
  local desc="$1" path="$2" before="$3"
  local after
  after="$(capture_digest "$path")"
  if [[ -n "$before" && "$before" == "$after" ]]; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — file changed unexpectedly: $path"
    (( FAIL++ )) || true
  fi
}

TEST_RUN_ID="${TEST_RUN_ID:-$$}"
export TEST_RUN_ID
# Keep mktemp under a slash-normalized root so pathlib prefix rewrites match
# fixture paths (TMPDIR on macOS often ends with /).
_SB_KAY_TMP_ROOT="${TMPDIR:-/tmp}"
_SB_KAY_TMP_ROOT="${_SB_KAY_TMP_ROOT%/}"
TMP="$(mktemp -d "${_SB_KAY_TMP_ROOT}/sb-kay-codex-isolation-${TEST_RUN_ID}.XXXXXX")"
cleanup_tmp_dir() {
  if [[ -n "${BRIDGE_WORKSPACE:-}" && -d "${BRIDGE_WORKSPACE:-}" ]]; then
    chmod -R u+w "$BRIDGE_WORKSPACE" 2>/dev/null || true
    if command -v chflags >/dev/null 2>&1; then
      chflags -R nouchg "$BRIDGE_WORKSPACE" 2>/dev/null || true
    fi
  fi
  rm -rf "$TMP"
}
trap cleanup_tmp_dir EXIT

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ORIGINAL_HOME="$TMP/original-home"
FAKE_BIN="$TMP/bin/kay"
# Portable trusted-project fixture path (avoid machine-specific absolute paths).
FIXTURE_PROJECT_PATH="$TMP/fixture-project"
mkdir -p "$ORIGINAL_HOME/.kay" "$(dirname "$FAKE_BIN")"
mkdir -p "$ORIGINAL_HOME/.codex/hooks" "$ORIGINAL_HOME/.codex/plugins" "$ORIGINAL_HOME/.codex/skills/external-discuss-phase" "$ORIGINAL_HOME/.agents/skills/external-plan-phase" "$ORIGINAL_HOME/.codex/.tmp/marketplaces/alo-labs-codex/plugins/silver-bullet/.codex-plugin"
mkdir -p "$ORIGINAL_HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet/0.37.4/.codex-plugin"
mkdir -p "$ORIGINAL_HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet/0.37.4/hooks"
mkdir -p "$ORIGINAL_HOME/.codex/plugins/cache/superpowers-marketplace/superpowers/5.1.0/skills/verification-before-completion"

cat > "$ORIGINAL_HOME/.kay/auth.json" <<'EOF'
{
  "provider_credentials": {
    "minimax": {
      "api_key": "test-minimax-key"
    }
  }
}
EOF

cat > "$FAKE_BIN" <<'EOF'
#!/usr/bin/env bash
printf 'kay 0.9.6\n'
EOF
chmod +x "$FAKE_BIN"
ln -sfn 0.37.4 "$ORIGINAL_HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet/current"
ln -sfn 5.1.0 "$ORIGINAL_HOME/.codex/plugins/cache/superpowers-marketplace/superpowers/current"
cat > "$ORIGINAL_HOME/.codex/config.toml" <<EOF
model = "gpt-5.5"
model_reasoning_effort = "medium"
approval_policy = "on-failure"
sandbox_mode = "read-only"

[marketplaces.alo-labs-codex]
source_type = "git"
source = "https://github.com/alo-labs/agent-plugins"

[marketplaces.superpowers-marketplace]
source_type = "git"
source = "https://github.com/obra/superpowers-marketplace.git"

[features]
plugin_hooks = true

hooks = true

[hooks.state]

[hooks.state."${ORIGINAL_HOME}/.codex/hooks.json:pre_tool_use:0:0"]
trusted_hash = "sha256:test"

[plugins."silver-bullet@alo-labs-codex"]
enabled = true

[plugins."superpowers@superpowers-marketplace"]
enabled = true

[mcp_servers.node_repl.env]
CODEX_HOME = "${ORIGINAL_HOME}/.codex"
NODE_REPL_TRUSTED_CODE_PATHS = "${ORIGINAL_HOME}/.codex"

[projects."${FIXTURE_PROJECT_PATH}"]
trust_level = "trusted"
EOF
cat > "$ORIGINAL_HOME/.codex/hooks.json" <<'EOF'
{
  "pre_tool_use": []
}
EOF
cat > "$ORIGINAL_HOME/.codex/hooks/legacy-check-update.js" <<'EOF'
console.log("check-update");
EOF
cat > "$ORIGINAL_HOME/.codex/skills/external-discuss-phase/SKILL.md" <<'EOF'
---
name: "external-discuss-phase"
---
EOF
cat > "$ORIGINAL_HOME/.agents/skills/external-plan-phase/SKILL.md" <<'EOF'
---
name: "external:plan-phase"
---
EOF
cat > "$ORIGINAL_HOME/.codex/plugins/installed_plugins.json" <<EOF
{
  "plugins": {
    "silver-bullet@alo-labs-codex": [
      {
        "version": "0.37.4",
        "installPath": "${ORIGINAL_HOME}/.codex/plugins/cache/alo-labs-codex/silver-bullet/current"
      }
    ],
    "superpowers@superpowers-marketplace": [
      {
        "version": "5.1.0",
        "installPath": "${ORIGINAL_HOME}/.codex/plugins/cache/superpowers-marketplace/superpowers/current"
      }
    ]
  }
}
EOF
cat > "$ORIGINAL_HOME/.codex/plugins/cache/superpowers-marketplace/superpowers/5.1.0/skills/verification-before-completion/SKILL.md" <<'EOF'
---
name: verification-before-completion
---
EOF
cat > "$ORIGINAL_HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet/0.37.4/.codex-plugin/plugin.json" <<'EOF'
{
  "name": "silver-bullet"
}
EOF
cat > "$ORIGINAL_HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet/0.37.4/hooks/kay-project-hook-bridge.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

export HOME="$ORIGINAL_HOME"
export CODEX_BIN="$FAKE_BIN"
unset MINIMAX_API_KEY OPENCODE_GO_API_KEY SB_LIVE_CODEX_ISOLATION_ACTIVE SB_LIVE_CODEX_ISOLATION_DIR SB_LIVE_ORIGINAL_HOME
unset KAY_HOME KAY_SB_TEST_HOME SB_LIVE_CODEX_ISOLATION_PARENT

# shellcheck source=tests/live/lib/kay-codex-isolation.sh
source "$REPO_ROOT/tests/live/lib/kay-codex-isolation.sh"
setup_kay_codex_isolation
export SILVER_BULLET_RUNTIME=codex
source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
source "$REPO_ROOT/hooks/lib/skill-discovery.sh"

PATHLESS_ORIGINAL_HOME="$TMP/pathless-original-home"
mkdir -p "$PATHLESS_ORIGINAL_HOME/.local/bin"
cp "$FAKE_BIN" "$PATHLESS_ORIGINAL_HOME/.local/bin/kay"
PATHLESS_RESOLVED="$(
  PATH="/usr/bin:/bin" HOME="$TMP/pathless-home" SB_LIVE_ORIGINAL_HOME="$PATHLESS_ORIGINAL_HOME" \
    CODEX_BIN="" \
    bash -lc 'source "'"$REPO_ROOT"'/tests/live/lib/kay-cli.sh"; resolve_kay_cli_path'
)"
NORMALIZED_KAY_HOME="$(python3 - "$KAY_HOME" <<'PY'
import pathlib
import sys
print(pathlib.Path(sys.argv[1]))
PY
)"

assert_eq "KAY_HOME is redirected to isolated test root" "$SB_LIVE_CODEX_ISOLATION_DIR" "$KAY_HOME"
assert_eq "KAY_SB_TEST_HOME mirrors KAY_HOME" "$KAY_HOME" "$KAY_SB_TEST_HOME"
assert_eq "HOME is redirected to isolated Kay root" "$KAY_HOME" "$HOME"
assert_eq "runtime-paths resolves Codex home under isolated Kay root" "$KAY_HOME/.codex" "$SB_RUNTIME_HOME_ROOT"
assert_eq "runtime-paths resolves Codex state under isolated Kay root" "$KAY_HOME/.codex/.silver-bullet" "$SB_RUNTIME_STATE_DIR"
assert_eq "Kay CLI resolves from original home when PATH omits kay" "$PATHLESS_ORIGINAL_HOME/.local/bin/kay" "$PATHLESS_RESOLVED"
assert_eq "Kay live harness disables exec_command tool mode" "false" "$CODEX_EXPERIMENTAL_USE_EXEC_COMMAND_TOOL"
assert_eq "MiniMax key is sourced from original Kay auth" "test-minimax-key" "$MINIMAX_API_KEY"
assert_eq "OpenCode-Go key stays unset for Kay MiniMax runs" "" "${OPENCODE_GO_API_KEY:-}"
assert_eq "Kay/Codex binary is preserved" "$FAKE_BIN" "$CODEX_BIN"
case "$KAY_HOME" in
  /var/*|/private/var/*)
    echo "FAIL: isolated Kay runtime root avoids symlinked temp trees — got [$KAY_HOME]"
    (( FAIL++ )) || true
    ;;
  *)
    echo "PASS: isolated Kay runtime root avoids symlinked temp trees"
    (( PASS++ )) || true
    ;;
esac
assert_file_contains "Projected Kay config enables plugin hooks" "$KAY_HOME/.kay/config.toml" 'plugin_hooks = true'
assert_file_contains "Projected Kay Codex config enables plugin hooks" "$KAY_HOME/.codex/config.toml" 'plugin_hooks = true'
assert_file_contains "Projected Kay Codex config registers SB marketplace" "$KAY_HOME/.codex/config.toml" '[marketplaces.alo-labs-codex]'
assert_file_contains "Projected Kay Codex config enables only SB plugin" "$KAY_HOME/.codex/config.toml" '[plugins."silver-bullet@alo-labs-codex"]'
assert_file_not_contains "Projected Kay Codex config omits GSD marketplace" "$KAY_HOME/.codex/config.toml" "get-shit-done-marketplace"
assert_file_not_contains "Projected Kay Codex config omits Superpowers marketplace" "$KAY_HOME/.codex/config.toml" "superpowers-marketplace"
assert_file_not_contains "Projected Kay Codex config omits Engineering plugin" "$KAY_HOME/.codex/config.toml" '[plugins."engineering@alo-labs-codex"]'
assert_file_not_contains "Projected Kay Codex config omits Design plugin" "$KAY_HOME/.codex/config.toml" '[plugins."design@alo-labs-codex"]'
assert_file_not_contains "Projected Kay Codex config omits Product Management plugin" "$KAY_HOME/.codex/config.toml" '[plugins."product-management@alo-labs-codex"]'
assert_file_contains "Isolated Kay config pins MiniMax provider" "$KAY_HOME/.kay/config.toml" 'model_provider = "minimax"'
assert_file_contains "Isolated Kay config pins MiniMax M3" "$KAY_HOME/.kay/config.toml" 'model = "MiniMax-M3"'
assert_file_contains "Isolated Kay config pins low reasoning" "$KAY_HOME/.kay/config.toml" 'model_reasoning_effort = "low"'
assert_file_contains "Projected Kay config keeps trusted projects" "$KAY_HOME/.kay/config.toml" "[projects.\"${FIXTURE_PROJECT_PATH}\"]"
assert_contains "Kay isolation parent is namespaced per TEST_RUN_ID" "$KAY_HOME" "/.tmp/kay-isolation-${TEST_RUN_ID}/"
assert_file_contains "Projected Kay config keeps trusted project level" "$KAY_HOME/.kay/config.toml" 'trust_level = "trusted"'
assert_file_not_contains "Projected Kay config strips Codex plugin registry sections" "$KAY_HOME/.kay/config.toml" '[plugins."silver-bullet@alo-labs-codex"]'
assert_file_not_contains "Projected Kay config strips Codex hook trust state blocks" "$KAY_HOME/.kay/config.toml" '[hooks.state]'
assert_file_not_contains "Projected Kay config strips Codex agent registry sections" "$KAY_HOME/.kay/config.toml" '[agents.external-planner]'
assert_file_exists "Isolated Codex hooks directory is mirrored" "$KAY_HOME/.codex/hooks/legacy-check-update.js"
assert_file_exists "Isolated Codex hooks.json is mirrored" "$KAY_HOME/.codex/hooks.json"
assert_file_exists "Isolated Kay env mirrors host Codex skill roots" "$KAY_HOME/.codex/skills/external-discuss-phase/SKILL.md"
assert_file_exists "Isolated Kay env mirrors host .agents skill roots" "$KAY_HOME/.agents/skills/external-plan-phase/SKILL.md"
assert_command_succeeds "Isolated Kay hook discovery resolves external-discuss-phase" sb_skill_is_installed "external-discuss-phase"
assert_command_succeeds "Isolated Kay hook discovery resolves external-plan-phase" sb_skill_is_installed "external-plan-phase"
assert_file_exists "Isolated Silver Bullet plugin cache exists" "$KAY_HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet/current/.codex-plugin/plugin.json"
assert_file_exists "Isolated Silver Bullet cache includes Kay hook bridge" "$KAY_HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet/current/hooks/kay-project-hook-bridge.sh"
assert_file_exists "Isolated Silver Bullet marketplace snapshot exists" "$KAY_HOME/.codex/.tmp/marketplaces/alo-labs-codex/plugins/silver-bullet/.codex-plugin/plugin.json"
assert_file_exists "Isolated Silver Bullet CLI shim exists" "$KAY_HOME/.codex/bin/silver-bullet"
assert_eq "Isolated Silver Bullet CLI shim is first on PATH" "$KAY_HOME/.codex/bin/silver-bullet" "$(command -v silver-bullet)"
case ":${PATH:-}:" in
  *":${KAY_HOME}/.kay/.silver-bullet/path-prepend/active:"*)
    echo "PASS: Isolated Kay active hook shim directory is on PATH"
    (( PASS++ )) || true
    ;;
  *)
    echo "FAIL: Isolated Kay active hook shim directory is missing from PATH"
    (( FAIL++ )) || true
    ;;
esac
assert_file_exists "Isolated Kay cache copies dependency plugin versions" "$KAY_HOME/.codex/plugins/cache/superpowers-marketplace/superpowers/5.1.0/skills/verification-before-completion/SKILL.md"
assert_file_exists "Isolated Kay state root exists under .kay" "$KAY_HOME/.kay/.silver-bullet"
assert_eq "Kay state root is explicitly allowlisted" "$KAY_HOME/.kay/.silver-bullet" "$SB_RUNTIME_EXTRA_STATE_ROOTS"
ISOLATED_SB_INSTALL_PATH="$(
  python3 - <<'PY'
import json
import os
from pathlib import Path
data = json.loads((Path(os.environ["KAY_HOME"]) / ".codex/plugins/installed_plugins.json").read_text())
print(data["plugins"]["silver-bullet@alo-labs-codex"][0]["installPath"])
PY
)"
assert_eq "Silver Bullet install path rewrites to isolated cache" "$KAY_HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet/current" "$ISOLATED_SB_INSTALL_PATH"
case "$SB_LIVE_CODEX_ISOLATED_PROMPT_GUARD" in
  *"minimax"*"MiniMax-M3"*"reasoning effort low"*"Do not call agent"*"Do not call browser"*"split argv array"*)
    echo "PASS: isolated Kay prompt guard constrains provider, model, reasoning, agents, browser tools, and command arrays"
    (( PASS++ )) || true
    ;;
  *)
    echo "FAIL: isolated Kay prompt guard missing expected constraints"
    (( FAIL++ )) || true
    ;;
esac

WORKSPACE="$TMP/workspace"
mkdir -p "$WORKSPACE"
RESOLVED_WORKSPACE="$(python3 - "$WORKSPACE" <<'PY'
import pathlib
import sys

print(pathlib.Path(sys.argv[1]).resolve())
PY
)"
export SILVER_BULLET_HOOK_AUDIT_LOG="$KAY_HOME/.codex/.silver-bullet/hook-audit.jsonl"
kay_register_silver_bullet_project_hooks "$WORKSPACE"
assert_file_contains "Kay bash profile sources SB shim prelude" "$KAY_HOME/.bash_profile" '.kay/.silver-bullet/profile-prelude.sh'
assert_file_contains "Kay config registers raw workspace bridge hooks" "$KAY_HOME/.kay/config.toml" "[[projects.\"${WORKSPACE}\".hooks]]"
assert_file_contains "Kay config registers resolved workspace bridge hooks" "$KAY_HOME/.kay/config.toml" "[[projects.\"${RESOLVED_WORKSPACE}\".hooks]]"
assert_file_contains "Kay config references installed bridge script" "$KAY_HOME/.kay/config.toml" 'kay-project-hook-bridge.sh'
assert_file_contains "Kay config registers tool.before native hook" "$KAY_HOME/.kay/config.toml" 'event = "tool.before"'
assert_file_contains "Kay project hook env passes isolated HOME" "$KAY_HOME/.kay/config.toml" "HOME = \"${KAY_HOME}\""
assert_file_contains "Kay project hook env passes isolated KAY_HOME root" "$KAY_HOME/.kay/config.toml" "KAY_HOME = \"${KAY_HOME}\""
assert_file_contains "Kay project hook env passes codex runtime name" "$KAY_HOME/.kay/config.toml" 'SILVER_BULLET_RUNTIME = "codex"'
assert_file_contains "Kay project hook env passes state allowlist" "$KAY_HOME/.kay/config.toml" "SB_RUNTIME_EXTRA_STATE_ROOTS = \"${KAY_HOME}/.kay/.silver-bullet\""
assert_file_contains "Kay project hook env passes audit log path" "$KAY_HOME/.kay/config.toml" "SILVER_BULLET_HOOK_AUDIT_LOG = \"${KAY_HOME}/.codex/.silver-bullet/hook-audit.jsonl\""
assert_file_contains "Kay project hook env enables fallback blockers for Kay" "$KAY_HOME/.kay/config.toml" 'SB_KAY_HOOK_BRIDGE_LEGACY_FALLBACK = "1"'

REAL_BRIDGE="$REPO_ROOT/hooks/kay-project-hook-bridge.sh"
BRIDGE_WORKSPACE="$TMP/bridge-workspace"
BRIDGE_TARGET="$BRIDGE_WORKSPACE/src/routes/todos.js"
ACTIVE_SHIM_DIR="$KAY_HOME/.kay/.silver-bullet/path-prepend/active"
mkdir -p "$(dirname "$BRIDGE_TARGET")" "$KAY_HOME/.codex/.silver-bullet"
cat > "$BRIDGE_TARGET" <<'EOF'
export const todos = [];
EOF

run_bridge_event() {
  local event="$1" call_id="$2" payload="$3"
  (
    cd "$BRIDGE_WORKSPACE"
    HOME="$KAY_HOME" \
    KAY_HOME="$KAY_HOME" \
    SILVER_BULLET_RUNTIME=codex \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    CODE_HOOK_EVENT="$event" \
    CODE_HOOK_SOURCE_CALL_ID="$call_id" \
    CODE_HOOK_PAYLOAD="$payload" \
    bash "$REAL_BRIDGE" </dev/null
  )
}

: > "$KAY_HOME/.codex/.silver-bullet/state"

chmod_probe_command='set +m; chmod u+w src/routes/todos.js && printf '"'"'\n// chmod bridge probe\n'"'"' >> src/routes/todos.js'
chmod_probe_payload="$(jq -nc --arg command "$chmod_probe_command" '{command:["bash","-lc",$command]}')"
target_digest="$(capture_digest "$BRIDGE_TARGET")"
bridge_status=0
set +e
bridge_output="$(run_bridge_event "tool.before" "call-native-deny-probe" "$chmod_probe_payload" 2>&1)"
bridge_status=$?
set -e
assert_eq "Kay bridge returns native deny status for blocked tool.before" "2" "$bridge_status"
assert_contains "Kay bridge writes native deny reason to stderr" "$bridge_output" "Planning incomplete"
assert_file_unchanged "Kay bridge native deny leaves target unchanged before execution" "$BRIDGE_TARGET" "$target_digest"
if [[ -d "$KAY_HOME/.kay/.silver-bullet/path-prepend/call-native-deny-probe" ]]; then
  echo "FAIL: Kay bridge default deny left stale fallback shims"
  (( FAIL++ )) || true
else
  echo "PASS: Kay bridge default deny avoids stale fallback shims"
  (( PASS++ )) || true
fi

reset_bridge_denial_state
target_digest="$(capture_digest "$BRIDGE_TARGET")"
bridge_status=0
set +e
bridge_output="$(SB_KAY_HOOK_BRIDGE_LEGACY_FALLBACK=1 run_bridge_event "tool.before" "call-chmod-probe" "$chmod_probe_payload" 2>&1)"
bridge_status=$?
set -e
assert_eq "Kay bridge fallback mode still returns native deny status" "2" "$bridge_status"
assert_contains "Kay bridge fallback mode surfaces planning denial" "$bridge_output" "Planning incomplete"
assert_file_exists "Kay bridge writes fallback shell shims into the active prepend root" "$ACTIVE_SHIM_DIR/chmod"
chmod_status=0
set +e
chmod_output="$(
  cd "$BRIDGE_WORKSPACE" && HOME="$KAY_HOME" KAY_HOME="$KAY_HOME" bash -lc "$chmod_probe_command" 2>&1
)"
chmod_status=$?
set -e
run_bridge_event "tool.after" "call-chmod-probe" "$(jq -nc --argjson command '["bash","-lc"]' --arg script "$chmod_probe_command" --arg stderr "$chmod_output" --argjson exit_code "$chmod_status" '{command:($command + [$script]), exit_code:$exit_code, stdout:"", stderr:$stderr}')"
assert_file_unchanged "Kay bridge blocks same-turn chmod retry writes" "$BRIDGE_TARGET" "$target_digest"
if [[ $chmod_status -ne 0 && "$chmod_output" == *"Planning incomplete"* ]]; then
  echo "PASS: Kay bridge surfaces planning denial through shell shim"
  (( PASS++ )) || true
else
  echo "FAIL: Kay bridge did not surface planning denial through shell shim"
  (( FAIL++ )) || true
fi

python_probe_script='from pathlib import Path; Path("src/routes/todos.js").open("a", encoding="utf-8").write("\n# python bridge probe\n")'
python_probe_payload="$(jq -nc --arg script "$python_probe_script" '{command:["python3","-c",$script]}')"
reset_bridge_denial_state
target_digest="$(capture_digest "$BRIDGE_TARGET")"
bridge_status=0
set +e
bridge_output="$(SB_KAY_HOOK_BRIDGE_LEGACY_FALLBACK=1 run_bridge_event "tool.before" "call-python-probe" "$python_probe_payload" 2>&1)"
bridge_status=$?
set -e
assert_eq "Kay bridge direct-write fallback returns native deny status" "2" "$bridge_status"
assert_contains "Kay bridge direct-write fallback surfaces planning denial" "$bridge_output" "Planning incomplete"
python_status=0
set +e
python_output="$(
  cd "$BRIDGE_WORKSPACE" && HOME="$KAY_HOME" KAY_HOME="$KAY_HOME" python3 -c "$python_probe_script" 2>&1
)"
python_status=$?
set -e
run_bridge_event "tool.after" "call-python-probe" "$(jq -nc --arg script "$python_probe_script" --arg stderr "$python_output" --argjson exit_code "$python_status" '{command:["python3","-c",$script], exit_code:$exit_code, stdout:"", stderr:$stderr}')"
assert_file_unchanged "Kay bridge immutable block stops direct python file writes" "$BRIDGE_TARGET" "$target_digest"
if [[ $python_status -ne 0 ]]; then
  echo "PASS: Kay bridge makes direct python writes fail while blocked"
  (( PASS++ )) || true
else
  echo "FAIL: Kay bridge allowed direct python write while blocked"
  (( FAIL++ )) || true
fi

shell_probe_command=$'printf \'\\n// shell bridge probe\\n\' >> src/routes/todos.js'
shell_probe_payload="$(jq -nc --arg command "$shell_probe_command" '{command:["bash","-lc",$command]}')"
reset_bridge_denial_state
target_digest="$(capture_digest "$BRIDGE_TARGET")"
bridge_status=0
set +e
bridge_output="$(SB_KAY_HOOK_BRIDGE_LEGACY_FALLBACK=1 run_bridge_event "tool.before" "call-shell-probe" "$shell_probe_payload" 2>&1)"
bridge_status=$?
set -e
assert_eq "Kay bridge shell fallback returns native deny status" "2" "$bridge_status"
assert_contains "Kay bridge shell fallback surfaces planning denial" "$bridge_output" "Planning incomplete"
shell_status=0
set +e
shell_output="$(
  cd "$BRIDGE_WORKSPACE" && HOME="$KAY_HOME" KAY_HOME="$KAY_HOME" bash -lc "$shell_probe_command" 2>&1
)"
shell_status=$?
set -e
run_bridge_event "tool.after" "call-shell-probe" "$(jq -nc --argjson command '["bash","-lc"]' --arg script "$shell_probe_command" --arg stderr "$shell_output" --argjson exit_code "$shell_status" '{command:($command + [$script]), exit_code:$exit_code, stdout:"", stderr:$stderr}')"
assert_file_unchanged "Kay bridge immutable block stops direct shell redirects from command arrays" "$BRIDGE_TARGET" "$target_digest"
if [[ $shell_status -ne 0 ]]; then
  echo "PASS: Kay bridge makes direct shell redirects fail while blocked"
  (( PASS++ )) || true
else
  echo "FAIL: Kay bridge allowed direct shell redirect while blocked"
  (( FAIL++ )) || true
fi

reset_bridge_denial_state
cat > "$BRIDGE_WORKSPACE/.silver-bullet.json" <<'EOF'
{
  "sb_initiated": true,
  "state": {
    "state_file": "~/.codex/.silver-bullet/state",
    "trivial_file": "~/.codex/.silver-bullet/trivial"
  },
  "skills": {
    "required_planning": ["silver-quality-gates"]
  },
  "project": {
    "active_workflow": "full-dev-cycle"
  }
}
EOF
printf '# Bridge Fixture\n' > "$BRIDGE_WORKSPACE/silver-bullet.md"
git -C "$BRIDGE_WORKSPACE" init -q
git -C "$BRIDGE_WORKSPACE" config user.email "bridge@example.test"
git -C "$BRIDGE_WORKSPACE" config user.name "Bridge Test"
git -C "$BRIDGE_WORKSPACE" add src/routes/todos.js
git -C "$BRIDGE_WORKSPACE" commit -q -m "baseline"
printf '\n// git bridge probe\n' >> "$BRIDGE_TARGET"
REAL_GIT_BIN="$(command -v git)"
git_probe_payload="$(jq -nc '{command:["git","commit","-am","blocked direct git probe"]}')"
head_before="$(git -C "$BRIDGE_WORKSPACE" rev-parse HEAD)"
reset_bridge_denial_state
bridge_status=0
set +e
bridge_output="$(SB_KAY_HOOK_BRIDGE_LEGACY_FALLBACK=1 run_bridge_event "tool.before" "call-git-probe_hook_tool_before_1" "$git_probe_payload" 2>&1)"
bridge_status=$?
set -e
assert_eq "Kay bridge direct-git fallback returns native deny status" "2" "$bridge_status"
assert_contains "Kay bridge direct-git fallback surfaces planning denial" "$bridge_output" "Planning incomplete"
assert_file_exists "Kay bridge writes git shim into the active prepend root" "$ACTIVE_SHIM_DIR/git"
hash -r 2>/dev/null || true
git_status=0
set +e
git_output="$(
  cd "$BRIDGE_WORKSPACE" && HOME="$KAY_HOME" KAY_HOME="$KAY_HOME" "$REAL_GIT_BIN" commit -am "blocked direct git probe" 2>&1
)"
git_status=$?
set -e
run_bridge_event "tool.after" "call-git-probe_hook_tool_after_1" "$(jq -nc --arg stderr "$git_output" --argjson exit_code "$git_status" '{command:["git","commit","-am","blocked direct git probe"], exit_code:$exit_code, stdout:"", stderr:$stderr}')"
assert_eq "Kay bridge direct-git fallback keeps HEAD unchanged" "$head_before" "$(git -C "$BRIDGE_WORKSPACE" rev-parse HEAD)"
if [[ $git_status -ne 0 ]]; then
  echo "PASS: Kay bridge blocks direct git through repository write lock"
  (( PASS++ )) || true
else
  echo "FAIL: Kay bridge did not block direct git through repository write lock"
  (( FAIL++ )) || true
fi
if [[ -w "$BRIDGE_WORKSPACE/.git/refs" && -w "$BRIDGE_WORKSPACE/.git/objects" ]]; then
  echo "PASS: Kay bridge restores repository write locks after Kay-style after hook"
  (( PASS++ )) || true
else
  echo "FAIL: Kay bridge left repository write locks in place after Kay-style after hook"
  (( FAIL++ )) || true
fi

isolated_root="$SB_LIVE_CODEX_ISOLATION_DIR"
teardown_kay_codex_isolation

if [[ -z "${KAY_HOME:-}" ]]; then
  echo "PASS: KAY_HOME unset after teardown"
  (( PASS++ )) || true
else
  echo "FAIL: KAY_HOME still set after teardown: $KAY_HOME"
  (( FAIL++ )) || true
fi
if [[ "$HOME" == "$ORIGINAL_HOME" ]]; then
  echo "PASS: HOME restored after teardown"
  (( PASS++ )) || true
else
  echo "FAIL: HOME not restored after teardown: $HOME"
  (( FAIL++ )) || true
fi
if [[ -z "${KAY_SB_TEST_HOME:-}" ]]; then
  echo "PASS: KAY_SB_TEST_HOME unset after teardown"
  (( PASS++ )) || true
else
  echo "FAIL: KAY_SB_TEST_HOME still set after teardown: $KAY_SB_TEST_HOME"
  (( FAIL++ )) || true
fi
if [[ -z "${SB_RUNTIME_EXTRA_STATE_ROOTS:-}" ]]; then
  echo "PASS: SB_RUNTIME_EXTRA_STATE_ROOTS unset after teardown"
  (( PASS++ )) || true
else
  echo "FAIL: SB_RUNTIME_EXTRA_STATE_ROOTS still set after teardown: $SB_RUNTIME_EXTRA_STATE_ROOTS"
  (( FAIL++ )) || true
fi
if [[ -z "${CODEX_EXPERIMENTAL_USE_EXEC_COMMAND_TOOL:-}" ]]; then
  echo "PASS: CODEX_EXPERIMENTAL_USE_EXEC_COMMAND_TOOL unset after teardown"
  (( PASS++ )) || true
else
  echo "FAIL: CODEX_EXPERIMENTAL_USE_EXEC_COMMAND_TOOL still set after teardown: $CODEX_EXPERIMENTAL_USE_EXEC_COMMAND_TOOL"
  (( FAIL++ )) || true
fi
if [[ ! -e "$isolated_root" ]]; then
  echo "PASS: isolated runtime directory cleaned up"
  (( PASS++ )) || true
else
  echo "FAIL: isolated runtime directory still exists: $isolated_root"
  (( FAIL++ )) || true
fi

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
