---
name: "silver:ui-review"
title: "UI Review"
description: This skill audits implemented UI for visual quality, accessibility, responsiveness, interaction quality, and performance.
argument-hint: "<UI scope>"
version: 0.1.0
---

# /silver:ui-review - UI Quality Review

SB-owned UI quality review. This absorbs the useful behavior SB previously took
from GSD ui-review and Anthropic Design critique/accessibility skills.

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
   - consistency with local design system.
4. Use real browser/screenshot evidence for frontend work when a runnable app is
   available.
5. Classify findings as BLOCK/WARN/INFO and route fixes back to
   `silver:execute`.

## Exit Gate

UI review passes only when no BLOCK UI findings remain or the user explicitly
accepts the residual risk.
