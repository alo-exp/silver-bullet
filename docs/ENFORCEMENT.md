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

`stop-check.sh` blocks **only** on the `required_planning` floor — it does **not** require the full `required_deploy` list. This is intentional (v0.30.0 #85): an agent may legitimately end a session mid-implementation as long as the planning floor is recorded. The full `required_deploy` list is enforced by `completion-audit.sh` when an actual delivery command runs. Intermediate commits and pushes need only the planning floor, so execution subagents can commit atomically mid-execution. `hooks/core-rules.md` and `silver-bullet.md` describe the same split — keep all three in sync.

In the `devops-cycle` workflow the `_devops` variants (`required_planning_devops`, `required_deploy_devops`, `required_release_devops`) apply.

### Orchestrator Worker SubagentStop

In orchestrator parent mode, the parent session spawns Task **workers**, each executing one atomic flow. Stop/SubagentStop handling differs by role:

- **Worker on `SubagentStop`** (a hook payload carrying the host's `agent_id`, or `SB_ORCHESTRATOR_WORKER=1`): `stop-check.sh` exits 0 and leaves shared state alone, because other workers may still be running. Workers are **not** individually subjected to the planning-floor or delivery gates — they perform a single flow and return to the parent. Enforcement is the parent's responsibility.
- **Parent on `Stop` with a pending flow queue:** `stop-check.sh` blocks and instructs the parent to spawn the next Task worker for the next flow before ending the session. The parent cannot declare the composition complete while flows remain queued.

This division means the planning-floor and delivery gates are enforced **once, at the parent level**, against the cumulative state the workers contributed — never redundantly on each worker SubagentStop.

## CI Status Gate

`ci-status-check.sh` reads the latest GitHub Actions run for the current branch (`gh run list`); without `gh` it exits quietly.

| Event | Commands | When CI failed or was cancelled |
|-------|----------|---------------------------------|
| PreToolUse | `git push`, `gh pr create`, `gh pr merge`, `gh release create` | Denied |
| PostToolUse | `git commit` | Warning only (the commit already happened; blocking would deadlock CI fixes) |
| PostToolUse | `git push`, `gh pr create/merge`, `gh release create` | Block message |

A `git push` is let through when the latest commit message starts with `fix(ci):` or `ci:` or contains `[ci-fix]`, or when the pushed diff touches `.github/workflows/`, `tests/` or `package.json`. The flag file `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/ci-red-override` disables the gate entirely. Runs that are in progress are informational. Deploy commands are not checked by this hook; `completion-audit.sh` separately requires the release commit to be green before `gh release create`.

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

On `gh release create`, `completion-audit.sh` adds the release gates the project config enables (`release.require_*`, all `true` in the template):

- **Plugin runtime matrix** (`require_plugin_runtime_matrix`) — matching `matrix=` markers from `scripts/run-release-live-matrix.sh`, `tests/e2e-live/run-e2e-live-tests.sh` and the enterprise inline journey in the runtime state dir.
- **Pre-release quality gate** (`require_pre_release_quality_gate`) — the markers `adversarial-review-clean`, `sentinel-skills-clean`, `quality-gate-stage-3` and `full-test-suite-rerun` in the quality-gate state file, plus `scripts/validate-launch-review.sh` and `scripts/validate-sentinel-skills-manifest.sh` when present.
- **RC validation matrix** (`require_rc_matrix`) — the six operator-local markers written by `scripts/run-rc-validation-matrix.sh`.
- **Green CI** on the release commit (always).

The stages behind these markers, and the order to run them in, are described in [RELEASE.md](RELEASE.md). The quality-gate state file is cleared on session start, so markers cannot carry over from an earlier session. The full-suite rerun runs through `verify-tests`, which also writes `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/verify-tests-state` so final delivery can detect stale source changes.

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `SILVER_BULLET_STATE_FILE` | `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/state` | Override the state file path used by all hooks. Intended for testing — lets test suites point hooks at a temp file instead of the real state. Must resolve, after `..` and symlinks, to a path inside `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/` (enforced by every hook that reads it); other paths fall back to the default. |
| `SILVER_BULLET_QUALITY_GATE_STATE_FILE` | `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/quality-gate-state` | Override the release-quality-gate marker file used by `completion-audit.sh` and `session-start`. Intended for testing. Must resolve, after `..` and symlinks, to a path inside `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/`; other paths fall back to the default. |
| `SILVER_BULLET_VERIFY_TESTS_STATE_FILE` | `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/verify-tests-state` | Override the test-execution freshness marker used by `completion-audit.sh`, `dev-cycle-check.sh`, `session-start`, and `/verify-tests`. Intended for testing. Must resolve, after `..` and symlinks, to a path inside `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/`; other paths fall back to the default. |

## Bypass Detection

Silver Bullet detects and blocks:
- Out-of-order skill invocation (finalization before review)
- State file tampering (direct writes to state files are blocked by `dev-cycle-check.sh`; `session-start` validates paths)
- Hook skip attempts (hooks fire on every tool call, not just session start)
- Trivial-mode abuse (agents cannot create the legacy trivial marker — `trivial-file-guard.sh` — and `session-start` deletes stale markers)

The audited escape hatch for orchestrator directives is `SB OVERRIDE: <reason>` in a user message; it is logged to `.planning/orchestrator-override-log.jsonl`.

## Scalability

**Fixed** — this document describes structural layers that change only when enforcement architecture changes. Dual-mode hooks support both composed-workflow projects (`.planning/workflows/<id>.md`) and legacy projects (skill markers). Not append-only.
