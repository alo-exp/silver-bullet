---
name: silver-spec
description: This skill should be used for AI-guided Socratic spec elicitation: interactive dialogue producing SPEC.md + REQUIREMENTS.md from scratch or augmenting an existing draft
argument-hint: "<feature name or description>"
version: 0.1.0
---

# /silver:spec -- Spec Elicitation Workflow

SB orchestrator for requirements elicitation. Guides PM/BA through structured Socratic dialogue to produce canonical `.planning/SPEC.md` and `.planning/REQUIREMENTS.md` artifacts.

Never implements features directly -- orchestrates dialogue and writes spec artifacts only.

## Pre-flight: Load Preferences

Read the **User Workflow Preferences** section of `silver-bullet.md` to load user workflow preferences before any other step. Silently apply any stored routing, skip, tool, or mode preferences throughout this workflow.

```bash
grep -A 50 "^## [0-9]\+\. User Workflow Preferences" silver-bullet.md | head -60
```

Display banner:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 SILVER BULLET ► SPEC ELICITATION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Feature: {$ARGUMENTS or "(not specified)"}
Mode:    {greenfield | augment — detected in Step 0}
```

## Step-Skip Protocol

When the user requests skipping any step:
1. Explain why the step exists (one sentence)
2. Offer: A. Accept skip  B. Lightweight alternative  C. Show me what you have
3. If user chooses A permanently: record in silver-bullet.md §10b and templates/silver-bullet.md.base §10b, then commit both files.

**Non-skippable gates:** `Step 3: Socratic Elicitation`, `Step 5: Assumption Consolidation`, `Step 7: Write SPEC.md`, `Step 7a: Review SPEC.md`, `Step 8a: Review REQUIREMENTS.md`, `Step 9a: Review DESIGN.md`. Refuse skip requests for these regardless of §10.

## Step 0: Mode Detection

Check whether `.planning/SPEC.md` already exists:

```bash
test -f .planning/SPEC.md && echo "augment" || echo "greenfield"
```

- **If `.planning/SPEC.md` exists:** augment mode. Read the existing spec, show the current `spec-version` and a one-line summary of each section present.
- **If `.planning/SPEC.md` does not exist:** greenfield mode. Proceed directly to Step 1.

Update the Mode field in the banner to reflect the detected mode before continuing.

## Step 1: Context Gathering

Ask the PM/BA for the following in a single prompt. Mark required items clearly; optional items are lettered:

> **Let's start with context for this spec.**
>
> 1. Feature name *(required)*
> 2. Feature description — 1-2 sentences on what it does and for whom *(required)*
>
> Optional — provide any that apply:
>
> A. JIRA ticket ID
> B. Figma URL
> C. Google Doc or PPT URL

If any URL is provided in A, B, or C, note it internally for artifact injection in Step 4.

## Step 2: Invoke product-management:write-spec

Invoke `product-management:write-spec` via the Skill tool. This generates a formal PM spec scaffold that provides structure for the Socratic dialogue to fill in.

If the skill is unavailable (invocation fails or skill not found), proceed without it — the SPEC.md template provides equivalent structure. Do not block on this step.

## Step 3: Socratic Elicitation Dialogue

**NON-SKIPPABLE GATE.**

Run 9 questioning turns in sequence. Each turn addresses one requirements domain.

**After EACH answer from the PM/BA:**
1. State any implicit assumption you made interpreting the answer: "I'm assuming [X] — is that right?"
2. If the PM/BA says "I don't know yet", cannot resolve, or gives a vague answer: emit an assumption block immediately:
   `[ASSUMPTION: {what SB is assuming} | Status: Follow-up-required | Owner: TBD]`
3. Ask: "Anything else on this topic, or shall we move to the next?"

Collect all answers and assumption blocks for Steps 5-8.

**Turn sequence:**

| Turn | Domain | Question |
|------|--------|----------|
| 1 | Problem | "What problem does this solve? For whom?" |
| 2 | User goal | "When a user reaches this feature, what do they want to accomplish?" |
| 3 | Scope boundary | "What is explicitly OUT of scope for this feature?" |
| 4 | User stories | "Walk me through the main thing a user does with this feature, step by step" |
| 5 | Acceptance criteria | "How do we know this works correctly? List one criterion at a time" |
| 6 | Edge cases | "What happens when [common failure scenario]?" |
| 7 | Error states | "What should the user see when something goes wrong?" |
| 8 | Data model | "What data does this feature create, read, update, or delete?" |
| 9 | Open questions | "What do you not know yet that would affect the spec?" |

**Assumption trigger patterns (include in phrasing):**
- Turn 1: "I'm assuming the primary user is [X] — is that right?"
- Turn 2: "I'm assuming success means [X] for the user"
- Turn 3: "I'm assuming [related capability] is not included in this release"
- Turn 4: After each step the user describes: "I'm assuming [step detail] — confirm?"
- Turn 5: "I'm noting [criterion] as testable — does it have a measurable threshold?"
- Turn 6: "I'm assuming [edge case] is handled by [default behavior]"
- Turn 7: "I'm assuming error messages follow [language/tone]"
- Turn 8: "I'm assuming [data entity] already exists in the system"

**Minimum turn enforcement:**

Maintain an internal turn counter starting at 0. Increment after each completed turn.
Do NOT proceed to Step 7 (Write SPEC.md) until the turn counter reaches at least 4.
If the user requests to skip remaining turns before turn 4, respond:

> "Spec elicitation requires a minimum of 4 turns to ensure adequate coverage. We've completed {N} so far. Let's continue with Turn {N+1}."

After turn 4, remaining turns may be condensed if the user explicitly requests it and all
critical domains (Turns 1-4: problem, scope, user stories, acceptance criteria) are covered.

**Warning signs:** A completed elicitation with zero `[ASSUMPTION]` blocks is suspicious for any non-trivial feature. Surface at least one assumption check per domain.

## Step 4: Artifact Injection (conditional -- only if URL provided in Step 1)

If no URL was provided in Step 1, skip this step entirely.

For each URL provided:

1. Display the URL and describe what will be extracted.
2. Attempt extraction:
   - **Google Doc or PPT URL:** attempt text extraction via WebFetch tool. If accessible, show a 3-bullet summary of extracted content. If inaccessible, record the URL in `source-artifacts:` frontmatter for Phase 13 MCP ingestion.
   - **Figma URL:** record the URL in `figma-url:` frontmatter. Invoke `design:user-research` via the Skill tool for design context. If the skill is unavailable, record URL only.
3. Ask: "A. Incorporate this content into the spec  B. Skip"

If user selects A: incorporate the relevant content into the appropriate sections during Step 7.

## Step 5: Assumption Consolidation

**NON-SKIPPABLE GATE.**

Collect all `[ASSUMPTION: ...]` blocks surfaced during Steps 3 and 4. Present them as a numbered list.

For each assumption, ask:

> A. Resolve now (provide the answer)
> B. Accept as assumption (keep as-is in spec)
> C. Tag for follow-up (Status: Follow-up-required)

Update the `Status:` field of each assumption block accordingly:
- A → `Status: Resolved` (record the resolution text)
- B → `Status: Accepted`
- C → `Status: Follow-up-required`

If no assumptions were surfaced, note this and ask: "Before we write the spec, are there any open questions or unknowns you want to flag?"

## Step 6: Invoke design:design-critique (conditional)

Only if a design artifact (Figma URL or design-related Google Doc) was provided in Step 1 or referenced during elicitation:

Invoke `design:design-critique` via the Skill tool. If the skill is unavailable, skip with a note: "(design:design-critique not available — design review deferred)"

## Step 7: Write .planning/SPEC.md

**NON-SKIPPABLE GATE.**

1. Read `templates/specs/SPEC.md.template` to get the canonical structure.
2. **Determine spec-version:**
   - Greenfield mode: `spec-version: 1`
   - Augment mode: read existing `spec-version:` from `.planning/SPEC.md` frontmatter, increment by 1
3. Populate all sections from the elicitation answers collected in Steps 1-6:
   - `## Overview` — from Turn 1 (problem) and feature description
   - `## User Stories` — from Turn 4 (user stories)
   - `## UX Flows` — from Turn 4 (step-by-step flow)
   - `## Acceptance Criteria` — from Turn 5
   - `## Assumptions` — all `[ASSUMPTION: ...]` blocks with final Status values from Step 5
   - `## Open Questions` — from Turn 9 and any Follow-up-required assumptions
   - `## Out of Scope` — from Turn 3
4. Set frontmatter fields:
   - `spec-version:` — as calculated above
   - `status: Draft`
   - `jira-id:` — from Step 1 if provided, else empty string
   - `figma-url:` — from Step 1 if provided, else empty string
   - `source-artifacts:` — list of all URLs provided in Step 1 (empty list if none)
   - `created:` — today's date (greenfield) OR preserve existing value (augment)
   - `last-updated:` — today's date
5. Write to `.planning/SPEC.md` using the Write tool.

Every `[ASSUMPTION: ...]` block in the spec must include `Status:` and `Owner:` fields. No untagged assumptions.

### Step 7a: Review SPEC.md

**NON-SKIPPABLE GATE.**

Invoke `/artifact-reviewer .planning/SPEC.md --reviewer review-spec` via the Skill tool.

Do NOT proceed to Step 8 until /artifact-reviewer reports 2 consecutive clean passes. If issues are found, /artifact-reviewer will apply fixes and re-review automatically. If /artifact-reviewer surfaces an unresolvable issue after 5 rounds, STOP and present it to the user.

## Step 8: Write .planning/REQUIREMENTS.md

1. Read `templates/specs/REQUIREMENTS.md.template` to get the canonical structure.
2. Derive `REQ-XX` IDs from the acceptance criteria collected in Turn 5. Assign sequential IDs starting at REQ-01.
3. Derive `NFR-XX` IDs from any non-functional concerns raised during elicitation (performance, security, accessibility, reliability). Assign sequential IDs starting at NFR-01.
4. Mirror the Out of Scope section from SPEC.md.
5. Mirror the Open Questions section from SPEC.md.
6. Write to `.planning/REQUIREMENTS.md` using the Write tool.

### Step 8a: Review REQUIREMENTS.md

**NON-SKIPPABLE GATE.**

Invoke `/artifact-reviewer .planning/REQUIREMENTS.md --reviewer review-requirements` via the Skill tool.

Do NOT proceed to Step 9 until /artifact-reviewer reports 2 consecutive clean passes. If issues are found, /artifact-reviewer will apply fixes and re-review automatically. If /artifact-reviewer surfaces an unresolvable issue after 5 rounds, STOP and present it to the user.

## Step 9: Write .planning/DESIGN.md (conditional)

Only if a design artifact or Figma URL was provided:

1. Read `templates/specs/DESIGN.md.template` to get the canonical structure.
2. Populate from design context gathered in Steps 4 and 6.
3. Write to `.planning/DESIGN.md` using the Write tool.

### Step 9a: Review DESIGN.md (conditional)

**Only if Step 9 produced a DESIGN.md.**

Invoke `/artifact-reviewer .planning/DESIGN.md --reviewer review-design` via the Skill tool.

Do NOT proceed to Step 10 until /artifact-reviewer reports 2 consecutive clean passes. If issues are found, /artifact-reviewer will apply fixes and re-review automatically. If /artifact-reviewer surfaces an unresolvable issue after 5 rounds, STOP and present it to the user.

## Step 10: Commit artifacts

Stage and commit all spec artifacts:

```bash
git add .planning/SPEC.md
git diff --quiet .planning/REQUIREMENTS.md 2>/dev/null || git add .planning/REQUIREMENTS.md
git add .planning/DESIGN.md 2>/dev/null || true
git commit -m "spec: [feature-slug] v{spec-version} draft"
```

Replace `[feature-slug]` with a kebab-case version of the feature name from Step 1. Replace `{spec-version}` with the actual version number written in Step 7.

## Step 11: Summary

Display a closing banner:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 SPEC ELICITATION COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Feature:         {feature name}
Spec version:    {spec-version}
Sections:        {count of ## sections in SPEC.md}
Assumptions:     {count of [ASSUMPTION] blocks}
Open questions:  {count of open question items}
Status:          Draft

Next step: run /silver:feature to begin implementation planning.
```

If any assumptions have `Status: Follow-up-required`, add:

```
⚠  {N} assumption(s) require follow-up before implementation begins.
   Review .planning/SPEC.md §Assumptions before running /silver:feature.
```
