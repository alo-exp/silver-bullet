# Silver Bullet

[![version](https://img.shields.io/badge/version-v0.53.0-blue)](https://github.com/alo-exp/silver-bullet/releases/tag/v0.53.0)
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
| Verification and validation loops | A local V-loop on every catalog flow step, with BLOCK / WARN / INFO evidence |
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
| Atomic flows (`AF-*`) | 29 | Composable primitives (ROUTE, SPECIFY, PLAN, EXECUTE, VERIFY, SHIP, …) |
| Workflows (`WF-*`) | 26 | 22 public task-shaped chains (`sb:feature`, `sb:bugfix`, `sb:devops`, …) + 4 reusable components (shared gate chains) |
| Flow steps, each with a local V-loop | 118 | Evidence at every step; resumable across context compaction |

The counts are the lengths of `atomic_flows`, `workflows` and `flow_steps` in the catalog; a reusable component is a workflow whose `type` is `reusable_component`. `tests/docs/test-doc-facts.sh` fails when the numbers here drift. Generated views: [docs/composable-flows-contracts.md](docs/composable-flows-contracts.md), [docs/workflow-composition-matrix.md](docs/workflow-composition-matrix.md).

### Two-Tier Delivery Discipline

- **Planning floor** — source edits, `git commit`, `git push` and ending a task require the selected SB pre-execution chain (`skills.required_planning`; default: `sb:quality-gates`, `sb:context`, `sb:plan`).
- **Final delivery floor** — `gh pr create`, `gh pr merge`, deploy commands and `gh release create` require the full `skills.required_deploy` list: review, security, validation, test freshness and ship markers.

Small edits stay on `sb:fast`. High-risk work gets the full chain.

### Twelve Enforcement Layers

Hooks observe real tool usage and state transitions — not decorative instructions. The same twelve layers are described in [docs/ENFORCEMENT.md](docs/ENFORCEMENT.md) and in `silver-bullet.md` §1:

| Layer | Hook or surface | Purpose |
|-------|-----------------|---------|
| 1 | `record-skill.sh` | Records completed SB skill invocations in the state file |
| 2 | `dev-cycle-check.sh`, `workflow-chain-guard.sh` | Block source edits until the planning floor (or the composed workflow's pre-execution chain) is recorded |
| 3 | `compliance-status.sh` | Shows workflow progress after every tool call (informational) |
| 4 | `planning-file-guard.sh` | Blocks direct edits to SB-owned planning artifacts |
| 5 | `completion-audit.sh` | Commits and pushes need the planning floor; PR, deploy and release need the full delivery floor |
| 6 | `ci-status-check.sh` | Blocks push, PR create/merge and release while CI is red; after a commit it only warns |
| 7 | `session-start`, `session-log-init.sh`, `timeout-check.sh` | Branch-scoped state reset, session logs, autonomous-mode timeout warnings |
| 8 | `stop-check.sh` (with `outcomes-check.sh` and other Stop gates) | Blocks task-complete declarations while the planning floor or another session gate is open |
| 9 | `record-requested-skill.sh`, `prompt-reminder.sh` | Record the requested `/sb` route and re-inject missing steps before each prompt |
| 10 | `forbidden-skill-check.sh` | Blocks forbidden or deprecated skills |
| 11 | `roadmap-freshness.sh` | Blocks commits that stage a phase summary without ticking its roadmap entry |
| 12 | `silver-bullet.md`, workflow docs, optional `CLAUDE.md` / `AGENTS.md` | The same rules repeated on every instruction surface |

Further gates sit beside these layers: spec and UAT floors, phase archive and phase locks, orchestrator parent-mode guards, site-session gates, and the opt-in Graphify, agentmemory, RTK, Context Mode, LeanCTX and Alumnium gates. [docs/HOOKS.md](docs/HOOKS.md) lists every registered hook with its event, matcher and timeout.

Capability tiers per host are documented in [docs/RUNTIME-COMPATIBILITY.md](docs/RUNTIME-COMPATIBILITY.md). Run `bash scripts/sb-diagnostics.sh` for a local tier report.

## Runtime Support

| Runtime | Status | Install surface |
|---------|--------|-----------------|
| Claude Code | Primary plugin runtime | `/plugin install alo-exp/silver-bullet` or `alo-labs/agent-plugins` marketplace (`alo-labs` catalog) |
| Codex | Supported package runtime | Public `alo-labs/agent-plugins` marketplace (`alo-labs-codex`); native `/sb:` namespace |
| Cursor | Supported plugin runtime | Public `alo-labs/agent-plugins` (`alo-labs-cursor`) or `bash scripts/install-cursor.sh --public-release` |

Hook-backed enforcement requires a runtime that supports the relevant hook events. In less capable runtimes, Silver Bullet still provides workflow guidance, but hard blocks depend on host support.

## Install

Requirements on the machine that runs your coding agent:

| Tool | Why |
|------|-----|
| A supported host | Claude Code, Codex or Cursor (see Runtime Support) |
| `bash` | Hooks are Bash scripts; they avoid Bash 4-only features, so the macOS system bash works |
| `jq` | Every hook reads JSON with `jq`. Without it most hooks only warn, but the core gates block (see [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)) |
| `git` | Branch-scoped state, commit gates, CI lookups |
| `python3` | Several hooks parse tool payloads with small Python helpers; diagnostics use it too |
| `gh` (optional) | The CI gate and the release gate query GitHub Actions; without `gh` the CI check is skipped and `gh release create` stays blocked |

```bash
brew install jq python gh            # macOS (bash and git ship with the OS / Xcode tools)
sudo apt install jq git python3 gh   # Debian/Ubuntu
```

Onboarding probe and capability report (run from a Silver Bullet checkout or the installed plugin root):

```bash
bash scripts/sb-bootstrap.sh
bash scripts/sb-diagnostics.sh                               # runtime auto-detected
SILVER_BULLET_RUNTIME=codex bash scripts/sb-diagnostics.sh   # or force claude | codex | cursor
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

Silver Bullet ships **98 skills** under `skills/` (one `skills/<name>/SKILL.md` each). The plugin exposes **18 command stubs** in `plugins/silver-bullet/commands/` for the top routes (generated by `scripts/generate-plugin-commands.sh`). The other skills are Skill-tool-only — invoke them through the host picker or, on Codex, `silver-bullet invoke-skill <name>`. `tests/docs/test-doc-facts.sh` keeps both counts in sync with the tree.

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

Project config lives in `.silver-bullet.json`, scaffolded by `/sb:init` from [templates/silver-bullet.config.json.default](templates/silver-bullet.config.json.default). The fields you most often change are `project.src_pattern` (which files count as source), `project.active_workflow` (`full-dev-cycle` or `devops-cycle`), `skills.required_planning` and `skills.required_deploy` (the two enforcement floors), `verify_commands` (what `verify-tests` runs) and the `recommended_tools.*.enabled_by_user` opt-ins.

[docs/CONFIGURATION.md](docs/CONFIGURATION.md) describes every key, which code reads it, and the keys the code reads that the template omits.

## Documentation

Start at [docs/README.md](docs/README.md), the index of the docs tree. The most used pages:

| Doc | Purpose |
|-----|---------|
| [docs/PRD-Overview.md](docs/PRD-Overview.md) | Product overview |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | System architecture |
| [docs/ENFORCEMENT.md](docs/ENFORCEMENT.md) | Enforcement layers and the two-tier model |
| [docs/HOOKS.md](docs/HOOKS.md) | Every registered hook (generated from `hooks/hooks.json`) |
| [docs/CONFIGURATION.md](docs/CONFIGURATION.md) | `.silver-bullet.json` reference |
| [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Common problems and fixes |
| [docs/RUNTIME-COMPATIBILITY.md](docs/RUNTIME-COMPATIBILITY.md) | Per-host capability tiers |
| [docs/composable-flows-contracts.md](docs/composable-flows-contracts.md) | Canonical flow contracts |
| [docs/TESTING.md](docs/TESTING.md) | Test layout, running tests, coverage |
| [docs/RELEASE.md](docs/RELEASE.md) | Release process |
| [docs/CICD.md](docs/CICD.md) | GitHub Actions workflows |
| [docs/ENTERPRISE-E2E-LIVE-TEST.md](docs/ENTERPRISE-E2E-LIVE-TEST.md) | Enterprise live-test runbook |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Development setup and pull requests |

## Testing

```bash
make setup                             # check prerequisites, install requirements-dev.txt
make check                             # lint + full suite (what a pull request must pass)
bash tests/run-all-tests.sh            # every default suite (the local equivalent of CI)
bash tests/run-all-tests.sh --jobs 4   # in parallel
bash tests/run-all-tests.sh --list     # list the test files without running them
bash scripts/verify-tests.sh           # what the verify-tests gate runs, plus its freshness marker
```

Live runtime tests use real host CLIs and model credentials and are not part of the default suite:

```bash
bash tests/live/run-live-tests.sh
bash tests/e2e-live/run-e2e-live-tests.sh
SB_LIVE_RUNTIMES=codex bash tests/live/run-live-tests.sh   # pick the runtime (default: claude)
```

See [docs/TESTING.md](docs/TESTING.md) for suites, isolation, coverage and live tests.

## Repository Layout

```text
skills/                           Source SB skills (one SKILL.md each)
hooks/                            Runtime enforcement hooks (hooks.json, hooks/lib/)
scripts/                          Installers, workflow helpers, generators, validators
templates/                        Files /sb:init stamps into projects
docs/                             Product, architecture, enforcement, testing docs
site/                             Public website (sb.alolabs.dev)
tests/                            Unit, integration, harness, docs, live and E2E suites
agents/, host-bundles/            Generated per-host skill bundles (do not edit)
plugins/silver-bullet/            Codex/Cursor package surface (mostly symlinks)
.claude-plugin/, .cursor-plugin/  Plugin and marketplace manifests
```

[CONTRIBUTING.md](CONTRIBUTING.md#repository-layout) describes every top-level directory.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `jq not found` | Install `jq` with Homebrew or apt |
| `/sb` not available | Install the plugin and restart the session |
| Hooks not firing | Run `/sb:init`: hooks stay inert until both `.silver-bullet.json` and `silver-bullet.md` exist in the project root |
| CI is red and you need to push a fix | Start the commit message with `fix(ci):` or `ci:` (or include `[ci-fix]`), or push changes under `.github/workflows/`, `tests/` or `package.json`; as a last resort `touch ${SB_RUNTIME_HOME_ROOT}/.silver-bullet/ci-red-override` |
| An orchestrator directive blocks and cannot be satisfied | Reply with `SB OVERRIDE: <reason>`; the override is logged to `.planning/orchestrator-override-log.jsonl` |
| Want to refresh templates | Re-run `/sb:init` |

Run `bash scripts/sb-doctor.sh` for an install and activation audit and `bash scripts/sb-diagnostics.sh` for the capability tier. [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) covers more cases, including the hook payload debug dump.

## Current Release

- Version: `0.53.0`
- Release: [v0.53.0](https://github.com/alo-exp/silver-bullet/releases/tag/v0.53.0)
- Changelog: [CHANGELOG.md](CHANGELOG.md) · [site/changelog/](https://sb.alolabs.dev/changelog/)

## License

[Business Source License 1.1 (BUSL 1.1)](LICENSE) — © 2026 [Alo Labs](https://alolabs.dev).
