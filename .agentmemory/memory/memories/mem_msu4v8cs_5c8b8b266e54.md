---
id: "mem_msu4v8cs_5c8b8b266e54"
type: "fact"
created: "2026-08-15T08:47:56.409Z"
updated: "2026-08-15T08:47:56.409Z"
strength: 7
version: 1
concepts: []
files: []
---

# ACCEPT B1: bound SB OVERRIDE as Authorizer-gated, human-authenticated, scoped, e

ACCEPT B1: bound SB OVERRIDE as Authorizer-gated, human-authenticated, scoped, expiring capability. Admission-only (who/what may start). MUST NOT override schema/hash integrity, identity, claimant-epochs, control-plane fences, revocation, or blocked_corrupt_state. Product kept; OVERRIDE not deleted. ACCEPT H1: parent-proxy status pending|consumed|launched|failed|completed|resumed plus completion_receipt_id, requester_continuation_id, resume_idempotency_token; idempotent resume CAS; CORR-17 crash reconcile launched-without-completed and completed-without-resumed; fail-closed blocked_callback_unresolved if Cursor cannot rebind requester. Distinct from locked in-flight spawn split. REJECT M1 as policy change; clarify recommended-defaults Advisor-strictly-stronger marked superseded/non-binding; plan same {runtime,model,effort} rule and retired row 14 unchanged. Plan copies byte-identical SHA-256 23065dd1605be4da828948c10ef2b419529fb07a66a6b3158f636fc960602909. Branch main. No commit.