# Silver Bullet Documentation

An index of the docs tree. Pages are grouped by audience; the last two sections say which material is generated and which is preserved history. The project overview is the [root README](../README.md); [CONTRIBUTING.md](../CONTRIBUTING.md) covers development setup and the repository layout.

## Live, generated and historical

- **Live guidance** is the set of pages below. `docs/doc-scheme.json` lists the governed ones and `docs/task-doc-checklist.json` records, per task, whether each was updated ([doc-scheme.md](doc-scheme.md) explains the scheme).
- **Generated** pages say so at the top and are rebuilt from a source of truth; edit the source, not the page.
- **Historical evidence** (audits, archives, research, specs, completed plans, forensics) is kept as written. It records what was true at the time and is not current instruction unless a live page promotes it.

## Using Silver Bullet

| Page | What it covers |
|------|----------------|
| [PRD-Overview.md](PRD-Overview.md) | Product overview and goals |
| [CONFIGURATION.md](CONFIGURATION.md) | Every `.silver-bullet.json` key |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Common problems: hooks not firing, gates blocking, red CI, debugging hooks |
| [ENFORCEMENT.md](ENFORCEMENT.md) | The twelve enforcement layers, the two-tier model, release gates |
| [HOOKS.md](HOOKS.md) | Every registered hook (generated) |
| [RUNTIME-COMPATIBILITY.md](RUNTIME-COMPATIBILITY.md) | Host capability tiers, runtime detection, install surfaces |
| [ORCHESTRATOR.md](ORCHESTRATOR.md) | Orchestrator parent mode and `SB OVERRIDE` |
| [NEW-WORKFLOW.md](NEW-WORKFLOW.md) | Authoring workflows with `/sb:new-workflow` |
| [CODEX-CLOUD.md](CODEX-CLOUD.md) | Running SB in Codex Cloud |
| [sb-vs-gsd.md](sb-vs-gsd.md), [sb-vs-as1.md](sb-vs-as1.md), [runtime-extensibility-comparison.md](runtime-extensibility-comparison.md) | Comparisons with GSD, AS1 and other agent runtimes |
| [PRODUCT-VISION-AUTONOMOUS-ENTERPRISE.md](PRODUCT-VISION-AUTONOMOUS-ENTERPRISE.md) | Product vision |

Optional tools (all opt-in): [GRAPHIFY.md](GRAPHIFY.md), [AGENTMEMORY.md](AGENTMEMORY.md), [CONTEXT-MODE.md](CONTEXT-MODE.md), [RTK.md](RTK.md), [LEANCTX.md](LEANCTX.md), [LEANCTX-OPERATING-GUIDE.md](LEANCTX-OPERATING-GUIDE.md), [ALUMNIUM.md](ALUMNIUM.md), [SEARCH-CLI.md](SEARCH-CLI.md), [STACK-OPTIMIZATION.md](STACK-OPTIMIZATION.md), [FIVE-TOOL-STACK.md](FIVE-TOOL-STACK.md), [AGENT-PI-OMNIROUTE.md](AGENT-PI-OMNIROUTE.md). Machine-level setup notes for the tool stacks are in `graphify-am/`, `rtk-cm/` and `research/graphify-agentmemory-optimization.md`.

The public help center at [sb.alolabs.dev/help](https://sb.alolabs.dev/help/) (source: `site/help/`) is the user-facing guide.

## Contributing

| Page | What it covers |
|------|----------------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | Components, host surfaces, design principles |
| [SDLC-MAP.md](SDLC-MAP.md) | Which skills, artifacts and layers act at each lifecycle stage |
| [PLUGIN-BOUNDARIES.md](PLUGIN-BOUNDARIES.md) | What SB owns versus optional extension plugins |
| [TESTING.md](TESTING.md) | Test layout, running tests, isolation, writing tests, coverage, live suites |
| [CICD.md](CICD.md) | GitHub Actions workflows and how to reproduce CI locally |
| [APO-AUTHORING-COMPLIANCE.md](APO-AUTHORING-COMPLIANCE.md) | Rules for authoring catalog-backed workflows |
| [evidence-schema.md](evidence-schema.md), [code-intelligence-contract.md](code-intelligence-contract.md), [external-review-policy.md](external-review-policy.md) | Contracts the quality gates check |
| [multi-agent-coordination.md](multi-agent-coordination.md), [multi-ai-task-self-review.md](multi-ai-task-self-review.md) | Multi-agent locking and the multi-AI task skill |
| [workflows/](workflows/) | The live workflow runbooks (`full-dev-cycle.md`, `devops-cycle.md`), byte-identical to `templates/workflows/` |
| [enforcement-techniques/claude.md](enforcement-techniques/claude.md) | Standalone reference of the enforcement techniques |
| [skills/](skills/) | Prompts for building sibling host skills |
| [doc-scheme.md](doc-scheme.md), [doc-scheme.json](doc-scheme.json), [task-doc-checklist.json](task-doc-checklist.json) | The documentation scheme ([documentation-scheme.md](documentation-scheme.md) and [project-documentation-scheme.md](project-documentation-scheme.md) are compatibility pointers) |
| [tech-debt.md](tech-debt.md), [TODO.md](TODO.md), [issues/](issues/) | Technical debt, backlog pointer, backlog and issues |
| [knowledge/](knowledge/), [learnings/](learnings/) | Monthly project knowledge and portable learnings ([knowledge/INDEX.md](knowledge/INDEX.md)) |
| [CHANGELOG.md](CHANGELOG.md) | Task log, newest first (release notes are the root `CHANGELOG.md`) |
| [../scripts/README.md](../scripts/README.md) | What each script in `scripts/` is for |

## Maintaining and releasing

| Page | What it covers |
|------|----------------|
| [RELEASE.md](RELEASE.md) | The release process, start to finish |
| [SECURITY.md](SECURITY.md) | Security posture (the disclosure policy is the root `SECURITY.md`) |
| [ENTERPRISE-E2E-LIVE-TEST.md](ENTERPRISE-E2E-LIVE-TEST.md) | Enterprise live-test runbook |
| [internal/](internal/) | Maintainer runbooks: [pre-release-quality-gate.md](internal/pre-release-quality-gate.md), [site-publishing.md](internal/site-publishing.md), [help-center-guidelines.md](internal/help-center-guidelines.md), update and packaging guides, plus superseded analyses marked as such |
| [testing/](testing/) | Release and enterprise validation runbooks, claim registries, the manual smoke protocol |
| [pm/](pm/) | Marketing and product research notes |

## Generated

| Page | Source | Generator |
|------|--------|-----------|
| [composable-flows-contracts.md](composable-flows-contracts.md), [workflow-composition-matrix.md](workflow-composition-matrix.md), [generated/](generated/) | [apo-catalog.json](apo-catalog.json) (schema: [apo-catalog.schema.json](apo-catalog.schema.json)) | `python3 scripts/generate-apo-artifacts.py` |
| [HOOKS.md](HOOKS.md) | `hooks/hooks.json` and [hooks-purpose.json](hooks-purpose.json) | `python3 scripts/generate-hook-reference.py` |

## Historical evidence

| Path | Contents |
|------|----------|
| [audits/](audits/) | SENTINEL and adversarial review reports, the per-skill SENTINEL manifest for the release it names |
| [archive/](archive/) | Archived documents and the archive manifest |
| [specs/](specs/), [superpowers/](superpowers/) | Point-in-time designs and completed plans |
| [silver-forensics/](silver-forensics/), [instruction-following/](instruction-following/), [handoffs/](handoffs/) | Forensic reports, instruction-following audits, session handoffs |
| [research/](research/) and the root [research/](../research/) | Research reports (the root folder is the output root for `sb:deep-research`) |
| `.planning/` (repo root) | This repository's own SB planning state and history; edited only through SB skills |
