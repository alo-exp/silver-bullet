# Triage — rung 1 GLM 5.2 High (review pass 13)

| ID | Sev | Decision | Why |
|----|-----|----------|-----|
| AB1 | LOW | ACCEPT | Missing §3 test for locked X-union dedup (I-1 behavior; test was never added). No lock unwind. |
| AB2 | NIT | ACCEPT | `--cache-ttl` is a locked Phase 1 ADD; clap help test omitted it. |
| AB3 | NIT | ACCEPT | I-23 no-stampede invariant has no dedicated §6.12 assertion. |
| AB4 | NIT | ACCEPT | I-10 future-`qN_*` lock has no `q4_*` fixture in §6.12 `clear()`. |

Disposition: ACCEPT-apply. Streak stays 0.
