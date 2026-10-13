# Rung 06 — Pi Codex GPT-5.6 Sol Extra High — Review pass 6

## Scope and freeze integrity

- Reviewer/runtime: Pi Codex, `PI_PROVIDER=omniroute`, `PI_MODEL=codex/gpt-5.6-sol-xhigh`.
- Reviewed freeze: `.planning/spec_template_world_class.plan.md`.
- Expected SHA-256: `1f11eacc50529cb8bab062a37bc80b4b6c988d855b17833332159b32a46d53fa`.
- Observed SHA-256: `1f11eacc50529cb8bab062a37bc80b4b6c988d855b17833332159b32a46d53fa`.
- Twin check: `.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md` has the same SHA-256 and is byte-identical to the freeze (`cmp -s` succeeded).
- Also read: `.planning/spec-template-world-class/CONTEXT.md`. Its `edf2c256…` freeze identity is stale metadata; this review used the supplied post-R6d pin.
- I ran the mandatory Graphify query before source exploration and independently read the complete pinned freeze. Passes 1–5 were treated as history, not authority for this verdict.

## Independent residual re-hunt

I re-hunted all three Policy E surfaces: the SPEC/REQUIREMENTS template contract, the software-kind catalog and Clarify skip-turns, and the compiler/QC/test/migration delivery plan.

### Fixed-point, staged validation, and pair installation

R6d-F01 remains materially present. The freeze names the **fixed-point**, invalidates PASS evidence after a successful 7a/8a mutation, and requires the applicable Step 8 / 7a/8a / `review-cross-artifact` cycle to re-PASS on:

> “the **exact** staged pair that will be installed.”

It further requires:

> “Install is allowed only when the last review/QC PASS was on those bytes with no further mutation.”

The compiler work still routes 7a to staged SPEC, routes 8a to staged REQUIREMENTS with the staged SPEC path as `source_inputs`, and makes a 7a/8a failure a no-install result. The named behavioral fixture still mutates staged REQUIREMENTS after a pair PASS and blocks installation until the applicable full cycle re-PASSes on the new bytes. All mutating Wave 6 branches (1, 1b, 2, 3, and 4b) retain the fixed-point requirement.

R6b-F01 and R6c-F01 also remain distinct and intact: Step 7 cannot durable-commit canonical SPEC before Step 8 succeeds; Step 8 evaluates the staged pair; both prior canonical states, including absence, are snapshotted before either canonical mutation; a second-replace failure restores both prior states; and staged-review failure plus commit-boundary fixtures cover true greenfield and an augment path. The 1b partial-pair route remains preserve-or-fail-closed.

### Other residual contract checks

- NFR reverse coverage remains an exclusive branch per eligible `QA-nn` / `SLO-nn` / `CTRL-nn`: live Source with zero disposition rows, or zero live Source cells with exactly one valid `### Source Dispositions` row. `review-requirements`, `review-cross-artifact`, Step 8, and the `QA-01` Source-plus-`out-of-scope`/`deferred` fixture retain the named overlap failure.
- SPEC catalog/core tombstones and REQUIREMENTS REQ/NFR tombstones remain separate, persistent allocator ledgers. Reissue failure, preserve-still-present behavior, next-free hole skipping, exact-width checks, and no-drop behavior remain stated across compiler, QC, augment, and fixtures.
- True greenfield still requires both canonical files absent. SPEC-absent/REQUIREMENTS-present remains the named 1b route and cannot silently replace `[REQ-03, NFR-02]` with `[]`; SPEC-present/REQUIREMENTS-absent enters the exhaustive SPEC-present augment/lock tree rather than greenfield.
- The template still carries seven kind-aware QC-1 core headings, QC-10 Change History, QC-11 Invariants, stable structured IDs, GWT/If-Then rules, conditional Decision Log, substantive required-pack bodies, optional-present validation, and the Implementations traceability comment.
- Kind tailoring remains closed-world. Atomic kinds and `multi` retain catalog validation, required-wins union behavior, forbidden/unlisted heading rejection, augment kind-reconciliation, pack-local IDs including `EX-nn`, and kind-first Clarify turns including the real `nfr` turn. Clarify still does not write SPEC/REQUIREMENTS, and no third canonical kind artifact is introduced.
- Exact-width parsing, duplicate/unlabeled source rejection, Coverage Matrix ordering, NFR Source/disposition checks, staged failure, snapshot restoration, and mutate-after-PASS behavior all retain named implementation/test obligations.

One new residual template/compiler contract gap remains.

## Findings

### R6f-F01 — MED — Global ID scheme and Wave 3 Steps 7/8: finite exact-width namespaces have no exhaustion behavior

**Location:** `### ID scheme`; `## Wave 3 — Compiler write path`, Work items 4–5; Wave 3 verification bullets; `## Wave 6 — Migration / augment / root lock`, behavioral allocator fixtures.

**Evidence:**

The global contract fixes every structured namespace to two digits and makes allocation monotonic:

> “zero-padded two digits, unique in the file. Compiler assigns sequentially at write time. Do not reuse IDs across augment versions”

For SPEC IDs, the allocator must retain retired slots permanently:

> “Sequential next-free skips tombstones **and** live current-file IDs”

Step 7 repeats that rule for `AC-nn`, `EX-nn`, and every catalog prefix. Step 8 imposes the same exact `REQ-[0-9]{2}` / `NFR-[0-9]{2}` grammar and next-free rule on the REQUIREMENTS ledger. The fixtures test skipping a single retired hole (`AC-03` → `AC-04`, `REQ-03` → `REQ-04`), but the freeze never defines what happens when every ID admitted by a namespace’s final two-digit grammar is live or tombstoned and another entry must be minted. It also does not define whether `-00` participates in the allocatable range; either interpretation still leaves a finite namespace with no exhaustion branch.

**Why it matters for the template contract:** Exact-width IDs, append-only tombstones, and never-reuse are all hard template invariants. Once a namespace is exhausted—through live entries, accumulated retirements, or both—there is no valid “next-free” ID. An implementation following the current prose could emit a three-digit ID that must fail QC-13/QC-2, reuse a retired/live ID, omit the new structured entry, or partially progress to a later pair gate. Each outcome breaks stable citation and compiler/QC agreement. This is especially relevant to long-lived augment specs: tombstoned IDs consume namespace capacity permanently even when the current document is small. The defect is not a request to weaken R5e/R5h/R5i exact-width or tombstone rules; it is the missing terminal case created by their combination.

**Suggested freeze-text fix:** Add a named **ID-namespace exhaustion fail-closed** rule shared by Step 7 and Step 8:

1. Define the allocatable numeric domain under the existing exact two-digit grammar, including an explicit decision on `00`.
2. Before accepting a staged mutation that needs a new ID, compute next-free against the union of live IDs and tombstones for that prefix. If no valid slot remains, emit a named compiler ISSUE and fail before any canonical pair replace; do not widen to three digits, wrap, reuse, renumber, silently omit the entry, or shrink tombstones.
3. Require an explicit operator-directed migration/split (for example, a new feature/spec lineage or a separately versioned future ID-schema migration) rather than guessing at the boundary.
4. Add parameterized allocator fixtures for a fully exhausted SPEC catalog namespace and a fully exhausted REQUIREMENTS namespace. Attempt one additional mint and assert a deterministic failure with both canonical artifacts/absence unchanged. Keep staged pair commit, snapshot-restore, fixed-point validation, exact-width QC, and both tombstone ledgers unchanged.

## Verdict

**NOT CLEAN**

One new residual finding is supported by this freeze: `R6f-F01`.
