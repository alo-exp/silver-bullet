#!/usr/bin/env bash
# sb-doctor cross-host surface checks (D14–D16)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DOCTOR="$REPO_ROOT/scripts/sb-doctor.sh"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

chmod +x "$DOCTOR" 2>/dev/null || true

for id in D14 D15 D16; do
  grep -q "record pass ${id}\|record fail ${id}\|record warn ${id}" "$DOCTOR" && pass "check ${id}" || fail "check ${id}"
done

grep -q -- '--fix' "$DOCTOR" && grep -q 'doctor_apply_fixes' "$DOCTOR" && pass "--fix support" || fail "--fix support"

MOCK_HOME="$(mktemp -d)"
MOCK_PROJ="$(mktemp -d)"
trap 'rm -rf "$MOCK_HOME" "$MOCK_PROJ"' EXIT
mkdir -p "$MOCK_PROJ/docs/workflows" "$MOCK_PROJ/scripts"
cp "$REPO_ROOT/templates/silver-bullet.config.json.default" "$MOCK_PROJ/.silver-bullet.json"
jq '.sb_initiated = true' "$MOCK_PROJ/.silver-bullet.json" >"$MOCK_PROJ/.silver-bullet.json.tmp" && mv "$MOCK_PROJ/.silver-bullet.json.tmp" "$MOCK_PROJ/.silver-bullet.json"
cp "$REPO_ROOT/silver-bullet.md" "$MOCK_PROJ/silver-bullet.md"
cp "$REPO_ROOT/scripts/workflows.sh" "$MOCK_PROJ/scripts/workflows.sh"
chmod +x "$MOCK_PROJ/scripts/workflows.sh"

cache_ver="0.51.2"
cache_dir="$MOCK_HOME/.claude/plugins/cache/alo-labs/silver-bullet/${cache_ver}"
mkdir -p "$cache_dir/hooks" "$cache_dir/agents/claude/sb" "$cache_dir/agents/codex"
cp -a "$cache_dir" "$MOCK_HOME/.claude/plugins/cache/alo-labs/silver-bullet/current"
cp "$REPO_ROOT/hooks/hooks.json" "$cache_dir/hooks/hooks.json"
cp "$REPO_ROOT/hooks/hooks.json" "$MOCK_HOME/.claude/plugins/cache/alo-labs/silver-bullet/current/hooks/hooks.json"
jq -n --arg v "$cache_ver" --arg p "$MOCK_HOME/.claude/plugins/cache/alo-labs/silver-bullet/current" \
  '{version:2,plugins:{"silver-bullet@alo-labs":[{scope:"user",version:$v,installPath:$p}]}}' \
  >"$MOCK_HOME/.claude/plugins/installed_plugins.json"
printf '{"hooks":{}}\n' >"$MOCK_HOME/.claude/settings.json"

out="$(env HOME="$MOCK_HOME" SILVER_BULLET_RUNTIME=claude bash "$DOCTOR" "$MOCK_PROJ" 2>&1 || true)"
grep -q 'FAIL: D14' <<<"$out" && pass "D14 cache bleed" || fail "D14 cache bleed"
grep -q 'PASS: D15\|FAIL: D15' <<<"$out" && pass "D15 token budget" || fail "D15 token budget"
grep -q 'PASS: D16\|FAIL: D16' <<<"$out" && pass "D16 repo surface" || fail "D16 repo surface"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
