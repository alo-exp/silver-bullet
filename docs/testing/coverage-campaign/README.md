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
| A-devcycle-completion | Merged after review (refactors and bug fixes listed in the merge commit) |
| B-orchestrator | Merged after review (agent-delegation scope fixes, fail-closed paths) |
| C-toolgates-1 | Merged after review |
| G-toolstack-1 | Merged after review (five bug fixes, each with a red test) |
| D-gates | Merged after two reviews (rfl errexit abort, phase-archive fails closed without jq, site-chrome font rule) |
| F-enterprise-1 | Merged after review and one repair round (preflight failures now fail their callers; overlay telemetry kept out of the checkout) |
| C-toolgates-2, F-enterprise-2, G-toolstack-2 | In review |
| E-core-hooks, H-recommended-1 | In progress |
| All others | Not started |

Each package is merged into the PR branch only after an adversarial review passes and its tests pass under both the `claude` and `codex` runtimes.

## Dead code and root-only paths

Statements that cannot run are removed, not excluded: each removal is its own `refactor:` commit that states why the code is unreachable, with the package's tests passing before and after. Paths that need a non-root user (unreadable files) are tested with an explicit skip under root; CI runs as a normal user, so the CI coverage job measures them.

## Findings outside the package that found them

| Finding | Where | Owner package |
|---|---|---|
| `if sb_stack_gitleaks_path >/dev/null` always passes (the function always exits 0), so diagnostics report gitleaks installed regardless | `scripts/sb-diagnostics.sh:275` | L-scripts-misc (sb-diagnostics) |
| `jq '... // "true"'` reads a JSON boolean `false` as `"true"`, so `hooks.evidence_schema.strict: false` does not relax the gate | `hooks/lib/enterprise-policy.sh:157`, `hooks/lib/completion-audit/gates.sh:221/224/227` | E-core-hooks / A follow-up |
| `count_*` helpers use `grep -c ... \|\| echo 0` (prints `0` twice when nothing matches) | `hooks/lib/workflow-utils.sh` | E-core-hooks |
| Invalid escape `\s` in a Python string (SyntaxWarning, an error in future Python) | `skills/silver-deep-research-multi-ai/scripts/landscape_preview_render.py:665` | M-dr-multi-ai |
| The in-place edit regex (`\bsed\b[^$]*-i`, `\bperl\b[^$]*-i`) misses combined flags such as `perl -pi` and `sed -Ei`; fixed in `scripts/lib/global-toolstack/common.sh` (G-toolstack-2) but the hook copies still use the old form | `hooks/dev-cycle-check.sh` (229, 249, 628), `hooks/{graphify,rtk,context-mode,agentmemory,leanctx,alumnium}-gate.sh` | Follow-up after the hook packages |
| `sb_rfl_activate` aborts under errexit in a project without `scripts/review-fix-ladder.py` | `hooks/lib/review-fix-ladder-state.sh` | D-gates (under review) |

## Known measurement limits

- Bash branch coverage beyond statements is not measurable from xtrace; `a || b` one-liners are covered at the statement level (each side is its own statement).
- Two commands with the same command word on one line, both with non-literal arguments (`if c; then _check pass "$x"; else _check fail "$x"; fi`), cannot be told apart: when either runs, the analyzer credits one of them. Such lines are split over several lines (layout only) so each statement is measured.
- Code embedded in Bash heredocs (python, jq, awk programs) and Tcl/Expect scripts is not measured.
- bash reports some commands at another line: inside a function, the commands of `< <(...)` carry the line of the last function definition it parsed, and a `|| fallback` after a multi-line program inside `$(...)` lands several lines late. `sbcov.py` matches these by function and by the substitution's words. The one case it cannot tell apart is a late-reported command that lands on a statement with the same command word in the same function (for example `orchestrator-scheduler.sh` line 797, `|| true`, reported at the `|| true` two lines later); such a statement is listed as missing although it ran.
- `.planning/scripts/phase-lock.sh` is in scope but lives in the SB-managed `.planning/` tree; test it without editing it.
