# RFL ladder 4 — start instruction (do not execute yet)

**Status:** instruction only. **Do not start ladder 4** until ladder 3 is 100% complete. This file is a process lock, not a product plan. Do not invent a new plan. Do not edit the frozen product plan copies.

**Plan id:** `router_subagent_surfaces_85bf9f09`  
**RFL folder:** `.planning/rfl-router-subagent-surfaces-85bf9f09-20260812/`  
**Written:** 2026-08-16  
**Branch:** stay on `main`. No `git checkout` / `git switch` / `SetActiveBranch`.

---

## User lock (write-down only — do not execute ladder 4 from this file)

After **current RFL round (ladder 3) completes 100%**, parent must start **yet another RFL round (ladder 4)** with the **same model rungs** as ladder 3 (**High+** for Cursor/Codex/Claude families; OpenCode rungs are Go SKUs from http://opencode.ai/docs/go/, not High/Max effort).

**Quota fallback:** Any time **Codex** or **Claude** hits a usage/spend limit on that rung, **do not QUOTA-ABORT the ladder**. Re-launch that **same rung** via **Cursor Task**, **after first ensuring** a Cursor `subagent_type` definition exists for that rung (create/install if missing). Then launch with that `subagent_type`, `model` unset/inherit, `run_in_background: true`.

---

## Start gate

Parent may start ladder 4 **only after ladder 3 is 100% complete**.

Until then:

- Ladder 3 remains owned by the **parent** after ACCEPT worker `067eb2ce-4301-433e-9aa3-205ca711a0a7`.
- That ACCEPT worker owns the frozen plan copies. **Do not edit:**
  - [`.planning/router_subagent_surfaces_85bf9f09.plan.md`](../router_subagent_surfaces_85bf9f09.plan.md)
  - `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md`
- Do not launch any review rung (ladder 3 or 4) from this instruction file.
- Do not start Max from this file.
- No Fast. Nested Task model: `sb-grok-4-6-xhigh` or `cursor-grok-4.6-high` only.
- No commit unless the user asked.

**Ladder-3 status (write-down only — do not launch reviews from this file):** Opus Extra High + Max are **CLEAN** on frozen SHA `5eba7e86c040c4965b43446a4454bde8064904a9e52c0f69d2a80f542f795216` (Max: 0 blockers, 0 Highs, 2 Mediums + 1 Low; parent verified none wrong). Round-21 ACCEPT incorporated M-1 / M-2 / L-1. **SHA parent should freeze at ladder-4 start:** `c9511f2daa336ef34f30271348085c885e19903eb8243ddb53832980279aaddf` (both plan copies byte-identical after ACCEPT). Re-hash at actual start. Max already CLEAN — do not re-start Max. Do not start ladder 4 from this file.

---

## Frozen plan SHA (parent fills at start time)

**Do not copy a SHA from this file or from older pause notes.** At the moment parent actually starts ladder 4:

1. Read **both** plan copies (repo + `~/.cursor/plans/`).
2. Confirm they are byte-identical.
3. Hash both (SHA-256). Record the **current** frozen SHA here (or in the ladder-4 launch note).

```
Frozen SHA-256 at ladder-4 start (parent fills): 1096479cc1deba1b902ca501e8d7b7b1c0c1ba5f23510f8776c098f6913002d5
Both copies byte-identical: yes
Hashed at (ISO-8601): 2026-08-16T03:06:34Z
Round: 24 (both plan copies)

Round-25 ACCEPT SHA-256 (GPT Max H-1 + Opus Extra High re-verify B-1/H-1/M-1; both copies byte-identical): 701cc66466830161476597af35606168377acb2437088fb86787eec0f6fcc884
Both copies byte-identical: yes
Hashed at (ISO-8601): 2026-08-16T03:35:23Z
Round: 25 (both plan copies)
Prior start SHA (round-24, invalidated as current freeze): 1096479cc1deba1b902ca501e8d7b7b1c0c1ba5f23510f8776c098f6913002d5
Max not re-launched.

Round-26 ACCEPT SHA-256 (GPT Max re-verify B-1/H-1/M-1/M-2 + Opus Extra High re-verify B-1/H-1/H-2/M-1; both copies byte-identical): ac500b960f2ade792b4cc97f542986e39582bae9a295e8be8a9cca6f2955974b
Both copies byte-identical: yes
Hashed at (ISO-8601): 2026-08-16T03:57:02Z
Round: 26 (both plan copies)
Prior start SHA (round-25, invalidated as current freeze): 701cc66466830161476597af35606168377acb2437088fb86787eec0f6fcc884
Max not re-launched.

Round-27 ACCEPT SHA-256 (GPT Max leftover H-1/H-2 + Opus Extra High re-verify B-1/B-2/H-1/M-1; both copies byte-identical): 60cf413ddac0cbcb80073e776dd0f6d9d56302002d3a2019a682fbb5060410de
Both copies byte-identical: yes
Hashed at (ISO-8601): 2026-08-16T04:15:00Z
Round: 27 (both plan copies)
Prior start SHA (round-26, invalidated as current freeze): ac500b960f2ade792b4cc97f542986e39582bae9a295e8be8a9cca6f2955974b
Max not re-launched.

Round-28 mid-write SHA-256 (GPT Max H-1/H-2/H-3 only; **not** the finished freeze — Opus Extra High H-1/H-2/M-1 landed after): 5463fc192eed0cc601d1406536f628ad7e8f8c0b3e182f7a57c5d249b21c6e27
Hashed at (ISO-8601): 2026-08-16T04:38:57Z
Invalidated as current freeze.

Round-28 ACCEPT SHA-256 **final** (GPT Max H-1 launch_intent closure identity + H-2 recursive definition_closure_hash + H-3 context_refs_hash/snapshot + Opus Extra High H-1 one ART-AGENT-DELEGATE via named emitters + H-2 WF-SILVER-ROUTER slug/owning_skill → sb + M-1 PP-SB-STARTUP-FAST.workflow_refs FEATURE-first; both copies byte-identical): aa3677a5531797f59465a1370b1909fb5c696a42067546b3b4f99f3ac4c5b30c
Both copies byte-identical: yes
Hashed at (ISO-8601): 2026-08-16T04:44:10Z
Round: 28 final (both plan copies)
Prior start SHA (round-27, invalidated as current freeze): 60cf413ddac0cbcb80073e776dd0f6d9d56302002d3a2019a682fbb5060410de
Mid-write SHA (invalidated): 5463fc192eed0cc601d1406536f628ad7e8f8c0b3e182f7a57c5d249b21c6e27
Max not re-launched.

Round-29 mid-write SHA-256 (GPT Max H-1/H-2/H-3/M-1 only; **not** the finished freeze — Opus Extra High B-1/H-1/M-1 landed after): caa36067e2ed6e893b46209a8bec9ee99d8ef78015efb65f8b967a1190934418
Hashed at (ISO-8601): 2026-08-16T04:55:37Z
Invalidated as current freeze.

Round-29 ACCEPT SHA-256 **final** (GPT Max H-1 cycle rejection / tree-not-cycle + H-2 hash recompute/compare omit-or-mismatch + H-3 immutable context_refs snapshot as child read source + M-1 SHA ledger backfill + Opus Extra High B-1 lock emitter + hand-authored nested_executor table + test-router-contract-locks.sh (create it) + H-1 composition remint mints a new launch_id + M-1 context_refs snapshot WS3 + VAL/TST-RFL-626; both copies byte-identical): 9a173a53f04eec56bc139d1e1ae67f7cdc3c0530a9860f71e6253a67e346e7be
Both copies byte-identical: yes
Hashed at (ISO-8601): 2026-08-16T05:04:32Z
Round: 29 final (both plan copies)
Prior start SHA (round-28 final, invalidated as current freeze): aa3677a5531797f59465a1370b1909fb5c696a42067546b3b4f99f3ac4c5b30c
Mid-write SHA (invalidated): caa36067e2ed6e893b46209a8bec9ee99d8ef78015efb65f8b967a1190934418
Max not re-launched.

Round-30 ACCEPT SHA-256 (GPT Max H-1 projector writes snapshot + H-2 tri-color cycle detect + H-3 remint revokes old Executor + M-1 TST-RFL-626 negative fixture + Opus Extra High B-1 projector sole writer + H-1 context_refs_hash stamp vs compare + H-2 live-file read cooperative + H-3 generate-router-contract-locks.py + M-1 regular-files-only snapshot + M-2 snapshot GC tied to resumability; both copies byte-identical): c1868fa31a9e424997ae9994376bac5d27e3f6886f74509c4f2717b21f36a93e
Both copies byte-identical: yes
Hashed at (ISO-8601): 2026-08-16T05:22:27Z
Round: 30 (both plan copies)
Prior start SHA (round-29 final, invalidated as current freeze): 9a173a53f04eec56bc139d1e1ae67f7cdc3c0530a9860f71e6253a67e346e7be
Max not re-launched. Extra High not re-launched.

Round-31 mid-write SHA-256 (GPT Max High only; **not** the finished freeze — Opus Extra High H-1/H-2 landed after): a007c83a645ab6d96846de07b3a22b8233ecbafd6699e83b233f6c3b7b48fe97
Hashed at (ISO-8601): 2026-08-16T05:33:54Z
Invalidated as current freeze. Opus also observed mid-write `b062dc1cbe92aaf9acf027804dd0719963551553d0c98da284bfa677c9a76a6b`.

Round-31 ACCEPT SHA-256 **final** (GPT Max High: canonical row 1 independently matches (a) revoke-before-admit failure and (b) still-running old Executor after remint regardless of whether revocation succeeded; pin both in VAL/TST-RFL-625 / WFM-01; **and** Opus Extra High H-1 L122 visited-set MUST → DFS tri-color / recursion-stack + H-2 L120 generated-template context_refs_hash may omit on launch_intent; both copies byte-identical): a8e7a463bb1bde980ed173b9ddd32e95accf0b6902d6ae92348145f1cffad9ca
Both copies byte-identical: yes
Hashed at (ISO-8601): 2026-08-16T05:38:59Z
Round: 31 final (both plan copies)
Prior start SHA (round-30, invalidated as current freeze): c1868fa31a9e424997ae9994376bac5d27e3f6886f74509c4f2717b21f36a93e
Mid-write SHA (invalidated): a007c83a645ab6d96846de07b3a22b8233ecbafd6699e83b233f6c3b7b48fe97
Max not re-launched. Extra High not re-launched.

Round-32 ACCEPT SHA-256 **final** (Opus Extra High re-verify M-1 row-1 limb (b) observable post-revoke effects only + M-2 canonical row-1 remediation cell exits + N-1 VAL/TST-RFL-604 citation form + N-2 context_refs_hash not a prompt_hash input + N-3 VALP-01 cycle fixtures; GPT Max already CLEAN — not reopened; both copies byte-identical): 3af884ef7892cc93ff5d69023632cf299ec18e87ce77d30860d205b694f317a4
Both copies byte-identical: yes
Hashed at (ISO-8601): 2026-08-16T05:57:13Z
Round: 32 final (both plan copies)
Prior start SHA (round-31 final, invalidated as current freeze): a8e7a463bb1bde980ed173b9ddd32e95accf0b6902d6ae92348145f1cffad9ca
Max not re-launched. Extra High not re-launched.

Round-33 ACCEPT SHA-256 **final** (Opus Extra High re-verify H-1 sweep live-spec restatements of un-narrowed limb (b) at L251/L253/L265/L669 + nit n-1 supersession pointers on append-only logs; M-2 and N-1/N-2/N-3 PASS; M-1 PARTIAL; GPT Max already CLEAN — not reopened; both copies byte-identical): ebd7ad9e499c34e669f8317fcc25715bdfab12a4ef5ed97ac14df6152575ae5e
Both copies byte-identical: yes
Hashed at (ISO-8601): 2026-08-16T06:15:47Z
Round: 33 final (both plan copies)
Prior start SHA (round-32 final, invalidated as current freeze): 3af884ef7892cc93ff5d69023632cf299ec18e87ce77d30860d205b694f317a4
Max not re-launched. Extra High not re-launched.

Round-34 ACCEPT SHA-256 **final** (Opus Max H-1 snapshot GC on CAS-provable `launch_id` supersession + M-1 L511 in-plan Executor mint edge + M-2 snapshot special-file failures exactly row 4 `blocked_launch_prompt_spec` + nit n-1 L470 inserted in-plan NW; Extra High and GPT Max already CLEAN — not reopened; both copies byte-identical): fe219ffeffd1bdff4a16debccb2a598f81e26176fdcc905d20af3c92a51f8b2b
Both copies byte-identical: yes
Hashed at (ISO-8601): 2026-08-16T06:40:37Z
Round: 34 final (both plan copies)
Prior start SHA (round-33 final, invalidated as current freeze): ebd7ad9e499c34e669f8317fcc25715bdfab12a4ef5ed97ac14df6152575ae5e
Max not re-launched. Extra High not re-launched.

Round-35 ACCEPT SHA-256 **final** (Opus Extra High re-verify M-1 L112/L118 two-limb Executor mint + row-40 mid-I PUB-01 trigger + M-2 second snapshot GC trigger from durable `scope_complete` / `completion_receipt_id` + nit VAL/TST-RFL-626 special-file fixtures; all four round-34 landings PASS; round-33 limb (b) 4/4 PASS; GPT Max already CLEAN — not reopened; both copies byte-identical): 71427c3dda42824c3dc59d04fa500f62c904c169bf782dc853a37815106f8c54
Both copies byte-identical: yes
Hashed at (ISO-8601): 2026-08-16T07:03:27Z
Round: 35 final (both plan copies)
Prior start SHA (round-34 final, invalidated as current freeze): fe219ffeffd1bdff4a16debccb2a598f81e26176fdcc905d20af3c92a51f8b2b
Max not re-launched. Extra High not re-launched.

Round-36 ACCEPT SHA-256 **final** (Opus Extra High re-verify M-1a canonical rows 37/40 third limb — row 40 trigger includes mid-I new PUB-01 definition / new catalog WF record; row 37 carve-out excludes that case; L112/L118 two-limb lock unchanged; GPT Max already CLEAN — not reopened; both copies byte-identical): 9c9aa7d93a6fa7dd701e18528dd3d8f422cff0da47902aac4b8ac8c76ce21b06
Both copies byte-identical: yes
Hashed at (ISO-8601): 2026-08-16T07:14:46Z
Round: 36 final (both plan copies)
Prior start SHA (round-35 final, invalidated as current freeze): 71427c3dda42824c3dc59d04fa500f62c904c169bf782dc853a37815106f8c54
Max not re-launched. Extra High not re-launched.

Round-36 ladder-4 GPT High + Extra High Mediums — both **REJECT** (no plan edit). Freeze **unchanged** `9c9aa7d93a6fa7dd701e18528dd3d8f422cff0da47902aac4b8ac8c76ce21b06`. GPT High M-1 Document control Round-35: provenance-only; recency in CLARIFY / this file governs. Extra High M-1 CORR-11 “before Advisor”: stale traceability; body L249→L255 is live spec. Both treated **CLEAN for ladder purposes**. Extra High **not** re-launched. Max **not** re-launched. Not round-37.

Round-36 ladder-4 OpenCode `qwen3.8-max` (**Qwen3.8 Max**, SKU name not effort) — **SKIPPED** this freeze. Blocker: two 2h OpenCode Go runs ([`qwen-high-ladder4/`](qwen-high-ladder4/) invoke-end `2026-08-16T11:20:06Z` and `2026-08-16T13:22:48Z`, both `REVIEW_MD_MISSING_OR_NO_VERDICT`); durable `Endpoint is unavailable`; no `review.md` VERDICT. User skip — **no third launch**. Freeze **unchanged** `9c9aa7d93a6fa7dd701e18528dd3d8f422cff0da47902aac4b8ac8c76ce21b06`. DeepSeek V4 Pro (`deepseek-v4-pro`) and MiniMax M3 (`minimax-m3`) remain **CLEAN** on this SHA. Not round-37.

Round-37 ACCEPT SHA-256 **final** (plan/spec leftovers: Document-control recency names Round-36 M-1a then Round-37; GPT High L4 first findings named ACCEPT (already in round-22 bytes); drop `(row 1 — cite row 1)`; Document-control UUIDs inline code; CORR-11 after Advisor compose L249→L255; mermaid complementary cite; FAST reclassify order matches L249→L255; KEEP REJECT intact; live harness Policy B untouched; both copies byte-identical): 176d0efcf9c88beda5d47e5e651ee69210a11faa48c493ea29d09ed88a0ccc8d
Both copies byte-identical: yes
Hashed at (ISO-8601): 2026-08-16T16:48:06Z
Round: 37 final (both plan copies)
Prior start SHA (round-36 final, invalidated as current freeze): 9c9aa7d93a6fa7dd701e18528dd3d8f422cff0da47902aac4b8ac8c76ce21b06
Max not re-launched. Extra High not re-launched.

Round-38 ACCEPT SHA-256 **final** (Extra High re-verify nits on `176d0efc…`: n-1 CORR-11 live-spec cite L251 then L257 not L249→L255; n-2 KEEP REJECT L598 abandonment-by-silence alias — no pointer churn; n-3 L545 Catalog/lock already lock-only — no schema change; KEEP REJECT intact; live harness Policy B untouched; both copies byte-identical): 1d5c5a3c894a442578d4cac14b391cfac0fa8a7282fa6569083831c05dcd5e6a
Both copies byte-identical: yes
Hashed at (ISO-8601): 2026-08-16T17:04:15Z
Round: 38 final (both plan copies)
Prior start SHA (round-37 final, invalidated as current freeze): 176d0efcf9c88beda5d47e5e651ee69210a11faa48c493ea29d09ed88a0ccc8d
Max not re-launched. Extra High not re-launched.

Round-39 ACCEPT SHA-256 **final** (Extra High re-verify nits on `1d5c5a3c…`: n-1 L265 cooperative-read cite L241 writes not L239 Job identity; n-2 row-1 cycle-class resume cite L122/L731 VALP-01 not L727 ESC-01; n-3 KEEP REJECT L598 abandonment-by-silence alias — no pointer churn; KEEP REJECT intact; live harness Policy B untouched; both copies byte-identical): 2fb45355ec20d044c8beaf60e4ed42128e09a09d9c4b879289426d62e2c0f0c0
Both copies byte-identical: yes
Hashed at (ISO-8601): 2026-08-16T17:10:37Z
Round: 39 final (both plan copies)
Prior start SHA (round-38 final, invalidated as current freeze): 1d5c5a3c894a442578d4cac14b391cfac0fa8a7282fa6569083831c05dcd5e6a
Max not re-launched. Extra High not re-launched.

Round-40 ACCEPT SHA-256 **final** (user lock: 100% test coverage of plan-executed change — not repo-wide line coverage; live-spec MUST + Testing and acceptance + YAML `validation-tests`; map each todo/WS/MUST to named test file/assertion; ship blocked until map complete and green; KEEP REJECT intact; live harness Policy B untouched; both copies byte-identical): 81af8287af9263a75ab88c57e370de22533f659c5777f35fdf95e7dfc8a6edbb
Both copies byte-identical: yes
Hashed at (ISO-8601): 2026-08-17T09:16:50Z
Round: 40 final (both plan copies)
Prior start SHA (round-39 final, invalidated as current freeze): 2fb45355ec20d044c8beaf60e4ed42128e09a09d9c4b879289426d62e2c0f0c0
Max not re-launched. Extra High not re-launched.

Round-41 ACCEPT SHA-256 **final** (Extra High re-verify Round-40 nits on `81af8287…`: n-1 L267 cooperative-read cite L243 writes not L241 Job identity; n-2 row-1 cycle-class resume cite L124/L733 VALP-01 not L122 `/sb:new-workflow` / L731 KLW-01; n-3 CORR-11 live-spec cite L253 then L259 not L251 heading → L257 in-plan-mint window; coverage MUST PASS; KEEP REJECT intact including L598 alias; live harness Policy B untouched; both copies byte-identical): a96045f96743fb33da4e30e1e9eb80a47eb4969641ad78b625a827c48b55df6f
Both copies byte-identical: yes
Hashed at (ISO-8601): 2026-08-17T09:22:00Z
Round: 41 final (both plan copies)
Prior start SHA (round-40 final, invalidated as current freeze): 81af8287af9263a75ab88c57e370de22533f659c5777f35fdf95e7dfc8a6edbb
Max not re-launched. Extra High not re-launched.
```

Round-41 ACCEPT (Extra High re-verify cite nits) on freeze `81af8287…` then this SHA `a96045f96743fb33da4e30e1e9eb80a47eb4969641ad78b625a827c48b55df6f`. Extra High + Max re-verify Round-41 **CLEAN** (0H/0M/0L; coverage L30/L98/L711 PASS; cites L243 / L124/L733 / L253 then L259 PASS; L598 skip). Freeze SHA unchanged.

Stale SHAs seen in this folder (do **not** reuse without re-hashing): pause note `db8cec80…`; later ACCEPT/clarify addenda superseded it. Round-36 ACCEPT `9c9aa7d9…`, Round-37 ACCEPT `176d0efc…`, Round-38 ACCEPT `1d5c5a3c…`, Round-39 ACCEPT `2fb45355…`, and Round-40 ACCEPT `81af8287…` are historical. Current freeze is the Round-41 ACCEPT SHA-256 `a96045f96743fb33da4e30e1e9eb80a47eb4969641ad78b625a827c48b55df6f`.

---

## KEEP REJECT pointer

Canonical KEEP REJECT lives in the clarify brief, latest addendum — **not** in this file and **not** in a new product plan.

- [`.planning/router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md`](../router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md) — section **KEEP REJECT (unchanged)** on the latest Clarify Decision Addendum (round-36 dismiss as of 2026-08-16; parent must use the **current** latest addendum at start time).

Ladder 4 reviews are **review-only**. Do not reopen KEEP REJECT. Do not amend KEEP / KEEP REJECT from a rung.

---

## Review-only (every ladder-4 rung)

- Adversarial architecture review of the **frozen** plan + clarify + [SB-PRODUCT-OVERVIEW-FOR-REVIEWERS.md](SB-PRODUCT-OVERVIEW-FOR-REVIEWERS.md) per [REVIEW-PROMPT-PREAMBLE.md](REVIEW-PROMPT-PREAMBLE.md).
- Do not triage. Do not implement. Do not edit the plan copies. Do not commit.
- Stay on `main`.
- End with exactly one line: `VERDICT: CLEAN` or `VERDICT: NEEDS_FIXES`.
- No Fast. Cursor/Codex/Claude families: no Medium unless a family has no High (none of those do). OpenCode Go SKUs have no High/Max reasoning-effort split.

---

## Same rung table as ladder 3 (High+ order)

Reconstructed from this folder’s High / Extra High / Max artifacts plus sibling OpenCode ladder-3 dirs. **Same Cursor/Codex/Claude families, same High+ order, no Fast.** OpenCode for **this** RFL is exactly **three** [OpenCode Go](http://opencode.ai/docs/go/) SKUs already in flight — not the whole Go catalog.

Within a **Cursor / Codex / Claude** family: **High**, then **Extra High** if it exists, then **Max** if it exists as a distinct rung. For GLM and Kimi, Extra High maps to the Max slug (do not run a duplicate third Max after Extra High unless parent explicitly splits them). GLM / Kimi / Grok / GPT Luna on Go are **not** extra OpenCode rungs here — those families already ran as Cursor `sb-*`.

**OpenCode exception:** http://opencode.ai/docs/go/ lists **distinct model SKUs**, not High vs Max reasoning effort. Do **not** invent a second Max **rung**, “OpenCode Max”, or Cursor `sb-opencode-*` / `sb-opencode-max`. “Max” in Qwen3.8 Max is the model **name**. Existing `launch.sh` may still pass `--variant high`; that is a launch flag, not a second rung. Do not launch invented ladder-3 `*-max-*` effort dirs for DeepSeek or MiniMax.

| # | Family | Effort | Host | Ladder-3 evidence | Launch (ladder 4) |
|---|--------|--------|------|-------------------|-------------------|
| 1 | DeepSeek V4 Pro | — (Go SKU; not High/Max effort) | OpenCode | `.planning/agent-opencode/rfl-deepseek-v4-pro-high-ladder3-20260815/` (prior SKU launch; ignore sibling `*-max-*` dir) | Go `deepseek-v4-pro`. Not a Cursor Task. `--variant high` OK if `launch.sh` already uses it. Canonical: http://opencode.ai/docs/go/. This freeze: **CLEAN** on `9c9aa7d9…`. |
| 2 | MiniMax M3 | — (Go SKU; not High/Max effort) | OpenCode | `rfl-minimax-m3-high-ladder3-20260815/` (prior SKU launch; ignore sibling `*-max-*` dir) | Go `minimax-m3`. Not a Cursor Task. `--variant high` OK if `launch.sh` already uses it. Canonical: http://opencode.ai/docs/go/. This freeze: **CLEAN** on `9c9aa7d9…`. |
| 3 | Qwen3.8 Max | — (Max is the SKU name, not effort) | OpenCode | `rfl-qwen-max-ladder3-20260815/` (name overlap only; not Cursor Max effort) | Go `qwen3.8-max`. Not a Cursor Task. Do not add `qwen3.7-max`. Canonical: http://opencode.ai/docs/go/. This freeze: **SKIPPED** (durable `Endpoint is unavailable`; two 2h Go runs; no `review.md` VERDICT; user skip — no third launch). |
| 4 | Composer 2.5 | High | Cursor | `composer-2.5-high-ladder3/` | `sb-composer-2-5-high` (`composer-2.5`) |
| 5 | Composer 2.5 | Extra High | Cursor | `composer-2.5-xhigh-ladder3/` | `sb-composer-2-5-xhigh` (`composer-2.5`) |
| 6 | GLM 5.2 | High | Cursor | `glm-5.2-high-ladder3/` | `sb-glm-5-2-high` (`glm-5.2-high`) |
| 7 | GLM 5.2 | Extra High | Cursor | `glm-5.2-xhigh-ladder3/` | `sb-glm-5-2-xhigh` (maps to `glm-5.2-max`) |
| 8 | Gemini 3.7 Flash | High | Cursor | `gemini-3.7-flash-high-ladder3/` | `sb-gemini-3-7-flash-high` (`gemini-3.7-flash-high`). High-only (no Extra High). |
| 9 | Kimi K3 | High | Cursor | `kimi-k3-high-ladder3/` | `sb-kimi-k3-high` (`kimi-k3-high`) |
| 10 | Kimi K3 | Extra High | Cursor | `kimi-k3-xhigh-ladder3/` | `sb-kimi-k3-xhigh` (maps to `kimi-k3-max`) |
| 11 | Grok 4.6 | High | Cursor | `grok-4.6-high-ladder3/` | `sb-grok-4-6-high` (`cursor-grok-4.6-high`) |
| 12 | Grok 4.6 | Extra High | Cursor | `grok-4.6-xhigh-ladder3/` | `sb-grok-4-6-xhigh` (`cursor-grok-4.6-xhigh`) |
| 13 | GPT-5.6 Sol (Codex) | High | Codex → Cursor on quota | `rung-gpt-5.6-sol-high-task-c*.md` | Codex High, **or** quota fallback `sb-gpt-5-6-sol-high` |
| 14 | GPT-5.6 Sol (Codex) | Extra High | Codex → Cursor on quota | `rung-gpt-5.6-sol-xhigh-task-c*.md` | Codex Extra High, **or** quota fallback `sb-gpt-5-6-sol-xhigh` |
| 15 | GPT-5.6 Sol (Codex) | Max | Codex → Cursor on quota | same High+ table (Max after Extra High) | Codex Max, **or** quota fallback `sb-gpt-5-6-sol-max` |
| 16 | Opus 5 (Claude) | High | Claude → Cursor on quota | `opus-5-high-ladder3/` | Claude High, **or** quota fallback `sb-opus-5-high` |
| 17 | Opus 5 (Claude) | Extra High | Claude → Cursor on quota | `opus-5-xhigh-ladder3/` | Claude Extra High, **or** quota fallback `sb-opus-5-xhigh` |
| 18 | Opus 5 (Claude) | Max | Claude → Cursor on quota | same High+ table (Max after Extra High) | Claude Max, **or** quota fallback `sb-opus-5-max` |

Notes:

- Original 20260812 [ledger.json](ledger.json) / [RFL-SUMMARY.md](RFL-SUMMARY.md) listed a shorter Gemini 3.6 → GLM → Kimi → GPT → Opus ladder. **Ladder 3 High+ is the wider table above** (OpenCode = three in-flight Go SKUs). Ladder 4 copies that table, not the original five-rung ledger.
- Gemini 3.6 Flash High task files in this folder are earlier-ladder artifacts. Ladder 3 Gemini Flash High is **3.7**.
- Composer has no distinct Max slug (same `composer-2.5` model, effort in the agent def).
- No `*-fast*` slugs. Ever.
- Do **not** add other Go SKUs (`qwen3.7-max`, DeepSeek V4 Flash, MiniMax M2.7, Go GLM/Kimi/Grok/Luna, …) as OpenCode rungs for this RFL.
- OpenCode this freeze (`9c9aa7d9…`): DeepSeek V4 Pro + MiniMax M3 **CLEAN**; Qwen3.8 Max **SKIPPED** (see SHA block). Rows stay the three Go SKUs.

---

## Quota fallback — Codex / Claude only

When **Codex** (GPT-5.6 Sol) or **Claude** (Opus 5) hits a usage/spend limit on the **current** rung:

1. **Do not QUOTA-ABORT** the ladder.
2. **Ensure** the Cursor `subagent_type` def exists (see table below). If missing: install via `bash scripts/install-cursor-sb-agents.sh` (lib: `scripts/lib/cursor-sb-agents/cursor_sb_agents_lib.py`; config: `.silver-bullet.json` `cursor_sb_agents` and `~/.config/silver-bullet/cursor-sb-agents.json`). Do not break existing xhigh/max defs. No Fast slugs.
3. Re-launch the **same rung** as a Cursor Task:
   - `subagent_type`: exact value from the table
   - `model`: **unset / inherit** (def already pins the slug)
   - `run_in_background`: **true**
4. Nested workers from that Task: `sb-grok-4-6-xhigh` or `cursor-grok-4.6-high` only. No Fast.

### Exact `subagent_type` (quota fallback)

| Rung | `subagent_type` | Def `model` (inherit) | Agent file |
|------|-----------------|------------------------|------------|
| GPT-5.6 Sol High | `sb-gpt-5-6-sol-high` | `gpt-5.6-sol-high` | `~/.cursor/agents/sb-gpt-5-6-sol-high.md` |
| GPT-5.6 Sol Extra High | `sb-gpt-5-6-sol-xhigh` | `gpt-5.6-sol-xhigh` | `~/.cursor/agents/sb-gpt-5-6-sol-xhigh.md` |
| GPT-5.6 Sol Max | `sb-gpt-5-6-sol-max` | `gpt-5.6-sol-max` | `~/.cursor/agents/sb-gpt-5-6-sol-max.md` |
| Opus 5 High | `sb-opus-5-high` | `claude-opus-5-thinking-high` | `~/.cursor/agents/sb-opus-5-high.md` |
| Opus 5 Extra High | `sb-opus-5-xhigh` | `claude-opus-5-thinking-xhigh` | `~/.cursor/agents/sb-opus-5-xhigh.md` |
| Opus 5 Max | `sb-opus-5-max` | `claude-opus-5-thinking-max` | `~/.cursor/agents/sb-opus-5-max.md` |

Inventory at write time (2026-08-16): **all six already present** in `~/.cursor/agents/` (managed marker `cursor-sb-agents`). Project `.silver-bullet.json` `cursor_sb_agents.rfl_effort_maps` already includes `high` / `xhigh` / `max` for `gpt-5.6-sol` and `opus-5`, so a later install with `include_max: false` still **keeps** these max defs (map keys drive `efforts_for_model`). High was **not** missing. No defs added by this worker. Tests not run (no def/lib change).

OpenCode DeepSeek V4 Pro / MiniMax M3 / Qwen3.8 Max quota is **not** this Cursor-Task path. Those three ids come from http://opencode.ai/docs/go/, not from Cursor `sb-*` slugs. No `sb-opencode-max`.

---

## Parent checklist when actually starting ladder 4

1. Ladder 3 = 100%.
2. Hash both frozen plan copies; fill SHA above.
3. Re-read KEEP REJECT from the current clarify addendum.
4. Confirm the six Codex/Claude agent defs still exist; install if pruned.
5. Launch rung 1 (DeepSeek V4 Pro, OpenCode Go `deepseek-v4-pro`, review-only). Do not invent a Max effort for that SKU. Do not skip to Cursor families.
6. Stay on `main`. No commit unless the user asked.

**This worker did not start ladder 4.**
