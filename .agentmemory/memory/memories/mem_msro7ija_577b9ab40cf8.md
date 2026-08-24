---
id: "mem_msro7ija_577b9ab40cf8"
type: "fact"
created: "2026-08-13T15:26:03.662Z"
updated: "2026-08-13T15:26:03.662Z"
strength: 7
version: 1
concepts: []
files: []
---

# Decision (2026-08-14): Router Subagent Surfaces plan iterated (plan-docs only on

Decision (2026-08-14): Router Subagent Surfaces plan iterated (plan-docs only on main). P-loop retired. Advisor-first one-way handoff: Parent -> Advisor (plans) -> Executor (executes only; never plans). WBS is central live artifact continuously tracked through last Validation; max opportunistic parallelization; overlapping file scopes => Executor worktrees, merge only after verification satisfied. Clarify Decision Addenda (2026-07-18, round-2/3/4) folded into Locked decisions (no standalone Addendum headings). Roles + WBS lifecycle sections + mermaid diagrams added. SM phases: pre_read_pending -> advisor_planning -> plan_handed_off -> i_* -> a_* -> v_* -> val_* -> kl_post -> scope_complete. POA-01/VAL-TST-RFL-618 IDs retained with new semantics. Byte-identical: .planning/router_subagent_surfaces_85bf9f09.plan.md and ~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md. No product/architecture code implemented.