# Runtime Compatibility

Silver Bullet supports multiple host coding-agent environments. The workflow intent is the same across hosts, but model selection belongs to the active host runtime and any delegated tool that owns its own execution.

## Model Selection Boundary

Silver Bullet does not provide generic automatic model routing. The historical `hooks/ensure-model-routing.sh` script is disabled, exits as a no-op, and is not registered as the active mechanism for model choice.

| Surface | Model owner | Silver Bullet responsibility |
|---------|-------------|------------------------------|
| Current Claude, Codex, or Cursor session | User and host configuration | Compose workflow, enforce gates, record skill progress |
| GSD subagents or GSD-managed work | GSD and host agent configuration | Delegate to GSD at the correct lifecycle boundary |
| Design, Engineering, Product Management, Superpowers, MultAI | The invoked plugin/tool and current host session | Sequence the helper only when the SB workflow calls for it |
| Hooks and shell helpers | No model selection | Validate state, command intent, and artifact freshness |

## Rules

- Use the active host session model for inline work and user-facing conversation.
- Do not encode Claude model names in Codex instructions, or Codex/OpenAI model names in Claude instructions.
- Do not require `.planning/config.json` `model_profile` fields as part of Silver Bullet setup.
- If stronger reasoning is needed, configure that in the host runtime or the delegated tool that owns execution.
- Treat model choice as an external runtime concern; treat workflow ordering, gates, artifacts, and traceability as Silver Bullet concerns.

## Runtime Capability Tiers

SB documents four capability tiers so users know what enforcement to expect in
each host environment. Run `bash scripts/sb-bootstrap.sh` for onboarding
orientation (jq check, diagnostics, init next steps) or
`bash scripts/sb-diagnostics.sh` for a capability probe only.

| Tier | Name | What works | Typical host |
|------|------|------------|--------------|
| 0 | Guidance-only | Skills, workflows, artifact templates; no hook enforcement | SDK/web sessions without hook config |
| 1 | State-tracked | Skill markers and state file under `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/` | Partial hook delivery or manual skill invocation |
| 2 | Hook-enforced | PreToolUse/PostToolUse/Stop gates, completion audit, planning guards | Claude Code CLI, Codex CLI, Cursor with `~/.cursor/hooks.json` |
| 3 | Live-tested | Release live matrix, e2e-live scenarios, installed-runtime receipts | CI release gates and local live harness |

Tiers are cumulative: tier 2 includes tier 1 behavior; tier 3 assumes tier 2
for release work.

### Diagnostics

```bash
# Onboarding probe (jq, diagnostics, init/migrator next steps)
bash scripts/sb-bootstrap.sh

# Human-readable capability report
bash scripts/sb-diagnostics.sh

# JSON for automation
SB_DIAG_FORMAT=json bash scripts/sb-diagnostics.sh
```

Checks: `jq`, hook config presence, Graphify availability, package version,
state root, inferred runtime name (`claude`, `codex`, or `cursor`), and capability tier.

### Marketplace install surfaces

| Host | Public marketplace | Dev/checkout installer |
|------|-------------------|------------------------|
| Claude Code | [alo-labs/claude-plugins](https://github.com/alo-labs/claude-plugins) | `scripts/install-claude.sh` |
| Codex | [alo-labs/codex-plugins](https://github.com/alo-labs/codex-plugins) | `scripts/install-codex.sh` |
| Cursor | [alo-labs/alo-labs-cursor-marketplace](https://github.com/alo-labs/alo-labs-cursor-marketplace) | `scripts/install-cursor.sh` |

Release prep runs `scripts/sync-release-marketplace-versions.sh <version>` to
keep all three marketplace repos aligned with `.claude-plugin/plugin.json` /
`.cursor-plugin/plugin.json` / `plugins/silver-bullet/.codex-plugin/plugin.json`.

Cursor release smoke (no live agent required): `bash scripts/release-live-matrix-cursor-smoke.sh`.

### Project instruction files

| Host | Typical filename | Notes |
|------|------------------|-------|
| Claude Code | `CLAUDE.md` | Optional; reconciled in place by `silver:init` |
| Codex | `AGENTS.md` | Optional; not created by default on fresh Codex init |
| Cursor | `AGENTS.md` | Optional; same reconciliation rules as Codex |

Template content is host-neutral: `templates/CLAUDE.md.base` (project instruction template).

### Host hooks manifests

| Host | Global hooks manifest | Hook merge script |
|------|----------------------|-------------------|
| Claude Code | `${SB_RUNTIME_HOME_ROOT}/settings.json` | `skills/silver-init/scripts/merge-hooks.py` |
| Codex | Plugin-delivered hooks (optional user merge) | `merge-hooks.py` when user hooks surface is used |
| Cursor | `${SB_RUNTIME_HOME_ROOT}/hooks.json` | `skills/silver-init/scripts/merge-cursor-hooks.py` |

Project-scoped legacy v1 hook entries may appear in `.claude/settings.json` or `.codex/settings.json`; `silver:init` removes incompatible v1 entries when found.

### Skill invocation channels

| Host | Supported channels |
|------|-------------------|
| Claude Code | `PostToolUse/Skill` (host skill events) |
| Codex | `silver-bullet invoke-skill <name>` adapter (hook-validated receipt) |
| Cursor | `PostToolUse/Skill` (Cursor skill channel) or `silver-bullet invoke-skill` |

### Related Docs

- `silver-bullet.md` §11 — hook protocol and SDK workarounds
- `docs/code-intelligence-contract.md` — code-intelligence tiers (separate from runtime tiers)
- `skills/silver-init/SKILL.md` — project bootstrap and runtime probe
