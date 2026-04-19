---
name: artifact-reviewer
description: "Framework for artifact review — defines the standard interface, 2-pass loop, state tracking, and audit trail that all SB artifact reviewers implement"
argument-hint: "<artifact-path> [--reviewer <reviewer-skill-name>]"
user-invocable: false
version: 0.1.0
---

# artifact-reviewer

Orchestrator skill for artifact review. Accepts an artifact path and optional reviewer name, dispatches to the appropriate reviewer skill, runs the 2-consecutive-pass review loop, records per-artifact state, and writes the REVIEW-ROUNDS.md audit trail.

## Usage

```
/artifact-reviewer <artifact-path> [--reviewer <reviewer-skill-name>]
```

If `--reviewer` is omitted, the reviewer is auto-detected from the artifact filename using the mapping table below.

## Artifact-to-Reviewer Mapping

| Artifact Pattern | Reviewer Skill | Notes |
|-----------------|---------------|-------|
| *-PLAN.md | gsd-plan-checker | Existing GSD reviewer |
| Code changes | gsd-code-reviewer | Existing GSD reviewer |
| VERIFICATION.md | gsd-verifier | Existing GSD reviewer |
| Security findings | silver:security | Existing SB reviewer |
| SPEC.md | review-spec | New SB reviewer |
| DESIGN.md | review-design | New SB reviewer |
| REQUIREMENTS.md | review-requirements | New SB reviewer |
| ROADMAP.md | review-roadmap | New SB reviewer |
| CONTEXT.md | review-context | New SB reviewer |
| RESEARCH.md | review-research | New SB reviewer |
| INGESTION_MANIFEST.md | review-ingestion-manifest | New SB reviewer |
| UAT.md | review-uat | New SB reviewer |
| Cross-artifact set | review-cross-artifact | New SB reviewer -- multi-artifact |

## Orchestration Steps

1. Resolve artifact path to absolute path
2. Load per-artifact review state (enables session resumption)
3. Auto-detect or validate reviewer from mapping table
4. Resolve review depth from `.planning/config.json` and run the review loop (defined in rules/review-loop.md) with the resolved depth
4.5. After each review round, emit metrics to `.planning/review-analytics.jsonl` (per rules/review-loop.md Section 4)
5. Write REVIEW-ROUNDS.md audit trail after each round
6. On required consecutive clean passes (depth-dependent): clear state, report completion
6.5. Analytics file rotation: if `.planning/review-analytics.jsonl` exceeds 1000 lines, archive to `.planning/archive/review-analytics-{date}.jsonl` before next append

## Review Depth Configuration

Review depth is configured per artifact type in `.planning/config.json`:

```json
{
  "review_depth": {
    "review-spec": "deep",
    "review-roadmap": "quick",
    "gsd-plan-checker": "standard"
  }
}
```

### Depth Levels

| Depth | QC Checks | Required Clean Passes | Use When |
|-------|-----------|----------------------|----------|
| deep | Full (all QC) | 2 consecutive | High-stakes artifacts (SPEC, REQUIREMENTS) |
| standard | Full (all QC) | 1 | Default — good balance of rigor and speed |
| quick | Structural only | 1 | Speed-critical reviews (CONTEXT, RESEARCH) |

### Defaults

- If `review_depth` is absent from config.json: all artifacts use `standard`
- If `review_depth` exists but has no entry for a reviewer: that reviewer uses `standard`
- An empty `review_depth: {}` is equivalent to "all standard"

## Review Analytics

Every review round emits a structured metric to `.planning/review-analytics.jsonl` (JSON Lines format, one object per line). Each record captures:

- `artifact_path`, `artifact_type`, `reviewer` — what was reviewed
- `round`, `finding_count`, `status` — round outcome
- `depth`, `check_mode` — review configuration
- `duration_seconds`, `timestamp` — timing data

When the analytics file exceeds 1000 lines, it is archived to `.planning/archive/review-analytics-{date}.jsonl` and a fresh file is started.

Run `silver-review-stats` to produce summary reports from the analytics data.

## Loading Rules

All reviewers implementing this framework MUST load:

- `@skills/artifact-reviewer/rules/reviewer-interface.md` — interface contract (input/output shape all reviewers must implement)
- `@skills/artifact-reviewer/rules/review-loop.md` — loop mechanism, per-artifact state tracking, and audit trail format
