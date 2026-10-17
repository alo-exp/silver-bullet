# Silver Bullet and GSD

Silver Bullet used to be documented as an orchestration and enforcement layer around GSD. That is historical context, not the current contract. SB now owns the core software-engineering lifecycle — routing, context, clarification, planning, execution, review, security, verification, shipping, release, docs governance and hook enforcement — and needs neither GSD nor Superpowers.

This page replaces three earlier notes (`sb-vs-gsd.md`, `gsd-vs-silver-bullet.md` and `sb-without-gsd.md`) for users who knew SB as a GSD companion or who run SB in a repository with GSD-era artifacts.

## Install Without GSD

```text
/plugin install alo-exp/silver-bullet
/sb:init
```

Install `jq` first if you do not have it (`brew install jq` or `sudo apt install jq`). No GSD, Superpowers or knowledge-work plugin is required for SB's default lifecycle; Codex and Cursor installs are described in the [README](../README.md#install).

## What SB Owns

| Area | SB-owned skills | Compatibility behavior |
|------|-----------------|------------------------|
| Routing and setup | `/sb`, `/sb:init`, `/sb:context` | Legacy route names may be normalized when found in old state files |
| Clarification and specs | `/sb:clarify`, `/sb:spec`, `/sb:ingest`, `/sb:validate` | Existing `.planning/REQUIREMENTS.md` and `SPEC.md` are used as evidence |
| Planning and execution | `/sb:plan`, `/sb:execute`, `/sb:feature`, `/sb:bugfix`, `/sb:ui`, `/sb:fast`, `tdd` when selected | Existing `.planning/` artifacts are read and preserved; historical execution markers can satisfy migrated state checks |
| Quality and security | `/sb:quality-gates`, `security`, `/sb:secure`, `/sb:verify`, `verify-tests`, `/sb:completion-audit` | Old verification markers are accepted during migration; existing SECURITY artifacts remain valid evidence when current |
| Review discipline | `/sb:review-request`, `/sb:review`, `/sb:review-triage` | Historical review markers are aliases only |
| Shipping and release | `/sb:branch-finish`, `/sb:ship`, `/sb:release`, `/sb:create-release` | Branch/ship aliases are accepted for legacy projects; release gates use SB-owned markers |
| Docs and continuity | `/sb:ensure-docs`, `/sb:add`, `/sb:remove`, `/sb:rem`, `/sb:scan`, `/sb:handoff`, `/sb:forensics` | — |
| DevOps governance | `/sb:blast-radius`, `devops-quality-gates`, `/sb:devops` | Provider plugins remain optional enrichments |
| Enforcement | The hook suite ([HOOKS.md](HOOKS.md)) | Hooks record SB markers first and normalize known historical aliases |

SB-owned lifecycle skills absorb the helper boundaries SB used to borrow: clarification, planning and execution discipline, review framing and triage, completion audit, branch finishing, debugging, security validation, UI contract and review, and release completion.

## Existing GSD Projects

SB does not clobber old project memory during initialization. It adds current enforcement and continues with SB-owned lifecycle steps.

| Artifact or state | SB behavior |
|-------------------|-------------|
| `.planning/PROJECT.md`, `.planning/ROADMAP.md`, `.planning/STATE.md` | Preserved and read as project memory |
| `.planning/REQUIREMENTS.md`, `.planning/SPEC.md` | Used as requirements evidence for planning and verification |
| `.planning/phases/` | Preserved as historical or active phase evidence |
| `.planning/workflows/<id>.md` | SB-owned composed-workflow tracking |
| SB runtime state | Records SB markers and normalizes known historical aliases |

Migration:

1. Run `/sb:init` in the project.
2. Let SB detect the existing planning artifacts.
3. Continue work through `/sb`, `sb:context`, `sb:plan`, `sb:execute`, `sb:verify` and `sb:ship`.
4. Keep external lifecycle plugins installed only when a specific old command or audit needs them.

SB still recognizes legacy GSD and Superpowers marker names during migration and state normalization so older projects can be resumed safely; they are not dependencies for new workflows. If a user explicitly asks to run an external GSD command and GSD is installed, the host agent may do so as an explicit external-tool request — `/sb` routes ordinary lifecycle requests to SB-owned skills.

## When To Add Optional Plugins

Add external plugins when they extend SB into a specialized domain, not to duplicate its lifecycle:

1. DevOps/provider plugins for Terraform, Kubernetes, AWS, Pulumi, or similar infrastructure work.
2. Data, browser, document, spreadsheet, presentation, GitHub, Gmail, or other tool plugins when the task needs those capabilities.
3. Research augmentation or second-opinion reviewers when the user asks for them or the change is risky enough to justify extra perspectives.

Install an external lifecycle plugin only for an explicit legacy command, a migration audit or a user-directed comparison. Third-party plugin source trees stay outside the SB bundle; SB never vendors them.

## See Also

- [PLUGIN-BOUNDARIES.md](PLUGIN-BOUNDARIES.md) — dependency and extension policy
- [composable-flows-contracts.md](composable-flows-contracts.md) — current SB-owned flow contracts
- [sb-vs-as1.md](sb-vs-as1.md) — comparison with AS1
