---
name: "silver:new-workflow"
title: "New Workflow"
description: >
  This skill should be used to create, convert, or audit Silver Bullet workflows and atomic flows — analyzes reusable catalog AFs/workflows, plans with review-fix-ladder, implements in a selected repo, validates catalog compliance, and registers locally; Audit mode is read-only compliance for existing workflows
argument-hint: "<workflow intent | --audit <target> | path to existing skill/workflow to convert>"
version: 0.2.0
---

# /silver:new-workflow — Workflow Authoring Meta Workflow

SB **queue builder** for workflow and atomic-flow authoring. Parent orchestrator
spawns workers per atomic flow; do not implement catalog changes inline in parent
mode.

**Canonical contracts:** `docs/composable-flows-contracts.md`, `docs/apo-catalog.json`,
`docs/APO-AUTHORING-COMPLIANCE.md`. **Runbook:** `docs/NEW-WORKFLOW.md`.

## Modes

| Mode | When | Primary outcome |
|------|------|-----------------|
| **Create** | User describes a new workflow intent | New composer skill + `WF-*` catalog entry + hooks/tests |
| **Convert** | User names an existing skill or workflow path (no audit intent) | Gap review → compliant SB workflow/AF + catalog registration |
| **Audit** | User names an existing workflow id (`WF-*`), composer slug (`silver-feature`), or path to `SKILL.md` with audit intent | Read-only compliance report; no create/convert/plan/RFL/implement |

### Mode detection (`$ARGUMENTS`)

1. **Audit** when any of:
   - `--audit`, `--validate`, or `audit` / `validate` prefix
   - Workflow id matching `WF-SILVER-*`
   - Existing composer slug (`silver-feature`, `feature`, etc.) with audit intent
   - Path to `skills/…/SKILL.md` **with** audit intent (`--audit`, `validate`, etc.)
2. **Convert** when `$ARGUMENTS` is a filesystem path or `skills/…/SKILL.md` **without** audit intent.
3. **Create** otherwise.

## Audit mode (read-only)

Audit mode runs **inline** — no orchestrator queue, no plan/RFL/execute. Orient → validate → document.

### Audit Step 1 — Resolve target

From `$ARGUMENTS`, derive `slug`, `wf_id`, and `skill`:

| Input | Example | Resolved |
|-------|---------|----------|
| Workflow id | `WF-SILVER-FEATURE` | `silver-feature`, `WF-SILVER-FEATURE` |
| Composer slug | `silver-feature` or `feature` | `silver-feature`, `WF-SILVER-FEATURE` |
| SKILL path | `skills/silver-new-workflow/SKILL.md` | `silver-new-workflow`, `WF-SILVER-NEW-WORKFLOW` |

### Audit Step 2 — Run compliance suite

```bash
bash scripts/audit-workflow-compliance.sh --target "<resolved-target>"
# or
bash scripts/validate-workflow-authoring.sh --audit --target "<resolved-target>"
```

Checks (PASS/FAIL per category + remediation links):

- **structural** — skill, catalog generator, workflow entry, orchestrator registration
- **migration_map** — `skill_to_entity` mapping
- **catalog** — `composition_tree`, `enforcement_queue`
- **triple_alignment** — SKILL pre-exec ↔ `workflow-chain-guard.sh` ↔ orchestrator pre-execute
- **orchestrator** — composer in `hooks/lib/orchestrator-state.sh`
- **flow_steps** — mapped entity V-loop / flow-step contract

Optional broader suite:

```bash
bash scripts/run-apo-authoring-compliance.sh
```

### Audit Step 3 — Document

Write `.planning/workflow-audit-<slug>-<date>.md` with verdict, per-category results, and remediation links. **No file edits** to skills, hooks, or catalog.

### Audit output contract

Return: target (`slug`, `wf_id`, `skill`), per-category PASS/FAIL, overall VERDICT, remediation links, blockers.

## Step 0 — Target repo (HARD)

**Create / Convert only** — skip for Audit mode.

1. Default target repo: current workspace / project root (`PWD` when SB is active).
2. Ask unless the user already named an absolute path:

   > Which repository should host this workflow? (default: `<current>`)

3. Record session scope before any writes:

```bash
mkdir -p .planning
jq -n \
  --arg repo "$(cd "$TARGET_REPO" && pwd)" \
  --arg mode "$MODE" \
  --arg intent "$INTENT" \
  --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{target_repo:$repo, mode:$mode, intent:$intent, created_at:$at}' \
  > .planning/new-workflow-session.json
```

4. **FORBIDDEN** to write outside `target_repo` and the SB source catalog surfaces
   (`skills/`, `docs/apo-catalog.json`, `scripts/generate-apo-catalog.py`, `hooks/`)
   without explicit user confirmation.
5. On abort: `git stash` / `git checkout --` in target repo; revert SB catalog edits via git.

## Step 1 — Orient and reuse analysis

Mandatory Graphify before catalog exploration:

```bash
graphify query "workflows and atomic flows related to <intent>" --graph graphify-out/graph.json --budget 2000
graphify explain "<capability class>"
```

Write reuse memo: `.planning/new-workflow-reuse-analysis.md`.

**Reuse policy:** Prefer existing AFs and composers before inventing new AFs.

## Step 2 — Plan

Create `.planning/NEW-WORKFLOW-<slug>-PLAN.md` with slug, composition tree, enforcement queue, files checklist, test plan. Invoke **`silver:plan`** when the target repo uses SB planning.

## Step 3 — Review-fix ladder on plan (HARD)

Run **`silver:review-fix-ladder`** on plan artifact(s). Two consecutive clean verify passes per rung. Do not implement until plan RFL passes.

## Step 4 — Implement

Update SB source: skill, `scripts/generate-apo-catalog.py`, hooks, router, tests. Regenerate catalog and sync bundles per `docs/NEW-WORKFLOW.md`.

## Step 5 — Validate

```bash
bash scripts/validate-workflow-authoring.sh --slug <slug>
bash scripts/audit-workflow-compliance.sh --slug <slug>
bash scripts/run-apo-authoring-compliance.sh
bash tests/scripts/test-silver-new-workflow.sh
bash tests/scripts/test-silver-new-workflow-audit.sh
```

## Step 6 — Convert mode

Gap matrix in `.planning/new-workflow-convert-gap-<slug>.md`; map steps to catalog AFs; same plan → RFL → implement → validate path.

## Standard composition chain

```
FLOW 3 (CLARIFY) → FLOW 2 (ORIENT) → FLOW 4 (DECIDE) → FLOW 6 (PLAN)
→ REVIEW TRIAGE (review-fix-ladder) → FLOW 8 (EXECUTE) → FLOW 12 (VERIFY)
→ VALIDATE → DOCUMENT
```

## Enforcement queue

Full chain: `silver:clarify` → `silver:scan` → `silver:deep-research` → `silver:plan`
→ `silver:review-fix-ladder` → `silver:execute` → `silver:verify`
→ `silver:validate` → `silver:ensure-docs`

**Pre-execution** (blocks implementation execute atom until recorded):

`silver:clarify` → `silver:scan` → `silver:plan` → `silver:validate`

**Post-execution:** `silver:verify`, `silver:ensure-docs`

**Audit mode** does not use the enforcement queue — read-only checks only.

## Routing and pre-flight

1. Banner: `SB ► new-workflow: {$ARGUMENTS} [mode=$MODE repo=$TARGET_REPO]`
2. Subagents MUST use **`composer-2.5` only** (never Fast).

## Non-skippable

- **Create/Convert:** target repo confirmation, plan RFL, `run-apo-authoring-compliance.sh` before handoff.
- **Audit:** compliance suite execution and documented verdict.

## Output contract

- **Create/Convert:** plan path + RFL status, catalog workflow id, files changed, tests, ready route, blockers.
- **Audit:** compliance report path, per-category PASS/FAIL, overall VERDICT, remediation links.
