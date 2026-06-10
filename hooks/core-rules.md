# Silver Bullet — Core Enforcement Rules

> **Motto: Process is non-negotiable. Hooks enforce. Vacuous invocation is a violation.**

## Non-Negotiable Rules (Section 3)

You MUST NOT:
- Invoke helper/plugin skills on your own before Silver Bullet routing or active workflow guidance has selected them
- Skip a required skill because "it's simple" or "already covered"
- Combine steps or claim implicit coverage — each Silver Bullet skill MUST be explicitly invoked through the active runtime's SB-recognized skill invocation channel
- Claim a step is not applicable without explicit user approval
- Proceed to the next phase before completing the current phase's required skills
- Declare work complete without all required_deploy skills recorded in the state file

## Enforcement Model (Section 1)

Twelve enforcement layers are active. Hooks are invocation-based — the hooks track supported skill invocation events/receipts, not your judgment:

1. **Skill tracker** (Claude Skill events or Codex `silver-bullet invoke-skill`) — records every supported skill invocation to state file
2. **Stage enforcer** (Pre+PostToolUse/Edit|Write|Bash) — HARD STOP if planning incomplete before code edits
3. **Compliance status** (PostToolUse/all) — shows workflow progress on every tool use
4. **Planning file guard** (PreToolUse/Edit|Write|MultiEdit) — blocks direct edits to GSD-managed planning artifacts (ROADMAP.md, STATE.md, etc.); use the owning GSD skill instead
5. **Completion audit** (Pre+PostToolUse/Bash) — blocks commits until planning done; blocks PR/deploy/release until full workflow done
6. **CI status check** (Pre+PostToolUse/Bash) — blocks all actions when CI is failing
7. **Session management** (PostToolUse/Bash) — timeout detection, branch-scoped state reset
8. **Stop hook** (Stop/SubagentStop) — blocks task-complete declaration if required_deploy skills are missing
9. **UserPromptSubmit recorder + reminder** (UserPromptSubmit) — records requested SB/GSD routes and re-injects missing skills before every message
10. **Forbidden skill gate** (PreToolUse/Skill) — blocks deprecated/forbidden skill invocations
11. **ROADMAP freshness gate** (PreToolUse/Bash) — blocks git commit if SUMMARY.md staged but ROADMAP.md checkbox not ticked
12. **Redundant instructions** (CLAUDE.md + workflow file) — same rules enforced across multiple surfaces

## Active Workflow (Section 2)

Read `docs/workflows/full-dev-cycle.md` before starting any non-trivial task. If a required skill cannot be invoked, STOP and notify the user — do NOT silently skip.

Silver Bullet owns the agentic loop in SB-activated projects. On every non-trivial user goal, wait for SB route/workflow guidance first, then invoke only the SB/GSD/helper skills that guidance selects. When an SB-launched workflow step completes, return control to the active SB workflow and let it choose the next step until the user goal is achieved or user feedback is required.

Before planning, editing, debugging, reviewing, or shipping, read the relevant project knowledge and learnings that could affect the action. Prefer Graphify when available (`graphify query "<task context>"` from the project root); otherwise read `docs/knowledge/INDEX.md`, current `docs/knowledge/YYYY-MM.md`, current `docs/learnings/YYYY-MM.md`, and any directly referenced docs.

## Review Loop (Section 3a)

Review loop must produce two consecutive clean passes. Run the audit skill twice in sequence:

1. Invoke the audit skill (e.g. `silver:quality-gates`, `gsd-code-review`, or the applicable review skill)
2. If issues found: fix them, then re-run
3. If clean pass: run the audit again immediately (second pass)
4. If second pass is also clean: two consecutive clean passes confirmed — proceed

**Do NOT write to state files directly.** The tamper-detection hook blocks any Bash command
that writes to the host runtime state root or adjacent files. State is recorded automatically
when skills are invoked through a supported runtime channel:

- Claude Code: the `Skill` tool.
- Codex: the SB-owned `silver-bullet invoke-skill <name>` adapter, which prints the skill body and emits a hook-validated receipt.

Reading `SKILL.md`, editing state files, or manually appending markers never counts.

The two-consecutive-pass requirement is a workflow discipline, not a state file marker.
No hook checks for `review-loop-pass-*` tokens — verification is evidence-based (audit output).

## Anti-Rationalization

These are invalid excuses:
- "I did code review while writing" — implicit coverage does not count
- "This step is not applicable" — requires explicit user approval
- "It's a simple change" — the hooks decide what's trivial, not you
- "I've already covered this" — a supported skill invocation is required, not just the work
