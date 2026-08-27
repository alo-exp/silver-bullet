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
    "--allow-mode-fallback                                 # pin/D4 interactive → NI if TUI missing; one hop; audit `mode_fallback` {from,to,reason,flag}",
    "--allow-mode-fallback                                 # **pinned interactive only** → NI if TUI missing; one hop; audit `mode_fallback` {from,to,reason,flag}. **Not valid on D4** (would be a second NI) (I-25)",
    "I-25 cli",
)
# D6 first sentence from hits is truncated; find unique
idx = text.find("- **D6 —")
if idx < 0:
    raise SystemExit("no D6")
end = text.find("\n- **D7", idx)
d6 = text[idx:end]
if "D4" in d6 and "allow-mode-fallback" in d6:
    d6n = d6.replace("pinned** or **mandatory via D4 escalation**", "pinned** (not D4)")
    d6n = d6n.replace("pin/D4", "pin only")
    if "I-25" not in d6n:
        d6n = d6n.rstrip() + " `--allow-mode-fallback` is **pin-only**; D4 TUI miss stays `escalate-unavailable` / original NI FAIL (I-25).\n"
    text = text[:idx] + d6n + text[end:]
    print("ok I-25 D6")
else:
    print("D6 skip", d6[:200])

one(
    "Record the decision in `mode.json`: `{requested, classified, reason[]}` (both modes). Interactive also appends `mode_resolved` to `events.jsonl`.",
    "Record the decision in `mode.json`: `{requested, classified, resolved, reason[]}` (both modes; `classified` is `null` when pinned). Interactive also appends `mode_resolved` to `events.jsonl` (I-27).",
    "I-27 record",
)
one(
    "3. Start interactive **once** with brief + `escalation.md`. Do not spawn a second NI.",
    "3. Start interactive **once** with brief + `escalation.md` (includes log tail, remaining criteria, and `NEXT_RETRY_PROMPT` from `result.md`). Do not spawn a second NI. Do not use a separate `prior_result.md` name (I-28).",
    "I-28",
)
one(
    "Parent implements the loop via `events.jsonl` + `cmd.fifo` or `scripts/agent-mode/ctl.sh send|key|snapshot`.",
    "Parent implements the loop via `events.jsonl` + `cmd.fifo` or `scripts/agent-mode/ctl.sh send|key|snapshot|status|abort` (I-31).",
    "I-31 ctl",
)

# events list
old_ev = None
for line in text.splitlines():
    if line.startswith("**Events:**") or "mode_resolved" in line and "ready" in line:
        old_ev = line
        break
if old_ev and "clarify" not in old_ev:
    text = text.replace(old_ev, old_ev.rstrip() + " | `clarify` | `zero_tokens` (I-26)", 1)
    print("ok I-26")
else:
    print("I-26 skip", old_ev)

# pid on session
if "pid" not in text.lower() or "child pid" not in text.lower():
    needle = "Stale/expired `session.json` does not force interactive."
    if needle in text:
        text = text.replace(
            needle,
            needle + " `session.json` stores `{status, conversation_id, pid?, updated_at, turns, wave_started_at}`; “OS child still running” means `pid` is set and `kill -0` succeeds (I-30).",
            1,
        )
        print("ok I-30")
    else:
        print("I-30 skip")

# mode.json schema unify in §6.3
one(
    "  mode.json                  # both modes; {requested, classified, reason[]}",
    "  mode.json                  # both modes; {requested, classified, resolved, reason[]}",
    "I-27 tree",
)

p.write_text(text)
print("delta", len(text) - len(orig))
