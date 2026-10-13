# Review — Rung 01 (Cursor GLM 5.2 High) — review-plan

**Reviewer:** GLM 5.2 High (`glm-5.2-high`), Cursor native.
**Rung:** 1 of 8 (Policy C, review-only).
**Artifact:** `.planning/spec_requirements_structure.plan.md` (PLAN doc).
**Skill:** `skills/review-plan/SKILL.md` + RFL Template A (plan-doc emphasis).
**Date:** 2026-08-29.

## Freeze integrity

- `shasum -a 256 .planning/spec_requirements_structure.plan.md` → `8f8a0d58aa11cc9cf23419ecc8eae73b9ae64cf25ff7c7365e7fc7c89d4beb74` ✓ matches expected.
- `diff -q` against `.planning/spec-requirements-structure/phases/01-world-class-artifacts/PLAN.md` → **byte-identical** ✓.
- No branch switch, no commit, no freeze YAML execution performed.

## Method

- Graphify CLI query run first (`graphify query "SPEC.md.template REQUIREMENTS.md.template review-spec QC-1 AC-nn coverage matrix silver-spec compiler Step 8 clarify --spec capture schema"`); MCP `user-graphify` namespace unavailable this session (per CONTEXT). 348 nodes surfaced; oriented on silver-spec Steps 7–8, review-spec/requirements QC, capture schema.
- Evidence claims in the plan were verified against the actual repo files (templates, skills, hooks, tests) via sandbox reads — see "Evidence verification" below.
- agentmemory saved: `mem_mte1y9a9_88918857d16c`.

## Evidence verification (plan claims vs repo)

| Plan claim | Verified | Note |
|------------|----------|------|
| `templates/specs/SPEC.md.template` = 53 lines / 1013 bytes, AC = unlabeled `- [ ]` bullets | PARTIAL | 53 lines ✓; **1017 bytes** (plan says 1013) — NIT R1-F04; unlabeled `- [ ]` confirmed (3 occurrences). |
| `templates/specs/REQUIREMENTS.md.template` = 25 lines / 636 bytes, no YAML frontmatter, example "derived from User Story" | YES | 25 lines / 636 bytes ✓; `derived-from:` count 0 ✓; `**Derived from:**` present ✓; "derived from User Story" row present ✓. |
| `review-cross-artifact` QC-1 looks for `AC-XX` and `**REQ-XX**:` / `- [x] **XXX-NNx**:` | YES | Both patterns present verbatim. |
| `silver-spec` Step 2 lists "Users and goals" and "Requirements"; Step 8 derives from SPEC AC | YES | All three strings present. |
| `silver-clarify` capture schema exists; "Never write SPEC.md/REQUIREMENTS.md" | YES | `### Capture schema (next=spec brief)` present; "Never write `.planning/SPEC.md` or `.planning/REQUIREMENTS.md`" present. |
| All 6 new test files / fixtures do not yet exist | YES | None of `test-spec-requirements-templates.sh`, `test-spec-req-id-parse.sh`, `test-review-spec-req-xart-qc-strings.sh`, `test-spec-legacy-lock.sh`, `tests/fixtures/specs/world-class-min/SPEC.md`, `tests/fixtures/specs/legacy-v035/SPEC.md` exist. |
| `test-clarify-spec-compiler.sh` does not assert `templates/specs/*` headings | YES | No `templates/specs/` string in the harness. |
| `pr-traceability.sh` hardcodes `.planning/SPEC.md` | YES | Confirmed. |
| `spec-floor-check.sh` requires Overview + Acceptance Criteria | YES | Confirmed. |

The plan's evidence base is overwhelmingly accurate. One byte-count typo (R1-F04).

## Findings

### R1-F01 — MED — Legacy lock algorithm is broader than its own rollback mitigation

- **Location:** Wave 6 — "Algorithm (implement this, RFL should challenge it)" step 3, vs Risk/rollback table row "Legacy lock too aggressive on consumer greenfield-after-manual-SPEC".
- **Evidence (algorithm, step 3):** "Legacy lock: existing `.planning/SPEC.md` has **no** `spec-version` frontmatter (v0.35 shape) → **do not overwrite**."
- **Evidence (rollback mitigation):** "Legacy lock too aggressive on consumer greenfield-after-manual-SPEC | Require **both** missing frontmatter **and** missing `## User Stories`."
- **Why it matters:** The algorithm locks on missing frontmatter **alone**. A consumer's manual greenfield SPEC that has `## User Stories` but no frontmatter would be locked (false positive) under step 3 as written, yet the rollback mitigation explicitly says the lock should require **both** conditions. The algorithm and its documented rollback fix disagree, so Wave 6 implementation could pick either trigger — a contract hole, not a doc nit. The plan even invites RFL to "challenge it," which is appropriate, but the contract itself should not ship with the trigger and its fix in tension.
- **Suggested fix:** Tighten step 3 to encode the mitigation up front: "Legacy lock fires only when SPEC has **no** `spec-version` frontmatter **and no** `## User Stories` heading (and no `feature-slug`). A file with `## User Stories` but no frontmatter is augmentable (mint frontmatter, preserve body)." Move the rollback row to "residual risk: none expected" or delete it.

### R1-F02 — LOW — REQ-09 wave mapping understates coverage

- **Location:** "Mapping: acceptance criteria → waves" table.
- **Evidence:** `AC-09 / REQ-09 | 1, 2, 7`.
- **Why it matters:** REQ-09 / AC-09 requires `test-clarify-spec-compiler.sh` to "gain string asserts for compiler/clarify/QC updates." Those asserts land in Wave 3 (compiler strings: `Coverage Matrix`, `feature-slug`, `None identified`, legacy-lock phrase) and Wave 4 (clarify strings: `Given`/`When`/`Then`, `Quality Attributes`). The mapping omits waves 3 and 4, so a reader checking coverage could conclude REQ-09 is fully satisfied after waves 1,2,7 when the compiler/clarify halves are not yet asserted. Not a defect — the waves still do the work — but the traceability table is the contract's join key and should be complete.
- **Suggested fix:** Change `AC-09 / REQ-09 | 1, 2, 7` → `1, 2, 3, 4, 7`.

### R1-F03 — LOW — "or equivalent" If/Then is undefined (contract-soft)

- **Location:** AC-03 ("missing Given/When/Then (or equivalent) is an ISSUE") and Wave 2 review-spec QC-9 ("Given/When/Then or `If/Then`").
- **Evidence:** The plan's own "What RFL should review" #2 asks: "is `If/Then` equivalent enough for backend-only AC? Should QC-9 be ISSUE or INFO on first release?"
- **Why it matters:** The plan defers the precise definition of "equivalent" and the ISSUE-vs-INFO severity of QC-9 to RFL. Surfacing the open question is correct for a plan, but the contract that Wave 2 implements should not leave "equivalent" unbounded — a reviewer applying QC-9 needs a deterministic rule (e.g., "If/Then accepted only for non-interactive/stateless AC; interactive AC require Given/When/Then") and a fixed severity. Leaving both to per-rung judgment invites ladder churn.
- **Suggested fix:** Add one line to Wave 2 review-spec QC-9: "`If/Then` is accepted only for non-interactive AC (no user/system step sequence). Interactive AC require Given/When/Then. QC-9 severity = ISSUE for new compiles, INFO for legacy augment of pre-ID specs." Resolve OQ alongside OQ-01/OQ-02 (still non-blocking).

### R1-F04 — NIT — SPEC template byte count typo

- **Location:** CONTEXT.md "Evidence already collected" table, row 1.
- **Evidence:** "`templates/specs/SPEC.md.template` | 53 lines / 1013 bytes."
- **Why it matters:** Actual size is 1017 bytes. Evidence tables in a contract doc should be re-checkable; a 4-byte drift invites a future reviewer to doubt the rest of the table.
- **Suggested fix:** Change "1013 bytes" → "1017 bytes" (or drop the byte count and keep line count, which is stable).

### R1-F05 — NIT — AC-09 / NFR-03 overlap on spec-floor test

- **Location:** AC-09 ("`tests/hooks/test-spec-floor-check.sh` still passes with only Overview+AC") and NFR-03 ("`tests/hooks/test-spec-floor-check.sh` PASS without requiring new headings").
- **Evidence:** Both criteria assert the same test passes with the same floor.
- **Why it matters:** Overlap, not a contradiction. Two criteria tracing to one invariant is fine, but it slightly inflates the AC/REQ count and can confuse coverage accounting. Acceptable as-is; flagging only for awareness.
- **Suggested fix:** None required. Optionally fold the spec-floor assertion into NFR-03 only and drop the trailing clause of AC-09.

## Template A checklist (plan-doc emphasis)

- **Contract vs waves:** AC-01..AC-10 / REQ-01..REQ-10 / NFR-01..NFR-04 all map to waves (mapping table present; one understatement — R1-F02). Wave acceptance tags each name REQs. ✓ (with R1-F02)
- **KEEP REJECT:** Comprehensive table. The specific tension the brief flagged — "do not drop REQUIREMENTS OOS/Open Items" vs "reduce clone by ID snapshot" — is resolved consistently: KEEP keeps the four QC-1 headings; target structure makes OOS/Open Items **ID snapshots** not prose clones. No reopen. ✓
- **GFM slugs:** `feature-slug` kebab-case required; IDs `US-nn`/`FLOW-nn`/`AC-nn`/`OQ-nn`/`OOS-nn`/`REQ-nn`/`NFR-nn` zero-padded two digits, unique, no renumber across augments. Consistent across SPEC, REQUIREMENTS, and Coverage Matrix. ✓
- **Test citations:** Every wave names concrete test paths and fixtures. No "path TBD." Wave 7 close-out lists the full suite + `graphify update .`. ✓
- **Contradictions:** One real tension (R1-F01) between algorithm and rollback; otherwise internally consistent. AC-01 bundling Change History is consistent with QC-10 being a separate enforcement (artifact vs enforcement split). ✓ (with R1-F01)
- **Missing owners:** Every wave has `Owner:`; blast-radius table has an Owner column; Assumptions and OQs carry Owner + Status. ✓

## review-plan quality criteria

1. Scope explicit (goal, non-goals, blast radius, files) — ✓ strong.
2. Dependencies explicit — ✓.
3. Work sequenced into safe waves with handoffs — ✓ (Wave N+1 depends on Wave N; Wave 7 close-out).
4. Acceptance criteria testable and traceable — ✓ (with R1-F02 mapping gap).
5. Verification plan concrete (commands listed) — ✓ strong.
6. Risk handling present (rollback table + per-wave risks) — ✓ (with R1-F01 algorithm/rollback tension).
7. No deferred blockers — ✓ (OQ-01/OQ-02 explicitly non-blocking; surfaced for RFL, not punted to a phantom phase).

## Prohibitions honored

- Did not modify the artifact. ✓
- Did not accept placeholder tasks/criteria/vague verification. ✓ (none present)
- Returned structured findings, not prose-only. ✓

## Verdict

**CLEAN.**

No HIGH findings. One MED (R1-F01) is a contract-tightening item — the algorithm works for the intended v0.35 victim, but its trigger is broader than its own rollback fix and should be pinned before Wave 6 implements it. Two LOW (R1-F02 traceability, R1-F03 contract-softness) and two NIT (R1-F04 byte typo, R1-F05 overlap) are non-blocking.

The plan is implementation-ready: KEEP REJECT is complete and consistent, GFM slugs are uniform, every wave names its test paths, ownership is explicit, and the two unresolved questions are correctly marked non-blocking and routed to RFL. Recommendation: **ACCEPT** (apply R1-F01 before Wave 6; R1-F02/R1-F03 before Wave 2; R1-F04/R1-F05 optional).

## Appendix — Freeze SHA

```
8f8a0d58aa11cc9cf23419ecc8eae73b9ae64cf25ff7c7365e7fc7c89d4beb74  .planning/spec_requirements_structure.plan.md
```

Byte-identical to `.planning/spec-requirements-structure/phases/01-world-class-artifacts/PLAN.md`. Re-hash only if that pair is rewritten.
