#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

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
  if [[ ! -e "$path" && ! -L "$path" ]]; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — should be absent: $path"
    (( FAIL++ )) || true
  fi
}

assert_not_symlink() {
  local desc="$1" path="$2"
  if [[ -e "$path" && ! -L "$path" ]]; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — expected real path: $path"
    (( FAIL++ )) || true
  fi
}

assert_equal() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — expected $expected, got $actual"
    (( FAIL++ )) || true
  fi
}

assert_not_contains() {
  local desc="$1" needle="$2" path="$3"
  if rg -n --hidden -S -- "$needle" "$path" >/dev/null 2>&1; then
    echo "FAIL: $desc — found [$needle] under $path"
    (( FAIL++ )) || true
  else
    echo "PASS: $desc"
    (( PASS++ )) || true
  fi
}

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/sync-codex-marketplace-version.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

MARKETPLACE="$TMP/marketplace"
REMOTE="$TMP/remote.git"
mkdir -p "$MARKETPLACE/plugins/silver-bullet/.codex-plugin" "$MARKETPLACE/skill-source/silver-init"

cat > "$MARKETPLACE/plugins/silver-bullet/.codex-plugin/plugin.json" <<'EOF'
{
  "name": "silver-bullet",
  "version": "0.0.1",
  "commands": "./commands/"
}
EOF
cat > "$MARKETPLACE/skill-source/silver-init/SILVER_SOURCE" <<'EOF'
---
name: stale-silver-init
---
EOF
ln -s ../../skill-source "$MARKETPLACE/plugins/silver-bullet/skill-source"

git -C "$MARKETPLACE" init -q
git -C "$MARKETPLACE" config user.email "tests@example.invalid"
git -C "$MARKETPLACE" config user.name "Tests"
git -C "$MARKETPLACE" add .
git -C "$MARKETPLACE" commit -q -m "seed stale marketplace"
git -C "$MARKETPLACE" branch -M local-release
git -C "$TMP" init --bare -q "$REMOTE"
git -C "$MARKETPLACE" remote add origin "$REMOTE"
git -C "$MARKETPLACE" push -q -u origin HEAD:main

bash "$REPO_ROOT/scripts/sync-codex-package.sh" >/dev/null
source_count="$(find "$REPO_ROOT/plugins/silver-bullet/skill-source" -maxdepth 2 -name SILVER_SOURCE | wc -l | tr -d ' ')"

CODEX_MARKETPLACE_REPO_ROOT="$MARKETPLACE" bash "$SCRIPT" >/dev/null

marketplace_count="$(find "$MARKETPLACE/plugins/silver-bullet/skill-source" -maxdepth 2 -name SILVER_SOURCE | wc -l | tr -d ' ')"

assert_file_absent "marketplace plugin does not expose picker skills directory" "$MARKETPLACE/plugins/silver-bullet/skills"
assert_file_absent "marketplace plugin does not expose picker-discoverable internal skill files" "$(find "$MARKETPLACE/plugins/silver-bullet" -name '*SKILL.md' -print -quit)"
assert_not_symlink "marketplace plugin skill-source surface is materialized" "$MARKETPLACE/plugins/silver-bullet/skill-source"
assert_file_exists "marketplace plugin includes Silver Bullet init skill source" "$MARKETPLACE/plugins/silver-bullet/skill-source/silver-init/SILVER_SOURCE"
assert_file_exists "marketplace plugin includes Silver Bullet feature skill source" "$MARKETPLACE/plugins/silver-bullet/skill-source/silver-feature/SILVER_SOURCE"
assert_file_absent "marketplace plugin does not expose Markdown skill source files" "$(find "$MARKETPLACE/plugins/silver-bullet/skill-source" -type f -name 'SILVER_SOURCE.md' -print -quit)"
assert_equal "marketplace plugin skill count matches source package" "$source_count" "$marketplace_count"
assert_file_absent "marketplace plugin does not expose generated picker skills directory" "$MARKETPLACE/plugins/silver-bullet/.generated-skills"
assert_file_absent "marketplace plugin does not expose agent SKILL.md bundle" "$MARKETPLACE/plugins/silver-bullet/agents"
assert_not_contains "marketplace plugin avoids Claude-only Skill tool wording" "via the Skill tool" "$MARKETPLACE/plugins/silver-bullet"
assert_not_contains "marketplace plugin avoids duplicate skill tracker wording" "PostToolUse/Skill or Codex invoke-skill receipt or Codex" "$MARKETPLACE/plugins/silver-bullet"
assert_not_contains "marketplace plugin avoids Claude-only Agent tool wording" "Agent tool" "$MARKETPLACE/plugins/silver-bullet"
assert_not_contains "marketplace plugin avoids Claude-only Read tool wording" "Read tool" "$MARKETPLACE/plugins/silver-bullet"
assert_not_contains "marketplace plugin avoids Claude-only Write tool wording" "Write tool" "$MARKETPLACE/plugins/silver-bullet"
assert_not_contains "marketplace plugin avoids Claude-only Edit tool wording" "Edit tool" "$MARKETPLACE/plugins/silver-bullet"
assert_not_contains "marketplace plugin avoids Claude MCP install command" "claude mcp install" "$MARKETPLACE/plugins/silver-bullet"
assert_not_contains "marketplace plugin avoids /compact commands" "/compact" "$MARKETPLACE/plugins/silver-bullet"
assert_not_contains "marketplace plugin avoids AskUserQuestion" "AskUserQuestion" "$MARKETPLACE/plugins/silver-bullet"
assert_not_contains "marketplace plugin avoids manual state recording workaround" "Manually record skills in agent-mode sessions" "$MARKETPLACE/plugins/silver-bullet"
assert_not_contains "marketplace plugin avoids state-file write workaround" "write its name to the SB state file" "$MARKETPLACE/plugins/silver-bullet"

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
