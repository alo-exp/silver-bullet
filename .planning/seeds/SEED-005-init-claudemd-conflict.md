---
seed_id: SEED-005
title: Interactive conflict resolution when CLAUDE.md already exists
github_issue: 69
priority: low
planted_during: v0.30.0 Open-Issue Sweep
planted_at: 2026-04-28
trigger_when:
  - A second user reports lost CLAUDE.md customization after `/silver:init`
  - SB grows a "managed-section" convention that requires bidirectional merge
  - `/silver:init` is restructured for any other reason (good time to land merge logic)
---

# SEED-005: Interactive conflict resolution for CLAUDE.md

## Idea

`/silver:init` currently overwrites `CLAUDE.md` if present. Users with customized CLAUDE.md lose their content silently. The fix is a three-way merge UX:

- **Replace** (today's behavior, plus a backup file)
- **Merge** (keep user sections, splice in SB-required sections marked with `<!-- silver-bullet-managed -->`)
- **Abort** (let the user reconcile manually)

Plus: write a `.backup` before any destructive operation, regardless of choice.

## Why This Matters

Onboarding loss-of-work is a high-friction failure mode. The cost is low (one extra prompt) and the upside is "no user ever loses CLAUDE.md to silver:init again."

## When to Surface

- A second confirmed report of lost CLAUDE.md content.
- Anytime silver:init gets a substantial rework — the merge logic is cleaner to land alongside other changes than as a standalone phase.
- When SB introduces managed-section markers (`<!-- silver-bullet-managed -->`) to other generated files (e.g. WORKFLOW.md), it's a good time to extend that convention to CLAUDE.md.

## Implementation Sketch (when triggered)

1. In `skills/silver-init/SKILL.md`, between the existing CLAUDE.md detection step and the write step, insert:
   - Detect existing CLAUDE.md.
   - Compute diff against template.
   - AskUserQuestion: A. Replace with backup, B. Merge, C. Abort.
2. For Merge mode: identify the SB-required sections by `<!-- silver-bullet-managed -->` HTML comment markers (need to add these to `templates/CLAUDE.md.base` first); preserve all non-managed user content unchanged.
3. Before any write: copy current CLAUDE.md to `CLAUDE.md.backup-<timestamp>`. Skip if backup file from the same minute already exists.
4. After write: tell the user where the backup landed.

## Why Deferred

This is a UX feature, not a bug fix. Implementing it requires (a) adding `<!-- silver-bullet-managed -->` markers to the template, (b) a robust merge implementation, (c) a backup convention that's consistent with the rest of SB's "never destroy user work" principle. None of that is trivial; it's worth doing once with care rather than rushed.

## References

- GitHub issue: https://github.com/alo-exp/silver-bullet/issues/69
