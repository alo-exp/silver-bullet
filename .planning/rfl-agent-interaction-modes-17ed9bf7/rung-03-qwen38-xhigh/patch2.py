#!/usr/bin/env python3
from pathlib import Path
p = Path("/Users/shafqat/projects/silver-bullet/repo/.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md")
t = p.read_text()
o = t
t = t.replace(
    "Next attempt is interactive, same `task-id`, brief plus `prior_result.md` / log tail.",
    "Next attempt is interactive, same `task-id`, brief plus `escalation.md` / log tail. D4 retry **inherits** the same wave `{turns, wave_started_at}` (does not reset wall/turns) (I-29).",
)
t = t.replace(
    "2. Resolve mode = interactive (D3 now true: session/context from the miss helps) **unless** `--no-escalate`.",
    "2. Resolve mode = interactive because D4 escalate is in-flight (not because D3 session-continuity flipped) **unless** `--no-escalate` (I-31c).",
)
t = t.replace(
    "5. On `stuck` / `0-token` — parent may Enter-wake, re-paste a narrower instruction, or abort. One automatic wake is allowed; then parent decides.",
    "5. On `stuck` / `zero_tokens` — parent may Enter-wake, re-paste a narrower instruction, or abort. One automatic wake is allowed; then parent decides (I-26).",
)
old = "- **OpenCode** (`tui` for interactive): NI = `opencode run`. Interactive = OpenCode TUI via PTY. Model pin `opencode-go/mimo-v2.5`. Preflight still rejects Desktop `.app`."
new = "- **OpenCode** (`tui` for interactive): NI = `opencode run`. Interactive = OpenCode TUI via **one PTY** using the existing host TUI driver (do not add a second expect/python wrap). Model pin `opencode-go/mimo-v2.5`. Preflight still rejects Desktop `.app` (I-31a)."
if old in t:
    t = t.replace(old, new, 1)
else:
    print("OpenCode line skip")
# §9 resolved
t = t.replace(
    "- `mode.json` contains `requested`, `classified`, `reason[]` (this is `mode_resolved` for **both** modes).",
    "- `mode.json` contains `requested`, `classified`, `resolved`, `reason[]` (this is `mode_resolved` for **both** modes; `classified` is `null` when pinned).",
)
# alias pairs
needle = "| `--interactive` + `--non-interactive` | Opposite aliases |"
if needle in t and "alias-form" not in t:
    t = t.replace(
        needle,
        needle + "\n| `--use-print` + `--non-interactive` (alias-form same pin) | redundant, allow | \n| `--use-print` + `--interaction-mode auto` | pin vs auto (already covered) |",
        1,
    )
if t == o:
    raise SystemExit("no change")
p.write_text(t)
print("delta", len(t)-len(o))
