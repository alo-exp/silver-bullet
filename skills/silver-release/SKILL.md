---
name: silver-release
description: This skill should be used for SB-orchestrated milestone release: silver-quality-gates → audit → gap-closure (max 2x) → docs → release notes → gsd-ship → gsd-complete-milestone
argument-hint: "<version or release description, e.g. v1.2.0>"
version: 0.1.0
---

# /silver:release — Ship, Version, Publish, Go Live

SB orchestrator for milestone-level publishing. Handles versioned releases, changelogs, documentation, GitHub Releases, and milestone archival.

**Distinction from gsd-ship:** `gsd-ship` inside other workflows = phase-level merge (push branch → create PR → prepare for merge). `silver:release` = milestone-level publishing (versioned release, docs, changelog, GitHub Release, milestone archival). These are different abstraction levels. SB disambiguates "ship" intent at routing time.

**Entry triggers:** "release", "publish", "version", "changelog", "go live", "cut a release", "tag v", "ship to users", "deploy to prod"

Never publishes directly — orchestrates only.

## Pre-flight: Load Preferences

Read the **User Workflow Preferences** section of `silver-bullet.md` to load user workflow preferences before any other step.

```bash
grep -A 50 "^## [0-9]\+\. User Workflow Preferences" silver-bullet.md | head -60
```

Display banner:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 SILVER BULLET ► RELEASE WORKFLOW
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Release: {$ARGUMENTS or "(version not specified)"}
```

## Composition Proposal

Before beginning execution, read existing artifacts to determine context and propose which PATHs to include or skip.

### 1. Context Scan

Release is a milestone-completion workflow — short chain focused on quality gate, documentation, and publishing. No per-phase loop.

| Artifact | Signal | Action |
|----------|--------|--------|
| UI-SPEC.md or UI-REVIEW.md in any phase directory | Milestone has UI phases | Include FLOW 15 (DESIGN HANDOFF) |
| `.planning/phases/*/UI-SPEC.md` or `.planning/phases/*/UI-REVIEW.md` absent | No UI phases in milestone | Skip FLOW 15 (DESIGN HANDOFF) |

```bash
# Detect UI phases in current milestone
ls .planning/phases/*/UI-SPEC.md .planning/phases/*/UI-REVIEW.md 2>/dev/null | grep -q . \
  && echo "Include FLOW 15 — UI phases detected" \
  || echo "SKIP FLOW 15 — no UI phases in this milestone"
```

### 2. Build Path Chain

Construct the proposed flow chain for milestone release. Default chain:

FLOW 12 (QUALITY GATE) → FLOW 15 (DESIGN HANDOFF) [only if UI milestone detected] → FLOW 16 (DOCUMENT) → FLOW 17 (RELEASE)

Short chain — release produces a versioned milestone artifact, not implementation code.

### 3. Display Proposal

Display the composition proposal to the user:

```
┌──────────────────────────────────────────────────────────────┐
│ SILVER BULLET ► FLOW COMPOSED                                │
├──────────────────────────────────────────────────────────────┤
│ Flows: QUALITY GATE → DOCUMENT → RELEASE                     │
│ Skipped: DESIGN HANDOFF — no UI phases detected              │
└──────────────────────────────────────────────────────────────┘
Approve composition? [Y/n]
```

(If UI milestone detected, DESIGN HANDOFF appears between QUALITY GATE and DOCUMENT.)

### 4. Auto-Confirm in Autonomous Mode

In autonomous mode (§10e), auto-confirm the composition proposal with a log message:

```
⚡ Autonomous mode: auto-confirming composition — {path count} paths, {skipped count} skipped
```

### 5. Create WORKFLOW.md

If `.planning/WORKFLOW.md` does not exist, create it from `templates/workflow.md.base`:
- Populate `Intent:` with the release version/description ($ARGUMENTS)
- Populate `Composed:` with the current ISO timestamp
- Populate `Composer:` with `/silver:release`
- Populate `Mode:` with the current mode (interactive or autonomous)
- Record the confirmed flow chain in the Flow Log section header

After each path completes, write status to Flow Log table:

```
| {#} | FLOW {N} ({name}) | complete | {artifacts produced} | ✓ |
```

## Step-Skip Protocol

When the user requests skipping any step:
1. Explain why the step exists (one sentence)
2. Offer: A. Accept skip  B. Lightweight alternative  C. Show me what you have
3. If user chooses A permanently: record in silver-bullet.md §10b and templates/silver-bullet.md.base §10b, commit both.

**Non-skippable gates:** `silver:security` (Step 2a), `silver:silver-quality-gates` pre-release (Step 0), `gsd-verify-work` (embedded in milestone audit), cross-artifact review (Step 6) must pass before Step 7 (gsd-ship), `gsd-ship` (Step 7) must succeed before Step 8 (gsd-complete-milestone), and Step 8 must succeed before Step 9 (Create Release). Tag is placed last — this ordering is non-negotiable.

## Step 0: Pre-Release Quality Gates (9 dimensions)

Invoke `silver:silver-quality-gates` via the Skill tool. Purpose: full 9-dimension sweep before any release audit begins — reliability, security, scalability, usability, testability, modularity, reusability, extensibility. Non-skippable.

## Step 1: Cross-Phase UAT

Invoke `gsd-audit-uat` via the Skill tool. Purpose: cross-phase UAT — surface all outstanding gaps before release. This gives a complete picture of the milestone state before deciding whether to ship.

## Step 2: Milestone Completion Audit

Invoke `gsd-audit-milestone` via the Skill tool. Purpose: compare milestone completion vs original intent — are all committed features shipped?

**After audit:** check for gaps.

## Step 2a: Security Hard Gate

Invoke `silver:security` via the Skill tool. Purpose: independent pre-release security review — mandatory regardless of §10 preferences. Non-skippable. Runs after milestone audit (Step 2) so it covers the full set of changes being released.

## FLOW DESIGN HANDOFF — Milestone UI handoff

**Prerequisite Check:**
```bash
# Scan phase directories for UI-SPEC.md or UI-REVIEW.md existence
ls .planning/phases/*/UI-SPEC.md .planning/phases/*/UI-REVIEW.md 2>/dev/null | grep -q . || echo "SKIP: No UI phases in this milestone — FLOW DESIGN HANDOFF not needed"
```

**Trigger note:** Activated when milestone has UI phases (detected by UI-SPEC.md or UI-REVIEW.md in any phase directory) AND currently in release flow. Runs inside FLOW RELEASE only — never in the per-phase sequence.

**Steps** (all via Skill tool):
1. `design:design-handoff` (Always in this path — produce handoff package)
2. `design:design-system` (As-needed — final component inventory, design token reconciliation)

**Produces:** Handoff package.

**Exit Condition:** Handoff package produced.

## Step 2b: Gap-Closure Loop (conditional, max 2 iterations)

**Only if gaps found in Step 2:**

Track iteration count (starts at 0).

**Iteration gate:** If iteration count reaches 2 and gaps remain, do NOT start another iteration. Instead, present to user using AskUserQuestion:

> Release gap limit reached (2 gap-closure iterations completed). Remaining gaps:
> {list gaps from gsd-audit-milestone output}
>
> A. Release anyway — document gaps as known issues, proceed to Step 3a
> B. Extend milestone — defer release, continue work outside this workflow
> C. Abort release — do not ship, requires manual decision to resume

Wait for user selection. If A: proceed to Step 3a with gaps documented. If B or C: exit workflow.

**When iteration count < 2:**

1. Invoke `gsd-plan-milestone-gaps` via the Skill tool. Purpose: plan the gap closure phases.
2. Invoke `silver:feature` via the Skill tool for each gap phase.
3. After gap phases complete, return to Step 0 (full quality gate sweep again).
4. Increment iteration count.
5. Re-run Steps 1–2 to check if gaps are resolved.

## Step 3a: Verify Existing Documentation

Invoke `gsd-docs-update` via the Skill tool. Purpose: verify all existing docs are accurate against current codebase — correct any outdated content before generating new docs.

## Step 3b: Generate/Update Documentation

After gsd-docs-update completes (accuracy verified), invoke `/documentation` via the Skill tool. Purpose: generate/update GitHub README, user guide, website help section, and project page. Runs AFTER gsd-docs-update so it generates new content on top of verified accuracy — never generates on stale foundation.

## Step 4: Milestone Summary

Invoke `gsd-milestone-summary` via the Skill tool. Purpose: generate milestone narrative for release notes.

## Step 5: PR Branch (ask user)

Ask using AskUserQuestion:

> Would you like a clean PR branch (strips .planning/ commits)?
>
> A. Yes — run gsd-pr-branch  B. No — release as-is  C. Save as permanent preference

If A: invoke `gsd-pr-branch` via the Skill tool.
If C: record in silver-bullet.md §10e and templates/silver-bullet.md.base §10e, commit both.

## Step 6: Cross-Artifact Consistency Review

**Only if `.planning/SPEC.md` and `.planning/REQUIREMENTS.md` exist:**

Invoke `/artifact-reviewer --reviewer review-cross-artifact --artifacts .planning/SPEC.md .planning/REQUIREMENTS.md .planning/ROADMAP.md` (add `.planning/DESIGN.md` if it exists).

Do NOT proceed to Step 7 (Ship) until cross-artifact review reports clean pass. If unresolvable after 5 rounds, STOP and present to the user.

## Step 6b: Pre-Ship Deployment Checklist

Invoke `/deploy-checklist` via the Skill tool. Purpose: verify all pre-deployment conditions are met before gsd-ship executes — infrastructure, environment config, rollback plan, monitoring. Non-skippable.

## Step 7: Ship — Deploy, CI Green

Invoke `gsd-ship` via the Skill tool. Purpose: deploy, ensure CI is green, push the branch. This MUST succeed before milestone is archived.

**Enforcement:** Do not proceed to Step 8 until gsd-ship confirms CI green and deploy succeeded.

## Step 8: Complete Milestone

**Only after Step 7 (gsd-ship) confirms success:**

Invoke `gsd-complete-milestone` via the Skill tool. Purpose: archive milestone, prepare for next version. Produces archival commits (ROADMAP, MILESTONES, STATE, RETROSPECTIVE). These commits MUST be on the branch before the release tag is placed.

## Step 9: Create Release

**Only after Step 8 (`gsd-complete-milestone`) commits are on the branch:**

Invoke `silver:silver-create-release` via the Skill tool. Purpose: SB-owned release creation — updates CHANGELOG.md and README version badge, commits those changes, creates the version tag, and publishes the GitHub Release. Tag is placed LAST so it captures all archival commits.

> **Why last?** Creating the tag before milestone archival causes the archival commits to appear after the tag, requiring an immediate patch release. The tag must be the final commit in the release.

## Step 9b: Post-Release Items Summary

**Trigger:** Execute this step only after Step 9 (`silver-create-release`) has completed and the release tag is published.

Generate a consolidated summary of all items filed and knowledge/lessons recorded during this milestone.

### Step 9b.1: Determine milestone window

```bash
# Read milestone name from STATE.md frontmatter
MILESTONE=$(grep '^milestone:' .planning/STATE.md | awk '{print $2}')

# Get the previous milestone release tag date (lower bound for session log filter)
# Finds the second-to-last semver tag — the tag before the one just created
PREV_TAG=$(git tag --sort=version:refname | grep '^v[0-9]' | tail -2 | head -1)
MILESTONE_START=$(git log --format="%ai" "$PREV_TAG" -1 2>/dev/null | cut -d' ' -f1 || echo "1970-01-01")
```

If PREV_TAG is empty or git log fails: use `MILESTONE_START="1970-01-01"` (include all logs).

### Step 9b.2: Collect Items Filed from session logs

```bash
# Session logs are named docs/sessions/YYYY-MM-DD-HH-MM-SS.md
# Filter to logs whose filename date is on or after MILESTONE_START
items_filed=""
sessions_scanned=0
for log in docs/sessions/*.md; do
  [ -f "$log" ] || continue
  log_date=$(basename "$log" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}')
  if [[ "$log_date" > "$MILESTONE_START" ]] || [[ "$log_date" = "$MILESTONE_START" ]]; then
    sessions_scanned=$((sessions_scanned + 1))
    # Extract lines from ## Items Filed section until next ## heading
    section=$(awk '/^## Items Filed$/{found=1; next} found && /^## /{exit} found{print}' "$log")
    if [ -n "$section" ] && ! echo "$section" | grep -qF '(none)'; then
      items_filed="${items_filed}${section}"$'\n'
    fi
  fi
done
```

### Step 9b.3: Present consolidated summary

If `items_filed` is empty:

Output:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 MILESTONE {MILESTONE} — POST-RELEASE ITEMS SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Session logs scanned: {sessions_scanned} (from {MILESTONE_START} to today)

No items were recorded during this milestone via /silver-add or /silver-rem.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

If `items_filed` is non-empty, separate items by prefix:
- Lines starting with `- SB-` or `- #` → filed via /silver-add (issues/backlog)
- Lines starting with `- [knowledge]:` or `- [lessons]:` → recorded via /silver-rem

Output a formatted summary:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 MILESTONE {MILESTONE} — POST-RELEASE ITEMS SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Session logs scanned: {sessions_scanned} (from {MILESTONE_START} to today)

Issues & Backlog filed via /silver-add:
{list of SB-/# lines, or "(none)"}

Knowledge & Lessons recorded via /silver-rem:
{list of [knowledge]/[lessons] lines, or "(none)"}

Total: {N} issues/backlog items, {M} knowledge/lessons entries
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
