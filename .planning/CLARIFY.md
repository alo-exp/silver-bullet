# SB Dependency Absorption And Repositioning

## Problem Statement

Silver Bullet is currently positioned as an Agentic Process Orchestrator around
GSD, Superpowers, and selected Anthropic Knowledge Work plugins. That made sense
while SB was mostly a workflow composer, but SB has since absorbed several of
those workflows directly. Keeping the dependency plugins as hard requirements now
creates overlap, duplicate routing surfaces, and unclear ownership.

The next major change is to make SB self-contained for software-engineering
process orchestration. SB should absorb only the GSD, Superpowers, and Anthropic
skills it explicitly depends on, merge overlapping skills into SB-native
workflows, and stop requiring those plugins at install/runtime. SB should still
support optional DevOps enrichment plugins because those extend SB into
provider-specific infrastructure domains rather than duplicating SB's core scope.

## Current Context

- The completed v0.37.0 milestone made SB the handholding orchestrator and
  process enforcer for non-trivial SDLC intent.
- `silver:clarify` already absorbed Product Management brainstorming,
  Superpowers brainstorming, and GSD discussion-style handoff behavior into a
  single SB-owned brief flow.
- Current README, homepage, templates, workflow files, install checks, and
  default config still describe GSD as lifecycle authority and Superpowers /
  Anthropic plugins as required helper dependencies.
- `templates/silver-bullet.config.json.default` still requires GSD markers and
  Superpowers markers for planning and deploy floors.
- `silver:init` still hard-checks GSD, Superpowers, Design, Engineering, and
  Product Management plugin availability.
- `silver:feature`, `silver:bugfix`, `silver:ui`, `silver:release`,
  `silver:spec`, `silver:fast`, `silver:forensics`, and workflow templates still
  invoke dependency skills directly.
- Workflow templates also explicitly suggest lifecycle utility commands such as
  `gsd:next`, `gsd:progress`, `gsd:resume-work`, `gsd:pause-work`,
  `gsd:add-phase`, and `gsd:insert-phase`.
- The repo already contains SB-owned quality, security, review, docs,
  handoff, issue capture, validation, TDD-wrapper, and artifact-review skills.
  Those should become the foundation of the absorbed flow system.

## PM Framing

**Audience:** SB users who want one reliable SDLC operating system rather than a
stack of overlapping plugins they must install, understand, and coordinate.

**Value:** Reduce installation friction, remove duplicate skill surfaces, make SB
ownership clearer, and keep the user experience as one coherent SDLC journey.

**Success:** A fresh SB install no longer requires GSD, Superpowers, or Anthropic
Knowledge Work plugins for normal software-engineering workflows. Existing SB
routes still produce equivalent or better artifacts, gates, and user guidance.
Optional DevOps enrichment plugins remain available through the DevOps router.

## Options Considered

### 1. Thin Absorption

Absorb only the exact skills named in `required_planning`,
`required_deploy`, and the active workflow files.

This is the fastest path, but it risks preserving hidden dependency assumptions
inside SB skills and docs. It also misses conditional call sites that are still
part of SB-owned workflows, such as UI design review and release documentation.

### 2. Full Plugin Cloning

Copy or recreate all GSD, Superpowers, and Anthropic skill surfaces inside SB.

This would remove dependency installation, but it would import a large amount of
scope that SB does not explicitly need. It also increases maintenance burden and
blurs the intended boundary between SB-owned SDLC orchestration and optional
specialist plugins.

### 3. Synergistic Flow-Cluster Absorption

Inventory every explicit SB dependency call site, group similar dependency
skills by SB flow responsibility, and create SB-owned merged workflows that
preserve the strongest behavior without exposing the original plugin boundary.

This mirrors the successful `silver:clarify` pattern. It removes required
dependency plugins while avoiding wholesale cloning.

### 4. Keep Dependencies But Rename Positioning

Continue requiring GSD, Superpowers, and Anthropic plugins, but describe them as
embedded ecosystem components.

This does not solve the overlap problem. It keeps install/runtime fragility and
continues to make SB's authority ambiguous.

## Recommendation

Use **Option 3: Synergistic Flow-Cluster Absorption**.

SB should absorb dependency behavior at the flow level, not by one-to-one
copying every upstream skill. The implementation should preserve existing
artifact names where they are part of the SB contract, especially `.planning/`
artifacts, while changing ownership from "GSD owns this" to "SB owns this
lifecycle evidence."

The dependency boundary should be:

- **Absorb:** Any GSD, Superpowers, Product Management, Engineering, or Design
  skill that SB currently requires in config, install checks, workflow templates,
  route skills, completion gates, or conditional SB-owned flows.
- **Do not absorb:** Unreferenced admin utilities, broad plugin capabilities
  listed only as ecosystem marketing, and provider-specific DevOps plugin skills.
- **Keep optional:** DevOps enrichment plugins routed by `devops-skill-router`;
  MultAI-style second-opinion research remains optional and user-requested.

## Absorption Groups

### Clarify And Product Framing

Already mostly absorbed by `silver:clarify`.

Merge sources:

- Anthropic Product Management `product-brainstorming`
- Anthropic Product Management `write-spec` where it supports idea-to-spec
  framing
- Superpowers `brainstorming`
- GSD `discuss-phase` context/decision discipline

SB-owned target behavior:

- Keep `silver:clarify` as the front-end clarify flow.
- Extend handoff so a clarify brief can seed SB-owned milestone or phase
  context without requiring GSD.
- Avoid duplicate spec-writing paths between `silver:clarify` and
  `silver:spec`.

### Project And Milestone Bootstrap

Absorb because SB initialization and workflows explicitly depend on these GSD
behaviors.

Merge sources:

- GSD `new-project`
- GSD `new-milestone`
- GSD `map-codebase`
- GSD `scan`
- GSD `next`
- GSD `progress`
- GSD `resume-work`
- GSD `pause-work`
- GSD `add-phase`
- GSD `insert-phase`
- SB `silver:init`, `silver:scan`, Graphify/project-memory behavior

SB-owned target behavior:

- SB initializes `.planning/PROJECT.md`, `.planning/REQUIREMENTS.md`,
  `.planning/ROADMAP.md`, `.planning/STATE.md`, and codebase intelligence.
- Brownfield mapping becomes an SB-owned orientation flow.
- Session resume, pause, progress, next-step detection, and phase insertion
  become SB-owned lifecycle utilities rather than GSD suggestions.
- Installer no longer checks for GSD.

### Phase Discussion And Context Capture

Absorb because `gsd:discuss-phase` is still a required planning marker.

Merge sources:

- GSD `discuss-phase`
- `silver:clarify`
- SB artifact reviewers, especially `review-context`

SB-owned target behavior:

- Produce phase `CONTEXT.md` artifacts with locked decisions, assumptions, gray
  areas, and deferrals.
- Read prior context and avoid re-asking settled questions.
- Support interactive, auto, all, text, and assumption-driven modes where they
  are useful to SB.

### Spec, Requirements, And Roadmap

Absorb because SB already owns `silver:spec` and still conditionally invokes
Product Management `write-spec`.

Merge sources:

- Anthropic Product Management `write-spec`
- GSD requirements and roadmap generation behavior from `new-project` /
  `new-milestone`
- SB `silver:spec`, `silver:ingest`, `review-spec`, `review-requirements`,
  `review-roadmap`, and cross-artifact review

SB-owned target behavior:

- `silver:spec` becomes fully self-contained.
- Product-style PRD structure, goals, non-goals, user stories, success metrics,
  open questions, and phasing remain preserved.
- SPEC, REQUIREMENTS, ROADMAP, and DESIGN review loops stay SB-owned.

### Architecture And Technical Design

Absorb because workflow templates explicitly invoke `system-design`, the default
config tracks `architecture` and `system-design`, and SB feature/UI flows route
architecture-significant work through research and design decisions.

Merge sources:

- Anthropic Engineering `architecture`
- Anthropic Engineering `system-design`
- SB `silver:research`, `silver:quality-gates`, `review-research`,
  `review-design`, security/reliability/scalability/extensibility gates

SB-owned target behavior:

- SB owns architecture decision framing, system design review, ADR/research
  evidence, and design-time quality checks.
- Architecture guidance feeds into phase context and plans without requiring a
  separate Engineering plugin invocation.

### Planning

Absorb because `gsd:plan-phase` is required before implementation and SB
explicitly redirects Superpowers `writing-plans` to GSD today.

Merge sources:

- GSD `plan-phase`
- GSD `analyze-dependencies`
- Superpowers `writing-plans` discipline
- SB quality gates, validation, artifact review, and dependency analysis

SB-owned target behavior:

- Produce implementation plans that preserve GSD's executable phase planning,
  verification criteria, and dependency structure.
- Preserve dependency analysis before planning when phase ordering or parallel
  execution can drift.
- Preserve Superpowers' insistence on exact file paths, concrete steps, no
  placeholders, TDD readiness, and self-review.
- Eliminate direct references to Superpowers `writing-plans`.

### Execution And TDD

Absorb because `gsd:execute-phase`, `gsd:autonomous`, and
`test-driven-development` are required or explicitly invoked.

Merge sources:

- GSD `execute-phase`
- GSD `autonomous`
- GSD `fast`
- GSD `quick`
- Superpowers `test-driven-development`
- Existing SB `tdd` wrapper

SB-owned target behavior:

- SB owns phase execution modes: standard, autonomous, quick, and trivial.
- Behavior-changing implementation keeps red-green-refactor discipline.
- Execution remains evidence-producing and resumable.
- Existing GSD command names may remain as compatibility aliases temporarily,
  but they should route to SB-owned skills.

### Debugging And Forensics

Absorb because SB bugfix and forensics flows explicitly invoke these skills.

Merge sources:

- Superpowers `systematic-debugging`
- GSD `debug`
- GSD `forensics`
- Anthropic Engineering `debug`
- Anthropic Engineering `incident-response`
- SB `silver:bugfix` and `silver:forensics`

SB-owned target behavior:

- Bugfix starts with root-cause discipline, then runs persistent investigation
  and regression coverage.
- Incident-specific behavior is available for DevOps or production failures,
  but provider-specific remediation remains optional plugin territory.
- Forensics stays SB-owned and routes GSD-specific historical analysis into a
  general SB workflow-state analysis.

### Review And Feedback Triage

Absorb because GSD review and Superpowers review helpers are required deploy
markers.

Merge sources:

- GSD `code-review`
- GSD `code-review-fix`
- GSD `review`
- Superpowers `requesting-code-review`
- Superpowers `receiving-code-review`
- Anthropic Engineering `code-review`
- SB artifact-reviewer framework and review analytics

SB-owned target behavior:

- SB owns review request framing, review execution, feedback skepticism,
  fix/triage, and deferred-item capture.
- `REVIEW.md` remains the authoritative code review artifact.
- Advisory review items that are not fixed must be filed through SB issue/backlog
  capture.

### Verification, Security, And Validation

Absorb because these gates are required before final delivery.

Merge sources:

- GSD `verify-work`
- GSD `secure-phase`
- GSD `validate-phase`
- GSD `add-tests`
- Superpowers `verification-before-completion`
- Anthropic Engineering `testing-strategy`
- SB `verify-tests`, `security`, `silver:validate`, quality gates, UAT gate,
  spec floor, and artifact reviewers

SB-owned target behavior:

- Verification remains evidence-first and conversational where useful.
- Test strategy becomes SB-owned rather than an Engineering plugin dependency.
- Gap-driven test generation from UAT/verification evidence becomes SB-owned.
- Security and validation artifacts stay first-class completion gates.
- No completion claim is accepted without fresh verification evidence.

### UI And Design Quality

Absorb because `silver:ui` and workflow templates explicitly invoke Design and
GSD UI skills.

Merge sources:

- GSD `ui-phase`
- GSD `ui-review`
- Anthropic Design `design-system`
- Anthropic Design `ux-copy`
- Anthropic Design `accessibility-review`
- Anthropic Design `design-critique`
- Anthropic Design `design-handoff`
- Anthropic Design `user-research`
- SB `review-design`, `review-uat`, usability/testability quality gates

SB-owned target behavior:

- SB owns UI-SPEC, design-system audit, UX copy review, accessibility review,
  implemented UI review, and design handoff evidence.
- UI workflow still feels like one SB path rather than a chain of Design plus
  GSD plus SB commands.

### Documentation, Shipping, And Release

Absorb because release workflows explicitly invoke GSD and Engineering release
helpers.

Merge sources:

- GSD `docs-update`
- GSD `ship`
- GSD `audit-uat`
- GSD `audit-milestone`
- GSD `complete-milestone`
- GSD `milestone-summary`
- GSD `plan-milestone-gaps`
- GSD `pr-branch`
- Superpowers `finishing-a-development-branch`
- Anthropic Engineering `documentation`
- Anthropic Engineering `tech-debt`
- Anthropic Engineering `deploy-checklist`
- SB `silver:ensure-docs`, `silver:release`, `silver:create-release`,
  `verify-tests`, CI gates, PR traceability, and docs governance

SB-owned target behavior:

- SB owns docs freshness, milestone audit, UAT audit, gap closure, branch finish,
  tech-debt capture, ship readiness, PR/release evidence, and milestone archival.
- DevOps provider deployment checks remain enrichments when optional DevOps
  plugins are installed.

## Explicit Non-Absorption List

Do not absorb these unless a later SB requirement introduces a direct call site:

- GSD settings, profile, workspace, thread, manager, help, stats, import/export,
  plugin-update, and other admin/maintenance commands.
- Superpowers `executing-plans` and `subagent-driven-development`; SB currently
  forbids them for project execution and should continue to own execution
  through SB workflows.
- Superpowers `using-superpowers`; it is only an activation mechanism and should
  disappear when Superpowers stops being required.
- Anthropic Product Management roadmap, stakeholder update, metrics review,
  competitive brief, sprint planning, and research synthesis skills unless SB
  has a current workflow call site or chooses to make them SB-owned later.
- Non-DevOps optional second-opinion tooling such as MultAI unless the user
  explicitly asks for multi-AI perspectives.
- Provider-specific optional DevOps plugin skills from HashiCorp, AWS Labs,
  Pulumi, DevOps Skills, and Kubernetes/agent ecosystems.

## Assumptions

- "Explicitly depends on" includes required config markers, install-time checks,
  workflow template steps, SB skill call sites, and conditional SB-owned routes.
- Existing `.planning/` artifact names should remain stable during the migration.
- Compatibility aliases for old `gsd-*`, Superpowers, and Anthropic marker names
  may be needed for existing projects, but those aliases should invoke SB-owned
  behavior.
- The absorption should happen in phases; trying to replace every dependency
  surface in one patch is too risky.
- Optional DevOps enrichment remains plugin-based because those skills extend SB
  into provider-specific infrastructure expertise rather than duplicating SB's
  core process engine.

## Unresolved Questions

- Should the next release be named as a major positioning release, such as
  v0.38.0 or v0.40.0, or held for a v1.0 boundary?
- Should SB keep GSD-compatible command aliases indefinitely, or mark them as
  migration shims with a deprecation window?
- Should the installer remove dependency plugin checks in one step, or first
  warn that dependency plugins are no longer required?
- Should dependency skill bodies be re-audited against upstream at the start of
  each absorption phase, or is the current SB call-site behavior the authority?
- Should `.planning/config.json` retain GSD-flavored field names for
  compatibility, or migrate to SB-native field names with backward compatibility?

## Next-Step Notes

Create a new milestone for dependency absorption and split it into small,
auditable phases. Recommended first phases:

1. Inventory every current dependency call site and marker, then freeze the
   absorption matrix.
2. Replace install-time hard checks for GSD, Superpowers, Engineering, Design,
   and Product Management with SB-owned capability checks.
3. Absorb bootstrap, phase context, planning, and execution into SB-owned
   lifecycle skills while preserving existing artifacts.
4. Absorb review, verification, TDD, security, validation, and completion gates.
5. Absorb UI/design, PM/spec, documentation, ship, and release helper behavior.
6. Add compatibility aliases, migration docs, and hook/config updates.
7. Update README, homepage, help center, package manifests, and templates to
   reposition SB as the self-contained SDLC process engine.
8. Run focused hook/skill tests, full local tests, and live install/update smoke
   tests across Claude and Codex before release.

The implementation should start with a dependency inventory phase, not with
rewriting workflow copy. The copy change is the visible outcome; the real risk is
missing a hidden call site or gate marker.
