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
  mkdir -p "${root}/.claude-plugin" "${root}/plugins/silver-bullet/.codex-plugin"
  printf '{"name":"silver-bullet","skills":"./agents/claude"}\n' >"${root}/.claude-plugin/plugin.json"
  printf '{"name":"silver-bullet","hooks":"./hooks/hooks.json"}\n' >"${root}/plugins/silver-bullet/.codex-plugin/plugin.json"
  write_skill "$root/agents/claude" "sb" "sb"
  write_skill "$root/host-bundles/codex" "sb" "sb"
  mkdir -p "$root/plugins/silver-bullet/skill-source/sb"
  printf 'mirror\n' >"$root/plugins/silver-bullet/skill-source/sb/SILVER_SOURCE"
}

good_root="$(mktemp -d)"
bleed_root="$(mktemp -d)"
cache_root="$(mktemp -d)"
codex_cache_root="$(mktemp -d)"
trap 'rm -rf "$good_root" "$bleed_root" "$cache_root" "$codex_cache_root"' EXIT

seed_good_fixture "$good_root"
seed_good_fixture "$bleed_root"
mkdir -p "$bleed_root/agents/codex/silver"

mkdir -p "$cache_root/agents/claude/sb" "$cache_root/agents/codex"

if bash "$SCRIPT" --repo-root "$good_root" >/dev/null 2>&1; then pass "good fixture passes"; else fail "good fixture passes"; fi
if bash "$SCRIPT" --repo-root "$bleed_root" >/dev/null 2>&1; then fail "bleed fixture should fail"; else pass "bleed fixture fails"; fi
if bash "$SCRIPT" --cache-root "$cache_root" --host claude >/dev/null 2>&1; then fail "cache bleed should fail"; else pass "cache bleed fails"; fi
rm -rf "$cache_root/agents/codex"
if bash "$SCRIPT" --cache-root "$cache_root" --host claude >/dev/null 2>&1; then pass "clean cache passes"; else fail "clean cache passes"; fi
mkdir -p "$codex_cache_root/skill-source/.placeholder" "$codex_cache_root/.codex-plugin/migrated-command-skills/source-command-feature"
if bash "$SCRIPT" --cache-root "$codex_cache_root" --host codex >/dev/null 2>&1; then fail "Codex source-command migration surface should fail"; else pass "Codex source-command migration surface fails"; fi
rm -rf "$codex_cache_root/.codex-plugin/migrated-command-skills"
if bash "$SCRIPT" --cache-root "$codex_cache_root" --host codex >/dev/null 2>&1; then pass "clean Codex cache passes"; else fail "clean Codex cache passes"; fi
if bash "$SCRIPT" --repo-root "$REPO_ROOT" >/dev/null 2>&1; then pass "live repo passes"; else fail "live repo passes"; fi

# R8-06: a sub-validator without its exec bit (zip extraction, core.fileMode=false)
# still runs, and a missing one fails loudly instead of printing OK.
copy_root="$(mktemp -d)"
trap 'rm -rf "$good_root" "$bleed_root" "$cache_root" "$codex_cache_root" "$copy_root"' EXIT
mkdir -p "$copy_root/scripts/lib"
cp "$SCRIPT" "$REPO_ROOT/scripts/validate-host-skill-surface.sh" "$REPO_ROOT/scripts/validate-claude-agent-token-budget.sh" "$copy_root/scripts/"
cp "$REPO_ROOT/scripts/lib/agent-bundle-paths.sh" "$copy_root/scripts/lib/"
bad_surface_root="$(mktemp -d)"
seed_good_fixture "$bad_surface_root"
write_skill "$bad_surface_root/host-bundles/codex" "zz-bad" "unprefixed-route"
chmod -x "$copy_root/scripts/validate-host-skill-surface.sh" "$copy_root/scripts/validate-claude-agent-token-budget.sh"
out="$(bash "$copy_root/scripts/validate-host-install-surface.sh" --repo-root "$bad_surface_root" 2>&1)" && rc=0 || rc=$?
if [[ "$rc" -eq 1 && "$out" == *"lacks sb: prefix"* && "$out" != *"OK — no cross-host"* ]]; then
  pass "non-executable skill-surface validator still runs and fails the surface"
else
  fail "non-executable skill-surface validator still runs and fails the surface (rc=$rc)"
fi
rm -f "$copy_root/scripts/validate-host-skill-surface.sh"
out="$(bash "$copy_root/scripts/validate-host-install-surface.sh" --repo-root "$good_root" 2>&1)" && rc=0 || rc=$?
if [[ "$rc" -eq 1 && "$out" == *"missing sub-validator"*"validate-host-skill-surface.sh"* ]]; then
  pass "missing skill-surface validator fails loudly"
else
  fail "missing skill-surface validator fails loudly (rc=$rc): $out"
fi
cp "$REPO_ROOT/scripts/validate-host-skill-surface.sh" "$copy_root/scripts/"
rm -f "$copy_root/scripts/validate-claude-agent-token-budget.sh"
out="$(bash "$copy_root/scripts/validate-host-install-surface.sh" --repo-root "$good_root" --host claude 2>&1)" && rc=0 || rc=$?
if [[ "$rc" -eq 1 && "$out" == *"missing sub-validator"*"validate-claude-agent-token-budget.sh"* ]]; then
  pass "missing token-budget validator fails loudly"
else
  fail "missing token-budget validator fails loudly (rc=$rc): $out"
fi
rm -rf "$bad_surface_root"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
