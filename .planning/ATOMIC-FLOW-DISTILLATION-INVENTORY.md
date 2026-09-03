# Atomic Flow Distillation Inventory

Date: 2026-06-24

Status: **Phase 1 deliverable** — classification input for APO catalog distillation (Phase 3+).
Schema-backed fields align with `docs/apo-catalog.schema.json`.

## Summary

- **Skills inventoried:** 85
- **Legacy FLOW mappings:** 18
- **GSD/SB alias mappings:** 16

## Distillation Table

| Skill | Classification | Hierarchy | Canonical entity | Equivalence | Disposition | Invariant | V-loop (draft) | Tools |
|-------|----------------|-----------|------------------|-------------|-------------|-----------|----------------|-------|
| `ai-llm-safety` | quality-dimension-step | flow_step | `AF-FLOW-13` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `artifact-review-assessor` | reviewer-pack | flow_step | `AF-FLOW-10` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `artifact-reviewer` | reviewer-pack | flow_step | `AF-FLOW-10` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `devops-quality-gates` | flow-step-skill | flow_step | `TBD-PHASE-3` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `devops-skill-router` | flow-step-skill | flow_step | `TBD-PHASE-3` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `extensibility` | quality-dimension-step | flow_step | `AF-FLOW-13` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `modularity` | quality-dimension-step | flow_step | `AF-FLOW-13` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `reliability` | quality-dimension-step | flow_step | `AF-FLOW-13` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `reusability` | quality-dimension-step | flow_step | `AF-FLOW-13` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `review-context` | reviewer-pack | flow_step | `AF-FLOW-10` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `review-cross-artifact` | reviewer-pack | flow_step | `AF-FLOW-10` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `review-design` | reviewer-pack | flow_step | `AF-FLOW-10` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `review-ingestion-manifest` | reviewer-pack | flow_step | `AF-FLOW-10` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `review-plan` | reviewer-pack | flow_step | `AF-FLOW-10` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `review-requirements` | reviewer-pack | flow_step | `AF-FLOW-10` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `review-research` | reviewer-pack | flow_step | `AF-FLOW-10` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `review-roadmap` | reviewer-pack | flow_step | `AF-FLOW-10` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `review-spec` | reviewer-pack | flow_step | `AF-FLOW-10` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `review-uat` | reviewer-pack | flow_step | `AF-FLOW-10` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `review-verification` | reviewer-pack | flow_step | `AF-FLOW-10` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `scalability` | quality-dimension-step | flow_step | `AF-FLOW-13` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `security` | quality-dimension-step | flow_step | `AF-FLOW-11` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver` | process-router | process | `WF-SILVER-ROUTER` | — | retain | required-when-in-workflow | input→product→V-gate | graphify |
| `silver-add` | flow-step-skill | flow_step | `TBD-PHASE-3` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-benchmark` | precomposed-workflow | workflow | `WF-SILVER-BENCHMARK` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-blast-radius` | flow-step-skill | flow_step | `TBD-PHASE-3` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-bootstrap-milestone` | flow-step-skill | flow_step | `TBD-PHASE-3` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-bootstrap-project` | flow-step-skill | flow_step | `TBD-PHASE-3` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-branch-finish` | flow-step-skill | flow_step | `AF-FLOW-14` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-bugfix` | precomposed-workflow | workflow | `WF-SILVER-BUGFIX` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-canary` | precomposed-workflow | workflow | `WF-SILVER-CANARY` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-clarify` | atomic-flow-implementation | atomic_flow | `AF-FLOW-03` | — | retain | context-conditional | input→product→V-gate | — |
| `silver-completion-audit` | flow-step-skill | flow_step | `AF-FLOW-12` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-content` | precomposed-workflow | workflow | `WF-SILVER-CONTENT` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-context` | flow-step-skill | flow_step | `TBD-PHASE-3` | — | retain | required-when-in-workflow | input→product→V-gate | graphify |
| `silver-create-release` | atomic-flow-implementation | atomic_flow | `AF-FLOW-18` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-debug` | atomic-flow-implementation | atomic_flow | `AF-FLOW-15` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-deploy` | precomposed-workflow | workflow | `WF-SILVER-DEPLOY` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-devops` | precomposed-workflow | workflow | `WF-SILVER-DEVOPS` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-domain-audit` | flow-step-skill | flow_step | `TBD-PHASE-3` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-ensure-docs` | atomic-flow-implementation | atomic_flow | `AF-FLOW-17` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-execute` | atomic-flow-implementation | atomic_flow | `AF-FLOW-08` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-fast` | precomposed-workflow | workflow | `WF-SILVER-FAST` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-feature` | precomposed-workflow | workflow | `WF-SILVER-FEATURE` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-forensics` | precomposed-workflow | workflow | `WF-SILVER-FORENSICS` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-handoff` | atomic-flow-implementation | atomic_flow | `AF-FLOW-16` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-incident` | precomposed-workflow | workflow | `WF-SILVER-INCIDENT` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-ingest` | flow-step-skill | flow_step | `TBD-PHASE-3` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-init` | atomic-flow-implementation | atomic_flow | `AF-FLOW-01` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-migrate` | flow-step-skill | flow_step | `TBD-PHASE-3` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-orchestrator` | process-router | process | `WF-SILVER-ROUTER` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-orient` | atomic-flow-implementation | atomic_flow | `AF-FLOW-02` | — | retain | context-conditional | input→product→V-gate | graphify |
| `silver-phase` | flow-step-skill | flow_step | `TBD-PHASE-3` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-plan` | atomic-flow-implementation | atomic_flow | `AF-FLOW-06` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-quality-gates` | atomic-flow-implementation | atomic_flow | `AF-FLOW-13` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-refactor` | precomposed-workflow | workflow | `WF-SILVER-REFACTOR` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-release` | precomposed-workflow | workflow | `WF-SILVER-RELEASE` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-rem` | flow-step-skill | flow_step | `TBD-PHASE-3` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-remove` | flow-step-skill | flow_step | `TBD-PHASE-3` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-research` | precomposed-workflow | workflow | `AF-FLOW-04` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-retro` | precomposed-workflow | workflow | `WF-SILVER-RETRO` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-review` | atomic-flow-implementation | atomic_flow | `AF-FLOW-10` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-review-fix-ladder` | flow-step-skill | flow_step | `TBD-PHASE-3` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-review-request` | flow-step-skill | flow_step | `AF-FLOW-10` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-review-stats` | flow-step-skill | flow_step | `TBD-PHASE-3` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-review-triage` | flow-step-skill | flow_step | `AF-FLOW-10` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-scan` | flow-step-skill | flow_step | `TBD-PHASE-3` | — | retain | context-conditional | input→product→V-gate | graphify |
| `silver-secure` | atomic-flow-implementation | atomic_flow | `AF-FLOW-11` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-ship` | atomic-flow-implementation | atomic_flow | `AF-FLOW-14` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-spec` | atomic-flow-implementation | atomic_flow | `AF-FLOW-05` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-spike` | flow-step-skill | flow_step | `TBD-PHASE-3` | — | retain | context-conditional | input→product→V-gate | — |
| `silver-test` | precomposed-workflow | workflow | `WF-SILVER-TEST` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-thread` | flow-step-skill | flow_step | `TBD-PHASE-3` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-ui` | precomposed-workflow | workflow | `WF-SILVER-UI` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-ui-contract` | atomic-flow-implementation | atomic_flow | `AF-FLOW-07` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-ui-review` | atomic-flow-implementation | atomic_flow | `AF-FLOW-09` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-undo` | flow-step-skill | flow_step | `TBD-PHASE-3` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-update` | flow-step-skill | flow_step | `TBD-PHASE-3` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-validate` | flow-step-skill | flow_step | `TBD-PHASE-3` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-verify` | atomic-flow-implementation | atomic_flow | `AF-FLOW-12` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `silver-worktree` | flow-step-skill | flow_step | `TBD-PHASE-3` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `tdd` | flow-step-skill | flow_step | `AF-FLOW-08` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `testability` | quality-dimension-step | flow_step | `AF-FLOW-13` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `usability` | quality-dimension-step | flow_step | `AF-FLOW-13` | — | retain | required-when-in-workflow | input→product→V-gate | — |
| `verify-tests` | flow-step-skill | flow_step | `AF-FLOW-12` | — | retain | required-when-in-workflow | input→product→V-gate | — |

## Legacy FLOW 1–18 Disposition

| Legacy FLOW | Catalog entity | Disposition |
|-------------|----------------|-------------|
| FLOW 1 | `AF-FLOW-01` | retained skeleton; Phase 3 dedup pending |
| FLOW 2 | `AF-FLOW-02` | retained skeleton; Phase 3 dedup pending |
| FLOW 3 | `AF-FLOW-03` | retained skeleton; Phase 3 dedup pending |
| FLOW 4 | `AF-FLOW-04` | retained skeleton; Phase 3 dedup pending |
| FLOW 5 | `AF-FLOW-05` | retained skeleton; Phase 3 dedup pending |
| FLOW 6 | `AF-FLOW-06` | retained skeleton; Phase 3 dedup pending |
| FLOW 7 | `AF-FLOW-07` | retained skeleton; Phase 3 dedup pending |
| FLOW 8 | `AF-FLOW-08` | retained skeleton; Phase 3 dedup pending |
| FLOW 9 | `AF-FLOW-09` | retained skeleton; Phase 3 dedup pending |
| FLOW 10 | `AF-FLOW-10` | retained skeleton; Phase 3 dedup pending |
| FLOW 11 | `AF-FLOW-11` | retained skeleton; Phase 3 dedup pending |
| FLOW 12 | `AF-FLOW-12` | retained skeleton; Phase 3 dedup pending |
| FLOW 13 | `AF-FLOW-13` | retained skeleton; Phase 3 dedup pending |
| FLOW 14 | `AF-FLOW-14` | retained skeleton; Phase 3 dedup pending |
| FLOW 15 | `AF-FLOW-15` | retained skeleton; Phase 3 dedup pending |
| FLOW 16 | `AF-FLOW-16` | retained skeleton; Phase 3 dedup pending |
| FLOW 17 | `AF-FLOW-17` | retained skeleton; Phase 3 dedup pending |
| FLOW 18 | `AF-FLOW-18` | retained skeleton; Phase 3 dedup pending |

## GSD / SB-Owned Alias Map

| Alias | Canonical entity |
|-------|------------------|
| `code-review` | `FS-SILVER_REVIEW` |
| `finishing-a-development-branch` | `FS-SILVER_BRANCH_FINISH` |
| `gsd-code-review` | `AF-FLOW-10` |
| `gsd-discuss-phase` | `AF-FLOW-03` |
| `gsd-execute-phase` | `AF-FLOW-08` |
| `gsd-plan-phase` | `AF-FLOW-06` |
| `gsd-secure-phase` | `AF-FLOW-11` |
| `gsd-ship` | `AF-FLOW-14` |
| `gsd-validate-phase` | `FS-SILVER_VALIDATE` |
| `gsd-verify-work` | `AF-FLOW-12` |
| `receiving-code-review` | `FS-SILVER_REVIEW_TRIAGE` |
| `requesting-code-review` | `FS-SILVER_REVIEW_REQUEST` |
| `systematic-debugging` | `AF-FLOW-15` |
| `test-driven-development` | `FS-TDD` |
| `verification-before-completion` | `FS-SILVER_COMPLETION_AUDIT` |
| `writing-plans` | `FS-SILVER_PLAN` |

## Runtime Queue Tokens

| Token | Entity |
|-------|--------|
| `FLOW-DEVOPS-QUALITY-GATE-PRESHIP` | `AF-FLOW-13` |
| `FLOW-QUALITY-GATE` | `AF-FLOW-13` |
| `FLOW-QUALITY-GATE-PRESHIP` | `AF-FLOW-13` |
| `ROUTER` | `FS-SILVER` |

## Worker Templates (`templates/orchestrator-workers/`)

- `BLAST-RADIUS.md` → `TBD`
- `BOOTSTRAP.md` → `AF-FLOW-01`
- `BRANCH-FINISH.md` → `TBD`
- `CLARIFY.md` → `AF-FLOW-03`
- `COMPLETION-AUDIT.md` → `TBD`
- `DEBUG.md` → `AF-FLOW-15`
- `DECIDE.md` → `AF-FLOW-04`
- `DESIGN-CONTRACT.md` → `AF-FLOW-07`
- `DEVOPS-SKILL-ROUTER.md` → `TBD`
- `DOCUMENT.md` → `AF-FLOW-17`
- `EXECUTE.md` → `AF-FLOW-08`
- `FAST.md` → `TBD`
- `ORIENT.md` → `AF-FLOW-02`
- `PHASE.md` → `TBD`
- `PLAN.md` → `AF-FLOW-06`
- `QUALITY-GATE.md` → `AF-FLOW-13`
- `RELEASE.md` → `AF-FLOW-18`
- `REVIEW-REQUEST.md` → `TBD`
- `REVIEW-TRIAGE.md` → `TBD`
- `REVIEW.md` → `AF-FLOW-10`
- `ROUTER.md` → `TBD`
- `SECURE.md` → `AF-FLOW-11`
- `SHIP.md` → `AF-FLOW-14`
- `SPECIFY.md` → `AF-FLOW-05`
- `UI-QUALITY.md` → `AF-FLOW-09`
- `VALIDATE.md` → `TBD`
- `VERIFY.md` → `AF-FLOW-12`

## Phase 3 Promotion Result

- Canonical atomic flows are promoted in `docs/apo-catalog.json` with stable `AF-*` IDs.
- All 85 skills are represented as catalog `flow_steps` with per-step V-loops.
- Legacy FLOW 1-18 mappings are retained only in `migration_map.legacy_flows`.
- `docs/composable-flows-contracts.md`, `docs/workflow-composition-matrix.md`, and `docs/generated/atomic-flow-index.json` are generated views from the catalog.
