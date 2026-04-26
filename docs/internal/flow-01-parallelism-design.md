# FLOW-01 — FLOW Layer Parallelism in /silver Composer: Design Note

**Status:** Design only (implementation deferred)
**Phase:** 64 — Verification & Init Improvements
**Requirement:** FLOW-01
**GitHub issue:** https://github.com/alo-exp/silver-bullet/issues/75

---

## Current State

The `/silver` composer (`skills/silver/SKILL.md`) routes user intent to a single workflow skill and invokes it sequentially. Each `silver-*` workflow (`silver-feature`, `silver-ui`, `silver-bugfix`, `silver-release`, etc.) is itself a sequential FLOW composition:

```
DISCUSS → QUALITY GATES → PLAN → EXECUTE → VERIFY → REVIEW → FINALIZE → SHIP
```

There is no parallelism at the FLOW layer today. The composer dispatches one skill at a time, and each skill in the chain waits for the previous one to complete before starting.

---

## What FLOW Layer Parallelism Means

A "FLOW" in Silver Bullet terminology is one composable path through the workflow (e.g., FLOW 1 = DISCUSS, FLOW 2 = PLAN, FLOW 3 = EXECUTE, etc.). FLOW layer parallelism means running two or more FLOWs simultaneously within a single composer invocation, or running the same FLOW across multiple independent work items concurrently.

Two forms of parallelism are relevant to the `/silver` composer:

### Form 1: Multi-feature Parallelism

Two independent `silver-*` workflows running concurrently. Example: `silver-feature` for Feature A and `silver-bugfix` for Bug B run in parallel because they touch different files and have no shared dependency.

**Trigger signals** (what causes the composer to propose parallel execution):
- User input contains conjunctions: "and also", "while also", "in parallel with", "at the same time as"
- User explicitly names two independent features or bugs in a single invocation
- MultAI is available (`~/.claude/.silver-bullet/mode` contains `multi-ai` or equivalent)
- The two work items affect disjoint file sets (detectable via planning artifacts)

**Example input** → parallel routing:
> "Fix the login bug and also add the new dashboard widget in parallel"

Composer response: route `silver:bugfix` for the login bug AND `silver:feature` for the dashboard widget, each in a separate AI agent context.

### Form 2: Intra-workflow FLOW Parallelism

Within a single `silver-*` workflow, certain FLOWs can run concurrently after their shared prerequisite completes.

**Primary candidate:** After EXECUTE completes, VERIFY (automated tests) and REVIEW (code quality) are both read-only operations on the completed codebase. They have no write dependency on each other — running them in parallel reduces total workflow time by up to 50% for the VERIFY+REVIEW segment.

---

## Dependency Model

For FLOW layer parallelism to be safe, a dependency model defines which FLOWs can overlap:

| FLOW | Depends on | Can run in parallel with |
|------|-----------|--------------------------|
| DISCUSS | — | Nothing (requires user input; cannot be parallelized) |
| QUALITY GATES | DISCUSS | Nothing (validates DISCUSS output; sequential by design) |
| PLAN | QUALITY GATES | Nothing (writes execution plans; exclusive write access) |
| EXECUTE | PLAN | Nothing (writes to codebase; exclusive write access) |
| VERIFY | EXECUTE | **REVIEW** (independent writers — produce different output files with no shared write conflict) |
| REVIEW | EXECUTE | **VERIFY** (independent writers — produce different output files with no shared write conflict) |
| FINALIZE | VERIFY + REVIEW | Nothing (aggregates both results; requires both to complete) |
| SHIP | FINALIZE | Nothing (external action; gates on FINALIZE output) |

**Safe parallelism in the current workflow model:**
- VERIFY ‖ REVIEW (only safe parallel pair in the standard `silver-feature` / `silver-ui` flows)
- Two independent `silver-*` invocations with disjoint file sets (Form 1 above)

**Unsafe parallelism (must never be allowed):**
- Any two FLOWs that write to the same file
- PLAN ‖ EXECUTE (EXECUTE depends on PLAN output)
- EXECUTE ‖ EXECUTE for the same codebase path (write-write conflict)

---

## Signal Design for the Composer

When `/silver` receives input, it should detect parallelism signals before routing. The detection happens in Step 2 (classify intent and complexity) of the current routing logic:

**Parallel signal detection rules (proposed addition to `/silver` routing table):**

```
Input: contains "and also" / "simultaneously" / "in parallel" / "at the same time"
  AND the two work items are classifiable as independent workflows
→ Propose: "I can run [workflow-A] and [workflow-B] in parallel if MultAI is available.
            Run together? (A. Yes / B. Sequential)"
```

**Intra-workflow parallelism offer (proposed addition to `silver-feature` FLOW composition):**

After EXECUTE completes, before routing to VERIFY:
```
"EXECUTE complete. VERIFY and REVIEW can run in parallel — both are read-only.
 Run them together? (A. Yes / B. Sequential)"
```

If user selects A: spawn two AI contexts, one for VERIFY, one for REVIEW. FINALIZE aggregates both SUMMARY outputs.

---

## Implementation Prerequisites (All Deferred)

All items below are prerequisites for FLOW layer parallelism. None are currently built.

| Prerequisite | Description | Blocking for |
|---|---|---|
| **MultAI integration** | Ability to spawn two AI agent contexts from the composer and collect both results | Form 1 + Intra-workflow |
| **WORKFLOW.md current-flow parser** | Must detect which FLOWs are complete vs in-progress to determine the safe parallel window | Intra-workflow (VERIFY ‖ REVIEW offer) |
| **Result merge protocol** | When VERIFY and REVIEW both produce reports, FINALIZE must merge them into a coherent view | Intra-workflow |
| **File conflict detection** | Two parallel FLOWs must not write the same file; pre-dispatch check against planned file sets | Form 1 + Intra-workflow |
| **Parallel state tracking** | WORKFLOW.md Flow Log must support recording two simultaneous active flows | Intra-workflow |

Until MultAI integration is built, FLOW layer parallelism can be simulated by having the user manually invoke both FLOWs in separate Claude sessions — the composer can detect this case and offer split-invocation instructions rather than true parallel execution.

---

## Relationship to VFY-01

Both FLOW-01 and VFY-01 depend on the same foundational piece: a `current_flow_name()` parser in `workflow-utils.sh`. VFY-01 needs it to know whether the active flow is EXECUTE/VERIFY before enforcing the plan-boundary verification check. FLOW-01 needs it to determine the safe window for proposing the VERIFY ‖ REVIEW parallel offer. Implementing the parser once satisfies both.

---

## References

- `skills/silver/SKILL.md` — current routing logic and Composer note
- `skills/silver-feature/SKILL.md` — FLOW composition template (DISCUSS → SHIP sequence)
- `hooks/lib/workflow-utils.sh` — flow log parsing utilities (foundation for current-flow parser)
- `.planning/WORKFLOW.md` — per-project FLOW log (active flow tracking)
- `docs/internal/vfy-01-enforcement-design.md` — related design (shares workflow-utils.sh dependency)
- GitHub issue #75 — FLOW-01 tracking issue
