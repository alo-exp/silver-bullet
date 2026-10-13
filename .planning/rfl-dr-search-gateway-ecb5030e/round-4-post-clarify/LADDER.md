# RFL — DR search gateway plan (round 4 post-clarify)

**Run id:** `rfl-dr-search-gateway-ecb5030e-round-4-post-clarify`  
**Target:** [`dr_search_gateway_prd_ecb5030e.plan.md`](/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md) **only** (reviewers do not receive clarify/research).

User-named ladder (host wins). Resolver default Cursor list is **not** used. Reviewer briefs do **not** include KEEP REJECT / lock-keeping text.

| N | Host | Model | Reasoning | Review launch |
|---|------|-------|-----------|---------------|
| 1 | Cursor | glm-5.2 | high | **CLOSED** 2026-08-31 — Policy F 2/2 CLEAN on SHA `916d87f5…` (pass 21 + pass 22). Next: rung 2 Kimi K3 High. |
| 2 | Cursor | kimi-k3 | high | **CLOSED** 2026-09-01 — Policy F 2/2 CLEAN on SHA `f6ba43bb…` (pass 6 + pass 7). Next: rung 3 Gemini 3.7 Flash High. Do not start Gemini from this hop. |
| 3 | Cursor | gemini-3.7-flash | high | `Task` `sb-gemini-3-7-flash-high` / `gemini-3.7-flash-high` |
| 4 | Cursor | grok-4.6 | high | `Task` `sb-grok-4-6-high` / `cursor-grok-4.6-high` |
| 5 | Pi Codex | gpt-5.6-sol | high | `/silver:agent-codex` or `scripts/agent-pi` **Codex** pin — **not** Cursor Task |
| 6 | Pi Codex | gpt-5.6-sol | xhigh | Codex Pi, not Cursor Task |
| 7 | Pi Claude | claude-opus-5 | high | `/silver:agent-claude` / Pi Claude — **not** Cursor Task |
| 8 | Pi Claude | claude-opus-5 | xhigh | Pi Claude, not Cursor Task |

**Policy F streaks:** two consecutive **CLEAN reviews** on the same rung (zero ACCEPT findings). ACCEPT-apply resets the streak to 0 and re-reviews that model. `verify_1` / `verify_2` are a separate gate — they are **not** the two streaks.

**Verify (all rungs, user override):** native Cursor Task **Composer 2.5 High** (`composer-2.5` / `sb-composer-2-5-high`). **Not** Fast (`composer-2.5-fast` forbidden). **Not** Grok 4.5 High despite `rfl-verify-grok-4.5-high.mdc`. **Not** Pi/Omni for Verify.

Nested unspecified workers: `cursor-grok-4.6-high`. Never Fast. Never Grok 4.6 XHigh as unspecified default.

Cursor-family models must **not** go through Omni/agent-pi. GPT/Claude rungs 5–8 are **named Pi** — stay on Pi; quota STOP once then skill fallback. Do not skip a named Pi rung onto a different family except the skill’s documented quota/cannot-launch path.

Unspecified nested default remains Grok 4.6 High. Verify stays Composer 2.5.
