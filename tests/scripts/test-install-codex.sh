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

sb_internal_skill() {
  printf '%s/skill-source/%s/SILVER_SOURCE\n' "$1" "$2"
}

assert_no_packaged_skill_md() {
  local desc="$1" path="$2"
  local hits
  hits="$(find "$path" -name '*SKILL.md' ! -path '*/agents/cursor/*' -print 2>/dev/null | head -1 || true)"
  if [[ -n "$hits" ]]; then
    echo "FAIL: $desc — packaged *SKILL.md found under $path (excluding agents/cursor)"
    find "$path" -name '*SKILL.md' ! -path '*/agents/cursor/*' -print 2>/dev/null | head -20
    (( FAIL++ )) || true
  else
    echo "PASS: $desc"
    (( PASS++ )) || true
  fi
}

assert_no_packaged_markdown_skill_sources() {
  local desc="$1" path="$2"
  if find "$path/skill-source" -type f -name 'SILVER_SOURCE.md' -print -quit 2>/dev/null | grep -q .; then
    echo "FAIL: $desc — packaged Markdown skill source found under $path/skill-source"
    find "$path/skill-source" -type f -name 'SILVER_SOURCE.md' -print 2>/dev/null | head -20
    (( FAIL++ )) || true
  else
    echo "PASS: $desc"
    (( PASS++ )) || true
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

assert_no_combined_tool_matchers() {
  local desc="$1" path="$2"
  if python3 - "$path" <<'PY' >/dev/null 2>&1
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
data = json.loads(path.read_text())
bad_matchers = {
    "Bash|shell|exec_command|Skill",
    "Skill|Bash|shell|exec_command",
    "Bash|shell|exec_command",
    "Edit|Write|MultiEdit|Bash|shell|exec_command",
}

for event_name in ("PreToolUse", "PostToolUse"):
    for item in data.get("hooks", {}).get(event_name, []):
        if item.get("matcher") in bad_matchers:
            raise SystemExit(1)

raise SystemExit(0)
PY
  then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — combined command-tool matcher still present in $path"
    (( FAIL++ )) || true
  fi
}

assert_hook_command_matchers() {
  local desc="$1" path="$2" event_name="$3" command_name="$4"
  shift 4
  if python3 - "$path" "$event_name" "$command_name" "$@" <<'PY' >/dev/null 2>&1
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
event_name = sys.argv[2]
command_name = sys.argv[3]
required_matchers = sys.argv[4:]
data = json.loads(path.read_text())
groups = data.get("hooks", {}).get(event_name, [])

present = set()
for group in groups:
    matcher = group.get("matcher", "")
    for hook in group.get("hooks", []):
        if command_name in hook.get("command", ""):
            present.add(matcher)

missing = [matcher for matcher in required_matchers if matcher not in present]
raise SystemExit(0 if not missing else 1)
PY
  then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — missing matcher coverage for $command_name in $path"
    python3 - "$path" "$event_name" "$command_name" "$@" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
event_name = sys.argv[2]
command_name = sys.argv[3]
required_matchers = sys.argv[4:]
data = json.loads(path.read_text())
groups = data.get("hooks", {}).get(event_name, [])

present = []
for group in groups:
    matcher = group.get("matcher", "")
    commands = [hook.get("command", "") for hook in group.get("hooks", [])]
    if any(command_name in command for command in commands):
        present.append(matcher)

print(f"  event={event_name} command={command_name}")
print(f"  required={required_matchers}")
print(f"  present={present}")
PY
    (( FAIL++ )) || true
  fi
}

assert_hook_trust_state_for_source() {
  local desc="$1" config_path="$2" hooks_source_path="$3" hooks_prefix="$4"
  if python3 - "$config_path" "$hooks_source_path" "$hooks_prefix" <<'PY' >/dev/null 2>&1
import hashlib
import json
import os
import pathlib
import re
import sys

config_path = pathlib.Path(sys.argv[1])
hooks_source_path = pathlib.Path(sys.argv[2])
hooks_prefix = sys.argv[3]

def event_slug(name: str) -> str:
    return re.sub(r"(?<!^)(?=[A-Z])", "_", name).lower()

def canonical_json(value):
    if isinstance(value, dict):
        return {key: canonical_json(value[key]) for key in sorted(value) if value[key] is not None}
    if isinstance(value, list):
        return [canonical_json(item) for item in value]
    return value

def hook_current_hash(event_name, matcher, hook):
    hook_type = hook.get("type")
    if hook_type is None and "command" in hook:
        hook_type = "command"
    if hook_type != "command":
        return None
    if hook.get("async", False):
        return None

    command = hook.get("command", "")
    command_windows = hook.get("commandWindows")
    if command_windows is None:
        command_windows = hook.get("command_windows")
    if os.name == "nt" and command_windows:
        command = command_windows
    if not str(command).strip():
        return None

    normalized_hook = {
        "type": "command",
        "command": command,
        "timeout": max(int(hook.get("timeout", 600) or 600), 1),
        "async": False,
    }
    status_message = hook.get("statusMessage")
    if status_message is None:
        status_message = hook.get("status_message")
    if status_message is not None:
        normalized_hook["statusMessage"] = status_message

    identity = {
        "event_name": event_slug(event_name),
        "hooks": [normalized_hook],
    }
    if matcher is not None:
        identity["matcher"] = matcher

    serialized = json.dumps(
        canonical_json(identity),
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")
    return "sha256:" + hashlib.sha256(serialized).hexdigest()

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

source_by_prefix = {hooks_prefix: hooks_source_path}

expected = {}
for prefix, source_path in source_by_prefix.items():
    for event_name, groups in hooks_data_for(source_path).items():
        slug = event_slug(event_name)
        for group_index, group in enumerate(groups):
            for hook_index, hook in enumerate(group.get("hooks", [])):
                digest = hook_current_hash(event_name, group.get("matcher"), hook)
                if digest is None:
                    continue
                key = f"{prefix}:{slug}:{group_index}:{hook_index}"
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
    echo "FAIL: $desc — missing or mismatched hook trust state in $config_path"
    python3 - "$config_path" "$hooks_source_path" "$hooks_prefix" <<'PY'
import hashlib
import json
import os
import pathlib
import re
import sys

config_path = pathlib.Path(sys.argv[1])
hooks_source_path = pathlib.Path(sys.argv[2])
hooks_prefix = sys.argv[3]

def event_slug(name: str) -> str:
    return re.sub(r"(?<!^)(?=[A-Z])", "_", name).lower()

def canonical_json(value):
    if isinstance(value, dict):
        return {key: canonical_json(value[key]) for key in sorted(value) if value[key] is not None}
    if isinstance(value, list):
        return [canonical_json(item) for item in value]
    return value

def hook_current_hash(event_name, matcher, hook):
    hook_type = hook.get("type")
    if hook_type is None and "command" in hook:
        hook_type = "command"
    if hook_type != "command":
        return None
    if hook.get("async", False):
        return None

    command = hook.get("command", "")
    command_windows = hook.get("commandWindows")
    if command_windows is None:
        command_windows = hook.get("command_windows")
    if os.name == "nt" and command_windows:
        command = command_windows
    if not str(command).strip():
        return None

    normalized_hook = {
        "type": "command",
        "command": command,
        "timeout": max(int(hook.get("timeout", 600) or 600), 1),
        "async": False,
    }
    status_message = hook.get("statusMessage")
    if status_message is None:
        status_message = hook.get("status_message")
    if status_message is not None:
        normalized_hook["statusMessage"] = status_message

    identity = {
        "event_name": event_slug(event_name),
        "hooks": [normalized_hook],
    }
    if matcher is not None:
        identity["matcher"] = matcher

    serialized = json.dumps(
        canonical_json(identity),
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")
    return "sha256:" + hashlib.sha256(serialized).hexdigest()

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

source_by_prefix = {hooks_prefix: hooks_source_path}

expected = {}
for prefix, source_path in source_by_prefix.items():
    for event_name, groups in hooks_data_for(source_path).items():
        slug = event_slug(event_name)
        for group_index, group in enumerate(groups):
            for hook_index, hook in enumerate(group.get("hooks", [])):
                digest = hook_current_hash(event_name, group.get("matcher"), hook)
                if digest is None:
                    continue
                key = f"{prefix}:{slug}:{group_index}:{hook_index}"
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
  local desc="$1" needle="$2" path="$3"
  if [[ -d "$path" ]]; then
    if rg -n --hidden -S -- "$needle" "$path" >/dev/null 2>&1; then
      echo "FAIL: $desc — unexpected [$needle] in $path"
      (( FAIL++ )) || true
    else
      echo "PASS: $desc"
      (( PASS++ )) || true
    fi
    return
  fi

  if ! grep -qF -- "$needle" "$path"; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — unexpected [$needle] in $path"
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

assert_command_fails() {
  local desc="$1"
  shift
  if "$@"; then
    echo "FAIL: $desc"
    (( FAIL++ )) || true
  else
    echo "PASS: $desc"
    (( PASS++ )) || true
  fi
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
bash "$REPO_ROOT/scripts/sync-codex-package.sh" >/dev/null
export SILVER_BULLET_RUNTIME="${SILVER_BULLET_RUNTIME:-codex}"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi
SCRIPT="$REPO_ROOT/scripts/install-codex.sh"
HOME_DIR="$TMP/home"
BIN_DIR="$TMP/bin"
mkdir -p \
  "$HOME_DIR/.codex" \
  "$HOME_DIR/.codex/skills/sb:feature" \
  "$HOME_DIR/.codex/skills/silver-review-fix-ladder" \
  "$HOME_DIR/.codex/skills/unrelated-native" \
  "$HOME_DIR/.codex/skills/writing-plans" \
  "$HOME_DIR/.agents/skills/silver-feature" \
  "$HOME_DIR/.agents/skills/using-silver-bullet" \
  "$HOME_DIR/.agents/skills/unrelated-skill" \
  "$BIN_DIR"
cat > "$HOME_DIR/.agents/skills/unrelated-skill/SKILL.md" <<'EOF'
---
name: unrelated-skill
---
EOF

cat > "$HOME_DIR/.codex/skills/unrelated-native/SKILL.md" <<'EOF'
---
name: unrelated-native
---
EOF

cat > "$HOME_DIR/.codex/skills/sb:feature/SKILL.md" <<'EOF'
---
name: "sb:feature"
title: "Silver Bullet: Silver: Feature"
---
EOF

cat > "$HOME_DIR/.codex/skills/silver-review-fix-ladder/SKILL.md" <<'EOF'
---
name: silver-review-fix-ladder
title: External Review Fix Ladder
---
EOF

cat > "$HOME_DIR/.codex/skills/writing-plans/SKILL.md" <<'EOF'
---
name: writing-plans
---
EOF

cat > "$HOME_DIR/.codex/skills/writing-plans/.silver-bullet-managed" <<'EOF'
source=Silver Bullet
EOF

cat > "$HOME_DIR/.agents/skills/using-silver-bullet/SKILL.md" <<'EOF'
---
name: using-silver-bullet
---
EOF

cat > "$BIN_DIR/install-legacy-tool" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$HOME/.codex/get-shit-done"
printf '9.9.9' > "$HOME/.codex/get-shit-done/VERSION"
EOF
chmod +x "$BIN_DIR/install-legacy-tool"

cat > "$BIN_DIR/npx" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "--yes" && "${2:-}" == "get-shit-done-cc@latest" ]]; then
  mkdir -p "$HOME/.codex/get-shit-done"
  printf '9.9.9' > "$HOME/.codex/get-shit-done/VERSION"
  exit 0
fi
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
legacy_claude_root="${SB_RUNTIME_HOME_ROOT}"
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
            "command": "node \"${SB_RUNTIME_HOME_ROOT}/hooks/legacy-check-update.js\""
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
            "command": "node \"${SB_RUNTIME_HOME_ROOT}/hooks/legacy-context-monitor.js\""
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
FAKE_KW_MARKETPLACE_ROOT="$TMP/knowledge-work-plugins"
FAKE_SB_PACKAGE_ROOT="$FAKE_MARKETPLACE_ROOT/plugins/silver-bullet"
FAKE_SB_SKILLS_SOURCE="$FAKE_MARKETPLACE_ROOT/skill-source"
FAKE_STALE_MARKETPLACE_SKILLS="$FAKE_MARKETPLACE_ROOT/skills"
FAKE_CACHE_ROOT="$HOME_DIR/.codex/plugins/cache/alo-labs-codex/silver-bullet/0.32.3"
FAKE_OLD_CACHE_ROOT="$HOME_DIR/.codex/plugins/cache/alo-labs-codex/silver-bullet/0.32.2"
FAKE_SB_INSTALL_ROOT="$FAKE_CACHE_ROOT"
FAKE_SB_INSTALL_ALIAS="$HOME_DIR/.codex/plugins/cache/alo-labs-codex/silver-bullet/current"
FAKE_LEGACY_BACKUP_SKILL="$HOME_DIR/.codex/legacy-uppercase-backups/20260513T031529Z.test/Codex/plugins/cache/alo-labs-codex/silver-bullet/0.31.0/skills/silver-feature/SKILL.md"
FAKE_LEGACY_BACKUP_GENERATED_SKILL="$HOME_DIR/.codex/legacy-uppercase-backups/20260513T031529Z.test/Codex/.tmp/marketplaces/alo-labs-codex/plugins/silver-bullet/.generated-skills/silver-feature/SKILL.md"
FAKE_LEGACY_BACKUP_MARKETPLACE_SKILL="$HOME_DIR/.codex/legacy-uppercase-backups/20260513T031529Z.test/Codex/.tmp/marketplaces/alo-labs-codex/skills/silver-feature/SKILL.md"
FAKE_TMP_MARKETPLACE_BACKUP_SKILL="$HOME_DIR/.codex/.tmp/marketplaces/marketplace-backup-test/root/plugins/silver-bullet/skills/silver-feature/SKILL.md"
FAKE_TMP_MARKETPLACE_BACKUP_AGENT_SKILL="$HOME_DIR/.codex/.tmp/marketplaces/marketplace-backup-test/root/agents/codex/silver-feature/SKILL.md"
FAKE_TMP_SB_LIVE_COMMAND_SKILL="$HOME_DIR/.codex/.tmp/sb-live-command.test/plugins/silver-bullet/skills/silver-feature/SKILL.md"
FAKE_TMP_SB_LIVE_COMMAND_AGENT_SKILL="$HOME_DIR/.codex/.tmp/sb-live-command.test/plugins/silver-bullet/agents/codex/silver-feature/SKILL.md"
FAKE_SB_STALE_ROOT="$HOME_DIR/.codex/plugins/cache/alo-labs-codex-local/silver-bullet/0.32.3"
FAKE_SB_STALE_ALIAS="$HOME_DIR/.codex/plugins/cache/alo-labs-codex-local/silver-bullet/current"
FAKE_SB_STALE_ROOT_MIRROR="$HOME_DIR/.codex/plugins/cache/alo-labs-codex-local/silver-bullet/0.32.3"
FAKE_SB_STALE_ALIAS_MIRROR="$HOME_DIR/.codex/plugins/cache/alo-labs-codex-local/silver-bullet/current"
FAKE_SUPERPOWERS_ROOT="$HOME_DIR/.codex/plugins/cache/superpowers-marketplace/superpowers/1.0.0"
FAKE_SUPERPOWERS_ALIAS="$HOME_DIR/.codex/plugins/cache/superpowers-marketplace/superpowers/current"
_LEGACY_VENDOR_ID=$(printf '%s%s' gs d)
FAKE_LEGACY_ROOT="$HOME_DIR/.codex/plugins/cache/get-shit-done-marketplace/${_LEGACY_VENDOR_ID}/1.41.1"
FAKE_LEGACY_ALIAS="$HOME_DIR/.codex/plugins/cache/get-shit-done-marketplace/${_LEGACY_VENDOR_ID}/current"
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
  "$FAKE_KW_MARKETPLACE_ROOT/engineering/skills/documentation" \
  "$FAKE_KW_MARKETPLACE_ROOT/design/skills/design-system" \
  "$FAKE_KW_MARKETPLACE_ROOT/product-management/skills/write-spec" \
  "$FAKE_STALE_MARKETPLACE_SKILLS/silver-feature" \
  "$FAKE_SB_SKILLS_SOURCE/silver-init" \
  "$FAKE_SB_SKILLS_SOURCE/silver-ensure-docs" \
  "$FAKE_SB_SKILLS_SOURCE/silver-feature" \
  "$FAKE_SB_SKILLS_SOURCE/silver" \
  "$FAKE_OLD_CACHE_ROOT/skills/silver-feature" \
  "$FAKE_CACHE_ROOT/hooks" \
  "$FAKE_SB_STALE_ROOT" \
  "$FAKE_SB_STALE_ROOT_MIRROR" \
  "$(dirname "$FAKE_LEGACY_BACKUP_SKILL")" \
  "$(dirname "$FAKE_LEGACY_BACKUP_GENERATED_SKILL")" \
  "$(dirname "$FAKE_LEGACY_BACKUP_MARKETPLACE_SKILL")" \
  "$(dirname "$FAKE_TMP_MARKETPLACE_BACKUP_SKILL")" \
  "$(dirname "$FAKE_TMP_MARKETPLACE_BACKUP_AGENT_SKILL")" \
  "$(dirname "$FAKE_TMP_SB_LIVE_COMMAND_SKILL")" \
  "$(dirname "$FAKE_TMP_SB_LIVE_COMMAND_AGENT_SKILL")"
cat > "$FAKE_SB_PACKAGE_ROOT/.codex-plugin/plugin.json" <<'EOF'
{
  "name": "silver-bullet",
  "version": "0.32.3",
  "commands": "./commands/",
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
cat > "$FAKE_STALE_MARKETPLACE_SKILLS/silver-feature/SKILL.md" <<'EOF'
---
name: silver-feature
title: "Silver Bullet: Silver: Feature"
---
EOF
cat > "$FAKE_OLD_CACHE_ROOT/skills/silver-feature/SKILL.md" <<'EOF'
---
name: sb:feature
title: "Silver Bullet: Silver: Feature"
---
EOF
cat > "$FAKE_LEGACY_BACKUP_SKILL" <<'EOF'
---
name: silver-feature
title: "Silver Bullet: Silver: Feature"
---
EOF
cat > "$FAKE_LEGACY_BACKUP_GENERATED_SKILL" <<'EOF'
---
name: sb:feature
title: "Silver Bullet: Silver: Feature"
---
EOF
cat > "$FAKE_LEGACY_BACKUP_MARKETPLACE_SKILL" <<'EOF'
---
name: silver-feature
title: "Silver Bullet: Silver: Feature"
---
EOF
cat > "$FAKE_TMP_MARKETPLACE_BACKUP_SKILL" <<'EOF'
---
name: silver-feature
title: "Silver Bullet: Silver: Feature"
---
EOF
cat > "$FAKE_TMP_MARKETPLACE_BACKUP_AGENT_SKILL" <<'EOF'
---
name: "sb:feature"
title: "Silver Bullet: Silver: Feature"
---
EOF
cat > "$FAKE_TMP_SB_LIVE_COMMAND_SKILL" <<'EOF'
---
name: "sb:feature"
title: "Silver Bullet: Silver: Feature"
---
EOF
cat > "$FAKE_TMP_SB_LIVE_COMMAND_AGENT_SKILL" <<'EOF'
---
name: "sb:feature"
title: "Silver Bullet: Silver: Feature"
---
EOF
cat > "$FAKE_KW_MARKETPLACE_ROOT/engineering/skills/documentation/SKILL.md" <<'EOF'
---
name: documentation
---
EOF
cat > "$FAKE_KW_MARKETPLACE_ROOT/design/skills/design-system/SKILL.md" <<'EOF'
---
name: design-system
---
EOF
cat > "$FAKE_KW_MARKETPLACE_ROOT/product-management/skills/write-spec/SKILL.md" <<'EOF'
---
name: write-spec
---
EOF
cp "$FAKE_HOOKS_FIXTURE" "$FAKE_MARKETPLACE_ROOT/hooks/hooks.json"
cp "$FAKE_HOOKS_FIXTURE" "$FAKE_CACHE_ROOT/hooks/hooks.json"
ln -s "$REPO_ROOT/README.md" "$FAKE_MARKETPLACE_ROOT/README.md"
rsync -a "$REPO_ROOT/hooks/" "$FAKE_SB_PACKAGE_ROOT/hooks/"
rsync -a "$REPO_ROOT/plugins/silver-bullet/skill-source/" "$FAKE_SB_PACKAGE_ROOT/skill-source/"

python3 - "$HOME_DIR" "$FAKE_SB_INSTALL_ROOT" "$FAKE_SUPERPOWERS_ROOT" "$FAKE_LEGACY_ROOT" "$FAKE_SIDEKICK_ROOT" "$FAKE_ENGINEERING_ROOT" "$FAKE_DESIGN_ROOT" "$FAKE_PRODUCT_ROOT" "$FAKE_SIDEKICK_STALE_ROOT" "$FAKE_ENGINEERING_STALE_ROOT" "$FAKE_DESIGN_STALE_ROOT" "$FAKE_PRODUCT_STALE_ROOT" "$FAKE_SB_STALE_ROOT" "$FAKE_SB_STALE_ROOT_MIRROR" "$_LEGACY_VENDOR_ID" <<'PY'
import json
import pathlib
import sys

home = pathlib.Path(sys.argv[1])
sb_install_root = pathlib.Path(sys.argv[2])
superpowers_root = pathlib.Path(sys.argv[3])
legacy_root = pathlib.Path(sys.argv[4])
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
legacy_vendor = sys.argv[15]

def write_json(path: pathlib.Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2) + "\n")

def write_text(path: pathlib.Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)

def write_manifest(path: pathlib.Path, name: str, version: str) -> None:
    payload = {"name": name, "version": version}
    if name in {"engineering", "design", "product-management"}:
        payload["skills"] = "./upstream/skills/"
    write_json(path, payload)

for root in [
    sb_install_root,
    superpowers_root,
    legacy_root,
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
write_manifest(legacy_root / ".codex-plugin/plugin.json", legacy_vendor, "1.41.1")
write_manifest(sidekick_root / ".codex-plugin/plugin.json", "sidekick", "0.5.4")
write_manifest(engineering_root / ".codex-plugin/plugin.json", "engineering", "1.2.0")
write_manifest(design_root / ".codex-plugin/plugin.json", "design", "1.2.0")
write_manifest(product_root / ".codex-plugin/plugin.json", "product-management", "1.2.0")

write_text(sidekick_root / "skills/codex-delegate/SKILL.md", "---\nname: codex-delegate\n---\n")
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
        f"{legacy_vendor}@get-shit-done-marketplace": [
            {
                "scope": "project",
                "projectPath": str(home),
                "installPath": str(legacy_root),
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
- Renamed /using-silver-bullet skill to /sb:init
- Kept other release notes intact
EOF

cd "$REPO_ROOT"
SB_CODEX_LOCAL_MARKETPLACE_SOURCE="$FAKE_MARKETPLACE_ROOT" \
PATH="$BIN_DIR:$PATH" \
HOME="$HOME_DIR" \
  bash "$SCRIPT" --purge-legacy-skills >/dev/null
FAKE_LEGACY_CACHE_ROOT="$FAKE_CACHE_ROOT"
FAKE_CACHE_ROOT="$FAKE_SB_INSTALL_ALIAS"

assert_file_absent "Codex installer does not bootstrap GSD" "$HOME_DIR/.codex/get-shit-done/VERSION"
assert_not_contains "legacy marketplace removed from config" "[marketplaces.silver-bullet-local]" "$HOME_DIR/.codex/config.toml"
assert_contains "shared marketplace registered in config" "[marketplaces.alo-labs-codex]" "$HOME_DIR/.codex/config.toml"
assert_contains "shared marketplace source preserved" "source = \"$FAKE_MARKETPLACE_ROOT\"" "$HOME_DIR/.codex/config.toml"
assert_not_contains "superpowers marketplace not registered by default" "[marketplaces.superpowers-marketplace]" "$HOME_DIR/.codex/config.toml"
assert_not_contains "GSD marketplace not registered by default" "[marketplaces.get-shit-done-marketplace]" "$HOME_DIR/.codex/config.toml"
assert_not_contains "superpowers plugin not enabled by default" '[plugins."superpowers@superpowers-marketplace"]' "$HOME_DIR/.codex/config.toml"
assert_not_contains "legacy plugin not enabled by default" "[plugins.\"${_LEGACY_VENDOR_ID}@get-shit-done-marketplace\"]" "$HOME_DIR/.codex/config.toml"
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
assert_not_contains "Silver Bullet plugin manifest does not advertise duplicate plugin skill listings" '"skills": "./skills/"' "$FAKE_SB_INSTALL_ALIAS/.codex-plugin/plugin.json"
assert_command_succeeds "Silver Bullet cache alias created" test -L "$FAKE_SB_INSTALL_ALIAS"
assert_file_absent "Silver Bullet cache alias does not expose plugin picker skills surface" "$FAKE_SB_INSTALL_ALIAS/skills"
assert_file_exists "Silver Bullet cache alias exposes internal skill source" "$(sb_internal_skill "$FAKE_SB_INSTALL_ALIAS" sb-feature)"
assert_file_exists "Silver Bullet cache alias exposes hidden modularity dimension source" "$(sb_internal_skill "$FAKE_SB_INSTALL_ALIAS" modularity)"
assert_file_exists "Silver Bullet cache alias exposes hidden testability dimension source" "$(sb_internal_skill "$FAKE_SB_INSTALL_ALIAS" testability)"
assert_no_packaged_skill_md "Silver Bullet cache alias exposes no picker-discoverable SKILL.md files" "$FAKE_SB_INSTALL_ALIAS"
assert_file_exists "Codex native SB mirror exposes Silver Bullet feature skill" "$HOME_DIR/.codex/skills/sb:feature/SKILL.md"
assert_file_exists "Codex native SB mirror exposes Silver Bullet router skill" "$HOME_DIR/.codex/skills/sb/SKILL.md"
assert_file_exists "Codex native SB mirror marks Silver Bullet feature as managed" "$HOME_DIR/.codex/skills/sb:feature/.silver-bullet-managed"
assert_contains "Codex native SB mirror uses bare silver namespace title" "title: \"Feature\"" "$HOME_DIR/.codex/skills/sb:feature/SKILL.md"
assert_not_contains "Codex native SB mirror avoids duplicate Silver title prefix" "title: \"Silver: Feature\"" "$HOME_DIR/.codex/skills/sb:feature/SKILL.md"
assert_not_contains "Codex native SB mirror removes legacy plugin title prefix" "Silver Bullet:" "$HOME_DIR/.codex/skills/sb:feature/SKILL.md"
assert_contains "Codex native SB mirror preserves Silver route name" "name: \"sb:feature\"" "$HOME_DIR/.codex/skills/sb:feature/SKILL.md"
assert_file_exists "Codex native SB mirror exposes review fix ladder helper" "$HOME_DIR/.codex/skills/sb-review-fix-ladder/SKILL.md"
assert_file_exists "Codex native SB mirror marks review fix ladder as managed" "$HOME_DIR/.codex/skills/sb-review-fix-ladder/.silver-bullet-managed"
assert_contains "Codex native review fix ladder uses SB picker prefix" "title: \"Review Fix Ladder\"" "$HOME_DIR/.codex/skills/sb-review-fix-ladder/SKILL.md"
assert_file_exists "Codex native SB mirror exposes verify-tests gate" "$HOME_DIR/.codex/skills/verify-tests/SKILL.md"
assert_file_exists "Codex native SB mirror marks verify-tests gate as managed" "$HOME_DIR/.codex/skills/verify-tests/.silver-bullet-managed"
assert_contains "Codex native verify-tests gate uses SB picker prefix" "title: \"SB: Verify Tests\"" "$HOME_DIR/.codex/skills/verify-tests/SKILL.md"
assert_file_exists "Codex native SB mirror exposes security gate" "$HOME_DIR/.codex/skills/security/SKILL.md"
assert_file_exists "Codex native SB mirror marks security gate as managed" "$HOME_DIR/.codex/skills/security/.silver-bullet-managed"
assert_contains "Codex native security gate uses SB picker prefix" "title: \"SB: Security\"" "$HOME_DIR/.codex/skills/security/SKILL.md"
assert_file_exists "Codex native SB mirror exposes DevOps quality gate" "$HOME_DIR/.codex/skills/devops-quality-gates/SKILL.md"
assert_file_exists "Codex native SB mirror marks DevOps quality gate as managed" "$HOME_DIR/.codex/skills/devops-quality-gates/.silver-bullet-managed"
assert_contains "Codex native DevOps quality gate uses SB picker prefix" "title: \"SB: DevOps Quality Gates\"" "$HOME_DIR/.codex/skills/devops-quality-gates/SKILL.md"
assert_file_absent "Codex native SB mirror excludes hidden TDD support skill" "$HOME_DIR/.codex/skills/tdd/SKILL.md"
assert_file_absent "Codex native SB mirror excludes hidden modularity dimension helper" "$HOME_DIR/.codex/skills/modularity/SKILL.md"
assert_file_absent "Codex native SB mirror excludes hidden testability dimension helper" "$HOME_DIR/.codex/skills/testability/SKILL.md"
assert_file_absent "Codex native SB mirror prunes stale managed writing-plans skill" "$HOME_DIR/.codex/skills/writing-plans"
assert_file_exists "Codex native SB mirror preserves unrelated native skill" "$HOME_DIR/.codex/skills/unrelated-native/SKILL.md"
assert_file_absent "stale SB local install root removed" "$FAKE_SB_STALE_ROOT"
assert_file_absent "stale SB local cache alias removed" "$FAKE_SB_STALE_ALIAS"
assert_file_absent "stale SB local install root removed from lowercase mirror" "$FAKE_SB_STALE_ROOT_MIRROR"
assert_file_absent "stale SB local cache alias removed from lowercase mirror" "$FAKE_SB_STALE_ALIAS_MIRROR"
assert_file_absent "stale same-marketplace SB cache version removed" "$FAKE_OLD_CACHE_ROOT"
assert_file_absent "stale pre-release SB cache version removed" "$FAKE_LEGACY_CACHE_ROOT"
assert_file_absent "stale marketplace root picker skill removed" "$FAKE_STALE_MARKETPLACE_SKILLS/silver-feature/SKILL.md"
assert_file_absent "legacy backup SB picker skill removed" "$FAKE_LEGACY_BACKUP_SKILL"
assert_file_absent "legacy backup generated SB picker skill removed" "$FAKE_LEGACY_BACKUP_GENERATED_SKILL"
assert_file_absent "legacy backup marketplace SB picker skill removed" "$FAKE_LEGACY_BACKUP_MARKETPLACE_SKILL"
assert_file_absent "temporary marketplace backup SB picker skill removed" "$FAKE_TMP_MARKETPLACE_BACKUP_SKILL"
assert_file_absent "temporary marketplace backup SB agent skill removed" "$FAKE_TMP_MARKETPLACE_BACKUP_AGENT_SKILL"
assert_file_absent "temporary SB live-command picker skill removed" "$FAKE_TMP_SB_LIVE_COMMAND_SKILL"
assert_file_absent "temporary SB live-command agent skill removed" "$FAKE_TMP_SB_LIVE_COMMAND_AGENT_SKILL"
assert_command_succeeds "Existing optional Superpowers cache alias preserved" test -L "$FAKE_SUPERPOWERS_ALIAS"
assert_command_succeeds "Existing optional GSD cache alias preserved" test -L "$FAKE_LEGACY_ALIAS"
assert_command_succeeds "Sidekick cache alias created" test -L "$FAKE_SIDEKICK_ALIAS"
assert_command_succeeds "Engineering cache alias created" test -L "$FAKE_ENGINEERING_ALIAS"
assert_command_succeeds "Design cache alias created" test -L "$FAKE_DESIGN_ALIAS"
assert_command_succeeds "Product-management cache alias created" test -L "$FAKE_PRODUCT_ALIAS"
assert_file_exists "Marketplace root hooks config materialized" "$FAKE_MARKETPLACE_ROOT/hooks/hooks.json"
assert_no_async_true "Marketplace root hooks config normalized for Codex package" "$FAKE_MARKETPLACE_ROOT/hooks/hooks.json"
assert_file_exists "Marketplace root Codex hook adapter materialized" "$FAKE_MARKETPLACE_ROOT/hooks/codex-hook-adapter.sh"
assert_not_symlink "SB hooks directory materialized" "$FAKE_SB_PACKAGE_ROOT/hooks"
assert_file_exists "SB hooks config materialized" "$FAKE_SB_PACKAGE_ROOT/hooks/hooks.json"
assert_file_exists "SB package Codex hook adapter materialized" "$FAKE_SB_PACKAGE_ROOT/hooks/codex-hook-adapter.sh"
assert_file_absent "SB package does not expose plugin picker skills directory" "$FAKE_SB_PACKAGE_ROOT/skills"
assert_not_symlink "SB internal skill-source directory materialized" "$FAKE_SB_PACKAGE_ROOT/skill-source"
assert_not_symlink "SB scripts directory materialized" "$FAKE_SB_PACKAGE_ROOT/scripts"
assert_not_symlink "SB templates directory materialized" "$FAKE_SB_PACKAGE_ROOT/templates"
assert_file_exists "SB invoke-skill adapter materialized" "$FAKE_SB_PACKAGE_ROOT/scripts/silver-bullet"
assert_file_exists "SB workflows helper materialized" "$FAKE_SB_PACKAGE_ROOT/scripts/workflows.sh"
assert_file_exists "SB scan helper materialized" "$FAKE_SB_PACKAGE_ROOT/scripts/silver-scan.sh"
assert_file_exists "SB package sanitizer helper materialized" "$FAKE_SB_PACKAGE_ROOT/scripts/codex-sanitize-package.sh"
assert_file_exists "Current cache invoke-skill adapter synced" "$FAKE_CACHE_ROOT/scripts/silver-bullet"
assert_file_exists "Current cache workflows helper synced" "$FAKE_CACHE_ROOT/scripts/workflows.sh"
assert_file_exists "Current cache scan helper synced" "$FAKE_CACHE_ROOT/scripts/silver-scan.sh"
assert_file_exists "Current cache package sanitizer helper synced" "$FAKE_CACHE_ROOT/scripts/codex-sanitize-package.sh"
assert_file_exists "Codex invoke-skill CLI shim installed" "$HOME_DIR/.codex/bin/silver-bullet"
assert_contains "Codex invoke-skill CLI shim targets SB cache" "plugins/cache/alo-labs-codex/silver-bullet" "$HOME_DIR/.codex/bin/silver-bullet"
assert_no_async_true "SB hooks config normalized for Codex package" "$FAKE_SB_PACKAGE_ROOT/hooks/hooks.json"
assert_no_async_true "Current cache hooks config normalized for Codex package" "$FAKE_CACHE_ROOT/hooks/hooks.json"
assert_no_combined_tool_matchers "Marketplace root hooks avoid combined command-tool matchers" "$FAKE_MARKETPLACE_ROOT/hooks/hooks.json"
assert_no_combined_tool_matchers "SB hooks avoid combined command-tool matchers" "$FAKE_SB_PACKAGE_ROOT/hooks/hooks.json"
assert_no_combined_tool_matchers "Current cache hooks avoid combined command-tool matchers" "$FAKE_CACHE_ROOT/hooks/hooks.json"
assert_not_contains "SB package hooks no longer use Claude plugin root placeholders" '${CLAUDE_PLUGIN_ROOT}' "$FAKE_SB_PACKAGE_ROOT/hooks/hooks.json"
assert_not_contains "Current cache SB hooks no longer use Claude plugin root placeholders" '${CLAUDE_PLUGIN_ROOT}' "$FAKE_CACHE_ROOT/hooks/hooks.json"
assert_not_contains "SB package does not contain AskUserQuestion" "AskUserQuestion" "$FAKE_SB_PACKAGE_ROOT"
assert_not_contains "Current cache package does not contain AskUserQuestion" "AskUserQuestion" "$FAKE_CACHE_ROOT"
assert_not_contains "SB package avoids Claude-only Skill tool wording" "via the Skill tool" "$FAKE_SB_PACKAGE_ROOT"
assert_not_contains "Current cache package avoids Claude-only Skill tool wording" "via the Skill tool" "$FAKE_CACHE_ROOT"
assert_not_contains "SB package avoids duplicate skill tracker wording" "PostToolUse/Skill or Codex invoke-skill receipt or Codex" "$FAKE_SB_PACKAGE_ROOT"
assert_not_contains "Current cache package avoids duplicate skill tracker wording" "PostToolUse/Skill or Codex invoke-skill receipt or Codex" "$FAKE_CACHE_ROOT"
assert_not_contains "SB package avoids Claude-only Agent tool wording" "Agent tool" "$FAKE_SB_PACKAGE_ROOT"
assert_not_contains "Current cache package avoids Claude-only Agent tool wording" "Agent tool" "$FAKE_CACHE_ROOT"
assert_not_contains "SB package avoids Claude-only Read tool wording" "Read tool" "$FAKE_SB_PACKAGE_ROOT"
assert_not_contains "Current cache package avoids Claude-only Read tool wording" "Read tool" "$FAKE_CACHE_ROOT"
assert_not_contains "SB package avoids Claude-only Write tool wording" "Write tool" "$FAKE_SB_PACKAGE_ROOT"
assert_not_contains "Current cache package avoids Claude-only Write tool wording" "Write tool" "$FAKE_CACHE_ROOT"
assert_not_contains "SB package avoids Claude-only Edit tool wording" "Edit tool" "$FAKE_SB_PACKAGE_ROOT"
assert_not_contains "Current cache package avoids Claude-only Edit tool wording" "Edit tool" "$FAKE_CACHE_ROOT"
assert_not_contains "SB package avoids Claude MCP install command" "claude mcp install" "$FAKE_SB_PACKAGE_ROOT"
assert_not_contains "Current cache package avoids Claude MCP install command" "claude mcp install" "$FAKE_CACHE_ROOT"
assert_not_contains "SB package avoids manual state recording workaround" "Manually record skills in agent-mode sessions" "$FAKE_SB_PACKAGE_ROOT"
assert_not_contains "Current cache package avoids manual state recording workaround" "Manually record skills in agent-mode sessions" "$FAKE_CACHE_ROOT"
assert_not_contains "SB package avoids state-file write workaround" "write its name to the SB state file" "$FAKE_SB_PACKAGE_ROOT"
assert_not_contains "Current cache package avoids state-file write workaround" "write its name to the SB state file" "$FAKE_CACHE_ROOT"
assert_not_contains "SB package does not contain ${SB_RUNTIME_HOME_ROOT} paths" "${SB_RUNTIME_HOME_ROOT}" "$FAKE_SB_PACKAGE_ROOT"
assert_not_contains "Current cache package does not contain ${SB_RUNTIME_HOME_ROOT} paths" "${SB_RUNTIME_HOME_ROOT}" "$FAKE_CACHE_ROOT"
assert_contains "SB runtime path helper keeps dynamic state path" 'SB_RUNTIME_STATE_DIR="${SB_RUNTIME_HOME_ROOT}/.silver-bullet"' "$FAKE_SB_PACKAGE_ROOT/hooks/lib/runtime-paths.sh"
assert_contains "Current cache runtime path helper keeps dynamic state path" 'SB_RUNTIME_STATE_DIR="${SB_RUNTIME_HOME_ROOT}/.silver-bullet"' "$FAKE_CACHE_ROOT/hooks/lib/runtime-paths.sh"
assert_not_contains "SB runtime path helper does not bake literal tilde state root" 'SB_RUNTIME_STATE_DIR="~/.codex/.silver-bullet"' "$FAKE_SB_PACKAGE_ROOT/hooks/lib/runtime-paths.sh"
assert_not_contains "Current cache runtime path helper does not bake literal tilde state root" 'SB_RUNTIME_STATE_DIR="~/.codex/.silver-bullet"' "$FAKE_CACHE_ROOT/hooks/lib/runtime-paths.sh"
assert_contains "SB dev-cycle-check keeps dynamic plugin cache path" 'plugin_cache="${SB_RUNTIME_PLUGIN_CACHE_ROOT}"' "$FAKE_SB_PACKAGE_ROOT/hooks/dev-cycle-check.sh"
assert_contains "Current cache dev-cycle-check keeps dynamic plugin cache path" 'plugin_cache="${SB_RUNTIME_PLUGIN_CACHE_ROOT}"' "$FAKE_CACHE_ROOT/hooks/dev-cycle-check.sh"
assert_not_contains "SB dev-cycle-check does not bake literal tilde plugin cache path" 'plugin_cache="~/.codex/plugins/cache"' "$FAKE_SB_PACKAGE_ROOT/hooks/dev-cycle-check.sh"
assert_not_contains "Current cache dev-cycle-check does not bake literal tilde plugin cache path" 'plugin_cache="~/.codex/plugins/cache"' "$FAKE_CACHE_ROOT/hooks/dev-cycle-check.sh"
assert_contains "SB debug-dump keeps dynamic runtime state dir" 'DBG_DIR="${SB_RUNTIME_STATE_DIR}"' "$FAKE_SB_PACKAGE_ROOT/hooks/debug-dump.sh"
assert_contains "Current cache debug-dump keeps dynamic runtime state dir" 'DBG_DIR="${SB_RUNTIME_STATE_DIR}"' "$FAKE_CACHE_ROOT/hooks/debug-dump.sh"
assert_not_contains "SB debug-dump does not bake literal tilde state dir" 'DBG_DIR="~/.codex/.silver-bullet"' "$FAKE_SB_PACKAGE_ROOT/hooks/debug-dump.sh"
assert_not_contains "Current cache debug-dump does not bake literal tilde state dir" 'DBG_DIR="~/.codex/.silver-bullet"' "$FAKE_CACHE_ROOT/hooks/debug-dump.sh"
assert_not_contains "SB package does not contain /compact commands" "/compact" "$FAKE_SB_PACKAGE_ROOT"
assert_not_contains "Current cache package does not contain /compact commands" "/compact" "$FAKE_CACHE_ROOT"
assert_not_contains "SB package does not contain model_profile routing" 'model_profile: "balanced"' "$FAKE_SB_PACKAGE_ROOT"
assert_not_contains "Current cache package does not contain model_profile routing" 'model_profile: "balanced"' "$FAKE_CACHE_ROOT"
assert_not_contains "SB package does not contain auto-routing wording" "auto-select the correct model for the current host" "$FAKE_SB_PACKAGE_ROOT"
assert_not_contains "Current cache package does not contain auto-routing wording" "auto-select the correct model for the current host" "$FAKE_CACHE_ROOT"
assert_not_contains "SB package does not contain manual routing wording" "Handled automatically via \`model_profile: \"balanced\"\`" "$FAKE_SB_PACKAGE_ROOT"
assert_not_contains "Current cache package does not contain manual routing wording" "Handled automatically via \`model_profile: \"balanced\"\`" "$FAKE_CACHE_ROOT"
assert_contains "SB package uses HOME-expanded Codex state paths" '$HOME/.codex/.silver-bullet/state' "$FAKE_SB_PACKAGE_ROOT/templates/silver-bullet.md.base"
assert_contains "Current cache uses HOME-expanded Codex state paths" '$HOME/.codex/.silver-bullet/state' "$FAKE_CACHE_ROOT/templates/silver-bullet.md.base"
assert_contains "SB package tracks SB lifecycle markers in config" '"silver-context"' "$FAKE_SB_PACKAGE_ROOT/templates/silver-bullet.config.json.default"
assert_contains "Current cache tracks SB lifecycle markers in config" '"silver-context"' "$FAKE_CACHE_ROOT/templates/silver-bullet.config.json.default"
assert_contains "SB package hooks routes commands through Codex hook adapter (may differ from marketplace canonical)" "codex-hook-adapter.sh" "$FAKE_SB_PACKAGE_ROOT/hooks/hooks.json"
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
assert_file_exists "SB Claude agent bundle synced into source bundle" "$REPO_ROOT/agents/claude/sb:scan/SKILL.md"
assert_file_exists "SB Codex agent bundle synced into source bundle" "$REPO_ROOT/host-bundles/codex/sb-scan/SKILL.md"
assert_file_absent "Installed SB package does not expose Claude agent SKILL.md bundle" "$FAKE_SB_PACKAGE_ROOT/agents/claude"
assert_file_absent "Installed SB package does not expose Codex agent SKILL.md bundle under agents/" "$FAKE_SB_PACKAGE_ROOT/agents/codex"
assert_file_exists "Installed SB package exposes sb slash command stub" "$FAKE_SB_PACKAGE_ROOT/commands/sb.md"
assert_file_absent "Installed SB package does not ship agents/cursor subagent mirror" "$FAKE_SB_PACKAGE_ROOT/agents/cursor"
assert_file_exists "Source workspace cursor bundle exposes non-command subagent skill" "$REPO_ROOT/host-bundles/cursor/sb:plan/SKILL.md"
assert_file_absent "Current cache does not expose Claude agent SKILL.md bundle" "$FAKE_CACHE_ROOT/agents/claude"
assert_file_absent "Current cache does not expose Codex agent SKILL.md bundle under agents/" "$FAKE_CACHE_ROOT/agents/codex"
assert_file_absent "SB source bundle does not expose plugin picker skills directory" "$REPO_ROOT/plugins/silver-bullet/skills"
assert_file_exists "SB init skill source synced into source bundle" "$(sb_internal_skill "$REPO_ROOT/plugins/silver-bullet" sb-init)"
assert_file_exists "SB ensure-docs skill source synced into source bundle" "$(sb_internal_skill "$REPO_ROOT/plugins/silver-bullet" sb-ensure-docs)"
assert_file_exists "SB feature skill source synced into source bundle" "$(sb_internal_skill "$REPO_ROOT/plugins/silver-bullet" sb-feature)"
assert_file_exists "SB router skill source synced into source bundle" "$(sb_internal_skill "$REPO_ROOT/plugins/silver-bullet" sb)"
assert_file_exists "SB handoff skill source synced into source bundle" "$(sb_internal_skill "$REPO_ROOT/plugins/silver-bullet" sb-handoff)"
assert_file_exists "Review fix ladder skill source synced into source bundle" "$(sb_internal_skill "$REPO_ROOT/plugins/silver-bullet" sb-review-fix-ladder)"
assert_file_exists "Installed review fix ladder skill source synced" "$(sb_internal_skill "$FAKE_SB_PACKAGE_ROOT" sb-review-fix-ladder)"
assert_file_exists "Current cache review fix ladder skill source synced" "$(sb_internal_skill "$FAKE_CACHE_ROOT" sb-review-fix-ladder)"
assert_file_exists "Current alias review fix ladder skill source synced" "$(sb_internal_skill "$FAKE_SB_INSTALL_ALIAS" sb-review-fix-ladder)"
assert_not_symlink "SB skill-source surface is materialized in the source bundle" "$REPO_ROOT/plugins/silver-bullet/skill-source"
assert_not_symlink "SB skill-source surface is materialized in the marketplace snapshot" "$FAKE_MARKETPLACE_ROOT/plugins/silver-bullet/skill-source"
assert_not_symlink "Installed SB skill-source surface is materialized in the package root" "$FAKE_SB_PACKAGE_ROOT/skill-source"
assert_not_symlink "Installed SB skill-source surface is materialized in the current cache" "$FAKE_CACHE_ROOT/skill-source"
assert_no_packaged_skill_md "Installed SB package contains no picker-discoverable SKILL.md files" "$FAKE_SB_PACKAGE_ROOT"
assert_no_packaged_skill_md "Current cache contains no picker-discoverable SKILL.md files" "$FAKE_CACHE_ROOT"
assert_no_packaged_markdown_skill_sources "Installed SB package contains no Markdown skill-source files" "$FAKE_SB_PACKAGE_ROOT"
assert_no_packaged_markdown_skill_sources "Current cache contains no Markdown skill-source files" "$FAKE_CACHE_ROOT"
assert_contains "SB Codex plugin manifest declares managed hooks" '"hooks": "./hooks/hooks.json"' "$FAKE_SB_PACKAGE_ROOT/.codex-plugin/plugin.json"
assert_contains "Current cache Codex plugin manifest declares managed hooks" '"hooks": "./hooks/hooks.json"' "$FAKE_CACHE_ROOT/.codex-plugin/plugin.json"
assert_not_contains "SB Codex plugin manifest does not advertise duplicate plugin skills" '"skills": "./skills/"' "$FAKE_SB_PACKAGE_ROOT/.codex-plugin/plugin.json"
assert_not_contains "Current cache Codex plugin manifest does not advertise duplicate plugin skills" '"skills": "./skills/"' "$FAKE_CACHE_ROOT/.codex-plugin/plugin.json"
assert_contains "SB hooks config includes dependency gate" 'dependency-skill-check.sh' "$FAKE_SB_PACKAGE_ROOT/hooks/hooks.json"
assert_contains "SB hooks config includes workflow-chain guard" 'workflow-chain-guard.sh' "$FAKE_SB_PACKAGE_ROOT/hooks/hooks.json"
assert_contains "SB hooks config includes instruction-file guard" 'instruction-file-guard.sh' "$FAKE_SB_PACKAGE_ROOT/hooks/hooks.json"
assert_contains "SB hooks config includes requested-skill recorder" 'record-requested-skill.sh' "$FAKE_SB_PACKAGE_ROOT/hooks/hooks.json"
assert_contains "SB hooks config routes commands through Codex hook adapter" 'codex-hook-adapter.sh' "$FAKE_SB_PACKAGE_ROOT/hooks/hooks.json"
assert_contains "SB hooks config includes exact Bash matcher" '"matcher": "Bash"' "$FAKE_SB_PACKAGE_ROOT/hooks/hooks.json"
assert_contains "SB hooks config includes exact exec_command matcher" '"matcher": "exec_command"' "$FAKE_SB_PACKAGE_ROOT/hooks/hooks.json"
assert_contains "SB hooks config includes native Codex apply_patch matcher coverage" 'apply_patch' "$FAKE_SB_PACKAGE_ROOT/hooks/hooks.json"
assert_hook_command_matchers "SB pretool completion-audit covers Bash and exec_command" "$FAKE_SB_PACKAGE_ROOT/hooks/hooks.json" "PreToolUse" "completion-audit.sh" "Bash" "exec_command"
assert_hook_command_matchers "SB pretool dev-cycle-check covers Bash and exec_command" "$FAKE_SB_PACKAGE_ROOT/hooks/hooks.json" "PreToolUse" "dev-cycle-check.sh" "Bash" "exec_command"
assert_hook_command_matchers "SB pretool ci-status-check covers Bash and exec_command" "$FAKE_SB_PACKAGE_ROOT/hooks/hooks.json" "PreToolUse" "ci-status-check.sh" "Bash" "exec_command"
assert_hook_command_matchers "SB posttool completion-audit covers Bash and exec_command" "$FAKE_SB_PACKAGE_ROOT/hooks/hooks.json" "PostToolUse" "completion-audit.sh" "Bash" "exec_command"
assert_contains "Current cache hooks config includes workflow-chain guard" 'workflow-chain-guard.sh' "$FAKE_CACHE_ROOT/hooks/hooks.json"
assert_contains "Current cache hooks config routes commands through Codex hook adapter" 'codex-hook-adapter.sh' "$FAKE_CACHE_ROOT/hooks/hooks.json"
assert_contains "Current cache hooks config includes exact Bash matcher" '"matcher": "Bash"' "$FAKE_CACHE_ROOT/hooks/hooks.json"
assert_contains "Current cache hooks config includes exact exec_command matcher" '"matcher": "exec_command"' "$FAKE_CACHE_ROOT/hooks/hooks.json"
assert_contains "Current cache hooks config includes native Codex apply_patch matcher coverage" 'apply_patch' "$FAKE_CACHE_ROOT/hooks/hooks.json"
assert_hook_command_matchers "Current cache pretool completion-audit covers Bash and exec_command" "$FAKE_CACHE_ROOT/hooks/hooks.json" "PreToolUse" "completion-audit.sh" "Bash" "exec_command"
assert_hook_command_matchers "Current cache pretool dev-cycle-check covers Bash and exec_command" "$FAKE_CACHE_ROOT/hooks/hooks.json" "PreToolUse" "dev-cycle-check.sh" "Bash" "exec_command"
assert_hook_command_matchers "Current cache pretool ci-status-check covers Bash and exec_command" "$FAKE_CACHE_ROOT/hooks/hooks.json" "PreToolUse" "ci-status-check.sh" "Bash" "exec_command"
assert_hook_command_matchers "Current cache posttool completion-audit covers Bash and exec_command" "$FAKE_CACHE_ROOT/hooks/hooks.json" "PostToolUse" "completion-audit.sh" "Bash" "exec_command"
assert_contains "SB package hooks use the canonical marketplace path" "$FAKE_SB_PACKAGE_ROOT/hooks/session-start" "$FAKE_SB_PACKAGE_ROOT/hooks/hooks.json"
assert_contains "Current cache hooks use the canonical marketplace path" "$FAKE_SB_PACKAGE_ROOT/hooks/session-start" "$FAKE_CACHE_ROOT/hooks/hooks.json"
assert_contains "SB init skill uses sb route" "name: \"sb:init\"" "$(sb_internal_skill "$REPO_ROOT/plugins/silver-bullet" sb-init)"
assert_contains "SB ensure-docs skill uses sb route" "name: \"sb:ensure-docs\"" "$(sb_internal_skill "$REPO_ROOT/plugins/silver-bullet" sb-ensure-docs)"
assert_contains "SB init skill is runtime-aware for Codex" "project instruction file and avoid runtime-specific model-routing jargon" "$(sb_internal_skill "$REPO_ROOT/plugins/silver-bullet" sb-init)"
# shellcheck disable=SC2088 # literal tilde is part of the documented Codex cache glob
assert_contains "SB init skill treats legacy plugins as optional" "no longer probes or reports" "$(sb_internal_skill "$REPO_ROOT/plugins/silver-bullet" sb-init)"
assert_contains "SB init skill recognizes WordPress-style roots" "first-class source roots instead of guessing \`/src/\`" "$(sb_internal_skill "$REPO_ROOT/plugins/silver-bullet" sb-init)"
assert_contains "SB init skill does not fail on flaky legacy GSD" "do not fail bootstrap" "$(sb_internal_skill "$REPO_ROOT/plugins/silver-bullet" sb-init)"
assert_contains "SB ensure-docs skill runs semantic audits" "semantic freshness audits against the current project state" "$(sb_internal_skill "$REPO_ROOT/plugins/silver-bullet" sb-ensure-docs)"
assert_contains "SB ensure-docs skill avoids placeholder doc keys" "using real governed doc keys only" "$(sb_internal_skill "$REPO_ROOT/plugins/silver-bullet" sb-ensure-docs)"
assert_contains "SB feature skill uses sb route" "name: \"sb:feature\"" "$(sb_internal_skill "$REPO_ROOT/plugins/silver-bullet" sb-feature)"
assert_contains "SB router skill uses sb name" "name: sb" "$(sb_internal_skill "$REPO_ROOT/plugins/silver-bullet" sb)"
assert_contains "SB handoff skill uses sb route" "name: \"sb:handoff\"" "$(sb_internal_skill "$REPO_ROOT/plugins/silver-bullet" sb-handoff)"
assert_contains "Review fix ladder keeps canonical skill name in source bundle" "name: \"sb:review-fix-ladder\"" "$(sb_internal_skill "$REPO_ROOT/plugins/silver-bullet" sb-review-fix-ladder)"
assert_contains "Review fix ladder picker title uses SB prefix in source bundle" "title: \"Review Fix Ladder\"" "$(sb_internal_skill "$REPO_ROOT/plugins/silver-bullet" sb-review-fix-ladder)"
assert_contains "TDD skill hidden from picker in source bundle" "user-invocable: false" "$(sb_internal_skill "$REPO_ROOT/plugins/silver-bullet" tdd)"
assert_contains "TDD skill is SB-owned in source bundle" "SB owns this TDD" "$(sb_internal_skill "$REPO_ROOT/plugins/silver-bullet" tdd)"
assert_not_contains "TDD skill does not delegate to Superpowers in source bundle" "superpowers:test-driven-development" "$(sb_internal_skill "$REPO_ROOT/plugins/silver-bullet" tdd)"
assert_contains "SB scan Codex agent bundle uses silver prefix" "name: \"sb:scan\"" "$REPO_ROOT/host-bundles/codex/sb-scan/SKILL.md"
assert_file_absent "SB generated skill package directory absent from source bundle" "$REPO_ROOT/plugins/silver-bullet/.generated-skills"
assert_contains "Installed SB init skill uses sb route" "name: \"sb:init\"" "$(sb_internal_skill "$FAKE_SB_PACKAGE_ROOT" sb-init)"
assert_contains "Installed SB ensure-docs skill uses sb route" "name: \"sb:ensure-docs\"" "$(sb_internal_skill "$FAKE_SB_PACKAGE_ROOT" sb-ensure-docs)"
assert_contains "Installed SB feature skill uses sb route" "name: \"sb:feature\"" "$(sb_internal_skill "$FAKE_SB_PACKAGE_ROOT" sb-feature)"
assert_contains "Installed SB router skill uses sb name" "name: sb" "$(sb_internal_skill "$FAKE_SB_PACKAGE_ROOT" sb)"
assert_file_absent "Installed SB generated skill package directory absent" "$FAKE_CACHE_ROOT/.generated-skills"
assert_file_absent "Installed SB Claude agent bundle absent from cache" "$FAKE_CACHE_ROOT/agents/claude"
assert_file_absent "Installed SB Codex agent bundle absent from cache under agents/" "$FAKE_CACHE_ROOT/agents/codex"
assert_contains "Installed SB feature skill documents FLOW 8 execute boundary" "FLOW 8 (EXECUTE)" "$(sb_internal_skill "$FAKE_SB_PACKAGE_ROOT" sb-feature)"
assert_contains "Installed SB feature skill is atomic queue builder" "queue builder" "$(sb_internal_skill "$FAKE_SB_PACKAGE_ROOT" sb-feature)"
assert_contains "Installed SB UI skill wires TDD into execute boundary" "sb:execute" "$(sb_internal_skill "$FAKE_SB_PACKAGE_ROOT" sb-ui)"
assert_contains "Installed SB bugfix skill documents internal TDD gate" "Internal \`tdd\` gate" "$(sb_internal_skill "$FAKE_SB_PACKAGE_ROOT" sb-bugfix)"
assert_contains "Installed SB bugfix skill executes through SB execute" "sb:execute" "$(sb_internal_skill "$FAKE_SB_PACKAGE_ROOT" sb-bugfix)"
assert_contains "Installed SB bugfix skill documents workflow tracking fallback" "scripts/workflows.sh" "$(sb_internal_skill "$FAKE_SB_PACKAGE_ROOT" sb-bugfix)"
assert_contains "TDD skill hidden from picker in installed package" "user-invocable: false" "$(sb_internal_skill "$FAKE_SB_PACKAGE_ROOT" tdd)"
assert_contains "TDD skill is SB-owned in installed package" "SB owns this TDD" "$(sb_internal_skill "$FAKE_SB_PACKAGE_ROOT" tdd)"
assert_not_contains "TDD skill does not delegate to Superpowers in installed package" "superpowers:test-driven-development" "$(sb_internal_skill "$FAKE_SB_PACKAGE_ROOT" tdd)"

_retired_ns=$'gs'"d"
if find "$FAKE_CACHE_ROOT/.generated-skills" -maxdepth 1 -name "${_retired_ns}-*" 2>/dev/null | grep -q .; then
  FAIL=$((FAIL + 1))
  echo "  FAIL: Legacy retired wrappers still present in installed SB cache"
else
  PASS=$((PASS + 1))
  echo "  ok: Legacy retired wrappers excluded from installed SB cache"
fi

assert_not_contains "Legacy using-silver-bullet trace removed from marketplace changelog" "using-silver-bullet" "$FAKE_MARKETPLACE_ROOT/CHANGELOG.md"
assert_not_contains "Anthropic PM plugin not enabled by default" '[plugins."product-management@alo-labs-codex"]' "$HOME_DIR/.codex/config.toml"
assert_not_contains "Anthropic engineering plugin not enabled by default" '[plugins."engineering@alo-labs-codex"]' "$HOME_DIR/.codex/config.toml"
assert_not_contains "Anthropic design plugin not enabled by default" '[plugins."design@alo-labs-codex"]' "$HOME_DIR/.codex/config.toml"
assert_contains "Codex plugin hooks feature enabled" '[features]' "$HOME_DIR/.codex/config.toml"
assert_contains "Codex plugin hooks feature flag" 'plugin_hooks = true' "$HOME_DIR/.codex/config.toml"
assert_contains "SB hook state recorded inside SB root" 'silver-bullet@' "$HOME_DIR/.codex/config.toml"
HOME_HOOKS_PATH_REAL="$(
  python3 - "$HOME_DIR/.codex/hooks.json" <<'PY'
import pathlib
import sys

print(pathlib.Path(sys.argv[1]).resolve())
PY
)"
assert_hook_trust_state_for_source "Codex package hook trust seeded for managed SB hooks" "$HOME_DIR/.codex/config.toml" "$FAKE_SB_PACKAGE_ROOT/hooks/hooks.json" "silver-bullet@alo-labs-codex:hooks/hooks.json"
assert_not_contains "Native Codex config no longer seeds SB user-hook trust" "$HOME_HOOKS_PATH_REAL" "$HOME_DIR/.codex/config.toml"
assert_file_exists "Codex registry created" "$HOME_DIR/.codex/plugins/installed_plugins.json"
assert_contains "Silver Bullet registry install path refreshed" "$FAKE_SB_INSTALL_ALIAS" "$HOME_DIR/.codex/plugins/installed_plugins.json"
assert_contains "Silver Bullet registry uses user scope" '"scope": "user"' "$HOME_DIR/.codex/plugins/installed_plugins.json"
if python3 - "$HOME_DIR/.codex/plugins/installed_plugins.json" <<'PY' >/dev/null 2>&1
import json
import pathlib
import sys

data = json.loads(pathlib.Path(sys.argv[1]).read_text())
entry = data.get("plugins", {}).get("silver-bullet@alo-labs-codex", [{}])[0]
raise SystemExit(0 if entry.get("scope") == "user" and "projectPath" not in entry else 1)
PY
then
  echo "PASS: Silver Bullet registry avoids home projectPath gate"
  (( PASS++ )) || true
else
  echo "FAIL: Silver Bullet registry avoids home projectPath gate"
  (( FAIL++ )) || true
fi
assert_not_contains "Silver Bullet versioned install path removed" "$FAKE_SB_INSTALL_ROOT" "$HOME_DIR/.codex/plugins/installed_plugins.json"
assert_contains "Sidekick registry install path refreshed" "$FAKE_SIDEKICK_ALIAS" "$HOME_DIR/.codex/plugins/installed_plugins.json"
assert_not_contains "Sidekick stale install path removed" "$FAKE_SIDEKICK_STALE_ROOT" "$HOME_DIR/.codex/plugins/installed_plugins.json"
assert_contains "Engineering registry install path refreshed" "$FAKE_ENGINEERING_ALIAS" "$HOME_DIR/.codex/plugins/installed_plugins.json"
assert_not_contains "Engineering stale install path removed" "$FAKE_ENGINEERING_STALE_ROOT" "$HOME_DIR/.codex/plugins/installed_plugins.json"
assert_file_absent "Engineering helper skill not hydrated from knowledge-work marketplace source by default" "$FAKE_ENGINEERING_ROOT/upstream/skills/documentation/SKILL.md"
assert_contains "Design registry install path refreshed" "$FAKE_DESIGN_ALIAS" "$HOME_DIR/.codex/plugins/installed_plugins.json"
assert_not_contains "Design stale install path removed" "$FAKE_DESIGN_STALE_ROOT" "$HOME_DIR/.codex/plugins/installed_plugins.json"
assert_file_absent "Design helper skill not hydrated from knowledge-work marketplace source by default" "$FAKE_DESIGN_ROOT/upstream/skills/design-system/SKILL.md"
assert_contains "Product-management registry install path refreshed" "$FAKE_PRODUCT_ALIAS" "$HOME_DIR/.codex/plugins/installed_plugins.json"
assert_not_contains "Product-management stale install path removed" "$FAKE_PRODUCT_STALE_ROOT" "$HOME_DIR/.codex/plugins/installed_plugins.json"
assert_file_absent "Product-management helper skill not hydrated from knowledge-work marketplace source by default" "$FAKE_PRODUCT_ROOT/upstream/skills/write-spec/SKILL.md"
assert_not_contains "legacy SB hooks removed from Codex user config" "$legacy_sb_hooks_root" "$HOME_DIR/.codex/hooks.json"
assert_not_contains "legacy SB hooks removed from Codex user config mirror" "$legacy_sb_hooks_root" "$HOME_DIR/.codex/hooks.json"
assert_not_contains "Requested-skill recorder not merged into native Codex user config" 'record-requested-skill.sh' "$HOME_DIR/.codex/hooks.json"
assert_not_contains "Prompt reminder not merged into native Codex user config" 'prompt-reminder.sh' "$HOME_DIR/.codex/hooks.json"
assert_not_contains "Skill recorder not merged into native Codex user config" 'record-skill.sh' "$HOME_DIR/.codex/hooks.json"
assert_not_contains "Instruction guard not merged into native Codex user config" 'instruction-file-guard.sh' "$HOME_DIR/.codex/hooks.json"
assert_not_contains "Workflow-chain guard not merged into native Codex user config" 'workflow-chain-guard.sh' "$HOME_DIR/.codex/hooks.json"
assert_contains "legacy hook preserved in Codex user config" 'legacy-check-update.js' "$HOME_DIR/.codex/hooks.json"
assert_contains "legacy hook preserved in Codex user config mirror" 'legacy-check-update.js' "$HOME_DIR/.codex/hooks.json"
assert_no_combined_tool_matchers "Codex user hooks avoid combined command-tool matchers" "$HOME_DIR/.codex/hooks.json"
RUNTIME_CLAUDE_REPORT="$TMP/codex-runtime-claude-reference-report.txt"
# These shared helpers deliberately contain explicit Claude branches for the
# other supported hosts.  They are host-dispatch code, not Codex runtime paths;
# keep the audit focused on accidental Claude-only paths in the Codex surface.
{
  rg -n -g '!**/.git/**' -g '!**/*.md' -g '!**/*.html' -g '!**/*.txt' -g '!**/*.err' -g '!**/agents/cursor/**' -g '!**/host-bundles/cursor/**' -g '!**/.cursor-plugin/**' -g '!**/scripts/install-leanctx-sb.sh' -g '!**/hooks/lib/recommended-tools.sh' -g '!**/hooks/lib/rtk-gate.sh' -g '!**/hooks/lib/leanctx-gate.sh' '/\\.claude(/|$)' "$FAKE_MARKETPLACE_ROOT" "$FAKE_SB_INSTALL_ROOT" || true
  rg -n -g '!**/.git/**' -g '!**/*.md' -g '!**/*.html' -g '!**/*.txt' -g '!**/*.err' -g '!**/agents/cursor/**' -g '!**/host-bundles/cursor/**' -g '!**/scripts/install-leanctx-sb.sh' -g '!**/hooks/lib/recommended-tools.sh' -g '!**/hooks/lib/rtk-gate.sh' -g '!**/hooks/lib/leanctx-gate.sh' 'os\\.homedir\\(\\).*\\.claude' "$FAKE_MARKETPLACE_ROOT" "$FAKE_SB_INSTALL_ROOT" || true
  rg -n -g '!**/.git/**' -g '!**/*.md' -g '!**/*.html' -g '!**/*.txt' -g '!**/*.err' -g '!**/agents/cursor/**' -g '!**/scripts/install-leanctx-sb.sh' -g '!**/hooks/lib/recommended-tools.sh' -g '!**/hooks/lib/rtk-gate.sh' -g '!**/hooks/lib/leanctx-gate.sh' -F '.claude/' "$FAKE_MARKETPLACE_ROOT" "$FAKE_SB_INSTALL_ROOT" || true
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

DEFAULT_GSD_TMP="$(mktemp -d)"
DEFAULT_GSD_HOME="$DEFAULT_GSD_TMP/home"
DEFAULT_GSD_WORKDIR="$DEFAULT_GSD_TMP/workdir"
mkdir -p "$DEFAULT_GSD_HOME/.codex" "$DEFAULT_GSD_WORKDIR"
(
  cd "$DEFAULT_GSD_WORKDIR"
SB_CODEX_LOCAL_MARKETPLACE_SOURCE="$FAKE_MARKETPLACE_ROOT" \
PATH="$BIN_DIR:$PATH" \
HOME="$DEFAULT_GSD_HOME" \
  bash "$SCRIPT" --purge-legacy-skills >/dev/null
)
assert_file_absent "default install does not fetch GSD" "$DEFAULT_GSD_HOME/.codex/get-shit-done/VERSION"

NON_SB_HOME="$TMP/no-sb-home"
NON_SB_WORKDIR="$TMP/non-sb-workdir"
mkdir -p "$NON_SB_HOME/.codex" "$NON_SB_WORKDIR"
(
  cd "$NON_SB_WORKDIR"
SB_CODEX_LOCAL_MARKETPLACE_SOURCE="$FAKE_MARKETPLACE_ROOT" \
PATH="$BIN_DIR:$PATH" \
HOME="$NON_SB_HOME" \
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
SB_CODEX_LEGACY_MARKETPLACE_SNAPSHOT=1 \
SB_CODEX_LOCAL_MARKETPLACE_SOURCE="$SEED_HOME/.codex/.tmp/marketplaces/alo-labs-codex" \
PATH="$BIN_DIR:$PATH" \
HOME="$SEED_HOME" \
  bash "$SCRIPT" --purge-legacy-skills >/dev/null
assert_file_exists "Codex marketplace snapshot seeded when legacy snapshot enabled" "$SEED_HOME/.codex/.tmp/marketplaces/alo-labs-codex/plugins/silver-bullet/.codex-plugin/plugin.json"

PUBLIC_STALE_TMP="$(mktemp -d)"
PUBLIC_STALE_HOME="$PUBLIC_STALE_TMP/home"
PUBLIC_STALE_WORKDIR="$PUBLIC_STALE_TMP/workdir"
PUBLIC_STALE_MARKETPLACE="$PUBLIC_STALE_HOME/.codex/.tmp/marketplaces/alo-labs-codex"
PUBLIC_STALE_SB_SOURCE="$PUBLIC_STALE_TMP/sb-source"
PUBLIC_STALE_SB_REMOTE="$PUBLIC_STALE_TMP/sb-source.git"
PUBLIC_STALE_MARKETPLACE_REMOTE="$PUBLIC_STALE_TMP/remote.git"
mkdir -p \
  "$PUBLIC_STALE_HOME/.codex" \
  "$PUBLIC_STALE_HOME/.codex/skills/writing-plans" \
  "$PUBLIC_STALE_WORKDIR" \
  "$PUBLIC_STALE_SB_SOURCE/plugins/silver-bullet" \
  "$PUBLIC_STALE_MARKETPLACE/.agents/plugins"
cat > "$PUBLIC_STALE_HOME/.codex/skills/writing-plans/SKILL.md" <<'EOF'
---
name: writing-plans
---
EOF
cat > "$PUBLIC_STALE_HOME/.codex/skills/writing-plans/.silver-bullet-managed" <<'EOF'
source=Silver Bullet
EOF
rsync -aL --delete "$REPO_ROOT/plugins/silver-bullet/" "$PUBLIC_STALE_SB_SOURCE/plugins/silver-bullet/"
git -C "$PUBLIC_STALE_SB_SOURCE" init -q
git -C "$PUBLIC_STALE_SB_SOURCE" config user.email "tests@example.invalid"
git -C "$PUBLIC_STALE_SB_SOURCE" config user.name "Tests"
git -C "$PUBLIC_STALE_SB_SOURCE" add .
git -C "$PUBLIC_STALE_SB_SOURCE" commit -q -m "seed sb source"
git -C "$PUBLIC_STALE_SB_SOURCE" branch -M main
git -C "$PUBLIC_STALE_TMP" init --bare -q "$PUBLIC_STALE_SB_REMOTE"
git -C "$PUBLIC_STALE_SB_SOURCE" remote add origin "$PUBLIC_STALE_SB_REMOTE"
git -C "$PUBLIC_STALE_SB_SOURCE" push -q -u origin HEAD:main
package_v="$(jq -r '.version' "$PUBLIC_STALE_SB_SOURCE/plugins/silver-bullet/.codex-plugin/plugin.json")"
jq -n \
  --arg v "$package_v" \
  --arg url "file://$PUBLIC_STALE_SB_REMOTE" \
  '{
    name: "alo-labs-codex",
    plugins: [{
      name: "silver-bullet",
      source: {source: "url", url: $url, ref: "main", path: "plugins/silver-bullet"},
      version: $v,
      policy: {installation: "AVAILABLE"}
    }]
  }' > "$PUBLIC_STALE_MARKETPLACE/.agents/plugins/marketplace.json"
git -C "$PUBLIC_STALE_MARKETPLACE" init -q
git -C "$PUBLIC_STALE_MARKETPLACE" config user.email "tests@example.invalid"
git -C "$PUBLIC_STALE_MARKETPLACE" config user.name "Tests"
git -C "$PUBLIC_STALE_MARKETPLACE" add .
git -C "$PUBLIC_STALE_MARKETPLACE" commit -q -m "seed thin public marketplace"
git -C "$PUBLIC_STALE_MARKETPLACE" branch -M main
git -C "$PUBLIC_STALE_TMP" init --bare -q "$PUBLIC_STALE_MARKETPLACE_REMOTE"
git -C "$PUBLIC_STALE_MARKETPLACE" remote add origin "$PUBLIC_STALE_MARKETPLACE_REMOTE"
git -C "$PUBLIC_STALE_MARKETPLACE" push -q -u origin HEAD:main
(
  cd "$PUBLIC_STALE_WORKDIR"
  PATH="$BIN_DIR:$PATH" \
  HOME="$PUBLIC_STALE_HOME" \
  CODEX_MARKETPLACE_SOURCE="file://$PUBLIC_STALE_MARKETPLACE_REMOTE" \
    bash "$SCRIPT" --public-release >/dev/null
)
PUBLIC_STALE_CACHE="$PUBLIC_STALE_HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet/$package_v"
PUBLIC_STALE_ALIAS="$PUBLIC_STALE_HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet/current"
assert_file_absent "public-release cache removes plugin picker skills directory" "$PUBLIC_STALE_CACHE/skills"
assert_file_exists "public-release cache keeps Silver Bullet feature skill source" "$(sb_internal_skill "$PUBLIC_STALE_CACHE" sb-feature)"
assert_no_packaged_skill_md "public-release cache contains no picker-discoverable SKILL.md files" "$PUBLIC_STALE_CACHE"
assert_command_succeeds "public-release cache alias created" test -L "$PUBLIC_STALE_ALIAS"
assert_file_absent "public-release cache alias does not expose plugin picker skills surface" "$PUBLIC_STALE_ALIAS/skills"
assert_file_exists "public-release cache alias exposes internal feature skill source" "$(sb_internal_skill "$PUBLIC_STALE_ALIAS" sb-feature)"
assert_file_exists "public-release cache alias exposes internal review fix ladder skill source" "$(sb_internal_skill "$PUBLIC_STALE_ALIAS" sb-review-fix-ladder)"
assert_file_exists "public-release cache alias exposes hidden modularity dimension source" "$(sb_internal_skill "$PUBLIC_STALE_ALIAS" modularity)"
assert_file_exists "public-release cache alias exposes hidden testability dimension source" "$(sb_internal_skill "$PUBLIC_STALE_ALIAS" testability)"
assert_no_packaged_skill_md "public-release cache alias contains no picker-discoverable SKILL.md files" "$PUBLIC_STALE_ALIAS"
assert_file_exists "public-release native SB mirror exposes Silver Bullet feature skill" "$PUBLIC_STALE_HOME/.codex/skills/sb:feature/SKILL.md"
assert_file_exists "public-release native SB mirror exposes review fix ladder helper" "$PUBLIC_STALE_HOME/.codex/skills/sb-review-fix-ladder/SKILL.md"
assert_contains "public-release review fix ladder uses SB picker prefix" "title: \"Review Fix Ladder\"" "$PUBLIC_STALE_HOME/.codex/skills/sb-review-fix-ladder/SKILL.md"
assert_file_exists "public-release native SB mirror exposes verify-tests gate" "$PUBLIC_STALE_HOME/.codex/skills/verify-tests/SKILL.md"
assert_contains "public-release verify-tests gate uses SB picker prefix" "title: \"SB: Verify Tests\"" "$PUBLIC_STALE_HOME/.codex/skills/verify-tests/SKILL.md"
assert_file_exists "public-release native SB mirror exposes security gate" "$PUBLIC_STALE_HOME/.codex/skills/security/SKILL.md"
assert_contains "public-release security gate uses SB picker prefix" "title: \"SB: Security\"" "$PUBLIC_STALE_HOME/.codex/skills/security/SKILL.md"
assert_file_exists "public-release native SB mirror exposes DevOps quality gate" "$PUBLIC_STALE_HOME/.codex/skills/devops-quality-gates/SKILL.md"
assert_contains "public-release DevOps quality gate uses SB picker prefix" "title: \"SB: DevOps Quality Gates\"" "$PUBLIC_STALE_HOME/.codex/skills/devops-quality-gates/SKILL.md"
assert_file_absent "public-release native SB mirror excludes hidden modularity dimension helper" "$PUBLIC_STALE_HOME/.codex/skills/modularity/SKILL.md"
assert_file_absent "public-release native SB mirror excludes hidden testability dimension helper" "$PUBLIC_STALE_HOME/.codex/skills/testability/SKILL.md"
assert_file_absent "public-release native SB mirror excludes stale delegate skill" "$PUBLIC_STALE_HOME/.codex/skills/stale-delegate"
assert_file_absent "public-release native SB mirror prunes stale managed writing-plans skill" "$PUBLIC_STALE_HOME/.codex/skills/writing-plans"
assert_file_absent "public-release ignores stale marketplace delegate skill" "$PUBLIC_STALE_CACHE/skills/stale-delegate/SKILL.md"
assert_file_absent "public-release ignores stale marketplace writing-plans skill" "$PUBLIC_STALE_CACHE/skills/writing-plans/SKILL.md"
assert_file_absent "thin public marketplace does not vendor plugins/silver-bullet" "$PUBLIC_STALE_MARKETPLACE/plugins/silver-bullet"

BROKEN_PUBLIC_TMP="$(mktemp -d)"
BROKEN_PUBLIC_HOME="$BROKEN_PUBLIC_TMP/home"
BROKEN_PUBLIC_WORKDIR="$BROKEN_PUBLIC_TMP/workdir"
BROKEN_PUBLIC_MARKETPLACE="$BROKEN_PUBLIC_HOME/.codex/.tmp/marketplaces/alo-labs-codex"
BROKEN_PUBLIC_SB_SOURCE="$BROKEN_PUBLIC_TMP/sb-source"
BROKEN_PUBLIC_SB_REMOTE="$BROKEN_PUBLIC_TMP/sb-source.git"
BROKEN_PUBLIC_MARKETPLACE_REMOTE="$BROKEN_PUBLIC_TMP/marketplace.git"
BROKEN_PUBLIC_OUTPUT="$BROKEN_PUBLIC_TMP/install.out"
mkdir -p \
  "$BROKEN_PUBLIC_HOME/.codex" \
  "$BROKEN_PUBLIC_WORKDIR" \
  "$BROKEN_PUBLIC_SB_SOURCE/plugins/silver-bullet/.codex-plugin" \
  "$BROKEN_PUBLIC_SB_SOURCE/plugins/silver-bullet/commands" \
  "$BROKEN_PUBLIC_MARKETPLACE/.agents/plugins"
cat > "$BROKEN_PUBLIC_SB_SOURCE/plugins/silver-bullet/.codex-plugin/plugin.json" <<'EOF'
{
  "name": "silver-bullet",
  "version": "0.37.4",
  "commands": "./commands/"
}
EOF
cat > "$BROKEN_PUBLIC_SB_SOURCE/plugins/silver-bullet/commands/sb:init.md" <<'EOF'
# init
EOF
git -C "$BROKEN_PUBLIC_SB_SOURCE" init -q
git -C "$BROKEN_PUBLIC_SB_SOURCE" config user.email "tests@example.invalid"
git -C "$BROKEN_PUBLIC_SB_SOURCE" config user.name "Tests"
git -C "$BROKEN_PUBLIC_SB_SOURCE" add .
git -C "$BROKEN_PUBLIC_SB_SOURCE" commit -q -m "broken sb source"
git -C "$BROKEN_PUBLIC_SB_SOURCE" branch -M main
git -C "$BROKEN_PUBLIC_TMP" init --bare -q "$BROKEN_PUBLIC_SB_REMOTE"
git -C "$BROKEN_PUBLIC_SB_SOURCE" remote add origin "$BROKEN_PUBLIC_SB_REMOTE"
git -C "$BROKEN_PUBLIC_SB_SOURCE" push -q -u origin HEAD:main
jq -n \
  --arg url "file://$BROKEN_PUBLIC_SB_REMOTE" \
  '{
    name: "alo-labs-codex",
    plugins: [{
      name: "silver-bullet",
      source: {source: "url", url: $url, ref: "main", path: "plugins/silver-bullet"},
      version: "0.37.4",
      policy: {installation: "AVAILABLE"}
    }]
  }' > "$BROKEN_PUBLIC_MARKETPLACE/.agents/plugins/marketplace.json"
git -C "$BROKEN_PUBLIC_MARKETPLACE" init -q
git -C "$BROKEN_PUBLIC_MARKETPLACE" config user.email "tests@example.invalid"
git -C "$BROKEN_PUBLIC_MARKETPLACE" config user.name "Tests"
git -C "$BROKEN_PUBLIC_MARKETPLACE" add .
git -C "$BROKEN_PUBLIC_MARKETPLACE" commit -q -m "broken thin marketplace"
git -C "$BROKEN_PUBLIC_MARKETPLACE" branch -M main
git -C "$BROKEN_PUBLIC_TMP" init --bare -q "$BROKEN_PUBLIC_MARKETPLACE_REMOTE"
git -C "$BROKEN_PUBLIC_MARKETPLACE" remote add origin "$BROKEN_PUBLIC_MARKETPLACE_REMOTE"
git -C "$BROKEN_PUBLIC_MARKETPLACE" push -q -u origin HEAD:main
set +e
(
  cd "$BROKEN_PUBLIC_WORKDIR"
  PATH="$BIN_DIR:$PATH" \
  HOME="$BROKEN_PUBLIC_HOME" \
  CODEX_MARKETPLACE_SOURCE="file://$BROKEN_PUBLIC_MARKETPLACE_REMOTE" \
    bash "$SCRIPT" --public-release >"$BROKEN_PUBLIC_OUTPUT" 2>&1
)
broken_public_status=$?
set -e
assert_command_fails "public-release install fails fast when SB package skills are missing" test "$broken_public_status" -eq 0
assert_contains "public-release failure explains missing SB skill source surface" "ERROR: Silver Bullet installed package is missing internal skill-source/" "$BROKEN_PUBLIC_OUTPUT"

echo
echo "Results: $PASS passed, $FAIL failed, $SKIP skipped"
[[ $FAIL -eq 0 ]]
