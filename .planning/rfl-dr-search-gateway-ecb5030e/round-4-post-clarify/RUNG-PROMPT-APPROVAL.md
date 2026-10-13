# Policy E — rung-prompt approval

**Run:** [round-4-post-clarify](./ROUND.md)  
**Status:** `approved: yes`  
**Written:** 2026-08-30T17:35:00Z  
**Approved:** 2026-08-30T17:49:00Z (user edits)

## Key tasks (5–12 bullets) — approved with edits

- **Artifact:** review [`dr_search_gateway_prd_ecb5030e.plan.md`](/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md) **only**. Do not attach or require the clarify brief or the agent-reach research note. Clarify decisions are already in the plan. Not SB plugin source unless the plan cites a broken contract.
- **Bird’s-eye:** missed alternative strategies/architectures, missed perspectives, outside-the-box improvements.
- **Ant’s-eye:** flaws, gaps, inconsistencies, clap `--x` vs `-p xweb`, catalog vs tests, fleet/cache/quota, X union cascade, consent/init, ToS vs unpaid HTTP, agent-reach non-goals.
- **Findings:** raw only — ID, `file:line` or heading+quote, HIGH|MED|LOW|NIT. Residual-only vs [ISSUE-LEDGER.md](ISSUE-LEDGER.md) (do not re-report ledger rows). File the full pack; CLEAN only if nothing valid remains. Reviewer does **not** ACCEPT/REJECT.
- **No lock-keeping in reviewer briefs.** Do not tell reviewers to KEEP REJECT or “do not unwind X/xweb/search-cli.” They may flag those decisions as findings. Launcher asks the user before applying an ACCEPT that would unwind a prior product decision.
- **Out of scope for reviewer:** triage, APPLY, verify, plan edits, commits, branch switches, implementing Rust/search-cli, launching nested subagents.
- **Verify (launcher, not reviewer):** Composer 2.5 High native Cursor Task (`composer-2.5` / `sb-composer-2-5-high`); not Fast; not Grok 4.5 High; not Pi. Verifies are **not** Policy F streaks.
- **Policy F (launcher, not reviewer):** a streak is a CLEAN review (zero ACCEPT findings) on this rung. Two consecutive CLEAN review streaks before the next model. ACCEPT-apply resets the streak and re-reviews the same model.
- **Host/model:** GLM 5.2 High parent-spawn on Cursor; then Kimi / Gemini / Grok Cursor Tasks; rungs 5–8 stay Pi Codex/Claude. Cursor-family models never via Omni.
- **Scope lock:** the plan file + this round dir (ladder artifacts). Graphify CLI first; save via agentmemory. No git branch switch.
