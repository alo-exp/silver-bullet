# Rung 06 — Pi Codex GPT-5.6 Sol Extra High — Review pass 9

## Review identity and pin

- **Role:** review-only residual re-hunt; no APPLY, triage, verify, branch change, commit, or ladder-state mutation performed.
- **Runtime:** `PI_PROVIDER=omniroute`; `PI_MODEL=codex/gpt-5.6-sol-xhigh` (GPT-5.6 Sol Extra High through Pi Codex).
- **Reviewed freeze:** `.planning/spec_template_world_class.plan.md`
- **Expected SHA-256:** `4d0d3684ccd0a73ecd15698a19c1498b7919e65eb89b4ca20a2f74cfc96cccba`
- **Observed SHA-256:** `4d0d3684ccd0a73ecd15698a19c1498b7919e65eb89b4ca20a2f74cfc96cccba`
- **Twin:** `.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`
- **Twin check:** byte-identical (`cmp` exit 0).
- **Additional context read:** `.planning/spec-template-world-class/CONTEXT.md` in full. Its `edf2c256…` identity was treated as stale metadata, as directed.
- **Graph-first retrieval:** before exploring the freeze, ran `graphify query "agent-pi invoke gpt-5.6-sol-xhigh AC-nn QC-4 REQ-F30 Wave 1 R6h-F01"`.

I re-read the complete post-R6h freeze from the start and performed a residual-only hunt. R6h landed on its named Wave 1 and Wave 2 surfaces, but the new exact-cell contract exposes one unreconciled cardinality instruction. A separate machine-join grammar gap remains in the NFR Source contract. These are new `R6i-*` findings, not re-filings of applied IDs.

## Independent residual-hunt evidence

### Functional AC cells — R6h landed, with one residual contradiction

The applied text is present on all of R6h's named surfaces:

- The locked table and REQUIREMENTS contract say every Functional `AC` data cell is an exact `AC-nn`, not merely a header named `AC`.
- Wave 1 requires a template/example cell `AC-01`, forbids a live `Acceptance Criterion` (or equivalent old) column, and requires `test-spec-req-id-parse.sh` to parse the REQUIREMENTS Functional cell rather than only SPEC `**AC-01**`.
- Wave 2 requires a behavioral—not string-only—fixture in which valid `AC-01` passes QC-4 and `REQ-F30` does not fire, while the old live column fails.
- The NFR `Metric` column remains separate; the Functional Requirement body is normative prose, not a GWT paste.

The final review directive nevertheless still asks whether many-to-one may be represented by “explicit AC column lists,” which conflicts with the now-pinned exact-single-cell grammar. That residual is `R6i-F01` below.

### Finite ID namespaces — R6f remains complete

The freeze retains the named `00–99` inclusive domain, makes `-00` allocatable, covers every catalog/core prefix plus `REQ` and `NFR`, and fails closed before pair replacement when no unused slot remains. Wave 3 Step 7 and Step 8 separately carry the rule. Wave 6 applies it to every minting branch (`1`, `1b`, `2`, `3`, `4b`). The behavioral contract covers a full `EX-00`–`EX-99` namespace and a full `REQ-00`–`REQ-99` or `NFR-00`–`NFR-99` namespace, with no wrap, widening, tombstone reuse, or install. QC-2 remains post-shape validation rather than a substitute for pre-emit allocator failure.

### Fixed point and recoverable staged install — R6b/R6c/R6d remain complete

Step 7 renders only a staged SPEC; Step 8 renders and checks staged REQUIREMENTS. Compiler-invoked `review-spec`, `review-requirements`, and `review-cross-artifact` consume staged paths, with 8a receiving the staged SPEC as `source_inputs`. A 7a/8a failure cannot install.

Both prior canonicals—including absence—are snapshotted before either canonical path is mutated. Failure of the second replace after the first restores both prior states. After any successful 7a/8a mutation, prior PASS evidence is stale; Step 8, applicable 7a/8a review, and `review-cross-artifact` must re-PASS on the exact staged bytes to be installed. The mutate-after-PASS and commit-boundary fixtures remain explicit.

### NFR exclusivity, tombstones, and partial pairs remain intact

The live NFR Source and `### Source Dispositions` branches remain exclusive per eligible `QA-nn` / `SLO-nn` / `CTRL-nn`: one or more live Source references and zero disposition rows, or zero live references and exactly one valid disposition row—not both and not neither. `review-requirements`, `review-cross-artifact`, and Step 8 retain overlap failure, including the `QA-01` plus `out-of-scope`/`deferred` negative. The residual in `R6i-F02` is not exclusivity; it is the absent serialization/parser contract for a cell containing the multiple source atoms that the allowed many-to-one branch requires.

SPEC and REQUIREMENTS tombstone ledgers remain namespace-separated, persistent, and never shrink to free exhausted slots. True greenfield still requires both canonicals absent. SPEC-absent/REQUIREMENTS-present remains the named preserve-or-fail-closed path, including prior ledger union and the `[REQ-03, NFR-02]` fixture. A present SPEC routes through the explicit SPEC-present tree rather than silently becoming greenfield.

### Template, kinds, Clarify, compiler, and v0.35 lock

The broader contract remains coherent: seven universal QC-1 headings; Change History as a substantive QC-10 table; GWT/If-Then split; invariants; global exact IDs; kind-required bodies and pack-local IDs; required/optional/forbidden closed-world packs; all atomic kinds plus validated `multi`; kind-first Clarify with real domain turns and skip behavior; two canonical outputs only; and a total legacy/augment decision tree. Clarify still does not write SPEC/REQUIREMENTS, ingest remains separate, and the thin spec-floor remains unchanged.

## Findings

### R6i-F01 — MED — Functional AC-cell cardinality remains contradictory after R6h

- **Location:** `Target structure — REQUIREMENTS.md` → Functional Requirements; final `What RFL should review` item 6; corresponding Step 8/reviewer parser contract.
- **Evidence:** The post-R6h target contract now says: “each Functional data-row `AC` cell is exact `AC-nn` (e.g. `AC-01`)”. Wave 1 and Wave 2 reinforce a single exact-cell grammar and behavioral `REQ-F30` no-fire on `AC-01`. But the final review list still says: “**Compiler 1:1 AC→REQ** — keep as default; many-to-one only via explicit AC column lists?”
- **Why it matters for the template contract:** A cell such as `AC-01, AC-02` is not exact `AC-[0-9]{2}`. Leaving the list option open permits the compiler, QC-4, Coverage Matrix, and XART to choose incompatible cardinality models: an implementation can emit a list that the newly required parser must reject, or weaken the parser to accept lists and thereby violate R6h's exact-cell contract. That also makes `REQ-F30` behavior and the canonical AC→REQ join representation ambiguous for humans and models.
- **Suggested freeze-text fix:** Resolve the question in favor of the landed R6h contract for this wave: one Functional row has exactly one `AC-nn` cell, and Step 8/compiler/reviewers MUST NOT emit or accept AC lists in that cell. Remove the “many-to-one via explicit AC column lists?” alternative and add a malformed-list negative (for example `AC-01, AC-02` fails QC-4/no-install). If many-to-one is needed later, design a separate normalized join representation rather than weakening the exact Functional cell.

### R6i-F02 — MED — NFR `Source` permits many-to-one but defines no cell-list grammar or behavioral parser fixture

- **Location:** `Target structure — REQUIREMENTS.md` → Non-Functional Requirements; Wave 1 REQUIREMENTS template/fixture; Wave 2 `review-requirements` and `review-cross-artifact`; Wave 3 Step 8 and test contracts.
- **Evidence:** The target says each `NFR-nn` “cites **one or more** pack-local IDs (`QA-nn`, `SLO-nn`, `CTRL-nn`) or `SCAN:<section>#<line-or-id>`” and explicitly allows “one-to-many and many-to-one NFR Source lists.” Yet it specifies no canonical serialization or token grammar for multiple atoms in one markdown table cell. Wave 1 requires only the `Source` header and an empty `None identified` NFR example, not a live multi-source cell. Wave 2 says each Source must be “resolvable,” while its named behavioral fixtures cover the Source/disposition overlap negative but do not require a valid multiple-sources-to-one-NFR parse or malformed-list rejection.
- **Why it matters for the template contract:** Many-to-one requires multiple source atoms in one cell. Without a normative encoding, compiler and reviewers can disagree over comma, slash, `<br>`, prose, or partial-token parsing; one reviewer may resolve only the first atom while another treats the whole cell as unknown. That can falsely mark a valid source as dropped, falsely accept an unresolved source, or miss a Source/disposition overlap. `SCAN:` makes substring matching especially unsafe because it has a different atom shape and is not an eligible `QA`/`SLO`/`CTRL` disposition source.
- **Suggested freeze-text fix:** Define one canonical Source-cell list syntax and an exact atom parser—for example, one or more source atoms separated by a single named delimiter, where each atom is exactly `QA-[0-9]{2}`, `SLO-[0-9]{2}`, `CTRL-[0-9]{2}`, or a fully specified `SCAN:<section>#<line-or-id>` form. State whitespace, duplicate-token, unknown-token, and mixed structured/`SCAN:` behavior. Put a live Source example in the template/minimum or dedicated fixture. Add behavioral positives for one source feeding multiple NFR rows and multiple structured sources feeding one NFR row, plus malformed/partial-token negatives, and require `review-requirements`, `review-cross-artifact`, and Step 8 to consume the same parser before staged-pair install.

## Result

**NOT CLEAN** — reviewed freeze SHA-256 `4d0d3684ccd0a73ecd15698a19c1498b7919e65eb89b4ca20a2f74cfc96cccba`; freeze twin byte-identical. R6h's named Functional-cell template/parser/QC-4 changes landed, while two residual machine-join contract gaps remain: `R6i-F01` and `R6i-F02`.
