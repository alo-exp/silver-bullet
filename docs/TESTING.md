# Testing

Silver Bullet's code is Bash hooks and scripts, Python helpers and generators, JSON configuration and packaging glue — no application server or database. Almost everything is covered by fast offline tests that pipe JSON into hooks or run scripts against temporary directories. Live suites that drive real host CLIs and models are separate and opt-in.

## Test Layout

| Path | Contents | In the default run? |
|------|----------|---------------------|
| `tests/hooks/` | Hook unit tests, one or more per hook (`test-<hook>.sh`); `tests/hooks/helpers/` holds shared fixtures | Yes — *Hook Unit Tests* |
| `tests/scripts/` | Script unit and contract tests: installers, generators, validators, site checks, release-identity parity, skill scenario coverage, and wrappers for the skills' Python suites | Yes — *Script Unit Tests* |
| `tests/integration/` | Multi-hook scenarios (session lifecycle, enforcement gates, devops cycle, skill tracking) and `coverage-matrix.sh`, which fails when a hook registered in `hooks/hooks.json` is not referenced by any test | Yes — *Integration Scenario Tests* + *Coverage Matrix* |
| `tests/lib/` | `testlib.sh`, the shared helper library, and its self-test | Yes — *Test Harness Tests* |
| `tests/coverage/` | Coverage tooling (`run-coverage.sh`, `sbcov.py`, `bash-env.sh`, `scope.json`) and its calibration self-test | Yes — *Test Harness Tests* |
| `tests/python/` | Python unit tests for repository Python code (`unittest`; `sbtest.load_module` imports hyphenated or package-less scripts by path) | Yes — via `tests/scripts/test-python-unit.sh` |
| `tests/js/` | JavaScript/TypeScript unit tests (`*.test.mjs`, Node's built-in `node:test`); the directory appears with its first test | Yes — via `tests/scripts/test-js-unit.sh`, which reports 0/0 when there are no tests and skips without `node` |
| `tests/docs/` | Documentation checks: doc scheme, relative links, stated counts, hook reference freshness | Yes — *Documentation Tests* |
| `tests/e2e-live/` | Live E2E harness (`run-e2e-live-tests.sh`, `scenarios/`) plus offline sanity tests of the harness itself | Sanity tests only — *E2E Live Harness Tests* |
| `tests/tui-contract/` | `expect`-driven contracts for interactive host prompts (folder trust, bypass and API-key disclaimers, blocking-decision picker); fail without `expect` | Yes — *TUI Contract Tests* |
| `tests/live/` | Live AI matrix (`run-live-tests.sh`): enforcement, skill recording, doc scheme, review-fix ladder, init migration, five-tool stack | No |
| `tests/enterprise-e2e-live/` | Structural checks for the operator-only enterprise E2E matrix | Only with `SB_ENTERPRISE_E2E_LIVE=1` |
| `tests/skill-scenarios/` | One scenario fixture per skill (trigger phrase and workflow), plus capability fixtures | Checked by `tests/scripts/test-sb-skill-scenario-coverage.sh` |
| `tests/fixtures/` | Shared JSON fixtures (model catalogs, quotas, scheduler, recommended tools) | — |
| `skills/*/tests/` | Python `unittest` suites for skills with Python helpers (`silver-deep-research`, `silver-deep-research-multi-ai`, `silver-multi-ai-task`) | Via `tests/scripts/test-solution-research-python.sh` and `tests/scripts/test-multi-ai-deep-research-contract.sh` |

The manual `/sb:init` smoke protocol lives in [testing/MANUAL-E2E-SMOKE-TEST.md](testing/MANUAL-E2E-SMOKE-TEST.md); the other files under `docs/testing/` are runbooks and registries for the release and enterprise suites.

## Running Tests

```bash
bash tests/run-all-tests.sh                  # every default suite
bash tests/run-all-tests.sh --jobs 4         # run test files in parallel (or SB_TEST_JOBS=4)
bash tests/run-all-tests.sh --suite hooks    # suites whose directory matches (repeatable)
bash tests/run-all-tests.sh tests/hooks/test-ci-status-check.sh tests/docs/test-doc-links.sh
bash tests/run-all-tests.sh --list           # print "suite<TAB>file" and exit
bash tests/run-all-tests.sh --help
```

The `Makefile` wraps the same commands:

| Target | Runs |
|--------|------|
| `make setup` | Checks required tools (`bash git jq python3 rsync`; warns about `shellcheck expect tmux node`) and runs `python3 -m pip install -r requirements-dev.txt` |
| `make lint` | `bash -n` over every shell source, `jq empty` over the manifests and config, then `shellcheck --exclude=SC2317,SC1091,SC2329` over hooks and scripts |
| `make test` | `bash tests/run-all-tests.sh --jobs $(JOBS)` (default 4); `SUITE=hooks make test` limits it |
| `make coverage` | `bash tests/coverage/run-coverage.sh --jobs $(JOBS)`; `FAIL_UNDER=100 make coverage` adds a threshold |
| `make check` | `make lint` and `make test` — what a pull request must pass |
| `make sync-check` | `bash scripts/sync-runtime-mirrors.sh --check` and `bash scripts/validate-plugin-mirror.sh` |

Suites run in this order: Hook Unit Tests (`hooks`), Script Unit Tests (`scripts`), Integration Scenario Tests (`integration`), Test Harness Tests (`lib`, `coverage`), Documentation Tests (`docs`), E2E Live Harness Tests (`e2e-live`), TUI Contract Tests (`tui-contract`), then the Coverage Matrix. `--suite` matches directory names, so `--suite docs` runs only `tests/docs/`. The coverage matrix runs only on a full run (no `--suite`, no explicit files). Results print in a stable order even with `--jobs`, followed by the five slowest files and a `TOTAL: N passed, M failed (x/y suites green)` line. The exit status is non-zero when any test fails.

A single test file can also be run directly (`bash tests/hooks/test-uat-gate.sh`), but then it sees your real `HOME` and tools; going through the runner gives it the sandbox below.

### Isolation

The runner is the local equivalent of CI because it isolates each test file:

- **Own `HOME` and `TMPDIR`.** Every test file runs with a fresh temporary `HOME` and `TMPDIR`, so runtime state under `~/.claude`, `~/.codex` or `~/.cursor` never touches your real home. `SB_RUNTIME_*`, `SILVER_BULLET_STATE_FILE`, `SILVER_BULLET_BRANCH_FILE` and `XDG_*` are unset and the runtime paths are recomputed inside the sandbox. `PYTHONUSERBASE` is pinned first so user-installed Python packages still import.
- **Hidden host tools.** Optional tools are removed from `PATH` so results do not depend on what is installed locally. The default hidden set is `graphify agentmemory iii context-mode rtk lean-ctx claude codex cursor-agent agent opencode pi kay gh alumnium search uv uvx pipx brew`. Set `SB_TEST_HOST_TOOLS=1` to keep them visible, or `SB_TEST_HIDE_TOOLS="a b c"` to choose the hidden set.
- **Runtime defaults.** `SILVER_BULLET_RUNTIME` defaults to `claude`, as do `SB_LIVE_AGENT`, `SB_E2E_LIVE_AGENT`, `SB_LIVE_RUNTIMES` and `SB_E2E_LIVE_RUNTIMES`. When neither `LANG` nor `LC_ALL` is set, the runner exports `LANG=C.UTF-8`, as on CI.
- **Closed stdin.** Each file runs with `</dev/null`, so hooks that read stdin cannot hang the run; tests that exercise stdin pipe explicit JSON.
- **Failure accounting.** A test file that exits non-zero counts as a failure even if it never printed a `Results:` line.

Opt-in additions: `SB_ENTERPRISE_E2E_LIVE=1` adds `tests/enterprise-e2e-live/`; `SB_FIVE_TOOL_LIVE=1` adds `tests/live/test-live-five-tool-stack-cursor.sh` (the pre-release gate runs `tests/scripts/test-five-tool-prerelease-cursor.sh` instead).

### The verify-tests gate

`/verify-tests` (`bash scripts/verify-tests.sh`) runs the project's `verify_commands` from `.silver-bullet.json`, or a stack default (`bash tests/run-all-tests.sh` when that file exists, then `npm test --if-present`, `pytest`, `cargo test`, `go test ./...`). On success it writes `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/verify-tests-state`. `dev-cycle-check.sh` deletes that marker whenever a source edit lands, and `completion-audit.sh` blocks final delivery when `verify-tests` was recorded but the marker is missing. Run it after the last source change and before `gh pr create`, deploy or `gh release create`.

## Writing Tests

Conventions every test file follows:

- Name it `test-<subject>.sh` in the suite directory; the runner picks up `test-*.sh` only.
- Print one `PASS: ...` or `FAIL: ...` line per check and finish with `Results: N passed, M failed`; exit non-zero when anything failed. The runner sums the last `N passed` / `M failed` it finds.
- Work in temporary directories and leave the repository tree clean. Point `SILVER_BULLET_STATE_FILE` (and `SILVER_BULLET_BRANCH_FILE` for session tests) at paths under `${SB_RUNTIME_HOME_ROOT}/`; hooks reject state paths outside it.
- Invoke hooks by piping the host JSON payload on stdin, as the host does. A hook only acts inside an SB project, so create `.silver-bullet.json` and `silver-bullet.md` in the test project.
- Stay hermetic: no network, no real `gh` (use overrides such as `GH_STATUS_OVERRIDE` or `GH_RUN_LIST_OVERRIDE`), no dependence on the developer's home directory. Assertions against the live sibling enterprise fixture are opt-in with `SB_TEST_ENTERPRISE_FIXTURE_STATE=1`.
- Generator tests write to temporary output directories; frozen audit manifests are inputs, not fixtures to rewrite.

New tests can use `tests/lib/testlib.sh`:

```bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init                                   # sandbox HOME + temp dir, counters, cleanup trap
tl_git_repo "$TL_TMP/project"             # git repo with one commit on feature/test
tl_stub gh 'echo "[]"'                    # fake command first on PATH
tl_run_hook hooks/ci-status-check.sh "$(tl_hook_json PreToolUse Bash 'git push')"
assert_eq "hook exits 0" 0 "$TL_STATUS"
assert_not_contains "push not denied without CI runs" "$TL_OUT" '"permissionDecision":"deny"'
tl_results                                # prints the Results line; non-zero on failure
```

| Helper | Purpose |
|--------|---------|
| `tl_init [runtime]` | Create the sandbox (`TL_TMP`, `TL_BIN`, `HOME`), recompute runtime paths, install the cleanup trap |
| `tl_run <cmd...>`, `tl_run_stdin <input> <cmd...>` | Run a command, capturing `TL_OUT`, `TL_ERR` and `TL_STATUS` |
| `tl_run_hook <hook> <json>` | Run a hook (path relative to the repo or absolute) with JSON on stdin |
| `tl_hook_json <event> <tool> [command-or-path] [extra-json]` | Build a hook payload |
| `tl_stub <name> <body>` | Install a fake executable first on `PATH` |
| `tl_path_without <cmd...>` | Print a `PATH` under which the named commands are absent |
| `tl_git_repo <dir>` | Initialise a git repo with one commit on `feature/test` |
| `assert_eq`, `assert_contains`, `assert_not_contains`, `assert_match`, `assert_file_exists`, `assert_file_absent` | Assertions; each records a pass or fail |
| `tl_pass`, `tl_fail`, `tl_results` | Manual results and the final summary line |

Older tests carry their own small helpers (for example `tests/hooks/helpers/common.sh` and `tests/integration/helpers/common.sh`); keep their conventions when you extend them.

### Python and JavaScript unit tests

Unit tests for Python code go in `tests/python/test_*.py` (standard `unittest`). Import repository scripts with `sbtest.load_module("scripts/some-script.py")`, which handles hyphenated names and sibling imports. `tests/scripts/test-python-unit.sh` runs the discovery and converts the result into a `Results:` line. Skills with their own Python helpers keep their suites under `skills/<name>/tests/`.

JavaScript and TypeScript tests go in `tests/js/*.test.mjs` and use Node's built-in `node:test`; `tests/scripts/test-js-unit.sh` runs them with the TAP reporter. During coverage runs it also writes LCOV for `site/**/*.js` and `scripts/**/*.{mjs,ts}`.

### Skill scenarios

Every `skills/*/SKILL.md` needs a fixture `tests/skill-scenarios/<skill-name>.md`; `tests/scripts/test-sb-skill-scenario-coverage.sh` computes coverage from the source tree and fails on a missing one. The directory may also hold capability-level fixtures, so its file count is not a skill count.

```markdown
# {Skill Name} Skill Scenario

## Skill: {skill-name}
## Context: One-line context

### Scenario: Brief description

**Trigger:** "trigger phrase"

**Workflow:**
1. Step one
2. Step two
```

## Coverage

```bash
python3 -m pip install -r requirements-dev.txt     # or: make setup (coverage tooling is pinned in tests/coverage/requirements.txt)
bash tests/coverage/run-coverage.sh                # full suite with coverage (or: make coverage)
bash tests/coverage/run-coverage.sh tests/hooks/test-ci-status-check.sh --show-missing
bash tests/coverage/run-coverage.sh --suite hooks --jobs 4 --only 'hooks/*' --fail-under 80
```

`run-coverage.sh` runs `tests/run-all-tests.sh` (all of it, selected suites, or given files) with tracing enabled, then prints a per-file table and totals. Options: `--cov-dir DIR` (default `.coverage-run/`, git-ignored), `--keep` (add to an existing run), `--only GLOB` (limit the report), `--show-missing`, `--fail-under PCT` (fail if any metric is below), `--no-report`, and `--jobs`/`--suite` passed through to the runner. The full results are written to `coverage-summary.json` and `coverage-summary.md` in the coverage directory.

**Metrics.** Bash files report statements, lines and functions; Python files report statements and branches; JavaScript/TypeScript files report lines, functions and branches from Node's LCOV output. `--fail-under` applies to every metric.

**How it works.** `tests/coverage/bash-env.sh` is exported as `BASH_ENV`, so every bash process started during the run turns on xtrace into a per-process trace file. `tests/coverage/sbcov.py` analyses each script with tree-sitter-bash, lists its executable statements with their line spans and command words, and credits a statement only when a trace line falls inside its span with the same command word — so in `check || exit 1` the `exit` counts only when the error path ran. Python is measured with coverage.py, started in every Python subprocess through a generated `sitecustomize.py`. JavaScript coverage comes from the LCOV files `tests/scripts/test-js-unit.sh` writes, merged by `sbcov.py`. `sbcov.py` also offers `analyze`, `collect`, `report` and `annotate` subcommands.

**Scope.** `tests/coverage/scope.json` defines the denominator per language: Bash and Python files under `hooks/`, `scripts/`, `skills/` and `site/` (plus `.planning/scripts/phase-lock.sh`), and JavaScript/TypeScript in `site/*.js`, `scripts/*.mjs` and `scripts/*.ts`, excluding generated mirrors (`plugins/`, `agents/`, `host-bundles/`) and test code. Each exclusion states its reason.

**Limitations.** Code embedded in other languages inside a Bash file — heredoc Python, `jq` filters, `awk` programs — is not measured; neither are Tcl `expect` scripts. Browser JavaScript counts only when a `tests/js` test loads it in Node; files no test loads are listed as unmeasured with approximate line counts. Bash has no explicit branch events, so implicit-else branches (an `if` without `else` that was never false) cannot be measured; use statement coverage of both arms instead. `eval` and trap bodies may show up as unattributed hits.

`tests/coverage/test-sbcov.sh` calibrates the analyzer against `tests/coverage/fixtures/` and runs in the default suite.

## Live and Opt-In Suites

These suites use real host CLIs, credentials and model calls. They are not part of `tests/run-all-tests.sh` or CI's required jobs.

| Suite | Command | Notes |
|-------|---------|-------|
| Live AI matrix | `bash tests/live/run-live-tests.sh` | Runtimes from `SB_LIVE_RUNTIMES` (default `claude`; for example `SB_LIVE_RUNTIMES=codex`). Writes the `release-live-matrix` marker used by the release gate |
| Live E2E | `bash tests/e2e-live/run-e2e-live-tests.sh` | Runtimes from `SB_E2E_LIVE_RUNTIMES` (default `claude`). Uses the sibling `enterprise-grade-test-app` fixture for hook-delivery checks and writes the `e2e-live-matrix` marker. The retired todo-app journey runs only with `SB_E2E_LIVE_INCLUDE_LEGACY_JOURNEY=1` |
| Runtime wrappers | `bash scripts/run-sb-live-tests-claude.sh`, `...-codex.sh`, `...-kay.sh` | Run both suites pinned to one runtime; the Kay wrapper selects the Kay (Codex-compatible) adapter with its own model and provider defaults |
| Release live matrix | `bash scripts/run-release-live-matrix.sh` | Requires a fresh `verify-tests` marker; see [RELEASE.md](RELEASE.md) |
| Enterprise E2E | `SB_ENTERPRISE_E2E_LIVE=1 bash scripts/run-enterprise-e2e-live-test.sh` | Operator-only interactive Claude TUI matrix; [ENTERPRISE-E2E-LIVE-TEST.md](ENTERPRISE-E2E-LIVE-TEST.md) |
| Five-tool stack (Cursor) | `SB_FIVE_TOOL_LIVE=1 SB_FIVE_TOOL_LIVE_EXECUTE=1 SB_FIVE_TOOL_MODE=full bash tests/run-all-tests.sh` | Needs `cursor-agent`; the pre-release gate runs the targeted check |
| RC validation matrix | `bash scripts/run-rc-validation-matrix.sh` | Six cells (cursor, codex, claude × fresh/upgrade) on the operator machine; [testing/RC-VALIDATION-MATRIX.md](testing/RC-VALIDATION-MATRIX.md) |

Model selection belongs to the host; see [RUNTIME-COMPATIBILITY.md](RUNTIME-COMPATIBILITY.md#model-selection-boundary).

## What Not to Test

- The prose inside workflow and skill files (no executable logic) beyond the structural checks that already exist
- Third-party plugin hooks, which enforce their own behaviour
- Placeholder presence in config scaffolding, which CI already checks
