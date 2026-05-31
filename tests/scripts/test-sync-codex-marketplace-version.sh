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

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/sync-codex-marketplace-version.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

MARKETPLACE="$TMP/marketplace"
REMOTE="$TMP/remote.git"
mkdir -p "$MARKETPLACE/plugins/silver-bullet/.codex-plugin" "$MARKETPLACE/skills/silver-init"

cat > "$MARKETPLACE/plugins/silver-bullet/.codex-plugin/plugin.json" <<'EOF'
{
  "name": "silver-bullet",
  "version": "0.0.1",
  "commands": "./commands/",
  "skills": "./skills/"
}
EOF
cat > "$MARKETPLACE/skills/silver-init/SKILL.md" <<'EOF'
---
name: stale-silver-init
---
EOF
ln -s ../../skills "$MARKETPLACE/plugins/silver-bullet/skills"

git -C "$MARKETPLACE" init -q
git -C "$MARKETPLACE" config user.email "tests@example.invalid"
git -C "$MARKETPLACE" config user.name "Tests"
git -C "$MARKETPLACE" add .
git -C "$MARKETPLACE" commit -q -m "seed stale marketplace"
git -C "$TMP" init --bare -q "$REMOTE"
git -C "$MARKETPLACE" remote add origin "$REMOTE"
git -C "$MARKETPLACE" push -q -u origin HEAD:main

source_count="$(find "$REPO_ROOT/plugins/silver-bullet/skills" -maxdepth 2 -name SKILL.md | wc -l | tr -d ' ')"

CODEX_MARKETPLACE_REPO_ROOT="$MARKETPLACE" bash "$SCRIPT" >/dev/null

marketplace_count="$(find "$MARKETPLACE/plugins/silver-bullet/skills" -maxdepth 2 -name SKILL.md | wc -l | tr -d ' ')"

assert_not_symlink "marketplace plugin skills surface is materialized" "$MARKETPLACE/plugins/silver-bullet/skills"
assert_file_exists "marketplace plugin includes Silver Bullet init skill" "$MARKETPLACE/plugins/silver-bullet/skills/silver-init/SKILL.md"
assert_file_exists "marketplace plugin includes Silver Bullet feature skill" "$MARKETPLACE/plugins/silver-bullet/skills/silver-feature/SKILL.md"
assert_equal "marketplace plugin skill count matches source package" "$source_count" "$marketplace_count"

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
