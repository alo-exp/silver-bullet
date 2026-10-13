# Rung 06 — Pi Codex GPT-5.6 Sol Extra High — Review pass 2

## Scope and freeze integrity

- Reviewer/runtime: Pi Codex, `PI_PROVIDER=omniroute`, `PI_MODEL=codex/gpt-5.6-sol-xhigh`.
- Reviewed freeze: `.planning/spec_template_world_class.plan.md`.
- Expected SHA-256: `d45ccf6b686250638ba22778618c4f31761919c5fd00ef692569049ac6526401`.
- Observed SHA-256: `d45ccf6b686250638ba22778618c4f31761919c5fd00ef692569049ac6526401`.
- Twin check: `.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md` is byte-identical to the freeze (`cmp -s` PASS; the twin has the same SHA).
- Also read: `.planning/spec-template-world-class/CONTEXT.md`. I treated its older `edf2c256…` identity as stale metadata and used the supplied, independently verified freeze pin.
- I ran the mandatory Graphify query before source exploration and re-read the pinned freeze rather than copying pass 1.

## Independent residual re-hunt

I re-hunted all three Policy E surfaces: the SPEC/REQUIREMENTS template contract, software-kind catalog plus Clarify skip-turns, and the implementation/compiler/QC/test plan. In particular, I independently checked the R5k exclusive NFR branches, R5j partial-pair behavior, both tombstone namespaces and allocators, exact-width ID grammars, required/optional/forbidden packs, required-pack bodies and IDs, GWT/invariants/Change History, and every Wave 3/Wave 6 write branch.

The R5k text itself remains exclusive: an eligible `QA-nn` / `SLO-nn` / `CTRL-nn` is live in one-or-more NFR Source cells with zero disposition rows, or is in zero Source cells with exactly one valid disposition row, and never both. `review-requirements`, `review-cross-artifact`, Step 8, and the `QA-01` overlap fixture retain the named overlap FAIL; one-to-many and many-to-one live mappings remain allowed. R5j's SPEC-absent/REQUIREMENTS-present branch also retains preserve-or-fail-closed behavior and the `[REQ-03, NFR-02]` fixture.

One different residual write-path defect remains.

## Findings

### R6b-F01 — HIGH — Wave 3 Steps 7–8 / Wave 6 writing branches: cross-artifact failure can commit only the new SPEC

**Location:** `## Wave 3 — Compiler write path`, Work items 4–6; `## Wave 6 — Migration / augment / root lock`, algorithm and behavioral verification.

**Evidence:**

> “4. Step 7: mint IDs; … bump `spec-version`; …”

> “5. Step 8: … reverse coverage exclusive branches … overlap FAIL; neither FAIL stays; **fail before replacing REQUIREMENTS if overlap is unresolved** …”

> “6. Step 7a/8a unchanged (2-pass).”

The only explicit pair-wide no-partial-output rule is scoped to partial-pair branch 1b:

> “If lineage cannot be established, **fail before write** (do not change SPEC or REQUIREMENTS; no partial output).”

and its fixture ends:

> “If pair writes are not atomic, assert no partial output.”

**Why it matters for the template contract:** Step 7 is the write of `.planning/SPEC.md`; Step 8 subsequently derives and writes `.planning/REQUIREMENTS.md`. The R5k residual guard is therefore too late for the pair: it promises only to fail before replacing REQUIREMENTS. If an overlap is discovered after Step 7—e.g. `QA-01` is emitted as a live NFR Source and also retained as `out-of-scope`/`deferred`—the compiler may leave a bumped/new SPEC beside the previous REQUIREMENTS. The same partial-commit risk applies to other Step 8 validation failures (REQ/NFR tombstone collision, duplicate AC discovered while building coverage, malformed/unresolved Source, or allocator failure). That state breaks the two-file contract: YAML versions/lineage and the AC→REQ/NFR joins no longer describe the same compile. On true greenfield, it can create SPEC without REQUIREMENTS even though the contract says the path writes both.

R5j closed branch 1b's lineage/tombstone wipe, but its pair-safety language is not generalized to true greenfield or augment branches 2/3/4b. This is not a re-file of R5k: the exclusivity predicate and negative fixture are present; the residual is transaction ordering around that predicate.

**Suggested freeze-text fix:** Make pair commit safety a named compiler invariant on **every writing path** (Wave 6 1, 1b, 2, 3, and 4b):

1. Render candidate SPEC and REQUIREMENTS to staging/temp artifacts without changing either canonical file.
2. Run all SPEC, REQUIREMENTS, and cross-artifact preconditions on the staged pair, including kind reconciliation, ID/tombstone allocation, duplicate-AC checks, NFR forward/reverse coverage, Source Dispositions exclusivity, Coverage Matrix, and lineage/version agreement.
3. Only after all checks pass, replace the canonical pair transactionally (or use an explicit rollback protocol if the filesystem cannot provide a two-file atomic rename).
4. On any Step 7/7a/8/8a failure, leave both prior canonical artifacts byte-identical; on greenfield, leave neither file created.

Add behavioral failure-injection fixtures for at least (a) the named `QA-01` Source-plus-disposition overlap after candidate SPEC generation and (b) a Step 8 REQ/NFR tombstone collision, each on greenfield and an augment branch. Assert no lone SPEC, no lone REQUIREMENTS, no version skew, and both prior artifact hashes unchanged on failure. Keep R5j's branch-1b tombstone union and preserve-or-fail-closed semantics unchanged.

## Verdict

**NOT CLEAN**

One new residual finding: `R6b-F01`.
