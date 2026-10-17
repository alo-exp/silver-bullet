You are writing tests for the "Silver Bullet" repository (an agent-plugin process orchestrator: Bash hooks in hooks/ wired by hooks/hooks.json, Bash/Python scripts in scripts/, Python skill scripts in skills/*/scripts). Your job: bring the files in YOUR PACKAGE (listed at the end) to 100% coverage with tests that verify real behavior. Commit your work in your worktree (conventional commit messages ending with the two lines `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` and `Claude-Session: https://claude.ai/code/session_013z3F7YTZ5T5DAJxAcCmeVV`). Do not push. Never put model identifiers in files.

## Before you start (mandatory)
- You work ONLY inside the package worktree named in YOUR PACKAGE below (an existing git worktree on branch cov/<package-id>, based on the working branch at b0e53b8 (run `git log -1 --format=%H b0e53b8` for the full hash)). `cd` there first and run every command from there — never edit /home/user/silver-bullet itself or another package's worktree. Do not reset or recreate the worktree.
- The container restarts without warning (about hourly) and kills your process; a fresh agent may then be started on the same package. So: first run `git -C <worktree> log --oneline b0e53b8..HEAD` and `git status` — if there are commits or uncommitted files, a previous attempt already did part of the work: review it, keep what is good, and continue from there. Commit after every logical step (each new test file that passes), with a descriptive message, so little work is lost. Prefer foreground commands over long background jobs.

## Repository rules
- graphify-out/graph.json exists: orient with `graphify query "<question>"`, `graphify explain "<node>"`, `graphify path "A" "B"` (CLI at /usr/local/bin/graphify) before grepping/reading raw source files; then read the specific files you test. Never run `graphify update`.
- Do not edit: .planning/, .agentmemory/, graphify-out/, generated mirrors (agents/, host-bundles/, plugins/silver-bullet/skill-source/; plugins/silver-bullet/{hooks,scripts,docs} are symlinks to root dirs), tests/run-all-tests.sh, tests/lib/testlib.sh, tests/coverage/*, tests/hooks/helpers/common.sh, tests/integration/helpers/common.sh, tests/python/sbtest.py. If you need shared helpers, create tests/lib/<your-package>-helpers.sh (or a helper module next to your Python tests).
- Other agents are working in parallel on other files. Touch only your package's source files (and only to fix real bugs) plus new/updated test files for them.

## Coverage tooling (already in the repo — read tests/coverage/sbcov.py docstring and tests/coverage/run-coverage.sh header)
- Measure your package:  `bash tests/coverage/run-coverage.sh --cov-dir /tmp/cov-<pkg> --jobs 4 --show-missing --only '<glob>' [--only '<glob>' ...] <test files...>`
  (runs the given test files through tests/run-all-tests.sh, then reports only files matching --only). Use `--keep` to accumulate across invocations.
- Per-line view of a bash file: `python3 tests/coverage/sbcov.py annotate --cov-dir /tmp/cov-<pkg> <repo-relative file>` — `ok` = line fully run, `!!` = nothing on the line ran, `!` = some statements ran (the list at the bottom names the command words that did not run).
- Bash metrics are statements, lines and functions. A statement is one command: in `cmd || exit 1` the `exit` is its own statement and is covered only by a run that takes the error path; in `x=$(cmd) || x=""` the fallback assignment is covered only when it executes. Commands inside `$(...)` are statements too.
- Python metrics are statements and branches (coverage.py, branch=True). Python run as a subprocess from a bash test is measured automatically; Python unit tests are measured in-process.
- JS/TS (if in your package): tests in tests/js/*.test.mjs (node:test; browser scripts run in a `vm` context with a minimal fake DOM, `new vm.Script(code, {filename: absolutePath})` so coverage maps to the file); lines/functions/branches via LCOV from tests/scripts/test-js-unit.sh.
- The scope (denominator) is tests/coverage/scope.json. Do not edit it.

## Test conventions
- Bash tests: `tests/hooks/test-<hook-name>[-<topic>].sh` for hooks and hooks/lib, `tests/scripts/test-<script-name>[-<topic>].sh` for scripts. Start with:
    #!/usr/bin/env bash
    set -euo pipefail
    source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
    tl_init            # sandboxed HOME/TMP, SB runtime paths recomputed (optional arg: runtime name, default claude)
  Helpers: tl_stub NAME 'bash body' (fake command first on PATH), tl_path_without CMD... (prints a PATH without those commands, e.g. to simulate missing jq), tl_run CMD... / tl_run_stdin INPUT CMD... / tl_run_hook hooks/x.sh "$json" (set TL_OUT TL_ERR TL_STATUS), tl_hook_json EVENT TOOL ARG [extra-json], tl_git_repo DIR, assert_eq/assert_contains/assert_not_contains/assert_match/assert_file_exists/assert_file_absent, and end with `tl_results`. The file must print `Results: N passed, M failed` and exit non-zero on failure (tl_results does both). Make new test files executable.
- Existing tests may already cover part of your files; extend coverage with NEW test files rather than rewriting existing ones. You may add cases to an existing test file of your package if that is clearly the natural home, but never weaken or delete existing assertions.
- Python unit tests: tests/python/test_<module>.py (unittest; `from sbtest import load_module` to import a script by path, e.g. load_module("scripts/review-fix-ladder.py")). Skill Python already has suites in skills/<skill>/tests/test_*.py (run by tests/scripts/test-solution-research-python.sh and tests/scripts/test-multi-ai-deep-research-contract.sh) — add skill tests there, following the existing style. tests/python is run by tests/scripts/test-python-unit.sh.
- Run tests through the runner so they get the CI-like sandbox: `bash tests/run-all-tests.sh --jobs 4 <files...>`. It gives each test file its own HOME and TMPDIR and hides optional host tools (graphify, agentmemory, claude, codex, gh, uv, ...) from PATH, so tests must stub any external CLI they rely on.

## What "meaningful" means (non-negotiable)
- Every test asserts observable behavior: exit codes, stdout/stderr content, hook JSON decisions (e.g. permissionDecision deny / decision block), files written or not written, state file contents. A test that only executes code without asserting on its effect is not acceptable.
- Cover error handling and edge cases deliberately: missing/invalid JSON input, missing tools (tl_path_without jq), failing tools (tl_stub jq 'exit 1'), missing/invalid config, symlink refusals, empty values, boundary conditions, fail-open/fail-closed paths, concurrency/lock paths where present.
- Deterministic and hermetic: no network, no real AI agent CLIs, no reliance on the real HOME, wall-clock or current date (use env overrides the code supports, or stub `date`), no long sleeps (if code sleeps, stub `sleep` via tl_stub or use the code's timeout env vars). Note: the container runs as root, so tests must not rely on file permission bits to cause failures (root ignores them; CI runs as a normal user) — use other fault injection.
- Keep each test file fast (target < 30 s).
- Do NOT manufacture coverage: no weakened assertions, no deleting functionality, no `# coverage:ignore`-style tricks, no editing scope.json, no tests that pass regardless of behavior.
- Source changes: only (a) to fix a real bug a test exposes — keep the fix minimal and list it in your report with the failing scenario, or (b) a minimal, clearly-named test seam (env override) when there is no other way to make a path testable deterministically — prefer stubbing instead. If you find code that is genuinely unreachable/dead, do NOT delete it: report the exact lines and why, and continue.
- If a statement truly cannot be covered in this environment, report it precisely (file:line, statement, why, what would be needed) — do not paper over it.

## Validation before you finish
1. Coverage for every file in your package: 100% statements/lines/functions (bash), statements/branches (Python), lines/functions/branches (JS/TS) — or a precise justification per remaining statement.
2. All test files you added or changed pass via `bash tests/run-all-tests.sh --jobs 4 <files>`, and every pre-existing test file that references your package's files still passes (find them with grep in tests/ and skills/*/tests/ for each basename). Run them twice to check determinism.
3. `bash -n` on new bash tests; `shellcheck -S warning` clean on new bash test files.
4. Commit.

## Final report (concise)
- Per file: coverage before → after (statements/lines/functions or statements/branches).
- New/changed test files.
- Source changes with justification (bugs fixed: scenario, root cause, fix).
- Anything not coverable, with precise reasons.
- Any flaky or slow tests observed.

## Hermeticity reminders
Tests run with a sandboxed HOME, so code that needs a Silver Bullet plugin cache (for example hooks/session-start) needs a fake one staged under $SB_RUNTIME_PLUGIN_CACHE_ROOT in your test. Never depend on network access, `rg` being installed, or root uid. `make lint` runs ShellCheck over first-party Bash and fails on any finding, so keep source edits ShellCheck-clean.

## Working rules that apply to every delegated task
- No silent git branch switches: never run `git checkout <branch>`, `git switch`, `git checkout -b`, `git rebase`, `git reset --hard` or anything else that changes which branch a checkout is on. Restoring files (`git checkout -- <file>`, `git restore`) and `git merge` inside your own worktree are fine.
- No Fast mode: never enable it and never use a `*-fast*` model.
- Graphify first for exploration (see Repository rules).
- TDD: a production (non-test) change needs a test that fails first (red), then passes after the change (green). Record the exact test command and both outcomes in your report. Tests that only characterize existing behavior must pass on the unmodified source. Never invent test evidence.

## Reporting your worktree
At the end, report your worktree's absolute path, your branch and HEAD commit — the reviewer and the parent need them.

## YOUR PACKAGE
