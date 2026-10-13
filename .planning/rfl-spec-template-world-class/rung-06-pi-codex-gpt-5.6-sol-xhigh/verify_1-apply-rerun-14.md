---
verdict: PASS
overturns: n
sha: 397020ce6adc1bdd713105100ec29412a440eabb99d898ea9269c2f92c4dfc69
role: apply_verify
pass: 14
model: composer-2.5
---

# verify_1 APPLY — Rung 06 Pi Codex GPT-5.6 Sol Extra High — pass 14

**Role:** apply_verify (Composer 2.5) — verify-only; no APPLY, triage, commit, or freeze mutation.  
**APPLY notes:** [`APPLY-rerun-14.md`](APPLY-rerun-14.md)  
**Pre-APPLY verify:** [`verify_1-rerun-14.md`](verify_1-rerun-14.md) — sustained R6n-F01 MED on pre-APPLY pin.

## SHA and twin verification

| Check | Result |
|-------|--------|
| Twin A | `.planning/spec_template_world_class.plan.md` |
| Twin B | `.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md` |
| Pre-APPLY SHA (claimed) | `364594469c19a7127b93f5d39a01b539a62f407e0a10940b2edab0faa2d05458` |
| Post-APPLY SHA (independent, both twins) | `397020ce6adc1bdd713105100ec29412a440eabb99d898ea9269c2f92c4dfc69` |
| Claimed post-APPLY match | **YES** |
| SHA changed from pre-APPLY | **YES** |
| Byte identity (twins) | **YES** — identical SHA-256 on both twins; `diff` 0 lines |

## APPLY criterion checks

### 1. SHA / twins

**PASS** — Independent `shasum -a 256` on both twins yields `397020ce6adc1bdd713105100ec29412a440eabb99d898ea9269c2f92c4dfc69`, matching APPLY claim and differing from pre-APPLY `364594469c19a7127b93f5d39a01b539a62f407e0a10940b2edab0faa2d05458`.

### 2. Named staged-pair lineage equality is normative

**PASS** — Locked-contract row names the contract and binds R6n-F01:

```82:82:.planning/spec_template_world_class.plan.md
| staged-pair lineage equality | R6n-F01 | Named contract **staged-pair lineage equality:** before orphan/coverage and before canonical replacement, parse both exact staged artifacts. REQUIREMENTS YAML `derived-from` MUST identify the logical canonical target of the staged SPEC (not presence-only). Human `**Derived from:**` path/version MUST agree with REQUIREMENTS YAML (`derived-from` + `spec-version`). Exact equality of staged SPEC and REQUIREMENTS `spec-version`, `feature-slug`, and `software-kind`. ...
```

ID scheme (L212), REQUIREMENTS frontmatter dual-emit (L280), Wave 1 template emit (L351), Wave 2 inherited pin (L407), Wave 3 inherited pin (L439), and Wave 6 inherited pin (L561) all carry the named contract.

### 3. QC-6 fail-closed parse-and-compare (not presence-only)

**PASS** — Wave 2 `review-requirements` QC-6 explicitly rejects presence-only and requires parse-and-compare of `derived-from`, `spec-version`, `feature-slug`, `software-kind`, and human `**Derived from:**` agreement:

```418:418:.planning/spec_template_world_class.plan.md
| review-requirements | QC-6 **staged-pair lineage equality (R6n-F01):** parse-and-compare, not presence-only. YAML `derived-from:` **and** `**Derived from:**` MUST both be present **and** agree (path/version); ... Do **not** treat QC-6 as YAML `derived-from:` **or** human line. ...
```

`review-cross-artifact` (L419) applies lineage check **before** orphan/coverage. Wave 2 risks (L641) add a presence-only QC-6 risk row. Wave 2 string test surface (L425, L428) names `staged-pair lineage equality` fixtures.

### 4. Bound to XART / Step 8 / Wave 6 1/1b/2/3/4b

**PASS** — Locked bind row:

```83:83:.planning/spec_template_world_class.plan.md
| Wave 3 Step 8 / XART / QC-6 staged-pair lineage equality | R6n-F01 | Bind **staged-pair lineage equality** to Wave 2 `review-requirements` QC-6 (parse-and-compare, not presence-only `derived-from` **or** human line), `review-cross-artifact` (lineage check **before** orphan/coverage), Step 8 serialize+parse, 7a/8a fixed-point revalidation, and Wave 6 paths 1/1b/2/3/4b. ...
```

Step 8 work (L449–L450) serializes+parses lineage and fail-before-replace on inequality. Compiler verify (L484) contains QC-6 staged-pair lineage equality fixtures. Wave 6 paths 1/1b/2/3/4b (L570–L575) name equality on all install paths; path 1b is no longer advisory reconcile. Wave 6 behavioral (L587) asserts matching PASS and independently stale/wrong/contradictory FAIL with no install.

### 5. R6m / R6l / R6k / R6j not regressed; KEEP REJECT intact

**PASS** — R6j-F01/F02 (L74–L75), R6k-F01 (L76–L77), R6l-F01 (L78–L79), R6m-F01 (L80–L81) remain present with explicit “do not weaken” guards in R6n rows. **KEEP REJECT** unchanged at L701 (two files; Clarify does not write SPEC; ingest stays).

## Overturns

**NO** — APPLY faithfully encodes the R6n-F01 MED remediation sustained in pre-APPLY `verify_1-rerun-14.md`. No criterion miss found.

## Verdict

**PASS** — Post-APPLY twins match claimed SHA, differ from pre-APPLY pin, and encode named **staged-pair lineage equality** with fail-closed QC-6 parse-and-compare, XART/Step 8/Wave 6 1/1b/2/3/4b binding, and preserved R6m/R6l/R6k/R6j/KEEP REJECT.
