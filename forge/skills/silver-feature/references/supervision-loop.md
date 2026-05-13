# Supervision Loop — Detailed Reference

The supervision loop runs BETWEEN each flow completion in silver-feature and silver-ui. It checks exit conditions, evaluates composition changes, detects stall, advances, and reports progress.

## SL-1: Exit Condition Check (D-07.1)

Verify the flow's exit condition was met (per `docs/composable-flows-contracts.md`). If the exit condition is NOT met:

```
⚠ FLOW {name} exit condition not met: {condition description}
Options:
  A. Retry FLOW {name}
  B. Skip with reason (document in WORKFLOW.md)
  C. Insert FLOW DEBUG before next flow
```

## SL-2: Composition Evaluation (D-07.2)

Re-evaluate context for dynamic insertion triggers:

- **Execution failed** → insert FLOW DEBUG before next flow (per D-11):
  - Record in WORKFLOW.md Dynamic Insertions table: `| After {name} | FLOW DEBUG | Execution failed: {reason} | {timestamp} |`
- **UI files discovered in SUMMARY.md** → insert FLOW DESIGN CONTRACT if not already in composition (per D-11, D-12):
  - Check SUMMARY.md for `*.tsx`, `*.css`, `*.html`, or `design/` references
  - Record in WORKFLOW.md Dynamic Insertions table: `| After {name} | FLOW DESIGN CONTRACT | UI files discovered | {timestamp} |`

## SL-3: Anti-Stall Check (D-07.3)

Run 4-tier anti-stall detection:

**Tier 1 — Progress-based (D-16):** If no WORKFLOW.md flow advancement in 10 minutes of execution wall-clock time, display:
```
⚠ STALL DETECTED: No flow advancement in 10 min. Continue? [Y/debug/skip]
```

**Tier 2 — Permission-stall (D-17):** If blocked waiting for user input >5 min in autonomous mode, auto-select recommended option (the first/default option) and log to WORKFLOW.md Autonomous Decisions table:
```
| {ISO timestamp} | Auto-selected option A for {decision} | Permission-stall: >5min wait in autonomous mode |
```

**Tier 3 — Context exhaustion (D-18):** Monitor context window usage:
- If context >80%: display `/compact recommendation: Context window at ~80%. Consider running /compact before continuing.`
- If context >90%: display `Context exhaustion imminent. Running /compact before continuing.` then invoke `/compact`

**Tier 4 — Heartbeat sentinel (D-19):** Each flow invocation writes a heartbeat timestamp to WORKFLOW.md (`Last-flow:` and `Last-beat:` fields). If heartbeat gap >15 minutes, display:
```
⚠ HEARTBEAT GAP: FLOW {name} may have stalled. Options: [retry/skip/debug]
```
Heartbeat timestamps use ISO 8601 format (e.g., `2026-04-15T10:30:00Z`).

## SL-4: Advance (D-07.4)

Move to the next flow in the composition chain.

## SL-5: Progress Report (D-09)

Display progress after each flow:

```
FLOW {current}/{total}: {name} ✓ | Context: ~{percent}% | Remaining: {list of remaining flows}
```

## SL-6: WORKFLOW.md Update (D-10)

Write flow status and timestamp to WORKFLOW.md Flow Log table:

```
| {#} | FLOW {name} | complete | {artifacts produced} | ✓ |
```

Also update heartbeat fields:
```
Last-flow: {N}
Last-beat: {ISO timestamp}
```
