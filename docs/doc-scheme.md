# Documentation Scheme

> How Silver Bullet organizes your project's documentation. This file is scaffolded once during `/silver:init` and is yours to keep — edit freely.

---

## Structure

Your project documentation lives in three layers:

| Layer | Location | Lifespan | What goes here |
|-------|----------|----------|---------------|
| **Planning** | `.planning/` | Per-milestone (archived on completion) | Specs, plans, reviews, verification — the work-in-progress trail |
| **Project docs** | `docs/` | Durable across milestones | Architecture, testing strategy, changelog, knowledge, learnings |
| **Public** | `README.md` | Permanent | Project overview for external readers |

---

## Audience Model

Write docs so the intended reader is obvious.

| Audience | Primary questions | Start here |
|----------|-------------------|------------|
| **New contributor** | What is this project? How do I run it safely? | `README.md`, `docs/ARCHITECTURE.md`, `docs/TESTING.md` |
| **Active implementer** | What changed? Where are the gotchas? | `docs/CHANGELOG.md`, `docs/knowledge/YYYY-MM.md` |
| **Reviewer / release operator** | Is this ready to ship? What is the risk? | `docs/TESTING.md`, `docs/CICD.md`, `docs/DEPLOYMENT.md` |
| **Maintainer** | What is durable policy vs temporary plan? | `docs/doc-scheme.md`, `docs/knowledge/`, `docs/ADR/` |
| **External stakeholder** | What shipped and why? | `README.md`, `docs/CHANGELOG.md` |
| **Plugin author** *(Claude-Codex plugin-dev projects only)* | How do I extend commands/skills/agents safely? | `docs/specs/`, plugin runtime docs, relevant ADRs |
| **Runtime operator** *(Claude/Codex/Kay, plugin-dev only)* | What is shared vs runtime-specific? | `docs/RUNTIME-COMPATIBILITY.md` |

---

## Documentation Taxonomy (Purpose-First)

Each page should have one **primary** purpose.

| Type | Primary question | Typical style | Typical locations |
|------|------------------|---------------|-------------------|
| **Tutorial** | "Teach me from zero" | Sequential, example-driven | `README.md`, onboarding docs |
| **How-to** | "Help me do one task now" | Step-by-step procedure | `docs/DEPLOYMENT.md`, runbooks |
| **Reference** | "What is the exact behavior?" | Exhaustive and factual | `docs/API.md`, command/options tables |
| **Explanation** | "Why is it designed this way?" | Conceptual, tradeoffs | `docs/ARCHITECTURE.md`, ADRs |

Rules:
1. Choose one primary type per document.
2. Link to supporting docs instead of mixing all types into one page.
3. If a doc tries to do all four, split it.

---

## Question-First Navigation Map

Use this map when adding or reorganizing docs.

| If you want to... | Start here |
|-------------------|------------|
| Install and run the project | `README.md` |
| Understand architecture and boundaries | `docs/ARCHITECTURE.md` |
| Run tests or debug regressions | `docs/TESTING.md`, `docs/knowledge/YYYY-MM.md` |
| Understand what changed in a task | `docs/CHANGELOG.md` |
| Find historical decisions and rationale | `docs/ADR/`, `docs/knowledge/YYYY-MM.md` |
| Ship/release safely | `docs/CICD.md`, `docs/DEPLOYMENT.md`, release checklist docs |
| Extend plugin behavior *(plugin-dev only)* | `docs/specs/`, plugin extension docs |
| Check runtime parity *(plugin-dev only)* | `docs/RUNTIME-COMPATIBILITY.md` |

---

## `docs/` — Your Project Documentation

### Core files (scaffolded by `/silver:init`)

| File | Purpose |
|------|---------|
| `ARCHITECTURE.md` | Component model, layers, data flow, design principles |
| `TESTING.md` | Test pyramid, coverage goals, test classification |
| `CHANGELOG.md` | Rolling task log — what was done, commits, skills used |
| `knowledge/INDEX.md` | Gateway index of all project docs |
| `task-doc-checklist.json` | Per-task checklist status for governed docs (hook-enforced gate) |
| `doc-scheme.md` | This file — documentation architecture reference |
| `doc-scheme.json` | Machine-enforced contract used by hooks (`required_docs`, sections, granularity, mappings, archive history) |

### Knowledge & Learnings (created during development)

| Directory | Purpose | Portability |
|-----------|---------|-------------|
| `docs/knowledge/` | Project-scoped intelligence — architecture patterns, gotchas, key decisions, recurring issues | **Project-specific** — references this codebase directly |
| `docs/learnings/` | Portable learnings — things useful beyond this project | **Portable** — no project-specific file paths or feature names |

Both use monthly files (`YYYY-MM.md`). Each month's file is append-only during that month, then frozen.

**Knowledge categories:** Architecture Patterns, Known Gotchas, Key Decisions, Recurring Patterns, Open Questions

**Learnings categories:** `domain:{area}`, `stack:{technology}`, `practice:{area}`, `devops:{area}`, `design:{area}`

### Optional files (created when relevant)

| File | When to create |
|------|---------------|
| `CICD.md` | CI/CD pipeline exists |
| `API.md` | First API endpoint |
| `DEPLOYMENT.md` | First deployment |
| `SECURITY.md` | After security audit |
| `CONTRIBUTING.md` | Multi-contributor project |
| `GLOSSARY.md` | Terminology starts drifting across docs |
| `NAVIGATION.md` | Docs grow large enough that question-first routing needs a dedicated page |
| `DOC-OWNERSHIP.md` | Team needs explicit doc owners and review cadence tracking |
| `RUNTIME-COMPATIBILITY.md` | **Claude-Codex plugin-dev projects only**; runtime parity must be explicit |
| `ADR/` | Significant architecture, packaging, compatibility, or deprecation decisions |

---

## `.planning/` — Ephemeral Planning Artifacts

Managed by SB workflows. You rarely edit these directly — they're created and consumed by workflow skills.

| Artifact | Created by | Purpose |
|----------|-----------|---------|
| `PROJECT.md` | `silver:init` / `silver:plan` | Vision, core value, requirements |
| `ROADMAP.md` | `silver:plan` | Phase structure, status |
| `STATE.md` | `silver:context` / `silver:plan` | Current progress, decisions, quick tasks |
| `REQUIREMENTS.md` | `silver:spec` / `silver:plan` | Scoped requirements with acceptance criteria |
| Phase dirs (`phases/`) | `silver:plan` / `silver:execute` | Per-phase context, research, plans, reviews |
| `workflows/<id>.md` | `/silver` composer | Active composed-workflow state per workflow instance |
| `WORKFLOW.md` (retired legacy) | Older `/silver` flows | Retired single-file composition log |
| `VALIDATION.md` | `silver-validate` | Pre-build validation results |
| `UI-SPEC.md` | `silver:ui-contract` | UI specification — layout, components, interactions |
| `UI-REVIEW.md` | `silver:ui-review` | UI review findings — 6-pillar assessment |
| `SECURITY.md` | `silver:secure` | Security audit findings — threat mitigations |

All planning artifacts are archived on milestone completion — nothing grows unbounded.

---

## Size Caps

Every document has a growth limit:

| Location | Cap | Enforcement |
|----------|-----|-------------|
| `docs/*.md` | 500 lines | Artifact reviewer flags violations |
| `docs/knowledge/*.md`, `docs/learnings/*.md` | 300 lines | Split into `YYYY-MM-a.md` / `YYYY-MM-b.md` if exceeded |
| `.planning/` active files | 300 lines | Milestone completion archives and resets |
| Quick tasks table in `STATE.md` | 20 rows | Oldest archived when exceeded |

---

## When docs get updated

| Event | What updates |
|-------|-------------|
| **Every task** (finalization step) | `CHANGELOG.md`, `knowledge/YYYY-MM.md`, `learnings/YYYY-MM.md` |
| **Architecture changes** | `ARCHITECTURE.md` (rewritten) |
| **Test infrastructure changes** | `TESTING.md` |
| **Docs added or removed** | `knowledge/INDEX.md` |
| **Governance review** (monthly for active repos; quarterly otherwise) | `doc-scheme.md`, `knowledge/INDEX.md`, ownership/cadence notes |
| **Milestone completion** | Planning artifacts archived; tables trimmed |
| **Release** | `README.md`, root `CHANGELOG.md` |

## Enforced Task Checklist

Runtime source of truth is `docs/doc-scheme.json`; this file (`docs/doc-scheme.md`) is the human policy companion.

Hard blocking applies when `task_granularity` is `2` or `3` (configured in `doc-scheme.json`).

`docs/task-doc-checklist.json` must include:
1. `task_id`
2. `task_granularity` (numeric)
3. `docs` object with one status per `required_docs[].key` in `doc-scheme.json`
4. `sections` coverage for every required section declared in `required_docs[].required_sections`

Allowed status values:
1. `updated`
2. `not-needed: <reason>`
3. `n/a: <reason>`

Mandatory `updated` keys are read from `doc-scheme.json` (`mandatory_updated_docs` and doc-level `mandatory_updated`).

Rule:
1. Any key marked `updated` must correspond to a file modified in the current session.
2. If the scheme files are missing/invalid, run `/silver:ensure-docs --recover-scheme`.
3. If hook gaps are emitted, run `/silver:ensure-docs --from-hook --task <id> --gaps <path>`.

## Brownfield Archival Policy

When a brownfield project switches from a pre-existing user doc structure to SB canonical docs:
1. Prior user artifacts are moved (not copied) to `docs/archive/<timestamp>/...`.
2. Every move is recorded in the scheme contract (`archive_moves`) and archive manifest.
3. Canonical SB docs are created/updated with relevant content carried forward.
4. Preserve-mode mappings are recorded in `preserved_mappings` and enforced by hooks.

---

## Governance

### Ownership and review cadence

| Doc class | Default owner | Review cadence |
|-----------|---------------|----------------|
| `README.md`, `ARCHITECTURE.md`, `TESTING.md` | Current maintainer or phase owner | At every release |
| `CHANGELOG.md` | Task owner | Every task |
| `knowledge/YYYY-MM.md`, `learnings/YYYY-MM.md` | Task owner | Every task + month-end cleanup |
| `CICD.md`, `DEPLOYMENT.md`, `SECURITY.md` | Release/operator owner | Every release touching ops |
| `RUNTIME-COMPATIBILITY.md` *(plugin-dev only)* | Runtime owner | Every runtime-impacting change |

### Staleness and contradiction policy

1. If code and docs disagree, update docs before merge (or block delivery intentionally with an ADR).
2. Mark deprecated docs with a clear header and replacement link.
3. If a recurring decision appears in monthly knowledge more than once, promote it to `docs/ADR/`.
4. Resolve contradictory docs by precedence: ADR > architecture/reference docs > monthly knowledge > learnings.

---

## Verification Policy

Layout checks are not enough; verify content quality too.

| Check | Minimum bar |
|-------|-------------|
| **Link integrity** | No broken internal links in modified docs |
| **Example/snippet drift** | Command examples in changed docs must run or be explicitly marked illustrative |
| **Doc/code parity** | Changed behavior in code has matching doc updates in the same task |
| **Runtime parity** *(plugin-dev only)* | Runtime-specific behavior tracked in `RUNTIME-COMPATIBILITY.md` |
| **Generated docs sanity** *(if docs site exists)* | Regenerated output matches source docs and nav |

---

## Glossary & Canonical Terms

Use terms consistently.

| Term | Canonical meaning |
|------|-------------------|
| **Planning artifact** | Temporary work-in-progress document under `.planning/` |
| **Project doc** | Durable document under `docs/` |
| **Knowledge** | Project-specific intelligence not derivable from code alone |
| **Learning** | Portable guidance that generalizes beyond this repo |
| **Task** | One unit of completed implementation or change work |
| **Milestone** | Group of tasks delivered and archived together |
| **ADR** | Architecture Decision Record for durable technical decisions |
| **Skill** | Reusable workflow capability invoked during development |
| **Runtime compatibility** *(plugin-dev only)* | Matrix of shared vs runtime-specific behavior (Claude/Codex/Kay) |

If terms drift or multiply, create/update `docs/GLOSSARY.md` and link it from `knowledge/INDEX.md`.

---

## Non-redundancy rules

1. `docs/` files summarize — `.planning/` artifacts are the source of truth during development.
2. `knowledge/` captures intelligence not derivable from code or git history.
3. `learnings/` captures portable learnings — never duplicates project-specific knowledge.
4. `ARCHITECTURE.md` is high-level design — detailed phase designs stay in `.planning/phases/`.
5. `CHANGELOG.md` is the task log — git log is the commit log (different granularity).
6. Compose docs by linking; avoid cloning the same content across multiple pages.
