# Decision — AM-first fail-closed kl_write + team Graphify fan-out (2026-08-16)

Locked into router_subagent_surfaces_85bf9f09 plan (clarify round-10). Did not stop for user questions. Stay on `main`. No commit.

Plan SHA-256 (both copies byte-identical): `db8cec806a33cfea991316c3ba9034281a229efe7424194625a51ce9527c06ed`
Invalidated prior SHA-256: `6bd715cd81abbfa367b81674624d55eabea02f7a2e44bf58fe499c9791dd6a52`

Opus High `--print` reviewing frozen SHA `276806…` was interrupted. Did not relaunch Opus.

## AM-first fail-closed provenance (locked)

K/L that currently gets captured still lands in agentmemory **mechanically**, not by hoping the agent also saved AM.

- Same leaf, ordered effects: `knowledge_postwrite` / FAST thin-capture MUST `memory_save` first (same durable text that would have been the K/L entry, not a weaker summary), then classify, then promote into `docs/knowledge/YYYY-MM.md` or `docs/learnings/YYYY-MM.md` (or `kl_post_write_no_insights` / FAST no-insight if ephemeral).
- Every `kl_write` receipt and every K/L monthly entry cites `am_id` (or content hash of the AM record). `kl_write` without AM provenance is invalid.
- When AM is opted in: AM save failure or missing `am_captured` → `blocked_knowledge_postwrite` (do **not** write K/L anyway).
- When AM is not opted in: K/L write may proceed; receipt is `kl_write_am_skipped`. INDEX fallback already covers retrieve. Do not silently pretend AM captured.
- No direct K/L authorship: Orchestrator / ordinary Executor / parent Write of `docs/knowledge/` or `docs/learnings/` without this leaf is `blocked_knowledge_postwrite`.

## Team Graphify fan-out (locked)

- Fan-in: local AM captures; classified durable insights promote into committed K/L (git). Unpromoted episodic AM stays local and is not the team store.
- Fan-out retrieve: `git pull` + Graphify index of `docs/knowledge/` + `docs/learnings/` (`graphify update` after pull / session start / Job pre-read).
- Do **not** ingest K/L back into each clone's agentmemory (optional thin pointer only, e.g. last commit SHA). Graphify is the shared retrieve layer.

## Do not reopen

Current-month is a context-load cap; FAST thin capture (AM always, durable promote to K/L); AM is capture buffer; K/L dirs are git SoT; `synergy_max` AM auto-commit is not the K/L path; ESC-02 no A; Authorizer not Approver; `process_v_verified`; FAST not a Job; FAST not on GST; FAST exempt from six-role quality order; wrap at `/sb`.

Clarify: `.planning/router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md` (round-10)
Overview (K/L/AM repeat): `.planning/rfl-router-subagent-surfaces-85bf9f09-20260812/SB-PRODUCT-OVERVIEW-FOR-REVIEWERS.md`
