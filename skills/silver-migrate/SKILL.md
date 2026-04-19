---
name: silver-migrate
description: "Migrates an existing mid-milestone project to composable flows by generating WORKFLOW.md from current artifact state."
version: 0.1.0
---

# silver:migrate

> Migrates an existing mid-milestone project to composable flows by generating WORKFLOW.md from current artifact state.

**Plugin root**: Determine `PLUGIN_ROOT` from this file's path. This file lives at
`${PLUGIN_ROOT}/skills/silver-migrate/SKILL.md`, so the plugin root is two directories up.

---

## When to Use

- Project started a milestone before composable flows architecture (v0.20.0)
- `.planning/` directory exists with `STATE.md` but no `WORKFLOW.md`
- User explicitly runs `/silver:migrate`

---

## Prerequisites

- `.planning/STATE.md` must exist
- `.planning/WORKFLOW.md` must NOT exist — if it already exists, migration is unnecessary. Inform the user and exit: "WORKFLOW.md already exists at .planning/WORKFLOW.md — migration is not needed. Use /silver to continue the current workflow."

---

## Steps

### Step 1: Scan Existing Artifacts

Read `.planning/STATE.md` to understand current phase, milestone state, and any completed skills listed.

Then scan the project for artifacts that indicate path completion. Use this artifact-to-path mapping:

| Flow | Name | Artifacts to Check | Inference Rule |
|------|------|--------------------|----------------|
| FLOW 0 | BOOTSTRAP | `.planning/PROJECT.md`, `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, `.planning/STATE.md` | Complete if ALL four exist |
| FLOW 1 | ORIENT | `.planning/intel/*.md`, `.planning/codebase/*.md` | Complete if any intel or codebase file exists |
| FLOW 2 | EXPLORE | (no dedicated artifact) | Mark as "skipped" — cannot infer from artifacts alone |
| FLOW 3 | IDEATE | `docs/superpowers/specs/*.md`, `.planning/ADR-*.md` | Complete if any matching file exists |
| FLOW 4 | SPECIFY | `.planning/SPEC.md` | Complete if file exists |
| FLOW 5 | PLAN | `.planning/phases/*/CONTEXT.md`, `.planning/phases/*/PLAN.md` | Complete if current phase has PLAN.md files |
| FLOW 6 | DESIGN CONTRACT | `.planning/DESIGN.md`, `.planning/UI-SPEC.md` | Complete if either exists |
| FLOW 7 | EXECUTE | `.planning/phases/*/*-SUMMARY.md` | Complete if current phase has SUMMARY.md files |
| FLOW 8 | UI QUALITY | `.planning/UI-REVIEW.md` | Complete if file exists |
| FLOW 9 | REVIEW | `.planning/REVIEW.md`, `.planning/phases/*/REVIEW.md` | Complete if any exists |
| FLOW 10 | SECURE | `.planning/SECURITY.md` | Complete if file exists |
| FLOW 11 | VERIFY | `.planning/VERIFICATION.md` | Complete if file exists |
| FLOW 12 | QUALITY GATE | (checked via STATE.md) | Complete if `silver-quality-gates` appears in STATE.md completed skills |
| FLOW 13 | SHIP | (checked via STATE.md) | Complete if `deploy-checklist` or `silver-create-release` appears in STATE.md completed skills |
| FLOW 14 | DEBUG | (no dedicated artifact) | Mark as "not applicable" — inserted dynamically only on failure |
| FLOW 15 | DESIGN HANDOFF | (no dedicated artifact) | Mark as "not applicable" unless milestone has UI phases |
| FLOW 16 | DOCUMENT | (checked via STATE.md) | Complete if `gsd-docs-update` or documentation skill appears in STATE.md |
| FLOW 17 | RELEASE | (checked via STATE.md) | Complete if `silver-create-release` appears in STATE.md completed skills |

Record which artifacts were found for each path. This evidence list will be shown to the user in Step 4.

---

### Step 2: Determine Composition

Based on the artifacts found in Step 1, determine which paths belong to this project's composition:

- **Always include:** FLOW 0, FLOW 1, FLOW 5, FLOW 7, FLOW 11, FLOW 13
- **Include if artifacts exist:** FLOW 2, FLOW 3, FLOW 4, FLOW 6, FLOW 8, FLOW 9, FLOW 10, FLOW 16, FLOW 17
- **Include FLOW 12** if silver-quality-gates skill appears in STATE.md
- **Exclude FLOW 14 and FLOW 15** unless specific evidence exists (UI milestone or debug artifacts)
- **Exclude paths** with no artifacts AND no STATE.md markers — these were intentionally skipped

For each included path, assign an inferred status:
- `complete` — artifact(s) confirmed present
- `in-progress` — partial artifacts exist (e.g., PLAN.md exists but no SUMMARY.md for FLOW 7)
- `pending` — no artifacts yet but path is in composition
- `skipped` — intentionally excluded (FLOW 2, 14, 15 when not applicable)

---

### Step 3: Generate WORKFLOW.md Content

Read `templates/workflow.md.base` as the scaffolding template.

Build the WORKFLOW.md content by filling in:

**Composition section:**
- `Intent:` → `"Migrated from legacy workflow — see STATE.md for original context"`
- `Composed:` → current ISO timestamp (e.g. `2026-04-15T12:00:00Z`)
- `Composer:` → `/silver:migrate`
- `Mode:` → `interactive`

**Flow Log table:** Add one row per path in the determined composition:
```
| {#} | {PATH NAME} | {status} | {artifact filename(s) or "—"} | {Yes / No / Inferred} |
```

**Phase Iterations section:** Add the current phase from STATE.md with status of Flows 5-13 based on inferred statuses.

**Heartbeat section:**
- `Last-flow:` → highest path number with status `complete`
- `Last-beat:` → current ISO timestamp

**Next Path section:**
- Set to the first path in composition with status `in-progress` or `pending`

---

### Step 4: Present for Confirmation

Display the full generated WORKFLOW.md content to the user.

Also display a summary panel:

```
## Migration Summary

Paths inferred as COMPLETE:
  - FLOW 0 (BOOTSTRAP): PROJECT.md, ROADMAP.md, REQUIREMENTS.md, STATE.md all present
  - FLOW 1 (ORIENT): intel files found in .planning/intel/
  - ... (list each with evidence)

Paths marked PENDING:
  - FLOW 11 (VERIFY): no VERIFICATION.md found
  - ... (list each)

Paths excluded from composition:
  - FLOW 2 (EXPLORE): no artifacts found, skipped
  - FLOW 14 (DEBUG): not applicable
  - ...

Next path after migration: FLOW {N} ({NAME})
```

Ask the user to confirm before writing:

> "Does this migration look correct? You can adjust any path status before I write WORKFLOW.md. Reply 'yes' to confirm, or describe any changes needed."

**Do not write WORKFLOW.md until the user explicitly confirms.**

---

### Step 5: Write and Commit

After user confirms (or after adjustments are agreed):

1. Write the final WORKFLOW.md content to `.planning/WORKFLOW.md`
2. Stage and commit:
   ```
   git add .planning/WORKFLOW.md
   git commit -m "docs(workflow): migrate to composable flows via silver:migrate"
   ```
3. Confirm to the user: "WORKFLOW.md written and committed. Your project is now on composable flows. Use /silver to continue from FLOW {N} ({NAME})."

---

## Produces

- `.planning/WORKFLOW.md` — populated with inferred path completion state and confirmed by user before writing

---

## Notes

- This is a **one-time migration skill**. Once WORKFLOW.md exists, the `/silver` composer manages it going forward.
- If the user disagrees with any inferred status, adjust before writing — the goal is an accurate starting state, not a perfect one.
- Paths marked `skipped` in the composition record that they were intentionally not part of this project's workflow. This prevents /silver from re-suggesting them.
- FLOW 2 (EXPLORE) is almost always `skipped` in migrations — its outputs are narrative and leave no dedicated artifact trail.
- The `workflow.md.base` template governs the file structure. Do not add sections not present in the template.
