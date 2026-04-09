# Review Loop, State Tracking, and Audit Trail

---

## Section 1: Review Loop Mechanism (ARFR-02)

The review loop runs until 2 consecutive clean PASS results are produced. A single pass is never sufficient.

### Algorithm

```
consecutive_passes = 0
round = 1

# Resume from state if available (ARFR-03)
state = load_review_state(artifact_path)
if state exists:
  consecutive_passes = state.consecutive_passes
  round = state.round
  display "Resuming review of {artifact} from round {round} ({consecutive_passes} consecutive passes so far)"

while consecutive_passes < 2:
  findings = invoke_reviewer(artifact_path, source_inputs)

  record_round(artifact_path, round, findings)  # ARFR-04

  if findings.status == "PASS":
    consecutive_passes += 1
    save_review_state(artifact_path, round, consecutive_passes)  # ARFR-03 — save AFTER status update
    if consecutive_passes < 2:
      display "Clean pass {consecutive_passes}/2. Re-reviewing for confirmation..."
      round += 1
  else:
    consecutive_passes = 0  # Reset on any ISSUE finding
    display "Round {round}: {len(findings.findings)} issue(s) found. Fixing..."

    # Fix each finding — the PRODUCING STEP (not the reviewer) applies fixes.
    # The orchestrator re-invokes the producing step's fix logic with the finding's
    # suggestion field as guidance. The reviewer is read-only and MUST NOT modify artifacts.
    for finding in findings.findings:
      orchestrator_apply_fix(artifact_path, finding)
      # orchestrator_apply_fix: reads finding.suggestion, applies the change to artifact_path,
      # commits atomically. If finding.suggestion is empty, surfaces to user for manual fix.

    save_review_state(artifact_path, round, consecutive_passes)  # ARFR-03 — save AFTER fixes applied

    round += 1

  # Safety cap — surface to user after 5 rounds without 2 consecutive passes
  if round > 5 and consecutive_passes < 2:
    display "Review has not converged after 5 rounds. All accumulated findings:"
    display_all_findings(artifact_path)
    STOP — surface to user for decision
    break

display "2 consecutive clean passes achieved. Review complete."
commit_review_trail(artifact_path)  # Commit REVIEW-ROUNDS.md alongside the artifact
clear_review_state(artifact_path)
```

### Key Rules

- A single clean pass is NOT sufficient — the loop continues until 2 consecutive passes
- Any ISSUE finding resets `consecutive_passes` to 0
- INFO findings do NOT reset the counter (INFO is advisory)
- The loop is self-limiting: it terminates after 2 consecutive PASS results
- If the loop reaches 5 rounds without achieving 2 consecutive passes, surface all accumulated findings to the user

---

## Section 2: Per-Artifact State Tracking (ARFR-03)

State is written after EVERY round so that review sessions can resume across context resets.

### State File Location

```
~/.claude/.silver-bullet/review-state/{artifact-hash}.json
```

Where `{artifact-hash}` = first 8 chars of SHA256 of the artifact's absolute path.

### State File Format

```json
{
  "artifact_path": "/absolute/path/to/artifact.md",
  "reviewer": "reviewer-skill-name",
  "round": 3,
  "consecutive_passes": 1,
  "last_updated": "2026-04-09T12:00:00Z",
  "findings_history": [
    { "round": 1, "status": "ISSUES_FOUND", "finding_count": 2 },
    { "round": 2, "status": "PASS", "finding_count": 0 },
    { "round": 3, "status": "in_progress" }
  ]
}
```

### State Operations

- `load_review_state(artifact_path)` — Read state file if it exists; return null if not present
- `save_review_state(artifact_path, round, consecutive_passes)` — Write/update state file after each round
- `clear_review_state(artifact_path)` — Delete state file after successful 2-pass completion

### Implementation (Shell)

```bash
# State directory
SB_REVIEW_STATE="${HOME}/.claude/.silver-bullet/review-state"
mkdir -p "$SB_REVIEW_STATE"

# Hash for state file (8-char prefix of SHA256 of absolute artifact path)
artifact_hash=$(printf '%s' "$(realpath "$artifact_path")" | shasum -a 256 | cut -c1-8)
state_file="${SB_REVIEW_STATE}/${artifact_hash}.json"

# Load
[ -f "$state_file" ] && cat "$state_file" || echo "null"

# Clear on completion
rm -f "$state_file"
```

---

## Section 3: REVIEW-ROUNDS.md Audit Trail (ARFR-04)

After each round completes, append to `REVIEW-ROUNDS.md` in the same directory as the reviewed artifact.

**Example:** If the artifact is `.planning/SPEC.md`, the audit trail lives at `.planning/REVIEW-ROUNDS.md`.

### Format

```markdown
# Review Rounds

## {artifact filename}

### Round {N} — {ISO timestamp}
- **Reviewer:** {reviewer-skill-name}
- **Status:** {PASS | ISSUES_FOUND}
- **Findings:**
  - {finding.id}: {finding.description} [{finding.severity}]
  - ...
  (or "No issues found" if PASS)
- **Consecutive clean passes:** {count}/2

---
```

### Rules

- REVIEW-ROUNDS.md is **append-only** during a review session — never truncate prior rounds
- Each artifact gets its own section identified by `## {artifact filename}` header
- If REVIEW-ROUNDS.md already contains rounds for this artifact from a prior session, append new rounds after the last existing one
- Commit REVIEW-ROUNDS.md alongside the artifact after the review loop completes (2 clean passes achieved)
