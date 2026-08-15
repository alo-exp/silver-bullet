# Decision — current-month cap + FAST thin capture + AM→K/L promote (2026-08-16)

Locked into router_subagent_surfaces_85bf9f09 plan (clarify round-9). Stay on `main`. No commit. Opus High reviewing old SHA was aborted.

## Current-month context-load cap

"Current month files" is a **context-load cap**, not "older months do not count."

- Graphify-first (five-tool opted in): one query covering `docs/knowledge/`, `docs/learnings/`, and `.agentmemory/memory/` when AM opted in. Graphify searches **all** months. Miss → `blocked_knowledge_preread`.
- INDEX fallback only when five-tool is not opted in: `INDEX.md` (all months) + current month files as the hot set. Older `YYYY-MM.md` are not discarded; pull on demand. Do not dump every historical month into pre-read context.

## FAST thin capture

FAST remains **not a Job**, **not on GST**, **exempt from six-role quality order**. After the FAST leaf answers, Authorizer admits a thin-capture deny-all leaf (same family as `knowledge_postwrite`, not a second Job):

- Always `memory_save` / AM capture of the Q&A insight candidate.
- Durable → promote into `docs/knowledge/YYYY-MM.md` or `docs/learnings/YYYY-MM.md`.
- Ephemeral → AM-only + `kl_post_write_no_insights` / FAST no-insight receipt.
- Must not mint `original_intent_hash`, write GST, or run Advisor/Board/Val/Ver/A.

FAST skips Job steps 2–11 but **does** run this thin capture.

## AM → K/L promote

Same insights at two stages, not two equal git knowledge trees.

- Capture buffer: agentmemory only (`memory_save`).
- Git SoT: `docs/knowledge/` (project) and `docs/learnings/` (portable).
- `knowledge_postwrite` / FAST thin-capture read AM candidates and export/promote. Do not dual-write. `synergy_max` AM auto-commit is not the K/L path.

## Locked otherwise (untouched)

ESC-02 no A; Authorizer not Approver; `process_v_verified`; FAST not a Job; wrap at `/sb`; BOA parallel; no `AF-meta-six-role`.

Clarify: `.planning/router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md` (round-9)
Plan SHA-256 (after round-9 locks, then concurrent round-10 AM-first/fan-out on the same copies): `db8cec806a33cfea991316c3ba9034281a229efe7424194625a51ce9527c06ed`
Round-9 SHA-256 (superseded as frozen pair): `6bd715cd81abbfa367b81674624d55eabea02f7a2e44bf58fe499c9791dd6a52`
Prior SHA-256 (invalidated): `276806b3091dea955ae6aeecf06562d4f9b7b8ceb105580238e0550d252aaae8`
Opus High aborted: yes (wrapper pid 20387 / `claude --print --model claude-opus-5` / dir `.planning/agent-claude/rfl-opus-high-ladder3-20260816/`)
