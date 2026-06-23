# Silver Bullet

[![version](https://img.shields.io/badge/version-v0.47.1-blue)](https://github.com/alo-exp/silver-bullet/releases/tag/v0.47.1)
[![license](https://img.shields.io/badge/license-MIT-green)](LICENSE)

**Agentic Process Orchestrator for AI-native Software Engineering and DevOps.**

Silver Bullet is the lifecycle orchestration and enforcement layer for AI-native
software engineering. It owns the core project flow: intent routing, context,
planning, execution, verification, review, security, documentation, shipping,
and release discipline. Hook-backed gates keep agents from skipping required
steps before code, PRs, deploys, or releases.

Plain version: describe what you want to do. Start with `/silver`. Silver Bullet
classifies the task, composes the right SB-owned workflow, and records the
evidence needed to continue safely.

> "There is no single development, in either technology or management technique,
> which by itself promises even one order-of-magnitude improvement..." -
> Fred Brooks, 1986

Brooks was right. Silver Bullet is not one magic technique. It is the coordinated
process layer that makes AI-native delivery less dependent on agent memory and
operator vigilance.

## What Silver Bullet Adds

Silver Bullet now owns the knowledge-work and lifecycle behaviors it explicitly
depends on as SB-owned skills. Optional plugins remain
useful when they extend SB into DevOps, provider, data, documentation, or
tool-specific domains, but they are no longer required for the core software
engineering lifecycle.

| Area | Silver Bullet owns |
|------|--------------------|
| Entry point | `/silver` routes freeform work into a task-shaped workflow |
| Workflow shape | Dynamic composition from 18 atomic flows |
| Process discipline | Hook-enforced, state-tracked lifecycle evidence |
| Quality | Product, security, DevOps, docs, UAT, CI, and release gates |
| Delivery safety | Mechanical blocks on unsafe edits, PRs, deploys, and releases |
| Continuity | Session logs, handoff, issue capture, knowledge capture, anti-stall checks, and forensics |

## Current Positioning

Silver Bullet is an **Agentic Process Orchestrator (APO)**:

- **Agentic**: built for AI coding agents that can forget, shortcut, overfit, or
  over-trust their own prior context.
- **Process**: turns SDLC discipline into explicit flows, artifacts, and gates.
- **Orchestrator**: chooses and sequences the right tools for the task instead of
  forcing every task through one rigid workflow.

Silver Bullet can still call optional extension plugins when a selected workflow
needs a domain-specific capability, especially DevOps/provider tools. It does not
use lifecycle-overlap knowledge-work plugins as default lifecycle dependencies.

## How It Works

You normally start with:

```text
/silver improve the account settings page and ship it safely
```

The router classifies the request, displays the selected route, and invokes the
appropriate SB-owned workflow. Examples:

| Intent | Typical route | Why |
|--------|---------------|-----|
| Build or enhance a feature | `silver:feature` | Runs SB context, planning, execution, review, verification, and ship |
| Fix a regression | `silver:bugfix` | Inserts debug/TDD before the normal lifecycle |
| Work on UI | `silver:ui` | Adds SB design contract and UI quality review around execution |
| Change infrastructure | `silver:devops` | Adds blast radius, IaC gates, promotion, and rollback discipline |
| Research a decision | `silver:research` | Produces a decision artifact before implementation |
| Prepare a release | `silver:release` | Runs documentation, UAT, milestone, release, and publication gates |
| Make a small safe edit | `silver:fast` | Routes low-risk work through a lighter path |
| Explicit legacy lifecycle request | SB equivalent by default | Legacy lifecycle names are compatibility routes unless the user explicitly asks for an external plugin |

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
Missing: silver-quality-gates, silver-context, silver-plan
Run the missing planning steps before editing source code.
```

```text
COMPLETION BLOCKED - Workflow incomplete.
Final delivery requires review, security, validation, test freshness,
release readiness, and ship markers before PR/deploy/release commands proceed.
```

```text
Silver Bullet: 8 steps | PLANNING 3/3 | REVIEW 1/3 | FINALIZATION 0/4
Next: silver-review-request
```

### Two-Tier Delivery Discipline

Silver Bullet deliberately does not block every useful intermediate commit.

- **Planning floor**: source edits and intermediate development commits require
  the selected SB pre-execution chain.
- **Final delivery floor**: PR creation, deploy commands, release commands, and
  completion claims require the broader review/security/validation/test/release
  chain.

This keeps incremental work viable while still blocking premature final
delivery.

### Enforcement Layers

| Layer | Hook or surface | Purpose |
|-------|-----------------|---------|
| 1 | `record-skill.sh` | Records completed SB and optional helper skill invocations |
| 2 | `record-requested-skill.sh` | Records requested `/silver` routes before work starts |
| 3 | `prompt-reminder.sh` | Re-injects missing steps and core rules before each user prompt |
| 4 | `dev-cycle-check.sh` | Blocks source edits before the required planning floor |
| 5 | `workflow-chain-guard.sh` | Blocks active composed workflows when downstream lifecycle markers are missing |
| 6 | `dependency-skill-check.sh` | Fails closed when required SB or optional extension skills are unavailable |
| 7 | `planning-file-guard.sh` | Blocks direct edits to SB-owned planning artifacts |
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
| Codex | Supported package runtime | Uses an SB-only Codex package and native `/Silver:` skill mirror |
| Kay | Tested agent for isolated live testing | Used for isolated live testing via MiniMax.io with `MiniMax-M3` |

Silver Bullet's Codex package intentionally contains only SB-owned surfaces:
skills, hooks, templates, commands, and helper scripts. Optional extension
plugins are installed separately only when the user explicitly needs their
domain-specific capabilities.

## Install

Install `jq` first:

```bash
brew install jq
# or
sudo apt install jq
```

### Claude Code

Install Graphify and Silver Bullet:

```text
/shell uv tool install graphifyy
/plugin install alo-exp/silver-bullet
```

Then open a project and run:

```text
/silver:init
```

### Codex

For normal use, install or refresh Silver Bullet from the public Codex
marketplace. The published package exposes SB through the native `/Silver:`
picker namespace, keeps internal `skill-source/` files hidden from duplicate
plugin listings, and wires hooks through the package manifest.

For local development from this repository checkout, use the same installer with
legacy cleanup enabled:

```bash
./scripts/install-codex.sh --purge-legacy-skills
```

The installer:

- syncs the curated SB-only Codex bundle in `plugins/silver-bullet/`
- registers the shared `alo-labs/codex-plugins` marketplace
- keeps `/silver` and `/silver:*` in the main Silver Bullet package
- includes the packaged `scripts/workflows.sh` helper used by composed workflow
  tracking
- includes the `scripts/silver-bullet invoke-skill <name>` Codex adapter so
  required skills can be invoked and recorded without a Claude-only `Skill` tool
- enables SB only when the current working directory is an actual SB project
  root (`.silver-bullet.json` plus `silver-bullet.md`)
- does not install or enable lifecycle-overlap plugins for core SB workflows
- purges stale SB user-level hook entries so unrelated Codex projects do not get
  Silver Bullet hooks
- seeds Codex hook trust from the installed plugin manifest instead of
  duplicating SB hooks into the user's global hook cache

For isolated Codex-compatible live testing, Kay `v0.9.6` plus MiniMax.io
with `MiniMax-M3` is the tested route. The live harness creates a
temporary `KAY_HOME` root so tests do not rewrite the user's real Kay or Codex
hook cache.

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
- scaffold the documentation scheme and durable knowledge/learnings folders
- initialize or connect SB planning artifacts
- set up enforcement state paths under `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/`

After that, use `/silver` for normal work.

## Built-In Skills And Routes

Silver Bullet ships **85 canonical skills** under `skills/`. The plugin exposes **36 command stubs** in `plugins/silver-bullet/commands/` for top marketplace routes (`/silver`, `/silver:feature`, `/silver:bugfix`, etc.). The remaining **~49 skills are Skill-tool-only** — invoke them through the host skill picker or, on Codex, `silver-bullet invoke-skill <name>`. Regenerate stubs after composer changes: `bash scripts/generate-plugin-commands.sh`.

| Route or skill | Purpose |
|----------------|---------|
| `/silver` | Main natural-language router and APO entry point |
| `/silver:init` | Project setup, SB lifecycle checks, config, workflow docs, doc scheme |
| `/silver:feature` | Feature workflow through SB-owned lifecycle |
| `/silver:bugfix` | Debug/TDD-oriented bugfix workflow |
| `/silver:ui` | UI workflow with design contract and UI quality gates |
| `/silver:devops` | Infrastructure workflow with blast radius and IaC gates |
| `/silver:deploy` | Deployment workflow with platform detection, health checks, rollback evidence, and runtime handoff |
| `/silver:canary` | Post-deploy runtime watch for HTTP/browser/log/metric evidence |
| `/silver:research` | Research and decision workflow |
| `/silver:spec` | Spec and requirements elicitation |
| `/silver:ingest` | External artifact ingestion with manifest review |
| `/silver:validate` | Gap analysis and validation before implementation or release |
| `/silver:release` | Release preparation workflow |
| `/silver:create-release` | Final release artifact creation after SB release readiness |
| `/silver:fast` | Small, low-risk work through a routed fast path |
| `/silver:test` | Test writing, E2E discovery, test repair, test audit, test performance, and mutation challenge workflow |
| `/silver:refactor` | Behavior-preserving refactor workflow with baseline proof |
| `/silver:worktree` | Isolated git worktree create/finish workflow |
| `/silver:content` | Public content, docs, migration, SEO/AI-search, optimization, and article workflow |
| `/silver:benchmark` | Repeatable benchmark workflow for agents, models, providers, prompts, or approaches |
| `/silver:ensure-docs` | Documentation scheme bootstrap, reconciliation, and recovery |
| `/silver:scan` | Retrospective session scan for deferred issues and insights |
| `/silver:add` | File an issue or backlog item |
| `/silver:remove` | Remove or close an issue/backlog item |
| `/silver:rem` | Capture knowledge or learnings |
| `/silver:handoff` | Create a project-level handoff prompt |
| `/silver:forensics` | Reconstruct failed, stalled, or abandoned sessions |
| `/silver:incident` | Incident response, postmortem, recovery verification, and corrective-action tracking |
| `/silver:retro` | Engineering retrospective over releases, incidents, dates, or workflow history |
| `/silver:quality-gates` | Product/software quality assessment |
| `/silver:domain-audit` | Specialized domain quality contracts for code, tests, API, data, dependencies, performance, structure, CI, environment, accessibility, content/search, UI, architecture, runtime, incident, retro, and benchmark evidence |
| `/silver-blast-radius` | DevOps change-impact and rollback assessment |
| `/devops-quality-gates` | IaC quality assessment |
| `/devops-skill-router` | Selects optional DevOps plugin skills for the current toolchain |
| `/verify-tests` | Runs configured verification commands or stack defaults and writes a freshness marker |

Workflow contracts use logical names such as `silver:feature`. In Codex, SB
mirrors its packaged `skill-source/` files into the native `~/.codex/skills`
surface so the picker shows a single `/Silver:` namespace instead of plugin
prefixed duplicates.

In Codex, use `silver-bullet invoke-skill <name>` when SB requires a recorded
skill invocation and the runtime has no callable `Skill` tool. Directly reading
`SKILL.md` is loaded-only metadata and does not satisfy workflow gates.

## Configuration

Project config lives in `.silver-bullet.json`. The default source of truth is
[templates/silver-bullet.config.json.default](templates/silver-bullet.config.json.default).

Minimal shape:

```json
{
  "config_version": "0.41.0",
  "version": "0.41.0",
  "project": {
    "name": "my-app",
    "src_pattern": "/src/",
    "src_exclude_pattern": "__tests__|\\.test\\.",
    "active_workflow": "full-dev-cycle"
  },
  "skills": {
    "required_planning": [
      "silver-quality-gates",
      "silver-context",
      "silver-plan"
    ],
    "required_deploy": [
      "silver-quality-gates",
      "silver-context",
      "silver-plan",
      "silver-execute",
      "silver-verify",
      "silver-ship",
      "silver-review",
      "silver-secure",
      "silver-validate",
      "silver-review-request",
      "silver-review-triage",
      "silver-branch-finish",
      "silver-create-release",
      "silver-completion-audit",
      "tdd",
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
- [docs/internal/sb-benefits-over-plain-gsd.md](docs/internal/sb-benefits-over-plain-gsd.md) -
  legacy comparison retained for migration context

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

Codex-compatible live tests use Kay `v0.9.6` with the MiniMax.io provider and
`MiniMax-M3` when configured.
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
tests/                            Unit, integration, live, and E2E harnesses
.claude-plugin/                   Claude plugin marketplace metadata
.planning/                        SB project lifecycle artifacts for this repo
```

The Codex package mostly symlinks source-owned assets into `plugins/silver-bullet/`, stores internal generated skill files under `skill-source/`, and mirrors those files into native `~/.codex/skills` during install so the picker exposes only the `/Silver:` namespace.
Project-instance artifacts such as `.planning/` and `.claude/`, and
runtime state are not treated as plugin package content.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `jq not found` | Install `jq` with Homebrew or apt |
| `/silver` not available in Claude Code | Install the plugin and restart/reload the Claude Code session |
| `/Silver:` entries not available in Codex | Refresh the public Codex marketplace install, or run `./scripts/install-codex.sh --purge-legacy-skills` from a repo checkout when developing SB itself |
| Graphify missing | Install with `uv tool install graphifyy` or `pip install graphifyy`; SB falls back to direct docs reads only as a degraded path |
| Legacy lifecycle plugin missing | No action needed for core SB workflows; use SB-owned `silver:*` skills |
| Hooks not firing | Confirm `.silver-bullet.json` and `silver-bullet.md` both exist in the project root |
| Too many files trigger enforcement | Adjust `project.src_pattern` and `project.src_exclude_pattern` |
| YAML/JSON edits are unexpectedly gated | In `devops-cycle`, YAML/JSON/TOML are infrastructure code and intentionally gated |
| CI is red and you need to push a fix | Commit normally; for push use the explicit CI override marker only when fixing CI: `touch ${SB_RUNTIME_HOME_ROOT}/.silver-bullet/ci-red-override` |
| Want to refresh templates | Re-run `/silver:init`; it detects existing config and preserves project-owned content |
| Want to start fresh | Remove `.silver-bullet.json` and `silver-bullet.md`, then rerun `/silver:init` |

## Current Release

- Version: `0.43.2`
- Release: [v0.43.2](https://github.com/alo-exp/silver-bullet/releases/tag/v0.43.2)
- Notable changes:
  - Template `config_version` aligned to `0.41.0` for orchestrator-parent-mode schema.
  - Cursor `cursor-hooks.json` regenerated for `flow-advance` and `industry-tooling-hint` hook parity.

## License

MIT - [Alo Labs](https://alolabs.dev)
