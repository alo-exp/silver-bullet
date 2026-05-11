# Requirements: Silver Bullet v0.32.5 Open Issue Burn-down

**Defined:** 2026-05-11
**Core Value:** A single enforced workflow that keeps AI agents on the rails while removing the last user-visible gaps.

---

## v1 Requirements

### Runtime-Aware Bootstrap

- [ ] **INIT-01**: `silver:init` detects Codex vs Claude runtime and uses runtime-appropriate bootstrap prompts and instruction-file handling instead of assuming Claude-only paths. (Issue #146)
- [ ] **INIT-02**: `silver:init` auto-detects permission mode and issue tracker from runtime/repo metadata, only prompting when detection fails. (Issue #145)
- [ ] **INIT-03**: Brownfield source-pattern inference uses real repository layout signals, including WordPress-style plugin roots, rather than defaulting to `/src/`. (Issue #144)
- [ ] **INIT-04**: Product-management plugin detection recognizes Codex plugin cache paths and other supported install roots. (Issue #148)
- [ ] **INIT-05**: Brownfield task-doc checklist generation emits real governed-doc keys plus required section maps, with no placeholder keys. (Issue #147)
- [ ] **INIT-06**: Init/bootstrap prefers the working local GSD entrypoint when the wrapper path cannot load correctly. (Issue #150)

### Docs & Enforcement

- [ ] **DOC-01**: `silver:ensure-docs` performs a full semantic audit of governed docs against current code, hooks, workflows, and runtime behavior, and explicitly distinguishes archival docs from live docs. (Issue #151)
- [ ] **HOOK-01**: Enforcement hooks allow read-only inspection of hook files while still blocking writes/modifications. (Issue #149)

### Backlog Reconciliation

- [ ] **TRACK-01**: Already-implemented backlog items are reconciled and closed, including the `silver-handoff` issue and any other stale non-blocking items that are now shipped. (Issue #98)
- [ ] **TRACK-02**: The todo-app clear-completed backlog cluster is collapsed to a canonical issue/fix path and duplicate issues are closed or retargeted. (Issues #106, #107, #111, #112, #122, #127, #135, #137, #138, #140, #141, #142, #143)

### Release Readiness

- [ ] **REL-01**: Version-facing surfaces are bumped to `v0.32.5` as part of the release prep, including changelog and release badge/material where applicable.
- [ ] **REL-02**: CI is green and the pre-release quality gate passes twice in a row with no findings before release.
- [ ] **REL-03**: `silver-create-release` produces structured notes and publishes the GitHub Release for `v0.32.5`.

## v2 Requirements

None yet. This milestone is intentionally a burn-down of current open issues, not a broad feature expansion.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Multi-agent phase coordination refactor | Still valuable, but not part of this issue burn-down and already tracked separately in project history |
| New SB feature areas unrelated to the 22 open issues | Keep the milestone focused so release can ship once the backlog is cleared |
| Broad product-line redesigns outside the current issue set | Would dilute the burn-down and delay release without reducing the open backlog |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| INIT-01 | Phase 86 | Pending |
| INIT-02 | Phase 86 | Pending |
| INIT-03 | Phase 86 | Pending |
| INIT-04 | Phase 86 | Pending |
| INIT-05 | Phase 86 | Pending |
| INIT-06 | Phase 86 | Pending |
| DOC-01 | Phase 87 | Pending |
| HOOK-01 | Phase 88 | Pending |
| TRACK-01 | Phase 89 | Pending |
| TRACK-02 | Phase 90 | Pending |
| REL-01 | Phase 91 | Pending |
| REL-02 | Phase 91 | Pending |
| REL-03 | Phase 91 | Pending |

**Coverage:**
- v1 requirements: 13 total
- Mapped to phases: 13
- Unmapped: 0 ✓

---
*Requirements defined: 2026-05-11*
*Last updated: 2026-05-11 after v0.32.5 milestone start*
