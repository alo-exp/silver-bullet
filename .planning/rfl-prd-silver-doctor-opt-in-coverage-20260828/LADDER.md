# RFL — PRD silver-doctor opt-in coverage

**Run id:** `prd-silver-doctor-opt-in-coverage-20260828`  
**Started:** 2026-08-28  
**Target:** [`.planning/PRD-silver-doctor-opt-in-coverage.md`](../PRD-silver-doctor-opt-in-coverage.md)

User-named ladder (host wins). Resolver default 27-rung Cursor list is **not** used.

| N | Host | Model | Reasoning | Review launch |
|---|------|-------|-----------|---------------|
| 1 | Cursor | glm-5.2 | high | `Task` `sb-glm-5-2-high` / `glm-5.2-high` |
| 2 | Cursor | kimi-k3 | high | `Task` `sb-kimi-k3-high` / `kimi-k3-high` |
| 3 | Cursor | gemini-3.7-flash | high | `Task` `sb-gemini-3-7-flash-high` / `gemini-3.7-flash-high` |
| 4 | Cursor | grok-4.6 | high | `Task` `sb-grok-4-6-high` / `cursor-grok-4.6-high` |
| 5 | Pi (`/silver:agent-pi`) | gpt-5.6-sol | high | `pi -p --provider omniroute --model codex/gpt-5.6-sol-high` (invoke.sh MiMo pin bypass) |
| 6 | Pi | gpt-5.6-sol | xhigh | `pi -p --provider omniroute --model codex/gpt-5.6-sol-xhigh` |
| 7 | Pi | claude-opus-5 | high | `pi -p --provider omniroute --model claude/claude-opus-5-high` — **no wait**; Omni **fill-first** (drain Sourcevo until exhausted, then Gmail). Not Grok. |
| 8 | Pi | claude-opus-5 | xhigh | `pi -p --provider omniroute --model claude/claude-opus-5-xhigh` — after rung 7. |

**Verify (all rungs):** native Cursor Task **Grok 4.5 High** (`cursor-grok-4.5-high` / `sb-grok-4-5-high`) only. Never Pi/Omni for verify. Never Fast. Never Grok 4.6 High for verify.

Launch/timeout: retry once, then skip (`SKIPPED.md`); OpenCode/Pi cannot_launch after retry → substitute Grok 4.6 High. Post-ladder retry skipped rungs once.
