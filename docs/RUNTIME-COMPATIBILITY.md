# Runtime Compatibility

Silver Bullet supports multiple host coding-agent environments. The workflow intent is the same across hosts, but model selection belongs to the active host runtime and any delegated tool that owns its own execution.

## Model Selection Boundary

Silver Bullet does not provide generic automatic model routing. The historical `hooks/ensure-model-routing.sh` script is disabled, exits as a no-op, and is not registered as the active mechanism for model choice.

| Surface | Model owner | Silver Bullet responsibility |
|---------|-------------|------------------------------|
| Current Claude, Codex, or Cursor session | User and host configuration | Compose workflow, enforce gates, record skill progress |
| SB orchestrator subagents / Task workers | Host agent configuration | Delegate implementation at the correct lifecycle boundary |
| Optional extension plugins (DevOps, MultAI, connectors) | The invoked plugin/tool and current host session | Sequence only when the SB workflow explicitly calls for them |
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
| 2 | Hook-enforced | PreToolUse/PostToolUse/Stop gates, completion audit, planning guards, **orchestrator parent blocks** | Claude Code CLI, Codex CLI, **Cursor with `~/.cursor/hooks.json` + Task/subagent support** |
| 3 | Live-tested | Release live matrix, e2e-live scenarios, installed-runtime receipts | CI release gates and local live harness |

Tiers are cumulative: tier 2 includes tier 1 behavior; tier 3 assumes tier 2
for release work.

### Tier 0–1 playbook (single-agent / no hooks)

When hooks are absent or tier &lt; 2, Silver Bullet still applies the **same skill order** but without mechanical PreToolUse/Stop enforcement:

1. Run `/silver:init` or `/silver:migrate` so `sb_initiated: true` and workflow docs are present.
2. Route via `/silver` → composer (`silver:feature`, `silver:fast`, etc.).
3. **Invoke each required skill explicitly** through the host skill channel — reading `SKILL.md` does not record state.
4. Follow composer post-execute order: **REVIEW → VERIFY → SECURE → VALIDATE → pre-ship QUALITY GATE → SHIP**.
5. Run `verify-tests` before `gh pr create` / release even without hook blocks.
6. Parent-only orchestrator directive blocks (`orchestrator-directive-guard`) are **inactive** below tier 2 — you may implement inline, but still invoke skills for traceability.

Tier 2+ restores parent-only mode: parent spawns Task workers; cooperative single-agent inline implementation is disabled when directive guard is active.

### Orchestrator parent mode (default)

SB uses **parent-only** orchestration: the parent agent delegates each atomic flow to a **Task worker** (subagent). At tier 2, `orchestrator-directive-guard.sh` blocks parent Edit/Write/Bash; workers implement after recording the assigned skill.

**Cursor requirement:** Tier-2 parent mode needs Cursor's Task/subagent tool and merged hooks. Without subagents, use tier 0–1 guidance-only behavior or migrate hooks per `skills/silver-init/scripts/merge-cursor-hooks.py`. See `docs/ORCHESTRATOR.md`.

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

Host detection follows `hooks/lib/runtime-paths.sh` (`SILVER_BULLET_RUNTIME`, `CURSOR_PLUGIN_ROOT`, `CLAUDE_PLUGIN_ROOT`, Codex env markers). Doctor and diagnostics **do not** infer Cursor from unrelated hosts' config files on the same machine.

### silver:doctor host-scoped checks

| Check | Cursor | Claude | Codex |
|-------|--------|--------|-------|
| D8 `silver-orchestrator.mdc` | FAIL if missing | N/A | N/A |
| D2/D3 plugin cache | `~/.cursor/plugins/...` | `~/.codex/plugins/...` | `~/.codex/plugins/...` |
| D13 contamination | no `.claude/plugins` in Cursor hooks | no `.cursor`/`.codex` paths in Claude settings | no `.cursor`/`.claude` paths in Codex config |

```bash
bash scripts/sb-doctor.sh
SB_DOCTOR_FORMAT=json bash scripts/sb-doctor.sh
```

### Marketplace install surfaces

| Host | Public marketplace | Dev/checkout installer |
|------|-------------------|------------------------|
| Claude Code | [alo-labs/agent-plugins](https://github.com/alo-labs/agent-plugins) (`alo-labs` catalog) | `scripts/install-claude.sh` |
| Codex | [alo-labs/agent-plugins](https://github.com/alo-labs/agent-plugins) (`alo-labs-codex` catalog) | `scripts/install-codex.sh` |
| Cursor | [alo-labs/agent-plugins](https://github.com/alo-labs/agent-plugins) (`alo-labs-cursor` catalog) | `scripts/install-cursor.sh` |

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
- `docs/CODEX-CLOUD.md` — running SB in Codex Cloud (tier 0–1), MCP limits, desktop/cloud split

## Reload receipts and host evidence (Cursor)

Runtime state for five-tool reconciliation lives under `${SB_RUNTIME_STATE}/recommended-tools/` (heartbeats, reload receipts). Paths resolve via `hooks/lib/runtime-paths.sh` — never by probing arbitrary home directories.

| Artifact | Path pattern |
|----------|----------------|
| Heartbeat | `heartbeats/<project-id>/<worktree-id>/<session-id>.json` |
| Reload receipt | `reload-receipts/<host>/<project-id>/<worktree-id>/<receipt-id>.json` |
| Host-global receipt | `reload-receipts/<host>/_host-global/_host-global/<receipt-id>.json` |

Skills supply host MCP attestation on stdin (`--host-evidence-stdin`) immediately after real tool calls. Attestations convey liveness only — not consent or repair authorization. Canonical `ready` requires no active receipt and full activation.
