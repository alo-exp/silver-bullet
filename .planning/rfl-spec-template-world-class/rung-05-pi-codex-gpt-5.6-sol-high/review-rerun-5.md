# Rung 05 — Pi Codex GPT-5.6 Sol High — Review pass 5

## Review identity

- **Role:** review-only; no APPLY, triage, verification launch, outcome recording, branch change, commit, freeze execution, or live template/skill edit.
- **Model / host:** `gpt-5.6-sol-high` via Pi Codex / OmniRoute (`PI_PROVIDER=omniroute`); no model remap or substitution.
- **Freeze:** `.planning/spec_template_world_class.plan.md`
- **Expected and observed SHA-256:** `506eca57afb3ea2dad0c8c69b486a2c0f7c632ad33bbff40b1f0e82665272d1a`
- **Twin:** `.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md` — byte-identical (`cmp` clean; same SHA).
- **Context read:** `.planning/spec-template-world-class/CONTEXT.md`.
- **Review history read without modification:** `review-rerun-1.md` through `review-rerun-4.md`.
- **Graphify first:** ran the mandated scoped query before source exploration.
- **Scope:** independently re-read the pinned freeze, with template contract and software-kind packs first; compiler/QC/tests second; hygiene last.

## Result

The independent pass reconfirmed that the R5, R5b, and R5c APPLYs remain in the pinned blob. In particular, the compiler reconciles kinds before every supported augment write; QC-6/QC-6b enforce the intended metadata boundary and valid `multi` shape; QC-12 rejects required-pack stubs and missing pack IDs; QC-13 / `SPEC-F75` enforces the declared SPEC-side ID shape and uniqueness; QC-10 validates the Change History table; and NFR Source plus Source Dispositions provide forward and reverse traceability. Earlier catalog-derived QC-7 / `SPEC-F61`, Functional-only `XART-F02`, kind-aware mapping, `SPEC-F08`, complete pack capture fields, and the real `nfr` turn also remain present. KEEP REJECT remains intact.

This pass found one residual ID-shape gap on the REQUIREMENTS side. It is outside the SPEC-side QC-13 scope and was not repaired by R5c-F01.

---

## R5e-F01 — MED — REQUIREMENTS accepts variable-width `REQ`/`NFR` IDs despite the two-digit cross-artifact contract

**Location:** Target structure — REQUIREMENTS.md; Wave 2 `review-requirements` QC-2/QC-3; Wave 3 Step 8; Wave 2/7 tests.

**Evidence quote:**

The pinned freeze consistently defines the generated index with two-digit forms:

> “`REQ-nn` / `NFR-nn` / P1–P3”

> “`## Functional Requirements` — `| ID | Requirement | AC | Priority |` — one REQ per SPEC AC by default.”

> “`## Non-Functional Requirements` — `| ID | Requirement | Metric | Source | Priority |`”

and its compiler contract says:

> “Step 8: one REQ per AC by default … NFR from Quality Attributes / kind NFR packs / scan …”

However, Wave 2 changes `review-requirements` QC-4, adds QC-8 and NFR Source/reverse coverage, and explicitly keeps QC-1, but never tightens the existing QC-2 ID parser. The implementation baseline that this wave leaves in place defines QC-2 as:

> “Functional: `REQ-nn` where `nn` is **one or more digits**”

> “Non-functional: `NFR-nn` where `nn` is **one or more digits**”

Thus `REQ-1`, `REQ-001`, `NFR-2`, and `NFR-0003` satisfy the planned REQUIREMENTS reviewer even though the world-class artifact uses the exact `nn` form and the SPEC-side QC-13 now deliberately requires exact two-digit IDs. QC-3 catches duplicates but not malformed width. The named Wave 2 test contract has malformed-ID fixtures only for SPEC QC-13; it has no REQUIREMENTS malformed-width negatives.

**Why it matters for the template contract:**

REQUIREMENTS is the stable ID index used by the Functional AC join, Coverage Matrix, ROADMAP assignments, PR traceability, and NFR provenance. Allowing multiple textual forms for the same ordinal creates a cross-artifact normalization gap: a hand-edited or stale index can pass `review-requirements` with `REQ-1` while generated fixtures, documentation, and downstream references use `REQ-01`. It also makes the promise of one consistent, machine-addressable ID grammar asymmetric: SPEC IDs are exact-width under QC-13, while the canonical REQ/NFR index accepts arbitrary widths. Compiler minting alone is insufficient because artifact review is the gate for edited and augmented files.

**Suggested freeze-text fix:**

Extend Wave 2 `review-requirements` QC-2 (keeping its existing `REQ-F10` fault family) to require exact `REQ-[0-9]{2}` and `NFR-[0-9]{2}` shapes, while QC-3 continues to enforce document-wide uniqueness. State that Step 8 mints sequential two-digit REQ/NFR IDs and preserves existing valid IDs during augment. Add positive `REQ-01` / `NFR-01` cases and negative `REQ-1`, `REQ-001`, `NFR-2`, and `NFR-0003` fixtures to `test-review-spec-req-xart-qc-strings.sh` or the ID-parse harness, and ensure Coverage Matrix / ROADMAP parsers consume the same exact grammar. This changes neither the two-file decision nor the SPEC-side QC-13 ownership.

---

## Prior APPLY residual check

| Pin requested by brief | Result in this freeze |
|---|---|
| R5-F01 kind-reconciliation before Wave 3 Step 7 and Wave 6 branches 2/3/4b; migrate-or-ASK; fail-before-write; behavioral fixtures | Present |
| R5-F02 QC-6 required set only shaped `feature-slug` + catalog-valid `software-kind`; QC-6b iff `multi`; optional `clarify-brief`; non-QC-required template-default `derived-requirements`; Step 7 writes QC-6 keys | Present |
| R5-F03 NFR `Source` column and forward join in Step 8 + both reviewers | Present |
| R5b-F01 QC-12 / `SPEC-F74` substantive required-pack bodies and catalog IDs; heading-only / empty / `_TBD` fail | Present |
| R5b-F02 two+ distinct atomic `software-kinds`, validated before union, with the listed negatives | Present |
| R5b-F03 reverse NFR coverage, allowed cardinalities, and guarded empty state | Present |
| R5c-F01 QC-13 / `SPEC-F75` exact two-digit, file-unique SPEC/core/pack IDs; duplicate AC failure before coverage; unlabeled US/OQ/OOS negatives | Present. R5e-F01 concerns the separate REQUIREMENTS `REQ`/`NFR` grammar, not a reopening of QC-13. |
| R5c-F02 QC-10 / `SPEC-F72` Change History table, current-version row, ordered/unique versions, substantive summary | Present |
| R5c-F03 canonical Source Dispositions table, closed enum, rationale/owner, source resolution/uniqueness, guarded `None identified.` | Present |
| Catalog-derived QC-7 / `SPEC-F61`; Functional-only `XART-F02`; kind-aware Step 1; `SPEC-F08`; all brief pack fields; real `nfr` turn | Present |

## Independent residual-hunt notes

- Rechecked core required/optional ownership, GWT, invariants, Change History, decision-log promotion, examples, and all security/telemetry/API/UX/data/errors packs. No additional finding was supported by this freeze.
- Recomputed representative atomic and `multi` pack unions, including required-wins, optional omission, closed-world forbidden headings, QC-6b membership/cardinality, and `_TBD` behavior. No additional gap found.
- Traced Wave 3 Step 7 and Wave 6 branches 2/3/4b through kind reconciliation and fail-before-write. The R5-F01 sharp path remains closed.
- Traced NFR rows in both directions, including resolvable `SCAN:` forward sources and the structured `QA`/`SLO`/`CTRL` reverse-coverage or exactly-one-disposition rule. No new Source Dispositions bypass found.
- Rechecked duplicate AC handling before Coverage Matrix/AC→REQ and the named `SPEC-F70`–`SPEC-F75` tests. The remaining issue is specifically that the REQUIREMENTS-side inherited QC-2 still accepts variable-width IDs.
- CONTEXT’s stale freeze metadata and Wave 6 numbering remain sibling/plan-hygiene issues; neither drives this finding.

# Verdict: NOT CLEAN

One new residual finding, `R5e-F01`, is filed. No triage, APPLY, verification, outcome recording, ladder PASS, or advancement recommendation is made.
