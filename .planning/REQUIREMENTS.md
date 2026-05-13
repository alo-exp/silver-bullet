# Requirements: Silver Bullet v0.33.1 Open Issue Burn-down

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

- [ ] **REL-01**: Version-facing surfaces are bumped to `v0.33.1` as part of the release prep, including changelog and release badge/material where applicable.
- [ ] **REL-02**: CI is green and the pre-release quality gate passes twice in a row with no findings before release.
- [ ] **REL-03**: `silver-create-release` produces structured notes and publishes the GitHub Release for `v0.33.1`.

### Architecture Contract Refresh

- [x] **FLOW-01**: `/silver` routes most non-trivial bare user intent through SB workflow composition or GSD delegation while preserving direct answers for Q&A/status/trivial interactions.
- [x] **FLOW-02**: Composable flow contracts are atomic enough to support dynamic workflow composition without bundling unrelated lifecycle steps.
- [x] **FLOW-03**: SB workflow skills reference the current SB, GSD, Superpowers, and Product Management skill catalogs.
- [x] **FLOW-04**: GSD remains the lifecycle authority for phase, milestone, semver, testing, bugfix, verification, and release mechanics.
- [x] **FLOW-05**: Templates and runtime instructions align with the refreshed router and flow contracts.
- [x] **FLOW-06**: Forge mirrors and Codex package sync reflect the updated router/flow contract surface.
- [x] **FLOW-07**: Verification covers router contracts, package sync, integration hooks, and the full suite.

### Forge Port Parity

- [x] **FORGE-01**: Forge SB-owned skills reflect the current source skill surface, including newly added SB skills.
- [x] **FORGE-02**: Forge-specific adaptations remain Forge-native and do not regress into Claude/Codex-only installation instructions.
- [x] **FORGE-03**: Hook-equivalent Forge agents represent the current SB hook surface where Forge can reasonably emulate it.
- [x] **FORGE-04**: Forge docs, installer counts, smoke tests, and scenario harnesses agree with the updated inventory.
- [x] **FORGE-05**: Legacy or stale Forge scenario references are removed or renamed to current skill/command names.
- [x] **FORGE-06**: Verification covers Forge parity plus the broader SB test suite.

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
| FLOW-01 | Phase 92 | Completed |
| FLOW-02 | Phase 92 | Completed |
| FLOW-03 | Phase 92 | Completed |
| FLOW-04 | Phase 92 | Completed |
| FLOW-05 | Phase 92 | Completed |
| FLOW-06 | Phase 92 | Completed |
| FLOW-07 | Phase 92 | Completed |
| FORGE-01 | Phase 93 | Completed |
| FORGE-02 | Phase 93 | Completed |
| FORGE-03 | Phase 93 | Completed |
| FORGE-04 | Phase 93 | Completed |
| FORGE-05 | Phase 93 | Completed |
| FORGE-06 | Phase 93 | Completed |

**Coverage:**
- v1 requirements: 26 total
- Mapped to phases: 26
- Unmapped: 0 ✓

---
*Requirements defined: 2026-05-11*
*Last updated: 2026-05-13 after v0.33.1 milestone start*
