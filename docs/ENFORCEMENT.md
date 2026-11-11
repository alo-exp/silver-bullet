# Enforcement Architecture

Silver Bullet enforces workflow compliance through twelve independent layers. No single layer can be bypassed in isolation — they compose to provide defense-in-depth. The same twelve layers appear in the README and in `silver-bullet.md` §1; [HOOKS.md](HOOKS.md) lists every registered hook, including the gates beside these layers.

## The 12 Layers

| # | Layer | Mechanism | Fires on | What it prevents |
|---|-------|-----------|----------|------------------|
| 1 | **Skill recording** | `record-skill.sh` (PostToolUse `Skill\|Bash\|exec_command`) | Host Skill tool calls; Codex `silver-bullet invoke-skill` receipts | Skills invoked through a supported channel but not tracked |
| 2 | **Planning-floor gate** | `dev-cycle-check.sh` (Pre+PostToolUse), `workflow-chain-guard.sh` (PreToolUse) | Edit, Write, MultiEdit, `apply_patch`, shell commands | Source edits before planning is complete. Uses active `.planning/workflows/<id>.md` admission first, then skill markers when no composed workflow is active |
| 3 | **Compliance status** | `compliance-status.sh` (PostToolUse `.*`) | Every tool call | Silent progress — shows flow progress (FLOW N/M) or recorded-skill count. Informational only |
| 4 | **Planning file guard** | `planning-file-guard.sh` (PreToolUse) | Edit, Write, MultiEdit, `apply_patch` | Direct edits to SB-managed planning artifacts (`ROADMAP.md`, `STATE.md`, phase plans and summaries); forces the owning SB workflow |
| 5 | **Completion audit** | `completion-audit.sh` (PreToolUse and PostToolUse) | `git commit`, `git push`, commit plumbing; `gh pr create/merge`, deploy, `gh release create` | Commits without the planning floor; delivery without the full workflow (two-tier model below) |
| 6 | **CI status check** | `ci-status-check.sh` (PreToolUse and PostToolUse) | `git push`, `gh pr create/merge`, `gh release create`; `git commit` (post only) | Pushing, opening or merging PRs, or releasing while the latest CI run failed. After a commit it only warns |
| 7 | **Session management** | `session-start` (SessionStart), `session-log-init.sh`, `timeout-check.sh` (PostToolUse) | Session start, compaction, every tool call | Stale state across branches and worktrees, missing session logs, runaway autonomous sessions |
| 8 | **Stop gates** | `stop-check.sh` with `outcomes-check.sh`, `instruction-ledger-gate.sh`, `subagent-stop-enforcement.sh` and the site gates (Stop/SubagentStop) | Task-complete declaration | Declaring done while the planning floor, outcomes, ledger items or worker audits are open |
| 9 | **Prompt recorder + reminder** | `record-requested-skill.sh` + `prompt-reminder.sh` (UserPromptSubmit) | Every user message | Requested SB routes are recorded before the next turn; missing steps are re-injected |
| 10 | **Forbidden skill gate** | `forbidden-skill-check.sh` (PreToolUse `Skill`) | Every Skill invocation | Deprecated or forbidden skills (`executing-plans`, `subagent-driven-development`, plus `skills.forbidden`) |
| 11 | **ROADMAP freshness gate** | `roadmap-freshness.sh` (PreToolUse shell) | `git commit` | Committing a phase `SUMMARY.md` without ticking the matching `ROADMAP.md` checkbox |
| 12 | **Redundant instructions** | `silver-bullet.md`, workflow docs and the optional project instruction file (`CLAUDE.md` / `AGENTS.md`) | Every session | Same rules stated on every instruction surface for defense-in-depth |

`record-skill.sh` searches every candidate receipt directory from `sb_runtime_skill_receipt_dirs()` (Claude and Codex homes). Codex adapter receipts land under `~/.codex/.silver-bullet/skill-invocations`; repo-source hooks must not assume the Claude runtime when `CLAUDE_PLUGIN_ROOT` resolves under `/.codex/`.

Beside the twelve layers run further gates: the spec floor (`spec-floor-check.sh`) and UAT gate (`uat-gate.sh`), `phase-archive.sh` and the phase locks, orchestrator parent-mode guards (`orchestrator-directive-guard.sh`, `agent-delegation-guard.sh`), site-session gates, and the opt-in gates for Graphify, agentmemory, RTK, Context Mode, LeanCTX and Alumnium. `hooks/core-rules.md`, which `session-start` injects, counts four of the opt-in gates as layers 13–16.

## Planning-Floor Gate

`dev-cycle-check.sh` enforces pre-execution readiness. When an active `.planning/workflows/<id>.md` exists, the gate requires `SB_WORKFLOW_ID` admission before non-trivial source edits. The skill-based check is the legacy fallback for projects without a composed workflow.

| Stage | Requires | Blocks until |
|-------|----------|--------------|
| A — Planning floor | `required_planning` skills in state | SB pre-execution gates complete |
| B — Implementation window | Planning floor complete | Source edits are allowed; review/verify/ship remain final-delivery gates |
| C — Review recorded | `silver-review` in state | Source edits still allowed; finalization remains gated |
| D — Finalization | All `required_deploy` skills plus expected SB artifacts | Final delivery commands allowed |

The same hook also hard-blocks edits under the host plugin cache (`${SB_RUNTIME_HOME_ROOT}/plugins/cache/`) and direct writes to SB state files.

## Two-Tier Model

Silver Bullet enforces two **distinct** tiers:

| Tier | Trigger | Hook | Requires |
|------|---------|------|----------|
| **Planning floor** | Commands that create commits or push: `git commit`, `merge`, `cherry-pick`, `revert`, `am`, `rebase`, `fast-import`, `pull .` (a local merge, however the repository is spelled: `.`, `./`, `.git`, `$PWD`, `file://`), forced branch moves (`branch -f`/`-M`), a branch moved onto a stash commit (`checkout -B`/`switch -C`/`reset`/`branch NAME` with `stash`, `stash@{N}` or `refs/stash` as the start point: the agent's stashed work lands on the branch without a `git commit`), `subtree add|merge|pull`, plumbing (`write-tree`, `commit-tree`, `hash-object -w`, `update-ref` of `refs/heads/*` or `HEAD`), `git push`, `subtree push`, `http-push`, `send-pack`. Plain `git pull`, `git stash` and `git checkout -B`/`switch -C` to an ordinary start point create no commits of the agent's own and are not gated | `completion-audit.sh` | `required_planning` skills in state |
| **Planning floor** | Task-complete declaration (Stop/SubagentStop) | `stop-check.sh` | `required_planning` skills in state |
| **Final delivery** | `gh pr create`/`new`, `gh pr merge`, `gh release create`/`new`, `gh api` writes to pulls, merges, releases, git refs or contents, `hub pull-request`/`merge`/`release`, `glab`/`tea`/`az repos` PR and release verbs, raw `curl`/`wget`/`http` writes to the GitHub API, and deploys: deploy tools (`kubectl apply`, `helm upgrade`, `terraform apply`, `npm publish`, `docker push`, `fly deploy`...) and tasks, scripts (also those inside a `deploy/` directory) or workflows named deploy, release or publish, and `ssh`/`scp`/`rsync` as a deploy user | `completion-audit.sh` | All `required_deploy` skills + expected artifacts; for `gh release create` also `required_release` and the release gates below |

**How commands are classified.** `hooks/lib/tool-input/shell_analysis.py` parses the whole command like bash does and follows it in execution order: every line and every segment of `;`, `&&`, `||` and `|` chains, `$(...)`, backticks, here-documents fed to a shell, `sh -c` and `eval` code, wrappers (`env`, `command`, `nohup`, `timeout`, `xargs`, `find -exec`...), git global options (`-C`, `-c`, `--git-dir`) and git and gh aliases. Variables, arrays, positional parameters (`shift`, `"${@:2}"`) and the common parameter operators (`:-`, `#`, `%`, `/`, `:N`, `^^`...) are evaluated on literal values. A command with several verbs gets the highest tier (`git push && gh pr create` is final delivery). Commands that only mention a verb (`echo deploy`, `grep "gh pr create" docs/`, `kubectl get deploy`, `tldr git commit`) are not gated.

*Commands hidden behind a program the analyzer does not model.* A program without a handler (`taskset`, `uv run`, `poetry run`, `tmux`, `pwsh -c`, `parallel`, `vim -c`, `docker exec`, `kubectl exec --`, `ssh host 'cmd'`...) cannot hide a delivery verb that is written out in its arguments: every argument suffix that starts at a program word (`git`, `gh`, `make`, `kubectl`, a shell...) and every argument that reads as a command line is judged, and git settings and variables that hold a command line (`core.pager`, `diff.external`, `core.sshCommand`, `GIT_EXTERNAL_DIFF`, `difftool -x`, `bisect run`, `submodule foreach`, `grep -O`...) are walked. What they could do is reported as a possible action; arguments after a pattern option (`pytest -k "git commit"`) and the topic of `man`/`tldr` are not commands.

*Unseen code.* Code the analysis cannot read is held at the strictest tier instead of being waved through (the pseudo action `unseen`, completion tier). That covers a program word computed in the command itself: a variable assigned from `$(...)`, `read` or `mapfile`, an element of such an array, a parameter operator that cannot be evaluated, a positional parameter taken from such text, or xargs input handed to `git`/`gh`; `eval` of anything but a well-known environment tool (`eval "$(ssh-agent -s)"`, `eval "$(brew shellenv)"`, `eval $(poetry env activate)`, `source <(kubectl completion bash)`: the whole substitution must be that one tool with plain arguments); a shell or interpreter fed by a pipe from a command or by `<(...)` or an open descriptor (`bash /dev/fd/3`); `bash -s` without a readable script; inline interpreter code that runs a command which is not written out (`os.system(cmd)`, `"gi" + "t"`, `exec`, `base64`, `getattr`); `awk system(var)`; `sed e`; arithmetic, array subscripts, `${x:off:len}` offsets, `declare -i` assignments and `[[ -v name ]]` that evaluate a variable holding `$(...)`; a changed `IFS` whose value is unknown; git or gh aliases that cannot be resolved (config files, `GH_CONFIG_DIR` or `HOME` redirected, included or written in the same command, `gh extension install`); `gh api graphql` with an unreadable query; and syntax the parser rejects. A variable that is merely inherited from the environment (`$PYTHON -m pytest`, `$G commit -m x`) is not computed: it is judged by its arguments. A script below a computed directory (`"$(git rev-parse --show-toplevel)/scripts/check.sh"`) and a script fed from a literal file (`bash < setup.sh`, `cat setup.sh | bash`) are script files like `bash setup.sh`: their contents are not analysed, but they are not unseen code. When `completion-audit.sh` blocks on unseen code, `ca_unseen_reasons` (classify.sh) holds why.

*Bounded work.* The analyzer is bounded in cost, not only in steps. Input over 512 KiB is not parsed; the parser and the walker each stop after 1 s (the deadline is checked at every step), a stored value over 64 KiB or an array over 4096 items becomes unknown, brace sequences and `GIT_CONFIG_COUNT` are capped, and every regular expression applied to command text is linear. Going over a limit, or an analyzer fault, reports unseen code (strictest tier), so a crafted command is denied rather than timing the hook out; `dev-cycle-check.sh` starts the analyzer three times per Bash call, which still fits the 15 s hook limit. If python3 is installed but the helper does not finish, `classify.sh` holds the command at the strictest tier too. The analyzer needs `python3`; without it a regex fallback over every line catches the plain verbs and variable-built commands that name a delivery verb, and `sb_shell_analysis_helper_message` tells the agent how to proceed.

*Residual limits.* Script, makefile and sourced-file contents are opaque, not read (a script written and run in the same command is read from the text it was given; one whose written content cannot be read is unseen code); `parallel gh ::: 'pr create'`, `make SHELL=...`, `rg --pre`, `GIT_ASKPASS=/tmp/x.sh` and `core.hooksPath` run files whose contents are never read; an environment variable that was exported in a previous tool call is invisible. The agent has a shell as the same user, so these checks make a bypass deliberate and visible rather than impossible.

*Push scope residual limits (Invariant P).*

1. **Code git runs on its own.** Git hooks (`pre-commit`, `post-commit`, `pre-push`, `reference-transaction`, `post-checkout`), `core.hooksPath`, credential helpers, `core.sshCommand`/`GIT_SSH_COMMAND`, `remote.*.receivepack` (strict when set, but other configured programs are not judged) and `ext::` transports are not judged. An agent that writes a hook can push anything when an inert `git commit` runs; the corpus pins this as a residual row (a `post-commit` hook that runs `git symbolic-ref HEAD refs/heads/main`, then `git commit -m x && git push origin HEAD`: verdict intermediate, effect on main). Follow-up outside this package: gate writes to `.git/hooks/**` and `git config core.hooksPath|*.receivepack|credential.*`.
2. **Shell environment outside the command text.** The host's shell snapshot (profile functions and aliases, for example a user `git` function), a `git` earlier on `PATH`, and variables exported in a previous tool call or through `CLAUDE_ENV_FILE` are not visible. Only the known redirecting variables in the hook's own environment are checked.
3. **Stale knowledge of the remote.** `refs/remotes/<remote>/HEAD` reflects the last fetch or `set-head`. A remote whose default branch was renamed since then, and which matches neither `main`, `master`, `init.defaultBranch` nor the stale target, is not recognised.
4. **Time of check versus time of use.** Background jobs started by earlier tool calls (`run_in_background`) can change HEAD or config between the hook and the push.
5. **Server-side automation.** Repository rules or workflows that merge or deploy on a feature-branch push are outside the gate.
6. **MCP.** The target repository is trusted to be the one named by the local remote URL. GitHub Enterprise hosts are always strict.
7. **gh placeholders.** `{owner}`/`{repo}` resolve to gh's base repository. In a fork checkout this may be `upstream`, while the release commit is read from `origin`.
8. **Strict-by-design false positives,** each with an actionable message. They cost an honest user one split command: `git fetch`/`pull`/`rebase`, test runners or `make` in the same command as the push; `git push origin "$(git branch --show-current)"`; `cd ~/...`; a forced push to an unqualified `src:dst`; `git push` retried in one command; a checkout without `refs/remotes/<remote>/HEAD` (the remedy is `git remote set-head <remote> --auto` once).
9. **Behaviour worth knowing.** A variable assignment in the push command (`RTK_DISABLED=1 git push origin feat/x`, `GIT_SSH_COMMAND=... git push`) is final delivery: the assignment is a top-level assignment the proof does not model, so set the variable with a separate `export` earlier in the session or accept the deploy floor (the block message names it). `gh release edit` and `gh release upload` are not release creations the commit reader understands and deny as `cannot determine release commit`. `GH_REPO`/`GH_HOST` anywhere in a release command (or `GH_REPO` in the hook environment naming another repository) deny. An MCP push when the python3 helper is unavailable is final delivery (its target cannot be read). With `project.push_to_default_branch_tier: "intermediate"` the verdict is ignored, but the three read-only git calls still run (classification happens before the config is read).

`stop-check.sh` blocks **only** on the `required_planning` floor — it does **not** require the full `required_deploy` list. This is intentional (v0.30.0 #85): an agent may legitimately end a session mid-implementation as long as the planning floor is recorded. The full `required_deploy` list is enforced by `completion-audit.sh` when an actual delivery command runs. Intermediate commits and pushes need only the planning floor, so execution subagents can commit atomically mid-execution. **Invariant P (push).** A shell push is intermediate only when Silver Bullet can prove, from the command text and from read-only local git answers (`rev-parse`, `config -z --list`, `for-each-ref`; no network, no hooks run), that the command runs exactly one `git push` from one known directory, contains nothing else that could change the facts the proof relies on, and, under the git configuration in force, updates only `refs/heads/<B>` on one named remote, where every `<B>` is a spelled-out branch name that is not that remote's default branch. Anything not proved is final delivery. The accepted shape is `git push [-u] [<remote>] [<branch>|HEAD|<src>:<dst>]` as its own command, optionally after `cd <literal dir> &&` or `git checkout -b <new> &&` / `git switch -c <new> &&` in an unbroken `&&` chain, next to nothing but inert commands (`git add|commit|status|diff|log|show|rev-parse|ls-files|describe|shortlog`, listing forms of `git branch` and `git remote -v`, `echo`, `printf`, `true`, `cat`, `head`, `tail`, `grep`, `wc`, `sleep`, `pwd`, `ls`, `test`). The directory is the payload's `cwd` (Codex: `workdir` joined to it), never the hook's own working directory. The strict causes are: any other command on the line (`git checkout`, `fetch`, `config`, `stash`, `rebase`, `sh -c`, `eval`, test runners, `make`, function calls, assignments, background jobs, compound commands), `git -c` and `--git-dir`, git-redirecting variables in the environment (`GIT_DIR`, `GIT_CONFIG_*`, `BASH_FUNC_*`...), push options other than the plain boolean ones (long options must be spelled in full; `--mir` is not `--mirror`), tags, `--all`/`--mirror`/`--delete`, globs and deletions, a forced push to an unqualified destination, a destination that is a default branch (`main`, `master`, `init.defaultBranch`, the target of `refs/remotes/<remote>/HEAD`, compared case-insensitively), a push to a URL or path instead of a configured remote, git settings that change what a push sends (`remote.<name>.push|pushurl|mirror|receivepack`, `push.default` other than `simple`/`current`, `push.followTags`, `push.pushOption`, `url.*.pushInsteadOf`), a detached HEAD, a git that does not answer in time, and a checkout that does not know its remote's default branch (`refs/remotes/<remote>/HEAD` missing: run `git remote set-head <remote> --auto` once, which needs the network). The block message names the cause and the accepted shape. `project.push_to_default_branch_tier: "intermediate"` is the explicit opt-out.

**Invariant M (MCP write).** An MCP write (`push_files`, `create_or_update_file`, `delete_file`, `create_commit`, `create_branch`) is intermediate only when `owner` and `repo` are plain strings that match, ignoring case, a GitHub remote (`https://github.com/O/R`, `git@github.com:O/R`, `ssh://git@github.com/O/R`, `git://github.com/O/R`) of the checkout in the payload's `cwd`; that remote's default branch is known locally (`refs/remotes/<remote>/HEAD`); and `branch` is a spelled-out branch name (one leading `refs/heads/` is stripped) that is not `main`, `master`, `init.defaultBranch` or the target of that remote's `HEAD`. A missing branch (the repository default), a repository the checkout has no remote for, a GitHub Enterprise host, a `repository: "o/r"` shape, `create_tag`, `create_ref`, `update_ref` and `update_pull_request_branch` are final delivery. `hooks/core-rules.md` and `silver-bullet.md` describe the same split — keep all three in sync.

In the `devops-cycle` workflow the `_devops` variants (`required_planning_devops`, `required_deploy_devops`, `required_release_devops`) apply.

### Orchestrator Worker SubagentStop

In orchestrator parent mode, the parent session spawns Task **workers**, each executing one atomic flow. Stop/SubagentStop handling differs by role:

- **Worker (`SB_ORCHESTRATOR_WORKER=1`) on `SubagentStop`:** `stop-check.sh` clears the worker marker and exits 0. Workers are **not** individually subjected to the planning-floor or delivery gates — they perform a single flow and return to the parent. Enforcement is the parent's responsibility.
- **Parent on `Stop` with a pending flow queue:** `stop-check.sh` blocks and instructs the parent to spawn the next Task worker for the next flow before ending the session. The parent cannot declare the composition complete while flows remain queued.

This division means the planning-floor and delivery gates are enforced **once, at the parent level**, against the cumulative state the workers contributed — never redundantly on each worker SubagentStop.

## CI Status Gate

`ci-status-check.sh` reads the latest GitHub Actions run for the current branch (`gh run list`); without `gh` it exits quietly.

| Event | Commands | When CI failed or was cancelled |
|-------|----------|---------------------------------|
| PreToolUse | `git push`, `gh pr create`, `gh pr merge`, `gh release create` | Denied |
| PostToolUse | `git commit` | Warning only (the commit already happened; blocking would deadlock CI fixes) |
| PostToolUse | `git push`, `gh pr create/merge`, `gh release create` | Block message |

The status checked is the latest run of each workflow on the newest commit of the branch (a red workflow is not hidden by a later green one). A `git push` is let through only when every changed file is under `.github/workflows/` or `tests/` (or is `package.json`); a commit-message convention no longer waives a red CI. A human can waive the block for 30 minutes (`SB_CI_OVERRIDE_TTL_MINUTES`) with the flag file `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/ci-red-override`; an expired flag is removed. When `gh` is missing, fails or exceeds its timeout (`SB_GH_TIMEOUT_SECONDS`, default 8) the hook says CI status could not be checked. `state.trivial_file` in the project config is honoured only as the state directory's own `trivial` file. Runs that are in progress are informational. Deploy commands are not checked by this hook; `completion-audit.sh` separately requires the release commit to be green before `gh release create`.

## Composed-Workflow-First Enforcement Pattern

All hooks check active `.planning/workflows/<id>.md` files first, falling back to legacy skill markers when no composed workflow is active.

| Hook | Composed-workflow mode | Legacy fallback |
|------|------------------------|-----------------|
| `dev-cycle-check.sh` | Active workflow exists and `SB_WORKFLOW_ID` matches before non-trivial source edits | 4-stage skill marker check |
| `completion-audit.sh` | `SB_WORKFLOW_ID`-matched workflow file shows all required flow rows complete | `required_deploy` skill list check |
| `compliance-status.sh` | Shows path progress (FLOW N/M) | Shows skill count only |
| `prompt-reminder.sh` | Includes active composed workflow IDs and current position | Omits composition context |
| `spec-floor-check.sh` | Advisory when FLOW 5 excluded from composition | Hard gate always |

Detection: hooks check for `.planning/workflows/` existence and active `.md` files. Present = composed-workflow mode, absent = legacy mode.

## Skill Classification

| List | Purpose | Enforcement |
|------|---------|-------------|
| `all_tracked` | Discovery — hooks record invocation | Observability only |
| `required_planning` | Planning floor | `dev-cycle-check.sh` blocks source edits; `completion-audit.sh` blocks commits and pushes; `stop-check.sh` blocks Stop |
| `required_deploy` | Final delivery floor | `completion-audit.sh` blocks `gh pr create/merge`, deploy and `gh release create` |
| `required_release` | Release-only additions (default `silver-create-release`) | `completion-audit.sh` on `gh release create` |

Current `required_deploy` (canonical source: `templates/silver-bullet.config.json.default`) includes SB quality gates, SB lifecycle markers (`silver-context`, `silver-plan`, `silver-execute`, `silver-verify`, `silver-ship`, review/security/validation), review framing, finalization, completion audit, TDD where applicable, and `verify-tests`. Legacy GSD/Superpowers marker names are accepted only as compatibility aliases during migration. [CONFIGURATION.md](CONFIGURATION.md) describes every list.

Conditional skills (NOT in `required_deploy`): `accessibility-review` (UI only), `incident-response` (DevOps only)

## Enterprise Policy Delivery Block

Before the delivery floor, `completion-audit.sh` applies the enterprise policy (`hooks/lib/enterprise-policy.sh`). When the active profile's `production_deploy_requires_human` is true — as in every shipped profile, and by default when no profile is configured — `gh pr create`, `gh pr merge`, `gh release create` and deploy commands are blocked with `ENTERPRISE POLICY BLOCK` until a human creates `${SB_RUNTIME_STATE_DIR}/enterprise-human-deploy-approved` from their own terminal. Agents must not create that marker. A profile with `non_production_deploy_autonomy: true` (the shipped `internal_dogfood`) exempts commands that name a non-production target (staging, preview, non-prod, sandbox, dogfood, internal). `SB_ENTERPRISE_HUMAN_DEPLOY_APPROVAL=1` exists for audited automation tests only. See [CONFIGURATION.md](CONFIGURATION.md#enterprise_policy).

## Release Gates

On `gh release create`, `completion-audit.sh` adds the release gates the project config enables (`release.require_*`; all `false` in the template, `true` in this repository). The commit checked for green CI is the one `gh release create` will release: an existing tag's commit, else `--target` (resolved against the remote branch), else the remote default branch, else `HEAD`. The tag and target are read the way gh reads them (`hooks/lib/tool-input/release_scope.py`): `gh release create`/`new`, `gh api repos/{owner}/{repo}/releases` (flags and fields in every spelling, `-f`/`-F`/`--field`/`--raw-field`, clusters such as `-if`, `-p` as the preview flag, no prefix abbreviations) and the MCP `create_release`, in the repository of this checkout (`{owner}`/`{repo}` or the slug of `remote.origin.url`), with one release per command. A second release, a repeated or computed `tag_name`/`target_commitish`, a body read from `--input` or `-F @file`, `GH_REPO`/`GH_HOST`, another tool (`hub`, `glab`, `curl`...) or an unknown flag blocks with `cannot determine release commit` and the reason. Validators and the RC predicate are loaded from the plugin, never from the project tree; a missing or non-executable plugin validator blocks the release:

- **Plugin runtime matrix** (`require_plugin_runtime_matrix`) — matching `matrix=` markers from `scripts/run-release-live-matrix.sh`, `tests/e2e-live/run-e2e-live-tests.sh` and the enterprise inline journey in the runtime state dir.
- **Pre-release quality gate** (`require_pre_release_quality_gate`) — the markers `adversarial-review-clean`, `sentinel-skills-clean`, `quality-gate-stage-3` and `full-test-suite-rerun` in the quality-gate state file, plus the plugin's `scripts/validate-launch-review.sh` and `scripts/validate-sentinel-skills-manifest.sh`, run against the project's files.
- **RC validation matrix** (`require_rc_matrix`) — six operator-local `status=pass` markers written by `scripts/run-rc-validation-matrix.sh` at the commit being released. A `--dry-run` (`status=dry-run`), a skipped cell, or a marker for another commit does not count; skips are accepted only for one commit when a human writes `commit=<sha>` into `rc-validation/skip-waiver`.
- **Green CI** on the release commit (always).

The stages behind these markers, and the order to run them in, are described in [RELEASE.md](RELEASE.md). The quality-gate state file is cleared on session start, so markers cannot carry over from an earlier session. The full-suite rerun runs through `verify-tests`, which also writes `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/verify-tests-state` so final delivery can detect stale source changes.

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `SILVER_BULLET_STATE_FILE` | `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/state` | Override the state file path used by all hooks. Intended for testing — lets test suites point hooks at a temp file instead of the real state. Must resolve, after `..` and symlinks, to a path inside `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/` (enforced by every hook that reads it); other paths fall back to the default. |
| `SILVER_BULLET_QUALITY_GATE_STATE_FILE` | `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/quality-gate-state` | Override the release-quality-gate marker file used by `completion-audit.sh` and `session-start`. Intended for testing. Must resolve, after `..` and symlinks, to a path inside `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/`; other paths fall back to the default. |
| `SILVER_BULLET_VERIFY_TESTS_STATE_FILE` | `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/verify-tests-state` | Override the test-execution freshness marker used by `completion-audit.sh`, `dev-cycle-check.sh`, `session-start`, and `/verify-tests`. Intended for testing. Must resolve, after `..` and symlinks, to a path inside `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/`; other paths fall back to the default. |

**Test and automation switches.** These variables exist for the test suites and cert cells, and are honoured only inside a throw-away sandbox, i.e. when HOME, the host runtime home and the runtime state directory ALL live under a fixed system temp root (`/tmp`, `/var/tmp`, `/var/folders` and their `/private` forms) and not under the user's passwd home; `$TMPDIR` is not trusted because the agent chooses it for a nested host: `SB_AGENT_CERT_RUN`, `GH_RUN_LIST_OVERRIDE`, `GH_RUN_LIST_OVERRIDE_CMD`, `GH_STATUS_OVERRIDE`, `SILVER_BULLET_SKIP_ENFORCEMENT_TIER_GATE` and `SILVER_BULLET_TEST_HOOK_ENFORCED`. A nested host CLI started by the agent keeps the user's real runtime home, so these switches do nothing there (`SB_RUNTIME_STATE_DIR`/`SB_RUNTIME_PRESERVE_STATE_DIR` cannot turn the switches on while the real HOME is in use; an agent can still point a child's HOME at `/tmp`, but that child has none of the user's auth, plugins, git credentials or state). `SB_ENTERPRISE_HUMAN_DEPLOY_APPROVAL=1` is a sign-off by whoever starts the host; each use is recorded in the hook audit log. Run the suites through `tests/run-all-tests.sh`, which gives every test a sandboxed `HOME`.

## Bypass Detection

Silver Bullet detects and blocks:
- Out-of-order skill invocation (finalization before review)
- State file tampering (direct writes to state files are blocked by `dev-cycle-check.sh`; `session-start` validates paths)
- Hook skip attempts (hooks fire on every tool call, not just session start)
- Trivial-mode abuse (agents cannot create the legacy trivial marker — `trivial-file-guard.sh` — and `session-start` deletes stale markers)

The audited escape hatch for orchestrator directives is `SB OVERRIDE: <reason>` in a user message; it is logged to `.planning/orchestrator-override-log.jsonl`.

## Scalability

**Fixed** — this document describes structural layers that change only when enforcement architecture changes. Dual-mode hooks support both composed-workflow projects (`.planning/workflows/<id>.md`) and legacy projects (skill markers). Not append-only.
