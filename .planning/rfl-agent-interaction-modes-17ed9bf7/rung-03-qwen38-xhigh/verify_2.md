# Rung 3 verify pass 2 (independent) — Qwen3.8 XHigh (OpenCode)

**Plan:** [agent_interaction_modes_17ed9bf7.plan.md](/Users/shafqat/projects/silver-bullet/repo/.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md)

**Method:** VERIFY-ONLY pass 2, independent of pass 1. Fresh re-read of the full plan (407 lines) plus independent line-level greps for every I-25..I-31 fix marker and a new-blocker sweep (flag-scope contradictions, event-vocabulary closure, schema consistency, mermaid/§4.2/§9/§12 agreement). No plan edits.

**Plan SHA256:** `1c25c33cd16f957a8752dafd30a290e10e36e070a8db51c96889b85aae2f3e09` (407 lines — byte-identical to the hash verified in pass 1; zero drift since `verify_1.md`).

**STATUS:** **VERIFY_PASS** — I-25..I-31 all hold under independent re-grep; no new blockers.

## Plan stability

- SHA256 matches pass 1 exactly (`1c25c33c…`, 407 lines). Nothing changed between pass 1 and pass 2, so every pass-1 line citation remains valid; pass 2 re-derived each verdict from fresh greps anyway.

## I-25..I-31 — independent re-grep

### I-25 (MEDIUM) — `--allow-mode-fallback` pin-only — HOLDS

- Line 78 (D6): fail-closed "**only** when interactive is **pinned** (not D4)"; closing sentence "`--allow-mode-fallback` is **pin-only**; D4 TUI miss stays `escalate-unavailable` / original NI FAIL (I-25)".
- Line 274 (§6.2): "**pinned interactive only** → NI if TUI missing; one hop; audit `mode_fallback` {from,to,reason,flag}. **Not valid on D4** (would be a second NI) (I-25)".
- Opposing side unconditionally fail-closed: line 76 (D4) "stop and report the NI failure (no fake TUI)" — no flag exception; line 166 "Do not spawn a second NI"; line 167 "keep original NI FAIL; do not loop"; line 358 (§9) `escalate-unavailable` keeps NI FAIL; mermaid lines 117–118 (`no and auto` → ni; `no and pin or D4` → done) + line 128 note.
- Full-mention sweep (`allow-mode-fallback` / `ALLOW_MODE_FALLBACK` / `allow_mode_fallback`): lines 78, 255, 274, 280, 345 — none re-admits D4. No contradiction.

### I-26 (MINOR) — event vocabulary closed — HOLDS

- Line 321 (§6.3): event enumeration ends "`… | `clarify` | `zero_tokens` (I-26)` — both §5.2 loop events documented.
- Line 232 (§5.2 step 4) `question` / `clarify` / `picker` and line 233 (step 5) `stuck` / `zero_tokens` — every event the normative loop reacts to now appears in the closed list.
- Independent grep: `0-token` occurrences = **0**. Single canonical spelling.

### I-27 (MINOR) — one `mode.json` schema, `resolved` everywhere, null `classified` — HOLDS

- Lines 158 (§4.1), 200 (§5.1), 309 (§6.3 tree) all read `{requested, classified, resolved, reason[]}`; line 158 and line 355 (§9) state `classified` is `null` when pinned.
- Line 200 pins NI to the same core schema with **no** `events.jsonl` / fifo; line 158 and line 355 give interactive the additional redacted `mode_resolved` event line. Consistent three-way (NI sidecar / interactive event / §9 acceptance).

### I-28 (MINOR) — `escalation.md` sole prior-result artifact — HOLDS

- Independent grep: `prior_result` appears exactly **once**, line 166, inside the explicit prohibition "Do not use a separate `prior_result.md` name (I-28)".
- Line 76 (D4) ships "brief plus `escalation.md` / log tail"; line 166 defines the payload: log tail, remaining criteria, and `NEXT_RETRY_PROMPT` from `result.md` (STATUS block field confirmed at line 199). §6.3 artifact list (line 312) carries `escalation.md # present after NI miss`; no `prior_result.md` entry.

### I-29 (MINOR) — D4 retry inherits the wave — HOLDS

- Line 76 (D4): "D4 retry **inherits** the same wave `{turns, wave_started_at}` (does not reset wall/turns) (I-29)".
- Line 243: `--max-wall-sec` "**wave-scoped** not per-process" — one wall clock spans NI→interactive retry; line 242 persists the shared `{turns, wave_started_at}` counter. Coherent; the near-wall-budget squeeze called out in the review is now a defined, testable behavior rather than an omission.

### I-30 (MINOR) — `session.json` schema + pid liveness — HOLDS

- Line 138 (§4.1): "`session.json` stores `{status, conversation_id, pid?, updated_at, turns, wave_started_at}`; 'OS child still running' means `pid` is set and `kill -0` succeeds (I-30). PASS/terminal reset **must** set `status=dead` (or delete `session.json`)".
- Case (1) now has a detection mechanism; TTL (24h from `updated_at`) applies to (1)(2); dead-reset closes the leftover-id skip. All testable.

### I-31 (NIT) — sub-items — HOLDS (in-scope)

- **(b) ctl ops:** line 327 lists all five: `ctl.sh send|key|snapshot|status|abort` (I-31), matching the op vocabulary at line 319; line 366 builds it interactive-only; line 396 tests `question` → `ctl.sh send` → `result.md`; frontmatter todo line 15 agrees.
- **(c) D4 not D3:** line 165 "Resolve mode = interactive because D4 escalate is in-flight (not because D3 session-continuity flipped) **unless** `--no-escalate` (I-31c)". Independent grep: "D3 now true" occurrences = **0**. `reason[]` attribution is escalate-flavored, matching §4.1 line 141 "In-flight escalate only".
- **(a) OpenCode driver:** line 336 names "the existing host TUI driver (do not add a second expect/python wrap) … (I-31a)" — named-by-existence; D7's single-driver clause satisfied.
- **(d):** lines 294–295 cover interactive-only flags on pinned NI and on auto (`attach-on-ni` / `control-dir-on-ni`); §6.1 slash synopsis omitting `--auto-policy`/`--control-dir` remains the deliberate slash-vs-CLI surface split (§6.2 is the full contract). Out of re-run scope; non-blocking.

## New-blocker search (fresh sweep)

- **Flag-scope contradictions:** `--allow-mode-fallback` (above), `--no-escalate` (lines 147/165/168 agree: disables D4 + in-flight-escalate force-interactive, never D3 (1)/(2)), `--attach` (lines 87/272/295 agree: not a pin on auto; `attach-on-ni` on classified NI), `--mode` permission smash (lines 74/258/290). None found.
- **Event-vocabulary closure:** every event named in §5.2's loop (lines 230–237: ready, assistant, tool_use, idle_working, question, clarify, picker, stuck, zero_tokens, auth, quota, done) appears in §6.3's closed list (line 321), which additionally carries `mode_resolved`, `prompt_submitted`, `escalated`, `error`, `exited` for §9/§4.2 needs. Closed.
- **Schema consistency:** `mode.json` (lines 158/200/309/355), `session.json` (lines 138/202/242), `escalation.md` (lines 166/312). No conflicting field lists.
- **Mermaid ↔ prose:** resolver edges (lines 106–125) match D1/D3/D4/D6 and the line 128 note; `retry --> pass` with inherited wave (I-29) is consistent with §4.2.
- **§9 ↔ §6.3 failure classes:** `mode-unavailable` | `mode-conflict` | `max-turns` | `escalate-unavailable` | `hook-trust` (line 359) each have a defining clause (D6, §6.2.1, §5.2 line 242, §9 line 358, §7 line 334). Complete.
- **§12 acceptance ↔ fixes:** lines 389–407 test classifier, pin-wins, one-retry, NI-isolation (no PTY/events.jsonl), ctl send, conflict pairs, orthogonality, I-18/I-20/I-21, prior-wave reset, Cursor new-process session, tui-unavailable, redaction, AF round-trip. No acceptance criterion contradicts a locked decision.
- Cosmetic only (not a blocker): line 298 table row ends with a trailing `|` cell ("redundant, allow |") — renders fine, semantics clear.

## Residuals carried (non-blocking, unchanged since pass 1)

- R-2: no payload schema for `clarify` / `zero_tokens` (enumeration-only was accepted).
- R-5: line 242 still names both `session.json` / `mode.json` for `{turns, wave_started_at}` without a single canonical owner.
- I-31(d) remainder: alias/env-form interactive-only-flag conflicts (e.g. `--non-interactive --attach`, `SB_AGENT_MODE_ATTACH=1` + NI pin) not individually enumerated; long-form rows + general preflight cover them.

All three were already classified non-blocking in pass 1 and are unchanged (identical SHA).

## Gate

**VERIFY_PASS.** Pass 2 independently confirms I-25 pin-only fallback, I-26 `zero_tokens`/`clarify` closure, I-27 unified `mode.json` schema, I-28 `escalation.md`-only, I-29 wave inheritance, I-30 pid liveness, and I-31 ctl-ops/D4-not-D3 in plan `1c25c33c…` (byte-identical to pass 1). No new blockers. No plan edits made.
