# Rung 06 — Pi Codex GPT-5.6 Sol Extra High — review pass 10

## Review identity and freeze verification

- **Role:** review-only. No APPLY, triage, verify launch, outcome recording, branch change, or freeze mutation was performed.
- **Model/host:** Pi Codex, `PI_PROVIDER=omniroute`, `PI_MODEL=codex/gpt-5.6-sol-xhigh`.
- **Reviewed freeze:** `.planning/spec_template_world_class.plan.md`
- **Observed SHA-256:** `f20dd7b1f1c0ff3e33a782a94d0de45979df2ce9badbb65e78b6a6961313b6b3` — matches the required pin.
- **Twin:** `.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md` has the same SHA-256, and `cmp` returned byte-identical.
- **Context:** `.planning/spec-template-world-class/CONTEXT.md` was read; its older `edf2c256…` metadata was treated as stale, as instructed.
- **Method:** ran the mandatory Graphify query, then re-read the complete pinned freeze independently. Earlier pass reports were treated as history rather than authority. The review covered the SPEC template contract, software-kind packs/Clarify tailoring, and implementation waves/QCs/tests.

## R6i landing confirmation

The post-R6i freeze does contain the central accepted text:

- The locked contract and Target REQUIREMENTS structure now say each Functional `AC` cell is **exactly one** `AC-[0-9]{2}`, explicitly make `AC-01, AC-02` fail, and represent many-to-one mapping through multiple Functional rows.
- Wave 1 requires parsing the Functional data cell, not merely the header or SPEC-side `**AC-01**`; Wave 2 gives QC-4 / `REQ-F30` a behavioral `AC-01` no-fire case and the list-cell negative.
- The named `nfr-source-cell-list` grammar now defines the exact `, ` delimiter, exact atoms, `SCAN:` restrictions, a live Source example, shared reverse-coverage/exclusivity intent, and positive/malformed fixtures.

Those additions close the original template and `review-requirements` surfaces, but the re-hunt found two residual consumer/compiler holes below. These are new pass-10 IDs, not a re-filing of `R6i-F01` or `R6i-F02`.

## Findings

### R6j-F01 — MED — Functional AC-cell cardinality is not carried into the compiler and cross-artifact consumer contract

**Location:** Wave 2 `review-cross-artifact`; Wave 3 `Step 8` and compiler verification; Wave 6 inherited pins/behavioral pair-write coverage.

**Evidence from this freeze:** The canonical REQUIREMENTS contract is precise:

> “each Functional data-row `AC` cell is **exactly one** exact `AC-nn` … No AC column lists: a cell `AC-01, AC-02` FAIL. Many-to-one REQ↔AC if needed is via **multiple Functional rows**”

Wave 1 and `review-requirements` repeat and test that rule. The downstream compiler instruction, however, only says:

> “fill AC column + Coverage Matrix”

Its Step 8 text does not require the emitted cell to be one exact `AC-[0-9]{2}`, prohibit list serialization, or say that a malformed/list cell fails before pair install. The Wave 3 compiler verification bullets likewise do not name the `AC-01` PASS / `AC-01, AC-02` FAIL contract. Wave 3 and Wave 6 inherited-pin lists stop at `R6f-F01`, omitting both `R6h-F01` and `R6i-F01` from the compiler/migration surfaces.

The second consumer is also under-specified. `review-cross-artifact` is told to use:

> “Functional `REQ-nn` rows that lack an AC join (Functional `AC` column and Coverage Matrix)”

but its row never says that its Functional-cell parser accepts exactly one `AC-[0-9]{2}` and rejects lists/prose. Thus QC-4 has the correct parser contract while another join consumer is free to split or normalize the same cell differently.

**Why this matters for the template contract:** The table contract is only reliable if the compiler emits it and every join consumer interprets it identically. As written, an implementation can satisfy the newly added template/parser test and `review-requirements` behavior while Step 8 or XART still serializes/accepts `AC-01, AC-02`. A later reviewer may reject that staged output, but the compiler contract itself remains ambiguous, and one consumer can compute coverage on a representation that another correctly declares invalid.

**Suggested freeze-text fix:** Extend the R6i rule—not weaken or replace it—across the remaining consumers:

1. Add `R6h-F01` / `R6i-F01` to Wave 3 and Wave 6 inherited pins.
2. In Step 8, require every Functional row it emits to contain exactly one `AC-[0-9]{2}`; prohibit all list aliases (comma, semicolon, slash, pipe, or whitespace-separated lists); model repeated joins with multiple Functional rows; and fail before canonical pair replace on any invalid cell.
3. Require `review-cross-artifact` to consume the same exact-one Functional-cell parser before orphan/coverage evaluation.
4. Add compiler/XART behavioral coverage for `AC-01` PASS and `AC-01, AC-02` FAIL, including a staged-pair assertion that the malformed cell cannot install.

### R6j-F02 — MED — `nfr-source-cell-list` is not bound to Step 8 or `review-cross-artifact` despite both performing reverse/exclusive coverage

**Location:** Wave 2 `review-cross-artifact`; Wave 3 `Step 8` and `test-clarify-spec-compiler.sh` verification; Wave 6 staged failure coverage.

**Evidence from this freeze:** The Target REQUIREMENTS contract correctly defines:

> “named `nfr-source-cell-list` — one or more source IDs separated by `, ` (U+002C COMMA + exactly one U+0020 SPACE); no other whitespace in the cell”

and requires:

> “reverse-coverage, exclusivity, and overlap FAIL consume this same parser”

The `review-requirements` Wave 2 row carries that grammar. But the parallel `review-cross-artifact` row performs the same reverse/exclusive checks while saying only that a source is:

> “represented by ≥1 `NFR-nn` Source … or … exactly one `### Source Dispositions` row”

It never names `nfr-source-cell-list`, its exact delimiter/atoms, or the shared parser. Step 8 similarly says it emits a Source join and fails on a “malformed/unresolved Source,” but does not define malformedness by the named grammar or require canonical `, ` serialization. The compiler verification bullet checks the Source join and exclusive branches, yet has no `QA-01, SLO-01` parses-as-two PASS or `QA-01,SLO-01` FAIL assertion. Consequently, the only explicit parser test is attached to template/`review-requirements` coverage, not all consumers that calculate overlap and reverse coverage.

**Why this matters for the template contract:** A split-on-comma implementation in Step 8 or XART can accept `QA-01,SLO-01`, trim double spaces/tabs, or mis-tokenize a `SCAN:` atom while `review-requirements` rejects the same bytes. More importantly, an overlap check using a different splitter can fail to see one atom and incorrectly accept a source that appears in both the live and disposition branches. That violates the accepted single-parser invariant and makes NFR lineage depend on which reviewer runs.

**Suggested freeze-text fix:** Carry the named grammar through every producer and consumer:

1. Add `R6i-F02` to Wave 3 and Wave 6 inherited pins.
2. Require Step 8 to serialize Source cells canonically with `nfr-source-cell-list`, parse its own staged output with that parser, and fail before pair replace on malformed cells.
3. Require `review-cross-artifact` reverse coverage, exclusivity, and overlap detection to use the same parser as `review-requirements`, including exact `SCAN:` atom validation.
4. Add compiler/XART behavioral fixtures where `QA-01, SLO-01` yields two source atoms and `QA-01,SLO-01` fails; include an overlap case whose second atom is detectable only through correct list parsing, plus a no-install assertion for malformed staged Source bytes.

## Independent residual-hunt notes

- **R6h / R6i template and QC surfaces:** The live Functional-row example requirement, old `Acceptance Criterion` heading prohibition, exact-one cell grammar, `REQ-F30` no-fire case, and list negative are present. The defects above are confined to omitted downstream compiler/XART bindings.
- **R6i NFR grammar core:** Exact delimiter, whitespace rule, atom shapes, non-empty/no-space/no-comma `SCAN:` components, live example, malformed-list negative, and exclusive-branch statement are present. The remaining defect is inconsistent end-to-end consumption.
- **R6f:** `00–99` inclusive with `-00` allocatable, no wrap/three-digit/tombstone reuse, Step 7 and Step 8 fail-closed behavior, SPEC and REQUIREMENTS full-namespace fixtures, and no-install semantics remain present.
- **R6b/R6c/R6d:** Non-canonical staging, staged 7a/8a inputs, snapshot of both prior states including absence, restoration after second-replace failure, fixed-point revalidation on exact staged bytes, and mutate-after-PASS invalidation remain present.
- **R5k/R5j/R5i/R5h:** Exclusive NFR Source-versus-disposition branches, overlap and neither-branch failures, true-greenfield two-file predicate, partial-pair preserve-or-fail-closed behavior, distinct persistent tombstone ledgers, and skip-without-reuse allocation remain present.
- **SPEC/kind/Clarify contract:** The seven-heading QC-1 core plus QC-10 Change History split, substantive pack bodies and pack-local IDs, closed catalog and `multi` required-wins rule, kind-first gated turns, required `nfr` turn for the three catalog kinds, two canonical outputs, Clarify non-writing rule, and ingest preservation remain coherent. No additional residual finding was identified there.

## Outcome

**NOT CLEAN** — two MED residual template-delivery gaps (`R6j-F01`, `R6j-F02`) remain on freeze SHA `f20dd7b1f1c0ff3e33a782a94d0de45979df2ce9badbb65e78b6a6961313b6b3`.
