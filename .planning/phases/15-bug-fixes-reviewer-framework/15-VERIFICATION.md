---
phase: 15-bug-fixes-reviewer-framework
verified: 2026-04-09T13:00:00Z
status: gaps_found
score: 5/6 must-haves verified
re_verification: false
gaps:
  - truth: "A reviewer can be invoked with an artifact path and returns structured findings with PASS or ISSUE severity plus finding descriptions — the interface is consistent across all artifact types"
    status: partial
    reason: "The interface contract is defined and correct (ARFR-01), but the review loop algorithm (ARFR-02) has two correctness defects: (1) apply_fix is called in the pseudocode but is not defined anywhere in the framework — no reviewer, orchestrator, or user knows who is responsible for fixes; (2) save_review_state is called before fixes are applied, so a mid-fix interruption leaves state recording a completed round when fixes were not applied."
    artifacts:
      - path: "skills/artifact-reviewer/rules/review-loop.md"
        issue: "apply_fix(artifact_path, finding) called at line 39 with no definition anywhere in the framework — reviewer-interface.md and SKILL.md do not define it"
      - path: "skills/artifact-reviewer/rules/review-loop.md"
        issue: "save_review_state called before the apply_fix loop (lines 26 vs 39) — state is persisted before fixes are applied, creating session-resume inconsistency"
    missing:
      - "Add apply_fix contract to reviewer-interface.md: who applies fixes (orchestrator, reviewer, or user), what 'applying a fix' means for a prose-based reviewer, and how finding.suggestion drives the fix action"
      - "Move save_review_state call to after the fix loop in the ISSUES_FOUND branch so that state reflects whether fixes were actually applied"
      - "Add the REVIEW-ROUNDS.md commit step to the loop pseudocode — it is documented in Section 3 rules but absent from the algorithm itself"
---

# Phase 15: Bug Fixes & Reviewer Framework Verification Report

**Phase Goal:** All critical v0.14.0 bugs are fixed and a reusable artifact reviewer framework exists — defining the interface, 2-consecutive-pass loop, per-artifact state tracking, and REVIEW-ROUNDS.md audit trail that every reviewer will use
**Verified:** 2026-04-09T13:00:00Z
**Status:** gaps_found
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths (from ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Running silver-ingest with a malicious --source-url does not execute arbitrary commands — input validated against allowed pattern before shell substitution | VERIFIED | `grep -c 'a-zA-Z0-9._-' skills/silver-ingest/SKILL.md` = 1; regex at line 253 blocks non-matching owner/repo before any gh api/curl call |
| 2 | pr-traceability.sh produces correct heredoc output even when WARN findings contain special characters — no command injection possible | VERIFIED | `cat <<TRACE` count = 0; printf count = 7; warn_items passed as positional `%s` argument at line 60 of hooks/pr-traceability.sh |
| 3 | When Confluence ingestion fails, SPEC.md contains `[ARTIFACT MISSING: <reason>]` block at the relevant section — not a note buried in Assumptions | VERIFIED | `grep -c 'ARTIFACT MISSING.*Confluence'` = 2 (inline instruction at line 116 + Failure Handling Summary table); Failure Handling row updated from "note in Assumptions" to inline `[ARTIFACT MISSING]` |
| 4 | When SPEC.main.md is stale, version mismatch block shows side-by-side content diff (not just version numbers) | VERIFIED | `grep -c 'diff --unified'` = 1 in templates/silver-bullet.md.base §5.5; fetches remote SPEC.md and runs `diff --unified=3` before blocking session |
| 5 | A reviewer can be invoked with an artifact path and returns structured findings with PASS or ISSUE severity plus finding descriptions — the interface is consistent across all artifact types | VERIFIED (partial) | reviewer-interface.md defines input/output contract correctly; SKILL.md has mapping table; but loop algorithm has correctness defects (see gaps) |
| 6 | Running a reviewer on an artifact with issues triggers an automated fix-and-re-review loop that terminates only after 2 consecutive PASS results — not just one clean pass | FAILED | review-loop.md documents the 2-consecutive-pass algorithm with `consecutive_passes < 2` termination condition, but `apply_fix` is called in the loop with no definition anywhere in the framework — downstream reviewers have no contract for what fix application means |

**Score:** 5/6 truths verified (Truth 5 partially, Truth 6 fails on wiring completeness)

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `skills/silver-ingest/SKILL.md` | BFIX-01 validation + BFIX-03 Confluence failure path | VERIFIED | regex at line 253; ARTIFACT MISSING instruction at line 116 and Failure Handling table |
| `hooks/pr-traceability.sh` | BFIX-02 printf-safe warn_items | VERIFIED | no heredoc; printf with positional %s for warn_items at line 60 |
| `templates/silver-bullet.md.base` | BFIX-04 content diff on mismatch | VERIFIED | `diff --unified=3` in §5.5 mismatch block |
| `skills/artifact-reviewer/SKILL.md` | ARFR-01 orchestrator with mapping table | VERIFIED | 12-row mapping table, 4 existing + 8 Phase-16 placeholders; loading rules for sub-files |
| `skills/artifact-reviewer/rules/reviewer-interface.md` | ARFR-01 input/output contract | VERIFIED | Input contract (artifact_path, source_inputs, review_context) and output contract (status, findings array) with Finding structure and Reviewer Prohibitions |
| `skills/artifact-reviewer/rules/review-loop.md` | ARFR-02 loop + ARFR-03 state + ARFR-04 audit trail | PARTIAL | Loop algorithm present with 2-pass termination and safety cap; state file format and SHA256 key defined; REVIEW-ROUNDS.md format defined; but apply_fix is undefined and save_review_state ordering is wrong |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| silver-ingest Step 5 | validation block | grep -qE regex before gh api | WIRED | BFIX-01: validation at line 253, skip to Step 7 on failure |
| pr-traceability.sh | warn_items | printf '%s' positional arg | WIRED | BFIX-02: line 60 passes warn_items as last %s — no format-string expansion |
| silver-ingest Step 1 Confluence failure | SPEC.md inline | [ARTIFACT MISSING] instruction | WIRED | BFIX-03: instruction explicit at line 116; Failure Handling Summary table updated |
| silver-bullet.md.base §5.5 mismatch | diff output | gh api + diff --unified=3 + /tmp/spec-remote-diff.md | WIRED | BFIX-04: fetch → diff → display → rm pattern present |
| artifact-reviewer SKILL.md | reviewer-interface.md | @skills loading rules | WIRED | SKILL.md Orchestration Steps reference reviewer-interface.md and review-loop.md |
| review-loop algorithm | apply_fix | (undefined) | NOT WIRED | apply_fix is called but has no contract or definition anywhere in the framework |
| review-loop algorithm | save_review_state | called before fix loop | PARTIAL | State is saved before fixes are applied — wrong ordering for session resume correctness |
| review-loop Section 3 | REVIEW-ROUNDS.md commit | documented in rules but absent from pseudocode | PARTIAL | Section 3 says "Commit REVIEW-ROUNDS.md after review loop completes" but pseudocode has no commit step |

---

### Data-Flow Trace (Level 4)

Not applicable — this phase produces skill/rule documentation and shell hook scripts, not components that render dynamic data.

---

### Behavioral Spot-Checks

Step 7b: SKIPPED — artifact-reviewer is a skill file (Markdown instruction set), not a runnable entry point. Shell hook pr-traceability.sh requires a live gh pr create context to test. Behavioral correctness is verified through code inspection above.

---

### Requirements Coverage

| Requirement | Description | Status | Evidence |
|-------------|-------------|--------|----------|
| BFIX-01 | Shell injection via unvalidated owner/repo in silver-ingest | SATISFIED | Regex validation block in silver-ingest SKILL.md Step 5 before any shell command |
| BFIX-02 | Command injection via unescaped WARN findings in pr-traceability.sh heredoc | SATISFIED | printf with positional %s replaces heredoc; no cat <<TRACE present |
| BFIX-03 | Confluence failure path produces [ARTIFACT MISSING] block not Assumptions note | SATISFIED | Inline instruction at line 116 + Failure Handling Summary updated |
| BFIX-04 | Version mismatch block shows content diff not just version numbers | SATISFIED | diff --unified=3 block in §5.5 |
| ARFR-01 | Standard artifact reviewer interface defined | SATISFIED | reviewer-interface.md with input/output contracts, Finding structure, Reviewer Prohibitions |
| ARFR-02 | 2-consecutive-pass review loop implemented as reusable mechanism | PARTIAL | Algorithm present with correct termination; apply_fix undefined breaks the fix-and-re-review loop completeness |
| ARFR-03 | Review round state tracked per-artifact for session resumption | SATISFIED | SHA256-keyed JSON state files in ~/.claude/.silver-bullet/review-state/ with load/save/clear operations |
| ARFR-04 | Review round results recorded in REVIEW-ROUNDS.md audit trail | SATISFIED | Append-only format documented; co-location rule (same directory as artifact) specified; commit instruction present in Section 3 rules |

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| skills/artifact-reviewer/rules/review-loop.md | 39 | `apply_fix(artifact_path, finding)` — function called but not defined | Blocker | Phase 16/17 reviewers implementing this framework have no contract for fix application; inconsistent implementations guaranteed |
| skills/artifact-reviewer/rules/review-loop.md | 26 | `save_review_state` called before fix loop — state persisted before fixes applied | Warning | Session resume after mid-fix interruption records incorrect round state |
| skills/artifact-reviewer/rules/review-loop.md | 149 | REVIEW-ROUNDS.md commit step documented in Section 3 prose but absent from loop pseudocode | Warning | Inconsistency between the algorithm and its prose spec; implementors following pseudocode will omit the commit |
| skills/artifact-reviewer/SKILL.md | 27-34 | 8 Phase-16 placeholder rows with no fallback behavior for unrecognized artifact paths | Info | Invoking artifact-reviewer on SPEC.md (a Phase-16 type) produces no clear error path |

**Code review status from 15-REVIEW.md:** `issues_found` — 4 warnings, 3 info, 0 critical

---

### Human Verification Required

None — all success criteria are verifiable through code inspection.

---

### Gaps Summary

The four v0.14.0 bugs (BFIX-01 through BFIX-04) are all correctly fixed and verified. The reviewer interface contract (ARFR-01) is complete. Per-artifact state tracking (ARFR-03) and the REVIEW-ROUNDS.md audit trail format (ARFR-04) are fully specified.

The gap is in the review loop mechanism (ARFR-02). The loop algorithm calls `apply_fix(artifact_path, finding)` but this function is not defined anywhere in the three framework files (SKILL.md, reviewer-interface.md, review-loop.md). The code review (15-REVIEW.md, WR-04) identified this: reviewers are read-only by contract, so they cannot apply fixes — but no other actor (orchestrator, user) is assigned responsibility. Without this contract, Phase 16 and Phase 17 reviewers will implement fix application inconsistently. Additionally, `save_review_state` is called before fixes are applied (WR-03), which corrupts session-resume state if a session is interrupted mid-fix. The commit step for REVIEW-ROUNDS.md appears in prose (Section 3) but not in the pseudocode algorithm.

These are correctness defects in the framework spec that Phase 16 will inherit. They should be resolved before Phase 16 builds eight reviewers on top of this framework.

---

_Verified: 2026-04-09T13:00:00Z_
_Verifier: Claude (gsd-verifier)_
