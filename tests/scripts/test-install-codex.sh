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

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/install-codex.sh"
HOME_DIR="$TMP/home"
BIN_DIR="$TMP/bin"
LOG_DIR="$TMP/log"
mkdir -p "$HOME_DIR/.Codex" "$HOME_DIR/.agents/skills/silver-feature" "$HOME_DIR/.agents/skills/using-silver-bullet" "$HOME_DIR/.agents/skills/unrelated-skill" "$BIN_DIR" "$LOG_DIR"
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

cat > "$HOME_DIR/.Codex/config.toml" <<EOF
[marketplaces.silver-bullet-local]
source = "/tmp/old-silver-bullet"
EOF

cat > "$BIN_DIR/codex" <<EOF
#!/usr/bin/env bash
printf '%s\n' "codex \$*" >> "$LOG_DIR/codex.log"
exit 0
EOF
chmod +x "$BIN_DIR/codex"

cat > "$BIN_DIR/npx" <<EOF
#!/usr/bin/env bash
printf '%s\n' "npx \$*" >> "$LOG_DIR/npx.log"
exit 0
EOF
chmod +x "$BIN_DIR/npx"

PATH="$BIN_DIR:$PATH" \
HOME="$HOME_DIR" \
GSD_INSTALL_CMD="$BIN_DIR/install-gsd" \
  bash "$SCRIPT" --purge-legacy-skills >/dev/null

assert_file_exists "GSD installer created VERSION file" "$HOME_DIR/.claude/get-shit-done/VERSION"
assert_contains "codex removed legacy marketplace" "codex plugin marketplace remove silver-bullet-local" "$LOG_DIR/codex.log"
assert_contains "codex registered shared marketplace" "codex plugin marketplace add https://github.com/alo-labs/codex-plugins" "$LOG_DIR/codex.log"
assert_contains "codex upgraded shared marketplace" "codex plugin marketplace upgrade alo-labs-codex" "$LOG_DIR/codex.log"
assert_contains "codex registered superpowers marketplace" "codex plugin marketplace add https://github.com/obra/superpowers-marketplace.git" "$LOG_DIR/codex.log"
assert_file_absent "legacy SB skill removed" "$HOME_DIR/.agents/skills/silver-feature"
assert_file_absent "legacy using-silver-bullet skill removed" "$HOME_DIR/.agents/skills/using-silver-bullet"
assert_file_exists "unrelated skill preserved" "$HOME_DIR/.agents/skills/unrelated-skill/SKILL.md"
assert_contains "SB hooks plugin enabled" '[plugins."silver-bullet@alo-labs-codex"]' "$HOME_DIR/.Codex/config.toml"
if grep -qF '[plugins."silver@alo-labs-codex"]' "$HOME_DIR/.Codex/config.toml"; then
  echo "FAIL: SB commands should be bundled into the Silver Bullet plugin, not installed separately"
  (( FAIL++ )) || true
else
  echo "PASS: Silver Bullet commands are bundled into the main SB plugin"
  (( PASS++ )) || true
fi
assert_file_exists "SB init command surface synced into source bundle" "$REPO_ROOT/plugins/silver-bullet/commands/init.md"
assert_file_exists "SB command surface synced into source bundle" "$REPO_ROOT/plugins/silver-bullet/commands/feature.md"
assert_file_exists "SB router command surface synced into source bundle" "$REPO_ROOT/plugins/silver-bullet/commands/silver.md"
assert_contains "SB init command uses silver prefix" "name: silver:init" "$REPO_ROOT/plugins/silver-bullet/commands/init.md"
assert_contains "SB feature command uses silver prefix" "name: silver:feature" "$REPO_ROOT/plugins/silver-bullet/commands/feature.md"
assert_contains "SB router command uses silver name" "name: silver" "$REPO_ROOT/plugins/silver-bullet/commands/silver.md"
assert_contains "Anthropic PM plugin enabled" '[plugins."product-management@alo-labs-codex"]' "$HOME_DIR/.Codex/config.toml"
assert_contains "Anthropic engineering plugin enabled" '[plugins."engineering@alo-labs-codex"]' "$HOME_DIR/.Codex/config.toml"
assert_contains "Anthropic design plugin enabled" '[plugins."design@alo-labs-codex"]' "$HOME_DIR/.Codex/config.toml"
assert_contains "Codex plugin hooks feature enabled" '[features]' "$HOME_DIR/.Codex/config.toml"
assert_contains "Codex plugin hooks feature flag" 'plugin_hooks = true' "$HOME_DIR/.Codex/config.toml"

echo
echo "Results: $PASS passed, $FAIL failed, $SKIP skipped"
[[ $FAIL -eq 0 ]]
