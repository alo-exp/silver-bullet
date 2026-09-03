# Rung 05 — Pi Codex GPT-5.6 Sol High — Review pass 10

## Review identity

- **Role:** review-only; no APPLY, triage, verification launch, outcome recording, branch change, commit, freeze execution, or live template/skill edit.
- **Model / host:** `gpt-5.6-sol-high` via Pi Codex / OmniRoute (`PI_PROVIDER=omniroute`, `PI_MODEL=codex/gpt-5.6-sol-high`); no model remap or substitution.
- **Freeze:** `.planning/spec_template_world_class.plan.md`
- **Expected and observed SHA-256:** `b04c6123138a1edf641f3de31c9171341a28e0e7800a640d6bd929ff5a06ff6c`
- **Twin:** `.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md` — byte-identical (`cmp` success; same SHA).
- **Context read:** `.planning/spec-template-world-class/CONTEXT.md`.
- **Graphify first:** ran `graphify query "agent-pi invoke gpt-5.6-sol-high REQUIREMENTS id-tombstones REQ NFR QC-2 R5i-F01"` before freeze exploration, then used a scoped query while checking partial-pair/allocator-state behavior.
- **Method:** independently reread all 672 lines of the pinned post-R5i freeze and the scoped CONTEXT, then consulted pass 9 only for residual-ID discipline. Template contract and kind packs were reviewed before compiler/QC/tests and hygiene.

## Result

The post-R5i freeze adds the intended REQUIREMENTS-side stable-ID mechanism without leaking namespaces or adding an artifact. REQUIREMENTS frontmatter now owns a same-file `id-tombstones` YAML list restricted to exact two-digit `REQ-nn` / `NFR-nn`; Step 8 says to preserve it, append removed row IDs, skip live and retired IDs when allocating, and preserve still-present IDs. `review-requirements` assigns missing-key severity, validates list shape, and makes a live/tombstoned overlap fail QC-2 / QC-3. Wave 6 applies persistence and allocation to its three SPEC augment branches. SPEC QC-12 / QC-13 / Step 7 remain restricted to core/catalog IDs.

One residual write-path hole remains at the greenfield boundary: Wave 6 classifies solely on absence of `.planning/SPEC.md`, then writes both outputs. If REQUIREMENTS already exists, that path is not an augment branch and has no instruction to read or preserve its canonical REQ/NFR tombstones before replacement. This directly conflicts with the unconditional “Never drop entries” rule and can re-enable a retired index ID.

## R5j-F01 — MED — SPEC-only greenfield detection can overwrite an existing REQUIREMENTS tombstone ledger

**Location:** Wave 6 — Migration / augment / root lock → Algorithm step 1, contrasted with the REQUIREMENTS frontmatter contract, Wave 3 Step 8, and Wave 6 augment persistence.

**Evidence quote:**

> “**Greenfield:** no `.planning/SPEC.md` → write `.planning/SPEC.md` + `.planning/REQUIREMENTS.md` as today (including `software-kind` from brief).”

> “Compiler Step 8 always writes it (`[]` if none). Never drop entries. Canonical allocator state for `REQ-nn` / `NFR-nn` lives in REQUIREMENTS.md”

> “Steps 2, 3, and 4b also persist REQUIREMENTS `id-tombstones` and skip retired `REQ-nn` / `NFR-nn`”

The persistence clause explicitly covers only steps 2, 3, and 4b. Step 1 tests only whether SPEC is absent; it does not require REQUIREMENTS to be absent, stop on a partial artifact pair, or import the existing REQUIREMENTS allocator state. Thus an existing `.planning/REQUIREMENTS.md` containing (for example) `id-tombstones: [REQ-03]` can enter the nominal greenfield path after SPEC is deleted, moved, or missing from a partial prior write. “Write … REQUIREMENTS.md” may replace it with the template default `[]`.

**Why it matters for the template contract:**

REQUIREMENTS is now the canonical stable-ID index and its same-file tombstones are the only state preventing historical `REQ-nn` / `NFR-nn` reuse. Losing that list makes a later obligation eligible for retired `REQ-03` even though the freeze promises that entries are never dropped and retired IDs are never reassigned. Current-file width, uniqueness, AC coverage, and live/tombstoned-overlap checks all pass after the ledger has been erased, so reviewers cannot reconstruct the lost retirement state. Partial pairs are plausible after manual recovery, file movement, or interruption between the two output writes. This is a residual of the R5i write-path integration, not a request for a third file or a reopening of the two-file decision.

**Suggested freeze-text fix:**

1. Define true greenfield as **both** `.planning/SPEC.md` and `.planning/REQUIREMENTS.md` absent.
2. Add a partial-pair branch for “SPEC absent, REQUIREMENTS present”: do not overwrite silently. Read and preserve valid existing REQ/NFR IDs plus `id-tombstones`, verify/reconcile `derived-from`, `feature-slug`, and version lineage, then either migrate with operator confirmation or fail before either write if lineage cannot be established.
3. Require Step 8 to union the prior REQUIREMENTS tombstone list on every path that replaces an existing REQUIREMENTS file; never initialize `[]` merely because SPEC was absent.
4. Add a behavioral fixture with no SPEC and an existing REQUIREMENTS containing live IDs plus `id-tombstones: [REQ-03, NFR-02]`; the run must preserve the ledger (and skip those IDs) or stop without changing either artifact. Include a no-partial-output assertion if pair writes are not atomic.

## R5i APPLY confirmation

| Required R5i-F01 property | Evidence in this freeze |
|---|---|
| REQUIREMENTS owns canonical index retirement state | Target frontmatter includes `id-tombstones: []`; prose says canonical `REQ-nn` / `NFR-nn` allocator state lives in REQUIREMENTS.md, not Git, a sidecar, or SPEC |
| Shape and namespace are closed | REQUIREMENTS entries must be exact `REQ-[0-9]{2}` or `NFR-[0-9]{2}`; SPEC tombstones reject those namespaces and REQUIREMENTS tombstones reject catalog/core prefixes |
| Normal Step 8 write and augment persistence | Step 8 says to write `[]` if no prior entries, append removed REQ/NFR IDs, and never drop entries; R5j-F01 identifies the uncovered partial-pair greenfield classification |
| Allocation and preservation | Step 8 next-free skips tombstones plus live current-file IDs and preserves still-present valid IDs; the named `REQ-03` retirement case mints `REQ-04` |
| Reviewer enforcement | `review-requirements` parses the list; missing key is ISSUE-new / INFO-legacy; live/tombstoned overlap fails QC-2 / QC-3 for both REQ and NFR |
| Augment coverage | Wave 6 branches 2, 3, and 4b persist and honor REQUIREMENTS tombstones alongside the separate SPEC list |
| Behavioral cases | Fixtures name retired `REQ-03` and `NFR-02` reissue failures, preserve-still-present, and mint-after-retire skip behavior |

The namespace, QC, allocator, and named augment behavior landed. `R5j-F01` is the remaining partial-pair/greenfield persistence defect.

## Prior APPLY residual check

| Pin requested by the brief | Result in this freeze |
|---|---|
| R5-F01 reconciliation in Wave 3 Step 7 and Wave 6 branches 2/3/4b; migrate-or-ASK; unresolved fails before write; behavioral cases | Present |
| R5-F02 QC-6 boundary; QC-6b iff `multi`; optional `clarify-brief`; non-required `derived-requirements`; Step 7 writes QC-6 keys | Present |
| R5-F03 NFR `Source` forward join in template, Step 8, reviewers, and cross-artifact checks | Present |
| R5b-F01 substantive required-pack bodies and catalog IDs; `_TBD`, heading-only, and empty stubs fail | Present |
| R5b-F02 two-plus distinct atomic `software-kinds`, validated before union | Present |
| R5b-F03 reverse structured-NFR coverage and guarded empty state | Present |
| R5c-F01 QC-13 exact-width/file-unique SPEC IDs and pre-coverage duplicate-AC failure | Present |
| R5c-F02 Change History table/current-version/ordered-unique/substantive-summary contract | Present |
| R5c-F03 Source Dispositions table, closed enum, source resolution, unique row, owner/rationale, and guarded `None identified.` | Present |
| R5e-F01 exact two-digit REQ/NFR grammar across compiler, reviewer, Coverage Matrix, ROADMAP, and fixtures | Present |
| R5f-F01 exact `EX-nn` contract across pack, compiler, QC, and fixtures | Present |
| R5h-F01 SPEC-only catalog/core tombstones, all prefixes, reissue failures, allocation skipping, augment persistence, and AC/EX fixtures | Present |
| R5i-F01 REQUIREMENTS-only REQ/NFR tombstones, reviewer overlap failure, allocation skipping, augment persistence, and fixtures | Present on Step 8 and augment branches; residual partial-pair greenfield hole filed as R5j-F01 |
| Catalog-derived QC-7 / `SPEC-F61`; Functional-only `XART-F02`; kind-aware Step 1; present forbidden heading `SPEC-F08`; all pack brief fields; real `nfr` turn | Present |

## Independent residual-hunt notes

- **REQUIREMENTS tombstones:** traced target YAML, Wave 1 template assertion, Wave 2 QC-2/QC-3 parsing, Wave 3 Step 8, Wave 6 branches 2/3/4b, and fixtures. Shape, live overlap, append-on-removal, preserve-still-present, next-free semantics, and missing-key ISSUE-new / INFO-legacy are aligned on those paths. Wave 6 step 1 can nevertheless replace an existing REQUIREMENTS ledger when SPEC is absent; this is R5j-F01.
- **Namespace separation:** SPEC `id-tombstones` admits exact two-digit core/catalog IDs only and remains owned by QC-12/QC-13/Step 7; REQUIREMENTS admits only exact two-digit REQ/NFR IDs and remains owned by QC-2/QC-3/Step 8. No cross-list allocation dependency or third sidecar is introduced.
- **SPEC tombstones:** all declared structured prefixes remain covered: `US`, `AC`, `OQ`, `OOS`, `FLOW`, `EX`, `DEC`, `QA`, `CTRL`, `SIG`, `EP`, `DATA`, `ERR`, `CMD`, `SCR`, `STG`, and `SLO`; optional `ASM-nn` remains intentionally optional. Step 7 and all supported augment paths preserve the accumulated list and skip retired IDs.
- **Template/core ontology:** rechecked seven QC-1 headings, QC-10 Change History table, QC-11 Invariants, GWT versus non-interactive If/Then, assumptions, decision promotion, OQ/OOS identities, Implementations, and AC→REQ Coverage Matrix. No unsupported universal pack or missing core contract was found.
- **Kinds and Clarify:** rechecked catalog membership, closed-world handling, `multi` two-plus/distinct/atomic validation, required-wins, optional decline, required pack bodies including `EX-nn`, and separate required `nfr`/`ops` turns. No incomplete union or nonexistent skip-turn was found.
- **Compiler/QC/tests:** Step 7 reconciliation still precedes writes and fails unresolved forbidden/unlisted headings before output; Step 8 aligns exact-width parsing and tombstone allocation with review-requirements, Coverage Matrix, ROADMAP, and named fixtures. No residual “one or more digits” baseline wording was found.
- **NFR provenance:** every NFR has structured or `SCAN:` forward provenance; every eligible `QA`/`SLO`/`CTRL` source is mapped or has exactly one valid closed-enum disposition; duplicate/unknown/unresolved dispositions and improper `None identified.` states fail. `SCAN:` remains a forward generated source rather than a structured reverse-coverage ID.
- **Finite two-digit namespaces:** the contract deliberately requires exact two-digit IDs, so each prefix has a finite space. The freeze does not state wrap/reuse behavior; however, current QC would reject any reused or widened ID, so exhaustion cannot silently corrupt traceability. Treating an eventual capacity stop as a blocker is not supported by this review surface.
- **KEEP REJECT / hygiene:** outputs remain SPEC.md + REQUIREMENTS.md; Clarify remains capture-only; ingest remains separate; kinds do not compile to a third consumer document. CONTEXT’s historical freeze SHA/line metadata is stale, but the explicitly pinned freeze and twin match; this does not break the template contract and is not filed.

# Verdict: NOT CLEAN

One new residual finding, `R5j-F01`, is filed. No triage, APPLY, verification, outcome recording, ladder PASS, or advancement recommendation is made.
