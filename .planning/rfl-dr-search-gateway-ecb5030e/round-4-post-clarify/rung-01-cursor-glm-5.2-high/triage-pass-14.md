# Triage — rung 1 GLM 5.2 High (review pass 14)

| ID | Sev | Decision | Why |
|----|-----|----------|-----|
| AC1 | NIT | ACCEPT | §6.12 `clear()` omitted locked `last.json.tmp.*` fixture. No lock unwind. |
| AC2 | NIT | ACCEPT | `cache_clear_busy` omitted reddit lock held/absent (I-25). No lock unwind. |
| AC3 | NIT | ACCEPT | Token-endpoint must not consume reddit search bucket; untested. No lock unwind. |

Disposition: ACCEPT-apply. Streak stays 0.
