# Silver Bullet

[![version](https://img.shields.io/badge/version-v0.37.5-blue)](https://github.com/alo-exp/silver-bullet/releases/tag/v0.37.5)
[![license](https://img.shields.io/badge/license-MIT-green)](LICENSE)

**Agentic Process Orchestrator for AI-native Software Engineering and DevOps.**

Silver Bullet is the orchestration and enforcement layer around
[GSD](https://github.com/gsd-build/get-shit-done). GSD remains the lifecycle
engine: project state, roadmaps, phase planning, execution, verification, review,
ship, and milestone work. Silver Bullet adds the missing operating system around
that engine: dynamic workflow composition, hook-backed gates, cross-plugin
sequencing, quality controls, traceability, documentation governance, and release
discipline.

Plain version: describe what you want to do. Start with `/silver`. Silver Bullet
classifies the task, composes the right workflow for that task, invokes GSD where
GSD owns the lifecycle, and keeps the agent from skipping required steps before
code, PRs, deploys, or releases.

> "There is no single development, in either technology or management technique,
> which by itself promises even one order-of-magnitude improvement..." -
> Fred Brooks, 1986

Brooks was right. Silver Bullet is not one magic technique. It is the coordinated
process layer that makes AI-native delivery less dependent on agent memory and
operator vigilance.

## What Silver Bullet Adds

GSD is already a strong planning and execution system. Silver Bullet adds the
APO layer around it:

| Area | Plain GSD | Silver Bullet + GSD |
|------|-----------|---------------------|
| Entry point | `gsd:*` commands and `gsd:do` | `/silver` routes freeform work into a task-shaped SB+GSD workflow |
| Workflow shape | GSD lifecycle commands | Dynamic composition from 18 atomic flows |
| Process discipline | Instructional and artifact-driven | Hook-enforced and state-tracked |
| Cross-plugin work | Manual or ad hoc | Explicit sequencing across GSD, SB gates, and selected helper plugins |
| Quality | GSD review and verification | Product, security, DevOps, docs, UAT, CI, and release gates |
| Delivery safety | Operator discipline plus GSD artifacts | Mechanical blocks on unsafe edits, planning-file writes, PRs, deploys, and releases |
| Continuity | GSD state and phase artifacts | Session logs, handoff, issue capture, knowledge capture, anti-stall checks, and forensics |

The important distinction: Silver Bullet does not replace GSD. It composes around
GSD and preserves GSD as the authority for `.planning/`, semver-relevant project
work, execution, verification, review, ship, and milestone lifecycle.

## Current Positioning

Silver Bullet is an **Agentic Process Orchestrator (APO)**:

- **Agentic**: built for AI coding agents that can forget, shortcut, overfit, or
  over-trust their own prior context.
- **Process**: turns SDLC discipline into explicit flows, artifacts, and gates.
- **Orchestrator**: chooses and sequences the right tools for the task instead of
  forcing every task through one rigid workflow.

Silver Bullet uses helper plugins only at selected boundaries. Superpowers is
used for SB-required helper surfaces such as TDD, review framing, review
receiving, verification-before-completion, and branch finishing when the active
workflow calls for them. It is not the execution engine; GSD owns execution.

## How It Works

You normally start with:

```text
/silver improve the account settings page and ship it safely
```

The router classifies the request, displays the selected route, and invokes the
appropriate SB or GSD workflow. Examples:

| Intent | Typical route | Why |
|--------|---------------|-----|
| Build or enhance a feature | `silver:feature` | Adds SB gates around GSD planning, execution, review, verification, and ship |
| Fix a regression | `silver:bugfix` | Inserts debug/TDD before the normal lifecycle |
| Work on UI | `silver:ui` | Adds design contract and UI quality review around GSD execution |
| Change infrastructure | `silver:devops` | Adds blast radius, IaC gates, promotion, and rollback discipline |
| Research a decision | `silver:research` | Produces a decision artifact before implementation |
| Prepare a release | `silver:release` | Runs documentation, UAT, milestone, release, and publication gates |
| Make a small safe edit | `silver:fast` | Routes low-risk work through a lighter path |
| Ask GSD to choose a lifecycle action | `gsd:do` | Delegates directly to GSD where GSD owns the decision |

### Dynamic Composition, Not A Fixed Script

Silver Bullet starts from two workflow families, then composes the exact flow
chain needed for the task:

| Workflow family | Use for | Composition surface |
|-----------------|---------|---------------------|
| `full-dev-cycle` | Applications, APIs, CLIs, libraries, plugin work | Clarify, specify, plan, execute, review, secure, verify, document, ship, release |
| `devops-cycle` | Terraform, Kubernetes, Helm, CI/CD, cloud, ops | Incident path, blast radius, IaC quality, environment promotion, deploy/rollback, release |

The canonical flow catalog lives in
[docs/composable-flows-contracts.md](docs/composable-flows-contracts.md). It
contains 18 atomic flows:

```text
BOOTSTRAP -> ORIENT -> CLARIFY -> DECIDE -> SPECIFY -> PLAN
-> DESIGN CONTRACT -> EXECUTE -> UI QUALITY -> REVIEW -> SECURE
-> VERIFY -> QUALITY GATE -> SHIP -> DEBUG -> DESIGN HANDOFF
-> DOCUMENT -> RELEASE
```

`/silver` includes only the flows whose prerequisites and triggers apply. For
example, a UI bugfix can include DEBUG, DESIGN CONTRACT, EXECUTE, UI QUALITY,
REVIEW, VERIFY, and SHIP without pretending every task needs a release flow.

## Enforcement Model

Silver Bullet is intentionally more than instructions in a README. It installs
hooks that observe real tool usage and state transitions.

Common examples:

```text
HARD STOP - Planning incomplete.
Missing: silver-quality-gates, gsd-discuss-phase, gsd-plan-phase
Run the missing planning steps before editing source code.
```

```text
COMPLETION BLOCKED - Workflow incomplete.
Final delivery requires review, security, validation, test freshness,
release readiness, and ship markers before PR/deploy/release commands proceed.
```

```text
Silver Bullet: 8 steps | PLANNING 3/3 | REVIEW 1/3 | FINALIZATION 0/4
Next: requesting-code-review
```

### Two-Tier Delivery Discipline

Silver Bullet deliberately does not block every useful intermediate commit.

- **Planning floor**: source edits and intermediate development commits require
  the selected SB+GSD pre-execution chain.
- **Final delivery floor**: PR creation, deploy commands, release commands, and
  completion claims require the broader review/security/validation/test/release
  chain.

This keeps GSD's atomic task commits viable while still blocking premature final
delivery.

### Enforcement Layers

| Layer | Hook or surface | Purpose |
|-------|-----------------|---------|
| 1 | `record-skill.sh` | Records completed SB/GSD/helper skill invocations |
| 2 | `record-requested-skill.sh` | Records requested `/silver` and GSD routes before work starts |
| 3 | `prompt-reminder.sh` | Re-injects missing steps and core rules before each user prompt |
| 4 | `dev-cycle-check.sh` | Blocks source edits before the required planning floor |
| 5 | `workflow-chain-guard.sh` | Blocks active composed workflows when downstream dependency markers are missing |
| 6 | `dependency-skill-check.sh` | Fails closed when required dependency skills are unavailable |
| 7 | `planning-file-guard.sh` | Blocks direct edits to GSD-owned planning artifacts |
| 8 | `completion-audit.sh` | Blocks PR/deploy/release and selected delivery commands when final gates are missing |
| 9 | `ci-status-check.sh` | Blocks push, PR, and release while CI is red; commit remains warning-only so CI fixes are possible |
| 10 | `stop-check.sh` | Blocks task-complete declarations when required gates are missing |
| 11 | `uat-gate.sh` and `spec-floor-check.sh` | Enforce minimum spec and UAT evidence before lifecycle completion |
| 12 | `forbidden-skill-check.sh`, `instruction-file-guard.sh`, `trivial-file-guard.sh` | Protect against deprecated paths, unsafe instruction-file creation, and legacy bypass abuse |

Additional support hooks handle session logging, timeout/stall warnings,
semantic compression, roadmap freshness, PR traceability, phase archive safety,
and compliance status.

Hook-backed enforcement requires a runtime that supports the relevant hook
events. In less capable runtimes, Silver Bullet can still provide workflow
guidance, but hard blocks depend on host support.

## Runtime Support

| Runtime | Status | Notes |
|---------|--------|-------|
| Claude Code | Primary plugin runtime | Uses Claude plugin skills, commands, and hooks |
| Codex | Supported package runtime | Uses an SB-only Codex package plus dependency marketplaces |
| Kay | Tested agent for isolated live testing | Used for isolated live testing via the `opencode-go` provider path |
| Forge | Port available | Uses Forge skills, slash commands, and hook-equivalent custom agents |

Silver Bullet's Codex package intentionally contains only SB-owned surfaces:
skills, hooks, templates, commands, and helper scripts. GSD, Superpowers, and
selected helper plugins are installed from their own official sources or via
thin Codex wrappers in the shared `alo-labs/codex-plugins` marketplace.

## Install

Install `jq` first:

```bash
brew install jq
# or
sudo apt install jq
```

### Claude Code

Install Silver Bullet and its required helper dependencies:

```text
/plugin install alo-exp/silver-bullet
/plugin install obra/superpowers
/plugin install anthropics/knowledge-work-plugins/tree/main/engineering
/plugin install anthropics/knowledge-work-plugins/tree/main/design
/plugin install anthropics/knowledge-work-plugins/tree/main/product-management
```

Install GSD:

```bash
npx get-shit-done-cc@latest
```

Then open a project and run:

```text
/silver:init
```

### Codex

For local development from this repository checkout:

```bash
./scripts/install-codex.sh --purge-legacy-skills
```

The installer:

- syncs the curated SB-only Codex bundle in `plugins/silver-bullet/`
- registers the shared `alo-labs/codex-plugins` marketplace
- installs or wires GSD, Superpowers, Engineering, Design, and Product Management from their official sources when needed
- keeps `/silver` and `/silver:*` in the main Silver Bullet package
- includes the packaged `scripts/workflows.sh` helper used by composed workflow
  tracking
- enables SB only when the current working directory is an actual SB project
  root (`.silver-bullet.json` plus `silver-bullet.md`)
- purges stale SB user-level hook entries so unrelated Codex projects do not get
  Silver Bullet hooks
- seeds Codex hook trust from the installed plugin manifest instead of
  duplicating SB hooks into the user's global hook cache

For isolated Codex-compatible live testing, Kay `v0.9.6` plus the
`opencode-go` provider path is the tested route. The live harness creates a
temporary `KAY_HOME` root so tests do not rewrite the user's real Kay or Codex
hook cache.

### Forge

Silver Bullet also ships a Forge port:

```bash
curl -fsSL https://raw.githubusercontent.com/alo-exp/silver-bullet/main/forge-sb-install.sh | bash
```

Then run `silver-init` in the target project.

See [forge/PARITY.md](forge/PARITY.md) for the Claude Code to Forge capability
map.

### Optional DevOps Plugins

The `devops-cycle` works without optional DevOps plugins, but these enrich
provider-specific work when installed:

```text
/plugin marketplace add hashicorp/agent-skills
/plugin marketplace add awslabs/agent-plugins
/plugin marketplace add pulumi/agent-skills
/plugin marketplace add ahmedasmar/devops-claude-skills
/plugin marketplace add wshobson/agents
```

Silver Bullet detects installed DevOps plugins during `/silver:init` and records
availability in `.silver-bullet.json`.

## Project Initialization

Run this once in a project:

```text
/silver:init
```

It will:

- detect project name, source paths, stack, and workflow type
- create or update `.silver-bullet.json`
- create `silver-bullet.md` from `templates/silver-bullet.md.base`
- reconcile existing host instruction files (`CLAUDE.md` in Claude, `AGENTS.md`
  in Codex) without overwriting user-owned content
- copy workflow docs into `docs/workflows/`
- scaffold the documentation scheme and durable knowledge/lessons folders
- initialize or connect GSD planning artifacts
- set up enforcement state paths under `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/`

After that, use `/silver` for normal work.

## Built-In Skills And Routes

| Route or skill | Purpose |
|----------------|---------|
| `/silver` | Main natural-language router and APO entry point |
| `/silver:init` | Project setup, dependency checks, config, workflow docs, doc scheme |
| `/silver:feature` | Feature workflow around GSD lifecycle |
| `/silver:bugfix` | Debug/TDD-oriented bugfix workflow |
| `/silver:ui` | UI workflow with design contract and UI quality gates |
| `/silver:devops` | Infrastructure workflow with blast radius and IaC gates |
| `/silver:research` | Research and decision workflow |
| `/silver:spec` | Spec and requirements elicitation |
| `/silver:ingest` | External artifact ingestion with manifest review |
| `/silver:validate` | Gap analysis and validation before implementation or release |
| `/silver:release` | Release preparation workflow |
| `/silver:create-release` | Final release artifact creation after GSD release readiness |
| `/silver:fast` | Small, low-risk work through a routed fast path |
| `/silver:ensure-docs` | Documentation scheme bootstrap, reconciliation, and recovery |
| `/silver:scan` | Retrospective session scan for deferred issues and insights |
| `/silver:add` | File an issue or backlog item |
| `/silver:remove` | Remove or close an issue/backlog item |
| `/silver:rem` | Capture knowledge or lessons learned |
| `/silver:handoff` | Create a project-level handoff prompt |
| `/silver:forensics` | Reconstruct failed, stalled, or abandoned sessions |
| `/silver:quality-gates` | Product/software quality assessment |
| `/silver-blast-radius` | DevOps change-impact and rollback assessment |
| `/devops-quality-gates` | IaC quality assessment |
| `/devops-skill-router` | Selects optional DevOps plugin skills for the current toolchain |
| `/verify-tests` | Runs configured verification commands or stack defaults and writes a freshness marker |

Logical route names may appear differently by host. For example, a Codex plugin
install may expose `silver-bullet:silver-feature`, while generated command
surfaces may expose `silver:feature`. The workflow contracts use logical names;
the host adapter chooses the equivalent exposed name.

## Configuration

Project config lives in `.silver-bullet.json`. The default source of truth is
[templates/silver-bullet.config.json.default](templates/silver-bullet.config.json.default).

Minimal shape:

```json
{
  "config_version": "0.37.0",
  "version": "0.37.0",
  "project": {
    "name": "my-app",
    "src_pattern": "/src/",
    "src_exclude_pattern": "__tests__|\\.test\\.",
    "active_workflow": "full-dev-cycle"
  },
  "skills": {
    "required_planning": [
      "silver-quality-gates",
      "gsd-discuss-phase",
      "gsd-plan-phase"
    ],
    "required_deploy": [
      "silver-quality-gates",
      "gsd-discuss-phase",
      "gsd-plan-phase",
      "gsd-execute-phase",
      "gsd-verify-work",
      "gsd-ship",
      "gsd-code-review",
      "gsd-secure-phase",
      "gsd-validate-phase",
      "requesting-code-review",
      "receiving-code-review",
      "finishing-a-development-branch",
      "silver-create-release",
      "verification-before-completion",
      "test-driven-development",
      "verify-tests"
    ]
  },
  "state": {
    "state_file": "${SB_RUNTIME_HOME_ROOT}/.silver-bullet/state",
    "trivial_file": "${SB_RUNTIME_HOME_ROOT}/.silver-bullet/trivial"
  },
  "release": {
    "profile": "generic",
    "require_plugin_runtime_matrix": true,
    "require_pre_release_quality_gate": true,
    "quality_gate_state_file": "${SB_RUNTIME_HOME_ROOT}/.silver-bullet/quality-gate-state"
  }
}
```

Important fields:

| Field | Meaning |
|-------|---------|
| `project.src_pattern` | Regex for files that count as source and trigger enforcement |
| `project.src_exclude_pattern` | Regex for source-like files excluded from implementation gates |
| `project.active_workflow` | `full-dev-cycle` or `devops-cycle` |
| `skills.required_planning` | Planning floor before implementation work |
| `skills.required_planning_devops` | DevOps-specific planning floor |
| `skills.required_deploy` | Final delivery floor for PR/deploy/release |
| `skills.all_tracked` | Canonical list of skill markers hooks record |
| `devops_plugins` | Optional DevOps plugin availability detected by init |
| `release.require_plugin_runtime_matrix` | Mandatory live runtime release gate for plugin projects |
| `release.require_pre_release_quality_gate` | Mandatory 4-stage pre-release quality gate |
| `semantic_compression` | TF-IDF context compression settings for large files |

Downstream projects normally use the generic release profile. This repository
requires plugin-runtime live matrices and the 4-stage pre-release gate because
Silver Bullet itself is a Claude/Codex plugin.

## Documentation Governance

Silver Bullet treats documentation as a delivery artifact, not an afterthought.

`/silver:init` scaffolds a doc scheme from
[templates/doc-scheme.md.base](templates/doc-scheme.md.base). The hooks then
check that required docs are present and current when delivery commands run. The
release flow expects README, changelog, architecture/testing/release docs, and
workflow docs to match the current product surface.

Useful docs:

- [docs/PRD-Overview.md](docs/PRD-Overview.md) - product overview
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) - system architecture
- [docs/ENFORCEMENT.md](docs/ENFORCEMENT.md) - enforcement details
- [docs/SDLC-MAP.md](docs/SDLC-MAP.md) - SDLC coverage matrix
- [docs/composable-flows-contracts.md](docs/composable-flows-contracts.md) -
  canonical flow contracts
- [docs/sb-benefits-over-plain-gsd.md](docs/sb-benefits-over-plain-gsd.md) -
  detailed SB-over-GSD analysis

## Testing

Run the normal suite:

```bash
bash scripts/verify-tests.sh
```

That runs hook unit tests, script unit tests, integration scenarios, E2E harness
sanity checks, and coverage matrix checks. Current release baseline:

```text
2,025 passed, 0 failed
```

Run live runtime tests when validating plugin/runtime behavior:

```bash
bash tests/live/run-live-tests.sh
bash tests/e2e-live/run-e2e-live-tests.sh
```

Limit live tests to one runtime:

```bash
SB_LIVE_RUNTIMES=codex bash tests/live/run-live-tests.sh
SB_E2E_LIVE_RUNTIMES=codex bash tests/e2e-live/run-e2e-live-tests.sh
```

Codex-compatible live tests use Kay `v0.9.6` and the `opencode-go` provider
path when configured.
SB tests should not be run against the upstream `codex` binary directly.
The harness isolates config roots so live tests do not mutate the user's normal
Codex hook cache.

## CI/CD And Release Gates

For downstream deploy pipelines, use:

```bash
bash scripts/deploy-gate-snippet.sh
```

The snippet checks the workflow state file and blocks deploys if required
delivery skills are missing.

Release behavior:

- `git commit` is warning-only for red CI, so CI fixes can be committed.
- `git push`, `gh pr create`, and `gh release create` are blocked when CI is red.
- `gh release create` can require plugin live matrices and the pre-release
  quality-gate markers when the project release profile opts in.
- The SB plugin repo requires the shared live matrix, todo-app live E2E marker,
  inline full-surface marker, 4-stage pre-release gate, and a fresh full-suite
  rerun before release.

## Repository Layout

```text
commands/                         Codex/Claude command surfaces
skills/                           Source SB skills
hooks/                            Runtime enforcement hooks
scripts/                          Installers, workflow helpers, verification tools
templates/                        Project config, instruction, workflow, and docs templates
docs/                             Product, architecture, enforcement, testing, release docs
site/                             Public website and Help Center
plugins/silver-bullet/            Codex package surface, mostly symlinks to source
forge/                            Forge runtime port
tests/                            Unit, integration, live, and E2E harnesses
.claude-plugin/                   Claude plugin marketplace metadata
.planning/                        GSD project lifecycle artifacts for this repo
```

The Codex package mostly symlinks source-owned assets into `plugins/silver-bullet/`, but materializes the picker-facing `skills/` tree as real files.
Project-instance artifacts such as `.planning/`, `.claude/`, `.forge/`, and
runtime state are not treated as plugin package content.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `jq not found` | Install `jq` with Homebrew or apt |
| `/silver` not available in Claude Code | Install the plugin and restart/reload the Claude Code session |
| `/silver` not available in Codex | Run `./scripts/install-codex.sh --purge-legacy-skills` from this repo checkout |
| GSD skills missing | Repair or reinstall GSD with `npx get-shit-done-cc@latest` |
| Superpowers helper missing | Repair or reinstall `obra/superpowers`; SB uses it only at selected helper boundaries |
| Engineering helper missing | Repair or reinstall `anthropics/knowledge-work-plugins/tree/main/engineering` |
| Design helper missing | Repair or reinstall `anthropics/knowledge-work-plugins/tree/main/design` |
| Product Management helper missing | Repair or reinstall `anthropics/knowledge-work-plugins/tree/main/product-management` |
| Hooks not firing | Confirm `.silver-bullet.json` and `silver-bullet.md` both exist in the project root |
| Too many files trigger enforcement | Adjust `project.src_pattern` and `project.src_exclude_pattern` |
| YAML/JSON edits are unexpectedly gated | In `devops-cycle`, YAML/JSON/TOML are infrastructure code and intentionally gated |
| CI is red and you need to push a fix | Commit normally; for push use the explicit CI override marker only when fixing CI: `touch ${SB_RUNTIME_HOME_ROOT}/.silver-bullet/ci-red-override` |
| Want to refresh templates | Re-run `/silver:init`; it detects existing config and preserves project-owned content |
| Want to start fresh | Remove `.silver-bullet.json` and `silver-bullet.md`, then rerun `/silver:init` |

## Current Release

- Version: `0.37.5`
- Release: [v0.37.5](https://github.com/alo-exp/silver-bullet/releases/tag/v0.37.5)
- Notable changes:
  - The Codex marketplace release sync now publishes the full materialized SB package, not only the manifest version.
  - The release regression test covers stale symlinked `plugins/silver-bullet/skills` trees so future Codex cache installs keep the picker-facing SB skills.
  - The active Codex install repair path verifies the SB cache alias points at a package with all SB `SKILL.md` files.

## License

MIT - [Alo Labs](https://alolabs.dev)
