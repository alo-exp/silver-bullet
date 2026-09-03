---
name: "silver:spike"
title: "Spike"
description: >
  Run 2–5 focused feasibility experiments before committing to an
  implementation approach. Each experiment has a hypothesis, executable
  code, and a VALIDATED / INVALIDATED / PARTIAL verdict.
argument-hint: "<technical question or approach to investigate> [--quick] [--wrap-up]"
version: 0.1.0
---

# /silver:spike — Feasibility Experiments

SB-owned spike workflow. Use when you need evidence before choosing an
implementation strategy — not research notes, but running code that proves
or disproves an approach. Each experiment is minimal, targeted, and leaves
no production footprint.

Do NOT use this skill for general research (`silver:deep-research`) or for full
feature planning (`silver:feature`). A spike answers a specific yes/no or
comparison question. If the question is broad enough to require a PLAN.md,
use `silver:plan` instead.

## Output

Write `.planning/spikes/<NNN>-<slug>/README.md` for each experiment and
`.planning/spikes/MANIFEST.md` for the registry.

Each spike README must include:

```markdown
# Spike: <title>

Hypothesis: <what you believe to be true>
Question: <the specific question this experiment answers>
Given/When/Then:
  Given: <preconditions>
  When: <action taken>
  Then: <observable outcome that proves/disproves>

## Experiment

<code, commands, or configuration used>

## Result

VALIDATED | INVALIDATED | PARTIAL

Evidence: <what you observed — output, error, timing, diff>

## Decision

<what this means for the implementation approach>
```

`MANIFEST.md` must include:

```markdown
# Spike Manifest

| ID | Slug | Question | Result | Date |
|----|------|----------|--------|------|
```

## Modes

| Flag | Behaviour |
|------|-----------|
| (none) | Interactive intake — ask clarifying questions before running experiments |
| `--quick` | Skip intake; use `$ARGUMENTS` text as the hypothesis directly |
| `--wrap-up` | Package completed spike findings into a reusable project-local knowledge entry via `silver:rem` |

## Process

1. Display `SILVER BULLET > SPIKE`.

2. **Understand the question.** If not `--quick`, ask at most 3 targeted
   clarifying questions:
   - What are you unsure about?
   - What would change your decision?
   - Are there constraints (language, existing libs, latency budget)?

3. **Decompose into 2–5 experiments.** Each experiment must:
   - Be independently runnable.
   - Answer one clear sub-question.
   - Produce an observable output that counts as evidence.
   - Take no longer than 10–15 minutes of agent time.

   Good experiments: prototype a call to an external API, benchmark two
   algorithms against a realistic data size, try a library's API to verify
   it handles the edge case, run a migration dry-run against a snapshot.

   Bad experiments: "research approaches" with no code, multi-day
   investigations, experiments that modify production data, broad codebase
   exploration (use `silver:scan` for that).

4. **Run experiments in order of risk.** Start with the hypothesis most
   likely to short-circuit remaining experiments if invalidated.

5. **Record each result immediately.** Write the spike README before moving
   to the next experiment. Do not defer recording.

6. **Synthesize.** After all experiments complete, write a one-paragraph
   synthesis in `MANIFEST.md`:
   - Which approach is validated?
   - What constraints or caveats surfaced?
   - What is the recommended next step?

7. **File deferred items.** Any question raised that was out of scope for
   this spike → `silver:add`.

8. **Wrap-up (if `--wrap-up`).** Invoke `silver:rem` with the key findings
   so they survive context compaction and are available in future sessions.

9. **Handoff.** If the spike result feeds a planning decision, surface the
   synthesis in `CONTEXT.md` or pass it as input to `silver:clarify`.

## Experiment Safety Rules

- Experiments run against isolated data, sandboxed environments, or mocks.
  Never run destructive operations against production.
- If an experiment requires credentials, verify they are test/sandbox
  credentials. Refuse if they appear to be production secrets.
- Discard any experimental code that was written purely to test the
  hypothesis; do not leave it in the codebase.
- If `--wrap-up` is specified, record only the decision and evidence —
  never the throwaway code.

## Exit Gate

The spike is complete only when:

- every planned experiment has a result (VALIDATED, INVALIDATED, or PARTIAL);
- `MANIFEST.md` contains a synthesis and a recommended next step;
- any deferred items are filed via `silver:add`.

A spike that ends in PARTIAL on all experiments without a recommended next
step is not a completed spike — surface the ambiguity and ask the user how
to proceed.
