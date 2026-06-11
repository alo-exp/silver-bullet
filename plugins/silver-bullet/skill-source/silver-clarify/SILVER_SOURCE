---
name: "silver:clarify"
title: "Clarify"
description: Turn vague ideas or requirements into a decision-ready brief that merges PM framing, brainstorming discipline, and SB-owned lifecycle handoff.
argument-hint: "<idea, rough requirement, or requirement doc>"
version: 0.1.0
---

# /silver:clarify — Clarify, Compare, and Hand Off

SB orchestrator for the front end of planning. It merges product framing, one-question-at-a-time interviewing, brainstorming discipline, and SB lifecycle handoff into one coherent workflow. It does not implement work or write plans; it reduces uncertainty until the next step is obvious.

## Goal

Convert ambiguous input into a concise brief that can seed `silver:context` when discovery is next, or `silver:plan` when the phase is already ready to plan.

## Modes

- `--auto`: choose reasonable defaults and ask only when a crucial or unsafe decision is blocked
- `--all`: surface every gray area before converging
- `--chain`: after the brief is captured, continue with `silver:context` or `silver:plan` when project/phase context exists
- `--text`: keep the session text-only; no visual companion
- `--analyze`: read more context up front before asking

## Operating Rules

- Read current project context first.
- If the topic is visual or diagram-heavy, offer the visual companion as its own message before asking deeper questions.
- Ask one question at a time when clarification is needed. Prefer multiple choice when possible.
- If the user supplied a full requirement doc, compress repeated or already-settled points instead of restating them.
- If the input spans multiple independent projects, split it before continuing.
- Be opinionated. Generate options, challenge assumptions, then converge.
- If multiple complex remote artifacts need intake, run `silver:ingest` first; otherwise `silver:clarify` handles the intake path itself.
- If the request has product or user-value implications, include PM framing as a dedicated section in the final brief.
- If the request is pure technical framing with no product angle, omit the PM framing section and keep the brief lean.
- Resolve all gray areas before handing off. The goal is to leave as little ambiguity as possible for the next SB lifecycle step.

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
If the next obvious step is project or milestone framing, preserve enough context for SB to hand off directly to `silver:context`.

### 2. Frame

State the problem in plain language:

- who this is for
- what problem exists
- why now
- what constraints matter
- what success looks like

If the user supplied a full doc, compress repeated or already-settled points instead of restating them.
If the request has product or user-value implications, include a short PM framing section that captures the problem, audience, value, and success definition before moving on.

### 3. Explore

Generate 2-4 distinct framings or directions. Internally apply the PM lens first, then the Superpowers lens, but present the result as one non-redundant clarify flow. Include, when useful:

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

Pick the strongest direction, or if no decision is appropriate yet, narrow the open questions to the ones the next SB lifecycle step must resolve.

Be decisive. Name the recommendation and the reason for it.
If the next step is project or milestone framing, say so explicitly and route the handoff to `silver:context`. Otherwise hand off to `silver:plan` when phase context already exists.

### 6. Capture

Write a concise brief to `.planning/CLARIFY.md` with:

- problem statement
- current context
- PM framing section, when applicable
- options considered
- recommendation
- assumptions
- unresolved questions, after the recommendation
- next-step notes for `silver:context` or `silver:plan`
- explicit notes about any assumptions that need later validation
- any deferred ideas that should move into the designated project system rather than the session ledger

If `--chain` is set and the project/phase context is already known, hand the brief off to `silver:context` or `silver:plan` after writing it. If not, state the exact next SB lifecycle step needed to make that handoff possible.

## Exit Condition

The brief is written, the decision boundary is clear, and the next SB lifecycle step is obvious.
