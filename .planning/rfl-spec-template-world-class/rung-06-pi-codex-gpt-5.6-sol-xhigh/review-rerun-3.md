# Rung 06 — Pi Codex GPT-5.6 Sol Extra High — Review pass 3

## Scope and freeze integrity

- Reviewer/runtime: Pi Codex, `PI_PROVIDER=omniroute`, `PI_MODEL=codex/gpt-5.6-sol-xhigh`.
- Reviewed freeze: `.planning/spec_template_world_class.plan.md`.
- Expected SHA-256: `878301866ecbc51c2ee144d566fdfaa36fcb34b37d8fd88166723b32d92879f5`.
- Observed SHA-256: `878301866ecbc51c2ee144d566fdfaa36fcb34b37d8fd88166723b32d92879f5`.
- Twin check: `.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md` is byte-identical to the freeze (`cmp -s` PASS; same SHA-256).
- Also read: `.planning/spec-template-world-class/CONTEXT.md`. Its `edf2c256…` freeze identity is stale metadata; this review used the supplied, independently verified post-R6b pin.
- I ran the mandatory Graphify query before source exploration and independently re-read the full pinned freeze. Passes 1–2 were consulted only as history after the fresh read.

## Independent residual re-hunt

I re-hunted all three Policy E surfaces: the SPEC/REQUIREMENTS template contract, software-kind catalog and Clarify skip-turns, and the compiler/QC/test/migration plan. The post-R6b text retains the intended staged-pair outcome for Wave 6 branches 1, 1b, 2, 3, and 4b; retains true-greenfield = both files absent and 1b preserve-or-fail-closed; keeps SPEC and REQUIREMENTS tombstone namespaces separate and durable; and preserves the exclusive NFR Source-versus-Source-Dispositions branches and named `QA-01` overlap failure.

The template and kind-pack contracts remain coherent on exact-width IDs (including `EX-nn` and REQ/NFR), required-pack bodies and IDs, GWT/If-Then, Invariants, Change History, conditional Decision Log, `multi` validation/required-wins, closed-world forbidden packs, and kind-gated Clarify turns. I found no separate new gap in those surfaces.

One residual staged-pair defect remains in the post-R6b freeze.

## Findings

### R6c-F01 — HIGH — Wave 3 Steps 7a/8a and final pair installation: staged candidates are not carried through the review gates or committed with a recoverable two-file protocol

**Location:** `## Wave 3 — Compiler write path`, Work items 4–6; `## Wave 6 — Migration / augment / root lock`, staged-pair behavioral fixture.

**Evidence:**

The new Step 7 contract correctly says:

> “Step 7 MUST NOT durable-commit canonical `.planning/SPEC.md`. Render the candidate SPEC to a non-canonical staging artifact only.”

Step 8 likewise says:

> “render candidate REQUIREMENTS to staging; run all Step 8 checks on the staged pair; replace both canonical files together only after Step 8 succeeds”

But the immediately following review contract remains:

> “Step 7a/8a unchanged (2-pass). Step 8a: pass SPEC path as `source_inputs`.”

The failure-injection fixture covers pre-install Step 8 failures:

> “after a would-be Step 7 SPEC bump, inject Step 8 FAIL … Assert prior canonical SPEC bytes unchanged or both files unwritten”

It does not cover a Step 7a/8a review/fix loop against staged paths or a failure after the first canonical replacement during the final two-file installation.

**Why it matters for the template contract:** The existing two-pass gates are path-based artifact reviewers. Leaving Steps 7a/8a “unchanged” does not define how Step 7a reviews and applies fixes to the staged SPEC rather than the old canonical SPEC (or a nonexistent path on greenfield), how Step 8 derives from that reviewed staged SPEC, or how Step 8a reviews/fixes staged REQUIREMENTS before either canonical file is replaced. If canonical paths are used to preserve the unchanged gates, the compiler durable-commits mid-path and recreates R6b's version-skew/lone-file failure. If canonical paths are not used, the unchanged reviewers inspect the wrong bytes or cannot run. A Step 8a fix can also invalidate an earlier cross-artifact check unless the staged pair is revalidated after the final review loop.

Separately, “replace both canonical files together” states an outcome but not an implementable filesystem transaction. Two ordinary renames are not pair-atomic: failure of the second rename can leave a lone new SPEC or REQUIREMENTS even though all pre-install Step 8 checks passed. The current fixture injects only Step 8 validation failures, so it cannot prove pair-wide no-partial-output at the commit boundary. This is a residual in the named staged-pair mechanism, not a re-file of R6b-F01 or any tombstone/NFR-exclusivity rule.

**Suggested freeze-text fix:** Define one staging workspace and thread its explicit paths through the whole pipeline:

1. Step 7 renders staged SPEC; Step 7a reviews and applies fixes to that staged path only.
2. Step 8 derives staged REQUIREMENTS from the final reviewed staged SPEC; Step 8a reviews/fixes staged REQUIREMENTS with the staged SPEC as `source_inputs`.
3. After both two-clean review gates, rerun all SPEC, REQUIREMENTS, and cross-artifact checks on the final staged bytes.
4. Install the pair with a named recoverable protocol: snapshot/backup both prior canonicals (including absence markers), fsync as appropriate, perform the two replacements, and roll both paths back to the snapshots on either replacement failure; alternatively use a real transaction/indirection mechanism that gives equivalent pair-wide recovery. Do not describe two independent renames as atomic.
5. Extend behavioral fixtures to assert reviewers receive staging paths and cannot mutate canonicals, and inject failure after the first canonical replacement on true greenfield, partial-pair 1b, and at least one augment branch. Assert both prior hashes/absence states are restored, no lone artifact or version skew remains, and temporary/backup recovery state is handled deterministically.

Keep R5j preserve-or-fail-closed, both tombstone ledgers/allocators, R5k exclusivity, and the existing Step 8 validation-failure fixtures unchanged.

## Verdict

**NOT CLEAN**

One new residual finding: `R6c-F01`.
