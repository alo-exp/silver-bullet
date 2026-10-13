---
phase: skills-review
reviewed: 2026-04-20T00:00:00Z
depth: deep
files_reviewed: 29
files_reviewed_list:
  - skills/silver/SKILL.md
  - skills/silver-bugfix/SKILL.md
  - skills/silver-create-release/SKILL.md
  - skills/silver-devops/SKILL.md
  - skills/silver-fast/SKILL.md
  - skills/silver-feature/SKILL.md
  - skills/silver-forensics/SKILL.md
  - skills/silver-ingest/SKILL.md
  - skills/silver-init/SKILL.md
  - skills/silver-migrate/SKILL.md
  - skills/silver-quality-gates/SKILL.md
  - skills/silver-release/SKILL.md
  - skills/silver-research/SKILL.md
  - skills/silver-spec/SKILL.md
  - skills/silver-ui/SKILL.md
  - skills/silver-update/SKILL.md
  - skills/silver-validate/SKILL.md
  - skills/silver-blast-radius/SKILL.md
  - skills/devops-quality-gates/SKILL.md
  - skills/devops-skill-router/SKILL.md
  - skills/security/SKILL.md
  - skills/testability/SKILL.md
  - skills/usability/SKILL.md
  - skills/reliability/SKILL.md
  - skills/scalability/SKILL.md
  - skills/modularity/SKILL.md
  - skills/reusability/SKILL.md
  - skills/extensibility/SKILL.md
  - skills/ai-llm-safety/SKILL.md
findings:
  critical: 2
  warning: 5
  info: 3
  total: 10
status: issues_found
---

# Skills Code Review Report

**Reviewed:** 2026-04-20
**Depth:** deep
**Files Reviewed:** 29
**Status:** issues_found

## Summary

Reviewed all 29 listed skill SKILL.md files. The v0.23.6 additions (semver validation in `silver-update` and tag signing in `silver-create-release`) are structurally sound with one critical ordering bug in the signature-verification logic that will cause all unsigned tag installs to hard-abort rather than warn-and-continue. A second critical finding is a dimension mismatch between what `silver-devops` advertises (observability, change-safety) and what `devops-quality-gates` actually evaluates (reusability, extensibility). No `review-loop-pass` marker references were found in `silver-quality-gates`. All cross-skill references resolve to real directories. Frontmatter is present and valid in all reviewed skills.

---

## Critical Issues

### CR-01: `silver-update` Step 5 — Unsigned tag triggers abort instead of warn-and-continue

**File:** `skills/silver-update/SKILL.md:154-157`

**Issue:** The signature-check evaluation order causes all unsigned annotated tags to trigger the ABORT path. The three-branch logic is:

```
Line 154: if VERIFY_OUT contains "Good signature" → SIGNED ✅, proceed
Line 155: if VERIFY_OUT contains "error" OR "BAD signature" → INVALID ❌, abort
Line 157: if VERIFY_OUT contains "no signature" or is empty → UNSIGNED ⚠️, warn+continue
```

When `git tag -v` runs against an unsigned annotated tag, its actual output is:

```
error: no signature found
```

This string contains both `"error"` and `"no signature"`. Because the `"error"` branch (line 155) is evaluated before the `"no signature"` branch (line 157), every unsigned tag triggers the ABORT path — blocking all Silver Bullet updates since the existing tags are not GPG/SSH signed.

**Fix:** Reorder the checks so `"no signature"` is tested before the generic `"error"` test:

```
if VERIFY_OUT contains "Good signature" → SIGNED ✅, proceed
if VERIFY_OUT contains "no signature" or is empty → UNSIGNED ⚠️, warn+continue
if VERIFY_OUT contains "BAD signature" → INVALID ❌, abort
if VERIFY_OUT contains "error" (excluding "no signature found") → INVALID ❌, abort
```

Or equivalently, treat the `"error: no signature found"` substring as the UNSIGNED case by checking for `"no signature"` before `"error"`:

```bash
if echo "$VERIFY_OUT" | grep -q "Good signature"; then
  # SIGNED ✅
elif echo "$VERIFY_OUT" | grep -q "no signature"; then
  # UNSIGNED ⚠️ — warn, ask user, continue if confirmed
elif echo "$VERIFY_OUT" | grep -qE "BAD signature|error"; then
  # INVALID ❌ — abort
fi
```

---

### CR-02: `silver-devops` Step 3 advertises dimensions that `devops-quality-gates` does not evaluate

**File:** `skills/silver-devops/SKILL.md:17` and `skills/silver-devops/SKILL.md:128`

**Issue:** `silver-devops` tells users — in both its header section and Step 3 description — that the 7 IaC quality dimensions are:

> reliability, security, scalability, modularity, testability, **observability**, **change-safety**

But `devops-quality-gates/SKILL.md` (the skill actually invoked at Step 3 and Step 10) loads and evaluates:

> modularity, **reusability**, scalability, security, reliability, testability, **extensibility**

The mismatched dimensions (`observability` and `change-safety` vs `reusability` and `extensibility`) mean users reading `silver-devops` have incorrect expectations about what gates are applied. A team relying on the advertised `observability` gate at the pre-plan stage will receive no observability checks at all.

**Fix:** Align the description in `silver-devops` to match what `devops-quality-gates` actually implements, OR update `devops-quality-gates` to add observability and change-safety dimensions and remove reusability and extensibility as inapplicable to IaC. The latter is the more correct choice given the IaC context. Choose one and make both files agree.

```
# In silver-devops SKILL.md lines 17 and 128, change:
reliability, security, scalability, modularity, testability, observability, change-safety

# to match what devops-quality-gates actually loads:
modularity, reusability, scalability, security, reliability, testability, extensibility

# Or update devops-quality-gates to implement the advertised 7:
# observability and change-safety are IaC-relevant; reusability and extensibility less so
```

---

## Warnings

### WR-01: `silver-create-release` Step 6 — `git tag -s` not listed in Allowed Commands

**File:** `skills/silver-create-release/SKILL.md:24-25` and `skills/silver-create-release/SKILL.md:157`

**Issue:** The Allowed Commands section lists `git tag` (for unsigned tag creation) but does not list `git tag -s` (for signed tag creation). Step 6 conditionally executes `git tag -s <version> -m "Release <version>"` when a signing key is configured. An LLM executing this skill against a strict allowed-list interpretation would be unable to create a signed tag because the `-s` flag variant is not declared.

**Fix:** Add `git tag -s` (or `git tag [-s]`) to the Allowed Commands section:

```
- `git tag [-s]` (create tag, optionally signed with -s when signing key is configured)
```

---

### WR-02: `silver-create-release` Step 5 — description says "mentions the new version" but command only checks file presence

**File:** `skills/silver-create-release/SKILL.md:133-144`

**Issue:** The prose in Step 5 says:

> "verify that README.md **mentions the new version** or has been updated in the commits since the last tag"

But the command executed is:

```
git log <last-tag>..HEAD --name-only -- README.md
```

This command checks whether `README.md` appears in any commit diff since the last tag — it does NOT verify that the file contains the new version string. The README in this repo has no "Current version" section; the only version reference is inside a JSON snippet. The stated intent ("mentions the new version") cannot be verified by the given command. This creates a false assurance — if someone touches README for an unrelated reason, the check passes even if no version is updated.

**Fix:** Either (a) remove the misleading "mentions the new version" clause and state only that README must be touched, or (b) add a second check that scans the README content for the version string:

```bash
# Check README was modified AND contains new version string
git log <last-tag>..HEAD --name-only -- README.md | grep -q README.md || warn
grep -qF "$NEW_VERSION" README.md || warn "README.md does not mention $NEW_VERSION"
```

---

### WR-03: `silver-init` has duplicate step number `1.6` for two distinct steps

**File:** `skills/silver-init/SKILL.md:175` and `skills/silver-init/SKILL.md:198`

**Issue:** Two separate dependency-check steps are both numbered `### 1.6`:

- Line 175: `### 1.6 v1 incompatibility check`
- Line 198: `### 1.6 MultAI plugin`

This creates navigation ambiguity. An LLM following the numbered sequence would have no clear signal that these are two distinct steps.

**Fix:** Renumber so the v1 incompatibility check is `1.6` and MultAI becomes `1.7`, shifting subsequent steps to `1.8` and `1.9`:

```
### 1.6 v1 incompatibility check  (keep as-is)
### 1.7 MultAI plugin              (was 1.6)
### 1.8 Anthropic Engineering plugin  (was 1.7)
### 1.9 Anthropic Product Management plugin  (was 1.8)
```

---

### WR-04: `silver-init` — Duplicate `### Scripts` section with copy-pasted content

**File:** `skills/silver-init/SKILL.md:557-564`

**Issue:** The Additional Resources section at the end of the file has two identical `### Scripts` subsections (lines 557-564), each listing the same `merge-hooks.py` entry. Additionally, `references/stack-detection.md` is listed under both `### Reference Files` and the first `### Scripts` section — it belongs only under References.

**Fix:** Remove the duplicate `### Scripts` block entirely (lines 562-564), and remove the `references/stack-detection.md` line from the first Scripts block (line 560) since it already appears in the Reference Files section.

---

### WR-05: `silver-update` Step 2 — semver validation block positioning is correct but `exit` terminates without cleanup

**File:** `skills/silver-update/SKILL.md:44-54`

**Issue:** The semver validation block (Step 2) correctly validates `$LATEST` with `^[0-9]+\.[0-9]+\.[0-9]+$` before any path construction or git operations. The regex is syntactically valid for bash `[[ =~ ]]`. The position (after curl, before version comparison) is correct.

However, the validation failure path calls `exit` without an established cleanup context — at this point no `$NEW_CACHE` directory has been created, so this is safe. The concern is that a future refactor could move the validation block later (after clone) without noticing that `exit` now leaks a half-cloned directory. A defensive note would prevent this regression.

**Fix:** Add a comment noting the cleanup precondition:

```bash
# NOTE: No cleanup needed here — $NEW_CACHE has not been created yet.
# If moving this validation block after the clone step, add cleanup logic.
if [[ -z "$LATEST" ]] || ! [[ "$LATEST" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "GitHub returned an unexpected version string: '${LATEST:-<empty>}'"
  echo "Expected semver format (e.g. 0.23.6). Aborting to prevent path/ref corruption."
  exit
fi
```

---

## Info

### IN-01: `files_to_read` requested `skills/silver-bullet/SKILL.md` — this directory does not exist

**File:** (review request config)

**Issue:** The review request listed `skills/silver-bullet/SKILL.md` in the required reading list. The actual top-level orchestrator skill lives at `skills/silver/SKILL.md` (name: `silver`). There is no `skills/silver-bullet/` directory. This is a documentation/reference error in the review request, not in the codebase. The `skills/silver/SKILL.md` was read instead.

**Fix:** Update any internal documentation or review config that references `skills/silver-bullet/SKILL.md` to use `skills/silver/SKILL.md`.

---

### IN-02: `silver-quality-gates` — no `review-loop-pass` marker references found

**File:** `skills/silver-quality-gates/SKILL.md`

**Issue:** Confirmed clean. No `review-loop-pass`, `review_loop_pass`, or similar marker references are present anywhere in `silver-quality-gates/SKILL.md`. The skill uses only the standard PASS/FAIL gate pattern. This is the expected state per v0.23.6 requirements.

---

### IN-03: `silver-devops` Step 7 omits the `/code-review` criteria step present in `silver-feature`

**File:** `skills/silver-devops/SKILL.md:153-158`

**Issue:** `silver-feature` Step 9a2 and `silver-bugfix` Step 5 both invoke `/code-review` to establish review criteria before running `gsd-code-review`. `silver-devops` Step 7 skips this and goes directly from `silver:request-review` to `gsd-code-review`. This is a workflow inconsistency across the orchestrator family. It is not a functional error (gsd-code-review works without the criteria step) but it weakens the review gate for IaC changes.

**Fix:** Consider adding the `/code-review` criteria step to `silver-devops` Step 7 for consistency:

```
1. Invoke `silver:request-review` (superpowers:requesting-code-review) via the Skill tool.
2. Invoke `/code-review` via the Skill tool. Purpose: establish review criteria for IaC changes.
3. Invoke `gsd-code-review` via the Skill tool. If issues found: invoke `gsd-code-review-fix`.
```

---

_Reviewed: 2026-04-20_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: deep_
