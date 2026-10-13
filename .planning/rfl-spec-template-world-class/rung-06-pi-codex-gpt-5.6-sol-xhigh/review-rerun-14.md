# Rung 06 — Pi Codex GPT-5.6 Sol Extra High — review pass 14

## Review identity and freeze verification

- **Role:** review-only. No APPLY, triage, verifier launch, outcome recording, ladder advance, branch change, commit, or freeze-twin mutation was performed.
- **Model/host:** Pi Codex through OmniRoute; observed `PI_PROVIDER=omniroute`, `PI_MODEL=codex/gpt-5.6-sol-xhigh`.
- **Reviewed freeze:** `.planning/spec_template_world_class.plan.md`.
- **Expected SHA-256:** `364594469c19a7127b93f5d39a01b539a62f407e0a10940b2edab0faa2d05458`.
- **Observed SHA-256:** `364594469c19a7127b93f5d39a01b539a62f407e0a10940b2edab0faa2d05458` — exact match.
- **Twin:** `.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md` has the same SHA-256; `cmp` confirmed byte identity.
- **Context:** `.planning/spec-template-world-class/CONTEXT.md` was read in full. Its `edf2c256…` freeze identity was treated as stale, as directed.
- **Method:** ran the mandatory Graphify query before exploration, then independently re-read the complete post-R6m freeze. Earlier passes were treated as history, not authority. The residual hunt covered the template/index contract, kind catalog and Clarify turns, reviewer semantics, compiler staging/install semantics, migration paths, and behavioral fixtures.

## R6m APPLY landing confirmation

R6m-F01 landed as encoded across the locked contract, ID scheme, target REQUIREMENTS structure, Waves 1–3 and 6, reviewer/XART contracts, compiler assertions, behavioral fixtures, inherited-pin lists, and the risk table:

- ID-bearing staged pairs use QC-7 **exact-ID** mode: a Functional `AC` cell maps only by equality with a live staged-SPEC `AC-nn`, using the same join as QC-8/R6l.
- The target no longer depends on fuzzy “same observable outcome” matching against the forbidden `Acceptance Criterion` prose column. Exact-ID mode is fail-closed, while prose/content alignment is expressly **legacy-only** when no exact `AC-nn` join cell exists.
- The freeze includes the positive case in which `REQ-01`/`AC-01` passes without paraphrasing the SPEC GWT, as well as fuzzy-column failure and no-install behavior.
- QC-4 retains its separate NFR `Metric` measurability branch: `fast` fails, `p95 <= 200 ms` passes, and a non-measurable staged Metric cannot install. Functional `REQ-F30` still does not fire on a valid exact-one `AC-nn` join cell.
- The contract is bound to Wave 2 `review-requirements` and `review-cross-artifact`, Wave 3 Step 8 serialize/parse and staged fixed-point flow, compiler assertions, and Wave 6 migration fixtures. Wave 2, Wave 3, and Wave 6 inherited pins name R6m-F01.
- R6l live staged-SPEC namespace/set equality, R6k matrix↔Functional edge equality and `coverage-matrix-req-cell-list`, R6j Step 8/XART cardinality/list bindings, R6i grammars, and the staged-pair/recovery/fixed-point contracts remain intact.

I did not re-file R6m-F01.

## Finding

### R6n-F01 — MED — The derived REQUIREMENTS pair identity is emitted but never fail-closed against the staged SPEC

- **Location:** `Target structure — REQUIREMENTS.md` → `Frontmatter (YAML) + human line`; Wave 2 `review-requirements` / `review-cross-artifact`; Wave 3 Step 8 and fixed-point; Wave 6 branches and behavioral fixtures.
- **Evidence from this freeze:** the target index carries four duplicated source-identity fields:

  > `derived-from: .planning/SPEC.md`  
  > `spec-version: 1`  
  > `feature-slug: <slug>`  
  > `software-kind: <kind>`

  and separately requires:

  > “Keep `**Derived from:** .planning/SPEC.md v{spec-version}` immediately under the H1”

  But the only explicit reviewer rule for this identity is presence-based:

  > “QC-6: YAML `derived-from:` **or** `**Derived from:**`.”

  It does not require the YAML source path to identify the logical staged-SPEC install target, the human line to agree with YAML, or REQUIREMENTS `spec-version`, `feature-slug`, and `software-kind` to equal the corresponding values on the staged SPEC. Step 8 likewise ends with:

  > “YAML + `**Derived from:**` including `software-kind`.”

  That says to emit the fields but defines no parse-and-compare gate or mismatch fixture. Partial-pair branch 1b alone says to “Verify/reconcile `derived-from`, `feature-slug`, and version lineage,” without a named equality rule, fault, or behavioral oracle; normal greenfield and augment branches do not carry even that prose. Wave 6 assertions that there be “no version skew” occur in write-failure/rollback fixtures and prove byte-atomic restoration, not semantic equality of an otherwise successfully installed pair.
- **Why it matters for the template contract:** REQUIREMENTS is the ID index **derived from this SPEC version**. A byte-atomic pair can currently pass exact AC namespace closure, matrix↔Functional edge equality, QC-7 exact-ID, and all parser checks while the index advertises a stale SPEC version, another feature slug or software kind, a wrong source path, or a human `Derived from` line that contradicts its YAML. That misroutes human and AI consumers, makes kind-derived NFR rows appear to belong to the wrong catalog selection, and corrupts augment lineage even though the AC IDs happen to remain valid. Fixed-point re-running does not close the hole when none of the re-run checks compares pair identity.
- **Suggested freeze-text fix:** add a named **staged-pair lineage equality** contract and bind it to all install paths:
  1. Before orphan/coverage and before canonical replacement, parse both exact staged artifacts. Require REQUIREMENTS `derived-from` to identify the logical canonical target of the staged SPEC, and require the human `**Derived from:**` path/version to agree with REQUIREMENTS YAML.
  2. Require exact equality of staged SPEC and REQUIREMENTS `spec-version`, `feature-slug`, and `software-kind`. For `software-kind: multi`, keep the staged SPEC’s QC-6b-validated `software-kinds` list authoritative; if REQUIREMENTS mirrors that list, require exact list equality as well.
  3. Give mismatch a named, non-advisory `review-cross-artifact`/REQUIREMENTS fault and run the check on the exact staged bytes before install. Bind it to Step 8 serialize+parse, 7a/8a fixed-point revalidation, and Wave 6 paths 1/1b/2/3/4b.
  4. Add behavioral fixtures: a fully matching pair passes; independently stale `spec-version`, wrong `feature-slug`, wrong `software-kind`, wrong `derived-from`, and contradictory human-line/YAML cases fail with no canonical pair install; an 8a mutation of any lineage field invalidates prior PASS evidence until the corrected exact pair re-passes.
  5. Retain R6m QC-7/NFR Metric, R6l namespace/set equality, R6k edge-set equality, R6j/R6i grammars, separate tombstone ledgers, staged pair commit, snapshot-restore, fixed-point, and exhaustion fail-closed unchanged.

## Independent residual-hunt notes

- **R6l/R6k/R6j/R6i/R6h:** every Functional and matrix `AC-nn` resolves to one unique live staged-SPEC AC; `distinct(Functional.AC) = distinct(Matrix.AC) = live staged-SPEC AC set`; phantom/tombstoned AC fails before coverage; matrix↔Functional edges remain equal; matrix REQ lists use exact `, ` and exact `REQ-[0-9]{2}` atoms; Functional cells remain exact-one `AC-[0-9]{2}` with list aliases rejected at mint/serialize/XART; `nfr-source-cell-list` keeps its distinct exact grammar and same-parser reverse/exclusive/overlap checks. The finding is about pair metadata lineage, not those settled joins.
- **R6f/R6b/R6c/R6d:** `00–99` inclusive (including `-00`) remains the finite allocatable domain for every required exact-width prefix; full namespaces fail before install without wrap, widening, or tombstone reuse. Step 7 remains staging-only; reviewers consume staged paths; both prior canonical states are snapshotted; second-replace failure restores both; any staged mutation makes prior PASS evidence stale until applicable Step 8/7a/8a/XART checks re-pass on the exact install bytes.
- **R5k/R5j/R5i/R5h:** eligible NFR sources retain exclusive live-Source versus exactly-one-Disposition branches; overlap and neither fail. True greenfield still means both files absent. Partial-pair 1b remains preserve-or-fail-closed. SPEC and REQUIREMENTS tombstone ledgers stay separate, persistent, exact-width, and exhaustion cannot free retired slots.
- **SPEC template, kinds, and Clarify:** the seven QC-1 core headings plus QC-10 Change History, GWT/If-Then split, Invariants, exact-width IDs, substantive required packs, optional-present validation, closed-world catalog, QC-6b `multi`, required-wins, `EX-nn`, and kind-first relevant-only turns remain coherent. Clarify remains non-writing; ingest remains separate; canonical outputs remain exactly SPEC.md and REQUIREMENTS.md.
- **Compiler/tests/v0.35 lock:** staged no-partial-output, recovery, fixed-point, exhaustion, Functional-cell, Source-list, Coverage Matrix, phantom-AC, QC-7 exact-ID, and NFR Metric fixtures remain named. The legacy decision tree stays total, and kind reconciliation remains fail-before-write. I found no second residual finding.

## Outcome

**NOT CLEAN** — one new MED residual template-contract gap (`R6n-F01`) remains on freeze SHA `364594469c19a7127b93f5d39a01b539a62f407e0a10940b2edab0faa2d05458`. The freeze twin is byte-identical. R6m-F01 landed as encoded; this pass does not triage or APPLY the residual.
