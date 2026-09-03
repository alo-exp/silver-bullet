# Resolved ladder (user mapping wins)

Resolver `python3 scripts/review-fix-ladder.py --host cursor --json` returned Cursor composer-2.5 / grok-4.5 only (`source=cursor_sb_agents`). **User mapping overrides.** Fast forbidden. No remap of GPT/Claude/OpenCode/Gemini to Grok Medium.

| # | Host | Model | Effort | Method |
|---|------|-------|--------|--------|
| 1 | OpenCode | MiniMax M3 | High | `/silver:agent-opencode` NI (`opencode run -m opencode-go/minimax-m3 --variant high`) |
| 2 | OpenCode | DeepSeek V4 Pro | Max | `/silver:agent-opencode` NI |
| 3 | OpenCode | Qwen3.8 | XHigh | `/silver:agent-opencode` NI |
| 4 | OpenCode | GLM 5.3 | Max | `/silver:agent-opencode` NI |
| 5 | OpenCode | Kimi K3 | Max | `/silver:agent-opencode` NI |
| 6 | Cursor Task | Gemini 3.7 Flash | High | Task `model: "gemini-3.7-flash-high"` |
| 7 | Cursor Task | Grok 4.6 | High | Task `model: "inherit"` if `cursor-grok-4.6-high` unavailable; never `*-fast*` |
| 8 | Codex | GPT-5.6 Sol | High | `/silver:agent-codex` NI |
| 9 | Codex | GPT-5.6 Sol | XHigh | `/silver:agent-codex` NI |
| 10 | Claude | Opus 5 | High | `/silver:agent-claude` NI |
| 11 | Claude | Opus 5 | XHigh | `/silver:agent-claude` NI |
| 12 | Claude | Fable 5 | High | `/silver:agent-claude` NI |
| 13 | Claude | Fable 5 | XHigh | `/silver:agent-claude` NI |

Per-rung states: `review` → `triage` (host model) → `file_valid_issues` → `fix` (host model) → `verify_1` → orchestrator greps → `verify_2` → orchestrator greps.

This coordinator is Grok 4.6 (parent/host model for triage+fix). Review/verify use the rung host/model.
