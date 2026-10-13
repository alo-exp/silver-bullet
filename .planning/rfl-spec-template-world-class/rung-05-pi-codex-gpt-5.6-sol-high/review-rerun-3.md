# Rung 05 — Pi Codex GPT-5.6 Sol High — Review pass 3

## Review identity

- **Role:** review-only; no APPLY, triage, verification launch, outcome recording, branch change, commit, freeze execution, or live template/skill edit.
- **Model / host:** `gpt-5.6-sol-high` via Pi Codex / OmniRoute; no model remap or substitution.
- **Freeze:** `.planning/spec_template_world_class.plan.md`
- **Expected and observed SHA-256:** `4a99ea1e75bfb3a0d364d365f61d2286ce1f82df1bd8070e12f599c1f1aa5374`
- **Twin:** `.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md` — byte-identical (`cmp` clean).
- **Context read:** `.planning/spec-template-world-class/CONTEXT.md`.
- **Prior reviews read without modification:** `review-rerun-1.md`, `review-rerun-2.md`.
- **Graphify first:** ran the mandated scoped query before source exploration.
- **Scope:** template contract and software-kind packs first; implementation waves second; hygiene last.

## Result

The post-R5b freeze contains the requested R5b-F01–F03 changes. QC-12 / `SPEC-F74` now rejects heading-only and `_TBD — Clarify skipped illegally_` required packs and requires their catalog IDs; QC-6b requires two or more distinct atomic kinds before pack union; and NFR reverse coverage is stated in the ID scheme, target REQUIREMENTS contract, both reviewers, Step 8, and tests. R5-F01–F03 and the earlier kind-aware QC-7 / `SPEC-F61`, Functional-only `XART-F02`, kind-aware compiler mapping, named fault-code checks, complete pack capture fields, and real `nfr` turn also remain present. KEEP REJECT remains intact.

This pass found one new global ID-integrity gap and two residual contract gaps. They do not undo any APPLYed decision: the first extends validation to ID-bearing core and optional content, the second makes the already-required Change History body executable, and the third closes the still-undefined exception in R5b reverse NFR coverage.

---

## R5c-F01 — HIGH — The stable-ID contract has no global uniqueness/shape check, allowing duplicate AC IDs to collapse traceability

**Location:** `ID scheme`; core headings; Wave 2 `review-spec` QC-8/QC-12; REQUIREMENTS snapshots and Coverage Matrix.

**Evidence quote:**

> “`US-nn`, `FLOW-nn`, `AC-nn`, `OQ-nn`, `OOS-nn`, `DEC-nn`, plus pack-local IDs … — **zero-padded two digits, unique in the file**.”

> “Add **QC-8:** every AC has `AC-nn` (`SPEC-F70`).”

> “For every **kind-required** pack, require ≥1 substantive well-formed entry with the catalog pack-local ID prefix (zero-padded, file-unique).”

> “`## Out of Scope` — snapshot by ID: `OOS-nn — <one line>`” and “`## Open Items` — `OQ-nn | Status | Owner | one-line`.”

> “`## Coverage Matrix` … every `AC-nn` exactly once.”

**Why it matters for the template contract:**

The declared ID scheme is global, but the executable reviewer rules are partial. QC-8 checks that an AC carries an `AC-nn` token; it does not say that AC IDs are unique or exactly zero-padded. QC-12 gives file-unique ID enforcement only to **kind-required** packs. No planned QC requires IDs on every User Story, Open Question, or Out-of-Scope item, and a present optional pack can contain substantive structured rows without its catalog prefix because only placeholder-only content is rejected for every-present packs.

A sharp passing counterexample is two distinct acceptance criteria both labeled `AC-01`. Each AC “has `AC-nn`,” and one Coverage Matrix row for `AC-01` can satisfy an ID-based parser while collapsing two obligations into one REQ join. Unlabeled `OOS` / `OQ` entries similarly prevent the promised snapshot-by-ID behavior, while an optional `## Data` or `## UX Flows` pack can remain unaddressable. Compiler minting language does not protect manually edited or stale artifacts; the two review passes are the contract gate. This directly compromises the primary goal that models and engineers can cite stable IDs and that AC coverage cannot silently collapse.

**Suggested freeze-text fix:**

Add a named global ID-integrity QC and fault code to Wave 2. It should:

1. parse every structured entry in core and every present pack;
2. require exactly the catalog prefix and two-digit shape where the contract declares an ID (`US-nn`, `AC-nn`, `OQ-nn`, `OOS-nn`, and every present pack’s prefix; keep `ASM-nn` optional as currently declared);
3. reject duplicate full IDs across the file, including duplicate `AC-nn` values;
4. require optional-present structured packs to use their IDs too, not only kind-required packs;
5. make Coverage Matrix validation operate on distinct AC entries and fail duplicate source IDs before coverage is evaluated.

Extend `test-review-spec-req-xart-qc-strings.sh` and behavioral fixtures with duplicate `AC-01`, malformed/non-zero-padded IDs, unlabeled US/OQ/OOS entries, and a substantive optional pack missing its prefix. Preserve append-never-renumber behavior on augment.

---

## R5c-F02 — MED — QC-10 enforces only the Change History heading, not the required table or current-version row

**Location:** core-required headings; Wave 2 `review-spec` QC-10; Wave 3 Step 7; Wave 6 augment.

**Evidence quote:**

> “`## Change History` — table: spec-version, date, summary.”

> “Missing Change History emits `SPEC-F72` (QC-10).”

> “Add **QC-10:** `## Change History` (`SPEC-F72`).”

> “Step 7: … write Change History … preserve `created` in augment; bump `spec-version`.”

**Why it matters for the template contract:**

A SPEC with a bare `## Change History` heading, a placeholder-only body, or a table whose latest row predates the YAML `spec-version` satisfies the planned QC-10. That makes the heading decorative even though the contract identifies history as the human audit record for augment versions. The compiler can bump `spec-version` without recording what changed, and both artifact-review passes can still report PASS. This is distinct from reopening the earlier decision that Change History belongs to QC-10 rather than QC-1; that ownership remains correct. The residual is that QC-10 does not validate the body it owns.

**Suggested freeze-text fix:**

Define QC-10 / `SPEC-F72` as a shape-and-consistency check, not heading presence only: require the declared columns (`spec-version`, date, summary), at least one substantive row, unique/ordered version values, and a row for the current YAML `spec-version` whose date agrees with `last-updated` (or define an explicit allowed relationship). Require non-placeholder summary text. Add greenfield, augment-version-bump, heading-only, stale-latest-row, and duplicate-version tests. Keep Change History outside QC-1.

---

## R5c-F03 — MED — Reverse NFR coverage can be bypassed through an undefined “non-requirement disposition”

**Location:** `ID scheme`; target REQUIREMENTS Non-Functional contract; Wave 2 review-requirements / review-cross-artifact; Wave 3 Step 8.

**Evidence quote:**

> “every eligible SPEC `QA-nn` / `SLO-nn` / `CTRL-nn` must appear in ≥1 REQUIREMENTS NFR `Source` (**or a recorded non-requirement disposition**).”

> “every eligible SPEC `QA-nn` / `SLO-nn` / `CTRL-nn` appears in ≥1 NFR Source (**or a recorded non-requirement disposition**); dropped sources FAIL.”

The target REQUIREMENTS shape defines only:

> `| ID | Requirement | Metric | Source | Priority |`

and no disposition table, field, enum, identifier, rationale requirement, owner, or reviewer parsing rule.

**Why it matters for the template contract:**

R5b-F03 correctly added the reverse direction, but its only exception has no canonical representation. An implementer or reviewer can treat arbitrary prose such as “not needed” as a disposition, while another can require a table; both conform to the freeze text. A dropped `CTRL-02` can therefore evade the promised FAIL without a machine-resolvable, reviewable record. The ambiguity also makes `None identified.` unsafe: it is unclear whether uncited eligible sources are formally disposed, merely overlooked, or allowed by prose. This leaves the exact omission path that reverse coverage was intended to expose.

**Suggested freeze-text fix:**

Choose one explicit rule:

- simplest: remove the exception and require every eligible structured source to map to at least one `NFR-nn`; or
- define a same-file subordinate contract under `## Non-Functional Requirements`, for example `### Source Dispositions` with `| Source | Disposition | Rationale | Owner |`, a closed disposition enum, non-placeholder rationale, and exactly one disposition per otherwise-unmapped source.

Then require both reviewers and Step 8 to parse that exact representation, reject unresolved/duplicate/unknown source IDs, and forbid `None identified.` while any eligible source lacks either an NFR mapping or a valid disposition. Add positive disposition and negative free-prose/missing-rationale/dropped-source fixtures. This keeps REQUIREMENTS as the one ID index and does not add a third artifact.

---

## Prior APPLY residual check

| Pin requested by brief | Result in this freeze |
|---|---|
| R5-F01 reconciliation in Wave 3 Step 7 and Wave 6 branches 2/3/4b; migrate/ASK; fail before write; behavioral cases | Present |
| R5-F02 QC-6 required set only slug + kind; QC-6b iff `multi`; optional clarify/path keys; Step 7 writes QC-6 keys | Present |
| R5-F03 NFR Source column and forward joins | Present |
| R5b-F01 QC-12 / `SPEC-F74` required-pack body, `_TBD` failure, catalog IDs | Present for required packs. R5c-F01 identifies the remaining global/core/optional ID-integrity boundary rather than removing that rule. |
| R5b-F02 two+ distinct atomic `software-kinds`, validated before union, with negatives | Present |
| R5b-F03 reverse structured-source coverage, cardinality, and empty-case rule | Present. R5c-F03 is the residual undefined exception path inside that rule. |
| Catalog-derived QC-7 / `SPEC-F61`; Functional-only `XART-F02`; kind-aware Step 1; `SPEC-F08`; all brief pack fields; real `nfr` turn | Present |

## KEEP REJECT and secondary checks

- Canonical outputs remain exactly SPEC.md + REQUIREMENTS.md; catalog and packs remain compiler inputs.
- Clarify remains capture-only and does not write either canonical artifact.
- Ingest remains a compiler input.
- REQUIREMENTS remains the REQ/NFR ID index; no finding proposes a third file or a Functional AC join for NFR rows.
- UX Flows remains catalog-gated rather than universal QC-1.
- CONTEXT’s stale freeze metadata is sibling hygiene and does not drive the verdict.

# Verdict: NOT CLEAN

R5c-F01 permits duplicate AC IDs to collapse the primary AC→REQ traceability contract and leaves other declared ID-bearing content unenforced. R5c-F02 and R5c-F03 leave Change History and the reverse-NFR exception materially under-specified. No triage, APPLY, verification, outcome recording, ladder PASS, or advancement recommendation is made.
