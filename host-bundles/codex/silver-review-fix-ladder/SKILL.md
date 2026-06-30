---
name: "silver:review-fix-ladder"
title: "Review Fix Ladder"
description: Progressively review and fix scoped artifacts or user-confirmed repo-wide work by escalating through every rung of a host-aware model/reasoning ladder, requiring two consecutive clean passes at each rung before advancing. Use for pre-ship confidence, launch-critical artifacts, and repo alignment checks against context-derived goals.
user-invocable: false
---

# /silver:review-fix-ladder — Progressive Review / Fix Ladder

Escalate review and fix work through a host-aware model/reasoning ladder. Each rung audits, fixes, and verifies against a context-derived review charter — not generic “find issues” heuristics.

**Orchestrator role:** The parent agent (you) MUST personally orchestrate every rung. Subagents execute one phase at a time. You MUST NOT delegate the ladder loop itself to a single subagent.

## When to Use

- Pre-ship confidence on launch-critical artifacts
- Bounded directories, files, or planning artifacts that need progressive review
- Repo-wide alignment checks **only after the user explicitly confirms repo-wide scope**

## Step 0: Resolve Scope

**Do not assume repo-wide scope.**

1. If `$ARGUMENTS` or the user message names explicit file path(s) or directory/directories, lock scope to those paths only.
2. Otherwise, stop and ask:

   > Review scope: whole repo, or specific artifact(s)/directory/directories?  
   > (If specific, provide path(s).)

3. Proceed only after scope is explicit from the initial request or the user's answer.
4. Do **not** derive the charter or resolve the ladder until scope is locked.

| Mode | Trigger | Scope |
|------|---------|-------|
| Explicit scope | User names paths in prompt or `$ARGUMENTS` | Only those paths |
| User-confirmed repo-wide | General invocation → user chooses whole repo | Entire project repo |
| User-provided scope | General invocation → user supplies paths when asked | User-provided paths |

### Scope Lock (HARD)

- **FORBIDDEN** to read, edit, or run commands against paths outside locked scope.
- If scope is two files, **zero** commands in other repos, directories, or test suites.
- Subagents MUST receive the exact locked path list; they MUST NOT expand scope.

## Step 1: Derive Review Charter

Build a short charter from available context. Use what exists; do not invent requirements.

**Primary sources (priority order):**

1. User's explicit request in the current turn
2. `.planning/` artifacts: `SPEC.md` acceptance criteria, `REQUIREMENTS.md`, active `PLAN.md`, `ROADMAP.md` phase goals, `DESIGN.md` constraints
3. `silver-bullet.md` and `.planning/workflows/*.md` exit conditions
4. Recent session logs or handoff notes under `docs/sessions/`

**Required charter output (show to user):**

1. **Scope** — confirmed paths or “whole repo”
2. **Goals** — intended outcomes to verify against
3. **Non-goals** — out of scope for this ladder pass
4. **Verification signals** — grep patterns, line checks, manual checks that prove a goal is met (list each signal with an exact command or search pattern the orchestrator will run)

If context is thin, state assumptions explicitly and keep the charter narrow.

## Step 2: Resolve Ladder

From the project root:

```bash
python3 scripts/review-fix-ladder.py --json
```

Add `--host <runtime> (from `SILVER_BULLET_RUNTIME`) when the host is known.

Print the resolved `host`, `source`, and ordered `rungs` (`model` + `reasoning`) before executing.

## Step 3: Execute Ladder — State Machine (HARD)

### Compliance Gate (MUST run before every rung advance)

**Before starting rung N+1** (or before declaring the ladder complete), the orchestrator MUST self-check the rung just finished. If **any** check fails → **STOP immediately**. Do **not** start the next rung. Do **not** continue advancing while non-compliant.

| Check | Pass criterion |
|-------|----------------|
| Sequential rung | Previous rung completed all states in order: `audit_fix` → `verify_1` → orchestrator grep → `verify_2` → orchestrator grep |
| Separate verify invocations | `verify_1` and `verify_2` were **separate** subagent `Task` calls — not one combined prompt |
| Orchestrator grep | Orchestrator ran **every** charter verification signal between verify passes and logged command + output + pass/fail |
| Scope | No reads, edits, or commands touched paths outside locked scope |
| Readonly verify | Both verify subagents used `readonly: true` (Task-capable hosts) or explicit verify-only directive |
| No parallel rungs | No other rung's audit-fix or verify was launched while this rung was incomplete |
| Advance gate | Advanced to next rung **only** after orchestrator confirmed **two consecutive clean** verify passes |

**On failure:** STOP. Report the violation. Fix the process, skill, or orchestrator prompt. Resume **only** after the fix is in place — re-run the failed phase on the **same** rung, not the next rung.

### Full-Ladder Requirement

- **Default:** Execute **every resolved rung** in order. A clean rung is not a completion condition; it is the gate that permits advancement to the next rung.
- **Two consecutive clean rounds per rung:** For each rung, `verify_1` and `verify_2` must both be clean, and the orchestrator verification signals after each pass must also be clean.
- **Advance after clean rung:** After two consecutive clean rounds and clean orchestrator signals, the orchestrator MUST advance to rung N+1 unless N is the final resolved rung.
- **Stop after first compliance failure** — never "push through" remaining rungs while the process is broken.
- A smoke demonstration may be run only when the user explicitly asks for a smoke test; otherwise the ladder must continue through the final resolved rung.

### STOP Conditions (immediate halt)

STOP and do **not** advance when any of the following is true:

1. **Compliance gate failure** — any row in the compliance gate table fails
2. **Skipped state** — tempted to skip audit-fix, either verify pass, or orchestrator grep
3. **Combined verify passes** — one subagent asked to "do 2 passes" or verify_1 and verify_2 merged
4. **Subagent-only gate** — advancing on subagent VERIFY_PASS without orchestrator grep evidence
5. **Scope violation** — any command or edit outside locked paths
6. **Parallel rungs** — multiple rung phases launched in one turn or overlapping
7. **Verify subagent edited files** — verify pass was not readonly
8. **Final rung complete** — the last resolved rung completed `audit_fix` → `verify_1` → orchestrator signals → `verify_2` → orchestrator signals with no gaps
9. **User stop** — user directs halt or scope change

### Recovery Procedure (before resuming)

When STOP triggers for compliance (items 1–7):

1. **Report** — state which check failed, what was attempted, and what evidence is missing
2. **Fix root cause** — update orchestrator behavior, subagent prompt, or skill/process gap (not "try again blindly")
3. **Re-anchor state** — document current state machine position (`rung_N_verify_1`, etc.)
4. **Re-run failed phase** — on the **same** rung, from the first failed state (usually re-run verify or re-run audit-fix if verify found gaps)
5. **Re-run compliance gate** — only after a clean re-run may you advance, or close out if the final resolved rung is complete
6. **Do not skip ahead** — never compensate for a compliance failure by jumping to a higher rung

### Explicit States Per Rung

For rung N, the orchestrator MUST traverse these states in order:

```
rung_N_audit_fix → rung_N_verify_1 → [orchestrator grep] → rung_N_verify_2 → [orchestrator grep] → rung_N+1_audit_fix
```

**STOP** if tempted to skip any state, combine verify passes, stop early because the charter is satisfied, or advance without orchestrator evidence.

### Anti-Skip Rules (MUST / FORBIDDEN)

1. **One rung at a time** — **FORBIDDEN** to launch multiple ladder rungs in parallel. **FORBIDDEN** to batch `Task` calls for different rungs in one turn. Exactly one subagent `Task` per turn.

2. **Two-pass gate** — Per rung:
   - (a) audit+fix subagent
   - (b) verify-only subagent pass 1 — if clean, proceed; if fail, return to (a) on **same** rung
   - (c) verify-only subagent pass 2 — only if pass 1 was clean
   - Advance to rung N+1 **only** if **both** verify passes are clean; after they are clean, advancement is mandatory unless N is the final resolved rung.
   - **FORBIDDEN** to combine passes into one subagent prompt (e.g. "do 2 passes" in a single Task).
   - **FORBIDDEN** to advance after only one clean verify pass.

3. **Verify-only passes** — Subagents on verify passes MUST NOT edit files. Use `readonly: true` on the host `Task` tool or explicit "verify only, no edits" in the prompt. **FORBIDDEN** for verify subagents to apply fixes.

4. **Orchestrator evidence** — The orchestrator MUST run charter verification signals (grep/checks) between verify passes and record pass/fail with command output. **FORBIDDEN** to advance on subagent self-reported PASS alone. Subagent reports are input; orchestrator grep is the gate.

5. **Scope lock** — **FORBIDDEN** to read/edit/run tests outside locked scope paths.

6. **Model lock** — Each rung uses exactly the `model` + `reasoning` from resolver JSON. **FORBIDDEN** to substitute models unless the host rejects the slug — then document the rejection and use the nearest host-documented slug, one substitution per rung.

7. **State machine** — Document current state in close-out (`rung_N_audit_fix`, `rung_N_verify_1`, etc.). **STOP** if tempted to skip.

8. **No parallel rung launches** — **FORBIDDEN** to launch audit-fix for rung N+1 while rung N verify is incomplete.

### Per-Rung Workflow (Orchestrator Checklist)

For rung `{n}/{total}` at `model={model}`, `reasoning={reasoning}`:

| Step | State | Action |
|------|-------|--------|
| 1 | `rung_N_audit_fix` | Launch **one** audit+fix subagent (can edit scoped files) |
| 2 | `rung_N_verify_1` | Launch **one** verify-only subagent pass 1 (`readonly: true`) |
| 3 | — | Orchestrator runs each charter verification signal; log pass/fail |
| 4 | `rung_N_verify_2` | If step 3 clean: launch **one** verify-only subagent pass 2 (`readonly: true`) |
| 5 | — | Orchestrator runs charter signals again; log pass/fail |
| 6 | advance | If steps 3 **and** 5 are clean, advance to rung N+1 unless N is the final resolved rung; else return to step 1 |

### Repo-wide mode (only after user confirms)

- Walk systematically against charter goals; do not run a blind full-tree audit.
- Prefer high-signal surfaces first: changed files, planning artifacts, entrypoints, tests, configs tied to stated goals.
- Do not expand scope beyond charter non-goals.
- If charter goals are phase-specific, limit edits to that phase's blast radius unless a repo-wide invariant is broken.

## Step 4: Close Out

Report:

- **Compliance log** — per rung: compliance gate pass/fail, any STOP events, recovery actions taken
- Per-rung pass table: rung → verify_1 evidence → verify_2 evidence → advanced (yes/no)
- Charter coverage matrix (goal → evidence / status)
- Residual risks
- Files touched (scoped paths only)
- Final rung reached and **why stopped** (final resolved rung complete, compliance failure, or user stop)

## Host Delegation Notes

| Host | Delegation |
|------|------------|
| **Task-capable host** | `Task` subagent with `model` set to the **composite slug** from `cursor_task_slug()` in `scripts/review-fix-ladder.py` (reasoning effort is encoded in the slug — there is no separate Task reasoning parameter). Ladder order: Composer low → medium → high → xhigh, then GPT-5.5 low → medium → high → xhigh. **All Composer rungs map to `composer-2.5` only** — never `composer-2.5-fast` (global subagent policy). GPT-5.5 maps to `gpt-5.5` for low and `gpt-5.5-extra-high` for medium/high/xhigh by model-lock substitution (not `gpt-5.5-medium`, `gpt-5.5-high`, or `gpt-5.5-xhigh`). Verify passes: `readonly: true`. **Note:** host model picker pinning may filter the Task enum; if a slug is rejected, document the rejection and apply model-lock substitution per rung. |
| **the active host agent** | Subagent with model `primary-model`, `primary host-opus-4-7`, or `primary host-opus-4-8` and thinking `medium`, `high`, or `xhigh` |
| **Secondary host agent** | `Codex exec -m <model> -c model_reasoning_effort=<reasoning>` (native Codex binary, not Kay shim) |

Model slug maps live in `scripts/review-fix-ladder.py` only — not in `silver-bullet.md`.

## Subagent Prompt Templates

### Template A — Audit+Fix (`rung_N_audit_fix`)

Use for the audit+fix phase only. Subagent **may** edit files within scope.

```
You are on rung {n}/{total}: model={model}, reasoning={reasoning}.
Phase: AUDIT+FIX (rung_N_audit_fix)

Scope (do not exceed — FORBIDDEN to touch any other path):
{scope}

Review charter:
- Goals: {goals}
- Non-goals: {non_goals}
- Verification signals: {verification_signals}

Tasks:
1. Audit scoped work against the charter goals.
2. Fix confirmed gaps with the smallest safe change within scope only.
3. Report raw findings, diffs, and what you changed.

FORBIDDEN behaviors:
- Do NOT run verification passes (orchestrator runs those separately).
- Do NOT read/edit/run commands outside locked scope.
- Do NOT claim PASS or recommend advancing — orchestrator verifies.
- Do NOT launch subagents or parallel work.
```

### Template B — Verify-Only (`rung_N_verify_1` or `rung_N_verify_2`)

Use for verify pass 1 and pass 2 separately. Subagent **MUST NOT** edit files.

```
You are on rung {n}/{total}: model={model}, reasoning={reasoning}.
Phase: VERIFY-ONLY pass {pass_num}/2 (rung_N_verify_{pass_num})

Scope (read-only — FORBIDDEN to edit any file):
{scope}

Review charter:
- Goals: {goals}
- Non-goals: {non_goals}
- Verification signals: {verification_signals}

Tasks:
1. Re-read scoped files and audit against charter goals.
2. Report findings with line references. List any remaining gaps.
3. State VERIFY_PASS or VERIFY_FAIL with evidence — do not fix anything.

FORBIDDEN behaviors:
- Do NOT edit, write, or patch any file (verify only).
- Do NOT run fixes or suggest "I'll fix this" — report only.
- Do NOT combine this with pass 2 — this is exactly one verify pass.
- Do NOT read/edit/run commands outside locked scope.
- Do NOT launch subagents or parallel work.
```

### Orchestrator Between Verify Passes

After each verify-only subagent returns, the orchestrator MUST:

1. Run every charter verification signal (grep, line count, pattern checks).
2. Record command + output + pass/fail.
3. Only proceed to the next verify pass if signals are clean; after `verify_2`, proceed to the next rung if signals are clean and another resolved rung remains.
4. **IGNORE** subagent VERIFY_PASS if orchestrator signals fail.
