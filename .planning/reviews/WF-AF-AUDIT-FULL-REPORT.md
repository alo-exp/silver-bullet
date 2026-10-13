# WF/AF Full Catalog Compliance Audit

**Date:** 2026-07-05 13:00 UTC  
**Branch:** wf-af-audit  
**Mode:** `/silver:new-workflow` Audit (read-only)  
**Scripts:** [`scripts/audit-workflow-compliance.sh`](../scripts/audit-workflow-compliance.sh), [`scripts/audit-atomic-flow-compliance.sh`](../scripts/audit-atomic-flow-compliance.sh) *(new)*

## Executive summary

Audited **157** catalog entities (100% coverage): **24** workflows, **28** atomic flows, **105** flow steps.

| Entity type | Total | PASS | FAIL | Pass rate |
|-------------|------:|-----:|-----:|----------:|
| Workflows (WF-*) | 24 | 14 | 10 | 58.3% |
| Atomic flows (AF-*) | 28 | 28 | 0 | 100.0% |
| Flow steps (FS-*) | 105 | 102 | 3 | 97.1% |
| **Overall** | **157** | **144** | **13** | **91.7%** |

### Script extensions (this run)

- Extended [`scripts/audit-workflow-compliance.sh`](../scripts/audit-workflow-compliance.sh): resolves any `WF-*` id; distinguishes composer (`WF-SILVER-*`) vs reusable-component workflows; composition ref resolution check.
- Added [`scripts/audit-atomic-flow-compliance.sh`](../scripts/audit-atomic-flow-compliance.sh): per-entity audit for `AF-*` and `FS-*` (catalog, v_loop, ownership, enforcement, composition).
- **Not committed** — extensions required for 100% coverage run; review before merge.

## Remediation priorities

### P0 — Router workflow mis-registration (user decision)

`WF-SILVER-ROUTER` fails across migration_map, structural, triple_alignment, orchestrator. Catalog slug is `silver-router` but canonical router skill is `silver` (no `skills/silver-router/`). **Decision needed:** map router WF to `silver` skill, or create dedicated `silver-router` composer surface.

### P1 — Secondary composers missing enforcement surfaces (9 workflows)

These composer workflows exist as skills but lack `enforcement_queue`, orchestrator registration, guard markers, and parseable pre-exec sections:

- `WF-SILVER-BENCHMARK`
- `WF-SILVER-CANARY`
- `WF-SILVER-CONTENT`
- `WF-SILVER-DEPLOY`
- `WF-SILVER-FORENSICS`
- `WF-SILVER-INCIDENT`
- `WF-SILVER-REFACTOR`
- `WF-SILVER-RETRO`
- `WF-SILVER-TEST`

**Fix pattern:** Add `enforcement_queue` to catalog entry; register in `hooks/lib/orchestrator-state.sh`; add guard `required_markers` in `hooks/workflow-chain-guard.sh`; document pre-exec in SKILL.md. See passing reference: `WF-SILVER-FEATURE`.

### P2 — Orphan delegation flow steps (3)

Flow steps exist in catalog but are not listed in any AF `flow_steps[]`:

- `FS-SILVER_AGENT_CLAUDE`
- `FS-SILVER_AGENT_CODEX`
- `FS-SILVER_AGENT_CURSOR`

**Fix:** Add to `AF-AGENT-DELEGATE.flow_steps[]` or mark deprecated with documented rationale (Phase 4 delegation flip).

### P3 — No action (passing)

- All **28 atomic flows** PASS (v_loop, owning_skills, worker templates, composition refs, dedup gates).
- **6 reusable-component workflows** PASS (`WF-POST-EXEC-GATES`, `WF-VALIDATE-SUBSTEP`, `WF-REVIEW-TRIAD`, `WF-SHIP-READINESS`, `WF-PROCESS-MAINTENANCE`, `WF-AGENT-DELEGATE-ENTRY`).
- **13 primary composer workflows** PASS (feature, ui, devops, fast, bugfix, deep-research, release, new-workflow, etc.).

## Remediation closeout (2026-07-05)

**Status: 157/157 PASS** — see [WF-AF-AUDIT-CLOSEOUT.md](WF-AF-AUDIT-CLOSEOUT.md).

| Priority | Items | Resolution |
|----------|-------|------------|
| P0 | `WF-SILVER-ROUTER` | Slug remapped to `silver`; enforcement surfaces aligned to `skills/silver/SKILL.md` |
| P1 | 9 secondary composers | Triple alignment: catalog `enforcement_queue` + orchestrator + guard + SKILL pre-exec |
| P2 | 3 orphan FS steps | Added to `AF-AGENT-DELEGATE.flow_steps[]` |

## Per-entity results

### Workflows

| ID | Verdict | Failure details |
|----|---------|-----------------|
| `WF-AGENT-DELEGATE-ENTRY` | PASS | — |
| `WF-POST-EXEC-GATES` | PASS | — |
| `WF-PROCESS-MAINTENANCE` | PASS | — |
| `WF-REVIEW-TRIAD` | PASS | — |
| `WF-SHIP-READINESS` | PASS | — |
| `WF-SILVER-BENCHMARK` | **FAIL** | FAIL: orchestrator-state missing silver-benchmark<br>FAIL [structural]: validate-workflow-authoring.sh<br>FAIL [catalog]: enforcement_queue missing for WF-SILVER-BENCHMARK<br>FAIL [triple_alignment]: SKILL pre-exec markers not parseable<br>FAIL [triple_alignment]: guard [] != orchestrator [context,plan]<br>FAIL [orchestrator]: composer missing from orchestrator-state.sh |
| `WF-SILVER-BUGFIX` | PASS | — |
| `WF-SILVER-CANARY` | **FAIL** | FAIL: orchestrator-state missing silver-canary<br>FAIL [structural]: validate-workflow-authoring.sh<br>FAIL [catalog]: enforcement_queue missing for WF-SILVER-CANARY<br>FAIL [triple_alignment]: SKILL pre-exec markers not parseable<br>FAIL [triple_alignment]: guard [] != orchestrator [context,plan]<br>FAIL [orchestrator]: composer missing from orchestrator-state.sh |
| `WF-SILVER-CONTENT` | **FAIL** | FAIL: orchestrator-state missing silver-content<br>FAIL [structural]: validate-workflow-authoring.sh<br>FAIL [catalog]: enforcement_queue missing for WF-SILVER-CONTENT<br>FAIL [triple_alignment]: SKILL pre-exec markers not parseable<br>FAIL [triple_alignment]: guard [] != orchestrator [context,plan]<br>FAIL [orchestrator]: composer missing from orchestrator-state.sh |
| `WF-SILVER-DEEP-RESEARCH` | PASS | — |
| `WF-SILVER-DEPLOY` | **FAIL** | FAIL: orchestrator-state missing silver-deploy<br>FAIL [structural]: validate-workflow-authoring.sh<br>FAIL [catalog]: enforcement_queue missing for WF-SILVER-DEPLOY<br>FAIL [triple_alignment]: SKILL pre-exec markers not parseable<br>FAIL [triple_alignment]: guard [] != orchestrator [context,plan]<br>FAIL [orchestrator]: composer missing from orchestrator-state.sh |
| `WF-SILVER-DEVOPS` | PASS | — |
| `WF-SILVER-FAST` | PASS | — |
| `WF-SILVER-FEATURE` | PASS | — |
| `WF-SILVER-FORENSICS` | **FAIL** | FAIL: orchestrator-state missing silver-forensics<br>FAIL [structural]: validate-workflow-authoring.sh<br>FAIL [catalog]: enforcement_queue missing for WF-SILVER-FORENSICS<br>FAIL [triple_alignment]: SKILL pre-exec markers not parseable<br>FAIL [triple_alignment]: guard [] != orchestrator [context,plan]<br>FAIL [orchestrator]: composer missing from orchestrator-state.sh |
| `WF-SILVER-INCIDENT` | **FAIL** | FAIL: orchestrator-state missing silver-incident<br>FAIL [structural]: validate-workflow-authoring.sh<br>FAIL [catalog]: enforcement_queue missing for WF-SILVER-INCIDENT<br>FAIL [triple_alignment]: SKILL pre-exec markers not parseable<br>FAIL [triple_alignment]: guard [] != orchestrator [context,plan]<br>FAIL [orchestrator]: composer missing from orchestrator-state.sh |
| `WF-SILVER-NEW-WORKFLOW` | PASS | — |
| `WF-SILVER-REFACTOR` | **FAIL** | FAIL: orchestrator-state missing silver-refactor<br>FAIL [structural]: validate-workflow-authoring.sh<br>FAIL [catalog]: enforcement_queue missing for WF-SILVER-REFACTOR<br>FAIL [triple_alignment]: SKILL pre-exec markers not parseable<br>FAIL [triple_alignment]: guard [] != orchestrator [context,plan]<br>FAIL [orchestrator]: composer missing from orchestrator-state.sh |
| `WF-SILVER-RELEASE` | PASS | — |
| `WF-SILVER-RETRO` | **FAIL** | FAIL: orchestrator-state missing silver-retro<br>FAIL [structural]: validate-workflow-authoring.sh<br>FAIL [catalog]: enforcement_queue missing for WF-SILVER-RETRO<br>FAIL [triple_alignment]: SKILL pre-exec markers not parseable<br>FAIL [triple_alignment]: guard [] != orchestrator [context,plan]<br>FAIL [orchestrator]: composer missing from orchestrator-state.sh |
| `WF-SILVER-ROUTER` | **FAIL** | FAIL: missing skills/silver-router/SKILL.md<br>FAIL: skill_to_entity missing silver-router<br>FAIL: orchestrator-state missing silver-router<br>FAIL [structural]: validate-workflow-authoring.sh<br>FAIL [migration_map]: skill_to_entity missing for silver-router<br>FAIL [catalog]: enforcement_queue missing for WF-SILVER-ROUTER |
| `WF-SILVER-TEST` | **FAIL** | FAIL: orchestrator-state missing silver-test<br>FAIL [structural]: validate-workflow-authoring.sh<br>FAIL [catalog]: enforcement_queue missing for WF-SILVER-TEST<br>FAIL [triple_alignment]: SKILL pre-exec markers not parseable<br>FAIL [triple_alignment]: guard [] != orchestrator [context,plan]<br>FAIL [orchestrator]: composer missing from orchestrator-state.sh |
| `WF-SILVER-UI` | PASS | — |
| `WF-VALIDATE-SUBSTEP` | PASS | — |

### Atomic flows

| ID | Verdict | Failure details |
|----|---------|-----------------|
| `AF-AGENT-DELEGATE` | PASS | — |
| `AF-BLAST-RADIUS` | PASS | — |
| `AF-BOOTSTRAP` | PASS | — |
| `AF-BRANCH-FINISH` | PASS | — |
| `AF-CLARIFY` | PASS | — |
| `AF-COMPLETION-AUDIT` | PASS | — |
| `AF-DEBUG` | PASS | — |
| `AF-DECIDE` | PASS | — |
| `AF-DESIGN-CONTRACT` | PASS | — |
| `AF-DEVOPS-ROUTE` | PASS | — |
| `AF-DOCUMENT` | PASS | — |
| `AF-EXECUTE` | PASS | — |
| `AF-FAST-PATH` | PASS | — |
| `AF-ORIENT` | PASS | — |
| `AF-PHASE-MANAGE` | PASS | — |
| `AF-PLAN` | PASS | — |
| `AF-QUALITY-GATE` | PASS | — |
| `AF-RELEASE` | PASS | — |
| `AF-REVIEW` | PASS | — |
| `AF-REVIEW-REQUEST` | PASS | — |
| `AF-REVIEW-TRIAGE` | PASS | — |
| `AF-ROUTE` | PASS | — |
| `AF-SECURE` | PASS | — |
| `AF-SHIP` | PASS | — |
| `AF-SPECIFY` | PASS | — |
| `AF-UI-QUALITY` | PASS | — |
| `AF-VALIDATE` | PASS | — |
| `AF-VERIFY` | PASS | — |

### Flow steps

| ID | Verdict | Failure details |
|----|---------|-----------------|
| `FS-AI_LLM_SAFETY` | PASS | — |
| `FS-ARTIFACT_REVIEWER` | PASS | — |
| `FS-ARTIFACT_REVIEW_ASSESSOR` | PASS | — |
| `FS-DELEGATE-BRIEF` | PASS | — |
| `FS-DELEGATE-CHECKPOINT` | PASS | — |
| `FS-DELEGATE-CLAUDE-LAUNCH` | PASS | — |
| `FS-DELEGATE-CLAUDE-ROUTE` | PASS | — |
| `FS-DELEGATE-CODEX-LAUNCH` | PASS | — |
| `FS-DELEGATE-CODEX-ROUTE` | PASS | — |
| `FS-DELEGATE-CURSOR-LAUNCH` | PASS | — |
| `FS-DELEGATE-CURSOR-ROUTE` | PASS | — |
| `FS-DELEGATE-CURSOR-SUBAGENT-POLICY` | PASS | — |
| `FS-DELEGATE-GUARD_OFF` | PASS | — |
| `FS-DELEGATE-GUARD_ON` | PASS | — |
| `FS-DELEGATE-LAUNCH` | PASS | — |
| `FS-DELEGATE-MENTOR` | PASS | — |
| `FS-DELEGATE-RELAUNCH` | PASS | — |
| `FS-DELEGATE-VERIFY` | PASS | — |
| `FS-DEVOPS_QUALITY_GATES` | PASS | — |
| `FS-DEVOPS_SKILL_ROUTER` | PASS | — |
| `FS-EXTENSIBILITY` | PASS | — |
| `FS-MODULARITY` | PASS | — |
| `FS-RELIABILITY` | PASS | — |
| `FS-REUSABILITY` | PASS | — |
| `FS-REVIEW_CONTEXT` | PASS | — |
| `FS-REVIEW_CROSS_ARTIFACT` | PASS | — |
| `FS-REVIEW_DESIGN` | PASS | — |
| `FS-REVIEW_INGESTION_MANIFEST` | PASS | — |
| `FS-REVIEW_PLAN` | PASS | — |
| `FS-REVIEW_REQUIREMENTS` | PASS | — |
| `FS-REVIEW_RESEARCH` | PASS | — |
| `FS-REVIEW_ROADMAP` | PASS | — |
| `FS-REVIEW_SPEC` | PASS | — |
| `FS-REVIEW_UAT` | PASS | — |
| `FS-REVIEW_VERIFICATION` | PASS | — |
| `FS-SCALABILITY` | PASS | — |
| `FS-SECURITY` | PASS | — |
| `FS-SILVER` | PASS | — |
| `FS-SILVER_ADD` | PASS | — |
| `FS-SILVER_AGENT_CLAUDE` | **FAIL** | FAIL [composition]: not owned by any atomic flow flow_steps[] |
| `FS-SILVER_AGENT_CODEX` | **FAIL** | FAIL [composition]: not owned by any atomic flow flow_steps[] |
| `FS-SILVER_AGENT_CURSOR` | **FAIL** | FAIL [composition]: not owned by any atomic flow flow_steps[] |
| `FS-SILVER_BENCHMARK` | PASS | — |
| `FS-SILVER_BLAST_RADIUS` | PASS | — |
| `FS-SILVER_BOOTSTRAP_MILESTONE` | PASS | — |
| `FS-SILVER_BOOTSTRAP_PROJECT` | PASS | — |
| `FS-SILVER_BRANCH_FINISH` | PASS | — |
| `FS-SILVER_BUGFIX` | PASS | — |
| `FS-SILVER_CANARY` | PASS | — |
| `FS-SILVER_CLARIFY` | PASS | — |
| `FS-SILVER_COMPLETION_AUDIT` | PASS | — |
| `FS-SILVER_CONTENT` | PASS | — |
| `FS-SILVER_CONTEXT` | PASS | — |
| `FS-SILVER_CREATE_RELEASE` | PASS | — |
| `FS-SILVER_DEBUG` | PASS | — |
| `FS-SILVER_DEEP_RESEARCH` | PASS | — |
| `FS-SILVER_DEPLOY` | PASS | — |
| `FS-SILVER_DEVOPS` | PASS | — |
| `FS-SILVER_DOCTOR` | PASS | — |
| `FS-SILVER_DOMAIN_AUDIT` | PASS | — |
| `FS-SILVER_ENSURE_DOCS` | PASS | — |
| `FS-SILVER_EXECUTE` | PASS | — |
| `FS-SILVER_FAST` | PASS | — |
| `FS-SILVER_FEATURE` | PASS | — |
| `FS-SILVER_FORENSICS` | PASS | — |
| `FS-SILVER_HANDOFF` | PASS | — |
| `FS-SILVER_INCIDENT` | PASS | — |
| `FS-SILVER_INGEST` | PASS | — |
| `FS-SILVER_INIT` | PASS | — |
| `FS-SILVER_MIGRATE` | PASS | — |
| `FS-SILVER_NEW_WORKFLOW` | PASS | — |
| `FS-SILVER_ORCHESTRATOR` | PASS | — |
| `FS-SILVER_ORIENT` | PASS | — |
| `FS-SILVER_PHASE` | PASS | — |
| `FS-SILVER_PLAN` | PASS | — |
| `FS-SILVER_QUALITY_GATES` | PASS | — |
| `FS-SILVER_REFACTOR` | PASS | — |
| `FS-SILVER_RELEASE` | PASS | — |
| `FS-SILVER_REM` | PASS | — |
| `FS-SILVER_REMOVE` | PASS | — |
| `FS-SILVER_RETRO` | PASS | — |
| `FS-SILVER_REVIEW` | PASS | — |
| `FS-SILVER_REVIEW_FIX_LADDER` | PASS | — |
| `FS-SILVER_REVIEW_REQUEST` | PASS | — |
| `FS-SILVER_REVIEW_STATS` | PASS | — |
| `FS-SILVER_REVIEW_TRIAGE` | PASS | — |
| `FS-SILVER_SCAN` | PASS | — |
| `FS-SILVER_SECURE` | PASS | — |
| `FS-SILVER_SHIP` | PASS | — |
| `FS-SILVER_SPEC` | PASS | — |
| `FS-SILVER_SPIKE` | PASS | — |
| `FS-SILVER_TEST` | PASS | — |
| `FS-SILVER_THREAD` | PASS | — |
| `FS-SILVER_UI` | PASS | — |
| `FS-SILVER_UI_CONTRACT` | PASS | — |
| `FS-SILVER_UI_REVIEW` | PASS | — |
| `FS-SILVER_UNDO` | PASS | — |
| `FS-SILVER_UPDATE` | PASS | — |
| `FS-SILVER_VALIDATE` | PASS | — |
| `FS-SILVER_VERIFY` | PASS | — |
| `FS-SILVER_WORKTREE` | PASS | — |
| `FS-TDD` | PASS | — |
| `FS-TESTABILITY` | PASS | — |
| `FS-USABILITY` | PASS | — |
| `FS-VERIFY_TESTS` | PASS | — |

## Batch artifacts

- Per-entity logs: [`.planning/reviews/audit-batch/`](../reviews/audit-batch/)
- Machine summary: [`.planning/reviews/audit-batch/summary.json`](../reviews/audit-batch/summary.json)

## References

- [`docs/APO-AUTHORING-COMPLIANCE.md`](../docs/APO-AUTHORING-COMPLIANCE.md)
- [`docs/apo-catalog.json`](../docs/apo-catalog.json)
- [`skills/silver-new-workflow/SKILL.md`](../skills/silver-new-workflow/SKILL.md) — Audit mode

## Re-audit 2026-07-05

Re-ran `scripts/audit-workflow-compliance.sh --target` for the 10 workflows that failed in the original full catalog audit (post-remediation commit [26edd496](https://github.com/alo-exp/silver-bullet/commit/26edd496)).

Also re-ran `scripts/audit-atomic-flow-compliance.sh --target` for P2 delegate agent flow steps.

| Entity | VERDICT | Notes |
|--------|---------|-------|
| WF-SILVER-ROUTER | PASS | AF-ROUTE / VL-AF-ROUTE |
| WF-SILVER-BENCHMARK | PASS | AF-FAST-PATH |
| WF-SILVER-CANARY | PASS | AF-SHIP |
| WF-SILVER-CONTENT | PASS | AF-DOCUMENT |
| WF-SILVER-DEPLOY | PASS | AF-SHIP |
| WF-SILVER-FORENSICS | PASS | AF-DEBUG |
| WF-SILVER-INCIDENT | PASS | AF-FAST-PATH |
| WF-SILVER-REFACTOR | PASS | AF-EXECUTE |
| WF-SILVER-RETRO | PASS | AF-DOCUMENT |
| WF-SILVER-TEST | PASS | AF-VERIFY |
| FS-SILVER_AGENT_CLAUDE | PASS | VL-FS-SILVER_AGENT_CLAUDE |
| FS-SILVER_AGENT_CODEX | PASS | VL-FS-SILVER_AGENT_CODEX |
| FS-SILVER_AGENT_CURSOR | PASS | VL-FS-SILVER_AGENT_CURSOR |

**Summary:** **10/10** previously failing workflows **PASS**. **3/3** P2 agent flow steps **PASS**. No failures; no remediation required on branch `wf-af-audit` at HEAD `26edd496`.

