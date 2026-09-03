# Rung 06 — Pi Codex GPT-5.6 Sol Extra High — review pass 12

## Review identity and freeze verification

- **Role:** review-only. No APPLY, triage, verifier launch, outcome recording, ladder advance, branch change, commit, or freeze-twin mutation was performed.
- **Model/host:** Pi Codex through OmniRoute; observed `PI_PROVIDER=omniroute`, `PI_MODEL=codex/gpt-5.6-sol-xhigh`.
- **Reviewed freeze:** `.planning/spec_template_world_class.plan.md`.
- **Expected SHA-256:** `bdb5c916f236875d8d046aaf506db2ec54347d42b4acc34080837f5f54bc6f94`.
- **Observed SHA-256:** `bdb5c916f236875d8d046aaf506db2ec54347d42b4acc34080837f5f54bc6f94` — exact match.
- **Twin:** `.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md` has the same SHA-256; `cmp` confirmed byte identity.
- **Context:** `.planning/spec-template-world-class/CONTEXT.md` was read in full. Its `edf2c256…` identity was treated as stale, as directed.
- **Method:** ran the mandatory Graphify query before exploration and independently re-read the complete post-R6k freeze. Passes 1–11 were history rather than authority. The residual hunt covered the template/index contract, software-kind packs and Clarify turns, reviewers, compiler staging/install semantics, migration paths, and behavioral fixtures.

## R6k APPLY landing confirmation

R6k-F01 landed as encoded across the locked contract, ID scheme, target REQUIREMENTS shape, Wave 1 parsing, Wave 2 reviewers, Wave 3 Step 8, compiler checks, Wave 6 migration fixtures, and risks:

- The named **`coverage-matrix-req-cell-list`** uses one or more exact `REQ-[0-9]{2}` atoms separated only by `, ` (U+002C COMMA plus exactly one U+0020 SPACE). It rejects duplicates, unknown/`NFR` IDs, empty atoms, and semicolon/slash/pipe/whitespace aliases.
- Each matrix `AC` cell is exactly one exact `AC-[0-9]{2}` and rejects prose or lists.
- Parsed matrix `(AC, REQ)` edges must equal Functional-table edges, with one matrix row per distinct AC aggregating all Functional REQs; missing, extra, and mismatched pairs fail closed.
- `review-requirements` QC-8 / `REQ-F70` makes mismatch a failure, and `review-cross-artifact` performs the same parser/equality check before orphan/coverage evaluation.
- Step 8 serializes and re-parses staged matrix cells, and malformed/mismatched staged output cannot reach canonical pair installation.
- Fixtures retain the required multi-REQ PASS (`REQ-01`/`AC-01` plus `REQ-02`/`AC-01`; matrix `AC-01 | REQ-01, REQ-02`) and delimiter/wrong-pair failures.
- R6j-F01/F02 remain intact: Functional AC cells are exact-one, NFR Source cells still use the separate `nfr-source-cell-list`, and neither parser was loosened to match the matrix list.

I did not re-file R6k-F01. The finding below is a residual namespace-closure defect after its grammar and edge-equality contract landed.

## Finding

### R6l-F01 — MED — Coverage equality is not closed against the live SPEC AC namespace

- **Location:** Target structure — REQUIREMENTS.md → Functional Requirements and Coverage Matrix; Wave 2 `review-requirements` QC-4/QC-8 and `review-cross-artifact`; Wave 3 Step 8; Wave 1/Wave 6 behavioral fixtures.
- **Evidence from this freeze:** QC-8 still defines the SPEC-side condition only as:

  > “Coverage Matrix exists and every SPEC `AC-nn` appears (`REQ-F70`).”

  The matrix-side R6k contract validates the cell's shape and equality to Functional rows:

  > “matrix `AC` cell is **exactly one** exact `AC-[0-9]{2}`”

  > “Parsed matrix `(AC, REQ)` edge set MUST equal Functional-table edges”

  The Functional-side contract likewise requires only an exact-one syntactically valid AC cell:

  > “Functional `AC` column **cells** are **exactly one** exact `AC-nn` IDs”

  No normative sentence requires every Functional/matrix `AC-nn` to resolve to a unique live Acceptance Criterion in the staged SPEC, and no negative fixture names an exact-but-unknown AC. Thus a staged pair can contain SPEC `AC-01`, valid edges for `AC-01`, **plus** Functional `REQ-99 | … | AC-99` and matching matrix `AC-99 | REQ-99`. Every live SPEC AC appears; both cells have exact shapes; matrix and Functional edge sets are equal; the extra phantom edge is not required to fail.
- **Why it matters for the template contract:** REQUIREMENTS is the canonical ID index derived from SPEC Acceptance Criteria. A syntactically exact but nonexistent `AC-99` creates an untraceable requirement and a fabricated coverage row while still passing the newly normative R6k equality check. Edge equality between two derived views prevents them from disagreeing with each other, but does not prove either view refers to the source SPEC. This is a forward-integrity hole in the AC→REQ contract, not a request for another canonical document and not a re-opening of R6k's list grammar.
- **Suggested freeze-text fix:** Define bidirectional SPEC namespace closure and bind it to the existing consumers/install gate:
  1. After SPEC QC-13 has established unique live `AC-[0-9]{2}` IDs, require every Functional `AC` cell and every Coverage Matrix `AC` cell to resolve to exactly one live staged-SPEC AC; unknown, tombstoned, malformed, or duplicate-source AC IDs fail before coverage/equality evaluation.
  2. State the coverage AC set equality explicitly: `distinct(Functional.AC) = distinct(Matrix.AC) = live staged-SPEC AC set` (while retaining R6k matrix↔Functional **edge-set** equality and one matrix row per AC).
  3. Bind that closure to `review-requirements` QC-8 / `REQ-F70`, `review-cross-artifact`, Step 8 staged self-parse, and fixed-point revalidation on the exact staged SPEC/REQUIREMENTS pair.
  4. Add a behavioral negative fixture: SPEC has only `AC-01`; Functional and matrix contain a mutually consistent exact `AC-99`/`REQ-99` edge in addition to valid `AC-01` coverage → FAIL and no canonical pair install. Retain the existing R6k delimiter and wrong-pair fixtures.

## Independent residual-hunt notes

- **R6j/R6i/R6h:** Functional cells remain exactly one `AC-[0-9]{2}`, `AC-01, AC-02` is rejected at mint/serialize/XART, many-to-one uses multiple rows, old `Acceptance Criterion` columns fail, Wave 1 parses the cell, and QC-4 includes the behavioral `REQ-F30` no-fire case. The separate `nfr-source-cell-list` retains its exact `, ` delimiter, structured/`SCAN:` atom grammar, live example, same-parser reverse/exclusive/overlap checks, no-space failure, and malformed-staged-Source no-install behavior.
- **R6f:** `00–99` inclusive with `-00` allocatable, all exact-width catalog and REQ/NFR namespaces, Step 7/Step 8 fail-closed allocation, and no wrap/widen/tombstone reuse remain present.
- **R6b/R6c/R6d:** Step 7 remains staging-only until Step 8 succeeds; 7a/8a and intervening reviewers consume staged paths; both prior canonicals (including absence) are snapshotted; second-replace failure restores both; mutation invalidates earlier PASS evidence until Step 8/7a/8a/XART re-PASS on the exact install bytes.
- **R5k/R5j/R5i/R5h:** Exclusive NFR live-Source versus exactly-one-Disposition branches, overlap/neither failures, true-greenfield two-file predicate, partial-pair preserve-or-fail-closed behavior, separate never-drop tombstone ledgers, and next-free skipping of live/tombstoned IDs remain intact.
- **SPEC template and kinds:** Seven QC-1 core headings plus QC-10 Change History, GWT/If-Then, Invariants, global exact-width IDs, conditional Decision Log, substantive required packs, optional-present validation, closed-world kind classification, validated `multi`/required-wins, `EX-nn`, and kind-first relevant-only Clarify turns remain coherent. Clarify remains non-writing, ingest remains separate, and outputs remain exactly SPEC.md plus REQUIREMENTS.md.
- **Compiler/tests/v0.35 lock:** Step 8/QC/XART bindings, migration branches 1/1b/2/3/4b, staged no-partial-output and recovery fixtures, exhaustion fixtures, parser fixtures, kind reconciliation, and the total legacy-lock decision tree remain specified. I found no second residual finding.

## Outcome

**NOT CLEAN** — one new MED residual template-contract gap (`R6l-F01`) remains on freeze SHA `bdb5c916f236875d8d046aaf506db2ec54347d42b4acc34080837f5f54bc6f94`. The freeze twin is byte-identical. R6k-F01 itself landed as encoded; this pass does not triage or APPLY the residual.
