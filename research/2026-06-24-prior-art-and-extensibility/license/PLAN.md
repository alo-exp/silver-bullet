# Phase 2: PLAN — Research Strategy

## Knowledge Dependencies

```
[Foundation]
 ├─ OSI Open Source Definition
 ├─ Source-available vs open source distinction
 ├─ SPDX license list
        ↓
[License Inventory]
 ├─ PolyForm Noncommercial 1.0.0  ★ PRIMARY CANDIDATE
 ├─ PolyForm Strict 1.0.0
 ├─ PolyForm Internal Use 1.0.0
 ├─ PolyForm Free Trial 1.0.0
 ├─ Business Source License (BUSL) 1.1
 ├─ Server Side Public License (SSPL) v1
 ├─ Elastic License v2
 ├─ Functional Source License (FSL) — Functional Software, Inc.
 ├─ Fair Source License
 ├─ Hippocratic License 2.1
 ├─ Parity Public License 7.0.0
 ├─ Commons Clause (deprecated, historical)
 └─ Cryptographic Autonomy License 1.0
        ↓
[Legal & Enforceability]
 ├─ Heather Meeker's analysis
 ├─ Artifex Software v. HashiCorp ruling (BUSL enforceability)
 ├─ OSI commentary on each
 └─ SPDX approval status
        ↓
[Adoption Signal]
 ├─ HashiCorp (BUSL → BSL post-2023 relicense)
 ├─ MongoDB (SSPL adoption)
 ├─ Elastic (Elastic License)
 ├─ Sentry (BSL → Fair Source)
 └─ PolyForm adopters
        ↓
[Recommendation]
```

## Search Queries (Decomposed)

**Q1 — Definition & landscape:**
- "source-available license non-commercial" OSI stance
- "source available vs open source" definition
- SPDX "non-commercial" license list

**Q2 — PolyForm family:**
- polyformproject.org/licenses/noncommercial
- polyformproject.org/licenses/strict
- polyformproject.org/licenses/internal-use
- polyformproject.org/licenses/free-trial

**Q3 — BUSL / SSPL / Elastic:**
- BUSL 1.1 full text
- MariaDB BSL commentary
- SSPL v1 MongoDB
- Elastic License v2 text

**Q4 — Other source-available:**
- Fair Source License (fair.io)
- Functional Source License (Sentry)
- Hippocratic License MIT + ethics
- Parity License 7.0

**Q5 — Enforceability & legal:**
- Artifex v. HashiCorp ruling
- Heather Meeker blog PolyForm
- OSI approval status each license

**Q6 — Adoption:**
- "HashiCorp BSL adoption 2023"
- "MongoDB SSPL adoption"
- "Sentry Fair Source"
- "PolyForm license adopters"

## Parallel Execution Plan

Run all retrievals as concurrent fetches via `ctx_fetch_and_index` with concurrency 6.

- Batch 1: 8 URL fetches covering all primary license texts (PolyForm x4, BUSL, SSPL, Elastic, FSL)
- Batch 2: 6 URL fetches covering legal analyses (Heather Meeker blog, Artifex ruling, OSI commentary, SPDX, adoption blogs)
- Batch 3 (gap-fill): 4 URL fetches as needed

## Quality Gate (UltraDeep)

- 30+ sources OR 15 minutes elapsed
- Average source credibility > 75/100
- Each license claim has 3+ independent citations
- Direct quote from canonical text for each license (not just summaries)

## Triangulation Strategy

For each major claim (e.g., "PolyForm Noncommercial prohibits Commercial Use"), require:
- Canonical license text (polyformproject.org)
- At least one attorney or analyst commentary
- At least one adoption example or case

## Time Budget

- Phase 1 SCOPE: 5 min ✓
- Phase 2 PLAN: 5 min (this file)
- Phase 3 RETRIEVE: 15 min (3 parallel batches)
- Phase 4 TRIANGULATE: 5 min
- Phase 4.5 OUTLINE: 3 min
- Phase 5 SYNTHESIZE: 30 min (progressive section writes)
- Phase 6 CRITIQUE: 8 min
- Phase 7 REFINE: 10 min
- Phase 8 PACKAGE: 15 min
- HTML/PDF rendering: 10 min

Total: ~100 min — comfortable margin for ultradeep.
