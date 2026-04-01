# Silver Bullet — Autonomous Mode Hardening Design

**Date:** 2026-04-02
**Scope:** Group A gap-narrowing — answer injection, timeout supervision, skill auto-discovery
**Out of scope:** Group B (semantic context compression, captures system, forensics skill);
  sliding-window stuck detection (Category 1 full parity) remains out of scope for v0.2.0
**Reference:** `docs/gsd2-vs-sb-gap-analysis.md` (Categories 1 partial, 6, 10 partial)
**Target workflow:** `docs/workflows/full-dev-cycle.md`

---

## Architecture: Hybrid Hook + Workflow

| Layer | Handles |
|-------|---------|
| **Hook (PostToolUse / session-log-init extension)** | Background timeout sentinel launch + PID tracking, per-tool-use timeout flag check |
| **Workflow + CLAUDE.md** | Answer injection at Step 0, enhanced anti-stall rules, skill auto-discovery at two workflow points |

---

## Feature 1 — Answer Injection

### Mechanism

Step 0 (session mode prompt) is extended. After the user chooses "autonomous", Claude asks one follow-up:

> Any decision points you want to pre-answer? Common ones:
> - Model routing — Planning phase: Sonnet or Opus?
> - Model routing — Design phase: Sonnet or Opus?
> - Worktree: use one for this task, or work on main?
> - Agent Teams: use worktree isolation, or main worktree throughout?
> Leave blank to use defaults (Sonnet for both phases, main, isolated).

### Storage

Answers are written into the session log under a **"Pre-answers"** section, inserted between the frontmatter block and `## Task`. Format:

```markdown
## Pre-answers
- Model routing — Planning: Opus
- Model routing — Design: Sonnet
- Worktree: main
- Agent Teams: isolated
```

Four distinct keys. Planning and Design are stored separately because they are asked at two distinct workflow points.

### Write timing

**Claude** (not the hook) writes the pre-answer values immediately after the user responds at Step 0, before any further workflow steps proceed. The hook creates an empty `## Pre-answers` section in the skeleton; Claude fills it in after the user's reply.

### Parsing rule

When Claude needs to apply a pre-answer mid-session: read the session log from `/tmp/.silver-bullet-session-log-path`, extract all lines between `## Pre-answers` and the next `##` heading. Strip the leading `- ` (dash-space) from each line before processing. Each line is then a key-value pair split on the first `:`. Leading and trailing whitespace is trimmed from both key and value. The key is matched case-insensitively against the current decision point label.

### Application

Whenever a pre-answered decision point arises, Claude applies the stored answer silently — no pause, no re-prompt. The decision is logged under "Autonomous decisions" with the note `(pre-answered at Step 0)`.

### Fallback

If any of the following occur, Claude falls back to workflow defaults (Sonnet for both phases, main, isolated):
- `/tmp/.silver-bullet-session-log-path` is absent
- The path pointer exists but the target log file is missing or unreadable
- The log file is readable but has no `## Pre-answers` section

### Scope constraint

Only the four keys above are pre-answerable. Arbitrary question pre-answering is out of scope.

---

## Feature 2 — Timeout Supervision

### Two complementary mechanisms

#### 2a — Background sentinel (hook layer)

**Revised `session-log-init.sh` execution order:**

The hook shebang must be `#!/usr/bin/env bash` (not `/bin/sh`) — `disown` is a bash built-in and is not available in POSIX sh. The existing hook already uses bash features (`[[ ]]`, `set -euo pipefail`) so this is consistent.

The hook is changed from `async: true` to `async: false` to eliminate the race window between PID file creation and the first tool use (see race note below).

The revised execution order is:

1. **Consume stdin** and extract `cmd` (unchanged)
2. **Filter** — exit 0 if command does not touch `.silver-bullet-mode` (unchanged)
3. **Locate project root** (unchanged)
4. **Sentinel cleanup (unconditional, before dedup guard):**
   ```bash
   if [[ -f /tmp/.silver-bullet-sentinel-pid ]]; then
     old_pid=$(cat /tmp/.silver-bullet-sentinel-pid)
     kill "$old_pid" 2>/dev/null || true
     rm -f /tmp/.silver-bullet-sentinel-pid /tmp/.silver-bullet-timeout \
           /tmp/.silver-bullet-session-start-time /tmp/.silver-bullet-timeout-warn-count
   fi
   ```
5. **Mode detection + dedup guard (combined):**
   - First, locate `$existing` (any `${today}*.md` in sessions dir — same logic as the current dedup guard).
   - If `$existing` found: extract mode from it: `mode=$(grep '^\*\*Mode:\*\*' "$existing" | awk '{print $NF}' | tr -d ' ')`. If `mode == "autonomous"`:
     1. Write a fresh session-start timestamp: `date +%s > /tmp/.silver-bullet-session-start-time`
     2. Re-launch the sentinel with `disown` and write PID file (same logic as step 8)
     3. Append the second-terminal note to `$existing` under `## Autonomous decisions`
     This sequence (start-time write → sentinel launch) must be in this order so `timeout-check.sh`'s stale-flag check correctly references the new session's start time.
   - Write path to `/tmp/.silver-bullet-session-log-path`, emit the "already exists" message, and `exit 0`.
   - If no `$existing`: extract mode from command string: `printf '%s' "$cmd" | grep -q "autonomous" && mode="autonomous" || mode="interactive"`. Continue to step 6.

   This combines what was formerly step 5 (mode detection) and step 6 (dedup guard) into one block so `$existing` is available to the mode-override read before any exit path fires.
6. **Create session log** (unchanged — only reached when no existing log was found in step 5)
7. **Write session start timestamp:**
   ```bash
   date +%s > /tmp/.silver-bullet-session-start-time
   ```
8. **Sentinel launch (autonomous mode only, with PID guard):**
   ```bash
   if [[ "$mode" == "autonomous" ]]; then
     (sleep 600 && echo "TIMEOUT" > /tmp/.silver-bullet-timeout) &
     sentinel_pid=$!
     disown $sentinel_pid
     echo "$sentinel_pid" > /tmp/.silver-bullet-sentinel-pid
   fi
   ```
   `disown` detaches the sentinel from the hook's shell job table, guaranteeing it survives after the hook shell exits.

**Race note:** With `async: false`, the PID file is guaranteed to exist before any subsequent tool use can trigger `timeout-check.sh`. This eliminates the race between sentinel launch and the first tool use. The Implementation Scope table reflects this change.

**Timer start note:** The 10-minute sentinel clock starts when `.silver-bullet-mode` is written (end of Step 0), not when autonomous workflow execution begins. If Step 0 conversation is slow (e.g., extended pre-answer Q&A), the warning fires earlier into actual execution. This is an accepted limitation — in practice Step 0 completes within seconds.

**New hook: `hooks/timeout-check.sh`**

- Matcher: `.*`, **async: false**
- Execution:
  1. `input=$(cat)` — consume stdin (required to avoid broken pipe)
  2. Read `/tmp/.silver-bullet-mode`; if absent or not "autonomous", exit 0 silently
  3. Check `[[ -f /tmp/.silver-bullet-timeout ]]`; if absent, exit 0 silently
  4. **Stale-flag check:** read `/tmp/.silver-bullet-session-start-time`; if absent, exit 0 silently. Compare flag file mtime against session start timestamp using:
     ```bash
     flag_mtime=$(stat -f %m /tmp/.silver-bullet-timeout 2>/dev/null) || exit 0
     session_start=$(cat /tmp/.silver-bullet-session-start-time 2>/dev/null) || exit 0
     [[ "$flag_mtime" -lt "$session_start" ]] && exit 0
     ```
     (`stat -f %m` is macOS syntax — hook includes a `uname` guard and exits 0 on non-macOS.)
  5. **Rate-limiting** (macOS only — same `uname` guard applies; on non-macOS the `uname` guard exits 0 at step 4 before reaching this step, so rate-limiting does not apply on non-macOS):
     - Read `/tmp/.silver-bullet-timeout-warn-count` (default 0 if absent).
     - If the file exists and its mtime predates `/tmp/.silver-bullet-session-start-time` (using `stat -f %m`, same as step 4), the count is stale — set count to 0 before incrementing (same as "absent" case).
     - Increment count by 1, **write back to file**, then evaluate: if `count mod 5 == 1`, emit warning. Write-back must precede the mod check so the persisted count is always current, regardless of whether the warning fires. The stale-reset path sets count to 1, which satisfies this condition, so the first call after a stale reset always emits. This is the shared evaluation path — no separate emit logic for the stale branch.
  6. Emit warning:
     ```json
     {"hookSpecificOutput":{"message":"⚠️ Autonomous session running 10+ min. Check for stalls or log a blocker under Needs human review."}}
     ```

- **Test override:** `TIMEOUT_FLAG_OVERRIDE` env var specifies a flag file path to check instead of `/tmp/.silver-bullet-timeout`, bypassing the real timer.

**Flag cleanup:** `rm -f /tmp/.silver-bullet-timeout /tmp/.silver-bullet-sentinel-pid /tmp/.silver-bullet-session-start-time /tmp/.silver-bullet-timeout-warn-count` is added as an explicit bash command in the autonomous completion summary step of `full-dev-cycle.md`. This command runs **after** the structured summary is output — so `timeout-check.sh` cannot fire during summary output, and the flag files persist until work is confirmed complete.

#### 2b — Enhanced anti-stall (CLAUDE.md layer)

Adds a third stall trigger to the existing two. Fires only when **all three conditions are simultaneously true**:

1. A single workflow step has accumulated **more than 10 tool calls**
2. **AND** no new file has been written since the step began (any Write or Edit tool use resets the counter to 0)
3. **AND** no new autonomous decision has been logged since the step began

The counter resets to 0 on any file write/edit or decision log event. It also resets when a new `/gsd:` command or Silver Bullet skill is invoked (marking a new step boundary).

**Partial implementation note:** This is a bounded approximation of GSD-2's Category 1 sliding-window stuck detection. Full sliding-window analysis with progress metrics remains out of scope for v0.2.0.

---

## Feature 3 — Skill Auto-Discovery

### Two insertion points

#### Point 1 — Proactive (before DISCUSS)

After the model routing prompt and before `/gsd:discuss-phase`, Claude:

1. Reads `all_tracked` from `.silver-bullet.json`
2. Scans **both** `~/.claude/skills/` (flat `.md` files) **and** `~/.claude/plugins/cache/` (subdirectory-based: assumed layout `<publisher>/<plugin>/<version>/skills/<skill-name>/SKILL.md` — glob `*/*/*/skills/*/SKILL.md`; observed from `superpowers-marketplace/superpowers/5.0.5/skills/brainstorming/SKILL.md`; falls back gracefully if no matches) for skills not already in `all_tracked` — these are "untracked" skills worth surfacing
3. Cross-references the combined list (tracked + untracked) against the current task description
4. Surfaces a short candidate list:
   > Skills that may apply to this task: `/security` — auth changes; `/system-design` — new service boundary

If no matches or both directories absent/empty: logs "Skill discovery: no candidates surfaced."

Appended to session log under **"Skills flagged at discovery"** (inserted between `## Skills invoked` and `## Agent Teams dispatched` in the skeleton). No skill is invoked at this point.

A companion section **"Skill gap check (post-plan)"** is also added to the skeleton, positioned immediately after `## Skills flagged at discovery`. Claude fills it in after Step 5; if no gap is found, Claude writes `(none)`. The hook creates all three new sections (`## Pre-answers`, `## Skills flagged at discovery`, `## Skill gap check (post-plan)`) as empty placeholders. **Note:** none of these sections exist in the current skeleton — all are new additions introduced by this spec's implementation. The hook must check for each section's existence before inserting to remain idempotent on re-runs (a section already present is left unchanged).

#### Point 2 — Reactive (after plan is written)

After Step 5 (`/gsd:plan-phase`) produces `.planning/{phase}-PLAN.md`, Claude:

1. Reads the plan
2. Cross-references against **all** installed skills from both sources (`all_tracked` + untracked from the two-directory scan) — the reactive scan considers every installed skill, not just untracked ones, because a tracked skill might still be missing from the plan
3. Flags any skill covering a concern not explicitly in the plan

**If a gap is found:**
- **Interactive mode**: flags it and asks whether to add the skill
- **Autonomous mode**: adds the skill to the plan or logs the omission as an autonomous decision

**Session log format:**

```markdown
## Skills flagged at discovery
- `/security` — auth changes detected in task description

## Skill gap check (post-plan)
- Gap: `/security` not in plan despite auth changes → added to plan (autonomous decision)
```

---

## Implementation Scope

| Component | Type | Feature |
|-----------|------|---------|
| `hooks/session-log-init.sh` | Modify | (a) Change async:true → async:false; (b) Restructure: cleanup before dedup guard, mode detection before dedup guard, session-start-time write, sentinel launch with `disown` after log creation; (c) Add `## Pre-answers` (between frontmatter and `## Task`), `## Skills flagged at discovery` (between `## Skills invoked` and `## Agent Teams dispatched`), and `## Skill gap check (post-plan)` (immediately after `## Skills flagged at discovery`) to skeleton — all as empty placeholders filled by Claude |
| `tests/hooks/test-session-log-init.sh` | Modify | Add: sentinel PID file created in autonomous mode; sentinel NOT launched in interactive mode; prior PID killed and files cleaned on re-init |
| `hooks/timeout-check.sh` | New hook | stdin consumption; mode gate; flag check; stale-flag rejection via session-start-time; rate-limit (mod 5); warning output |
| `tests/hooks/test-timeout-check.sh` | New test | Flag present + current + autonomous → warning on call 1; flag present + call 2 → silent (rate limit); flag absent → silent; interactive mode → silent; stale flag → silent |
| `hooks/hooks.json` | Modify | Change session-log-init from async:true to async:false; add timeout-check entry (matcher:`.*`, async:false) |
| `templates/CLAUDE.md.base` | Modify | Add per-step budget stall trigger (all-three-conditions + counter-reset rules) |
| `CLAUDE.md` | Modify | Same stall trigger addition |
| `templates/workflows/full-dev-cycle.md` | Modify | (a) Step 0 answer injection Q&A; (b) Skill discovery before DISCUSS; (c) Skill gap check after Step 5; (d) Completion summary cleanup command |
| `docs/workflows/full-dev-cycle.md` | Modify | Same workflow edits applied to installed copy |

---

## Edge Cases

- **Two autonomous sessions same day**: Dedup guard fires; cleanup block (step 4) already ran and killed old sentinel; mode read from existing log; new sentinel launched. No collision.
- **Interactive mode**: Sentinel not launched. `timeout-check.sh` reads mode file and exits 0. Per-step budget rule does not apply.
- **Mode file absent at `timeout-check.sh` runtime**: Treated as interactive — exit 0 silently.
- **`/tmp/.silver-bullet-session-start-time` absent at `timeout-check.sh`**: Exit 0 silently (safe fallback).
- **Second terminal opened mid-autonomous-session**: `session-log-init.sh` re-triggers. Step 4 (cleanup) kills the old sentinel. Step 5 (dedup path) detects `mode=autonomous` from the existing log, re-launches a fresh sentinel (with new PID file and session-start-time), appends a note to `$existing` under `## Autonomous decisions`, and exits. Timeout supervision is preserved with a fresh 10-minute window. Warn-count is reset by step 4 cleanup — accepted, as the new sentinel represents a fresh supervision window.
- **Non-macOS environment**: `timeout-check.sh` emits a `uname` guard; exits 0 on Linux (stat syntax incompatibility). No stale-flag check is performed — accepted limitation.
- **Skill scan returns empty**: Discovery step logs "Skill discovery: no candidates surfaced" and continues.
- **`~/.claude/plugins/cache/` absent**: Skip silently; scan only `~/.claude/skills/`.

---

*Generated: 2026-04-02 | Silver Bullet v0.2.0*
