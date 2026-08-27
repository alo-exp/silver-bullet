# Rung 8 method

- Skill: `skills/silver-agent-codex/SKILL.md` (`/silver:agent-codex`)
- Preferred path: NI `codex exec` (`--use-exec` / skill NI)
- Model pin: **GPT-5.3 High** (`-m gpt-5.3 -c model_reasoning_effort=high`)
- Same-model slug retry: `-m gpt-5.3-codex` (not a family remap)
- Graphify first: CLI `graphify query` (MCP graphify namespace down)
- Agentmemory: HTTP `127.0.0.1:3111/agentmemory/health` → 404; lean-ctx `ctx_knowledge` used if available
- Branch: `main` (no checkout, no commit, plan not edited)
- Nested agents: none
