# Rung 05 — Pi Codex GPT-5.6 Sol High — Review pass 2

## Review identity

- **Role:** review-only; no APPLY, triage, verification launch, outcome recording, branch change, commit, or live template/skill edit.
- **Model / host:** `codex/gpt-5.6-sol-high` via Pi Codex, `PI_PROVIDER=omniroute`; no model remap or substitution.
- **Freeze:** `.planning/spec_template_world_class.plan.md`
- **Expected and observed SHA-256:** `acaae5f796c963ded0e8a8f74ca09e9d16156c59bfc2b126ddd3e31ed9f79a5b`
- **Twin:** `.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md` — byte-identical (`cmp` clean; same SHA).
- **Context read:** `.planning/spec-template-world-class/CONTEXT.md`.
- **Graphify first:** ran the mandated scoped `graphify query` before source exploration.
- **Scope:** template contract and kind packs first; implementation waves second; hygiene last.

## Result

The post-APPLY freeze contains the requested R5-F01–F03 changes: kind-reconciliation is present in Wave 3 Step 7 and Wave 6 branches 2/3/4b with migrate-or-ASK and fail-before-write; QC-6 is limited to shaped `feature-slug` plus catalog-valid `software-kind`, with QC-6b presence-iff-`multi`; and the REQUIREMENTS NFR table, Step 8, review-requirements, and cross-artifact prose now carry the `Source` join. Earlier kind-aware QC-7 / `SPEC-F61`, Functional-only `XART-F02`, kind-aware Step 1, named fault-code tests, `SPEC-F08`, complete pack-field capture, and the real `nfr` turn also remain present. KEEP REJECT remains intact.

This pass found three residual template-contract gaps. The first lets a required kind pack pass review with no usable contract body. The second accepts malformed `multi` selectors that cannot denote the catalog union promised by the template. The third makes the newly added NFR provenance join only one-way, so omitted SPEC NFR sources remain invisible.

---

## R5b-F01 — HIGH — Kind-aware QC checks required pack headings, but not required pack bodies or pack-local IDs

**Location:** Section ontology; ID scheme; Wave 2 `review-spec`; Wave 4 capture/required-empty behavior.

**Evidence:**

> “**kind-required** | Required when the kind’s pack list says so | Missing = ISSUE for that kind”

> “Optional headings: omit if the brief has nothing. Kind-required headings: compiler writes a real section from the brief, or a `_TBD — Clarify skipped illegally_` ISSUE rather than a fake happy path.”

> “Every structured pack is ID-addressable … zero-padded two digits, unique in the file.”

> “required + empty → `_TBD — Clarify skipped illegally_` ISSUE.”

But Wave 2 specifies only:

> “**QC-1 is kind-aware:** required `##` set = **7 QC-1 core headings** … ∪ kind-required packs”

and adds ID validation only for AC:

> “Add **QC-8:** every AC has `AC-nn` (`SPEC-F70`).”

There is no named `review-spec` check or `SPEC-F*` fault that rejects a present required pack whose only body is `_TBD — Clarify skipped illegally_`, another placeholder, or structured rows missing the pack-local ID (`EP-nn`, `CTRL-nn`, `SLO-nn`, and so on). The ontology’s “placeholder-only = ISSUE” is stated on the optional-class row, but Wave 2 does not turn even that rule into an executable reviewer criterion.

**Why it matters for the template contract:**

For `http-api`, a compiled file can contain `## API`, `## Security`, `## Telemetry`, `## Errors`, and `## Examples`, with one or more required headings containing only the compiler’s `_TBD` marker. Heading-only QC-1 is satisfied. Core QC-2–QC-11 do not validate those pack bodies, so two artifact-review passes can report clean despite the compiler explicitly marking required contract content as skipped illegally. Similarly, API/security/operations rows without their promised stable IDs can pass, undermining the stated model-facing ability to cite every structured pack. This is a supported compiler path, not only a hand-edited malformed artifact.

**Suggested freeze-text fix:**

Add a named kind-pack shape QC to Wave 2 with a `SPEC-F*` code. For every present pack, load its pack contract and reject placeholder-only bodies; for every kind-required pack, require at least one substantive, well-formed entry; for every structured entry, require the pack-local ID prefix, zero-padded shape, and file-wide uniqueness. Explicitly recognize `_TBD — Clarify skipped illegally_` as an ISSUE, not content satisfying QC-1. Extend `test-review-spec-req-xart-qc-strings.sh` and kind fixtures with required-empty, optional-placeholder, missing-pack-ID, and duplicate-ID negatives. The compiler may still write the marker to preserve an audit trail, but review must not PASS it.

---

## R5b-F02 — MED — `software-kinds` QC accepts lists that violate the catalog’s “Two+ of the above” contract

**Location:** Frontmatter `software-kinds`; `multi` catalog row; Wave 2 QC-6b; Wave 4 Turn 0.

**Evidence:**

> “if `software-kind: multi` then `software-kinds` MUST be a **non-empty list**”

> “`multi` | **Two+ of the above** | union of listed `software-kinds` required packs …”

> “Extend QC-6: … `software-kind` (catalog enum or `multi`) required.”

> “**QC-6b:** `software-kinds` present and non-empty iff `software-kind: multi`; absent otherwise”

The QC validates only that the list is non-empty. It does not require at least two entries, require each member to be a known atomic catalog kind, reject nested `multi`, or reject duplicates. Thus `[cli]`, `[spaceship, cli]`, `[multi, web-ui]`, and `[cli, cli]` all meet the stated QC-6b presence/non-empty rule while failing to denote “Two+ of the above.”

**Why it matters for the template contract:**

`software-kinds` is the input to required-pack union, forbidden-pack intersection, Clarify skip-turns, kind reconciliation, and catalog-derived QC-1/QC-7. A malformed list makes those computations undefined or silently incomplete while the frontmatter reviewer passes it. This is a metadata-shape defect in the primary template contract and a residual beyond the applied presence-iff rule; it does not reopen the decision to keep `multi`.

**Suggested freeze-text fix:**

Define a valid `software-kinds` value as a YAML list of at least two **distinct atomic** catalog kinds, with no `multi` member and no unknown value. Require compiler/Clarify validation before pack computation and extend QC-6b to enforce the same shape under ISSUE-new / INFO-legacy policy. Add negative tests for one member, duplicate members, unknown members, nested `multi`, scalar values, and an empty list; retain positive required-wins fixtures.

---

## R5b-F03 — MED — The applied NFR `Source` join validates NFR→SPEC provenance but not SPEC→NFR coverage

**Location:** REQUIREMENTS Non-Functional table; Wave 2 review-requirements / cross-artifact; Wave 3 Step 8.

**Evidence:**

> “each `NFR-nn` cites one or more pack-local IDs (`QA-nn`, `SLO-nn`, `CTRL-nn`) or `SCAN:<section>#<line-or-id>`”

> “**NFR Source QC:** every `NFR-nn` row has a resolvable Source”

> “each row must cite that source in the Source column”

> “Step 8: … NFR from Quality Attributes / kind NFR packs / scan with **Source** join”

These clauses all constrain an existing REQUIREMENTS row. None requires each eligible structured NF source in SPEC (`QA-nn`, `SLO-nn`, `CTRL-nn`) to appear in at least one NFR Source cell. A compiler may omit `QA-02` or `SLO-01` entirely while every emitted `NFR-nn` has a valid source and all planned checks pass.

**Why it matters for the template contract:**

The Source column fixes provenance for rows that survived derivation, but it does not detect the loss scenario that motivated an auditable ID join. A world-class two-file contract needs to reveal both fabricated NFR rows and dropped quality/security/operations obligations. Otherwise the REQUIREMENTS ID index can silently underrepresent the selected SPEC packs despite looking fully traceable. This is a residual directionality gap in the applied R5-F03 fix, not a proposal for a third file or an AC join on NFR rows.

**Suggested freeze-text fix:**

Make NFR traceability bidirectional in Step 8 and the cross-artifact reviewer: (1) every NFR Source reference resolves to the cited SPEC ID or valid `SCAN:` locator; and (2) every eligible `QA-nn`, `SLO-nn`, and `CTRL-nn` source is represented by at least one `NFR-nn`, unless an explicit contract-defined non-requirement disposition is recorded. Define allowed cardinality for one-to-many and many-to-one mappings rather than assuming exactly one row. Add tests for an unresolved source, a dropped SPEC source, duplicate/combined source lists, and the valid empty-NFR case when no eligible sources exist.

---

## Prior APPLY residual check

| Pin requested by brief | Result in this freeze |
|---|---|
| R5-F01 kind-reconciliation in Wave 3 Step 7 and Wave 6 branches 2/3/4b; migrate/ASK; unresolved fails before write; two behavioral cases | Present; no forbidden-heading residual re-filed |
| R5-F02 QC-6 only `feature-slug` + `software-kind`; QC-6b `software-kinds` iff `multi`; optional `clarify-brief`; template-default `derived-requirements`; Step 7 writes QC-6 keys | Present. R5b-F02 is the remaining member/cardinality validation for the list, not a request to broaden QC-6 to optional keys |
| R5-F03 NFR `Source` column and forward source join in Step 8 + reviewers | Present. R5b-F03 is the remaining reverse-coverage direction |
| Catalog-derived QC-7 / `SPEC-F61`, including `multi` and optional-omitted plugin UX | Present |
| `XART-F02` Functional-only; NFR exempt from AC join | Present and unchanged |
| Wave 3 Step 1 kind-aware mapping; Wave 2 named-code grep/test contract; present forbidden = `SPEC-F08` | Present |
| Wave 4 all pack fields + `decisions`; real required/optional `nfr` turn | Present |

## KEEP REJECT and secondary checks

- Canonical outputs remain exactly SPEC.md + REQUIREMENTS.md; packs/catalog are compiler inputs.
- Clarify remains capture-only and does not write SPEC.md or REQUIREMENTS.md.
- Ingest remains an input path.
- REQUIREMENTS remains the REQ/NFR ID index, with kind-derived NFRs as rows.
- No finding proposes making UX Flows universal, merging kinds into a third document, or applying the Functional AC join to NFR rows.
- CONTEXT’s stale freeze metadata is sibling plan hygiene and does not drive this verdict.

# Verdict: NOT CLEAN

R5b-F01 is a HIGH template/reviewer contradiction on the explicit required-empty compiler path. R5b-F02 and R5b-F03 leave first-class `multi` selection and NFR cross-artifact coverage materially under-validated. No triage, APPLY, verification, outcome recording, or ladder-advancement claim is made.
