---
name: "silver:release"
title: "Release"
description: >
  This skill should be used for SB-owned milestone release: silver:quality-gates -> audit -> gap closure (max 2x) -> docs -> silver:ship -> milestone archive -> silver:create-release
argument-hint: "<version or release description, e.g. v1.2.0>"
version: 0.2.0
---

# /silver:release - Ship, Version, Publish, Go Live

SB-owned milestone publishing. This workflow owns release composition, milestone
audit, gap closure, documentation, phase-level ship readiness, milestone archive,
and final release publication.

Use `silver:ship` for phase-level branch/PR/CI readiness. Use `silver:release`
when the user asks for a versioned milestone release, public publication,
changelog, tag, GitHub Release, or production go-live.

Never publishes directly. It coordinates gates and writes release evidence before
the final `silver:create-release` step.

## Pre-flight: Load Preferences

Read the **User Workflow Preferences** section of `silver-bullet.md` before any
other step.

```bash
grep -A 50 "^## [0-9]\+\. User Workflow Preferences" silver-bullet.md | head -60
```

Display banner:

```text
SILVER BULLET > RELEASE WORKFLOW

Release: {$ARGUMENTS or "(version not specified)"}
```

## Composition Proposal

Release is a milestone-completion workflow. It does not run a normal per-phase
implementation loop unless release audits find gaps.

### Context Scan

Read these artifacts when present:

- `.planning/STATE.md`
- `.planning/ROADMAP.md`
- `.planning/REQUIREMENTS.md`
- `.planning/SPEC.md`
- `.planning/DESIGN.md`
- `.planning/phases/**`
- `.planning/reports/**`
- `docs/task-doc-checklist.json`
- `docs/CHANGELOG.md`

Detect UI release scope:

```bash
ls .planning/phases/*/UI-SPEC.md .planning/phases/*/UI-REVIEW.md 2>/dev/null | grep -q . \
  && echo "Include DESIGN HANDOFF - UI phases detected" \
  || echo "Skip DESIGN HANDOFF - no UI phases in this milestone"
```

### Default Flow Chain

QUALITY GATE -> DOMAIN AUDIT -> UAT AUDIT -> MILESTONE AUDIT -> SECURITY -> GAP CLOSURE
[conditional] -> DESIGN HANDOFF [if UI scope] -> DOCUMENT -> REVIEW -> VERIFY ->
SHIP -> DEPLOYMENT READINESS -> CANARY [if deployed] -> RETRO ITEMS ->
MILESTONE ARCHIVE -> CREATE RELEASE

Display the proposed chain and skipped flows before starting. In autonomous mode,
auto-confirm the composition and record the decision.

### Workflow Tracking

Resolve `scripts/workflows.sh`, start `/silver:release`, export
`SB_WORKFLOW_ID`, mark each completed flow with `complete-flow`, and close the
workflow with `complete` only after the final release step succeeds.

```bash
SB_FLOWS="<confirmed comma-separated flow list>"

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

SB_WORKFLOW_ID=$("$SB_WORKFLOWS_BIN" start /silver:release "the user's original request" "$SB_FLOWS")
export SB_WORKFLOW_ID
echo "Workflow tracker started: $SB_WORKFLOW_ID"
```

## Step-Skip Protocol

When the user requests skipping any step:

1. Explain why the step exists in one sentence.
2. Offer: A. Accept skip  B. Lightweight alternative  C. Show current evidence.
3. If the user makes the skip permanent, record it in `silver-bullet.md` and
   `templates/silver-bullet.md.base`.

**Non-skippable gates:** `silver:quality-gates`, `security`, UAT audit,
milestone completion audit, cross-artifact review when release artifacts exist,
fresh full-suite verification via `verify-tests`, `silver:verify`,
`silver:ship`, and milestone archive before `silver:create-release`.

Non-skippable release gates:

- `silver:quality-gates`
- `security`
- UAT audit
- milestone completion audit
- cross-artifact review when release artifacts exist
- fresh full-suite verification via `verify-tests`
- `silver:verify`
- `silver:ship`
- milestone archive before `silver:create-release`

## Step 0: Pre-Release Quality Gates

Invoke `silver:quality-gates`. Purpose: run the release-level 8-dimension quality
sweep plus conditional AI/LLM safety and DevOps gates where applicable.

## Step 0a: Pre-Release Domain Audit

Invoke or apply `silver:domain-audit --mode release` across release-touched
surfaces. Select packs for API, data, dependencies, performance, structure,
CI/workflows, environment/secrets, accessibility, content/search, UI system,
architecture, runtime-release, incident-retro, and benchmark evidence as
applicable.

The release cannot proceed with unresolved `BLOCK` domain findings. Deferred
`WARN` findings must be filed through `silver:add` and referenced in the
milestone summary.

## Step 1: Cross-Phase UAT Audit

Build `.planning/RELEASE-UAT-AUDIT.md` from milestone evidence:

- completed and pending `.planning/**/UAT.md`
- `.planning/**/VERIFICATION.md`
- `.planning/REQUIREMENTS.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- open review/security findings

The audit must list:

- released user-facing capabilities
- acceptance criteria and matching evidence
- unverified or partially verified criteria
- known issues that would ship if release proceeds
- recommendation: `PASS`, `PASS_WITH_KNOWN_ISSUES`, or `BLOCK`

Do not proceed on `BLOCK` unless the user explicitly chooses to convert the
blockers into documented known issues.

## Step 2: Milestone Completion Audit

Build `.planning/RELEASE-MILESTONE-AUDIT.md` by comparing original intent to
current evidence:

- milestone goals from `.planning/ROADMAP.md`
- requirements from `.planning/REQUIREMENTS.md`
- current phase state from `.planning/STATE.md`
- implementation summaries
- verification, review, security, UI, and documentation artifacts

The audit must list:

- committed scope completed
- committed scope missing
- scope intentionally deferred
- release risks
- required gap-closure phases

## Step 2a: Security Hard Gate

Invoke `security`. Purpose: independent pre-release security review across the
changes being released. This gate is mandatory even if the normal workflow
preferences allow lighter review.

## Step 2b: Gap-Closure Loop (conditional, max 2 iterations)

If Step 1, Step 2, Step 2a, or review gates find blocking gaps, run at most two
gap-closure iterations.

For each iteration:

1. Invoke `silver:plan` to create the gap-closure plan.
2. Route execution to `silver:feature`, `silver:bugfix`, `silver:ui`, or
   `silver:devops` based on gap type.
3. Re-run `silver:quality-gates`, the affected audit, `security` when relevant,
   and verification for the touched scope.
4. Update `.planning/RELEASE-GAP-CLOSURE.md`.

If blockers remain after two iterations, ask the user directly when the host
supports it; otherwise ask directly. The user must choose one of:

- release anyway with documented known issues
- extend the milestone and continue work outside this release workflow
- abort release

## Step 3: Milestone UI Handoff (conditional)

Run this step only when the milestone contains UI scope.

Use `silver:ui-contract` and `silver:ui-review` evidence to build
`.planning/UI-HANDOFF.md` with:

- screens, flows, components, and states included in the release
- accessibility status and unresolved UI risks
- design token/component inventory where applicable
- screenshots or artifact references when available
- final recommendation: `PASS`, `PASS_WITH_KNOWN_ISSUES`, or `BLOCK`

Do not introduce a dependency on external design plugins. If optional design
plugins are available and the user explicitly requests them, record their output
as supplemental evidence only.

## Step 4: Documentation

Invoke `silver:ensure-docs --release` when available. Otherwise, directly verify
the configured documentation scheme and update release-facing docs.

Required release documentation checks:

- `README.md` and user docs describe the shipped behavior accurately.
- `docs/CHANGELOG.md` has or will receive the release entry.
- `site/help/` and public site content match the current SB lifecycle.
- `docs/task-doc-checklist.json` has no stale claims for release-touched areas.
- project documentation does not advertise retired dependency ownership.

## Step 5: Milestone Summary

Build `.planning/MILESTONE-SUMMARY.md` from audit and documentation evidence:

- milestone goals
- completed capabilities
- notable fixes
- security/reliability/DevOps notes
- known issues and deferrals
- verification summary
- release-note candidates

This summary is input to `silver:create-release`.

## Step 6: Clean PR Branch Preference

Ask whether the user wants a clean PR branch when the repo is dirty with planning
or generated artifacts:

```text
Would you like a clean PR branch for this release?

A. Yes - run silver:branch-finish
B. No - release as-is
C. Save as permanent preference
```

If A, invoke `silver:branch-finish`. If C, record the preference in
`silver-bullet.md` and `templates/silver-bullet.md.base`.

## Step 7: Cross-Artifact Consistency Review

When `.planning/SPEC.md` and `.planning/REQUIREMENTS.md` exist, invoke:

```text
/artifact-reviewer --reviewer review-cross-artifact --artifacts .planning/SPEC.md .planning/REQUIREMENTS.md .planning/ROADMAP.md
```

Add `.planning/DESIGN.md` when it exists. Do not proceed until the review passes
or the user explicitly accepts documented known issues after the five-round cap.

## Step 8: Deployment Readiness (conditional)

If the release includes deployment, run SB DevOps readiness:

- invoke `silver:devops` for infrastructure/deployment changes that still need
  work
- invoke `silver:deploy` when a deployment command, platform, environment, or
  production/staging rollout is part of the release
- invoke `devops-quality-gates` for release readiness checks
- invoke or apply `silver:domain-audit` with `ci-workflow`,
  `environment-secrets`, and `runtime-release` packs
- verify rollback plan, environment config, monitoring, alert ownership, and
  deployment command safety

Provider/tool-specific DevOps plugins remain optional enrichment through SB's
DevOps router. Do not require external Engineering plugins for release.

If the release deploys to a live runtime, invoke `silver:canary` after the
deployment or record why canary evidence is unavailable. A release cannot claim
runtime confidence from CI alone.

## Step 9: Mandatory Verification

Invoke `verify-tests` after the pre-release quality gate and before any ship or
release action. Purpose: rerun the full local test suite in the current release
session.

Then invoke `silver:verify` for release-scope evidence review. Do not proceed to
ship until both gates have fresh passing evidence.

## Step 10: Ship - Branch, PR, CI, Deploy Readiness

Invoke `silver:ship`. Purpose: complete phase-level shipping duties before the
milestone archive:

- git scope hygiene
- PR body and traceability
- CI status
- deployment readiness or deployment result when applicable
- state updates for shipped scope

Do not proceed to milestone archive until `silver:ship` reports success or the
user explicitly accepts a documented release exception.

## Step 11: Complete Milestone Archive

Create `.planning/archive/<milestone-slug>/` and copy the release evidence:

- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/REQUIREMENTS.md` when present
- `.planning/RELEASE-UAT-AUDIT.md`
- `.planning/RELEASE-MILESTONE-AUDIT.md`
- `.planning/RELEASE-GAP-CLOSURE.md` when present
- `.planning/MILESTONE-SUMMARY.md`
- `.planning/REVIEW-ROUNDS.md` when present
- `.planning/review-analytics.jsonl` when present

Update `.planning/STATE.md` and `.planning/ROADMAP.md` so the completed
milestone is clearly archived and the next milestone/phase state is explicit.

If `.planning/REVIEW-ROUNDS.md` exists, rotate it into the milestone archive and
start fresh only after preserving the archived copy.

## Step 12: Create Release

Only after Step 11 has landed, sync marketplace version surfaces when applicable:

```bash
bash scripts/sync-release-marketplace-versions.sh
```

The release contract requires the marketplace sync, release docs, and manifest
changes to be part of the release commit before any tag is created:

- run `bash scripts/sync-release-marketplace-versions.sh "$VERSION"` before the
  release commit
- stage the release docs and marketplace manifests with
  `git add CHANGELOG.md README.md .codex-plugin/marketplace.json plugins/silver-bullet/.codex-plugin/plugin.json`
- confirm each upstream marketplace repo touched by the sync has been committed
  and pushed before the release tag

Then invoke `silver:create-release`. Purpose: update release notes, changelog,
README badge, marketplace manifests, tag, GitHub Release, live matrix, CI wait,
and post-release refresh according to the dedicated release-creation skill.

Tag placement is last: it must include quality evidence, docs updates, ship
evidence, and milestone archive commits.

## Step 13: Post-Release Items Summary

After `silver:create-release` publishes the release tag, generate a consolidated
summary of issues, backlog items, knowledge, and learnings recorded during the
milestone.

Use the previous release tag as the lower bound when available. If no previous
tag exists, include all session logs.

Report:

- sessions scanned
- issues and backlog items filed via `silver:add`
- knowledge and learnings recorded via `silver:rem`
- release URL or manual publication note

For major releases, incident-heavy ranges, or releases that changed delivery
process, invoke `silver:retro` or create a `.planning/RETRO.md` action summary.

## Completion

Complete the workflow tracker only after all release gates, archive updates, tag
publication, and post-release refresh steps have succeeded or have explicit
documented user exceptions.
