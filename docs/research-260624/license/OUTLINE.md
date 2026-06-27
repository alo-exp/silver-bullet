# Phase 4.5: OUTLINE REFINEMENT

## Initial Outline (Phase 2)

1. Definitions
2. License inventory
3. Freedom comparison
4. Monetization restriction analysis
5. Enforceability
6. Adoption signal
7. Recommendation

## Evidence-Driven Refinements

After Phase 3-4, evidence suggests:

- **Add a dedicated Finding on the Heather Meeker authority** — she is the single attorney behind 5+ of the top source-available licenses, which strengthens the legitimacy of the PolyForm recommendation.
- **The user's "no monetization" requirement has TWO sub-flavors**: (a) "I want to retain all monetization rights" — this maps to PolyForm Noncommercial (blocks anyone else from monetizing, preserves internal business use); (b) "I also want to block a competitor from offering this as a SaaS" — this maps to PolyForm Strict or Elastic License v2. The report must distinguish these.
- **BUSL 1.1's 4-year conversion is an advantage or disadvantage depending on use case** — for some users, eventual full open-source release is desirable; for the user's stated needs, it creates friction.
- **SSPL is materially over-restrictive** — Section 13 requires disclosure of unrelated infrastructure, making it impossible for SaaS shops to use. This is a key finding for the user.
- **FSL and Elastic License v2 are narrower but designed specifically for the SaaS case** — if the user's "no monetization" specifically means "no SaaS resale," Elastic v2 may be a better fit than PolyForm Noncommercial.

## Refined Outline

```
1. Executive Summary
2. Introduction
3. Finding 1 — The Source-Available Landscape and What "No Monetization" Means
4. Finding 2 — PolyForm Noncommercial 1.0.0: The Primary Recommendation
5. Finding 3 — PolyForm Strict 1.0.0: The Anti-SaaS Extension
6. Finding 4 — BUSL 1.1: Time-Delayed Open Source
7. Finding 5 — SSPL v1: Why Overreach Fails the User's Needs
8. Finding 6 — Elastic License 2.0: Narrow SaaS Carve-Out
9. Finding 7 — FSL: The Fair Source SaaS Alternative
10. Finding 8 — Adjacent Licenses (Hippocratic, Parity) and Why They Don't Fit
11. Finding 9 — Enforceability and Legal Foundation
12. Synthesis & Insights
13. Limitations & Caveats
14. Recommendations
15. Bibliography
16. Methodology Appendix
```

## Why these adaptations

- **Finding 1 sets up the definitional axis** — without it, the rest of the report is hard to navigate.
- **Finding 2-3 are the headline recommendation pair** — PolyForm Noncommercial for the broad case, PolyForm Strict for the SaaS case.
- **Finding 4-5 explain why other "obvious" source-available licenses are wrong fits** — BUSL has time-delayed conversion (extra friction), SSPL requires disclosure of unrelated infrastructure (overreach).
- **Finding 6-7 are narrower alternatives** for users whose no-monetization is specifically about SaaS.
- **Finding 8 prevents the user from wandering into adjacent but wrong-fit licenses** (Hippocratic ethics, Parity share-alike).
- **Finding 9 grounds the recommendation in legal reality** (Heather Meeker's authority, 17 U.S.C. § 106).

## Gaps Identified

- No actual court ruling text retrieved (Artifex v. HashiCorp) — captured via Wikipedia summary; acknowledged in Limitations.
- No detailed PolyForm adopter list — only Warrant.dev referenced indirectly; acknowledged in Limitations.
- The specific text of PolyForm Strict's "Competing Use" definition is paraphrased rather than verbatim (the strict page returned a similar structure but the exact clause was inferred).
