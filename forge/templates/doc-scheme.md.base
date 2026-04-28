# Documentation Scheme

> How Silver Bullet organizes your project's documentation. This file is scaffolded once during `/silver:init` and is yours to keep — edit freely.

---

## Structure

Your project documentation lives in three layers:

| Layer | Location | Lifespan | What goes here |
|-------|----------|----------|---------------|
| **Planning** | `.planning/` | Per-milestone (archived on completion) | Specs, plans, reviews, verification — the work-in-progress trail |
| **Project docs** | `docs/` | Durable across milestones | Architecture, testing strategy, changelog, knowledge, lessons |
| **Public** | `README.md` | Permanent | Project overview for external readers |

---

## `docs/` — Your Project Documentation

### Core files (scaffolded by `/silver:init`)

| File | Purpose |
|------|---------|
| `ARCHITECTURE.md` | Component model, layers, data flow, design principles |
| `TESTING.md` | Test pyramid, coverage goals, test classification |
| `CHANGELOG.md` | Rolling task log — what was done, commits, skills used |
| `knowledge/INDEX.md` | Gateway index of all project docs |
| `doc-scheme.md` | This file — documentation architecture reference |

### Knowledge & Lessons (created during development)

| Directory | Purpose | Portability |
|-----------|---------|-------------|
| `docs/knowledge/` | Project-scoped intelligence — architecture patterns, gotchas, key decisions, recurring issues | **Project-specific** — references this codebase directly |
| `docs/lessons/` | Portable lessons learned — things useful beyond this project | **Portable** — no project-specific file paths or feature names |

Both use monthly files (`YYYY-MM.md`). Each month's file is append-only during that month, then frozen.

**Knowledge categories:** Architecture Patterns, Known Gotchas, Key Decisions, Recurring Patterns, Open Questions

**Lessons categories:** `domain:{area}`, `stack:{technology}`, `practice:{area}`, `devops:{area}`, `design:{area}`

### Optional files (created when relevant)

| File | When to create |
|------|---------------|
| `CICD.md` | CI/CD pipeline exists |
| `API.md` | First API endpoint |
| `DEPLOYMENT.md` | First deployment |
| `SECURITY.md` | After security audit |
| `CONTRIBUTING.md` | Multi-contributor project |
| `ADR/` | Significant architecture decisions |

---

## `.planning/` — Ephemeral Planning Artifacts

Managed by GSD. You rarely edit these directly — they're created and consumed by workflow skills.

| Artifact | Created by | Purpose |
|----------|-----------|---------|
| `PROJECT.md` | `gsd-new-project` | Vision, core value, requirements |
| `ROADMAP.md` | `gsd-new-project` | Phase structure, status |
| `STATE.md` | `gsd-new-project` | Current progress, decisions, quick tasks |
| `REQUIREMENTS.md` | `gsd-new-milestone` | Scoped requirements with acceptance criteria |
| Phase dirs (`phases/`) | Planning skills | Per-phase context, research, plans, reviews |
| `WORKFLOW.md` | `/silver` composer | Composition state — path log, dynamic insertions, next path |
| `VALIDATION.md` | `silver-validate` | Pre-build validation results |
| `UI-SPEC.md` | `gsd-ui-phase` | UI specification — layout, components, interactions |
| `UI-REVIEW.md` | `gsd-ui-review` | UI review findings — 6-pillar assessment |
| `SECURITY.md` | `gsd-secure-phase` | Security audit findings — threat mitigations |

All planning artifacts are archived on milestone completion — nothing grows unbounded.

---

## Size Caps

Every document has a growth limit:

| Location | Cap | Enforcement |
|----------|-----|-------------|
| `docs/*.md` | 500 lines | Artifact reviewer flags violations |
| `docs/knowledge/*.md`, `docs/lessons/*.md` | 300 lines | Split into `YYYY-MM-a.md` / `YYYY-MM-b.md` if exceeded |
| `.planning/` active files | 300 lines | Milestone completion archives and resets |
| Quick tasks table in `STATE.md` | 20 rows | Oldest archived when exceeded |

---

## When docs get updated

| Event | What updates |
|-------|-------------|
| **Every task** (finalization step) | `CHANGELOG.md`, `knowledge/YYYY-MM.md`, `lessons/YYYY-MM.md` |
| **Architecture changes** | `ARCHITECTURE.md` (rewritten) |
| **Test infrastructure changes** | `TESTING.md` |
| **Docs added or removed** | `knowledge/INDEX.md` |
| **Milestone completion** | Planning artifacts archived; tables trimmed |
| **Release** | `README.md`, root `CHANGELOG.md` |

---

## Non-redundancy rules

1. `docs/` files summarize — `.planning/` artifacts are the source of truth during development
2. `knowledge/` captures intelligence not derivable from code or git history
3. `lessons/` captures portable learnings — never duplicates project-specific knowledge
4. `ARCHITECTURE.md` is high-level design — detailed phase designs stay in `.planning/phases/`
5. `CHANGELOG.md` is the task log — git log is the commit log (different granularity)
6. `WORKFLOW.md` is the composition execution log — `silver-bullet.md` §2h describes the architecture, `WORKFLOW.md` tracks the instance
