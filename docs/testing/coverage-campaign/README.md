# Coverage campaign — handoff

Handoff for the effort to bring first-party code to 100% measured coverage with meaningful tests. The campaign is complete: see [Final result](#final-result). Pull request: alo-exp/silver-bullet#291 (branch `claude/optimistic-ramanujan-tccfud`).

## Goal and measurement

- Tooling: `tests/coverage/run-coverage.sh` (`make coverage`), engine `tests/coverage/sbcov.py`, scope `tests/coverage/scope.json`. See [../../TESTING.md](../../TESTING.md).
- Metrics: Bash statements, lines and functions; Python statements and branches; JS/TS lines, functions and branches.
- Target: `--fail-under 100`, enforced by the CI coverage job. It is evaluated on the denominator minus four audited statements listed in `tests/coverage/known-limits.json` (see Known measurement limits); no other statement is excluded.
- Denominator at the baseline (2026-10-17): Bash 44,168 statements in 353 files; Python 19,483 statements in 108 files; JS/TS 7 files (about 1,400 lines). Generated mirrors and test code are excluded.

## Final result

CI run 39176781413 on commit `bd0cdb2` (coverage job with `--fail-under 100`; all jobs green):

| Item | Result |
|---|---|
| Tests | TOTAL 31376 passed, 0 failed (8/8 suites green); 64/64 hooks covered by the hook coverage matrix |
| Bash | 355 files; statements 44094/44094 (100.00%), lines 31807/31807 (100.00%), functions 2107/2107 (100.00%) |
| Python | 111 files; statements 19782/19782 (100.00%), branches 8442/8442 (100.00%) |
| JS/TS | 7 files; lines 1543/1543, functions 116/116, branches 486/486 (all 100.00%) |

These totals exclude the four audited statements in `tests/coverage/known-limits.json` (see Known measurement limits). Measurement limits the report itself prints: 259 modified staged copies are ignored because their traces do not match the source; 313 bash trace hits are unattributed (eval/trap bodies or analyzer gaps); Bash parse errors near `hooks/lib/agentmemory-gate.sh` line 302, `hooks/lib/graphify-gate.sh` line 180 and `scripts/lib/global-toolstack/common.sh` lines 390 and 540 mean statements near those lines may be miscounted. Bash has no branch metric (statements, lines and functions only); JS/TS has no statement metric.

Final packages merged in the last round: Q-final-gaps (last Bash and Python gaps, lint-shell test), limits (known-limits mechanism, CI `--fail-under 100`), R-default-paths (tests for the sibling-directory defaults from the portability fix `f088c3f`), and the minimax-proxy test race fix (`bd0cdb2`).

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
| G-toolstack-2 | Merged after review (pi plugin result unwrap, GNU stat lock age, perl -pi detection) |
| F-enterprise-2 | Merged after two reviews (live-test resume race, quiesce id regex, marker search) |
| C-toolgates-2 | Merged after two reviews (record-skill debug-mode abort, dead token guards removed) |
| I-scripts-py-1 | Merged after review (codex PTY EIO on Linux, shared default lists, unreapable child terminated) |
| L-scripts-misc-1 | Merged after three reviews (deploy-gate sourcing leak, evidence zip staleness, timeout helper fixes) |
| H-recommended-1 | Merged after three reviews (eleven fixes incl. heartbeat root write, routeShell false, receipts brace) |
| L-scripts-misc-2 | Merged after review (value-less options fail closed, workflows awk, semantic-compress budget) |
| H-recommended-2 | Merged after two reviews (diagnostics gitleaks, doctor --fix twice, lost score exports, claude host detection) |
| I-scripts-py-2 | Merged after three reviews (merge scripts no longer overwrite user config; hermes YAML keeps user servers) |
| E-core-hooks | Merged after two reviews (session-start cleanup no longer aborts, strict=false honoured, SIGPIPE-safe grep, prompt-reminder fallback list pinned to the template) |
| I-scripts-py-3 | Merged after four reviews (silver-scan case-insensitive match and lost-filing retry, atomic Cursor hook strip, launchd failure falls back to at, render failures exit non-zero) |
| F-enterprise-3 | Merged after review |
| F-enterprise-4 | Merged after review |
| J-install-sync-1 | Merged after review |
| J-install-sync-2 | Merged after review |
| K-agents-live-1 | Merged after review |
| K-agents-live-2 | Merged after review (agent-mode resolver dirname fix, host-smoke-cell claim exit code, status listing reads RUNS_DIR; log-floor boundary pinned after review) |
| M-dr-multi-ai-1 | Merged after three reviews (tests made hermetic: no network, was 3,525 connection attempts; JS regex escapes fixed; discover_solutions fallback returns slugs; font cache restored between tests) |
| M-dr-multi-ai-2 | Merged after review and one repair round (code-span URL with spaces, hash-seed-dependent label tie-break, nested links for overlapping labels) |
| N-deep-research-1 | Merged |
| N-deep-research-2 | Merged |
| O-skills-other | Merged |
| P-site-js | Merged |
| Q-final-gaps | Merged (last Bash and Python gaps, lint-shell test) |
| limits | Merged (known-limits mechanism, CI `--fail-under 100`) |
| R-default-paths | Merged (tests for the sibling-directory defaults from `f088c3f`) |
| Final result | 100% on every supported metric, CI run 39176781413 at `bd0cdb2` (see [Final result](#final-result)) |

Each package is merged into the PR branch only after an adversarial review passes and its tests pass under both the `claude` and `codex` runtimes.

## Dead code and root-only paths

Statements that cannot run are removed, not excluded: each removal is its own `refactor:` commit that states why the code is unreachable, with the package's tests passing before and after. Paths that need a non-root user (unreadable files) are tested with an explicit skip under root; CI runs as a normal user, so the CI coverage job measures them.

## Findings outside the package that found them

| Finding | Where | Owner package |
|---|---|---|
| ~~`if sb_stack_gitleaks_path >/dev/null` always passes, so diagnostics report gitleaks installed regardless~~ fixed | `scripts/sb-diagnostics.sh` | H-recommended-2 (merged) |
| ~~`jq '... // "true"'` reads a JSON boolean `false` as `"true"`, so `hooks.evidence_schema.strict: false` does not relax the gate~~ fixed | `hooks/lib/enterprise-policy.sh`, `hooks/lib/completion-audit/gates.sh` | E-core-hooks (merged) |
| ~~`count_*` helpers use `grep -c ... \|\| echo 0` (prints `0` twice when nothing matches)~~ fixed | `hooks/lib/workflow-utils.sh` | E-core-hooks (merged) |
| ~~`refactor(hooks): drop unreachable alternatives` removed the `.git`/`/` stop from the config walk-ups in `session-start` (trivial file) and `stop-check` (transient patterns); when the config vanishes mid-run (project deleted under a backgrounded hook) the walk spins on `dirname /` forever, which killed the CI runners~~ fixed, guard restored with a red test (`tests/hooks/test-config-walk-vanishes.sh`) | `hooks/session-start`, `hooks/stop-check.sh` | E-core-hooks follow-up |
| ~~Invalid escape `\s` in a Python string (SyntaxWarning, an error in future Python)~~ fixed | `skills/silver-deep-research-multi-ai/scripts/landscape_preview_render.py:665` | M-dr-multi-ai-1 (merged) |
| The in-place edit regex (`\bsed\b[^$]*-i`, `\bperl\b[^$]*-i`) misses combined flags such as `perl -pi` and `sed -Ei`; fixed in `scripts/lib/global-toolstack/common.sh` (G-toolstack-2) but the hook copies still use the old form | `hooks/dev-cycle-check.sh` (229, 249, 628), `hooks/{graphify,rtk,context-mode,agentmemory,leanctx,alumnium}-gate.sh` | Follow-up after the hook packages |
| ~~On timeout `scripts/codex-interactive-invoke.expect` ran `kill -TERM -$child_pid`; procps-ng 4.0.4 kill(1) reads a negative pid without `--` as an option and drops its last digit, so `test-run-sb-live-tests-kay.sh` signalled an unrelated process group (the CI runner, which shut down)~~ fixed with a red test | `scripts/codex-interactive-invoke.expect` | CI follow-up |
| ~~`sb_rfl_activate` aborts under errexit in a project without `scripts/review-fix-ladder.py`~~ fixed | `hooks/lib/review-fix-ladder-state.sh` | D-gates (merged) |

## Known measurement limits

- Bash branch coverage beyond statements is not measurable from xtrace; `a || b` one-liners are covered at the statement level (each side is its own statement).
- Two commands with the same command word on one line, both with non-literal arguments (`if c; then _check pass "$x"; else _check fail "$x"; fi`), cannot be told apart: when either runs, the analyzer credits one of them. Such lines are split over several lines (layout only) so each statement is measured.
- Code embedded in Bash heredocs (python, jq, awk programs) and Tcl/Expect scripts is not measured.
- bash reports some commands at another line: inside a function, the commands of `< <(...)` carry the line of the last function definition it parsed, and a `|| fallback` after a multi-line program inside `$(...)` lands several lines late. `sbcov.py` matches these by function and by the substitution's words. The one case it cannot tell apart is a late-reported command that lands on a statement with the same command word in the same function (for example `orchestrator-scheduler.sh` line 797, `|| true`, reported at the `|| true` two lines later); such a statement is listed as missing although it ran.
- `.planning/scripts/phase-lock.sh` is in scope but lives in the SB-managed `.planning/` tree; test it without editing it.

### Audited known limits

`tests/coverage/known-limits.json` removes exactly four statements from the Bash denominator (the covered count and the total; they are not counted as covered, and function counts are unchanged). `--fail-under 100` is enforced on the denominator minus these four statements. `sbcov.py report` validates the file on every run: an entry for a file outside `scope.json`, with no statement of that command word at that line, or whose statement was covered in the run (`stale known limit: now covered`) is an error and the report exits 3. Entries for files not measured in a `--only` run are skipped. See [../../TESTING.md](../../TESTING.md).

| File:line | Word | Kind | Why |
|---|---|---|---|
| `.planning/scripts/phase-lock.sh:478` | `cat` | unreachable | The `"" \| -h \| --help)` arm of the final dispatch `case` is dead: the early dispatch at lines 31-46 has already exited for those values. The file is in the SB-managed `.planning/` tree and may not be edited, so the dead code cannot be removed. |
| `.planning/scripts/phase-lock.sh:490` | `exit` | unreachable | The `exit` ending the same dead arm. |
| `hooks/lib/orchestrator-scheduler.sh:797` | `true` | unmeasurable | The `\|\| true` after `tmpl=$(jq ...)` in `sb_scheduler_mark_handoff_dispatched` is the late-reported fallback described above. It runs: removing it fails `tests/hooks/test-orchestrator-failure-paths-scheduler-lib.sh`. |
| `scripts/enterprise-e2e/lib/core.sh:26` | `*` | unmeasurable | `done < <("$@")` in `enterprise_e2e_read_lines_to_array` runs a dynamic command; xtrace prints the resolved command, so the static word match fails. It runs: `tests/scripts/test-enterprise-e2e-core-fixture.sh` asserts the resulting array. |
