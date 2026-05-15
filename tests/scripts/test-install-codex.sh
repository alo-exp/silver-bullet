#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0
SKIP=0

assert_file_exists() {
  local desc="$1" path="$2"
  if [[ -f "$path" ]]; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — missing: $path"
    (( FAIL++ )) || true
  fi
}

assert_file_absent() {
  local desc="$1" path="$2"
  if [[ ! -e "$path" ]]; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — should be absent: $path"
    (( FAIL++ )) || true
  fi
}

assert_not_symlink() {
  local desc="$1" path="$2"
  if [[ ! -L "$path" ]]; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — still a symlink: $path"
    (( FAIL++ )) || true
  fi
}

make_async_hooks_fixture() {
  local source_path="$1"
  local dest_path="$2"

  python3 - "$source_path" "$dest_path" <<'PY'
import json
import pathlib
import sys

source_path = pathlib.Path(sys.argv[1])
dest_path = pathlib.Path(sys.argv[2])

data = json.loads(source_path.read_text())
for event_items in data.get("hooks", {}).values():
    for item in event_items:
        for hook in item.get("hooks", []):
            if "compliance-status.sh" in hook.get("command", ""):
                hook["async"] = True

dest_path.write_text(json.dumps(data, indent=2) + "\n")
PY
}

assert_no_async_true() {
  local desc="$1" path="$2"
  if python3 - "$path" <<'PY' >/dev/null 2>&1
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
data = json.loads(path.read_text())

def walk(value):
    if isinstance(value, dict):
        if value.get("async") is True:
            return True
        return any(walk(v) for v in value.values())
    if isinstance(value, list):
        return any(walk(v) for v in value)
    return False

raise SystemExit(0 if not walk(data) else 1)
PY
  then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — async:true still present in $path"
    (( FAIL++ )) || true
  fi
}

assert_silver_bullet_hook_trust_state() {
  local desc="$1" config_path="$2" package_hooks_path="$3"
  if python3 - "$config_path" "$package_hooks_path" <<'PY' >/dev/null 2>&1
import hashlib
import json
import pathlib
import re
import sys

config_path = pathlib.Path(sys.argv[1])
package_hooks_path = pathlib.Path(sys.argv[2])
home = config_path.parent.parent

def event_slug(name: str) -> str:
    return re.sub(r"(?<!^)(?=[A-Z])", "_", name).lower()

def first_existing(*paths):
    for path in paths:
        if path.is_file():
            return path
    return None

def hooks_data_for(path):
    if path is None:
        return {}
    return json.loads(path.read_text()).get("hooks", {})

def parse_state(raw_text: str) -> dict[str, str]:
    state = {}
    current_key = None
    for line in raw_text.splitlines():
        stripped = line.strip()
        match = re.match(r'^\[hooks\.state\."(.+)"\]$', stripped)
        if match:
            current_key = match.group(1)
            continue
        if current_key is not None and stripped.startswith("trusted_hash = "):
            hash_match = re.match(r'^trusted_hash = "(sha256:[0-9a-f]{64})"$', stripped)
            if hash_match:
                state[current_key] = hash_match.group(1)
            continue
        if stripped.startswith("[") and not stripped.startswith('[hooks.state.'):
            current_key = None
    return state

source_by_prefix = {
    "silver-bullet@alo-labs-codex:hooks/hooks.json": package_hooks_path,
}

expected = {}
for prefix, source_path in source_by_prefix.items():
    for event_name, groups in hooks_data_for(source_path).items():
        slug = event_slug(event_name)
        for group_index, group in enumerate(groups):
            for hook_index, hook in enumerate(group.get("hooks", [])):
                key = f"{prefix}:{slug}:{group_index}:{hook_index}"
                digest = "sha256:" + hashlib.sha256(hook.get("command", "").encode("utf-8")).hexdigest()
                expected[key] = digest

actual = {
    key: digest
    for key, digest in parse_state(config_path.read_text()).items()
    if any(key.startswith(f"{prefix}:") for prefix in source_by_prefix)
}

if len(actual) != len(expected):
    raise SystemExit(1)

for key, digest in expected.items():
    if actual.get(key) != digest:
        raise SystemExit(1)
PY
  then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — missing or mismatched Silver Bullet hook trust state in $config_path"
    python3 - "$config_path" "$package_hooks_path" <<'PY'
import hashlib
import json
import pathlib
import re
import sys

config_path = pathlib.Path(sys.argv[1])
package_hooks_path = pathlib.Path(sys.argv[2])
home = config_path.parent.parent

def event_slug(name: str) -> str:
    return re.sub(r"(?<!^)(?=[A-Z])", "_", name).lower()

def first_existing(*paths):
    for path in paths:
        if path.is_file():
            return path
    return None

def hooks_data_for(path):
    if path is None:
        return {}
    return json.loads(path.read_text()).get("hooks", {})

def parse_state(raw_text: str) -> dict[str, str]:
    state = {}
    current_key = None
    for line in raw_text.splitlines():
        stripped = line.strip()
        match = re.match(r'^\[hooks\.state\."(.+)"\]$', stripped)
        if match:
            current_key = match.group(1)
            continue
        if current_key is not None and stripped.startswith("trusted_hash = "):
            hash_match = re.match(r'^trusted_hash = "(sha256:[0-9a-f]{64})"$', stripped)
            if hash_match:
                state[current_key] = hash_match.group(1)
            continue
        if stripped.startswith("[") and not stripped.startswith('[hooks.state.'):
            current_key = None
    return state

source_by_prefix = {
    "silver-bullet@alo-labs-codex:hooks/hooks.json": package_hooks_path,
}

expected = {}
for prefix, source_path in source_by_prefix.items():
    for event_name, groups in hooks_data_for(source_path).items():
        slug = event_slug(event_name)
        for group_index, group in enumerate(groups):
            for hook_index, hook in enumerate(group.get("hooks", [])):
                key = f"{prefix}:{slug}:{group_index}:{hook_index}"
                digest = "sha256:" + hashlib.sha256(hook.get("command", "").encode("utf-8")).hexdigest()
                expected[key] = digest

actual = {
    key: digest
    for key, digest in parse_state(config_path.read_text()).items()
    if any(key.startswith(f"{prefix}:") for prefix in source_by_prefix)
}

expected_keys = set(expected)
actual_keys = set(actual)
missing = sorted(expected_keys - actual_keys)
extra = sorted(actual_keys - expected_keys)
bad = sorted(key for key in expected_keys & actual_keys if expected[key] != actual[key])

print(f"  expected={len(expected)} actual={len(actual)} missing={len(missing)} extra={len(extra)} mismatched={len(bad)}")
if missing:
    print("  missing keys:")
    for key in missing[:8]:
        print(f"    - {key}")
if extra:
    print("  extra keys:")
    for key in extra[:8]:
        print(f"    - {key}")
if bad:
    print("  mismatched keys:")
    for key in bad[:8]:
        print(f"    - {key}")
        print(f"      expected: {expected[key]}")
        print(f"      actual:   {actual[key]}")
PY
    (( FAIL++ )) || true
  fi
}

assert_contains() {
  local desc="$1" needle="$2" file="$3"
  if grep -qF -- "$needle" "$file"; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — missing [$needle] in $file"
    (( FAIL++ )) || true
  fi
}

assert_not_contains() {
  local desc="$1" needle="$2" file="$3"
  if ! grep -qF -- "$needle" "$file"; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — unexpected [$needle] in $file"
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
SCRIPT="$REPO_ROOT/scripts/install-codex.sh"
HOME_DIR="$TMP/home"
BIN_DIR="$TMP/bin"
mkdir -p "$HOME_DIR/.codex" "$HOME_DIR/.agents/skills/silver-feature" "$HOME_DIR/.agents/skills/using-silver-bullet" "$HOME_DIR/.agents/skills/unrelated-skill" "$BIN_DIR"
cat > "$HOME_DIR/.agents/skills/unrelated-skill/SKILL.md" <<'EOF'
---
name: unrelated-skill
---
EOF

cat > "$HOME_DIR/.agents/skills/using-silver-bullet/SKILL.md" <<'EOF'
---
name: using-silver-bullet
---
EOF

cat > "$BIN_DIR/install-gsd" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$HOME/.codex/get-shit-done"
printf '9.9.9' > "$HOME/.codex/get-shit-done/VERSION"
EOF
chmod +x "$BIN_DIR/install-gsd"

cat > "$BIN_DIR/npx" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exec "$@"
EOF
chmod +x "$BIN_DIR/npx"

cat > "$BIN_DIR/codex" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF
chmod +x "$BIN_DIR/codex"

cat > "$HOME_DIR/.codex/config.toml" <<EOF
[marketplaces.silver-bullet-local]
source = "/tmp/old-silver-bullet"

[plugins."silver-bullet@alo-labs-codex-local"]
enabled = true
EOF

sb_prefix="silver"
sb_suffix="bullet"
legacy_sb_name="${sb_prefix}-${sb_suffix}"
legacy_claude_root="${HOME}/.claude"
legacy_plugins_root="${legacy_claude_root}/plugins"
legacy_cache_root="${legacy_plugins_root}/cache"
legacy_vendor_root="${legacy_cache_root}/alo-labs"
legacy_sb_hooks_root="${legacy_vendor_root}/${legacy_sb_name}/0.32.2/hooks"

cat > "$HOME_DIR/.codex/hooks.json" <<EOF
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "node \"/Users/shafqat/.claude/hooks/gsd-check-update.js\""
          },
          {
            "type": "command",
            "command": "\"${legacy_sb_hooks_root}/session-start\""
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Bash|Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "node \"/Users/shafqat/.claude/hooks/gsd-context-monitor.js\""
          },
          {
            "type": "command",
            "command": "\"${legacy_sb_hooks_root}/dev-cycle-check.sh\""
          }
        ]
      }
    ]
  }
}
EOF

FAKE_MARKETPLACE_ROOT="$HOME_DIR/.codex/.tmp/marketplaces/alo-labs-codex"
FAKE_SB_PACKAGE_ROOT="$FAKE_MARKETPLACE_ROOT/plugins/silver-bullet"
FAKE_SB_SKILLS_SOURCE="$FAKE_MARKETPLACE_ROOT/skills"
FAKE_CACHE_ROOT="$HOME_DIR/.codex/plugins/cache/alo-labs-codex/silver-bullet/0.32.3"
FAKE_SB_INSTALL_ROOT="$FAKE_CACHE_ROOT"
FAKE_SB_INSTALL_ALIAS="$HOME_DIR/.codex/plugins/cache/alo-labs-codex/silver-bullet/current"
FAKE_SB_STALE_ROOT="$HOME_DIR/.codex/plugins/cache/alo-labs-codex-local/silver-bullet/0.32.3"
FAKE_SB_STALE_ALIAS="$HOME_DIR/.codex/plugins/cache/alo-labs-codex-local/silver-bullet/current"
FAKE_SB_STALE_ROOT_MIRROR="$HOME_DIR/.codex/plugins/cache/alo-labs-codex-local/silver-bullet/0.32.3"
FAKE_SB_STALE_ALIAS_MIRROR="$HOME_DIR/.codex/plugins/cache/alo-labs-codex-local/silver-bullet/current"
FAKE_SUPERPOWERS_ROOT="$HOME_DIR/.codex/plugins/cache/superpowers-marketplace/superpowers/1.0.0"
FAKE_SUPERPOWERS_ALIAS="$HOME_DIR/.codex/plugins/cache/superpowers-marketplace/superpowers/current"
FAKE_GSD_ROOT="$HOME_DIR/.codex/plugins/cache/get-shit-done-marketplace/gsd/1.41.1"
FAKE_GSD_ALIAS="$HOME_DIR/.codex/plugins/cache/get-shit-done-marketplace/gsd/current"
FAKE_SIDEKICK_ROOT="$HOME_DIR/.codex/plugins/cache/alo-labs-codex-local/sidekick/0.5.4"
FAKE_SIDEKICK_ALIAS="$HOME_DIR/.codex/plugins/cache/alo-labs-codex-local/sidekick/current"
FAKE_ENGINEERING_ROOT="$HOME_DIR/.codex/plugins/cache/alo-labs-codex-local/engineering/1.2.0"
FAKE_ENGINEERING_ALIAS="$HOME_DIR/.codex/plugins/cache/alo-labs-codex-local/engineering/current"
FAKE_DESIGN_ROOT="$HOME_DIR/.codex/plugins/cache/alo-labs-codex-local/design/1.2.0"
FAKE_DESIGN_ALIAS="$HOME_DIR/.codex/plugins/cache/alo-labs-codex-local/design/current"
FAKE_PRODUCT_ROOT="$HOME_DIR/.codex/plugins/cache/alo-labs-codex-local/product-management/1.2.0"
FAKE_PRODUCT_ALIAS="$HOME_DIR/.codex/plugins/cache/alo-labs-codex-local/product-management/current"
FAKE_SIDEKICK_STALE_ROOT="$HOME_DIR/.codex/plugins/cache/alo-labs-codex-local/sidekick/1.5.4"
FAKE_ENGINEERING_STALE_ROOT="$HOME_DIR/.codex/plugins/cache/alo-labs-codex-local/engineering/1.2.0+codex.1"
FAKE_DESIGN_STALE_ROOT="$HOME_DIR/.codex/plugins/cache/alo-labs-codex-local/design/1.2.0+codex.1"
FAKE_PRODUCT_STALE_ROOT="$HOME_DIR/.codex/plugins/cache/alo-labs-codex-local/product-management/1.2.0+codex.1"
FAKE_HOOKS_FIXTURE="$TMP/hooks-async.json"
make_async_hooks_fixture "$REPO_ROOT/hooks/hooks.json" "$FAKE_HOOKS_FIXTURE"
mkdir -p \
  "$FAKE_SB_PACKAGE_ROOT/.codex-plugin" \
  "$FAKE_MARKETPLACE_ROOT/hooks" \
  "$FAKE_SB_SKILLS_SOURCE/silver-init" \
  "$FAKE_SB_SKILLS_SOURCE/silver-ensure-docs" \
  "$FAKE_SB_SKILLS_SOURCE/silver-feature" \
  "$FAKE_SB_SKILLS_SOURCE/silver" \
  "$FAKE_CACHE_ROOT/hooks" \
  "$FAKE_SB_STALE_ROOT" \
  "$FAKE_SB_STALE_ROOT_MIRROR"
cat > "$FAKE_SB_PACKAGE_ROOT/.codex-plugin/plugin.json" <<'EOF'
{
  "name": "silver-bullet",
  "version": "0.32.3",
  "commands": "./commands/",
  "skills": "./skills/",
  "hooks": "./hooks/hooks.json"
}
EOF
cat > "$FAKE_SB_SKILLS_SOURCE/silver-init/SKILL.md" <<'EOF'
---
name: silver-init
---
EOF
cat > "$FAKE_SB_SKILLS_SOURCE/silver-ensure-docs/SKILL.md" <<'EOF'
---
name: silver-ensure-docs
---
EOF
cat > "$FAKE_SB_SKILLS_SOURCE/silver-feature/SKILL.md" <<'EOF'
---
name: silver-feature
---
EOF
cat > "$FAKE_SB_SKILLS_SOURCE/silver/SKILL.md" <<'EOF'
---
name: silver
---
EOF
cp "$FAKE_HOOKS_FIXTURE" "$FAKE_MARKETPLACE_ROOT/hooks/hooks.json"
cp "$FAKE_HOOKS_FIXTURE" "$FAKE_CACHE_ROOT/hooks/hooks.json"
ln -s "$REPO_ROOT/README.md" "$FAKE_MARKETPLACE_ROOT/README.md"
ln -s "../../hooks" "$FAKE_SB_PACKAGE_ROOT/hooks"
ln -s "../../skills" "$FAKE_SB_PACKAGE_ROOT/skills"

python3 - "$HOME_DIR" "$FAKE_SB_INSTALL_ROOT" "$FAKE_SUPERPOWERS_ROOT" "$FAKE_GSD_ROOT" "$FAKE_SIDEKICK_ROOT" "$FAKE_ENGINEERING_ROOT" "$FAKE_DESIGN_ROOT" "$FAKE_PRODUCT_ROOT" "$FAKE_SIDEKICK_STALE_ROOT" "$FAKE_ENGINEERING_STALE_ROOT" "$FAKE_DESIGN_STALE_ROOT" "$FAKE_PRODUCT_STALE_ROOT" "$FAKE_SB_STALE_ROOT" "$FAKE_SB_STALE_ROOT_MIRROR" <<'PY'
import json
import pathlib
import sys

home = pathlib.Path(sys.argv[1])
sb_install_root = pathlib.Path(sys.argv[2])
superpowers_root = pathlib.Path(sys.argv[3])
gsd_root = pathlib.Path(sys.argv[4])
sidekick_root = pathlib.Path(sys.argv[5])
engineering_root = pathlib.Path(sys.argv[6])
design_root = pathlib.Path(sys.argv[7])
product_root = pathlib.Path(sys.argv[8])
sidekick_stale_root = pathlib.Path(sys.argv[9])
engineering_stale_root = pathlib.Path(sys.argv[10])
design_stale_root = pathlib.Path(sys.argv[11])
product_stale_root = pathlib.Path(sys.argv[12])
sb_stale_root = pathlib.Path(sys.argv[13])
sb_stale_root_mirror = pathlib.Path(sys.argv[14])

def write_json(path: pathlib.Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2) + "\n")

def write_text(path: pathlib.Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)

def write_manifest(path: pathlib.Path, name: str, version: str) -> None:
    write_json(path, {"name": name, "version": version})

for root in [
    sb_install_root,
    superpowers_root,
    gsd_root,
    sidekick_root,
    engineering_root,
    design_root,
    product_root,
    sb_stale_root,
    sb_stale_root_mirror,
]:
    root.mkdir(parents=True, exist_ok=True)

write_manifest(sb_install_root / ".codex-plugin/plugin.json", "silver-bullet", "0.32.3")
write_manifest(sb_stale_root / ".codex-plugin/plugin.json", "silver-bullet", "0.32.2")
write_manifest(sb_stale_root_mirror / ".codex-plugin/plugin.json", "silver-bullet", "0.32.2")
write_manifest(superpowers_root / ".codex-plugin/plugin.json", "superpowers", "1.0.0")
write_manifest(gsd_root / ".codex-plugin/plugin.json", "gsd", "1.41.1")
write_manifest(sidekick_root / ".codex-plugin/plugin.json", "sidekick", "0.5.4")
write_manifest(engineering_root / ".codex-plugin/plugin.json", "engineering", "1.2.0")
write_manifest(design_root / ".codex-plugin/plugin.json", "design", "1.2.0")
write_manifest(product_root / ".codex-plugin/plugin.json", "product-management", "1.2.0")

write_text(sidekick_root / "skills/codex-delegate/SKILL.md", "---\nname: codex-delegate\n---\n")
write_text(sidekick_root / "skills/forge-delegate/SKILL.md", "---\nname: forge-delegate\n---\n")
write_text(superpowers_root / "skills/verification-before-completion/SKILL.md", "---\nname: verification-before-completion\n---\n")

registry = {
    "version": 2,
    "plugins": {
        "silver-bullet@alo-labs-codex": [
            {
                "scope": "project",
                "projectPath": str(home),
                "installPath": str(sb_install_root),
                "version": "0.32.3",
                "installedAt": "2026-05-10T06:56:32.762233Z",
                "lastUpdated": "2026-05-10T06:56:32.762233Z",
            }
        ],
        "silver-bullet@alo-labs-codex-local": [
            {
                "scope": "project",
                "projectPath": str(home),
                "installPath": str(sb_stale_root),
                "version": "0.32.2",
                "installedAt": "2026-05-10T06:56:32.762233Z",
                "lastUpdated": "2026-05-10T06:56:32.762233Z",
            }
        ],
        "superpowers@superpowers-marketplace": [
            {
                "scope": "project",
                "projectPath": str(home),
                "installPath": str(superpowers_root),
                "version": "1.0.0",
                "installedAt": "2026-05-10T06:56:32.762233Z",
                "lastUpdated": "2026-05-10T06:56:32.762233Z",
            }
        ],
        "gsd@get-shit-done-marketplace": [
            {
                "scope": "project",
                "projectPath": str(home),
                "installPath": str(gsd_root),
                "version": "1.41.1",
                "installedAt": "2026-05-10T06:56:32.762233Z",
                "lastUpdated": "2026-05-10T06:56:32.762233Z",
            }
        ],
        "sidekick@alo-labs-codex-local": [
            {
                "scope": "project",
                "projectPath": str(home),
                "installPath": str(sidekick_stale_root),
                "version": "1.5.4",
                "installedAt": "2026-05-10T06:56:32.762233Z",
                "lastUpdated": "2026-05-10T06:56:32.762233Z",
            }
        ],
        "engineering@alo-labs-codex-local": [
            {
                "scope": "project",
                "projectPath": str(home),
                "installPath": str(engineering_stale_root),
                "version": "1.2.0+codex.1",
                "installedAt": "2026-05-10T06:56:32.762233Z",
                "lastUpdated": "2026-05-10T06:56:32.762233Z",
            }
        ],
        "design@alo-labs-codex-local": [
            {
                "scope": "project",
                "projectPath": str(home),
                "installPath": str(design_stale_root),
                "version": "1.2.0+codex.1",
                "installedAt": "2026-05-10T06:56:32.762233Z",
                "lastUpdated": "2026-05-10T06:56:32.762233Z",
            }
        ],
        "product-management@alo-labs-codex-local": [
            {
                "scope": "project",
                "projectPath": str(home),
                "installPath": str(product_stale_root),
                "version": "1.2.0+codex.1",
                "installedAt": "2026-05-10T06:56:32.762233Z",
                "lastUpdated": "2026-05-10T06:56:32.762233Z",
            }
        ],
    },
}

for registry_path in [home / ".codex/plugins/installed_plugins.json", home / ".codex/plugins/installed_plugins.json"]:
    write_json(registry_path, registry)
PY

cat > "$FAKE_MARKETPLACE_ROOT/CHANGELOG.md" <<'EOF'
- Renamed /using-silver-bullet skill to /silver:init
- Kept other release notes intact
EOF

cd "$REPO_ROOT"
PATH="$BIN_DIR:$PATH" \
HOME="$HOME_DIR" \
GSD_INSTALL_CMD="$BIN_DIR/install-gsd" \
  bash "$SCRIPT" --purge-legacy-skills >/dev/null

assert_file_exists "GSD installer created VERSION file" "$HOME_DIR/.codex/get-shit-done/VERSION"
assert_not_contains "legacy marketplace removed from config" "[marketplaces.silver-bullet-local]" "$HOME_DIR/.codex/config.toml"
assert_contains "shared marketplace registered in config" "[marketplaces.alo-labs-codex]" "$HOME_DIR/.codex/config.toml"
assert_contains "shared marketplace source preserved" 'source = "https://github.com/alo-labs/codex-plugins"' "$HOME_DIR/.codex/config.toml"
assert_contains "superpowers marketplace registered in config" "[marketplaces.superpowers-marketplace]" "$HOME_DIR/.codex/config.toml"
assert_contains "superpowers marketplace source preserved" 'source = "https://github.com/obra/superpowers-marketplace.git"' "$HOME_DIR/.codex/config.toml"
assert_contains "GSD marketplace registered in config" "[marketplaces.get-shit-done-marketplace]" "$HOME_DIR/.codex/config.toml"
assert_contains "superpowers plugin enabled" '[plugins."superpowers@superpowers-marketplace"]' "$HOME_DIR/.codex/config.toml"
assert_contains "GSD plugin enabled" '[plugins."gsd@get-shit-done-marketplace"]' "$HOME_DIR/.codex/config.toml"
assert_file_absent "legacy SB skill removed" "$HOME_DIR/.agents/skills/silver-feature"
assert_file_absent "legacy using-silver-bullet skill removed" "$HOME_DIR/.agents/skills/using-silver-bullet"
assert_file_exists "unrelated skill preserved" "$HOME_DIR/.agents/skills/unrelated-skill/SKILL.md"
assert_contains "SB hooks plugin enabled" '[plugins."silver-bullet@alo-labs-codex"]' "$HOME_DIR/.codex/config.toml"
assert_not_contains "stale SB local plugin removed from config" 'silver-bullet@alo-labs-codex-local' "$HOME_DIR/.codex/config.toml"
assert_not_contains "stale SB local plugin removed from registry" 'silver-bullet@alo-labs-codex-local' "$HOME_DIR/.codex/plugins/installed_plugins.json"
if grep -qF '[plugins."silver@alo-labs-codex"]' "$HOME_DIR/.codex/config.toml"; then
  echo "FAIL: SB skills should be bundled into the Silver Bullet plugin, not installed separately"
  (( FAIL++ )) || true
else
  echo "PASS: Silver Bullet skills are bundled into the main SB plugin"
  (( PASS++ )) || true
fi
assert_command_succeeds "Silver Bullet cache alias created" test -L "$FAKE_SB_INSTALL_ALIAS"
assert_file_absent "stale SB local install root removed" "$FAKE_SB_STALE_ROOT"
assert_file_absent "stale SB local cache alias removed" "$FAKE_SB_STALE_ALIAS"
assert_file_absent "stale SB local install root removed from lowercase mirror" "$FAKE_SB_STALE_ROOT_MIRROR"
assert_file_absent "stale SB local cache alias removed from lowercase mirror" "$FAKE_SB_STALE_ALIAS_MIRROR"
assert_command_succeeds "Superpowers cache alias created" test -L "$FAKE_SUPERPOWERS_ALIAS"
assert_command_succeeds "GSD cache alias created" test -L "$FAKE_GSD_ALIAS"
assert_command_succeeds "Sidekick cache alias created" test -L "$FAKE_SIDEKICK_ALIAS"
assert_command_succeeds "Engineering cache alias created" test -L "$FAKE_ENGINEERING_ALIAS"
assert_command_succeeds "Design cache alias created" test -L "$FAKE_DESIGN_ALIAS"
assert_command_succeeds "Product-management cache alias created" test -L "$FAKE_PRODUCT_ALIAS"
assert_file_exists "Marketplace root hooks config materialized" "$FAKE_MARKETPLACE_ROOT/hooks/hooks.json"
assert_no_async_true "Marketplace root hooks config normalized for Codex package" "$FAKE_MARKETPLACE_ROOT/hooks/hooks.json"
assert_not_symlink "SB hooks directory materialized" "$FAKE_SB_PACKAGE_ROOT/hooks"
assert_file_exists "SB hooks config materialized" "$FAKE_SB_PACKAGE_ROOT/hooks/hooks.json"
assert_not_symlink "SB skills directory materialized" "$FAKE_SB_PACKAGE_ROOT/skills"
assert_not_symlink "SB scripts directory materialized" "$FAKE_SB_PACKAGE_ROOT/scripts"
assert_not_symlink "SB templates directory materialized" "$FAKE_SB_PACKAGE_ROOT/templates"
assert_file_exists "SB workflows helper materialized" "$FAKE_SB_PACKAGE_ROOT/scripts/workflows.sh"
assert_file_exists "SB scan helper materialized" "$FAKE_SB_PACKAGE_ROOT/scripts/silver-scan.sh"
assert_file_exists "SB package sanitizer helper materialized" "$FAKE_SB_PACKAGE_ROOT/scripts/codex-sanitize-package.sh"
assert_file_exists "Current cache workflows helper synced" "$FAKE_CACHE_ROOT/scripts/workflows.sh"
assert_file_exists "Current cache scan helper synced" "$FAKE_CACHE_ROOT/scripts/silver-scan.sh"
assert_file_exists "Current cache package sanitizer helper synced" "$FAKE_CACHE_ROOT/scripts/codex-sanitize-package.sh"
assert_no_async_true "SB hooks config normalized for Codex package" "$FAKE_SB_PACKAGE_ROOT/hooks/hooks.json"
assert_no_async_true "Current cache hooks config normalized for Codex package" "$FAKE_CACHE_ROOT/hooks/hooks.json"
assert_not_contains "Marketplace root SB hooks no longer use Claude plugin root placeholders" '${CLAUDE_PLUGIN_ROOT}' "$FAKE_MARKETPLACE_ROOT/hooks/hooks.json"
assert_not_contains "SB package hooks no longer use Claude plugin root placeholders" '${CLAUDE_PLUGIN_ROOT}' "$FAKE_SB_PACKAGE_ROOT/hooks/hooks.json"
assert_not_contains "Current cache SB hooks no longer use Claude plugin root placeholders" '${CLAUDE_PLUGIN_ROOT}' "$FAKE_CACHE_ROOT/hooks/hooks.json"
assert_not_contains "SB package does not contain AskUserQuestion" "AskUserQuestion" "$FAKE_SB_PACKAGE_ROOT"
assert_not_contains "Current cache package does not contain AskUserQuestion" "AskUserQuestion" "$FAKE_CACHE_ROOT"
assert_command_succeeds "Marketplace and SB package hook surfaces are identical" python3 - "$FAKE_MARKETPLACE_ROOT/hooks/hooks.json" "$FAKE_SB_PACKAGE_ROOT/hooks/hooks.json" <<'PY'
import json
import pathlib
import sys

left = json.loads(pathlib.Path(sys.argv[1]).read_text()).get("hooks")
right = json.loads(pathlib.Path(sys.argv[2]).read_text()).get("hooks")
if left != right:
    print(f"left_keys={list(left.keys()) if isinstance(left, dict) else type(left)}")
    print(f"right_keys={list(right.keys()) if isinstance(right, dict) else type(right)}")
    print(f"left_len={sum(len(v) for v in left.values()) if isinstance(left, dict) else 'n/a'}")
    print(f"right_len={sum(len(v) for v in right.values()) if isinstance(right, dict) else 'n/a'}")
raise SystemExit(0 if left == right else 1)
PY
assert_command_succeeds "SB package and current cache hook surfaces are identical" python3 - "$FAKE_SB_PACKAGE_ROOT/hooks/hooks.json" "$FAKE_CACHE_ROOT/hooks/hooks.json" <<'PY'
import json
import pathlib
import sys

left = json.loads(pathlib.Path(sys.argv[1]).read_text()).get("hooks")
right = json.loads(pathlib.Path(sys.argv[2]).read_text()).get("hooks")
if left != right:
    print(f"left_keys={list(left.keys()) if isinstance(left, dict) else type(left)}")
    print(f"right_keys={list(right.keys()) if isinstance(right, dict) else type(right)}")
    print(f"left_len={sum(len(v) for v in left.values()) if isinstance(left, dict) else 'n/a'}")
    print(f"right_len={sum(len(v) for v in right.values()) if isinstance(right, dict) else 'n/a'}")
raise SystemExit(0 if left == right else 1)
PY
assert_file_exists "SB dependency gate hook synced into source bundle" "$REPO_ROOT/hooks/dependency-skill-check.sh"
assert_file_exists "Installed SB dependency gate hook synced into package" "$FAKE_SB_PACKAGE_ROOT/hooks/dependency-skill-check.sh"
assert_file_exists "SB workflow-chain guard hook synced into source bundle" "$REPO_ROOT/hooks/workflow-chain-guard.sh"
assert_file_exists "Installed SB workflow-chain guard hook synced into package" "$FAKE_SB_PACKAGE_ROOT/hooks/workflow-chain-guard.sh"
assert_file_exists "Current cache workflow-chain guard synced" "$FAKE_CACHE_ROOT/hooks/workflow-chain-guard.sh"
assert_file_exists "SB instruction-file guard hook synced into source bundle" "$REPO_ROOT/hooks/instruction-file-guard.sh"
assert_file_exists "Installed SB instruction-file guard hook synced into package" "$FAKE_SB_PACKAGE_ROOT/hooks/instruction-file-guard.sh"
assert_file_exists "Current cache instruction-file guard synced" "$FAKE_CACHE_ROOT/hooks/instruction-file-guard.sh"
assert_file_exists "SB init skill surface synced into source bundle" "$REPO_ROOT/plugins/silver-bullet/skills/silver-init/SKILL.md"
assert_file_exists "SB ensure-docs skill surface synced into source bundle" "$REPO_ROOT/plugins/silver-bullet/skills/silver-ensure-docs/SKILL.md"
assert_file_exists "SB feature skill surface synced into source bundle" "$REPO_ROOT/plugins/silver-bullet/skills/silver-feature/SKILL.md"
assert_file_exists "SB router skill surface synced into source bundle" "$REPO_ROOT/plugins/silver-bullet/skills/silver/SKILL.md"
assert_file_exists "SB handoff skill surface synced into source bundle" "$REPO_ROOT/plugins/silver-bullet/skills/silver-handoff/SKILL.md"
assert_contains "SB hooks config includes dependency gate" 'dependency-skill-check.sh' "$FAKE_SB_PACKAGE_ROOT/hooks/hooks.json"
assert_contains "SB hooks config includes workflow-chain guard" 'workflow-chain-guard.sh' "$FAKE_SB_PACKAGE_ROOT/hooks/hooks.json"
assert_contains "SB hooks config includes instruction-file guard" 'instruction-file-guard.sh' "$FAKE_SB_PACKAGE_ROOT/hooks/hooks.json"
assert_contains "SB hooks config includes requested-skill recorder" 'record-requested-skill.sh' "$FAKE_SB_PACKAGE_ROOT/hooks/hooks.json"
assert_contains "Current cache hooks config includes workflow-chain guard" 'workflow-chain-guard.sh' "$FAKE_CACHE_ROOT/hooks/hooks.json"
assert_contains "SB package hooks use the canonical marketplace path" "$FAKE_SB_PACKAGE_ROOT/hooks/session-start" "$FAKE_SB_PACKAGE_ROOT/hooks/hooks.json"
assert_contains "Current cache hooks use the canonical marketplace path" "$FAKE_SB_PACKAGE_ROOT/hooks/session-start" "$FAKE_CACHE_ROOT/hooks/hooks.json"
assert_contains "SB init skill uses silver prefix" "name: silver:init" "$REPO_ROOT/plugins/silver-bullet/skills/silver-init/SKILL.md"
assert_contains "SB ensure-docs skill uses silver prefix" "name: silver:ensure-docs" "$REPO_ROOT/plugins/silver-bullet/skills/silver-ensure-docs/SKILL.md"
assert_contains "SB init skill is runtime-aware for Codex" "project instruction file and avoid runtime-specific model-routing jargon" "$REPO_ROOT/plugins/silver-bullet/skills/silver-init/SKILL.md"
# shellcheck disable=SC2088 # literal tilde is part of the documented Codex cache glob
assert_contains "SB init skill checks Codex product-management cache" "~/.codex/plugins/cache/*/product-management/skills/" "$REPO_ROOT/plugins/silver-bullet/skills/silver-init/SKILL.md"
assert_contains "SB init skill recognizes WordPress-style roots" "first-class source roots instead of guessing \`/src/\`" "$REPO_ROOT/plugins/silver-bullet/skills/silver-init/SKILL.md"
assert_contains "SB init skill keeps the working GSD entrypoint fallback" "prefer the local entrypoint and continue bootstrap instead of failing on wrapper import noise" "$REPO_ROOT/plugins/silver-bullet/skills/silver-init/SKILL.md"
assert_contains "SB ensure-docs skill runs semantic audits" "semantic freshness audits against the current project state" "$REPO_ROOT/plugins/silver-bullet/skills/silver-ensure-docs/SKILL.md"
assert_contains "SB ensure-docs skill avoids placeholder doc keys" "using real governed doc keys only" "$REPO_ROOT/plugins/silver-bullet/skills/silver-ensure-docs/SKILL.md"
assert_contains "SB feature skill uses silver prefix" "name: silver:feature" "$REPO_ROOT/plugins/silver-bullet/skills/silver-feature/SKILL.md"
assert_contains "SB router skill uses silver name" "name: silver" "$REPO_ROOT/plugins/silver-bullet/skills/silver/SKILL.md"
assert_contains "SB handoff skill uses silver prefix" "name: silver:handoff" "$REPO_ROOT/plugins/silver-bullet/skills/silver-handoff/SKILL.md"
assert_contains "TDD skill hidden from picker in source bundle" "user-invocable: false" "$REPO_ROOT/plugins/silver-bullet/skills/tdd/SKILL.md"
assert_contains "TDD skill delegates to Superpowers TDD in source bundle" "superpowers:test-driven-development" "$REPO_ROOT/plugins/silver-bullet/skills/tdd/SKILL.md"
assert_contains "SB init generated skill uses no-new-CLAUDE contract" "without creating one" "$REPO_ROOT/plugins/silver-bullet/.generated-skills/silver-init/SKILL.md"
assert_not_contains "SB init generated skill no longer promises fresh CLAUDE.md creation" "scaffolds silver-bullet.md + CLAUDE.md + config + workflow files" "$REPO_ROOT/plugins/silver-bullet/.generated-skills/silver-init/SKILL.md"
assert_file_exists "SB scan generated skill available in source bundle" "$REPO_ROOT/plugins/silver-bullet/.generated-skills/silver-scan/SKILL.md"
assert_contains "SB scan generated skill uses silver prefix" "name: silver:scan" "$REPO_ROOT/plugins/silver-bullet/.generated-skills/silver-scan/SKILL.md"
assert_contains "Installed SB init skill uses silver prefix" "name: silver:init" "$FAKE_SB_PACKAGE_ROOT/skills/silver-init/SKILL.md"
assert_contains "Installed SB ensure-docs skill uses silver prefix" "name: silver:ensure-docs" "$FAKE_SB_PACKAGE_ROOT/skills/silver-ensure-docs/SKILL.md"
assert_contains "Installed SB feature skill uses silver prefix" "name: silver:feature" "$FAKE_SB_PACKAGE_ROOT/skills/silver-feature/SKILL.md"
assert_contains "Installed SB router skill uses silver name" "name: silver" "$FAKE_SB_PACKAGE_ROOT/skills/silver/SKILL.md"
assert_file_exists "Installed SB scan generated skill available" "$FAKE_CACHE_ROOT/.generated-skills/silver-scan/SKILL.md"
assert_contains "Installed SB scan generated skill uses silver prefix" "name: silver:scan" "$FAKE_CACHE_ROOT/.generated-skills/silver-scan/SKILL.md"
assert_contains "Installed SB feature skill wires TDD into execute boundary" "gsd-execute-phase --tdd" "$FAKE_SB_PACKAGE_ROOT/skills/silver-feature/SKILL.md"
assert_contains "Installed SB feature skill documents hidden TDD gate" "Internal TDD gate" "$FAKE_SB_PACKAGE_ROOT/skills/silver-feature/SKILL.md"
assert_contains "Installed SB UI skill wires TDD into execute boundary" "gsd-execute-phase --tdd" "$FAKE_SB_PACKAGE_ROOT/skills/silver-ui/SKILL.md"
assert_contains "Installed SB bugfix skill uses SB TDD wrapper" "Invoke \`tdd\`" "$FAKE_SB_PACKAGE_ROOT/skills/silver-bugfix/SKILL.md"
assert_contains "Installed SB bugfix skill executes with TDD flag" "gsd-execute-phase --tdd" "$FAKE_SB_PACKAGE_ROOT/skills/silver-bugfix/SKILL.md"
assert_contains "Installed SB bugfix skill resolves packaged workflows helper" 'SB_WORKFLOWS_BIN' "$FAKE_SB_PACKAGE_ROOT/skills/silver-bugfix/SKILL.md"
assert_contains "TDD skill hidden from picker in installed package" "user-invocable: false" "$FAKE_SB_PACKAGE_ROOT/skills/tdd/SKILL.md"
assert_contains "TDD skill delegates to Superpowers TDD in installed package" "superpowers:test-driven-development" "$FAKE_SB_PACKAGE_ROOT/skills/tdd/SKILL.md"
assert_contains "Installed SB init generated skill mirrors no-new-CLAUDE contract" "without creating one" "$FAKE_CACHE_ROOT/.generated-skills/silver-init/SKILL.md"
assert_not_contains "Installed SB init generated skill no longer promises fresh CLAUDE.md creation" "scaffolds silver-bullet.md + CLAUDE.md + config + workflow files" "$FAKE_CACHE_ROOT/.generated-skills/silver-init/SKILL.md"

LEGACY_GSD_WRAPPERS=(
  gsd-brainstorm
  gsd-discuss
  gsd-execute
  gsd-intel
  gsd-plan
  gsd-progress
  gsd-review
  gsd-review-fix
  gsd-secure
  gsd-ship
  gsd-validate
  gsd-verify
)

for skill in "${LEGACY_GSD_WRAPPERS[@]}"; do
  assert_file_absent "Legacy GSD wrapper excluded from installed SB cache: $skill" "$FAKE_CACHE_ROOT/.generated-skills/$skill"
done

assert_not_contains "Legacy using-silver-bullet trace removed from marketplace changelog" "using-silver-bullet" "$FAKE_MARKETPLACE_ROOT/CHANGELOG.md"
assert_contains "Anthropic PM plugin enabled" '[plugins."product-management@alo-labs-codex"]' "$HOME_DIR/.codex/config.toml"
assert_contains "Anthropic engineering plugin enabled" '[plugins."engineering@alo-labs-codex"]' "$HOME_DIR/.codex/config.toml"
assert_contains "Anthropic design plugin enabled" '[plugins."design@alo-labs-codex"]' "$HOME_DIR/.codex/config.toml"
assert_contains "Codex plugin hooks feature enabled" '[features]' "$HOME_DIR/.codex/config.toml"
assert_contains "Codex plugin hooks feature flag" 'plugin_hooks = true' "$HOME_DIR/.codex/config.toml"
assert_contains "SB hook state recorded inside SB root" 'silver-bullet@' "$HOME_DIR/.codex/config.toml"
assert_silver_bullet_hook_trust_state "Silver Bullet hook trust seeded in Codex config" "$HOME_DIR/.codex/config.toml" "$FAKE_SB_PACKAGE_ROOT/hooks/hooks.json"
assert_silver_bullet_hook_trust_state "Silver Bullet hook trust seeded in codex config mirror" "$HOME_DIR/.codex/config.toml" "$FAKE_SB_PACKAGE_ROOT/hooks/hooks.json"
assert_file_exists "Codex registry created" "$HOME_DIR/.codex/plugins/installed_plugins.json"
assert_contains "Silver Bullet registry install path refreshed" "$FAKE_SB_INSTALL_ALIAS" "$HOME_DIR/.codex/plugins/installed_plugins.json"
assert_not_contains "Silver Bullet versioned install path removed" "$FAKE_SB_INSTALL_ROOT" "$HOME_DIR/.codex/plugins/installed_plugins.json"
assert_contains "Sidekick registry install path refreshed" "$FAKE_SIDEKICK_ALIAS" "$HOME_DIR/.codex/plugins/installed_plugins.json"
assert_not_contains "Sidekick stale install path removed" "$FAKE_SIDEKICK_STALE_ROOT" "$HOME_DIR/.codex/plugins/installed_plugins.json"
assert_contains "Engineering registry install path refreshed" "$FAKE_ENGINEERING_ALIAS" "$HOME_DIR/.codex/plugins/installed_plugins.json"
assert_not_contains "Engineering stale install path removed" "$FAKE_ENGINEERING_STALE_ROOT" "$HOME_DIR/.codex/plugins/installed_plugins.json"
assert_contains "Design registry install path refreshed" "$FAKE_DESIGN_ALIAS" "$HOME_DIR/.codex/plugins/installed_plugins.json"
assert_not_contains "Design stale install path removed" "$FAKE_DESIGN_STALE_ROOT" "$HOME_DIR/.codex/plugins/installed_plugins.json"
assert_contains "Product-management registry install path refreshed" "$FAKE_PRODUCT_ALIAS" "$HOME_DIR/.codex/plugins/installed_plugins.json"
assert_not_contains "Product-management stale install path removed" "$FAKE_PRODUCT_STALE_ROOT" "$HOME_DIR/.codex/plugins/installed_plugins.json"
assert_not_contains "legacy SB hooks removed from Codex user config" "$legacy_sb_hooks_root" "$HOME_DIR/.codex/hooks.json"
assert_not_contains "legacy SB hooks removed from Codex user config mirror" "$legacy_sb_hooks_root" "$HOME_DIR/.codex/hooks.json"
assert_not_contains "Requested-skill recorder not duplicated into Codex user config" 'record-requested-skill.sh' "$HOME_DIR/.codex/hooks.json"
assert_not_contains "Requested-skill recorder not duplicated into Codex user config mirror" 'record-requested-skill.sh' "$HOME_DIR/.codex/hooks.json"
assert_not_contains "Skill recorder not duplicated into Codex user config" 'record-skill.sh' "$HOME_DIR/.codex/hooks.json"
assert_not_contains "Skill recorder not duplicated into Codex user config mirror" 'record-skill.sh' "$HOME_DIR/.codex/hooks.json"
assert_not_contains "Instruction guard not duplicated into Codex user config" 'instruction-file-guard.sh' "$HOME_DIR/.codex/hooks.json"
assert_not_contains "Instruction guard not duplicated into Codex user config mirror" 'instruction-file-guard.sh' "$HOME_DIR/.codex/hooks.json"
assert_contains "GSD hook preserved in Codex user config" 'gsd-check-update.js' "$HOME_DIR/.codex/hooks.json"
assert_contains "GSD hook preserved in Codex user config mirror" 'gsd-check-update.js' "$HOME_DIR/.codex/hooks.json"
RUNTIME_CLAUDE_REPORT="$TMP/codex-runtime-claude-reference-report.txt"
{
  rg -n -g '!**/.git/**' -g '!**/*.md' -g '!**/*.html' -g '!**/*.txt' '/\\.claude(/|$)' "$FAKE_MARKETPLACE_ROOT" "$FAKE_SB_INSTALL_ROOT" || true
  rg -n -g '!**/.git/**' -g '!**/*.md' -g '!**/*.html' -g '!**/*.txt' 'os\\.homedir\\(\\).*\\.claude' "$FAKE_MARKETPLACE_ROOT" "$FAKE_SB_INSTALL_ROOT" || true
  rg -n -g '!**/.git/**' -g '!**/*.md' -g '!**/*.html' -g '!**/*.txt' -F '.claude/' "$FAKE_MARKETPLACE_ROOT" "$FAKE_SB_INSTALL_ROOT" || true
} > "$RUNTIME_CLAUDE_REPORT"
assert_file_exists "Codex runtime Claude reference audit report generated" "$RUNTIME_CLAUDE_REPORT"
if [[ -s "$RUNTIME_CLAUDE_REPORT" ]]; then
  echo "FAIL: Runtime Claude path references detected in Codex installation:"
  sed -n '1,20p' "$RUNTIME_CLAUDE_REPORT"
  (( FAIL++ )) || true
else
  echo "PASS: Codex runtime Claude reference audit is clean"
  (( PASS++ )) || true
fi

CLAUDE_REFERENCE_REPORT="$TMP/codex-claude-reference-report.txt"
{
  rg -n -i -g '!skills/**' -g '!hooks/**' -g '!**/.git/**' 'claude' "$FAKE_MARKETPLACE_ROOT" "$FAKE_SB_INSTALL_ROOT" || true
} > "$CLAUDE_REFERENCE_REPORT"
assert_file_exists "Codex claude reference audit report generated" "$CLAUDE_REFERENCE_REPORT"
if [[ -s "$CLAUDE_REFERENCE_REPORT" ]]; then
  echo "INFO: Non-skill/hook claude references detected in Codex installation:"
  sed -n '1,20p' "$CLAUDE_REFERENCE_REPORT"
fi

if [[ -f "$FAKE_MARKETPLACE_ROOT/scripts/gsd-sdk.cjs" ]]; then
  assert_not_contains "Codex gsd-sdk no longer references Claude home" ".claude" "$FAKE_MARKETPLACE_ROOT/scripts/gsd-sdk.cjs"
fi
if [[ -f "$FAKE_SB_INSTALL_ROOT/scripts/gsd-sdk.cjs" ]]; then
  assert_not_contains "Codex gsd-sdk cache copy no longer references Claude home" ".claude" "$FAKE_SB_INSTALL_ROOT/scripts/gsd-sdk.cjs"
fi

NON_SB_HOME="$TMP/no-sb-home"
NON_SB_WORKDIR="$TMP/non-sb-workdir"
mkdir -p "$NON_SB_HOME/.codex" "$NON_SB_WORKDIR"
(
  cd "$NON_SB_WORKDIR"
  PATH="$BIN_DIR:$PATH" \
  HOME="$NON_SB_HOME" \
  GSD_INSTALL_CMD="$BIN_DIR/install-gsd" \
    bash "$SCRIPT" --purge-legacy-skills >/dev/null
)

assert_contains "shared marketplace still registered outside SB root" "[marketplaces.alo-labs-codex]" "$NON_SB_HOME/.codex/config.toml"
assert_not_contains "SB plugin not auto-enabled outside SB root" "[plugins.\"silver-bullet@alo-labs-codex\"]" "$NON_SB_HOME/.codex/config.toml"
assert_not_contains "SB hook state not installed outside SB root" 'silver-bullet@' "$NON_SB_HOME/.codex/config.toml"
if [[ -f "$NON_SB_HOME/.codex/hooks.json" ]]; then
  assert_not_contains "SB hooks not installed outside SB root" 'plugins/silver-bullet/hooks/' "$NON_SB_HOME/.codex/hooks.json"
else
  echo "PASS: SB hooks not installed outside SB root"
fi
if [[ -f "$NON_SB_HOME/.codex/hooks.json" ]]; then
  assert_not_contains "SB hooks not installed outside SB root mirror" 'plugins/silver-bullet/hooks/' "$NON_SB_HOME/.codex/hooks.json"
else
  echo "PASS: SB hooks not installed outside SB root mirror"
fi

SEED_TMP="$(mktemp -d)"
SEED_HOME="$SEED_TMP/home"
mkdir -p "$SEED_HOME/.codex"
cat > "$SEED_HOME/.codex/config.toml" <<'EOF'
[features]
plugin_hooks = true
EOF
PATH="$BIN_DIR:$PATH" \
HOME="$SEED_HOME" \
GSD_INSTALL_CMD="$BIN_DIR/install-gsd" \
  bash "$SCRIPT" --purge-legacy-skills >/dev/null
assert_file_exists "Codex marketplace snapshot seeded when missing" "$SEED_HOME/.codex/.tmp/marketplaces/alo-labs-codex/plugins/silver-bullet/.codex-plugin/plugin.json"

echo
echo "Results: $PASS passed, $FAIL failed, $SKIP skipped"
[[ $FAIL -eq 0 ]]
