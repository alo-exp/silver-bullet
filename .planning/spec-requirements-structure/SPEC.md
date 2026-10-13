---
spec-version: 1
status: Draft
jira-id: ""
figma-url: ""
source-artifacts: []
created: 2026-08-29
last-updated: 2026-08-29
feature-slug: spec-requirements-structure
planning-root: .planning/spec-requirements-structure
---

# SPEC.md + REQUIREMENTS.md structure — Spec

## Overview

Silver Bullet’s canonical spec artifacts are compiled into `.planning/SPEC.md` and `.planning/REQUIREMENTS.md` from a clarify `--spec` brief. The current templates are too thin for dual use: humans get unlabeled checkbox AC and duplicated mirrors; models (plan, validate, execute, RFL, cross-artifact QC) cannot reliably address AC or join REQ rows to AC. Cross-artifact QC already looks for `AC-XX` IDs the SPEC template never emits. This work upgrades **structure and effectiveness** of both files, their reviewers, the compiler write path, and the clarify capture schema, without merging the files or moving the interview back into spec.

## User Stories

- As a **PM**, I want SPEC.md to read as a short story (who, problem, flows, testable outcomes) so that stakeholders can review intent without decoding an ID dump.
- As an **engineer**, I want REQUIREMENTS.md to be a stable REQ/NFR index with priority and AC links so that plans, tests, and PRs can cite IDs.
- As a **compiler (`/silver:spec`)**, I want templates and write-steps to agree so that compiled files pass review-spec / review-requirements / review-cross-artifact without heuristic guessing.
- As an **RFL / artifact reviewer**, I want machine-checkable IDs, Given/When/Then (or equivalent), and a coverage matrix so that QC is evidence, not vibes.
- As an **operator of this repo**, I want augment mode and a legacy root lock so that the v0.35 `.planning/SPEC.md` is not silently destroyed.

## UX Flows

This is a docs/skill/template change, not a product UI.

1. User runs `/silver:clarify --spec` (interview). Brief is written to `*-CLARIFY-*.md` using the **updated capture schema**. Clarify does not write SPEC.md.
2. User runs `/silver:spec` (compiler). It reads the newest brief (+ ingest draft if any), writes SPEC.md then derives REQUIREMENTS.md from SPEC AC.
3. `/artifact-reviewer` runs review-spec, then review-requirements (source_inputs includes SPEC), later review-cross-artifact against the ID scheme.
4. `/silver:plan` still passes spec-floor on Overview + Acceptance Criteria (floor unchanged).
5. After ship, `pr-traceability.sh` still anchors on `## Implementations` and cites REQ IDs as well as SPEC.

## Acceptance Criteria

- [ ] **AC-01** Given the SPEC template is the compiler’s canonical shape, when a greenfield compile finishes, then SPEC.md has YAML frontmatter (existing fields plus `feature-slug`, `clarify-brief` or empty, `derived-requirements` path), the eight QC-1 sections, ID-labeled user stories (`US-nn`), ID-labeled AC (`AC-nn`) in Given/When/Then or documented equivalent, Assumptions with Status+Owner, Open Questions with `OQ-nn`, Out of Scope with `OOS-nn`, Implementations placeholder, and a Change History table.
- [ ] **AC-02** Given REQUIREMENTS.md remains a separate derived index, when the compiler writes it, then it has YAML frontmatter (`derived-from`, `spec-version`, `generated`, `feature-slug`) **and** a `**Derived from:**` line (QC-6), Functional and Non-Functional tables with `REQ-nn` / `NFR-nn`, unique IDs, P1–P3, an **AC** column on REQ rows, Out of Scope and Open Items headings (QC-1) as ID snapshots not prose clones, and a Coverage Matrix (`AC-nn` → `REQ-nn`).
- [ ] **AC-03** Given review-spec QC today has no AC IDs, when QC is updated, then missing `AC-nn` or missing Given/When/Then (or equivalent) is an ISSUE, and QC-1 still requires the eight section headings (Implementations included).
- [ ] **AC-04** Given review-requirements QC-6/7, when QC is updated, then frontmatter `derived-from` is accepted, QC-7 prefers AC-ID join over prose fuzzy match when IDs exist, and Out of Scope / Open Items headings remain required.
- [ ] **AC-05** Given review-cross-artifact QC-1 parse examples do not match the REQ table, when QC is updated, then parsers accept `| REQ-nn |` / `| NFR-nn |` and `AC-nn`, and XART-F01/F02 are ID-based when the coverage matrix or AC column is present.
- [ ] **AC-06** Given silver-spec Step 2 lists sections not in the template, when the compiler skill is updated, then the fallback scaffold matches the template, Step 7 mints IDs and GWT from the brief, Step 8 derives REQ from SPEC AC (not the brief) and does not invent a SPEC `## Requirements` section.
- [ ] **AC-07** Given clarify `--spec` capture schema has no GWT/NFR/IDs, when the schema is updated, then the brief can fill Overview, US, UX, AC (GWT-ready), Quality Attributes (optional NFR seed), Assumptions, OOS, Edges/Errors/Data, OQ, source artifacts — and Clarify still **must not** write SPEC.md or REQUIREMENTS.md.
- [ ] **AC-08** Given Spec Lifecycle and help list artifacts at a coarse grain, when docs are updated, then `silver-bullet.md` + `templates/silver-bullet.md.base` + `site/help/workflows/silver-spec.html` name the ID scheme and SPEC vs REQUIREMENTS split, and `bash scripts/sync-templates.sh` keeps the plugin mirror in parity.
- [ ] **AC-09** Given no current test asserts `templates/specs/*` structure, when tests land, then `tests/scripts/test-spec-requirements-templates.sh` locks template headings/frontmatter/ID examples, a fixture pair under `tests/fixtures/specs/world-class-min/` parses with `tests/scripts/test-spec-req-id-parse.sh`, and `tests/scripts/test-clarify-spec-compiler.sh` gains string asserts for compiler/clarify/QC updates; `tests/hooks/test-spec-floor-check.sh` still passes with only Overview+AC.
- [ ] **AC-10** Given root `.planning/SPEC.md` is the v0.35 product spec, when augment/greenfield logic is updated, then a fixture shaped like that root file is **not** overwritten; greenfield still writes `.planning/SPEC.md`; augment of a template-shaped spec bumps `spec-version`, preserves `created`, fills missing IDs without deleting extra sections.

## Assumptions

- [ASSUMPTION: Root `.planning/SPEC.md` / `REQUIREMENTS.md` stay untouched by this feature’s implementation waves | Status: Accepted | Owner: planning]
- [ASSUMPTION: DESIGN.md.template is out of scope unless a one-line AC link is required for help accuracy | Status: Accepted | Owner: planning]
- [ASSUMPTION: `## Quality Attributes` on SPEC is optional, not QC-1-required, unless RFL flips it | Status: Follow-up-required | Owner: RFL]
- [ASSUMPTION: spec-floor remains Overview + AC only | Status: Accepted | Owner: planning]
- [ASSUMPTION: Plugin template mirror is regenerated with sync-templates.sh, not edited by hand | Status: Accepted | Owner: implementation]
- [ASSUMPTION: This authoring pass does not rewrite templates or run RFL | Status: Accepted | Owner: planning]

## Open Questions

- [ ] **OQ-01** Required vs optional `## Quality Attributes` on SPEC — Owner: RFL | Status: Follow-up-required (PLAN default: optional)
- [ ] **OQ-02** First-class `planning-root` for all compiles vs refuse-overwrite-only for legacy root — Owner: RFL | Status: Follow-up-required (PLAN default: refuse overwrite + greenfield path unchanged)

## Out of Scope

- Merging SPEC.md and REQUIREMENTS.md
- Clarify writing SPEC.md / REQUIREMENTS.md
- Folding ingest into spec or clarify
- Verify rungs, Template B, Grok 4.5 High verify routing
- Policy A/B/C/D, OpenCode skip, executing `router_subagent_surfaces_85bf9f09.plan.md`
- Rewriting root v0.35/v0.37 planning artifacts to the new shape
- New product UI

## Implementations

<!-- Populated automatically by pr-traceability.sh hook post-merge. -->
