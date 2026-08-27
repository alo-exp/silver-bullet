# Rung 2 verify_1 (DeepSeek V4 Pro max — VERIFY-ONLY pass 1, READONLY)

Scope: confirm I-18..I-24 applied to `.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md`; confirm re-filed M-A1/2/6/7 rejection stands. Plan was not modified by this pass.

## I-18..I-24 — all applied

| ID | Substance | Plan evidence | Verdict |
|----|-----------|---------------|---------|
| I-18 | Session liveness split: OS child alive → D3 interactive; reusable conversation id + continue utterance → interactive; reusable id + terminal result → resume-token only; TTL 24h; PASS/terminal sets `status=dead` | L132-133 §4.1 "Session liveness is **split** (I-18)"; `resume-token only`; `status=dead` | APPLIED |
| I-19 | `escalated` event only if the interactive retry actually starts; else `escalate-unavailable` on NI `mode.json` `reason[]`; keep original NI FAIL (no false PASS) | L349 §9 "…and the interactive retry actually starts…"; `escalate-unavailable`; "(I-19)" | APPLIED |
| I-20 | Auto + `--attach`/`--control-dir`: pin interactive (skip classifier) or fail `mode-conflict`; never silently ignored on NI | L289 §6.2.1 table row, "(I-20)" | APPLIED |
| I-21 | Env `auto` = requested-auto (not a pin); concrete env value pins this argv only; tests use `env -u`; preflight warns on leftover concrete env pin | L74 D2 "requested-auto"; "preflight **warns**"; `env -u`; "(I-21)" | APPLIED |
| I-22 | Mermaid fixed: `retry --> pass` (was `retry --> done`) | L120 `retry --> pass`; L118/L121 pass-evaluation edges intact | APPLIED (substance) |
| I-23 | Pi probe `2s timeout` ≡ not a TUI; auto → NI `tui-unavailable`; pin/D4 → `mode-unavailable` | L328 §7 Pi "(I-7/I-23)" | APPLIED |
| I-24 | Persist `{turns, wave_started_at}` on `session.json`/`mode.json` so Cursor new-process follow-ups share one wave counter | L236 §5.2 hard limits "(I-24)" | APPLIED |

Note (non-blocking): I-22 is the only item without an explicit `(I-22)` marker citation in the plan (marker count = 0 vs 1 for all others). The substance is fully applied at L120; the marker omission is cosmetic.

## Re-filed M-A1/2/6/7 — REJECT CONFIRMED

Triage counts verified exactly against the current plan:

| Item | Concept | Plan evidence | Count (plan vs triage) |
|------|---------|---------------|------------------------|
| M-A1 | auto_policy surface | L269 CLI `--auto-policy`; L274 env `SB_AGENT_AUTO_POLICY` + AF seed field; L336-339 §8 default `supervised` | 4 = 4 ✓ |
| M-A2 | hook-trust in §9 catalog | L325 §7 Codex; L350 §9 `failure_class`; L339 banner auto-handle | 3 = 3 ✓ |
| M-A6 | reply.fifo vs events.jsonl | L307 tree; L316 "ctl RPC only… not a second event stream" | 2 = 2 ✓ |
| M-A7 | AF field parity | L274 seed JSON lists `allow_mode_fallback`, `control_dir`, `auto_policy` | present ✓ |

The rung-02 review.md claims (M-A1 "no CLI/env/AF surface", M-A2 "absent from §9", M-A6 "unexplained", M-A7 "AF lacks fields") are stale — each claim is contradicted by the line references above. REJECT stands.

## Verdict

- I-18..I-24: 7/7 applied (I-22 marker-only cosmetic gap).
- M-A1/2/6/7: rejection confirmed; all four concepts already in plan with triage-exact counts.
- READONLY honored: plan untouched (no edits, no writes).
