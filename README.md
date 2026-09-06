# Silver Bullet

[![version](https://img.shields.io/badge/version-v0.52.0-blue)](https://github.com/alo-exp/silver-bullet/releases/tag/v0.52.0)
[![license](https://img.shields.io/badge/license-BUSL--1.1-blue)](LICENSE)
[![website](https://img.shields.io/badge/site-sb.alolabs.dev-green)](https://sb.alolabs.dev)

**Agentic Process Orchestrator for AI-native Software Engineering and DevOps.**

*The process layer of AI-driven dev.* Silver Bullet runs inside your Claude Code, Codex, or Cursor session. It composes the right workflow for the task, blocks unsafe commits, PRs, and releases until the evidence is real, and stays out of the way for work that should be fast.

> "There is no single development, in either technology or management technique,
> which by itself promises even one order-of-magnitude improvement..." -
> Fred Brooks, 1986

Brooks was right. Silver Bullet is not one magic technique. It is the coordinated process layer that makes AI-native delivery less dependent on agent memory and operator vigilance.

**Source-available · BUSL 1.1 · No telemetry · No vendor lock-in**

Full homepage: [sb.alolabs.dev](https://sb.alolabs.dev)

## Why Silver Bullet

A good prompt is not a delivery system. Agents skip planning, spec and PR drift apart, "done" gets declared without evidence, and infrastructure edits ship without blast-radius review. Silver Bullet is hook-enforced orchestration — not a smarter model, but mechanical gates plus retrieval so the same model ships like your best senior engineer.

| Capability | What you get |
|------------|--------------|
| Engineering best practices | Spec-to-release traceability, not prompt-only discipline |
| Dynamically tailored workflows | `/sb` composes the smallest safe chain per task |
| Verification and validation loops | 85 flow-step V-loops with BLOCK / WARN / INFO evidence |
| Quality gates | Two-tier delivery discipline — fast in the middle, strict at the edges |
| Cost optimization | Enforced process + Graphify, agentmemory, RTK, Context Mode for cheaper models |
| Intent-aligned results | The agent reasons; the environment decides whether unsafe actions proceed |

## The Mechanism

Silver Bullet is an **Agentic Process Orchestrator (APO)**:

- **Agentic** — built for AI coding agents that forget, shortcut, overfit, or over-trust prior context.
- **Process** — turns SDLC discipline into explicit flows, artifacts, and gates.
- **Orchestrator** — chooses and sequences the right tools for the task instead of forcing every task through one rigid workflow.

The catalog authority is [docs/apo-catalog.json](docs/apo-catalog.json):

| Layer | Count | Role |
|-------|-------|------|
| Atomic flows (`AF-*`) | 27 | Composable primitives (ROUTE, SPECIFY, PLAN, EXECUTE, VERIFY, SHIP, …) |
| Workflows (`WF-*`) | 22 | Task-shaped chains (`sb:feature`, `sb:bugfix`, `sb:devops`, …) |
| Flow-step V-loops | 85 | Evidence at every step; resumable across context compaction |

Generated views: [docs/composable-flows-contracts.md](docs/composable-flows-contracts.md), [docs/workflow-composition-matrix.md](docs/workflow-composition-matrix.md).

### Two-Tier Delivery Discipline

- **Planning floor** — source edits and intermediate commits require the selected SB pre-execution chain (default: `sb:quality-gates`, `sb:context`, `sb:plan`).
- **Final delivery floor** — PR creation, deploy, release, and completion claims require review, security, validation, test freshness, and ship markers.

Small edits stay on `sb:fast`. High-risk work gets the full chain.

### Twelve Hook Layers

Hooks observe real tool usage and state transitions — not decorative instructions:

| Layer | Hook or surface | Purpose |
|-------|-----------------|---------|
| 1 | `record-skill.sh` | Records completed SB skill invocations |
| 2 | `record-requested-skill.sh` | Records requested `/sb` routes |
| 3 | `prompt-reminder.sh` | Re-injects missing steps before each prompt |
| 4 | `dev-cycle-check.sh` | Blocks source edits before planning floor |
| 5 | `workflow-chain-guard.sh` | Blocks composed workflows with missing downstream markers |
| 6 | `dependency-skill-check.sh` | Fails closed when required skills are unavailable |
| 7 | `planning-file-guard.sh` | Blocks direct edits to SB-owned planning artifacts |
| 8 | `completion-audit.sh` | Blocks PR/deploy/release when final gates are missing |
| 9 | `ci-status-check.sh` | Blocks push/PR/release while CI is red; commit stays warning-only |
| 10 | `stop-check.sh` | Blocks task-complete declarations when gates are missing |
| 11 | `uat-gate.sh`, `spec-floor-check.sh` | Enforce minimum spec and UAT evidence |
| 12 | `forbidden-skill-check.sh`, guards | Protect against deprecated paths and bypass abuse |

Capability tiers per host are documented in [docs/RUNTIME-COMPATIBILITY.md](docs/RUNTIME-COMPATIBILITY.md). Run `bash scripts/sb-diagnostics.sh` for a local tier report.

## Runtime Support

| Runtime | Status | Install surface |
|---------|--------|-----------------|
| Claude Code | Primary plugin runtime | `/plugin install alo-exp/silver-bullet` or `alo-labs/agent-plugins` marketplace (`alo-labs` catalog) |
| Codex | Supported package runtime | Public `alo-labs/agent-plugins` marketplace (`alo-labs-codex`); native `/sb:` namespace |
| Cursor | Supported plugin runtime | Public `alo-labs/agent-plugins` (`alo-labs-cursor`) or `bash scripts/install-cursor.sh --public-release` |

Hook-backed enforcement requires a runtime that supports the relevant hook events. In less capable runtimes, Silver Bullet still provides workflow guidance, but hard blocks depend on host support.

## Install

Install `jq` first:

```bash
brew install jq
# or
sudo apt install jq
```

Onboarding probe and capability report:

```bash
bash scripts/sb-bootstrap.sh
bash scripts/sb-diagnostics.sh          # claude | codex | cursor
```

### Claude Code

```text
/plugin install alo-exp/silver-bullet
```

Or use the public marketplace: `alo-labs/agent-plugins` (`alo-labs` catalog).

Optional code-intelligence tooling:

```text
/shell uv tool install graphifyy
```

### Codex

For normal use, install or refresh from the public `alo-labs/agent-plugins` marketplace (`alo-labs-codex` catalog). The package exposes native `/sb:` entries and hides internal `skill-source/` duplicates.

For local development from this checkout:

```bash
./scripts/install-codex.sh --purge-legacy-skills
```

On Codex, use `silver-bullet invoke-skill <name>` when SB requires a recorded skill invocation and the runtime has no callable `Skill` tool.

### Cursor

Install from the public `alo-labs/agent-plugins` package (`alo-labs-cursor` catalog), or from a checkout:

```bash
bash scripts/install-cursor.sh --public-release
```

### Initialize Your Project

Run once per project:

```text
/sb:init
```

Then start normal work:

```text
/sb improve the account settings page and ship it safely
/sb:feature API rate limiter
/sb:quality-gates
```

`/sb:init` detects stack and workflow type, scaffolds `.silver-bullet.json`, `silver-bullet.md`, workflow docs, doc scheme, and enforcement state under `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/`.

## Built-In Skills And Routes

Silver Bullet ships **85 canonical skills** under `skills/`. The plugin exposes **36 command stubs** in `plugins/silver-bullet/commands/` for top marketplace routes. Remaining skills are Skill-tool-only — invoke through the host picker or, on Codex, `silver-bullet invoke-skill <name>`.

| Route or skill | Purpose |
|----------------|---------|
| `/sb` | Main natural-language router and APO entry point |
| `/sb:init` | Project setup, config, workflow docs, doc scheme |
| `/sb:feature` | Feature workflow through SB-owned lifecycle |
| `/sb:bugfix` | Debug/TDD-oriented bugfix workflow |
| `/sb:ui` | UI workflow with design contract and UI quality gates |
| `/sb:devops` | Infrastructure workflow with blast radius and IaC gates |
| `/sb:deploy` | Deployment with platform detection, health checks, rollback evidence |
| `/sb:canary` | Post-deploy runtime watch |
| `/sb:deep-research` | Research and decision workflow |
| `/sb:spec` | Spec and requirements elicitation |
| `/sb:release` | Release preparation workflow |
| `/sb:fast` | Small, low-risk work through a routed fast path |
| `/sb:test` | Test writing, E2E discovery, repair, audit, performance |
| `/sb:refactor` | Behavior-preserving refactor with baseline proof |
| `/sb:quality-gates` | Product/software quality assessment |
| `/sb:domain-audit` | Domain quality contract packs |
| `/sb:ship` | Branch/PR readiness and delivery gates |
| `/sb:create-release` | Release artifact creation after readiness |
| `/sb:handoff` | Project-level handoff prompt |
| `/sb:forensics` | Reconstruct failed, stalled, or abandoned sessions |

Full catalog: [docs/apo-catalog.json](docs/apo-catalog.json).

### Optional DevOps Plugins

The `devops-cycle` works without optional DevOps plugins. When installed, SB detects them during `/sb:init`:

```text
/plugin marketplace add hashicorp/agent-skills
/plugin marketplace add awslabs/agent-plugins
/plugin marketplace add pulumi/agent-skills
```

## Enterprise E2E Live Test

Optional live validation against the [`enterprise-grade-test-app`](https://github.com/alo-exp/enterprise-grade-test-app) fixture via interactive Claude TUI. Not run in default CI unless explicitly opted in.

```bash
export SB_ENTERPRISE_E2E_LIVE=1
bash scripts/run-enterprise-e2e-live-test.sh
```

Operator runbook: [docs/ENTERPRISE-E2E-LIVE-TEST.md](docs/ENTERPRISE-E2E-LIVE-TEST.md).

## Configuration

Project config lives in `.silver-bullet.json`. Default source of truth: [templates/silver-bullet.config.json.default](templates/silver-bullet.config.json.default).

Important fields:

| Field | Meaning |
|-------|---------|
| `project.src_pattern` | Regex for files that trigger enforcement |
| `project.active_workflow` | `full-dev-cycle` or `devops-cycle` |
| `skills.required_planning` | Planning floor before implementation |
| `skills.required_deploy` | Final delivery floor for PR/deploy/release |

Downstream projects normally use the generic release profile. This repository requires plugin-runtime live matrices and the 4-stage pre-release gate because Silver Bullet itself is a multi-host plugin.

## Documentation

| Doc | Purpose |
|-----|---------|
| [docs/PRD-Overview.md](docs/PRD-Overview.md) | Product overview |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | System architecture |
| [docs/ENFORCEMENT.md](docs/ENFORCEMENT.md) | Enforcement details |
| [docs/RUNTIME-COMPATIBILITY.md](docs/RUNTIME-COMPATIBILITY.md) | Per-host capability tiers |
| [docs/composable-flows-contracts.md](docs/composable-flows-contracts.md) | Canonical flow contracts |
| [docs/ENTERPRISE-E2E-LIVE-TEST.md](docs/ENTERPRISE-E2E-LIVE-TEST.md) | Enterprise live-test runbook |

## Testing

```bash
bash scripts/verify-tests.sh
```

Live runtime tests:

```bash
bash tests/live/run-live-tests.sh
bash tests/e2e-live/run-e2e-live-tests.sh
```

Limit to one runtime:

```bash
SB_LIVE_RUNTIMES=codex bash tests/live/run-live-tests.sh
```

## Repository Layout

```text
skills/                           Source SB skills
hooks/                            Runtime enforcement hooks
scripts/                          Installers, workflow helpers, verification tools
templates/                        Project config and docs templates
docs/                             Product, architecture, enforcement, testing docs
site/                             Public website (sb.alolabs.dev)
plugins/silver-bullet/            Codex/Cursor package surface (mostly symlinks)
tests/                            Unit, integration, live, and E2E harnesses
.claude-plugin/                   Claude plugin marketplace metadata
```

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `jq not found` | Install `jq` with Homebrew or apt |
| `/sb` not available | Install the plugin and restart the session |
| Hooks not firing | Confirm `.silver-bullet.json` and `silver-bullet.md` exist in project root |
| CI is red and you need to push a fix | Commit normally; for push use `touch ${SB_RUNTIME_HOME_ROOT}/.silver-bullet/ci-red-override` only when fixing CI |
| Want to refresh templates | Re-run `/sb:init` |

Run `bash scripts/sb-diagnostics.sh` for host-specific install and hook wiring checks.

## Current Release

- Version: `0.52.0`
- Release: [v0.52.0](https://github.com/alo-exp/silver-bullet/releases/tag/v0.52.0)
- Changelog: [CHANGELOG.md](CHANGELOG.md) · [site/changelog/](https://sb.alolabs.dev/changelog/)

## License

[Business Source License 1.1 (BUSL 1.1)](LICENSE) — © 2026 [Alo Labs](https://alolabs.dev).
