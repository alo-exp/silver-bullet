---
name: "silver:migrate"
title: "Migrate"
description: "This skill should be used when the user runs `/silver:migrate` or asks to migrate an older Silver Bullet project from retired workflow/doc conventions to current per-instance workflow tracking and Learnings documentation terminology."
version: 0.3.0
---

# silver:migrate

Migrates an older mid-milestone project to the current composed-workflow tracker and current documentation terminology.

The legacy `.planning/WORKFLOW.md` file is retired. Do not create or update it.
The legacy `docs/lessons/` path and "Lessons" terminology are retired. Use `docs/learnings/` and "Learnings" instead.

## When to Use

- `.planning/` exists with GSD state artifacts.
- The project was started before per-instance workflow tracking.
- The user explicitly runs `/silver:migrate` or asks to migrate workflow tracking.
- The project has older `docs/lessons/` files, doc-scheme entries, checklist keys, or docs text that still says "Lessons".

## Prerequisites

- `.planning/STATE.md` must exist.
- `scripts/workflows.sh` must be available from the project root or plugin install.
- If `.planning/workflows/*.md` already contains an active workflow, report the active id and skip only the workflow-tracker migration. Still run the documentation terminology migration below.

## Steps

### Step 0: Migrate Documentation Terminology

Run this step before workflow-tracker checks so projects with current workflow files still receive the doc migration.

1. If `docs/lessons/` exists and `docs/learnings/` does not exist, move the directory:

   ```bash
   mv docs/lessons docs/learnings
   ```

2. If both directories exist, merge files conservatively:
   - For each file that exists only in `docs/lessons/`, move it to `docs/learnings/`.
   - For each file that exists in both, append the old `docs/lessons/` content under a `## Migrated from docs/lessons/` heading in the matching `docs/learnings/` file, then remove the old file only after confirming the content is preserved.
   - Remove `docs/lessons/` only when empty.

3. Update documentation scheme files and checklist keys:
   - `docs/doc-scheme.md`
   - `docs/doc-scheme.json`
   - `docs/task-doc-checklist.json`
   - `docs/knowledge/INDEX.md`
   - project docs that reference `docs/lessons/`, `lessons/YYYY-MM.md`, "Lessons", or "lessons"

   Required replacements:
   - `docs/lessons/` -> `docs/learnings/`
   - `lessons/YYYY-MM.md` -> `learnings/YYYY-MM.md`
   - `type: lessons` -> `type: learnings`
   - "Lessons" -> "Learnings"
   - "lessons" -> "learnings"
   - "lesson" -> "learning" only when it refers to the documentation category, not normal prose unrelated to SB docs

4. Update monthly learnings files:
   - Frontmatter must use `type: learnings`.
   - Title should be `# Learnings - YYYY-MM` or `# Learnings — YYYY-MM`.
   - Category headings remain `domain:{area}`, `stack:{technology}`, `practice:{area}`, `devops:{area}`, and `design:{area}`.

5. Report the documentation migration separately:
   - files moved
   - files updated
   - any `docs/lessons/` files left for manual review

### Step 1: Scan Existing Artifacts

If an active `.planning/workflows/*.md` file exists, report the active id and skip to Step 4 after Step 0. Workflow migration is unnecessary, but the documentation migration remains valid.

Read `.planning/STATE.md` to identify the current milestone, phase, and status.

Then scan for artifacts that indicate flow completion:

| Flow | Artifacts to Check | Inference Rule |
|------|--------------------|----------------|
| BOOTSTRAP | `.planning/PROJECT.md`, `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, `.planning/STATE.md` | Complete if all four exist |
| ORIENT | `.planning/intel/*.md`, `.planning/codebase/*.md` | Complete if any exists |
| CLARIFY | `.planning/phases/*/*-CONTEXT.md` | Complete if context exists; otherwise pending or skipped based on current phase |
| DECIDE | `.planning/research/*.md`, `.planning/ADR-*.md`, `docs/superpowers/specs/*.md` | Complete if any exists |
| SPECIFY | `.planning/SPEC.md` | Complete if exists |
| PLAN | `.planning/phases/*/*-PLAN.md` | Complete if current phase has a plan |
| EXECUTE | `.planning/phases/*/*-SUMMARY.md` | Complete if current phase has a summary |
| REVIEW | `.planning/phases/*/*-REVIEW.md`, `.planning/REVIEW.md` | Complete if any exists |
| SECURE | `.planning/phases/*/*-SECURITY.md`, `.planning/SECURITY.md` | Complete if any exists |
| VERIFY | `.planning/UAT.md`, `.planning/phases/*/*-UAT.md`, `.planning/phases/*/*-VERIFICATION.md` | Complete if any exists |
| QUALITY GATE | SB state marker `silver-quality-gates` | Complete if marker exists |
| SHIP | GSD state marker `gsd-ship` | Complete if marker exists |
| DOCUMENT | `gsd-docs-update` marker or docs modified for current phase | Complete if evidence exists |
| RELEASE | `silver-create-release` marker or current version tag exists | Complete if evidence exists |

### Step 2: Compose Current Flow List

Include only flows that are relevant to the current project state. Always include the next unfinished GSD lifecycle flow needed to resume safely.

Use GSD artifacts for phase position. Use SB markers only for SB compliance progress.

### Step 3: Start Per-Instance Workflow Tracking

Resolve the workflow helper, then run its start subcommand:

```bash
SB_FLOWS="<comma-separated inferred flow list>"
if [[ -x scripts/workflows.sh ]]; then
  SB_WORKFLOWS_BIN="scripts/workflows.sh"
else
  SB_WORKFLOWS_BIN="$(
    for root in \
      "$HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet/current" \
      "$HOME/.codex/plugins/cache/alo-labs/silver-bullet/current" \
      "$HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet"/* \
      "$HOME/.codex/plugins/cache/alo-labs/silver-bullet"/*; do
      if [[ -x "$root/scripts/workflows.sh" ]]; then
        printf "%s\n" "$root/scripts/workflows.sh"
        break
      fi
    done
  )"
fi
if [[ -z "${SB_WORKFLOWS_BIN:-}" ]]; then
  echo "Silver Bullet workflow tracker not found. Run /silver:update or reinstall Silver Bullet, then retry." >&2
  exit 1
fi

SB_WORKFLOW_ID=$("$SB_WORKFLOWS_BIN" start /silver:migrate "migrated legacy project state" "$SB_FLOWS")
export SB_WORKFLOW_ID
```

For each inferred-complete flow, mark it complete:

```bash
"$SB_WORKFLOWS_BIN" complete-flow "$SB_WORKFLOW_ID" "<flow-name>"
```

Leave the first uncertain or unfinished flow pending. Do not mark execution, review, security, verification, or ship complete unless the corresponding GSD artifact exists.

### Step 4: Report Migration

Report:

- documentation terminology/path migration result
- workflow id
- inferred complete flows with evidence
- pending next flow
- any uncertainty that requires user review

## Produces

- `.planning/workflows/<id>.md` — active per-instance workflow tracker
- `docs/learnings/` — current portable learnings path
- updated `docs/doc-scheme.md`, `docs/doc-scheme.json`, and `docs/task-doc-checklist.json` keys when present

## Notes

- Do not create `.planning/WORKFLOW.md`.
- If a legacy `.planning/WORKFLOW.md` exists, leave it untouched and treat it as historical evidence only.
- If inferred state is ambiguous, choose the safer pending status and let GSD resume from `.planning/STATE.md`.
- Do not leave new writes pointed at `docs/lessons/`. Read legacy `docs/lessons/` only as migration input.
