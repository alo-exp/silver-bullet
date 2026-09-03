# Requirements: SPEC.md + REQUIREMENTS.md structure

**Derived from:** [.planning/spec-requirements-structure/SPEC.md](SPEC.md) v1
**Generated:** 2026-08-29

## Functional Requirements

| ID | Requirement | Acceptance Criterion | Priority |
|----|-------------|----------------------|----------|
| REQ-01 | SPEC template is dual-audience: story plus ID-addressable AC | AC-01 | P1 |
| REQ-02 | REQUIREMENTS remains a derived REQ/NFR index with frontmatter, AC column, coverage matrix, and QC-1 headings as ID snapshots | AC-02 | P1 |
| REQ-03 | review-spec requires AC-nn and GWT (or equivalent) without dropping the eight QC-1 sections | AC-03 | P1 |
| REQ-04 | review-requirements keeps QC-1 OOS/Open Items; QC-6 accepts YAML; QC-7 prefers ID join | AC-04 | P1 |
| REQ-05 | review-cross-artifact parses table REQ/NFR and AC-nn; XART-F01/F02 are ID-based when matrix/AC column exists | AC-05 | P1 |
| REQ-06 | silver-spec write path matches templates; REQ derived from SPEC AC; no SPEC Requirements section | AC-06 | P1 |
| REQ-07 | clarify `--spec` capture schema can fill the new sections; Clarify never writes SPEC/REQUIREMENTS | AC-07 | P1 |
| REQ-08 | Help + Spec Lifecycle + plugin template mirror stay in parity with the new shape | AC-08 | P1 |
| REQ-09 | Template/compiler/QC string tests and ID-parse fixtures exist; spec-floor tests still pass | AC-09 | P1 |
| REQ-10 | Legacy root SPEC is not overwritten; greenfield and augment behave as specified | AC-10 | P1 |

## Non-Functional Requirements

| ID | Requirement | Metric | Priority |
|----|-------------|--------|----------|
| NFR-01 | SPEC template stays loadable | Canonical template body ≤ 200 lines / ≤ 16 KB | P2 |
| NFR-02 | REQUIREMENTS template stays an index, not a second spec | Template body ≤ 120 lines / ≤ 8 KB; no User Stories / UX Flows headings | P1 |
| NFR-03 | Existing spec-floor consumers keep working | `tests/hooks/test-spec-floor-check.sh` PASS without requiring new headings | P1 |
| NFR-04 | No live freeze execution or branch switch in implementation or tests | Tests and skills MUST NOT run `router_subagent_surfaces_85bf9f09.plan.md`; no `git checkout` / `git switch` | P1 |

## Out of Scope

- Merging SPEC.md and REQUIREMENTS.md
- Clarify writing SPEC.md / REQUIREMENTS.md
- Folding ingest into spec or clarify
- Verify rungs / Template B / verify model routing
- Policy C/D and executing the router_subagent_surfaces freeze
- Rewriting root v0.35/v0.37 planning artifacts to the new shape
- New product UI

## Open Items

- [ ] **OQ-01** Required vs optional `## Quality Attributes` on SPEC — Owner: RFL | Status: Follow-up-required
- [ ] **OQ-02** First-class `planning-root` vs refuse-overwrite-only — Owner: RFL | Status: Follow-up-required
