---
name: silver-research
description: "SB-orchestrated research workflow: explore → MultAI (landscape | tech-selection | competitive) → brainstorm → hand off to silver:feature or silver:devops"
argument-hint: "<research question or technology decision>"
---

# /silver:research — Tech Decisions, Architecture Spikes, Comparisons

SB orchestrator for technology decisions, architecture spikes, tech comparisons, and competitive intelligence. Research always precedes implementation — findings are written to `.planning/research/` and referenced by the receiving workflow.

**Routing note:** `silver:research` takes precedence over any other matched workflow — research informs the implementation workflow. If an instruction matches both research and feature/devops, run research first, then hand off.

Never does research directly — orchestrates MultAI research tools and then hands off to the appropriate implementation workflow.

## Pre-flight: Load Preferences

Read `silver-bullet.md §10` to load user workflow preferences before any other step. Silently apply any stored routing, skip, tool, MultAI, or mode preferences throughout this workflow.

```bash
grep -A 50 "^## 10\. User Workflow Preferences" silver-bullet.md | head -60
```

Display banner:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 SILVER BULLET ► RESEARCH WORKFLOW
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Question: {$ARGUMENTS or "(not specified)"}
```

## Composition Proposal

Before beginning execution, read existing artifacts to determine context and propose which PATHs to include or skip.

### 1. Context Scan

Research is an exploration-focused workflow — it produces artifacts, not shipped code. No PATH 7 (EXECUTE), PATH 11 (VERIFY), or PATH 13 (SHIP) are included.

| Artifact | Signal | Action |
|----------|--------|--------|
| `.planning/research/` directory exists | Prior research artifacts present | Note for continuity — do not skip, always re-scope |
| External spec artifacts provided | Structured source material | Include PATH 4 (SPECIFY) to ingest into SPEC.md |

```bash
# Check for existing research artifacts
ls .planning/research/ 2>/dev/null | head -5
```

### 2. Build Path Chain

Construct the proposed path chain for research/exploration work. Short chain — research produces artifacts only:

PATH 2 (EXPLORE) → PATH 3 (IDEATE) → PATH 4 (SPECIFY)

No per-phase loop — research is a single-pass engagement that hands off to the appropriate implementation workflow (silver:feature or silver:devops).

### 3. Display Proposal

Display the composition proposal to the user:

```
┌─ COMPOSITION PROPOSAL ─────────────────────────
│ Paths: PATH 2 (EXPLORE) → PATH 3 (IDEATE) → PATH 4 (SPECIFY)
│ Skipped: PATH 7/11/13 — research produces artifacts, not shipped code
└────────────────────────────────────────────────
Approve composition? [Y/n]
```

### 4. Auto-Confirm in Autonomous Mode

In autonomous mode (§10e), auto-confirm the composition proposal with a log message:

```
⚡ Autonomous mode: auto-confirming composition — {path count} paths, {skipped count} skipped
```

### 5. Create WORKFLOW.md

If `.planning/WORKFLOW.md` does not exist, create it from `templates/workflow.md.base`:
- Populate `Intent:` with the research question ($ARGUMENTS)
- Populate `Composed:` with the current ISO timestamp
- Populate `Composer:` with `/silver:research`
- Populate `Mode:` with the current mode (interactive or autonomous)
- Record the confirmed path chain in the Path Log section header

After each path completes, write status to Path Log table:

```
| {#} | PATH {N} ({name}) | complete | {artifacts produced} | ✓ |
```

## Step-Skip Protocol

When the user requests skipping any step:
1. Explain why the step exists (one sentence)
2. Offer: A. Accept skip  B. Lightweight alternative  C. Show me what you have
3. If user chooses A permanently: record in silver-bullet.md §10b and templates/silver-bullet.md.base §10b, then commit both files.

## Step 1: Clarify Research Question

Invoke `silver:explore` (gsd-explore) via the Skill tool. Purpose: Socratic clarification — precisely define the research question before choosing the research mode. This prevents running the wrong MultAI path on an ambiguous question.

After silver:explore completes, the research question should be specific enough to select a path.

## Step 2: Choose Research Path

Ask:

> What type of research question is this?
>
> A. Market/landscape — "What tools/solutions exist for X?", "What's the state of the art?", "What does the ecosystem look like?"
> B. Tech selection — "Should we use X or Y?", "Which library/framework/approach is best for our case?", "Compare X vs Y"
> C. Competitive/product intelligence — "How do competitors solve X?", "What does product Y do that we should learn from?"

Wait for selection. Note: if the answer is obvious from $ARGUMENTS or silver:explore output, skip this question and proceed directly.

## Path 2a: Market/Landscape Research

Invoked when: selection is A.

**2a.1 — Landscape research across 9 sections**
Invoke `multai:landscape-researcher` via the Skill tool. Purpose: generates a 9-section market landscape report covering vendors, tools, patterns, and trends.

**2a.2 — Consolidate findings**
Invoke `multai:consolidator` via the Skill tool. Purpose: synthesize the landscape report into unified findings with actionable recommendations.

**Output:** Write consolidated findings to `.planning/research/<YYYY-MM-DD>-<topic-slug>/landscape-report.md`

Proceed to Step 3.

## Path 2b: Tech Selection Research

Invoked when: selection is B.

**2b.1 — Multi-AI perspectives**
Invoke `multai:orchestrator` via the Skill tool. Purpose: 7-AI perspectives on the technical question from different expert viewpoints.

**2b.2 — Weighted comparison matrix**
Invoke `multai:comparator` via the Skill tool. Purpose: structured comparison matrix with weighted criteria for the options under consideration.

**2b.3 — Unified recommendation**
Invoke `multai:consolidator` via the Skill tool. Purpose: synthesize multi-AI perspectives + comparison matrix into a unified recommendation report.

**Output:** Write consolidated report to `.planning/research/<YYYY-MM-DD>-<topic-slug>/comparison-report.md`

Proceed to Step 3.

## Path 2c: Competitive/Product Intelligence

Invoked when: selection is C.

**2c.1 — Competitive intelligence research**
Invoke `multai:solution-researcher` via the Skill tool. Purpose: 7-AI competitive intelligence CIR — how do others solve this problem, what can we learn, what gaps exist.

**Output:** Write CIR to `.planning/research/<YYYY-MM-DD>-<topic-slug>/competitive-intelligence-report.md`

Proceed to Step 3.

## Artifact Output Protocol

After any research path completes, ensure the artifact directory exists before writing:

```bash
mkdir -p ".planning/research/$(date +%Y-%m-%d)-{topic-slug}/"
```

The artifact file path will be referenced in the handoff to the receiving workflow (Step 4). Research lineage is fully traceable via the `.planning/research/` directory — the path is passed explicitly to the receiving workflow so provenance is never lost.

## Step 3: Apply Research to Engineering Design

Invoke `silver:brainstorm` (superpowers:brainstorming) via the Skill tool. Purpose: apply research findings to engineering design — "what do we actually build and how?" Use the research artifact as primary input context for the brainstorm.

## Step 4: Hand Off to Implementation Workflow

Ask:

> Research complete. Which workflow should receive these findings?
>
> A. silver:feature — build a new feature based on research findings
> B. silver:devops — infrastructure/deployment change based on research findings
> C. Done — research-only engagement, no implementation needed

If A: invoke `silver:feature` via the Skill tool. Pass the artifact path (`.planning/research/<date>-<topic>/`) as context argument so gsd-discuss-phase can reference it.

If B: invoke `silver:devops` via the Skill tool. Pass the artifact path as context argument.

If C: summarize research artifacts created and their paths. Done.
