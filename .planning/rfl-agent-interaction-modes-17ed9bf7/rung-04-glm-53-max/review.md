# Rung 4 review — GLM 5.3 Max (OpenCode)

**Plan:** [agent_interaction_modes_17ed9bf7.plan.md](/Users/shafqat/projects/silver-bullet/repo/.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md)

**Method:** direct review session (parent agent = `opencode-go/glm-5.3`, rung label GLM 5.3 Max). Full-plan read (407 lines) plus `grep -n` verification of every quoted phrase/line citation below; RFL ledger, rung 1–3 reviews, and rung-1 triage read for dedup; repo file-existence re-check. No plan edits.

**STATUS:** review-complete

**Plan SHA256:** `1c25c33cd16f957a8752dafd30a290e10e36e070a8db51c96889b85aae2f3e09` (mtime Aug 24 03:12:04) — differs from rung-2/3's `4077356b…`: the I-25..I-31 fix rung landed between rung 3 and this rung. This review targets the post-fix text.

## Prior-rung state checked (do not re-file)

- **I-25..I-31 fixes verified present and correct:** D6/§6.2 `--allow-mode-fallback` pin-only, D4 stays `escalate-unavailable` (I-25); `clarify`/`zero_tokens` in §6.3 events (I-26); mode.json schema with `classified: null` when pinned (I-27); escalation payload via `escalation.md`, no `prior_result.md` (I-28); D4 inherits wave (I-29); session.json schema + `kill -0` liveness (I-30); OpenCode Desktop `.app` preflight rejection, ctl.sh five ops, §4.2 step-2 D4-not-D3 attribution, leftover-env-pin / auto+`--attach` conflict rows (I-31a–d).
- **Rung-2 residuals I-18/I-20/I-21** — fixes now landed in the current text (D1/§4.1/mermaid three-way split; D8 + `attach-on-ni` + §12 row; D2 `leftover-env-pin` + preflight unset + §12 row). Not re-filed.
- I-9/I-10/I-11/I-14 closed by the landed text (§4.1 signal list + §10 step-11 fixtures; `auto_policy` ownership; precedence sentence; event/escalation schemas). Not re-filed.
- Sparse HEAD persists: all 11 §1/§7/§10 file references MISSING at this checkout (re-verified). B1 was **REJECT** at rung-1 triage; informational only, not re-litigated. Consequence for this rung: the live `failure_class` catalog is not greppable here (scripts/, skills/ absent), so §9 statements are reviewed as plan text alone.
- Rung-1 triage dispositions honored: I-5/I-6/I-15/B1 REJECT; M-A3 (auth/log-floor enumeration) DEFER — not re-raised; m-A*/n-A* SELECTIVE — not re-raised.

## ISSUES (new)

### I-32 MEDIUM — resolver can land on NI while a live session/child exists; orphan handling undefined, and D3-mandatory interactive is silently downgraded

Three reachable paths resolve to a **fresh NI** while the session-continuity premise is still live, and the plan never says what happens to the still-running child / open thread:

- **D6 downgrade (line 78):** "Auto (**including classifier/D3 picking interactive**) + TUI/session unavailable: do not fail-closed — launch NI with `reason=tui-unavailable` (Pi/Cursor)." Mermaid edge 117 (`tui -->|no and auto| ni`) encodes the same. But §2 (line 53) says session continuity makes interactive **required** ("classifier must not pick NI"), and D3's own definition (line 75) is "any case where a fresh one-shot would lose an already-open tool/context/thread" — the downgrade does exactly that. The rung-1 triage action for I-7 was "Auto interactive + no TUI → NI `tui-unavailable` **unless pin/mandatory**"; the landed text dropped the *mandatory* carve-out for D3 (I-25 later carved out D4 only).
- **§7 Cursor (line 335):** "If CLI cannot keep or reuse a session id, then: auto → NI `reason=tui-unavailable`". An in-wave Cursor follow-up is D3 (2) — its whole point is reusing the open conversation. Id-reuse failure → fresh NI silently starts a **new** conversation, discarding the open thread D3 (2) exists to protect.
- **§4.1 TTL (line 138):** "TTL (default 24h from `updated_at`) applies to (1)(2). Stale/expired `session.json` does not force interactive." A >24h-old `session.json` with `kill -0` **succeeding** (live child) is ignored → classify fresh → possibly NI while the child still runs.

In all three, a second agent starts while the first session lives: nobody aborts it (§6.3 `abort` is wired only to the interactive command loop), D7 line 85 ("Prefer attaching an existing session over spawning a second agent when D3 applies") is violated, `session.json` gains a second writer, and line 138's PASS/terminal reset must set `status=dead` while the pid is still alive.

**Fix:** (a) scope D6's auto downgrade to *classifier-heuristic* interactive only — D3-forced (1)/(2) + transport unavailable behaves like pin/D4 (`mode-unavailable`, prior result kept); or (b) keep the downgrade but define the orphan policy (abort the live child first via the existing `abort` op; mark thread-lost; document the context discard). Separately, decide TTL-vs-liveness precedence: `kill -0` success outranks TTL, or TTL expiry obligates the parent to stop the child before classifying fresh.

### I-33 MINOR — D4 wall-budget inheritance can stillborn the mandated retry; the NI leg's wall participation is undefined

D4 (line 76): retry "inherits the same wave `{turns, wave_started_at}` (**does not reset wall/turns**)" (I-29). §5.2 (line 243): "`--max-wall-sec` host defaults (… Cursor 1800 …), **wave-scoped** not per-process." But `--max-wall-sec` is defined only under §5.2 *Interactive* hard limits — §5.1 NI has no wall cap (block on exit + tail-idle). Two consequences:

1. If the NI leg is metered: a 35-min Cursor NI run exhausts the 1800 s wave budget before the retry starts → the D4 escalation is born dead (remaining wall ≤ 0) and fails instantly.
2. If the NI leg is unmetered: it is unclear what `wave_started_at` means for a wave whose first leg is NI, and the inherited wall is either full (contradicting "does not reset wall") or arbitrary.

Also, wall-exhaustion as a terminal failure has no §9 `failure_class` (line 359 catalog: `mode-unavailable | mode-conflict | max-turns | escalate-unavailable | hook-trust`) — not verifiable against the live catalog in this sparse checkout.

**Fix:** one sentence either way — NI leg is wall-unmetered and the D4 retry restarts wall (turns still inherited; NI consumes 0 turns), or wall is shared with a floor (e.g. `max(300s, remaining)`); and name the failure_class for wall exhaustion (existing class or new).

### I-34 MINOR — `{turns, wave_started_at}` have no schema home in `mode.json`

§5.2 (line 242) requires persisting `{turns, wave_started_at}` "on `session.json` / `mode.json`" (I-24), and D4 (line 76) inherits the wave from the **NI** run. But:

- `session.json` (I-30 schema, line 138) has the wave fields, and interactive runs write it — yet NI writes `session.json` "only if the host one-shot returns a reusable conversation id (**usually empty in NI**)" (line 202).
- Every `mode.json` schema statement (lines 158, 200, 309, 355) is `{requested, classified, resolved, reason[]}` — no wave fields (I-27 scoped the core schema only).

So for the common NI wave there is no defined persistence location, and both D4 inheritance and Cursor new-process follow-ups after an NI first leg have nothing to read.

**Fix:** add optional `turns`/`wave_started_at` to the `mode.json` schema at all four statements, or name `session.json` canonical and require NI to write it (minimal fields) when a wave is open.

### I-35 MINOR — §11 allowed-wrapper assertion contradicts D7's six-wrapper list

D7 (line 82) allows **six** NI reliability wrappers: preflight, quota-retry loop, tail-idle, secret scan, log header, optional read-only `monitor.sh` — and its "live path" sentence makes secret scan and log header effectively mandatory. §11 (line 386): "allowed wrappers are **preflight/quota/tail-idle only**." Tests written to §11's enumeration fail D7-compliant NI paths (or pressure implementers to drop mandated wrappers).

**Fix:** align §11's risk line with D7's list.

### I-36 MINOR — `mode.json` `reason[]` vocabulary is undefined while four behaviors key off it

`reason[]` is load-bearing in: D6's downgrade marker (`reason=tui-unavailable`, line 78), §9's `escalate-unavailable` record (line 358), §4.2 step 2's attribution requirement (line 165: interactive "because D4 escalate is in-flight (**not because D3 session-continuity flipped**)" — I-31c), and §4.1's decision record (line 158). No section enumerates the vocabulary or states whether entries are machine-readable codes or free prose. I-14 covered `events.jsonl`/`escalation.md` schemas, I-27 the mode.json core schema, I-31c the attribution — none defined `reason[]` itself. Consequence: the I-31c attribution rule and the §9 markers are unassertable in tests.

**Fix:** enumerate the codes (e.g. `pinned`, `d3-process-alive`, `d3-continue`, `d3-in-wave-cursor`, `classifier-interactive`, `classifier-ni`, `tie-break-ni`, `tui-unavailable`, `escalate`, `escalate-unavailable`, `leftover-env-pin`, `attach-on-ni`…) and state `reason[]` entries are codes, not prose.

### I-37 MINOR — D3's own signal list exceeds the (1)(2) definition everything else uses

D1 (line 73) scopes D3 strictly: "D3 fires **only** for (1) … or (2) …". §4.1 (line 138) implements exactly that split. But D3's body (line 75) appends classifier heuristics — "multi-step supervision…; **likely clarifiers/pickers**" — inline with the (1)(2) liveness signals (§4.1 lines 139–140 correctly keep those under the classifier). Consequence: "D3 fired" is ill-defined; a picker-driven invoke can be attributed to D3 in `reason[]`/`mode_resolved`, breaking I-31c's attribution and muddying D1's precedence clause ("process-alive or continue/coach (D3) > classifier").

**Fix:** trim D3's body to (1)(2) plus the open-context clause; keep pickers/clarifiers/multi-checkpoint supervision in §4.1's classifier force-interactive list only.

### I-38 MINOR — D4 retry bookkeeping: one `mode.json`, two resolutions; classifier's `mode.json` read and escalate-pending persistence undefined

- §4.1 (line 134) lists `mode.json` as **classifier input**, but no field is defined as consumed (`requested`? `resolved`? `reason[]`?), and the in-flight-escalate signal (line 141: "a §4.2 retry for this `task-id` is **pending**") has no persistence mechanism. `escalation.md` (line 313) is written at §4.2 step 1 but persists after the retry completes, so its presence cannot distinguish pending from done; if the parent dies between NI exit and retry start, the next invoke cannot see the pending escalate (line 145's prior-wave reset keys on "no pending escalate" — unreadable).
- One task-dir holds two resolved modes when D4 fires. §9 (line 358) says `escalate-unavailable` goes "on **NI** `mode.json` `reason[]`" — implying mode.json stays the NI record; but when the retry *does* start, does it overwrite `mode.json` (losing the NI resolution) or record its `mode_resolved` only in the retry's `events.jsonl` (line 355)? Single-valued `{requested, classified, resolved}` cannot represent both.

**Fix:** define (a) which `mode.json` fields the classifier reads; (b) where escalate-pending is persisted (e.g. a `reason[]` code or a status field, cleared on retry start/terminal); (c) retry bookkeeping — NI `mode.json` gains `escalated` in `reason[]` and the retry's `mode_resolved` lives in its `events.jsonl` (recommended), or `mode.json` gains a `resolved[]` history.

### I-39 NIT — §6.2.1 gaps: `--auto-policy` missing from the NI interactive-only-flags row; `--allow-mode-fallback` undefined on auto/NI

Line 294's row (`--interaction-mode non-interactive` + `--attach` / `--control-dir` / `--max-turns`) omits `--auto-policy`, which line 275 and §8 (line 345) mark interactive-only — same class of conflict, not enumerated. And `--allow-mode-fallback` is pin-only (lines 74/78, I-25) but no row covers it on `auto` or NI argv: conflict (like `attach-on-ni`) or documented-ignore? Extends I-31(d)'s pattern to two flags it did not name.

**Fix:** add `--auto-policy` to line 294's row (plus alias forms per I-31(d)); add a row or a help-note defining `--allow-mode-fallback` outside pinned-interactive scope.

### I-40 NIT — D9 shared-API function list vs §6.3 ops/ctl.sh mismatch

D9 (line 88): `resolve_mode, classify_task, start, send, snapshot, wait_event, stop`. §6.3 (lines 319/327): ops and ctl.sh expose `send|key|snapshot|status|abort`. D9 omits `key` and `status`, and splits naming `stop` vs `abort`.

**Fix:** add `key`/`status` to D9's list and unify `stop`/`abort` naming.

### I-41 NIT — `kill -0` liveness is pid-reuse-unsound

Line 138 (I-30): "OS child still running means `pid` is set and `kill -0` succeeds." A recycled pid makes an unrelated process look like a live child → false D3 (1) → forced interactive against a stranger process.

**Fix:** store pid **plus** process start time (or boot id, or a `pgrep -f` pattern from the recorded launch command) in `session.json` and verify both.

### I-42 NIT — two small robustness/diagram gaps

- (a) §4.2 step 3 (line 166): escalation payload includes "`NEXT_RETRY_PROMPT` from `result.md`" — absent when the miss is a hard crash (no `result.md`/STATUS block). Say "when present".
- (b) Mermaid lines 103/122–123: `pass -->|no and auto NI| esc{Auto-selected NI?}` has only a `yes` edge; the node's question is already answered by the incoming edge label, leaving a dead-end node. Drop `esc` or add its `no` branch to `done`.

## Non-issues

- Core model re-verified sound: dual modes, auto default, pin-wins-over-D3, exactly one NI→interactive escalate, no silent IX→NI on pin/D4, honest `mode-unavailable`, NI = `mode.json` only (no events/fifo), redaction parity for `events.jsonl`, wave-scoped limits, AF field parity, implementation deferred.
- I-18/I-20/I-21 and I-25..I-31 landed text is correct as written (verified above); not re-filed.
- D4-on-auth/quota misses, escalate cost, fifo deadlock watchdog, secret handling — already bounded by landed text/§11.
- Sparse-HEAD §1/§7/§10 file references — B1 rejected at rung-1 triage; informational only.
- M-A3 auth/log-floor enumeration — DEFER at rung-1 triage; not re-raised.

## Summary counts

| Severity | New |
|----------|-----|
| MEDIUM   | 1 (I-32) |
| MINOR    | 6 (I-33..I-38) |
| NIT      | 4 (I-39..I-42) |

## Gate

**advance.** I-32 is a genuine contract gap — D3-mandatory interactive can be silently downgraded to a context-losing NI with an orphaned live child, deviating from §2's "required" language and the I-7 triage's "unless pin/mandatory" carve-out — and needs a fix rung. I-33/I-34 tighten the wave-budget/persistence cluster I-29/I-30 opened; I-35–I-38 are schema/vocabulary/attribution tightening; I-39–I-42 are surface nits. Nothing restructures the mode model.
