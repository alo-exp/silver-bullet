You are on rung 6/11: model=cursor/gemini-3.7-flash-high (Gemini 3.7 Flash High via `/silver:agent-pi` / OmniRoute).
Phase: REVIEW-ONLY (rung_06_review)

This is `/silver:review-fix-ladder` only. Do **not** run `/silver:clarify`. Do not write clarifications.md. Do not AskQuestion. Do not encode product forks.

Scope (do not exceed — FORBIDDEN to touch any other path):
- `/Users/shafqat/projects/silver-bullet/repo/.planning/router_subagent_surfaces_85bf9f09.plan.md`
- `/Users/shafqat/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md`

Independently re-hash both copies. Disk wins.
- Charter start SHA: `07b986094e983d39fe3c7d2f1ac215ae730cbd28ccf3957655f5ec4c53d3280a` / 620985 bytes (historical; do not treat as current)
- Current disk SHA (rung 5 closed; both copies byte-identical): `d5343ac14c24c23930140ffe39d34dea5ab799fde2e8f200571c5086131029e0` / 621095 bytes
Record the SHA you actually hashed. Do **not** use stale brief SHA `07b98609…` / 620985 as current. Existing `review.md` / `verify-1.md` / `verify-2.md` hashed that stale SHA — overwrite `review.md` with a fresh official review of `d5343ac1…` / 621095. Do not copy stale findings blindly.

Review charter:
- Goals: freeze completeness/consistency; closed locks intact (KEEP REJECT, Q1–Q3, Part A then Part B, no /sb:multi-ai-task, no sb:agent-wrap even as alias, FAST not a Job / not a legal compose route, OmniRoute routing-only); YAML 33 todos pending; broken refs / truncated headings / TOC-GFM / LS-post-val-kl Executor producer / FAST short-order E→Ver→Val+thin capture / single mermaid.
- TOC-GFM algorithm (HARD, F-1 REJECT from rung 3): strip punctuation then collapse whitespace to a **single** hyphen. Do **not** demand `--` for ` / ` ` → ` ` — `. The slug `ws0--ws0b` must stay `0` (do not invent a double-hyphen miss). You may file a *new* TOC/body miss only if it fails **that** algorithm.
- Closed / do not reopen as product forks: KEEP REJECT / Q1–Q3 / Part A then Part B; F-1 (Qwen double-hyphen GFM) REJECT; F-2 HOLD at L3246 `#### \`blocked_advisor_state\` (row 14)`.
- Non-goals: product implementation; executing YAML todos; clarify encode; reopening locked decisions; git checkout/commit.
- Verification signals: sha256 both copies; 33 pending todos; forbid-only multi-ai-task and agent-wrap; FAST not a Job; one mermaid; closed KEEP REJECT / Q1–Q3 / Part A then Part B.

Template A (HARD):
1. Graphify query before exploration. agentmemory memory_save session notes. Retrieve via Graphify not memory dumps.
2. Report raw findings with line references and severity (HIGH / MED / LOW / NIT).
3. Verdict CLEAN or NOT CLEAN.
- Do NOT triage (parent triages Policy A).
- Do NOT fix / Edit / Write the freeze copies.
- Do NOT launch further subagents.
- Do NOT expand scope.

Part A then Part B. Non-goals: implement product, execute YAML, reopen KEEP REJECT/Q1–Q3, clarify, repo-wide.

Tasks:
1. Audit the freeze against the charter. Full independent re-read.
2. Report raw findings with line references and severity (HIGH / MED / LOW / NIT).
3. Write the report ONLY to this ABSOLUTE path (must exist after you finish):
   `/Users/shafqat/projects/silver-bullet/repo/.planning/rfl-router-subagent-surfaces-85bf9f09-final-review/rung-06-cursor-gemini-3.7-flash-high/review.md`
4. Do NOT classify ACCEPT/REJECT, file issues, or apply fixes.
5. MUST NOT Edit/Write either freeze copy.

The review.md MUST include:
- SHA-256 you hashed for each copy, sizes, byte-identical yes/no (must be `d5343ac1…` / 621095, not `07b98609…`)
- Findings list with line refs + severity
- Finding counts by HIGH / MED / LOW / NIT
- Verdict: CLEAN or NOT CLEAN

FORBIDDEN:
- `/silver:clarify`, clarifications.md, AskQuestion
- Triage or fix
- Claiming PASS or advancing the ladder
- Checkout/switch/commit
- Remapping to a different model
- Treating stale review.md / verify-*.md as completing this rung
- Substituting Grok (Pi worker must be cursor/gemini-3.7-flash-high; launcher substitute is a separate policy after two Pi failures)
