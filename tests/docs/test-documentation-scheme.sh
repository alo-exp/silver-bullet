#!/usr/bin/env bash
set -euo pipefail

# Test suite for the Silver Bullet documentation scheme
# Validates structure, references, scalability, and non-redundancy

PASS=0
FAIL=0
TOTAL=0

pass() { ((PASS++)); ((TOTAL++)); printf "  ✓ %s\n" "$1"; }
fail() { ((FAIL++)); ((TOTAL++)); printf "  ✗ %s\n" "$1"; }
section() { printf "\n━━━ %s ━━━\n" "$1"; }

# ─── Section 1: Required docs exist ───

section "Required docs exist"

for f in \
  docs/ARCHITECTURE.md \
  docs/ENFORCEMENT.md \
  docs/SDLC-MAP.md \
  docs/PLUGIN-BOUNDARIES.md \
  docs/SECURITY.md \
  docs/RELEASE.md \
  docs/TESTING.md \
  docs/tech-debt.md \
  docs/CHANGELOG.md \
  docs/PRD-Overview.md \
  docs/documentation-scheme.md \
  docs/project-documentation-scheme.md \
  docs/doc-scheme.md \
  docs/knowledge/INDEX.md \
  docs/knowledge/2026-04.md \
  docs/lessons/2026-04.md; do
  if [[ -f "$f" ]]; then
    pass "$f exists"
  else
    fail "$f MISSING"
  fi
done

# ─── Section 2: Required directories exist ───

section "Required directories exist"

for d in docs/audits docs/internal docs/knowledge docs/lessons docs/specs docs/sessions docs/workflows; do
  if [[ -d "$d" ]]; then
    pass "$d/ exists"
  else
    fail "$d/ MISSING"
  fi
done

# ─── Section 3: Templates exist ───

section "Templates exist"

for f in \
  templates/knowledge/INDEX.md.base \
  templates/knowledge/YYYY-MM.md.base \
  templates/lessons/YYYY-MM.md.base \
  templates/doc-scheme.md.base \
  templates/CHANGELOG-project.md.base \
  templates/silver-bullet.md.base \
  templates/silver-bullet.config.json.default; do
  if [[ -f "$f" ]]; then
    pass "$f exists"
  else
    fail "$f MISSING"
  fi
done

# ─── Section 4: Old KNOWLEDGE.md removed ───

section "KNOWLEDGE.md migration complete"

if [[ ! -f docs/KNOWLEDGE.md ]]; then
  pass "docs/KNOWLEDGE.md deleted"
else
  fail "docs/KNOWLEDGE.md still exists — should be migrated to docs/knowledge/"
fi

if [[ ! -f templates/KNOWLEDGE.md.base ]]; then
  pass "templates/KNOWLEDGE.md.base deleted"
else
  fail "templates/KNOWLEDGE.md.base still exists — should be replaced by templates/knowledge/"
fi

# No KNOWLEDGE.md references in active source files
# Excludes: worktrees, specs (point-in-time), site HTML, sessions, internal, CHANGELOG (historical),
# test fixtures, test scripts, superpowers plans, hooks that log session metadata, templates for session logs
# Excludes all archived/historical dirs: specs (point-in-time designs), sessions (logs),
# internal (superseded), superpowers (completed plans), tests, .planning, .claude, site,
# plus CHANGELOG files (historical entries) and session-log templates
stale_refs=$(grep -rl "KNOWLEDGE\.md" --include="*.md" --include="*.sh" --include="*.json" --include="*.base" \
  --exclude-dir=".claude" --exclude-dir="site" --exclude-dir="specs" --exclude-dir="sessions" \
  --exclude-dir="internal" --exclude-dir="superpowers" --exclude-dir="tests" \
  --exclude-dir=".planning" . 2>/dev/null | \
  grep -v "CHANGELOG" | grep -v "session-log" || true)
if [[ -z "$stale_refs" ]]; then
  pass "No stale KNOWLEDGE.md references in active source files"
else
  fail "Stale KNOWLEDGE.md references found in: $stale_refs"
fi

# ─── Section 5: No stale doc name references ───

section "No stale doc name references"

for pattern in "Architecture-and-Design" "Testing-Strategy-and-Plan" "Master-PRD"; do
  # Exclude: worktrees, archived docs (specs, sessions, internal, superpowers), test fixtures,
  # .planning (historical), CHANGELOG, README (updated during release Stage 3)
  hits=$(grep -rl "$pattern" --include="*.md" --include="*.sh" --include="*.json" --include="*.base" \
    --exclude-dir=".claude" --exclude-dir="internal" --exclude-dir="specs" \
    --exclude-dir="sessions" --exclude-dir="superpowers" --exclude-dir="tests" \
    --exclude-dir=".planning" --exclude-dir="site" . 2>/dev/null | \
    grep -v "CHANGELOG" | grep -v "README" || true)
  if [[ -z "$hits" ]]; then
    pass "No references to '$pattern' in active files"
  else
    fail "'$pattern' still referenced in: $hits"
  fi
done

# ─── Section 6: Doc size caps ───

section "Doc size caps (docs/ files < 500 lines)"

over_cap=0
for f in docs/*.md; do
  lines=$(wc -l < "$f")
  if (( lines > 500 )); then
    fail "$f has $lines lines (cap: 500)"
    ((over_cap++))
  fi
done
if (( over_cap == 0 )); then
  pass "All docs/ files under 500-line cap"
fi

section "Knowledge/lessons file size caps (< 300 lines)"

for f in docs/knowledge/*.md docs/lessons/*.md; do
  [[ -f "$f" ]] || continue
  lines=$(wc -l < "$f")
  if (( lines > 300 )); then
    fail "$f has $lines lines (cap: 300)"
  else
    pass "$f is $lines lines (under 300)"
  fi
done

# ─── Section 7: Knowledge file frontmatter ───

section "Knowledge file frontmatter validation"

for f in docs/knowledge/2*.md; do
  [[ -f "$f" ]] || continue
  if head -1 "$f" | grep -q "^---"; then
    pass "$f has frontmatter"
  else
    fail "$f missing frontmatter"
  fi
  if grep -q "^type: knowledge" "$f"; then
    pass "$f has type: knowledge"
  else
    fail "$f missing type: knowledge"
  fi
  if grep -q "^period:" "$f"; then
    pass "$f has period field"
  else
    fail "$f missing period field"
  fi
done

# ─── Section 8: Lessons file frontmatter and portability ───

section "Lessons file frontmatter validation"

for f in docs/lessons/2*.md; do
  [[ -f "$f" ]] || continue
  if head -1 "$f" | grep -q "^---"; then
    pass "$f has frontmatter"
  else
    fail "$f missing frontmatter"
  fi
  if grep -q "^type: lessons" "$f"; then
    pass "$f has type: lessons"
  else
    fail "$f missing type: lessons"
  fi
  if grep -q "^categories:" "$f"; then
    pass "$f has categories field"
  else
    fail "$f missing categories field"
  fi
done

section "Lessons portability check (no project-specific leakage)"

for f in docs/lessons/2*.md; do
  [[ -f "$f" ]] || continue
  # Check for project-specific references that shouldn't be in portable lessons
  leaks=$(grep -n "silver-bullet\|\.silver-bullet\|silver_bullet\|\.planning/" "$f" 2>/dev/null || true)
  if [[ -z "$leaks" ]]; then
    pass "$f has no project-specific references"
  else
    fail "$f contains project-specific references: $leaks"
  fi
done

# ─── Section 9: INDEX.md accuracy ───

section "Knowledge INDEX.md accuracy"

# Every doc path in INDEX.md should point to an existing file
while IFS= read -r line; do
  # Extract paths like `docs/ARCHITECTURE.md` from markdown table
  path=$(echo "$line" | sed -n 's/.*`\(docs\/[^`]*\)`.*/\1/p' || true)
  [[ -z "$path" ]] && continue
  # Skip directory references and URLs
  [[ "$path" == */ ]] && continue
  if [[ -f "$path" ]]; then
    pass "INDEX.md → $path exists"
  else
    fail "INDEX.md → $path MISSING"
  fi
done < docs/knowledge/INDEX.md

# ─── Section 10: Workflow Documentation step references ───

section "Workflow files reference knowledge/lessons (not KNOWLEDGE.md)"

for f in docs/workflows/full-dev-cycle.md docs/workflows/devops-cycle.md; do
  if grep -q "docs/knowledge/YYYY-MM.md" "$f"; then
    pass "$f references docs/knowledge/"
  else
    fail "$f missing docs/knowledge/ reference"
  fi
  if grep -q "docs/lessons/YYYY-MM.md" "$f"; then
    pass "$f references docs/lessons/"
  else
    fail "$f missing docs/lessons/ reference"
  fi
done

# ─── Section 11: Template parity (workflow files) ───

section "Workflow template parity"

for wf in full-dev-cycle.md devops-cycle.md; do
  if diff -q "docs/workflows/$wf" "templates/workflows/$wf" > /dev/null 2>&1; then
    pass "docs/workflows/$wf matches templates/workflows/$wf"
  else
    fail "docs/workflows/$wf differs from templates/workflows/$wf"
  fi
done

# ─── Section 12: Scalability enforcement documented ───

section "Scalability enforcement in silver-bullet.md"

if grep -q "Scalability Enforcement" silver-bullet.md; then
  pass "silver-bullet.md contains Scalability Enforcement section"
else
  fail "silver-bullet.md missing Scalability Enforcement section"
fi

if grep -q "Scalability Enforcement" templates/silver-bullet.md.base; then
  pass "templates/silver-bullet.md.base contains Scalability Enforcement section"
else
  fail "templates/silver-bullet.md.base missing Scalability Enforcement section"
fi

# ─── Section 13: REVIEW-ROUNDS.md rotation documented ───

section "Review loop scalability"

if grep -q "Rotation at Milestone Completion" skills/artifact-reviewer/rules/review-loop.md; then
  pass "review-loop.md has rotation section"
else
  fail "review-loop.md missing rotation section"
fi

if grep -q "count_lines.*200" skills/artifact-reviewer/rules/review-loop.md; then
  pass "review-loop.md has 200-line rotation cap"
else
  fail "review-loop.md missing 200-line cap"
fi

# ─── Section 14: Consolidated docs in audits/ ───

section "SENTINEL audits archived"

audit_count=$(ls -1 docs/audits/*.md 2>/dev/null | wc -l)
if (( audit_count >= 7 )); then
  pass "docs/audits/ has $audit_count audit files (expected >= 7)"
else
  fail "docs/audits/ has only $audit_count files (expected >= 7)"
fi

if [[ -f docs/SECURITY.md ]]; then
  if grep -q "docs/audits/" docs/SECURITY.md; then
    pass "SECURITY.md references docs/audits/"
  else
    fail "SECURITY.md doesn't reference docs/audits/"
  fi
fi

# ─── Section 15: Internal docs moved ───

section "Non-SDLC docs in internal/"

for f in help-center-guidelines.md site-content-audit.md site-qa-report.md; do
  if [[ -f "docs/internal/$f" ]]; then
    pass "docs/internal/$f exists"
  else
    fail "docs/internal/$f MISSING"
  fi
  if [[ -f "docs/$f" ]]; then
    fail "docs/$f still in top-level (should be in internal/)"
  fi
done

# ─── Results ───

printf "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
printf "Results: %d passed, %d failed, %d total\n" "$PASS" "$FAIL" "$TOTAL"
printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"

if (( FAIL > 0 )); then
  exit 1
else
  printf "\nAll documentation scheme tests passed.\n"
  exit 0
fi
