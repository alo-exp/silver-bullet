# Rung 06 — Pi Codex GPT-5.6 Sol Extra High — Review pass 7

## Scope and freeze integrity

- Reviewer/runtime: Pi Codex, `PI_PROVIDER=omniroute`, `PI_MODEL=codex/gpt-5.6-sol-xhigh`.
- Reviewed freeze: `.planning/spec_template_world_class.plan.md`.
- Expected SHA-256: `f7c632b85ae324b4ee74414acc2b9db40564a7f7bce01ca29300d437e1a58892`.
- Observed SHA-256: `f7c632b85ae324b4ee74414acc2b9db40564a7f7bce01ca29300d437e1a58892`.
- Twin check: `.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md` has the same SHA-256 and is byte-identical to the freeze (`cmp -s` succeeded).
- Also read: `.planning/spec-template-world-class/CONTEXT.md`. Its `edf2c256…` identity is stale metadata; this review used the supplied post-R6f pin.
- I ran the mandatory Graphify query before source exploration and independently read the complete pinned freeze. Passes 1–6 were treated as history rather than authority for this verdict.

## Independent residual re-hunt

I re-reviewed all three Policy E surfaces: the SPEC/REQUIREMENTS template contract, software-kind tailoring and Clarify skip-turns, and the compiler/QC/test/migration delivery plan. I found no residual template-contract gap on this post-R6f freeze.

### ID-namespace exhaustion fail-closed

R6f-F01 is present as a named mechanism in the global ID scheme and is carried into both allocator steps. The global contract defines:

> “Allocatable domain for every exact two-digit prefix the freeze already requires (`AC-nn`, `EX-nn`, every catalog prefix, `REQ-nn`, `NFR-nn`) is `00–99` inclusive (`-00` is allocatable).”

It also defines the terminal behavior:

> “When next-free cannot mint an unused exact two-digit ID (all `00–99` live or tombstoned for that prefix), **FAIL closed** before any canonical pair replace — do not wrap, do not three-digit, do not reuse tombstones.”

The coverage is not confined to that global statement:

- Wave 3 Step 7 applies it to `AC-nn`, `EX-nn`, and every catalog prefix, while preserving the SPEC tombstone ledger and exact-width QC.
- Wave 3 Step 8 applies it independently to `REQ-nn` and `NFR-nn`, preserving the REQUIREMENTS tombstone ledger. Wave 2 explicitly distinguishes allocator failure before emit from QC-2 rejecting malformed width after emit.
- Wave 6 applies it to every minting route—1, 1b, 2, 3, and 4b—with no install after exhaustion. No route authorizes wrapping, widening, tombstone reuse, ledger shrinkage, silent omission, or guessed migration.
- The behavioral fixtures cover both sides of the pair: full `EX-00`–`EX-99` and full `REQ-00`–`REQ-99` (or `NFR-00`–`NFR-99`), followed by one additional mint, with deterministic failure and prior canonical bytes/absence unchanged.

The R6f additions therefore close the finite-namespace terminal case without weakening exact two-digit grammar, either tombstone ledger, or pair-wide no-partial-output behavior.

### Fixed-point and staged review/QC

R6d-F01 remains intact after R6f APPLY. The freeze requires that after any successful 7a or 8a staged mutation, the applicable Step 8 / 7a/8a / `review-cross-artifact` cycle re-run on:

> “the **exact** staged pair that will be installed.”

Installation is bound to the last PASS on those bytes with no subsequent mutation. Both 7a and 8a invalidate earlier PASS evidence when they mutate a candidate. Step 7a operates on staged SPEC; Step 8a operates on staged REQUIREMENTS with the staged SPEC path as `source_inputs`; compiler-invoked Wave 2 reviews consume staged candidates. The named fixture still mutates REQUIREMENTS after a pair PASS and requires the applicable full cycle to re-PASS on the new bytes before installation. Wave 6 routes 1/1b/2/3/4b all inherit the fixed-point.

### Staged pair commit and recoverable pair-install

R6b-F01 and R6c-F01 remain distinct and complete:

- Step 7 renders only a non-canonical staged SPEC and MUST NOT durable-commit canonical `.planning/SPEC.md` before Step 8 succeeds.
- Step 8 renders staged REQUIREMENTS, validates the staged pair, and permits canonical replacement only after Step 8 plus staged 7a/8a and intervening QC PASS.
- A Step 8, 7a, 8a, overlap, tombstone, allocator, coverage, Source, or exhaustion failure installs neither candidate and leaves prior canonical bytes unchanged; true greenfield leaves both absent.
- Prior states of both canonical files, including absence, are snapshotted before either canonical mutation. A second-replace failure after the first replacement restores both prior states and deterministically handles temporary/recovery state.
- The fixtures separately exercise pre-install staged-review failure, Step 8 failures on true greenfield and augment, and the commit boundary on true greenfield plus an augment route. These are not conflated with fixed-point validation.

The inverse partial states do not reopen a hole: SPEC-absent/REQUIREMENTS-present is the named 1b preserve-or-fail-closed route, while SPEC-present/REQUIREMENTS-absent enters the total SPEC-present augment/lock tree and still uses pair staging, snapshot-restore, fixed-point validation, and exhaustion failure.

### Tombstones, NFR coverage, and exact-width joins

- True greenfield remains exactly both files absent. Route 1b unions existing REQUIREMENTS tombstones or fails before write; it cannot initialize `[]` from SPEC absence, silently wipe `[REQ-03, NFR-02]`, or later reissue `REQ-03`.
- SPEC catalog/core tombstones remain in SPEC and REQUIREMENTS `REQ-nn`/`NFR-nn` tombstones remain in REQUIREMENTS. Both lists are persistent, never-drop allocator state; neither exhaustion nor augment can shrink a ledger to free slots.
- QC-12/QC-13 and Step 7 retain exact-width, uniqueness, unlabeled-entry, duplicate, live-versus-tombstone, optional-present pack, and `EX-nn` checks. QC-2/QC-3 and Step 8 retain exact `REQ-[0-9]{2}` / `NFR-[0-9]{2}`, live-versus-tombstone, Coverage Matrix, and ROADMAP/parser alignment. No “one or more digits” grammar remains.
- NFR reverse coverage remains exclusive per eligible `QA-nn` / `SLO-nn` / `CTRL-nn`: one or more live NFR Source cells and zero dispositions rows, or zero live Source cells and exactly one valid `### Source Dispositions` row—not both. The overlap failure remains in the REQUIREMENTS contract, `review-requirements`, `review-cross-artifact`, Step 8 fail-before-pair-replace behavior, and the `QA-01` Source plus `out-of-scope`/`deferred` negative fixture.

### Template contract, kinds, Clarify, and delivery plan

- The core remains thin and dual-audience: seven kind-aware QC-1 headings, QC-10 Change History table tied to current `spec-version`, QC-11 `### Invariants`, stable IDs, GWT/allowed If-Then, Implementations traceability, and a Coverage Matrix rather than a second AC prose copy.
- Required packs require substantive bodies and catalog IDs; heading-only and `_TBD — Clarify skipped illegally_` bodies fail. Optional-present packs are validated. Examples use exact `EX-nn` and participate in tombstones, exact-width QC, and exhaustion handling.
- The kind catalog remains closed-world. `multi` requires two or more distinct atomic known kinds and uses required-wins. Forbidden/unlisted headings are omitted or reconciled before write, including augment kind changes; unresolved migration fails before write.
- Clarify remains kind-first and asks only required or accepted-optional domain turns. The real `nfr` turn remains mandatory for nfr-required kinds and distinct from Operations; all named pack fields are captured; decisions conditionally compile into Decision Log. Clarify does not write SPEC/REQUIREMENTS, ingest remains separate, and the output contract remains exactly the canonical SPEC/REQUIREMENTS pair.
- The named Wave 1/1b/2/3/4/6 fixtures and Wave 7 close-out commands cover template shape, kinds, QC, compiler allocation, migration, staging, recovery, fixed-point behavior, and exhaustion without tightening the Overview+Acceptance-Criteria floor or mutating the live root pair.

## Findings

No new `R6g-F*` findings.

## Verdict

**CLEAN**

The post-R6f freeze at SHA-256 `f7c632b85ae324b4ee74414acc2b9db40564a7f7bce01ca29300d437e1a58892` is byte-identical to its PLAN twin, R6f-F01 is fully represented across the global contract, Steps 7/8, all minting routes, and both exhaustion fixtures, and the independent residual hunt found no remaining template-contract defect.
