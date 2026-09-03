#!/usr/bin/env python3
from pathlib import Path

p = Path("/Users/shafqat/projects/silver-bullet/repo/.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md")
text = p.read_text()
orig = text

def one(old, new, label):
    global text
    if old not in text:
        raise SystemExit(f"missing {label}: {old[:140]!r}")
    text = text.replace(old, new, 1)
    print("ok", label)

one(
    "- Session file exists with `status=alive` **and** is within TTL (default **24h** from `updated_at`, or until the child process is known dead). Stale/expired `session.json` does not force interactive.",
    "- Session liveness is **split** (I-18): (1) **OS child still running** → D3 interactive; (2) **reusable conversation id** + explicit continue/coach utterance **or** in-wave Cursor follow-up → interactive; (3) reusable id + **terminal** `result.md` and no continue utterance → **resume-token only**, do **not** D3 (classify fresh). TTL (default **24h** from `updated_at`) applies to (1)(2). Stale/expired `session.json` does not force interactive. PASS/terminal reset **must** set `status=dead` (or delete `session.json`) so leftover ids cannot skip the classifier.",
    "I-18",
)
one(
    "  retry --> done",
    "  retry --> pass",
    "I-22",
)
one(
    "- Auto NI extra: if FAIL and not `--no-escalate`, exactly one `escalated` (on the interactive retry’s `events.jsonl`) then interactive scoring; do not PASS on the NI miss.",
    "- Auto NI extra: if FAIL and not `--no-escalate` **and the interactive retry actually starts**, exactly one `escalated` on that retry’s `events.jsonl`, then interactive scoring. If retry cannot start (`mode-unavailable` / `tui-unavailable`), record `escalate-unavailable` on NI `mode.json` `reason[]` (no `events.jsonl`) and keep the original NI FAIL — do not PASS on the NI miss (I-19).",
    "I-19",
)
one(
    "| `--interaction-mode non-interactive` + `--attach` / `--control-dir` / `--max-turns` | Interactive-only flags on NI |",
    "| `--interaction-mode non-interactive` + `--attach` / `--control-dir` / `--max-turns` | Interactive-only flags on NI |\n| `--interaction-mode auto` (or omitted) + `--attach` / `--control-dir` | Interactive pin (skip classifier) **or** fail `mode-conflict` if you need classify-then-NI; do **not** silently ignore attach on NI (I-20). `--max-turns` on auto is a cap **if** interactive is selected; ignored on NI (document in help) |",
    "I-20",
)
one(
    "- **Pi**: NI = `pi -p` (direct). Interactive = probe `pi` without `-p`; if not a real TUI/REPL: **auto** → NI `reason=tui-unavailable` (I-7); **pin/D4** → `mode-unavailable` (do not fake). Same model pin.",
    "- **Pi**: NI = `pi -p` (direct). Interactive = probe `pi` without `-p` with a **2s timeout** (PTY + banner/status then abort). Timeout or non-TUI ≡ not a TUI: **auto** → NI `reason=tui-unavailable` (I-7/I-23); **pin/D4** → `mode-unavailable` (do not fake). Same model pin as OpenCode (`opencode-go/mimo-v2.5`).",
    "I-23",
)
one(
    "- `--max-turns` default 8 (brief submit counts as 1).\n- `--max-wall-sec` host defaults (Claude/Codex 900, Cursor 1800, OpenCode/Pi 900).",
    "- `--max-turns` default 8 (brief submit counts as 1). Persist `{turns, wave_started_at}` on `session.json` / `mode.json` so Cursor new-process follow-ups share one wave counter (I-24).\n- `--max-wall-sec` host defaults (Claude/Codex 900, Cursor 1800, OpenCode/Pi 900), **wave-scoped** not per-process.",
    "I-24",
)
one(
    "Env: `SB_AGENT_INTERACTION_MODE` (CLI wins). AF: `interaction_mode`. Conflicting pairs fail preflight — enumerated in §6.2.1.",
    "Env: `SB_AGENT_INTERACTION_MODE` (CLI wins). Value `auto` is requested-auto (**not** a concrete pin). Concrete `interactive|non-interactive` env is a pin for **this argv only**; tests use `env -u`; preflight **warns** if a leftover concrete env pin is inherited from the parent shell (I-21). AF: `interaction_mode`. Conflicting pairs fail preflight — enumerated in §6.2.1.",
    "I-21",
)

p.write_text(text)
print("delta", len(text) - len(orig))
