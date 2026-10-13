---
id: "mem_msuir4ck_07cb0596b53f"
type: "fact"
created: "2026-08-15T15:16:39.201Z"
updated: "2026-08-15T15:16:39.201Z"
strength: 7
version: 1
concepts: []
files: []
---

# READ-ONLY report (main, no edits) from router_subagent_surfaces_85bf9f09. WHEN: 

READ-ONLY report (main, no edits) from router_subagent_surfaces_85bf9f09. WHEN: User-intent Workflows are minted at /sb Process resolve/wrap. Proposed architecture: the router mints a Process WBS and always creates a wrapping Workflow (AF never sits directly under Process). WBS is created from user intent at Process resolve. Orchestrator projector writes child work-specs/WBS before spawn. Cold /sb:agent-* mints Process wrap + wrapping Workflow sb:agent-wrap owning AF AF-agent-delegate; in-flight mints nested sb:agent-wrap under current Process (nested_executor, not a second Process). NOT THEN: Advisor plan, plan_val_verified, or Executor handoff do not mint the wrapping WF. Ordinary-delivery step 3: durable plan-handoff only after plan_val_verified; step 4 Authorizer admits Executor spawn. WBS section: After Advisor plan and plan-time Validation-loop (plan_val_verified), launch Executors as the touch-set allows. NOT A USER-INTENT WF: The six architectural roles (Orchestrator, Advisor, Authorizer, Executor, Verifier, Validator) are the Process quality order (plan-time Val → I → A → Verification at AF/WF; after top WF join: Process-synthesis I → Process A/V → Process-final Val). Deny-all control-plane leaves must not recursively run I/A/V/Val. No AF-meta / meta workflow in the spec. RECOMMENDATION: Keep mint at /sb Process resolve. Keep MF as quality-order only (do not catalog AF-meta-six-role). Wrapping Workflow already hosts child WFs. Do not reopen ESC-02, row 14, Authorizer→Approver, process_v_two_clean. Sources: .planning/router_subagent_surfaces_85bf9f09.plan.md L106/L139/L189-194/L308/L328/L372; clarify Validation-loop; SB-PRODUCT-OVERVIEW-FOR-REVIEWERS.md §3-§5 (current-product /silver vs architecture /sb).