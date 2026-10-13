# Rung 4 review — GLM 5.3 Max (OpenCode)
Plan: .cursor/plans/agent_interaction_modes_17ed9bf7.plan.md
SHA256: 0716b40e1992c3bf7548b3ef0b4b8a78b034f913484b2c30bf2f731edc3c078d
METHOD: native opencode run -m opencode-go/glm-5.3 --variant max
STATUS: review-complete

**Method:** full plan read from disk, verbatim with line numbers (410 newline-terminated lines; SHA verified via `shasum -a 256` before review). `graphify query "agent interaction modes D3 D4 D6 mode.json session.json escalate"` run first (177-node BFS subgraph; confirms the RFL artifact cluster — plan, CHARTER, LEDGER, rung-1..4 reviews, rung-7 review — nothing outside it bears on the spec). Rung 1–3 reviews, prior rung-4 session (`rung-04-glm-53-max/`, I-32..I-42), rung-7 Grok review (I-43..I-47), rung-8 (blocked, nothing filed), and this rung's blocked stub reconciled against the current text. Charter greps V1–V10 re-run with `rg`. Live-file spot checks: `scripts/agent-opencode-delegate.sh`, `scripts/agent-pi-delegate.sh`. No plan edits. No commit. On `main`. No subagents. No Fast. No Grok remap.

**Numbering note:** rung-3 and the prior rung-4 session each filed an I-32..I-40 band (IDs collide). Below, "rung-3 I-3x" vs "rung-4 I-3x" disambiguates; the plan's inline tags `(I-32)`/`(I-33)` refer to the rung-4 (prior session) items. Highest filed ID is I-47 (rung 7); new issues start at I-48.

## Prior I-1..I-47

**Landed and verified in current text (do not re-file):**

- **Rung-3 I-32..I-40 — all landed:** concrete-pin wording (§12 line 396); classifier inputs include `result.md`/`escalation.md` + disk predicate (§4.1 lines 135/142 — but see new I-49); fork-safe `session.json` delete / `status=dead` keeps the resume-token (line 139); `--auto-policy` + `--allow-mode-fallback` in conflict rows (§6.2.1 lines 297–298); `--max-wall-sec`/`--idle-sec` on §6.1 (line 256), §6.2 (lines 275–276), env (line 283), AF (§8 line 348); pid start-time/identity check + orphan abort/reset (line 139); auth + 2048 B log floor on all five hosts (§7 lines 336–340); `--no-escalate` scoped to in-flight escalate (line 148, §12 line 406); mermaid `esc -->|no| done` (line 124).
- **Rung-4 (prior session) I-41/I-42 — landed:** start-time identity defeats pid reuse (line 139); `esc` no-edge (line 124). I-42(a) is largely resolved by the I-44 synthesis (line 163: a missing `result.md` is synthesized `fail` + `result-missing` before D4), though a synthesized `result.md` carries no `NEXT_RETRY_PROMPT` field — line 167 should still say "when present".
- **Rung-7 I-43..I-47 — all landed:** §8 directive carries `max_wall_sec`/`idle_sec` with parent-override-wins (line 348; §12 line 410); parent-scored incomplete normalized to STATUS `fail` + `reason[]` `incomplete`/`result-missing` before the predicate and D4 (lines 142, 163, 200; §10 line 378 fixture); mermaid `retry --> tui` + "D4 retry re-enters the resolver `tui` gate … `reason=tui-unavailable` … never D4" (lines 125, 129); Pi NI argv includes `--provider opencode-go --model mimo-v2.5` as part of the native one-shot, not a wrapper (D7 line 81, §5.1 line 194, §7 line 340 — matches live `scripts/agent-pi-delegate.sh`: "Model policy: `--provider opencode-go --model mimo-v2.5` always"); AF `allow_mode_fallback` valid only with concrete `interaction_mode=interactive`, else `fallback-not-pinned` (§8 line 348, §6.2.1 line 298, §10 line 378 fixture).
- **I-1..I-31** — spot re-verified where load-bearing (D1 line 73, D2 line 74, D8 line 87, §6.2.1 rows 293–303, §6.3 events line 324); no regressions found. Rung-1 triage dispositions (B1 reject, M-A3 defer) not re-litigated.

**Still wrong in current text (open; not renumbered):**

- **I-32-r1/r2/r3 (rung-4) — D3-mandatory interactive can still be silently NI'd.** (a) Line 78 self-contradicts: "**Auto** (including classifier/D3 picking interactive) + TUI/session unavailable: do **not** fail-closed — launch NI with `reason=tui-unavailable` (Pi/Cursor)" vs the same line's trailing "**D3 live-session (resolver step before classifier) is mandatory interactive:** TUI/session-id miss → `mode-unavailable`, not silent NI (I-32)". (b) Line 129: "Auto + TUI unavailable (classifier/auto, **not** D4) falls through to NI" — omits D3; a D3-forced interactive is auto-*requested*, so this sentence routes it to NI. (c) Mermaid line 117 `tui -->|no and auto and not D4| ni`: D3 enters `tui` via lines 110/112 and is then NI'd — no D3 branch. (d) §7 line 338 (Cursor) and line 340 (Pi): "auto → NI `reason=tui-unavailable`" with no D3 carve-out — an in-wave Cursor follow-up whose session id cannot be reused silently starts a fresh NI, discarding the open thread D3 (2) exists to protect. This is the brief's explicit re-file example; the mermaid/prose still silently NIs a D3-mandatory TUI miss.
- **I-32-r4 (rung-4) — TTL-vs-live-pid precedence undefined.** Line 139: "TTL (default **24h** from `updated_at`) applies to (1)(2). Stale/expired `session.json` does not force interactive." A >24h-old record with a verifiably-alive, identity-matched child is ignored → fresh classify → possible NI while the child still runs (G3).
- **I-33-partial (rung-4)** — the new-wave reset landed (line 76), but (a) the NI leg's wall participation is still undefined (`--max-wall-sec` has no §5.1 semantics; see new I-51), and (b) wall exhaustion still has no `failure_class` (§9 line 362 catalog: `mode-unavailable | mode-conflict | max-turns | escalate-unavailable | hook-trust`).
- **I-34 (rung-4)** — line 243: "Persist `{turns, wave_started_at}` on `session.json` / `mode.json`", but every `mode.json` schema statement (lines 159, 201, 312, 358) is `{requested, classified, resolved, reason[]}` — no wave fields.
- **I-35 (rung-4)** — §11 line 389 "allowed wrappers are preflight/quota/tail-idle only" contradicts D7 line 82's six wrappers (adds secret scan, log header, optional read-only `monitor.sh`).
- **I-36 (rung-4)** — `reason[]` vocabulary still unenumerated while D6 (line 78 `tui-unavailable`), §9 (line 361 `escalate-unavailable`), and §4.2 step 2 (line 166, D4-not-D3 attribution) key off codes.
- **I-37 (rung-4)** — D3 body (line 75) still appends "multi-checkpoint coaching; likely clarifiers/pickers; … any case where a fresh one-shot would lose an already-open tool/context/thread" beyond the (1)(2) liveness split that D1 (line 73) and §4.1 (line 139) use.
- **I-38 (rung-4)** — one `mode.json`, two resolutions across a D4 escalate still undefined (does the retry overwrite the NI record?); pending-escalate persistence leans on an `escalated` event the NI phase never writes. Compounded by new I-48/I-49.
- **I-40 (rung-4)** — D9 line 88 (`resolve_mode, classify_task, start, send, snapshot, wait_event, stop`) vs §6.3 ops (line 322) / ctl.sh (line 330) (`send|key|snapshot|status|abort`): `key`/`status` missing from D9, `stop` ≠ `abort`, `wait_event` has no §6.3 surface.
- **I-11 (rung-1)** — live `scripts/agent-opencode-delegate.sh` still exposes `--delegation-mode default|multi-ai-worker-v1|multi-ai-pool-v1` (lines 18/51/85/138); the spec never mentions the flag or its orthogonality to `--interaction-mode`.

## ISSUES (new only, I-48+)

### I-48 MEDIUM — escalate-unavailable never clears the pending-escalate predicate: cross-invoke D4 re-arm loop contradicts "do not loop"

§4.1 line 142: pending escalate ⇔ `mode.json` `requested=auto` ∧ `resolved=non-interactive` ∧ `result.md` STATUS `fail|blocked` ∧ `escalation.md` present ∧ "no `escalated` event yet". §4.2 step 4 (line 168): "If interactive is `mode-unavailable`, keep original NI FAIL; **do not loop**." §9 line 361: when the retry cannot start, record `escalate-unavailable` on NI `mode.json` `reason[]` and keep the original FAIL — i.e. **no `escalated` event is ever written** (events.jsonl is interactive-only and the retry never started) and NI's `mode.json` keeps `{requested:auto, resolved:non-interactive}`. Every subsequent auto invoke on this task-id re-satisfies the predicate → force-interactive (§4.2 step 2) → a **second** D4 attempt → if still unavailable, again. The one-retry budget (D4 line 76 "one interactive retry"; §2 line 69 "at most one auto-escalation") has no durable terminal marker for the could-not-start case; `--no-escalate` is the only unstick. Fix: on retry-cannot-start, durably clear/mark the pending state (e.g. the predicate also requires `escalate-unavailable` ∉ prior `mode.json` `reason[]`, or truncate/rename `escalation.md`).

### I-49 MEDIUM — the §4.1 predicate's final clause reads `events.jsonl`, which is not a declared classifier input

Line 135 input list: brief text, optional user utterance, `task-id`, `session.json` if present, `mode.json` if present, `result.md` if present, `escalation.md` presence — **no `events.jsonl`**. Line 142 requires "no `escalated` event yet", and the only defined home of `escalated` is "that retry's `events.jsonl`" (§9 line 361; §6.3 line 324 event list). Same input-coverage class as rung-3 I-33, whose fix added `result.md`/`escalation.md` but omitted the very store the new clause reads. A unit-testable classifier (§10 step 3, line 370) cannot evaluate the clause from the declared inputs; implementers will either skip the clause or read undeclared state. Fix: add `events.jsonl` (`escalated` presence) to the §4.1 input list — or move the marker onto a NI-visible store (`mode.json` `reason[]`), which also relieves I-38.

### I-50 MEDIUM — "in-wave Cursor follow-up" (D3 (2)) has no disk predicate, and prior-wave "reset" has no defined disk operation

Lines 53/73/75/97/131/139 make "in-wave Cursor follow-up" a normative D3 (2) trigger, but nothing defines *in-wave* on disk. Between Cursor follow-ups no child process is alive (session transport, line 239: a follow-up "is a **new process**"), so case (1) cannot fire; the discriminator must be wave state. But: (a) `session.json.status` values are never enumerated — only `dead` is ever named (line 139); nothing defines what a Cursor wave writes at start (no pid to make live). (b) Prior-wave reset (line 146: a completed wave "**resets** the task-id") is defined on disk only as `status=dead` — `result.md` from wave N−1 keeps its terminal STATUS into wave N. (c) Case (3) (line 139) tests "reusable id + **terminal** `result.md` and no continue utterance → resume-token only". Consequence: a mid-wave Cursor follow-up without an explicit continue utterance sees a stale terminal `result.md` + `status=dead` → classified (3) → fresh NI on a **new** conversation, splitting the open wave — the exact failure mode rung-3 I-34 fixed for the delete-fork, now reachable via stale wave state. §10 fixtures (line 378) include no in-wave-Cursor classifier fixture. Fix: define in-wave ⇔ `session.json` has `conversation_id` ∧ current wave non-terminal (e.g. `status=live` written at any interactive start including Cursor session transport; terminal `result.md` counts only if newer than `wave_started_at`), and specify what reset clears.

### I-51 LOW — `--max-wall-sec` / `--idle-sec` have no NI semantics

§6.2 lines 275–276 carry no interactive-only marker (contrast `--max-turns N # interactive only`, line 274), and §6.2.1's NI-pin row (line 297) does not list them as conflicts — so they are legal on pinned-NI argv — but §5.2 lines 244–245 define them only under *Interactive* hard limits, and §5.1 NI (line 183) is "block on exit" with no wall cap. With D4's new-wave reset (line 76) the NI leg cannot consume the retry's wall, so the flag is either inert on NI or caps the NI exec — undefined. `--idle-sec` similarly has no stated relationship to the NI tail-idle wrapper (D7 line 82). Fix: one sentence in §5.1/§6.2 (NI ignores `--max-wall-sec`; `--idle-sec` feeds tail-idle) — or mark both interactive-only and add them to line 297's conflict row.

### I-52 LOW — `session.json` `status` field has no enumerated values

Line 139 schema `{status, conversation_id, pid?, updated_at, turns, wave_started_at}`; the only value any text assigns is `status=dead` (line 139). No value for a live interactive child, none for the NI-written record (line 203), and "usually empty in NI" is ambiguous between an empty file and absence. Liveness is checked via pid/identity, so `status` is otherwise unassertable in tests — and I-50's in-wave predicate needs a live value. Fix: enumerate (e.g. `live` while the recorded child/session is open, `dead` on terminal reset) and state what NI writes (skip the file when there is no conversation id).

### I-53 NIT — §9 lists `tui-unavailable` as a retry-cannot-start cause, contradicting I-45's own landing

Line 361: "If retry cannot start (`mode-unavailable` / `tui-unavailable`), record `escalate-unavailable`…" vs line 129: "`reason=tui-unavailable` is the auto-classifier path only, **never D4** (I-45)". Per D6 (line 78) and line 129, a D4 TUI miss is `mode-unavailable`/`escalate-unavailable`; the parenthetical's second alternative can never occur. Fix: drop "` / tui-unavailable`".

### I-54 NIT — line 76's "(I-29/I-33)" tag misattributes the new-wave reset

"D4 retry **starts a new wave** (reset `wave_started_at` and turn count) … (I-29/I-33)" — but I-29's landed requirement (rung-3 verify_1/verify_2, both HOLDS) was that the retry **inherits** the wave; the reset is rung-4 I-33's remedy. The plan's inline issue tags are its audit trail; a tag pointing at the opposite requirement misleads the next rung. Fix: cite "(I-33; supersedes I-29)".

### I-55 NIT — `--max-turns` is the only interactive limit without an env counterpart

§6.2 env list (line 283) names `SB_AGENT_MAX_WALL_SEC`, `SB_AGENT_IDLE_SEC` (rung-3 I-36 landing) but no `SB_AGENT_MAX_TURNS`, while `--max-turns` (line 274) and the AF seed's `max_turns` (line 283) both exist. The asymmetry is undocumented. Fix: add `SB_AGENT_MAX_TURNS` or state turns is argv/AF-only.

## Charter V1–V10

Re-run on `0716b40e…` (`rg -n` per CHARTER.md commands):

| ID | Signal | Matching lines | Status |
|----|--------|----------------|--------|
| V1 | dual modes named | 95 | PASS |
| V2 | auto default / pin wins / `--mode` | 22 | PASS |
| V3 | session continuity → interactive | 7 | PASS |
| V4 | NI→interactive escalation | 6 | PASS |
| V5 | D7 least overhead | 9 | PASS |
| V6 | five hosts | 50 | PASS |
| V7 | control dir interactive-only | 1 | PASS |
| V8 | events `mode_resolved` | 6 | PASS |
| V9 | no silent IX→NI / `mode-unavailable` | 11 | PASS |
| V10 | implementation deferred | 2 | PASS |

All ten PASS.

## Gate

**advance** — with a fix rung recommended for the new cluster **I-48/I-49/I-50** (all local: one terminal-state clause on the escalate predicate, one input-list line, one in-wave/reset definition) plus the still-open **I-32 mermaid/D6/§7 D3 carve-out**. The core model — dual modes, pin > D3, one D4 hop, NI isolation (no PTY/fifo/events), honest unavailability, AF field parity, deferred implementation — remains sound and internally consistent; nothing restructures it. I-51/I-52 are LOW schema tightenings; I-53–I-55 are NITs; rung-4 residuals I-33-partial/I-34..I-40 and I-11 remain open nits per the prior table.

No plan edits made by this rung. No commits. Stayed on `main`.
