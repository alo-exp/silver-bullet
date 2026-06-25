# Stack Optimization (Graphify + agentmemory)

Silver Bullet applies a **post-install optimization layer** when users opt into Graphify and/or agentmemory. Default profile: **`synergy_max`**.

## When it runs

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
| **Advisory** | `brew install gitleaks` when missing |

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

Warnings (non-blocking): missing git hooks, bridge, gitleaks, launchd.

## Platform matrix

| Host | Graphify | agentmemory |
|------|----------|-------------|
| Cursor | `graphify cursor install` → `.cursor/rules/graphify.mdc` | MCP in `~/.cursor/mcp.json` |
| Claude | `graphify install --project` + `graphify claude install --project` | `agentmemory connect claude-code` |
| Codex | `graphify install --project --platform codex` + `graphify codex install --project` | `agentmemory connect codex --with-hooks` |

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
