# Runtime Compatibility

Silver Bullet supports multiple host coding-agent environments. The workflow intent is the same across hosts, but the model names and tiers are host-specific. Keep the host family consistent: do not mix Claude models into Codex routing or OpenAI models into Claude routing.

## Model Routing

| Intent | Claude host | Codex host |
|--------|-------------|------------|
| Structured output, indexing, lightweight summarization | Haiku | `GPT-5.2-low` |
| Execution, research, routine code changes | `claude-sonnet-4-6` | `GPT-5.3-medium` |
| Design, review, verification | `claude-opus-4-6` | `GPT-5.4-high` |
| Deep reasoning, adversarial security, hardest architectural calls | `claude-opus-4-6` | `GPT-5.5-xhigh` |

## Routing Rules

- Use the host execution tier as the default session model for inline work and user-facing conversation.
- Escalate only for the current task step, then return to the host execution tier afterward.
- Reserve the host high tier for design/review/verification work.
- Reserve the host top tier for the deepest planning, security, and architectural reasoning steps.
- If a host exposes only a single OpenAI model with reasoning-effort levels, treat `low` → `medium` → `high` → `xhigh` as the ordered ladder within that host.
