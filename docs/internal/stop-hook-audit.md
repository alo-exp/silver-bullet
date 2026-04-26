# Stop Hook Audit: `hooks/stop-check.sh`

**Phase**: 63 — Stop Hook Audit (v0.27.0)
**Date**: 2026-04-26
**Auditor**: Phase 63 executor
**Requirement**: HK-01 (GitHub #71)

---

## Overview

`hooks/stop-check.sh` fires on every `Stop` and `SubagentStop` event — when Claude
declares a task complete. It blocks completion if the required deployment skills have
not been invoked during the session.

This document enumerates every known bail-out path (scenarios where the hook exits 0
without enforcing), distinguishes deliberate fail-opens from confirmed false-positives,
provides reproduction steps for each, and records the disposition of each finding.

The hook fires in a layered order: the first matching gate wins and exits 0. Scenarios
are numbered in firing order.

---

## Scenario Catalogue

### S-01: jq Missing

| Attribute | Value |
|-----------|-------|
| Trigger condition | `jq` is not installed or not on PATH |
| Hook lines | 26–31 |
| Test coverage | None (hard to test portably without removing jq) |
| Severity | MEDIUM — all enforcement disabled while jq is absent |
| Disposition | **Documented** — correct fail-open by design |

**Reproduction steps:**

1. Remove `jq` from PATH (e.g. `PATH= bash hooks/stop-check.sh`).
2. Send a Stop event.
3. Hook exits 0 and prints a visible warning via `hookSpecificOutput`.

**Rationale:**
Without `jq`, the hook cannot parse `.silver-bullet.json` to read required skill lists
or file paths. Blocking on a parse failure would create a permanent, unrecoverable gate.
The warning is surfaced via `hookSpecificOutput` so the user sees enforcement is off.

---

### S-02: No `.silver-bullet.json` Config

| Attribute | Value |
|-----------|-------|
| Trigger condition | No `.silver-bullet.json` found walking up from `$PWD` |
| Hook lines | 43–58 |
| Test coverage | Test 1 |
| Severity | LOW — correct for projects not using Silver Bullet |
| Disposition | **Documented** — correct fail-open by design |

**Reproduction steps:**

1. Run the hook from any directory that has no `.silver-bullet.json` up to `$HOME` or
   the nearest `.git` boundary.
2. Hook exits 0 silently.

**Rationale:**
Silver Bullet is an opt-in plugin. Projects without a config file are not enrolled in
enforcement. Blocking would break non-SB projects that happen to have the hook installed
globally.

---

### S-03: Trivial Bypass

| Attribute | Value |
|-----------|-------|
| Trigger condition | Trivial file (`~/.claude/.silver-bullet/trivial`) exists and is a regular file (not a symlink) |
| Hook lines | 103–107 (via `lib/trivial-bypass.sh`) |
| Test coverage | Test 4 |
| Severity | MEDIUM — bypasses enforcement for the whole session |
| Disposition | **Documented** — correct by design; lifecycle is managed automatically |

**Reproduction steps:**

1. Create `~/.claude/.silver-bullet/trivial` (regular file).
2. Send a Stop event with skills missing from state.
3. Hook exits 0 via `sb_trivial_bypass`.

**Rationale:**
Sessions that make no code edits (Q&A, research, config reads) should not be blocked
for missing deploy skills. `session-start` creates the trivial file at session start.
The first `PostToolUse/Write|Edit` removes it, marking the session as a dev session.
After that removal, subsequent Stop events enforce normally.

**Edge case**: If `session-start` does not run (e.g., context compaction mid-session
restarts a subshell), the trivial file may persist beyond its intended lifetime and
suppress enforcement for a genuine dev session. Mitigated in practice because
`PostToolUse/Write|Edit` removes it on the first file modification.

---

### S-04: HOOK-14 — Clean Tree + Upstream at HEAD

| Attribute | Value |
|-----------|-------|
| Trigger condition | Inside git repo; `git status` shows no output; upstream is configured and 0 commits ahead |
| Hook lines | 164–174 |
| Test coverage | Test 7b |
| Severity | LOW — correct behavior |
| Disposition | **Documented** — correct fail-open by design |

**Reproduction steps:**

1. Be on a branch with a configured upstream (e.g., `origin/main`).
2. Ensure `git status --porcelain --untracked-files=all --ignored=traditional` returns empty.
3. Ensure `git rev-list --count origin/main..HEAD` returns `0`.
4. Send a Stop event with skills missing.
5. Hook exits 0 — nothing to deploy.

**Rationale:**
A session where no commits have been pushed ahead of the remote has nothing to deploy.
This is the primary read-only / conversational session detection. Fail-open is correct:
enforcing on a session that produced no deployable change would block helpdesk and
research sessions.

---

### S-05: HOOK-14 — Clean Tree + Named Branch + No Remote

| Attribute | Value |
|-----------|-------|
| Trigger condition | Inside git repo; clean tree; named branch (not detached); no upstream configured; no `origin/main` or `origin/master` ref |
| Hook lines | 177–184 |
| Test coverage | Test 7 |
| Severity | LOW — correct behavior |
| Disposition | **Documented** — correct fail-open by design |

**Reproduction steps:**

1. Clone or init a repo with no remote configured.
2. Be on a named branch (e.g., `feature/x`) with a clean working tree.
3. Send a Stop event with skills missing.
4. Hook exits 0 — no trusted anchor, nowhere to deploy.

**Rationale:**
Without a remote anchor (`origin/main`, `origin/master`, or a configured upstream),
there is no deployment target. Local-only `main`/`master` are explicitly NOT used as
anchors (they may have been reset by the user and are not a reliable baseline —
HOOK-06 / issue #17 finding #4). Fail-open is correct.

---

### S-06: Detached HEAD — Misleading Comment (Code Is Correct)

| Attribute | Value |
|-----------|-------|
| Trigger condition | Git repo in detached HEAD state; clean tree; no remote anchor |
| Hook lines | 177–188 |
| Test coverage | Test 15 (added in this phase) |
| Severity | LOW — code behavior is correct; comment was misleading |
| Disposition | **Fixed** — misleading comment corrected; regression test added |

**Reproduction steps (pre-fix — showed comment/behavior mismatch):**

1. Enter detached HEAD state: `git checkout --detach HEAD`.
2. Ensure a clean working tree and no remote anchor configured.
3. Send a Stop event.
4. Hook exits 0 — via the `elif [[ -n "$current_branch" ]]` branch.

**Root cause:**
The comment at lines 186–188 claimed "detached-HEAD state. Fall through to enforcement."
In reality, `git rev-parse --abbrev-ref HEAD` returns `"HEAD"` (not an empty string)
when in detached HEAD state. `"HEAD"` passes the safety validation regex
`^[a-zA-Z0-9/_.-]+$`, so `current_branch="HEAD"` (non-empty). The
`elif [[ -n "$current_branch" ]]; then exit 0` branch fires and the hook **exits 0**
(no block). The code is correct; the comment was wrong.

The fall-through to enforcement in this code block only occurs when `current_branch`
is genuinely empty — which happens only if `git rev-parse --abbrev-ref HEAD` fails
outright (unexpected in a valid git repo with commits).

**Fix applied**: Comment updated to reflect actual behavior. Test 15 added to lock in
the correct exit-0 behavior for detached HEAD + clean tree + no remote.

---

### S-07: HOOK-14 — Upstream Configured but Ref Unresolvable

| Attribute | Value |
|-----------|-------|
| Trigger condition | Branch has `branch.<name>.remote` configured in `.git/config`; the upstream ref does not resolve (pruned or renamed remote branch) |
| Hook lines | 142–163 (`upstream_broken=true` path) |
| Test coverage | Test 11 |
| Severity | LOW — correct fail-closed behavior |
| Disposition | **Documented** — correct fail-closed by design |

**Reproduction steps:**

1. Configure a branch with a remote that no longer resolves:
   `git config branch.feature/test.remote origin`
   `git config branch.feature/test.merge refs/heads/does-not-exist`
2. Send a Stop event with skills missing.
3. Hook falls through to enforcement (blocks).

**Rationale:**
When a branch explicitly has an upstream configured but the upstream ref no longer
exists (remote branch deleted after a merge), the hook cannot prove "nothing to deploy."
Failing closed here prevents a silent enforcement bypass for sessions that have real
changes against a pruned upstream. This is the `HOOK-06 / #17` hardening.

---

### S-08: HOOK-04 — Empty State File

| Attribute | Value |
|-----------|-------|
| Trigger condition | State file does not exist or is empty (no skills recorded this session) |
| Hook lines | 192–198 |
| Test coverage | Test 6 |
| Severity | LOW — correct behavior |
| Disposition | **Documented** — correct fail-open by design |

**Reproduction steps:**

1. Delete or empty the state file (`~/.claude/.silver-bullet/state`).
2. Send a Stop event.
3. Hook exits 0 — non-dev session detected.

**Rationale:**
A session with no recorded skills never invoked any workflow tooling. This identifies
pure conversational or read-only sessions where no productive work requiring deploy
gates was performed. Blocking an empty-state session would prevent users from closing
any Claude session that happened to fire the Stop hook.

---

### S-09: Branch-Scope Mismatch

| Attribute | Value |
|-----------|-------|
| Trigger condition | The branch name stored in `~/.claude/.silver-bullet/branch` differs from the current git branch |
| Hook lines | 200–219 |
| Test coverage | Test 14 |
| Severity | MEDIUM — can fail-open for cross-worktree contamination |
| Disposition | **Documented** — intentional fail-open by design |

**Reproduction steps:**

1. Set the branch file to a different branch:
   `printf 'phase/10-other-project\n' > ~/.claude/.silver-bullet/branch`
2. Run from a repo on `feature/test`.
3. Send a Stop event with skills missing.
4. Hook exits 0 — stale state treated as not applicable to current branch.

**Rationale:**
State is branch-scoped: `session-start` resets it when the branch changes. If the
branch file diverges from the current branch (parallel sessions, resumed sessions,
worktree switching), the stored skills are stale and must not gate the current branch.
Enforcing against another branch's skills would block legitimate work. Fail-open is
correct here; the cost is a potential missed enforcement on a branch that somehow lost
its branch-file synchronisation.

---

### S-10: Subagent Sessions (SubagentStop Event)

| Attribute | Value |
|-----------|-------|
| Trigger condition | GSD subagent spawned via Agent tool with `isolation: "worktree"`; `SubagentStop` fires at subagent completion |
| Hook lines | All layers; typically exits via S-08 (empty state) or S-03 (trivial bypass) |
| Test coverage | None explicitly for SubagentStop |
| Severity | LOW — handled by two independent bail-out layers |
| Disposition | **Documented** — correct behavior; no fix required |

**How subagents exit 0:**

- **S-03 (Trivial bypass)**: `session-start` creates the trivial file at the start of
  each session/worktree context. If the subagent makes no file edits, the trivial file
  persists and the hook exits 0.
- **S-08 (Empty state)**: GSD subagents start with a fresh worktree context. Their
  state file is branch-scoped and begins empty. Even after file edits remove the
  trivial file, the state file contains only skills invoked *within the subagent* —
  never the parent session's full required-deploy list. HOOK-04 exits 0 on the empty
  or near-empty state.

**Rationale:**
Subagents execute specific plans (file edits, commits) and are not expected to run
the full deploy-skill workflow. Blocking SubagentStop for missing deploy skills would
permanently prevent GSD execution in Silver Bullet–enrolled projects.

---

### S-11: DevOps Cycle Workflow Substitution

| Attribute | Value |
|-----------|-------|
| Trigger condition | `.silver-bullet.json` has `active_workflow: "devops-cycle"` |
| Hook lines | 234–236 |
| Test coverage | None explicitly for devops-cycle substitution |
| Severity | LOW — correct behavior |
| Disposition | **Documented** — correct by design |

**Reproduction steps:**

1. Set `active_workflow: "devops-cycle"` in `.silver-bullet.json`.
2. Send a Stop event.
3. Hook uses `DEVOPS_DEFAULT_REQUIRED` instead of `DEFAULT_REQUIRED`.
   `silver-blast-radius` and `devops-quality-gates` replace `silver-quality-gates`.

**Rationale:**
Infrastructure workflows require blast-radius assessment and DevOps-specific quality
gates that are not relevant to application development sessions. The substitution is
intentional; both lists contain the same deploy, review, and verification skills.

---

### S-12: Phantom Required Skills (Permanent False-Positive)

| Attribute | Value |
|-----------|-------|
| Trigger condition | `required_deploy` in `.silver-bullet.json` / `templates/silver-bullet.config.json.default` lists skill names for which no `SKILL.md` file exists in any installed plugin |
| Hook lines | 268–273 (skills check loop) |
| Test coverage | None — phantom skills cannot be invoked |
| Severity | HIGH — hook permanently blocks until phantom skills are removed from config or their SKILL.md files are created |
| Disposition | **Deferred** — config cleanup required in a follow-up phase |

**Reproduction steps:**

1. Inspect `templates/silver-bullet.config.json.default` → `skills.required_deploy`.
2. For each skill name, search for a matching `SKILL.md`:
   `find ~/.claude/plugins/cache -name "SKILL.md" | xargs grep -l "^name: <skill>"`
3. Skills with no matching `SKILL.md` are phantom entries. They can never be recorded
   in the state file and will always appear as "missing" in the skills check.
4. Invoke all real skills, then trigger a Stop event — phantom skills still block.

**Known phantom skills (as of v0.27.0):**
`code-review`, `testing-strategy`, `documentation`, `deploy-checklist`, `tech-debt`

**Root cause:**
These skill names were added to the canonical required list as aspirational entries
before their corresponding `SKILL.md` files were written. Because `record-skill.sh`
can only record invocations of real skills, phantom entries create a permanent
enforcement gap: the stop hook always fires with these skills listed as missing.

**Remediation options (deferred):**
- Option A: Remove phantom entries from `required_deploy` in both
  `templates/silver-bullet.config.json.default` and `.silver-bullet.json`.
- Option B: Create `SKILL.md` files for each phantom skill in the silver-bullet plugin.

---

## Summary Table

| ID | Scenario | Severity | Disposition |
|----|----------|----------|-------------|
| S-01 | jq missing | MEDIUM | Documented — correct fail-open by design |
| S-02 | No `.silver-bullet.json` config | LOW | Documented — correct fail-open by design |
| S-03 | Trivial bypass | MEDIUM | Documented — auto-lifecycle managed |
| S-04 | HOOK-14: clean tree + upstream at HEAD | LOW | Documented — correct fail-open by design |
| S-05 | HOOK-14: clean tree + named branch + no remote | LOW | Documented — correct fail-open by design |
| S-06 | Detached HEAD: misleading comment | LOW | **Fixed** — comment corrected; Test 15 added |
| S-07 | HOOK-14: upstream configured but unresolvable | LOW | Documented — correct fail-closed by design |
| S-08 | HOOK-04: empty state file | LOW | Documented — correct fail-open by design |
| S-09 | Branch-scope mismatch | MEDIUM | Documented — intentional fail-open |
| S-10 | Subagent sessions (SubagentStop) | LOW | Documented — handled by S-03 / S-08 |
| S-11 | DevOps cycle workflow substitution | LOW | Documented — correct by design |
| S-12 | Phantom required skills | HIGH | **Deferred** — config cleanup needed |

---

## References

- `hooks/stop-check.sh` — the audited hook; bail-out paths correspond to scenarios above
- `tests/hooks/test-stop-check.sh` — unit tests; Test 15 added for S-06 regression
- `hooks/lib/trivial-bypass.sh` — shared trivial-session bypass guard (S-03)
- `hooks/lib/required-skills.sh` — canonical required skill list reader (S-12 source)
- `templates/silver-bullet.config.json.default` — source of truth for required_deploy (S-12)
- GitHub issue #71 — HK-01 requirement for this audit
