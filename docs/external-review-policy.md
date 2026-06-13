# SB External Review Policy

Silver Bullet review is authoritative. Optional external reviewers may enrich
coverage but never replace SB-owned artifacts or hook-backed gates.

## Hard Rules

1. **`silver:review` owns `REVIEW.md`.** Every review pass produces or updates
   this artifact through the active runtime's SB-recognized skill channel.
2. **External findings are supplemental.** They must be merged into `REVIEW.md`
   and triaged by `silver:review-triage`. No parallel review artifact replaces
   `REVIEW.md`.
3. **Hooks and completion audit stay SB-native.** External reviewers do not
   satisfy `required_deploy` skill markers or completion-audit evidence by
   themselves.

## When To Request External Enrichment

| Trigger | Recommended enrichment | Still required |
|---------|------------------------|----------------|
| High blast-radius change (auth, payments, data migration) | Second-opinion reviewer or `silver:benchmark` comparison | `silver:review`, `silver:secure` when applicable |
| Public API or contract change | External API review helper if installed | `silver:domain-audit --pack api-contract` |
| Security-sensitive surface | Authorized `silver:secure` live/static mode | normalized SECURITY findings |
| Release blocker disagreement | Optional adversarial reviewer | `silver:review-triage` resolution in REVIEW.md |
| Routine feature or bugfix | None by default | `silver:review` only |

## When Not To Use External Review

- Trivial or typo-only sessions (trivial bypass applies)
- Steps already covered by artifact reviewers (`review-spec`, `review-plan`, …)
- As a substitute for missing tests, VERIFICATION.md, or UAT evidence
- To bypass SB gate ordering or ship without `silver:review-triage` on BLOCK items

## Normalization

External findings imported into `REVIEW.md` must use the cross-domain evidence
schema in `docs/evidence-schema.md`:

- severity, confidence, evidence pointer, owner workflow, blocking status
- note source as `external-enrichment` in the finding row when helpful

## Related Surfaces

- `silver-bullet.md` §6 — code review ownership
- `skills/silver-review/SKILL.md` — SB review process
- `skills/silver-review-triage/SKILL.md` — finding triage
- `skills/silver-benchmark/SKILL.md` — provider/model comparison evidence
