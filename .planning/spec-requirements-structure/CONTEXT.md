---
phase: 01-world-class-artifacts
created: 2026-08-29
last-updated: 2026-08-29
status: ready-for-rfl
graphify: CLI (MCP user-graphify unavailable this session)
agentmemory: mem_mte1o9yp_9fcea556ac82
freeze: .planning/spec_requirements_structure.plan.md
freeze-sha256: 5d387487c1888fc260d50ffc57a4440459df9514fc0b9128c2c61e2ced0a61af
---

# CONTEXT — SPEC.md + REQUIREMENTS.md structure

## Why this file is scoped

Canonical `/silver:context` writes [`.planning/CONTEXT.md`](../CONTEXT.md) (v0.35.0 SB/GSD alignment). That file, plus root [`.planning/SPEC.md`](../SPEC.md) and [`.planning/REQUIREMENTS.md`](../REQUIREMENTS.md), must not be overwritten.

This feature’s context lives here. Phase plan: [`phases/01-world-class-artifacts/PLAN.md`](phases/01-world-class-artifacts/PLAN.md). RFL freeze copy: [`../spec_requirements_structure.plan.md`](../spec_requirements_structure.plan.md).

## Freeze identity

Pin RFL to this file, not to CONTEXT/SPEC edits after the copy:

- **File:** [`.planning/spec_requirements_structure.plan.md`](../spec_requirements_structure.plan.md)
- **SHA-256:** `5d387487c1888fc260d50ffc57a4440459df9514fc0b9128c2c61e2ced0a61af`
- **Bytes:** identical to [`phases/01-world-class-artifacts/PLAN.md`](phases/01-world-class-artifacts/PLAN.md) (454 lines). Re-hash only if that pair is rewritten.

Do not clobber [`.planning/rfl-plan-review-prompt/`](../rfl-plan-review-prompt/), [`.planning/clarify-spec-compiler/`](../clarify-spec-compiler/), or freeze [`../router_subagent_surfaces_85bf9f09.plan.md`](../router_subagent_surfaces_85bf9f09.plan.md).

## Locked decisions

1. **Keep two files.** SPEC.md = human story (problem, stories, flows, AC, assumptions). REQUIREMENTS.md = REQ/NFR ID index with priority. Do not merge.
2. **Compiler derives REQ from SPEC AC.** `/silver:spec` Step 8: derive from **SPEC.md acceptance criteria**, not from the clarify brief. Keep that authority.
3. **Clarify owns the interview.** `/silver:clarify --spec` (`next=spec`) writes `*-CLARIFY-*.md`. Clarify does **not** write SPEC.md or REQUIREMENTS.md.
4. **Do not subsume ingest.** `/silver:ingest` remains the MCP dump path; spec compiles ingest draft + brief.
5. **This pass is plan-only.** Do not rewrite templates, skills, help, or tests yet. Do not run RFL rungs (parent will). Do not `git checkout` / `git switch`, commit, push, or execute freeze YAML.
6. **Audience is dual:** humans (PM/eng) **and** models (plan, validate, execute, RFL, reviewers). Structure must be ID-addressable and story-readable.
7. **Root v0.35 spec is legacy-protected.** Do not silently destroy [`.planning/SPEC.md`](../SPEC.md) (16-line v0.35.0 SB/GSD alignment, no frontmatter).
8. **Out of Scope / Open Items stay on REQUIREMENTS.** review-requirements QC-1 requires those headings. Reduce accidental clone; do not delete the sections (QC-6/7 / QC-1).
9. **Model policy inherited:** unspecified Grok = 4.6 High not Extra High; Fast forbidden; Verify = Grok 4.5 High native Cursor Task; Cursor via Pi forbidden until Omni tool-call translation is fixed.

## Scope

Improve **structure and effectiveness** of SPEC.md and REQUIREMENTS.md templates, reviewer QCs, compiler write path, clarify `--spec` capture schema, help + `silver-bullet.md` Spec Lifecycle parity, tests, and augment/migration. Not a product-feature spec for an unrelated app.

## Constraints

- Graphify first (CLI if MCP fails); agentmemory save; Context Mode for large analysis.
- PathJail: read `skills/` via copy-out or sandbox; this pass writes planning docs only.
- Nested workers: `model: cursor-grok-4.6-high`. No Fast. No Grok 4.6 Extra High as unspecified default.
- Site/help Wave 5 (implementation later) must follow repo site-worker model policy.
- `plugins/silver-bullet/templates/specs/` is a mirror: edit `templates/specs/` then `bash scripts/sync-templates.sh`.
- Skill edits later require `bash scripts/sync-codex-package.sh`. Live `silver-bullet.md` stays in parity with `templates/silver-bullet.md.base`.

## Evidence already collected

| Source | Finding |
|--------|---------|
| [`templates/specs/SPEC.md.template`](../../templates/specs/SPEC.md.template) | 52 lines / 1017 bytes. Frontmatter: `spec-version`, `status`, `jira-id`, `figma-url`, `source-artifacts`, `created`, `last-updated`. AC = unlabeled `- [ ]` bullets. No AC-NN, no Given/When/Then, no change history, no feature-slug, no coverage table. |
| [`templates/specs/REQUIREMENTS.md.template`](../../templates/specs/REQUIREMENTS.md.template) | 25 lines / 636 bytes. No YAML frontmatter. Example row says REQ derived from **User Story**. Compiler Step 8 derives from **AC**. Mirrors OOS + Open Questions as prose placeholders. |
| [`skills/review-spec/SKILL.md`](../../skills/review-spec/SKILL.md) | QC-1 locks eight `##` headings matching the template. QC-4 is testability heuristic only (no GWT, no AC IDs). QC-6 requires four frontmatter fields; empty `YYYY-MM-DD` fails. |
| [`skills/review-requirements/SKILL.md`](../../skills/review-requirements/SKILL.md) | QC-1 requires Functional / Non-Functional / Out of Scope / Open Items. QC-2/3/5: `REQ-nn` / `NFR-nn`, unique, P1–P3. QC-6: `**Derived from:**` **or** `derived-from:`. QC-7: content-alignment heuristic when `source_inputs` has a spec path. |
| [`skills/review-cross-artifact/SKILL.md`](../../skills/review-cross-artifact/SKILL.md) | QC-1 **already looks for `AC-XX`** and REQ patterns like `**REQ-XX**:` / `- [x] **XXX-NNx**:`. Templates emit neither AC IDs nor that REQ shape (they emit a markdown table `\| REQ-01 \|`). |
| [`skills/silver-spec/SKILL.md`](../../skills/silver-spec/SKILL.md) | Compiler. Step 2 fallback scaffold lists **Users and goals** and **Requirements** (not in template). Step 7 writes template sections. Step 8: 1:1 REQ from AC, NFR from NF concerns, **mirror** OOS + Open Questions. |
| [`skills/silver-clarify/SKILL.md`](../../skills/silver-clarify/SKILL.md) | `next=spec` capture schema: Overview, stories, UX, AC, assumptions, OOS, Edges, Errors, Data, OQ, source artifacts. No AC-NN, no GWT, no NFR/quality-attributes field, no priority. **Do not write SPEC.md.** |
| [`silver-bullet.md`](../../silver-bullet.md) Spec Lifecycle (~L507) | Artifacts named; SPEC frontmatter listed as `spec-version`, `jira-id`, `status` only. REQ-XX / NFR-XX named. Create = clarify `--spec` then spec compile. |
| [`hooks/spec-floor-check.sh`](../../hooks/spec-floor-check.sh) | Hard floor for `silver:plan`: file exists + `## Overview` + `## Acceptance Criteria` only. |
| [`hooks/pr-traceability.sh`](../../hooks/pr-traceability.sh) | PR blurb: “Requirements covered: see SPEC.md ## Acceptance Criteria”. Appends Implementations after the template HTML comment. Hardcoded `.planning/SPEC.md`. |
| [`tests/scripts/test-clarify-spec-compiler.sh`](../../tests/scripts/test-clarify-spec-compiler.sh) | Skill-string contract for compiler split. **Does not** assert `templates/specs/*` headings or ID schemes. |
| Root [`.planning/SPEC.md`](../SPEC.md) | v0.35.0 product spec: Overview + unlabeled AC only; **no** template frontmatter / stories / flows. Judge template, not this product. |
| Root [`.planning/REQUIREMENTS.md`](../REQUIREMENTS.md) | v0.37 ORCH-* checklist, not REQ/NFR tables. Judge template, not this product. |
| [`.planning/rfl-plan-review-prompt/SPEC.md`](../rfl-plan-review-prompt/SPEC.md) | Template-faithful (frontmatter + 8 sections) but AC still unlabeled checkboxes — shows the template is the bottleneck. |

Graphify CLI: `graphify query "SPEC.md.template REQUIREMENTS.md.template review-spec QC"` (MCP namespace `user-graphify` failed live discovery). Nodes included Spec Elicitation Workflow (help), REQUIREMENTS template, silver-spec Steps 7–8 (`clarify-spec-compiler/_work`), review-requirements sections.

## Risks

| Risk | Mitigation |
|------|------------|
| Requiring every new heading in spec-floor breaks v0.35 root + old consumer specs | Floor stays Overview + AC. New structure is reviewer + compiler, not the hook floor. |
| Deleting REQUIREMENTS OOS/Open Items to avoid clone fails QC-1 | Keep headings; snapshot-by-ID not prose dump. |
| Compiler default path overwrites root SPEC | Wave 6 legacy lock + fixture; never use live root as the test victim. |
| XART parse vs table format | Wave 2 updates parse examples to `\| REQ-nn \|` and `AC-nn`. |
| Help/site drift | Wave 5 + `test-clarify-spec-compiler.sh` help asserts + site freshness tests. |
| Skill/template mirror staleness | `sync-templates.sh` + `sync-codex-package.sh` in Wave 7. |

## Non-goals

- Merging SPEC + REQUIREMENTS into one file
- Moving the 9-turn interview back into `/silver:spec`
- Replacing or folding `/silver:ingest`
- Executing router_subagent_surfaces freeze YAML
- Rewriting live RFL prompts, Policy C/D, or verify routing
- Rewriting DESIGN.md.template except a one-line “link AC-NN” note if Wave 5 needs it (default: skip DESIGN)
- Silently “fixing” root v0.35/v0.37 planning files to the new shape

## Dependencies

- Templates: [`templates/specs/SPEC.md.template`](../../templates/specs/SPEC.md.template), [`REQUIREMENTS.md.template`](../../templates/specs/REQUIREMENTS.md.template)
- Skills: silver-spec, silver-clarify, review-spec, review-requirements, review-cross-artifact
- Reviewer interface: [`skills/artifact-reviewer/rules/reviewer-interface.md`](../../skills/artifact-reviewer/rules/reviewer-interface.md)
- Lifecycle: [`silver-bullet.md`](../../silver-bullet.md) Spec Lifecycle + review-loop table; [`templates/silver-bullet.md.base`](../../templates/silver-bullet.md.base)
- Help: [`site/help/workflows/silver-spec.html`](../../site/help/workflows/silver-spec.html)
- Tests to extend: [`tests/scripts/test-clarify-spec-compiler.sh`](../../tests/scripts/test-clarify-spec-compiler.sh), [`tests/hooks/test-spec-floor-check.sh`](../../tests/hooks/test-spec-floor-check.sh)
- Sync: [`scripts/sync-templates.sh`](../../scripts/sync-templates.sh), [`scripts/sync-codex-package.sh`](../../scripts/sync-codex-package.sh)

## Planning handoff

- **Scope:** World-class dual-audience structure for SPEC + REQUIREMENTS; QC; compiler; clarify capture; help/parity; tests; migration lock.
- **Out of scope:** See locked decisions and non-goals.
- **Acceptance:** This folder’s [`SPEC.md`](SPEC.md) AC-01–AC-10 / [`REQUIREMENTS.md`](REQUIREMENTS.md) REQ-01–REQ-10, NFR-01–NFR-04.
- **Verification:** Named test paths in the phase PLAN; no freeze YAML; no branch switch.
- **Blockers:** none for plan authoring.

## Unresolved (not blocking)

- Whether `## Quality Attributes` is a **required** SPEC heading (default in PLAN: **optional**; capture schema still collects NFR so the compiler can fill the REQUIREMENTS NFR table). RFL may flip this to required.
- Whether feature-scoped `planning-root` becomes a first-class compiler path in this feature or a follow-up. Default in PLAN: **detect legacy root and refuse overwrite**; still default-write `.planning/SPEC.md` for true greenfield.
