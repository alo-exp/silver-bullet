# Silver Bullet — Core Enforcement Rules

> **Motto: Process is non-negotiable. Hooks enforce. Vacuous invocation is a violation.**

## Non-Negotiable Rules (Section 3)

You MUST NOT:
- Skip a required skill because "it's simple" or "already covered"
- Combine steps or claim implicit coverage — each Silver Bullet skill MUST be explicitly invoked via the Skill tool
- Claim a step is not applicable without explicit user approval
- Proceed to the next phase before completing the current phase's required skills
- Declare work complete without all required_deploy skills recorded in the state file

## Enforcement Model (Section 1)

Ten enforcement layers are active. Hooks are invocation-based — the hooks track Skill tool calls, not your judgment:

1. **Skill tracker** (PostToolUse/Skill) — records every skill invocation to state file
2. **Stage enforcer** (Pre+PostToolUse/Edit|Write|Bash) — HARD STOP if planning incomplete before code edits
3. **Compliance status** (PostToolUse/all) — shows workflow progress on every tool use
4. **Completion audit** (Pre+PostToolUse/Bash) — blocks commits until planning done; blocks PR/deploy/release until full workflow done
5. **CI status check** (Pre+PostToolUse/Bash) — blocks all actions when CI is failing
6. **Session management** (PostToolUse/Bash) — timeout detection, branch-scoped state reset
7. **Stop hook** (Stop/SubagentStop) — blocks task-complete declaration if required_deploy skills are missing
8. **UserPromptSubmit reminder** (UserPromptSubmit) — re-injects missing skills before every message
9. **Forbidden skill gate** (PreToolUse/Skill) — blocks deprecated/forbidden skill invocations
10. **Redundant instructions** (CLAUDE.md + workflow file) — same rules enforced across multiple surfaces

## Active Workflow (Section 2)

Read `docs/workflows/full-dev-cycle.md` before starting any non-trivial task. If a required skill cannot be invoked, STOP and notify the user — do NOT silently skip.

## Review Loop (Section 3a)

Review loop must produce two consecutive clean passes. Run the audit skill twice in sequence:

1. Invoke the audit skill (e.g. `silver:quality-gates`, `gsd-code-review`, or the applicable review skill)
2. If issues found: fix them, then re-run
3. If clean pass: run the audit again immediately (second pass)
4. If second pass is also clean: two consecutive clean passes confirmed — proceed

**Do NOT write to state files directly.** The tamper-detection hook blocks any Bash command
that writes to `~/.claude/.silver-bullet/state` or adjacent files. State is recorded automatically
when skills are invoked via the Skill tool.

The two-consecutive-pass requirement is a workflow discipline, not a state file marker.
No hook checks for `review-loop-pass-*` tokens — verification is evidence-based (audit output).

## Anti-Rationalization

These are invalid excuses:
- "I did code review while writing" — implicit coverage does not count
- "This step is not applicable" — requires explicit user approval
- "It's a simple change" — the hooks decide what's trivial, not you
- "I've already covered this" — Skill tool invocation is required, not just the work
