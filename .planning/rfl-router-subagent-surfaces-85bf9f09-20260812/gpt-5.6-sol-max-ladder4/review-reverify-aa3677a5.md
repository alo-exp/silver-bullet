# RFL Ladder 4 — GPT-5.6 Sol Max — RE-VERIFY on `aa3677a5…` — PARENT ACCEPT

**Reviewer:** GPT-5.6 Sol Max (`sb-gpt-5-6-sol-max` / [`bea156bd-36ca-4c24-bd70-4a891bc77031`](bea156bd-36ca-4c24-bd70-4a891bc77031)). Review-only at review time. No nested Task. No Fast. No edits, commit, or checkout.
**Branch:** `main`
**Frozen SHA-256 at re-verify:** `aa3677a5531797f59465a1370b1909fb5c696a42067546b3b4f99f3ac4c5b30c`
**Parent ACCEPT (round-29):** H-1 / H-2 / H-3 / M-1 incorporated. Round-28 landings present. Max **not** re-launched. No commit.

**Hash gate: PASS.** Both plan copies hashed to `aa3677a5531797f59465a1370b1909fb5c696a42067546b3b4f99f3ac4c5b30c` at review time. Branch `main`, untouched during review.

**Round-28 landed check: PASS.** `launch_intent` requires `definition_closure_hash` / `composition_generation`; recursive closure over nested WFs; `context_refs_hash` + snapshot; Opus Extra High one `ART-AGENT-DELEGATE` / `WF-SILVER-ROUTER` slug/`owning_skill` → `sb` / `workflow_refs` FEATURE-first. KEEP REJECT honored (unlimited **tree** nesting of NWs; in-plan Executor mint; `prompt_hash` inner-only; public `/sb`). Recursive cycles are not that tree lock.

## Blockers

None.

## High (accepted)

### H-1 — Cycle rejection

Unlimited nesting is a **tree**. Self/mutual WF cycles fail-closed (`blocked_corrupt_state`, row 1). `definition_closure_hash` walk MUST terminate (visited-set). Composition-Val / Advisor mint that would introduce a cycle is rejected before Executor I.

### H-2 — Hash correctness not just presence

Admission **recomputes** the current recursive closure and **compares** to `launch_intent.definition_closure_hash` (and `composition_generation`). Presence-only is insufficient. Stale/wrong hash or drifted generation → **row 4** (omit **or mismatch**).

### H-3 — Immutable `context_refs` snapshot as child read source

At admit: snapshot job-relevant K/L / work-spec-cited ref **bytes** to `$primary_checkout/.planning/packets/<launch_id>/context-refs-snapshot/`. Child **reads the snapshot**, not live files. `context_refs_hash` = SHA-256 of specified canonical bytes (sorted UTF-8 NFC POSIX relative paths + `0x00` + uint64_be(length) + file bytes). Consume / nested-Task compare hash **and** that the snapshot still exists. TOCTOU on live docs after admit is not a valid read. Not live AM dumps.

## Mediums (accepted)

### M-1 — Clarify SHA ledger

Round-28 addendum/header still showed the round-26 hash. Record this freeze’s SHA after ACCEPT (round-29) and backfill round-28’s **final** SHA `aa3677a5…` on the round-28 block. Invalidated-prior list must not leave round-28’s actual freeze missing.

VERDICT: NOT CLEAN

Parent ACCEPT 2026-08-16 (round-29): H-1 / H-2 / H-3 / M-1 incorporated. Round-29 SHA: `caa36067e2ed6e893b46209a8bec9ee99d8ef78015efb65f8b967a1190934418`. Max not re-launched.
