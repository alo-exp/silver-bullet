# Triage — rung 1 GLM 5.2 High (review pass 12)

| ID | Sev | Decision | Why |
|----|-----|----------|-----|
| AA1 | LOW | ACCEPT | Missing §6.12 acquire tests for locked `serper.rs` / `x.rs` paths; not a duplicate of I-26 (brave-only). No lock unwind. |
| AA2 | NIT | ACCEPT | Missing negative test for human-run `cache_ttl_default_300s` exemption. No lock unwind. |

Disposition: ACCEPT-apply. Streak resets to 0.
