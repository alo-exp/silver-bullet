# Decision — RFL GPT Max ladder3 M1/M2 ACCEPT (2026-08-16)

Launcher ACCEPT of ladder-3 GPT-5.6 Sol Max Mediums (review on stale SHA `6d7398b0…`, still valid) into `router_subagent_surfaces_85bf9f09` on `main`. Did not commit. Did not start Max/Opus.

1. **M1 ACCEPT.** Testing/acceptance validation-family floor now includes `VAL/TST-RFL-620` (ABU-01), `621` (GST-01), and `622` (PUB-01). Preserve range is `601..622` (was `601..619`). WS7 MVP list includes ABU-01 Board of Advisors (GST-01 was already listed) and PUB-01 flow-publisher so the ID floor matches named MVP obligations.
2. **M2 ACCEPT.** Traceability now has a `PUB-01` row with dedicated `VAL/TST-RFL-622` / `TST-RFL-622` covering stage→validate→promote publication and registration. Collision/crash remain dependencies: FIX-05 deny-graph overlay, CORR-17 staged-without-promoted, VALP-01 composition-Val. No orphan: PUB-01 has one validator and one test owner.
3. **Locked unchanged:** FAST exemption not reopened; ESC-02 no A; Authorizer not Approver; no `AF-meta-six-role`.

Clarify: `.planning/router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md`  
Review: `.planning/agent-codex/rfl-gpt-max-ladder3-20260816/review.md`  
Plan SHA-256: `c33bad1a0598791d341f0dd0995ac9400ce17d15194660817dbd3a2c266b0d3f`  
Prior SHA-256: `d7565d5695651ccd90696711561f1d61004006bf0c6b41cd536779b03f01268b`
