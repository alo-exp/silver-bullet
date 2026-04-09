---
phase: 15-bug-fixes-reviewer-framework
reviewed: 2026-04-09T12:02:26Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - skills/silver-ingest/SKILL.md
  - hooks/pr-traceability.sh
  - templates/silver-bullet.md.base
  - skills/artifact-reviewer/SKILL.md
  - skills/artifact-reviewer/rules/reviewer-interface.md
  - skills/artifact-reviewer/rules/review-loop.md
findings:
  critical: 0
  warning: 4
  info: 3
  total: 7
status: issues_found
---

# Phase 15: Code Review Report

**Reviewed:** 2026-04-09T12:02:26Z
**Depth:** standard
**Files Reviewed:** 6
**Status:** issues_found

## Summary

This phase delivers four targeted bug fixes (BFIX-01 through BFIX-04) and the artifact-reviewer framework (ARFR-01 through ARFR-04). The bug fixes are substantively correct — BFIX-01 closes the shell injection path, BFIX-02 eliminates the heredoc expansion vector, and BFIX-03 improves Confluence failure visibility. BFIX-04 (version-mismatch diff) is implemented correctly but has one residual security concern.

The reviewer framework (SKILL.md + rules files) is internally consistent and well-structured. However there are gaps in the interface contract and loop algorithm that could cause incorrect behavior: the loop's fix step is delegated without a concrete mechanism, the `save_review_state` call in the algorithm has an ordering defect, and the REVIEW-ROUNDS.md commit step is underspecified.

---

## Warnings

### WR-01: BFIX-01 — validation regex permits dot in owner/repo, enabling path traversal in `gh api` URL

**File:** `skills/silver-ingest/SKILL.md:253`
**Issue:** The BFIX-01 regex `^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$` allows dots in both the owner and repo segments. A crafted input like `../admin/secret-repo` does not pass the regex (the leading `../` is caught), but a value like `owner/..` does pass (dot-only repo segment `..` is two dots, matched by `[._-]+`). More concretely, `a./b..` matches the pattern. If `{owner}` or `{repo}` expand to values like `repos/..` the composite path passed to `gh api repos/{owner}/{repo}/contents/...` could traverse up. GitHub's API server would reject such a request, but this is a defense-in-depth concern — the validation should be tighter.
**Fix:**
```bash
# Reject any segment that is purely dots (. or ..)
if ! printf '%s' "{owner}/{repo}" | grep -qE '^[a-zA-Z0-9][a-zA-Z0-9._-]*/[a-zA-Z0-9][a-zA-Z0-9._-]*$'; then
  echo "ERROR: Invalid repository identifier."
fi
# Separately reject dot-only segments
if printf '%s' "{owner}/{repo}" | grep -qE '(^|/)\.*(/|$)'; then
  echo "ERROR: Repository segments must not be purely dots."
fi
```
Requiring each segment to start with an alphanumeric character eliminates dot-only and dot-leading segments.

---

### WR-02: BFIX-02 — `warn_items` is not sanitized before insertion into PR body string

**File:** `hooks/pr-traceability.sh:60`
**Issue:** `warn_items` is populated by grepping VALIDATION.md for raw finding lines (`grep 'FINDING \[WARN\]' .planning/VALIDATION.md`). Its content is then interpolated directly into the `printf` format string via `%s`. If a VALIDATION.md line contains printf format specifiers such as `%s`, `%d`, or `%n`, they will be interpreted by `printf`, causing garbled output or (in the `%n` case) undefined behavior depending on the shell's printf implementation. The fix used (`printf '\n---\n...\n%s' ... "${warn_items}"`) is correct for the trailing argument, but only because `%s` is the last conversion. If the format string is ever extended, this invariant could silently break.
**Fix:** Use a safer pattern to make the dependency on argument ordering explicit and document it:
```bash
# warn_items may contain arbitrary text from VALIDATION.md — always pass as positional arg to %s
# Never embed warn_items directly in the format string
traceability_block=$(printf '%s' "$warn_items_prefix"; printf '%s\n' "${warn_items:-None}")
```
Or alternatively, escape percent signs in `warn_items` before use:
```bash
warn_items_safe="${warn_items//%/%%}"
```

---

### WR-03: review-loop.md — `save_review_state` is called before the fix step, so state reflects round N before fixes are applied

**File:** `skills/artifact-reviewer/rules/review-loop.md:25-41`
**Issue:** The algorithm calls `save_review_state(artifact_path, round, consecutive_passes)` before the `apply_fix` loop. If the session is interrupted mid-fix, the saved state records `round` and `consecutive_passes` as if the round completed normally, but the fixes were not applied. On resume, the loop will re-review an artifact that was only partially fixed, with the state incorrectly reporting it as having completed round N. This creates a silent state inconsistency: the resume display would show "round {N+1}" with `consecutive_passes` at its pre-fix value, but the artifact may be in a partially-fixed state.

Additionally, the `save_review_state` call passes `consecutive_passes` after it has been reset to 0 (in the ISSUES_FOUND branch), which is correct, but the state written does not record _which_ fixes were applied — making partial fix resumption impossible.

**Fix:** Move `save_review_state` to after the fix loop, and add a `fixes_applied` field to the state:
```
  if findings.status == "PASS":
    consecutive_passes += 1
    save_review_state(artifact_path, round, consecutive_passes)
    ...
  else:
    consecutive_passes = 0
    for finding in findings.findings:
      apply_fix(artifact_path, finding)
    save_review_state(artifact_path, round, consecutive_passes)  # After fixes
    round += 1
```

---

### WR-04: review-loop.md — `apply_fix` is invoked in the loop algorithm but is not defined anywhere in the framework

**File:** `skills/artifact-reviewer/rules/review-loop.md:39`
**Issue:** The loop pseudocode calls `apply_fix(artifact_path, finding)` with no definition of what this function does, who implements it, or how it is dispatched. There is no mention of `apply_fix` in `reviewer-interface.md` or `SKILL.md`. Because reviewers are "strictly read-only" (reviewer-interface.md line 57), reviewers cannot apply fixes. It is unclear whether the orchestrator, the reviewer, or the user is responsible for applying fixes. This ambiguity will lead to inconsistent implementations.

Additionally, the `REVIEW-ROUNDS.md` commit step mentioned in `review-loop.md` line 149 ("Commit REVIEW-ROUNDS.md alongside the artifact after the review loop completes") is not represented in the loop algorithm pseudocode at all — the algorithm has no commit step, making it incomplete.

**Fix:** Add an explicit `apply_fix` contract to the framework, clarifying who is responsible. For example:
```
# In reviewer-interface.md, add:
## Fix Responsibility
The orchestrator (artifact-reviewer) is responsible for applying fixes, NOT the reviewer.
The orchestrator interprets finding.suggestion and either:
  (a) applies the fix itself (for mechanical changes), or
  (b) delegates to the user with a prompt.
Reviewers MUST NOT modify the artifact.

# In review-loop.md, after the while loop, add:
git add "{artifact_path}" "{audit_trail_path}"
git commit -m "review: {reviewer} — {N} rounds, 2 clean passes"
```

---

## Info

### IN-01: BFIX-03 — Confluence failure placement rule is documented but not machine-enforceable

**File:** `skills/silver-ingest/SKILL.md:116`
**Issue:** BFIX-03 adds the instruction "Do NOT bury the failure in the Assumptions section — it must appear inline at the point where the content was expected." This is the right rule, but it is expressed as a prose guideline only. There is no validation step or check in the workflow that verifies this placement. A future reviewer cannot detect a violation automatically. Consider adding this as a named invariant in the Failure Handling Summary table (already present at the bottom of the file) so it is checkable during spec validation.

---

### IN-02: BFIX-04 — `/tmp` file left behind if `gh api` call fails mid-pipeline

**File:** `templates/silver-bullet.md.base:82-84`
**Issue:** The diff snippet writes to `/tmp/spec-remote-diff.md` and then runs `rm -f /tmp/spec-remote-diff.md`. If the pipeline is killed between the write and the `rm`, the file remains. This is a low-severity temporary-file leak (contents are a SPEC.md, not secret). The pattern is also not atomic — a race exists between write and read. Using `mktemp` and a `trap` cleanup is more robust for a session-startup check.
**Fix:**
```bash
tmp_spec=$(mktemp)
trap 'rm -f "$tmp_spec"' EXIT
/opt/homebrew/bin/gh api repos/{owner}/{repo}/contents/.planning/SPEC.md --jq '.content' | base64 -d > "$tmp_spec"
diff --unified=3 .planning/SPEC.main.md "$tmp_spec" || true
```

---

### IN-03: artifact-reviewer/SKILL.md — mapping table has 8 "Phase 16" placeholder rows with no fallback behavior documented

**File:** `skills/artifact-reviewer/SKILL.md:28-34`
**Issue:** The mapping table lists 8 artifact types as "(Phase 16) — Not yet implemented". The orchestration steps do not describe what the framework does if an unrecognized artifact pattern is passed. Should it error? Warn and fall back to a generic reviewer? Prompt the user? Without a documented fallback, invoking `artifact-reviewer` on a SPEC.md will silently mismatch with no clear error path.
**Fix:** Add a "no matching reviewer" handling clause to the Orchestration Steps:
```
3. Auto-detect or validate reviewer from mapping table
   - If no reviewer is found and --reviewer was not provided:
     STOP with: "No reviewer configured for {artifact}. Use --reviewer to specify one explicitly."
   - If --reviewer is explicitly provided but not a known skill, warn and proceed.
```

---

_Reviewed: 2026-04-09T12:02:26Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
