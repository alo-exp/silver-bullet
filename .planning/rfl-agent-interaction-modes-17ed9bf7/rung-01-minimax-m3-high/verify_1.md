# Rung 1 verify 1/2 — MiniMax M3 High

**Plan:** `/.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md`
**Review:** `./review.md`
**Triage:** `./triage.md`
**Scope:** VERIFY-ONLY. Plan was not edited in this rung.

## VERIFY_PASS

Every VALID finding from `triage.md` is applied in the plan. No leftover gaps.

### Per-finding trace

| ID | Verdict | Evidence in plan (line refs on the current `/...plan.md`) |
|----|---------|----------------------------------------------------------|
| **I-1** flag split | VALID-HIGH — applied | D2: `--interaction-mode auto\|interactive\|non-interactive`; `--mode permissive\|strict` is orthogonal; explicit "Do not reuse `--mode`" and "live `--mode` remains permission". |
| **I-2** first-wave NI | VALID-HIGH — applied | §4.1 "Not a D3 signal: a normal first-wave implement+test / test-fix brief with no live session and no continue/coach utterance — that stays NI (D7 cheaper path); D4 covers a real product miss." |
| **I-4** no sticky task-id | VALID-HIGH — applied | §4.1 "Prior-wave stick (I-4 / I-13)": "A completed wave (PASS, or terminal `result.md` STATUS `pass\|fail\|blocked` with no pending escalate) **resets** the task-id" and "TTL expiry also resets". In-flight-escalate force-interactive is the only sticky case. |
| **I-7** auto `tui-unavailable` | VALID-MED — applied | D6: "**Auto** (including classifier/D3 picking interactive) + TUI/session unavailable: do **not** fail-closed — launch NI with `reason=tui-unavailable` (Pi/Cursor). Pinned or classified NI must not spawn a TUI." |
| **I-8** wrappers | VALID-MED — applied | D7: "Allowed NI reliability wrappers (not interaction wrappers): preflight, quota-retry loop, tail-idle (python idle watcher on the log), secret scan, log header, optional read-only `monitor.sh`." |
| **I-12** conflicts | VALID-MED — applied | §6.2.1 explicit table with 7 invalid pairs incl. `--mode non-interactive --use-interactive` row and `--interaction-mode non-interactive + --attach/--control-dir/--max-turns` row, all `mode-conflict`. |
| **I-16** redact events | VALID-MED — applied | §6.3 "Redaction (I-16): `events.jsonl` `assistant` and `tool_use` payloads use the **same redaction pipeline as `snapshots/`** … Persist redacted events; do not keep a raw sibling on disk." §11 Security: "snapshots **and** `events.jsonl` `assistant`/`tool_use` redacted". |
| **M-A1** auto_policy surface | VALID-MED — applied | §6.1/§6.2: CLI `--auto-policy parent\|brief_only\|supervised` + env `SB_AGENT_AUTO_POLICY=parent\|brief_only\|supervised`; §8 directive carries `auto_policy`; default `supervised`. |
| **M-A2** hook-trust in §9 | VALID-LOW — applied | §9: "`failure_class`: `mode-unavailable` \| `mode-conflict` \| `max-turns` \| `escalate-unavailable` \| **`hook-trust`** (Codex, when emitted)." |
| **M-A6** fifo split | VALID-MED — applied | §6.3: "**Commands (JSON lines):** send/key/snapshot/status/abort" via cmd.fifo; "**Events:** mode_resolved/ready/…" via `events.jsonl` (append-only telemetry); "`reply.fifo` is ctl RPC only (snapshot/status replies), not a second event stream." |
| **M-A7** AF field parity | VALID-MED — applied | §6.2: AF seed JSON lists `interaction_mode, max_turns, attach, no_escalate, allow_mode_fallback, control_dir, auto_policy`; §8 directive gain matches. |

### Rejected-as-FP findings — correctly left alone

- **B1** (sparse-checkout FP): §1 references `claude-interactive-invoke.expect`, `codex-interactive-invoke.py`, `agent-cursor-delegate.sh` — all three paths are present in the repo per `ctx_execute_file` lookup. The original review's harness was on a sparse view; triage rejection stands. Plan not changed.
- **I-3** (events.jsonl both modes): Already correct. NI uses `mode.json` for the only `mode_resolved` record; interactive writes `events.jsonl` including `mode_resolved`; §5.1 explicitly says "**no** `events.jsonl`, **no** fifo" in NI. The todo `ctl-and-events` correctly says "Control dir/events.jsonl/ctl.sh only for interactive; NI writes mode.json sidecar only (no event stream / fifo)". No change needed.
- **I-5** (pin vs D3): One-line clarifier added in D1 — "**Pin always wins over D3** (I-5): session-continuity applies only when the *requested* interaction mode is `auto`. Pinned NI + live session stays NI." Sufficient.
- **I-6** (Cursor session transport): §7 explicitly labels Cursor as `session` and allows new-process follow-up with the same conversation id; "is the Cursor interactive equivalent, not a D5/D7 violation, and not `mode-unavailable`." Already covered.
- **I-15** (monitor.sh): D7 names "optional read-only `monitor.sh`" as allowed. No change.
- **I-17** (`--control-dir` on NI): §6.2.1 table row 5: `--interaction-mode non-interactive + --attach / --control-dir / --max-turns` is `mode-conflict`. Applied.

### Consistency check

- D1 ↔ §4.1 ↔ §4.2: pin > session > classifier > NI; one-retry escalation; `--no-escalate` unsticks prior-wave. ✓
- D7 ↔ §5.1 ↔ §6.3: NI = native exec + allowed reliability wrappers; no PTY/fifo/expect/tmux; `control/` only interactive. ✓
- §6.2.1 conflict table ↔ §6.2 CLI: every CLI flag has a conflict row or orthogonal pairing. ✓
- §8 ↔ §6.2: every AF directive field has a CLI/env source. ✓
- §9 ↔ §7: failure_class catalog includes `hook-trust` for Codex. ✓
- §10 ↔ §9: implementation steps (especially #3 classifier+escalation, #4-#8 adapters, #9 skills+worker+AF seed) match the decisions. ✓
- §12 acceptance: every MUST-FIX surface (auto + both modes, explicit pin, NI miss → one escalate, no TUI in NI, conflict pairs, redaction, AF round-trip, first-wave NI, prior-wave reset, Cursor follow-up new process) has an acceptance row. ✓

### Notes for the next rung

- The plan is text-only and self-consistent. No silent assumptions, no orphan fields, no dangling references.
- The `mimo-v2.5` model pin for OpenCode (and `Same model pin` for Pi) is intentionally out of scope for this spec; per the review's own "Non-issues", it does not block the spec.
- `M-A3` (per-host auth + log-floor values) and `M-A9` (env var pin semantics) are DEFERRED to implementation, which is the correct call given they are per-host numerics, not spec decisions.

## VERIFY_PASS

Plan ready for rung 2/13.
