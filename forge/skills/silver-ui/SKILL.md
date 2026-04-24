---
id: silver-ui
title: Silver — UI/Frontend Workflow
description: UI development workflow with design review and accessibility
trigger:
  - "silver UI"
  - "UI workflow"
  - "frontend workflow"
  - "build UI"
---

# Silver UI — UI/Frontend Workflow

## When to Use
For UI, frontend, component, screen, interface, or design work.

## Steps

### Step 1: ORIENT
Read existing UI code and design system documentation. Understand component patterns.

### Step 2: DESIGN REVIEW
Before coding:
- Review any existing designs
- Check design system components
- Note accessibility requirements
- Define responsive breakpoints

### Step 3: QUALITY GATES (pre-plan)
Run quality gates (trigger: "quality gates") on the UI approach.

### Step 4: PLAN
Plan the UI implementation (trigger: "plan phase"). Include:
- Component hierarchy
- State management
- Accessibility requirements
- Responsive behavior

### Step 5: IMPLEMENT
Execute the plan (trigger: "execute phase"). Follow:
- Design system conventions
- Accessibility best practices
- Responsive design patterns

### Step 6: ACCESSIBILITY CHECK
Verify accessibility:
- Keyboard navigation works
- Screen reader compatible
- Color contrast adequate
- Focus states visible

### Step 7: VERIFY
Run verification (trigger: "verify work"). Include:
- Visual regression testing
- Cross-browser testing
- Accessibility audit

### Step 8: REVIEW
Run code review (trigger: "code review"). Focus on:
- Component structure
- Accessibility
- Responsive behavior
- State management

### Step 9: QUALITY GATES (pre-ship)
Run quality gates (trigger: "quality gates").

**PATH 10b: DOC-SCHEME COMPLIANCE (conditional)**
Only if `docs/doc-scheme.md` exists: before raising the PR, verify:
1. `docs/CHANGELOG.md` — has an entry for this phase (newest-first). Write it if missing.
2. `docs/ARCHITECTURE.md` — does not say "in progress" for completed phases. Update if stale.
3. `docs/knowledge/YYYY-MM.md` — append architectural patterns, API gotchas, or key decisions if any.
4. `docs/lessons/YYYY-MM.md` — append portable lessons learned if any.
Do NOT proceed to Step 10 until all four checks pass. If `docs/doc-scheme.md` does not exist, skip this path.

### Step 10: SHIP
Create PR (trigger: "ship").

## Session Logging
Document UI decisions and patterns in `docs/sessions/YYYY-MM-DD.md`.

## Exit Condition
UI implemented, verified, accessible, and PR created.
