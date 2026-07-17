# Stack Optimization (Graphify + agentmemory)

Default profile: **`synergy_max`**.

## Global setup (SB-independent — primary for Claude, Codex, OpenCode, Goose, Hermes)

Machine-level wiring does **not** require Silver Bullet, `/silver:init`, `.silver-bullet.json`, or SB hooks:

```bash
bash scripts/graphify-am-global-setup.sh --host claude --apply
bash scripts/graphify-am-global-setup.sh --host codex --verify
bash scripts/graphify-am-global-setup.sh --host all --verify    # detected hosts only
bash scripts/graphify-am-global-setup.sh --host claude --apply --repo /path/to/project
```

| Deliverable | Path |
|-------------|------|
| Global setup script | `scripts/graphify-am-global-setup.sh` |
| Implementation lib | `hooks/lib/graphify-am-global.sh` |
| Platform matrix | `docs/graphify-am/PLATFORM-MATRIX.md` |
| Per-agent verification | `docs/graphify-am/verification/<host>-verify-graphify-am.md` |

Without `--repo`, `AGENTMEMORY_EXPORT_ROOT` defaults to `~/.agentmemory/default-export`. Pass `--repo` for per-project export, bridge launchd, and optional `graphify update`.

Silver Bullet **may delegate** to global setup during `/silver:init` Step 3f, then run project-level `sb-optimize-stack.sh` when the user has opted in.

## When SB optimization runs

| Trigger | Command |
|---------|---------|
| `/silver:init` §1.1a/§1.1b Step 3f | `bash scripts/sb-optimize-stack.sh --apply` |
| `/silver:update` Step 8d | same (idempotent re-apply) |
| Manual | `bash scripts/sb-optimize-stack.sh --apply` |
| Verify only | `bash scripts/sb-optimize-stack.sh --verify` |
| Report | `bash scripts/sb-optimize-stack.sh --report` |
| Synergy audit | `bash scripts/sb-verify-synergy.sh [--write-setup-report]` |
| Diagnostics | `bash scripts/sb-diagnostics.sh` (`optimize-*` checks) |

## synergy_max profile

Configured in `.silver-bullet.json` under `optimization_profiles.synergy_max`:

| Area | Applies |
|------|---------|
| **Graphify** | `graphify hook install`, platform always-on artifacts, `graphify update . --no-cluster`, query budget 2000, TTL 1800s |
| **agentmemory** | Merge `~/.agentmemory/.env` (chmod 600, backup `.env.bak`), absolute `AGENTMEMORY_EXPORT_ROOT`, `INJECT_CONTEXT=true`, obsidian export, bridge flags |
| **Persistence** | macOS launchd `com.agentmemory.server` + `com.agentmemory.bridge`; Linux systemd user units when available |
| **Project** | `.agentmemory/memory/**` scaffold, gitignore `/**` negation fix |
| **Synergy** | Obsidian export trigger + post-export `graphify update`; verify graph contains `.agentmemory` refs |
| **gitleaks** | Required with bridge — `brew install gitleaks` (macOS) or apt on Linux; `GITLEAKS_PATH` in bridge launchd plist |

## Consent and safety

- Optimization runs only when `recommended_tools.graphify.enabled_by_user` and/or `recommended_tools.agentmemory.enabled_by_user` is `true`.
- `.env` merge preserves user keys outside the SB managed block; backs up to `.env.bak`.
- Host-level hooks and launchd are **skipped** when `CI=true`.
- `INJECT_CONTEXT=true` increases token usage — document tradeoff; use future `cost_minimized` profile to reduce.

## Scoring

`sb_optimization_score` returns 0–100:

| Score | Verdict |
|-------|---------|
| ≥85, 0 fails | OPTIMAL |
| ≥60, 0 fails | ACCEPTABLE |
| else | NEEDS_WORK |

Critical failures (exit non-zero on `--verify` when opted in): missing CLI, index, server health, synergy graph refs.

Warnings (non-blocking): missing git hooks, bridge, gitleaks (when required), launchd.

## Platform matrix

| Host | Graphify | agentmemory | Artifact paths |
|------|----------|-------------|----------------|
| Cursor | `graphify cursor install` → `.cursor/rules/graphify.mdc` | MCP in `~/.cursor/mcp.json` | Full `connect` support |
| Claude | `graphify install --project` + `graphify claude install --project` | `agentmemory connect claude-code` | `~/.claude.json` |
| Codex | `graphify install --project --platform codex` + `graphify codex install --project` | `agentmemory connect codex --with-hooks` | `~/.codex/config.toml` |
| OpenCode | `graphify install --project --platform opencode` | **Manual MCP** in `~/.config/opencode/opencode.json` | No `connect opencode` subcommand |
| Goose (Pi) | `graphify install --project --platform pi` | **Manual** `agentmemory connect pi` (TS extension) | `~/.config/goose/config.yaml`, `.pi/agent/` |
| Hermes | `graphify install --project --platform hermes` | **Manual** `agentmemory connect hermes` (YAML merge) | `~/.hermes/config.yaml`, `AGENTS.md` rules |

Apply per host: `SILVER_BULLET_RUNTIME=<host> bash scripts/sb-optimize-stack.sh --apply --host <host>`

Verification addenda: `docs/graphify-am/verification/<host>-verify-graphify-am.md`

## Verification addendum mapping

Phase checks from `agentmemory-graphify-synergy-audit.md` map to optimizer score lines:

| Audit phase | Optimizer check |
|-------------|-----------------|
| Server health | `agentmemory-server` |
| Bridge commits | `agentmemory-bridge` |
| Graphify indexes memory | `synergy-index` |
| MCP wiring | `graphify-platform`, `agentmemory` platform checks in diagnostics |
| Proactive injection | Manual (Step 8.6) — not automated |

## Research traceability

Every optimization step traces to `docs/research/graphify-agentmemory-optimization.md` (ultradeep digest) and dogfood evidence in `SETUP_REPORT.md`.

## Related

- `docs/GRAPHIFY.md` — Graphify optimization section
- `docs/AGENTMEMORY.md` — synergy_max `.env` template
- `docs/code-intelligence-contract.md` — tier-1 optimization requirement
- `hooks/lib/stack-optimizer.sh` — implementation

## Five-tool stack optimization (RTK + Context Mode + LeanCTX)

When LeanCTX is opted in, use the orchestrator script instead of `optimize-rtk-context-mode.sh` alone:

```bash
bash scripts/optimize-five-tool-stack.sh --host cursor --project-root "$(pwd)"
```

For RTK + Context Mode only (no LeanCTX):

```bash
bash scripts/optimize-rtk-context-mode.sh --host cursor --project-root "$(pwd)"
```

Both scripts require explicit `--host` and `--project-root` (canonical SB project root).

## Five-tool reconciliation and reload receipts

`/silver:init`, `/silver:update`, installer reconciliation, and `/silver:doctor --fix` delegate to `scripts/reconcile-recommended-tools.sh`. Host MCP/hook writes batch into one reload receipt per worktree (or linked host-global receipt for pure host scope). SessionStart is verification-only: it may verify receipts but never creates, clears, or supersedes them.

Regenerate runtime plugin mirrors after script/hook changes:

```bash
bash scripts/sync-runtime-mirrors.sh
bash tests/scripts/test-runtime-mirror-freshness.sh
```
