# Silver Bullet And Legacy GSD Compatibility

Silver Bullet's current default is SB-only for the core software-engineering
lifecycle. SB owns routing, context, clarification, planning, execution, review,
security, verification, shipping, release, documentation, and enforcement hooks.

This page remains for users who previously understood SB as an orchestration
layer around GSD. That old model is no longer the default operating model.

## Current Boundary

| Concern | Current SB owner | Compatibility behavior |
|---------|------------------|------------------------|
| Workflow routing | `/sb` and `sb:*` skills | Legacy route names may be normalized when found in old state files. |
| Planning | `sb:context`, `sb:plan`, `sb:validate` | Existing `.planning/` artifacts are read and preserved. |
| Execution | `sb:execute`, `tdd` when selected | Historical execution markers can satisfy migrated state checks. |
| Review | `sb:review-request`, `sb:review`, `sb:review-triage` | Historical review markers are aliases only. |
| Verification | `sb:verify`, `verify-tests`, `sb:completion-audit` | Old verification markers are accepted during migration. |
| Security | `security`, `sb:secure`, `sb:validate` | Existing SECURITY artifacts remain valid evidence when current. |
| Shipping | `sb:branch-finish`, `sb:ship` | Branch/ship aliases are accepted for legacy projects. |
| Release | `sb:release`, `sb:create-release` | Release gates use SB-owned audit and completion markers. |
| Enforcement | SB hook suite | Hooks record SB markers first and normalize known historical aliases. |

## What Changed

- Core SB workflows no longer require overlapping lifecycle plugins.
- SB-owned lifecycle skills absorb the explicit helper boundaries SB depended on:
  clarification, planning discipline, execution discipline, review framing,
  review triage, completion audit, branch finishing, debugging,
  security validation, UI contract/review, and release completion.
- DevOps/provider/design/research plugins remain optional extensions when they
  add domain capability rather than duplicate SB's lifecycle.
- Third-party plugin source trees remain outside the SB bundle. SB may recognize
  legacy markers, but it does not vendor or depend on those plugins for normal
  operation.

## When To Install External Lifecycle Plugins

Install an external lifecycle plugin only when you have an explicit legacy task
or migration need that calls for that tool directly. Ordinary `/sb` feature,
bugfix, UI, DevOps, research, fast-path, and release workflows route through
SB-owned skills.

If a repository already contains old planning artifacts, `/sb:init` preserves
them. New work can continue from those artifacts through SB-owned context,
planning, execution, and verification skills.

## See Also

- `docs/sb-without-gsd.md` — SB-only install and operating model
- `docs/composable-flows-contracts.md` — current SB-owned flow contract
- `docs/PLUGIN-BOUNDARIES.md` — dependency and extension policy
