# Plugin Responsibility Boundaries

Defines what each plugin owns. Silver Bullet never duplicates documentation or functionality that belongs to another plugin — it orchestrates and enforces.

**Last updated:** 2026-05-07

## Ownership Matrix

| Concern | GSD | Superpowers | Engineering | Design | Silver Bullet |
|---------|-----|-------------|-------------|--------|--------------|
| Phase planning | **Owns** | — | — | — | Enforces (dev-cycle gate) |
| Phase execution | **Owns** | — | — | — | Enforces (model routing) |
| Verification | **Owns** | — | — | — | Enforces (completion audit) |
| Spec creation | — | **Owns** | — | — | Orchestrates (silver-spec) |
| TDD methodology | — | **Owns** | — | — | Enforces (required_deploy) |
| Code review dispatch | — | **Owns** | — | — | Enforces (dev-cycle Stage C) |
| Autonomous patterns | — | **Owns** | — | — | Delegates to |
| System design | — | — | **Owns** | — | Triggers at workflow step |
| Deploy checklist | — | — | **Owns** | — | Triggers at workflow step |
| Testing strategy | — | — | **Owns** | — | Triggers at workflow step |
| Incident response | — | — | **Owns** | — | Triggers conditionally |
| UI/UX review | — | — | — | **Owns** | Triggers conditionally |
| Design system | — | — | — | **Owns** | Triggers conditionally |
| Accessibility | — | — | — | **Owns** | Enforces when UI present |
| Codex package surface | — | — | — | — | **Owns** (SB-only bundle; no dependency vendoring) |
| Codex slash commands | — | — | — | — | **Owns** (ship inside the SB bundle; not a separate installed plugin) |
| Third-party Codex wrappers | — | — | — | — | **Owns** (wrapper metadata only; upstream content fetched at install time) |
| 12-layer enforcement | — | — | — | — | **Owns** |
| Workflow sequencing | — | — | — | — | **Owns** |
| Pre-release quality gate | — | — | — | — | **Owns** |
| Artifact reviewer framework | — | — | — | — | **Owns** |
| Cross-artifact consistency | — | — | — | — | **Owns** |
| Review analytics | — | — | — | — | **Owns** |
| Configurable review depth | — | — | — | — | **Owns** |

## Architectural Distinction

**GSD** is the execution engine — it runs phases, manages state, creates artifacts.
**Superpowers** provides craft-discipline helpers — TDD, review framing/triage, verification-before-completion, and branch finishing when SB explicitly selects them.
**Silver Bullet** is the enforcement layer — it ensures nothing is skipped, everything is sequenced, and quality gates are met.
It also owns SB's own packaging surfaces, including the SB-only Codex bundle, the `/silver:*`
command surface that ships inside it, and the shared marketplace glue for third-party Codex wrappers.

SB adds enforcement to the SB+GSD core and only calls Superpowers, Engineering, or Design at explicit helper boundaries. It never replaces any plugin's functionality.

If one of those dependency plugins becomes unavailable during a run, SB
fails closed: stop, notify the user, and offer install-and-retry first.
Only continue with an explicitly approved degraded path if the workflow
documents one.

## Packaging Boundaries

- `/.planning/`, `/.claude/`, and `/.forge/` are project-instance artifacts, not plugin artifacts.
- `silver-bullet.md` is the project-side instance copy; `templates/silver-bullet.md.base` is the source template.
- `plugins/silver-bullet/` is the curated SB-only Codex bundle, synchronized from the repo root.
- `commands/` is the Codex command surface. It exposes `/silver:*` entry points and ships inside the Silver Bullet bundle so the default install presents one SB plugin.
- Third-party Codex wrappers belong in the shared marketplace and fetch upstream content at install time.

## Non-Redundancy Rules

1. SB docs never explain GSD phase mechanics — they reference GSD
2. SB docs never explain Superpowers spec philosophy — they reference Superpowers
3. SB docs never document Engineering/Design skill behavior — they reference the skills
4. SB documents only: enforcement layers, orchestration wiring, quality posture, SDLC coverage
5. If content belongs to a plugin, SB links to it rather than duplicating it
6. SB plugin packaging never vendors dependency plugins or project-instance artifacts

## Scalability

**Fixed** — updated when plugin responsibilities shift (rare). Matrix format prevents unbounded growth.

## Codex Marketplace Packaging

For the Codex packaging pattern used with Alo Labs plugins, see
[docs/internal/codex-marketplace-packaging-guide.md](docs/internal/codex-marketplace-packaging-guide.md).
SB's own Codex package stays SB-only; upstream dependency plugins are installed from
their official source repos, and the marketplace hosts only thin Codex packaging when
an upstream project does not publish its own Codex artifact. SB's slash-command layer
ships inside the main SB bundle so the default install exposes one Silver Bullet plugin
with `/silver:*` commands instead of two separate installed plugins. That wrapper layer
is packaging glue only — it does not copy upstream skills, hooks, templates, or project
docs into this repository.
