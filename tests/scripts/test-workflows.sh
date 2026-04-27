#!/usr/bin/env bash
set -euo pipefail
PASS=0; FAIL=0

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then echo "PASS: $desc"; (( PASS++ )) || true
  else echo "FAIL: $desc"; echo "  expected: [$expected]"; echo "  actual:   [$actual]"; (( FAIL++ )) || true; fi
}

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if printf '%s' "$haystack" | grep -qE "$needle"; then echo "PASS: $desc"; (( PASS++ )) || true
  else echo "FAIL: $desc — looking for: [$needle]"; (( FAIL++ )) || true; fi
}

assert_not_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if ! printf '%s' "$haystack" | grep -qE "$needle"; then echo "PASS: $desc"; (( PASS++ )) || true
  else echo "FAIL: $desc — should NOT contain: [$needle]"; (( FAIL++ )) || true; fi
}

assert_file_exists() {
  local desc="$1" path="$2"
  if [[ -f "$path" ]]; then echo "PASS: $desc"; (( PASS++ )) || true
  else echo "FAIL: $desc — missing: $path"; (( FAIL++ )) || true; fi
}

assert_file_absent() {
  local desc="$1" path="$2"
  if [[ ! -e "$path" ]]; then echo "PASS: $desc"; (( PASS++ )) || true
  else echo "FAIL: $desc — should be absent: $path"; (( FAIL++ )) || true; fi
}

SCRIPT="$(cd "$(dirname "$0")/../.." && pwd)/scripts/workflows.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

setup_repo() {
  rm -rf "$TMP/repo"
  mkdir -p "$TMP/repo/.planning"
  cd "$TMP/repo" && git init -q
}

# T1: start emits a valid workflow id and creates the file
setup_repo
ID=$("$SCRIPT" start silver-feature "build auth" "explore,plan,execute,ship")
assert_contains "T1 id format <date>-<rand>-<composer>" \
  '^[0-9]{8}T[0-9]{6}Z-[a-z0-9]+-silver-feature$' "$ID"
assert_file_exists "T1 workflow file created" "$TMP/repo/.planning/workflows/$ID.md"
content=$(cat "$TMP/repo/.planning/workflows/$ID.md")
assert_contains "T1 frontmatter has workflow_id" "workflow_id: $ID" "$content"
assert_contains "T1 frontmatter has composer" "composer: silver-feature" "$content"
assert_contains "T1 frontmatter has status: active" "^status: active" "$content"
assert_contains "T1 intent recorded" "intent: build auth" "$content"
assert_contains "T1 flow row 1" '^\| 1 \| explore \| pending' "$content"
assert_contains "T1 flow row 4" '^\| 4 \| ship \| pending' "$content"

# T2: start without flows yields a single (unspecified) row
setup_repo
ID2=$("$SCRIPT" start silver-bugfix)
content2=$(cat "$TMP/repo/.planning/workflows/$ID2.md")
assert_contains "T2 default unspecified flow row" '^\| 1 \| \(unspecified\) \| pending' "$content2"
assert_contains "T2 default intent placeholder" "intent: \(none\)" "$content2"

# T3: complete-flow marks one row complete, leaves others pending
setup_repo
ID=$("$SCRIPT" start silver-feature "x" "explore,plan,ship")
"$SCRIPT" complete-flow "$ID" plan
content=$(cat "$TMP/repo/.planning/workflows/$ID.md")
assert_contains "T3 plan flow flipped to complete" '^\| 2 \| plan \| complete' "$content"
assert_contains "T3 explore still pending" '^\| 1 \| explore \| pending' "$content"
assert_contains "T3 ship still pending" '^\| 3 \| ship \| pending' "$content"

# T4: list returns active ids; complete archives + removes from active
setup_repo
ID=$("$SCRIPT" start silver-ui "ui work")
ID_B=$("$SCRIPT" start silver-devops "infra work")
list=$("$SCRIPT" list)
assert_contains "T4 list includes ID" "$ID" "$list"
assert_contains "T4 list includes ID_B" "$ID_B" "$list"

"$SCRIPT" complete "$ID"
list_after=$("$SCRIPT" list)
assert_not_contains "T4 list no longer includes completed ID" "$ID" "$list_after"
assert_contains "T4 list still includes ID_B" "$ID_B" "$list_after"
assert_file_absent "T4 active file removed" "$TMP/repo/.planning/workflows/$ID.md"
assert_file_exists "T4 archive file present" "$TMP/repo/.planning/workflows/.archive/$ID.md"
archived=$(cat "$TMP/repo/.planning/workflows/.archive/$ID.md")
assert_contains "T4 archived status flipped to complete" "^status: complete" "$archived"
assert_contains "T4 archived has completed_at" "^completed_at:" "$archived"

# T5: invalid id rejected for complete-flow / get / heartbeat
setup_repo
"$SCRIPT" start silver-feature "x" >/dev/null
err=$("$SCRIPT" complete-flow "../etc/passwd" foo 2>&1 || true)
assert_contains "T5 path traversal blocked" "invalid workflow id" "$err"
err2=$("$SCRIPT" get "not-a-real-id" 2>&1 || true)
assert_contains "T5 nonsense id rejected" "invalid workflow id" "$err2"

# T6: get returns the file path
setup_repo
ID=$("$SCRIPT" start silver-feature)
got=$("$SCRIPT" get "$ID")
assert_eq "T6 get returns full path" "$TMP/repo/.planning/workflows/$ID.md" "$got"

# T7: active returns single active path; fails if multiple or zero
setup_repo
err=$("$SCRIPT" active 2>&1 || true)
assert_contains "T7 no active workflows" "no active workflows" "$err"
ID=$("$SCRIPT" start silver-feature)
got=$("$SCRIPT" active)
assert_eq "T7 single active returned" "$TMP/repo/.planning/workflows/$ID.md" "$got"
"$SCRIPT" start silver-bugfix >/dev/null
err2=$("$SCRIPT" active 2>&1 || true)
assert_contains "T7 multiple active rejected" "multiple active workflows" "$err2"

# T8: heartbeat updates mtime, preserves content
setup_repo
ID=$("$SCRIPT" start silver-feature)
file="$TMP/repo/.planning/workflows/$ID.md"
old_mtime=$(stat -f '%m' "$file" 2>/dev/null || stat -c '%Y' "$file")
sleep 1
"$SCRIPT" heartbeat "$ID"
new_mtime=$(stat -f '%m' "$file" 2>/dev/null || stat -c '%Y' "$file")
if [[ "$new_mtime" -gt "$old_mtime" ]]; then
  echo "PASS: T8 heartbeat advanced mtime"; (( PASS++ )) || true
else
  echo "FAIL: T8 heartbeat did not advance mtime ($old_mtime → $new_mtime)"; (( FAIL++ )) || true
fi

# T9: refusing to write through symlink (SEC-02 pattern) on complete-flow
setup_repo
ID=$("$SCRIPT" start silver-feature "x" "alpha")
file="$TMP/repo/.planning/workflows/$ID.md"
# Replace file with a symlink pointing elsewhere
real_target="$TMP/elsewhere.md"
cp "$file" "$real_target"
rm "$file"
ln -s "$real_target" "$file"
err=$("$SCRIPT" complete-flow "$ID" alpha 2>&1 || true)
assert_contains "T9 symlink refused" "refusing to write through symlink|invalid workflow id|workflow not found" "$err"
# Validate the real target was NOT written through the symlink
target_after=$(cat "$real_target")
assert_not_contains "T9 real target unchanged" "complete" "$target_after"

# T10: id contains only sane characters even for messy composer slug
setup_repo
ID=$("$SCRIPT" start "Silver/UI:Workflow" "x")
assert_contains "T10 messy composer sanitized" "silver-ui-workflow" "$ID"

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
