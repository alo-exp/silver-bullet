#!/usr/bin/env bash
# CI gate: silver-bullet.md must stay in sync with templates/silver-bullet.md.base
# aside from whitelisted dogfood-only deltas (placeholders, §9 pre-release, numbering).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIVE="${REPO_ROOT}/silver-bullet.md"
TEMPLATE="${REPO_ROOT}/templates/silver-bullet.md.base"
PASS=0
FAIL=0

assert_pass() {
  echo "PASS: $1"
  PASS=$((PASS + 1))
}

assert_fail() {
  echo "FAIL: $1"
  FAIL=$((FAIL + 1))
}

if [[ ! -f "$LIVE" ]] || [[ ! -f "$TEMPLATE" ]]; then
  echo "FAIL: missing silver-bullet.md or templates/silver-bullet.md.base"
  exit 1
fi

TMP_LIVE="$(mktemp)"
TMP_TEMPLATE="$(mktemp)"
trap 'rm -f "$TMP_LIVE" "$TMP_TEMPLATE"' EXIT

normalize_for_parity() {
  local infile="$1"
  local outfile="$2"
  awk '
    BEGIN { skip=0 }
    /^## 9\. Pre-Release Quality Gate/ { skip=1; next }
    skip && /^## 10\. User Workflow Preferences/ { skip=0 }
    skip { next }
    {
      gsub(/# Silver Bullet — Enforcement Instructions for silver-bullet/, "# Silver Bullet — Enforcement Instructions for {{PROJECT_NAME}}")
      gsub(/`docs\/workflows\/full-dev-cycle\.md`/, "`docs/workflows/{{ACTIVE_WORKFLOW}}.md`")
      gsub(/§10/, "§9")
      gsub(/§11/, "§10")
      gsub(/§12/, "§11")
      gsub(/^## 10\. User Workflow Preferences/, "## 9. User Workflow Preferences")
      gsub(/^### 10a\./, "### 9a.")
      gsub(/^### 10b\./, "### 9b.")
      gsub(/^### 10c\./, "### 9c.")
      gsub(/^### 10d\./, "### 9d.")
      gsub(/^### 10e\./, "### 9e.")
      gsub(/^### 10f\./, "### 9f.")
      gsub(/^## 11\. Multi-Agent Coordination/, "## 10. Multi-Agent Coordination")
      gsub(/^## 12\. Runtime Compatibility/, "## 11. Runtime Compatibility")
      if ($0 ~ /This live repo uses §9 for Pre-Release/) next
      if ($0 ~ /^  User Workflow Preferences is §10/) next
      if ($0 ~ /^  Multi-Agent is §11/) next
      if ($0 ~ /^  Runtime Compatibility is §12/) next
      if ($0 ~ /^  The template \(`templates\/silver-bullet\.md\.base`\) omits/) next
      print
    }
  ' "$infile" | sed 's/^     decision/    decision/' \
    | awk 'BEGIN{skip=0} /^<!--$/{skip=1; next} skip && /^-->$/ {skip=0; next} !skip' > "$outfile"
}

normalize_for_parity "$LIVE" "$TMP_LIVE"
normalize_for_parity "$TEMPLATE" "$TMP_TEMPLATE"

if diff -u "$TMP_TEMPLATE" "$TMP_LIVE" >/dev/null 2>&1; then
  assert_pass "silver-bullet.md matches template after dogfood whitelist normalization"
else
  assert_fail "silver-bullet.md drift vs templates/silver-bullet.md.base (non-whitelisted)"
  diff -u "$TMP_TEMPLATE" "$TMP_LIVE" | head -40 || true
fi

if grep -qE '\{\{[A-Z0-9_]+\}\}' "$LIVE"; then
  assert_fail "live silver-bullet.md contains template placeholders"
else
  assert_pass "live silver-bullet.md has no template placeholders"
fi

echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
