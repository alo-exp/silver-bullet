# Rung 06 — Pi Codex GPT-5.6 Sol Extra High — Review pass 4

## Scope and freeze integrity

- Reviewer/runtime: Pi Codex, `PI_PROVIDER=omniroute`, `PI_MODEL=codex/gpt-5.6-sol-xhigh`.
- Reviewed freeze: `.planning/spec_template_world_class.plan.md`.
- Expected SHA-256: `7a6bfc5d66e9acdbf782f15bbe724c51b586e39d1c9cac95e8c547017e6bdc91`.
- Observed SHA-256: `7a6bfc5d66e9acdbf782f15bbe724c51b586e39d1c9cac95e8c547017e6bdc91`.
- Twin check: `.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md` is byte-identical to the freeze (`cmp -s` PASS; same SHA-256).
- Also read: `.planning/spec-template-world-class/CONTEXT.md`. Its `edf2c256…` freeze identity is stale metadata; this review used the supplied post-R6c pin.
- I ran the mandatory Graphify query before source exploration and independently re-read the complete pinned freeze. Passes 1–3 were treated as history rather than authority.

## Independent residual re-hunt

I re-hunted all three Policy E surfaces: the SPEC/REQUIREMENTS template contract, the software-kind catalog plus Clarify skip-turns, and the compiler/QC/test/migration plan.

The post-R6c freeze does land most of the accepted mechanism. Step 7 stages SPEC rather than committing it; Step 7a consumes the staged SPEC; Step 8 stages REQUIREMENTS and validates the staged pair; Step 8a receives the staged SPEC as `source_inputs`; canonical installation is delayed until the staged gates pass; both prior canonical states, including absence, are snapshotted before either canonical mutation; and a second-replace failure restores both prior states. Wave 6 applies the mechanisms to branches 1, 1b, 2, 3, and 4b, with staged-review-failure and commit-boundary fixtures.

The R6b staged-until-Step-8 contract, R5j true-greenfield/partial-pair distinction, separate SPEC and REQUIREMENTS tombstone ledgers, R5k exclusive NFR Source-versus-Disposition branches, exact-width ID grammars, required-pack bodies/IDs, and the named `QA-01` overlap failure all remain present. The template and kind catalog also retain GWT/If-Then, Invariants, Change History, conditional Decision Log, closed-world pack classification, `multi` validation/required-wins, `EX-nn`, and kind-gated Clarify turns.

One residual remains in the post-R6c review-to-install sequence.

## Findings

### R6d-F01 — HIGH — Wave 3 Step 8a/final install gate: fixes can mutate the staged pair after its cross-artifact validation without a mandatory final fixed-point revalidation

**Location:** `## Wave 3 — Compiler write path`, Work items 5–6 and verification bullets; `## Wave 6 — Migration / augment / root lock`, recoverable-pair-install fixtures.

**Evidence:**

Step 8 establishes a validated staged-pair boundary:

> “render candidate REQUIREMENTS to staging; run all Step 8 checks on the staged pair”

and names checks including:

> “NFR overlap, QC, tombstone collision, allocator, Coverage Matrix, malformed/unresolved Source”

But the next work item explicitly permits a later mutation:

> “Step 8a reviews/fixes staged REQUIREMENTS with the **staged SPEC path** as `source_inputs`.”

The only general statement about the other gates is:

> “Any review/QC gates between mint and install … consume staged bytes.”

The install condition likewise requires that the gates have passed:

> “install from the staged pair only after Step 8 **and** 7a/8a (plus intervening review/QC) PASS on staged candidates”

Neither statement requires all SPEC, REQUIREMENTS, and cross-artifact checks to be rerun on the **final bytes after the last Step 8a fix**, nor does it require a full clean cycle to restart whenever any reviewer changes either candidate. The verification list and Wave 6 fixtures cover a 7a/8a FAIL and a second-write commit-boundary failure, but not a Step 8a fix that makes an earlier staged-pair or `review-cross-artifact` PASS stale.

**Why it matters for the template contract:** Step 8a is a mutating review loop, not a read-only assertion. A REQUIREMENTS fix can change a `REQ-nn`/`NFR-nn`, AC join, Coverage Matrix reference, NFR Source, disposition, tombstone, or lineage field after Step 8 and an earlier cross-artifact gate inspected the pair. A clean `review-requirements` pass does not by itself prove every compiler allocator/lineage invariant or every `review-cross-artifact` relation on those new bytes. As written, an implementation may legally install a physically recoverable but semantically unvalidated final pair using stale PASS evidence. That breaks the two-file template contract even though R6c's staged paths and snapshot-restore protocol otherwise work.

This is a residual after R6c-F01, not a re-file of it: staged-path routing, no-install on review failure, snapshots, two-file restoration, and commit-boundary fixtures are present; the missing contract is final fixed-point validation after a successful reviewer mutation.

**Suggested freeze-text fix:** Add a named **final staged-pair fixed-point gate** immediately before snapshot/install:

1. After Step 8a's last fix, run `review-spec` on the staged SPEC, `review-requirements` on the staged REQUIREMENTS with the staged SPEC as `source_inputs`, and `review-cross-artifact` on that exact staged pair, together with all Step 8 allocator, tombstone, lineage, coverage, Source/disposition, and version checks.
2. If any gate changes either candidate, invalidate all earlier PASS evidence and restart the complete final gate cycle. Installation is allowed only after one full cycle is clean with no subsequent mutation.
3. Bind the install to the exact validated candidate hashes/bytes so no post-gate edit can be installed.
4. Add a behavioral fixture in which Step 8a applies a REQUIREMENTS fix that makes an earlier cross-artifact relation stale (for example, a changed REQ ID leaving a Coverage Matrix reference stale). Assert that installation is blocked until the complete staged-pair cycle is rerun and clean; on unresolved failure, prior canonical bytes/absence remain unchanged.

Keep R6c snapshot-restore, R6b staged-until-Step-8-succeeds, R5j 1b preserve-or-fail-closed, both tombstone namespaces, and R5k exclusivity unchanged.

## Verdict

**NOT CLEAN**

One new residual finding: `R6d-F01`.
