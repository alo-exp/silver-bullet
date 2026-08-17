# RFL Ladder 3 — Opus 5 Max — REVIEW ONLY (saved by ACCEPT worker)

**Reviewer:** Opus 5 Max ([`sb-opus-5-max`](511a9a49-a7a9-434d-8760-9a7cde177082); not delegated; no Fast; ladder 4 not started)
**Date:** 2026-08-16
**Branch:** `main` (no switch; this file saved by the ACCEPT worker after parent verified the findings)
**Read order:** [SB-PRODUCT-OVERVIEW-FOR-REVIEWERS.md](../SB-PRODUCT-OVERVIEW-FOR-REVIEWERS.md) → [router_subagent_surfaces_85bf9f09.plan.md](../../router_subagent_surfaces_85bf9f09.plan.md) → [router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md](../../router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md)
**Frozen SHA-256 at review time (both copies matched):** `5eba7e86c040c4965b43446a4454bde8064904a9e52c0f69d2a80f542f795216`
**ACCEPT SHA-256 (both copies, after round-21 incorporation):** `c9511f2daa336ef34f30271348085c885e19903eb8243ddb53832980279aaddf`

Body below is the reviewer's verbatim Max output (not invented).

SHA verified before review: both copies matched `5eba7e86…95216`, so the spec was frozen throughout.

```
VERDICT: CLEAN
```

Frozen-plan gate passed: both copies hash to `5eba7e86c040c4965b43446a4454bde8064904a9e52c0f69d2a80f542f795216`, branch `main`, no edits/commits/switches.

## Blockers

None.

## Highs

None. The three round-20 ACCEPT Mediums are landed and verifiable:

- **M-A (row 42)** — L667 now states the spawn target is in scope and explicitly warns against reading "sibling / non-parent" as the spawn target; the doctor-warning carve is scoped to a third present host that is neither parent nor spawn target, and Init-time sibling warn is bounded to "no spawn target yet."
- **M-B (Advisor gate)** — the catalog-dispatch escape is closed at every site that grants it: L181 (both Owns and Must-not cells), L247, L664 row 39, plus L80/L120/L751-752. `type: precomposed` is explicitly stated not to mean skip-Advisor for this route.
- **M-C (derived-surface sync)** — L753 names source `templates/orchestrator-workers/NEW-WORKFLOW.md`, the generated mirror via `scripts/sync-templates.sh`, and the installed `.silver-bullet/orchestrator-workers/NEW-WORKFLOW.md` following install.

## Mediums (new)

**M-1 (consistency / hosts) — the `/silver:new-workflow` route keeps the `silver-` public prefix that the ship-wide rename lock forbids.** The plan locks public identifiers three times: L24 "public IDs `sb` / `sb:` / `/sb` only; no dual `/silver` window", L564 "Public names are `sb` / `sb:` / `/sb` only. No dual `/silver` window", and L695 "No migrate window that keeps `/silver` working as a public prefix." But this one route is carried the other way round. The L120 route header names `/silver:new-workflow` as the route and demotes `/sb:new-workflow` to an "alias"; row 39 at L664 names `/silver:new-workflow` first as a live runtime `wf_mint` path; WFM-01 (L733) and traceability (L854) both use the `/silver:` form. Across the whole plan `/silver:new-workflow` appears 12 times against 2 for `/sb:new-workflow`, and the `silver-new-workflow` slug appears 26 times against **zero** occurrences of any `sb-new-workflow` slug.

The asymmetry is sharpest inside the workstreams: L751 updates `skills/sb/SKILL.md` with the explicit gloss "(historical `skills/silver/SKILL.md` under the `silver`→`sb` rename)" and L771 does the same for `skills/sb-init/`, while L753 hands WS2 `skills/silver-new-workflow/SKILL.md`, `plugins/silver-bullet/commands/silver-new-workflow.md`, `site/help/workflows/silver-new-workflow.html`, and `tests/scripts/test-silver-new-workflow.sh` with no rename note at all. An implementer following L753 literally ships a `silver-`prefixed command stub and help page as live public surfaces — which either violates the no-dual-window lock or, once `sb-migrate-from-silver.sh` removes `/silver`, leaves the authoring route with no public id. Note this is a naming/derived-surface gap only: it does not touch the KEEP-REJECT behavior locks (generator bar, authoring session is a Job, Advisor compose, queue-builder retired), all of which read correctly.

**M-2 (consistency / testability) — rows 37 and 40 have no first-match carve for an Executor out-of-plan mint.** Row 37 (`blocked_wf_mint_unauthorized`, L662) fires on "any non-Advisor `wf_mint` / `wf_invoke` … without Authorizer admit / role permission," and its role enumeration includes Executor. Row 40 (`blocked_executor_wf_out_of_plan`, L665) fires on an Executor mint "without a cited `plan_node_id` / WBS id from the validated Work Plan, or new product scope." Since L249 makes Executor mint legal *iff* the launched WF supports a Work Plan node, an uncited or out-of-plan Executor mint is by construction "without role permission" and therefore satisfies row 37 too — and 37 precedes 40 under first-match. Row 37's own resume text ("Authorizer-admit then retry only if the role is permitted (Executor in-plan; Advisor compose)") reinforces the overlap rather than resolving it.

The plan is careful with this pattern everywhere else — rows 1/4, 8/33, 11/12→41/42, 20→41/42, row 22 excluding 36–42, and row 37's own "Orchestrator stays row 39" — but the symmetric carve is missing: the string "stays row 40" appears nowhere in the document, while "stays row 39" appears twice. This also bears on WFM-01 (L733), which requires 37 / 39 / 40 to be provable as three distinct golden fixtures; an ambiguous 37/40 boundary makes that fixture set unfalsifiable. Not the same issue as the KEEP-REJECT "agent-* in-plan Executor minter" lock, which governs who may mint, not how a bad mint classifies.

## Lows / observations

- **L-1 (document integrity)** — L6 (frontmatter todo, capability-contract) contains an adjacent verbatim duplicate of the parenthetical "(Codex may stamp sentinel `unbounded`; consumers MUST accept the non-integer token; integer `> 0` / `== 0` apply only when numeric)". Cosmetic; the normative body text is not duplicated.

## Hosts / five-tool / control plane / consistency

- **`remaining_depth` sentinel vs integer** — consistent. No line asserts a bare integer type for the field; L80 states "Codex `unbounded` is not integer 0", the sentinel is referenced 23 times, and the depth unit is hops below main (Cursor 2, Claude 3) with refuse-then-parent-proxy at exhaustion (`host_nest_refused`, `VAL/TST-RFL-623`).
- **Five-tool vs OpenCode/Pi** — consistent across all five statements (L80, L419, L570, L732, L853): instruction-only runtimes are probe-exempt, ancestor parent-proxy satisfies the opted-in stack, and they explicitly remain selectable rather than being unselected on probe failure.
- **Host Init writes / HINST-01 3+2** — coherent. Rows 11/12 are carved so install/reference failures classify as 41/42, instruction-only hosts are excluded from closest-replacement when the recorded tuple was installable, and parent-proxy is explicitly not an install substitute (HINST-01 B4).
- **Executor in-plan mint** — the round-16 retraction of the catalog-only invent ban reads consistently at L249, L732, and L853; the only residual issue is the M-2 classification boundary above.
- **FAST vs Job** — no retained prose calls FAST a Job, mints `original_intent_hash`, or takes a GST row; thin capture remains the sole obligation with the three documented receipts.
- **`/sb:agent-*` 3+2 install** — consistent: `nested_executor` class, not new WFs, installable hosts get ensure and instruction-only hosts get instruction wiring only.

Files touched: none.
