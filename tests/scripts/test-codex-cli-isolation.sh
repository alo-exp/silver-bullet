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

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ORIGINAL_HOME="$TMP/original-home"
FAKE_BIN="$TMP/bin/codex"
mkdir -p "$ORIGINAL_HOME/.codex/agents" "$ORIGINAL_HOME/.codex/hooks" "$ORIGINAL_HOME/.codex/skills/silver-context" "$ORIGINAL_HOME/.agents/skills/silver-plan" "$(dirname "$FAKE_BIN")"
mkdir -p "$ORIGINAL_HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet/0.37.4/.codex-plugin"
mkdir -p "$ORIGINAL_HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet/0.37.4/hooks"
mkdir -p "$ORIGINAL_HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet/0.37.4/scripts"
mkdir -p "$ORIGINAL_HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet/sb-live-version.zzzzzz"
mkdir -p "$ORIGINAL_HOME/.codex/.tmp/marketplaces/alo-labs-codex/plugins/silver-bullet/.codex-plugin"
mkdir -p "$ORIGINAL_HOME/.codex/.tmp/marketplaces/alo-labs-codex/plugins/silver-bullet/hooks"

cat > "$FAKE_BIN" <<'EOF'
#!/usr/bin/env bash
printf 'codex-cli 0.133.0-alpha.1\n'
EOF
chmod +x "$FAKE_BIN"
ln -sfn 0.37.4 "$ORIGINAL_HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet/current"

cat > "$ORIGINAL_HOME/.codex/config.toml" <<EOF
model = "gpt-5.5"
model_reasoning_effort = "medium"
approval_policy = "on-request"
sandbox_mode = "read-only"

[marketplaces.alo-labs-codex]
source_type = "git"
source = "https://github.com/alo-labs/agent-plugins"

[features]
plugin_hooks = true

hooks = true

[plugins."silver-bullet@alo-labs-codex"]
enabled = true

[agents.sb-planner]
config_file = "${ORIGINAL_HOME}/.codex/agents/sb-planner.toml"

[projects."/Users/shafqat/projects/silver-bullet"]
trust_level = "trusted"
EOF

cat > "$ORIGINAL_HOME/.codex/agents/sb-planner.toml" <<'EOF'
model = "gpt-5.5"
EOF
cat > "$ORIGINAL_HOME/.codex/skills/silver-context/SKILL.md" <<'EOF'
---
name: "silver:context"
---
EOF
cat > "$ORIGINAL_HOME/.agents/skills/silver-plan/SKILL.md" <<'EOF'
---
name: "silver:plan"
---
EOF
cat > "$ORIGINAL_HOME/.codex/hooks/sb-check-update.js" <<'EOF'
console.log("check-update");
EOF
cat > "$ORIGINAL_HOME/.codex/hooks.json" <<'EOF'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
          {
            "command": "\"__ORIGINAL_HOME__/.codex/hooks/sb-check-update.js\""
          }
        ]
      }
    ]
  }
}
EOF
python3 - "$ORIGINAL_HOME/.codex/hooks.json" "$ORIGINAL_HOME" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
path.write_text(path.read_text().replace("__ORIGINAL_HOME__", sys.argv[2]))
PY
cat > "$ORIGINAL_HOME/.codex/plugins/installed_plugins.json" <<EOF
{
  "plugins": {
    "silver-bullet@alo-labs-codex": [
      {
        "version": "sb-live-version.zzzzzz",
        "installPath": "${ORIGINAL_HOME}/.codex/plugins/cache/alo-labs-codex/silver-bullet/current"
      }
    ]
  }
}
EOF
cat > "$ORIGINAL_HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet/0.37.4/.codex-plugin/plugin.json" <<'EOF'
{
  "name": "silver-bullet",
  "hooks": "./hooks/hooks.json"
}
EOF
cat > "$ORIGINAL_HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet/0.37.4/hooks/session-start" <<'EOF'
#!/usr/bin/env bash
printf '{"hookSpecificOutput":{"hookEventName":"SessionStart"}}'
EOF
chmod +x "$ORIGINAL_HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet/0.37.4/hooks/session-start"
cat > "$ORIGINAL_HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet/0.37.4/scripts/silver-bullet" <<'EOF'
#!/usr/bin/env bash
printf 'silver-bullet %s\n' "$*"
EOF
chmod +x "$ORIGINAL_HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet/0.37.4/scripts/silver-bullet"
cat > "$ORIGINAL_HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet/0.37.4/hooks/hooks.json" <<EOF
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "command": "\"${ORIGINAL_HOME}/.codex/plugins/cache/alo-labs-codex/silver-bullet/0.37.4/hooks/session-start\""
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "command": "\"${ORIGINAL_HOME}/.codex/plugins/cache/alo-labs-codex/silver-bullet/0.37.4/hooks/prompt-reminder.sh\""
          }
        ]
      }
    ]
  }
}
EOF
cat > "$ORIGINAL_HOME/.codex/.tmp/marketplaces/alo-labs-codex/plugins/silver-bullet/.codex-plugin/plugin.json" <<'EOF'
{
  "name": "silver-bullet",
  "hooks": "./hooks/hooks.json"
}
EOF
cat > "$ORIGINAL_HOME/.codex/.tmp/marketplaces/alo-labs-codex/plugins/silver-bullet/hooks/session-start" <<'EOF'
#!/usr/bin/env bash
printf '{"hookSpecificOutput":{"hookEventName":"SessionStart"}}'
EOF
chmod +x "$ORIGINAL_HOME/.codex/.tmp/marketplaces/alo-labs-codex/plugins/silver-bullet/hooks/session-start"
cat > "$ORIGINAL_HOME/.codex/.tmp/marketplaces/alo-labs-codex/plugins/silver-bullet/hooks/hooks.json" <<EOF
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "command": "\"${ORIGINAL_HOME}/.codex/.tmp/marketplaces/alo-labs-codex/plugins/silver-bullet/hooks/session-start\""
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "command": "\"${ORIGINAL_HOME}/.codex/.tmp/marketplaces/alo-labs-codex/plugins/silver-bullet/hooks/prompt-reminder.sh\""
          }
        ]
      }
    ]
  }
}
EOF

export HOME="$ORIGINAL_HOME"
export CODEX_BIN="$FAKE_BIN"
unset CODEX_HOME CODEX_SB_TEST_HOME SB_LIVE_CODEX_ISOLATION_ACTIVE SB_LIVE_CODEX_ISOLATION_DIR SB_LIVE_ORIGINAL_HOME
unset SB_LIVE_AGENT SB_LIVE_CODEX_MODEL SB_LIVE_CODEX_MODEL_PROVIDER SB_LIVE_CODEX_REASONING_EFFORT CODEX_REASONING_EFFORT

# shellcheck source=tests/live/lib/codex-cli-isolation.sh
source "$REPO_ROOT/tests/live/lib/codex-cli-isolation.sh"
setup_codex_cli_isolation
export SILVER_BULLET_RUNTIME=codex
source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
source "$REPO_ROOT/hooks/lib/skill-discovery.sh"

NORMALIZED_CODEX_HOME="$(python3 - "$CODEX_HOME" <<'PY'
import pathlib
import sys
print(pathlib.Path(sys.argv[1]))
PY
)"

assert_eq "HOME is redirected to isolated Codex root" "$SB_LIVE_CODEX_ISOLATION_DIR" "$HOME"
assert_eq "CODEX_HOME is rooted under isolated HOME" "$HOME/.codex" "$CODEX_HOME"
assert_eq "runtime-paths resolves Codex home under isolation root" "$CODEX_HOME" "$SB_RUNTIME_HOME_ROOT"
assert_eq "runtime-paths resolves Codex state under isolation root" "$CODEX_HOME/.silver-bullet" "$SB_RUNTIME_STATE_DIR"
assert_eq "native Codex binary is preserved" "$FAKE_BIN" "$CODEX_BIN"
assert_eq "isolated Codex PATH exposes SB CLI shim first" "$CODEX_HOME/bin/silver-bullet" "$(command -v silver-bullet || true)"
assert_file_contains "isolated SB CLI shim targets isolated package cache" "$CODEX_HOME/bin/silver-bullet" "$CODEX_HOME/plugins/cache/alo-labs-codex/silver-bullet/current/scripts/silver-bullet"
assert_eq "trusted command package root uses the isolated Codex cache current path" "$CODEX_HOME/plugins/cache/alo-labs-codex/silver-bullet/current" "$SB_LIVE_COMMAND_PACKAGE_ROOT"
assert_file_exists "trusted command package temp version root exists" "$SB_LIVE_COMMAND_PACKAGE_VERSION_ROOT"
case "$SB_LIVE_CODEX_ISOLATION_DIR" in
  /var/*|/private/var/*)
    echo "FAIL: isolated Codex runtime root avoids symlinked temp trees — got [$SB_LIVE_CODEX_ISOLATION_DIR]"
    (( FAIL++ )) || true
    ;;
  *)
    echo "PASS: isolated Codex runtime root avoids symlinked temp trees"
    (( PASS++ )) || true
    ;;
esac
assert_file_contains "Isolated Codex config preserves supported model" "$CODEX_HOME/config.toml" 'model = "gpt-5.5"'
assert_file_contains "Isolated Codex config preserves reasoning when unspecified" "$CODEX_HOME/config.toml" 'model_reasoning_effort = "medium"'
assert_file_contains "Isolated Codex config forces approval never" "$CODEX_HOME/config.toml" 'approval_policy = "never"'
assert_file_contains "Isolated Codex config forces danger-full-access" "$CODEX_HOME/config.toml" 'sandbox_mode = "danger-full-access"'
assert_file_contains "Isolated Codex config rewrites alo-labs marketplace to a local isolation root" "$CODEX_HOME/config.toml" "source = \"${NORMALIZED_CODEX_HOME}/.tmp/marketplaces/alo-labs-codex\""
assert_file_not_contains "Isolated Codex config does not add GSD marketplace" "$CODEX_HOME/config.toml" "get-shit-done-marketplace"
assert_file_not_contains "Isolated Codex config does not add Superpowers marketplace" "$CODEX_HOME/config.toml" "superpowers-marketplace"
assert_file_contains "Isolated Codex config keeps only required Silver Bullet plugin enablement" "$CODEX_HOME/config.toml" '[plugins."silver-bullet@alo-labs-codex"]'
assert_file_contains "Isolated Codex config keeps existing trusted projects" "$CODEX_HOME/config.toml" '[projects."/Users/shafqat/projects/silver-bullet"]'
assert_file_contains "Isolated Codex config keeps trusted project level" "$CODEX_HOME/config.toml" 'trust_level = "trusted"'
assert_file_exists "Isolated Codex env mirrors host Codex skill roots" "$CODEX_HOME/skills/silver-context/SKILL.md"
assert_file_exists "Isolated Codex env mirrors host .agents skill roots" "$HOME/.agents/skills/silver-plan/SKILL.md"
assert_command_succeeds "Isolated Codex hook discovery resolves silver-context" sb_skill_is_installed "silver-context"
assert_command_succeeds "Isolated Codex hook discovery resolves silver-plan" sb_skill_is_installed "silver-plan"
if [[ ! -e "$CODEX_HOME/agents/sb-planner.toml" ]]; then
  echo "PASS: isolated Codex env does not mirror host agent-role files"
  (( PASS++ )) || true
else
  echo "FAIL: isolated Codex env unexpectedly mirrored host agent-role files"
  (( FAIL++ )) || true
fi
if [[ ! -e "$CODEX_HOME/hooks/sb-check-update.js" ]]; then
  echo "PASS: isolated Codex env does not mirror host user hook scripts"
  (( PASS++ )) || true
else
  echo "FAIL: isolated Codex env unexpectedly mirrored host user hook scripts"
  (( FAIL++ )) || true
fi
if [[ ! -e "$CODEX_HOME/hooks.json" ]]; then
  echo "PASS: isolated native Codex env does not preseed user hooks.json"
  (( PASS++ )) || true
else
  echo "FAIL: isolated native Codex env unexpectedly preseeded hooks.json"
  (( FAIL++ )) || true
fi
assert_file_exists "Isolated Silver Bullet plugin cache exists" "$CODEX_HOME/plugins/cache/alo-labs-codex/silver-bullet/current/.codex-plugin/plugin.json"
assert_eq "Isolated Silver Bullet current alias preserves the real installed version" "$CODEX_HOME/plugins/cache/alo-labs-codex/silver-bullet/0.37.4" "$(python3 - "$CODEX_HOME/plugins/cache/alo-labs-codex/silver-bullet/current" <<'PY'
import pathlib
import sys
print(pathlib.Path(sys.argv[1]).resolve())
PY
)"
if [[ ! -e "$CODEX_HOME/plugins/cache/alo-labs-codex/silver-bullet/sb-live-version.zzzzzz" ]]; then
  echo "PASS: invalid transient Silver Bullet cache versions are pruned from isolation"
  (( PASS++ )) || true
else
  echo "FAIL: invalid transient Silver Bullet cache version still present in isolation"
  (( FAIL++ )) || true
fi
assert_file_exists "Synthetic local marketplace exposes Silver Bullet" "$CODEX_HOME/.tmp/marketplaces/alo-labs-codex/plugins/silver-bullet/.codex-plugin/plugin.json"

ISOLATED_SB_INSTALL_PATH="$(
  python3 - <<'PY'
import json
import os
from pathlib import Path
data = json.loads((Path(os.environ["CODEX_HOME"]) / "plugins/installed_plugins.json").read_text())
print(data["plugins"]["silver-bullet@alo-labs-codex"][0]["installPath"])
PY
)"
assert_eq "Silver Bullet install path rewrites to isolated cache" "$CODEX_HOME/plugins/cache/alo-labs-codex/silver-bullet/current" "$ISOLATED_SB_INSTALL_PATH"

ISOLATED_SB_VERSION="$(
  python3 - <<'PY'
import json
import os
from pathlib import Path
data = json.loads((Path(os.environ["CODEX_HOME"]) / "plugins/installed_plugins.json").read_text())
print(data["plugins"]["silver-bullet@alo-labs-codex"][0]["version"])
PY
)"
assert_eq "Silver Bullet registry version normalizes to the resolved current target" "0.37.4" "$ISOLATED_SB_VERSION"

isolated_root="$SB_LIVE_CODEX_ISOLATION_DIR"
teardown_codex_cli_isolation

if [[ -z "${CODEX_HOME:-}" ]]; then
  echo "PASS: CODEX_HOME unset after teardown"
  (( PASS++ )) || true
else
  echo "FAIL: CODEX_HOME still set after teardown: $CODEX_HOME"
  (( FAIL++ )) || true
fi
if [[ "$HOME" == "$ORIGINAL_HOME" ]]; then
  echo "PASS: HOME restored after teardown"
  (( PASS++ )) || true
else
  echo "FAIL: HOME not restored after teardown: $HOME"
  (( FAIL++ )) || true
fi
if [[ ":$PATH:" != *":$isolated_root/.codex/bin:"* ]]; then
  echo "PASS: isolated Codex bin removed from PATH after teardown"
  (( PASS++ )) || true
else
  echo "FAIL: isolated Codex bin still present in PATH after teardown"
  (( FAIL++ )) || true
fi
if [[ ! -e "$isolated_root" ]]; then
  echo "PASS: isolated runtime directory cleaned up"
  (( PASS++ )) || true
else
  echo "FAIL: isolated runtime directory still exists: $isolated_root"
  (( FAIL++ )) || true
fi
if [[ "$(python3 - "$ORIGINAL_HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet/current" <<'PY'
import pathlib
import sys
print(pathlib.Path(sys.argv[1]).resolve())
PY
)" == "$(python3 - "$ORIGINAL_HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet/0.37.4" <<'PY'
import pathlib
import sys
print(pathlib.Path(sys.argv[1]).resolve())
PY
)" ]]; then
  echo "PASS: original command package current symlink restored after teardown"
  (( PASS++ )) || true
else
  echo "FAIL: original command package current symlink not restored after teardown"
  (( FAIL++ )) || true
fi

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
