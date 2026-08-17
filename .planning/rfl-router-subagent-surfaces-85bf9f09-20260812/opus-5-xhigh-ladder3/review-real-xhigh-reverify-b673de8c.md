# RFL Ladder 3 — Opus 5 Extra High — RE-VERIFY REVIEW ONLY (real xhigh; SHA `b673de8c`; saved by ACCEPT worker)

**Reviewer:** Opus 5 Extra High ([`sb-opus-5-xhigh`](8e7aedfa-cc7c-4479-bdf0-948e403f553c); not delegated; no Fast; Max not started)
**Date:** 2026-08-16
**Branch:** `main` (no switch; this file saved by the ACCEPT worker after parent verified the findings)
**Read order:** [SB-PRODUCT-OVERVIEW-FOR-REVIEWERS.md](../SB-PRODUCT-OVERVIEW-FOR-REVIEWERS.md) → [router_subagent_surfaces_85bf9f09.plan.md](../../router_subagent_surfaces_85bf9f09.plan.md) → [router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md](../../router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md)
**Frozen SHA-256 at review time (both copies matched):** `b673de8cc11bb46dfb12ed8bd48fa1d9ecc642f9e4ea4b9047d46b8e9c240c18`

Prior Extra High remains in [`review-real-xhigh.md`](review-real-xhigh.md), [`review-real-xhigh-reverify.md`](review-real-xhigh-reverify.md), and [`review-real-xhigh-reverify-65fde3d6.md`](review-real-xhigh-reverify-65fde3d6.md). Body below is the reviewer's verbatim Extra High re-verify output (not invented).

SHA verified before review: both copies matched `b673de8c…40c18`, so the spec was frozen throughout.

```
VERDICT: CLEAN
```

Frozen-plan integrity: both copies of [`router_subagent_surfaces_85bf9f09.plan.md`](.planning/router_subagent_surfaces_85bf9f09.plan.md) and [`~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md`](/Users/shafqat/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md) hash to `b673de8cc11bb46dfb12ed8bd48fa1d9ecc642f9e4ea4b9047d46b8e9c240c18`; branch `main`. Read order honored ([overview](.planning/rfl-router-subagent-surfaces-85bf9f09-20260812/SB-PRODUCT-OVERVIEW-FOR-REVIEWERS.md), plan, [round-19 SUPERSEDE](.planning/router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md) L33), contrasted against [prior Extra High](.planning/rfl-router-subagent-surfaces-85bf9f09-20260812/opus-5-xhigh-ladder3/review-real-xhigh-reverify-65fde3d6.md).

## Blockers
None.

## Highs
None. The four must-be-landed items are landed:

- **H-1** — L120 makes the authoring session a Job with the full role contract (Orchestrator work-spec → Advisor composes the authoring Work Plan → Validator → Executor), retires queue-builder composition ("Orchestrator-composed Work Plan — that would be row 39"), and mints `original_intent_hash` + GST row + WBS. `WF-SILVER-NEW-WORKFLOW`'s own catalog record is explicitly in scope (must become NW-capable / spec-compliant). WFM-01 proves the session path at L733 and L854 ("Advisor-composed authoring Job … not Orchestrator queue-builder"), named in MVP acceptance at L779 as `VAL/TST-RFL-625`. Round-18's output-compliance bar is intact, and the two "may use Advisor internally" / "only invokes Advisor" hits (L80, L120) are retraction text, not live spec.
- **H-2** — Row 11 (L636) and row 12 (L637) both carve out HINST-01 install/reference failures to rows 41/42 and exclude instruction-only runtimes from closest replacement when the recorded tuple was installable. Rows 41/42 are defined at L666/L667; L622 lists them in the ordered first-match table. No shadowing found from the earlier install/host-adjacent rows: row 1 (L626) and row 4 (L629) carve LPS-01 vs corrupt-state and accept `unbounded` as a valid stamp, row 20 (L645) explicitly defers to 41/42, and row 22 (L647) is the residual catch-all excluding 36–42.
- **M-1** — L364 states the sentinel is not compared as integer 0 and that `> 0` / `== 0` apply only when numeric; L362 repeats the numeric-only qualifier on the nested-Task gate; L427 makes the canonical parent-proxy trigger set numeric-0 **or** `host_nest_refused` **or** in-flight projector write; the envelope schema carries `host_nest_refused`; the refuse-then-proxy fixture is pinned at L731 and L852 as `VAL/TST-RFL-623`. No integer-comparison hazard survives — the remaining `> 0` mentions (L251, L301) are proxy-anyway rules that the sentinel satisfies.
- **M-2** — The three-clause replacement-ladder probe appears in both normative homes (L209 roles/preferences and L570 five-tool), with instruction-only runtimes probe-exempt at L570 and restated in workstreams (L773, L787) and the changelog (L80).

Earlier leftovers also verified: dispatch-not-mint (L251, row 39 at L664), parent-proxy beyond depth 0 (L251, L301, L427), row 22 excludes 36–42, `VAL/TST-RFL-625` / WFM-01, probe-exempt OpenCode/Pi, hops-below-main as the stamp unit (L364, L372–L374), row 37 covering any non-Advisor `wf_mint` (L622), and HNEST-01 / HINST-01 risk + traceability rows (L731–L732, L791, L852–L853). GST 34/35 remain dashboard-only; HINST 3+2 and HNEST Cursor 2 / Codex unbounded / Claude 3 are intact. No KEEP REJECT item reopened.

## Mediums (new)

**M-A (control plane / consistency) — row 42's "sibling" clause contradicts its own target-host clause.** Row 42 (L667) opens with "install/repair failed before `/sb:agent-cursor|codex|claude` spawn" and closes with "Sibling-host (non-parent) install fail is a doctor warning, not this row." In the common topology (parent Cursor, target Codex) the spawn target *is* non-parent, so a literal read of the normative first-match table downgrades the exact failure that B4 (L402) and row 20 (L645) both route to row 42. The Init-time framing at L380/L400 shows the intent is a third host that is neither parent nor spawn target; the table cell should say that, otherwise a real spawn blocker can be classified as a warning and then fall through to row 22.

**M-B (consistency) — precomposed catalog-dispatch escape for the authoring session is not closed.** `WF-SILVER-NEW-WORKFLOW` is `type: precomposed` (L120), and the only requirement on the record is that it become NW-capable / spec-compliant. Meanwhile row 39 (L664) explicitly permits "catalog dispatch of an already-existing AF/WF id", and L247 permits "work-spec + Advisor invoke, **or** catalog dispatch of an already-existing AF/WF id". Nothing states that resolve of this route must not take the precomposed-dispatch path, so the round-19 Advisor-compose lock rests on L120's "must" plus the WFM-01 fixture while the prose still sanctions a non-Advisor path for the same route. One line closes it (e.g. this record's dispatch is Advisor-compose-gated, or its type stops being `precomposed`).

**M-C (consistency / derived surfaces) — WS2 retires the queue-builder worker only in the installed copy.** L120 and L753 name [`.silver-bullet/orchestrator-workers/NEW-WORKFLOW.md`](.silver-bullet/orchestrator-workers/NEW-WORKFLOW.md) as the file that "must stop being a queue-builder mint path", but the source of truth is [`templates/orchestrator-workers/NEW-WORKFLOW.md`](templates/orchestrator-workers/NEW-WORKFLOW.md) with generated mirror [`plugins/silver-bullet/templates/orchestrator-workers/NEW-WORKFLOW.md`](plugins/silver-bullet/templates/orchestrator-workers/NEW-WORKFLOW.md). All three are byte-identical today (`sha256 ba90134e029a…`), and the file's contract is the parent-advances-queue pattern (`Parent advances via flow-advance.sh`). An edit confined to the named path is reverted by `scripts/sync-templates.sh` or the next install, so downstream installs keep shipping the retired queue-builder worker. The plan's sync mandate at L777 belongs to a different workstream and never names this template.

## Lows / observations
Replacement probe clause set (L209, L570) does not define the instruction-only → instruction-only case (recorded Pi replaced by OpenCode); row 20 admission covers it in practice. Back-references at L402, L732, L789 and L853 restate the parent-proxy trigger as numeric-0 plus projector-write without repeating `host_nest_refused`; each says the §Dispatch rules "still apply unchanged", and L427 is canonical, so this is a readability snag rather than a defect.

## Hosts / five-tool / control plane / consistency
Hosts: HNEST-01 knob table (L370–L374) and HINST-01 install-ensure (L376–L390) are internally consistent, with no invented Codex numeric max and no `install-opencode.sh` / `install-pi.sh`. Five-tool: init probe before record, brownfield re-probe with warn+unselect, instruction-only probe exemption, and `$primary_checkout` binding all hold. Control plane: 42-row first-match table classifies exactly one code per failure with rows 34/35 degrading and row 22 as residual; the only weak spot is M-A's ambiguous cell. Consistency: only M-B and M-C are unresolved, both single-sentence fixes.

Tools: Graphify used for repo orientation on the new-workflow surfaces (which surfaced M-C); `ctx_*`/scripted analysis for the large-plan passes; agentmemory write skipped per brief (tree-mutating export).

Files touched: none.
