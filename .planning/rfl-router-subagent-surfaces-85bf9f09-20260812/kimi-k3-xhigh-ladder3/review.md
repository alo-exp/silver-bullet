# RFL Ladder 3 — Kimi K3 Extra High — REVIEW ONLY (rerun after 2026-08-16 plan change)

**Rung model:** Kimi K3 Extra High (`sb-kimi-k3-xhigh`) — independent review; no rubber-stamp of the High CLEAN pass or the aborted Extra High pass.
**Frozen SHA (verified, both copies match):** `25f43f8268163c44d9b2b1a79b7b03051002498bfb1151d55e7baca4bc36d8a0`
- `.planning/router_subagent_surfaces_85bf9f09.plan.md`
- `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md`

**Read in full, in order:** SB-PRODUCT-OVERVIEW-FOR-REVIEWERS.md → frozen plan (all 665 lines) → CLARIFY-260717-143757.md (incl. 2026-08-16 supersede banner).
**Mode:** review-only. No plan edits, no commits, plan copies left byte-identical.

## Verdict: NOT CLEAN

One High: the 2026-08-16 plan-time Validation-loop is not bound to the POA-01 mid-flight plan-replacement path, so an Executor can resume on an unvalidated revised plan — contradicting the spec sentence "Executor I proceeds only on the validated plan."

---

## Locked-item conformance (verified, not reopened)

| Locked item | Plan evidence | Status |
|---|---|---|
| ESC-02: I then Verification, **no A** on steps 2–3 | §Escalation ladder ("do not add an A-loop on escalation steps 2–3"), Doctor paragraph, rows VAL/TST-RFL-619, ESC-01/ESC-02 matrix rows | OK |
| Same model across roles allowed; row 14 retired | Roles section ("Same `{ runtime, model, effort }` across Advisor and Executor is allowed; row 14 is retired"); blocker row 14 = historical, warn-only, non-classifying | OK |
| `process_v_verified`, not `process_v_two_clean` | `process_v_two_clean` appears exactly once — in the prohibition sentence "Do not invent `process_v_two_clean`; keep `process_v_verified`" (step 3 of ordinary-delivery procedure) | OK |
| Authorizer stays sixth role (not Approver; not merged with Validator) | Six roles table; "Approver" appears 0 times; Authorizer not a preference key, distinct Verifier identity at `verifier-trust/<repo-id>/` for Ver-receipts only | OK |

## 2026-08-16 user-spec conformance (verified)

- **Plan-time Validation-loop after Advisor plan vs work spec:** present in frontmatter overview + `nested-quality-loops` todo, Overview §2, Proposed-architecture one-way rule + mermaid, ordinary-delivery step 3, Validator role row, mandatory control-plane children list, WBS viz surface list + ASCII example, VALP-01 / VAL/TST-RFL-615, POA-01 / VAL/TST-RFL-618, ESC-01 MVP clause, migration prospective re-entry (`pre_read_pending → advisor_planning → plan-time Validation-loop → plan_handed_off → i_running`). States `plan_val_running` / `plan_val_two_clean` / `plan_val_verified` exactly as the banner requires; `plan_val_verified` = two-clean terminal.
- **Verification-loop (Ver-loop) naming:** "V-loop" appears 0 times; "Verification-loop" on 25 lines; the meta-rule "Never use the historical two-letter V hyphen-loop name" is stated without using the literal string. Bare shorthand "V" survives only as `v_*` SM tokens and "V-clean"/"V two-clean" compounds, which the spec permits (SM tokens unchanged per Q13 2026-08-16 note).
- **Process-final Val-fail → Validation-loop starting with Advisor re-plan:** present in Overview §2, ordinary-delivery step 10, Process-repair section, WBS section, second mermaid (fail receipt → Orchestrator+Advisor map → Advisor re-plans → plan-time Validation-loop → Exec), VALP-01, ESC-01 MVP clause. Explicitly marked as superseding fail-receipt-only / no re-plan; keeps `launch_id` / occurrence / 9a–9c mechanics; no un-merge.
- **9a–9c kept and mandatory** after top Workflow join, before Process-final Val, with rerun on both Val-fail and Process-scope A/V-dirty paths (distinct `launch_id` minting rules stated for each).
- **Process-final Val states** `val_running` / `val_two_clean` / `val_validated` unchanged; product Val remains Process-final only; ordinary AF/Workflow SM has no `val_*`.

## Blockers

None.

## Highs

### H1 — Plan-time Validation-loop is not bound to POA-01 mid-flight plan replacement; Executor can resume on an unvalidated plan

The 2026-08-16 spec requires: "after **each** Advisor plan, Validator runs a plan-time Validation-loop (Val-loop) vs the work spec … Executor I proceeds only on the validated plan."

The plan binds this correctly for (a) the initial plan (ordinary-delivery step 3: `plan_val_verified` before `plan_handed_off`; `blocked_plan_of_action_review` row 6 updated) and (b) the Process-final Val-fail re-plan (step 10 and Process-repair section: "then plan-time Validation-loop again until `plan_val_verified`").

But the **mid-flight material plan change** path is not bound. §"On-demand Advisor consult" / material-change paragraph: "Material plan-of-action change means an **Advisor receipt** that the ordered steps changed … the Task-capable Orchestrator session replaces the plan artifact under the same `launch_id` … Executor continuation resume and callback acceptance require the current revision." No plan-time Validation-loop is required on the replacement revision — Executor continuation resume binds only `plan_revision` + plan-artifact hash (POA-01 revision binding), not `plan_val_verified` on the new revision. The same unbound phrasing recurs in §Process-synthesis repair ("otherwise the same `launch_id` may continue with an Advisor plan-replacement receipt") and the frontmatter `nested-quality-loops` todo.

Net effect: during ordinary `i_running`, an Advisor can replace the plan (e.g. after a consult), and the Executor resumes implementing a plan revision the Validator never checked against the work spec — exactly the hole the plan-time Val-loop was added to close. This is an interaction introduced by the 2026-08-16 change (the POA-01 replacement text predates plan-time Val and was not propagated).

**Suggested fix direction (review-only, not applied):** state that a plan-replacement receipt re-enters `plan_val_running` (replacement is not effective for Executor resume until `plan_val_verified` on the new revision); bind resume/callback acceptance to current revision **and** its `plan_val_verified` receipt; extend row 6 `blocked_plan_of_action_review` trigger to "unvalidated replacement revision".

## Mediums

### M1 — Plan-time Validation-loop non-convergence has no explicit bound or named blocker mapping

Spec says "two-clean spirit … until the plan satisfies the work spec." If Advisor↔Validator plan revision never converges, no text says what fires: row 13 `blocked_validation_state` ("Val two-clean cannot complete as a process") plausibly covers it but does not name plan-time Val, and the finite four-step ESC-02 ladder is scoped to "Ordinary Executor stall" — its applicability to a plan-time Val stall (or to an Advisor who cannot produce a satisfying plan) is unstated. A one-line cross-reference (row 13 trigger names `plan_val_two_clean`; ladder step semantics for plan-stage stall) would close it.

### M2 — Second mermaid Val-fail path skips the handoff/admission node

In the WBS mermaid, the Val-fail path runs `Map → Replan[Advisor re-plans] → PlanValFail[plan-time Validation-loop] → Exec[Executors execute only]`, omitting the Orchestrator/Authorizer-admitted handoff that the first mermaid and the prose require (`PlanVal →|plan satisfies work spec| Orchestrator → Authorizer-admitted spawn → Executor`). Prose is authoritative and correct, but the diagram is part of the spec implementers read; add the handoff node (or a note) on the re-plan edge.

### M3 — Document control Date still 2026-08-14; no in-plan marker of the 2026-08-16 spec revision

The plan body contains zero occurrences of `2026-08-16`; the date lives only in the clarify banner. Given this plan's supersede-driven evolution and byte-identical-mirror discipline, a Document-control "Revised" field (or revision line) would prevent future reviewers from mis-dating the spec they are reading. Cosmetic; does not affect correctness.

## Notes (not findings)

- Row 8/9 wording "Val is not run after every AF, every Workflow, or every repair hop" and "repair hops do not run Val" refer to **product** Val and remain consistent with plan-time Val, which is bound to Advisor plans (pre-I), not to AF/Workflow completion or repair hops. Read together with step 10 / Process-repair this is unambiguous enough; flagged here only so future rungs do not re-litigate it.
- Frontmatter has exactly ten todos; headings match the Document-integrity checklist; one YAML block; no duplicate mermaid/migration/integrity blocks observed.
- `sb:agent-*` cold wrap (`advisor_planning → plan_handed_off` per POA-01) transitively inherits the plan-time Val-loop via POA-01's updated text ("plan-time Validation-loop vs work spec to `plan_val_verified` before `plan_handed_off`") — covered.
- Iterate rung implementers remain exempt from ordinary Advisor planning, hence from plan-time Val; consistent with the charter+baseline admission gate.

## Protocol compliance

- Stayed on `main`; no branch commands run.
- Plan copies untouched (SHA re-verified identical before review; no writes made to either).
- No commits. No other rungs started.
- Graphify query run before Read/Grep; native Grep was hook-denied and analysis was done via ctx sandbox instead.
