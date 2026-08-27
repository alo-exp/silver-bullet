15|    content: Control dir/events.jsonl/ctl.sh only for interactive; NI writes mode.json sidecar only (no event stream / fifo)
76|- **D4 — Auto NI miss ⇒ one interactive retry.** Applies only when mode was **auto-selected** NI (not an explicit NI pin). Trigger: harness ok but product FAIL, or child `blocked`/`result` incomplete vs brief acceptance. Next attempt is int
78|- **D6 — No silent interactive → NI downgrade when interactive is required.** Fail-closed `mode-unavailable` **only** when interactive is **pinned** or **mandatory via D4 escalation** and PTY/session is unavailable — unless `--allow-mode-fa
87|- **D9 — Shared control protocol** in [`scripts/lib/agent-delegate-common.sh`](scripts/lib/agent-delegate-common.sh) + new [`scripts/lib/agent-mode.sh`](scripts/lib/agent-mode.sh): `resolve_mode`, `classify_task`, `start`, `send`, `snapshot
133|Input: brief text, optional user utterance, `task-id`, `.planning/agent-<host>/<task-id>/session.json` if present, `.planning/agent-<host>/<task-id>/mode.json` if present.
157|Record the decision in `mode.json`: `{requested, classified, reason[]}` (both modes). Interactive also appends `mode_resolved` to `events.jsonl`.
163|1. Write `escalation.md`: why NI missed, log tail, remaining criteria.
165|3. Start interactive **once** with brief + `escalation.md`. Do not spawn a second NI.
199|- `mode.json` (`{requested, classified, resolved, reason[]}` — the only `mode_resolved` record in NI; **no** `events.jsonl`, **no** fifo; same core schema as the interactive `mode_resolved` event)
231|4. On `question` / `clarify` / `picker` — parent chooses from brief + policy; send keys (`Enter`, arrows, `y`/`n`, text).
232|5. On `stuck` / `0-token` — parent may Enter-wake, re-paste a narrower instruction, or abort. One automatic wake is allowed; then parent decides.
241|- `--max-turns` default 8 (brief submit counts as 1). Persist `{turns, wave_started_at}` on `session.json` / `mode.json` so Cursor new-process follow-ups share one wave counter (I-24).
254|  [--max-turns N] [--allow-mode-fallback] [--no-escalate]
273|--allow-mode-fallback                                 # pin/D4 interactive → NI if TUI missing; one hop; audit `mode_fallback` {from,to,reason,flag}
279|Env (CLI `--interaction-mode` wins when present; leftover concrete env is **not** a pin — I-21): `SB_AGENT_INTERACTION_MODE`, `SB_AGENT_MODE_ATTACH=1`, `SB_AGENT_NO_ESCALATE=1`, `SB_AGENT_ALLOW_MODE_FALLBACK=1`, `SB_AGENT_AUTO_POLICY=parent
306|  mode.json                  # both modes; {requested, classified, reason[]}
309|  escalation.md              # present after NI miss
324|Parent implements the loop via `events.jsonl` + `cmd.fifo` or `scripts/agent-mode/ctl.sh send|key|snapshot`.
352|- `mode.json` contains `requested`, `classified`, `reason[]` (this is `mode_resolved` for **both** modes). Interactive `events.jsonl` also has a `mode_resolved` line (redacted).
355|- Auto NI extra: if FAIL and not `--no-escalate` **and the interactive retry actually starts**, exactly one `escalated` on that retry’s `events.jsonl`, then interactive scoring. If retry cannot start (`mode-unavailable` / `tui-unavailable`)
362|1. **Contract layer** — [`scripts/lib/agent-mode.sh`](scripts/lib/agent-mode.sh): `resolve_mode`, `classify_task`, flag parse (`--interaction-mode` vs permission `--mode`), `mode.json`, control dir (interactive only), events (interactive on
363|2. **Ctl helper** — `scripts/agent-mode/ctl.sh` (interactive only).
389|- Bare invoke without `--interaction-mode` records `mode_resolved` in `mode.json` from the classifier (not a hardcoded host default).
392|- NI path never opens a TUI/PTY/fifo/`events.jsonl` in tests; writes `mode.json` only.
393|- Interactive Claude (or Codex) test: `question` → `ctl.sh send` → `result.md`.
