# Rung 3 review — Qwen3.8 XHigh (OpenCode)

**Plan:** [agent_interaction_modes_17ed9bf7.plan.md](/Users/shafqat/projects/silver-bullet/repo/.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md)

**Method:** interactive OpenCode session, model `opencode-go/qwen3.8-max` (rung label Qwen3.8 XHigh). Direct full-plan read plus grep/sha cross-reference verification of every internal citation (event names, artifact names, schemas, flag scopes). Repo file-existence check for §1/§10 references. No plan edits.

**STATUS:** review-complete

**Plan SHA256:** `4077356bef18e78d276685b09a4c91b5f2f3f859888aa891656bcf0a26a5eff5` — byte-identical to rung-2's post-mutation hash (mtime Aug 24 02:45:09, untracked in git). This review is against the same text rung 2 reviewed; no fix rung has landed since.

## Rung-2 state checked (do not re-file)

- I-19/I-22/I-23/I-24 fixes still present and correct in the current text.
- I-18 (D1/mermaid vs §4.1 liveness split), I-20 (auto+`--attach` fork), I-21 (inherited concrete env pin) — still open exactly as rung 2 described; not re-filed.
- I-9/I-10/I-11/I-14 still open per rung 2's "still open from rung 1" list; not re-filed. (I-30 below is adjacent to I-14 but scoped to `session.json`, which I-14 does not cover.)
- Charter V1–V10 grep signals still pass (plan unchanged).
- Sparse HEAD persists: every §1/§10 file reference is MISSING at this checkout (re-verified). B1 was rejected at rung 1 triage; not re-litigated — informational only.

## ISSUES (new)

### I-25 MEDIUM — `--allow-mode-fallback` scope contradicts D4 / §4.2 / §9 / §12

Two places put D4-mandatory interactive inside the flag's scope:

- D6 (line 78): fail-closed `mode-unavailable` when interactive is "pinned or **mandatory via D4 escalation** and PTY/session is unavailable — **unless `--allow-mode-fallback` is set**".
- §6.2 (line 268): `--allow-mode-fallback  # pin/**D4** interactive → NI if TUI missing; one hop`.

Three places say the opposite, unconditionally:

- D4 (line 76): "If interactive TUI/session is `mode-unavailable`, **stop and report the NI failure**" — no flag exception.
- §4.2 steps 3–4 (lines 159–161): "Start interactive **once** … **Do not spawn a second NI**"; "keep original NI FAIL; do not loop".
- §9 (line 349) and §12 (line 385): retry cannot start → `escalate-unavailable`, keep NI FAIL (the I-19 fix); "exactly one interactive retry (unless `--no-escalate` or TUI unavailable)".

Semantically the flag cannot be honored for D4 anyway: the original NI already ran and missed, so "D4 interactive → NI" means a **second NI run**, which contradicts §4.2 step 3 and the §2 non-goal ("at most one auto-escalation" — a fallback NI is a re-run, and nothing defines what new input it would carry).

**Fix:** pick one — (a) strike "D4" from D6/§6.2 so the flag applies to **pinned interactive only** (D4 stays fail-closed per D4/§9/§12), or (b) explicitly define D4+flag second-NI semantics (input, audit, ping-pong bound) and update §4.2/§9/§12 to match.

### I-26 MINOR — split event vocabulary: `clarify` and `0-token` in §5.2 loop absent from §6.3 event list

§5.2's normative parent loop reacts to event names not in the closed enumeration:

- Line 226: "On `question` / **`clarify`** / `picker` — parent chooses…"
- Line 227: "On `stuck` / **`0-token`** — parent may Enter-wake…"
- §6.3 (line 312) enumerates: `mode_resolved | ready | prompt_submitted | assistant | question | picker | tool_use | idle_working | stuck | auth | quota | escalated | done | error | exited` — no `clarify`, no `0-token`.

An implementer either emits two undocumented events or silently drops both loop branches — one of which (`clarify`) is the core value of interactive mode (D5). Tests in §10 step 11 key on event names, so the split is testable-but-ambiguous today.

**Fix:** add `clarify` / `0-token` to §6.3 (with payload schema), or rewrite §5.2 steps 4–5 onto `question` / `stuck` only.

### I-27 MINOR — `mode.json` schema inconsistent across sections; `classified` undefined for pinned invokes

- §5.1 (line 194): `mode.json` = `{requested, classified, resolved, reason[]}`.
- §4.1 (line 152), §6.3 (line 300), §9 (line 346): `{requested, classified, reason[]}` — no `resolved`.

Additionally, D1 forbids classifying when a pin is present ("do not classify"), so `classified` has no defined value for pinned invokes (null? omitted? echoed?), and `resolved` — the field §12's acceptance actually greps (`mode_resolved`) — appears in exactly one section.

**Fix:** state one canonical schema once (suggest `{requested, classified?, resolved, reason[]}` with `classified` null/omitted when requested ≠ auto) and make §4.1/§5.1/§6.3/§9 cite it.

### I-28 MINOR — D4's `prior_result.md` is a dangling artifact; escalation payload disagrees with §4.2

- D4 (line 76): retry gets "brief plus **`prior_result.md`** / log tail". `prior_result.md` appears nowhere else; §6.3's directory layout lists only `escalation.md`, and §4.2 step 1/3 writes and ships `escalation.md` (why NI missed, log tail, remaining criteria).
- §4.2's `escalation.md` content list also omits the child's own `NEXT_RETRY_PROMPT` from the `result.md` STATUS block (§5.1) — the purpose-built seed for exactly this retry.

**Fix:** strike `prior_result.md` from D4 (or define it as a section of `escalation.md`), and add `NEXT_RETRY_PROMPT` (when present) to the `escalation.md` content list.

### I-29 MINOR — wave boundary across D4 escalation undefined (wall/turn budget fresh or inherited?)

`--max-wall-sec` and `--max-turns` are wave-scoped (I-24 fix, line 236–238), but the spec never says whether the D4 interactive retry starts a **new wave** (fresh `wave_started_at`, turns reset, full wall budget) or inherits the failed NI wave's clock. It matters: a Cursor NI that misses at 1700s of its 1800s budget would hand the interactive retry 100s — a near-certain wall failure. The mermaid (`retry --> pass`) and §4.2 are silent on budgets.

**Fix:** one sentence — escalation retry starts a new wave (new `wave_started_at`, `turns=0`, full `--max-wall-sec`), or explicitly define inheritance.

### I-30 MINOR — `session.json` schema and liveness detection undefined (distinct from I-14)

§4.1's liveness split keys on `session.json` fields that are never schematized: `status` (must be set to `dead` on PASS/terminal), `updated_at` (24h TTL), a reusable conversation id, plus §5.2's `{turns, wave_started_at}` persisted on "session.json **/** mode.json" (ambiguous which file is canonical for the wave counter). Case (1) — "**OS child still running** → D3 interactive" — has no detection mechanism at all: no PID field is defined anywhere, so an implementer cannot write case (1) or its test (`kill -0` on what?).

I-14 covers `events.jsonl` / `escalation.md` schemas; `session.json` is not in its scope.

**Fix:** minimal schema — e.g. `{host, task_id, session_id, pid?, status, updated_at, turns, wave_started_at}` — plus the liveness check mechanic for case (1) (recorded pid + `kill -0`/pgrep), and name the canonical home of the wave counter.

### I-31 NIT — four small surface gaps

- **(a)** §7 OpenCode interactive row (line 327) says "OpenCode TUI via PTY" but names **no driver** to extend, unlike the Claude (expect driver) and Codex (Python PTY driver) rows; D7's "single proven driver" clause needs a name. §1 (line 40) implies a `--use-interactive` legacy path exists — cite it or state "new driver".
- **(b)** §6.3 line 318 offers `ctl.sh send|key|snapshot` — omitting the `status` and `abort` ops defined two lines above (line 310).
- **(c)** §4.2 step 2 (line 159): "Resolve mode = interactive (**D3 now true**…)" misattributes the escalation — the force signal is §4.1's "in-flight escalate only" / D4, not D3 (the NI child has exited; there is no live session yet). This leaks into `mode.json` `reason[]` vocabulary (`d3` vs `escalate`).
- **(d)** §6.2.1 conflict table enumerates interactive-only-flag conflicts only for the long form (`--interaction-mode non-interactive` + `--attach`/`--control-dir`/`--max-turns`); alias/legacy forms (`--non-interactive --attach`, `--use-print --attach`) and env-form (`SB_AGENT_MODE_ATTACH=1` + concrete NI pin) are not enumerated. Also §6.1's skill synopsis omits `--auto-policy` / `--control-dir` that §6.2/§8 expose.

## Non-issues

- Dual modes, auto default, pin-wins-over-D3, one NI→interactive escalate, no silent IX→NI on pin/D4, honest `mode-unavailable`, NI = `mode.json` only (no events/fifo), redaction parity for `events.jsonl`, wave-scoped limits, AF field parity, implementation deferred — still sound.
- I-19's `escalated`-only-if-retry-starts rule, I-22's `retry --> pass`, I-23's Pi 2s probe, I-24's persisted wave counter — correct as written.
- `--max-turns` on auto being a cap-if-interactive (ignored on NI) — reasonable, and §6.2.1 says to document it.

## Gate

**advance.** One MEDIUM (I-25) is a genuine contract contradiction needing a fix rung; the rest are MINOR/NIT schema- and vocabulary-tightening. Nothing restructures the mode model.
