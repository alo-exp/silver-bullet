---
verdict: PASS
overturns: n
sha: 364594469c19a7127b93f5d39a01b539a62f407e0a10940b2edab0faa2d05458
role: apply_verify
pass: 13
model: composer-2.5
---

# verify_1 APPLY — Rung 06 Pi Codex GPT-5.6 Sol Extra High — pass 13

**Role:** apply_verify (Composer 2.5) — verify-only; no APPLY, triage, commit, or freeze mutation.  
**APPLY notes:** [`APPLY-rerun-13.md`](APPLY-rerun-13.md)  
**Pre-APPLY verify:** [`verify_1-rerun-13.md`](verify_1-rerun-13.md) — sustained R6m-F01 MED on pre-APPLY pin.

## SHA and twin verification

| Check | Result |
|-------|--------|
| Twin A | `.planning/spec_template_world_class.plan.md` |
| Twin B | `.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md` |
| Pre-APPLY SHA (claimed) | `91652845956169f878a53bb184ccd6e4d4403f03a3e3c9cd803bdf360bf8b5e0` |
| Post-APPLY SHA (independent, both twins) | `364594469c19a7127b93f5d39a01b539a62f407e0a10940b2edab0faa2d05458` |
| Claimed post-APPLY match | **YES** |
| SHA changed from pre-APPLY | **YES** |
| Byte identity (twins) | **YES** — identical SHA-256 on both twins |

## APPLY criterion checks

### 1. SHA / twins

**PASS** — Independent `shasum -a 256` on both twins yields `364594469c19a7127b93f5d39a01b539a62f407e0a10940b2edab0faa2d05458`, matching APPLY claim and differing from pre-APPLY `91652845956169f878a53bb184ccd6e4d4403f03a3e3c9cd803bdf360bf8b5e0`. `diff -q` reports no difference between twins.

### 2. QC-7 two-mode exact-ID (fail closed; legacy-only fuzzy)

**PASS** — Locked-contract row adds normative two-mode QC-7:

```80:80:.planning/spec_template_world_class.plan.md
| review-requirements QC-7 two-mode exact-ID | R6m-F01 | When staged Functional `AC` cells are exact `AC-nn` join keys ... Source Consistency maps by **exact ID** ... Fail closed. Prose fallback **legacy-only**. |
```

Wave 2 `review-requirements` encodes exact-ID for ID-bearing pairs; forbids fuzzy “same observable outcome” on a removed `Acceptance Criterion` column; prose fallback **legacy-only**:

```416:416:.planning/spec_template_world_class.plan.md
| review-requirements | ... **QC-7 two-mode exact-ID (R6m-F01):** ... Source Consistency maps by **exact ID** ... Do **not** require content alignment / “same observable outcome” on an `Acceptance Criterion` prose column ... Fail closed ... Prose/content-alignment fallback is **legacy-only** ... |
```

`review-cross-artifact` applies exact-ID **before** leftover fuzzy text:

```417:417:.planning/spec_template_world_class.plan.md
| review-cross-artifact | ... **QC-7 two-mode (R6m-F01):** ID-bearing staged pairs use **exact-ID** Source Consistency ... **before** any leftover fuzzy text ... Prose/content-alignment fallback is **legacy-only**. |
```

Risk rows scope prose fallback to legacy-only (L621) and name two-mode QC-7 risk (L637).

### 3. Wave 2 NFR Metric measurability fixtures (`fast` FAIL / `p95 <= 200 ms` PASS)

**PASS** — Locked-contract QC-4 retains NFR Metric branch with named fixtures:

```72:72:.planning/spec_template_world_class.plan.md
| review-requirements QC-4 | R4-F01, R6h-F01, R6i-F01, R6m-F01 | ... **NFR Metric measurability (R6m-F01):** ... Fixture FAIL: `fast`; fixture PASS: `p95 <= 200 ms`. |
```

Wave 2 `review-requirements` row names the same fixtures on the QC-4 NFR branch (L416). Wave 2 QC-string test surface (`test-review-spec-req-xart-qc-strings.sh`, L426) explicitly asserts **QC-7 two-mode exact-ID** and **NFR Metric measurability (`fast` FAIL / `p95 <= 200 ms` PASS)** alongside R6l/R6k/R6j fixtures.

### 4. Bound to Step 8 / XART / compiler

**PASS** — Locked bind row:

```81:81:.planning/spec_template_world_class.plan.md
| Wave 3 Step 8 / XART / QC-7 exact-ID + NFR Metric | R6m-F01 | Bind two-mode QC-7 to Wave 2 `review-requirements`, `review-cross-artifact` (exact-ID **before** any leftover fuzzy text), Step 8 serialize+parse, compiler/migration fixtures. |
```

Step 8 work (L447–L448) fail-closes on QC-7 exact-ID mismatch and non-measurable NFR Metric before canonical pair install. Compiler verify (L480–L481) retains QC-7 two-mode + NFR Metric fixtures. Wave 6 behavioral (L584) asserts exact-ID PASS without GWT paraphrase and `fast`/`p95` fixtures.

### 5. R6l / R6k / R6j not regressed; KEEP REJECT intact

**PASS** — R6k-F01 (`coverage-matrix-req-cell-list`, L76–L77), R6l-F01 (live staged-SPEC AC namespace closure, L78–L79), R6j-F01/F02 (AC-cell cardinality / `nfr-source-cell-list`, L74–L75) remain present and explicitly “do not weaken” in Wave 2 rows. **KEEP REJECT** unchanged at L697 (two files; Clarify does not write SPEC; ingest stays).

## Overturns

**NO** — APPLY faithfully encodes the R6m-F01 MED remediation sustained in pre-APPLY `verify_1-rerun-13.md`. No criterion miss found.

## Verdict

**PASS** — Post-APPLY twins match claimed SHA, differ from pre-APPLY pin, and encode QC-7 two-mode exact-ID (legacy-only fuzzy), Wave 2 NFR Metric fixtures, Step 8/XART/compiler binding, and preserved R6l/R6k/R6j/KEEP REJECT.
