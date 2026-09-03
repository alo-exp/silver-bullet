# Handoff — Round 4 post-clarify RFL (next session)

Copy the **Prompt** block into a new chat that is rooted on the **main checkout**. Do not reopen worktree `ewwf` if it has been removed.

## State

- **Plan (canonical; may be outside git):** `/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md`
- **Round:** `.planning/rfl-dr-search-gateway-ecb5030e/round-4-post-clarify/`
- **Work from main:** `/Users/shafqat/projects/silver-bullet/repo` (confirm with `git worktree list`). Do **not** reopen worktree `ewwf` if removed.
- **Freeze SHA (re-hash the plan before any action):** `f6ba43bb7d7d4d4ca394333ae5f7c15022059040edac9ec75585654630584cd6`
- **Commit SHA (RFL artifacts on feature branch `cursor/c7ad820b`):** `04de855ef6919315fef215f20fb8dd841c6e3f61`
- **Main SHA (after local land):** `ec54642697e064030ba68d37fd687692194b79ea`
- **Rung 1 CLOSED:** Cursor GLM 5.2 High, 2/2 CLEAN pack, SHA `916d87f52b25688f7953c76c89b96802d9438eb8da537a8c16b927b98b2ee138` (historical)
- **Rung 2 CLOSED:** Cursor Kimi K3 High (`kimi-k3-high` / `sb-kimi-k3-high`), Policy F 2/2 CLEAN (pass 6 + pass 7) on unchanged SHA `f6ba43bb…`. Last review pass: **7**. Last SHA: `f6ba43bb7d7d4d4ca394333ae5f7c15022059040edac9ec75585654630584cd6`
- **Ledger IDs:** I-1 … I-64 (all ACCEPT / resolved at the freeze SHA)
- **Verify override:** Composer 2.5 High (`composer-2.5` / `sb-composer-2-5-high`), not Fast, not Grok 4.5
- **Remaining rungs (do not skip):**
  3 cursor `gemini-3.7-flash-high`
  4 cursor `cursor-grok-4.6-high`
  5 **pi** `gpt-5.6-sol-high` (Codex/Pi, not Cursor Task)
  6 **pi** `gpt-5.6-sol-xhigh`
  7 **pi** `claude-opus-5-high`
  8 **pi** `claude-opus-5-xhigh`
- **Policy F:** 2 consecutive CLEAN **reviews** per rung on unchanged SHA; verifies after APPLY do not count as streaks
- **Policy G pack-ledger mandatory:** encoder `--issue-ledger` + `--write-review-brief`; all severities including nits; pack-APPLY; one-ID residual-only is **wrong**
- **Product locks:** ask user before APPLY that unwinds X-must-search / xweb / search-cli-only gateway
- Graphify CLI retrieval; agentmemory save; no Fast; no Grok 4.6 XHigh as default; RFL verify is Composer 2.5 High this ladder
- Checkpoint stop after each review/APPLY so the parent chat gets Policy C
- No search-cli/Rust implementation unless a later user message says so
- No silent git branch switch

## Prompt

```
You are continuing Round 4 post-clarify RFL from main. Start at rung 3.

You are the RFL parent/launcher (not the reviewer). Work from the main checkout at /Users/shafqat/projects/silver-bullet/repo (confirm with `git worktree list`). Do not reopen worktree ewwf if it was removed.

Canonical plan (reviewer corpus = this file ONLY):
  /Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md
Round dir:
  .planning/rfl-dr-search-gateway-ecb5030e/round-4-post-clarify/
Skill: skills/silver-review-fix-ladder/SKILL.md Policy G (pack-ledger).

First action (before any Task):
1. Graphify CLI: `graphify query "review-fix-ladder Policy G pack-ledger encoder"` (not Graphify MCP query_graph).
2. agentmemory `memory_save` that you resumed from HANDOFF-NEXT-SESSION.md on main.
3. Re-hash the plan: `shasum -a 256 /Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md`
   Required freeze: f6ba43bb7d7d4d4ca394333ae5f7c15022059040edac9ec75585654630584cd6
   If drifted, STOP.
4. Refresh the encoder brief (redirect stdout; do not handwrite briefs):
   python3 scripts/review-fix-ladder.py --issue-ledger --run-dir .planning/rfl-dr-search-gateway-ecb5030e/round-4-post-clarify
   python3 scripts/review-fix-ladder.py --write-review-brief --run-dir .planning/rfl-dr-search-gateway-ecb5030e/round-4-post-clarify
   Write the brief to:
   .planning/rfl-dr-search-gateway-ecb5030e/round-4-post-clarify/rung-03-cursor-gemini-3.7-flash-high/brief-review.md
5. Launch rung 3 only: native Cursor Task model gemini-3.7-flash-high / subagent_type sb-gemini-3-7-flash-high.
   Residual-only Policy G pack. Do not re-report I-1…I-64. File all valid new residuals, all severities including nits.
   Artifact: …/rung-03-cursor-gemini-3.7-flash-high/review.md (or review-pass-1.md).

Encoder / close commands you will need later:
  python3 scripts/review-fix-ladder.py --write-policy-c --rung-dir <rung-dir> --table-json-file <payload.json>
  python3 scripts/review-fix-ladder.py --assert-policy-c --rung-dir <rung-dir>
  python3 scripts/review-fix-ladder.py --record-rung-review-outcome clean|accept-apply --run-dir .planning/rfl-dr-search-gateway-ecb5030e/round-4-post-clarify

State you inherit:
- Rung 1 CLOSED: Cursor GLM 5.2 High, 2/2 CLEAN, SHA 916d87f52b25688f7953c76c89b96802d9438eb8da537a8c16b927b98b2ee138
- Rung 2 CLOSED: Cursor Kimi K3 High, 2/2 CLEAN (pass 6 + pass 7), SHA f6ba43bb7d7d4d4ca394333ae5f7c15022059040edac9ec75585654630584cd6
- Ledger through I-64
- Verify override: Composer 2.5 High (composer-2.5 / sb-composer-2-5-high). Not Fast. Not Grok 4.5. Not Pi.
- Remaining after this hop: 4 cursor-grok-4.6-high; 5 pi gpt-5.6-sol-high; 6 pi gpt-5.6-sol-xhigh; 7 pi claude-opus-5-high; 8 pi claude-opus-5-xhigh. Do not skip. Rungs 5–8 are Pi, not Cursor Task.

Hard rules:
- Policy F: 2 consecutive CLEAN reviews per rung on unchanged SHA. Verifies after APPLY do not count as streaks.
- Policy G: encoder --issue-ledger + --write-review-brief; all severities including nits; pack-APPLY; one-ID residual-only is wrong.
- Product locks (launcher-only — do not paste into reviewer briefs): one search-cli fork gateway; X must-search = official -p x + unpaid -p xweb + xAI -p xai + dedicated Serper site:x.com; no exec twitter/opencli/bird, no Chrome fleet, no Nitter, no scrape google.com; Facebook must_search: false. HOLD APPLY that would unwind X-must-search / xweb / search-cli-only — ask the user first.
- Graphify CLI retrieval; agentmemory save; no Fast; no Grok 4.6 XHigh as unspecified default.
- Checkpoint stop after each review/APPLY so the parent chat gets Policy C.
- No search-cli/Rust implementation unless a later user message says so.
- No silent git branch switch. No push unless asked.

Stop conditions:
- After the Gemini review artifact exists: write Policy C via encoder, record clean|accept-apply, STOP for parent Policy C. Do not start rung 4 in the same hop.
- If ACCEPT would unwind X locks: HOLD and ask the user.
- If the plan hash drifted: STOP.
```
