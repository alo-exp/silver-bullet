# Round 4 — post-clarify (2026-08-31 locks)

**Run id:** `rfl-dr-search-gateway-ecb5030e-round-4-post-clarify`  
**Started:** 2026-08-31  
**Kind:** plan-only review-fix ladder (new ladder after 2026-08-31 locks + re-clarify)  
**Rung 1:** CLOSED — Policy F 2/2 CLEAN (pass 21 + pass 22) on SHA `916d87f52b25688f7953c76c89b96802d9438eb8da537a8c16b927b98b2ee138`.  
**Rung 2:** CLOSED — Policy F 2/2 CLEAN (pass 6 + pass 7) on SHA `f6ba43bb7d7d4d4ca394333ae5f7c15022059040edac9ec75585654630584cd6`. Next resume: rung 3 Gemini 3.7 Flash High from the **main** checkout. Do not start Gemini from this hop. Do not reopen worktree `ewwf` if removed.

This is **not** Round 1–3 and **not** Round 3 MiniMax. Do not resume `missing-highplus/` or any pre-lock MiniMax handoff.

## Canonical corpus (locked scope)

1. [`/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md`](/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md) — **only** reviewer input (clarify/research are not attached)

Review **the plan**. Do not attach clarify or research notes. Do not audit Silver Bullet plugin source unless the plan cites a broken contract. Do **not** implement `alo-exp/search-cli` / Rust unless a Policy A ACCEPT is a **plan text** patch. Do **not** switch git branches. Do **not** commit unless a planning artifact is required. Do **not** tell reviewers to keep product locks (launcher asks the user before unwinding).

## State machine (HARD)

Per APPLY cycle: `review` → Policy C → Policy A/B (launcher APPLY) → `verify_1` (Composer 2.5) → orchestrator greps → `verify_2` (Composer 2.5) → greps.

### Policy F — two CLEAN **review** streaks (not verifies)

A **streak** is one full review (or re-review after APPLY) that comes back **CLEAN**: zero ACCEPT-worthy findings (0 findings, or triage is only REJECT-as-wrong). The **same rung / same model** must produce **two consecutive CLEAN review streaks** (`consecutive_clean_reviews == 2`) before the next model.

- ACCEPT findings → APPLY, then `verify_1` + `verify_2` + greps, then **`--record-rung-review-outcome accept-apply` (streak resets to 0)** → re-launch the **same** reviewer (review-only). Verifies are **not** streak increments.
- CLEAN review (no ACCEPTs) → still run both verifies + greps → `--record-rung-review-outcome clean` (streak +1) → if streak < 2, re-review the same model.
- Do **not** treat `verify_1` CLEAN + `verify_2` CLEAN as the two streaks. Both verify passes still run per skill; they are a separate gate.

Leftover-cycle: verify FAIL → Policy B leftovers then re-verify; same defect class failing verify >2 times → corpus sweep; cap 5 leftover cycles then escalate.

Launch/timeout: retry once immediately. After two failures with no verdict: skip (`SKIPPED.md`) for Cursor hosts; Pi/OpenCode cannot-launch after retry → substitute Grok 4.6 High per skill. After the whole ladder, retry skipped rungs once more. Three timeouts → `SKIPPED.md`. Anti-stall: `ANTI-STALL.md` if present under `.planning/rfl-dr-search-gateway-ecb5030e/` (none at round start).

## Rungs (user-specified, sequential)

See [LADDER.md](LADDER.md). Exactly one Task / Pi invoke per turn. GLM 5.2 High is parent-spawned (not nested under Grok).

## Policy E

[RUNG-PROMPT-APPROVAL.md](RUNG-PROMPT-APPROVAL.md) is `approved: yes` (2026-08-30T17:49Z, user edits: plan-only corpus; no lock-keeping in reviewer briefs).
