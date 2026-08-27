#!/usr/bin/env python3
"""RFL rung-1 spec fixes. Edit/StrReplace sees lean-ctx compressed plan; patch real bytes."""
from pathlib import Path

p = Path("/Users/shafqat/projects/silver-bullet/repo/.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md")
text = p.read_text()
orig = text
subs = [
    (
        "    content: Implement task-signal classifier + session-continuity rule; explicit --mode always wins",
        "    content: Implement task-signal classifier + session-continuity rule; explicit --interaction-mode always wins",
    ),
    (
        "    content: Control dir/events.jsonl/ctl.sh only for interactive; NI is direct native one-shot with no fifo",
        "    content: Control dir/fifos/ctl.sh only for interactive; events.jsonl at task root for both modes (redacted); NI is direct native one-shot with no fifo",
    ),
    (
        "- **Default is auto:** classify the task unless the user (or caller) pins `--mode`.",
        "- **Default is auto:** classify the task unless the user (or caller) pins `--interaction-mode` (do not overload permission `--mode permissive|strict`).",
    ),
    (
        "- **D1 — Default mode = `auto` (not a fixed NI or TUI default).** Resolver order: **explicit pin > existing live session > classifier > non-interactive.** If `--mode interactive|non-interactive` (or legacy flags) is present, do not classify and do not auto-escalate. Bare invoke classifies.",
        "- **D1 — Default mode = `auto` (not a fixed NI or TUI default).** Resolver order: **explicit pin > existing live session > classifier > non-interactive.** A pin is `--interaction-mode interactive|non-interactive`, aliases `--interactive`/`--non-interactive`, legacy `--use-*`, or env `SB_AGENT_INTERACTION_MODE=interactive|non-interactive`. Pins skip classify and skip auto-escalate. Pin wins over D3 (pinning NI with a live session discards that session on purpose). Bare invoke classifies.",
    ),
    (
        "- **D2 — Canonical flag `--mode auto|interactive|non-interactive`.** Default `auto`. Aliases: `--interactive`, `--non-interactive`. Legacy: `--use-print`/`--use-exec` → pinned non-interactive; `--use-interactive` → pinned interactive. Conflicting flags fail preflight.",
        "- **D2 — Canonical flag `--interaction-mode auto|interactive|non-interactive`.** Default `auto`. Do **not** overload live permission `--mode permissive|strict` on invoke/delegate (RFL-AIM-I1). Aliases: `--interactive`, `--non-interactive`. Optional `--mode auto|interactive|non-interactive` only on CLIs that do not already use `--mode` for permission. Legacy: `--use-print`/`--use-exec` → pinned non-interactive; `--use-interactive` → pinned interactive. Conflicting pairs fail preflight: `--interaction-mode auto` + `--use-print`; `--interaction-mode non-interactive` + `--use-interactive`; `--interaction-mode interactive` + `--use-print`; `--control-dir` on NI (RFL-AIM-I12/I17).",
    ),
]
# D3 is long; match prefix
start = text.find("- **D3 — Session continuity requires interactive.**")
end = text.find("- **D4 —")
if start < 0 or end < 0:
    raise SystemExit("D3 block not found")
d3 = """- **D3 — Session continuity requires interactive (classifier only; pins override).** Closed force-interactive signals (any one): (1) `session.json` with `status=alive` or reusable `conversation_id`; (2) brief matches continue/resume/follow-up/answer-the-child/pick-a-dialog/iterate-on-last-attempt; (3) multi-checkpoint coaching or likely permission pickers / Q&A; (4) **in-flight** D4 escalate for this `task-id`. **Not** force-interactive: a first implement+test wave with git/tests-checkable acceptance and no live session (RFL-AIM-I2). After **successful** completion, the next invoke on the same `task-id` re-classifies (no sticky interactive) (RFL-AIM-I4). Starting NI and hoping to “attach later” is forbidden. D4 escalate is not “attach later.” `--no-escalate` also prevents prior-wave stickiness from a failed auto-NI (RFL-AIM-I13).
"""
text = text[:start] + d3 + text[end:]
for a, b in subs:
    if a not in text:
        raise SystemExit(f"missing snippet: {a[:80]!r}")
    text = text.replace(a, b, 1)

d6_old = "- **D6 — No silent interactive → NI downgrade.** If interactive is required (pin, session rule, or escalation) and PTY/session is unavailable, FAIL `failure_class=mode-unavailable` unless `--allow-mode-fallback` is set (audited). Pinned or classified NI must not spawn a TUI."
d6_new = "- **D6 — No silent interactive → NI downgrade.** If interactive is **pinned** or **D4-escalated** and PTY/session is unavailable, FAIL `failure_class=mode-unavailable` unless `--allow-mode-fallback` is set (audited one hop to NI; emit `mode_fallback` on `events.jsonl`). If interactive was **only auto-classified** (no pin, no live session) and TUI is missing, run NI with `reason=tui-unavailable` (RFL-AIM-I7). Pinned or classified NI must not spawn a TUI. `--allow-mode-fallback` on NI is ignored."
if d6_old not in text:
    raise SystemExit("D6 not found")
text = text.replace(d6_old, d6_new, 1)

ni_old = "  - NI: exec the host’s native one-shot (`claude --print`, `codex exec`, `cursor-agent` print, `opencode run`, `pi -p`) with the brief as argv/stdin. **No** expect, **no** PTY, **no** `control/` fifos, **no** snapshot loop, **no** extra bash wrapper beyond `invoke.sh` → `delegate.sh` → `exec`."
ni_new = "  - NI: exec the host’s native one-shot (`claude --print`, `codex exec`, `cursor-agent` print, `opencode run`, `pi -p`) with the brief as argv/stdin. **No** expect, **no** PTY, **no** `control/` fifos, **no** snapshot loop, **no** extra bash wrapper beyond `invoke.sh` → `delegate.sh` → `exec`. **Allowed** around that exec (not interaction wrappers): quota/429 retry, read-only log tail / idle detector, secret scan, log header, optional `monitor.sh` that only tails the log (RFL-AIM-I8)."
if ni_old not in text:
    raise SystemExit("NI bullet not found")
text = text.replace(ni_old, ni_new, 1)

# Precedence + events + AF + fifo + redaction appendix before §4 if not present
marker = "\n## 4. Mode resolver\n"
extra = """
- **D10 — Precedence and orthogonality.** Interaction pin: CLI `--interaction-mode` / aliases / legacy `--use-*` > env `SB_AGENT_INTERACTION_MODE` > AF `interaction_mode` > classifier. `--delegation-mode` / `--mode permissive|strict` (permission) are orthogonal (RFL-AIM-I11). `--no-escalate` is CLI/env `SB_AGENT_NO_ESCALATE=1` / AF `no_escalate`.
- **D11 — `events.jsonl` vs control dir.** `events.jsonl` lives at the task root in **both** modes and always includes `mode_resolved`. `control/` fifos + `ctl.sh` + snapshots exist **only** in interactive (RFL-AIM-I3). `--control-dir` on NI is `failure_class=mode-conflict`. `reply.fifo` is ctl RPC (snapshot/status replies); `events.jsonl` is the append-only stream (RFL-AIM-M6). Redact secrets in `events.jsonl` the same as snapshots (RFL-AIM-I16).
- **D12 — Fallback audit.** `--allow-mode-fallback` is interactive→NI only, one hop, writes `mode_fallback` `{from,to,reason,flag}` (RFL-AIM-M5). Auto-classified interactive with no TUI uses D6 NI `tui-unavailable` without this flag.
- **D13 — Classifier is closed-world.** Force-interactive only via D3 enumerated signals (plus optional fixture regex in tests). Else NI (RFL-AIM-I9). Worker owns the PTY driver; parent is the only `send`/`key` client (RFL-AIM-I10).
- **D14 — AF parity.** AGENT-DELEGATE fields: `interaction_mode`, `max_turns`, `attach`, `no_escalate`, `allow_mode_fallback`, `control_dir`, `auto_policy` (`parent|brief_only|supervised`, default `supervised`) (RFL-AIM-M1/M7). Env listed in §6.2: `SB_AGENT_INTERACTION_MODE`, `SB_AGENT_MODE_ATTACH`, `SB_AGENT_NO_ESCALATE`, `SB_AGENT_ALLOW_MODE_FALLBACK` (RFL-AIM-M8).
- **D15 — Extra host failure classes.** Catalog host-specific classes in §9 including Codex `hook-trust` if the adapter already emits it (RFL-AIM-M2). Pi “same model pin” = OpenCode `opencode-go/mimo-v2.5` (RFL-AIM-M4).

"""
if marker not in text:
    raise SystemExit("§4 marker missing")
if "- **D10 —" not in text:
    text = text.replace(marker, extra + marker, 1)

# §6.2 env line expansion
env_old = "Env: `SB_AGENT_MODE=auto|interactive|non-interactive` (CLI wins)."
# try several
for env_old in [
    "Env: `SB_AGENT_MODE=auto|interactive|non-interactive` (CLI wins).",
    "Env: `SB_AGENT_MODE=auto|interactive|non-interactive`.",
]:
    if env_old in text:
        text = text.replace(
            env_old,
            "Env: `SB_AGENT_INTERACTION_MODE=auto|interactive|non-interactive` (CLI wins; non-auto is a pin). Also `SB_AGENT_MODE_ATTACH=1`, `SB_AGENT_NO_ESCALATE=1`, `SB_AGENT_ALLOW_MODE_FALLBACK=1`.",
            1,
        )
        break

# AF fields
af_old = "Directive gains `interaction_mode` (`auto|interactive|non-interactive`), `max_turns`, `attach`, `no_escalate`."
if af_old in text:
    text = text.replace(
        af_old,
        "Directive gains `interaction_mode` (`auto|interactive|non-interactive`), `max_turns`, `attach`, `no_escalate`, `allow_mode_fallback`, `control_dir`, `auto_policy`.",
        1,
    )

# §9 failure classes
if "hook-trust" not in text and "failure_class" in text:
    text = text.replace(
        "`mode-unavailable` | `mode-conflict` | `max-turns` | `escalate-unavailable`",
        "`mode-unavailable` | `mode-conflict` | `max-turns` | `escalate-unavailable` | `hook-trust` (Codex, if adapter emits it)",
        1,
    )

if text == orig:
    raise SystemExit("no changes applied")
p.write_text(text)
print(f"patched {p} delta_bytes={len(text)-len(orig)}")
