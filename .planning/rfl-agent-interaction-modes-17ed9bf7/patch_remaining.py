#!/usr/bin/env python3
from pathlib import Path

p = Path("/Users/shafqat/projects/silver-bullet/repo/.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md")
text = p.read_text()
orig = text

def one(old, new, label):
    global text
    if old not in text:
        raise SystemExit(f"missing {label}: {old[:120]!r}")
    text = text.replace(old, new, 1)
    print("ok", label)

one(
    'Env: `SB_AGENT_INTERACTION_MODE=auto|interactive|non-interactive` (CLI wins; env is a pin). Seed AF-AGENT-DELEGATE JSON with `"interaction_mode": "auto|interactive|non-interactive"` and write `mode.json` after classify.',
    'Env (CLI wins; non-auto `SB_AGENT_INTERACTION_MODE` is a pin): `SB_AGENT_INTERACTION_MODE`, `SB_AGENT_MODE_ATTACH=1`, `SB_AGENT_NO_ESCALATE=1`, `SB_AGENT_ALLOW_MODE_FALLBACK=1`, `SB_AGENT_AUTO_POLICY=parent|brief_only|supervised`. Seed AF-AGENT-DELEGATE JSON with `interaction_mode`, `max_turns`, `attach`, `no_escalate`, `allow_mode_fallback`, `control_dir`, `auto_policy` and write `mode.json` after classify.',
    "env",
)
one(
    "- Directive gains `interaction_mode` (`auto|interactive|non-interactive`), `max_turns`, `attach`, `no_escalate`.",
    "- Directive gains `interaction_mode` (`auto|interactive|non-interactive`), `max_turns`, `attach`, `no_escalate`, `allow_mode_fallback`, `control_dir`, `auto_policy` (`parent|brief_only|supervised`, default `supervised`; set via `--auto-policy` / `SB_AGENT_AUTO_POLICY` / this field).",
    "af",
)
one(
    "--allow-mode-fallback                                 # interactive → NI if TUI missing (audited; pin/D4 only)\n--no-escalate                                         # disable auto NI→interactive retry AND prior-wave force-interactive",
    "--allow-mode-fallback                                 # pin/D4 interactive → NI if TUI missing; one hop; audit `mode_fallback` {from,to,reason,flag}\n--auto-policy parent|brief_only|supervised            # interactive only; default supervised\n--no-escalate                                         # disable auto NI→interactive retry AND prior-wave force-interactive",
    "cli",
)
one(
    "Parent implements the loop via `events.jsonl` + `cmd.fifo` or `scripts/agent-mode/ctl.sh send|key|snapshot`.",
    "`cmd.fifo` carries parent ops. `reply.fifo` is ctl RPC only (snapshot/status replies), not a second event stream. `events.jsonl` is append-only telemetry.\n\nParent implements the loop via `events.jsonl` + `cmd.fifo` or `scripts/agent-mode/ctl.sh send|key|snapshot`.",
    "fifo",
)
one(
    "- New `failure_class`: `mode-unavailable` | `mode-conflict` | `max-turns` | `escalate-unavailable`.",
    "- New `failure_class`: `mode-unavailable` | `mode-conflict` | `max-turns` | `escalate-unavailable` | `hook-trust` (Codex, when emitted).",
    "failclass",
)
one(
    "- `mode.json` (`{requested, classified, reason[]}` — the only `mode_resolved` record in NI; **no** `events.jsonl`, **no** fifo)",
    "- `mode.json` (`{requested, classified, resolved, reason[]}` — the only `mode_resolved` record in NI; **no** `events.jsonl`, **no** fifo; same core schema as the interactive `mode_resolved` event)",
    "modejson",
)

p.write_text(text)
print("delta", len(text) - len(orig))
