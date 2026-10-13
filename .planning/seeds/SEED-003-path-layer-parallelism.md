---
seed_id: SEED-003
title: PATH layer parallelism for independent paths (composer optimization)
github_issue: 75
priority: low
planted_during: v0.30.0 Open-Issue Sweep
planted_at: 2026-04-28
trigger_when:
  - A future milestone surfaces FLOW execution latency as a measured pain point
  - A composer (silver-feature, silver-ui, silver-devops) is observed to spend significant time in independent paths that could overlap
  - User asks "can SB parallelize the FLOW execution"
---

# SEED-003: PATH layer parallelism for independent paths

## Idea

Composer skills (silver-feature et al.) execute their FLOWs sequentially today. Some flows have no read/write dependency on each other and could run as parallel Agent invocations:

- FLOW 2 EXPLORE and FLOW 1 ORIENT can overlap once the project is bootstrapped
- FLOW 8 UI QUALITY and FLOW 9 CODE REVIEW (Layer A static-analysis) can overlap
- Layer A/B/C of the FLOW 9 review structure already overlap conceptually but execute sequentially per D-65

The optimization: a "parallel layer" annotation in WORKFLOW.md that the composer dispatches as a single multi-agent message.

## Why This Matters

Today's wall-clock cost of a composed workflow is dominated by sequential sub-agent dispatch. If we can shave 2-3 sequential agent rounds into one parallel round, downstream feature workflows finish meaningfully faster. This is a pure latency win — no behavioral change.

## When to Surface

- After we have telemetry showing per-flow latency aggregated across real composed-workflow runs.
- When a user complains the silver-feature run took longer than expected.
- When SB-bearing agents start coordinating across a single project (v0.29.x multi-agent foundation) and serialization of independent paths becomes a bottleneck.

## Implementation Sketch (when triggered)

1. Annotate each path in `templates/workflows/*.md` with a `dependencies: [other-path]` field.
2. Build a topological dispatcher in the composer skills: at each step, dispatch all paths whose dependencies are met as a single multi-agent message.
3. Reconcile output ordering — the Flow Log table needs deterministic ordering even when paths complete out of order.
4. Add a `--no-parallel` flag for debugging.

## Why Deferred

The optimization is real but speculative — we don't have measured latency data showing where the bottleneck actually is. Premature parallelization would complicate the composer for unproven gain. Wait for concrete signal before investing in the dispatcher rewrite.

## References

- GitHub issue: https://github.com/alo-exp/silver-bullet/issues/75
- Related: D-65 (parallel-layer dispatch for FLOW 9 code review)
