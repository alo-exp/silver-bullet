#!/usr/bin/env bash
# Tests for scripts/validate-host-install-surface.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/validate-host-install-surface.sh"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

write_skill() {
  local root="$1" dir="$2" name="$3"
  mkdir -p "${root}/${dir}"
  cat >"${root}/${dir}/SKILL.md" <<EOF
---
name: ${name}
description: test
user-invocable: true
---
# test
EOF
}

seed_good_fixture() {
  local root="$1"
  mkdir -p "${root}/.claude-plugin" "${root}/.cursor-plugin" "${root}/plugins/silver-bullet/.cursor-plugin" "${root}/plugins/silver-bullet/.codex-plugin"
  printf '{"name":"silver-bullet","skills":"./agents/claude"}\n' >"${root}/.claude-plugin/plugin.json"
  printf '{"name":"silver-bullet","hooks":"./cursor-hooks.json"}\n' >"${root}/.cursor-plugin/plugin.json"
  printf '{"name":"silver-bullet","commands":"./commands","hooks":"./cursor-hooks.json"}\n' >"${root}/plugins/silver-bullet/.cursor-plugin/plugin.json"
  printf '{"name":"silver-bullet","commands":"./commands/","hooks":"./hooks/hooks.json"}\n' >"${root}/plugins/silver-bullet/.codex-plugin/plugin.json"
  write_skill "$root/agents/claude" "silver" "silver"
  write_skill "$root/host-bundles/codex" "silver" "silver"
  write_skill "$root/host-bundles/cursor" "silver" "silver"
  mkdir -p "$root/plugins/silver-bullet/skill-source/silver" "$root/plugins/silver-bullet/commands"
  printf 'mirror\n' >"$root/plugins/silver-bullet/skill-source/silver/SILVER_SOURCE"
  cat >"$root/plugins/silver-bullet/commands/silver-feature.md" <<'EOF'
---
name: silver-feature
description: test command stub
user-invocable: true
---
# silver-feature
EOF
}

good_root="$(mktemp -d)"
bleed_root="$(mktemp -d)"
cache_root="$(mktemp -d)"
trap 'rm -rf "$good_root" "$bleed_root" "$cache_root"' EXIT

seed_good_fixture "$good_root"
seed_good_fixture "$bleed_root"
mkdir -p "$bleed_root/agents/codex/silver"

mkdir -p "$cache_root/agents/claude/silver" "$cache_root/agents/codex"

if bash "$SCRIPT" --repo-root "$good_root" >/dev/null 2>&1; then pass "good fixture passes"; else fail "good fixture passes"; fi
if bash "$SCRIPT" --repo-root "$bleed_root" >/dev/null 2>&1; then fail "bleed fixture should fail"; else pass "bleed fixture fails"; fi
if bash "$SCRIPT" --cache-root "$cache_root" --host claude >/dev/null 2>&1; then fail "cache bleed should fail"; else pass "cache bleed fails"; fi
rm -rf "$cache_root/agents/codex"
if bash "$SCRIPT" --cache-root "$cache_root" --host claude >/dev/null 2>&1; then pass "clean cache passes"; else fail "clean cache passes"; fi
if bash "$SCRIPT" --repo-root "$REPO_ROOT" >/dev/null 2>&1; then pass "live repo passes"; else fail "live repo passes"; fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
