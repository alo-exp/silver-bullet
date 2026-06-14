---
name: "silver:ship"
title: "Ship"
description: "This skill performs SB phase shipping: final gates, branch/PR readiness, CI status, docs traceability, and handoff."
argument-hint: "<phase or ship scope>"
version: 0.1.0
---

# /silver:ship - Phase Ship

SB-owned phase shipping handles branch/PR readiness, CI status, deployment
readiness, docs traceability, and handoff.

This is phase-level ship, not milestone release. Use `silver:release` for
versioned publication.

## Output

Write or update the ship section in `.planning/STATE.md`, current phase
SUMMARY/VERIFICATION, or a PR description draft.

## Process

1. Display `SILVER BULLET > SHIP`.
2. Confirm required gates have passed:
   - `silver:verify`;
   - `silver:review`;
   - `silver:secure`;
   - `silver:validate` where the workflow requires it;
   - `silver:domain-audit` where specialized packs were selected by
     `silver:quality-gates`, review, verification, DevOps, or release scope;
   - `verify-tests` — **mandatory before any delivery**. `verify-tests` is in the
     `required_deploy` list, so the completion-audit deploy gate blocks
     `gh pr create` / `gh release create` / `deploy` until a fresh `verify-tests`
     run is recorded. Run it here even when the suite was run earlier in the phase,
     so the recorded freshness marker reflects the shipped tree.
3. Run `silver:branch-finish` on non-main branches.
4. Check git status and separate unrelated user changes from ship scope.
5. Prepare PR or merge notes with:
   - problem and solution summary;
   - tests and verification evidence;
   - risk and rollback notes;
   - docs and artifact updates;
   - deferred items.
6. Check CI or provide exact missing CI status.
7. Update planning state only after gates and ship action are consistent.

## Exit Gate

Ship passes only when the branch/PR action is clear, required gates are fresh,
and the user can see exactly what is being delivered.
