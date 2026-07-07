---
name: "silver:triage"
title: "Triage"
description: Generic review-finding triage across any artifact or scope — classifies findings, files valid issues via PM adapter, and routes fixes without reviewer self-triage.
argument-hint: "<review findings> [--artifact PATH] [--charter PATH]"
version: 0.1.0
---

# /silver:triage — Generic Review Finding Triage

SB-owned triage for **any** review output: code review, artifact review, ladder review, domain audit, or external feedback. Classifies each finding, files valid non-duplicates through `/silver:add`, and produces a fix plan — **without** the review subagent triaging its own findings.

## When to Use

- After any review subagent returns raw findings (ladder, triad, audit, PR review)
- Standalone: user asks to triage review feedback on a scoped artifact
- Inside `silver:review-fix-ladder` between `rung_N_review` and `rung_N_fix_parallel`

## Separation Rules (HARD)

1. **Review subagent does not triage** — it reports raw findings only.
2. **Triage runs as a separate subagent** launched by the host orchestrator using the **host's current model**, not the rung review model.
3. **Filing runs after triage** — only `VALID-BLOCKER` and `VALID-NONBLOCKER` findings are filed via `/silver:add` (or PM adapter).
4. **Fix agents launch after filing** — host model, parallel only when triage grouping says safe.

## Inputs

| Input | Source |
|-------|--------|
| Raw review findings | Review subagent output |
| Reviewed artifact / scope | Locked paths, file list, or charter scope |
| Charter / contract | `.planning/`, `silver-bullet.md`, artifact contract (see `artifact-review-assessor`) |
| Current context | Session logs, prior triage tables, PM issue links |

## Classification Outcomes

| Classification | Meaning | PM filing | Fix routing |
|----------------|---------|-----------|-------------|
| `VALID-BLOCKER` | Must fix before advancing charter or ship gate | Yes (issue) | Immediate fix workflow |
| `VALID-NONBLOCKER` | Genuine gap; deferrable under current charter | Yes (backlog) | Defer or fix if low effort |
| `DUPLICATE` | Matches existing filed item (fingerprint or title) | No — link existing `id`/`url` | None |
| `ALREADY-FIXED` | Evidence shows fix landed in scope | No | Record evidence only |
| `FALSE-POSITIVE` | Reject with evidence (contract, scope, stale) | No | None |
| `NEEDS-USER-DECISION` | Genuinely ambiguous — **stop and ask user** | No until resolved | Block until user decides |

Use `artifact-review-assessor` criteria when an artifact contract exists; otherwise apply charter goals, non-goals, and verification signals.

## Process

1. Display `SILVER BULLET > TRIAGE`.
2. Assign stable finding IDs (`T-001`, `T-002`, …) to each raw finding.
3. For each finding, classify with evidence (line refs, grep output, contract rule).
4. Run dedupe before filing:
   ```bash
   bash scripts/silver-add.sh fingerprint --domain "<scope>" --scope "<path>" --finding "<one-line>"
   bash scripts/silver-add.sh dedup --fingerprint "<fp>"
   ```
   For `issue_tracker=custom`, also run adapter dedupe when configured (see `/silver:add`).
5. File valid findings through `/silver:add` — never file `FALSE-POSITIVE`, `DUPLICATE`, or `ALREADY-FIXED`.
6. Group independent fixes into parallelization groups (same file or conflicting edits → same group).
7. Recommend fix workflow per blocker: `/silver:bugfix`, `/silver:refactor`, `/silver:devops`, or composed workflow.

## Output — Triage Table (required)

Write or update `.planning/REVIEW.md` (or append to the active review artifact) with:

```markdown
## Triage — <scope or artifact>

| ID | Finding (summary) | Classification | Evidence | PM id/url | Fix workflow | Parallel group |
|----|-------------------|----------------|----------|-----------|--------------|----------------|
| T-001 | ... | VALID-BLOCKER | line 42 violates charter goal X | SB-I-12 | /silver:bugfix | G1 |
| T-002 | ... | FALSE-POSITIVE | already covered by SPEC §3 | — | — | — |
```

Also emit a machine-readable summary for the orchestrator:

```json
{
  "schema": "silver-triage-v1",
  "blockers": ["T-001"],
  "filed": [{"id": "T-001", "pm_id": "SB-I-12", "pm_url": null}],
  "parallel_groups": {"G1": ["T-001"]},
  "dismissed": ["T-002"]
}
```

## Exit Gate

Triage is complete only when:

- Every finding has a classification and evidence
- Every `VALID-*` item is filed or linked to an existing PM item
- No reviewer self-triage occurred (triage agent ≠ review agent for same rung)
- Blockers have fix workflow and parallel group assigned
- `NEEDS-USER-DECISION` items are escalated — do not silently defer
