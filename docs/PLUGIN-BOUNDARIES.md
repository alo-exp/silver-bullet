# Plugin Responsibility Boundaries

Defines what each plugin owns. Silver Bullet never duplicates documentation or functionality that belongs to another plugin — it orchestrates and enforces.

**Last updated:** 2026-04-13

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
| 7-layer enforcement | — | — | — | — | **Owns** |
| Workflow sequencing | — | — | — | — | **Owns** |
| Pre-release quality gate | — | — | — | — | **Owns** |
| Artifact reviewer framework | — | — | — | — | **Owns** |
| Cross-artifact consistency | — | — | — | — | **Owns** |
| Review analytics | — | — | — | — | **Owns** |
| Configurable review depth | — | — | — | — | **Owns** |

## Architectural Distinction

**GSD** is the execution engine — it runs phases, manages state, creates artifacts.
**Superpowers** provides autonomous patterns — spec-driven development, TDD, subagent dispatch.
**Silver Bullet** is the enforcement layer — it ensures nothing is skipped, everything is sequenced, and quality gates are met.

SB adds enforcement to the GSD+Superpowers+Engineering+Design stack. It never replaces any plugin's functionality.

## Non-Redundancy Rules

1. SB docs never explain GSD phase mechanics — they reference GSD
2. SB docs never explain Superpowers spec philosophy — they reference Superpowers
3. SB docs never document Engineering/Design skill behavior — they reference the skills
4. SB documents only: enforcement layers, orchestration wiring, quality posture, SDLC coverage
5. If content belongs to a plugin, SB links to it rather than duplicating it

## Scalability

**Fixed** — updated when plugin responsibilities shift (rare). Matrix format prevents unbounded growth.

## Codex Marketplace Packaging

For the Codex packaging pattern used with Alo Labs plugins, see
[docs/internal/codex-marketplace-packaging-guide.md](docs/internal/codex-marketplace-packaging-guide.md).
SB's own Codex package stays SB-only; upstream dependency plugins are installed from
their official source repos, and the marketplace hosts only thin Codex packaging when
an upstream project does not publish its own Codex artifact.
