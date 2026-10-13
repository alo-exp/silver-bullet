# RFL Ladder 4 — Opus Extra High — RE-VERIFY on `aa3677a5…` — PARENT ACCEPT

**Reviewer:** Opus Extra High (`sb-opus-5-xhigh` / [`8ed1bc81-2e08-48d8-9032-a0bc239fb5a6`](8ed1bc81-2e08-48d8-9032-a0bc239fb5a6)). Review-only at review time. No Fast. No Max.
**Branch:** `main`
**Frozen SHA-256 at re-verify start:** `aa3677a5531797f59465a1370b1909fb5c696a42067546b3b4f99f3ac4c5b30c`
**Official verdict:** **HASH MISMATCH** (plan moved mid-review to ~`caa36067…` — GPT Max cycle/hash/snapshot Highs only).
**Parent ACCEPT (round-29 final):** B-1 / H-1 / M-1 incorporated on top of GPT Max H-1 / H-2 / H-3 / M-1. Max **not** re-launched. No commit.

**Hash gate at review start:** both copies were `aa3677a5…`. Mid-review the ACCEPT worker landed GPT Highs → `caa36067e2ed6e893b46209a8bec9ee99d8ef78015efb65f8b967a1190934418`. That mid-write is **not** the finished freeze.

**Round-28 landed check: PASS.** Authorizer-admitted `launch_intent` requires `definition_closure_hash` + `composition_generation`; recursive closure; job-relevant `context_refs` / `context_refs_hash`; one `ART-AGENT-DELEGATE` via named emitters; `WF-SILVER-ROUTER` slug/`owning_skill` → `sb`; `PP-SB-STARTUP-FAST.workflow_refs` FEATURE-first. KEEP REJECT intact (`nested_executor` lock-only, not a catalog JSON field; schema `additionalProperties: false` unchanged; public `/sb`; catalog generated; unlimited **tree** nesting; cycles fail-closed; in-plan Executor mint; row 40 re-bind).

Findings survive on the new bytes. Parent: **ACCEPT B-1, H-1, M-1.**

## VERDICT: HASH MISMATCH (findings still accepted)

### Blocker B-1 — Lock files need an emitter + input table (accepted)

`contracts/` does **not** exist. `generate-apo-artifacts.py` does **not** emit `apo-hierarchy.lock.json` / `public-workflow-routes.lock.json`. Catalog cannot carry `nested_executor`.

WS1 must:

- **Create** `contracts/apo-hierarchy.lock.json` and `contracts/public-workflow-routes.lock.json` via a **named generator** (new script or named function — not “the catalog emits locks”).
- Input for `nested_executor` is a **hand-authored table** in generator source (or a committed seed JSON the generator reads) listing the five `/sb:agent-*` leaves as lock class `nested_executor`. **Not** a catalog extra property.
- Commit the generated locks; content-hash parity; CI drift fails. First ship: generated files **are** the baseline (no prior hash).
- Name `tests/scripts/test-router-contract-locks.sh` (**create it**) in WS1. “Automated old/new lock-hash evidence” = this test + committed locks.

### High H-1 — Composition remint mints a new Executor `launch_id` (accepted)

Row-40 / Advisor re-compose **changes composition**, so Executor resume is **not** put-if-absent on the old `(prompt_hash, work_spec_hash)` only.

Lock: composition remint **mints a new `launch_id`** for the Executor replacement revision (same exception class as Val-fail 9a–9c / Process-scope dirty). Admission payload **includes** `definition_closure_hash` + `composition_generation`. Conflicting payload on the **old** `launch_id` stays blocked (CORR-17 fence). The new `launch_id` carries the re-bound closure. Do not ack generation-N as a duplicate of generation-N+1.

### Medium M-1 — `context_refs` snapshot has a WS + VAL/TST (accepted)

WS3 owns `hooks/lib/orchestrator-admission.sh` writing `$primary_checkout/.planning/packets/<launch_id>/context-refs-snapshot/`. Add `VAL/TST-RFL-626` (extend LPS-01) for hash + snapshot existence. Snapshot is **cited job-relevant refs only**, not whole `docs/knowledge/` / `docs/learnings/` trees. GC = packet lifecycle (same as other packet files).

Parent ACCEPT 2026-08-16 (round-29 final): Opus B-1 / H-1 / M-1 incorporated with GPT Max H-1 / H-2 / H-3 / M-1. Mid-write `caa36067…` invalidated. Final SHA `9a173a53f04eec56bc139d1e1ae67f7cdc3c0530a9860f71e6253a67e346e7be`. Max not re-launched.
