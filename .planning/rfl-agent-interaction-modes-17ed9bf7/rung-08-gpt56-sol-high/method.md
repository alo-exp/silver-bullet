# Rung 8 method — GPT-5.6 Sol High (Codex NI)

- Skill: `~/.codex/skills/silver:agent-codex/SKILL.md` (`/silver:agent-codex`). Repo `skills/silver-agent-codex/SKILL.md` is absent at detached `1569b060`.
- Preferred skill path: `bash scripts/agent-codex/invoke.sh --use-exec` — **file missing** at this SHA. D7 NI = native `codex exec` (same as `--use-exec`).
- Model pin: **GPT-5.6 Sol High** (`-m gpt-5.6-sol -c model_reasoning_effort=high`). Not GPT-5.3. Not Extra High / Max. No Grok/Fast remap.
- Auth: ChatGPT (`codex login status`). Same home as prior GPT-5.3 400 pin-lock.
- Graphify first: CLI `graphify query` (MCP graphify namespace down).
- Agentmemory: HTTP `127.0.0.1:3111/agentmemory/health` → 404; file export under this dir.
- Branch: stay put (detached `1569b060`; no checkout, no commit, plan not edited).
- Nested agents: none.
- Lightweight: native `codex exec`, no PTY/fifo, no AF-AGENT-DELEGATE Task worker.
