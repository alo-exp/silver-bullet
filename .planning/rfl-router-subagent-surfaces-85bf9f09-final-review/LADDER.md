# Ladder (user-pinned Pi RFL) — CLOSED

Host resolver default (`review-fix-ladder.py --host cursor`) is Composer/Grok 4.5 — **overridden**.

Preferred host: all 11 rungs via `/silver:agent-pi` first.

```
PI_PROVIDER=omniroute PI_MODEL=<slug> \
  bash scripts/agent-pi/invoke.sh --interaction-mode non-interactive
```

**Official substitution (session policy):** after **two** Pi launch failures (401 / empty EXIT 0 / hang EXIT 143), substitute **Grok 4.6 High** (`cursor-grok-4.6-high`). Never Fast. Never Extra High as the unspecified default. Named Extra High/XHigh Pi slugs are used when they succeed (verify). Do **not** treat start-of-ladder “No Grok substitute” as live policy.

| N | PI_MODEL | Review | APPLY | v1 | v2 | State |
|---|---|---|---|---|---|---|
| 1 | opencode-go/minimax-m3 | NOT CLEAN (Grok sub) | ACCEPT F-01–F-08 | CLEAN | CLEAN | CLOSED |
| 2 | opencode-go/deepseek-v4-pro-max | CLEAN leftover LOW/NIT (Pi) | APPLY; REJECT N-6 | CLEAN | CLEAN | CLOSED |
| 3 | opencode-go/qwen3.8-max | NOT CLEAN (Pi) | REJECT F-1; ACCEPT F-2 HOLD | CLEAN | CLEAN | CLOSED |
| 4 | opencode-go/glm-5.3 | CLEAN 0 (Grok sub) | none | CLEAN | CLEAN | CLOSED |
| 5 | opencode-go/kimi-k3-max | CLEAN 0 (Grok sub) | none | CLEAN | CLEAN | CLOSED |
| 6 | cursor/gemini-3.7-flash-high | CLEAN 0 (Pi EXIT 0) | none | Pi | Pi | CLOSED |
| 7 | cursor/grok-4.6-high | CLEAN 0 (Grok in-session) | none | Pi retry | Grok sub | CLOSED |
| 8 | codex/gpt-5.6-sol-high | CLEAN (Grok sub) | none | Pi Codex EXIT 0 | Pi Codex EXIT 0 | CLOSED |
| 9 | codex/gpt-5.6-sol-xhigh | CLEAN (Grok High sub) | none | Pi XHigh EXIT 0 | hang 143 → Pi retry EXIT 0 | CLOSED |
| 10 | claude/claude-opus-5-high | CLEAN 0 (Grok sub) | none | Pi Claude EXIT 0 | Pi Claude EXIT 0 | CLOSED |
| 11 | claude/claude-opus-5-xhigh | CLEAN 0 (Grok High sub) | none | Pi XHigh EXIT 0 | hang 143 → Pi retry EXIT 0 | CLOSED |

Freeze SHA (since rung 3 APPLY): `d5343ac14c24c23930140ffe39d34dea5ab799fde2e8f200571c5086131029e0` / **621095** bytes.

Policy D: [`POLICY-D.md`](POLICY-D.md). **Freeze READY but NOT EXECUTED.**
