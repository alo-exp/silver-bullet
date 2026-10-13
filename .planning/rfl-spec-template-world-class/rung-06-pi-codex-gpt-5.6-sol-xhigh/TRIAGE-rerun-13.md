# RFL Triage — Rung 06 Extra High pass 13

**Rung:** 6 of 8 — Pi Codex GPT-5.6 Sol Extra High — review pass 13 triage  
**Model:** Composer 2.5 (`sb-composer-2-5-high`)  
**Review:** [`review-rerun-13.md`](review-rerun-13.md)  
**Freeze pin:** `91652845956169f878a53bb184ccd6e4d4403f03a3e3c9cd803bdf360bf8b5e0`  
**Twins:** [`.planning/spec_template_world_class.plan.md`](../../../spec_template_world_class.plan.md) · [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../../spec-template-world-class/phases/01-world-class-spec/PLAN.md)

## Authenticity and pin verification

| Check | Result |
|-------|--------|
| Freeze SHA-256 | **MATCH** — observed `91652845…` on both twins (`shasum -a 256`; byte-identical) |
| Review freeze claim | **MATCH** — `review-rerun-13.md` cites same pin and twin `cmp` |
| Review authentic | **YES** — independent post-R6l freeze read; R6l landing confirmed; one new MED residual |
| R6l-F01 re-file | **NOT re-filed** — review confirms R6l landed at L11, L78–L79, L208, L280, L284, L348, L403, L414–L415, L435, L445, L554, L580, L632 |
| Product lock collision | **NONE** — proposed fix scopes reviewer two-mode QC-7 and NFR Metric branch; two-file model, Clarify non-writing, and ingest unchanged |

## R6l landing confirmation (do not re-file)

R6l-F01 is encoded on this pin: live staged-SPEC AC namespace closure, coverage AC set equality (`distinct(Functional.AC) = distinct(Matrix.AC) = live staged-SPEC AC set`), bidirectional QC-8 / `REQ-F70`, XART-before-orphan binding, Step 8 serialize+parse, fixed-point, and phantom `AC-99`/`REQ-99` negative fixtures with no canonical pair install. R6k edge-set equality and `coverage-matrix-req-cell-list` remain intact. **R6l-F01 is settled on this pin.**

## Triage decisions

| ID | Sev | Decision | One-line why |
|----|-----|----------|--------------|
| R6m-F01 | MED | **ACCEPT** | Wave 2 retargets QC-4 to exact `AC-nn` join keys but never retargets review-requirements QC-7 to exact-ID mode; live skill QC-7 still fuzzy-matches “same observable outcome” on a column that no longer exists |

### R6m-F01 — MED — ACCEPT

**Rationale:** After independent freeze read, the gap is real and fail-closed for the exact-ID template contract.

**QC-7 exact-ID mode (primary):** Wave 2 `review-requirements` retargets QC-4 for Functional `AC` cells (exact-one `AC-[0-9]{2}`, `REQ-F30` no-fire on join key) and adds QC-8/R6l bidirectional namespace closure — but it never updates **review-requirements QC-7** (Source Consistency). The live baseline skill still requires fuzzy content alignment: “the requirement's acceptance criterion column should capture the same observable outcome” (`skills/review-requirements/SKILL.md` QC-7). The freeze target table has replaced that prose column with an exact `AC-nn` join cell (`| ID | Requirement | AC | Priority |`). Risk L617 explicitly says “Keep XART/QC-7 prose fallback” without scoping it to legacy-only input. QC-8/R6l close namespace and edge integrity, but an unretargeted QC-7 can still reject a semantically correct staged pair because Functional `AC-01` is not a GWT paraphrase, or pressure implementers back toward forbidden prose columns.

**NFR Metric branch (secondary, same finding):** The target NFR table retains a `Metric` column (L281), but Wave 2 `review-requirements` and the named QC-string test (L424) document only the Functional `REQ-F30` no-fire/list cases. They do not state that live NFR `Metric` values remain measurable under QC-4 or name positive/negative metric fixtures (`fast` FAIL / `p95 <= 200 ms` PASS). R4-F01 is an inherited pin (L72, L403), but the Wave 2 implementation surface documents only the Functional exemption — leaving NFR Metric enforcement implicit on the live skill baseline rather than freeze-bound.

**Not REJECT because:**

- **Not already encoded:** R4-F01 locked row and Wave 2 QC-4 retarget cover Functional AC join-key grammar only; no freeze line requires two-mode QC-7 (exact-ID when staged SPEC has `AC-nn`, prose fallback legacy-only) or binds NFR Metric measurability on the Wave 2 reviewer/test surface.
- **Not out of scope:** Policy E — reviewer QC semantics that change install gates are template-contract findings.
- **Not superseded by R6l alone:** R6l closes AC namespace/set equality; it does not retarget QC-7 source-consistency semantics or preserve the NFR Metric half of QC-4 on the implementation surface.
- **No KEEP REJECT collision:** Fix adds reviewer two-mode QC-7 + NFR Metric fixtures; no third doc, no Clarify write, ingest unchanged.

**Freeze cites:**

```72:72:.planning/spec_template_world_class.plan.md
| review-requirements QC-4 | R4-F01, R6h-F01, R6i-F01 | Functional `AC` column **cells** are **exactly one** exact `AC-nn` ... `REQ-F30` does not fire on a valid `AC-nn` join key ...
```

```103:103:.planning/spec_template_world_class.plan.md
| No coverage matrix | Nothing joins AC text to REQ-01 except fuzzy QC-7. |
```

```414:414:.planning/spec_template_world_class.plan.md
| review-requirements | ... **QC-4 retarget (R4-F01, R6h-F01, R6i-F01):** ... `REQ-F30` does **not** fire on a valid `AC-nn` join key ... New **QC-8:** ...
```

```617:617:.planning/spec_template_world_class.plan.md
| QC-8 fails every old SPEC | Keep XART/QC-7 prose fallback; spec-floor unchanged |
```

Live skill baseline (`skills/review-requirements/SKILL.md` QC-7 L101): fuzzy “same observable outcome” on acceptance-criterion column — not retargeted in freeze Wave 2 work.

## Outcome

**ACCEPT R6m-F01** — one MED residual to APPLY on pin `91652845…`. Do not re-file R6l-F01. Do not launch verify from this triage hop.
