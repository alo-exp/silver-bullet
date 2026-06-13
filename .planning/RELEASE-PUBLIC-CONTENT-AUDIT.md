---
audit: pre-release-public-content
date: 2026-06-12
release_candidate: v0.39.0
status: PASS
objective_review: PASS_AFTER_FIXES
---

# Public Content and Dependency-Absorption Audit

## Objective Under Review

Silver Bullet should absorb only the GSD, Superpowers, and Anthropic
knowledge-work behaviors it explicitly depends on, expose those behaviors
through SB-owned skills, and stop depending on those overlapping plugins for
core software-engineering lifecycle execution. Optional DevOps and provider
plugins remain extension points.

## Adversarial Review Result

Result: PASS after final stale-surface cleanup.

The first adversarial pass found release-blocking contradictions on active
surfaces:

- `hooks/core-rules.md`, `silver-bullet.md`, and `templates/silver-bullet.md.base`
  still described planning files as GSD-managed and referred to SB/GSD helper
  routing.
- `CONTRIBUTING.md` still listed GSD and Superpowers as setup prerequisites.
- `site/help/search.js` still said Silver Bullet wraps GSD and that GSD remains
  the lifecycle engine.
- `site/help/concepts/composable-workflow.html` still described flow contracts
  as having GSD state impact.
- `site/help/concepts/cost-optimization.html` still framed model controls and
  planning config around GSD.
- `skills/devops-skill-router/SKILL.md` still called GSD steps enforcement gates
  for routed DevOps enrichments.

All of those were fixed in the source surfaces, then `bash scripts/sync-codex-package.sh`
regenerated the packaged Codex/Claude/plugin mirrors.

## Public Surfaces Audited

- GitHub repository metadata: description updated and the stale `gsd` topic was
  removed before this audit.
- `README.md`: describes SB-owned lifecycle behavior, absorbed legacy plugins,
  and optional extension-plugin boundaries.
- `site/index.html`: positions GSD/Superpowers/Anthropic knowledge-work as
  absorbed or optional, not required.
- `site/help/*`: help pages and `site/help/search.js` align with SB-owned
  lifecycle routing.
- `site/compare/index.html` and `site/sb-vs-gsd/index.html`: comparison copy
  treats GSD and Superpowers as standalone alternatives or historical sources,
  not runtime dependencies.
- `CONTRIBUTING.md`: contributor setup no longer installs GSD or Superpowers as
  prerequisites.
- `silver-bullet.md` and `templates/silver-bullet.md.base`: runtime-facing
  instruction surfaces now describe SB-managed planning, SB lifecycle skill
  order, and optional extension routing.

## Evidence

Clean scans:

- High-risk phrase scan found no active matches for:
  `GSD-managed`, `SB/GSD`, `owning GSD`, `GSD steps MUST`,
  `GSD remains the lifecycle engine`, `discusses and plans with GSD`,
  `GSD workflow settings`, `plain GSD`, `GSD configuration`,
  `GSD state impact`, or `quality gates and GSD`.
- Broader public scan found only acceptable compatibility/history wording,
  including legacy marker compatibility and comparison-page standalone-tool
  descriptions.
- JSON validation passed for SB config, marketplace manifests, and package
  manifests.
- `git diff --check` passed.

Targeted checks:

- `bash tests/scripts/test-sync-codex-package.sh`: 95 passed, 0 failed.
- `bash tests/scripts/test-silver-router-flow-contracts.sh`: 58 passed, 0 failed.
- `bash tests/scripts/test-install-codex.sh`: 313 passed, 0 failed, 0 skipped
  when rerun without racing the package-sync test.

## Compatibility References Accepted

The following references are intentional and not dependency evidence:

- Legacy GSD/Superpowers marker names in `all_tracked` for migration.
- Hook alias tables that normalize old project state to SB-owned markers.
- Historical specs, audits, and session notes.
- Source-attribution lines in absorbed SB skills that explain the behavior SB
  merged from GSD, Superpowers, or Anthropic knowledge-work plugins.
- Public comparison copy that describes GSD/Superpowers as standalone tools.

## Verdict

PASS. The release candidate fulfills the dependency-absorption objective on
active code, configuration, package, installer, workflow, and public content
surfaces.

## 2026-06-12 Refresh

The homepage card layout and Help Center content were refreshed again for the
v0.39.0 candidate. The active public content scan now covers the landing page,
Help Center pages, search index, Open Graph card, README, and comparison page.
The landing-page lifecycle cards render as three desktop cards per row and a
single mobile column without overflowing bullet text.
