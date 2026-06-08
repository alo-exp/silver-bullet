# Runtime Compatibility

Silver Bullet supports multiple host coding-agent environments. The workflow intent is the same across hosts, but model selection belongs to the active host runtime and any delegated tool that owns its own execution.

## Model Selection Boundary

Silver Bullet does not provide generic automatic model routing. The historical `hooks/ensure-model-routing.sh` script is disabled, exits as a no-op, and is not registered as the active mechanism for model choice.

| Surface | Model owner | Silver Bullet responsibility |
|---------|-------------|------------------------------|
| Current Claude or Codex session | User and host configuration | Compose workflow, enforce gates, record skill progress |
| GSD subagents or GSD-managed work | GSD and host agent configuration | Delegate to GSD at the correct lifecycle boundary |
| Design, Engineering, Product Management, Superpowers, MultAI | The invoked plugin/tool and current host session | Sequence the helper only when the SB workflow calls for it |
| Hooks and shell helpers | No model selection | Validate state, command intent, and artifact freshness |

## Rules

- Use the active host session model for inline work and user-facing conversation.
- Do not encode Claude model names in Codex instructions, or Codex/OpenAI model names in Claude instructions.
- Do not require `.planning/config.json` `model_profile` fields as part of Silver Bullet setup.
- If stronger reasoning is needed, configure that in the host runtime or the delegated tool that owns execution.
- Treat model choice as an external runtime concern; treat workflow ordering, gates, artifacts, and traceability as Silver Bullet concerns.
