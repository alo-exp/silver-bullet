# Rung 05 — Pi Codex GPT-5.6 Sol High — Review pass 13

## Review identity and freeze integrity

- **Role:** review-only (Policy C). No implementation, APPLY, triage, verification launch, outcome recording, branch change, commit, or freeze execution was performed.
- **Model/provider observed:** `codex/gpt-5.6-sol-high` via `omniroute` (`PI_MODEL=codex/gpt-5.6-sol-high`, `PI_PROVIDER=omniroute`).
- **Freeze reviewed:** `.planning/spec_template_world_class.plan.md`
- **Expected SHA-256:** `d45ccf6b686250638ba22778618c4f31761919c5fd00ef692569049ac6526401`
- **Observed SHA-256:** `d45ccf6b686250638ba22778618c4f31761919c5fd00ef692569049ac6526401`
- **Twin:** `.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`
- **Twin check:** byte-identical (`cmp` exit 0); the twin has the same SHA-256.
- **Context read:** `.planning/spec-template-world-class/CONTEXT.md`.
- **Graphify-first check:** ran the required scoped query for `gpt-5.6-sol-high`, R5k NFR Source/Source Dispositions exclusivity, overlap FAIL, and an R5m residual before exploring.
- **Method:** reread the complete 674-line pinned freeze from the beginning, independently traced the requested residual classes across contract, compiler, reviewers, tests, and migration branches, and used prior pass material only afterward to avoid re-filing already-APPLYed IDs.

## Verdict

# CLEAN

No new residual template-contract, software-kind-pack, compiler/QC, test-lock, or migration defect was found in this pinned post-R5k freeze. There are **zero `R5m-F*` findings**.

This is only a review verdict on the pinned blob. It is not a ladder PASS, an APPLY/triage decision, an outcome record, or an advancement recommendation.

## Independent residual re-hunt evidence

### 1. NFR live-source/disposition exclusivity

The freeze consistently encodes two mutually exclusive branches for each eligible structured SPEC source (`QA-nn`, `SLO-nn`, or `CTRL-nn`):

1. the source occurs in one or more live NFR `Source` cells and in **zero** `### Source Dispositions` rows; or
2. it occurs in zero live NFR `Source` cells and in **exactly one** valid disposition row.

The ID scheme, REQUIREMENTS NFR contract, `review-requirements`, and `review-cross-artifact` all say **not both**, retain neither-branch failure, and name overlap as an NFR reverse-coverage failure rather than QC-3 uniqueness. Compiler Step 8 applies the same cardinalities and fails before replacing REQUIREMENTS if overlap remains unresolved. The Wave 2 and Wave 3 test contracts retain the concrete negative where `QA-01` is both a live NFR Source and `out-of-scope` or `deferred`.

The live branch still permits one source to feed multiple NFR rows and multiple structured sources to feed one NFR row. `SCAN:<section>#<line-or-id>` remains forward provenance for a compiler-discovered concern without a structured pack ID; it does not enter or dilute the reverse exclusivity rule for the eligible structured prefixes.

No residual of R5k-F01 remains.

### 2. Greenfield and both partial-pair directions

- Wave 6 step 1 defines true greenfield as **both** `.planning/SPEC.md` and `.planning/REQUIREMENTS.md` absent and explicitly rejects SPEC-only absence as greenfield.
- Step 1b names SPEC-absent / REQUIREMENTS-present behavior **preserve-or-fail-closed**. It reads prior tombstones and live IDs before any write, unions the REQUIREMENTS ledger, reconciles lineage, and changes neither artifact if lineage cannot be established.
- Step 8 requires prior REQUIREMENTS tombstones to be unioned on every replacement path—2, 3, 4b, and 1b—and permits `[]` only when no prior REQUIREMENTS ledger exists.
- The no-SPEC fixture with `id-tombstones: [REQ-03, NFR-02]` forbids ledger reset, later `REQ-03` reuse, and partial output.
- The inverse pair, SPEC present / REQUIREMENTS absent, enters the total SPEC-present decision tree (2/3/4/4b), not greenfield. There is no prior REQUIREMENTS ledger to erase; creation of the missing index therefore does not silently shrink canonical REQUIREMENTS allocator state.

No residual of R5j-F01 remains.

### 3. REQUIREMENTS tombstones and exact-width index IDs

REQUIREMENTS owns the canonical `REQ-nn` / `NFR-nn` allocator ledger in its own YAML `id-tombstones`. The list is namespace-restricted to exact two-digit `REQ-[0-9]{2}` and `NFR-[0-9]{2}` entries, persists across replacement/augment paths, appends removed live rows, and is never silently dropped. Step 8 preserves still-present IDs and allocates next-free IDs while skipping both live IDs and tombstones. QC-2/QC-3 reject a live/tombstoned overlap for either namespace.

The compiler, review-requirements, cross-artifact/Coverage Matrix and ROADMAP parsers, and fixtures share the exact two-digit grammar. The freeze contains no permissive “one or more digits” rule; malformed-width examples (`REQ-1`, `REQ-001`, `NFR-2`, `NFR-0003`) remain named failures.

SPEC catalog/core tombstones do not admit REQ/NFR, and REQUIREMENTS tombstones do not admit SPEC prefixes, so allocator ownership remains separated without a sidecar or third canonical artifact.

No residual of R5i-F01 or R5e-F01 remains.

### 4. SPEC tombstones and global ID integrity

SPEC YAML `id-tombstones` remains the canonical retirement ledger for core and catalog pack IDs. Step 7 appends removed IDs, never drops accumulated entries, preserves still-live valid IDs, and skips live plus retired IDs during sequential allocation. Wave 6 branches 2/3/4b carry those rules through augment.

QC-13 / `SPEC-F75` requires exact two-digit, file-unique IDs and rejects live/tombstoned overlap; QC-12 / `SPEC-F74` additionally rejects a present pack entry using a tombstoned pack ID. Coverage includes `US`, `AC`, `OQ`, `OOS`, `FLOW`, `EX`, `DEC`, `QA`, `CTRL`, `SIG`, `EP`, `DATA`, `ERR`, `CMD`, `SCR`, `STG`, and `SLO`; `ASM-nn` remains intentionally optional. Named AC and EX retired-ID failures, preserve-still-present behavior, and mint-after-retire behavior remain in the test contract.

No residual of R5h-F01, R5c-F01, or R5f-F01 remains.

### 5. Template and software-kind contract

- The universal shape remains seven QC-1 core headings, with Change History separately enforced by QC-10 and `### Invariants` by QC-11.
- Change History is a real table with `spec-version`, date, and summary; it requires a substantive current-version row plus unique/ordered versions and rejects heading-only, placeholder-only, and stale-latest states.
- User Stories, AC, Open Questions, and Out of Scope retain addressable IDs. Interactive AC use Given/When/Then; If/Then remains limited to non-interactive criteria.
- Required packs need substantive bodies and their catalog-local IDs. Heading-only content, empty/placeholder bodies, and `_TBD — Clarify skipped illegally_` fail. Optional packs may be absent but must satisfy their pack contract when present. Forbidden and closed-world-unlisted headings remain omitted and fail as `SPEC-F08` when improperly present.
- `examples` remains exact `EX-nn` throughout the pack table, QC-12/QC-13, compiler mint/preserve rules, and positive/missing/unlabeled/malformed/duplicate fixtures.
- The catalog retains closed membership, QC-6b two-or-more distinct atomic kinds, validation before `multi` union, and required-wins. Required-pack prefixes in the catalog are represented in QC-12/QC-13.
- Security, telemetry, API, UX, data, errors, examples, CLI, mobile, pipeline, operations, Quality Attributes, and conditional Decision Log remain kind-tailored rather than forced into the core.

### 6. Clarify, compiler, reviewers, and tests

Clarify remains kind-first and capture-only. It has a named field/turn for each kind-gated pack, including distinct `nfr` and `ops` turns, validates `multi` shape before pack computation, skips forbidden/declined optional turns, and does not write SPEC.md or REQUIREMENTS.md.

Step 7 and Wave 6 augment branches 2/3/4b run kind reconciliation before write. Existing forbidden/unlisted headings cannot survive preserve-body: prose must be migrated through the presented mechanism or resolved by ASK, with fail-before-write if unresolved. Step 8 aligns exact-width index allocation, REQUIREMENTS ledger preservation, Source provenance, mutually exclusive reverse coverage, and fail-before-replace behavior.

The named verification contracts cover required-pack bodies, `_TBD` rejection, duplicate/unlabeled/malformed SPEC IDs, exact `EX-nn`, exact REQ/NFR widths, retired SPEC and REQUIREMENTS IDs, partial-pair ledger preservation, duplicate AC failure before coverage, dropped structured NFR sources, invalid dispositions, and live-source/disposition overlap. No compiler/reviewer/parser mismatch survived this read.

### 7. KEEP REJECT and hygiene boundary

The freeze still specifies exactly two canonical outputs: SPEC.md and REQUIREMENTS.md. REQUIREMENTS remains the REQ/NFR index with Out of Scope and Open Items; kind catalog and pack files are compiler inputs, not a third consumer artifact. Clarify does not write the outputs, and ingest remains separate.

`CONTEXT.md` still contains historical freeze SHA/line/byte metadata from an earlier pin. The user-pinned review blob and its phase twin independently match at `d45ccf6…`; this stale contextual metadata does not alter the template contract and is not an R5m finding.

## Review boundaries

This pass did not mutate either freeze twin, patch live `templates/` or `skills/`, create `review.md`, overwrite a prior rerun, launch verification, record a rung outcome, triage ACCEPT/REJECT, APPLY a change, switch branches, commit, execute freeze YAML, claim ladder PASS, or recommend advancement.
