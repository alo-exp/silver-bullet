---
name: progressive-review-loop
title: "Silver: Progressive Review Loop"
description: Run iterative audit/fix/verify loops for bounded artifact sets by escalating through model and reasoning levels one pair at a time until two consecutive clean passes are achieved at each level. Use when reviewing scripts, prompts, runbooks, configs, or other operational artifacts that need progressive confidence-building reviews.
---

# Progressive Review Loop

Use this skill for review tasks where one pass is not enough and the process must escalate through model/reasoning levels in order.

## Workflow

1. Start with the lowest capable model at `low` reasoning.
2. Keep one subagent on one model/reasoning pair at a time.
3. For that pair, require the subagent to:
   - audit the scoped artifact set for concrete failures, mismatches, and misleading behavior
   - fix confirmed issues in place
   - verify the fixes
   - repeat until it produces two consecutive clean passes
4. Only after two clean passes, move to the next reasoning level for the same model.
5. After exhausting that model, move to the next more capable model and restart at `low`.
6. Continue until the required ceiling is reached, or stop earlier only if the user explicitly allows it.

## Operating rules

- Keep scope narrow and artifact-driven.
- Preserve user changes; do not revert unrelated edits.
- Do not parallelize model/reasoning combinations.
- Treat a pass as clean only when verification is clean, not when no obvious issue is seen.
- Ask subagents for raw findings, diffs, logs, and verification output.
- Stay on the same pair if a fix introduces a new issue.
- Escalate only after the current pair is truly stable.

## What to tell a subagent

Use a short directive such as:

`Audit this folder, fix any concrete issues you find, verify the fixes, and keep iterating until you get two consecutive clean passes. Stay on this model/reasoning pair until that happens.`

## Use cases

- launch-critical runbooks and checklists
- k6 or other load-test harnesses
- operational prompts and execution plans
- script-heavy folders where syntax, semantics, and workflow alignment all matter
