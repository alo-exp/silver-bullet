# Rung 06 — Pi Codex GPT-5.6 Sol Extra High — review pass 13

## Review identity and freeze verification

- **Role:** review-only. No APPLY, triage, verifier launch, outcome recording, ladder advance, branch change, commit, or freeze-twin mutation was performed.
- **Model/host:** Pi Codex through OmniRoute; observed `PI_PROVIDER=omniroute`, `PI_MODEL=codex/gpt-5.6-sol-xhigh`.
- **Reviewed freeze:** `.planning/spec_template_world_class.plan.md`.
- **Expected SHA-256:** `91652845956169f878a53bb184ccd6e4d4403f03a3e3c9cd803bdf360bf8b5e0`.
- **Observed SHA-256:** `91652845956169f878a53bb184ccd6e4d4403f03a3e3c9cd803bdf360bf8b5e0` — exact match.
- **Twin:** `.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md` has the same SHA-256; `cmp` confirmed byte identity.
- **Context:** `.planning/spec-template-world-class/CONTEXT.md` was read in full. Its `edf2c256…` freeze identity was treated as stale, as directed.
- **Method:** ran the mandatory Graphify query before exploration, then independently re-read the complete 702-line post-R6l freeze. Passes 1–12 were treated as history, not authority. The residual hunt covered the template/index contract, software-kind packs and Clarify turns, reviewer semantics, compiler staging/install semantics, migration paths, and behavioral fixtures.

## R6l APPLY landing confirmation

R6l-F01 landed as encoded across the locked contract, ID scheme, target REQUIREMENTS structure, Wave 1 parser fixture, Wave 2 reviewers, Wave 3 Step 8, compiler assertions, Wave 6 migration fixture, and risk table:

- Every Functional and Coverage Matrix `AC-nn` must resolve to one unique **live staged-SPEC** AC after SPEC QC-13 establishes the source set. Tombstoned and invented IDs are not live.
- The contract states `distinct(Functional.AC) = distinct(Matrix.AC) = live staged-SPEC AC set`, while retaining R6k matrix↔Functional **edge-set** equality and one matrix row per distinct AC.
- `review-requirements` makes QC-8 / `REQ-F70` bidirectional and fails unknown, tombstoned, or invented ACs before coverage/equality.
- `review-cross-artifact` performs the namespace check before orphan/coverage evaluation, and Step 8 serializes and parses the staged cells against the staged SPEC before canonical pair installation.
- Fixed-point semantics continue to invalidate PASS evidence after any staged mutation, so the closure applies to the exact pair that can be installed.
- The behavioral negative is present at Wave 1, Wave 2 test planning, Wave 3 compiler checks, and Wave 6: staged SPEC has only `AC-01`, while mutually consistent Functional/matrix `AC-99`/`REQ-99` edges are rejected with no canonical pair install.
- R6k remains intact: matrix `AC` cells are exact-one, `coverage-matrix-req-cell-list` retains its exact `, ` delimiter and exact `REQ-[0-9]{2}` atoms, malformed aliases fail, and matrix↔Functional edges must be equal.

I did not re-file R6l-F01. The finding below is separate: an inherited REQUIREMENTS testability/reviewer-mode contract was incompletely carried into this freeze.

## Finding

### R6m-F01 — MED — Wave 2 drops the inherited exact-ID QC-7 mode and NFR-metric branch while retargeting QC-4

- **Location:** `Locked from prior ladder` → `review-requirements QC-4`; `Target structure — REQUIREMENTS.md` → Functional and Non-Functional Requirements; Wave 2 `review-requirements`; Wave 2 QC test contract; Wave 3 Step 8a/fixed-point; Risk table.
- **Evidence from this freeze:** the locked row now says only:

  > “`REQ-F30` does not fire on a valid `AC-nn` join key”

  and the Wave 2 reviewer row similarly retargets Functional cells, then jumps directly to:

  > “New **QC-8:** Coverage Matrix exists and every SPEC `AC-nn` appears (`REQ-F70`)”

  It never states that the existing QC-7 source-coverage check must join by exact `AC-nn` when IDs exist, nor that prose/content alignment is a legacy-only fallback. Yet the freeze still expressly preserves that old path in the risk table:

  > “Keep XART/QC-7 prose fallback”

  The implementation baseline that Wave 2 changes still defines QC-7 by fuzzy content alignment: the Functional “acceptance criterion column should capture the same observable outcome.” The target table has deliberately replaced that prose column with an exact-one `AC-nn` join cell. Thus QC-8/R6k/R6l can prove exact namespace, set, and edge integrity while the unretargeted QC-7 still asks the ID cell to carry or resemble criterion prose.

  The same partial retarget omits the other half of the existing QC-4 contract. The target still declares a Non-Functional `Metric` column, but the frozen Wave 2 reviewer text and its named test enumerate the Functional `AC-01` no-fire/list cases without saying that every live NFR Metric remains measurable or naming a positive/negative metric fixture. The inherited R4-F01 APPLY contract had explicitly preserved that branch while exempting only the Functional AC join; this freeze says prior R1–R4 pins must not be reverted, but does not encode the preserved branch on the implementation surface.
- **Why it matters for the template contract:** REQUIREMENTS is intended to be an exact-ID index, not a second prose copy of SPEC. Leaving fuzzy QC-7 active for new ID-bearing pairs can reject a semantically correct staged pair merely because an `AC-01` cell is not a paraphrase of the GWT text, or pressure implementation back toward the forbidden prose/GWT column. Conversely, rewriting QC-4 around Functional join-key grammar without preserving NFR Metric validation can allow rows such as `NFR-01 | Service is fast | fast | QA-01 | P1` to pass despite the world-class contract requiring testable quality attributes. Because Step 8a and fixed-point require clean reviewer passes on staged bytes, this is both a template/index semantic defect and an install-gate ambiguity.
- **Suggested freeze-text fix:** restore a two-mode, column-specific reviewer contract and bind it to the existing staged tests:
  1. In the locked row and Wave 2 `review-requirements`, state that when the staged SPEC/REQUIREMENTS pair has `AC-nn` IDs, QC-7 joins by exact ID and **does not** perform fuzzy “same observable outcome” matching; prose alignment is permitted only for legacy input where IDs are absent. QC-8/R6k/R6l remain the fail-closed exact-ID coverage, edge, and live-namespace gates.
  2. State that Functional `AC` cells are join keys and therefore exempt from measurable-prose evaluation, while the Functional `Requirement` remains a substantive one-line normative statement and each live NFR `Metric` remains measurable/observable. Empty NFR plus the valid `None identified` form still has no row to fail.
  3. Add behavioral fixtures, not only skill-string checks: (a) a valid exact-ID pair whose Functional requirement wording does not paraphrase the GWT still PASSes QC-7; (b) an orphan/phantom/tombstoned ID still fails via QC-8/R6l; (c) NFR Metric `fast` or `works well` FAILs `REQ-F30`, while a concrete metric such as `p95 <= 200 ms` PASSes; (d) Step 8a cannot install a staged pair that fails either branch. Retain all R6h–R6l parser, equality, closure, staged-pair, recovery, and fixed-point contracts unchanged.

## Independent residual-hunt notes

- **R6k/R6j/R6i/R6h:** Functional cells remain exactly one `AC-[0-9]{2}`; list aliases fail at mint/serialize/XART; many-to-one uses multiple Functional rows; the old live `Acceptance Criterion` column fails; Wave 1 parses the data cell; and the `REQ-F30` no-fire fixture for valid `AC-01` remains. `nfr-source-cell-list` retains its exact U+002C/U+0020 delimiter, exact structured/`SCAN:` atoms, live example, same-parser Step 8/XART reverse/exclusive/overlap checks, no-space failure, second-atom overlap case, and malformed-staged-Source no-install behavior. The finding is about the distinct fuzzy QC-7 and NFR Metric branches, not any of those applied parser contracts.
- **R6f:** `00–99` inclusive with `-00` allocatable, every exact-width catalog prefix plus REQ/NFR, Step 7 and Step 8 fail-closed allocation, and no wrap/widen/tombstone reuse remain specified with no-install fixtures.
- **R6b/R6c/R6d:** Step 7 remains staging-only until Step 8 succeeds; 7a/8a and intervening reviewers consume staged paths; both prior canonical states, including absence, are snapshotted; second-replace failure restores both; any staged mutation invalidates earlier PASS evidence until the applicable Step 8/7a/8a/XART cycle re-PASSes on the exact install bytes.
- **R5k/R5j/R5i/R5h:** exclusive live NFR Source versus exactly-one Source Disposition branches, overlap/neither failures, true-greenfield two-file predicate, partial-pair preserve-or-fail-closed behavior, separate never-drop tombstone ledgers, live/tombstoned collision checks, and next-free skipping remain intact. R6l does not treat tombstoned SPEC AC IDs as live.
- **SPEC template and kinds:** seven QC-1 core headings plus QC-10 Change History, GWT/If-Then, Invariants, global exact-width IDs, conditional Decision Log, substantive required packs, optional-present validation, closed-world kind classification, validated `multi`/required-wins, `EX-nn`, and kind-first relevant-only Clarify turns remain coherent. Clarify remains non-writing, ingest remains separate, and canonical outputs remain exactly SPEC.md plus REQUIREMENTS.md.
- **Compiler/tests/v0.35 lock:** Wave 3 and Wave 6 retain staged no-partial-output, snapshot recovery, fixed-point, exhaustion, AC-cell, Source-list, Coverage Matrix grammar/edge, and phantom-AC fixtures across branches 1/1b/2/3/4b. The total legacy-lock tree and kind reconciliation remain present. I found no second residual finding.

## Outcome

**NOT CLEAN** — one new MED residual template-contract gap (`R6m-F01`) remains on freeze SHA `91652845956169f878a53bb184ccd6e4d4403f03a3e3c9cd803bdf360bf8b5e0`. The freeze twin is byte-identical. R6l-F01 landed as encoded; this pass does not triage or APPLY the residual.
