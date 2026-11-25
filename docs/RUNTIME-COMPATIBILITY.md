# Runtime Compatibility

Silver Bullet supports multiple host coding-agent environments. The workflow intent is the same across hosts, but model selection belongs to the active host runtime and any delegated tool that owns its own execution.

## Model Selection Boundary

Silver Bullet does not provide generic automatic model routing. An earlier model-routing hook (`ensure-model-routing.sh`) has been removed, and no hook registered in `hooks/hooks.json` selects models.

| Surface | Model owner | Silver Bullet responsibility |
|---------|-------------|------------------------------|
| Current Claude or Codex session | User and host configuration | Compose workflow, enforce gates, record skill progress |
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
| 2 | Hook-enforced | PreToolUse/PostToolUse/Stop gates, completion audit, planning guards; **orchestrator parent blocks on Claude Code only** (Codex: inactive until the host identifies workers in hook payloads) | Claude Code CLI, Codex CLI |
| 3 | Live-tested | Release live matrix, e2e-live scenarios, installed-runtime receipts | CI release gates and local live harness |

Tiers are cumulative: tier 2 includes tier 1 behavior; tier 3 assumes tier 2
for release work.

### Tier 0–1 playbook (single-agent / no hooks)

When hooks are absent or tier &lt; 2, Silver Bullet still applies the **same skill order** but without mechanical PreToolUse/Stop enforcement:

1. Run `/sb:init` or `/sb:migrate` so `sb_initiated: true` and workflow docs are present.
2. Route via `/sb` → composer (`sb:feature`, `sb:fast`, etc.).
3. **Invoke each required skill explicitly** through the host skill channel — reading `SKILL.md` does not record state.
4. Follow composer post-execute order: **REVIEW → VERIFY → SECURE → VALIDATE → pre-ship QUALITY GATE → SHIP**.
5. Run `verify-tests` before `gh pr create` / release even without hook blocks.
6. Parent-only orchestrator directive blocks (`orchestrator-directive-guard`) are **inactive** below tier 2 — you may implement inline, but still invoke skills for traceability.

On Claude Code, tier 2 restores parent-only mode: the parent spawns Task workers and cooperative single-agent inline implementation is disabled while the directive guard is active. Codex has no worker identity in its hook payloads, so there the parent cannot be told from a worker and parent mode is inactive (the planning floor and delivery gates still apply); `SB_ORCHESTRATOR_PARENT=1` forces it on.

### Orchestrator parent mode (default on Claude Code)

On Claude Code SB uses **parent-only** orchestration: the parent agent delegates each atomic flow to a **Task worker** (subagent). At tier 2, `orchestrator-directive-guard.sh` blocks parent Edit/Write/Bash; workers implement after recording the assigned skill. On Codex this is inactive because the host does not identify workers (see [ORCHESTRATOR.md](ORCHESTRATOR.md#worker-identity)).

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
state root, inferred runtime name, and capability tier. The scripts take no runtime
argument; set `SILVER_BULLET_RUNTIME` to check a specific host.

Host detection follows `hooks/lib/runtime-paths.sh`: `SILVER_BULLET_RUNTIME` when set, otherwise Codex env markers (including a `CLAUDE_PLUGIN_ROOT` that contains `/.codex/`), `PI_CODING_AGENT_DIR` or a `/.pi/` script path, OpenCode markers, defaulting to `claude`. Accepted runtime names are `claude`, `codex`, `opencode`, `pi`, `goose` and `hermes`; each has its own state root (`~/.claude`, `~/.codex`, `~/.config/opencode`, `~/.pi/agent`, `~/.config/goose`, `~/.hermes`). **Goose and Hermes are never auto-detected**: without `SILVER_BULLET_RUNTIME=goose` (or `hermes`) they fall back to `claude` and their state lands under `~/.claude/.silver-bullet`. Doctor and diagnostics **do not** infer a host from unrelated hosts' config files on the same machine. Cursor is no longer a supported host; `scripts/uninstall-cursor-legacy.sh` removes what an older install left under `~/.cursor`.

### sb:doctor host-scoped checks

| Check | Claude | Codex |
|-------|--------|-------|
| D2/D3 plugin cache | `~/.claude/plugins/...` | `~/.codex/plugins/...` |
| D13 contamination | no `.codex` paths in Claude settings | no `.claude` paths in Codex config |

```bash
bash scripts/sb-doctor.sh
SB_DOCTOR_FORMAT=json bash scripts/sb-doctor.sh
```

### Marketplace install surfaces

| Host | Public marketplace | Dev/checkout installer |
|------|-------------------|------------------------|
| Claude Code | [alo-labs/agent-plugins](https://github.com/alo-labs/agent-plugins) (`alo-labs` catalog) | `scripts/install-claude.sh` |
| Codex | [alo-labs/agent-plugins](https://github.com/alo-labs/agent-plugins) (`alo-labs-codex` catalog) | `scripts/install-codex.sh` |

Release prep runs `scripts/sync-release-marketplace-versions.sh <version>` to
align the in-repo marketplace manifests with `.claude-plugin/plugin.json` /
`plugins/silver-bullet/.codex-plugin/plugin.json`; once
the release tag is pushed and green, `--publish <version>` updates the unified
marketplace ([RELEASE.md](RELEASE.md#8-publish-the-unified-marketplace)).


### Project instruction files

| Host | Typical filename | Notes |
|------|------------------|-------|
| Claude Code | `CLAUDE.md` | Optional; reconciled in place by `sb:init` |
| Codex | `AGENTS.md` | Optional; not created by default on fresh Codex init |

The project instruction skeleton is `scripts/lib/install-claude/templates/CLAUDE.md.base`; Silver Bullet's own rules live in `silver-bullet.md`, not in the instruction file.

### Host hooks manifests

| Host | Global hooks manifest | Hook merge script |
|------|----------------------|-------------------|
| Claude Code | Plugin-delivered hooks (`hooks/hooks.json`); `${SB_RUNTIME_HOME_ROOT}/settings.json` only for manual installs | `scripts/lib/install-claude/merge-hooks.py` (also reachable through the `skills/silver-init/scripts/merge-hooks.py` shim): with the plugin installed it removes SB's settings copies, which would run every hook twice; otherwise it registers every (event, matcher, command) |
| Codex | Plugin-delivered hooks (optional user merge) | `scripts/install-codex.sh`, which routes hook commands through `hooks/codex-hook-adapter.sh` |

Project-scoped legacy v1 hook entries may appear in `.claude/settings.json` or `.codex/settings.json`; `sb:init` removes incompatible v1 entries when found.

### Skill invocation channels

| Host | Supported channels |
|------|-------------------|
| Claude Code | `PostToolUse/Skill` (host skill events) |
| Codex | `silver-bullet invoke-skill <name>` adapter (hook-validated receipt) |

### Related Docs

- `silver-bullet.md` §11 — hook protocol and SDK workarounds
- `docs/code-intelligence-contract.md` — code-intelligence tiers (separate from runtime tiers)
- `skills/silver-init/SKILL.md` — project bootstrap and runtime probe
- `docs/CODEX-CLOUD.md` — running SB in Codex Cloud (tier 0–1), MCP limits, desktop/cloud split

## Reload receipts and host evidence

Runtime state for five-tool reconciliation lives under `${SB_RUNTIME_STATE_DIR}/recommended-tools/` (heartbeats, reload receipts). Paths resolve via `hooks/lib/runtime-paths.sh` — never by probing arbitrary home directories.

| Artifact | Path pattern |
|----------|----------------|
| Heartbeat | `heartbeats/<project-id>/<worktree-id>/<session-id>.json` |
| Reload receipt | `reload-receipts/<host>/<project-id>/<worktree-id>/<receipt-id>.json` |
| Host-global receipt | `reload-receipts/<host>/_host-global/_host-global/<receipt-id>.json` |

Skills supply host MCP attestation on stdin (`--host-evidence-stdin`) immediately after real tool calls. Attestations convey liveness only — not consent or repair authorization. Canonical `ready` requires no active receipt and full activation.

### Kay limits

`hooks/kay-project-hook-bridge.sh` maps Kay's native events onto the PreToolUse and PostToolUse hooks only: `tool.before` and `file.before_write` run the PreToolUse hooks (every path of a multi-file write is gated, including the source and destination of a rename or move), `tool.after` and `file.after_write` run PostToolUse. Kay has **no Stop, SubagentStop or UserPromptSubmit gating**: `session.end` runs no hooks, so the Stop planning floor and the prompt-time reminders do not run and those checks are advisory there. `session.start` runs the SessionStart hooks for their side effects only (the branch-scoped state reset); their output and decision are ignored because a bridge cannot inject context or block a session start. Both session events also restore any stale denial locks. The commit, push, PR, deploy and protected-file gates still apply through the tool hooks. A hook that exits 2 (with or without a reason), or that answers `deny`, `block` or `ask` (also after a banner, including pretty-printed JSON), blocks the call; Kay cannot prompt, so `ask` is treated as a block.

Kay's real change schema is not documented in this repository, so the bridge gates a write by the union of every path-like value it finds (keys matched case-insensitively; a `changes` list or an object keyed by path, top-level path keys, nested rename or move objects). A `file.before_write` payload with no recognisable path at all is denied (fail closed). Hooks run under a timeout derived from the `hooks.json` budget (a little below it, as for the Codex adapter) so a hung hook cannot stall a Kay session: a timed-out PreToolUse hook denies the call (fail closed), a timed-out PostToolUse or SessionStart hook does not block. Denial locks are shared per path (the original mode is captured once and restored when the last holder releases; `session.start` and `session.end` restore everything).

### Codex adapter

`hooks/codex-hook-adapter.sh` only reshapes hook output for Codex and enforces the hook's own timeout (the installer passes `--timeout`, a budget a little below each hook's `hooks.json` timeout so the adapter can answer before Codex's own timer fires). It does **not** translate tool names: the installer expands each shell matcher into `Bash`, `shell` and `exec_command` entries. A hook that times out, or is ended by a signal (exit 129 to 159, for example a stray SIGTERM that surfaces as 143) and so produced no verdict, is blocked on PreToolUse, Stop or SubagentStop (fail closed) and only noted elsewhere; set `SB_CODEX_HOOK_ON_TIMEOUT=allow` to opt out. Ordinary hook exit codes (1 to 127) pass through unchanged. If the output transform cannot run, the hook's own output is passed through unchanged, so a deny is never dropped.
