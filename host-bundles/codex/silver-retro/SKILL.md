---
name: "silver:retro"
title: "Retro"
description: >
  This skill should be used for SB-owned engineering retrospectives over a
  release, date range, incident cluster, or workflow history.
argument-hint: "<range, release, or scope>"
version: 0.1.0
---

# /silver:retro - Engineering Retrospective

SB-owned retrospective workflow for turning delivery history into concrete
process improvements.

## Output

Write or update `.planning/RETRO.md`.

The report must include:

- scope and source range;
- delivery metrics available from git, CI, releases, issues, and SB artifacts;
- quality trends from reviews, domain audits, incidents, and verification;
- recurring blockers and process gaps;
- action items filed through `silver:add`;
- knowledge/learnings candidates for `silver:rem`.

## Process

1. Display `SILVER BULLET > RETRO`.
2. Determine the retrospective scope: release tag range, date range, incident,
   milestone, or workflow archive.
3. Gather evidence from git history, release notes, CI status, issue backlog,
   `.planning/` artifacts, `review-analytics.jsonl`, and session logs.
4. Invoke or apply `silver:domain-audit --pack incident-retro` and
   `benchmark-eval` when provider/tooling performance is part of the scope.
5. Separate observed facts from inferred causes.
6. File actionable improvements through `silver:add`; capture durable knowledge
   or learnings through `silver:rem`.

## Exit Gate

The retro passes only when every recommendation has either a tracked work item,
an accepted no-action rationale, or a documented owner outside SB.
