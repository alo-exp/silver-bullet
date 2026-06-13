---
name: "silver:ui-contract"
title: "UI Contract"
description: This skill creates UI implementation contracts covering layout, states, accessibility, copy, tokens, and acceptance criteria.
argument-hint: "<UI scope>"
version: 0.1.0
---

# /silver:ui-contract - UI Design Contract

SB-owned UI contract defines layout, states, accessibility, copy, tokens, and
acceptance criteria before UI implementation.

## Output

Write or update `.planning/UI-SPEC.md` or the current phase UI contract.
When the project has durable UI state or design-system expectations, also write
or update `.planning/interface/STATE.md`.

## Process

1. Display `SILVER BULLET > UI CONTRACT`.
2. Read product/spec context, existing UI conventions, design tokens, component
   patterns, accessibility constraints, and target workflows.
3. Define:
   - user goals and primary workflow;
   - layout structure and responsive behavior;
   - states: empty, loading, error, success, disabled, and edge cases;
   - interaction details and keyboard behavior;
   - copy requirements;
   - accessibility criteria;
   - visual consistency constraints and reusable components;
   - interface-state updates: design tokens, components, interaction patterns,
     accessibility decisions, screenshots, and open design debt;
   - screenshot or Playwright verification needs.
4. Add acceptance criteria that `silver:execute`, `silver:ui-review`, and
   `silver:verify` can check.
5. Invoke or apply `silver:domain-audit --pack ui-system` and `accessibility`
   for public or reusable UI surfaces.

## Exit Gate

The UI contract is complete only when implementation can start without
inventing layout, states, or accessibility rules during execution.
