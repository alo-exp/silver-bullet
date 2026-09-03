# RFL Rung 3 — Kimi K3 High — Adversarial Architecture Re-Review (Cycle 2)

**Plan under review:** `.planning/router_subagent_surfaces_85bf9f09.plan.md`
**Fix under verification:** commit `e5c58009` ("fix(planning): enumerate AF/Workflow validator and A-loop advisor launch edges"; 2 files, +7/−5 — plan §1 line 127, §3 lines 163–164; brief canonical-order line 41 + Q18 appendix row line 100).
**Read order followed:** SB-PRODUCT-OVERVIEW-FOR-REVIEWERS.md → REVIEW-PROMPT-PREAMBLE.md → plan (full, 441 lines) → cycle-1 report (`rung-kimi-k3-high-task-c1.md`) → clarify brief (full) → full diff of `e5c58009` → repo plan vs Cursor mirror byte-parity check.
**Stance:** independent re-verification of cycle-1 Finding 1 closure plus fresh adversarial sweep of the changed surfaces for introduced defects. Not a rubber stamp: the fix diff, both fixed files, the mirror, and every cross-reference of the new enumeration were re-read from current bytes.

## Finding 1 closure verification (cycle-1 material finding)

Cycle-1 Finding 1 had three sub-gaps; each is closed:

1. **Missing AF/Workflow Validation-loop validator launch/request edges — CLOSED.**
   - §1 line 127: Workflow may now "request a composition verifier, A-loop advisor (Mentor), **Workflow-scope Validation-loop validator**, or defect escalation"; AF requests "Steps, AF verifier, AF/leaf A-loop advisor (Mentor; leaf Step A-gate), **AF-scope Validation-loop validator**, or defect escalation".
   - §3 line 163: "Process launches the top Workflow and **Process-final Validation-loop validator** (plus Process A-loop advisor / final verifier as required by the ordinary SM)" with the same per-scope Workflow/AF enumeration mirrored.
   - This matches locked Q21=B / Q22=B (plan lines 50, 53, 221; brief lines 103–104): Validation mandatory at AF completion, Workflow composition join/final, and Process final, always after V.
2. **Missing AF/leaf-Step A-loop advisor edge — CLOSED.**
   - The `AF/leaf A-loop advisor (Mentor; leaf Step A-gate)` edge is now enumerated in both §1 and §3, with the parenthetical correctly invoking the Q14 dedup (leaf Step A-once satisfies the AF A-gate; plan line 220, brief line 96 — unchanged and mutually consistent).
   - The symmetric rule explicitly separates mandatory A-loop Mentors from executor-initiated on-demand `i_running` consults (plan line 87), closing cycle-1's observation that the free-consult right could not be stretched to cover the A-loop.
3. **§6 deny-generation would fence out mandatory control-plane children — CLOSED.**
   - §3 line 163 now states: "§6 deny-generation **MUST include these edges** so generated denies never fence out mandatory control-plane children" — a direct executability instruction binding the §6 generator (line 262) to the repaired enumeration.
   - §3 line 164 deny-all leaf classes repaired: "Final, triage, advisor (P-loop / A-loop Mentor / on-demand consult), **verifier**, **validator**, defect-escalation, and Iterate controllers" — the missing validator (and verifier) classes are now explicit, consistent with Locked line 86 (`advisor`, `verifier`, `validator`, `defect_escalation`, "equivalent Authorizer-launched Mentors/Validators").
   - The **symmetric Authorizer launch rule** is stated identically in §1 and §3 with triggers bound to the real ordinary-SM edges: `i_two_clean → a_*` (Mentor admission), `v_verified → val_*` (validator admission), P-loop Advisor at `poa_advisor_review`. All three edges exist verbatim in the locked SM (line 222: `… → i_running/i_two_clean → a_running/a_two_clean → v_running/v_two_clean/v_verified → val_running/val_two_clean/val_validated → …`); no dangling or invented transition names.
   - The fix implements **both** branches of cycle-1's suggested fix direction (per-scope enumeration **and** the explicit symmetric Authorizer-launched path bound to SM edges), so the deadlock between §1/§3 and §5/Locked is resolved.

## Introduced-defect sweep (changed surfaces + cross-references)

- **Scope discipline:** `git show e5c58009` confirms only 3 plan lines and 2 brief lines changed (plus trailing blank lines at brief EOF). No headings, frontmatter, todos, addenda, or traceability rows touched; final-integrity invariants (10 pending todos, single `## Locked decisions`, single `## 1`–`## 9`) structurally unaffected.
- **Byte-parity lock (Q2 / addenda lines 105, 113, 118):** `diff -q` of repo plan vs `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md` → **identical**. The locked mirror constraint survived the edit.
- **Internal consistency of new text:**
  - "Process launches … validator" vs "only the Authorizer admits/spawns them" reads as request-side vs admit-side, the same sense in which "Process launches the top Workflow" has always coexisted with Authorizer-committed `launch_intent` (line 169). No contradiction.
  - Verifier admission is unchanged from pre-fix structure: verifiers remain enumerated request edges (§1/§3) and deny-all Authorizer-handoff leaves (lines 86, 164). Cycle-1 never flagged verifier edges; the fix neither weakens nor contradicts them.
  - The new enumeration retains "defect escalation" at every scope and leaves triage pass (line 163) and triage-as-leaf (line 164) intact; Levels 0–3, Iterate isolation ("never auto-launched by Process"), and Work-Skill confinement ("execute only inside AF") are untouched.
  - Locked line 86's P-loop exemption list, line 218's restated exemption, line 220's A-loop boundaries, line 221's Val boundaries, line 223's canonical order, and line 254's `blocked_validation_state` predicate all read identically against the new §1/§3 text. No stale mirror-text of the old ("verifier/advisor" / "Steps and AF verifiers") enumeration survives anywhere in the plan (full-file re-read confirms the old phrasing existed only at the two repaired sites).
- **Hierarchy-lock coverage:** lines 48 and 137 are edge-generic (ownership/reachability/binding; deny rules for graph-derived zero-child leaves), so the newly enumerated edges fall under existing lock/deny machinery without further text.
- **Launch admission for the new children:** line 85's prompt+work-spec fail-closed gate applies to every host subagent launch, including Authorizer-launched Mentors/validators; line 86 exempts them from P-loop/recursive loops only. Admission and exemption compose without conflict.

## Non-material observations (recorded, not blocking)

- **Residual brief hygiene (third instance):** the fix updated brief line 41 (canonical order now includes P-loop) and the Q18 appendix row (line 100, now shows `p_*` with "P-loop phases aligned round-4"), but the round-2 historical "Ratified" addendum at brief line 120 still shows Q18 as `pre_read_pending → i_* → …` without `p_*`. The plan's own round-2 addendum (line 109) was re-texted with an explicit "this addendum text updated for consistency" note; the brief's round-2 section carries no such note. Impact: none — line 120 is a historical round record inside an addendum marked COMPLETE, the authoritative appendix (line 100), the round-4 addendum (line 175), and the plan all carry the correct SM, and the brief self-defers to the plan (line 90). Same class cycle-1 already rated non-material; one parenthetical at brief line 120 would fully close it.
- Cycle-1's remaining non-material observations (A-loop disposition semantics for knowledge/learning candidates, LPS cross-host hash canonicalization, POA re-satisfaction on pure approach pivot, P-loop Advisor-unavailability blocker classification) were not part of Finding 1, were not required of this fix, and remain non-material on re-read.

## Conclusion

Cycle-1's sole material finding is closed on all three sub-parts with the exact fix shape cycle-1 specified, the locked byte-parity constraint holds, and the adversarial sweep of the changed surfaces and their cross-references (Locked decisions, §5 loop semantics, §6 deny-generation, Q14/Q21/Q22, blocker enum, traceability rows) found no new contradiction, state-machine hole, executability break, or traceability orphan introduced by `e5c58009`.

VERDICT: CLEAN
