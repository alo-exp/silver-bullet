# Decision — AM-first K/L + team Graphify fan-out (2026-08-16)

User agreed and asked to reflect in plan. Frozen SHA-256 (both plan copies): `db8cec806a33cfea991316c3ba9034281a229efe7424194625a51ce9527c06ed`.

## AM-first (ensure K/L still lands in agentmemory)

- Same leaf, ordered effects: `memory_save` first (same durable text), then classify, then promote to `docs/knowledge/` or `docs/learnings/`.
- `kl_write` cites `am_id` (or AM content hash). Missing provenance is invalid.
- AM opted in + save fail / missing `am_captured` → `blocked_knowledge_postwrite` (do not write K/L).
- AM not opted in → `kl_write_am_skipped`.
- No direct K/L Write except via `knowledge_postwrite` / FAST thin-capture.

## Team fan-out (do not reload K/L into everyone's AM)

- Fan-in: local AM → promote durable into git K/L.
- Fan-out: `git pull` + Graphify index of K/L dirs.
- Do not ingest K/L back into each clone's agentmemory (optional thin pointer only).
