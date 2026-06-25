# Review Loop, State Tracking, and Audit Trail

---

## Section 1: Review Loop Mechanism (ARFR-02)

The review loop runs until the configured number of consecutive clean PASS results are produced (`required_passes`; depth-dependent — see artifact-reviewer SKILL.md). A single pass is never sufficient when `required_passes` is 2.

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

depth = resolve_depth(reviewer_skill_name)
required_passes = 2 if depth == "deep" else 1
check_mode = "structural" if depth == "quick" else "full"

while consecutive_passes < required_passes:
  round_start = current_time()  # ARVW-10a/10d: timing start
  findings = invoke_reviewer(artifact_path, source_inputs, check_mode)

  record_round(artifact_path, round, findings)  # ARFR-04

  duration = current_time() - round_start  # ARVW-10a/10d: compute duration
  # ARVW-10a/10d: emit per-round metric
  emit_review_metric(artifact_path, reviewer_skill_name, round, len(findings.findings), findings.status, depth, check_mode, duration)

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
    STOP — surface to user for decision and exit review loop without success commit/clear
    return NON_CONVERGED

display "{required_passes} consecutive clean pass(es) achieved. Review complete."
commit_review_trail(artifact_path)  # Commit REVIEW-ROUNDS.md alongside the artifact
clear_review_state(artifact_path)

# Verification gate — no completion claim without fresh evidence
invoke /silver:completion-audit or /silver:verify as appropriate for the artifact
# The producing step is NOT done until verification confirms the artifact
# meets its acceptance criteria with fresh, run-the-command evidence.
# This prevents "review passed → step complete" shortcuts where the
# orchestrator trusts the review result without independent verification.
```

### Key Rules

- A single clean pass is NOT sufficient when `required_passes` is 2 — the loop continues until `required_passes` consecutive passes
- Any ISSUE finding resets `consecutive_passes` to 0
- INFO findings do NOT reset the counter (INFO is advisory)
- The loop is self-limiting: it terminates after `required_passes` consecutive PASS results
- If the loop reaches 5 rounds without achieving `required_passes` consecutive passes, surface all accumulated findings to the user and stop without committing/clearing review success state
- After the loop completes, `silver:completion-audit` or `silver:verify` MUST be invoked before the producing step is marked done — no completion claim without fresh verification evidence

---

## Section 2: Per-Artifact State Tracking (ARFR-03)

State is written after EVERY round so that review sessions can resume across context resets.

### State File Location

```
$HOME/.codex/.silver-bullet/review-state/{artifact-hash}.json
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
- `clear_review_state(artifact_path)` — Delete state file after successful required_passes completion

### Implementation (Shell)

```bash
# State directory
SB_REVIEW_STATE="$HOME/.codex/.silver-bullet/review-state"
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
- **Consecutive clean passes:** {count}/{required_passes}

---
```

### Rules

- REVIEW-ROUNDS.md is **append-only** during a review session — never truncate prior rounds
- Each artifact gets its own section identified by `## {artifact filename}` header
- If REVIEW-ROUNDS.md already contains rounds for this artifact from a prior session, append new rounds after the last existing one
- Commit REVIEW-ROUNDS.md alongside the artifact after the review loop completes (`required_passes` clean passes achieved)

### Scalability: Rotation at Milestone Completion

REVIEW-ROUNDS.md grows unboundedly across a milestone. To prevent it from exceeding LLM context limits:

- **On milestone completion** (`silver:release` milestone archive): archive the current REVIEW-ROUNDS.md to `.planning/archive/{milestone-slug}/REVIEW-ROUNDS.md` and start a fresh empty file
- **Cap**: if REVIEW-ROUNDS.md exceeds 200 lines mid-milestone, archive to `.planning/archive/review-rounds-{YYYY-MM-DD}.md` and start fresh
- The `record_round()` function checks line count before appending:

```
record_round(artifact_path, round, findings):
  review_rounds_file = dirname(artifact_path) + "/REVIEW-ROUNDS.md"

  # Rotation check (scalability enforcement)
  if file_exists(review_rounds_file) and count_lines(review_rounds_file) > 200:
    archive_dir = ".planning/archive"
    mkdir_p(archive_dir)
    move(review_rounds_file, archive_dir + "/review-rounds-{YYYY-MM-DD}.md")

  append_round_entry(review_rounds_file, artifact_path, round, findings)
```

---

## Section 4: Review Analytics (ARVW-10)

Every completed review round appends a structured JSON record to `.planning/review-analytics.jsonl`. This enables data-driven review health visibility and is the data source for the `silver-review-stats` skill.

### 4a. Metric Record Schema

```json
{
  "artifact_path": "/absolute/path/to/artifact.md",
  "artifact_type": "SPEC.md",
  "reviewer": "review-spec",
  "round": 2,
  "finding_count": 3,
  "status": "ISSUES_FOUND",
  "depth": "standard",
  "check_mode": "full",
  "duration_seconds": 45,
  "timestamp": "2026-04-10T12:00:00Z"
}
```

Where `artifact_type` is the filename (basename) of the artifact, and `duration_seconds` is wall-clock seconds for that round.

### 4b. `emit_review_metric()` Function

```
emit_review_metric(artifact_path, reviewer, round, finding_count, status, depth, check_mode, duration_seconds):
  analytics_file = ".planning/review-analytics.jsonl"

  # Rotate if needed (ARVW-10e)
  rotate_analytics_if_needed(analytics_file)

  metric = {
    artifact_path: realpath(artifact_path),
    artifact_type: basename(artifact_path),
    reviewer: reviewer,
    round: round,
    finding_count: finding_count,
    status: status,
    depth: depth,
    check_mode: check_mode,
    duration_seconds: duration_seconds,
    timestamp: current_iso_timestamp()
  }

  append_json_line(analytics_file, metric)
```

### 4c. `rotate_analytics_if_needed()` Function

```
rotate_analytics_if_needed(analytics_file):
  if not file_exists(analytics_file):
    return

  line_count = count_lines(analytics_file)
  if line_count <= 1000:
    return

  archive_dir = ".planning/archive"
  mkdir_p(archive_dir)
  archive_name = "review-analytics-{YYYY-MM-DD}.jsonl"
  move(analytics_file, archive_dir + "/" + archive_name)
  # New entries will be appended to a fresh analytics_file
```

When the analytics file exceeds 1000 lines, the oldest entries are archived before the new record is appended. This prevents unbounded file growth (ARVW-10e / T-19-02 mitigation).

### 4d. Integration Notes

The `emit_review_metric()` call is placed in Section 1 after `record_round()` and before the PASS/ISSUES_FOUND branching — so every round (pass or fail) is captured. The variables `artifact_path`, `reviewer_skill_name`, `round`, `findings`, `depth`, `check_mode`, `round_start`, and `duration` are all in scope at that point.
