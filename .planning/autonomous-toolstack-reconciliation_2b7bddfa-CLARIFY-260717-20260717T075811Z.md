# Clarify Brief — Autonomous Five-Tool Toolstack Reconciliation

Input plan: [autonomous-toolstack-reconciliation plan](autonomous-toolstack-reconciliation_2b7bddfa.plan.md)
Mode: interactive `/silver:clarify` (text-only; no visual companion — the topic is infrastructure/hooks, not UI)
Input maturity: phase-ready handoff (a detailed, already review-fix-laddered plan)

## Problem statement

This session surfaced concrete toolstack failures for an end user of Silver Bullet: Graphify MCP shipped without the `[mcp]` extra, LeanCTX kept re-inserting its shell-rewrite hook after Cursor restarts, and a `graphify-out/` index was missing in a git worktree. The plan consolidates installer, `/silver:init`, `/silver:update`, SessionStart, and `/silver:doctor` around one consent-aware, host-aware reconciliation engine so SB can install, verify, repair, and truthfully report the five tools without duplicate ownership or false health claims. Clarify only needed to resolve delivery, host, ship-path, and validation forks — the technical contracts were already settled by the review-fix ladder.

## Current context

- The plan passed a single-rung GPT-5.6 Sol High review-fix ladder with two clean verify passes.
- Repo stack is Bash for hooks/scripts, so the engine is `scripts/reconcile-recommended-tools.sh` (Bash), consistent with the codebase.
- Global toolstack (`~/.cursor/`) was already deployed and parity-verified this session; the recurring LeanCTX regression is the main live instability.

## Decisions (this clarify session)

1. Delivery scope: PHASED.
   - Phase A = Sections 1-3 (canonical engine, Graphify + worktree indexing, route/hook ownership + heartbeat).
   - Phase B = Sections 4-7 (installer, `/silver:init`, `/silver:update` + SessionStart, `/silver:doctor`).
   - Phase C = Sections 8-10 (reload receipts + host evidence, tests, docs/mirrors).
2. Host scope: CURSOR ONLY for the first implementation; keep the engine host-neutral by contract, but implement and verify Cursor paths first. Claude/Codex parity is deferred.
3. Ship path: MERGE TO MAIN without a version bump or plugin release for now.
4. LeanCTX shell rewrite: EITHER — investigate LeanCTX internals first, then choose the more robust of (a) removing LeanCTX shell-rewrite ownership entirely in `five_tool_routed`, or (b) keeping the observer but always reordering RTK-first with per-session self-heal. Add a short investigation spike as a Phase A deliverable.
5. Validation bar: TARGETED per phase — new/focused five-tool tests + `bash -n` shell syntax checks + ShellCheck where available; run the full `bash tests/run-all-tests.sh` once at the end (before the final merge), not per phase.
6. Section 10 scope: KEEP docs correctness + mirror-freshness work in scope now; DEFER the plugin release / 100% site review / tag / CI-green release-gate steps until a release is actually cut.

## Options considered (and why the chosen path wins)

- Delivery: all-at-once vs phased vs engine-only. Phased wins because Sections 1-3 fix the live regressions and establish the contract other sections depend on, while keeping each merge reviewable.
- Host: Cursor-only vs multi-host now. Cursor-only wins because the observed failures and the runtime in use are Cursor; host-neutral contracts keep parity cheap later without paying for it now.
- Ship: release vs merge-only vs decide-later. Merge-only matches "no release pressure" and avoids a premature version bump; release-gate steps remain documented for when a release is cut.
- LeanCTX: remove vs reorder vs investigate-then-decide. Investigate-then-decide avoids guessing at LeanCTX behavior that already regressed once.

## Assumptions (validate during implementation)

- Removing LeanCTX shell ownership does not disable a LeanCTX capability the user relies on (RTK owns shell; LeanCTX keeps wire/read/PathJail/injection). Confirm in the Phase A spike.
- Merging to `main` without a release is acceptable for engine/hook/skill changes (not only `site/**`); global CI on `main` still runs but is not a merge blocker under the chosen bar.
- The new focused suite in `tests/scripts/lib/five-tool-prerelease.sh` can run per-phase without the full suite.

## Unresolved questions

- None blocking. Open item deferred to implementation: final LeanCTX remove-vs-reorder decision, resolved by the Phase A spike with evidence.

## Next-step notes

- Phase context already exists (the plan is phase-ready). Next SB lifecycle step is execution of Phase A once the plan is updated with these decisions; no `silver:context` framing needed.
- Incorporate all six decisions into the plan: add a "Delivery, scope, and ship path (clarified)" section, add the LeanCTX investigation spike to Section 3, relax Section 9's validation cadence to per-phase targeted + final full suite, and mark Section 10 release-gate steps as deferred while keeping docs/mirror work active.
