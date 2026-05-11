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

assert_contains() {
  local desc="$1" needle="$2" file="$3"
  if grep -qF "$needle" "$file"; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — missing [$needle] in $file"
    (( FAIL++ )) || true
  fi
}

assert_not_contains() {
  local desc="$1" needle="$2" file="$3"
  if ! grep -qF "$needle" "$file"; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — unexpected [$needle] in $file"
    (( FAIL++ )) || true
  fi
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/install-codex.sh"
HOME_DIR="$TMP/home"
BIN_DIR="$TMP/bin"
mkdir -p "$HOME_DIR/.Codex" "$HOME_DIR/.agents/skills/silver-feature" "$HOME_DIR/.agents/skills/using-silver-bullet" "$HOME_DIR/.agents/skills/unrelated-skill" "$BIN_DIR"
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
mkdir -p "$HOME/.claude/get-shit-done"
printf '9.9.9' > "$HOME/.claude/get-shit-done/VERSION"
EOF
chmod +x "$BIN_DIR/install-gsd"

cat > "$BIN_DIR/npx" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exec "$@"
EOF
chmod +x "$BIN_DIR/npx"

cat > "$HOME_DIR/.Codex/config.toml" <<EOF
[marketplaces.silver-bullet-local]
source = "/tmp/old-silver-bullet"
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

FAKE_MARKETPLACE_ROOT="$HOME_DIR/.Codex/.tmp/marketplaces/alo-labs-codex"
FAKE_SB_PACKAGE_ROOT="$FAKE_MARKETPLACE_ROOT/plugins/silver-bullet"
FAKE_SB_SKILLS_SOURCE="$FAKE_MARKETPLACE_ROOT/skills"
FAKE_CACHE_ROOT="$HOME_DIR/.codex/plugins/cache/alo-labs-codex/silver-bullet/0.32.3"
FAKE_HOOKS_FIXTURE="$TMP/hooks-async.json"
make_async_hooks_fixture "$REPO_ROOT/hooks/hooks.json" "$FAKE_HOOKS_FIXTURE"
mkdir -p \
  "$FAKE_SB_PACKAGE_ROOT/.codex-plugin" \
  "$FAKE_MARKETPLACE_ROOT/hooks" \
  "$FAKE_SB_SKILLS_SOURCE/silver-init" \
  "$FAKE_SB_SKILLS_SOURCE/silver-ensure-docs" \
  "$FAKE_SB_SKILLS_SOURCE/silver-feature" \
  "$FAKE_SB_SKILLS_SOURCE/silver" \
  "$FAKE_CACHE_ROOT/hooks"
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

cat > "$FAKE_MARKETPLACE_ROOT/CHANGELOG.md" <<'EOF'
- Renamed /using-silver-bullet skill to /silver:init
- Kept other release notes intact
EOF

cd "$REPO_ROOT"
PATH="$BIN_DIR:$PATH" \
HOME="$HOME_DIR" \
GSD_INSTALL_CMD="$BIN_DIR/install-gsd" \
  bash "$SCRIPT" --purge-legacy-skills >/dev/null

assert_file_exists "GSD installer created VERSION file" "$HOME_DIR/.claude/get-shit-done/VERSION"
assert_not_contains "legacy marketplace removed from config" "[marketplaces.silver-bullet-local]" "$HOME_DIR/.Codex/config.toml"
assert_contains "shared marketplace registered in config" "[marketplaces.alo-labs-codex]" "$HOME_DIR/.Codex/config.toml"
assert_contains "shared marketplace source preserved" 'source = "https://github.com/alo-labs/codex-plugins"' "$HOME_DIR/.Codex/config.toml"
assert_contains "superpowers marketplace registered in config" "[marketplaces.superpowers-marketplace]" "$HOME_DIR/.Codex/config.toml"
assert_contains "superpowers marketplace source preserved" 'source = "https://github.com/obra/superpowers-marketplace.git"' "$HOME_DIR/.Codex/config.toml"
assert_file_absent "legacy SB skill removed" "$HOME_DIR/.agents/skills/silver-feature"
assert_file_absent "legacy using-silver-bullet skill removed" "$HOME_DIR/.agents/skills/using-silver-bullet"
assert_file_exists "unrelated skill preserved" "$HOME_DIR/.agents/skills/unrelated-skill/SKILL.md"
assert_contains "SB hooks plugin enabled" '[plugins."silver-bullet@alo-labs-codex"]' "$HOME_DIR/.Codex/config.toml"
if grep -qF '[plugins."silver@alo-labs-codex"]' "$HOME_DIR/.Codex/config.toml"; then
  echo "FAIL: SB skills should be bundled into the Silver Bullet plugin, not installed separately"
  (( FAIL++ )) || true
else
  echo "PASS: Silver Bullet skills are bundled into the main SB plugin"
  (( PASS++ )) || true
fi
assert_file_exists "Marketplace root hooks config materialized" "$FAKE_MARKETPLACE_ROOT/hooks/hooks.json"
assert_no_async_true "Marketplace root hooks config normalized for Codex package" "$FAKE_MARKETPLACE_ROOT/hooks/hooks.json"
assert_not_symlink "SB hooks directory materialized" "$FAKE_SB_PACKAGE_ROOT/hooks"
assert_file_exists "SB hooks config materialized" "$FAKE_SB_PACKAGE_ROOT/hooks/hooks.json"
assert_not_symlink "SB skills directory materialized" "$FAKE_SB_PACKAGE_ROOT/skills"
assert_no_async_true "SB hooks config normalized for Codex package" "$FAKE_SB_PACKAGE_ROOT/hooks/hooks.json"
assert_no_async_true "Current cache hooks config normalized for Codex package" "$FAKE_CACHE_ROOT/hooks/hooks.json"
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
assert_contains "SB init skill uses silver prefix" "name: silver:init" "$REPO_ROOT/plugins/silver-bullet/skills/silver-init/SKILL.md"
assert_contains "SB ensure-docs skill uses silver prefix" "name: silver:ensure-docs" "$REPO_ROOT/plugins/silver-bullet/skills/silver-ensure-docs/SKILL.md"
assert_contains "SB feature skill uses silver prefix" "name: silver:feature" "$REPO_ROOT/plugins/silver-bullet/skills/silver-feature/SKILL.md"
assert_contains "SB router skill uses silver name" "name: silver" "$REPO_ROOT/plugins/silver-bullet/skills/silver/SKILL.md"
assert_contains "SB handoff skill uses silver prefix" "name: silver:handoff" "$REPO_ROOT/plugins/silver-bullet/skills/silver-handoff/SKILL.md"
assert_contains "SB init generated skill uses no-new-CLAUDE contract" "without creating one" "$REPO_ROOT/plugins/silver-bullet/.generated-skills/silver-init/SKILL.md"
assert_not_contains "SB init generated skill no longer promises fresh CLAUDE.md creation" "scaffolds silver-bullet.md + CLAUDE.md + config + workflow files" "$REPO_ROOT/plugins/silver-bullet/.generated-skills/silver-init/SKILL.md"
assert_contains "Installed SB init skill uses silver prefix" "name: silver:init" "$FAKE_SB_PACKAGE_ROOT/skills/silver-init/SKILL.md"
assert_contains "Installed SB ensure-docs skill uses silver prefix" "name: silver:ensure-docs" "$FAKE_SB_PACKAGE_ROOT/skills/silver-ensure-docs/SKILL.md"
assert_contains "Installed SB feature skill uses silver prefix" "name: silver:feature" "$FAKE_SB_PACKAGE_ROOT/skills/silver-feature/SKILL.md"
assert_contains "Installed SB router skill uses silver name" "name: silver" "$FAKE_SB_PACKAGE_ROOT/skills/silver/SKILL.md"
assert_contains "Installed SB init generated skill mirrors no-new-CLAUDE contract" "without creating one" "$FAKE_CACHE_ROOT/.generated-skills/silver-init/SKILL.md"
assert_not_contains "Installed SB init generated skill no longer promises fresh CLAUDE.md creation" "scaffolds silver-bullet.md + CLAUDE.md + config + workflow files" "$FAKE_CACHE_ROOT/.generated-skills/silver-init/SKILL.md"
assert_not_contains "Legacy using-silver-bullet trace removed from marketplace changelog" "using-silver-bullet" "$FAKE_MARKETPLACE_ROOT/CHANGELOG.md"
assert_contains "Anthropic PM plugin enabled" '[plugins."product-management@alo-labs-codex"]' "$HOME_DIR/.Codex/config.toml"
assert_contains "Anthropic engineering plugin enabled" '[plugins."engineering@alo-labs-codex"]' "$HOME_DIR/.Codex/config.toml"
assert_contains "Anthropic design plugin enabled" '[plugins."design@alo-labs-codex"]' "$HOME_DIR/.Codex/config.toml"
assert_contains "Codex plugin hooks feature enabled" '[features]' "$HOME_DIR/.Codex/config.toml"
assert_contains "Codex plugin hooks feature flag" 'plugin_hooks = true' "$HOME_DIR/.Codex/config.toml"
assert_contains "SB hook state recorded inside SB root" 'silver-bullet@' "$HOME_DIR/.Codex/config.toml"
assert_not_contains "legacy SB hooks removed from Codex user config" "$legacy_sb_hooks_root" "$HOME_DIR/.codex/hooks.json"
assert_not_contains "legacy SB hooks removed from Codex user config mirror" "$legacy_sb_hooks_root" "$HOME_DIR/.Codex/hooks.json"
assert_contains "Requested-skill recorder merged into Codex user config" 'record-requested-skill.sh' "$HOME_DIR/.codex/hooks.json"
assert_contains "Requested-skill recorder merged into Codex user config mirror" 'record-requested-skill.sh' "$HOME_DIR/.Codex/hooks.json"
assert_contains "Skill recorder merged into Codex user config" 'record-skill.sh' "$HOME_DIR/.codex/hooks.json"
assert_contains "Skill recorder merged into Codex user config mirror" 'record-skill.sh' "$HOME_DIR/.Codex/hooks.json"
assert_contains "Instruction guard merged into Codex user config" 'instruction-file-guard.sh' "$HOME_DIR/.codex/hooks.json"
assert_contains "Instruction guard merged into Codex user config mirror" 'instruction-file-guard.sh' "$HOME_DIR/.Codex/hooks.json"
assert_contains "GSD hook preserved in Codex user config" 'gsd-check-update.js' "$HOME_DIR/.codex/hooks.json"
assert_contains "GSD hook preserved in Codex user config mirror" 'gsd-check-update.js' "$HOME_DIR/.Codex/hooks.json"

NON_SB_HOME="$TMP/no-sb-home"
NON_SB_WORKDIR="$TMP/non-sb-workdir"
mkdir -p "$NON_SB_HOME/.Codex" "$NON_SB_WORKDIR"
(
  cd "$NON_SB_WORKDIR"
  PATH="$BIN_DIR:$PATH" \
  HOME="$NON_SB_HOME" \
  GSD_INSTALL_CMD="$BIN_DIR/install-gsd" \
    bash "$SCRIPT" --purge-legacy-skills >/dev/null
)

assert_contains "shared marketplace still registered outside SB root" "[marketplaces.alo-labs-codex]" "$NON_SB_HOME/.Codex/config.toml"
assert_not_contains "SB plugin not auto-enabled outside SB root" "[plugins.\"silver-bullet@alo-labs-codex\"]" "$NON_SB_HOME/.Codex/config.toml"
assert_not_contains "SB hook state not installed outside SB root" 'silver-bullet@' "$NON_SB_HOME/.Codex/config.toml"

SEED_TMP="$(mktemp -d)"
SEED_HOME="$SEED_TMP/home"
mkdir -p "$SEED_HOME/.Codex"
cat > "$SEED_HOME/.Codex/config.toml" <<'EOF'
[features]
plugin_hooks = true
EOF
PATH="$BIN_DIR:$PATH" \
HOME="$SEED_HOME" \
GSD_INSTALL_CMD="$BIN_DIR/install-gsd" \
  bash "$SCRIPT" --purge-legacy-skills >/dev/null
assert_file_exists "Codex marketplace snapshot seeded when missing" "$SEED_HOME/.Codex/.tmp/marketplaces/alo-labs-codex/plugins/silver-bullet/.codex-plugin/plugin.json"

echo
echo "Results: $PASS passed, $FAIL failed, $SKIP skipped"
[[ $FAIL -eq 0 ]]
