# Silver Bullet Enforcement Techniques Reference

> **Standalone reference.** A reader who has never seen Silver Bullet before should
> understand its entire enforcement model from this document.

---

## 1. Introduction

Silver Bullet is a Claude Code plugin that enforces a disciplined software development
lifecycle. It installs a set of Claude Code hooks, a project configuration file, and
workflow skill definitions that collectively prevent Claude from skipping planning, code
review, testing, documentation, and other mandatory workflow phases before committing,
creating pull requests, or declaring a task complete.

### Why Enforcement Matters for AI-Native Development

Large language models have three failure modes that naive prompt-based enforcement cannot
fix:

1. **Step skipping under pressure.** When a user says "just write the code," an LLM will
   skip planning, tests, and documentation unless a mechanical gate blocks it.
2. **Rationalization.** LLMs construct plausible-sounding reasons for skipping steps
   ("the tests are obvious," "the documentation was implicit"). Rules stated once in a
   prompt do not prevent this.
3. **Context loss.** After `/compact` or across sessions, instructions stated only in the
   conversation are lost. Rules embedded in hooks and config files survive compaction.

Silver Bullet addresses all three with multiple overlapping layers: invocation-based skill
recording, stage gates that block tool use, a Stop hook that blocks task completion, a
UserPromptSubmit hook that re-injects reminders before every prompt, and anti-
rationalization language in the workflow instructions.

---

## 2. The AI-Native SDLC Playbook Taxonomy (Tiers 1–11)

The AI-Native SDLC Playbook defines 11 tiers of enforcement technique, from weakest to
strongest. The table below shows Silver Bullet's implementation status for each tier.

| Tier | Technique | SB Status | SB Implementation |
|------|-----------|-----------|-------------------|
| 1 | CLAUDE.md / system prompt | Implemented | `silver-bullet.md` (sections 0–9) injected into every project via `/using-silver-bullet` |
| 2 | `.claude/rules/` scoped rules | Deferred | Hooks compensate; scoped rules add marginal value for SB's flat structure |
| 3 | Hooks (PreToolUse, PostToolUse, Stop, UserPromptSubmit, SessionStart) | Implemented | 11 hooks registered in `hooks/hooks.json` across 5 event types |
| 4 | Recursive rule echo (self-reinforcing CLAUDE.md) | Deferred | Hooks fire on every relevant tool use, compensating adequately |
| 5 | Redundant encoding (multiple files state same rules) | Implemented | `silver-bullet.md` + `CLAUDE.md` + workflow files all enforce the same constraints |
| 6 | Separate instruction file (CLAUDE.local.md) | N/A | `silver-bullet.md` achieves the same separation from project-specific CLAUDE.md |
| 7 | Anti-rationalization language | Implemented | Explicit "Anti-Skip" blocks in `silver-bullet.md` and workflow files name the violation pattern |
| 8 | compactPrompt override | Implemented | `.silver-bullet.json` `compactPrompt` key tells the compaction LLM to preserve rules verbatim |
| 9 | Plan Mode enforcement | Deferred | GSD planning phases (via `gsd-*` skill markers) compensate |
| 10 | Stop hook (completion gate) | Implemented | `hooks/stop-check.sh` — blocks final response if required skills missing |
| 11 | UserPromptSubmit (context re-injection) | Implemented | `hooks/prompt-reminder.sh` — injects compact reminder before every user prompt |

**Tier coverage:** Tiers 1, 3, 5, 7, 8, 10, and 11 are fully implemented. Tiers 2, 4,
and 9 are deferred (hooks compensate). Tier 6 is N/A.

---

## 3. Silver Bullet's Defense-in-Depth Stack

Each layer reinforces the layers inside it. A workflow step must survive all outer layers
before reaching Claude's execution.

```
┌───────────────────────────────────────────────────────────────────┐
│  [UserPromptSubmit]  prompt-reminder.sh                           │
│  Re-injects missing-skills reminder before EVERY user prompt.     │
│  Survives /compact — hook fires regardless of context state.      │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │  [SessionStart]  session-start                              │  │
│  │  Resets branch state on branch change.                      │  │
│  │  Injects "superpowers" context for autonomous mode.         │  │
│  │                                                             │  │
│  │  ┌───────────────────────────────────────────────────────┐  │  │
│  │  │  silver-bullet.md  (documentation layer)              │  │  │
│  │  │  Rules, anti-skip blocks, anti-rationalization text,  │  │  │
│  │  │  workflow ordering constraints.                        │  │  │
│  │  │                                                        │  │  │
│  │  │  ┌──────────────────────────────────────────────────┐ │  │  │
│  │  │  │  [PreToolUse]                                     │ │  │  │
│  │  │  │  • dev-cycle-check.sh  (Edit|Write|Bash)          │ │  │  │
│  │  │  │    Stage gate: HARD STOP if planning incomplete   │ │  │  │
│  │  │  │    Hook self-protection: blocks edits to hooks/   │ │  │  │
│  │  │  │    State tamper prevention                        │ │  │  │
│  │  │  │    Plugin boundary protection                     │ │  │  │
│  │  │  │  • completion-audit.sh  (Bash)                    │ │  │  │
│  │  │  │    Commit gate / PR+deploy gate                   │ │  │  │
│  │  │  │  • ci-status-check.sh  (Bash)                     │ │  │  │
│  │  │  │    Blocks commits when CI is failing              │ │  │  │
│  │  │  │                                                   │ │  │  │
│  │  │  │  ╔══════════════════════════════════════════════╗ │ │  │  │
│  │  │  │  ║          Claude executes tool                ║ │ │  │  │
│  │  │  │  ╚══════════════════════════════════════════════╝ │ │  │  │
│  │  │  │                                                   │ │  │  │
│  │  │  │  [PostToolUse]                                    │ │  │  │
│  │  │  │  • record-skill.sh     (Skill)                    │ │  │  │
│  │  │  │  • semantic-compress.sh (Skill)                   │ │  │  │
│  │  │  │  • dev-cycle-check.sh  (Edit|Write|Bash)          │ │  │  │
│  │  │  │  • completion-audit.sh  (Bash)                    │ │  │  │
│  │  │  │  • ci-status-check.sh  (Bash)                     │ │  │  │
│  │  │  │  • compliance-status.sh (all)                     │ │  │  │
│  │  │  │  • session-log-init.sh  (Bash)                    │ │  │  │
│  │  │  │  • timeout-check.sh     (all)                     │ │  │  │
│  │  │  └──────────────────────────────────────────────────┘ │  │  │
│  │  └───────────────────────────────────────────────────────┘  │  │
│  └─────────────────────────────────────────────────────────────┘  │
│                                                                   │
│  [Stop]  stop-check.sh                                            │
│  Final completion gate. Blocks final response if required         │
│  deploy skills are not all recorded in the state file.            │
└───────────────────────────────────────────────────────────────────┘
```

---

## 4. Detailed Mechanism Reference

> **Source of truth for hook count:** `hooks/hooks.json` registers 11 hooks across
> 5 event types (SessionStart, PreToolUse, PostToolUse, Stop, UserPromptSubmit).
> Hook scripts are in `hooks/`. The `run-hook.cmd` file is a Windows test runner, not a hook.

### 4.1 session-start (SessionStart hook)

| Attribute | Value |
|-----------|-------|
| File | `hooks/session-start` |
| Hook event | SessionStart |
| Matcher | `startup\|clear\|compact` |
| Async | No |

**What it does:** Fires at session start and after `/compact` or `/clear`. Reads the
current git branch and compares it to the branch stored in `~/.claude/.silver-bullet/branch`.
If the branch has changed, it resets the state file so skills from the previous branch
do not carry over. Also injects "superpowers" context for autonomous mode sessions.

**What it blocks:** Does not block — informational/setup only.

**Config keys read:** `state.state_file`, `state.branch_file`

**Bypass:** No bypass — fires unconditionally on SessionStart events.

---

### 4.2 dev-cycle-check.sh (PreToolUse + PostToolUse, Edit|Write|Bash)

| Attribute | Value |
|-----------|-------|
| File | `hooks/dev-cycle-check.sh` |
| Hook event | PreToolUse and PostToolUse |
| Matcher | `Edit\|Write\|Bash` |
| Async | No |

**What it does:** The primary stage enforcer. Walks up from the edited file's directory
(or `$PWD` for Bash) to find `.silver-bullet.json`. Checks whether required planning
skills are recorded in the state file before allowing source file edits.

**Four-stage gate:**

| Stage | Condition | Action |
|-------|-----------|--------|
| A | Planning skills missing | HARD STOP — deny/block |
| B | Planning done, no `code-review` | BLOCK source edits |
| — | Phase skip detected (finalization before code-review) | BLOCK |
| C | `code-review` done, finalization not yet started | Allow with reminder |
| D | All phases complete | Allow |

**Additional protections in this hook (sub-sections):**

#### 4.2a Plugin boundary protection

Blocks any Edit/Write/Bash targeting `~/.claude/plugins/cache/`. Claude must never
modify upstream plugin files.

**Block message:** "THIRD-PARTY PLUGIN BOUNDARY VIOLATION"

#### 4.2b Hook self-protection (added in Phase 06 Plan 02)

Blocks Edit/Write targeting `${CLAUDE_PLUGIN_ROOT}/hooks/` or
`${CLAUDE_PLUGIN_ROOT}/hooks.json`. Also blocks Bash write commands (using `>>`, `>`,
`tee`, `cp`, `mv`, `rm`, `chmod`, `sed`) targeting those paths.

Fallback: when `CLAUDE_PLUGIN_ROOT` is not set, matches path pattern
`/silver-bullet[^/]*/hooks/` to catch the same paths.

**Block message:** "Silver Bullet NEVER modifies its own enforcement hooks. This would
disable process compliance. If you need to reconfigure, use /using-silver-bullet."

**Threat mitigated:** T-06-05 (Tampering via unset CLAUDE_PLUGIN_ROOT)

#### 4.2c State file tamper prevention (SB-008)

Blocks direct Edit/Write targeting `~/.claude/.silver-bullet/` and Bash write commands
targeting `state`, `branch`, or `trivial` files within that directory. Whitelist: Bash
commands matching `quality-gate-stage-[1-4]` (legitimate §9 stage recording).

**Block message:** "STATE TAMPER BLOCKED"

**Config keys read:** `project.src_pattern`, `project.src_exclude_pattern`,
`project.active_workflow`, `skills.required_planning`, `state.state_file`,
`state.trivial_file`

**Bypass conditions:**
- No `.silver-bullet.json` found walking up the directory tree
- Trivial file exists at `state.trivial_file` (and is not a symlink)
- Non-logic file extension (`.md`, `.json`, `.yml`, etc.) — skipped per-edit
- Small Edit tool change (combined old+new string < 100 chars) — treated as typo fix
- In `devops-cycle` workflow, `.yml`, `.yaml`, `.json`, `.toml` are NOT auto-exempted

---

### 4.3 completion-audit.sh (PreToolUse + PostToolUse, Bash)

| Attribute | Value |
|-----------|-------|
| File | `hooks/completion-audit.sh` |
| Hook event | PreToolUse and PostToolUse |
| Matcher | `Bash` |
| Async | No |

**What it does:** Two-tier delivery gate. Inspects the Bash command string for git/deploy
patterns and checks the state file.

**Tier 1 (intermediate commits):** `git commit`, `git push` — requires planning skills
only (`required_planning`). Blocked with "COMMIT BLOCKED".

**Tier 2 (final delivery):** `gh pr create`, `gh pr merge`, `npm run deploy`,
`gh release create`, etc. — requires all `required_deploy` skills. Blocked with
"COMPLETION BLOCKED".

**§9 pre-release gate:** `gh release create` additionally requires
`quality-gate-stage-1` through `quality-gate-stage-4` in the state file.

**Ordering enforcement:** Checks that `code-review` precedes `requesting-code-review`
and `receiving-code-review` in the state file. Out-of-order invocation is flagged.

**Main branch handling:** On `main`/`master`, `finishing-a-development-branch` is
removed from the required list.

**DevOps workflow:** `blast-radius` and `devops-quality-gates` replace `quality-gates`
for Tier 1.

**Config keys read:** `skills.required_planning`, `skills.required_deploy`,
`project.active_workflow`, `state.state_file`, `state.trivial_file`

**Bypass:** Trivial file present; command does not match delivery patterns.

---

### 4.4 ci-status-check.sh (PreToolUse + PostToolUse, Bash)

| Attribute | Value |
|-----------|-------|
| File | `hooks/ci-status-check.sh` |
| Hook event | PreToolUse and PostToolUse |
| Matcher | `Bash` |
| Async | No |

**What it does:** Checks CI status (via `gh run list` or similar) before allowing
commits, pushes, or PRs when CI is known to be failing. Prevents layering new work on
top of a broken CI.

**What it blocks:** Bash commands containing git/delivery patterns when CI status is
`failure` or `startup_failure`.

**Config keys read:** `project.active_workflow`, `state.state_file`

**Bypass:** No CI configuration detected; trivial file present.

---

### 4.5 record-skill.sh (PostToolUse, Skill)

| Attribute | Value |
|-----------|-------|
| File | `hooks/record-skill.sh` |
| Hook event | PostToolUse |
| Matcher | `Skill` |
| Async | No |

**What it does:** Appends the invoked skill name to the state file
(`~/.claude/.silver-bullet/state`) on every successful Skill tool use. This is the
primary mechanism that tracks workflow progress.

**Output format:** Writes one line (skill name) to state file. Emits informational JSON
with invocation count.

**Important:** Recording proves invocation, not outcome quality. Claude is responsible
for doing the actual work — vacuous invocation satisfies the hook technically but violates
workflow intent.

**Config keys read:** `state.state_file`

**Bypass:** None — records every Skill invocation unconditionally.

---

### 4.6 semantic-compress.sh (PostToolUse, Skill)

| Attribute | Value |
|-----------|-------|
| File | `hooks/semantic-compress.sh` |
| Hook event | PostToolUse |
| Matcher | `Skill` |
| Async | No |

**What it does:** After certain skill invocations, compresses the skill's output into a
compact summary stored in the project's `.claude/` directory. Reduces context consumption
for long skill outputs (e.g., code review, testing-strategy).

**What it blocks:** Does not block — performs compression and exits 0.

**Config keys read:** `project.compress_skills` (list of skill names to compress)

---

### 4.7 compliance-status.sh (PostToolUse, all tools)

| Attribute | Value |
|-----------|-------|
| File | `hooks/compliance-status.sh` |
| Hook event | PostToolUse |
| Matcher | `.*` (all tools) |
| Async | Yes |

**What it does:** After every tool use, emits a compact compliance status line showing
which required skills are complete and which are missing. Purely informational — does not
block. Runs async so it never delays Claude's next action.

**Output format:**
```json
{"hookSpecificOutput":{"message":"✅ quality-gates ✅ code-review ❌ testing-strategy ..."}}
```

**Config keys read:** `skills.required_deploy`, `state.state_file`

---

### 4.8 session-log-init.sh (PostToolUse, Bash)

| Attribute | Value |
|-----------|-------|
| File | `hooks/session-log-init.sh` |
| Hook event | PostToolUse |
| Matcher | `Bash` |
| Async | No |

**What it does:** Detects autonomous mode (long-running agent sessions) by checking
whether Bash output has exceeded a configured time limit. Initializes and rotates session
log files. Provides a structured record of which commands ran in each session.

**What it blocks:** Does not block — logging and timeout detection only.

**Config keys read:** `session.log_dir`, `session.max_duration_minutes`

---

### 4.9 timeout-check.sh (PostToolUse, all tools)

| Attribute | Value |
|-----------|-------|
| File | `hooks/timeout-check.sh` |
| Hook event | PostToolUse |
| Matcher | `.*` (all tools) |
| Async | No |

**What it does:** Checks whether the current session has exceeded the configured
autonomous mode timeout. If so, emits a block decision to stop further tool use and
prompt the user to review progress before continuing.

**What it blocks:** All PostToolUse actions after timeout threshold is exceeded.

**Output format (block):**
```json
{"decision":"block","reason":"Session timeout reached. Review progress before continuing."}
```

**Config keys read:** `session.max_duration_minutes`, `state.start_time_file`

**Bypass:** Trivial file present; timeout not configured.

---

### 4.10 stop-check.sh (Stop hook) — Added in Phase 06 Plan 01

| Attribute | Value |
|-----------|-------|
| File | `hooks/stop-check.sh` |
| Hook event | Stop |
| Matcher | `.*` |
| Async | No |

**What it does:** Fires when Claude outputs a final response (declaring the task
complete). Checks the state file for all `required_deploy` skills. If any are missing,
emits a block decision that prevents the final response from being delivered and shows
Claude which skills to run next.

**What it blocks:** Claude declaring task complete without all required workflow phases
done.

**Output format (block):**
```json
{"decision":"block","reason":"Cannot complete -- missing required skills:\n  - testing-strategy\n  - documentation\nRun these skills before declaring task complete."}
```

**Output format (allow):** Silent exit 0 (no output).

**Main branch handling:** `finishing-a-development-branch` is removed from the required
list when on `main` or `master` branch (same rule as completion-audit.sh).

**Config keys read:** `skills.required_deploy`, `project.active_workflow`,
`state.state_file`, `state.trivial_file`

**Bypass:** No `.silver-bullet.json` found; trivial file present (not a symlink).

---

### 4.11 prompt-reminder.sh (UserPromptSubmit hook) — Added in Phase 06 Plan 01

| Attribute | Value |
|-----------|-------|
| File | `hooks/prompt-reminder.sh` |
| Hook event | UserPromptSubmit |
| Matcher | `.*` |
| Async | No |

**What it does:** Fires before every user prompt is processed. Reads the state file and
emits a compact compliance reminder as `additionalContext`. This re-injects the
enforcement state into Claude's context on every turn, surviving `/compact` and session
boundaries.

**Output format (missing skills):**
```
Silver Bullet -- Missing: testing-strategy, documentation (3 of 12 complete)
```

**Output format (all complete):**
```
Silver Bullet: all required skills complete.
```

**Output format (JSON envelope):**
```json
{"hookSpecificOutput":{"additionalContext":"Silver Bullet -- Missing: ..."}}
```

**Performance:** Does NOT read stdin (avoids blocking). Single `jq` call reads all config
values. Target: < 200 ms. Error trap exits 0 silently — never delays user prompts.

**Config keys read:** `skills.required_deploy`, `state.state_file`, `state.trivial_file`

**Bypass:** No `.silver-bullet.json` found; trivial file present (not a symlink); `jq`
not installed (exits silently).

---

### 4.12 silver-bullet.md (documentation layer)

| Attribute | Value |
|-----------|-------|
| File | `silver-bullet.md` (in each project) |
| Hook event | N/A — read by Claude at session start |

**What it does:** The primary instruction document injected into each project via
`/using-silver-bullet`. Contains: session startup protocol, enforcement model overview,
active workflow reference, anti-skip blocks, anti-rationalization text, and workflow
transition narration requirements.

**Anti-skip blocks** explicitly name violation patterns:
> "You are violating this rule if you begin work without reading docs/ or skip /compact."

**Anti-rationalization blocks** state that combining steps, skipping steps, or implicitly
covering steps are all violations regardless of the justification offered.

**Survives compaction:** The `compactPrompt` config key instructs the compaction LLM to
preserve `silver-bullet.md` rules verbatim. Combined with hooks firing regardless of
context state, the enforcement model survives context window limits.

---

### 4.13 State file (~/.claude/.silver-bullet/state)

| Attribute | Value |
|-----------|-------|
| Path | `~/.claude/.silver-bullet/state` (configurable) |
| Format | One skill name per line |

**What it does:** The single source of truth for workflow progress within a session and
branch. Every hook that needs to know "has skill X been completed?" reads this file.
`record-skill.sh` writes to it; no other mechanism writes to it directly (state tamper
prevention in `dev-cycle-check.sh` blocks direct writes).

**Branch scoping:** `session-start` resets the state file on branch change, so skills
from one branch do not carry over to another.

**Security:** Path validated to stay within `~/.claude/` by every hook that reads it
(SB-002/SB-003). Symlinks rejected for trivial file.

---

### 4.14 Trivial bypass (~/.claude/.silver-bullet/trivial)

| Attribute | Value |
|-----------|-------|
| Path | `~/.claude/.silver-bullet/trivial` (configurable) |
| Format | Regular file, presence = bypass active |

**What it does:** When this file exists (and is not a symlink), all enforcement hooks
exit 0 immediately without checking the state file. Intended for quick fixes, hotfixes,
or work the developer has manually verified does not require the full workflow.

**Security:** Only a regular file triggers bypass — symlinks are rejected to prevent
attacks where an attacker creates a symlink from the trivial path to an existing file.

**Usage:** Create with `touch ~/.claude/.silver-bullet/trivial`; remove with
`rm ~/.claude/.silver-bullet/trivial`.

---

### 4.15 Branch-scoped state (session-start reset)

**What it does:** When `session-start` detects that the current git branch differs from
the branch stored in `~/.claude/.silver-bullet/branch`, it deletes the state file
(clearing all recorded skills) and writes the new branch name. This ensures Claude
starts the full workflow from scratch on each branch.

**Why it matters:** Without branch scoping, skills recorded on a feature branch would
persist when the developer switches to a hotfix branch, falsely showing the hotfix as
"planning complete."

---

### 4.16 Plugin boundary protection (dev-cycle-check.sh §4.2a)

Already documented in §4.2a above.

---

### 4.17 Hook self-protection (dev-cycle-check.sh §4.2b) — Added in Phase 06 Plan 02

Already documented in §4.2b above.

---

### 4.18 compactPrompt config key — Added in Phase 06 Plan 01

| Attribute | Value |
|-----------|-------|
| Config key | `compactPrompt` in `.silver-bullet.json` |
| Template | `templates/silver-bullet.config.json.default` |

**What it does:** Provides a custom instruction to Claude Code's `/compact` compaction
LLM. The value tells the compaction model to preserve `silver-bullet.md` rules verbatim
— especially skill names, ordering constraints, and anti-skip rules — rather than
summarizing them.

**Example value:**
```
When compacting, preserve all rules and workflow steps from silver-bullet.md verbatim.
Do not summarize skill names, ordering constraints, or anti-skip rules.
```

**Why it matters:** The compaction LLM may summarize or omit enforcement rules if not
given explicit guidance, weakening the documentation layer after `/compact` runs. The
`compactPrompt` key is Playbook Tier 8.

---

## 5. What Doesn't Work

From the AI-Native SDLC Playbook and Silver Bullet's own experience — enforcement
techniques that are insufficient on their own:

| Technique | Why It Fails |
|-----------|-------------|
| Polite requests ("please follow these rules") | Ignored under pressure or when the LLM constructs a justification for skipping |
| Single-mention rules in a prompt | Forgotten after context compaction; LLM may not have them in its active context when making decisions |
| Complex conditional logic in prompts | Misinterpreted; LLMs apply pattern matching, not strict logical evaluation |
| Relying on LLM memory across sessions | Sessions are stateless; nothing persists unless written to a file or config |
| Trust-based enforcement ("Claude should know better") | Unreliable; LLMs are optimized to be helpful and will rationalize away constraints under user pressure |
| Documentation-only enforcement | Effective until context fills; survives only if hooks re-inject rules (Tier 11) or compactPrompt preserves them (Tier 8) |
| Listing rules once in CLAUDE.md without redundancy | Works when context is fresh; fails after compaction removes or summarizes the rules |

**Effective patterns (Silver Bullet's approach):**

1. **Mechanical gates** — Block the tool call before it executes (PreToolUse deny).
2. **Block at declaration** — Block the final response (Stop hook).
3. **Re-injection on every turn** — UserPromptSubmit hook fires regardless of context state.
4. **State persistence** — State file records what happened; survives context loss.
5. **Redundant encoding** — Rules stated in `silver-bullet.md`, `CLAUDE.md`, and workflow files; three independent sources must all be "forgotten" to escape.
6. **Explicit violation naming** — Anti-skip blocks name the violation pattern so the LLM cannot claim the rule was ambiguous.

---

## 6. Configuration Reference

### .silver-bullet.json Keys Affecting Enforcement

| Key | Type | Default | Effect |
|-----|------|---------|--------|
| `project.src_pattern` | string | `/src/` | Path prefix that triggers stage enforcement in `dev-cycle-check.sh` |
| `project.src_exclude_pattern` | string | `__tests__\|\.test\.` | Regex: files matching this skip enforcement (test files) |
| `project.active_workflow` | string | `full-dev-cycle` | Sets skill lists for intermediate and final delivery checks |
| `skills.required_planning` | string[] | `["quality-gates"]` | Skills required before any source edit (Stage A gate) |
| `skills.required_deploy` | string[] | (12-skill default list) | Skills required before PR/deploy/release commands and before Stop hook allows completion |
| `state.state_file` | string | `~/.claude/.silver-bullet/state` | Path to the skill recording state file |
| `state.trivial_file` | string | `~/.claude/.silver-bullet/trivial` | Path to the trivial bypass marker file |
| `compactPrompt` | string | (verbatim preservation instruction) | Instruction to `/compact` compaction LLM to preserve enforcement rules |

### State File Format

One skill name per line, appended by `record-skill.sh` after each Skill invocation:

```
quality-gates
code-review
requesting-code-review
receiving-code-review
testing-strategy
documentation
finishing-a-development-branch
deploy-checklist
create-release
verification-before-completion
test-driven-development
tech-debt
```

### Environment Variable Overrides

| Variable | Effect |
|----------|--------|
| `SILVER_BULLET_STATE_FILE` | Overrides `state.state_file` config key (used in tests to isolate state) |
| `CLAUDE_PLUGIN_ROOT` | Set by Claude Code to the plugin's installation directory; used by `dev-cycle-check.sh` hook self-protection to resolve hooks paths |

### Default required_deploy Skill List (full-dev-cycle workflow)

```
quality-gates
code-review
requesting-code-review
receiving-code-review
testing-strategy
documentation
finishing-a-development-branch
deploy-checklist
create-release
verification-before-completion
test-driven-development
tech-debt
```

### Default required_deploy Skill List (devops-cycle workflow)

```
blast-radius
devops-quality-gates
code-review
requesting-code-review
receiving-code-review
testing-strategy
documentation
finishing-a-development-branch
deploy-checklist
create-release
verification-before-completion
test-driven-development
tech-debt
```

### Mandatory Finalization Skills (always required regardless of config)

The following skills are always appended to the `required_deploy` list and cannot be
removed via config:

```
testing-strategy
documentation
finishing-a-development-branch
deploy-checklist
```

Exception: `finishing-a-development-branch` is dropped when on `main` or `master` branch.

---

## 7. hooks/hooks.json Registration Reference

As of Phase 06 Plan 02, `hooks/hooks.json` registers 11 hooks across 5 event types:

| Event | Matcher | Script | Async |
|-------|---------|--------|-------|
| SessionStart | `startup\|clear\|compact` | `session-start` | No |
| PreToolUse | `Bash` | `completion-audit.sh` | No |
| PreToolUse | `Edit\|Write\|Bash` | `dev-cycle-check.sh` | No |
| PreToolUse | `Bash` | `ci-status-check.sh` | No |
| PostToolUse | `Skill` | `semantic-compress.sh` | No |
| PostToolUse | `Skill` | `record-skill.sh` | No |
| PostToolUse | `Edit\|Write\|Bash` | `dev-cycle-check.sh` | No |
| PostToolUse | `.*` | `compliance-status.sh` | Yes |
| PostToolUse | `Bash` | `completion-audit.sh` | No |
| PostToolUse | `Bash` | `session-log-init.sh` | No |
| PostToolUse | `Bash` | `ci-status-check.sh` | No |
| PostToolUse | `.*` | `timeout-check.sh` | No |
| Stop | `.*` | `stop-check.sh` | No |
| UserPromptSubmit | `.*` | `prompt-reminder.sh` | No |

Note: `dev-cycle-check.sh` and `completion-audit.sh` are registered for both PreToolUse
and PostToolUse. The hook detects which event fired via `.hook_event_name` in stdin JSON
and adjusts its output format accordingly (PreToolUse uses `permissionDecision: "deny"`;
PostToolUse uses `decision: "block"`).

---

*Last updated: Phase 06 Plan 02 (2026-04-06)*
*Maintained by: Silver Bullet enforcement infrastructure*
