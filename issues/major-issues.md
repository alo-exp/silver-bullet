# Silver Bullet — Major Issues Analysis

*Based on exhaustive review of every file in the repository, evaluated against the 10 stated goals.*
*Generated: 2026-04-06 | Silver Bullet v0.9.2*

---

## ISSUE 1: Enforcement Is Invocation-Based, Not Outcome-Based

**Severity: Critical** | **Goals affected: 3, 4, 9, 10**

The entire enforcement architecture checks whether a skill was *called*, never whether it *succeeded* or produced a meaningful result. `record-skill.sh` appends the skill name to the state file the moment the Skill tool fires — before the skill even completes.

**Concrete consequences:**
- Claude can invoke `/quality-gates`, say "all 8 dimensions pass," and move on — no artifact, no hash, no evidence trail validates this
- `/code-review` can be "completed" by calling it and dismissing the output
- `/test-driven-development` can be recorded without a single test being written
- The completion-audit blocks commits until 12 skills are "done," but "done" means "was called once"

**Why this matters for Goal 9 (stopping Claude from skipping):** Claude doesn't need to skip a step — it can *perform the step vacuously* and the hooks will be satisfied. The enforcement prevents skipping the invocation, not skipping the work.

**Status:** [x] Resolved 2026-04-06 (partial) — Three changes: (1) `completion-audit.sh` now checks for GSD artifact existence at final delivery time — if `gsd-execute-phase` is recorded but `.planning/STATE.md` is absent, or `gsd-verify-work` is recorded but `VERIFICATION.md` is absent, an artifact warning is emitted. (2) `silver-bullet.md` §1 updated with an explicit "Enforcement model: invocation-based, not outcome-based" paragraph explaining the limitation. (3) Anti-rationalization language added. Full outcome-based enforcement (verifying content, not just file existence) remains an architectural gap requiring integration with GSD's verification outputs.

---

## ISSUE 2: Two of Seven "Enforcement Layers" Don't Exist

**Severity: Critical** | **Goals affected: 3, 4, 9**

`silver-bullet.md` §1 claims seven enforcement layers. Two are fictional:

- **Layer 5 — "GSD workflow guard"**: Claims to "detect file edits made outside a `/gsd:*` command and warn." No hook in `hooks.json` does this. `dev-cycle-check.sh` checks skill completion state, not whether the current edit is within a GSD execution scope.

- **Layer 6 — "GSD context monitor"**: Claims to "warn at ≤35% tokens remaining, escalate at ≤25%." No hook reads Claude's token usage. `timeout-check.sh` is a wall-clock timer (10 minutes), not a token budget monitor.

Layer 7 ("redundant instructions") is prose in markdown files — not a technical enforcement mechanism.

**Status:** [x] Resolved 2026-04-06 — `silver-bullet.md` and `templates/silver-bullet.md.base` updated: "Seven layers" changed to "Six technical layers plus one documentation layer"; fictional GSD workflow guard (layer 5) and GSD context monitor (layer 6) replaced with accurate descriptions of CI status check (layer 5) and session management (layer 6).

---

## ISSUE 3: The Three Most Critical Hooks Have Zero Tests

**Severity: Critical** | **Goals affected: 3, 4, 10**

| Hook | Lines of Code | Tests | Risk |
|------|:---:|:---:|------|
| `dev-cycle-check.sh` | 252 | **0** | The 4-stage gate that blocks source edits |
| `completion-audit.sh` | 204 | **0** | The commit/push/deploy blocker |
| `record-skill.sh` | 91 | **0** | The single source of truth for all enforcement |

CI runs only 5 static checks (JSON syntax, file permissions, shellcheck). None of the 8 local test scripts are executed in CI. A regression in any enforcement hook would ship undetected.

**Status:** [x] Resolved 2026-04-06 — Created `tests/hooks/test-record-skill.sh` (17 tests), `tests/hooks/test-completion-audit.sh` (19 tests), and `tests/hooks/test-dev-cycle-check.sh` (19 tests). All 55 tests pass. Added "Run hook unit tests" step to `.github/workflows/ci.yml`.

---

## ISSUE 4: GSD Slash Commands Are Invisible to Silver Bullet

**Severity: Critical** | **Goals affected: 1, 3, 4, 9**

`record-skill.sh` fires on the `Skill` tool matcher. GSD commands (`/gsd:discuss-phase`, `/gsd:plan-phase`, `/gsd:execute-phase`, `/gsd:verify-work`, `/gsd:ship`) are slash commands, not Skill tool invocations. Silver Bullet has **no mechanism to detect whether they ran.**

Steps that workflows mark **REQUIRED — DO NOT SKIP** but have zero SB enforcement:

| Step | Workflow Status | Hook Enforcement |
|------|:-:|:-:|
| `/gsd:discuss-phase` | REQUIRED | ❌ None |
| `/gsd:plan-phase` | REQUIRED | ❌ None |
| `/gsd:execute-phase` | REQUIRED | ❌ None |
| `/gsd:verify-work` | REQUIRED | ❌ None |
| `/gsd:ship` | REQUIRED | ❌ None |

**Status:** [x] Resolved 2026-04-06 (partial) — `record-skill.sh` now preserves the `gsd-` prefix for GSD commands (e.g., `gsd:discuss-phase` → `gsd-discuss-phase`) rather than stripping it entirely. 11 GSD phase markers added to the default `all_tracked` list. `compliance-status.sh` now shows a `GSD N/5` counter for the 5 core phases. `completion-audit.sh`'s enforcement tiers still only check SB skills (quality-gates, code-review, etc.), NOT GSD phases — enforcing that `/gsd:discuss-phase` actually ran remains out of scope because SB cannot distinguish "GSD command invoked and produced output" from "GSD command skipped"; the recording only proves invocation, not completion.

---

## ISSUE 5: Intermediate Commits During Execution Are Blocked

**Severity: High** | **Goals affected: 8, 10**

`completion-audit.sh` blocks **any** `git commit` unless all 12 `required_deploy` skills are recorded. But GSD's `/gsd:execute-phase` makes atomic commits during development — long before code-review, testing-strategy, documentation, etc., are done.

This creates a silent deadlock: execution subagents try to commit, completion-audit blocks because the workflow is incomplete. This is the most likely source of mysterious stalls in autonomous mode.

**Status:** [x] Resolved 2026-04-06 — `completion-audit.sh` rewritten with two-tier enforcement: `git commit`/`git push` → only require `required_planning` skills (quality-gates); `gh pr create`/deploy/release → require full `required_deploy` list. GSD execute-phase can now make atomic commits during development.

---

## ISSUE 6: DevOps Workflow Is Under-Enforced

**Severity: High** | **Goals affected: 2, 3**

When `active_workflow` is `devops-cycle`:

- `dev-cycle-check.sh` still defaults to `required_planning="quality-gates"` — doesn't check for `blast-radius` or `devops-quality-gates`
- `completion-audit.sh` doesn't include `blast-radius` in `DEFAULT_REQUIRED`
- `.toml` files are exempted by dev-cycle-check even though silver-bullet.md says NOT exempt in DevOps
- Incident fast path has zero hook enforcement
- Environment promotion (staging → production) has no gate

**Status:** [x] Resolved 2026-04-06 (partial) — Both `dev-cycle-check.sh` and `completion-audit.sh` now read `active_workflow` from config and apply `blast-radius`+`devops-quality-gates` as the default planning requirement when `devops-cycle` is active, instead of `quality-gates`. Incident fast path and environment promotion gating remain out of scope for hook-level enforcement.

---

## ISSUE 7: All Enforcement Fails Open

**Severity: High** | **Goals affected: 3, 9**

Every critical hook has error handling that exits 0 on any unexpected error:

- `completion-audit.sh` line 57: `trap '... exit 0' ERR`
- `dev-cycle-check.sh` line 248-250: `if ! main; then ... exit 0`
- Without jq: all enforcement is silently disabled (only a warning printed)
- Without `gh` CLI: CI status enforcement is silently disabled

**Status:** [x] Resolved 2026-04-06 (partial) — Both hooks now emit visible warning messages when jq is missing rather than silently skipping. The `trap ERR exit 0` behavior is retained for unexpected errors to avoid false blocking in production, but the jq-missing case is now prominently reported. Full fail-closed behavior deferred (would break install experience on systems without jq).

---

## ISSUE 8: Direct State File Manipulation Bypasses Everything

**Severity: High** | **Goals affected: 3, 9**

The state file at `~/.claude/.silver-bullet/state` is a plain text file with one skill name per line. Any bash command can satisfy all enforcement:

```bash
echo "quality-gates" >> ~/.claude/.silver-bullet/state
```

No HMAC, no signature, no tamper detection. Claude could rationalize writing directly to the state file to "fix" a "stuck" workflow.

**Status:** [x] Resolved 2026-04-06 — `dev-cycle-check.sh` (PreToolUse for Edit/Write/Bash) now includes tamper prevention: (1) any Edit/Write tool targeting `~/.claude/.silver-bullet/*` is hard-blocked with a message directing users to reset via terminal, not Claude; (2) Bash commands that write to state/branch/trivial via `>>`, `>`, or `tee` are blocked. Note: HMAC-level cryptographic integrity is not implemented — determined bypasses via `sed -i` or Python remain possible, but the most common rationalization path (Bash echo/printf redirect) is blocked.

---

## ISSUE 9: Autonomous Mode Has No Machine-Backed Anti-Stall

**Severity: High** | **Goals affected: 8, 9**

Autonomous mode stall conditions defined in §4 (repeated tool calls, no state change, per-step budget >10 tool calls) have **no hook backing**. The timeout-check only triggers after 10 wall-clock minutes with a non-blocking warning. Claude can loop indefinitely without any machine intervention.

**Status:** [x] Resolved 2026-04-06 — `timeout-check.sh` enhanced with two-tier anti-stall protection: Tier 1 (existing wall-clock) unchanged; Tier 2 (new call-count) tracks tool calls since last skill was recorded and emits escalating warnings at 30 calls (light check-in), 60 calls (stall warning with instructions), and 100+ calls (STALL DETECTED with specific actions). The state file mod time is compared each call to detect when skills are recorded and reset the baseline. This catches tight loops that wall-clock time misses.

---

## ISSUE 10: Skill Ordering Is Not Enforced

**Severity: Medium** | **Goals affected: 4**

Hooks check presence/absence of skills, never sequence. The workflow documents strict ordering; the hooks enforce a loose set. Notable: `/receiving-code-review` can be recorded before `/requesting-code-review`; `/tech-debt` before any code exists; `/create-release` doesn't require `/deploy-checklist` first in terms of ordering.

**Status:** [x] Resolved 2026-04-06 (partial) — `completion-audit.sh` now enforces code review triad ordering at PR/deploy time: `code-review` must precede `requesting-code-review`, which must precede `receiving-code-review`. Wrong order triggers a blocking warning. Full sequential ordering for all skills remains deferred.

---

## ISSUE 11: Cross-Session State Persistence Creates False Confidence

**Severity: Medium** | **Goals affected: 4, 10**

`session-start` resets only `quality-gate-stage-*` and `gsd-*` markers but **preserves all skill recordings**. Skills from Session 1 satisfy enforcement checks in Session 2 for a completely different feature/branch.

**Status:** [x] Resolved 2026-04-06 — `hooks/session-start` now stores current git branch in `~/.claude/.silver-bullet/branch`. On session start: branch changed → full state reset (rm state file, update branch file); same branch → only session-specific markers cleared (quality-gate-stage-* and gsd-*). Skill recordings now correctly scoped to one branch/feature.

---

## ISSUE 12: Documentation Inconsistencies Undermine Credibility

**Severity: Medium** | **Goals affected: 6**

| Issue | Location | Problem |
|-------|----------|---------|
| `all_tracked` count | README line 291 | Says "17 skills" — actual array has 31 |
| Compare hero pill | `site/compare/index.html` | Says "11 Categories" — has 12 |
| `required_deploy` description | README line 290 | Lists 8 skills — config block shows 11 |
| Config file naming | `site/compare/index.html` | References `silver-bullet.config.json` — actual name is `.silver-bullet.json` |
| Compare scoring | Multiple | GSD scored 0/8 on enforcement despite providing 2 of SB's 7 "layers" |
| "Practically impossible" | `site/index.html` line 1121 | Bypass requires one `touch` command |

**Status:** [x] Resolved 2026-04-06 — Fixed: (1) README `all_tracked` count 17→31, (2) README `required_deploy` updated to list all 12 skills with two-tier enforcement note, (3) compare page "11 Categories"→"12 Categories", (4) compare page config filename `silver-bullet.config.json`→`.silver-bullet.json`, (5) all "seven-layer" claims updated to "six-layer technical plus documentation layer" across `site/index.html` and `site/compare/index.html`, (6) "practically impossible" changed to "extremely difficult to bypass by accident", (7) fictional layers 5 & 6 replaced with CI Status Check and Session Management in `site/index.html`.

---

## ISSUE 13: `finishing-a-development-branch` Conflict on Main

**Severity: Medium** | **Goals affected: 4**

User memory says "Don't invoke finishing-a-development-branch when current branch is main." But `completion-audit.sh` requires it in `DEFAULT_REQUIRED`. This creates a deadlock: working on main, completion-audit blocks commits because `finishing-a-development-branch` can never be satisfied.

**Status:** [x] Resolved 2026-04-06 — `completion-audit.sh` now detects current git branch via `git rev-parse --abbrev-ref HEAD`. When on `main` or `master`: `finishing-a-development-branch` is removed from `DEFAULT_REQUIRED`, config-supplied `required_deploy`, and the mandatory skills set. The 19-test suite covers this with Test 11.

---

## ISSUE 14: Small Edit Bypass Allows Incremental Source Changes

**Severity: Medium** | **Goals affected: 3, 9**

`dev-cycle-check.sh` bypasses enforcement for edits where `old_string + new_string < 300 chars`. Source code can be changed in 299-char increments repeatedly without triggering any gate. A significant refactor could bypass enforcement entirely.

**Status:** [x] Resolved 2026-04-06 — Threshold reduced from 300 to 100 chars combined (old_string + new_string). This covers typo fixes and single-variable renames while enforcing gates on all meaningful edits. `silver-bullet.md` updated to reflect the new threshold.

---

## ISSUE 15: No SDLC Coverage Beyond Ship

**Severity: Medium (Critical for long-term vision)** | **Goals affected: 1, 5**

The workflow ends at `/gsd:ship`. The SDLC gap analysis identifies 4 Critical and 4 High gaps:
- Post-deployment observability (no monitoring setup)
- Security testing (SAST/SCA/secrets scanning — design checklist ≠ scanner)
- Test execution gate (strategy document ≠ tests passing)
- Requirements/discovery (AI-inferred ≠ validated)
- Release management (PR ≠ release with versioning/changelog)
- Incident→fix feedback loop
- Performance testing
- CI/CD scaffolding

**Status:** [x] Resolved 2026-04-06 — Created `docs/SDLC-Coverage-Roadmap.md` with 7 numbered milestones (v0.11–v0.17) mapping each gap to a concrete implementation plan, effort estimate, and success criterion. Milestones: (1) Test Execution Gate, (2) Security Scanner Integration, (3) Post-Deployment Observability, (4) Requirements Validation Gate, (5) Release Management, (6) Incident→Fix Feedback Loop, (7) Feedback & Iteration Loop. Includes Long-Term Vision for v1.0 artifact-based enforcement.

---

## Priority Order for Resolution

1. Issue 5 — Intermediate commit blocking (breaks autonomous mode)
2. Issue 2 — Fictional enforcement layers (accuracy fix)
3. Issue 13 — main branch deadlock (usability fix)
4. Issue 12 — Documentation inconsistencies (credibility)
5. Issue 3 — Add critical hook tests to CI (reliability)
6. Issue 6 — DevOps enforcement gaps (completeness)
7. Issue 11 — Cross-session state (correctness)
8. Issue 10 — Ordering enforcement (quality)
9. Issue 14 — Small edit bypass tightening (security)
10. Issue 7 — Fail-open to fail-closed where possible (resilience)
11. Issue 8 — State file tamper detection (integrity)
12. Issue 4 — GSD command visibility (architecture)
13. Issue 9 — Autonomous mode anti-stall (reliability)
14. Issue 1 — Outcome-based enforcement (architecture)
15. Issue 15 — SDLC coverage expansion (roadmap)
