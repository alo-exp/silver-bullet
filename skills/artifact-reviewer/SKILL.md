---
name: artifact-reviewer
description: "Framework for artifact review — defines the standard interface, 2-pass loop, state tracking, and audit trail that all SB artifact reviewers implement"
argument-hint: "<artifact-path> [--reviewer <reviewer-skill-name>]"
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
| SPEC.md | (Phase 16) | Not yet implemented |
| DESIGN.md | (Phase 16) | Not yet implemented |
| REQUIREMENTS.md | (Phase 16) | Not yet implemented |
| ROADMAP.md | (Phase 16) | Not yet implemented |
| CONTEXT.md | (Phase 16) | Not yet implemented |
| RESEARCH.md | (Phase 16) | Not yet implemented |
| INGESTION_MANIFEST.md | (Phase 16) | Not yet implemented |
| UAT.md | (Phase 16) | Not yet implemented |

## Orchestration Steps

1. Resolve artifact path to absolute path
2. Load per-artifact review state (enables session resumption)
3. Auto-detect or validate reviewer from mapping table
4. Run the review loop (defined in rules/review-loop.md)
5. Write REVIEW-ROUNDS.md audit trail after each round
6. On 2 consecutive clean passes: clear state, report completion

## Loading Rules

All reviewers implementing this framework MUST load:

- `@skills/artifact-reviewer/rules/reviewer-interface.md` — interface contract (input/output shape all reviewers must implement)
- `@skills/artifact-reviewer/rules/review-loop.md` — loop mechanism, per-artifact state tracking, and audit trail format
