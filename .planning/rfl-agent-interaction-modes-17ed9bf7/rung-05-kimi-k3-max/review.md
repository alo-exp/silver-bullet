# Rung 5 review — Kimi K3 Max (OpenCode)
Plan: .cursor/plans/agent_interaction_modes_17ed9bf7.plan.md
SHA256: d62a05d38cefd51892cba1d95e6043c6a51e37abf18dc62a9399efe6798ebe16
METHOD: native opencode run -m opencode-go/kimi-k3 --variant max
STATUS: review-complete

**Method:** SHA256 verified via `shasum -a 256` before review (matches the locked `d62a05d3…`). Full plan read from disk, verbatim with line numbers (411 newline-terminated lines). `graphify query "agent interaction modes D3 D4 D6 mode.json session.json escalate I-48 I-49 I-50"` run first: 5344-node graph, 232-node BFS result — confirms the RFL artifact cluster (plan node, CHARTER/LEDGER, rung-3/rung-4 review ISSUES nodes incl. I-38/I-39, closeout memory); nothing outside the cluster bears on the spec. Charter V1–V10 greps re-run with `grep -cE` against the current text. I-11 live-script evidence re-verified read-only via `git show main:scripts/agent-opencode-delegate.sh` (this shell sits on a detached HEAD at `1569b060` memory auto-snapshot where `scripts/` is not materialized; the plan and `.planning/rfl-…/` trees are untracked, so their bytes are checkout-independent). No plan edits. No commits. No subagents. No Fast. No Grok/MiniMax/MiMo remap.

## Prior I-1..I-55

**Landed and verified in current text (do not re-file):**

- **I-48 — landed.** Line 142 predicate now requires `escalate-unavailable` ∉ `reason[]` ∧ `escalated` ∉ `reason[]`; line 168 appends `escalate-unavailable` with "**do not loop** and do not start a later D4 on this task-id while that token remains (I-48)"; line 361 "That `reason[]` token durably clears the §4.1 pending-escalate predicate (I-48)"; line 378 test fixture present. The cross-invoke re-arm loop is closed.
- **I-49 — landed.** Line 135 "Classifier does **not** read `events.jsonl` (interactive-only; I-49)"; line 142 "Do **not** consult `events.jsonl` (I-49)" with the marker moved to `mode.json` `reason[]` (line 167); line 378 fixture.
- **I-50 — landed.** Line 139 "**In-wave (disk, D3 (2) Cursor):** `conversation_id` is set ∧ `status=live` — no continue utterance required (I-50)" plus terminal-`result.md`-vs-`wave_started_at` ordering; line 146 reset = `status=dead` + keep `conversation_id`, next invoke classifies fresh; line 378 fixture.
- **I-51 — landed.** Line 183 "NI ignores `--max-wall-sec` … `--idle-sec` on NI feeds the D7 tail-idle watcher (I-51)"; lines 275–276 carry the same semantics on the CLI flags.
- **I-52 — landed.** Line 139 enumerates `status` `live` | `dead`; line 203 NI writes `{status:dead, conversation_id, updated_at}` / omits the file when no id; line 314 `status=live|dead (I-52)`.
- **I-53 — landed.** Line 361 retry-cannot-start is `(`mode-unavailable`)` only; "`tui-unavailable` is the auto-classifier path only, never a D4 retry-cannot-start cause (I-45/I-53)".
- **I-54 — landed (content).** Line 76 cites "(I-33; supersedes I-29)"; the `I-54` tag string is absent as the brief anticipated.
- **I-55 — landed.** Line 274 `env SB_AGENT_MAX_TURNS (CLI wins when present) (I-55)`; line 283 env list; line 348 AF precedence `--max-turns` / `SB_AGENT_MAX_TURNS` / field.
- **I-43..I-47 — re-verified landed:** line 348 + line 410 (AF `max_wall_sec`/`idle_sec`, parent override wins); lines 142/163/200 (incomplete → `fail` + `incomplete`/`result-missing`, no fourth STATUS); lines 125/129 (`retry --> tui`, `tui-unavailable` never D4); lines 81/194/340 (Pi `--provider opencode-go --model mimo-v2.5` native); lines 298/348/378 (`fallback-not-pinned`).
- **I-1..I-42 — no regressions** on load-bearing lines (D1 line 73, D2 line 74, D3 line 75, D4 line 76, D5 line 77, D6 line 78, D8 line 87, D9 line 88, conflict rows 293–303, events line 324, §12 lines 394–410). Rung-1 triage dispositions not re-litigated.

**Still wrong vs current text (open; IDs retained per brief):**

- **I-32 (rung-4 r1/r2/r3) — partially landed; the silent-NI paths for D3-mandatory interactive remain.** Line 78 (D6) now carries the carve-out sentence: "**D3 live-session (resolver step before classifier) is mandatory interactive:** TUI/session-id miss → `mode-unavailable`, not silent NI (I-32)" — but the same line's opening still lumps "classifier/D3 picking interactive" into the NI-`tui-unavailable` group, and the carve-out never propagated: (b) line 129 "Auto + TUI unavailable (classifier/auto, **not** D4) falls through to NI" still omits D3 from the fail-closed side; (c) mermaid line 117 `tui -->|no and auto and not D4| ni` still NIs D3-forced entries arriving via lines 110/112 — no D3 branch exists in the diagram; (d) §7 line 338 (Cursor) and line 340 (Pi) "auto → NI `reason=tui-unavailable`" have no D3 carve-out — an in-wave Cursor follow-up (defined on disk by I-50 at line 139) whose session id cannot be reused silently starts a fresh NI, splitting the open wave D3 (2) exists to protect.
- **I-32-r4 — open.** Line 139: "TTL (default **24h** from `updated_at`) applies to (1)(2). Stale/expired `session.json` does not force interactive." A >24h record with a verifiably alive, identity-matched child still has no precedence rule → fresh classify → possible NI while the child runs (G3).
- **I-33-partial — (a) resolved by I-51 (line 183); (b) open.** Wall exhaustion still has no `failure_class`: line 362 catalog is `mode-unavailable` | `mode-conflict` | `max-turns` | `escalate-unavailable` | `hook-trust`. Whether a wall-killed wave counts as "terminal" for the line-139/146 `status=dead` reset is likewise unstated.
- **I-34 — open.** Line 243: "Persist `{turns, wave_started_at}` on `session.json` / `mode.json`", but every `mode.json` schema statement (lines 159, 201, 312, 358) remains `{requested, classified, resolved, reason[]}`.
- **I-35 — open.** Line 389 "allowed wrappers are preflight/quota/tail-idle only" still contradicts line 82's six allowed NI wrappers (adds secret scan, log header, optional read-only `monitor.sh`).
- **I-36 — open.** `reason[]` vocabulary still unenumerated while normative logic keys off tokens: `tui-unavailable` (78, 129, 338, 340), `escalate-unavailable` (168, 361), `escalated` (167, 361), `incomplete` / `result-missing` (163, 200).
- **I-37 — open, and now load-bearing against the I-32 split.** Line 75 (D3 body) still lists "multi-checkpoint coaching; likely clarifiers/pickers; … any case where a fresh one-shot would lose an **already-open** tool/context/thread" beyond the (1)(2) split. The same "likely clarifiers/pickers" signal is also §4.1 line 141's classifier force-interactive — which line 78's trailing clause ("Classifier-picked interactive without a live session may still NI `tui-unavailable`") makes fallible. One signal, two different TUI-miss consequences (mandatory `mode-unavailable` vs silent NI), chosen by which paragraph the reader applies.
- **I-38 — open, compounded by the I-48 landing.** Lines 167/361 have the D4 retry appending `escalated` to "the NI `mode.json` `reason[]` (durable; classifier-visible)", but the retry runs under the same per-task-id `mode.json` path (line 312) and line 159 says "Record the decision in `mode.json` … (both modes)" — whether the retry overwrites the NI record (destroying the `escalated` token and the NI resolution it annotates) or the NI record is retained alongside is still undefined; §9 line 358 scoring does not say which record a D4 wave presents.
- **I-40 — open.** D9 line 88 (`resolve_mode, classify_task, start, send, snapshot, wait_event, stop`) vs §6.3 line 322 / line 330 ctl.sh (`send|key|snapshot|status|abort`): `key`/`status` absent from D9, `stop` ≠ `abort`, `wait_event` has no §6.3 surface.
- **I-11 — open.** Re-verified read-only on `main`: `scripts/agent-opencode-delegate.sh` still exposes `--delegation-mode default|multi-ai-worker-v1|multi-ai-pool-v1` (lines 18/51/85/138); the spec never mentions the flag or its orthogonality to `--interaction-mode`. (This shell's detached-HEAD tree does not materialize `scripts/`; evidence taken from `git show main:`.)

## ISSUES (new only, I-56+)

### I-56 LOW — `mode_fallback` audit record has no defined sink when the fallback resolves to NI

§6.2 line 277: "`--allow-mode-fallback` # **pinned interactive only** → NI if TUI missing; one hop; audit `mode_fallback` {from,to,reason,flag}." The fallback target is NI, and §5.1 line 201 makes `mode.json` "the only `mode_resolved` record in NI; **no** `events.jsonl`" — but every `mode.json` schema statement (lines 159, 201, 312, 358) is `{requested, classified, resolved, reason[]}` with no `from`/`to`/`flag` field and no `mode_fallback` `reason[]` token defined, and §9 line 358's PASS/FAIL bar does not require the record. The mandated audit has nowhere to go; implementers will invent divergent sinks. Fix: define `mode_fallback` as a `mode.json` `reason[]` token (e.g. `mode_fallback:interactive→non-interactive:<cause>`) or an optional field, and add it to §9 scoring.

### I-57 LOW — `SB_AGENT_ALLOW_MODE_FALLBACK=1` env form escapes the pin-only constraint

Line 283 lists `SB_AGENT_ALLOW_MODE_FALLBACK=1` in the env block with no constraint sentence; the pin-only rule exists only for the CLI flag (line 298: "`--allow-mode-fallback` is invalid outside pinned interactive (fail `mode-conflict` `fallback-not-pinned`)") and the AF field (line 348). Env-set fallback with requested `auto` or pinned NI argv is unspecified — fail `fallback-not-pinned`, or ignore? This is the same coverage class I-21 closed for `SB_AGENT_INTERACTION_MODE`; the fallback env var was left behind. Fix: one clause in line 283 (or extend line 298) giving the env form the same `fallback-not-pinned` behavior as the flag.

### I-58 NIT — NI-written `session.json` record shape is narrower than the line-139 schema with no partial-record statement

Line 139 declares `session.json` stores `{status, conversation_id, pid?, updated_at, turns, wave_started_at}`; line 203's NI write is `{status:dead, conversation_id, updated_at}` — no `turns`, no `wave_started_at`. Line 139's "(or `wave_started_at` is absent)" tolerates the omission for the case-(3) recency test, but nothing states that NI records are partial / that `turns` and `wave_started_at` are interactive-only fields. A schema-validating consumer (or the line-243 wave-counter persistence) reading an NI-written token hits undeclared shape. Fix: mark `turns`/`wave_started_at` optional or interactive-only in line 139.

### I-59 NIT — mermaid `tui` gate has no `--allow-mode-fallback` edge

Lines 116–118: `tui -->|yes| ix`; `tui -->|no and auto and not D4| ni`; `tui -->|no and pin or D4| done`. Pinned interactive + TUI unavailable + `--allow-mode-fallback` resolves NI per line 277 and D6 line 78 ("unless `--allow-mode-fallback` is set (audited)"), but the diagram's only pin-miss edge goes to `done` (fail-closed). One more edge (`no and pin and fallback → ni`) or a footnote keeps the diagram from contradicting the flag it documents two sections later.

## Charter V1–V10

Re-run on `d62a05d3…` (`grep -cE` per CHARTER.md patterns):

| ID | Signal | Matching lines | Status |
|----|--------|----------------|--------|
| V1 | dual modes named | 99 | PASS |
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

**advance** — the I-48..I-55 cluster landed cleanly and is internally consistent: the pending-escalate predicate is now fully classifier-visible from declared inputs (I-48/I-49), in-wave Cursor has a disk predicate and the reset keeps the resume-token (I-50/I-52), and the NI limit semantics (I-51/I-55) closed the flag surface. Recommend a fix rung for: the still-open **I-32 mermaid/line-129/§7 D3 carve-out** (the only remaining place the spec can silently NI a mandatory-interactive session), plus the new low-severity cluster **I-56/I-57** (fallback audit sink + env-form constraint, both one-sentence fixes) and NITs **I-58/I-59**. Residuals I-32-r4, I-33-partial(b), I-34..I-38, I-40, I-11 remain open per the prior table. The core model — dual modes, pin > D3, one D4 hop with durable terminal tokens, NI isolation, honest unavailability, AF field parity, deferred implementation — remains sound; nothing restructures it.

No plan edits made by this rung. No commits. (Shell sits on a detached HEAD at `1569b060`; not moved — no git mutations performed.)
