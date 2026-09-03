# Rung 3 review — Qwen3.8 XHigh (OpenCode)

**Plan:** [agent_interaction_modes_17ed9bf7.plan.md](/Users/shafqat/projects/silver-bullet/repo/.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md)

**Method:** Qwen3.8 XHigh via opencode CLI, non-interactive (direct spec review; no TUI harness). Full plan read from disk (407 lines, verbatim, two passes). Charter V1–V10 re-run with `rg`. Rung-01/rung-02 reviews and this rung's prior draft (`review.prior-stale.md`, `verify_1.md`, `verify_2.md`) reconciled against the current text.

**STATUS:** review-complete

**Plan SHA256 (as read):** `1c25c33cd16f957a8752dafd30a290e10e36e070a8db51c96889b85aae2f3e09`

Byte-identical to the SHA verified by this rung's two earlier verify passes; the plan has not mutated since I-25..I-31 were confirmed fixed.

## Rung-2 fixes + prior-draft items checked (do not re-file)

Verified against the current text, line numbers from the current plan:

| ID | Current text | Verdict |
|----|--------------|---------|
| I-18 | D1 (line 70) resolver is pin > process-alive-or-continue/coach > classifier > NI; mermaid (lines 95–125) has split `live`/`tok` nodes; D3 (line 75) live session = §4.1 (1)/(2) only | fixed, matches |
| I-20 | D8 (line 87) + §6.2.1 row (line 295): `--attach` on auto is not a pin, classifier runs, classified NI → `attach-on-ni` / `control-dir-on-ni` | fixed, matches |
| I-21 | D2 (line 74) + §6.2 env paragraph + §6.2.1 row (line 296): inherited concrete `SB_AGENT_INTERACTION_MODE` fails `mode-conflict` (`leftover-env-pin`); unset when argv pin present | fixed, matches |
| I-25 | D6 (line 78) + §6.2 (line 274): fallback pin-only, one hop, `mode_fallback {from,to,reason,flag}`, not valid on D4; §9 keeps `escalate-unavailable` | fixed |
| I-26 | §6.3 (line 321) closed event list carries `clarify` / `zero_tokens`; §5.2 step 5 (line 233) uses `zero_tokens` | fixed |
| I-27 | `mode.json {requested, classified, resolved, reason[]}` uniform (lines 158/200/309/355); `classified` null when pinned | fixed |
| I-28 | §4.2 step 3 (line 166): `escalation.md` is the only prior-result artifact; carries log tail, remaining criteria, `NEXT_RETRY_PROMPT` from `result.md`; `prior_result.md` explicitly prohibited | fixed |
| I-29 | D4 (line 76): retry inherits the wave `{turns, wave_started_at}`; §5.2 (line 243) wall is wave-scoped | fixed |
| I-30 | §4.1 (line 138): `session.json {status, conversation_id, pid?, updated_at, turns, wave_started_at}`; alive = `pid` set + `kill -0` | fixed |
| I-31 | §6.3 (line 327): `ctl.sh send\|key\|snapshot\|status\|abort`; §4.2 step 2 (line 165) attributes escalate to D4, not D3 | fixed |

None re-opened. Rung-1 I-1..I-17 and B1 (rejected) not re-litigated.

## ISSUES (new)

### I-32 MEDIUM — §12 "Explicit `--interaction-mode` skips classify" contradicts explicit `auto`

Line 393: "Explicit `--interaction-mode` skips classify and skips escalate, and wins over D3."

This is now wrong for the `auto` value, and contradicts three current passages:

- D2 (line 74): "Value `auto` is requested-auto (**not** a concrete pin)."
- D1 (line 70): only `interactive|non-interactive` (or alias / legacy pin) skips classify.
- §12's own line 401: "`--interaction-mode auto --attach` does not skip the classifier" (I-20).

`--interaction-mode auto` **is** an explicit `--interaction-mode`, so §12 lines 393 and 401 cannot both hold. A test written from line 393 asserts the opposite of the I-20 fixture. Post-I-20 residue: the acceptance row was never narrowed to concrete pins.

**Fix:** line 393 → "Explicit **concrete** `--interaction-mode interactive|non-interactive` (or pin alias / legacy pin) skips classify and skips escalate, and wins over D3; explicit `auto` is requested-auto (classifier runs)."

### I-33 MEDIUM — §4.1 classifier inputs cannot detect the in-flight-escalate state it normatively requires

§4.1 input list (line 134): brief text, optional user utterance, `task-id`, `session.json`, `mode.json`. Two rules need state that none of those inputs carries:

- Force-interactive bullet (line 141): "a §4.2 retry for this `task-id` is pending (failed auto-NI about to escalate)."
- Prior-wave reset exception (line 145): completed wave resets "**with no pending escalate**" — and the reset itself keys on terminal `result.md` STATUS, which is also not an input.

At retry-classify time, `mode.json` holds the NI phase's `{requested:auto, resolved:non-interactive}` — indistinguishable from a plain finished NI run. The FAIL state lives in `result.md` (STATUS `fail|blocked`) and the pending marker is `escalation.md` (§4.2 step 1 writes it before step 2 resolves) — neither is in the input list. §10 step 3 wants a unit-testable classifier; fixtures have no defined disk predicate for "pending escalate."

**Fix:** add `result.md` (terminal STATUS) and `escalation.md` presence to §4.1 inputs, and define: pending escalate ⇔ prior `mode.json` `requested=auto ∧ resolved=non-interactive` ∧ `result.md` STATUS `fail|blocked` ∧ `escalation.md` present ∧ no `escalated` event yet.

### I-34 MEDIUM — §4.1 "(or delete `session.json`)" fork destroys the resume-token that D3 (2) needs

Line 138: "PASS/terminal reset **must** set `status=dead` (or delete `session.json`)". The two allowed behaviors have different observable outcomes:

- D3 (2) (line 75) and §4.1 case (2) force interactive on "reusable conversation id + explicit continue/coach utterance or in-wave Cursor follow-up" — no origin restriction on the id; §5.1 (line 202) explicitly has NI write `session.json` when the one-shot returns a reusable id (Cursor stream-json does).
- If the terminal reset **deleted** `session.json`, a later "continue this work" loses the token: on `tui` hosts the utterance bullet (line 139) still forces interactive but into a **cold** session (the child brain D3 exists to keep is gone); for an **in-wave Cursor follow-up** (no continue utterance in the brief by construction) nothing fires — `tok` → no → classifier → likely NI, splitting a live wave mid-wave.

If the reset sets `status=dead` instead, both continuations work. The "(or delete)" option licenses breaking a normative force-interactive rule.

**Fix:** when a reusable `conversation_id` exists, mandate `status=dead` (token preserved); deletion allowed only when there is no reusable id.

### I-35 LOW — §6.2.1 interactive-only conflict rows omit `--auto-policy` and `--allow-mode-fallback`

§6.2 marks `--allow-mode-fallback` "pinned interactive only" (line 274) and `--auto-policy` "interactive only" (line 275), but the NI-pin conflict row (line 294) enumerates only `--attach` / `--control-dir` / `--max-turns`, and the auto row (line 295) likewise. Behavior of `--auto-policy` / `--allow-mode-fallback` on pinned NI or on auto is undefined (fail-closed vs silently ignore) — the table claims to enumerate what "fails closed." (Adjacent to rung-1 I-31d/R-9, but scoped to §6.2.1 completeness, not the §6.1 synopsis.)

**Fix:** extend row (line 294) with both flags; state auto behavior (`--auto-policy` binds if interactive is selected; `--allow-mode-fallback` invalid outside pinned interactive).

### I-36 LOW — `--max-wall-sec` / `--idle-sec` are normative in §5.2 but absent from every surface in §6.1/§6.2

§5.2 Hard limits (lines 243–244) name `--max-wall-sec` (host defaults 900/1800) and `--idle-sec` as flags, but neither appears in the §6.1 slash signature, the §6.2 CLI contract, the §6.2 env list, or the AF seed list — so there is no documented way to set or override them, and the "existing quiet/idle env" §5.2 references is still unnamed (rung-1 m-A4 residual). Either they are user-settable (then add to §6.2 + env + AF) or internal-only (then say so and drop the `--` flag spelling).

### I-37 LOW — D3 (1) process-alive edge: orphaned child has no defined attach path; `kill -0` alone is weak

§4.1 (line 138) defines alive as `pid` set + `kill -0` succeeds. Two edge cases are forks:

- **Orphan:** child alive but original driver/parent gone (new invoke finds the live pid). Attaching presumes the driver + `control/` dir still live; if not, "TUI or session available?" is undefined, and the mermaid fall-through `tui -->|no and auto| ni` spawns a **second, concurrent** NI child on the same task-id while the orphan still runs (git/commit race).
- **Pid reuse / zombie:** `kill -0` succeeds on a reused pid or zombie; no start-time or process-identity check.

**Fix:** define pid-alive-but-no-driver as stale → abort/reset the record, then classify fresh (never spawn alongside a live orphan); verify process start time, not `kill -0` alone.

### I-38 LOW — per-host auth + log-floor values still enumerated for only 2 of 5 hosts (rung-1 M-A3 residual, still unaddressed)

§7 gives auth for Claude (OAuth/Keychain, line 333) and Cursor (Keychain only, line 335) and a log floor only for Cursor (2048 B); Codex/OpenCode/Pi have none. §9 and §12 reference "log floor" generically, so tests cannot assert uniformly. Re-surfaced residual (filed at rung 1 as M-A3, not in the protected I-1..I-17 set, never adopted); informational weight acknowledged since this sparse HEAD lacks the product SKILL.md files where live values live.

**Fix:** pin per-host auth + log-floor values in §7, or explicitly incorporate them by reference to the existing SKILL.md values.

### I-39 NIT — §12 line 403 overgeneralizes `--no-escalate`

"`--no-escalate` does not force-interactive on a reused task-id" — read generally this contradicts §4.1 (line 147), which keeps D3 (1) process-alive and (2) continue/coach in force **even with** `--no-escalate`. Intended fixture is only the in-flight-escalate stick. Reword to "in-flight-escalate force-interactive."

### I-40 NIT — mermaid `esc` node has no `no` edge

Line 123: `esc -->|yes| retry` only; the `--no-escalate` / pinned path out of `esc` is an implicit terminal. Add `esc -->|no| done` for readability. (The missing `--allow-mode-fallback` / legacy-pin branches are rung-1 m-A1 territory — noted, not re-filed.)

## Charter V1–V10 (re-run on current text)

| ID | Matches | Status |
|----|---------|--------|
| V1 dual modes | 93 | PASS |
| V2 auto default / pin wins / --mode | 18 | PASS |
| V3 session continuity | 6 | PASS |
| V4 escalation | 6 | PASS |
| V5 D7 least overhead | 7 | PASS |
| V6 five hosts | 47 | PASS |
| V7 control dir interactive-only | 1 | PASS |
| V8 mode_resolved | 6 | PASS |
| V9 no silent IX→NI / mode-unavailable | 11 | PASS |
| V10 implementation deferred | 2 | PASS |

Informational caveat per charter: this sparse HEAD has **zero** product files (re-verified: all eight §1/§10 reference paths MISSING, 0 SKILL.md anywhere), so adapter-matrix and auth/log-floor claims cannot be checked against product reality here. B1 stays rejected/informational.

## Residuals observed, not re-filed

- Rung-2's carried list: I-9 (classifier signal list not closed), I-10 (loop ownership; §8 "unless `auto_policy` says otherwise" still dangles — no policy hands the loop to the worker), I-11 (`--delegation-mode` / env-vs-AF precedence), I-14 (event payload schemas).
- Prior rung-3 verify passes: R-2 (`clarify`/`zero_tokens` payload schema, optional), R-5 (line 242 names both `session.json` and `mode.json` for the wave counter), I-31d (§6.1 slash synopsis deliberately slimmer than §6.2).
- Rung-1 m-A1 (mermaid lacks legacy/fallback branches) — adjacent to I-40 only.

## Non-issues (checked and consistent in current text)

- D4 wave inheritance + wave-scoped `--max-wall-sec`; one-retry policy; pinned NI never escalates; D4 TUI miss → `escalate-unavailable`, original NI FAIL kept, no second NI.
- Event vocabulary closed: every event in the §5.2 loop appears in §6.3's list (which additionally carries `mode_resolved`, `prompt_submitted`, `escalated`, `error`, `exited`).
- `mode.json` schema uniform across lines 158/200/309/355; NI isolation invariants (no PTY / fifo / `events.jsonl`) consistent across §5.1, §6.3, §9, §12.
- Redaction (I-16): `events.jsonl` `assistant`/`tool_use` use the snapshot pipeline; no raw sibling.
- `failure_class` catalog complete: each of `mode-unavailable | mode-conflict | max-turns | escalate-unavailable | hook-trust` has a defining clause.
- `--mode permissive|strict` orthogonality preserved; permission smash rows present; leftover-env-pin fail + unset semantics coherent with AF seeding.
- Mermaid resolver edges otherwise match D1/D3/D4/D6, including `retry --> pass` with inherited wave.

## Gate

**`fix`** — three MEDIUMs: I-32 (acceptance row contradicts D1/D2 and §12's own I-20 row), I-33 (normative classifier rule has no defined input/marker), I-34 (licensed reset behavior destroys a token that D3 (2) normatively requires). All are small, local text fixes; no structural rework. I-35..I-38 are LOW surface/edge gaps; I-39/I-40 are NITs.

No plan edits made by this rung.
