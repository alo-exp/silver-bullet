# Dual interaction modes for `/sb:agent-*`

Canonical spec for plan [`agent_interaction_modes_17ed9bf7`](../../.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md). Implementation library: [`scripts/lib/agent-mode.sh`](../../scripts/lib/agent-mode.sh). Interactive ctl: [`scripts/agent-mode/ctl.sh`](../../scripts/agent-mode/ctl.sh).

## Modes

1. **Interactive** — parent drives the child TUI/session like a user (live follow-ups, `control/` fifos, `events.jsonl`).
2. **Non-interactive (NI)** — prompt in, result out; native one-shot (`claude --print`, `codex exec`, Cursor print/stream-json, `opencode run`, `pi -p --provider opencode-go --model mimo-v2.5`).

Permission `--mode permissive|strict` is orthogonal. `--delegation-mode` is orthogonal. Do not smash host `--mode` with interaction values (`mode-conflict`).

## Default `/sb:agent-*` host routing

When the user env has Pi, OpenCode, Cursor, Codex, and Claude, default routing unless the user names an agent:

| Model family | Default host |
|---|---|
| Grok, Composer | Cursor (`/sb:agent-cursor`) |
| Gemini | If the user did **not** specify an agent: Gemini CLI, else Pi, else OpenCode, else Cursor |
| GPT | Codex (`/sb:agent-codex`) |
| Claude | Claude (`/sb:agent-claude`) |
| Other models | Pi or OpenCode, or any other external agent the user named |

User override always wins. Do not smash host `--mode` permission flags. Do not remap RFL GPT/Claude rungs onto Grok High. Encoder: `python3 scripts/review-fix-ladder.py --default-host-route --model {model}`.

## Resolver (locked)

explicit pin > live session / continuity (D3) > classifier > NI.

- Session continuity **requires** interactive when requested mode is `auto`.
- Pin always wins, including over D3.
- Auto-selected NI that misses acceptance gets **one** interactive retry (D4).
- No silent interactive→NI downgrade when interactive is pinned or D4-mandatory.
- D3 TUI miss → `mode-unavailable` (not silent NI).
- Auto classifier-heuristic interactive + TUI miss → NI `tui-unavailable` plus `fallback_drop:<flag>` (I-66). That hop is **terminal NI** (not D4, I-67).

Shared flag: `--interaction-mode auto|interactive|non-interactive` (default `auto`). Aliases: `--interactive`, `--non-interactive`. Legacy: `--use-print`/`--use-exec` → NI pin; `--use-interactive` → interactive pin.

Env: `SB_AGENT_INTERACTION_MODE`. Concrete leftover env without argv pin → `mode-conflict` `leftover-env-pin`. CLI wins and unsets leftover env when argv pin/`--interaction-mode` is present.

## Artifacts

`.planning/agent-<host>/<task-id>/`

- `mode.json` `{requested, classified, resolved, reason[], turns?, wave_started_at?}` — both modes. `classified` is `null` when pinned. `turns`/`wave_started_at` interactive-only.
- `events.jsonl` + `control/` — interactive only (never NI).
- `session.json` `{status: live|dead, conversation_id, pid?, pid_started_at?, updated_at, turns?, wave_started_at?}`.
- Closed `reason[]`: `tui-unavailable` | `mode-unavailable` | `mode_fallback:interactive→non-interactive:<cause>:<via>` | `fallback_drop:<flag>` (`attach`|`control-dir`|`max-turns`|`auto-policy`) | `incomplete` | `result-missing` | `escalate-unavailable` | `escalated` | `d3-process-alive` | `d3-continue` | `d3-in-wave-cursor` | `classifier-interactive` | `classifier-ni` | `pin`.

## Host matrix

| Host | NI | Interactive |
|------|----|-------------|
| Claude | `claude --print` | expect PTY (`scripts/claude-interactive-invoke.expect`) |
| Codex | `codex exec` | Python PTY (`scripts/codex-interactive-invoke.py`) |
| Cursor | print/stream-json | session-id follow-up (new process, same conversation id) |
| OpenCode | `opencode run` | host TUI (one PTY) |
| Pi | `pi -p --provider opencode-go --model mimo-v2.5` | 2s TUI probe; else `tui-unavailable` / `mode-unavailable` |

## Ctl (interactive)

`scripts/agent-mode/ctl.sh send|key|snapshot|status|abort` over `control/cmd.fifo` + `reply.fifo`. `stop` is an alias of `abort`.

## AF-AGENT-DELEGATE

Seed fields: `interaction_mode`, `max_turns`, `max_wall_sec`, `idle_sec`, `attach`, `no_escalate`, `allow_mode_fallback`, `control_dir`, `auto_policy`. `{interaction_mode:auto, allow_mode_fallback:true}` is `fallback-not-pinned`.
