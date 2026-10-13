# Triage — rung 1 GLM 5.2 High (review pass 8)

All seven residuals ACCEPT. None unwind X-must-search / xweb / search-cli-only.

| ID | Sev | Decision | Why |
|----|-----|----------|-----|
| W1 | MED | ACCEPT | Normative clash; operative default is `~/.config/silver-bullet/search-quota/` |
| W2 | LOW | ACCEPT | Field order required for golden-vector parity |
| W3 | LOW | ACCEPT | Canonicalize SearchOpts before augment_query |
| W4 | LOW | ACCEPT | Double-check TTL under lock |
| W5 | LOW | ACCEPT | Drift-guard for clap values list |
| W6 | NIT | ACCEPT | Absent reddit lock is unlockable |
| W7 | NIT | ACCEPT | Brave acquire test |

Disposition: ACCEPT-apply. Streak stays 0.
