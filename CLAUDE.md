# silver-bullet — Claude Code Instructions

> **Always adhere strictly to this file — it overrides all defaults.**

---

## 0. Session Startup (Automatic)

At the very start of any new session, perform these steps automatically:

1. **Switch to Opus 4.6 (1M context)** if not already selected.
2. **Read all project docs** — this file and 100% of docs/.
3. **Compact the context** — run /compact to free context for the task.
4. **Switch back to original model** if it was changed in step 1.

---

## Project Overview

- **Stack**: Node.js
- **Git repo**: https://github.com/alo-exp/silver-bullet.git

---

## 1. Automated Enforcement

Seven layers enforce compliance:

1. **PostToolUse — Skill tracker** — Records every Silver Bullet skill invocation
2. **PostToolUse — Stage enforcer** — HARD STOP if quality gates incomplete before plan
3. **PostToolUse — Compliance status** — Shows progress on every tool use
4. **PostToolUse — Completion audit** — Blocks commit/push/deploy if required skills missing
5. **GSD workflow guard** — Detects file edits made outside a `/gsd:*` command and warns
6. **GSD context monitor** — Warns at ≤35% tokens remaining, escalates at ≤25%
7. **Redundant instructions + anti-rationalization** — Workflow file + CLAUDE.md both enforce;
   explicit rules against skipping, combining, or implicitly covering steps

**Trivial changes** (typos, copy fixes, config tweaks): Automatically
detected by hooks. Small edits (<300 chars) and non-logic files (.md,
.txt, .css, .svg, etc.) skip enforcement per-edit. No action needed.
**Note**: In the `devops-cycle` workflow, `.yml`, `.yaml`, `.json`, and
`.toml` files are infrastructure code and are NOT auto-exempted.

**Subagent commits**: Every git commit MUST use HEREDOC format and end with:
Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>

---

## 2. Active Workflow

The active workflow is loaded from `docs/workflows/`. Claude MUST read
the active workflow file before starting any non-trivial task.

**Active**: `docs/workflows/full-dev-cycle.md`

**Skill not found rule**: If a skill listed in the workflow cannot be
invoked, STOP and notify the user immediately. Do NOT silently skip.

---

## 3. NON-NEGOTIABLE RULES

These rules apply to EVERY non-trivial change. There are NO exceptions.

You MUST NOT:
- Skip a REQUIRED step because "it's simple enough"
- Combine or implicitly cover steps ("I did code review while writing")
- Claim a step is "not applicable" without explicit user approval
- Proceed to the next phase before completing the current phase
- Claim work is complete without running `/gsd:verify-work`

If you believe a step is genuinely not applicable, you MUST:
1. State which step you want to skip
2. State why
3. Wait for explicit user approval before proceeding

"I already covered this" is NOT valid. Each Silver Bullet skill MUST be
explicitly invoked via the Skill tool — implicit coverage does not count
because the enforcement hooks track Skill tool invocations, not your judgment.
GSD steps MUST be invoked as slash commands in the correct phase order.

**Rules**:
- Do NOT stop until the final outcome is achieved
- Always use `/gsd:debug` for ANY bug encountered during execution
- Always use `/forensics` for root-cause investigation of completed sessions, abandoned sessions, or verification failures
- CI must be green before deployment. When the CI status hook reports failure after a push, STOP all other work immediately and invoke `/gsd:debug` to investigate. Do NOT proceed to any other step until CI is green.
- README.md MUST be updated to reflect current version, features, and changes before release. /create-release will block if README is stale.
- Always strictly adhere to this CLAUDE.md 100%

## 3a. Review Loop Enforcement

Every review loop (spec review, plan review, code review, verification) **MUST iterate until the reviewer returns ✅ Approved TWICE IN A ROW**. A single clean pass is not sufficient — the reviewer must find no issues on two consecutive passes. There are NO exceptions.

You MUST NOT:
- Stop a review loop because "issues are minor"
- Stop because "it's close enough"
- Accept a partial fix and move on without re-dispatching
- Count a loop as done unless the reviewer explicitly outputs `✅ Approved` on two consecutive passes
- Count a single clean pass as done

The loop is self-limiting: it ends when two consecutive clean passes are produced. Surface to the user only if the reviewer raises an issue it cannot resolve (e.g. requires a decision, a missing dependency, or an external constraint).

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
- **Anti-stall** (non-blocker stalls only): a stall = any of these three conditions:
  1. Same tool call with identical args producing the same result 2+ times consecutively
  2. 3+ tool calls in one step with no new state change (no file written, no decision, no new info)
  3. Per-step budget: >10 tool calls in one step AND no file written (Write/Edit resets counter)
     AND no autonomous decision logged since step began. Counter resets on Write/Edit, on any
     decision log event, and when a new `/gsd:` command or skill is invoked (new step boundary).
  On any stall: make best-judgment decision, move on, log under "Autonomous decisions".
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

---

## 6. GSD / Superpowers Ownership Rules

GSD is the authoritative execution orchestrator. Superpowers provides design and review
capabilities only. Where both tools could apply, **GSD wins**.

**Hard rules — no exceptions:**

- **Execution**: Always use `/gsd:execute-phase` (wave-based). NEVER use
  `superpowers:subagent-driven-development` or `superpowers:executing-plans` for project work.
- **Planning**: Always use `/gsd:plan-phase`. When Superpowers' `brainstorming` skill offers
  to hand off to `writing-plans`, **redirect to `/gsd:plan-phase` instead**.
- **Requirements**: `.planning/REQUIREMENTS.md` is the single source of truth (owned by GSD).
  Superpowers must NOT create or maintain a separate requirements list.
- **Design specs**: Save to `docs/specs/YYYY-MM-DD-<topic>-design.md`.
  Superpowers' default path (`docs/superpowers/specs/`) is overridden — use `docs/specs/`.
- **Code review**: Superpowers' review skills (`/requesting-code-review`,
  `/receiving-code-review`, `superpowers:code-reviewer`) are used for review only.

---

## 7. File Safety Rules

These rules apply to ALL file operations, in every context and session mode.

- **Never overwrite, rename, move, or delete** any existing project file without first
  communicating the objective to the user and obtaining explicit permission.
- Permission may be requested for a logical group of files in one prompt (e.g., "I need to
  update these 3 template files to apply the new workflow — proceed?"), but the intent and
  scope must be clear before any file is touched.
- **When in doubt: skip and inform**, never act and apologize.
- This applies to Silver Bullet setup, template refresh, and all agent/subagent operations.
