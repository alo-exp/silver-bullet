# ISSUE-LEDGER — router subagent surfaces freeze (`85bf9f09`) final RFL

Compiler of launcher triage. Plan copies **not** edited in Policy D. No product IDs invented.

**Freeze:** `.planning/router_subagent_surfaces_85bf9f09.plan.md` + `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md`
**SHA:** `d5343ac14c24c23930140ffe39d34dea5ab799fde2e8f200571c5086131029e0` / 621095
**Sources:** `rung-*/review.md`, verify reports, parent-launched official matrix, [`POLICY-D.md`](POLICY-D.md), [`LADDER.md`](LADDER.md).

Ignore stale `SKIPPED.md` / SHA `07b98609…`. ID collisions: later CLEAN rungs cite F-1/F-2 as HOLD/REJECT leftovers, not new filings.

| ID | Sev | Summary | Reported by | Accepted? | Addressed? |
|----|-----|---------|-------------|-----------|------------|
| F-01 | HIGH | AM-first / K/L lock existed in four drifted copies | r1 MiniMax (Grok sub) | yes | yes (r1 APPLY; SHA later superseded) |
| F-02 | MED | Broken TOC anchor for `/sb:agent-*` cwd heading | r1 | yes | yes |
| F-03 | MED | Appendix C inventory incomplete vs Appendix B / §5.4 | r1 | yes | yes |
| F-04 | MED | VAL/TST-RFL preserve ranges contradicted freeze IDs | r1 | yes | yes |
| F-05 | MED | GST-01 helper lacked YAML todo / workstream banner | r1 | yes | yes |
| F-06 | LOW | WS1 and WS3 omitted Part A prereq banner | r1 | yes | yes |
| F-07 | NIT | GFM auto-suffix TOC links for duplicate headings | r1 | yes | yes |
| F-08 | NIT | Duplicate `#### VAL/TST-RFL-*` headings | r1 | yes | yes |
| L-1 | LOW | Truncated heading (mid-sentence) | r2 DeepSeek (Pi) | yes | yes (r2 APPLY; SHA later superseded) |
| L-2 | LOW | Truncated heading (mid-clause) | r2 | yes | yes |
| L-3 | LOW | Truncated heading (hook enum cut off) | r2 | yes | yes |
| N-1 | NIT | Empty stub `blocked_launch_prompt_spec` | r2 | yes | yes |
| N-2 | NIT | Empty stub `blocked_knowledge_preread` | r2 | yes | yes |
| N-3 | NIT | Empty stub `blocked_plan_of_action_review` | r2 | yes | yes |
| N-4 | NIT | Empty stub `VAL/TST-RFL-626 (WS3)` | r2 | yes | yes |
| N-5 | NIT | TOC asymmetry for specified-risks heading | r2 | yes | yes |
| N-6 | NIT | LS-*/KR-* not individually listed in TOC | r2 | **no (REJECT)** | n/a — canonical-catalog design |
| N-7 | NIT | Duplicate non-TOC `####` heading texts | r2 | yes | yes |
| F-1 | MED | 20 unique broken GFM anchors needing `--` | r3 Qwen (Pi) | **no (REJECT)** | n/a — github-slugger is single hyphen; `ws0--ws0b` stays 0 |
| F-2 | NIT | Row-number tag style at L3246 | r3 | yes (HOLD) | HOLD — keep `#### \`blocked_advisor_state\` (row 14)` |

Rungs 4–11: CLEAN, 0 new findings.

Residual: F-2 HOLD only (by design). Freeze implementation **not** executed.
