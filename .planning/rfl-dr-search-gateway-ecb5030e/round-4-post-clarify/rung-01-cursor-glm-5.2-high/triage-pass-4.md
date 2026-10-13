# Triage — rung 1 GLM 5.2 High (review pass 4)

Policy A: ACCEPT if not wrong. S1 does not unwind product locks.

| ID | Sev | Decision | Why |
|----|-----|----------|-----|
| S1 | LOW | ACCEPT | M-4 “fleet never passes `--allow-private`” only covers fleet-as-writer. Human `--allow-private --cache-dir "$SEARCH_CACHE_DIR"` can poison fleet `q3_` hits. Not a duplicate of I-6 (`last.json` write clobber). |

Disposition: ACCEPT-apply. Policy F streak resets to 0.
