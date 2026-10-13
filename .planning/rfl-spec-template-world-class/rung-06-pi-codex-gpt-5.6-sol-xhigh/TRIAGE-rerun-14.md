# RFL Triage — Rung 06 Extra High pass 14

**Rung:** 6 of 8 — Pi Codex GPT-5.6 Sol Extra High — review pass 14 triage  
**Model:** Composer 2.5 (`sb-composer-2-5-high`)  
**Review:** [`review-rerun-14.md`](review-rerun-14.md)  
**Freeze pin:** `364594469c19a7127b93f5d39a01b539a62f407e0a10940b2edab0faa2d05458`  
**Twins:** [`.planning/spec_template_world_class.plan.md`](../../../spec_template_world_class.plan.md) · [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../../spec-template-world-class/phases/01-world-class-spec/PLAN.md)

## Authenticity and pin verification

| Check | Result |
|-------|--------|
| Freeze SHA-256 | **MATCH** — observed `36459446…` on both twins (`shasum -a 256`; byte-identical) |
| Review freeze claim | **MATCH** — `review-rerun-14.md` cites same pin and twin `cmp` |
| Review authentic | **YES** — independent post-R6m freeze read; R6m landing confirmed; one new MED residual |
| R6m-F01 re-file | **NOT re-filed** — review confirms R6m landed (QC-7 two-mode exact-ID, NFR Metric measurability, Wave 2/3/6 bindings, behavioral fixtures); triage agrees |
| Product lock collision | **NONE** — proposed fix adds staged-pair lineage equality reviewer gate; two-file model, Clarify non-writing, and ingest unchanged |

## R6m landing confirmation (do not re-file)

R6m-F01 is encoded on this pin: QC-7 two-mode exact-ID Source Consistency for ID-bearing staged pairs (Functional `AC` ↔ live staged-SPEC `AC-nn`; prose fallback legacy-only; fail closed); NFR Metric measurability on QC-4 (`fast` FAIL / `p95 <= 200 ms` PASS); bindings to Wave 2 `review-requirements` / `review-cross-artifact`, Wave 3 Step 8 serialize+parse, compiler/migration fixtures, and Wave 6 behavioral oracles. R6l live staged-SPEC AC namespace/set equality, R6k matrix↔Functional edge-set equality, and R6j/R6i grammars remain intact. **R6m-F01 is settled on this pin.**

## Triage decisions

| ID | Sev | Decision | One-line why |
|----|-----|----------|--------------|
| R6n-F01 | MED | **ACCEPT** | QC-6 is presence-only (`derived-from` **or** human line); no parse-and-compare equality of `spec-version` / `feature-slug` / `software-kind` / human-YAML agreement against staged SPEC before install |

### R6n-F01 — MED — ACCEPT

**Rationale:** After independent freeze read, the gap is real and fail-closed for the template contract.

**Presence-only QC-6 (primary):** The target REQUIREMENTS frontmatter emits `derived-from`, `spec-version`, `feature-slug`, and `software-kind`, plus a human `**Derived from:** .planning/SPEC.md v{spec-version}` line. The only explicit reviewer rule is:

> QC-6: YAML `derived-from:` **or** `**Derived from:**`.

That is presence-only — it does not require YAML `derived-from` to identify the staged SPEC install target, human-line/YAML agreement, or equality of `spec-version`, `feature-slug`, or `software-kind` between the staged SPEC and REQUIREMENTS. Step 8 ends with “YAML + `**Derived from:**` including `software-kind`” — emission language only, no parse-and-compare gate or mismatch fixture.

**Wave 6 1b prose is advisory, not fail-closed (secondary):** Partial-pair branch 1b says “Verify/reconcile `derived-from`, `feature-slug`, and version lineage” but names no equality rule, fault code, or behavioral oracle. Greenfield and augment branches 1/2/3/4b carry no comparable lineage check. Wave 6 “no version skew” assertions in R6b/R6c fixtures prove byte-atomic pair restoration (no lone SPEC), not semantic metadata equality on an otherwise installable pair.

**Not REJECT because:**

- **Not already encoded:** No freeze line names **staged-pair lineage equality**, binds cross-artifact parse-and-compare of pair-identity fields, or adds mismatch fixtures (stale `spec-version`, wrong `feature-slug`, wrong `software-kind`, wrong `derived-from`, contradictory human/YAML). `review-cross-artifact` closes AC namespace (R6l), matrix edges (R6k), QC-7 exact-ID (R6m), and NFR Metric — not pair metadata lineage.
- **Not out of scope:** REQUIREMENTS is the ID index derived from a SPEC version; mismatched lineage misroutes consumers and corrupts augment semantics even when AC IDs remain valid. Policy E — reviewer/install gates on the template contract.
- **Not superseded by R6m/R6l:** R6m retargets QC-7 source-consistency to exact AC join keys; R6l closes AC namespace/set equality. Neither compares staged SPEC vs REQUIREMENTS `spec-version`, `feature-slug`, `software-kind`, or human/YAML lineage fields.
- **No KEEP REJECT collision:** Fix adds reviewer equality on staged bytes + fixtures; no third canonical doc; Clarify still non-writing; ingest unchanged.

**Freeze cites:**

```268:278:.planning/spec_template_world_class.plan.md
derived-from: .planning/SPEC.md
spec-version: 1
...
Keep `**Derived from:** .planning/SPEC.md v{spec-version}` immediately under the H1 so current QC-6 passes without a flag day.
```

```416:416:.planning/spec_template_world_class.plan.md
| review-requirements | QC-6: YAML `derived-from:` **or** `**Derived from:**`. ...
```

```568:568:.planning/spec_template_world_class.plan.md
1b. ... Verify/reconcile `derived-from`, `feature-slug`, and version lineage. If lineage cannot be established, **fail before write** ...
```

No freeze line requires exact equality of staged SPEC and REQUIREMENTS pair-identity fields or human/YAML agreement before install on paths 1/1b/2/3/4b.

## Outcome

**ACCEPT R6n-F01** — one MED residual to APPLY on pin `36459446…`. Do not re-file R6m-F01. Do not launch verify from this triage hop.
