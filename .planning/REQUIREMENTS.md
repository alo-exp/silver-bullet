# Requirements: Silver Bullet v0.14.0

**Defined:** 2026-04-09
**Core Value:** Single enforced workflow that eliminates the gap between "what AI should do" and "what AI actually does"

## v1 Requirements

Requirements for v0.14.0 milestone. Each maps to roadmap phases.

### Spec Foundation

- [ ] **SPEC-01**: SB produces a canonical `.planning/SPEC.md` artifact with YAML frontmatter (spec-version, status, jira-id, figma-url, source-artifacts) and standardized sections (Overview, User Stories, UX Flows, Acceptance Criteria, Assumptions, Open Questions)
- [ ] **SPEC-02**: SB produces a `.planning/DESIGN.md` artifact with structured screen/component/behavior/state definitions extracted from design inputs
- [ ] **SPEC-03**: Spec templates exist in `templates/specs/` (SPEC.md.template, DESIGN.md.template, REQUIREMENTS.md.template) that new specs are generated from
- [ ] **SPEC-04**: Every unresolvable ambiguity during spec creation produces an explicit `[ASSUMPTION: ...]` block in SPEC.md — assumption density is a quality signal, not optional decoration
- [ ] **SPEC-05**: SPEC.md includes a `spec-version:` field in frontmatter that increments on each substantive change, enabling downstream version pinning

### AI-Driven Elicitation

- [ ] **ELIC-01**: `silver-spec` skill guides PM/BA through Socratic requirements elicitation — asking clarifying questions, surfacing gaps, and producing SPEC.md + REQUIREMENTS.md as output
- [ ] **ELIC-02**: Elicitation covers: user stories, acceptance criteria, UX flow definition, edge cases, error states, and data model implications — through interactive dialogue, not template filling
- [ ] **ELIC-03**: At any point during elicitation, user can provide a Google Doc, PPT, or Figma link as input — SB extracts content and incorporates it into the evolving spec
- [ ] **ELIC-04**: Elicitation produces assumption blocks for every gap the PM/BA cannot resolve on the spot, with each assumption tagged for follow-up
- [ ] **ELIC-05**: `silver-spec` can be invoked standalone (greenfield spec) or to augment an ingested draft (post-JIRA-ingestion refinement)
- [ ] **ELIC-06**: Elicitation orchestrates existing plugin skills where applicable (product-management:write-spec, design:user-research, design:design-critique) rather than reimplementing their capabilities

### External Artifact Ingestion

- [ ] **INGT-01**: `silver-ingest` skill pulls JIRA ticket content (summary, description, acceptance criteria, linked issues) via Atlassian MCP connector and produces a draft SPEC.md
- [ ] **INGT-02**: `silver-ingest` resolves artifact links found in JIRA ticket (Google Drive URLs, Figma URLs, Confluence URLs) and ingests their content
- [ ] **INGT-03**: Figma design context extracted via Figma MCP server — components, layout, tokens, flows — and written to DESIGN.md
- [ ] **INGT-04**: Google Docs/Slides content extracted via Google Workspace CLI with vision support for embedded images — text + image understanding incorporated into spec context
- [ ] **INGT-05**: Every ingestion produces an `INGESTION_MANIFEST.md` listing all artifacts attempted, succeeded, failed, and missing — no silent partial failures
- [ ] **INGT-06**: Missing or failed artifact ingestion produces `[ARTIFACT MISSING: reason]` blocks in SPEC.md, not empty sections
- [ ] **INGT-07**: Ingestion is resumable — if a connector fails mid-ingestion, re-running `silver-ingest` picks up from where it left off using the manifest

### Multi-Repo Spec Referencing

- [ ] **REPO-01**: `silver-ingest --source-url <repo-url>` fetches main repo's SPEC.md and caches it as `.planning/SPEC.main.md` (read-only) in the mobile/satellite repo
- [ ] **REPO-02**: Mobile repo's SB session validates its pinned spec-version against the main repo's current version at session start — blocks on mismatch with diff shown
- [ ] **REPO-03**: Non-mobile-exclusive requirements are implementation-spec'd in the main repo first, then the main repo spec is referenced as input for mobile repo SB sessions
- [ ] **REPO-04**: Mobile-exclusive requirements follow standard SB process entirely within the mobile repo — no main repo dependency

### Pre-Build Validation

- [ ] **VALD-01**: `silver-validate` skill performs gap analysis between SPEC.md and PLAN.md before implementation begins — surfaces missing coverage, conflicting requirements, unresolved assumptions
- [ ] **VALD-02**: Validation output uses machine-readable finding objects with severity (BLOCK / WARN / INFO), not prose
- [ ] **VALD-03**: BLOCK-severity findings prevent `gsd-plan-phase` from proceeding until resolved
- [ ] **VALD-04**: WARN-severity findings are surfaced in PR description as deferred items
- [ ] **VALD-05**: Pre-build validation re-surfaces all `[ASSUMPTION: ...]` blocks from SPEC.md at implementation start for developer awareness

### Spec Floor Enforcement

- [ ] **FLOR-01**: `spec-floor-check.sh` hook on `gsd-plan-phase` hard-blocks if `.planning/SPEC.md` is missing or lacks required sections (Overview, Acceptance Criteria, at minimum)
- [ ] **FLOR-02**: `gsd-fast` and `gsd-quick` use a separate 3-field minimal spec format (what, why, acceptance-criteria) — checked as warning, not hard block
- [ ] **FLOR-03**: Spec floor check completes in under 10 seconds to avoid blocking developer flow

### PR Traceability

- [ ] **TRAC-01**: Session record written at session start captures active spec-id, spec-version, and JIRA ticket reference
- [ ] **TRAC-02**: `pr-traceability.sh` hook on `gsd-ship` auto-populates PR description with spec reference, requirement IDs covered, and link to SPEC.md
- [ ] **TRAC-03**: PR traceability is machine-generated from session records — no developer annotation required
- [ ] **TRAC-04**: SPEC.md Implementations section updated post-merge with PR URL and commit range

### UAT Gate

- [ ] **UATG-01**: `gsd-audit-uat` produces a UAT checklist derived from SPEC.md acceptance criteria — each criterion becomes a verifiable checklist item
- [ ] **UATG-02**: UAT artifact (UAT.md) committed to `.planning/` with pass/fail per criterion and evidence notes
- [ ] **UATG-03**: `uat-gate.sh` hook on `gsd-complete-milestone` blocks if UAT not run or any criterion marked FAIL
- [ ] **UATG-04**: UAT validates against the pinned spec-version to prevent verification against a stale spec

## Validated (from previous milestones)

- ✓ 7-layer enforcement architecture — v0.7.0
- ✓ 8 quality dimension gates — v0.7.0
- ✓ full-dev-cycle / devops-cycle workflows — v0.7.0
- ✓ Pre-release quality gate §9 — v0.7.4
- ✓ 4 gap-filling skills as enforced gates — v0.8.0
- ✓ SENTINEL security hardening — v0.8.0
- ✓ GSD-mainstay orchestration — v0.13.0
- ✓ silver-bullet.md overhaul — v0.13.0
- ✓ /silver smart router — v0.13.0
- ✓ SB orchestration skills — v0.13.0

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Advanced Ingestion

- **INGT-08**: Bidirectional JIRA sync — spec changes push status updates back to JIRA ticket
- **INGT-09**: Confluence page ingestion as spec source (alongside Google Docs)
- **INGT-10**: PDF attachment ingestion from JIRA (pending MCP support)

### Advanced Validation

- **VALD-06**: Cross-spec conflict detection across multiple SPEC.md files in same repo
- **VALD-07**: Automated Requirements Traceability Matrix (RTM) generation
- **VALD-08**: Regression UAT — re-run UAT for previously shipped specs affected by new changes

### Advanced Multi-Repo

- **REPO-05**: Automatic cross-repo sync notifications when main repo spec version changes
- **REPO-06**: Shared design token synchronization between main and mobile repos

## Out of Scope

| Feature | Reason |
|---------|--------|
| Custom API integrations for JIRA/Figma/Google | MCP connectors handle all external access — no custom API code |
| Modifying GSD plugin files | §8 plugin boundary — SB orchestrates, doesn't modify |
| Automated Figma design creation | Figma MCP is read-only during beta; write capability deferred |
| JIRA ticket creation from SB | One-way ingestion only for v0.14.0; bidirectional sync is v2 |
| Nomadic Care-specific naming or file structures | SB provides generic patterns; teams customize via config |
| Replacing GSD execution engine | GSD owns execution, SB orchestrates |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| SPEC-01 | Phase 12 | Pending |
| SPEC-02 | Phase 12 | Pending |
| SPEC-03 | Phase 12 | Pending |
| SPEC-04 | Phase 12 | Pending |
| SPEC-05 | Phase 12 | Pending |
| ELIC-01 | Phase 12 | Pending |
| ELIC-02 | Phase 12 | Pending |
| ELIC-03 | Phase 12 | Pending |
| ELIC-04 | Phase 12 | Pending |
| ELIC-05 | Phase 12 | Pending |
| ELIC-06 | Phase 12 | Pending |
| FLOR-01 | Phase 12 | Pending |
| FLOR-02 | Phase 12 | Pending |
| FLOR-03 | Phase 12 | Pending |
| INGT-01 | Phase 13 | Pending |
| INGT-02 | Phase 13 | Pending |
| INGT-03 | Phase 13 | Pending |
| INGT-04 | Phase 13 | Pending |
| INGT-05 | Phase 13 | Pending |
| INGT-06 | Phase 13 | Pending |
| INGT-07 | Phase 13 | Pending |
| REPO-01 | Phase 13 | Pending |
| REPO-02 | Phase 13 | Pending |
| REPO-03 | Phase 13 | Pending |
| REPO-04 | Phase 13 | Pending |
| VALD-01 | Phase 14 | Pending |
| VALD-02 | Phase 14 | Pending |
| VALD-03 | Phase 14 | Pending |
| VALD-04 | Phase 14 | Pending |
| VALD-05 | Phase 14 | Pending |
| TRAC-01 | Phase 14 | Pending |
| TRAC-02 | Phase 14 | Pending |
| TRAC-03 | Phase 14 | Pending |
| TRAC-04 | Phase 14 | Pending |
| UATG-01 | Phase 14 | Pending |
| UATG-02 | Phase 14 | Pending |
| UATG-03 | Phase 14 | Pending |
| UATG-04 | Phase 14 | Pending |

**Coverage:**
- v1 requirements: 38 total
- Mapped to phases: 38
- Unmapped: 0 ✓

---
*Requirements defined: 2026-04-09*
*Last updated: 2026-04-09 after roadmap creation*
