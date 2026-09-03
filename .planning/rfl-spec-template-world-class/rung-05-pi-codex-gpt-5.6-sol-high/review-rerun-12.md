# Rung 05 — Pi Codex GPT-5.6 Sol High — Review pass 12

## Review identity and integrity

- **Role:** review-only (Policy C); no implementation, APPLY, triage, verification launch, outcome recording, branch change, commit, or freeze execution.
- **Model/provider observed:** `codex/gpt-5.6-sol-high` via `omniroute` (`PI_MODEL=codex/gpt-5.6-sol-high`, `PI_PROVIDER=omniroute`).
- **Freeze reviewed:** `.planning/spec_template_world_class.plan.md`
- **Expected and observed SHA-256:** `d45ccf6b686250638ba22778618c4f31761919c5fd00ef692569049ac6526401`
- **Twin:** `.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`
- **Twin check:** byte-identical (`cmp` exit 0).
- **Context read:** `.planning/spec-template-world-class/CONTEXT.md`.
- **Graphify-first check:** queried `agent-pi invoke gpt-5.6-sol-high NFR Source Dispositions exclusive overlap FAIL R5k-F01` before exploring the freeze.
- **Method:** independently reread the complete pinned freeze, then consulted pass 11 only after the fresh read to enforce residual-ID discipline.

## Verdict

# CLEAN

No new residual template-contract, software-kind-pack, compiler/QC, test-lock, or migration defect was found in the post-R5k freeze. There are zero `R5l-F*` findings.

This is a review verdict for this pinned blob only. It is not a ladder PASS, an APPLY decision, an outcome record, or an advancement recommendation.

## R5k-F01 APPLY confirmation — exclusive NFR branches

The exclusivity repair is present across the contract, both reviewers, compiler write path, and named fixture. I found no surviving inclusive-or path.

| Surface | Evidence in this freeze |
|---|---|
| ID scheme | Defines “exclusive branches”: an eligible `QA-nn` / `SLO-nn` / `CTRL-nn` is either in at least one NFR `Source` **and zero** disposition rows, or in zero Source cells **and exactly one** disposition row, “**not both**.” It separately names overlap FAIL and neither-branch FAIL. |
| REQUIREMENTS NFR contract | Repeats both branch cardinalities, identifies overlap as a named NFR reverse-coverage failure rather than QC-3 uniqueness, and retains one-to-many and many-to-one live NFR mappings. |
| Disposition parser | Requires the closed enum, non-placeholder rationale, owner, source resolution, and unique disposition Source IDs; explicitly rejects “live NFR Source **and** a dispositions row.” |
| `review-requirements` | Requires the same mutually exclusive cardinalities, says “**not both**,” names overlap FAIL on reverse coverage, preserves neither FAIL, and retains one-to-many/many-to-one Source mappings. |
| `review-cross-artifact` | Repeats the exclusive live-versus-disposition branches and rejects overlap and neither, while keeping `XART-F02` Functional-only. |
| Compiler Step 8 | Emits either the live mapping branch or the disposition branch, says “**not both**,” and must fail before replacing REQUIREMENTS if overlap is unresolved. It therefore cannot knowingly emit both mappings on a successful write. |
| Negative fixture | Wave 2 names `QA-01` as a live NFR Source plus `out-of-scope` (or `deferred`) as an overlap FAIL. Wave 3’s verification list repeats the same negative. |
| Cardinality positives | The contract expressly allows one eligible source to feed multiple NFR rows and multiple sources to feed one NFR row; exclusivity applies only to whether that structured source also has a disposition row. |

`SCAN:<section>#<line-or-id>` remains a permitted **forward** provenance form for compiler-discovered concerns without a structured pack ID. Reverse exclusivity is deliberately scoped to eligible structured `QA-nn` / `SLO-nn` / `CTRL-nn` sources, so `SCAN:` does not create a second disposition branch or weaken the structured-source overlap check.

No residual of R5k-F01 was re-filed.

## Independent residual re-hunt

### 1. Greenfield and partial-pair behavior

- Wave 6 step 1 defines true greenfield as **both** `.planning/SPEC.md` and `.planning/REQUIREMENTS.md` absent and explicitly says SPEC absence alone is not greenfield.
- Step 1b names the SPEC-absent / REQUIREMENTS-present behavior **preserve-or-fail-closed**. It reads the prior REQUIREMENTS tombstones and live IDs before any write, unions the ledger, verifies lineage, and fails before changing either artifact if lineage cannot be established.
- Step 8 applies prior-ledger union to every replacement path: augment branches 2/3/4b and partial-pair 1b. It allows `[]` only when no prior REQUIREMENTS ledger exists.
- The fixture with no SPEC and `id-tombstones: [REQ-03, NFR-02]` forbids resetting the ledger, later reissuing `REQ-03`, or leaving partial output.
- The inverse pair (SPEC present / REQUIREMENTS absent) enters the total SPEC-present decision tree (2/3/4/4b), not greenfield. Because no REQUIREMENTS ledger exists on that side, creating the missing index does not silently discard prior REQUIREMENTS tombstones.

No residual of R5j-F01 was found.

### 2. REQUIREMENTS tombstone contract

- REQUIREMENTS owns its canonical allocator state in YAML `id-tombstones`; the namespace is restricted to exact two-digit `REQ-[0-9]{2}` / `NFR-[0-9]{2}`.
- QC-2/QC-3 reject live/tombstoned overlap for both REQ and NFR IDs. Step 8 appends removed IDs, never drops entries, preserves still-present IDs, and allocates sequential next-free IDs while skipping both live and retired IDs.
- Wave 6 carries those rules through all augment branches, while true greenfield alone may begin at `[]`.
- SPEC catalog/core tombstones do not admit REQ/NFR IDs, so allocator ownership does not leak between the two canonical files.

No residual of R5i-F01 was found.

### 3. SPEC tombstone contract

- SPEC YAML owns catalog/core retirement state; Step 7 always writes the list, appends IDs on removal, preserves accumulated entries, and skips live plus retired IDs during allocation.
- QC-13 rejects live/tombstoned overlap and malformed IDs globally; QC-12 additionally rejects tombstoned pack-local IDs in present packs.
- The contract covers the core and all declared structured pack prefixes, including `US`, `AC`, `OQ`, `OOS`, `FLOW`, `EX`, `DEC`, `QA`, `CTRL`, `SIG`, `EP`, `DATA`, `ERR`, `CMD`, `SCR`, `STG`, and `SLO`; `ASM-nn` remains intentionally optional for assumptions.
- Wave 6 branches 2/3/4b persist and honor the list. Named AC and EX reissue failures, preserve-still-present behavior, and mint-after-retire behavior remain specified.

No residual of R5h-F01 was found.

### 4. IDs, parsers, and cross-artifact joins

- SPEC QC-13 keeps file-wide uniqueness and exact two-digit shape for core/catalog IDs, rejects unlabeled US/OQ/OOS entries and malformed optional-present pack entries, and rejects duplicate AC IDs before Coverage Matrix evaluation.
- REQUIREMENTS QC-2 retains exact `REQ-[0-9]{2}` / `NFR-[0-9]{2}`. Compiler minting, review-requirements, Coverage Matrix, ROADMAP parsing, and fixtures use the same grammar. The prohibited phrase “one or more digits” is absent.
- The exact `EX-nn` contract remains in the pack table, ID scheme, QC-12/QC-13, Step 7 mint/preserve rules, catalog fixtures, and malformed/missing/duplicate negatives.
- Functional AC→REQ traceability remains Functional-only. NFR provenance remains in the Source column and reverse coverage remains separate from the Functional Coverage Matrix.

### 5. Core template and kind packs

- The ontology still distinguishes seven QC-1 core headings, QC-10 Change History, kind-required packs, optional-present packs, and forbidden/unlisted packs.
- Required packs need substantive bodies and their catalog IDs; heading-only bodies, placeholders, and `_TBD — Clarify skipped illegally_` fail. Optional packs may be absent but must be well-formed when present.
- Change History remains a table with `spec-version`, date, and summary, including a unique/ordered current-version row and substantive summary. GWT versus non-interactive If/Then, Overview invariants, OQ/OOS IDs, and the Implementations comment remain coherent.
- The catalog preserves closed-world behavior, QC-6b two-plus/distinct/atomic validation before union, and required-wins for `multi`. No required pack prefix is missing from QC-12/QC-13.
- Security, telemetry, API, UX, data, errors, examples, operations, pipeline, mobile, CLI, Quality Attributes, and conditional Decision Log contracts remain represented without inflating the core template.

### 6. Clarify, compiler, QC, and tests

- Clarify remains capture-only and kind-first. It has a real field/turn for every named kind-gated pack, including separate `nfr` and `ops` turns, and validates `multi` before computing the pack union.
- Step 7 and Wave 6 branches 2/3/4b retain kind-reconciliation before write: forbidden/unlisted preserved headings must be migrated or presented for an operator decision, and unresolved conflicts fail before write rather than emitting `SPEC-F08`.
- Step 8 aligns forward NFR provenance, exclusive reverse coverage, dispositions parsing, tombstones, exact-width minting, and fail-before-replace behavior.
- Wave 2 and Wave 3 verification text retains named QC/fault strings and the key behavioral negatives: duplicate AC, malformed REQ/NFR and EX widths, retired-ID reissue, partial-pair ledger loss, required-pack stubs, dropped NFR sources, and live/disposition overlap.

### 7. KEEP REJECT and hygiene

The freeze still keeps exactly the intended canonical artifact split: SPEC.md plus REQUIREMENTS.md. Clarify does not write either artifact, ingest remains separate, kind catalog/pack files are compiler inputs rather than a third compiled consumer document, and REQUIREMENTS remains the REQ/NFR index with Out of Scope and Open Items.

`CONTEXT.md` retains historical freeze SHA/line metadata from an earlier pin. The user-supplied pin and both freeze twins match at `d45ccf6…`; the stale contextual metadata does not alter or break the reviewed template contract, so it is not filed as a pass-12 finding.

## Review boundaries

This pass did not mutate either freeze twin, patch live `templates/` or `skills/`, create `review.md`, overwrite an earlier rerun, launch verification, record a rung outcome, triage ACCEPT/REJECT, APPLY a change, switch branches, commit, execute freeze YAML, claim ladder PASS, or recommend advancement.
