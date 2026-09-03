# Rung 06 — Pi Codex GPT-5.6 Sol Extra High — Review pass 8

## Review identity and pin

- **Role:** review-only residual re-hunt; no APPLY, triage, verify, branch change, commit, or ladder-state mutation performed.
- **Runtime:** `PI_PROVIDER=omniroute`; `PI_MODEL=codex/gpt-5.6-sol-xhigh` (GPT-5.6 Sol Extra High through Pi Codex).
- **Reviewed freeze:** `.planning/spec_template_world_class.plan.md`
- **Expected SHA-256:** `f7c632b85ae324b4ee74414acc2b9db40564a7f7bce01ca29300d437e1a58892`
- **Observed SHA-256:** `f7c632b85ae324b4ee74414acc2b9db40564a7f7bce01ca29300d437e1a58892`
- **Twin:** `.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`
- **Twin check:** byte-identical (`cmp` exit 0) and independently hashes to the same SHA-256.
- **Additional context read:** `.planning/spec-template-world-class/CONTEXT.md` in full. Its older `edf2c256…` freeze metadata was treated as stale, as directed.
- **Graph-first evidence retrieval:** ran `graphify query "agent-pi invoke gpt-5.6-sol-xhigh ID namespace exhaustion fail-closed R6f-F01 residual pass 8"` before source exploration.

I re-read the complete 685-line pinned freeze from the start and performed a residual-only hunt. Passes 1–7 were not used as authority. One new residual finding is warranted.

## Independent residual-hunt evidence

### 1. ID-namespace exhaustion fail-closed — R6f-F01 remains complete

The global ID contract explicitly defines the finite domain and terminal behavior:

> “**ID-namespace exhaustion fail-closed (R6f-F01):** Allocatable domain for every exact two-digit prefix the freeze already requires (`AC-nn`, `EX-nn`, every catalog prefix, `REQ-nn`, `NFR-nn`) is `00–99` inclusive (`-00` is allocatable). When next-free cannot mint an unused exact two-digit ID (all `00–99` live or tombstoned for that prefix), **FAIL closed** before any canonical pair replace — do not wrap, do not three-digit, do not reuse tombstones.”

This is not confined to the global scheme:

- **Wave 3 Step 7** says next-free for `AC-nn`, `EX-nn`, and **every catalog prefix** fails closed at full `00–99`, identifies `-00` as allocatable, forbids wrap/three-digit/tombstone reuse, and gives the full `EX-00`–`EX-99` no-install fixture.
- **Wave 3 Step 8** independently applies the same pre-install terminal rule to `REQ-nn` and `NFR-nn`, with the full `REQ-00`–`REQ-99` or `NFR-00`–`NFR-99` fixture.
- **Wave 6** states that the mechanism applies to every minting path—steps `1`, `1b`, `2`, `3`, and `4b`—and repeatedly requires “mint FAIL, no install.”
- The behavioral test contract includes both a full SPEC catalog namespace and a full REQUIREMENTS namespace, asserting no wrap, no three-digit output, no tombstone reuse, and unchanged canonical bytes/absence.
- Wave 2 preserves the distinction between allocator exhaustion and post-emit grammar validation: “exhaustion is fail-before-emit, not a QC widen after emit.”

No text authorizes an allocator to free capacity by shrinking tombstones, guess an operator migration, wrap, widen IDs, or install a partial pair. The forbidden phrase “one or more digits” is absent; the only related wording is the explicit negation “not one-or-more digits.”

### 2. Fixed-point revalidation — R6d-F01 remains complete

The compiler contract requires:

> “After any successful 7a or 8a mutation of staged bytes, re-run Step 8 / 7a/8a / `review-cross-artifact` (as applicable) on the **exact** staged pair that will be installed.”

It also binds installation to a last PASS on those bytes with no later mutation and expressly marks a pre-mutation PASS stale. The behavioral fixture injects an 8a REQUIREMENTS mutation after Step 8 and `review-cross-artifact` PASS, then requires install to fail until the applicable gates re-run and PASS on the exact new staged bytes. Step 8’s checks retain allocator/exhaustion, tombstones, Coverage Matrix, Source/disposition, lineage/version, and QC preconditions, so the restart does not omit the post-R6f terminal case.

### 3. Staged reviews and recoverable pair-install — R6c-F01 remains complete

The freeze states:

> “Step 7a reviews and applies fixes to the staged SPEC only. Step 8a reviews/fixes staged REQUIREMENTS with the **staged SPEC path** as `source_inputs`.”

All compiler-invoked Wave 2 review/QC gates consume staged bytes. A 7a/8a failure cannot install. Before either canonical path is mutated, prior bytes of **both** canonicals are snapshotted, including absence; a failed second replace after a successful first replace restores both prior states. The test contract separately covers staged-review failure and the commit boundary, including true greenfield and an augment branch, rather than treating a pre-install Step 8 failure as sufficient evidence.

### 4. Staged pair commit — R6b-F01 remains complete

Step 7 is expressly prohibited from durable-committing canonical `.planning/SPEC.md`; it renders only a non-canonical staged candidate. Step 8 stages REQUIREMENTS, validates the pair, and permits canonical replacement only after the checks and staged review cycle succeed. The rule is explicitly carried across Wave 6 steps `1`, `1b`, `2`, `3`, and `4b`.

The fixture contract includes Step 8 failures from both (a) live NFR Source plus a disposition overlap and (b) a REQ/NFR tombstone collision, on true greenfield and augment. It asserts no lone SPEC, no version skew, and unchanged prior bytes (or both outputs absent on greenfield). Exhaustion failure is separately bound to the same no-install boundary.

### 5. NFR Source/disposition exclusivity — R5k-F01 remains intact

The template and all relevant reviewer/compiler surfaces retain mutually exclusive branches for each eligible `QA-nn`, `SLO-nn`, or `CTRL-nn`:

- live branch: one or more NFR Source references and zero dispositions rows;
- disposition branch: zero live NFR Source references and exactly one valid `### Source Dispositions` row;
- both branches or neither branch: FAIL.

`review-requirements`, `review-cross-artifact`, and Step 8 all state the overlap failure. The negative fixture still uses `QA-01` as a live Source plus `out-of-scope` or `deferred`, and Step 8 fails before **any canonical pair replace** when unresolved.

### 6. Greenfield, partial-pair, and inverse-pair behavior — R5j-F01 remains intact

True greenfield is defined only when **both** canonical files are absent. SPEC-absent / REQUIREMENTS-present is the named **preserve-or-fail-closed** branch: prior live IDs and REQUIREMENTS tombstones are read, the tombstone ledger is unioned into replacement bytes, and unresolved lineage fails before write. The fixture with `[REQ-03, NFR-02]` forbids reset to `[]` and later reissue of `REQ-03`.

A present SPEC is routed through the explicit SPEC-present decision tree (`2`, `3`, `4`, or `4b`), so REQUIREMENTS absence does not silently become true greenfield or authorize a lone-file commit.

### 7. SPEC and REQUIREMENTS tombstones — R5h-F01/R5i-F01 remain intact

Allocator state remains split correctly:

- SPEC YAML owns core/catalog tombstones and Step 7 next-free behavior.
- REQUIREMENTS YAML owns `REQ-nn`/`NFR-nn` tombstones and Step 8 next-free behavior.

Both lists persist across augment, skip live and retired IDs, reject live/tombstoned collisions, and are never shrunk to escape exhaustion. The global catalog prefix list includes `US`, `FLOW`, `AC`, `OQ`, `OOS`, `DEC`, `EX`, `ERR`, `EP`, `CMD`, `DATA`, `SIG`, `SLO`, `CTRL`, `QA`, `SCR`, and `STG`; QC-12/QC-13 and Step 7 cover present structured packs and catalog/core IDs. REQUIREMENTS QC-2/QC-3 retain exact two-digit `REQ`/`NFR` shape and collision checks.

### 8. Template, kind-pack, Clarify, and test-contract scan

The residual scan found one new REQUIREMENTS AC-join test-contract gap, filed below as `R6h-F01`; the remaining template/kind surfaces were sustained:

- Core required headings remain seven QC-1 headings, with Change History separately enforced by QC-10 as a substantive table tied to current `spec-version`.
- GWT/If-Then, invariants, stable IDs, examples, decision log, Quality Attributes, security, telemetry, API, UX, data, errors, CLI, mobile, pipeline, and operations retain explicit required/optional/forbidden treatment.
- All ten software-kind rows remain present; `multi` validates two or more distinct atomic kinds before union and uses required-wins.
- Required packs require substantive bodies and catalog IDs; optional-present packs are validated; forbidden and closed-world-unlisted headings cannot survive kind reconciliation.
- Clarify remains kind-first, asks only applicable domain turns, includes real `nfr` and all named pack fields, and does not write SPEC/REQUIREMENTS.
- REQUIREMENTS remains the two-file ID index, with no third canonical kind document.
- The named tests cover duplicate/malformed/unlabeled SPEC and REQ/NFR IDs, Change History, kind-pack bodies, `EX-nn`, tombstones, partial-pair behavior, pair staging/recovery/fixed-point, exclusivity overlap, and full-namespace exhaustion; the missing Functional `AC-nn` cell/QC-4 behavioral assertion is the exception filed below.
- The v0.35 lock remains total without weakening the thin spec-floor.

## Findings

### R6h-F01 — MED — Wave 1 REQUIREMENTS template and Wave 2 `review-requirements` QC-4

- **Location:** `Target structure — REQUIREMENTS.md` → Functional Requirements contract; Wave 1 REQUIREMENTS template assertions; Wave 2 `review-requirements` QC-4 retarget; Wave 3 Step 8.
- **Evidence:** The target structure correctly changes the functional table to `| ID | Requirement | AC | Priority |` and says the `AC` column is the `AC-nn` join key: “`AC` column is `AC-nn` (R4-F01). Requirement column = one-line normative statement, not a GWT paste.” Wave 2 likewise says: “**QC-4 retarget (R4-F01):** Functional `AC` column is `AC-nn` IDs. … `REQ-F30` does not fire on the join key.” But Wave 1 only requires “column header `AC`” and does not require a valid example `AC-01` cell or forbid the old `Acceptance Criterion` column; its fixture parse only extracts `AC-01` from the SPEC and `REQ-01` from REQUIREMENTS. Step 8 says “fill AC column” but no named behavioral fixture asserts that emitted Functional rows contain exact `AC-nn` joins or that `REQ-F30` no longer evaluates them as measurable prose.
- **Why it matters for the template contract:** The current live REQUIREMENTS template uses `| ID | Requirement | Acceptance Criterion | Priority |` with prose placeholders, and the current reviewer QC-4 treats every Functional cell as a measurable acceptance criterion. Under the frozen test plan, an implementation can minimally rename that header to `AC` while leaving prose values and the old QC-4 behavior, yet still satisfy the Wave 1 string assertion and the named parse fixture. That defeats the primary AC→REQ machine join, can make `REQ-F30` fire on a correct `AC-01` key, and leaves Coverage Matrix/XART depending on an untested parser contract.
- **Suggested freeze-text fix:** Strengthen Wave 1 so `templates/specs/REQUIREMENTS.md.template` and the min fixture must contain a Functional example row whose AC cell is exact `AC-01`; explicitly forbid the old `Acceptance Criterion` header and prose/GWT in that column. Extend `tests/scripts/test-spec-req-id-parse.sh` (or the Wave 2 behavioral QC test) to parse the REQUIREMENTS Functional AC cell and assert exact `AC-[0-9]{2}`, including positive `AC-01` and malformed/non-ID negatives, and assert `REQ-F30` does **not** fire on a valid AC join. Require Step 8/Wave 6 emitted fixtures to preserve that join.

## Result

**NOT CLEAN** — freeze SHA-256 `f7c632b85ae324b4ee74414acc2b9db40564a7f7bce01ca29300d437e1a58892`; freeze twin byte-identical. One new residual template-contract/test gap (`R6h-F01`) remains. The primary R6f ID-namespace-exhaustion hunt and the applied staged-install/fixed-point/tombstone/NFR-exclusivity contracts otherwise remain intact.
