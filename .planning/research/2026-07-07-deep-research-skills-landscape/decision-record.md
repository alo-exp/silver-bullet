# AF-DECIDE — Decision Record

## Decision

Adopt the **feature-matrix-ranked top 10** as the SB reference landscape for deep-research skill benchmarking (July 2026). Primary external benchmarks for capability gaps:

1. **Socialpranker/claude-deep-research** — catalogs, adversarial, runtime verify
2. **199-biotechnologies/claude-deep-research-skill** — validation scripts (already upstream of SB)
3. **hoolulu/deep-research** — multilingual + multi-agent assembly
4. **blessonism/openclaw-search-skills** — intent-aware multi-provider search

## Alternatives considered

| Alternative | Why not primary |
|-------------|-----------------|
| Rank by GitHub stars | Refuted — Weizhena #1 stars but #6 features [C007] |
| Rank skills.sh installs only | API unavailable [C009] |
| Include last30days-skill | Social synthesis, not phased DR (out of scope) |
| Promote DishantPal to top 10 | Strong philosophy, weak formal validation vs #10 |

## Evidence summary

28 sources, 15 evidence spans, 10 supported claims. See [research_report.md](./research_report.md).

## Tradeoffs & risks

- **Pro:** Feature-grounded ranking resistant to popularity bias
- **Con:** No empirical output comparison across skills
- **Risk:** Fast-moving repos may add phases after 2026-07-07

## Confidence

**High** for documented feature comparisons · **Medium** for cross-skill output quality · **Low** for skills.sh portal ordering

## Remaining gaps

- Live bake-off with identical research question across top 5
- search-cli provider setup for broader web retrieval
- Cursor marketplace-specific DR skill catalog (beyond GitHub)

## Downstream handoff

→ `handoff.md` — implementation research for SB silver-deep-research superset planning
