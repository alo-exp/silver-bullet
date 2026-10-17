# Contributing to Silver Bullet

Thank you for your interest in contributing! Silver Bullet is an agentic process orchestrator for AI coding agents (Claude Code, Codex and Cursor). This guide covers the development setup, the repository layout, how to test and how to send changes. [docs/README.md](docs/README.md) indexes the rest of the documentation.

## Licensing of contributions

Silver Bullet is source-available under the [Business Source License 1.1](LICENSE) (BUSL-1.1), as declared in `LICENSE`, `package.json` and the plugin manifests. Each version converts to the Change License, the Apache License 2.0, on the Change Date stated in `LICENSE` (currently 2030-06-24).

Contributions are accepted on an inbound = outbound basis: by submitting a contribution you agree that it is licensed under the same terms as the project — BUSL-1.1 with the Additional Use Grant, Change Date and Change License in `LICENSE` — and that you have the right to submit it.

## Prerequisites

**To use Silver Bullet** in a project you need a supported host (Claude Code, Codex or Cursor) plus `bash`, `jq`, `git` and `python3`; `gh` is optional (the CI and release gates query GitHub Actions). Hooks avoid Bash 4-only features, so the macOS system bash runs them.

**To develop Silver Bullet** you need more:

| Tool | Used for | Required? |
|------|----------|-----------|
| Bash 4+ | `tests/run-all-tests.sh` uses associative arrays; macOS ships Bash 3.2 | Yes |
| `git`, `jq` | Hooks, scripts and almost every test | Yes |
| Python 3.10+ | Hook payload helpers (`hooks/lib/tool-input/`), generators, validators, skill unit tests, coverage | Yes |
| `rsync` | `scripts/sync-*.sh` and installer tests | Yes |
| `expect` | `tests/tui-contract/` (those tests fail without it) | Yes, for the full suite |
| `shellcheck` | Linting (`make lint`; CI uses the same exclusions) | Yes, before a PR |
| `xxd`, `zip`/`unzip`, GNU `timeout` | Used by a few script tests (`test-silver-doctor.sh`, `test-export-enterprise-evidence.sh`, `test-reconcile-recommended-tools.sh`); macOS ships `xxd` and `zip`, and `timeout` comes from Homebrew `coreutils` | Yes, for the full suite |
| `make` | The `Makefile` entry points (`make setup`, `lint`, `test`, `coverage`, `check`) | Recommended |
| `python3 -m pip install -r requirements-dev.txt` (or `make setup`) | Coverage tooling (`coverage`, `tree-sitter`, `tree-sitter-bash`, pinned in `tests/coverage/requirements.txt`) plus `openpyxl` and `PyYAML` for the deep-research skill tests (some skip without them). Runtime hooks need only the standard library | For coverage and the full skill tests |
| `node` / `npx` | `tests/js/` unit tests and JavaScript coverage (skipped without Node), CI's site HTML lint (`html-validate`), and the opt-in Node tools (Context Mode, agentmemory, Alumnium) | Optional |
| `tmux` | `scripts/agent-claude-autonomous-test.sh --tmux` and the enterprise E2E matrix drivers (operator-only) | Optional |
| `gh` | Release scripts and live suites; `tests/run-all-tests.sh` hides it from tests | Optional |

## Development Setup

macOS (Homebrew):

```bash
brew install bash jq python rsync expect shellcheck coreutils
# git and make come with the Xcode command line tools: xcode-select --install
```

Debian/Ubuntu:

```bash
sudo apt-get update
sudo apt-get install -y bash git jq make python3 python3-pip rsync expect shellcheck xxd zip unzip
# on releases without a separate xxd package, xxd comes with vim-common
```

Then:

```bash
git clone https://github.com/alo-exp/silver-bullet.git
cd silver-bullet
make setup     # checks required tools, then python3 -m pip install -r requirements-dev.txt
make test      # bash tests/run-all-tests.sh --jobs 4: confirm a green baseline
```

On macOS, make sure the Homebrew bash runs the test runner: put `$(brew --prefix)/bin` first on `PATH` (the Makefile runs `bash` from `PATH`), or call it explicitly (`$(brew --prefix)/bin/bash tests/run-all-tests.sh`).

To dogfood enforcement while you work, install the plugin into your host from this checkout (`./scripts/install-codex.sh --purge-legacy-skills`, `bash scripts/install-cursor.sh`, or the Claude Code marketplace) and run `/sb:init` in the repo. `bash scripts/sb-doctor.sh` audits the install.

## Repository Layout

| Path | What it is |
|------|------------|
| `hooks/` | Runtime enforcement: `hooks.json` (registrations), hook scripts, `hooks/lib/` helpers, `cursor-hooks.json` (generated). See [docs/HOOKS.md](docs/HOOKS.md). |
| `scripts/` | Runtime CLI (`scripts/silver-bullet`), installers, sync/generate tools, validators, release and live-test drivers. See [scripts/README.md](scripts/README.md). Installed hooks and skills call these by path through the plugin root, so scripts are not moved or renamed casually. |
| `skills/` | Source skills, one `skills/<name>/SKILL.md` each (some with `scripts/`, `references/` or Python `tests/`). |
| `templates/` | Files `/sb:init` stamps into projects: `silver-bullet.md.base`, `silver-bullet.config.json.default`, workflow docs, doc-scheme files. |
| `docs/` | Live documentation, generated catalog views, internal maintainer docs and preserved history. See [docs/README.md](docs/README.md). |
| `site/` | Public website and help center (`sb.alolabs.dev`), deployed by `.github/workflows/pages.yml`. |
| `tests/` | Test suites. See [docs/TESTING.md](docs/TESTING.md). |
| `research/` | Dated research reports (historical; not live guidance). |
| `design-system/` | Site design tokens and themes (`DESIGN.md`). |
| `agents/`, `host-bundles/` | **Generated** skill bundles: `agents/claude/` for Claude Code, `host-bundles/codex/` and `host-bundles/cursor/` for the other hosts. Rendered from `skills/` by `scripts/sync-codex-package.sh`; never edit by hand. |
| `plugins/silver-bullet/` | Codex/Cursor package surface. `hooks`, `scripts`, `docs` and the root docs are symlinks; `skill-source/`, `templates/` and `cursor-hooks.json` are generated; `commands/` holds the command stubs. |
| `.claude-plugin/`, `.cursor-plugin/`, `.agents/plugins/` | Plugin and marketplace manifests for Claude Code, Cursor and Codex. |
| `.claude/`, `.codex/`, `.cursor/`, `.opencode/`, `.pi/`, `.hermes/`, `.agents/skills/` | Host configuration used when dogfooding Silver Bullet in this repo (project hooks, rules, skills). `skills-lock.json` pins the third-party skills under `.agents/skills/`. |
| `.planning/`, `.agentmemory/`, `.silver-bullet/`, `.silver-bullet.json`, `silver-bullet.md` | This repo's own Silver Bullet project state. `.planning/` is edited only through SB skills; `silver-bullet.md` is the live copy of `templates/silver-bullet.md.base`. |
| `graphify-out/` | Committed Graphify knowledge graph of the repo (refreshed with `graphify update .`). |
| `data/` | Local agentmemory engine config (`iii-config.yaml`). |
| `subagent-model-scores.csv` | Maintainer log of subagent assessments. |
| `SETUP_REPORT.md` | Output of `bash scripts/sb-verify-synergy.sh --write-setup-report` (a point-in-time machine report). |
| `CHANGELOG.md` | Release notes per version. `docs/CHANGELOG.md` is the task log. |
| `Makefile`, `requirements-dev.txt` | Developer entry points (`make setup`, `lint`, `test`, `coverage`, `check`) and the Python packages the test suite and coverage need. |

## Running Tests, Coverage and Lint

```bash
make check                                  # lint + full suite: what a pull request must pass
make lint                                   # bash -n, JSON validity, shellcheck
make test                                   # bash tests/run-all-tests.sh --jobs 4
SUITE=hooks make test                       # one suite
make coverage                               # Bash, Python and JS/TS coverage report

bash tests/run-all-tests.sh tests/hooks/test-ci-status-check.sh   # specific files
bash tests/run-all-tests.sh --list                                # list the test files
```

Every target wraps a script you can also run directly. `make lint` fails on any `shellcheck` finding; at the time of writing the existing hooks and scripts still carry findings (CI's shellcheck step tolerates them), so look at the findings in the files you changed.

[docs/TESTING.md](docs/TESTING.md) explains the suites, the per-test sandbox, test conventions and the live suites. [docs/CICD.md](docs/CICD.md) lists the GitHub Actions workflows.

## Making Changes

### Adding a skill

1. Create `skills/<skill-name>/SKILL.md` with YAML frontmatter: `name`, `description`, and optionally `argument-hint`.
2. Add a scenario fixture `tests/skill-scenarios/<skill-name>.md` (trigger phrase and workflow); `tests/scripts/test-sb-skill-scenario-coverage.sh` fails without it.
3. If enforcement should track the skill, add it to `skills.all_tracked` in `templates/silver-bullet.config.json.default` **and** in `.silver-bullet.json` (CI requires the two to match).
4. If it is a top-level route that needs a command stub, add it to `COMPOSERS` in `scripts/generate-plugin-commands.sh` and run that script.
5. If it owns a workflow or atomic flow, update `docs/apo-catalog.json` and run `python3 scripts/generate-apo-artifacts.py`.
6. Render the host bundles: `bash scripts/sync-codex-package.sh` (updates `agents/claude/`, `host-bundles/`, `plugins/silver-bullet/skill-source/`), then `bash scripts/validate-plugin-mirror.sh`.
7. For a user-facing skill, add a help-center entry and a `site/help/search.js` record.
8. Run `bash tests/run-all-tests.sh`.

### Adding a hook

1. Create `hooks/<name>.sh` and make it executable (`chmod +x`; CI checks every hook). Follow the existing pattern: `set -euo pipefail`, an `ERR` trap that exits 0, source `hooks/lib/runtime-paths.sh` and `hooks/lib/sb-project-gate.sh`, read the JSON payload from stdin with `jq`, and emit host-correct JSON (see `hooks/lib/hook-output.sh`).
2. Register it in `hooks/hooks.json` with `"${CLAUDE_PLUGIN_ROOT}/hooks/<name>.sh"`, a matcher covering both Claude and Codex tool names (for example `Bash|exec_command`, `Edit|Write|MultiEdit|apply_patch`) and a timeout.
3. Regenerate the Cursor manifest: `python3 scripts/generate-cursor-hooks.py` (writes `hooks/cursor-hooks.json` and `plugins/silver-bullet/cursor-hooks.json`).
4. Add a one-line purpose under `purposes` in `docs/hooks-purpose.json` and run `python3 scripts/generate-hook-reference.py` to refresh `docs/HOOKS.md`.
5. Add `tests/hooks/test-<name>.sh`; the coverage matrix fails when a registered hook is not referenced by any test.
6. Run `bash -n`, `shellcheck`, `bash scripts/validate-plugin-mirror.sh` and the test suite.

### Changing templates or instruction text

- Keep `silver-bullet.md` and `templates/silver-bullet.md.base` in sync (`tests/scripts/test-silver-bullet-template-parity.sh`), and `docs/workflows/` byte-identical to `templates/workflows/`.
- After editing `templates/`, run `bash scripts/sync-templates.sh` to refresh `plugins/silver-bullet/templates/`.

### Documentation

- Generated docs say so at the top; change their source and rerun the generator instead of editing them: `docs/HOOKS.md` (`scripts/generate-hook-reference.py`), `docs/composable-flows-contracts.md` and `docs/workflow-composition-matrix.md` (`scripts/generate-apo-artifacts.py`).
- `docs/doc-scheme.json` and `docs/task-doc-checklist.json` govern the live docs inventory. When you add a governed doc, add it to both files. Files in `docs/*.md` stay under 500 lines unless they are generated.
- The docs tests (`bash tests/run-all-tests.sh --suite docs`) check relative links, stated counts, the hook reference and the doc scheme.

### Help pages (`site/`)

- Pages use the shared stylesheets `site/chrome.css` and `site/tokens.css`. Navigation, footer and the help sub-navigation come from the fragments in `site/_chrome/`; `python3 scripts/apply-site-chrome.py` rewrites every page from them (it edits files in place and takes no options). `hooks/site-chrome-guard.sh` blocks inline `<nav>`/`<footer>` markup.
- Add new pages to `site/help/search.js`.
- Preview locally with `bash site/serve.sh start` (serves `http://127.0.0.1:8765`; `stop`, `restart` and `status` also work).
- Run `bash tests/scripts/test-site-structural-consistency.sh`, `bash tests/scripts/test-site-content-freshness.sh` and `bash tests/scripts/test-site-doc-freshness.sh`. Maintainer publishing rules are in [docs/internal/site-publishing.md](docs/internal/site-publishing.md).

## Code Style

- **Shell**: Bash (not POSIX sh). Hooks must keep running on Bash 3.2, so no associative arrays, `mapfile` or `${var,,}` in `hooks/`. Pass `shellcheck` with the CI exclusions, quote expansions, use `jq` for JSON, and never write through symlinks (`hooks/lib/nofollow-guard.sh`).
- **Python**: standard library where possible, `from __future__ import annotations`, runnable as a script.
- **HTML**: semantic markup on the shared stylesheets and chrome fragments; no inline nav or footer.
- **Markdown**: ATX headings, fenced code blocks, relative links that resolve.

## Commit Conventions

Use [Conventional Commits](https://www.conventionalcommits.org/): `feat:`, `fix:`, `docs:`, `test:`, `refactor:`, `chore:`, with an optional scope (`fix(ci):`, `chore(release):`). Keep the subject imperative and under about 72 characters, and explain the why in the body. A commit that fixes red CI should start with `fix(ci):` or `ci:` (or contain `[ci-fix]`) so `hooks/ci-status-check.sh` lets the push through.

## Pull Request Process

1. Create a feature branch from `main`.
2. Make focused commits with conventional messages.
3. Run `make check` (or `bash tests/run-all-tests.sh` plus `shellcheck` on the files you changed); update docs and generated files that your change affects.
4. Open a PR; the template asks for a summary, the testing you did and the docs you updated.
5. CI ([docs/CICD.md](docs/CICD.md)) must be green. PRs are reviewed for consistency with the existing workflow structure and enforcement model.

Releases are cut by maintainers following [docs/RELEASE.md](docs/RELEASE.md).

## Reporting Issues

Use [GitHub Issues](https://github.com/alo-exp/silver-bullet/issues) with the provided templates for bug reports and feature requests. Report security problems privately as described in [SECURITY.md](SECURITY.md).
