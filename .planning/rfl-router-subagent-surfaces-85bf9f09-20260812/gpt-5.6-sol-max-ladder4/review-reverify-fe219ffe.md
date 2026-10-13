# RFL Ladder 4 re-verification — GPT 5.6 Sol Max

## Freeze

- Branch: `main`
- Repository copy start/end SHA-256: `fe219ffeffd1bdff4a16debccb2a598f81e26176fdcc905d20af3c92a51f8b2b`
- Cursor copy start/end SHA-256: `fe219ffeffd1bdff4a16debccb2a598f81e26176fdcc905d20af3c92a51f8b2b`
- Both copies match the requested frozen hash. No hash mismatch.

## Round-34 landing check

1. **CAS-provable snapshot supersession: landed.** The live contract retains snapshots while a `launch_id` remains current, including parent-proxy continuation, ESC-02 re-dispatch, and same-id `plan_revision`; it permits GC only after a replacement `launch_id` is admitted, explicitly keeps the old CORR-17 fence in force, and rejects fence release, child terminality, or process death as prerequisites. A missing snapshot for a still-current id remains row 4/corrupt (`.planning/router_subagent_surfaces_85bf9f09.plan.md:263`, `:433`, `:592`, `:728`, `:738`). The round-34 decision records the same rule (`.planning/router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md:1227-1229`).
2. **L511 in-plan diagram: landed.** The WBS/parallelism edge says `in-plan wf_mint / wf_invoke` and targets an “Authorizer-admitted in-plan nested WF” (`.planning/router_subagent_surfaces_85bf9f09.plan.md:511-512`), matching the primary architecture diagram (`:156-157`) and the prose gate (`:112`). The clarification confirms this exact alignment (`.planning/router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md:1231-1233`).
3. **Special-file failures exactly row 4: landed.** The canonical encoding rule routes fifo/socket/device, dangling-symlink, and symlink-loop failures to row 4 and explicitly excludes row 1 (`.planning/router_subagent_surfaces_85bf9f09.plan.md:263`). Row 1 repeats the exclusion (`:630`), while row 4 contains the sole positive trigger and says “exactly this row; not row 1” (`:633`). The clarification records that no dual “as appropriate” citation remains (`.planning/router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md:1235-1237`).
4. **Row 1 remains independent: landed.** Row 1 still separately matches failure to complete revoke-before-admit and observable post-revoke stale-Executor effects; it also preserves that a live/pid-existing but fenced Executor is not failure evidence (`.planning/router_subagent_surfaces_85bf9f09.plan.md:630`). The WFM-01 acceptance fixture independently pins both limbs and the same pid/process-death exclusions (`:737`).

## KEEP REJECT

No regression found. The frozen plan retains:

- projector-only packet ownership (`.planning/router_subagent_surfaces_85bf9f09.plan.md:429`, `:433`);
- unlimited tree composition with DFS recursion-stack/tri-color cycle rejection (`:122`, `:263`, `:630`, `:727`);
- in-plan-only Executor mint/invoke and a newly minted `launch_id` on remint (`:112`, `:156`, `:265`, `:433`, `:737`);
- public `/sb`, generated-catalog obligations, lock-only `nested_executor`, and unchanged B1 schema constraints (`:110`, `:118`, `:120`, `:122`);
- Authorizer as admitter, not Approver (`:261`);
- ESC-02 without an A-loop (`:731`);
- launcher omission of `context_refs_hash` before admit (`:263`, `:433`, `:592`, `:738`);
- L598’s proof limits (`:598`);
- OFF-01 as post-MVP, observable-only limb (b), and pid-exists-not-FAIL (`:630`, `:737`).

## Findings

None. No new defect survived review.

## VERDICT

**CLEAN**
