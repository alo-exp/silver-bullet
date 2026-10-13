# Decision — RFL GPT Max ladder3 H1/H2/M1/M2 ACCEPT (2026-08-16)

Launcher ACCEPT of ladder-3 GPT-5.6 Sol Max findings (review SHA `c33bad1a…`) into `router_subagent_surfaces_85bf9f09` on `main`. Did not commit. Did not start Opus.

1. **H1 ACCEPT.** PUB-01 must not promote before current-generation `comp_val_two_clean`. Order: `comp_val_two_clean → promote → comp_val_verified` (catalog / pre-existing-AF compositions skip promote). Overlay-in-use forbidden before that two-clean. `TST-RFL-622` covers promoted-without-verified (quarantine; no execute; no verified). CORR-17 stays staged-without-promoted.
2. **H2 ACCEPT.** GST-01 semantic row CAS is `(instance_id, gst_row_id)` with `gst_row_id = H(original_intent_hash, process_id)` (Job remains user intent; display `job_id` stays short of `original_intent_hash`). Monotonic `gst_row_revision`; terminal-state precedence; tombstone so stale retries cannot rewind Completed/Blocked to Active. `TST-RFL-621` covers same-intent Process collision and rewind.
3. **M1 ACCEPT.** Plan-time Val `plan_val_round` ceiling 8 is per `launch_id` (not reset on each `plan_revision`; two-clean still resets per revision). Exceed → row 13, not ESC-02.
4. **M2 ACCEPT.** Authorized `advisor_board_unify` producer is an Authorizer-admitted deny-all Advisor-unifier leaf (`advisor_board_unifier`): Authorizer-admitted launch, input-set hash of all member outputs, output-receipt identity. Not last-write-wins. Parallel members unchanged. Orchestrator does not implement unify.
5. **Locked unchanged:** FAST exemption not reopened; ESC-02 no A; Authorizer not Approver; no `AF-meta-six-role`.

Clarify: `.planning/router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md`
Review: `.planning/agent-codex/rfl-gpt-max-ladder3-20260816/review.md`
Prior SHA-256: `c33bad1a0598791d341f0dd0995ac9400ce17d15194660817dbd3a2c266b0d3f`
Plan SHA-256: `276806b3091dea955ae6aeecf06562d4f9b7b8ceb105580238e0550d252aaae8`
