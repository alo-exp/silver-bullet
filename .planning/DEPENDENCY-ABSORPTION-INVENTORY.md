# SB Dependency Absorption Inventory

Date: 2026-06-11

Status: implementation slice completed in this worktree. SB now owns the core
context/plan/execute/verify/review/secure/UI/ship/release lifecycle surfaces.
Legacy GSD, Superpowers, and Anthropic knowledge-work names remain only as
compatibility aliases, migration diagnostics, historical docs, or explicit
external-plugin requests.

This inventory turns the clarify brief into an implementation control document.
It maps every explicit GSD, Superpowers, and Anthropic dependency surface found
in the current worktree to an SB-owned absorption decision.

The objective is not to clone dependency plugins. The objective is to make
normal Silver Bullet software-engineering workflows self-contained while
preserving the useful behavior SB currently receives from those plugins.

## Absorption Rule

Absorb a dependency behavior when it appears in at least one current SB-owned
contract surface:

- default config required or tracked skill markers
- install or init hard checks
- hook admission, completion, or dependency gates
- workflow templates or canonical flow contracts
- SB router or SB workflow skill instructions
- homepage, help, or reference docs that define expected normal operation
- tests that encode required workflow behavior

Do not absorb:

- unreferenced upstream admin or settings utilities
- forbidden Superpowers execution modes that SB already blocks
- provider-specific DevOps plugin behavior
- optional marketplace wrappers that extend SB into infrastructure/vendor
  domains rather than duplicating SB's software-engineering lifecycle scope

## Current Hard Dependency Surfaces

### Resolution Status

| Surface | Status |
|---------|--------|
| Default config | Required planning/deploy markers now use SB-owned lifecycle markers. Legacy names remain in `all_tracked` for migration compatibility only. |
| Required-skills reader | Updated to normalize legacy configs onto SB defaults and treat old markers as aliases for SB markers. |
| Workflow chain gate | Updated to require SB lifecycle markers while accepting old markers as compatibility evidence. |
| Dependency gate | Updated so direct GSD/Superpowers/Anthropic knowledge-work requests route to SB replacements unless the user explicitly asks for an external plugin. |
| Init hard checks | Updated: Graphify and core SB checks remain; GSD/Superpowers/Anthropic knowledge-work checks are optional diagnostics only. |
| Codex installer | Updated to install the SB package by default and stop installing absorbed dependency plugins as core requirements. |
| Claude installer | Updated with the same SB-default boundary. |
| Router | Updated so `/silver` routes lifecycle work to SB-owned flows. Explicit legacy lifecycle requests route to SB equivalents unless the user requires external GSD. |
| Flow contract | Updated around SB-owned flow responsibility. |
| Workflow templates | Replaced with SB-owned `full-dev-cycle` and `devops-cycle` canonical workflows. |
| Public docs/site | Updated homepage, help center, reference, troubleshooting, workflow pages, and SB-vs-GSD positioning to describe SB-only core lifecycle. |
| Tests | Focused tests were updated for SB markers and rerun after package regeneration. |

### Remaining Intentional Legacy Surfaces

- `templates/silver-bullet.config.json.default` keeps legacy markers in
  `all_tracked` so old project state remains readable.
- Hook alias tables keep old marker names so migration does not break active
  branches.
- `scripts/gsd-sdk.cjs` and `scripts/install-gsd-sdk-shim.sh` were removed
  (2026-06-17): legacy GSD SDK compatibility shim with no runtime or install
  wiring in the SB lifecycle.
- Historical docs under `docs/superpowers/`, `docs/sessions/`,
  `docs/silver-forensics/`, and older audit/spec records were not rewritten.
- Negative rules may still name forbidden Superpowers execution skills to block
  direct external execution.

| Surface | Current dependency evidence | Migration decision |
|---------|-----------------------------|--------------------|
| Default config | `templates/silver-bullet.config.json.default` requires `gsd-discuss-phase`, `gsd-plan-phase`, `gsd-execute-phase`, `gsd-verify-work`, `gsd-ship`, `gsd-code-review`, `gsd-secure-phase`, `gsd-validate-phase`, Superpowers review/TDD markers, and tracks Anthropic Design/Engineering markers. | Replace required defaults with SB-owned markers. Keep compatibility aliases for old marker names during migration. |
| Required-skills reader | `hooks/lib/required-skills.sh` reads the default config as the source of truth. | Keep this design, but change the config source of truth to SB-owned markers. |
| Workflow chain gate | `hooks/workflow-chain-guard.sh` hardcodes `gsd-discuss-phase`, `gsd-plan-phase`, and `gsd-ui-phase` as edit admission markers. | Replace with SB planning markers while accepting old GSD markers as legacy compatibility. |
| Dependency gate | `hooks/dependency-skill-check.sh` fails closed for `gsd:*`, `superpowers:*`, `design:*`, `engineering:*`, `product-management:*`, and bare helper skills. | Invert this gate: dependency namespaces should be blocked only when they are no longer SB-supported direct routes, while SB-owned replacements must not require external plugin discovery. |
| Init hard checks | `skills/silver-init/SKILL.md` requires Superpowers, Design, Engineering, GSD, and Product Management before project setup proceeds. | Remove hard checks for absorbed dependency plugins. Keep `jq` and Graphify checks. Optional DevOps and optional second-opinion plugins remain non-blocking. |
| Codex installer | `scripts/install-codex.sh` registers/installs Superpowers, GSD, and Anthropic knowledge-work sources. | Stop installing absorbed core dependencies by default. Keep only SB package install plus optional DevOps/plugin-enrichment install paths. |
| Claude installer | `scripts/install-claude.sh` targets Superpowers and Anthropic knowledge-work plugins. | Same as Codex: remove core dependency installs from default path, keep optional install support if user asks for enrichment. |
| Router | `skills/silver/SKILL.md` delegates lifecycle/status work to `gsd:do` and treats GSD as lifecycle authority. | Make `/silver` route to SB-owned lifecycle flows. Keep `gsd:*` only as legacy compatibility or explicit user-requested external plugin usage. |
| Flow contract | `docs/composable-flows-contracts.md` assigns primary ownership for BOOTSTRAP, PLAN, EXECUTE, VERIFY, SHIP, REVIEW, DEBUG, DOCUMENT, and RELEASE to GSD/Superpowers/Product Management. | Rewrite the 18-flow contract around SB-owned lifecycle responsibility. |
| Workflow templates | `templates/workflows/full-dev-cycle.md` and plugin snapshot templates instruct users to invoke `gsd:*` for setup, discuss, plan, execute, verify, review, and ship. | Rewrite as SB-owned lifecycle steps and compatibility notes. |
| Public docs/site | README, homepage, help center, and reference pages present GSD/Superpowers/Anthropic plugins as required. | Reposition SB as the self-contained software-engineering process engine; describe GSD/Superpowers/Anthropic only as former inspirations or optional external compatibility where kept. |
| Tests | Hook, integration, live, and scenario tests assert old required markers and hard dependency checks. | Update tests in the same slice as each runtime contract change; do not leave tests asserting dependency availability as success criteria. |

## Flow-Level Absorption Matrix

| SB flow | Current external owner(s) | Dependency skills currently referenced | SB-owned target |
|---------|---------------------------|----------------------------------------|-----------------|
| BOOTSTRAP | GSD | `gsd:new-project`, `gsd:map-codebase`, `gsd:new-milestone`, `gsd:resume-work`, `gsd:progress` | SB project/milestone bootstrap over `.planning/PROJECT.md`, `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`, `.planning/STATE.md`, and codebase-intel artifacts. |
| ORIENT | GSD/SB | `gsd-scan`, `gsd:map-codebase`, `gsd:progress` | `silver:scan` plus SB-owned project-state and codebase orientation. |
| CLARIFY | SB/Product Management/Superpowers/GSD | `silver:clarify`, PM brainstorming/spec framing, Superpowers brainstorming, `gsd:discuss-phase` handoff | Already mostly absorbed by `silver:clarify`; extend handoff to SB-owned milestone/phase context. |
| DECIDE | SB/GSD/Engineering | `silver:research`, `gsd:spike`, `gsd:discuss-phase`, `architecture`, `system-design` | `silver:research` owns decision framing, ADR-style output, and architecture/system-design review. |
| SPECIFY | SB/Product Management | `silver:ingest`, `product-management:write-spec`, `silver:spec`, `silver:validate` | `silver:spec` and `silver:ingest` fully own PRD/spec/requirements structure and validation. |
| PLAN | GSD/Superpowers | `gsd:discuss-phase`, `writing-plans`, `gsd:list-phase-assumptions`, `gsd:analyze-dependencies`, `gsd:plan-phase` | SB phase-context and phase-plan generation with assumptions, dependency graph, waves, acceptance criteria, and verification plan. |
| DESIGN CONTRACT | GSD/Design/SB | `gsd:ui-phase`, `design-system`, `ux-copy`, `accessibility-review`, `silver:quality-gates` | `silver:ui` and `review-design` own design contract, UX copy, WCAG checks, token/component reuse, and design acceptance. |
| EXECUTE | GSD/Superpowers | `tdd`, `superpowers:test-driven-development`, `gsd:execute-phase`, `gsd:autonomous` | SB-owned execution loop that invokes the active coding agent with plan waves, TDD policy, task summaries, and state updates. |
| UI QUALITY | GSD/Design/SB | `gsd:ui-review`, `design-critique`, `accessibility-review` | `silver:ui` and `review-design` own visual/UI review and gap closure. |
| REVIEW | GSD/Superpowers/Engineering | `superpowers:requesting-code-review`, `gsd:code-review`, `gsd:code-review-fix`, `superpowers:receiving-code-review`, `gsd:review`, `code-review` | SB-owned review request, review artifact generation, findings triage, fix loop, and optional cross-AI review. |
| SECURE | GSD/SB/Engineering | `security`, `gsd:secure-phase`, `gsd:validate-phase`, `silver:ai-llm-safety` | SB security, AI/LLM safety, and validation gates own threat review and gap closure. |
| VERIFY | GSD/Superpowers/SB | `gsd:verify-work`, `gsd:add-tests`, `verify-tests`, `superpowers:verification-before-completion` | SB verification gate owns must-have checks, test freshness, coverage-gap routing, UAT evidence, and completion-claim audit. |
| QUALITY GATE | SB | `silver:quality-gates`, `devops-quality-gates`, dimension skills | Already SB-owned. Preserve as the common pre-plan and pre-ship gate. |
| SHIP | GSD | `gsd:pr-branch`, `gsd:ship` | SB-owned PR/CI/ship step with branch hygiene, PR body, traceability, and state/roadmap updates. |
| DEBUG | GSD/Superpowers/SB | `superpowers:systematic-debugging`, `gsd:debug`, `silver:forensics`, `gsd:forensics` | `silver:forensics` and `silver:bugfix` own root cause, reproduction, minimal fix path, and workflow recovery. |
| DESIGN HANDOFF | Design/SB | `design-handoff`, `design-system`, `silver:handoff` | SB handoff plus UI/design release notes and optional Figma/design-system checklist. |
| DOCUMENT | GSD/Engineering/SB | `gsd:docs-update`, `documentation`, `gsd:milestone-summary`, `gsd:session-report`, `silver:handoff` | `silver:ensure-docs`, `silver:handoff`, and docs gates own durable docs, session summaries, and milestone narrative. |
| RELEASE | GSD/SB | `gsd:audit-uat`, `gsd:audit-milestone`, `gsd:plan-milestone-gaps`, `gsd:complete-milestone`, `silver:create-release` | `silver:release` and `silver:create-release` own milestone audit, gap planning, archive, changelog, tag, and GitHub Release. |

## Skill Absorption Decisions

### GSD Core Lifecycle

| External skill | Evidence type | SB target | Decision |
|----------------|---------------|-----------|----------|
| `gsd:new-project` | Flow contract, workflow template, config tracking, docs/site | `silver:init` plus SB bootstrap flow | Absorb. |
| `gsd:new-milestone` | Flow contract, workflow template, router/docs | SB milestone bootstrap flow | Absorb. |
| `gsd:map-codebase` | Flow contract, workflow template, `silver:feature` | `silver:scan` and SB orientation | Absorb. |
| `gsd-scan` / `gsd:scan` | Flow contract, feature skill, config tracking | `silver:scan` | Absorb by consolidating around `silver:scan`. |
| `gsd:progress` / `gsd:next` | Flow contract, workflow template, docs/site | SB progress/next lifecycle utility | Absorb. |
| `gsd:resume-work` / `gsd:pause-work` | Flow contract, workflow template, docs/site | `silver:handoff` plus SB state resume | Absorb. |
| `gsd:discuss-phase` | Required planning marker, flow contract, workflow template, router | SB phase-context flow | Absorb. |
| `gsd:plan-phase` | Required planning marker, flow contract, workflow template, router | SB phase-plan flow | Absorb. |
| `gsd:list-phase-assumptions` | Flow contract | SB phase-plan flow | Absorb as plan validation behavior. |
| `gsd:analyze-dependencies` | Flow contract/workflow suggestions | SB phase-plan dependency graph | Absorb. |
| `gsd:execute-phase` | Required deploy marker, flow contract, workflow template, feature skill | SB execution loop | Absorb. |
| `gsd:autonomous` | Flow contract, feature skill | SB autonomous progress loop | Absorb behavior, not necessarily command name. |
| `gsd:verify-work` | Required deploy marker, flow contract, workflow template | SB verification gate | Absorb. |
| `gsd:ship` | Required deploy marker, flow contract, workflow template | SB ship/PR flow | Absorb. |
| `gsd:code-review` | Required deploy marker, flow contract, workflow template | SB review flow | Absorb. |
| `gsd:code-review-fix` | Flow contract/docs/tests | SB review-fix loop | Absorb. |
| `gsd:secure-phase` | Required deploy marker, flow contract, workflow template | SB secure flow | Absorb. |
| `gsd:validate-phase` | Required deploy marker, flow contract, workflow template | `silver:validate` plus validation gate | Absorb. |
| `gsd:ui-phase` | UI workflow chain gate, flow contract, config tracking | `silver:ui` design-contract flow | Absorb. |
| `gsd:ui-review` | Flow contract, config tracking | `review-design` / `silver:ui` UI-quality flow | Absorb. |
| `gsd:add-tests` | Flow contract | `verify-tests` plus SB test-gap flow | Absorb. |
| `gsd:pr-branch` | Flow contract/docs | SB ship branch hygiene | Absorb. |
| `gsd:debug` | Flow contract, bugfix/forensics docs | `silver:bugfix` and `silver:forensics` | Absorb. |
| `gsd:forensics` | Flow contract/docs | `silver:forensics` | Absorb where SB currently delegates workflow failures. |
| `gsd:docs-update` | Flow contract/docs | `silver:ensure-docs` | Absorb. |
| `gsd:milestone-summary` | Flow contract/docs | `silver:release` milestone summary | Absorb. |
| `gsd:session-report` | Flow contract/docs | `silver:handoff` | Absorb. |
| `gsd:audit-uat` | Flow contract/release docs | `silver:release` UAT audit | Absorb. |
| `gsd:audit-milestone` | Flow contract/release docs | `silver:release` milestone audit | Absorb. |
| `gsd:plan-milestone-gaps` | Flow contract/release docs | `silver:release` gap-planning subflow | Absorb. |
| `gsd:complete-milestone` | Flow contract/release docs/UAT gate | `silver:release` archive/complete flow | Absorb. |
| `gsd:fast` / `gsd:quick` | Router, workflow docs, `silver:fast` | `silver:fast` | Absorb. |
| `gsd:add-phase` / `gsd:insert-phase` | Workflow template/docs | SB roadmap phase utility | Absorb. |
| `gsd:add-backlog` / `gsd:review-backlog` | Docs/suggestions | `silver:add` / issue workflow | Absorb only if still referenced after router cleanup. |

### Superpowers

| External skill | Evidence type | SB target | Decision |
|----------------|---------------|-----------|----------|
| `superpowers:brainstorming` | `silver:clarify` lineage and docs | `silver:clarify` | Already absorbed; keep as source attribution only where useful. |
| `superpowers:test-driven-development` / `test-driven-development` | Required deploy marker, `tdd` wrapper | `tdd` SB-owned TDD policy | Absorb fully; remove requirement to invoke Superpowers directly. |
| `superpowers:systematic-debugging` / `systematic-debugging` | Flow contract/debug docs | `silver:bugfix` / `silver:forensics` | Absorb. |
| `superpowers:requesting-code-review` / `requesting-code-review` | Required deploy marker, flow contract, docs/tests | SB review-request subflow | Absorb. |
| `superpowers:receiving-code-review` / `receiving-code-review` | Required deploy marker, flow contract, docs/tests | SB review-triage subflow | Absorb. |
| `superpowers:finishing-a-development-branch` / `finishing-a-development-branch` | Required deploy marker, hooks/tests | SB branch-finishing/ship subflow | Absorb. |
| `superpowers:verification-before-completion` / `verification-before-completion` | Required deploy marker, hooks/tests | SB completion-claim audit | Absorb. |
| `superpowers:writing-plans` / `writing-plans` | Flow contract, tests/scenarios | SB phase-plan generation | Absorb. |
| `superpowers:executing-plans` | Forbidden-skill check | None | Do not absorb; keep forbidden unless future SB design changes. |
| `superpowers:subagent-driven-development` | Forbidden-skill check | None | Do not absorb; keep forbidden unless future SB design changes. |
| `superpowers:using-superpowers` | Activation-only dependency | None | Remove from SB-facing dependency model. |

### Anthropic Product Management

| External skill | Evidence type | SB target | Decision |
|----------------|---------------|-----------|----------|
| `product-management:product-brainstorming` | `silver:clarify` lineage | `silver:clarify` | Already absorbed. |
| `product-management:write-spec` / `write-spec` | `silver:init` hard check, flow contract, dependency gate | `silver:spec` | Absorb. |
| `product-management:synthesize-research` | Flow contract optional CLARIFY step, homepage plugin card | `silver:research` / `silver:clarify` | Absorb only the research-synthesis lens currently used by SB; remove plugin invocation. |
| `product-management:competitive-brief` | Flow contract optional CLARIFY step, homepage plugin card | `silver:research` | Absorb as optional market/competitive framing inside SB research. |
| `roadmap-update`, `sprint-planning`, `stakeholder-update`, `metrics-review` | Homepage broad plugin copy only unless further call sites remain | None or future PM layer | Do not absorb in first pass unless a live SB call site is found. |

### Anthropic Engineering

| External skill | Evidence type | SB target | Decision |
|----------------|---------------|-----------|----------|
| `architecture` | Config tracking, docs/site | `silver:research` / quality gates | Absorb as architecture review lens. |
| `system-design` | Config tracking, flow docs, site | `silver:research` / design contract | Absorb. |
| `testing-strategy` | Docs/tests and retired/legacy config behavior | `verify-tests` / SB plan verification | Absorb if still referenced after retired-marker cleanup. |
| `documentation` | Docs/tests and retired/legacy config behavior | `silver:ensure-docs` | Absorb. |
| `deploy-checklist` | Docs/tests and retired/legacy config behavior | `silver:release` / `silver:devops` | Absorb if still referenced after cleanup. |
| `incident-response` | Config tracking/docs | `silver:bugfix` / `silver:forensics` | Absorb as incident/failure mode, especially DevOps path. |
| `tech-debt` | Docs/tests and retired/legacy config behavior | `silver:add` / docs issue capture | Absorb if still referenced after cleanup. |
| `code-review` | Dependency gate/config/docs ambiguity | SB review flow | Absorb where used as Engineering review lens; avoid collision with GSD `gsd:code-review`. |
| `debug` | Upstream Engineering capability; current hard evidence weaker than GSD/Superpowers debug | `silver:bugfix` | Absorb only if direct SB call site remains after cleanup. |

### Anthropic Design

| External skill | Evidence type | SB target | Decision |
|----------------|---------------|-----------|----------|
| `design-system` | Config tracking, flow contract, site/help | `silver:ui` / `review-design` | Absorb. |
| `ux-copy` | Config tracking, flow contract, site/help | `silver:ui` / `review-design` | Absorb. |
| `accessibility-review` | Config tracking, flow contract, site/help | `silver:ui`, `review-design`, `usability` | Absorb WCAG-oriented checks. |
| `design-critique` | Flow contract/dependency gate/site | `review-design` | Absorb. |
| `design-handoff` | Flow contract/site | `silver:handoff` / release design handoff | Absorb. |
| `user-research` | Dependency gate / broad plugin capability | `silver:clarify` or `silver:research` if retained | Do not absorb unless current route keeps a user-research step. |
| `research-synthesis` | Homepage/broad plugin capability | `silver:research` if retained | Do not absorb unless direct call site remains. |

## Optional Plugins To Keep External

These extend SB rather than overlap with core SB software-engineering process
scope. They should stay optional and routed by `devops-skill-router` or
task-specific user requests:

- HashiCorp/Terraform skills
- AWS Labs/cloud-provider skills
- Pulumi skills
- Kubernetes/Helm/operator skills
- generic DevOps skills that are provider/tool specific
- MultAI-style second-opinion research, unless the user explicitly asks for it

## Marker Migration

SB should migrate toward SB-owned markers while accepting old markers for a
compatibility window.

| Legacy marker | New SB-owned marker |
|---------------|---------------------|
| `gsd-new-project` | `silver-bootstrap-project` |
| `gsd-new-milestone` | `silver-bootstrap-milestone` |
| `gsd-scan` / `gsd-map-codebase` | `silver-orient` |
| `gsd-discuss-phase` | `silver-context` |
| `gsd-plan-phase` | `silver-plan` |
| `gsd-execute-phase` | `silver-execute` |
| `gsd-verify-work` | `silver-verify` |
| `gsd-ship` | `silver-ship` |
| `gsd-code-review` | `silver-review` |
| `gsd-secure-phase` | `silver-secure` |
| `gsd-validate-phase` | `silver-validate` |
| `gsd-ui-phase` | `silver-ui-contract` |
| `gsd-ui-review` | `silver-ui-review` |
| `requesting-code-review` | `silver-review-request` |
| `receiving-code-review` | `silver-review-triage` |
| `finishing-a-development-branch` | `silver-branch-finish` |
| `verification-before-completion` | `silver-completion-audit` |
| `test-driven-development` | `silver-tdd` |
| `systematic-debugging` | `silver-debug` |
| `writing-plans` | `silver-plan` |

Compatibility rule: hooks should count a legacy marker as satisfying the new
marker while existing projects migrate, but new config/templates should emit
only SB-owned markers.

## First Implementation Slice

The safest first slice is the runtime dependency boundary, because it removes
install-time/runtime hard dependency without yet rewriting every public page.

1. Change default config required markers from GSD/Superpowers names to SB-owned
   marker names.
2. Teach `hooks/lib/required-skills.sh` and gate consumers to treat legacy
   markers as aliases for SB-owned markers.

## 2026-06-11 Implementation Status

Completed in this slice:

- Runtime required markers now use SB-owned lifecycle markers, with legacy
  GSD/Superpowers aliases accepted for compatibility.
- Codex and Claude installers no longer install or enable GSD, Superpowers, or
  Anthropic knowledge-work plugins by default.
- SB-owned lifecycle skill contracts were added for context, plan, execute,
  verify, review, review request/triage, secure, UI contract/review, debug,
  branch finish, completion audit, and ship.
- `silver:clarify`, `silver:spec`, `silver:init`, `silver:quality-gates`, and
  `devops-quality-gates` were moved away from hard dependency invocation paths.
- README/package metadata and the homepage were repositioned around SB-owned
  lifecycle responsibility instead of SB+GSD dependency positioning.
- Generated Claude/Codex/package surfaces were refreshed.

Verified:

- `bash tests/scripts/test-sync-codex-package.sh` -> 95 passed.
- `bash tests/scripts/test-install-codex.sh` -> 313 passed.
- `bash tests/scripts/test-install-claude.sh` -> 12 passed.
- `bash tests/scripts/test-codex-cli-isolation.sh` -> 38 passed.
- `bash tests/hooks/test-required-skills-consistency.sh` -> 10 passed.
- `bash tests/hooks/test-dependency-skill-check.sh` -> 8 passed.
- `git diff --check` on touched absorption files -> clean.

Still outstanding before the overall goal is complete:

- `silver:release` still delegates milestone audit, gap planning, docs update,
  ship, milestone completion, and PR-branch work to GSD/Design/Engineering
  skills. It needs an SB-owned release contract.
- `silver:forensics`, `silver:scan`, `silver:research`, `silver:create-release`,
  artifact-review docs, and quality-dimension helper docs still contain
  direct GSD/Superpowers references.
- `site/help/index.html` and `site/sb-vs-gsd/index.html` still carry old public
  positioning and need the same repositioning as the homepage.
- `scripts/deploy-gate-snippet.sh` remains a legacy compatibility surface that
  needs an explicit keep/remove decision. (`gsd-sdk.cjs` / GSD SDK shim removed
  2026-06-17.)
3. Rewrite `hooks/workflow-chain-guard.sh` pre-execution marker lists to use
   SB-owned markers and legacy aliases.
4. Change `hooks/dependency-skill-check.sh` so absorbed dependency namespaces
   are no longer required for normal SB-owned flow markers.
5. Remove hard GSD/Superpowers/Anthropic checks from `silver:init`; keep optional
   plugin discovery as informational.
6. Update focused hook tests for required-skills consistency,
   workflow-chain-guard, dependency-skill-check, stop-check, prompt-reminder,
   dev-cycle-check, completion-audit, and compliance-status.

Exit condition for this slice:

- A fresh SB config does not require GSD, Superpowers, or Anthropic
  knowledge-work markers for planning or delivery gates.
- Existing projects with legacy markers still pass gates.
- `silver:init` no longer stops because GSD, Superpowers, Engineering, Design,
  or Product Management plugins are missing.
- Optional DevOps enrichment remains visible and non-blocking.

## Later Slices

After the runtime boundary is safe:

1. Absorb bootstrap/context/plan execution instructions into SB-owned skills.
2. Absorb review, TDD, verification, security, validation, and ship flows.
3. Absorb UI/design and PM/spec/research helpers.
4. Rewrite canonical flow contracts, workflow templates, router docs, README,
   homepage, help center, and troubleshooting.
5. Remove dependency marketplace installs from default installers.
6. Regenerate agent bundles and Codex package snapshots.
7. Run focused hook tests, integration tests, package integrity tests, install
   tests, site freshness tests, and live Claude/Codex/Kay smoke tests.

## Open Implementation Questions

- Should compatibility aliases be kept permanently or only until the first major
  release after absorption?
- Should SB expose the new lifecycle fragments as user-visible `/silver:*`
  commands, internal markers only, or a mix?
- Should `.planning/config.json` retain its GSD-flavored schema version or move
  to an SB-native state schema in the same release?
- Should default installers remove dependency setup in one release, or support a
  `--with-legacy-dependencies` flag for users who still want the old stack?
- Which Anthropic optional PM/Design capabilities should be retained as SB
  lenses versus removed from the flow contract as no longer explicit SB scope?
