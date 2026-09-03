# Decision — router_subagent_surfaces Round-4

Date: 2026-08-14
Surfaces: `.planning/router_subagent_surfaces_85bf9f09.plan.md` (byte-identical Cursor mirror), `.planning/router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md`

- All packet/plan-artifact writes go through `hooks/lib/wbs-projector.sh`, including Advisor plan-replacement receipts, Process-synthesis packet-local findings, and callback CAS that would land in packet/WBS paths.
- Children (Advisor, Executor including Process-synthesis, Verifier, Validator) must not Edit those files except by invoking the projector. Non-packet callbacks may use `~/.silver-bullet/projects/<repo-id>/` without the projector.
- Mermaid 2: Val does not write WBS. Fail receipt → Orchestrator+Advisor map → projector updates WBS. Process-synthesis then Process A/V before Process-final Val (no AfDone → Val flatten).
- WS7 MVP IDs: LPS, WBS, POA, ALP, VLP, VALP, KLW, ADM-01, ILM-01 (bootstrap), TRUST-01 identity-only, EFF-01 exactly-once ordinary effects. EFF-01 rollback/migration compensation and TRUST-01 token rotation/revocation are post-MVP. ILP-01 is I-loop (WS4), not launch-identity.
- Clarify Q11 one-liner names bootstrap migrate (ILM-01). No commit. Both plan copies remain byte-identical on main.
