---
seed_id: SEED-001
title: Skill Gap Check — detect missing required skills, surface install portals
github_issue: 68
priority: low
planted_during: v0.30.0 Open-Issue Sweep
planted_at: 2026-04-28
trigger_when:
  - SB adds a hook that depends on a not-yet-installed Claude Code skill
  - Users report repeated "missing skill X" enforcement failures across projects
  - GSD or Superpowers ships a new required skill that downstream installs lack
---

# SEED-001: Skill Gap Check — detect missing required skills, surface install portals

## Idea

When a downstream project's `.silver-bullet.json` lists a `required_planning` or `required_deploy` skill that isn't installed in the user's `~/.claude/plugins/cache/`, the SB Stop hook today produces an opaque "missing skill X" message. The user has to figure out where X comes from (GSD? Superpowers? a sibling SB plugin?) and how to install it.

A Skill Gap Check would: at SessionStart, walk the required-skills list, probe `~/.claude/plugins/cache/*/*/skills/<skill>/SKILL.md` (and the dynamic skill list emitted by Claude Code), and for each missing skill render a one-shot "/install" portal — exact `claude plugin install <slug>` command, plus the skill's owning plugin marketplace entry.

## Why This Matters

Today, "missing skill" failures look like a Silver Bullet bug; users blame SB for upstream plugin gaps. Surfacing the gap with an install path turns the failure into a 30-second self-service fix instead of a support ticket.

## When to Surface

- Hook author notes their hook depends on a skill that isn't transitively guaranteed by SB itself.
- Users repeatedly report the same "missing X" for skills owned by an upstream plugin.
- Onboarding flow shows the dropoff is at "user can't figure out which plugin owns the skill."

## Implementation Sketch (when triggered)

1. Build a registry of `skill_slug -> plugin_slug` mappings (static JSON, one per upstream plugin SB depends on).
2. Add `hooks/skill-gap-check.sh` (SessionStart): walk required skills, diff against installed, emit `additionalContext` listing missing skills with copy-pasteable install commands.
3. Add `silver:bullet.json` knob `hooks.skill_gap_check.enabled` (default `true`).
4. Document in `silver-bullet.md §11` (Runtime Compatibility / Dependencies).

## Why Deferred

This is a UX feature, not a bug fix — it requires a stable, curated registry of skill→plugin mappings, design choice on when to nudge vs. block, and probably a usability test pass. None of that is mechanical, and the issue is `priority: low`. The seed lets v0.30.0 close the open issue without dropping the idea.

## References

- GitHub issue: https://github.com/alo-exp/silver-bullet/issues/68
- Related: stop-check.sh produces "missing required skill" output that names skills opaquely
