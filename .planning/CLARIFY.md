# SB SDLC Interception And Workflow Enforcement v0.37.0

## Problem Statement

Silver Bullet is meant to act as a hand-holding orchestrator and process enforcer, not just a router. The desired behavior is that any non-trivial user instruction inside SDLC scope is intercepted and converted into a dynamically composed workflow, so interaction with the SE agent stays methodical instead of ad hoc.

The current gap is that this vision is only partially realized in runtime behavior, especially in Codex. The repo already documents the routing/composition model, but the enforcement path that reliably catches SDLC intent across both Claude and Codex still needs to be designed and implemented.

Codex helper-skill discoverability was discussed separately, but it is not part of the v0.37.0 milestone scope.

## Current Context

- The repo already has canonical SB sources in `silver-bullet.md`, `docs/composable-flows-contracts.md`, and the `skills/silver/*` tree.
- The repo also has generated runtime bundles for both `agents/claude` and `agents/codex`.
- The existing `/silver` router already classifies many intent types and maps them to `silver:*` workflows or `gsd:do`.
- GSD remains the lifecycle authority for planning, execution, verification, and release. SB is the orchestration and enforcement layer on top.
- The work is a new milestone, not a patch to the completed v0.35.4 agents-directory reorg.
- The intended `silver:clarify` / brainstorming / PM synergy still needs to be preserved in the workflow design.

## Options Considered

1. **Router-only tightening**
   - Improve intent classification and workflow selection in the canonical SB router.
   - Regenerate Claude and Codex bundles from that source.
   - Lowest risk, but may still leave bypass gaps at host/runtime boundaries.

2. **Host-level enforcement**
   - Add interception/guard rails in both runtime surfaces so non-trivial SDLC intent cannot skip the workflow router.
   - Strongest enforcement, but more host-specific and harder to keep symmetric.

3. **Hybrid rollout**
   - First stabilize the canonical routing and flow contracts.
   - Then add host-specific interception where each runtime can support it.
   - Best balance of correctness, portability, and delivery risk.

## Recommendation

Use the hybrid rollout.

Make the canonical router and flow contracts the source of truth, keep Claude and Codex aligned through generated bundles, and add host-specific interception hooks only where needed to guarantee that non-trivial SDLC intent is routed before ad hoc execution.

This is the best fit because the desired behavior is cross-runtime, but the mechanics of interception are likely to differ between Claude and Codex.

## Assumptions

- SDLC scope is determined by user intent, not by file type alone.
- Q&A, trivial edits, and explicitly non-SDLC requests should remain direct.
- GSD continues to own plan, execute, verify, and ship semantics.
- Both hosts should consume the same logical workflow model, even if their runtime hooks differ.
- The first milestone should improve enforcement without replacing GSD's lifecycle authority.

## Open Questions

- What exact intent patterns count as SDLC versus Q&A or trivial?
- Should v1 intercept only freeform routed instructions, or also message submission and tool-use boundaries?
- What is the minimum enforcement guarantee required for Claude and for Codex?
- Should the first milestone cover orchestration only, or orchestration plus completion verification?
- Which runtime-specific hooks are actually available in Codex for interception, and which need to be simulated at the router layer?

## Next-Step Notes For GSD

Start a new milestone for the SB orchestration/enforcement overhaul, then run `/gsd:discuss-phase` to lock:

- the SDLC scope boundary
- the interception surface per host
- the minimum enforcement guarantee for v1
- the exact workflow composition rules for non-trivial instructions

Once those decisions are locked, planning can break the work into implementable phases for both Claude and Codex.
