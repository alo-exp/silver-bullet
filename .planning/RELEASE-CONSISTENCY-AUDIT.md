---
audit: pre-release-consistency
date: 2026-06-11
release_candidate: v0.38.0
status: PASS
clean_passes: 2
---

# Pre-Release Consistency Audit

## Scope

Audited the dependency absorption release candidate across the five Stage 2
dimensions:

- Workflows: `docs/workflows/`, `templates/workflows/`, `silver-bullet.md`,
  and `templates/silver-bullet.md.base`.
- Skills: `skills/`, generated `agents/codex`, generated `agents/claude`, and
  `plugins/silver-bullet/skill-source`.
- Hooks and config: required marker defaults, compatibility aliases, and JSON
  config surfaces.
- Help site and README: public lifecycle claims and routing references.
- Absorbed dependency consistency: hard dependency claims on GSD, Superpowers,
  or Anthropic knowledge-work skills.

## Pass 1

Result: PASS.

Evidence:

- Workflow docs match templates byte-for-byte.
- Required marker config uses SB-owned planning/deploy markers.
- Active public docs/site scan returned no current hard-dependency lifecycle
  references after the Stage 1 fixes.
- Skills scan found only source-attribution lines in absorbed SB skills, not
  current hard dependency instructions.
- JSON parse and whitespace checks passed.

## Pass 2

Result: PASS.

Evidence:

- Workflow template parity remained clean.
- `tests/hooks/test-required-skills-consistency.sh` passed: 10 passed, 0 failed.
- Skills hard-dependency scan returned no matches.
- Active public docs/site stale-reference scan returned no matches.
- `git diff --check` passed.
- JSON parse check passed for SB config and plugin manifests.

## Accepted Compatibility References

The following are intentional and not release blockers:

- Legacy markers in `all_tracked`.
- Alias tables in hooks.
- Compatibility wording in workflow docs and comparison pages.
- Source attribution lines inside absorbed SB skills.

## Result

PASS. The release candidate is internally consistent with the SB-owned lifecycle
positioning.
