# Review — Rung 02 (Cursor Kimi K3 High) — review-plan

**Reviewer:** Kimi K3 High (`kimi-k3-high`), Cursor native.
**Rung:** 2 of 8 (Policy C, review-only).
**Artifact:** `.planning/spec_requirements_structure.plan.md` (PLAN doc).
**Skill:** `skills/review-plan/SKILL.md` + RFL Template A (plan-doc emphasis).
**Date:** 2026-08-29.

## Freeze integrity

- `shasum -a 256 .planning/spec_requirements_structure.plan.md` → `d281cb7ee6321201bdce5825dde26f48c082ab6c7e4ef7a59cfeff965dcd1feb` ✓ matches expected post-APPLY SHA.
- `shasum -a 256 .planning/spec-requirements-structure/phases/01-world-class-artifacts/PLAN.md` → identical SHA ✓ (byte-identical pair, 453 lines).
- No branch switch, no commit, no freeze YAML execution performed.

## Method

- Graphify CLI query run first (`graphify query "spec requirements structure plan review-fix-ladder"`); 147 nodes surfaced including the freeze, CONTEXT, rung-01 APPLY/verify nodes, silver-spec, silver-clarify. MCP `user-graphify` unavailable per CONTEXT.
- Full plan read via sandbox (lean-ctx triage filters native Read on this file); contract [`SPEC.md`](../../spec-requirements-structure/SPEC.md) (AC-01–AC-10) and [`REQUIREMENTS.md`](../../spec-requirements-structure/REQUIREMENTS.md) (REQ-01–REQ-10, NFR-01–NFR-04) read in full.
- Independent spot-checks against the live repo (grep via sandbox): review-spec QC-1..QC-7 / SPEC-F01..F61, review-requirements QC-1..QC-7 / REQ-F01..F60, current `templates/specs/SPEC.md.template` headings, `test-clarify-spec-compiler.sh` existing asserts.
- Rung-01 [APPLY.md](../rung-01-cursor-glm-5.2-high/APPLY.md) and [review.md](../rung-01-cursor-glm-5.2-high/review.md) read; R1-F01–F05 confirmed applied in the freeze and **not** re-filed.

## Rung-01 APPLY confirmation (post-APPLY freeze)

| Rung-01 fix | Present in freeze |
|-------------|-------------------|
| R1-F01: lock requires missing `spec-version` **and** missing `## User Stories` **and** missing `feature-slug`; stories-without-frontmatter is augment | ✓ Wave 6 steps 3–4; rollback row now "residual: none expected" |
| R1-F02: `AC-09 / REQ-09` → waves `1, 2, 3, 4, 7` | ✓ mapping table |
| R1-F03: `If/Then` only for non-interactive AC; QC-9 ISSUE new / INFO legacy | ✓ Wave 2 QC-9, Wave 4 Turn 5, RFL-review item 2 (PINNED) |
| R1-F04: 52 lines / 1017 bytes | ✓ CONTEXT evidence table |
| R1-F05: spec-floor = NFR-03 only footnote | ✓ mapping footnote |

APPLY left nothing wrong; no re-opened findings.

## Evidence spot-checks (new this rung)

| Check | Result |
|-------|--------|
| Plan adds review-spec **QC-8/9/10** with IDs **SPEC-F70/F71/F72** | ✓ No collision: review-spec today ends at QC-7 / SPEC-F61; F70+ free, numbering continues cleanly. |
| Plan adds review-requirements **QC-8** with ID **REQ-F70** | ✓ No collision: skill today ends at QC-7 / REQ-F60. |
| Current `templates/specs/SPEC.md.template` headings | ✓ Eight headings exactly as the plan's QC-1 lock lists (Overview, User Stories, UX Flows, Acceptance Criteria, Assumptions, Open Questions, Out of Scope, Implementations). |
| Wave 4 claim: `test-clarify-spec-compiler.sh` "already has `Never write.*SPEC.md` and `As a \[persona\]`" | ✓ Both asserts present (lines 91, 94). |
| Wave 2 `rg` verify pattern `\\\\\| REQ-nn` | ✓ correctly escaped for the table-cell parse example. |

## Findings

### R2-F01 — LOW — Legacy-lock decision tree has a fall-through case

- **Location:** Wave 6 — "Algorithm (implement this; lock trigger pinned by rung-01 APPLY)", steps 1–4.
- **Evidence:** Step 2 (augment, template-shaped) requires YAML `spec-version` **and** (`## User Stories` **or** `feature-slug`). Step 3 (augment, stories without frontmatter) requires (`## User Stories` **or** `feature-slug`) **and no** `spec-version`. Step 4 (legacy lock) requires **no** `spec-version` **and no** `## User Stories` **and no** `feature-slug`. The fourth combination — `spec-version` present, **no** `## User Stories`, **no** `feature-slug` — matches no branch: not greenfield (file exists), not step 2 (no stories/slug), not step 3 (has `spec-version`), not step 4 (lock requires missing `spec-version`).
- **Why it matters:** The algorithm is the pinned contract Wave 6 implements and Wave 6 tests assert. A non-total decision tree leaves one input class undefined — the implementer must invent behavior (overwrite? lock? augment?) at code time, which is exactly the class of drift R1-F01 was filed to remove. Realistic trigger: a consumer's hand-written or older-partial SPEC that has frontmatter with `spec-version` but no User Stories heading (today's template always emits `## User Stories`, so compiled specs are safe — hence LOW not MED).
- **Fix:** Add one sentence to step 4 (or a step 4b): "If `spec-version` frontmatter is present but neither `## User Stories` nor `feature-slug` exists, treat as augment: preserve body, mint missing structure, bump `spec-version` — do not overwrite." (Or explicitly lock it; either way, make the tree total.)

### R2-F02 — LOW — Legacy severity carve-out pinned for QC-9 only; QC-8 / QC-10 / QC-6-extension are silent

- **Location:** Wave 2 — review-spec row ("Add **QC-8** … (`SPEC-F70`) … Add **QC-10** … (`SPEC-F72`). Extend QC-6: `feature-slug` required.") vs the pinned severity sentence that covers **QC-9** only; Risk/rollback row "QC-8 fails every old SPEC".
- **Evidence:** The plan pins "Severity: **ISSUE** on new compiles, **INFO** on legacy augment of pre-ID specs (`SPEC-F71`)" — scoped to QC-9. The Risks row says "Flagging all legacy unlabeled AC as ISSUE is intended for **new compiles**," but QC-8 (every AC has `AC-nn`), QC-10 (Change History present), and the QC-6 `feature-slug`-required extension carry no legacy carve-out. As written, Wave 2 could legitimately implement QC-8/QC-10/QC-6-ext as unconditional ISSUEs, failing every pre-ID legacy spec on review — contradicting the stated intent.
- **Why it matters:** Same contract-softness class as R1-F03 (which pinned QC-9). The pin was applied to exactly one of four new/extended checks; the other three need the same rule or Wave 2 review text will be internally inconsistent with the risk table.
- **Fix:** Extend the severity sentence in the Wave 2 review-spec row: "The ISSUE-new / INFO-legacy split applies to QC-8, QC-9, QC-10, and the QC-6 `feature-slug` extension."

### R2-F03 — LOW — Wave 2 names two different files for the same new QC-string test

- **Location:** Wave 2 — Verify block comment vs the paragraph after it; Wave 7 close-out command list.
- **Evidence:** The Verify bash comment says "`# extend tests/scripts/test-clarify-spec-compiler.sh OR add tests/scripts/test-review-spec-qc-strings.sh`". The very next paragraph says "Name the new test file in Wave 2 implementation: `tests/scripts/test-review-spec-req-xart-qc-strings.sh`", and Wave 7 runs `bash tests/scripts/test-review-spec-req-xart-qc-strings.sh`. The comment's alternative name (`test-review-spec-qc-strings.sh`) appears nowhere else.
- **Why it matters:** The plan's own "What RFL should review" #8 demands "Test paths named — no 'path TBD.'" Two names for one artifact is a soft version of that defect: an implementer following the comment creates a file Wave 7 never runs, and close-out fails on a missing path.
- **Fix:** Strike the stale alternative from the comment so it reads "`# extend tests/scripts/test-clarify-spec-compiler.sh AND add tests/scripts/test-review-spec-req-xart-qc-strings.sh`" (or drop the comment; the paragraph already pins the name).

### R2-F04 — NIT — Stray mid-document H1 breaks single-H1 GFM structure

- **Location:** Line 38: `# Do NOT execute freeze YAML; do not git checkout / switch.`
- **Evidence:** The document's title H1 is line 1 (`# PLAN — 01-world-class-artifacts`); line 38 is a second H1 sandwiched between `## KEEP REJECT` and `## Current-structure critique`.
- **Why it matters:** GFM heading-anchor/slug tooling and any markdown linter treat the file as two documents; the warning also renders as a peer of the title rather than as the admonition it is. Content is correct and should stay prominent — only the level is wrong.
- **Fix:** Demote to a blockquote admonition, e.g. `> **WARNING:** Do NOT execute freeze YAML; do not git checkout / switch.`

## Template A checklist (plan-doc emphasis)

- **Contract vs waves:** AC-01..AC-10 / REQ-01..REQ-10 / NFR-01..NFR-04 all map to waves; post-APPLY mapping (`AC-09/REQ-09 → 1,2,3,4,7`) is complete. Wave acceptance tags name REQs; NFR-04 ("all waves") is covered by the mapping table + Wave 6/7 acceptance. ✓
- **KEEP REJECT:** Table intact and byte-unchanged by rung-01 APPLY (confirmed). The brief's flagged tension — keep REQUIREMENTS OOS/Open Items headings vs reduce clone — stays resolved via ID snapshots (`OOS-nn — <one line>` + "Canonical prose: SPEC.md ## Out of Scope"). Two files kept; Clarify does not write SPEC; ingest stays. ✓
- **GFM slugs / ID scheme:** `feature-slug` kebab-case; `US/FLOW/AC/OQ/OOS/REQ/NFR-nn` zero-padded, unique, never renumbered across augments; consistent across SPEC target, REQUIREMENTS target, Coverage Matrix, and QC text. New finding IDs (SPEC-F70–72, REQ-F70) verified collision-free against the live skills. ✓ (one structural NIT: R2-F04)
- **Test citations:** Every wave names concrete paths and fixtures; Wave 7 close-out lists the full suite + `graphify update .`. One naming contradiction (R2-F03). ✓ with finding
- **Contradictions:** None at HIGH/MED level. R2-F01 (non-total decision tree) and R2-F02 (severity-split scope) are residual contract gaps in sections rung-01 already tightened; R2-F03 is a doc-internal naming slip. ✓ with findings
- **Missing owners:** Every wave has `Owner:`; blast-radius table has an Owner column; site work pinned to `cursor-grok-4.6-high` docs worker per model policy; Assumptions/OQs carry Owner + Status. ✓

## review-plan quality criteria

1. Scope explicit (goal, non-goals, blast radius, files) — ✓.
2. Dependencies explicit — ✓.
3. Work sequenced into safe waves with handoffs — ✓.
4. Acceptance criteria testable and traceable — ✓ (mapping complete post-APPLY).
5. Verification plan concrete — ✓ (commands + named test paths; R2-F03 naming slip).
6. Risk handling present — ✓ (rollback table; R2-F01 residual tree gap).
7. No deferred blockers — ✓ (OQ-01/OQ-02 explicitly non-blocking, routed to RFL).

## Prohibitions honored

- Did not modify the artifact, templates, skills, or tests. ✓
- Did not switch branches, commit, or execute freeze YAML. ✓
- Did not re-open R1-F01–F05. ✓
- Structured findings, not prose-only. ✓

## Verdict

**CLEAN.**

No HIGH or MED findings. Four non-blocking items: three LOW (R2-F01 decision-tree fall-through; R2-F02 severity-split scope; R2-F03 test-file naming) and one NIT (R2-F04 stray H1). All are small, mechanical plan edits; none blocks Wave 1.

The freeze is consistent with the rung-01 APPLY, KEEP REJECT is complete and stable, the ID scheme is uniform and collision-free against live reviewer skills, and every wave cites concrete test paths with explicit owners. Recommendation: **ACCEPT** (apply R2-F01/R2-F02 before Wave 6/Wave 2 respectively; R2-F03/R2-F04 anytime).

## Appendix — Freeze SHA

```
d281cb7ee6321201bdce5825dde26f48c082ab6c7e4ef7a59cfeff965dcd1feb  .planning/spec_requirements_structure.plan.md
d281cb7ee6321201bdce5825dde26f48c082ab6c7e4ef7a59cfeff965dcd1feb  .planning/spec-requirements-structure/phases/01-world-class-artifacts/PLAN.md
```

Byte-identical pair. Re-hash only if that pair is rewritten.
