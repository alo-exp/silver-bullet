# Roadmap: Silver Bullet v0.35.4 Agents Directory Reorg

**Goal:** Reorganize generated agent-specific skill bundles under `agents/<agent-name>/...`, keep `skills/` as the canonical source tree, and make Claude and Codex consume the correct runtime bundles without drift.

**Phase numbering:** Continues from Phase 94.

---

## Phases

### Phase 95: Agent Bundle Renderer & Layout Scaffold

**Requirements:** AGENT-01..02

**Goal:** Add a shared renderer that generates `agents/claude` and `agents/codex` from the canonical `skills/` tree and normalizes skill naming consistently.

### Phase 96: Installer and Package Wiring

**Requirements:** AGENT-03..07

**Goal:** Rewire Codex/Claude package surfaces and installers so the generated bundles are the runtime source of truth, with compatibility aliases only as compatibility aliases.

### Phase 97: Docs and Compatibility Notes

**Requirements:** AGENT-08

**Goal:** Update repo docs, templates, and bundle comments to clearly describe the agent bundle layout and source/bundle contract.

### Phase 98: Tests and Verification Harness

**Requirements:** AGENT-09

**Goal:** Add and update tests for bundle generation, sync/install parity, naming consistency, and runtime compatibility.

### Phase 99: Release v0.35.4

**Requirements:** AGENT-10

**Goal:** Bump release-facing version surfaces, run focused and full verification, execute live e2e smoke, and publish the `v0.35.4` release once the reorg is green.

---

## Progress

| Phase | Requirements | Status | Notes |
|-------|--------------|--------|-------|
| 95. Agent Bundle Renderer & Layout Scaffold | AGENT-01..02 | Pending | Generate `agents/claude` and `agents/codex` |
| 96. Installer and Package Wiring | AGENT-03..07 | Pending | Codex/Claude installers, package surfaces, aliases |
| 97. Docs and Compatibility Notes | AGENT-08 | Pending | Runtime/bundle layout docs |
| 98. Tests and Verification Harness | AGENT-09 | Pending | Sync/install parity and naming tests |
| 99. Release v0.35.4 | AGENT-10 | Pending | Full verification + live e2e + release |

## Coverage Validation

- v1 requirements: 10/10 mapped
- Milestone phases: 5
- Open issues in scope: 0
- Unmapped requirements: 0 ✓

---
*Roadmap defined: 2026-05-16*
