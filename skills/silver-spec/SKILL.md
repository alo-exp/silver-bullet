---
name: silver-spec
description: >
  Compile a canonical .planning/SPEC.md and .planning/REQUIREMENTS.md from the newest clarify brief (next=spec) plus any ingest SPEC draft. Gap-fill only empty required sections — does not run the 9-turn interview.
argument-hint: "<feature name or description>"
version: 0.2.0
---

# /sb:spec -- Spec Compiler

SB orchestrator for compiling canonical `.planning/SPEC.md` and `.planning/REQUIREMENTS.md` from the newest `*-CLARIFY-*.md` brief and any ingest SPEC draft.

**This skill does not run the 9-turn Socratic interview.** Interviewing lives in `/sb:clarify --spec` (`next=spec`). Spec is a compiler: read the brief (+ ingest draft), write artifacts, review them.

Never implements features directly -- compiles and writes spec artifacts only.

## Pre-flight: Load Preferences

Read the **User Workflow Preferences** section of `silver-bullet.md` to load user workflow preferences before any other step. Silently apply any stored routing, skip, tool, or mode preferences throughout this workflow.

```bash
grep -A 50 "^## [0-9]\+\. User Workflow Preferences" silver-bullet.md | head -60
```

Display banner:

```
SILVER BULLET ► SPEC COMPILER

Feature: {$ARGUMENTS or "(not specified)"}
Mode:    {greenfield | augment — detected in Step 0}
Brief:   {newest *-CLARIFY-*.md or "(none)"}
```

## Step-Skip Protocol

When the user requests skipping any step:
1. Explain why the step exists (one sentence)
2. Offer: A. Accept skip  B. Lightweight alternative  C. Show me what you have
3. If user chooses A permanently: record in silver-bullet.md §10b and templates/silver-bullet.md.base §9b, then commit both files.

**Non-skippable gates:** `Step 0: consume newest clarify brief when present`, `Step 5: Assumption Consolidation`, `Step 7: Write SPEC.md`, `Step 7a: Review SPEC.md`, `Step 8a: Review REQUIREMENTS.md`, `Step 9a: Review DESIGN.md`. Refuse skip requests for these regardless of §10.

## Step 0: Mode Detection + Input Discovery

**Augment vs greenfield:**

```bash
test -f .planning/SPEC.md && echo "augment" || echo "greenfield"
```

- **If `.planning/SPEC.md` exists:** augment mode. Read the existing spec, show the current `spec-version` and a one-line summary of each section present.
- **If `.planning/SPEC.md` does not exist:** greenfield mode.

Update the Mode field in the banner before continuing.

**Newest clarify brief (MUST consume when present):**

```bash
NEWEST_CLARIFY="$(ls -1t .planning/*-CLARIFY-*.md 2>/dev/null | head -1 || true)"
```

Read `$NEWEST_CLARIFY` in full when it exists. This is the primary interview record.

**Ingest SPEC draft:** if `.planning/INGESTION_MANIFEST.md` exists, treat current `.planning/SPEC.md` (if any) as an ingest dump to merge — not as a finished spec.

**If no clarify brief AND no ingest draft (no SPEC.md and no INGESTION_MANIFEST.md):**

Stop. Do **not** run Turns 1–9 here. Instruct:

> Spec compiles from a clarify brief. Run `/sb:clarify --spec` (or `/sb:clarify --next spec`) first, then re-run `/sb:spec`.

**If ingest draft exists without a clarify brief:** compile from the ingest SPEC, then gap-fill only empty required sections (Step 3). Recommend `/sb:clarify --spec` when domains are thin, but do not block a compile+gap-fill path.

## Step 1: Load Inputs (no live interview)

Collect, in order of authority for compiled content:

1. Newest `*-CLARIFY-*.md` (`next=spec` capture schema)
2. Ingest SPEC draft (MCP dump) when present
3. Existing SPEC.md in augment mode (preserve structure; bump version)

Do **not** re-ask context gathering or the 9 spec turns when the brief already covers those domains.

Map brief sections onto the spec scaffold:

| Brief / ingest | SPEC.md section |
|----------------|-----------------|
| Overview (who + problem) | `## Overview` |
| User Stories (`As a…`) | `## User Stories` |
| UX Flows / main path | `## UX Flows` |
| Acceptance Criteria | `## Acceptance Criteria` |
| Assumptions + Status | `## Assumptions` |
| Out of Scope | `## Out of Scope` |
| Edges / Errors / Data | UX Flows, AC, and/or Open Questions as appropriate |
| Open Questions | `## Open Questions` |
| Source artifacts / JIRA / Figma | frontmatter |

## Step 2: Build SB Spec Scaffold

Build the formal spec scaffold directly in SB.

Read `templates/specs/SPEC.md.template` if present and use it as the canonical
shape. If the template is missing, continue with this minimum scaffold in working
notes so Step 7 can write the file:

- Overview
- Users and goals
- User stories
- UX or workflow flows
- Acceptance criteria
- Requirements
- Assumptions
- Open questions
- Out of scope
- Source artifacts

This is not a fallback path. Do not install or invoke Product Management plugins
for core SB spec compilation.

## Step 3: Domain Completeness + Gap-Fill Only

**NOT a 9-turn tour. NOT a live turn-counter.**

The former min-4 live turn-counter is **retired**. Coverage is **brief-domain completeness**, not live Q&A count.

**Covered domains** (count as done when present in the newest clarify brief or ingest draft):

- **problem** — Overview names who + what the problem is
- **scope** — Out of Scope is non-empty
- **stories** — ≥1 `As a… I want to… so that…`
- **AC** — ≥1 testable acceptance criterion

When those four are covered, do **not** interview. Proceed to Steps 4–7.

**Gap-fill (only):** If a **required SPEC section** would still be empty after compile, ask questions **only for those empty sections** — not a second 9-turn tour.

Required SPEC sections (review-spec QC-1):

- `## Overview`
- `## User Stories`
- `## UX Flows`
- `## Acceptance Criteria`
- `## Assumptions`
- `## Open Questions`
- `## Out of Scope`
- `## Implementations` (header + template placeholder is enough)

If gap-fill answers create implicit assumptions, emit:

`[ASSUMPTION: {what SB is assuming} | Status: Follow-up-required | Owner: TBD]`

**Zero Socratic** unless a required section is still empty after compile.

If the user asks to skip remaining gap-fill while a required section is empty, refuse: that section must be filled or explicitly assumed with Status.

## Step 4: Artifact Injection (conditional -- only if URL provided in brief or ingest)

If no URL is present in the brief, ingest draft, or `$ARGUMENTS`, skip this step entirely.

For each URL provided:

1. Display the URL and describe what will be extracted.
2. Attempt extraction:
   - **Google Doc or PPT URL:** attempt text extraction via WebFetch tool. If accessible, show a 3-bullet summary of extracted content. If inaccessible, record the URL in `source-artifacts:` frontmatter for Phase 13 MCP ingestion.
   - **Figma URL:** record the URL in `figma-url:` frontmatter. Extract visible intent manually from accessible metadata or user-provided context. If inaccessible, keep the URL as a source artifact and ask for the minimum design context needed to proceed.
3. Ask: "A. Incorporate this content into the spec  B. Skip"

If user selects A: incorporate the relevant content into the appropriate sections during Step 7.

## Step 5: Assumption Consolidation

**NON-SKIPPABLE GATE.**

Collect all `[ASSUMPTION: ...]` blocks from the clarify brief, ingest draft, and any Step 3 gap-fill. Present them as a numbered list.

For each assumption still `Follow-up-required` without a recorded choice in the brief, ask:

> A. Resolve now (provide the answer)
> B. Accept as assumption (keep as-is in spec)
> C. Tag for follow-up (Status: Follow-up-required)

Update the `Status:` field of each assumption block accordingly:
- A → `Status: Resolved` (record the resolution text)
- B → `Status: Accepted`
- C → `Status: Follow-up-required`

If the brief already recorded A/B/C, honor it — do not re-interview.

If no assumptions were surfaced, note this and ask: "Before we write the spec, are there any open questions or unknowns you want to flag?"

## Step 6: SB Design Context Check (conditional)

Only if a design artifact (Figma URL or design-related Google Doc) was provided in the brief, ingest, or `$ARGUMENTS`:

Perform the design context check directly in SB. This absorbs the design critique
behavior SB requires for spec quality without requiring the external Design
plugin.

Capture concise findings for:

- primary user flow and entry/exit states
- information architecture or component implications
- accessibility or copy risks that affect requirements
- open design questions that must be resolved before implementation

Add any design-affecting assumptions to the assumption list before Step 7.

## Step 7: Write .planning/SPEC.md

**NON-SKIPPABLE GATE.**

1. Read `templates/specs/SPEC.md.template` to get the canonical structure.
2. **Determine spec-version:**
   - Greenfield mode: `spec-version: 1`
   - Augment mode: read existing `spec-version:` from `.planning/SPEC.md` frontmatter, increment by 1
3. Populate all sections from the **compiled** brief + ingest draft + gap-fill (Steps 1–6) — **not** by re-running clarify turns:
   - `## Overview` — from brief Overview / problem domain
   - `## User Stories` — from brief User Stories
   - `## UX Flows` — from brief UX Flows / edges / errors / data as mapped
   - `## Acceptance Criteria` — from brief AC (compiler source of truth for Step 8)
   - `## Assumptions` — all `[ASSUMPTION: ...]` blocks with final Status values from Step 5
   - `## Open Questions` — from brief Open Questions and Follow-up-required assumptions
   - `## Out of Scope` — from brief Out of Scope
   - `## Implementations` — write the section header with the placeholder comment from the template (`<!-- Populated automatically by pr-traceability.sh hook post-merge. -->`). Leave the body empty; the `pr-traceability.sh` hook appends merged-PR rows here post-merge. The section header MUST be present so the traceability hook has an anchor to append to.
4. Set frontmatter fields:
   - `spec-version:` — as calculated above
   - `status: Draft`
   - `jira-id:` — from brief / ingest if provided, else empty string
   - `figma-url:` — from brief / ingest if provided, else empty string
   - `source-artifacts:` — list of URLs from brief / ingest (empty list if none)
   - `created:` — today's date (greenfield) OR preserve existing value (augment)
   - `last-updated:` — today's date
5. Write to `.planning/SPEC.md` using the active runtime file-writing mechanism.

Every `[ASSUMPTION: ...]` block in the spec must include `Status:` and `Owner:` fields. No untagged assumptions.

### Step 7a: Review SPEC.md

**NON-SKIPPABLE GATE.**

Invoke `/artifact-reviewer .planning/SPEC.md --reviewer review-spec` through the active runtime's SB-recognized skill invocation channel.

Do NOT proceed to Step 8 until /artifact-reviewer reports 2 consecutive clean passes. If issues are found, /artifact-reviewer will apply fixes and re-review automatically. If /artifact-reviewer surfaces an unresolvable issue after 5 rounds, STOP and present it to the user.

## Step 8: Write .planning/REQUIREMENTS.md

Derive from **SPEC.md acceptance criteria**, not from the clarify brief.

1. Read `templates/specs/REQUIREMENTS.md.template` to get the canonical structure.
2. Derive `REQ-XX` IDs from the acceptance criteria in `.planning/SPEC.md` `## Acceptance Criteria`. Assign sequential IDs starting at REQ-01.
3. Derive `NFR-XX` IDs from any non-functional concerns in SPEC.md (performance, security, accessibility, reliability). Assign sequential IDs starting at NFR-01.
4. Mirror the Out of Scope section from SPEC.md.
5. Mirror the Open Questions section from SPEC.md.
6. Write to `.planning/REQUIREMENTS.md` using the active runtime file-writing mechanism.

### Step 8a: Review REQUIREMENTS.md

**NON-SKIPPABLE GATE.**

Invoke `/artifact-reviewer .planning/REQUIREMENTS.md --reviewer review-requirements` through the active runtime's SB-recognized skill invocation channel.

Do NOT proceed to Step 9 until /artifact-reviewer reports 2 consecutive clean passes. If issues are found, /artifact-reviewer will apply fixes and re-review automatically. If /artifact-reviewer surfaces an unresolvable issue after 5 rounds, STOP and present it to the user.

## Step 9: Write .planning/DESIGN.md (conditional)

Only if a design artifact or Figma URL was provided:

1. Read `templates/specs/DESIGN.md.template` to get the canonical structure.
2. Populate from design context gathered in Steps 4 and 6.
3. Write to `.planning/DESIGN.md` using the active runtime file-writing mechanism.

### Step 9a: Review DESIGN.md (conditional)

**Only if Step 9 produced a DESIGN.md.**

Invoke `/artifact-reviewer .planning/DESIGN.md --reviewer review-design` through the active runtime's SB-recognized skill invocation channel.

Do NOT proceed to Step 10 until /artifact-reviewer reports 2 consecutive clean passes. If issues are found, /artifact-reviewer will apply fixes and re-review automatically. If /artifact-reviewer surfaces an unresolvable issue after 5 rounds, STOP and present it to the user.

## Step 10: Commit artifacts

Stage and commit all spec artifacts:

```bash
git add .planning/SPEC.md
git diff --quiet .planning/REQUIREMENTS.md 2>/dev/null || git add .planning/REQUIREMENTS.md
git add .planning/DESIGN.md 2>/dev/null || true
git commit -m "spec: [feature-slug] v{spec-version} draft"
```

Replace `[feature-slug]` with a kebab-case version of the feature name from the brief or `$ARGUMENTS`. Replace `{spec-version}` with the actual version number written in Step 7.

## Step 11: Summary

Display a closing banner:

```
SPEC COMPILE COMPLETE

Feature:         {feature name}
Spec version:    {spec-version}
Brief:           {newest *-CLARIFY-*.md or "(none — ingest/gap-fill)"}
Sections:        {count of ## sections in SPEC.md}
Assumptions:     {count of [ASSUMPTION] blocks}
Open questions:  {count of open question items}
Status:          Draft

Next step: run /sb:feature to begin implementation planning.
```

If any assumptions have `Status: Follow-up-required`, add:

```
⚠  {N} assumption(s) require follow-up before implementation begins.
   Review .planning/SPEC.md §Assumptions before running /sb:feature.
```
