#!/usr/bin/env bash
# Integration test: SKILL.md structural validation for all skills
set -euo pipefail

PASS=0; FAIL=0
SKILL_COUNT=0

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILLS_DIR="$REPO_ROOT/skills"

check() {
  local desc="$1" result="$2"
  if [[ "$result" == "pass" ]]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== SKILL.md Structural Validation ==="

for skill_dir in "$SKILLS_DIR"/*/; do
  skill_name="$(basename "$skill_dir")"
  skill_file="$skill_dir/SKILL.md"
  SKILL_COUNT=$((SKILL_COUNT + 1))

  echo "--- $skill_name ---"

  # Check 1: SKILL.md exists
  if [[ -f "$skill_file" ]]; then
    check "$skill_name: SKILL.md exists" "pass"
  else
    check "$skill_name: SKILL.md exists" "fail"
    # Skip remaining checks — file doesn't exist
    check "$skill_name: file size > 100 bytes (skipped — SKILL.md missing)" "fail"
    check "$skill_name: has YAML frontmatter (skipped — SKILL.md missing)" "fail"
    check "$skill_name: frontmatter has name: field (skipped — SKILL.md missing)" "fail"
    check "$skill_name: name: value matches directory name (skipped — SKILL.md missing)" "fail"
    check "$skill_name: has at least one ## section heading (skipped — SKILL.md missing)" "fail"
    check "$skill_name: no TODO/TBD/FIXME markers (skipped — SKILL.md missing)" "fail"
    continue
  fi

  # Check 2: File is > 100 bytes
  file_size=$(wc -c < "$skill_file" | tr -d ' ')
  if [[ "$file_size" -gt 100 ]]; then
    check "$skill_name: file size > 100 bytes ($file_size bytes)" "pass"
  else
    check "$skill_name: file size > 100 bytes ($file_size bytes)" "fail"
  fi

  # Check 3: Has YAML frontmatter (line 1 is "---" and a second "---" appears later)
  first_line="$(head -1 "$skill_file")"
  closing_count=$(grep -c '^---$' "$skill_file" || true)
  if [[ "$first_line" == "---" && "$closing_count" -ge 2 ]]; then
    check "$skill_name: has YAML frontmatter" "pass"
    has_frontmatter=true
  else
    check "$skill_name: has YAML frontmatter" "fail"
    has_frontmatter=false
  fi

  # Check 4: Has "name:" field in frontmatter
  if [[ "$has_frontmatter" == "true" ]]; then
    # Extract frontmatter block (between first and second ---)
    fm_name=$(awk '/^---$/{count++; if(count==2) exit} count==1 && /^name:/' "$skill_file" | head -1)
    if [[ -n "$fm_name" ]]; then
      check "$skill_name: frontmatter has name: field" "pass"
      has_name=true
    else
      check "$skill_name: frontmatter has name: field" "fail"
      has_name=false
    fi
  else
    check "$skill_name: frontmatter has name: field (skipped — no frontmatter)" "fail"
    has_name=false
  fi

  # Check 5: name: value matches directory name (strip quotes and whitespace)
  if [[ "$has_name" == "true" ]]; then
    # Extract the value after "name:" and strip quotes/whitespace
    name_value=$(echo "$fm_name" | sed 's/^name:[[:space:]]*//' | tr -d '"'"'" | tr -d '[:space:]')
    if [[ "$name_value" == "$skill_name" ]]; then
      check "$skill_name: name: value matches directory name ('$name_value')" "pass"
    else
      check "$skill_name: name: value matches directory name (got '$name_value', want '$skill_name')" "fail"
    fi
  else
    check "$skill_name: name: value matches directory name (skipped — no name field)" "fail"
  fi

  # Check 6: Has at least one ## section heading
  section_count=$(grep -c '^## ' "$skill_file" || true)
  if [[ "$section_count" -ge 1 ]]; then
    check "$skill_name: has at least one ## section heading ($section_count found)" "pass"
  else
    check "$skill_name: has at least one ## section heading" "fail"
  fi

  # Check 7: No [TODO], [TBD], or FIXME markers (case-insensitive)
  placeholder_count=$(grep -ciE '\[TODO\]|\[TBD\]|FIXME' "$skill_file" || true)
  if [[ "$placeholder_count" -eq 0 ]]; then
    check "$skill_name: no TODO/TBD/FIXME markers" "pass"
  else
    check "$skill_name: no TODO/TBD/FIXME markers ($placeholder_count found)" "fail"
  fi

done

echo ""
echo "Validated $SKILL_COUNT skills"
echo "Results: $PASS passed, $FAIL failed"

[[ $FAIL -eq 0 ]]
