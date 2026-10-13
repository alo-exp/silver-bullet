---
phase: 12-spec-foundation
reviewed: 2026-04-09T00:00:00Z
depth: standard
files_reviewed: 7
files_reviewed_list:
  - hooks/spec-floor-check.sh
  - skills/silver-spec/SKILL.md
  - templates/specs/SPEC.md.template
  - templates/specs/DESIGN.md.template
  - templates/specs/REQUIREMENTS.md.template
  - skills/silver/SKILL.md
  - templates/silver-bullet.md.base
findings:
  critical: 0
  warning: 3
  info: 4
  total: 7
status: issues_found
---

# Phase 12: Code Review Report

**Reviewed:** 2026-04-09
**Depth:** standard
**Files Reviewed:** 7
**Status:** issues_found

## Summary

Phase 12 introduces spec templates, a Bash enforcement hook, an elicitation skill, and routing/doc wiring. The implementation is structurally sound and follows established boilerplate patterns correctly. No security vulnerabilities or data-loss risks were found. The three warnings represent correctness concerns: a command detection regex that can produce false positives, a missing-anchor grep that may produce false negatives, and a missing `set -o pipefail` coverage gap inside a pipeline. Four info items cover template gaps and minor quality issues.

---

## Warnings

### WR-01: Command detection regex matches substrings — false positive risk

**File:** `hooks/spec-floor-check.sh:44`

**Issue:** The regex `\bgsd-plan-phase\b|\bgsd[- ]plan[- ]phase\b` uses word boundaries (`\b`), but in POSIX ERE (used by `grep -E`) `\b` is not guaranteed to be a word boundary — it is treated as a literal `\b` escape in some grep implementations (notably macOS/BSD grep). If `\b` is silently discarded, the pattern degrades to `gsd-plan-phase` with no boundary guard, which would match a command like `echo "not-gsd-plan-phase"` or `# gsd-plan-phase docs`. This would trigger a false block when a Bash tool call merely mentions the command in a comment or string, not invokes it.

**Fix:** Replace `\b` anchors with explicit non-word-character anchors that are portable in ERE, or anchor the match to the start of the command token:

```bash
# Option A: anchor to start-of-string or whitespace boundary (portable)
if printf '%s' "$cmd" | grep -qE '(^|[[:space:]])gsd-plan-phase([[:space:]]|$)'; then

# Option B: check for the command as the first token (stricter, but covers most real usage)
if printf '%s' "$cmd" | grep -qE '^[[:space:]]*gsd-plan-phase([[:space:]]|$)'; then
```

The same issue applies to the `gsd-fast`/`gsd-quick` branch on line 46.

---

### WR-02: Section presence check uses anchored grep but anchor character is a shell variable — correctness risk

**File:** `hooks/spec-floor-check.sh:63`

**Issue:** The loop checks `grep -q "^${section}" "$SPEC"`. The `^` anchor is inside a double-quoted string, but `section` is set from a literal: `"## Overview"`. This is functionally correct. However, if `section` ever contains characters with special meaning in BRE/ERE (e.g., brackets, dots), the grep pattern would silently malform. More concretely: `grep -q "^## Overview"` matches `## Overview` at the start of any line — it does NOT require the section to be on its own line (no trailing `$` anchor). A file containing `## Overview — draft` would pass, which is intentional, but a file containing `## Overviewer` would also pass. This is unlikely with the current template but is a latent correctness gap.

**Fix:** Add a trailing word boundary or space check to tighten the match:

```bash
for section in "## Overview" "## Acceptance Criteria"; do
  if ! grep -q "^${section}[[:space:]]*$" "$SPEC"; then
```

This ensures the heading is exactly the section header and not a longer string that happens to start with the expected text.

---

### WR-03: SKILL.md Step 10 git add does not stage REQUIREMENTS.md path-safely

**File:** `skills/silver-spec/SKILL.md:207`

**Issue:** The commit block stages `.planning/DESIGN.md` with `2>/dev/null || true` to suppress errors when the file doesn't exist — correct. But `.planning/REQUIREMENTS.md` is staged unconditionally alongside `.planning/SPEC.md`. If Step 8 is somehow skipped (e.g., the user aborts mid-workflow and restarts at Step 10), the `git add` for REQUIREMENTS.md will stage a stale or absent file without surfacing an error, silently producing an incomplete commit.

**Fix:** Verify REQUIREMENTS.md exists before staging, analogous to the DESIGN.md pattern:

```bash
git add .planning/SPEC.md
git add .planning/REQUIREMENTS.md 2>/dev/null || true
git add .planning/DESIGN.md 2>/dev/null || true
git commit -m "spec: [feature-slug] v{spec-version} draft"
```

Alternatively, add a pre-commit check: verify both SPEC.md and REQUIREMENTS.md exist before reaching Step 10.

---

## Info

### IN-01: REQUIREMENTS.md template lacks YAML frontmatter

**File:** `templates/specs/REQUIREMENTS.md.template:1`

**Issue:** `SPEC.md.template` and `DESIGN.md.template` both use YAML frontmatter blocks. `REQUIREMENTS.md.template` starts directly with a `# Requirements:` heading and uses inline bold text (`**Derived from:**`) for metadata. This inconsistency means downstream hooks or tooling that expect to parse frontmatter from all spec artifacts will fail silently on REQUIREMENTS.md.

**Fix:** Add a minimal YAML frontmatter block matching the other templates:

```yaml
---
spec-version: 1
linked-spec: .planning/SPEC.md
generated: YYYY-MM-DD
---
```

---

### IN-02: DESIGN.md template missing `created:` frontmatter field

**File:** `templates/specs/DESIGN.md.template:4`

**Issue:** `SPEC.md.template` frontmatter includes both `created:` and `last-updated:`. `DESIGN.md.template` has only `last-updated:`. When silver-spec Step 9 populates DESIGN.md, there is no field to record the initial creation date. This makes it impossible to detect augment-mode DESIGN.md updates consistently.

**Fix:** Add `created: YYYY-MM-DD` to DESIGN.md.template frontmatter, between `figma-url:` and `last-updated:`:

```yaml
figma-url: ""
created: YYYY-MM-DD
last-updated: YYYY-MM-DD
```

---

### IN-03: SKILL.md references a non-skippable gate (Step 3) but elicitation has no minimum turn enforcement

**File:** `skills/silver-spec/SKILL.md:38-39`

**Issue:** The Step-Skip Protocol declares Step 3 non-skippable. However, Step 3 itself is a 9-turn sequence with no explicit "minimum turns required" rule. An orchestrator (or a PM with urgent deadlines) could interpret "non-skippable" as "we must enter Step 3" while still short-circuiting individual turns. The warning at line 115 ("A completed elicitation with zero ASSUMPTION blocks is suspicious") is advisory, not gating. There is no instruction to refuse a commit if, say, Turn 5 (Acceptance Criteria) was skipped.

**Fix:** Add an explicit guard before Step 7 (which IS non-skippable) that validates at minimum Turn 5 (AC) and Turn 1 (Problem) were answered, since these directly map to the spec-floor-check.sh requirements:

```
Before writing SPEC.md, verify:
- Turn 1 (Problem) produced an answer → populate ## Overview
- Turn 5 (Acceptance Criteria) produced at least one criterion → populate ## Acceptance Criteria
If either is empty, refuse to write SPEC.md and return to the missing turn.
```

---

### IN-04: hooks.json registration is pending (Task 3 checkpoint unresolved)

**File:** `hooks/hooks.json` (not yet modified)

**Issue:** Plan 12-03 summary explicitly documents Task 3 as "Checkpoint — user action required" with no commit. The hook file `spec-floor-check.sh` exists and is correct, but it is not registered in `hooks.json` and therefore does not run. The spec-floor enforcement described in silver-bullet.md.base §2i is non-functional until registration is completed.

**Fix:** Complete hooks.json registration. The entry should follow the pattern of other PreToolUse hooks in the file (matcher: `Bash`, command: path to `spec-floor-check.sh`). This is a known stub tracked in the plan, but it represents a gap between documented behavior and actual behavior.

---

_Reviewed: 2026-04-09_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
