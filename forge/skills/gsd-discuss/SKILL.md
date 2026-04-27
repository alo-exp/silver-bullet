---
name: gsd-discuss
id: gsd-discuss
title: GSD — Discuss Phase
description: Adaptive questioning to surface assumptions and lock decisions before planning
trigger:
  - "discuss phase"
  - "clarify phase"
  - "explore assumptions"
  - "gray areas"
---

# GSD — Discuss Phase

## When to Use
Before planning any phase with ambiguous requirements. Surfaces hidden assumptions before they become expensive mistakes.

## Steps

### Step 1: Read Phase Context
Read `.planning/ROADMAP.md` for the phase goal and requirements. Read `.planning/REQUIREMENTS.md` for relevant REQ-IDs. Note any ambiguous or under-specified areas.

### Step 2: Ask Clarifying Questions (one at a time)
For each ambiguous area, ask ONE question and wait for the answer before asking the next. Do not ask multiple questions in a single message.

### Step 3: Lock Decisions
After each answer, write a "Locked: <decision>" entry in `.planning/phases/<N>/CONTEXT.md`. Never reopen locked decisions.

### Step 4: Gate
Do not exit this skill until all identified gray areas have locked decisions in CONTEXT.md.

## Exit Condition
`.planning/phases/<N>/CONTEXT.md` exists with a `## Locked Decisions` section containing at least one entry per gray area identified.
