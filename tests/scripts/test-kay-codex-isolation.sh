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
  shasum -a 256 "$path" | awk '{print $1}'
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

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ORIGINAL_HOME="$TMP/original-home"
FAKE_BIN="$TMP/bin/kay"
mkdir -p "$ORIGINAL_HOME/.kay" "$(dirname "$FAKE_BIN")"
mkdir -p "$ORIGINAL_HOME/.codex/hooks" "$ORIGINAL_HOME/.codex/plugins" "$ORIGINAL_HOME/.codex/skills/gsd-discuss-phase" "$ORIGINAL_HOME/.agents/skills/gsd-plan-phase" "$ORIGINAL_HOME/.codex/.tmp/marketplaces/alo-labs-codex/plugins/silver-bullet/.codex-plugin"
mkdir -p "$ORIGINAL_HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet/0.37.4/.codex-plugin"
mkdir -p "$ORIGINAL_HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet/0.37.4/hooks"
mkdir -p "$ORIGINAL_HOME/.codex/plugins/cache/superpowers-marketplace/superpowers/5.1.0/skills/verification-before-completion"

cat > "$ORIGINAL_HOME/.kay/auth.json" <<'EOF'
{
  "provider_credentials": {
    "opencode-go": {
      "api_key": "test-opencode-go-key"
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
source = "https://github.com/alo-labs/codex-plugins"

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

[projects."/Users/shafqat/projects/silver-bullet"]
trust_level = "trusted"
EOF
cat > "$ORIGINAL_HOME/.codex/hooks.json" <<'EOF'
{
  "pre_tool_use": []
}
EOF
cat > "$ORIGINAL_HOME/.codex/hooks/gsd-check-update.js" <<'EOF'
console.log("check-update");
EOF
cat > "$ORIGINAL_HOME/.codex/skills/gsd-discuss-phase/SKILL.md" <<'EOF'
---
name: "gsd-discuss-phase"
---
EOF
cat > "$ORIGINAL_HOME/.agents/skills/gsd-plan-phase/SKILL.md" <<'EOF'
---
name: "gsd:plan-phase"
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
unset KAY_HOME KAY_SB_TEST_HOME

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
assert_eq "OpenCode-Go key is sourced from original Kay auth" "test-opencode-go-key" "$OPENCODE_GO_API_KEY"
assert_eq "MiniMax key stays unset for Kay OCG runs" "" "${MINIMAX_API_KEY:-}"
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
assert_file_contains "Isolated Kay config pins OpenCode-Go provider" "$KAY_HOME/.kay/config.toml" 'model_provider = "opencode-go"'
assert_file_contains "Isolated Kay config pins DeepSeek V4 Flash" "$KAY_HOME/.kay/config.toml" 'model = "deepseek-v4-flash"'
assert_file_contains "Isolated Kay config pins low reasoning" "$KAY_HOME/.kay/config.toml" 'model_reasoning_effort = "low"'
assert_file_contains "Projected Kay config keeps trusted projects" "$KAY_HOME/.kay/config.toml" '[projects."/Users/shafqat/projects/silver-bullet"]'
assert_file_contains "Projected Kay config keeps trusted project level" "$KAY_HOME/.kay/config.toml" 'trust_level = "trusted"'
assert_file_not_contains "Projected Kay config strips Codex plugin registry sections" "$KAY_HOME/.kay/config.toml" '[plugins."silver-bullet@alo-labs-codex"]'
assert_file_not_contains "Projected Kay config strips Codex hook trust state blocks" "$KAY_HOME/.kay/config.toml" '[hooks.state]'
assert_file_not_contains "Projected Kay config strips Codex agent registry sections" "$KAY_HOME/.kay/config.toml" '[agents.gsd-planner]'
assert_file_exists "Isolated Codex hooks directory is mirrored" "$KAY_HOME/.codex/hooks/gsd-check-update.js"
assert_file_exists "Isolated Codex hooks.json is mirrored" "$KAY_HOME/.codex/hooks.json"
assert_file_exists "Isolated Kay env mirrors host Codex skill roots" "$KAY_HOME/.codex/skills/gsd-discuss-phase/SKILL.md"
assert_file_exists "Isolated Kay env mirrors host .agents skill roots" "$KAY_HOME/.agents/skills/gsd-plan-phase/SKILL.md"
assert_command_succeeds "Isolated Kay hook discovery resolves gsd-discuss-phase" sb_skill_is_installed "gsd-discuss-phase"
assert_command_succeeds "Isolated Kay hook discovery resolves gsd-plan-phase" sb_skill_is_installed "gsd-plan-phase"
assert_file_exists "Isolated Silver Bullet plugin cache exists" "$KAY_HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet/current/.codex-plugin/plugin.json"
assert_file_exists "Isolated Silver Bullet cache includes Kay hook bridge" "$KAY_HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet/current/hooks/kay-project-hook-bridge.sh"
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
  *"opencode-go"*"deepseek-v4-flash"*"reasoning effort low"*"Do not call agent"*"Do not call browser"*"split argv array"*)
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

REAL_BRIDGE="$REPO_ROOT/hooks/kay-project-hook-bridge.sh"
BRIDGE_WORKSPACE="$TMP/bridge-workspace"
BRIDGE_TARGET="$BRIDGE_WORKSPACE/src/routes/todos.js"
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
run_bridge_event "tool.before" "call-chmod-probe" "$chmod_probe_payload"
assert_file_exists "Kay bridge writes per-call shell shims into the active prepend root" "$KAY_HOME/.kay/.silver-bullet/path-prepend/call-chmod-probe/chmod"
chmod_status=0
chmod_output="$(
  cd "$BRIDGE_WORKSPACE" && HOME="$KAY_HOME" KAY_HOME="$KAY_HOME" bash -lc "$chmod_probe_command" 2>&1
)" || chmod_status=$?
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
target_digest="$(capture_digest "$BRIDGE_TARGET")"
run_bridge_event "tool.before" "call-python-probe" "$python_probe_payload"
python_status=0
python_output="$(
  cd "$BRIDGE_WORKSPACE" && HOME="$KAY_HOME" KAY_HOME="$KAY_HOME" python3 -c "$python_probe_script" 2>&1
)" || python_status=$?
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
target_digest="$(capture_digest "$BRIDGE_TARGET")"
run_bridge_event "tool.before" "call-shell-probe" "$shell_probe_payload"
shell_status=0
shell_output="$(
  cd "$BRIDGE_WORKSPACE" && HOME="$KAY_HOME" KAY_HOME="$KAY_HOME" bash -lc "$shell_probe_command" 2>&1
)" || shell_status=$?
run_bridge_event "tool.after" "call-shell-probe" "$(jq -nc --argjson command '["bash","-lc"]' --arg script "$shell_probe_command" --arg stderr "$shell_output" --argjson exit_code "$shell_status" '{command:($command + [$script]), exit_code:$exit_code, stdout:"", stderr:$stderr}')"
assert_file_unchanged "Kay bridge immutable block stops direct shell redirects from command arrays" "$BRIDGE_TARGET" "$target_digest"
if [[ $shell_status -ne 0 ]]; then
  echo "PASS: Kay bridge makes direct shell redirects fail while blocked"
  (( PASS++ )) || true
else
  echo "FAIL: Kay bridge allowed direct shell redirect while blocked"
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
