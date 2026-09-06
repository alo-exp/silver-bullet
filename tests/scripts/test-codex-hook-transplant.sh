#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

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

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FAKE_SB_ROOT="$TMP/fake-sb"
TARGET_HOME="$TMP/target-home"
mkdir -p "$FAKE_SB_ROOT/scripts" "$TARGET_HOME/.codex/plugins"

cat > "$FAKE_SB_ROOT/scripts/install-codex.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
root="${KAY_HOME:-${HOME}}"
mkdir -p "$root/.codex"
mkdir -p "$root/.codex/hooks"
mkdir -p "$root/.codex/bin"
mkdir -p "$root/.codex/skills/silver-feature"
mkdir -p "$root/.codex/.tmp/marketplaces/alo-labs-codex/plugins/silver-bullet/hooks"
mkdir -p "$root/.codex/plugins/cache/alo-labs-codex/silver-bullet/9.9.9/hooks"
mkdir -p "$root/.codex/plugins/cache/alo-labs-codex/silver-bullet/9.9.9/.codex-plugin"
mkdir -p "$root/.codex/plugins/cache/episodic-memory-dev/episodic-memory/1.2.3/.codex-plugin"
cat > "$root/.codex/hooks.json" <<JSON
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "command": "\"$root/.codex/hooks/legacy-check-update.js\""
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "exec_command",
        "hooks": [
          {
            "command": "\"$root/.codex/.tmp/marketplaces/alo-labs-codex/plugins/silver-bullet/hooks/dev-cycle-check.sh\""
          }
        ]
      }
    ]
  }
}
JSON
cat > "$root/.codex/hooks/legacy-check-update.js" <<'HOOKJS'
console.log("harvested-check-update");
HOOKJS
cat > "$root/.codex/bin/silver-bullet" <<SHIM
#!/usr/bin/env bash
exec "$root/.codex/plugins/cache/alo-labs-codex/silver-bullet/current/scripts/silver-bullet" "\$@"
SHIM
chmod +x "$root/.codex/bin/silver-bullet"
cat > "$root/.codex/skills/silver-feature/SKILL.md" <<'SKILL'
---
name: "sb:feature"
title: "Silver: Feature"
---

# Silver Feature
harvested-valid-native-skill
SKILL
cat > "$root/.codex/skills/silver-feature/.silver-bullet-managed" <<'MARKER'
source=Silver Bullet
MARKER
cat > "$root/.codex/config.toml" <<CFG
model = "gpt-5.5"

[plugins."silver-bullet@alo-labs-codex"]
enabled = true

[hooks.state]
[hooks.state."$root/.codex/hooks.json:pre_tool_use:0:0"]
trusted_hash = "sha256:harvested-user-hook"

[hooks.state."silver-bullet@alo-labs-codex:hooks/hooks.json:pre_tool_use:0:0"]
trusted_hash = "sha256:stale-package-hook"
CFG
cat > "$root/.codex/plugins/installed_plugins.json" <<CFG
{
  "plugins": {
    "silver-bullet@alo-labs-codex": [
      {
        "version": "9.9.9",
        "installPath": "$root/.codex/plugins/cache/alo-labs-codex/silver-bullet/current"
      }
    ],
    "episodic-memory@episodic-memory-dev": [
      {
        "version": "1.2.3",
        "installPath": "$root/.codex/plugins/cache/episodic-memory-dev/episodic-memory/1.2.3"
      }
    ]
  }
}
CFG
cat > "$root/.codex/plugins/cache/alo-labs-codex/silver-bullet/9.9.9/.codex-plugin/plugin.json" <<'PLUGINJSON'
{
  "name": "silver-bullet",
  "hooks": "./hooks/hooks.json"
}
PLUGINJSON
cat > "$root/.codex/plugins/cache/alo-labs-codex/silver-bullet/9.9.9/hooks/hooks.json" <<JSON
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "exec_command",
        "hooks": [
          {
            "command": "\"$root/.codex/.tmp/marketplaces/alo-labs-codex/plugins/silver-bullet/hooks/dev-cycle-check.sh\""
          }
        ]
      }
    ]
  }
}
JSON
cat > "$root/.codex/plugins/cache/episodic-memory-dev/episodic-memory/1.2.3/.codex-plugin/plugin.json" <<'EPISODICPLUGIN'
{
  "name": "episodic-memory",
  "hooks": "./hooks/hooks.json"
}
EPISODICPLUGIN
mkdir -p "$root/.codex/plugins/cache/episodic-memory-dev/episodic-memory/1.2.3/hooks"
cat > "$root/.codex/plugins/cache/episodic-memory-dev/episodic-memory/1.2.3/hooks/hooks.json" <<'EPISODICHOOKS'
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "command": "node \"${CLAUDE_PLUGIN_ROOT}/cli/episodic-memory.js\" sync --background"
          }
        ]
      }
    ]
  }
}
EPISODICHOOKS
cat > "$root/.codex/.tmp/marketplaces/alo-labs-codex/plugins/silver-bullet/hooks/dev-cycle-check.sh" <<'MARKER'
#!/usr/bin/env bash
echo harvest-marketplace-surface
MARKER
chmod +x "$root/.codex/.tmp/marketplaces/alo-labs-codex/plugins/silver-bullet/hooks/dev-cycle-check.sh"
cat > "$root/.codex/plugins/cache/alo-labs-codex/silver-bullet/9.9.9/hooks/dev-cycle-check.sh" <<'MARKER'
#!/usr/bin/env bash
echo harvest-cache-surface
MARKER
chmod +x "$root/.codex/plugins/cache/alo-labs-codex/silver-bullet/9.9.9/hooks/dev-cycle-check.sh"
ln -sfn 9.9.9 "$root/.codex/plugins/cache/alo-labs-codex/silver-bullet/current"
EOF
chmod +x "$FAKE_SB_ROOT/scripts/install-codex.sh"

cat > "$TARGET_HOME/.codex/config.toml" <<'EOF'
model = "gpt-5.5"
approval_policy = "never"

[plugins."superpowers@superpowers-marketplace"]
enabled = true

[hooks.state]
[hooks.state."/original/target/.codex/hooks.json:pre_tool_use:0:0"]
trusted_hash = "sha256:old-user-hook"

[hooks.state."silver-bullet@alo-labs-codex:hooks/hooks.json:pre_tool_use:0:0"]
trusted_hash = "sha256:old-package-hook"

[hooks.state."third-party@test-marketplace:hooks/hooks.json:pre_tool_use:0:0"]
trusted_hash = "sha256:third-party-hook"
EOF

cat > "$TARGET_HOME/.codex/hooks.json" <<'EOF'
{
  "hooks": {
    "PreToolUse": []
  }
}
EOF
mkdir -p "$TARGET_HOME/.codex/bin"
mkdir -p "$TARGET_HOME/.codex/skills/silver-feature"
cat > "$TARGET_HOME/.codex/bin/silver-bullet" <<'EOF'
#!/usr/bin/env bash
echo stale-target-shim
EOF
chmod +x "$TARGET_HOME/.codex/bin/silver-bullet"
cat > "$TARGET_HOME/.codex/skills/silver-feature/SKILL.md" <<'SKILL'
---
name: sb:feature
title: Silver: Feature
---

# Silver Feature
stale-invalid-native-skill
SKILL
mkdir -p "$TARGET_HOME/.codex/plugins/cache/episodic-memory-dev/episodic-memory/1.2.3/.codex-plugin"
mkdir -p "$TARGET_HOME/.codex/plugins/cache/episodic-memory-dev/episodic-memory/1.2.3/hooks"
cat > "$TARGET_HOME/.codex/plugins/cache/episodic-memory-dev/episodic-memory/1.2.3/.codex-plugin/plugin.json" <<'EOF'
{
  "name": "episodic-memory",
  "hooks": "./hooks/hooks.json"
}
EOF
cat > "$TARGET_HOME/.codex/plugins/cache/episodic-memory-dev/episodic-memory/1.2.3/hooks/hooks.json" <<'EOF'
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "command": "node \"${CLAUDE_PLUGIN_ROOT}/cli/episodic-memory.js\" sync --background"
          }
        ]
      }
    ]
  }
}
EOF
cat > "$TARGET_HOME/.codex/plugins/installed_plugins.json" <<EOF
{
  "plugins": {
    "silver-bullet@alo-labs-codex": [
      {
        "version": "9.9.9",
        "installPath": "$TARGET_HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet/current"
      }
    ],
    "episodic-memory@episodic-memory-dev": [
      {
        "version": "1.2.3",
        "installPath": "$TARGET_HOME/.codex/plugins/cache/episodic-memory-dev/episodic-memory/1.2.3"
      }
    ]
  }
}
EOF

export SB_ROOT="$FAKE_SB_ROOT"
# shellcheck source=tests/live/lib/codex-hook-transplant.sh
source "$REPO_ROOT/tests/live/lib/codex-hook-transplant.sh"
sync_install_generated_codex_user_hooks "$TARGET_HOME" "codex"
sync_install_generated_codex_user_hooks "$TARGET_HOME" "codex"

TARGET_HOOKS_PATH_REAL="$(
  python3 - "$TARGET_HOME/.codex/hooks.json" <<'PY'
import pathlib
import sys

print(pathlib.Path(sys.argv[1]).resolve())
PY
)"

assert_file_contains "target hooks.json updated from harvested install" \
  "$TARGET_HOME/.codex/hooks.json" \
  'dev-cycle-check.sh'
assert_file_contains "target hooks directory synced from harvested install" \
  "$TARGET_HOME/.codex/hooks/legacy-check-update.js" \
  'harvested-check-update'
assert_file_contains "target Codex invoke-skill shim synced from harvested install" \
  "$TARGET_HOME/.codex/bin/silver-bullet" \
  'plugins/cache/alo-labs-codex/silver-bullet/current/scripts/silver-bullet'
assert_file_not_contains "target Codex invoke-skill shim does not retain stale target content" \
  "$TARGET_HOME/.codex/bin/silver-bullet" \
  'stale-target-shim'
assert_file_contains "target native SB mirror synced from harvested install" \
  "$TARGET_HOME/.codex/skills/silver-feature/SKILL.md" \
  'harvested-valid-native-skill'
assert_file_contains "target native SB mirror uses YAML-safe quoted Silver route name" \
  "$TARGET_HOME/.codex/skills/silver-feature/SKILL.md" \
  'name: "sb:feature"'
assert_file_not_contains "target native SB mirror does not retain stale invalid Silver route name" \
  "$TARGET_HOME/.codex/skills/silver-feature/SKILL.md" \
  'name: sb:feature'
assert_file_contains "target native SB mirror preserves managed marker" \
  "$TARGET_HOME/.codex/skills/silver-feature/.silver-bullet-managed" \
  'source=Silver Bullet'
assert_file_contains "target config keeps existing non-SB plugin config" \
  "$TARGET_HOME/.codex/config.toml" \
  '[plugins."superpowers@superpowers-marketplace"]'
assert_file_contains "target config rewrites user hook trust to target hooks path" \
  "$TARGET_HOME/.codex/config.toml" \
  "[hooks.state.\"$TARGET_HOOKS_PATH_REAL:pre_tool_use:0:0\"]"
assert_file_not_contains "target config removes stale original user hook path" \
  "$TARGET_HOME/.codex/config.toml" \
  '/original/target/.codex/hooks.json'
assert_file_contains "target config preserves unrelated third-party hook trust" \
  "$TARGET_HOME/.codex/config.toml" \
  'third-party@test-marketplace:hooks/hooks.json'
assert_file_contains "target config preserves package hook trust" \
  "$TARGET_HOME/.codex/config.toml" \
  'silver-bullet@alo-labs-codex:hooks/hooks.json'
assert_file_contains "target config seeds managed hook trust for mirrored plugins" \
  "$TARGET_HOME/.codex/config.toml" \
  'episodic-memory@episodic-memory-dev:hooks/hooks.json'
assert_file_contains "target marketplace plugin surface synced from harvested install" \
  "$TARGET_HOME/.codex/.tmp/marketplaces/alo-labs-codex/plugins/silver-bullet/hooks/dev-cycle-check.sh" \
  'harvest-marketplace-surface'
assert_file_contains "target plugin cache surface synced from harvested install" \
  "$TARGET_HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet/9.9.9/hooks/dev-cycle-check.sh" \
  'harvest-cache-surface'
assert_file_not_contains "target plugin cache hook manifest does not retain harvest temp-home paths" \
  "$TARGET_HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet/9.9.9/hooks/hooks.json" \
  '/sb-codex-hook-harvest.'
assert_eq "target plugin cache current symlink restored" \
  "$(python3 - "$TARGET_HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet/9.9.9" <<'PY'
import pathlib
import sys

print(pathlib.Path(sys.argv[1]).resolve())
PY
)" \
  "$(python3 - "$TARGET_HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet/current" <<'PY'
import pathlib
import sys

print(pathlib.Path(sys.argv[1]).resolve())
PY
)"

HARVEST_CMD="$(
  python3 - "$TARGET_HOME/.codex/hooks.json" <<'PY'
import json
import pathlib
import sys

data = json.loads(pathlib.Path(sys.argv[1]).read_text())
print(data["hooks"]["PreToolUse"][0]["hooks"][0]["command"])
PY
)"
assert_eq "harvested command points at target home after transplant" \
  "\"$TARGET_HOME/.codex/.tmp/marketplaces/alo-labs-codex/plugins/silver-bullet/hooks/dev-cycle-check.sh\"" \
  "$HARVEST_CMD"
PLUGIN_CACHE_CMD="$(
  python3 - "$TARGET_HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet/9.9.9/hooks/hooks.json" <<'PY'
import json
import pathlib
import sys

data = json.loads(pathlib.Path(sys.argv[1]).read_text())
print(data["hooks"]["PreToolUse"][0]["hooks"][0]["command"])
PY
)"
assert_eq "plugin cache hook manifest points at target home after transplant" \
  "\"$TARGET_HOME/.codex/.tmp/marketplaces/alo-labs-codex/plugins/silver-bullet/hooks/dev-cycle-check.sh\"" \
  "$PLUGIN_CACHE_CMD"
assert_file_not_contains "transplanted hooks.json does not retain harvest temp-home paths" \
  "$TARGET_HOME/.codex/hooks.json" \
  '/sb-codex-hook-harvest.'

EXPECTED_DIGEST="$(
  python3 - "$TARGET_HOME/.codex/hooks.json" <<'PY'
import hashlib
import json
import pathlib
import sys

def event_slug(name: str) -> str:
    import re
    return re.sub(r"(?<!^)(?=[A-Z])", "_", name).lower()

def canonical_json(value):
    if isinstance(value, dict):
        return {key: canonical_json(value[key]) for key in sorted(value) if value[key] is not None}
    if isinstance(value, list):
        return [canonical_json(item) for item in value]
    return value

hooks = json.loads(pathlib.Path(sys.argv[1]).read_text())["hooks"]
group = hooks["PreToolUse"][0]
hook = group["hooks"][0]
identity = {
    "event_name": event_slug("PreToolUse"),
    "matcher": group.get("matcher"),
    "hooks": [{
        "type": hook.get("type", "command"),
        "command": hook["command"],
        "timeout": max(int(hook.get("timeout", 600) or 600), 1),
        "async": False,
    }],
}
serialized = json.dumps(canonical_json(identity), separators=(",", ":"), sort_keys=True).encode("utf-8")
print("sha256:" + hashlib.sha256(serialized).hexdigest())
PY
)"
assert_file_contains "target config recomputes user hook trust digest for rewritten hook identity" \
  "$TARGET_HOME/.codex/config.toml" \
  "trusted_hash = \"$EXPECTED_DIGEST\""

EXPECTED_PACKAGE_DIGEST="$(
  python3 - "$TARGET_HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet/9.9.9/hooks/hooks.json" <<'PY'
import hashlib
import json
import pathlib
import sys

def event_slug(name: str) -> str:
    import re
    return re.sub(r"(?<!^)(?=[A-Z])", "_", name).lower()

def canonical_json(value):
    if isinstance(value, dict):
        return {key: canonical_json(value[key]) for key in sorted(value) if value[key] is not None}
    if isinstance(value, list):
        return [canonical_json(item) for item in value]
    return value

hooks = json.loads(pathlib.Path(sys.argv[1]).read_text())["hooks"]
group = hooks["PreToolUse"][0]
hook = group["hooks"][0]
identity = {
    "event_name": event_slug("PreToolUse"),
    "matcher": group.get("matcher"),
    "hooks": [{
        "type": hook.get("type", "command"),
        "command": hook["command"],
        "timeout": max(int(hook.get("timeout", 600) or 600), 1),
        "async": False,
    }],
}
serialized = json.dumps(canonical_json(identity), separators=(",", ":"), sort_keys=True).encode("utf-8")
print("sha256:" + hashlib.sha256(serialized).hexdigest())
PY
)"
assert_file_contains "target config recomputes package hook trust digest for rewritten command" \
  "$TARGET_HOME/.codex/config.toml" \
  "[hooks.state.\"silver-bullet@alo-labs-codex:hooks/hooks.json:pre_tool_use:0:0\"]"
assert_file_contains "target config stores rewritten package hook digest" \
  "$TARGET_HOME/.codex/config.toml" \
  "trusted_hash = \"$EXPECTED_PACKAGE_DIGEST\""

HARVEST_COUNT="$(
  python3 - "$TARGET_HOME/.codex/config.toml" "$TARGET_HOME" <<'PY'
import sys
from pathlib import Path

config_path = Path(sys.argv[1])
target_home = Path(sys.argv[2])
needle = f'[hooks.state."{(target_home / ".codex" / "hooks.json").resolve()}:pre_tool_use:0:0"]'
print(config_path.read_text().count(needle))
PY
)"
assert_eq "target config keeps harvested hook trust idempotent across repeated syncs" \
  "1" \
  "$HARVEST_COUNT"

PACKAGE_COUNT="$(
  python3 - "$TARGET_HOME/.codex/config.toml" <<'PY'
import sys
from pathlib import Path

config_path = Path(sys.argv[1])
needle = '[hooks.state."silver-bullet@alo-labs-codex:hooks/hooks.json:pre_tool_use:0:0"]'
print(config_path.read_text().count(needle))
PY
)"
assert_eq "target config keeps managed package hook trust idempotent across repeated syncs" \
  "1" \
  "$PACKAGE_COUNT"

TARGET_KAY_HOME="$TMP/target-kay-home"
mkdir -p "$TARGET_KAY_HOME/.codex/plugins/cache/alo-labs-codex/engineering/1.2.0/.codex-plugin"
mkdir -p "$TARGET_KAY_HOME/.codex/.tmp/marketplaces/alo-labs-codex/plugins/design/.codex-plugin"
cat > "$TARGET_KAY_HOME/.codex/plugins/cache/alo-labs-codex/engineering/1.2.0/.codex-plugin/plugin.json" <<'EOF'
{
  "name": "engineering"
}
EOF
cat > "$TARGET_KAY_HOME/.codex/.tmp/marketplaces/alo-labs-codex/plugins/design/.codex-plugin/plugin.json" <<'EOF'
{
  "name": "design"
}
EOF
cat > "$TARGET_KAY_HOME/.codex/config.toml" <<'EOF'
model = "deepseek-v4-flash"
EOF
ln -sfn 1.2.0 "$TARGET_KAY_HOME/.codex/plugins/cache/alo-labs-codex/engineering/current"

sync_install_generated_codex_user_hooks "$TARGET_KAY_HOME" "kay"

assert_file_contains "kay-mode transplant preserves existing alo-labs engineering cache plugin" \
  "$TARGET_KAY_HOME/.codex/plugins/cache/alo-labs-codex/engineering/1.2.0/.codex-plugin/plugin.json" \
  '"name": "engineering"'
assert_eq "kay-mode transplant preserves engineering current symlink" \
  "$(python3 - "$TARGET_KAY_HOME/.codex/plugins/cache/alo-labs-codex/engineering/1.2.0" <<'PY'
import pathlib
import sys

print(pathlib.Path(sys.argv[1]).resolve())
PY
)" \
  "$(python3 - "$TARGET_KAY_HOME/.codex/plugins/cache/alo-labs-codex/engineering/current" <<'PY'
import pathlib
import sys

print(pathlib.Path(sys.argv[1]).resolve())
PY
)"
assert_file_contains "kay-mode transplant preserves existing alo-labs marketplace plugins" \
  "$TARGET_KAY_HOME/.codex/.tmp/marketplaces/alo-labs-codex/plugins/design/.codex-plugin/plugin.json" \
  '"name": "design"'

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
