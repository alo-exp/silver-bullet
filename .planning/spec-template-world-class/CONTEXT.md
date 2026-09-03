---
phase: 01-world-class-spec
created: 2026-08-29
last-updated: 2026-08-29
status: ready-for-rfl
graphify: CLI (MCP user-graphify unavailable this session)
freeze: .planning/spec_template_world_class.plan.md
freeze-sha256: edf2c256dcf987016c887555bb0a60fadd0c45b636fd101faf309f3729b54b96
supersedes: .planning/spec_requirements_structure.plan.md
supersedes-sha256: 5d387487c1888fc260d50ffc57a4440459df9514fc0b9128c2c61e2ced0a61af
---

# CONTEXT — world-class SPEC template + software-kind packs

## Why this file is scoped

Canonical `/silver:context` writes [`.planning/CONTEXT.md`](../CONTEXT.md) (v0.35.0 SB/GSD alignment). That file, plus root [`.planning/SPEC.md`](../SPEC.md) and [`.planning/REQUIREMENTS.md`](../REQUIREMENTS.md), must not be overwritten.

This feature’s context lives here. Phase plan: [`phases/01-world-class-spec/PLAN.md`](phases/01-world-class-spec/PLAN.md). RFL freeze copy: [`../spec_template_world_class.plan.md`](../spec_template_world_class.plan.md).

A prior ladder ([`.planning/rfl-spec-requirements-structure/`](../rfl-spec-requirements-structure/)) is **discontinued** (2026-08-29) after rung 04 APPLY. It reviewed plan hygiene, not SPEC-template quality + software-kind tailoring. Useful content including R1–R4 APPLY is inherited in the new freeze. Do not continue that ladder.

## Freeze identity

Pin RFL to this SHA, not to CONTEXT edits after the copy:

- **File:** [`.planning/spec_template_world_class.plan.md`](../spec_template_world_class.plan.md)
- **SHA-256:** `edf2c256dcf987016c887555bb0a60fadd0c45b636fd101faf309f3729b54b96`
- **Bytes:** identical to [`phases/01-world-class-spec/PLAN.md`](phases/01-world-class-spec/PLAN.md) (653 lines / 54141 bytes). Re-hash only if that pair is rewritten.

Do not clobber [`.planning/rfl-plan-review-prompt/`](../rfl-plan-review-prompt/), [`.planning/clarify-spec-compiler/`](../clarify-spec-compiler/), discontinued [`.planning/rfl-spec-requirements-structure/`](../rfl-spec-requirements-structure/) history, or freeze [`../router_subagent_surfaces_85bf9f09.plan.md`](../router_subagent_surfaces_85bf9f09.plan.md).

## Locked decisions

1. **Keep two files.** SPEC.md = human story + kind-selected packs. REQUIREMENTS.md = REQ/NFR ID index with priority. Do not merge. Do **not** compile kinds into a third canonical consumer doc.
2. **Compiler derives REQ from SPEC AC.** `/silver:spec` Step 8: derive from **SPEC.md acceptance criteria**, not from the clarify brief.
3. **Clarify owns the interview.** `/silver:clarify --spec` writes `*-CLARIFY-*.md`. Clarify does **not** write SPEC.md or REQUIREMENTS.md. Kind-first turn, then skip N/A packs.
4. **Do not subsume ingest.** `/silver:ingest` remains the MCP dump path; spec compiles ingest draft + brief.
5. **This pass is plan-only.** Do not rewrite templates, skills, help, or tests until this RFL completes. Do not run RFL rungs from the freeze author (parent launches subsequent rungs). Do not `git checkout` / `git switch`, commit, push, or execute freeze YAML.
6. **Audience is dual:** humans (PM/eng) **and** models (plan, validate, execute, RFL, reviewers).
7. **Root v0.35 spec is legacy-protected.** Do not silently destroy [`.planning/SPEC.md`](../SPEC.md).
8. **Out of Scope / Open Items stay on REQUIREMENTS.** Reduce clone by ID snapshot; do not delete the sections.
9. **SPEC is not one generic blob.** `software-kind` frontmatter + section packs compile in/out. UX Flows is **not** universal QC-1.
10. **RFL review priority:** template contract + kind packs first; implementation waves second; plan-hygiene last.
11. **Model policy inherited:** unspecified Grok = 4.6 High not Extra High; Fast forbidden; Verify = Grok 4.5 High native Cursor Task; Cursor via Pi forbidden until Omni tool-call translation is fixed. Claude via Pi.
12. **Prior APPLY pins stay** (legacy lock totality, QC-4 AC column = IDs, If/Then only for non-interactive, `### Invariants`, QC-string filename). Do not unwind without a template-contract reason.
13. **Rung 01 APPLY (GLM 5.2 High):** R1-F01–F10 accepted into this freeze. QC-1 = 7 headings; Change History = QC-10; Step 3 kind-aware; kind-gated clarify turns; `multi` required-wins; `decisions` capture; `security` required for headless/data-ml/library-sdk; `kind-multi` fixture; QC-11 Invariants; pack-local IDs; QC-6b `software-kinds` iff `multi`.
14. **Rung 02 APPLY (Kimi K3 High):** R2-F01–F06 accepted into this freeze. Real `nfr` Clarify turn (honors R1-F03); pack-table Notes match catalog; closed-world default for unlisted kind×pack cells; `SCR-nn`/`STG-nn`; omit-do-not-stub for forbidden headings; twin-relative link base + inline NFR-01–04 thresholds. KEEP REJECT unchanged.
15. **Rung 03 APPLY (Gemini 3.7 Flash High):** R3-F01–F05 accepted into this freeze. Kind-aware QC-7 (no UX Flows / SPEC-F61 when `ux` is forbidden, even if `figma-url` is present); XART-F02 Functional-only (NFR-nn exempt); Wave 3 Step 1 kind-aware domain mapping; Wave 2 `rg` includes QC-9/10 and SPEC-F71/F72/REQ-F70; present forbidden heading emits `SPEC-F08`. KEEP REJECT unchanged.

## Scope

World-class SPEC.md **template contract** (frontmatter, IDs, GWT, invariants, change history, examples, decision log, NFR/quality attributes, security, telemetry, API, UX, data, errors — required vs optional); **software-kind** catalog and pack compile; REQUIREMENTS as ID index with optional NFR packs; reviewer QCs (kind-aware); compiler write path; clarify `--spec` skip-turns; help + Spec Lifecycle parity; tests; augment/migration lock.

Not a product-feature spec for an unrelated app. Not a continuation of the discontinued hygiene ladder.

## Constraints

- Graphify first (CLI if MCP fails); agentmemory save; Context Mode for large analysis.
- Nested workers: `model: cursor-grok-4.6-high`. No Fast. No Grok 4.6 Extra High as unspecified default.
- Site/help Wave 5 (implementation later) must follow repo site-worker model policy.
- `plugins/silver-bullet/templates/specs/` is a mirror: edit `templates/specs/` then `bash scripts/sync-templates.sh`.
- Skill edits later require `bash scripts/sync-codex-package.sh`. Live `silver-bullet.md` stays in parity with `templates/silver-bullet.md.base`.

## Evidence already collected

| Source | Finding |
|--------|---------|
| [`templates/specs/SPEC.md.template`](../../templates/specs/SPEC.md.template) | 52 lines / 1017 bytes. Generic UX Flows for every product. No `software-kind`, no AC-nn, no GWT, no change history, no security/telemetry/API/data/errors/decision log/examples packs. |
| [`templates/specs/REQUIREMENTS.md.template`](../../templates/specs/REQUIREMENTS.md.template) | 25 lines / 636 bytes. No YAML. Example row says REQ derived from **User Story**. Compiler Step 8 derives from **AC**. |
| [`skills/review-spec/SKILL.md`](../../skills/review-spec/SKILL.md) | QC-1 locks eight `##` headings including UX Flows — kind-blind. |
| [`skills/silver-clarify/SKILL.md`](../../skills/silver-clarify/SKILL.md) | `next=spec` capture schema has no software-kind, no skip-turns, no GWT. **Do not write SPEC.md.** |
| Discontinued ladder | Rungs 01–04 APPLY landed hygiene pins in SHA `5d387487…`. Remaining Pi/Claude rungs cancelled 2026-08-29. |

Graphify CLI: `graphify query "spec requirements structure RFL freeze PLAN template software-kind"` and `graphify query "software-kind SPEC template packs clarify capture schema review-spec QC-1 headings"`.

## Risks

| Risk | Mitigation |
|------|------------|
| Requiring every pack in spec-floor breaks v0.35 | Floor stays Overview + AC |
| Kind-blind QC-1 forces UX Flows on CLIs | Wave 2 kind-aware QC-1; UX Flows is a pack |
| Third canonical doc creep | Catalog/packs are compiler **inputs**; outputs remain SPEC + REQUIREMENTS |
| Deleting REQUIREMENTS OOS/Open Items fails QC-1 | Keep headings; snapshot-by-ID |
| Compiler overwrites root SPEC | Wave 6 legacy lock + fixture |
| Hygiene-only RFL repeat | CHARTER + brief: template contract + kinds are primary |

## Non-goals

- Merging SPEC + REQUIREMENTS or adding a compiled third spec
- Moving the interview back into `/silver:spec`
- Replacing or folding `/silver:ingest`
- Executing router_subagent_surfaces freeze YAML
- Rewriting live RFL prompts, Policy C/D, or verify routing
- Rewriting DESIGN.md.template (default skip)
- Silently “fixing” root v0.35/v0.37 planning files
- Continuing `.planning/rfl-spec-requirements-structure/` after discontinuation

## Dependencies

- Templates: [`templates/specs/SPEC.md.template`](../../templates/specs/SPEC.md.template), [`REQUIREMENTS.md.template`](../../templates/specs/REQUIREMENTS.md.template)
- Skills: silver-spec, silver-clarify, review-spec, review-requirements, review-cross-artifact
- Lifecycle: [`silver-bullet.md`](../../silver-bullet.md) Spec Lifecycle
- Tests to extend: [`tests/scripts/test-clarify-spec-compiler.sh`](../../tests/scripts/test-clarify-spec-compiler.sh), [`tests/hooks/test-spec-floor-check.sh`](../../tests/hooks/test-spec-floor-check.sh)
- Inherited freeze: [`../spec_requirements_structure.plan.md`](../spec_requirements_structure.plan.md) SHA `5d387487c1888fc260d50ffc57a4440459df9514fc0b9128c2c61e2ced0a61af`
- Successor RFL: [`../rfl-spec-template-world-class/`](../rfl-spec-template-world-class/)

## Planning handoff

- **Scope:** World-class SPEC template + kind packs; REQUIREMENTS index; QC; compiler; clarify skip-turns; help; tests; migration lock.
- **Out of scope:** See locked decisions and non-goals.
- **Verification:** Named test paths in the phase PLAN; no freeze YAML; no branch switch.
- **Blockers:** none for freeze authoring. Rung 03 Gemini APPLIED (SHA `edf2c256dcf987016c887555bb0a60fadd0c45b636fd101faf309f3729b54b96`). Parent launches Grok 4.6 High.

## Unresolved (not blocking Wave 1)

See PLAN OQ-01–OQ-07. Rung 01 pinned OQ-03 (`multi` + required-wins), OQ-04 (`decisions` capture), OQ-06 (`kind-multi` = web-ui+http-api). Rung 02 pinned OQ-01 (real `nfr` Clarify turn for nfr-required kinds).
