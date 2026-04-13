#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

echo "=== Live Doc Scheme Tests ==="

# Helper: seed standard doc scaffold into WORK_DIR
seed_doc_scheme() {
  mkdir -p "$WORK_DIR/docs/knowledge" "$WORK_DIR/docs/lessons"

  # INDEX.md from template
  sed 's|{{GIT_REPO}}|https://github.com/test/test.git|g' \
    "$SB_ROOT/templates/knowledge/INDEX.md.base" \
    > "$WORK_DIR/docs/knowledge/INDEX.md"

  # knowledge/2026-04.md from template
  sed \
    -e 's|{{PROJECT_NAME}}|live-test|g' \
    -e 's|{{YYYY-MM}}|2026-04|g' \
    "$SB_ROOT/templates/knowledge/YYYY-MM.md.base" \
    > "$WORK_DIR/docs/knowledge/2026-04.md"

  # lessons/2026-04.md from template
  sed 's|{{YYYY-MM}}|2026-04|g' \
    "$SB_ROOT/templates/lessons/YYYY-MM.md.base" \
    > "$WORK_DIR/docs/lessons/2026-04.md"

  git -C "$WORK_DIR" add -A
  git -C "$WORK_DIR" commit -q -m "seed docs"
}

# --- S1: Doc scheme scaffold — knowledge and lessons files created from scratch ---
echo "--- S1: Doc scheme scaffold creates all required files ---"
live_setup
response=$(invoke_claude_permissive "This is a new Node.js project named 'live-test' with git repo 'https://github.com/test/test.git'. Set up the Silver Bullet documentation scheme by creating these files:
1. docs/knowledge/INDEX.md — a documentation index table listing key docs including Architecture, Testing, CHANGELOG, and the git repo URL. Include a pointer to docs/knowledge/ and docs/lessons/.
2. docs/knowledge/2026-04.md — the April 2026 knowledge file with frontmatter (project: live-test, period: 2026-04, type: knowledge) and sections: Architecture Patterns, Known Gotchas, Key Decisions, Recurring Patterns, Open Questions.
3. docs/lessons/2026-04.md — the April 2026 lessons file with frontmatter (period: 2026-04, type: lessons) and sections: domain, stack, practice, devops, design.
Create all three files now.")
assert_file_exists "S1: knowledge INDEX exists" "$WORK_DIR/docs/knowledge/INDEX.md"
assert_file_exists "S1: knowledge monthly exists" "$WORK_DIR/docs/knowledge/2026-04.md"
assert_file_exists "S1: lessons monthly exists" "$WORK_DIR/docs/lessons/2026-04.md"
assert_file_contains "S1: INDEX references knowledge or lessons" "$WORK_DIR/docs/knowledge/INDEX.md" "knowledge|lessons"
assert_file_contains "S1: knowledge has section headers" "$WORK_DIR/docs/knowledge/2026-04.md" "Architecture Patterns|Known Gotchas"
live_teardown

# --- S2: Finalization step appends to knowledge/lessons ---
echo "--- S2: Finalization appends to knowledge and lessons ---"
live_setup
seed_doc_scheme
k_mtime=$(capture_mtime "$WORK_DIR/docs/knowledge/2026-04.md")
l_mtime=$(capture_mtime "$WORK_DIR/docs/lessons/2026-04.md")
sleep 2
response=$(invoke_claude_permissive "We just completed implementing a caching feature using Redis. Update docs/knowledge/2026-04.md and docs/lessons/2026-04.md with what we learned. Add to knowledge: an architecture pattern about cache-aside strategy, and a gotcha about Redis connection pooling. Add to lessons: a portable lesson about cache invalidation strategies under practice:architecture. Do not mention any project-specific names in the lessons file.")
assert_file_modified "S2: knowledge file modified" "$WORK_DIR/docs/knowledge/2026-04.md" "$k_mtime"
assert_file_modified "S2: lessons file modified" "$WORK_DIR/docs/lessons/2026-04.md" "$l_mtime"
assert_file_contains "S2: knowledge mentions caching" "$WORK_DIR/docs/knowledge/2026-04.md" "cache|Redis|caching"
assert_file_contains "S2: lessons mentions cache" "$WORK_DIR/docs/lessons/2026-04.md" "cache|invalidation"
live_teardown

# --- S3: CHANGELOG.md gets prepended with correct task entry ---
echo "--- S3: CHANGELOG.md prepended with new entry ---"
live_setup
seed_doc_scheme
mkdir -p "$WORK_DIR/docs"
cat > "$WORK_DIR/docs/CHANGELOG.md" << 'EOCL'
# Changelog

## 2026-04-10 — initial-setup
- **What:** Project scaffolding
- **Commits:** def5678
- **Skills:** quality-gates
EOCL
git -C "$WORK_DIR" add -A
git -C "$WORK_DIR" commit -q -m "seed changelog"
response=$(invoke_claude_permissive "Prepend a new CHANGELOG entry to docs/CHANGELOG.md for today's work. Task slug: redis-cache. What was done: Added Redis cache-aside layer for API responses. Commits: abc1234. Skills run: quality-gates, code-review. Knowledge updated: Architecture Patterns. Lessons updated: stack, practice.")
assert_file_contains "S3: new entry has slug" "$WORK_DIR/docs/CHANGELOG.md" "redis-cache"
assert_file_contains "S3: new entry has date" "$WORK_DIR/docs/CHANGELOG.md" "2026-04"
assert_file_contains "S3: entry has Knowledge ref" "$WORK_DIR/docs/CHANGELOG.md" "Knowledge|knowledge"
assert_file_contains "S3: entry has Lessons ref" "$WORK_DIR/docs/CHANGELOG.md" "Lessons|lessons"
assert_file_contains "S3: old entry preserved" "$WORK_DIR/docs/CHANGELOG.md" "initial-setup"
live_teardown

# --- S4: knowledge/INDEX.md updates when new doc created ---
echo "--- S4: INDEX.md updated when new doc added ---"
live_setup
seed_doc_scheme
echo "# Security" > "$WORK_DIR/docs/SECURITY.md"
git -C "$WORK_DIR" add -A
git -C "$WORK_DIR" commit -q -m "add SECURITY.md"
response=$(invoke_claude_permissive "A new SECURITY.md was created at docs/SECURITY.md. Update docs/knowledge/INDEX.md to include SECURITY.md in the index table. Keep all existing entries.")
assert_file_contains "S4: INDEX has SECURITY" "$WORK_DIR/docs/knowledge/INDEX.md" "SECURITY"
assert_file_contains "S4: INDEX still has Architecture" "$WORK_DIR/docs/knowledge/INDEX.md" "Architecture|ARCHITECTURE"
live_teardown

# --- S5: Non-redundancy — lessons must be portable ---
echo "--- S5: Lessons are portable (no project-specific names) ---"
live_setup
seed_doc_scheme
response=$(invoke_claude_permissive "Add a lesson to docs/lessons/2026-04.md about what we learned from implementing a Git hook-based enforcement system. The lesson should be portable — it must NOT mention any specific project names, tool names, or hook script names. Write it as a general practice lesson about pre-commit hook enforcement patterns.")
assert_file_contains "S5: lesson content added" "$WORK_DIR/docs/lessons/2026-04.md" "hook|enforcement|pre-commit"
assert_file_not_contains "S5: no silver-bullet mention" "$WORK_DIR/docs/lessons/2026-04.md" "silver-bullet|silver bullet"
assert_file_not_contains "S5: no specific hook names" "$WORK_DIR/docs/lessons/2026-04.md" "spec-floor-check|dev-cycle-check|completion-audit"
live_teardown

# --- S6: Monthly file boundary — new month gets fresh file ---
echo "--- S6: Monthly boundary — March frozen, April updated ---"
live_setup
seed_doc_scheme
printf '## Architecture Patterns\n\n2026-03-15 — Old pattern about something\n' \
  > "$WORK_DIR/docs/knowledge/2026-03.md"
git -C "$WORK_DIR" add -A
git -C "$WORK_DIR" commit -q -m "add march knowledge"
old_mtime=$(capture_mtime "$WORK_DIR/docs/knowledge/2026-03.md")
sleep 2
response=$(invoke_claude_permissive "It is now April 2026. The March knowledge file docs/knowledge/2026-03.md is frozen and must not be modified. Verify that docs/knowledge/2026-04.md exists (it should from scaffolding). Add an architecture pattern about hook-based enforcement to docs/knowledge/2026-04.md. Do NOT modify docs/knowledge/2026-03.md.")
assert_file_exists "S6: April file exists" "$WORK_DIR/docs/knowledge/2026-04.md"
assert_file_contains "S6: April has new content" "$WORK_DIR/docs/knowledge/2026-04.md" "hook|enforcement"
assert_file_contains "S6: April has section headers" "$WORK_DIR/docs/knowledge/2026-04.md" "Architecture Patterns"
new_mtime=$(capture_mtime "$WORK_DIR/docs/knowledge/2026-03.md")
if [[ "$new_mtime" -le "$old_mtime" ]]; then
  PASS=$((PASS + 1))
  printf 'PASS: S6: March file unchanged\n'
else
  FAIL=$((FAIL + 1))
  printf 'FAIL: S6: March file unchanged\n  (mtime changed: before=%s after=%s)\n' "$old_mtime" "$new_mtime"
fi
live_teardown

print_results
