# Silver Bullet review fixes: shared brief for fix authors (read all of it first)

An exhaustive adversarial review of Silver Bullet produced findings, one JSON file per area, in
`/tmp/claude-0/-home-user-silver-bullet/a8e36ab4-d9e2-56b2-b366-31e100f031d9/scratchpad/review/R<n>.json`.
Each finding has an id (`R<n>-NN`), severity, locations, a failure scenario, evidence (usually a
reproducing probe), a proposed fix and a test idea. Your task message names your **package**: the
finding ids you own, the files you own, and your branch. You fix those findings properly, with tests.

Read `CLAUDE.md` in the repository first. Its rules apply to you: the graphify-first rule, the
generated-mirror rules, template parity, the ERR-trap convention and the test patterns.

## Setup

- You work in your own git worktree, on the package branch your task names. Create it from the
  current head of `claude/optimistic-ramanujan-tccfud` unless your task gives another base. Commit
  only to that branch.
  - Never push.
  - Never switch, reset or rewrite any other branch.
  - Never touch the main checkout at `/home/user/silver-bullet` (other agents share it).
- Graphify first: `graphify-out/graph.json` exists, and a project hook requires you to run
  `graphify query "<question>"` (or `explain` / `path`) to orient yourself before you grep or read raw
  files.
- Export `PYTHONDONTWRITEBYTECODE=1`. Never switch branches silently, and don't use Fast mode.
- Resources are shared, with 4 CPUs among several agents.
  - Run only the test files that matter, at most two at a time. Always run them through
    `bash tests/run-all-tests.sh <file> [<file>...]`, which gives a sandboxed HOME and TMPDIR.
  - Never run the full suite or a full coverage run; the orchestrator does that.
  - Scoped coverage runs (`--only`) are fine; run one at a time.
  - Never run `tests/scripts/test-run-sb-live-tests-*.sh` or live/e2e suites, or launch real AI CLIs.
  - No network and no package installs.
- Process safety: kill only processes you started, by exact PID. Never kill by name or pattern.
  Always write `kill -TERM -- -<pgid>` for process groups. Do not touch `/sess-1.json` or `/sb-*.json`.

## How to fix

1. **Verify before you change anything.** For every finding, reproduce it first, ideally as an
   automated test that fails (red). If it does not reproduce, or the behaviour is a documented,
   intended design that the finding misreads, do not change code. Record it as `rejected` with the
   evidence. Likewise, if a fix needs a product decision the brief can't settle (for example deleting
   a user's data, or changing how releases are distributed), record it as `needs-user` with a crisp
   question and your recommendation.
2. **TDD.** Write the failing test first and capture its output. Then make the minimal correct fix
   and show the test passing (green). Put tests in the existing file for that hook or script
   (`tests/hooks/test-<name>.sh`, `tests/scripts/...`, `tests/python/...`) using
   `tests/lib/testlib.sh` helpers, or in a new, well-named file. Tests must assert behaviour (exit
   code, deny JSON, file contents), not just run the code. Record the red and green evidence in the
   commit messages.
3. **Fix the root cause, once.** If several findings share a cause, fix the cause and add a test for
   each scenario. Prefer robust mechanisms over growing pattern lists:
   - real shell tokenizing in Python that unwraps wrappers and handles newlines, comments and
     quoting, over regexes on the raw string;
   - allowlists over denylists for "read-only" decisions;
   - stdin or a temp file over argv for payloads.
4. **Realistic threat model.** The governed agent has a shell as the same OS user, so Silver Bullet
   cannot be made tamper-proof. Your fixes should:
   - close every concrete bypass in your findings;
   - make forging state or evidence take deliberate, unusual effort that leaves a trace (for
     example a hook-maintained digest that detects writes made outside the hooks);
   - **fail closed** in the core gates (commit/push/PR/merge/deploy/release, the planning floor,
     protected files) when input is unparseable, oversized or inconsistent, with a clear message
     saying how to proceed;
   - **never block legitimate everyday work.** A false positive is a bug. Every new block needs a
     test that the normal, honest variant still passes.
   Do not build security theatre: no secret the agent can trivially read used as if it were
   unforgeable, and no hidden state presented as a guarantee.
5. **Never execute repository-controlled code from a hook** unless it is the documented, intended
   behaviour. Resolve Silver Bullet's own scripts from the plugin root, never from the user's project.
6. **User machines.** Writes to user config must be atomic (temp file in the same directory, then
   rename), keep the file's mode, back it up before a destructive change, be idempotent, and never
   remove entries Silver Bullet did not create. No `sudo` or package-manager runs without explicit
   consent. No `rm -rf` on a path that could be empty.
7. **Portability.** Hooks must run on macOS Bash 3.2 and BSD userland. In `hooks/` that means no
   associative arrays, `mapfile`, `${var,,}` and the like, and no GNU-only flags without a fallback.

## Repository invariants you must keep

- **Coverage.** CI enforces 100% coverage: `tests/coverage/run-coverage.sh --fail-under 100`
  covers Bash statements, lines and functions, Python statements and branches, and JS
  lines/functions/branches. Every line you add must be executed by a test.
  - Deleting dead code is welcome.
  - Prove it with a scoped run over the files you changed and the tests that cover them:
    `bash tests/coverage/run-coverage.sh --cov-dir <your scratch dir> --jobs 2 --show-missing
    --only <file> [--only <file>...] <test files...>`. It must show 100% for every changed file.
- **Known limits.** `tests/coverage/known-limits.json` holds line-specific audited exclusions:
  - `.planning/scripts/phase-lock.sh` lines 478 and 490;
  - `hooks/lib/orchestrator-scheduler.sh` line 797;
  - `scripts/enterprise-e2e/lib/core.sh` line 26.

  If you edit one of those files so that the line moves, update the entry and show a scoped coverage
  run exiting 0. Exit 3 means a stale or mismatched limit.
- `.planning/` is managed by Silver Bullet: do not edit it.
- Don't hand-edit generated files. Regenerate them:
  - after `skills/` changes, `bash scripts/sync-codex-package.sh` (commit the regenerated mirrors);
  - after `hooks/hooks.json` changes, `python3 scripts/generate-cursor-hooks.py` and
    `python3 scripts/generate-hook-reference.py`;
  - check with `python3 scripts/generate-hook-reference.py --check`,
    `python3 scripts/generate-apo-artifacts.py --check` and `bash scripts/validate-plugin-mirror.sh`.
- **Template parity.** Changes to enforcement behaviour must be reflected in both `silver-bullet.md`
  and `templates/silver-bullet.md.base` (`tests/scripts/test-silver-bullet-template-parity.sh`).
  `docs/workflows/` must stay byte-identical to `templates/workflows/`.
- **Before your final commit**, run and pass:
  - `bash scripts/lint-shell.sh --all --jobs 2`
  - `bash scripts/check-repo-invariants.sh`
  - the docs suite (`bash tests/run-all-tests.sh --suite docs`) if you touched docs
  - every test file that covers code you changed, under both `SILVER_BULLET_RUNTIME=claude` and `codex`
- **Docs.** When behaviour changes, update the docs that describe it (`docs/HOOKS.md` is generated;
  others are hand-written). Keep `docs/` files under 500 lines.

## File ownership

Your task lists the files you own. Other packages are editing other files in parallel. Change files
outside your list only when a fix truly needs it, keep those changes minimal, and list each one in
your report so the orchestrator can resolve merge conflicts. If a fix belongs in another package's
file, say so in the report rather than doing it. Before you finish, merge the latest
`claude/optimistic-ramanujan-tccfud` into your branch (a merge, not a rebase) and re-run your tests.

## Commits

Commit messages are imperative, scoped, and record the red and green evidence. Every commit message
ends with exactly these two lines:

```
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>   (fix authors on Sonnet may use "Claude Sonnet 5.5" — accurate attribution is accepted)
Claude-Session: https://claude.ai/code/session_013z3F7YTZ5T5DAJxAcCmeVV
```

## Report

Write `/tmp/claude-0/-home-user-silver-bullet/a8e36ab4-d9e2-56b2-b366-31e100f031d9/scratchpad/review/fix-<package>.json`:

```json
{
  "package": "<name>", "branch": "<branch>", "head": "<sha>", "worktree": "<path>",
  "dispositions": [
    {"id": "R1-01", "status": "fixed|rejected|needs-user|partial",
     "commits": ["<sha>"], "tests": ["<test file>: <assertion names>"],
     "evidence": "red output -> green output, or why rejected",
     "notes": "residual risk, follow-ups"}
  ],
  "files_changed_outside_ownership": ["path: why"],
  "validation": {"tests": "...", "coverage": "...", "lint": "...", "invariants": "..."},
  "notes": "..."
}
```

Your final message must be at most 400 words: the counts by status, anything rejected or left as
`needs-user` (with the question), files changed outside your ownership, and the validation results.
