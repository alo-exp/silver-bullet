# Troubleshooting

Common problems with Silver Bullet in a project, and how to fix them. The help center has a longer, user-oriented version at [sb.alolabs.dev/help/troubleshooting/](https://sb.alolabs.dev/help/troubleshooting/) (source: `site/help/troubleshooting/index.html`), including recovery from failed sessions and missing optional skills.

## Start here

```bash
bash scripts/sb-doctor.sh            # install + project activation audit; exits non-zero on any FAIL
bash scripts/sb-doctor.sh --dry-run  # what --fix would change; --fix=local|host|packages|all applies it
bash scripts/sb-diagnostics.sh       # capability tier, hook config, jq, Graphify, package version
SB_DIAG_FORMAT=json bash scripts/sb-diagnostics.sh
bash scripts/sb-bootstrap.sh         # onboarding probe with next steps
```

In a host session, `/sb:doctor` runs the same audit. Neither script takes a runtime argument: the runtime is detected, or forced with `SILVER_BULLET_RUNTIME=claude|codex|cursor`.

Runtime state lives in `${SB_RUNTIME_STATE_DIR}` — `~/.claude/.silver-bullet/`, `~/.codex/.silver-bullet/` or `~/.cursor/.silver-bullet/` depending on the host ([RUNTIME-COMPATIBILITY.md](RUNTIME-COMPATIBILITY.md)). The paths below use that directory.

## Hooks do not fire

| Cause | Fix |
|-------|-----|
| The project is not initialized. Hooks stay inert until **both** `.silver-bullet.json` and `silver-bullet.md` exist at the project root (`hooks/lib/sb-project-gate.sh`); some gates also need `"sb_initiated": true` | Run `/sb:init` in the project root, then `bash scripts/sb-diagnostics.sh` |
| Cursor hooks were not merged into `~/.cursor/hooks.json`, or point at an old checkout | `bash scripts/install-cursor.sh --public-release`, then re-run diagnostics; expect tier 2 (hook-enforced) |
| The host session has no hook delivery (capability tier 0) or skills are read rather than invoked (tier 1) | Install from your host's marketplace, run `/sb:init`, and invoke skills through `/sb` or the Skill tool (on Codex: `silver-bullet invoke-skill <name>`) |
| Hook scripts lost their executable bit (some filesystems or archive tools) | `chmod +x hooks/*.sh hooks/session-start` in the installed plugin directory |

## `jq` is missing

Every hook reads JSON with `jq`. Without it `session-start` prints "Silver Bullet DISABLED — jq is required" and most hooks exit 0, **but** the core gates block instead of failing open: in an initiated project `completion-audit.sh`, `dev-cycle-check.sh`, `forbidden-skill-check.sh`, `planning-file-guard.sh`, `uat-gate.sh` and `workflow-chain-guard.sh` deny their commands, and `completion-audit.sh` blocks commit, push, PR, release and deploy commands even outside an SB project. Install it: `brew install jq` (macOS) or `sudo apt install jq` (Linux). Several hooks and the diagnostics also need `python3`.

## A gate blocks your work

| Message | Meaning and fix |
|---------|-----------------|
| `HARD STOP` from the stage enforcer (`dev-cycle-check.sh`) | Source edits need the planning floor (`skills.required_planning`, default `sb:quality-gates`, `sb:context`, `sb:plan`; for DevOps work `sb:blast-radius` and `devops-quality-gates` first). Run the missing skills, or route a genuinely small change through `/sb:fast`. Check `project.src_pattern` if the file should not count as source |
| `COMMIT BLOCKED — Planning incomplete` on `git commit` / `git push` | The same planning floor is missing |
| `PLAN SEAL BLOCKED` | A plan/phase completion commit needs `/sb:completion-audit` and `/sb:verify` (with a `VERIFICATION.md`) recorded this session |
| `COMPLETION BLOCKED` on `gh pr create`, `gh pr merge`, deploy or `gh release create` | The final delivery floor (`skills.required_deploy`) is incomplete; the message lists the missing skills. Run them, or ask `/sb` for the next step. `WORKFLOW GATE`, `ORDERING BLOCKED` and `ARTIFACT BLOCKED` are variants for composed workflows, skill order and missing artifacts |
| `ENTERPRISE POLICY BLOCK` on a PR, release or deploy | The active enterprise profile requires a human to approve production delivery. After you sign off, create the marker yourself, outside the agent session: `touch "${SB_RUNTIME_STATE_DIR}/enterprise-human-deploy-approved"`. See [ENFORCEMENT.md](ENFORCEMENT.md#enterprise-policy-delivery-block) |
| `TEST GATE STALE` | `/verify-tests` ran earlier but a later source edit removed its freshness marker. Re-run `/verify-tests` |
| `RELEASE BLOCKED` | A release gate is unmet (live matrices, quality-gate markers, RC matrix, CI on the release commit). See [RELEASE.md](RELEASE.md) and [ENFORCEMENT.md](ENFORCEMENT.md#release-gates) |
| `ORCHESTRATOR DIRECTIVE` | Parent mode expects the named skill (or a Task worker) before other tools. Invoke it; if it truly cannot be satisfied, reply with `SB OVERRIDE: <reason>` — the override is logged to `.planning/orchestrator-override-log.jsonl` |
| A Stop is blocked | `stop-check.sh` and the other Stop gates (outcomes, instruction ledger, worker audit, site sessions) name what is open. Ending a session needs only the planning floor; delivery needs the full list |

Commits work but PRs and releases are blocked: that is the two-tier model working as designed ([ENFORCEMENT.md](ENFORCEMENT.md#two-tier-model)).

## CI is red

`ci-status-check.sh` reads the latest GitHub Actions run on the branch and blocks `git push`, `gh pr create/merge` and `gh release create` while it failed or was cancelled; after a `git commit` it only warns, so you can always commit the fix. To push the fix, use one of:

- start the commit message with `fix(ci):` or `ci:`, or include `[ci-fix]`;
- push a change that touches `.github/workflows/`, `tests/` or `package.json` (treated as a suspected CI fix);
- as a last resort, `touch "${SB_RUNTIME_STATE_DIR}/ci-red-override"` (remove it once CI is green).

Then investigate with `gh run list --limit 3` and `gh run view <run-id> --log-failed`, or `/sb:debug`. If CI is actually green but the gate disagrees, check that `gh` is installed and authenticated (`gh auth status`). Without `gh` the CI check is skipped, but `gh release create` stays blocked because the release gate cannot verify CI.

## Progress or state looks wrong

- **State is branch-scoped.** Skill markers live in `${SB_RUNTIME_STATE_DIR}/state` and are cleared when the git branch or worktree changes between sessions; switching branches means re-running that branch's workflow.
- **Stale state.** Deleting `${SB_RUNTIME_STATE_DIR}/state` resets recorded skills; it is recreated on the next skill invocation.
- **Legacy trivial marker.** `${SB_RUNTIME_STATE_DIR}/trivial` used to bypass the gates. `session-start` deletes it, any file write clears it, and agents are blocked from creating it; use `/sb:fast` for small changes.
- **Session logs** in `docs/sessions/` and `/sb:forensics` reconstruct what happened in an interrupted or failed session.

## Configuration problems

| Symptom | Fix |
|---------|-----|
| The wrong files trigger enforcement | Adjust `project.src_pattern` (default `/src/`) and `project.src_exclude_pattern` (default `__tests__|\.test\.`) |
| Old skill names or an old `config_version` | Run `/sb:update`, or `bash scripts/sb-migrate-config.sh` to merge the config forward from the template; `sb-doctor.sh` reports a stale `config_version` |
| An opt-in tool gate blocks (Graphify, agentmemory, RTK, Context Mode, LeanCTX, Alumnium) | Install and wire the tool, or set its `recommended_tools.<tool>.enabled_by_user` to `false` |

[CONFIGURATION.md](CONFIGURATION.md) describes every key.

## Debugging hooks

- **Payload dump.** Create the flag file `${SB_RUNTIME_STATE_DIR}/debug-dump` and every PreToolUse payload is appended to `${SB_RUNTIME_STATE_DIR}/hook-dump.jsonl` by `hooks/debug-dump.sh`. Delete the flag when done; the dump can contain prompts and file contents.
- **Hook audit log.** Create `${SB_RUNTIME_STATE_DIR}/hook-audit-enabled` (or export `SILVER_BULLET_HOOK_AUDIT_LOG` to a path inside the state dir) and gates that support it record their allow/deny decisions to `hook-audit.jsonl` (`hooks/lib/hook-audit.sh`).
- **Run a hook by hand.** Pipe a payload into it from the project directory, for example `printf '%s' '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git push"}}' | bash hooks/ci-status-check.sh`.
- [HOOKS.md](HOOKS.md) lists every hook with its event, matcher and timeout.
