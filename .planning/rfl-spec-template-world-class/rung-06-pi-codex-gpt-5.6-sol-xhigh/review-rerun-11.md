# Rung 06 — Pi Codex GPT-5.6 Sol Extra High — review pass 11

## Review identity and freeze verification

- **Role:** review-only. No APPLY, triage, verifier launch, outcome recording, ladder advance, branch change, commit, or freeze mutation was performed.
- **Model/host:** Pi Codex through OmniRoute; `PI_PROVIDER=omniroute`, `PI_MODEL=codex/gpt-5.6-sol-xhigh`.
- **Reviewed freeze:** `.planning/spec_template_world_class.plan.md`.
- **Expected SHA-256:** `1b681ea74e5b606c52481e10d81377fbedffb5206074c860d0989c9e4cbe1fe3`.
- **Observed SHA-256:** `1b681ea74e5b606c52481e10d81377fbedffb5206074c860d0989c9e4cbe1fe3` — exact match.
- **Twin:** `.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md` has the same SHA-256; `cmp` confirmed byte identity.
- **Context:** `.planning/spec-template-world-class/CONTEXT.md` was read in full. Its `edf2c256…` metadata was treated as stale, as directed.
- **Method:** ran the mandatory Graphify query before exploring, then independently re-read the complete post-R6j freeze. Earlier reviews were treated as history, not authority. The residual hunt covered the template/index contract, kind packs and Clarify skip-turns, compiler/QC consumers, migration branches, and behavioral fixtures.

## R6j APPLY landing confirmation

### R6j-F01 — Functional AC-cell cardinality

The post-R6j freeze carries the accepted rule through the intended producer, consumers, and tests:

- The locked contract, Target REQUIREMENTS structure, Wave 1 parser work, and Wave 2 QC-4 all retain **exactly one** exact `AC-[0-9]{2}` per Functional `AC` cell. `AC-01, AC-02` fails, while repeated joins use multiple Functional rows.
- Wave 3 Step 8 now requires that exact emitted form, prohibits comma, semicolon, slash, pipe, and whitespace-separated aliases, and makes a malformed Functional cell a fail-before-pair-install condition.
- `review-cross-artifact` now uses the exact-one Functional-cell parser before orphan/coverage evaluation.
- Compiler/XART and Wave 6 behavioral coverage explicitly require `AC-01` PASS, `AC-01, AC-02` FAIL at mint/serialize/XART, and no install of malformed staged bytes.
- Wave 3 and Wave 6 inherited pins include `R6h-F01`, `R6i-F01`, and `R6j-F01`. The stricter Wave 1 grammar was not weakened.

No residual R6j-F01 defect remains on those surfaces.

### R6j-F02 — Step 8/XART `nfr-source-cell-list`

The post-R6j freeze also carries the named NFR parser end to end:

- Step 8 serializes Source cells with named `nfr-source-cell-list`, parses its staged output with the same parser as Wave 1, and fails before pair replacement on malformed Source bytes.
- `review-cross-artifact` reverse coverage, exclusivity, and overlap consume that named parser with the exact `, ` delimiter and exact structured/`SCAN:` atoms.
- The contract preserves `QA-01, SLO-01` as a two-atom PASS, rejects `QA-01,SLO-01`, and requires an overlap fixture whose second atom is visible only after correct list parsing.
- Wave 6 includes the malformed-staged-Source no-install behavior, and Wave 3/Wave 6 inherited pins include `R6i-F02` and `R6j-F02`.
- The exclusive live-Source-versus-disposition branches remain intact; neither overlap nor unresolved-source failure was weakened.

No residual R6j-F02 defect remains on those surfaces.

## Finding

### R6k-F01 — MED — Coverage Matrix cells and edge consistency still lack a normative machine contract

- **Location:** `Target structure — REQUIREMENTS.md` → `## Coverage Matrix`; Wave 2 `review-requirements` QC-8 and `review-cross-artifact`; Wave 3 Step 8; Wave 1/Wave 2/compiler behavioral fixtures.
- **Evidence from this freeze:** The matrix contract says:

  > “`| AC | REQ | Notes |` — every distinct AC **entry** exactly once; REQ list non-empty.”

  The Functional contract now permits one AC to be represented by multiple Functional rows:

  > “Many-to-one REQ↔AC if needed is via **multiple Functional rows**.”

  But QC-8 requires only that the matrix exists and that every SPEC `AC-nn` appears. XART says its Coverage Matrix parser consumes the exact two-digit REQ grammar and runs before fuzzy matching, but the freeze never defines a column-level matrix grammar: it does not require the matrix `AC` cell to be exactly one `AC-[0-9]{2}`, does not define how a non-empty list of multiple `REQ-[0-9]{2}` atoms is serialized, and does not require the matrix `(AC, REQ)` edge set to equal the edges represented by Functional rows. No behavioral fixture exercises a multi-REQ matrix row, a malformed delimiter, or a matrix/Functional pair mismatch.
- **Why it matters for the template contract:** Exact ID atom regexes do not define a list or a relationship. A conforming implementation could scan two exact tokens from `REQ-01/REQ-02`, `REQ-01; REQ-02`, or prose, while another accepts only comma lists. More seriously, a matrix can contain exact live IDs yet encode a different relationship—for example, Functional `REQ-01 → AC-01` while the matrix says `AC-01 → REQ-02`. The stated checks can still see every AC, non-empty exact REQ tokens, and Functional rows with AC joins without being required to reject the contradictory edge. Humans and downstream models would then receive two authoritative-looking traceability views with different semantics. The R6j exact-one Functional-cell fix makes this sharper: multiple Functional rows now require a deterministic aggregation representation in the one-row-per-AC matrix.
- **Suggested freeze-text fix:** Define a named, column-aware Coverage Matrix contract and bind it to every producer/consumer:
  1. Matrix `AC` cell = exactly one exact `AC-[0-9]{2}`; no prose or list aliases.
  2. Define a canonical `coverage-matrix-req-cell-list`, for example one or more exact `REQ-[0-9]{2}` atoms separated only by `, ` (U+002C + one U+0020), with no duplicates, unknown IDs, `NFR` IDs, empty atoms, alternate whitespace, or separator aliases.
  3. Require the parsed matrix edge set to equal the Functional-table edge set: for each distinct AC, its single matrix row lists exactly all live Functional `REQ-nn` rows whose exact-one AC cell is that AC—no missing, extra, or mismatched pairs.
  4. Bind Step 8 serialization plus staged self-parse, `review-requirements` QC-8, and `review-cross-artifact` to that same parser/equality check before canonical pair install.
  5. Add behavioral fixtures: Functional `REQ-01/AC-01` plus `REQ-02/AC-01` with matrix `AC-01 | REQ-01, REQ-02` PASS; no-space/semicolon/slash/pipe/whitespace aliases FAIL; and an exact-ID-but-wrong-pair matrix FAIL with malformed staged output unable to install.

## Independent residual-hunt notes

- **R6h/R6i:** The live Functional-cell example, old-column prohibition, exact-one cardinality, QC-4/`REQ-F30` no-fire behavior, and NFR Source list grammar remain present. The finding above concerns the separate Coverage Matrix representation, not a re-filing of the Functional AC-cell or NFR Source-cell contracts.
- **R6f:** `00–99` inclusive with `-00` allocatable, all exact-width catalog/REQ/NFR namespaces, no wrap/widen/reuse, Step 7 and Step 8 failure, and no-install fixtures remain intact.
- **R6b/R6c/R6d:** Non-canonical pair staging, staged 7a/8a inputs, snapshot/restore including absence, second-replace recovery, exact-byte fixed-point validation, and mutate-after-PASS invalidation remain intact.
- **R5k/R5j/R5i/R5h:** Exclusive NFR Source/disposition branches, overlap and neither-branch failure, true-greenfield two-file predicate, partial-pair preserve-or-fail-closed behavior, namespace-separated never-drop tombstone ledgers, and skip-without-reuse allocation remain intact.
- **SPEC/kinds/Clarify:** The seven-heading QC-1 core plus QC-10 Change History split, GWT/invariants/global IDs, substantive required packs with pack-local IDs, closed catalog and validated `multi`, kind-first gated turns, required `nfr` turns, two canonical outputs, Clarify non-writing rule, ingest preservation, and v0.35 lock remain coherent. No second residual finding was identified.

## Outcome

**NOT CLEAN** — one new MED residual template-contract gap (`R6k-F01`) remains on freeze SHA `1b681ea74e5b606c52481e10d81377fbedffb5206074c860d0989c9e4cbe1fe3`. The freeze twin is byte-identical, and R6j-F01/R6j-F02 themselves landed as encoded.
