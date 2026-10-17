# Coverage campaign — handoff

Working state of the effort to bring first-party code to 100% measured coverage with meaningful tests. Pull request: alo-exp/silver-bullet#291 (branch `claude/optimistic-ramanujan-tccfud`).

## Goal and measurement

- Tooling: `tests/coverage/run-coverage.sh` (`make coverage`), engine `tests/coverage/sbcov.py`, scope `tests/coverage/scope.json`. See [../../TESTING.md](../../TESTING.md).
- Metrics: Bash statements, lines and functions; Python statements and branches; JS/TS lines, functions and branches.
- Denominator (2026-10-17): Bash 44,168 statements in 353 files; Python 19,483 statements in 108 files; JS/TS 7 files (about 1,400 lines). Generated mirrors and test code are excluded.

## Baseline (2026-10-17, commit 990268442b)

| Language | Measure | Covered |
|---|---|---|
| Bash | statements | 24,193 / 44,168 (54.77%) |
| Bash | lines | 18,609 / 31,485 (59.10%) |
| Bash | functions | 1,470 / 2,097 (70.10%) |
| Python | statements | 13,836 / 19,483 (71.02%) |
| Python | branches | 5,032 / 8,366 (60.15%) |
| JS/TS | lines | 0 / 1,408 (no JS tests yet) |

Regenerate the per-file report with `make coverage` (about 13 minutes with 4 jobs); it writes `.coverage-run/coverage-summary.json`.

## Work packages

[packages.json](packages.json) splits the roughly 30,400 uncovered units (Bash statements + Python statements and branches + JS lines) into 29 packages of related files. Each entry has `id`, `files`, `missing` and the per-file `baseline`.

| Family | Packages |
|---|---|
| Hooks | A-devcycle-completion, B-orchestrator, C-toolgates-1/2, D-gates, E-core-hooks |
| Enterprise E2E scripts | F-enterprise-1..4 |
| Global tool stack | G-toolstack-1/2 |
| Recommended tools / doctor | H-recommended-1/2 |
| Scripts (Python) | I-scripts-py-1..3 |
| Install and sync | J-install-sync-1/2 |
| Agents and live harness | K-agents-live-1/2 |
| Other scripts | L-scripts-misc-1/2 |
| Deep research (multi-AI) | M-dr-multi-ai-1/2 |
| Deep research | N-deep-research-1/2 |
| Other skills | O-skills-other |
| Site and JS | P-site-js |

Package files and baselines were computed at commit 990268442b; later merges (ShellCheck, docs, test isolation) changed some files, so re-run `make coverage` and refresh the numbers before starting a package.

## Process per package

1. Author agent: [coverage-agent-prompt.md](coverage-agent-prompt.md) — writes tests in its own worktree on branch `cov/<package-id>`, commits after every step, reports per-file coverage.
2. Adversarial reviewer: [review-agent-prompt.md](review-agent-prompt.md) — re-measures coverage independently and audits assertion quality, hermeticity and determinism.
3. Repair until the reviewer passes, then merge the package branch into the PR branch and re-run the full suite.

Update the base commit named in coverage-agent-prompt.md to the PR branch head before launching. Tests that only characterize existing behavior need a passing baseline; any production fix needs a failing test first (red → green), recorded in the agent's report.

## Status

| Package | State |
|---|---|
| A-devcycle-completion | Partial: branch `cov/A-devcycle-completion` (WIP commit 52f047b) — Python tests for hooks/lib/tool-input, plus edits to two tool-input sources that must be reviewed |
| B-orchestrator | Partial: branch `cov/B-orchestrator` (WIP commit 6fadc36) — agent-delegation hook test and helpers, plus an edit to hooks/lib/agent-delegation-state.sh that must be reviewed |
| All others | Not started |

The partial branches are unreviewed WIP checkpoints taken when the container restarted; review the source edits before keeping them.

## Known measurement limits

- Bash branch coverage beyond statements is not measurable from xtrace; `a || b` one-liners are covered at the statement level (each side is its own statement).
- Code embedded in Bash heredocs (python, jq, awk programs) and Tcl/Expect scripts is not measured.
- `.planning/scripts/phase-lock.sh` is in scope but lives in the SB-managed `.planning/` tree; test it without editing it.
