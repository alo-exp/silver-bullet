#!/usr/bin/env bash
# Tests for scripts/install-cursor-sb-agents.sh — AC-1,7,10,11,14,17,18
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
INSTALLER="${REPO_ROOT}/scripts/install-cursor-sb-agents.sh"
FIXTURE_CATALOG="${REPO_ROOT}/tests/fixtures/cursor-models-catalog.json"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  [[ "$expected" == "$actual" ]] && pass "$desc" || fail "$desc (expected=$expected actual=$actual)"
}

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  printf '%s' "$haystack" | grep -qF "$needle" && pass "$desc" || fail "$desc"
}

assert_not_contains() {
  local desc="$1" needle="$2" haystack="$3"
  printf '%s' "$haystack" | grep -qF "$needle" && fail "$desc" || pass "$desc"
}

[[ -x "$INSTALLER" ]] && pass "installer executable" || fail "installer executable"

TEST_HOME="$(mktemp -d)"
TEST_PROJ="$(mktemp -d)"
AGENTS_DIR="${TEST_HOME}/.cursor/agents"
mkdir -p "$AGENTS_DIR" "${TEST_HOME}/.config/silver-bullet"
cp "$FIXTURE_CATALOG" "${TEST_HOME}/.config/silver-bullet/cursor-models-catalog.json"
cp "$REPO_ROOT/templates/silver-bullet.config.json.default" "${TEST_PROJ}/.silver-bullet.json"

cleanup() { rm -rf "$TEST_HOME" "$TEST_PROJ"; }
trap cleanup EXIT

run_install() {
  env HOME="$TEST_HOME" \
    SB_CURSOR_SB_AGENTS_OFFLINE=1 \
    SB_CURSOR_MODELS_CATALOG="${TEST_HOME}/.config/silver-bullet/cursor-models-catalog.json" \
    CSBA_REPO_ROOT="$TEST_PROJ" \
    bash "$INSTALLER" "$@"
}

# AC-1: default 6 agents, sb- prefix, no fast/max/low
run_install --global --non-interactive >/dev/null
shopt -s nullglob
managed=("$AGENTS_DIR"/sb-*.md)
assert_eq "AC-1 default writes 6 sb agents" "6" "${#managed[@]}"

names="$(for f in "${managed[@]}"; do awk '/^name:/{print $2; exit}' "$f"; done | sort)"
assert_contains "AC-1 includes sb-composer-2-5-medium" "sb-composer-2-5-medium" "$names"
assert_contains "AC-1 includes sb-grok-4-5-xhigh" "sb-grok-4-5-xhigh" "$names"
for f in "${managed[@]}"; do
  base="$(basename "$f")"
  [[ "$base" == sb-* ]] || fail "AC-1 sb- prefix on $base"
  [[ "$base" != *fast* && "$base" != *max* && "$base" != *-low* ]] || fail "AC-1 no fast/max/low in $base"
done
pass "AC-1 no fast/max/low suffixes in default set"

# AC-11: Grok composite model lines; Composer locked composer-2.5
grok_high="$(awk '/^model:/{print $2; exit}' "$AGENTS_DIR/sb-grok-4-5-high.md")"
assert_eq "AC-11 grok high composite slug" "cursor-grok-4.5-high" "$grok_high"
composer_xhigh="$(awk '/^model:/{print $2; exit}' "$AGENTS_DIR/sb-composer-2-5-xhigh.md")"
assert_eq "AC-11 composer all efforts composer-2.5" "composer-2.5" "$composer_xhigh"

# AC-11b: explicit low effort uses cursor-grok-4.5-low (grok-4.5-low is not a CLI slug)
run_install --global --non-interactive --select-models grok-4.5 --effort-levels low,medium,high >/dev/null
grok_low="$(awk '/^model:/{print $2; exit}' "$AGENTS_DIR/sb-grok-4-5-low.md")"
assert_eq "AC-11b grok low cursor-prefixed slug" "cursor-grok-4.5-low" "$grok_low"
grok_med="$(awk '/^model:/{print $2; exit}' "$AGENTS_DIR/sb-grok-4-5-medium.md")"
assert_eq "AC-11b grok medium cursor-prefixed slug" "cursor-grok-4.5-medium" "$grok_med"
# Restore default-shaped set for subsequent ACs
run_install --global --non-interactive --select-models composer-2.5,grok-4.5 --effort-levels medium,high,xhigh >/dev/null

# AC-14: unmarked sb-user-custom.md survives prune
cat >"$AGENTS_DIR/sb-user-custom.md" <<'EOF'
---
name: sb-user-custom
description: user agent
model: composer-2.5
---
User-authored agent without managed marker.
EOF
run_install --global --non-interactive --select-models composer-2.5 --effort-levels medium >/dev/null
[[ -f "$AGENTS_DIR/sb-user-custom.md" ]] && pass "AC-14 unmarked sb-user-custom preserved" || fail "AC-14 unmarked sb-user-custom preserved"

# AC-7 / AC-17: deselect grok prunes managed orphans
run_install --global --non-interactive --select-models composer-2.5 --effort-levels medium,high,xhigh >/dev/null
managed_after=("$AGENTS_DIR"/sb-*.md)
count_after=0
for f in "${managed_after[@]}"; do
  grep -qF '<!-- sb-managed: cursor-sb-agents -->' "$f" && count_after=$((count_after + 1)) || true
done
assert_eq "AC-17 prune to 3 composer agents" "3" "$count_after"
[[ ! -f "$AGENTS_DIR/sb-grok-4-5-medium.md" ]] && pass "AC-7 pruned managed grok orphan" || fail "AC-7 pruned managed grok orphan"

# AC-10: no fast unless --include-fast (default install already checked; explicit select without fast)
run_install --global --non-interactive --select-models composer-2.5,grok-4.5 --effort-levels medium,high,xhigh >/dev/null
fast_found=0
for f in "$AGENTS_DIR"/sb-*.md; do
  [[ "$(basename "$f")" == *fast* ]] && fast_found=1
done
[[ "$fast_found" -eq 0 ]] && pass "AC-10 no fast agents by default" || fail "AC-10 no fast agents by default"

# AC-18: no legacy keys / sb-rfl prefix
legacy_hits="$(rg -n 'cursor_review_fix_ladder|install-cursor-rfl|sb-rfl-' \
  "$REPO_ROOT/scripts/install-cursor-sb-agents.sh" \
  "$REPO_ROOT/scripts/lib/cursor-sb-agents" \
  "$AGENTS_DIR" 2>/dev/null || true)"
[[ -z "$legacy_hits" ]] && pass "AC-18 no legacy keys or sb-rfl names" || fail "AC-18 no legacy keys or sb-rfl names"

# Catalog fixture has pricing fields (AC-9 partial)
jq -e '.models[0].pricing.input' "$FIXTURE_CATALOG" >/dev/null \
  && pass "fixture catalog includes pricing.input" || fail "fixture catalog includes pricing.input"

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]

