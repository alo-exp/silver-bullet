# Decision — router_subagent_surfaces Round-2 R1

Date: 2026-08-14
Surfaces: `.planning/router_subagent_surfaces_85bf9f09.plan.md` (byte-identical Cursor mirror), `.planning/router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md`

- Q18: ordinary AF/Workflow SM is I→A→V with no `val_*`. Process-final Val is a separate last step after Workflow join.
- Note 15: trust path remains `~/.silver-bullet/authorizer-trust/<repo-id>/`. `remote_id_sha256` is not a path suffix.
- Launch adapters persist work-spec and plan artifacts only by invoking `hooks/lib/wbs-projector.sh`. Spawn-proxy jsonl append by children remains allowed.
- Extra worktrees only for `host_native`. `/sb:agent-*` cwd is always the primary root. Launch envelope includes `primary_checkout`.
- Five-tool brownfield opt-in re-probes all recorded runtimes. Runtime-changing replacement must probe first. Empty replacement set is terminal `blocked_executor_unavailable` (same hard stop for Verifier/Advisor/Validator) after the user is told.
- Pi MiMo pin retires when recorded `{model,effort}` is set and the key is in the host/OS store or env. Prefs never store the key.
- ILM-01 bootstrap migrate is MVP. MIG-01 / VAL-604 reverse-bridge and offline quiescence are post-MVP. WS6: Pi five-tool only if Pi is a selected probed runtime. WS3: token rotation/revocation evidence is post-MVP.
