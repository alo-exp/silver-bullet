# Plugin Responsibility Boundaries

Defines what Silver Bullet owns directly and where optional plugins may extend it.

**Last updated:** 2026-06-12

## Current Boundary

Silver Bullet owns the core software-engineering lifecycle:

- Clarification, spec, requirements, and planning context
- Phase planning and wave execution
- TDD boundary, verification, completion audit, review framing, review triage, and branch finish
- Security, UI contract, UI review, release readiness, milestone archival, and phase-level ship
- Domain quality contracts for code/test/API/data/dependency/performance/structure/CI/environment/accessibility/content/search/UI/architecture/runtime/incident/retro/benchmark evidence
- Hook enforcement, packaging, project templates, and public command surfaces

Legacy lifecycle-overlap behaviors that SB explicitly depended on have been absorbed into SB-owned skills. Legacy marker names may still satisfy hooks during migration, but new SB workflow instructions must use SB lifecycle skills.

## Extension Boundary

Optional plugins remain useful when they add capability outside SB's lifecycle scope:

| Extension class | Examples | Boundary |
|---|---|---|
| DevOps/provider tooling | Terraform, Kubernetes, cloud-provider operations, deploy readiness | May provide domain checks, commands, and evidence. SB still owns context, plan, execute, verify, review, ship, and release sequencing. |
| Connectors | GitHub, Gmail, Google Workspace, browser, documents, spreadsheets, presentations | May fetch or update external artifacts. SB still owns how those artifacts enter specs, plans, review, docs, and release gates. |
| Research augmentation | Multi-agent or provider-specific research tools | May add perspectives when explicitly requested. SB still owns the research question, evidence synthesis, and implementation handoff. |
| Host/runtime features | Model selection, subagent execution primitives, local browser control | Host-owned. SB composes workflow requirements but does not own host model routing. |

## Ownership Matrix

| Concern | Silver Bullet | Optional extensions |
|---|---|---|
| `.planning/` lifecycle artifacts | **Owns** | May supply source evidence only |
| Context and planning | **Owns** through `silver:context` and `silver:plan` | No competing phase planner |
| Execution | **Owns** through `silver:execute` | May run domain commands under SB plan control |
| Verification and completion audit | **Owns** through `silver:verify` and `silver:completion-audit` | May provide evidence |
| Domain quality packs | **Owns** through `silver:domain-audit` | May provide command output, traces, screenshots, or provider-specific evidence |
| Specialized test/refactor/content/benchmark routes | **Owns** through `silver:test`, `silver:refactor`, `silver:content`, and `silver:benchmark` | May provide tool output only |
| Deployment, canary, incident, retro loops | **Owns** through `silver:deploy`, `silver:canary`, `silver:incident`, and `silver:retro` | May provide platform, log, metric, or provider evidence |
| TDD boundary | **Owns** through `tdd` / SB marker aliases | No direct required dependency |
| Review framing and triage | **Owns** through `silver:review-request`, `silver:review`, `silver:review-triage` | May add findings into REVIEW.md |
| Branch finish and phase ship | **Owns** through `silver:branch-finish` and `silver:ship` | No competing phase ship |
| Release | **Owns** through `silver:release` and `silver:create-release` | May provide deployment or announcement evidence |
| Codex/Claude package surface | **Owns** | No dependency vendoring |

## Non-Redundancy Rules

1. SB docs describe SB-owned lifecycle behavior, not external plugin mechanics.
2. Optional plugin docs are referenced only when the plugin adds domain capability outside SB's lifecycle.
3. Legacy lifecycle command names may appear only as compatibility aliases, migration notes, or historical records.
4. New runtime instructions, templates, hooks, and public docs must use SB-owned lifecycle skills.
5. SB plugin packaging never vendors dependency plugins or project-instance artifacts.

## Packaging Boundaries

- `/.planning/` and `/.codex/` are project-instance artifacts, not plugin artifacts.
- `silver-bullet.md` is the project-side instance copy; `templates/silver-bullet.md.base` is the source template.
- `plugins/silver-bullet/` is the curated SB-only Codex bundle, synchronized from the repo root.
- `commands/` is the Codex command surface. It exposes `/silver:*` entry points and ships inside the Silver Bullet bundle so the default install presents one SB plugin.
- Third-party Codex wrappers belong in their own packages or marketplaces and should not copy upstream skills into this repository.

## Codex Marketplace Packaging

For the Codex packaging pattern used with Alo Labs plugins, see
[docs/internal/codex-marketplace-packaging-guide.md](docs/internal/codex-marketplace-packaging-guide.md).
SB's own Codex package stays SB-only. Optional extension plugins are installed
from their own sources when needed, and SB's slash-command layer ships inside the
main SB bundle so the default install exposes one Silver Bullet plugin with
`/silver:*` commands.
