---
name: "silver:migrate"
title: "Silver: /silver:migrate - Migrate"
description: "This skill should be used when the user runs `/silver:migrate` or asks to migrate an older Silver Bullet project from the retired single-file WORKFLOW.md model to per-instance `.planning/workflows/<id>.md` tracking."
version: 0.2.0
---

# silver:migrate

Migrates an older mid-milestone project to the current composed-workflow tracker.

The legacy `.planning/WORKFLOW.md` file is retired. Do not create or update it.

## When to Use

- `.planning/` exists with GSD state artifacts.
- The project was started before per-instance workflow tracking.
- The user explicitly runs `/silver:migrate` or asks to migrate workflow tracking.

## Prerequisites

- `.planning/STATE.md` must exist.
- `scripts/workflows.sh` must be available from the project root or plugin install.
- If `.planning/workflows/*.md` already contains an active workflow, report the active id and stop; migration is unnecessary.

## Steps

### Step 1: Scan Existing Artifacts

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

- workflow id
- inferred complete flows with evidence
- pending next flow
- any uncertainty that requires user review

## Produces

- `.planning/workflows/<id>.md` — active per-instance workflow tracker

## Notes

- Do not create `.planning/WORKFLOW.md`.
- If a legacy `.planning/WORKFLOW.md` exists, leave it untouched and treat it as historical evidence only.
- If inferred state is ambiguous, choose the safer pending status and let GSD resume from `.planning/STATE.md`.
