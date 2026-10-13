# Review charter — DR search gateway plan (round 4)

## Scope (locked) — reviewer

1. [`/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md`](/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md) — **only** review target
2. [`.planning/rfl-dr-search-gateway-ecb5030e/round-4-post-clarify/`](./) — ladder artifacts (ledger, write `review.md` here)

**FORBIDDEN** for reviewers: clarify brief, agent-reach research note, SB plugin source (unless the plan cites a broken contract), implementing `alo-exp/search-cli` / Rust, git branch switch.

## Goals (reviewer-facing)

1. The plan is internally consistent and implementable as written.
2. **Bird’s-eye:** missed alternative strategies/architectures, missed perspectives, outside-the-box improvements.
3. **Ant’s-eye:** flaws, gaps, inconsistencies, clap collisions (`--x` vs `-p xweb`), catalog vs tests, fleet/cache/quota, X union cascade, consent/init, ToS vs unpaid HTTP, agent-reach non-goals.
4. Findings have `file:line` (or heading + quote) and severity HIGH / MED / LOW / NIT.

## Non-goals (reviewer)

- Implementing the fork or SB orchestrator
- Re-running Round 1–3 / MiniMax
- Repo-wide SB plugin audit
- Triage, APPLY, or verify
- Nested subagents

## Launcher-only (not reviewer prompt text)

If an ACCEPT would unwind a prior product decision (runtime = search-cli fork; X must-search union; no twitter/opencli/bird/Chrome/Nitter/google.com scrape), **ask the user** (`decision_class: locked`). Do not put KEEP REJECT / “do not unwind” in reviewer briefs.

**Policy F (launcher):** a streak is a CLEAN **review** (zero ACCEPT-worthy findings), not a verify pass. Same rung needs two consecutive CLEAN review streaks before the next model. After ACCEPT-apply, streak resets to 0 and the same reviewer re-reviews. `verify_1` and `verify_2` still run; they do not count as streaks.

## Verification signals (orchestrator)

After each verify pass, from repo root:

```bash
PLAN="/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md"
test -f "$PLAN"
grep -nE "must_search|xweb|-p x| --x |Nitter|agent-reach|twitter|opencli|bird|site:x.com|clap|--providers|SEARCH_CACHE_DIR|SEARCH_QUOTA_DIR|consent|ToS" "$PLAN" | head -80
```

Pass = plan exists and grep returns hits. Fail = missing file or APPLY dropped phrases still required by an applied finding.
