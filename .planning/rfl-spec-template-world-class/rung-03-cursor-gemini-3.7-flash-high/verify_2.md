# verify_2 — Rung 03 (Cursor Gemini 3.7 Flash High)

**Verifier:** Grok 4.5 High (`cursor-grok-4.5-high` / `sb-grok-4-5-high`), native Cursor Task only.  
**Role:** RFL verify_2 (independent falsify/confirm of reviewer findings). Not verify_1. Not Reviewer. No APPLY. No branch switch. No commit.  
**Date:** 2026-08-29.  
**Review under test:** [`.planning/rfl-spec-template-world-class/rung-03-cursor-gemini-3.7-flash-high/review.md`](review.md)  
**Claim:** **NOT CLEAN** (1 HIGH / 2 MED / 2 LOW — R3-F01…R3-F05).  
**Independence:** Re-hashed freeze twins; re-read Wave 2/3 + catalog + REQUIREMENTS shapes from scratch; re-checked live `review-spec` QC-7, `review-cross-artifact` QC-1 Step 4, and `silver-spec` Step 1; did not treat verify_1 verdicts as authority.

## Freeze integrity

```
shasum -a 256 .planning/spec_template_world_class.plan.md
d05755cb838f7143f5f922d8d2e8823e2ef215b56522801902d5179a66188989
```

| Check | Result |
|-------|--------|
| Expected SHA-256 | `d05755cb838f7143f5f922d8d2e8823e2ef215b56522801902d5179a66188989` |
| Live freeze | **MATCH** |
| Twin [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../spec-template-world-class/phases/01-world-class-spec/PLAN.md) | **MATCH** same SHA; `diff -q` identical (`wc -l` → 650 lines each) |
| Reviewer / verify_1 freeze claim | Correct |

**STOP condition:** not triggered.

## Method

- Graphify first: `graphify query "spec_template_world_class R3-F01 QC-7 UX Flows review-cross-artifact NFR silver-spec Step 1"`.
- agentmemory `memory_save` at start + on verdict.
- Independent checks against freeze SHA only (post rung-02 APPLY):
  - Frontmatter `figma-url` (L120, L132) vs catalog `ux` forbidden (L225–L232)
  - Wave 2 review-spec Work (L398) QC matrix — QC-7 absent
  - REQUIREMENTS NFR table / Coverage Matrix (L267–L271) vs live XART Step 4
  - Wave 3 Work steps listed (L426–L431) — no Step 1
  - Wave 2 `rg` snippet (L406) vs assert prose (L409)
  - Forbidden-heading ISSUE text (L145, L241, L398) vs assigned `SPEC-F*` codes
- Did not rewrite freeze. Did not APPLY. Did not triage Policy C. Did not mutate twins.

## Per-finding verdicts (independent)

### R3-F01 — HIGH — `review-spec` QC-7 kind-blind vs UX-forbidden kinds when Figma provided — **CONFIRMED**

| Claim | Live evidence (own quotes) |
|-------|----------------------------|
| Live QC-7 demands `## UX Flows` + Figma ref → `SPEC-F61` | [`skills/review-spec/SKILL.md`](../../../skills/review-spec/SKILL.md) QC-7: `If Figma URL provided: Verify that ## UX Flows references the design… emit ISSUE finding SPEC-F61` |
| `figma-url` remains core frontmatter (not kind-gated) | Freeze **L120**: Keep includes `figma-url`; **L132**: stays allowed-empty |
| `ux` forbidden on non-UX kinds | Catalog **L225–L232**: `http-api`, `cli`, `library-sdk`, `data-ml`, `infra-devops`, `headless-service` forbid `ux` |
| Present forbidden heading = ISSUE | Ontology **L145**; QC **L241**; Wave 2 **L398**: `Forbidden heading present = ISSUE` |
| Wave 2 never retargets QC-7 | Wave 2 Work **L398–L400**: updates QC-1 / QC-6 / QC-6b / QC-8–11 — **no** `QC-7` / `figma` / `SPEC-F61` |

**Precision (does not dispute):** live QC-7 evaluates when `source_inputs` is non-empty (skill QC-7 gate), not solely when YAML `figma-url` is set; the dual-fail still holds whenever a Figma URL is supplied as a source input on a UX-forbidden kind. Impossible omit-UX→`SPEC-F61` vs add-UX→forbidden QC-1 ISSUE. HIGH / template-contract stands. Not invented.

### R3-F02 — MED — `review-cross-artifact` QC-1 Step 4 orphans all `NFR-nn` (`XART-F02`) — **CONFIRMED**

| Claim | Live evidence (own quotes) |
|-------|----------------------------|
| Live Step 4 orphans any requirement without AC join | [`skills/review-cross-artifact/SKILL.md`](../../../skills/review-cross-artifact/SKILL.md) QC-1 Step 4: `For EACH requirement in REQUIREMENTS.md: verify it traces back to a SPEC AC… emit ISSUE finding XART-F02` |
| NFR table has **no** `AC` column | Freeze **L268**: `## Non-Functional Requirements` — `\| ID \| Requirement \| Metric \| Priority \|` |
| Coverage Matrix is AC→REQ only | Freeze **L271**: `\| AC \| REQ \| Notes \|` — every `AC-nn` once |
| NFR provenance is QA/packs/scan, not AC | Freeze **L268**: from Quality Attributes / kind NFR packs / scanned NF concerns; **L183**: `QA-nn` → `NFR-nn` |
| Wave 2 XART work does not exempt NFR | Freeze **L400**: `Parse **AC-nn** / ### AC-nn; REQ from \| REQ-nn \|. Coverage Matrix before fuzzy text` — no Step-4 NFR carve-out |

Every compiled NFR-bearing REQUIREMENTS (including nfr-required kinds) would false-positive under current Step 4. MED stands. Not invented.

### R3-F03 — MED — `silver-spec` Step 1 domain mapping kind-blind; Wave 3 omits Step 1 — **CONFIRMED**

| Claim | Live evidence (own quotes) |
|-------|----------------------------|
| Live Step 1 hard-maps UX + folds Edges/Errors/Data into UX/AC/OQ | [`skills/silver-spec/SKILL.md`](../../../skills/silver-spec/SKILL.md) Step 1 table: `UX Flows / main path → ## UX Flows`; `Edges / Errors / Data → UX Flows, AC, and/or Open Questions as appropriate` — no Security/Telemetry/API/CLI/Mobile/Pipeline/Operations/Examples/QA/Decision Log rows |
| Wave 3 Work names Steps 0, 2, 3, 7, 8 — **not** Step 1 | Freeze **L426–L431**: Step 2, Step 3, Step 7, Step 8, Step 7a/8a, Step 0 — zero “Step 1” |
| Same defect class as omitted Step 3 (R1-F02) | Freeze inherited pin **L420**: R1-F02 was Step 3 kind-aware; Step 1 left untouched is the parallel gap |

Kind-blind routing would destroy structured Errors/Data packs and leave no contract for the other domain turns Clarify captures. MED stands. Not invented.

### R3-F04 — LOW — Wave 2 verify `rg` omits QC-9/10, SPEC-F71/72, REQ-F70 — **CONFIRMED**

| Claim | Live evidence (own quotes) |
|-------|----------------------------|
| Snippet regex jumps QC-8→QC-11 and SPEC-F70→SPEC-F73 | Freeze **L406**: `rg -n "QC-8\|QC-11\|SPEC-F70\|SPEC-F73|…"` |
| Assert prose names the omitted codes | Freeze **L409**: assert `REQ-F70`, QC-10 Change History, QC-11 Invariants, etc. |

Snippet-to-description divergence only; LOW correct. Not invented.

### R3-F05 — LOW — No finding code for present forbidden heading under QC-1 — **CONFIRMED**

| Claim | Live evidence (own quotes) |
|-------|----------------------------|
| Present forbidden = ISSUE, no `SPEC-F*` assigned | Freeze **L145**, **L241**, Wave 2 **L398**: `Forbidden heading present = ISSUE` — no code |
| Neighboring faults do get codes | Freeze **L398**: QC-8→`SPEC-F70`, QC-9→`SPEC-F71`, QC-10→`SPEC-F72`, QC-11→`SPEC-F73` |

Implementers / string tests lack a pinned ID for the forbidden-present path. LOW / assign-or-reuse stands. Not invented.

## Reviewer meta-checks

| Check | Result |
|-------|--------|
| Freeze SHA | Correct (`d05755cb…88989`) |
| Twin PLAN byte-identical | Correct |
| Invented findings | **None** — all five grounded in freeze + cited live skill text |
| Severity dump | Fit evidence: 1 HIGH / 2 MED / 2 LOW; F01 correctly elevated as impossible dual-fail |
| NOT CLEAN | **Sustained** — F01 alone blocks clean; F02/F03 leave Wave 2/3 underdetermined for NFR join and Step 1 routing |
| KEEP REJECT respected | **Yes** — two files; Clarify does not write SPEC; ingest stays; no third kind canonical; OOS/Open Items on REQUIREMENTS; UX Flows not universal QC-1. No KEEP REJECT violation |

## Parent triage cross-check (ACCEPT candidates)

| ID | Parent | verify_2 | APPLY proceed? |
|----|--------|----------|----------------|
| R3-F01 | ACCEPT | **CONFIRMED** | Yes |
| R3-F02 | ACCEPT | **CONFIRMED** | Yes |
| R3-F03 | ACCEPT | **CONFIRMED** | Yes |
| R3-F04 | ACCEPT | **CONFIRMED** | Yes |
| R3-F05 | ACCEPT | **CONFIRMED** | Yes |

**APPLY may proceed on all five ACCEPTs** after Policy C encode (this worker does **not** APPLY).

## Overall verdict

**verify_2 PASS** (findings confirmed; reviewer’s **NOT CLEAN** stands)

Independent of verify_1: R3-F01…R3-F05 are real against freeze SHA `d05755cb838f7143f5f922d8d2e8823e2ef215b56522801902d5179a66188989`. Reviewer did not invent issues, did not mis-hash the freeze, did not violate KEEP REJECT, and did not dump severity incorrectly. No REJECT / dispute. FAIL ids: *(none)*.

## Appendix — SHA

```
d05755cb838f7143f5f922d8d2e8823e2ef215b56522801902d5179a66188989  .planning/spec_template_world_class.plan.md
d05755cb838f7143f5f922d8d2e8823e2ef215b56522801902d5179a66188989  .planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md
```
