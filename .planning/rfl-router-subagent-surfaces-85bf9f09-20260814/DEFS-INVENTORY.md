# RFL defs inventory — router_subagent_surfaces_85bf9f09 (2026-08-14)

Canonical location: [`~/.cursor/agents/`](/Users/shafqat/.cursor/agents/) (existing `agents_install_scope: global`). Live slugs from `agent models` this session. No Fast variants created. Low skipped unless it was the only way to get Medium (it never was).

## Created this turn

| Path | Model slug | Level |
|---|---|---|
| [`~/.cursor/agents/sb-gemini-3-7-flash-medium.md`](/Users/shafqat/.cursor/agents/sb-gemini-3-7-flash-medium.md) | `gemini-3.7-flash-medium` | Medium |
| [`~/.cursor/agents/sb-gemini-3-7-flash-high.md`](/Users/shafqat/.cursor/agents/sb-gemini-3-7-flash-high.md) | `gemini-3.7-flash-high` | High |
| [`~/.cursor/agents/sb-opus-5-medium.md`](/Users/shafqat/.cursor/agents/sb-opus-5-medium.md) | `claude-opus-5-thinking-medium` | Medium |
| [`~/.cursor/agents/sb-opus-5-max.md`](/Users/shafqat/.cursor/agents/sb-opus-5-max.md) | `claude-opus-5-thinking-max` | Max |
| [`~/.cursor/agents/sb-gpt-5-6-sol-max.md`](/Users/shafqat/.cursor/agents/sb-gpt-5-6-sol-max.md) | `gpt-5.6-sol-max` | Max |

`~/.config/silver-bullet/cursor-sb-agents.json` `rfl_effort_maps` updated for gemini-3.7-flash, gpt-5.6-sol max/medium, opus-5 medium/max.

## Already existed (kept)

- Composer 2.5: `sb-composer-2-5-medium|high|xhigh` (+ unused `low`) — model `composer-2.5`
- GLM 5.2: `sb-glm-5-2-high` (`glm-5.2-high`), `sb-glm-5-2-xhigh` (`glm-5.2-max`)
- Gemini 3.6 Flash: `sb-gemini-3-6-flash-high` — **wrong generation; not used**. Left in place.
- Kimi K3: `sb-kimi-k3-high` (`kimi-k3-high`), `sb-kimi-k3-xhigh` (`kimi-k3-max`)
- GPT-5.6 Sol: `sb-gpt-5-6-sol-medium|high|xhigh` (+ unused `low`)
- Opus 5: `sb-opus-5-high` (`claude-opus-5-thinking-high`), `sb-opus-5-xhigh` (`claude-opus-5-thinking-xhigh`)

## Skipped (no Cursor slug, or Max already mapped via xhigh)

| Family | Level | Why |
|---|---|---|
| Composer 2.5 | Max | No distinct Max slug (`composer-2.5` + `composer-2.5-fast` only; Fast forbidden) |
| GLM 5.2 | Medium | No `glm-5.2-medium` |
| GLM 5.2 | Max as extra def | Max already encoded as Extra High → `sb-glm-5-2-xhigh` / `glm-5.2-max` |
| Gemini 3.7 Flash | Extra High | No `gemini-3.7-flash-xhigh` |
| Gemini 3.7 Flash | Max | No `gemini-3.7-flash-max` |
| Gemini 3.7 Flash | Low | Medium exists; Low not requested |
| Kimi K3 | Medium | No `kimi-k3-medium` (only low/high/max) |
| Kimi K3 | Max as extra def | Max already encoded as Extra High → `sb-kimi-k3-xhigh` / `kimi-k3-max` |
| GPT-5.6 Sol | Low | Medium exists |
| Opus 5 | Low | Medium thinking slug exists |
| All families | Fast | Forbidden |

## Remaining ladder for parent (after Composer 2.5 Medium/High/xHigh)

1. GLM 5.2: High (`sb-glm-5-2-high`) → Extra High/Max (`sb-glm-5-2-xhigh` / `glm-5.2-max`)
2. Gemini 3.7 Flash: Medium (`sb-gemini-3-7-flash-medium`) → High (`sb-gemini-3-7-flash-high`)
3. Kimi K3: High (`sb-kimi-k3-high`) → Extra High/Max (`sb-kimi-k3-xhigh` / `kimi-k3-max`)
4. GPT-5.6 Sol via `sb:agent-codex`: Medium → High → Extra High → Max (`gpt-5.6-sol-max`)
5. Opus 5 via `sb:agent-claude`: Medium (thinking) → High → Extra High → Max (`claude-opus-5-thinking-max`)
