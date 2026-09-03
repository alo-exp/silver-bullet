---
name: "silver:context"
title: "Context"
description: This skill captures phase context, decisions, assumptions, constraints, and open questions before planning.
argument-hint: "<phase or change description> [--assumptions] [--auto] [--batch]"
version: 0.2.0
---

# /silver:context - Phase Context

SB-owned context capture records adaptive questioning, locked decisions,
assumptions, constraints, and planner handoff.

Do not delegate core context capture to an external lifecycle plugin. Produce
enough context for an SB plan to be written without re-asking solved questions.

## Modes

| Flag | Behaviour |
|------|-----------|
| (none) | Interactive — ask material unanswered questions one round at a time |
| `--assumptions` | Surface-and-stop — expose the AI's implementation assumptions for the phase without asking any questions. Writes an `ASSUMPTIONS.md` draft; does NOT write `CONTEXT.md`. Use to inspect hidden choices before committing to a direction. |
| `--auto` | Non-interactive — select reasonable defaults for all questions; write CONTEXT.md without pausing |
| `--batch` | Group questions into one prompt for bulk intake instead of round-by-round |

## Output

Write or update the narrowest applicable context artifact:

- `.planning/CONTEXT.md` for project-level context.
- `.planning/phases/<phase>/CONTEXT.md` for phase-level context.
- `.planning/phases/<phase>/ASSUMPTIONS.md` when `--assumptions` is used.
- `.planning/SPEC.md` references when context changes acceptance criteria.

## Process

### Standard mode (no flags)

1. Display `SILVER BULLET > CONTEXT`.
2. Read existing `.planning/PROJECT.md`, `.planning/REQUIREMENTS.md`,
   `.planning/ROADMAP.md`, `.planning/STATE.md`, `.planning/SPEC.md`, and any
   current phase context or plan files that exist.
3. Ask only material unanswered questions. Prefer 3 or fewer questions per
   round. Do not ask questions already answered by artifacts.
4. Record decisions, constraints, risks, assumptions, non-goals, dependencies,
   and unresolved questions.
5. Mark each assumption with owner and status: Accepted, Follow-up-required, or
   Blocking.
6. End with a planning handoff section containing scope, out-of-scope items,
   acceptance criteria references, and unresolved blockers.

### `--assumptions` mode

Use when you want to see what implementation decisions the agent would make on
its own — before committing to an interactive session. This is a diagnostic
tool, not a replacement for full context capture.

1. Display `SILVER BULLET > CONTEXT (assumptions mode)`.
2. Read all available artifacts (same as standard mode).
3. For the given phase or change description, enumerate:
   - **Architecture assumptions**: library choices, patterns, data structures
   - **Behavior assumptions**: edge case handling, error strategy, defaults
   - **Scope assumptions**: what is included and excluded from the phase goal
   - **Integration assumptions**: how the new work connects to existing code
   - **Risk assumptions**: what the agent considers the hardest parts
4. Write to `.planning/phases/<phase>/ASSUMPTIONS.md`:
   ```markdown
   # Implementation Assumptions — <phase name>

   Generated: YYYY-MM-DD
   Status: DRAFT — review before planning

   ## Architecture
   | Assumption | Confidence | Alternative |
   |------------|------------|-------------|

   ## Behavior
   | Assumption | Confidence | Alternative |
   |------------|------------|-------------|

   ## Scope
   | Assumption | Confidence | Alternative |
   |------------|------------|-------------|

   ## Integration
   | Assumption | Confidence | Alternative |
   |------------|------------|-------------|

   ## Risks
   | Assumption | Confidence | Alternative |
   |------------|------------|-------------|

   ## Recommended questions
   <3–5 questions the user should answer to override the riskiest assumptions>
   ```
5. Present the assumptions to the user and invite them to accept, override, or
   ask follow-up questions. If the user accepts and wants to continue, proceed
   with a normal context session (convert to CONTEXT.md).

## Exit Gate

Standard/`--auto`/`--batch`: Context is complete only when:

- blockers are either resolved or explicitly labeled Blocking;
- assumptions are visible to the planner;
- the handoff is specific enough for `silver:plan` to create tasks and
  verification criteria.

`--assumptions` mode: complete when ASSUMPTIONS.md is written and presented.
