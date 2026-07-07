# Graphify + agentmemory — Global Platform Matrix

**Profile:** `synergy_max` (see `docs/research/graphify-agentmemory-optimization.md`)  
**Setup script:** `bash scripts/graphify-am-global-setup.sh --host <host> --apply`  
**SB-independent:** no `/silver:init`, no `.silver-bullet.json`, no SB hooks required.

## Global install commands (no `--project`)

| Host | Graphify pre-index | Graphify always-on | agentmemory wiring | Global artifact paths |
|------|-------------------|--------------------|--------------------|------------------------|
| **Claude Code** | `graphify install` | `graphify claude install` | `agentmemory connect claude-code` | `~/.codex/skills/graphify/`, `~/.claude.json` |
| **Codex** | `graphify install --platform codex` | `graphify codex install` | `codex plugin …` + `agentmemory connect codex --with-hooks` | `~/.codex/skills/graphify/`, `~/.codex/config.toml` |
| **OpenCode** | `graphify install --platform opencode` | `graphify opencode install` | **Manual MCP** merge in `~/.config/opencode/opencode.json` | `~/.config/opencode/opencode.json` |
| **Goose (Pi)** | `graphify install --platform pi` | `graphify pi install` | `agentmemory connect pi` | `~/.pi/agent/skills/graphify/`, `~/.config/goose/config.yaml` |
| **Hermes** | `graphify install --platform hermes` | `graphify hermes install` | `agentmemory connect hermes` | `~/.hermes/skills/graphify/`, `~/.hermes/config.yaml` |

## Shared machine-level steps (all hosts)

| Step | Command / path | Notes |
|------|----------------|-------|
| Graphify CLI | `uv tool install graphifyy` or `pipx install graphifyy` | Python 3.10+ |
| agentmemory CLI | `npm install -g @agentmemory/agentmemory` | Node 20+ |
| **gitleaks** | `brew install gitleaks` (macOS) or `apt install gitleaks` (Linux) | Required for bridge second-line secret scan |
| synergy_max `.env` | `~/.agentmemory/.env` | Script merges managed block; chmod 600 |
| Server persistence | macOS: `~/Library/LaunchAgents/com.agentmemory.server.plist` | Linux: systemd user unit (manual) |
| Git hooks | `graphify hook install` | Global git template — new repos inherit |
| Export root (default) | `~/.agentmemory/default-export` | Override with `--repo /path/to/project` |
| Bridge (optional) | `com.agentmemory.bridge` launchd | Only when `--repo` passed and `~/.agentmemory/bridge.py` exists; requires gitleaks on PATH |

## Synergy loop (per project)

1. Capture via agentmemory MCP in the agent UI  
2. Export → `.agentmemory/memory/` (absolute `AGENTMEMORY_EXPORT_ROOT`)  
3. Bridge auto-commits (optional)  
4. `graphify update . --no-cluster`  
5. `graphify query "<topic>"` must return `.agentmemory` nodes  

**Anti-pattern:** reading raw `.agentmemory/` dumps when Graphify is enabled — save via agentmemory, retrieve via Graphify.

## Verification prompts

| Host | Doc |
|------|-----|
| Claude | `docs/graphify-am/verification/claude-verify-graphify-am.md` |
| Codex | `docs/graphify-am/verification/codex-verify-graphify-am.md` |
| OpenCode | `docs/graphify-am/verification/opencode-verify-graphify-am.md` |
| Goose | `docs/graphify-am/verification/goose-verify-graphify-am.md` |
| Hermes | `docs/graphify-am/verification/hermes-verify-graphify-am.md` |

## Silver Bullet integration (optional)

When SB is active in a repo, `/silver:init` Step 3f may **delegate** to global setup, then apply project-level index/gitignore:

```bash
bash scripts/graphify-am-global-setup.sh --host claude --apply --repo .
bash scripts/sb-optimize-stack.sh --apply --host claude
```

SB project optimization still requires `recommended_tools.*.enabled_by_user: true`. Global setup does not.
