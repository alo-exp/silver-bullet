---
name: silver-clarify
description: Turn vague ideas or requirements into a decision-ready brief for GSD discuss-phase.
argument-hint: "<idea, rough requirement, or requirement doc>"
version: 0.1.0
---

# /silver-clarify — Clarify, Compare, and Hand Off

SB orchestrator for the front end of planning. It blends product framing, one-question-at-a-time interviewing, brainstorming discipline, and GSD handoff into one coherent workflow. It does not implement work or write plans; it reduces uncertainty until the next step is obvious.

## Goal

Convert ambiguous input into a concise brief that `gsd-discuss-phase` can use immediately.

## Modes

- `--auto`: choose reasonable defaults and ask only when blocked
- `--all`: surface every gray area before converging
- `--chain`: after the brief is captured, continue with `gsd-discuss-phase` when project/phase context exists
- `--text`: keep the session text-only; no visual companion
- `--analyze`: read more context up front before asking

## Operating Rules

- Read current project context first.
- If the topic is visual or diagram-heavy, offer the visual companion as its own message before asking deeper questions.
- Ask one question at a time when clarification is needed. Prefer multiple choice when possible.
- If the user supplied a full requirement doc, compress repeated or already-settled points instead of restating them.
- If the input spans multiple independent projects, split it before continuing.
- Be opinionated. Generate options, challenge assumptions, then converge.

## Session Flow

### 1. Orient

First, read the current project context if it exists:

- `.planning/PROJECT.md`
- `.planning/REQUIREMENTS.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- any existing phase `CONTEXT.md`, `SPEC.md`, or related docs

Classify the input maturity:

- raw idea
- rough requirement
- full requirement doc
- research question or decision
- phase-ready handoff

If the input clearly spans multiple independent projects, split it before continuing.

### 2. Frame

State the problem in plain language:

- who this is for
- what problem exists
- why now
- what constraints matter
- what success looks like

If the user supplied a full doc, compress repeated or already-settled points instead of restating them.

### 3. Explore

Generate 2-4 distinct framings or directions. Include, when useful:

- a simpler option
- a more ambitious option
- a remove/simplify option
- the opposite of the obvious instinct

Use product frameworks as needed:

- How Might We
- Jobs To Be Done
- First Principles
- Opportunity Solution Trees
- SCAMPER
- OODA Loop
- Reverse Brainstorming

### 4. Pressure-Test

Challenge the ideas before they harden:

- list assumptions
- identify the riskiest assumption
- call out contradictions or missing decisions
- compare options on value, effort, risk, and future flexibility
- separate solved decisions from true gray areas
- name the cheapest way to test the riskiest assumption when useful

If the input is already formalized, focus on gaps and conflicts rather than generating new scope.

### 5. Converge

Pick the strongest direction, or if no decision is appropriate yet, narrow the open questions to the ones `gsd-discuss-phase` must resolve next.

Be decisive. Name the recommendation and the reason for it.

### 6. Capture

Write a concise brief to `.planning/CLARIFY.md` with:

- problem statement
- current context
- options considered
- recommendation
- assumptions
- open questions
- next-step notes for `gsd-discuss-phase`
- explicit notes about any assumptions that need later validation

If `--chain` is set and the project/phase context is already known, hand the brief off to `gsd-discuss-phase` after writing it. If not, state the exact next GSD step needed to make that handoff possible.

## Exit Condition

The brief is written, the decision boundary is clear, and the next step for GSD is obvious.
