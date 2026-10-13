# verify_1 — Rung 03 (Cursor Gemini 3.7 Flash High)

**Verifier:** Grok 4.5 High (`cursor-grok-4.5-high` / `sb-grok-4-5-high`), native Cursor Task only.  
**Role:** RFL verify_1 (falsify/confirm reviewer findings). Not Reviewer. No APPLY. No branch switch. No commit.  
**Date:** 2026-08-29.  
**Review under test:** [`.planning/rfl-spec-template-world-class/rung-03-cursor-gemini-3.7-flash-high/review.md`](review.md)  
**Claim:** **NOT CLEAN** (1 HIGH, 2 MED, 2 LOW).

## Freeze integrity

```
shasum -a 256 .planning/spec_template_world_class.plan.md
d05755cb838f7143f5f922d8d2e8823e2ef215b56522801902d5179a66188989
```

| Check | Result |
|-------|--------|
| Expected SHA-256 | `d05755cb838f7143f5f922d8d2e8823e2ef215b56522801902d5179a66188989` |
| Live freeze | **MATCH** |
| Twin [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../spec-template-world-class/phases/01-world-class-spec/PLAN.md) | **MATCH** same SHA; `diff -q` identical (651 lines) |
| Reviewer freeze SHA claim | Correct (not invented) |

**STOP condition:** not triggered. Branch: `main` (no switch).

## Method

- Graphify CLI first (`graphify query` on spec_template_world_class / RFL / QC-7 / NFR orphan / silver-spec domain mapping).
- agentmemory save at start + on verdict.
- Re-checked freeze frontmatter/`figma-url`, catalog forbidden `ux`, Wave 2 QC matrix (QC-7 absence), REQUIREMENTS NFR/Coverage Matrix shapes, Wave 3 Step list (no Step 1), Wave 2 `rg` snippet vs assert names, forbidden-heading finding-code gap — against freeze SHA and cited live skill text only as the plan claims it.
- Did not rewrite freeze. Did not APPLY. Did not implement templates/skills.

## Per-finding verdicts

### R3-F01 — HIGH — `review-spec` QC-7 kind-blind vs UX-forbidden kinds when `figma-url` present — **CONFIRMED**

| Claim | Evidence |
|-------|----------|
| Live QC-7 mandates `## UX Flows` + Figma reference → `SPEC-F61` | [`skills/review-spec/SKILL.md`](../../../skills/review-spec/SKILL.md) QC-7: “If Figma URL provided: Verify that `## UX Flows` references the design… emit ISSUE finding `SPEC-F61`.” |
| `figma-url` is core allowed frontmatter (may be empty, not kind-gated) | Freeze L120 Keep list includes `figma-url`; L132: stays allowed-empty |
| `ux` / `## UX Flows` **forbidden** for cli, http-api, library-sdk, data-ml, infra-devops, headless-service | Catalog L225–L232 Forbidden column lists `ux` for those kinds |
| Present forbidden heading = ISSUE (new compiles) | Ontology L145; QC L241; Wave 2 review-spec L398: “Forbidden heading present = ISSUE” |
| Wave 2 updates QC-1 / QC-6 / QC-6b / QC-8–11 — **not QC-7** | Wave 2 Work L398–L400: no `QC-7` / `figma` / `SPEC-F61` |

Impossible dual-fail on any UX-forbidden kind that carries a non-empty `figma-url` (omit UX → SPEC-F61; add UX → forbidden QC-1 ISSUE). HIGH / template-contract correct. Not invented.

### R3-F02 — MED — `review-cross-artifact` QC-1 Step 4 orphans all `NFR-nn` (`XART-F02`) — **CONFIRMED**

| Claim | Evidence |
|-------|----------|
| Live Step 4: **EACH** requirement must trace to a SPEC AC or be marked derived; else `XART-F02` | [`skills/review-cross-artifact/SKILL.md`](../../../skills/review-cross-artifact/SKILL.md) QC-1 Step 4 (skill L77) |
| REQUIREMENTS NFR table has **no AC column**; Coverage Matrix is AC↔REQ only | Freeze L268 (`\| ID \| Requirement \| Metric \| Priority \|`); L271 (`\| AC \| REQ \| Notes \|`) |
| `NFR-nn` derive from QA/ops/security packs / NF scan — not AC-nn | Freeze L183 (`QA-nn` → `NFR-nn`); L198; L243; L268 |
| Wave 2 XART row scopes REQ parse to `\| REQ-nn \|` + Coverage Matrix, **no** explicit NFR non-join / Step-4 exemption | Freeze L400 |

Live Step 4 will ISSUE every `NFR-nn` without an AC join. Wave 2’s `| REQ-nn |` parse may *accidentally* drop `NFR-nn` from the orphan loop, but the freeze still never defines the NFR↔AC non-join contract — MED stands (ambiguity = template-contract gap). Not invented. Nuance recorded; not a REJECT.

### R3-F03 — MED — `silver-spec` Step 1 domain mapping kind-blind; Wave 3 omits Step 1 — **CONFIRMED**

| Claim | Evidence |
|-------|----------|
| Live Step 1 maps “UX Flows / main path” → `## UX Flows`; “Edges / Errors / Data” → UX Flows, AC, and/or OQ | [`skills/silver-spec/SKILL.md`](../../../skills/silver-spec/SKILL.md) Step 1 table (skill L91, L95); no Security/Telemetry/API/CLI/Mobile/Pipeline/Operations/Examples/QA/Decision Log rows |
| Wave 3 Work names Step 2, Step 3, Step 7, Step 8, Step 7a/8a, Step 0 — **never Step 1** | Freeze L426–L431 |
| Same defect class as R1-F02 (compiler layer residue Wave 3 must name) | Freeze L420 Inherited pin R1-F02 for Step 3; Step 1 still unnamed |

Kind-blind Step 1 misroutes Errors/Data and leaves other Clarify domains unmapped. MED correct. Not invented.

### R3-F04 — LOW — Wave 2 verify `rg` omits QC-9 / QC-10 / SPEC-F71 / SPEC-F72 / REQ-F70 — **CONFIRMED**

| Claim | Evidence |
|-------|----------|
| Verify snippet regex | Freeze L406: `QC-8\|QC-11\|SPEC-F70\|SPEC-F73|…` — jumps QC-8→QC-11 and SPEC-F70→SPEC-F73 |
| Assert description names the omitted codes | Freeze L409: asserts `REQ-F70`, QC-10, QC-11, etc. |

Snippet/description divergence only. LOW correct. Not invented.

### R3-F05 — LOW — No explicit finding code for present forbidden heading under kind-aware QC-1 — **CONFIRMED**

| Claim | Evidence |
|-------|----------|
| Other QC faults mint codes | Wave 2 L398: `SPEC-F70`…`SPEC-F73`, QC-6/6b severity pins |
| Present forbidden = ISSUE **without** an ID | Freeze L241; Wave 2 L398: “Forbidden heading present = ISSUE” — no `SPEC-F0x` |
| Missing required headings use `SPEC-F01` (live / planned) | Live review-spec QC-1 uses `SPEC-F01` for missing sections; freeze does not say whether forbidden reuses it |

Implementer/test ID drift risk. LOW / mint-or-reuse pin appropriate. Not invented.

## Reviewer meta-checks

| Check | Result |
|-------|--------|
| Freeze SHA | Correct (`d05755cb…88989`) |
| Twin PLAN byte-identical | Correct |
| Finding IDs unique | R3-F01…R3-F05 unique |
| Invented findings | None — all five grounded in freeze + cited live skill text the plan claims |
| Wrong severity dump | No — 1 HIGH / 2 MED / 2 LOW fit evidence; F01 correctly HIGH (impossible pass) |
| NOT CLEAN verdict | **Sustained** — F01 alone blocks clean; F02/F03 leave Wave 2/3 contracts underspecified |
| KEEP REJECT | Honored — review reports two files; Clarify does not write SPEC; ingest stays; no third kind canonical; UX Flows not universal QC-1. No KEEP REJECT violation found |
| Review-only | No implement / branch / commit / freeze mutation in review.md |

## Extra issues (verify)

None that change the verdict. Minor: review “~line 384” for Wave 2 is off-by-one hygiene (Wave 2 header is L385; review-spec row L398) — not a false finding.

## Overall verdict

**verify_1 PASS** (findings confirmed; reviewer’s **NOT CLEAN** stands)

All five claimed findings (R3-F01…R3-F05) are real against freeze SHA `d05755cb…88989`. Reviewer did not invent issues, did not mis-hash the freeze, did not violate KEEP REJECT, and did not dump severity incorrectly. No REJECT.

## Appendix — SHA

```
d05755cb838f7143f5f922d8d2e8823e2ef215b56522801902d5179a66188989  .planning/spec_template_world_class.plan.md
d05755cb838f7143f5f922d8d2e8823e2ef215b56522801902d5179a66188989  .planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md
```
