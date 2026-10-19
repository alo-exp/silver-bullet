Review complete. Output written to `skills/multi-ai-task/rules/review-self-260627.md`.

**Summary:** Score **8/16** with medium confidence.

**Top 5 findings:**
1. **7+ conflict resolution rules are referenced but undefined** — `most-severe`, `majority-with-uncertain`, `concatenate-all`, etc. appear in examples/custom strategies but have no algorithm definitions anywhere
2. **No machine-readable pipeline manifest** — the 4-phase pipeline exists only as prose; scores 1/2 on "Catalog of composable units"
3. **Retry policy is contradictory** — methodology says "no retries", dispatch-mechanics says "retry"
4. **`--mode thorough` is undefined** — described in 4 words across the entire spec with no algorithmic specification
5. **Dispatch layer is entirely OpenCode-coupled** — Mechanism 4 (the only portable option) gets 6 lines of Python while OpenCode-specific tricks get 130+ lines
