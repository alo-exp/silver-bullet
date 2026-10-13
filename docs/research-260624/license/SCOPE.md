# Phase 1: SCOPE — Source-Available License for Maximum Freedom, No Monetization

## Research Question

**What is the best source-available software license that grants users maximum freedom to read, modify, use, and redistribute the software while preventing users from monetizing it (commercial use, paid services, or competitive resale)?**

## Decomposed Sub-Questions

1. **Definitional landscape** — How does "source-available" differ from "open source"? What does "no monetization" actually mean legally (commercial use prohibition, copyleft, no-SaaS clause, ethical clauses)?
2. **Candidate license inventory** — Which licenses match the profile (source-available + non-monetization)? PolyForm variants, BUSL, SSPL, Elastic License, Fair Source, FSL, Hippocratic, Parity, etc.
3. **Freedom comparison** — How permissive is each license on the dimensions of use, modification, redistribution, study, internal business use, patent grants, and aggregation?
4. **Monetization restriction** — How is "no monetization" defined? Does the restriction cover (a) direct sale, (b) SaaS / hosted service, (c) competing services, (d) embedding in paid products?
5. **Enforceability & legal robustness** — What do courts say? Recent rulings (Artifex v. HashiCorp on BUSL enforceability). How have terms held up?
6. **Adoption signal** — Who uses each license in production? Track record.
7. **Recommendation** — Given the tradeoffs, which license best fits "max freedom + no monetization"?

## Stakeholder Perspectives

- **Licensor (creator)** — wants source visible for trust, wants to retain monetization rights, doesn't want resellers or cloud operators capturing the value.
- **End user / integrator** — wants to read code, fix bugs, audit, learn, evaluate, integrate into internal workflows, possibly contribute back.
- **SaaS provider / competitor** — wants to offer the software as a managed service for revenue. This is what we want to block.
- **OSS purist** — views source-available-non-commercial as not "true" open source; relevant for ideological community reception.
- **Legal counsel** — care about clarity, enforceability, and how terms translate to jury instructions.

## Scope Boundaries

**In scope:**
- OSI-approved and non-OSI source-available licenses with any form of monetization restriction (direct, SaaS, or competing service).
- Legal analysis (text, enforceability, court rulings, attorney commentary).
- Adoption cases (named companies using each license).
- Comparison of "freedom dimensions" (use, modification, redistribution, internal use, patent grant).
- SPDX identifiers.

**Out of scope:**
- Pure open-source permissive licenses (MIT, BSD, Apache 2.0, MPL 2.0, GPL/AGPL) — these do not restrict monetization and are well-understood.
- Proprietary EULAs and per-seat commercial licensing (not source-available).
- Creative Commons (designed for content, not source code) except where CC BY-NC has been used on code (rare).
- Public domain dedication / CC0 / Unlicense.
- Cryptographic / hardware restrictions (TARS, BSL on hardware).
- Country-specific software law beyond US/EU enforcement references.

## Success Criteria

A high-quality output will:
- Inventory ≥10 candidate licenses, each with a direct citation to the canonical text.
- For the top 4-6 candidates, perform a freedom-vs-restriction matrix.
- Cite at least one attorney-authored analysis (Heather Meeker is the central figure).
- Cite at least one court ruling on license enforceability where applicable.
- Include SPDX identifiers for each license.
- Recommend a single primary choice plus 1-2 alternatives with explicit rationale.
- Address: what kind of monetization is blocked, what is preserved, what survives modification/redistribution.

## Key Assumptions to Validate

1. **"Source available" ≠ "open source"** — license is publicly readable but does not meet OSI Open Source Definition because of monetization restriction. Validate this with OSI's stance on each license.
2. **"Maximum freedom" means maximum permissible use absent monetization** — internal business use, modification, redistribution, evaluation, study, patent grant, and aggregation are all preserved.
3. **"Monetization" is most commonly restricted via "Commercial Use" definition or via no-SaaS clause** — both patterns must be analyzed.
4. **Enforceability is non-trivial** — particularly US case law on contractual restrictions vs. copyright exhaustion. The Artifex v. HashiCorp ruling (2024-2025) is relevant.
5. **Heather Meeker's family of licenses** (BUSL, SSPL, PolyForm) represents the modern "source-available standard" — primary axis of analysis.

## Deliverables

- `license/SCOPE.md` — this file
- `license/sources.jsonl` — source registry
- `license/evidence.jsonl` — verbatim quotes from sources
- `license/claims.jsonl` — atomic claims
- `license/run_manifest.json` — research run metadata
- `license/research_report.md` — final report
- `license/research_report.html` — McKinsey-style HTML
- `license/research_report.pdf` — print PDF
