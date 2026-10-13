# verify_2 — Rung 04 (Cursor Grok 4.6 High)

**Verifier:** Grok 4.5 High (`cursor-grok-4.5-high` / `sb-grok-4-5-high`), native Cursor Task only.  
**Role:** RFL verify_2 (independent of verify_1). Not Reviewer. No APPLY. No branch switch. No commit.  
**Date:** 2026-08-29.  
**Review under test:** [`review.md`](review.md)  
**Claim:** **NOT CLEAN** — findings **R4-F01 (MED)**, **R4-F02 (LOW)**, **R4-F03 (NIT)**.  
**Prior verify (not copied):** [`verify_1.md`](verify_1.md) reported **PASS** with R4-F01–F03 **CONFIRMED** — re-derived from freeze + live skill; not rubber-stamped.

## Freeze integrity

```
shasum -a 256 .planning/spec_requirements_structure.plan.md
2b2f7d7672534c8895ac821fe49d34b634833cc1eb16770d6f2f5d9d3f2d1ffe
```

| Check | Result |
|-------|--------|
| Expected SHA-256 | **MATCH** — STOP condition not triggered |
| Twin [`phases/01-world-class-artifacts/PLAN.md`](../../spec-requirements-structure/phases/01-world-class-artifacts/PLAN.md) | Same SHA; `diff -q` identical (454 lines) |
| Post–rung-02 APPLY SHA | Same hash — freeze not drifted since APPLY / Gemini CLEAN |
| Branch | `main` (no switch performed) |

## Method

- Graphify CLI first (`graphify query` on rfl-spec-requirements-structure / SPEC+REQUIREMENTS structure / R4 findings).
- agentmemory save at start + on verdict.
- Context Mode sandbox: freeze SHA + twin identity; line extracts for Wave 1–3 / Invariants / QC-4; live `skills/review-requirements/SKILL.md` QC-4/QC-7; `skills/silver-spec/SKILL.md` Step 8a; prior APPLY marker audit; fence-aware H1 count.
- Did not rewrite freeze; did not APPLY; did not treat verify_1 as authority.

## Per-finding verdicts

### R4-F01 — MED — Wave 2 does not retarget review-requirements QC-4 for the new Functional `AC` column — **CONFIRMED**

| Claim | Independent evidence |
|-------|----------------------|
| Target Functional table is `\| ID \| Requirement \| AC \| Priority \|`; `AC` = `AC-nn` ID join key; Requirement = one-line normative; GWT stays in SPEC | Freeze L137–L141 |
| Wave 1 locks column header `AC` | Freeze L217 |
| Live QC-4 requires every Functional row’s **Acceptance Criterion** column value to be **measurable** (threshold / state / pass-fail); non-testable → `REQ-F30` | Live skill L70–L78 |
| Live QC-7 still expects the AC column to “capture the same observable outcome” | Live skill L101 |
| Wave 2 rewrites QC-6, QC-7 (ID join), adds QC-8; QC-4 mentioned **only** for empty NFR + `None identified` PASS | Freeze L247 — no Functional QC-4 retarget, no rename guidance, no `AC-nn` measurable-text exemption |
| Step 8a still runs full `review-requirements` (QC-4 included); Wave 3 only adds `source_inputs` for QC-7/QC-8 | Freeze L275–L276; live silver-spec Step 8a still invokes `/artifact-reviewer … --reviewer review-requirements` |

**Severity:** MED is correct — greenfield rows following the target table systematically fail QC-4 / `REQ-F30` (or miss an “Acceptance Criterion” column after the `AC` rename) while Step 8a remains a non-skippable gate. Fights AC-02/REQ-02 (AC = ID) and AC-04/REQ-04 (Wave 2 QC updates). Empty-NFR QC-4 was handled; Functional QC-4 was not. Not invented. Not a KEEP REJECT reopen.

### R4-F02 — LOW — Wave 3 verify omits the “Requirements” negative assert the work item itself requires — **CONFIRMED**

| Claim | Independent evidence |
|-------|----------------------|
| Work drops both “Users and goals” **and** “Requirements” from Step 2 fallback | Freeze L273 |
| Verify bans only “Users and goals” as a write section | Freeze L284; bullets L281–L286 have **no** “Requirements” negative |
| Critique already flags inventing SPEC `## Requirements` as REJECT | Freeze L61 |

Work contract and verify harness are misaligned. LOW is correct (string-harness completeness, not a new design decision). Suggested fix (mirror the Users-and-goals negative for “Requirements”) matches the work sentence. Not invented.

### R4-F03 — NIT — `## Invariants` is not a subsection of Overview — **CONFIRMED**

| Claim | Independent evidence |
|-------|----------------------|
| Plan says a short `` `## Invariants` `` “subsection of Overview” to avoid a ninth QC-1 heading | Freeze L102 |
| Same block defaults to subsection under Overview unless Wave 2 updates QC-1 | Freeze L105 |
| GFM `## Invariants` is a sibling H2 of `## Overview`, not a subsection (`###`) | Markup semantics |
| Rollback still says “Cut Invariants subsection” | Freeze L401 |

Copy-paste of the backticked `##` would emit an extra H2 while the prose argues against a ninth QC-1 heading. Extra H2 is not a current QC-1 existence failure (Change History is already a planned non-QC-1 H2 via QC-10), so NIT is correct — clarity / implementer trap, not a lock break. Not invented.

## Prior APPLY still in freeze text (independent audit)

All nine applied findings from rungs 01–02 re-checked against current freeze SHA:

| Prior finding | Still in freeze? | Independent evidence |
|---------------|------------------|----------------------|
| R1-F01 MED | Yes | L355: lock only when missing `spec-version` **and** missing `## User Stories` **and** missing `feature-slug`; L402 residual “none expected” |
| R1-F02 LOW | Yes | L432: `AC-09 / REQ-09` → `1, 2, 3, 4, 7` |
| R1-F03 LOW | Yes | L246 + L443: `If/Then` only for non-interactive; ISSUE-new / INFO-legacy for QC-9 |
| R1-F04 NIT | Yes | L48: `52 lines / 1017 bytes` (disk `wc -l -c` matches) |
| R1-F05 NIT | Yes | L438: spec-floor is **NFR-03 only** |
| R2-F01 LOW | Yes | L356 **4b** augment path present |
| R2-F02 LOW | Yes | L246: ISSUE-new / INFO-legacy covers QC-8, QC-9, QC-10, QC-6 `feature-slug` extension |
| R2-F03 LOW | Yes | Canon `test-review-spec-req-xart-qc-strings.sh` at L253/L257/L382; stale `test-review-spec-qc-strings.sh` absent |
| R2-F04 NIT | Yes | L38 is `> **WARNING:** …` blockquote; fence-aware GFM H1 count = **1** (L1 only) |

None re-opened; none defective relative to APPLY ledgers. KEEP REJECT not re-litigated.

## Independent adversarial spot-check (holes Grok / verify_1 may have missed)

| Candidate | Assessment |
|-----------|------------|
| Live QC-4 wording “Acceptance Criterion column” vs Wave 1 header `AC` (existence/rename failure separate from measurable `AC-nn`) | **Subsumed by R4-F01** — same Wave 2 Functional QC-4 hole; not a second finding |
| Wave 3 `source_inputs` only for QC-7/QC-8 while QC-4 still fires | Already filed as part of R4-F01 evidence chain |
| OQ-01 / OQ-02 still open | Intentional non-blocking product defaults; not incomplete algorithm |
| Second `#` at L253 | **Not a hole** — inside fenced `bash`. Outside-fence H1 count = 1 |
| Stale template evidence / 53×1013 | Absent from freeze. Disk template still **52 / 1017** |
| Missed HIGH elsewhere in Waves 4–7 | None found; primary contract hole is Functional QC-4 (already MED) |

**No additional HIGH / MED / LOW / NIT** beyond R4-F01–F03.

## Reviewer meta-checks (independent)

| Check | Result |
|-------|--------|
| Freeze SHA / twin identity | Correct |
| Invented findings | None |
| Severity dump | No — MED / LOW / NIT fit evidence |
| NOT CLEAN | Consistent with one MED contract hole |
| KEEP REJECT / R1–R2 APPLY reopened | No |
| Missed HIGH | None in independent spot-check |
| Policy C / review-only | Observed (no YAML exec / implement / branch / commit) |
| verify_1 rubber-stamp? | No — re-hashed freeze, re-read L137–L141 / L217 / L247 / L273–L286 / L102–L105 / L401, re-checked live QC-4 + Step 8a |

## Overall verdict

**verify_2 PASS**

Reviewer’s **NOT CLEAN** stands. All three findings (**R4-F01 MED**, **R4-F02 LOW**, **R4-F03 NIT**) are **CONFIRMED** against freeze SHA `2b2f7d7672534c8895ac821fe49d34b634833cc1eb16770d6f2f5d9d3f2d1ffe` and live `skills/review-requirements/SKILL.md` QC-4. Consistent with verify_1 PASS without copying its evidence chain. Parent may APPLY R4-F01–F03; this worker does not APPLY.

## Appendix — SHA

```
expected: 2b2f7d7672534c8895ac821fe49d34b634833cc1eb16770d6f2f5d9d3f2d1ffe
observed: 2b2f7d7672534c8895ac821fe49d34b634833cc1eb16770d6f2f5d9d3f2d1ffe
twin:     2b2f7d7672534c8895ac821fe49d34b634833cc1eb16770d6f2f5d9d3f2d1ffe
```
