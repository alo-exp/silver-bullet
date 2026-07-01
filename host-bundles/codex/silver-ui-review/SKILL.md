---
name: "silver:ui-review"
title: "UI Review"
description: This skill audits implemented UI for visual quality, accessibility, responsiveness, interaction quality, and performance.
argument-hint: "<UI scope>"
version: 0.1.0
---

# /silver:ui-review - UI Quality Review

SB-owned UI quality review audits implemented UI for visual quality,
accessibility, responsiveness, interaction quality, and performance.

## Output

Write or update `.planning/UI-REVIEW.md`.

## Process

1. Display `SILVER BULLET > UI REVIEW`.
2. Read UI-SPEC, changed UI files, screenshots, Playwright output, and existing
   design conventions.
3. Audit:
   - layout and visual hierarchy;
   - responsive behavior across mobile and desktop;
   - accessibility and keyboard operation;
   - interaction states and error states;
   - copy clarity;
   - performance and rendering stability;
   - consistency with local design system;
   - drift against `.planning/interface/STATE.md` when present.
4. Use real browser/screenshot evidence for frontend work when a runnable app is
   available.
4b. Collect browser evidence per `silver-bullet.md §8.1` fallback hierarchy:
   - **Alumnium (preferred):** when configured, use `check` and `get` for layout,
     accessibility, interaction, and responsive assertions; attach command output
     and screenshots to UI-REVIEW.md.
   - **Host browser MCP:** when Alumnium is absent, navigate to the running app,
     capture `browser_snapshot` for structure/a11y cues and
     `browser_take_screenshot` for visual layout; exercise key interactions with
     `browser_click` / `browser_type` / `browser_scroll`, then re-snapshot.
     Cursor: `cursor-ide-browser` tools. Attach evidence to UI-REVIEW.md.
   - **Otherwise:** Playwright output and static screenshots when available.
5. Invoke or apply `silver:domain-audit` with `ui-system`, `accessibility`, and
   `performance-resource` packs for reusable or public UI changes.
6. Update `.planning/interface/STATE.md` when the implementation establishes a
   reusable token, component, pattern, or design constraint.
7. Classify findings as BLOCK/WARN/INFO and route fixes back to
   `silver:execute`.

## Exit Gate

UI review passes only when no BLOCK UI findings remain or the user explicitly
accepts the residual risk.
