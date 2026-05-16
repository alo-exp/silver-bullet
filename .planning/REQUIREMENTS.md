# Requirements: Silver Bullet v0.35.4 Agents Directory Reorg

**Defined:** 2026-05-16
**Core Value:** Keep Silver Bullet's canonical source skills agent-agnostic while generating stable runtime-specific bundles for Claude and Codex.

---

## v1 Requirements

### Agent Bundle Layout

- [x] **AGENT-01**: The canonical skill source tree remains `skills/`, and generated agent bundles are emitted under `agents/claude/` and `agents/codex/` from that source tree.
- [x] **AGENT-02**: Generated bundles normalize skill naming consistently so the runtime picker sees `silver:*` names in both agent outputs.
- [x] **AGENT-03**: The Codex bundle is sanitized for Codex-safe interaction semantics without reintroducing Claude-only runtime assumptions.
- [x] **AGENT-04**: The Claude bundle preserves Claude-native behavior while still being generated from the same canonical source.

### Installer / Package Wiring

- [x] **AGENT-05**: Codex package sync/install surfaces consume the generated `agents/codex` bundle and retain compatibility aliases only as aliases, not as the source of truth.
- [x] **AGENT-06**: Claude install materializes `agents/claude` in the installed cache and keeps the `skills` entrypoint functional.
- [x] **AGENT-07**: Package surface copying includes `agents/` so the generated bundles are present in the repo snapshot and installed caches.

### Documentation / Tests / Verification

- [x] **AGENT-08**: Repository docs and bundle comments clearly explain the canonical source tree vs. generated `agents/<agent>/` bundles.
- [x] **AGENT-09**: Tests cover bundle generation, install/sync parity, generated naming, alias compatibility, and both runtime surfaces.
- [x] **AGENT-10**: Verification includes the focused installer/sync tests, the full suite, and live e2e smoke before release.

## v2 Requirements

None yet. This milestone is focused on the agent-bundle layout reorg, not a broader workflow redesign.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Rewriting all skill bodies to be fully runtime-neutral in one pass | The reorg is about layout and generation first; body-level neutralization can be phased without blocking the new bundle architecture |
| Introducing a new third-party agent family | The milestone targets Claude and Codex first, with the layout designed so future agents can be added later |
| Changing the SB/GSD semver contract | This milestone should stay on the current patch line and not reopen the execution/lifecycle architecture |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| AGENT-01 | Phase 95 | Complete |
| AGENT-02 | Phase 95 | Complete |
| AGENT-03 | Phase 96 | Complete |
| AGENT-04 | Phase 96 | Complete |
| AGENT-05 | Phase 96 | Complete |
| AGENT-06 | Phase 96 | Complete |
| AGENT-07 | Phase 97 | Complete |
| AGENT-08 | Phase 97 | Complete |
| AGENT-09 | Phase 98 | Complete |
| AGENT-10 | Phase 99 | Complete |

**Coverage:**
- v1 requirements: 10 total
- Mapped to phases: 10
- Unmapped: 0 ✓

---
*Requirements defined: 2026-05-16*
*Last updated: 2026-05-16 after v0.35.4 milestone start*
