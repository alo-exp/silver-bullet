# Rung 05 — Pi Codex GPT-5.6 Sol High — Review pass 6

## Review identity

- **Role:** review-only; no APPLY, triage, verification launch, outcome recording, branch change, commit, freeze execution, or live template/skill edit.
- **Model / host:** `gpt-5.6-sol-high` via Pi Codex / OmniRoute (`PI_PROVIDER=omniroute`); no model remap or substitution.
- **Freeze:** `.planning/spec_template_world_class.plan.md`
- **Expected and observed SHA-256:** `0844eb0fbf945aa64fa40a5f6dfe2369cc6c812701dbda92e472a58e097d68cc`
- **Twin:** `.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md` — byte-identical (`cmp` clean; same SHA).
- **Context read:** `.planning/spec-template-world-class/CONTEXT.md`.
- **History used only as history:** `review-rerun-5.md` was read after the fresh freeze read; prior findings were not treated as authority.
- **Graphify first:** ran the mandated scoped query before source exploration.
- **Scope:** template contract and software-kind packs first; compiler/QC/tests second; hygiene last.

## Result

The post-R5e freeze contains the requested exact two-digit REQUIREMENTS grammar in the ID scheme, target tables, Wave 2 `review-requirements`, cross-artifact Coverage Matrix/ROADMAP parsing, Step 8 mint/preserve behavior, and named positive/negative fixtures. The phrase “one or more digits” is absent from the freeze. R5/R5b/R5c behavior also remains present: kind reconciliation precedes every supported augment write; QC-6/QC-6b enforce the intended metadata boundary and valid `multi` shape; QC-12 rejects required-pack stubs; QC-13 / `SPEC-F75` validates declared SPEC IDs; QC-10 validates Change History; and NFR Source plus Source Dispositions provide forward and reverse traceability. KEEP REJECT remains intact.

The independent re-hunt found one residual catalog/QC mismatch: `examples` is required for three atomic kinds, while the global required-pack contract says required packs have pack-local IDs, but no Examples ID is declared anywhere.

---

## R5f-F01 — MED — Required `examples` pack has no catalog ID, contradicting the required-pack and global ID-addressability contracts

**Location:** PRIMARY — SPEC.md template contract / Cross-cutting packs (`examples`); ID scheme; software-kind catalog; Wave 1b pack fixtures; Wave 2 QC-12/QC-13.

**Evidence quote:**

The freeze makes pack-local identity part of the product contract, not merely an implementation preference:

> “Kind-required packs are a **heading + body + pack-local IDs** contract, not headings-only.”

It also says:

> “Every structured pack is ID-addressable.”

The `examples` row is kind-gated and substantive, but declares no prefix:

> “`examples` | `## Examples` (worked scenarios, golden I/O, copy-paste) | kind-gated | required: library-sdk, http-api, cli; optional otherwise”

The ID scheme enumerates `FLOW-nn`, `DEC-nn`, and prefixes for errors, API, CLI, data, telemetry, operations, security, quality attributes, mobile, and pipeline, but no Examples prefix. The Wave 2 QC-12 prefix list likewise names:

> “`EP-nn` / `CTRL-nn` / `SLO-nn` / `QA-nn` / `SIG-nn` / `ERR-nn` / `CMD-nn` / `DATA-nn` / `SCR-nn` / `STG-nn` / `FLOW-nn` / `DEC-nn` as the pack table requires”

Because the pack table supplies no Examples prefix, an `http-api`, `cli`, or `library-sdk` fixture cannot simultaneously demonstrate the stated required-pack-local-ID invariant for `## Examples`. Depending on implementation interpretation, QC-12 either exempts this required pack from the global rule or has no valid ID with which to satisfy it. QC-13 also has no declared prefix to parse for optional-present Examples sections.

**Why it matters for the template contract:**

Worked examples and golden I/O are implementation-bearing contract entries for APIs, CLIs, and SDKs. Without stable IDs, plans, reviews, tests, and augment passes cannot cite or append them with the same identity guarantees provided to every other structured pack. More importantly, the freeze currently gives implementers contradictory instructions: all kind-required packs require pack-local IDs, yet one pack that is required by three kinds has no legal ID shape. The body can be substantive, so this is not a reopening of the already-APPLYed heading-only/`_TBD` defect; it is a residual hole in the catalog needed to execute that rule consistently.

**Suggested freeze-text fix:**

Declare an Examples entry prefix (for example, `EX-nn`) in the `examples` pack row and global ID scheme. Require each worked scenario/golden I/O entry in a present `## Examples` pack to use exact two-digit, file-unique `EX-nn`; include it in QC-12/QC-13 and Step 7 mint/augment behavior. Extend Wave 1b fixtures for required Examples kinds with `EX-01`, and add unlabeled, malformed-width, and duplicate Examples negatives to the QC fixture set. Clarify may continue capturing unnumbered `examples` brief content; the compiler can mint the IDs at write time, consistent with other pack fields.

---

## Prior APPLY residual check

| Pin requested by brief | Result in this freeze |
|---|---|
| R5-F01 kind reconciliation before Wave 3 Step 7 and Wave 6 branches 2/3/4b; migrate-or-ASK; fail-before-write; behavioral fixtures | Present |
| R5-F02 QC-6 required set only shaped `feature-slug` + catalog-valid `software-kind`; QC-6b iff `multi`; optional `clarify-brief`; non-QC-required default `derived-requirements`; Step 7 writes keys | Present |
| R5-F03 NFR `Source` column and forward join in Step 8 plus both reviewers | Present |
| R5b-F01 QC-12 / `SPEC-F74` substantive required-pack bodies and catalog IDs; heading-only / empty / `_TBD` fail | Present for every declared prefix, but `examples` has no declared prefix; this is the residual catalog hole in R5f-F01. |
| R5b-F02 two+ distinct atomic `software-kinds`, validated before union, with named negatives | Present |
| R5b-F03 reverse NFR coverage, allowed cardinalities, and guarded empty state | Present |
| R5c-F01 QC-13 / `SPEC-F75` exact two-digit, file-unique declared SPEC/core/pack IDs; duplicate AC failure before coverage; unlabeled US/OQ/OOS negatives | Present for declared IDs. R5f-F01 concerns the missing Examples declaration, not a reversal of QC-13. |
| R5c-F02 QC-10 / `SPEC-F72` Change History table, current-version row, ordered/unique versions, substantive summary | Present |
| R5c-F03 canonical Source Dispositions table, closed enum, rationale/owner, source resolution/uniqueness, guarded `None identified.` | Present |
| R5e-F01 exact two-digit QC-2 / `REQ-F10`; Step 8 mint/preserve; exact cross-artifact parsers; named fixtures; no “one or more digits” | Present |
| Catalog-derived QC-7 / `SPEC-F61`; Functional-only `XART-F02`; kind-aware Step 1; `SPEC-F08`; all brief pack fields; real `nfr` turn | Present |

## Independent residual-hunt notes

- Re-read the core heading ontology, GWT split, Invariants, Change History, decision-log promotion, and required/optional/forbidden behavior. No additional supported core-heading finding emerged.
- Recomputed representative atomic and `multi` pack unions, including required-wins, closed-world omission, optional packs, QC-6b membership/cardinality, and `_TBD` handling. The only newly supported mismatch is the missing identity grammar for the required `examples` pack.
- Traced Wave 3 Step 7 and Wave 6 branches 2/3/4b through kind reconciliation and fail-before-write. The forbidden/unlisted-heading write path remains closed.
- Traced REQUIREMENTS QC-2 through Step 8, Coverage Matrix, ROADMAP parsing, and tests. Exact two-digit `REQ`/`NFR` grammar is consistently specified in this freeze, with malformed-width negatives.
- Traced NFR rows in both directions, including `SCAN:` forward sources and structured `QA`/`SLO`/`CTRL` reverse coverage or exactly-one valid disposition. No new Source Dispositions bypass was found.
- Plan-hygiene metadata drift in CONTEXT does not create or drive this template-contract finding.

# Verdict: NOT CLEAN

One new residual finding, `R5f-F01`, is filed. No triage, APPLY, verification, outcome recording, ladder PASS, or advancement recommendation is made.
