# Claude + OpenCode Go — Omni fill-first (drain until exhausted)

User cancelled the `2026-08-28T15:41Z` wait. Expired Omni row **Claude (local OAuth)** was deleted. Claude and OpenCode Go traffic goes through Pi → OmniRoute (`127.0.0.1:20128`).

**Account strategy is `fill-first`, not round-robin.** Round-robin splits traffic while both accounts are healthy. That is not the intended pool behavior.

Confirmed in Omni dashboard 2026-08-29:

| Provider | Dashboard | Accounts | Account strategy |
|---|---|---|---|
| Claude | `http://127.0.0.1:20128/dashboard/providers/claude` | 2 connected | **fill-first** |
| OpenCode Go | `http://127.0.0.1:20128/dashboard/providers/opencode-go` | 2 connected | **fill-first** |

## How fill-first works

1. Omni uses **only the first account in the dashboard list** until that account’s quota is exhausted (or the account errors).
2. Then it uses the **next** account in the pool.
3. When that one exhausts, Omni can return to an earlier account whose quota window has **reset**.

Pool order is the Connections list (top first). Use **Reorder** if the top account is not the intended drain-first account.

## Claude pool (list order)

| Order | Account | Role |
|---|---|---|
| 1 | `shafqat@sourcevo.com` | Drain first until exhausted |
| 2 | `shafqat.ullah@gmail.com` | Used only after #1 is exhausted |

## OpenCode Go pool

Two connected accounts, same **fill-first** drain. Only one account is used at a time until it exhausts.

## Applies to (Claude rungs)

| N | Host | Model | Action |
|---|------|-------|--------|
| 7 | Pi `/silver:agent-pi` | `claude/claude-opus-5-high` | Done. **Do not wait** for a 5-hour window. |
| 8 | Pi `/silver:agent-pi` | `claude/claude-opus-5-xhigh` | Sequential after rung 7. |

## Policy

- **Do not** `substitute_grok` / remap to `cursor-grok-4.6-high`.
- If Omni still 429s on **both** Claude accounts after retry-once, classify + schedule — still not Grok.
- Do **not** use `scripts/agent-claude/invoke.sh` for these rungs (bypasses Omni fill-first).
- Launch as `pi -p --provider omniroute --model claude/claude-opus-5-{high|xhigh}` (Pi catalog ids). `scripts/agent-pi/invoke.sh` pins MiMo and would wrong-model.

## Verify

Verify remains native Cursor Grok 4.5 High (`cursor-grok-4.5-high` / `sb-grok-4-5-high`). Never Pi/Omni for verify.
