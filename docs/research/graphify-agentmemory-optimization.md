# Graphify + agentmemory Optimization Digest

**Profile default:** `synergy_max`  
**Audience:** Silver Bullet init/update/diagnostics implementers  
**Sources:** [graphify](https://github.com/safishamsi/graphify), [agentmemory](https://github.com/rohitg00/agentmemory), `SETUP_REPORT.md`, `agentmemory-stack-setup.md`, `agentmemory-graphify-synergy-audit.md`

## Executive Summary

Multi-agent teams get the best retrieval/capture loop when **agentmemory exports markdown to `.agentmemory/`**, a **git bridge auto-commits** clean exports, and **Graphify re-indexes after export** so `graphify query` surfaces memory nodes alongside code. The `synergy_max` profile enables proactive injection (`AGENTMEMORY_INJECT_CONTEXT=true`), obsidian export, bridge + launchd persistence, Graphify git hooks, `--no-cluster` indexing, and post-export `graphify update`. Token cost is higher than `cost_minimized` but recall and team continuity improve materially.

## Graphify Optimization Checklist

| Knob | synergy_max | Rationale |
|------|-------------|-----------|
| `query --budget 2000` | Yes | SB §2g-i default; caps traversal tokens [SETUP_REPORT, silver-bullet.md] |
| `query_ttl_seconds: 1800` | Yes | Hook freshness gate; 30 min matches session cadence |
| `graphify hook install` | Yes | Auto-rebuild on commit/checkout [graphify README] |
| `graphify update . --no-cluster` | Yes | Faster incremental index; sufficient for memory+code [SETUP_REPORT Step 8.7] |
| Platform always-on | Per host | Cursor `.cursor/rules/graphify.mdc`; Claude hooks; Codex hooks [issue #137] |
| Team `graphify-out/` commit | Optional | Document only — not auto-applied this pass |

**Watch vs hooks:** `graphify watch` suits long dev sessions; git hooks cover commit-driven freshness with lower background CPU. synergy_max prefers hooks; watch is advisory.

**Cursor vs Claude vs Codex:** Cursor uses `graphify cursor install` (rules file, no pre-index skill). Claude/Codex need pre-index skill registration then post-index hook install. Codex needs `multi_agent = true` for parallel extraction.

## agentmemory Optimization Checklist

| Knob | synergy_max | Rationale |
|------|-------------|-----------|
| `AGENTMEMORY_INJECT_CONTEXT=true` | Yes | Proactive injection [#152 integration layer] |
| `AGENTMEMORY_AUTO_COMPRESS=false` | Yes | Cost control until user adds LLM key |
| `OBSIDIAN_AUTO_EXPORT=true` | Yes | Markdown export for Graphify indexing |
| `AGENTMEMORY_EXPORT_ROOT` | **Absolute path** | Relative paths resolve to `~/.agentmemory` when cwd ≠ repo [SETUP_REPORT deviation] |
| Server persistence | launchd (macOS) / systemd (Linux) | `nohup` exits when CLI returns [SETUP_REPORT] |
| Bridge + gitleaks | Bridge required; gitleaks required | Regex scan always; gitleaks second line |
| BM25 floor | ≥0.9.5 | BM25 fix in 0.9.5+ [agentmemory issues] |

## Synergy Index Order

1. Capture via agentmemory MCP/API  
2. `POST /agentmemory/obsidian/export` (or auto-export) → `.agentmemory/memory/`  
3. Bridge commits clean changes  
4. `graphify update . --no-cluster`  
5. `graphify query "<topic>"` must return `.agentmemory` nodes [SETUP_REPORT 8.7]

**Anti-pattern:** Reading raw `.agentmemory/` dumps for orientation when Graphify is enabled — use save-via-agentmemory, retrieve-via-Graphify.

## Platform Matrix

| Surface | Cursor | Claude Code | Codex | OpenCode | Goose (Pi) | Hermes |
|---------|--------|-------------|-------|----------|------------|--------|
| Graphify install | `graphify cursor install` | `graphify install --project` + `graphify claude install --project` | `graphify install --project --platform codex` + `graphify codex install --project` | `graphify install --project --platform opencode` | `graphify install --project --platform pi` | `graphify install --project --platform hermes` |
| agentmemory MCP | `~/.cursor/mcp.json` | `agentmemory connect claude-code` | `agentmemory connect codex --with-hooks` | Manual MCP in `opencode.json` | Manual `connect pi` (TS extension) | Manual `connect hermes` (YAML) |
| Hook strength | SB graphify-gate + rules | Claude settings hooks + skill | Codex hooks.json | `.opencode/plugins/graphify.js` | Pi extension (manual) | AGENTS.md rules only |
| Optimization script | `bash scripts/sb-optimize-stack.sh --apply --host <host>` | same | same | same | same | same |

## gitignore Fix (mandatory)

Use `.agentmemory/*` with `!.agentmemory/memory/**` — not `!.agentmemory/memory/` alone. Without `/**`, `git add` fails and bridge crashes [SETUP_REPORT, runbook Step 3].

## cost_minimized Stub

Future profile: `INJECT_CONTEXT=false`, no bridge launchd, no graphify hooks, relative export root, no gitleaks advisory. Not implemented in optimizer apply path yet.

## References

- `docs/STACK-OPTIMIZATION.md` — SB automation contract  
- `docs/GRAPHIFY.md` — platform registration  
- `docs/AGENTMEMORY.md` — MCP and `.env`  
- `SETUP_REPORT.md` — dogfood evidence on this repo
