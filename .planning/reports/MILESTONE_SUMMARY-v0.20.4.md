# Milestone Summary — v0.20.4

**Released:** 2026-04-16
**Type:** Patch release
**Theme:** Skill UX — unified `/silver-*` naming + internal skill hygiene

---

## Overview

v0.20.4 delivers two related UX improvements that reduce cognitive overhead for end users of the Silver Bullet plugin:

1. **All user-facing skills renamed to `/silver-*`** — four skills that lacked the prefix (`blast-radius`, `create-release`, `forensics`, `quality-gates`) are now `silver-blast-radius`, `silver-create-release`, `silver-forensics`, and `silver-quality-gates`. End users now see a consistent `/silver-*` namespace in the Claude Code slash command menu.

2. **22 internal skills hidden from the slash command menu** — skills used only by SB orchestrators (dimension checkers like `modularity`, `security`, `testability`; artifact reviewers; routing skills) now carry `user-invocable: false` in their SKILL.md frontmatter, preventing them from appearing in the menu and consuming context window tokens in every session.

---

## What Changed

### Renamed Skills (4)

| Old name | New name |
|----------|----------|
| `/quality-gates` | `/silver-quality-gates` |
| `/blast-radius` | `/silver-blast-radius` |
| `/create-release` | `/silver-create-release` |
| `/forensics` | `/silver-forensics` |

### Hidden Skills (22)

Internal-only skills marked `user-invocable: false`:
- Quality dimensions: `modularity`, `reusability`, `scalability`, `reliability`, `testability`, `extensibility`, `usability`, `ai-llm-safety`
- Artifact reviewers: `review-spec`, `review-context`, `review-cross-artifact`, `review-design`, `review-ingestion-manifest`, `review-requirements`, `review-research`, `review-roadmap`, `review-uat`, `artifact-reviewer`, `artifact-review-assessor`
- Internal routing: `devops-skill-router`, `devops-quality-gates`, `security`

### Reference Updates

All 43 files referencing old skill names updated: hooks, configs, templates, tests, README, CHANGELOG.

---

## Architecture Impact

- `hooks/lib/required-skills.sh` — single source of truth for required skill names, updated to new names
- `hooks/record-skill.sh` — `DEFAULT_TRACKED` updated; namespace stripping (`silver:` → `silver-quality-gates`) works correctly
- `hooks/completion-audit.sh`, `stop-check.sh`, `dev-cycle-check.sh` — reference new names
- `.silver-bullet.json` + `templates/silver-bullet.config.json.default` — config examples use new names

---

## Key Decisions

- `user-invocable: false` is a Claude Code frontmatter field (not a Silver Bullet invention) that hides skills from the slash command menu and system-reminder listings
- The silver-* naming convention was already established for orchestrator skills; this release extends it to the 4 remaining user-facing skills
- Internal skills are still fully functional — they are invoked by orchestrators, just not directly by users

---

## Tests

962 tests, 3/3 suites green. CI green on main.

---

## Getting Started

No migration required for new projects. Existing projects using `.silver-bullet.json` should update `required_planning`, `required_deploy`, and `all_tracked` arrays to use the new names (or run `/silver-migrate` if available).
