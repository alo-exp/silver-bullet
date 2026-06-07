---
name: "silver:research"
title: "Silver: /silver:research - Research"
description: >
  This skill should be used for SB-orchestrated research workflow: clarify → direct research by default, optional MultAI augmentation only when user-requested → clarify → hand off to silver:feature or silver:devops
argument-hint: "<research question or technology decision>"
version: 0.1.0
---

# /silver:research — Tech Decisions, Architecture Spikes, Comparisons

SB orchestrator for technology decisions, architecture spikes, tech comparisons, and competitive intelligence. Research always precedes implementation — findings are written to `.planning/research/` and referenced by the receiving workflow.

**Routing note:** `silver:research` takes precedence over any other matched workflow — research informs the implementation workflow. If an instruction matches both research and feature/devops, run research first, then hand off.

By default, research runs directly in the current host session using repository context, local artifacts, official docs, primary sources, and other concrete evidence available through the host/runtime. MultAI is optional and is used only when the user explicitly requests multi-AI perspectives in the current task. After research is complete, hand off to the appropriate implementation workflow.

## Mandatory dependency execution

Before any local research write-up or handoff, the execution trace must show the dependency chain for this workflow. At minimum:

1. Invoke `silver:clarify`
2. Run the selected research path in the current host session; invoke MultAI only when the user explicitly requested it in the current task
3. Invoke `silver:clarify`
4. Handoff to `silver:feature` or `silver:devops` only after the research artifact exists

If any required downstream skill cannot be invoked, stop immediately and notify the user. If the user explicitly requested MultAI and it is unavailable, stop and offer install-and-retry or permission to continue with the default direct-research path. Do not treat missing MultAI as a blocker for the default path. Do not replace missing dependency skills with shell reconnaissance, direct edits, or ad hoc local reasoning.

The `workflow-chain-guard.sh` hook enforces this at edit time: once the composed workflow is active, implementation edits stay blocked until the downstream GSD markers are actually present in the workflow state. If the guard blocks you, the research chain has not been completed yet.

## Pre-flight: Load Preferences

Read the **User Workflow Preferences** section of `silver-bullet.md` to load user workflow preferences before any other step. Silently apply any stored routing, skip, tool, MultAI, or mode preferences throughout this workflow.

```bash
grep -A 50 "^## [0-9]\+\. User Workflow Preferences" silver-bullet.md | head -60
```

Display banner:

```
SILVER BULLET ► RESEARCH WORKFLOW

Question: {$ARGUMENTS or "(not specified)"}
```

## Composition Proposal

Before beginning execution, read existing artifacts to determine context and propose which flows to include or skip.

### 1. Context Scan

Research is an exploration-focused workflow — it produces artifacts, not shipped code. No FLOW 7 (EXECUTE), FLOW 11 (VERIFY), or FLOW 13 (SHIP) are included.

| Artifact | Signal | Action |
|----------|--------|--------|
| `.planning/research/` directory exists | Prior research artifacts present | Note for continuity — do not skip, always re-scope |
| External spec artifacts provided | Structured source material | Include FLOW 4 (SPECIFY) to ingest into SPEC.md |

```bash
# Check for existing research artifacts
ls .planning/research/ 2>/dev/null | head -5
```

### 2. Build Flow Chain

Construct the proposed flow chain for research/exploration work. Short chain — research produces artifacts only:

FLOW 2 (CLARIFY) → FLOW 3 (DECIDE) → FLOW 4 (SPECIFY) [only when research should become a spec]

No per-phase loop — research is a single-pass engagement that hands off to the appropriate implementation workflow (`silver:feature`, `silver:ui`, `silver:devops`) or to `gsd:do` for GSD-owned lifecycle work.

### 3. Display Proposal

Display the composition proposal to the user:

```
SILVER BULLET ► FLOW COMPOSED
Flows: CLARIFY → DECIDE → SPECIFY (if needed)
Skipped: EXECUTE/VERIFY/SHIP — research produces artifacts only
Approve composition? [Y/n]
```

### 4. Auto-Confirm in Autonomous Mode

In autonomous mode (§10e), auto-confirm the composition proposal with a log message:

```
⚡ Autonomous mode: auto-confirming composition — {path count} paths, {skipped count} skipped
```

### 5. Start workflow tracking (Pass 2 — workflows.sh)

Resolve the workflow helper, then run its start subcommand to register this composition as an active workflow.
The helper writes a per-instance file to `.planning/workflows/<id>.md` and returns the
workflow id. Capture it and export it as `SB_WORKFLOW_ID` so all child shells (including
`gh release create` / `gh pr create`) inherit it — completion-audit's strict gate uses
this to verify the active workflow is fully complete before final delivery.

```bash
# Build a comma-separated flow list from the confirmed composition (use the
# user-facing FLOW / PATH names so they match what compliance-status surfaces).
SB_FLOWS="<flow1>,<flow2>,..."   # filled in from the confirmed chain

if [[ -x scripts/workflows.sh ]]; then
  SB_WORKFLOWS_BIN="scripts/workflows.sh"
else
  SB_WORKFLOWS_BIN="$(
    for root in \
      "$HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet/current" \
      "~/.codex/plugins/cache/alo-labs/silver-bullet/current" \
      "$HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet"/* \
      "~/.codex/plugins/cache/alo-labs/silver-bullet"/*; do
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

SB_WORKFLOW_ID=$("$SB_WORKFLOWS_BIN" start /silver:research "the research question" "$SB_FLOWS")
export SB_WORKFLOW_ID
echo "Workflow tracker started: $SB_WORKFLOW_ID"
```

After each flow / path completes, mark it done:

```bash
"$SB_WORKFLOWS_BIN" complete-flow "$SB_WORKFLOW_ID" "<flow-name>"
```

When the entire composition finishes (after the final SHIP / RELEASE flow lands), close
the workflow:

```bash
"$SB_WORKFLOWS_BIN" complete "$SB_WORKFLOW_ID"
```

`complete` archives the file under `.planning/workflows/.archive/<id>.md` and removes
it from the active set, so the strict final-delivery gate will not match a stale id.

> **Legacy:** the v0.22 single-file `.planning/WORKFLOW.md` mechanism is retired. The
> per-instance `.planning/workflows/<id>.md` files are the only workflow tracker as of
> v0.29.1.

After each path completes, the helper updates the Flow Log row in-place — the helper does
not edit the file directly.


## Step-Skip Protocol

When the user requests skipping any step:
1. Explain why the step exists (one sentence)
2. Offer: A. Accept skip  B. Lightweight alternative  C. Show me what you have
3. If user chooses A permanently: record in silver-bullet.md §10b and templates/silver-bullet.md.base §9b, then commit both files.

## Step 1: Clarify Research Question

Invoke `silver:clarify` through the active runtime's SB-recognized skill invocation channel. Purpose: Socratic clarification — precisely define the research question before choosing the research mode. This prevents running the wrong research path or optional MultAI augmentation on an ambiguous question.

After silver:clarify completes, the research question should be specific enough to select a path.

## Step 1.5: Research Mode Policy

Default mode is direct research in the current host session. Use repository context, local artifacts, and primary sources available through the current host/runtime.

Only opt into MultAI when the user explicitly asks for multi-AI, second-opinion, or cross-model perspectives in the current task.

If MultAI is requested but unavailable, stop and ask the user whether to install it now or continue with direct research only.

## Step 2: Choose Research Path

Ask:

> What type of research question is this?
>
> A. Market/landscape — "What tools/solutions exist for X?", "What's the state of the art?", "What does the ecosystem look like?"
> B. Tech selection — "Should we use X or Y?", "Which library/framework/approach is best for our case?", "Compare X vs Y"
> C. Competitive/product intelligence — "How do competitors solve X?", "What does product Y do that we should learn from?"

Wait for selection. Note: if the answer is obvious from $ARGUMENTS or silver:clarify output, skip this question and proceed directly.

## Path 2a: Market/Landscape Research

Invoked when: selection is A.

**2a.1 — Direct landscape scan**
Research the landscape directly in the current host session. Prefer official docs, vendor materials, primary sources, repo constraints, and concrete examples over generic summaries.

**2a.2 — Synthesize findings**
Summarize the market map, key options, trade-offs, and recommendations in a concise artifact.

**2a.3 — Optional MultAI augmentation**
Only when the user explicitly requested multi-AI perspectives in the current task, invoke `multai:landscape-researcher` and then `multai:consolidator` through the active runtime's SB-recognized skill invocation channel to broaden and cross-check the direct research artifact. If MultAI is unavailable, stop and ask whether to install it now or continue without it.

**Output:** Write consolidated findings to `.planning/research/<YYYY-MM-DD>-<topic-slug>/landscape-report.md`

Proceed to Step 3.

## Path 2b: Tech Selection Research

Invoked when: selection is B.

**2b.1 — Build the evaluation criteria directly**
Define the decision criteria from the clarified question, repo constraints, and operational requirements.

**2b.2 — Compare the options directly**
Use primary sources and concrete constraints to compare options and draft the recommendation rationale.

**2b.3 — Optional MultAI augmentation**
Only when the user explicitly requested multi-AI perspectives in the current task, invoke `multai:orchestrator`, `multai:comparator`, and `multai:consolidator` through the active runtime's SB-recognized skill invocation channel to add cross-model perspectives and a comparison matrix. If MultAI is unavailable, stop and ask whether to install it now or continue without it.

**Output:** Write consolidated report to `.planning/research/<YYYY-MM-DD>-<topic-slug>/comparison-report.md`

Proceed to Step 3.

## Path 2c: Competitive/Product Intelligence

Invoked when: selection is C.

**2c.1 — Direct competitive/product research**
Inspect public product evidence, docs, changelogs, demos, reviews, and local problem context directly in the current host session.

**2c.2 — Optional MultAI augmentation**
Only when the user explicitly requested multi-AI perspectives in the current task, invoke `multai:solution-researcher` through the active runtime's SB-recognized skill invocation channel to broaden the competitive scan. If MultAI is unavailable, stop and ask whether to install it now or continue without it.

**Output:** Write CIR to `.planning/research/<YYYY-MM-DD>-<topic-slug>/competitive-intelligence-report.md`

Proceed to Step 3.

## Artifact Output Protocol

After any research path completes, ensure the artifact directory exists before writing:

```bash
mkdir -p ".planning/research/$(date +%Y-%m-%d)-{topic-slug}/"
```

The artifact file path will be referenced in the handoff to the receiving workflow (Step 4). Research lineage is fully traceable via the `.planning/research/` directory — the path is passed explicitly to the receiving workflow so provenance is never lost.

## Step 3: Apply Research to Engineering Design

Invoke `silver:clarify` through the active runtime's SB-recognized skill invocation channel. Purpose: apply research findings to engineering design — turn the research artifact into a decision-ready handoff that the implementation workflow can absorb. Use the research artifact as primary input context for the clarification pass.

## Step 4: Hand Off to Implementation Workflow

Ask:

> Research complete. Which workflow should receive these findings?
>
> A. silver:feature — build a new feature based on research findings
> B. silver:devops — infrastructure/deployment change based on research findings
> C. Done — research-only engagement, no implementation needed

If A: invoke `silver:feature` through the active runtime's SB-recognized skill invocation channel. Pass the artifact path (`.planning/research/<date>-<topic>/`) as context argument so gsd-discuss-phase can reference it.

If B: invoke `silver:devops` through the active runtime's SB-recognized skill invocation channel. Pass the artifact path as context argument.

If C: summarize research artifacts created and their paths. Done.
