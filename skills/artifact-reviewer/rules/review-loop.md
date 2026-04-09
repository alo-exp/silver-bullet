# Review Loop, State Tracking, and Audit Trail

---

## Section 1: Review Loop Mechanism (ARFR-02)

The review loop runs until the required number of consecutive clean PASS results are produced. The required pass count depends on the configured depth for the reviewer.

### Depth Resolution

At the start of the review loop, resolve the depth for this reviewer:

1. Read `.planning/config.json` and look up `review_depth[reviewer_skill_name]`
2. If no entry exists for this reviewer in `review_depth`, default to `"standard"` (per ARVW-11e)
3. If no `review_depth` key exists in config.json, default to `"standard"` for all reviewers
4. If `.planning/config.json` does not exist, default to `"standard"` for all reviewers

Depth semantics:
- `deep`: full QC checks + 2 consecutive clean passes required (per ARVW-11b)
- `standard`: full QC checks + 1 clean pass required (per ARVW-11c) — **THIS IS THE DEFAULT**
- `quick`: structural checks only + 1 pass required (per ARVW-11d)

### Algorithm

```
consecutive_passes = 0
round = 1

# Resolve depth from config (ARVW-11a, ARVW-11e)
depth = resolve_depth(reviewer_skill_name)
required_passes = 2 if depth == "deep" else 1
check_mode = "structural" if depth == "quick" else "full"

display "Reviewing {artifact} at {depth} depth (requires {required_passes} consecutive clean pass(es))"

# Resume from state if available (ARFR-03)
state = load_review_state(artifact_path)
if state exists:
  consecutive_passes = state.consecutive_passes
  round = state.round
  display "Resuming review of {artifact} from round {round} ({consecutive_passes} consecutive passes so far)"

while consecutive_passes < required_passes:
  findings = invoke_reviewer(artifact_path, source_inputs, check_mode)

  record_round(artifact_path, round, findings)  # ARFR-04

  if findings.status == "PASS":
    consecutive_passes += 1
    save_review_state(artifact_path, round, consecutive_passes)  # ARFR-03 — save AFTER status update
    if consecutive_passes < required_passes:
      display "Clean pass {consecutive_passes}/{required_passes}. Re-reviewing for confirmation..."
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

  # Safety cap — surface to user after 5 rounds without required consecutive passes
  if round > 5 and consecutive_passes < required_passes:
    display "Review has not converged after 5 rounds. All accumulated findings:"
    display_all_findings(artifact_path)
    STOP — surface to user for decision
    break

display "Review complete at {depth} depth. {required_passes} consecutive clean pass(es) achieved."
commit_review_trail(artifact_path)  # Commit REVIEW-ROUNDS.md alongside the artifact
clear_review_state(artifact_path)
```

#### resolve_depth(reviewer_skill_name)

```
function resolve_depth(reviewer_skill_name):
  if .planning/config.json does not exist:
    return "standard"
  config = load_json(".planning/config.json")
  if "review_depth" not in config:
    return "standard"
  return config["review_depth"].get(reviewer_skill_name, "standard")
```

### Key Rules

- The required number of consecutive clean passes depends on depth: deep=2, standard=1, quick=1
- Any ISSUE finding resets `consecutive_passes` to 0
- INFO findings do NOT reset the counter (INFO is advisory)
- The loop is self-limiting: it terminates after `required_passes` consecutive PASS results
- If the loop reaches 5 rounds without achieving `required_passes` consecutive passes, surface all accumulated findings to the user
- When `check_mode` is `"structural"`, reviewers MUST skip content quality checks and only validate section presence and format validity (per ARVW-11d)
- Default depth is `"standard"` for all artifact types when `review_depth` is absent or does not contain an entry for the reviewer (per ARVW-11e)

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
- `clear_review_state(artifact_path)` — Delete state file after successful completion

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
- **Depth:** {depth}
- **Check mode:** {check_mode}
- **Status:** {PASS | ISSUES_FOUND}
- **Findings:**
  - {finding.id}: {finding.description} [{finding.severity}]
  - ...
  (or "No issues found" if PASS)
- **Consecutive clean passes:** {count}/{required_passes}

---
```

### Rules

- REVIEW-ROUNDS.md is **append-only** during a review session — never truncate prior rounds
- Each artifact gets its own section identified by `## {artifact filename}` header
- If REVIEW-ROUNDS.md already contains rounds for this artifact from a prior session, append new rounds after the last existing one
- Commit REVIEW-ROUNDS.md alongside the artifact after the review loop completes (required consecutive clean passes achieved)
