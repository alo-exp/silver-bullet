# Gap Narrowing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the 5 GSD-2 gap-narrowing strategies (cross-session knowledge, observability, autonomy, CI/CD verification, model routing + Agent Teams) in Silver Bullet.

**Architecture:** Hybrid hook + skill approach. Two new PostToolUse hook scripts handle mechanical concerns (session log creation, CI status warnings). Template files (CLAUDE.md.base, workflow, new KNOWLEDGE/CHANGELOG/session-log bases) encode the deliberate behaviours Claude follows. The SB init skill (using-silver-bullet SKILL.md) creates the new project files on fresh setup.

**Tech Stack:** bash, jq, Claude Code plugin hook system, gh CLI (for CI checks)

**Key file note:** `templates/workflows/full-dev-cycle.md` is the GSD-integrated 19-step template (canonical source). `docs/workflows/full-dev-cycle.md` is a stale 31-step copy written during today's init — it will be replaced by Task 10.

**Task ordering constraint:** Task 10 Step 10.4 must execute after Task 8 completes (copies the modified template).

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `tests/hooks/test-session-log-init.sh` | Test driver for session-log-init hook |
| Create | `tests/hooks/test-ci-status-check.sh` | Test driver for ci-status-check hook |
| Create | `hooks/session-log-init.sh` | Creates `docs/sessions/<timestamp>.md` when session mode is written |
| Create | `hooks/ci-status-check.sh` | Warns after git commit/push if last CI run failed |
| Modify | `hooks/hooks.json` | Wire up the 2 new hooks |
| Create | `templates/KNOWLEDGE.md.base` | Template for docs/KNOWLEDGE.md |
| Create | `templates/CHANGELOG-project.md.base` | Template for docs/CHANGELOG.md (task log) |
| Create | `templates/sessions/session-log.md.base` | Template for per-task session log |
| Modify | `templates/CLAUDE.md.base` | Add Section 4 (Session Mode + Anti-stall) and Section 5 (Model Routing) |
| Modify | `templates/workflows/full-dev-cycle.md` | Add Step 0, model routing, Agent Teams, KNOWLEDGE/CHANGELOG/session at step 15, CI gate at step 17 |
| Modify | `skills/using-silver-bullet/SKILL.md` | Phase 3: CI setup, KNOWLEDGE.md, CHANGELOG.md, sessions/ creation |
| Create | `docs/KNOWLEDGE.md` | Apply KNOWLEDGE.md.base to this project |
| Create | `docs/CHANGELOG.md` | Apply CHANGELOG-project.md.base to this project |
| Create | `docs/sessions/.gitkeep` | Ensure directory is tracked |
| Replace | `docs/workflows/full-dev-cycle.md` | Replace stale 31-step copy with current template |
| Modify | `CLAUDE.md` | Apply same new sections 4 and 5 |

---

## Task 1: session-log-init.sh

**Files:**
- Create: `tests/hooks/test-session-log-init.sh`
- Create: `hooks/session-log-init.sh`

This hook fires when Claude writes the session mode to `/tmp/.silver-bullet-mode`. It creates the session log skeleton (timestamp-named; Step 15 fills in content) and records its path at `/tmp/.silver-bullet-session-log-path`.

- [ ] **Step 1.1: Create tests directory and write test driver**

```bash
mkdir -p /Users/shafqat/Documents/Projects/silver-bullet/tests/hooks
```

Write `tests/hooks/test-session-log-init.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
# Test driver for hooks/session-log-init.sh
# Uses PROJECT_ROOT_OVERRIDE to bypass the .silver-bullet.json walk-up.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SCRIPT_DIR/../../hooks/session-log-init.sh"
SESSION_LOG_DIR="/tmp/sb-test-sessions-$$"
mkdir -p "$SESSION_LOG_DIR"

run_hook() {
  local cmd="$1"
  printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$cmd" \
    | PROJECT_ROOT_OVERRIDE="$(dirname "$SESSION_LOG_DIR")" \
      SESSION_LOG_TEST_DIR="$SESSION_LOG_DIR" \
      bash "$HOOK"
}

# Test 1: mode file write — should create session log and emit path message
out=$(run_hook "echo autonomous > /tmp/.silver-bullet-mode")
if printf '%s' "$out" | grep -q "session-log"; then
  printf 'PASS: mode write triggers session log creation\n'
else
  printf 'FAIL: expected session-log in output, got: %s\n' "$out"
  exit 1
fi

# Test 2: unrelated command — must be silent
out=$(run_hook "git status")
if [[ -z "$out" ]]; then
  printf 'PASS: unrelated command silently ignored\n'
else
  printf 'FAIL: expected silence, got: %s\n' "$out"
  exit 1
fi

# Test 3: dedup — second trigger same day must NOT create a second file
run_hook "echo interactive > /tmp/.silver-bullet-mode" > /dev/null 2>&1 || true
file_count=$(ls "$SESSION_LOG_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
if [[ "$file_count" -eq 1 ]]; then
  printf 'PASS: dedup guard prevents second session log\n'
else
  printf 'FAIL: expected 1 session log, found: %s\n' "$file_count"
  exit 1
fi

rm -rf "$SESSION_LOG_DIR"
printf 'All tests passed.\n'
```

```bash
chmod +x /Users/shafqat/Documents/Projects/silver-bullet/tests/hooks/test-session-log-init.sh
```

- [ ] **Step 1.2: Run test to confirm it fails (script not yet written)**

```bash
bash /Users/shafqat/Documents/Projects/silver-bullet/tests/hooks/test-session-log-init.sh 2>&1 || true
```
Expected: error (HOOK path not found) or FAIL.

- [ ] **Step 1.3: Write hook script**

Create `hooks/session-log-init.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# PostToolUse hook (matcher: Bash)
# Fires when Claude writes the session mode to /tmp/.silver-bullet-mode.
# Creates docs/sessions/<date>-<timestamp>.md skeleton and records path to
# /tmp/.silver-bullet-session-log-path so Step 15 (documentation) can fill it in.
# Note: hook infers mode by checking for "autonomous" in the command string.
# Known edge case: two-step writes (touch then echo) may fire the hook twice —
# dedup guard prevents a second session log.

command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
[[ -z "$cmd" ]] && exit 0

# Only fire when command touches .silver-bullet-mode
printf '%s' "$cmd" | grep -q '\.silver-bullet-mode' || exit 0

# --- Locate project root (allow override for testing) ---
project_root="${PROJECT_ROOT_OVERRIDE:-}"
if [[ -z "$project_root" ]]; then
  search_dir="$PWD"
  while true; do
    if [[ -f "$search_dir/.silver-bullet.json" ]]; then
      project_root="$search_dir"
      break
    fi
    [[ -d "$search_dir/.git" ]] || [[ "$search_dir" == "/" ]] && break
    search_dir=$(dirname "$search_dir")
  done
fi
[[ -z "$project_root" ]] && exit 0

# Allow sessions dir override for testing
sessions_dir="${SESSION_LOG_TEST_DIR:-$project_root/docs/sessions}"
mkdir -p "$sessions_dir"

# --- Dedup: one session log per calendar day ---
today=$(date '+%Y-%m-%d')
existing=$(ls "$sessions_dir/${today}"*.md 2>/dev/null | head -1 || true)
if [[ -n "$existing" ]]; then
  printf '%s' "$existing" > /tmp/.silver-bullet-session-log-path
  printf '{"hookSpecificOutput":{"message":"ℹ️ Session log already exists: %s"}}' \
    "$(basename "$existing")"
  exit 0
fi

# --- Extract mode from command ---
mode="interactive"
printf '%s' "$cmd" | grep -q "autonomous" && mode="autonomous"

# --- Create session log ---
timestamp=$(date '+%H-%M-%S')
log_file="$sessions_dir/${today}-${timestamp}.md"

cat > "$log_file" << LOGEOF
# Session Log — ${today}

**Date:** ${today}
**Mode:** ${mode}
**Model:** (filled at step 15)
**Virtual cost:** (filled at step 15)

---

## Task

(filled at step 15)

## Approach

(filled at step 15)

## Files changed

(filled at step 15)

## Skills invoked

(filled at step 15)

## Agent Teams dispatched

(filled at step 15)

## Autonomous decisions

(none)

## Needs human review

(none)

## Outcome

(filled at step 15)

## KNOWLEDGE.md additions

(filled at step 15)
LOGEOF

printf '%s' "$log_file" > /tmp/.silver-bullet-session-log-path
printf '{"hookSpecificOutput":{"message":"📋 Session log created: docs/sessions/%s"}}' \
  "$(basename "$log_file")"
```

- [ ] **Step 1.4: Make executable**

```bash
chmod +x /Users/shafqat/Documents/Projects/silver-bullet/hooks/session-log-init.sh
```

- [ ] **Step 1.5: Run test to confirm it passes**

```bash
bash /Users/shafqat/Documents/Projects/silver-bullet/tests/hooks/test-session-log-init.sh
```
Expected: `All tests passed.`

- [ ] **Step 1.6: Commit**

```bash
git add hooks/session-log-init.sh tests/hooks/test-session-log-init.sh
git commit -m "$(cat <<'EOF'
feat: add session-log-init hook and test

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: ci-status-check.sh

**Files:**
- Create: `tests/hooks/test-ci-status-check.sh`
- Create: `hooks/ci-status-check.sh`

Fires after `git commit` or `git push`. If the most recently completed CI run failed, emits a non-blocking warning. The Step 17 polling loop is the authoritative verification gate.

- [ ] **Step 2.1: Write test driver**

Write `tests/hooks/test-ci-status-check.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SCRIPT_DIR/../../hooks/ci-status-check.sh"

run_hook() {
  local cmd="$1"
  local gh_output="$2"
  printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$cmd" \
    | GH_STATUS_OVERRIDE="$gh_output" bash "$HOOK"
}

# Test 1: git commit + failed CI — must emit warning
out=$(run_hook "git commit -m test" '{"status":"completed","conclusion":"failure"}')
if printf '%s' "$out" | grep -q "CI"; then
  printf 'PASS: failed CI emits warning\n'
else
  printf 'FAIL: expected CI warning, got: %s\n' "$out"
  exit 1
fi

# Test 2: git commit + passing CI — must be silent
out=$(run_hook "git commit -m test" '{"status":"completed","conclusion":"success"}')
if [[ -z "$out" ]]; then
  printf 'PASS: passing CI is silent\n'
else
  printf 'FAIL: expected silence, got: %s\n' "$out"
  exit 1
fi

# Test 3: unrelated command + failed CI — must be silent
out=$(run_hook "npm install" '{"status":"completed","conclusion":"failure"}')
if [[ -z "$out" ]]; then
  printf 'PASS: unrelated command ignored\n'
else
  printf 'FAIL: expected silence, got: %s\n' "$out"
  exit 1
fi

printf 'All tests passed.\n'
```

```bash
chmod +x /Users/shafqat/Documents/Projects/silver-bullet/tests/hooks/test-ci-status-check.sh
```

- [ ] **Step 2.2: Run test to confirm it fails**

```bash
bash /Users/shafqat/Documents/Projects/silver-bullet/tests/hooks/test-ci-status-check.sh 2>&1 || true
```
Expected: error or FAIL.

- [ ] **Step 2.3: Write hook script**

Create `hooks/ci-status-check.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# PostToolUse hook (matcher: Bash)
# After git commit/push, checks last completed CI run status and warns if failed.
# NON-BLOCKING — warning only. Step 17 polling loop is the authoritative gate.
# Race condition: reflects most recently COMPLETED run, not necessarily this push.

command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
[[ -z "$cmd" ]] && exit 0

# Only fire on commit or push
printf '%s' "$cmd" | grep -qE '\bgit (commit|push)\b' || exit 0

# gh CLI required for real runs; test override bypasses it
if [[ -n "${GH_STATUS_OVERRIDE:-}" ]]; then
  run_json="$GH_STATUS_OVERRIDE"
else
  command -v gh >/dev/null 2>&1 || exit 0
  run_json=$(gh run list --limit 1 --json status,conclusion 2>/dev/null \
    | jq -r '.[0] // empty' 2>/dev/null) || true
fi

[[ -z "${run_json:-}" ]] && exit 0

conclusion=$(printf '%s' "$run_json" | jq -r '.conclusion // ""' 2>/dev/null) || true
status=$(printf '%s' "$run_json" | jq -r '.status // ""' 2>/dev/null) || true

if [[ "$conclusion" == "failure" ]] || [[ "$conclusion" == "cancelled" ]]; then
  printf '{"hookSpecificOutput":{"message":"⚠️ CI WARNING: Last completed run conclusion=%s. Check before deploying. (Step 17 polling is the authoritative gate.)"}}'  \
    "$conclusion"
elif [[ "$status" == "in_progress" ]]; then
  printf '{"hookSpecificOutput":{"message":"ℹ️ CI in progress. Step 17 will poll for result."}}'
fi
# success or unknown: silent exit
```

- [ ] **Step 2.4: Make executable**

```bash
chmod +x /Users/shafqat/Documents/Projects/silver-bullet/hooks/ci-status-check.sh
```

- [ ] **Step 2.5: Run test to confirm it passes**

```bash
bash /Users/shafqat/Documents/Projects/silver-bullet/tests/hooks/test-ci-status-check.sh
```
Expected: `All tests passed.`

- [ ] **Step 2.6: Commit**

```bash
git add hooks/ci-status-check.sh tests/hooks/test-ci-status-check.sh
git commit -m "$(cat <<'EOF'
feat: add ci-status-check hook and test

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Update hooks.json

**Files:**
- Modify: `hooks/hooks.json`

Read `hooks/hooks.json` first. Add two new objects to the `PostToolUse` array — do NOT replace existing entries.

- [ ] **Step 3.1: Read current hooks.json**

```bash
cat /Users/shafqat/Documents/Projects/silver-bullet/hooks/hooks.json
```
Confirm the 4 existing PostToolUse entries are present before editing.

- [ ] **Step 3.2: Add two new hook entries**

Append the following two objects inside the `"PostToolUse"` array (before its closing `]`):

```json
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/session-log-init.sh\"",
            "async": true
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/ci-status-check.sh\"",
            "async": false
          }
        ]
      }
```

Note: `session-log-init` is async (non-blocking); `ci-status-check` is sync (user sees warning before next action).

- [ ] **Step 3.3: Verify JSON is valid and has 6 PostToolUse entries**

```bash
jq '.hooks.PostToolUse | length' /Users/shafqat/Documents/Projects/silver-bullet/hooks/hooks.json
```
Expected: `6`

- [ ] **Step 3.4: Commit**

```bash
git add hooks/hooks.json
git commit -m "$(cat <<'EOF'
feat: wire session-log-init and ci-status-check hooks

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: KNOWLEDGE.md base template

**Files:**
- Create: `templates/KNOWLEDGE.md.base`

- [ ] **Step 4.1: Create file**

Write `templates/KNOWLEDGE.md.base` with this content:

```markdown
# {{PROJECT_NAME}} — Project Knowledge

> Gateway index and accumulated project intelligence.
> Claude reads this at session startup. Claude updates Part 2 at step 15 (documentation).
> **Never delete or edit prior entries.** All additions are append-only with date stamps.

---

## Part 1 — Gateway Index

| Doc | Path | Status |
|-----|------|--------|
| Master PRD | `docs/Master-PRD.md` | draft |
| Architecture | `docs/Architecture-and-Design.md` | draft |
| Testing Strategy | `docs/Testing-Strategy-and-Plan.md` | draft |
| CI/CD | `docs/CICD.md` | draft |
| Active Workflow | `docs/workflows/full-dev-cycle.md` | active |
| Specs | `docs/specs/` | 0 specs |
| Task Log | `docs/CHANGELOG.md` | — |
| Session Logs | `docs/sessions/` | 0 sessions |
| Git Repo | {{GIT_REPO}} | — |

**Running virtual cost total:** $0.00 (estimated)

---

## Part 2 — Accumulated Intelligence

> Each entry: `YYYY-MM-DD — <note>`. Append below existing entries. Never edit above.

### Architecture patterns

*(none yet)*

### Known gotchas

*(none yet)*

### Key decisions

*(none yet)*

### Recurring patterns

*(none yet)*

### Open questions

*(none yet)*

> To add: append `YYYY-MM-DD — <question>`
> To resolve: append `[RESOLVED YYYY-MM-DD]: <resolution>` below the original question
```

- [ ] **Step 4.2: Verify file created correctly**

```bash
head -3 /Users/shafqat/Documents/Projects/silver-bullet/templates/KNOWLEDGE.md.base
```
Expected: first line is `# {{PROJECT_NAME}} — Project Knowledge`

- [ ] **Step 4.3: Commit**

```bash
git add templates/KNOWLEDGE.md.base
git commit -m "$(cat <<'EOF'
feat: add KNOWLEDGE.md base template

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Session log base template

**Files:**
- Create: `templates/sessions/session-log.md.base`

- [ ] **Step 5.1: Create file**

Write `templates/sessions/session-log.md.base`:

```markdown
# Session Log — YYYY-MM-DD

**Date:** YYYY-MM-DD
**Mode:** interactive | autonomous
**Model:** claude-sonnet-4-6 | claude-opus-4-6
**Virtual cost:** ~$X.XX (estimated, Model, complexity-tier)

---

## Task

One sentence description of what was asked.

## Approach

How it was tackled. Key decisions made.

## Files changed

- `path/to/file` — what changed

## Skills invoked

In order: skill-name, skill-name, ...

## Agent Teams dispatched

- Steps N–M: [dimension] agents × N (worktree isolated) | doc agents (main worktree)

## Autonomous decisions

*(interactive mode: n/a)*

## Needs human review

*(none)*

## Outcome

What was produced. Commits: abc1234, ...

## KNOWLEDGE.md additions

- Architecture patterns: (none | described)
- Known gotchas: (none | described)
- Key decisions: (none | described)
```

- [ ] **Step 5.2: Commit**

```bash
git add templates/sessions/session-log.md.base
git commit -m "$(cat <<'EOF'
feat: add session log base template

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Project CHANGELOG base template

**Files:**
- Create: `templates/CHANGELOG-project.md.base`

Note: This is the per-task activity log (`docs/CHANGELOG.md`), distinct from the root-level `CHANGELOG.md` (SB release log).

- [ ] **Step 6.1: Create file**

Write `templates/CHANGELOG-project.md.base`:

```markdown
# Task Log

> Rolling log of completed tasks. One entry per non-trivial task, written at step 15.
> Most recent entry first.

---

<!-- Entry format:
## YYYY-MM-DD — task-slug
**What**: one sentence description
**Commits**: abc1234, def5678
**Skills run**: brainstorming, write-spec, security, ...
**Virtual cost**: ~$0.04 (Sonnet, medium complexity)
**KNOWLEDGE.md**: updated (architecture patterns, known gotchas) | no changes
-->

<!-- ENTRIES BELOW — newest first -->
```

- [ ] **Step 6.2: Commit**

```bash
git add templates/CHANGELOG-project.md.base
git commit -m "$(cat <<'EOF'
feat: add project CHANGELOG base template

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Update CLAUDE.md.base

**Files:**
- Modify: `templates/CLAUDE.md.base`

Read the file first. Append two new sections after the existing Section 3.

- [ ] **Step 7.1: Read current CLAUDE.md.base to confirm Section 3 is the last section**

```bash
tail -10 /Users/shafqat/Documents/Projects/silver-bullet/templates/CLAUDE.md.base
```
Expected: ends with content from Section 3.

- [ ] **Step 7.2: Append Section 4 and Section 5**

Append to `templates/CLAUDE.md.base`:

```markdown

---

## 4. Session Mode

At the start of every session, before any work begins, ask:

> Run this session **interactively** or **autonomously**?
> - **Interactive** (default) — I pause at decision points and phase gates
> - **Autonomous** — I drive start to finish and surface blockers at the end

Write the choice:
```bash
echo "interactive" > /tmp/.silver-bullet-mode
# or
echo "autonomous" > /tmp/.silver-bullet-mode
```

**Fallback**: if `/tmp/.silver-bullet-mode` is unreadable at any point, default to interactive
and log "Mode fallback: defaulted to interactive" in the session log.

**In autonomous mode:**
- Phase gates removed — proceed without approval pauses
- Clarifying questions suppressed — make best-judgment calls, log each as "Autonomous decision"
- **Genuine blockers first** (missing credentials, ambiguous destructive operations): these take
  precedence over all other rules — queue under "Needs human review", skip, surface in summary
- **Anti-stall** (non-blocker stalls only): a stall = the same tool call with identical args
  producing the same result 2+ times consecutively, OR 3+ tool calls in one step with no new
  state change (no file written, no new decision, no new information). On stall: make
  best-judgment decision, move on, log it.
- All Agent Team dispatches use `run_in_background: true`
- On completion: output structured summary (phases done, autonomous decisions, blockers queued,
  agents dispatched, commits made, virtual cost)

---

## 5. Model Routing

Default model: **claude-sonnet-4-6** (latest Sonnet). No user friction for standard work.

Ask about Opus at two phase transitions only:

1. **Before Planning begins (before DISCUSS step):**
   > Entering Planning phase. Use Opus (claude-opus-4-6) for deeper reasoning, or stay on Sonnet?

2. **Before Design sub-steps apply (design-system / ux-copy / architecture / system-design):**
   > Entering Design phase. Use Opus, or stay on Sonnet?

If Opus permitted: switch to `claude-opus-4-6` for that phase, return to Sonnet afterward.

**Autonomous mode**: stay Sonnet. Escalate silently to Opus only if a planning step produces
measurably incomplete output: fewer than 5 lines, contains `TBD`/`[TODO]`/`...` placeholders,
or a step expected to produce a file produces none. Log escalation as an autonomous decision.
```

- [ ] **Step 7.3: Verify both sections appended**

```bash
grep -c "Session Mode\|Model Routing" /Users/shafqat/Documents/Projects/silver-bullet/templates/CLAUDE.md.base
```
Expected: `2`

- [ ] **Step 7.4: Commit**

```bash
git add templates/CLAUDE.md.base
git commit -m "$(cat <<'EOF'
feat: add session mode and model routing to CLAUDE.md.base

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Update workflow template

**Files:**
- Modify: `templates/workflows/full-dev-cycle.md`

Eight targeted insertions to the existing 19-step GSD-integrated template. Read the file before editing. Do NOT rewrite existing content — insert/append only.

- [ ] **Step 8.1: Add Step 0 (Session Mode) before PROJECT INITIALIZATION**

Insert before the `## PROJECT INITIALIZATION` heading:

```markdown
## STEP 0: SESSION MODE

> Run once at the very start of the session, before any project work.

Ask:
> Run this session **interactively** or **autonomously**?
> - **Interactive** (default) — I pause at decision points and phase gates
> - **Autonomous** — I drive start to finish, surface blockers at the end

Write choice to `/tmp/.silver-bullet-mode`:
```bash
echo "interactive" > /tmp/.silver-bullet-mode   # or "autonomous"
```

---
```

- [ ] **Step 8.2: Add model routing prompt BEFORE the DISCUSS section heading**

Insert before the `### DISCUSS` heading:

```markdown
### MODEL ROUTING (once per session)

Before DISCUSS begins, ask:
> Entering Planning phase. Use Opus (claude-opus-4-6) for deeper reasoning, or stay on Sonnet?

Autonomous mode: stay Sonnet; escalate silently only on measurably incomplete planning output.

```

- [ ] **Step 8.2b: Add second model routing prompt for Design sub-steps inside DISCUSS block**

Inside the DISCUSS step 3 conditional sub-steps block (after the line `- If this phase involves **UI work**: /design-system + /ux-copy`), add:

```markdown
   **Model routing for Design**: if any design sub-steps apply (design-system, ux-copy,
   architecture, system-design), ask once before beginning them:
   > Entering Design phase. Use Opus, or stay on Sonnet?
```

- [ ] **Step 8.3: Enhance /quality-gates step with Agent Teams**

After the step 4 (`/quality-gates`) block, add:

```markdown
   **Agent Team dispatch**: Dispatch all 8 quality dimensions (modularity, reusability,
   scalability, security, reliability, usability, testability, extensibility) as a single
   parallel Agent Team wave — one agent per dimension, `isolation: "worktree"`.
   Claude synthesises results. Conflict resolution: more conservative/restrictive finding wins;
   resolution rationale logged in session log.
   Autonomous mode: all dispatches use `run_in_background: true`.
```

- [ ] **Step 8.4: Enhance /gsd:execute-phase with Agent Teams**

After the step 6 (`/gsd:execute-phase`) block, add:

```markdown
   Each GSD wave dispatches Agent Teams for independent implementation units
   (`isolation: "worktree"` per agent). Merge gate after each wave before the next begins.
   Autonomous mode: all agents use `run_in_background: true`.
```

- [ ] **Step 8.5: Clarify code review steps 8–10 Agent Teams scope**

Insert before the step 8 (`/code-review`) line:

```markdown
   **Agent Team scope for steps 8 + 10**: Steps 8 and 10 may use parallel agents (security,
   performance, correctness) with `isolation: "worktree"`.
   Step 9 (`/requesting-code-review`) is human-facing — runs sequentially after step 8
   agent wave resolves; cannot be parallelised.
   Autonomous mode: agent dispatches use `run_in_background: true`.
```

- [ ] **Step 8.6: Extend step 15 (/documentation) with KNOWLEDGE.md + session log**

After the step 15 block's minimum required files list, add:

```markdown
    **Additional required at this step:**
    - Update `docs/KNOWLEDGE.md` Part 2: append dated entries to Architecture patterns,
      Known gotchas, Key decisions, Recurring patterns, Open questions as applicable.
      Resolved questions: append `[RESOLVED YYYY-MM-DD]: <resolution>` below original.
    - Update `docs/CHANGELOG.md`: prepend a new entry (newest first):
      ```
      ## YYYY-MM-DD — <task-slug>
      **What**: one sentence
      **Commits**: <hashes>
      **Skills run**: <list>
      **Virtual cost**: ~$X.XX (Model, complexity)
      **KNOWLEDGE.md**: updated (<sections>) | no changes
      ```
      Virtual cost complexity tiers: simple < 5 files / < 300 lines changed;
      medium 5–15 files or 300–1000 lines; complex > 15 files or architectural.
      Sonnet base rate; Opus ≈ 3× multiplier.
    - Complete the session log: read path from `/tmp/.silver-bullet-session-log-path`,
      edit that file to fill in Task, Approach, Files changed, Skills invoked,
      Agent Teams dispatched, Autonomous decisions, Outcome, KNOWLEDGE.md additions,
      Model, Virtual cost. If `/tmp/.silver-bullet-session-log-path` is missing,
      create `docs/sessions/<today>-manual.md` from the session log template.
    - Documentation agents writing to `docs/` run in the **main worktree only**
      (no `isolation: "worktree"`). Only implementation-touching agents use worktree isolation.
```

- [ ] **Step 8.7: Extend step 17 (CI/CD) with CI polling and blocker rule**

After the step 17 block, add:

```markdown
    **CI verification gate:**
    - Run local verify commands first (from `.silver-bullet.json` `verify_commands`,
      or stack defaults: `npm test` / `pytest` / `cargo test` / `go test ./...`)
    - Check CI: `gh run list --limit 1 --json status,conclusion`
    - **Autonomous mode**: poll every 30 seconds, up to 20 retries (10 min max).
      On timeout: log blocker under "Needs human review", surface in completion summary,
      then proceed.
    - **Interactive mode**: show status. If `in_progress`: inform user, wait for
      confirmation to re-check or proceed.
    - If CI red: log failure, invoke `/gsd:debug`.
    - **Missing ci.yml rule**: if `.github/workflows/ci.yml` is absent at this step,
      Claude must NOT invoke `/deploy-checklist`. Log as blocker under "Needs human review",
      surface missing file to user, stop deployment steps.
    - Race condition: the post-commit hook (ci-status-check.sh) reflects the last
      *completed* run, not necessarily this push. This polling loop is the authoritative gate.
```

- [ ] **Step 8.8: Verify key strings present in template**

```bash
for term in "STEP 0" "MODEL ROUTING" "Agent Team" "KNOWLEDGE.md" "ci.yml" "silver-bullet-mode"; do
  count=$(grep -c "$term" /Users/shafqat/Documents/Projects/silver-bullet/templates/workflows/full-dev-cycle.md 2>/dev/null || echo 0)
  if [[ "$count" -gt 0 ]]; then
    printf 'PASS: "%s" found (%s occurrences)\n' "$term" "$count"
  else
    printf 'FAIL: "%s" not found\n' "$term"
  fi
done
```
Expected: all 6 terms print PASS.

- [ ] **Step 8.9: Commit**

```bash
git add templates/workflows/full-dev-cycle.md
git commit -m "$(cat <<'EOF'
feat: add gap-narrowing enhancements to workflow template

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Update using-silver-bullet SKILL.md (Phase 3)

**Files:**
- Modify: `skills/using-silver-bullet/SKILL.md`

Three additions: (a) update allowed-commands declaration, (b) CI setup step, (c) new file creation in Phase 3.

- [ ] **Step 9.0: Update allowed Bash commands declaration (if present)**

Read `skills/using-silver-bullet/SKILL.md`. If it contains a line declaring allowed Bash commands, update it to also permit `ls` glob patterns and `test -d` (used in CI detection). If no such declaration exists, skip this step.

- [ ] **Step 9.1: Add CI setup step (3.2.5) after directory creation**

In `skills/using-silver-bullet/SKILL.md`, after the `#### 3.2 Create directories` section, insert:

```markdown
#### 3.2.5 CI setup

Check if a GitHub Actions CI workflow exists:
```bash
test -d .github/workflows && ls .github/workflows/*.yml 2>/dev/null | head -1
```

If no CI workflow exists, create `.github/workflows/` and generate `ci.yml` based on the detected stack from Phase 2:

**Node.js** (package.json found):
```yaml
name: CI
on: [push, pull_request]
jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20' }
      - run: npm ci
      - run: npm run lint --if-present
      - run: npm run typecheck --if-present
      - run: npm test --if-present
```

**Python** (pyproject.toml found):
```yaml
name: CI
on: [push, pull_request]
jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: '3.12' }
      - run: pip install -e ".[dev]" || pip install -e .
      - run: ruff check . || true
      - run: mypy . || true
      - run: pytest
```

**Rust** (Cargo.toml found):
```yaml
name: CI
on: [push, pull_request]
jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: cargo clippy
      - run: cargo test
```

**Go** (go.mod found):
```yaml
name: CI
on: [push, pull_request]
jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
      - run: go vet ./...
      - run: go test ./...
```

**Other**: prompt user to specify verify commands. Store in `.silver-bullet.json` under `"verify_commands": ["cmd1", "cmd2"]`.

Also update `.silver-bullet.json` to add a `"verify_commands"` field matching the generated CI commands, for local use by the CI polling gate at step 17.
```

- [ ] **Step 9.2: Add KNOWLEDGE.md + CHANGELOG + sessions creation to step 3.6**

In the `#### 3.6 Create placeholder docs` section, add after the last existing placeholder file:

```markdown
**`docs/KNOWLEDGE.md`**:

Read `${PLUGIN_ROOT}/templates/KNOWLEDGE.md.base` using the Read tool. Replace `{{PROJECT_NAME}}` with the confirmed project name and `{{GIT_REPO}}` with the confirmed repo URL. Write to `docs/KNOWLEDGE.md`.

**`docs/CHANGELOG.md`** (task log — distinct from root-level CHANGELOG.md if present):

Read `${PLUGIN_ROOT}/templates/CHANGELOG-project.md.base` using the Read tool. Write as-is to `docs/CHANGELOG.md`.

**`docs/sessions/` directory:**

```bash
mkdir -p docs/sessions && touch docs/sessions/.gitkeep
```
```

- [ ] **Step 9.3: Verify skill file updated**

```bash
grep -c "CI setup\|verify_commands\|KNOWLEDGE.md.base\|CHANGELOG-project\|sessions/.gitkeep" \
  /Users/shafqat/Documents/Projects/silver-bullet/skills/using-silver-bullet/SKILL.md
```
Expected: `≥ 4`

- [ ] **Step 9.4: Commit**

```bash
git add skills/using-silver-bullet/SKILL.md
git commit -m "$(cat <<'EOF'
feat: add CI setup, KNOWLEDGE.md, CHANGELOG, sessions to SB init

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: Apply changes to current project files

**Prerequisite: Task 8 must be complete before Step 10.4.**

**Files:**
- Create: `docs/KNOWLEDGE.md`
- Create: `docs/CHANGELOG.md`
- Create: `docs/sessions/.gitkeep`
- Replace: `docs/workflows/full-dev-cycle.md`
- Modify: `CLAUDE.md`

- [ ] **Step 10.1: Create docs/KNOWLEDGE.md**

Read `templates/KNOWLEDGE.md.base`. Replace `{{PROJECT_NAME}}` with `silver-bullet` and `{{GIT_REPO}}` with `https://github.com/alo-exp/silver-bullet.git`. Write result to `docs/KNOWLEDGE.md`.

- [ ] **Step 10.2: Create docs/CHANGELOG.md**

Read `templates/CHANGELOG-project.md.base`. Write as-is to `docs/CHANGELOG.md`.

Note: the root-level `CHANGELOG.md` is the SB release log — leave it untouched.

- [ ] **Step 10.3: Create docs/sessions/.gitkeep**

```bash
mkdir -p /Users/shafqat/Documents/Projects/silver-bullet/docs/sessions
touch /Users/shafqat/Documents/Projects/silver-bullet/docs/sessions/.gitkeep
```

- [ ] **Step 10.4: Replace docs/workflows/full-dev-cycle.md (requires Task 8 complete)**

Read `templates/workflows/full-dev-cycle.md` (which now contains all Task 8 additions). Write its content to `docs/workflows/full-dev-cycle.md`.

- [ ] **Step 10.5: Append Sections 4 and 5 to project CLAUDE.md**

Check if sections already present:
```bash
grep -c "Session Mode\|Model Routing" /Users/shafqat/Documents/Projects/silver-bullet/CLAUDE.md || echo 0
```
If output is `0`: read `templates/CLAUDE.md.base`, extract the content from `## 4. Session Mode` to end of file, and append it to `CLAUDE.md`.
If output is `2`: skip this step — sections already present.

- [ ] **Step 10.6: Verify all files present and correct**

```bash
# Files exist
ls /Users/shafqat/Documents/Projects/silver-bullet/docs/KNOWLEDGE.md \
   /Users/shafqat/Documents/Projects/silver-bullet/docs/CHANGELOG.md \
   /Users/shafqat/Documents/Projects/silver-bullet/docs/sessions/.gitkeep

# CLAUDE.md has new sections
grep -c "Session Mode\|Model Routing" /Users/shafqat/Documents/Projects/silver-bullet/CLAUDE.md
# Expected: 2

# Workflow is the new template (not stale 31-step copy)
grep "gsd:execute-phase" /Users/shafqat/Documents/Projects/silver-bullet/docs/workflows/full-dev-cycle.md | head -2
# Expected: ≥ 1 match

# KNOWLEDGE.md placeholder substituted
grep "alo-exp/silver-bullet" /Users/shafqat/Documents/Projects/silver-bullet/docs/KNOWLEDGE.md
# Expected: 1 match
```

- [ ] **Step 10.7: Commit**

```bash
git add docs/KNOWLEDGE.md docs/CHANGELOG.md docs/sessions/.gitkeep \
        docs/workflows/full-dev-cycle.md CLAUDE.md
git commit -m "$(cat <<'EOF'
feat: apply gap-narrowing changes to installed project files

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: Final verification

Note: Steps 11.3 must run in the same shell session that built the test files, OR use the committed paths in `tests/hooks/`. The committed test files are the canonical version.

- [ ] **Step 11.1: Verify all new/modified files exist**

```bash
echo "=== Hook scripts ===" && \
  ls -la /Users/shafqat/Documents/Projects/silver-bullet/hooks/session-log-init.sh \
         /Users/shafqat/Documents/Projects/silver-bullet/hooks/ci-status-check.sh && \
echo "=== Test drivers ===" && \
  ls -la /Users/shafqat/Documents/Projects/silver-bullet/tests/hooks/test-session-log-init.sh \
         /Users/shafqat/Documents/Projects/silver-bullet/tests/hooks/test-ci-status-check.sh && \
echo "=== Templates ===" && \
  ls -la /Users/shafqat/Documents/Projects/silver-bullet/templates/KNOWLEDGE.md.base \
         /Users/shafqat/Documents/Projects/silver-bullet/templates/CHANGELOG-project.md.base \
         /Users/shafqat/Documents/Projects/silver-bullet/templates/sessions/session-log.md.base && \
echo "=== Project files ===" && \
  ls -la /Users/shafqat/Documents/Projects/silver-bullet/docs/KNOWLEDGE.md \
         /Users/shafqat/Documents/Projects/silver-bullet/docs/CHANGELOG.md \
         /Users/shafqat/Documents/Projects/silver-bullet/docs/sessions/.gitkeep
```

- [ ] **Step 11.2: Verify hooks.json is valid and has correct entry count**

```bash
jq '.hooks.PostToolUse | length' /Users/shafqat/Documents/Projects/silver-bullet/hooks/hooks.json
```
Expected: `6`

- [ ] **Step 11.3: Run all hook tests from committed paths**

```bash
bash /Users/shafqat/Documents/Projects/silver-bullet/tests/hooks/test-session-log-init.sh && \
bash /Users/shafqat/Documents/Projects/silver-bullet/tests/hooks/test-ci-status-check.sh
```
Expected: `All tests passed.` for each.

- [ ] **Step 11.4: Check git log shows all commits**

```bash
git log --oneline -12
```
Expected: 10+ commits from this plan (Tasks 1–10) plus earlier project commits.

- [ ] **Step 11.5: Check git status is clean**

```bash
git status
```
Expected: `nothing to commit, working tree clean`

---

*Generated: 2026-04-02 | Silver Bullet v0.2.0 | Spec: docs/specs/2026-04-02-gap-narrowing-design.md*
