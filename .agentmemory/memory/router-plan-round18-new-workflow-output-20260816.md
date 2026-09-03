# Decision — Round-18 ACCEPT (`/silver:new-workflow` output compliance, 2026-08-16)

Locked into router_subagent_surfaces_85bf9f09 plan. Stay on `main`. No commit. Max not started. No Fast.

## Retracted draft

Do **not** treat `/silver:new-workflow` primarily as “become a work-spec that invokes Advisor instead of Orchestrator mint.”

## Actual lock — output compliance

The skill is a **workflow authoring generator**. Emitted WFs must match this plan’s spec:

1. Composition: AFs **and Nested Workflows**; NWs may nest. Not AF-only trees.
2. Role-gate runtime contract on the generated WF (Advisor compose/amend; Executor in-plan `wf_mint` only; Orchestrator/`/sb` do not mint; Authorizer admits; inner NW join stops at Ver-loop; Process-final Val after top WF join).
3. Catalog-legal (`v_loop` required on AFs; `additionalProperties: false`; B1 generators + `check-apo-invariants.py`). FAST stays `AF-FAST-PATH` only.
4. FAST vs Job artifact shape; authoring session is a Job; artifact may be FAST- or Job-shaped.
5. Launch envelope stamps: WBS / work-spec / GST / remaining_depth / parent-proxy / five-tool.
6. Agent-wrap family: `sb:agent-wrap` / `AF-agent-delegate` / `nested_executor`.
7. Host docs: no SB hooks on OpenCode/Pi.

Internal run may use Advisor to formulate the definition. Orchestrator still does not `wf_mint` at runtime.

## Skill paths

- `skills/silver-new-workflow/SKILL.md`
- `plugins/silver-bullet/commands/silver-new-workflow.md`
- `plugins/silver-bullet/skill-source/silver-new-workflow/SILVER_SOURCE`
- `docs/NEW-WORKFLOW.md`
- `.silver-bullet/orchestrator-workers/NEW-WORKFLOW.md`
- `site/help/workflows/silver-new-workflow.html`
- `tests/scripts/test-silver-new-workflow.sh` (+ audit + skill-scenarios)

## WS / VAL

WS1 generator + catalog; WS2 skill/docs stubs. `VAL/TST-RFL-625` / WFM-01 golden fixture.

Extra High H-1–H-5 / M-1–M-4 remain. KEEP REJECT untouched.

Plan SHA-256 (both copies, byte-identical after Round-18): `65fde3d6f4521e7a8aed89ceb07efc6bcfdbf1b5518e3d1ce0e921c43ac7fd8c`
Extra High ACCEPT SHA (before Round-18): `3b980a2006e8c05448ed02a38e879d6e47cfa2bec8e20ecfb66cb3e772e15fcc`
