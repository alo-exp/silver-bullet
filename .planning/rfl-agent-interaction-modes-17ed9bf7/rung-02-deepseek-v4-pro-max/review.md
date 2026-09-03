# Rung 2 review — DeepSeek V4 Pro Max (OpenCode)

**Plan:** [agent_interaction_modes_17ed9bf7.plan.md](/Users/shafqat/projects/silver-bullet/repo/.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md)

**Method:** `/silver:agent-opencode` — `scripts/agent-opencode/invoke.sh` missing in this sparse HEAD (would also refuse non-`mimo-v2.5`). Native fallback `opencode run -m opencode-go/deepseek-v4-pro --variant max --auto`. Banner `build · deepseek-v4-pro`. Not remapped to Grok or Fast.

**STATUS:** review-complete

**Plan SHA256 (post-mutation):** `4077356bef18e78d276685b09a4c91b5f2f3f859888aa891656bcf0a26a5eff5` @ 02:45:09

DeepSeek wrote the first complete issue list at 02:42. The plan then mutated at 02:45 (I-18/I-19/I-20/I-21/I-22/I-23/I-24 text landed). This file is that DeepSeek list **minus issues whose new text is actually fixed**, plus residuals where the new text is still wrong. Plan not edited by this rung.

## Method evidence

```
invoke.sh on disk: false
git cat-file HEAD:scripts/agent-opencode/invoke.sh: missing
SKILL.md on disk: false
opencode 1.17.16
Native model: opencode-go/deepseek-v4-pro
Native effort: --variant max
attempt1: --file ate the positional message
launch-native.py INVOKE_EXIT=0; banner build · deepseek-v4-pro
PID 14847 native --file attach completed; review.md mtime 02:42:35
Plan mtime 02:45:09 — delta re-check of mutated §§3–9 (no second model remap)
```

Graphify CLI used (`graphify query` / `explain`); Graphify MCP down.

## Rung-1 fixes checked (do not re-raise)

| ID | Post-fix text | Verdict |
|----|---------------|---------|
| I-1 | `--interaction-mode` vs permission `--mode permissive\|strict`; smash → `mode-conflict` | still correct |
| I-2 | D3 first-wave implement+test stays NI | still correct |
| I-3 | NI writes `mode.json` only; no `events.jsonl` / fifo | still correct |
| I-4 | TTL + PASS reset + in-flight-escalate only | §4.1 split added; D1/mermaid still stale — see I-18 |
| I-5 | Pin always wins over D3 | still correct |
| I-6 | Cursor new process + session id is interactive | still correct |
| I-7 | Auto + TUI missing → NI `tui-unavailable` | still correct |
| I-8 | Named NI reliability wrappers allowed | still correct |
| I-12 | §6.2.1 conflict table | still correct; auto+attach still a fork — see I-20 |
| I-13 | `--no-escalate` unsticks in-flight; does not ignore live `session.json` | still correct |
| I-16 | `events.jsonl` `assistant`/`tool_use` redacted like snapshots | still correct |

## ISSUES (still open after 02:45 plan mutation)

### I-18 MEDIUM — D1 / mermaid still treat any live session as D3; §4.1 split is not wired through

§4.1 now splits liveness (DeepSeek I-18 fix): (1) OS child running → D3; (2) reusable id + continue/coach or in-wave Cursor follow-up → D3; (3) reusable id + terminal `result.md` and no continue → resume-token only, classify fresh. PASS must `status=dead` or delete `session.json`.

That prose is implementable. **D1 and the §4 mermaid were not updated to match:**

- D1 still: **explicit pin > existing live session > classifier > non-interactive.**
- Mermaid `sess{Live session or continuity needed?} -->|yes| tui` still has one boolean.
- D3 still: follow-up on a **live/recent-alive** child session (no resume-token exception).

An implementer following D1/mermaid will D3 on a leftover reusable id after PASS if the `status=dead` mutation is missed, which is the original I-4/I-6 collision. §4.1 (3) and D1 cannot both be right until `sess` is the three-way split (process-alive vs resume-token vs dead).

**Fix:** Change D1 to pin > process-alive-or-continue-utterance > classifier > NI. Split the mermaid `sess` node the same way as §4.1. D3 “live session” = (1) or (2) only.

### I-20 MEDIUM — `--interaction-mode auto` + `--attach` still two legal implementations

§6.2.1 now mentions auto/`omitted` + `--attach` / `--control-dir`: interactive pin (skip classifier) **or** fail `mode-conflict`; do not silently ignore attach on NI. `--max-turns` on auto is a cap if interactive, ignored on NI.

Silent-ignore is closed. The spec still licenses **two opposite behaviors** (pin vs conflict). Tests cannot pick a fixture. D1 “bare invoke classifies” is false if attach is a pin.

**Fix:** Pick one. Recommended: `--attach` / `--control-dir` is an interactive pin (document; skip classifier). `--max-turns` stays “cap if interactive.”

### I-21 MEDIUM — leftover concrete `SB_AGENT_INTERACTION_MODE` still pins every later invoke

D2 now: env `auto` is requested-auto; concrete env is a pin for **this argv only**; tests use `env -u`; preflight **warns** if a leftover concrete env is inherited.

Warning does not unstick. An exported `SB_AGENT_INTERACTION_MODE=non-interactive` in CI/matrix still disables classify and D4 for every subsequent `/silver:agent-*` until unset. “This argv only” is not an isolation mechanism (the env is still in the process environment).

**Fix:** treat inherited concrete env as requested-auto + warn, **or** fail preflight `mode-conflict` on inherited concrete env unless `--interaction-mode` is also on argv. Tests `env -u` are necessary but not sufficient.

## Fixed in the 02:45 plan mutation (do not re-file)

- **I-19** — §9: `escalated` only if the interactive retry **starts**; else `escalate-unavailable` on NI `mode.json` `reason[]`.
- **I-22** — mermaid `retry --> pass`.
- **I-23** — Pi probe **2s timeout**; timeout ≡ not a TUI.
- **I-24** — persist `{turns, wave_started_at}`; wall is wave-scoped.

## Still open from rung 1 (not re-filed)

VALID in triage, not in the user’s “already fixed” list, still gappy after 02:45:

- I-9 classifier “likely pickers / ambiguous Q&A” still not a closed signal list
- I-10 three owners of the interactive loop (`auto_policy` / worker / parent) — `auto_policy` exists but does not collapse ownership
- I-11 `--delegation-mode` still unmentioned (live OpenCode adapter has it)
- I-14 event / `escalation.md` field schemas still missing (event **names** only)

Closed by 02:45 text (were listed as open in the 02:42 DeepSeek draft): M-A1 `auto_policy` CLI/env/AF; M-A2 Codex `hook-trust` in `failure_class`; M-A4 Pi model pin `opencode-go/mimo-v2.5`; M-A5 `mode_fallback` `{from,to,reason,flag}`; M-A6 `reply.fifo` vs `events.jsonl`; M-A7 AF `allow_mode_fallback` / `control_dir` / `auto_policy`.

## Non-issues

- Dual modes, auto default, one NI→interactive escalate, no silent IX→NI on pin/D4, honest `mode-unavailable`, AF `interaction_mode`, implementation deferred — still sound.
- Orthogonal `--mode permissive|strict` + `--interaction-mode` — correct after I-1.
- OpenCode NI = `opencode run`; Max effort is `--variant max` on `opencode-go/deepseek-v4-pro` (no `*-pro-max` slug).

## Gate

Parent (coordinator) decides accept/fix. This rung did not edit the plan.
