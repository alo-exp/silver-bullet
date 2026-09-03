# Triage — rung 1 GLM 5.2 High (review pass 6)

Policy A: ACCEPT if not wrong. Both NITs are rationale/allowlist wording, not product-lock unwind.

| ID | Sev | Decision | Why |
|----|-----|----------|-----|
| U1 | NIT | ACCEPT | “upstream already exposes `--cache-ttl`” is false; flag is a Phase 1 fork ADD. Discriminator stay remains correct. |
| U2 | NIT | ACCEPT | Admission N is orchestrator-side. Fork has no operative `SB_DR_FLEET_SLOTS` use. |

Disposition: ACCEPT-apply. Policy F streak resets to 0.
