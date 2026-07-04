# Composable Flows - Generated Contract Reference

> Generated from `docs/apo-catalog.json` by `scripts/generate-apo-artifacts.py`.
> Do not hand-edit workflow composition here; the catalog is the sole authority.

## APO Hierarchy

Silver Bullet owns the default software-engineering lifecycle across routing, context, planning, execution, review, verification, security, shipping, release, and documentation.
Silver Bullet models delivery as `Process > Workflow > Atomic Flow > Flow Step/Skill`.
Workflow nesting is represented only by `workflow.composition_tree` references in the catalog.
Every atomic flow is one subagent work package with a local V-loop; every flow step has its own V-loop that rolls up into the parent flow gate.

## Legacy FLOW Compatibility

Legacy FLOW 1-18 labels are migration aliases only; canonical execution uses AF-* entities and reusable workflow components from the catalog.

| Legacy FLOW | Canonical Capability | Catalog Entity |
|-------------|----------------------|----------------|
| FLOW 1 | BOOTSTRAP | `AF-BOOTSTRAP` |
| FLOW 2 | ORIENT | `AF-ORIENT` |
| FLOW 3 | CLARIFY | `AF-CLARIFY` |
| FLOW 4 | DECIDE | `AF-DECIDE` |
| FLOW 5 | SPECIFY | `AF-SPECIFY` |
| FLOW 6 | PLAN | `AF-PLAN` |
| FLOW 7 | DESIGN CONTRACT | `AF-DESIGN-CONTRACT` |
| FLOW 8 | EXECUTE | `AF-EXECUTE` |
| FLOW 9 | UI QUALITY | `AF-UI-QUALITY` |
| FLOW 10 | REVIEW | `WF-REVIEW-TRIAD` |
| FLOW 11 | SECURE | `AF-SECURE` |
| FLOW 12 | VERIFY | `AF-VERIFY` |
| FLOW 13 | QUALITY GATE | `AF-QUALITY-GATE` |
| FLOW 14 | SHIP | `WF-SHIP-READINESS` |
| FLOW 15 | DEBUG | `AF-DEBUG` |
| FLOW 16 | DESIGN HANDOFF | `AF-DOCUMENT` |
| FLOW 17 | DOCUMENT | `AF-DOCUMENT` |
| FLOW 18 | RELEASE | `AF-RELEASE` |

Ship readiness composes `silver:branch-finish` before `silver:completion-audit` before `silver:ship`.
Release audit artifacts remain `RELEASE-UAT-AUDIT` for FLOW 12 verification and `RELEASE-MILESTONE-AUDIT` for FLOW 18 release readiness.

## Post-execution sequencing

Flow numbers are stable identifiers — not always runtime order. For `silver:feature`, `silver:ui`, `silver:devops`, and `silver:bugfix`, the mandatory post-execute order is:

1. FLOW 9 (UI QUALITY) — always for `silver:ui`; for `silver:feature` only when UI scope is detected
2. FLOW 10 (REVIEW triad: `silver:review-request` → `silver:review` → `silver:review-triage`)
3. FLOW 12 (VERIFY: `silver:verify` + `verify-tests`)
4. FLOW 11 (SECURE: `security` + `silver:secure`, with `silver:validate` as needed)
5. FLOW 13 (QUALITY GATE, pre-ship)
6. FLOW 14 (SHIP: `silver:branch-finish` → `silver:completion-audit` → `silver:ship`)

## Atomic Flow Catalog

| Atomic Flow | Capability Class | Worker Template | Primary Skills |
|-------------|------------------|-----------------|----------------|
| `AF-ROUTE` | route_intent | `templates/orchestrator-workers/ROUTER.md` | `silver`, `silver-orchestrator` |
| `AF-BOOTSTRAP` | project_bootstrap | `templates/orchestrator-workers/BOOTSTRAP.md` | `silver-bootstrap-milestone`, `silver-bootstrap-project`, `silver-init` |
| `AF-ORIENT` | context_orientation | `templates/orchestrator-workers/ORIENT.md` | `silver-context`, `silver-orient`, `silver-review-stats`, `silver-scan` |
| `AF-CLARIFY` | scope_clarification | `templates/orchestrator-workers/CLARIFY.md` | `silver-clarify` |
| `AF-DECIDE` | decision_research | `templates/orchestrator-workers/DECIDE.md` | `review-research`, `silver-multi-ai`, `silver-research` |
| `AF-SPECIFY` | requirements_specification | `templates/orchestrator-workers/SPECIFY.md` | `review-ingestion-manifest`, `review-requirements`, `review-spec`, `silver-ingest` |
| `AF-PLAN` | execution_planning | `templates/orchestrator-workers/PLAN.md` | `review-context`, `review-plan`, `silver-plan` |
| `AF-DESIGN-CONTRACT` | design_contract | `templates/orchestrator-workers/DESIGN-CONTRACT.md` | `review-design`, `silver-ui-contract` |
| `AF-EXECUTE` | implementation_execution | `templates/orchestrator-workers/EXECUTE.md` | `silver-execute`, `silver-refactor`, `silver-spike`, `silver-worktree` |
| `AF-UI-QUALITY` | ui_quality_review | `templates/orchestrator-workers/UI-QUALITY.md` | `silver-ui`, `silver-ui-review`, `usability` |
| `AF-REVIEW-REQUEST` | review_request | `templates/orchestrator-workers/REVIEW-REQUEST.md` | `silver-review-request` |
| `AF-REVIEW` | artifact_and_code_review | `templates/orchestrator-workers/REVIEW.md` | `artifact-reviewer`, `artifact-review-assessor`, `review-cross-artifact`, `review-roadmap` |
| `AF-REVIEW-TRIAGE` | review_triage_and_fix | `templates/orchestrator-workers/REVIEW-TRIAGE.md` | `silver-review-fix-ladder`, `silver-review-triage` |
| `AF-VERIFY` | verification_and_testing | `templates/orchestrator-workers/VERIFY.md` | `review-verification`, `silver-test`, `silver-verify`, `testability` |
| `AF-SECURE` | security_and_llm_safety | `templates/orchestrator-workers/SECURE.md` | `ai-llm-safety`, `security`, `silver-secure` |
| `AF-QUALITY-GATE` | cross_cutting_quality_gate | `templates/orchestrator-workers/QUALITY-GATE.md` | `devops-quality-gates`, `extensibility`, `modularity`, `reliability` |
| `AF-SHIP` | ship_readiness | `templates/orchestrator-workers/SHIP.md` | `silver-canary`, `silver-deploy`, `silver-ship` |
| `AF-BRANCH-FINISH` | branch_hygiene | `templates/orchestrator-workers/BRANCH-FINISH.md` | `silver-branch-finish` |
| `AF-COMPLETION-AUDIT` | completion_audit | `templates/orchestrator-workers/COMPLETION-AUDIT.md` | `silver-completion-audit` |
| `AF-DEBUG` | failure_diagnosis | `templates/orchestrator-workers/DEBUG.md` | `silver-bugfix`, `silver-debug`, `silver-forensics` |
| `AF-DOCUMENT` | durable_documentation | `templates/orchestrator-workers/DOCUMENT.md` | `silver-content`, `silver-ensure-docs`, `silver-handoff`, `silver-retro` |
| `AF-RELEASE` | release_management | `templates/orchestrator-workers/RELEASE.md` | `silver-create-release`, `silver-release` |
| `AF-BLAST-RADIUS` | blast_radius_assessment | `templates/orchestrator-workers/BLAST-RADIUS.md` | `silver-blast-radius` |
| `AF-DEVOPS-ROUTE` | devops_toolchain_routing | `templates/orchestrator-workers/DEVOPS-SKILL-ROUTER.md` | `devops-skill-router`, `silver-devops` |
| `AF-VALIDATE` | gap_validation | `templates/orchestrator-workers/VALIDATE.md` | `silver-validate` |
| `AF-PHASE-MANAGE` | phase_and_state_management | `templates/orchestrator-workers/PHASE.md` | `silver-add`, `silver-doctor`, `silver-migrate`, `silver-phase` |
| `AF-FAST-PATH` | bounded_fast_path | `templates/orchestrator-workers/FAST.md` | `silver-benchmark`, `silver-fast`, `silver-feature`, `silver-incident` |
| `AF-AGENT-DELEGATE` | external_agent_delegation | `templates/orchestrator-workers/AGENT-DELEGATE.md` | `silver-agent-codex`, `silver-agent-cursor` |

## Skill-Dispatched Worker Templates

Some queue atoms override the default worker template for their atomic flow.
Runtime resolution: `hooks/lib/orchestrator-parent.sh` → project copy under `.silver-bullet/orchestrator-workers/`, then plugin mirror.

| Atomic Flow | Queue Atom / Skill | Alternate Worker Template |
|-------------|--------------------|---------------------------|
| `AF-SECURE` | `security` | `templates/orchestrator-workers/SECURITY.md` |
| `AF-DOCUMENT` | `FLOW-DESIGN-HANDOFF` | `templates/orchestrator-workers/DESIGN-HANDOFF.md` |
| `AF-DOCUMENT` | `silver-handoff` | `templates/orchestrator-workers/DESIGN-HANDOFF.md` |

## Workflow Composition

### `WF-SILVER-ROUTER`

- Slug: `silver-router`
- Type: `dynamic_route`
- Final intent gate: `INTENT-GATE-DEFAULT`

- atomic_flow: `AF-ROUTE`
- workflow: `WF-SILVER-FEATURE` optional
- workflow: `WF-SILVER-FAST` optional

### `WF-SILVER-FEATURE`

- Slug: `silver-feature`
- Type: `precomposed`
- Final intent gate: `INTENT-GATE-DEFAULT`

- atomic_flow: `AF-BOOTSTRAP` optional
- atomic_flow: `AF-ORIENT` optional
- atomic_flow: `AF-CLARIFY` optional
- atomic_flow: `AF-DECIDE` optional
- atomic_flow: `AF-SPECIFY` optional
- atomic_flow: `AF-QUALITY-GATE` (pre-plan)
- atomic_flow: `AF-PLAN`
- atomic_flow: `AF-DESIGN-CONTRACT` optional when ui_scope
- atomic_flow: `AF-EXECUTE`
- workflow: `WF-POST-EXEC-GATES`

### `WF-POST-EXEC-GATES`

- Slug: `post-exec-gates`
- Type: `reusable_component`
- Final intent gate: `INTENT-GATE-DEFAULT`

- atomic_flow: `AF-UI-QUALITY` optional when ui_scope
- atomic_flow: `AF-REVIEW-REQUEST`
- atomic_flow: `AF-REVIEW`
- atomic_flow: `AF-REVIEW-TRIAGE`
- atomic_flow: `AF-VERIFY`
- atomic_flow: `AF-SECURE`
- atomic_flow: `AF-VALIDATE` optional
- atomic_flow: `AF-QUALITY-GATE` (pre-ship)
- atomic_flow: `AF-BRANCH-FINISH`
- atomic_flow: `AF-COMPLETION-AUDIT`
- atomic_flow: `AF-SHIP`

### `WF-VALIDATE-SUBSTEP`

- Slug: `validate-substep`
- Type: `reusable_component`
- Final intent gate: `INTENT-GATE-DEFAULT`

- atomic_flow: `AF-VALIDATE`

### `WF-REVIEW-TRIAD`

- Slug: `review-triad`
- Type: `reusable_component`
- Final intent gate: `INTENT-GATE-DEFAULT`

- atomic_flow: `AF-REVIEW-REQUEST`
- atomic_flow: `AF-REVIEW`
- atomic_flow: `AF-REVIEW-TRIAGE`

### `WF-SHIP-READINESS`

- Slug: `ship-readiness`
- Type: `reusable_component`
- Final intent gate: `INTENT-GATE-DEFAULT`

- atomic_flow: `AF-BRANCH-FINISH`
- atomic_flow: `AF-COMPLETION-AUDIT`
- atomic_flow: `AF-SHIP`

### `WF-SILVER-UI`

- Slug: `silver-ui`
- Type: `precomposed`
- Final intent gate: `INTENT-GATE-DEFAULT`

- atomic_flow: `AF-BOOTSTRAP` optional
- atomic_flow: `AF-ORIENT` optional
- atomic_flow: `AF-CLARIFY` optional
- atomic_flow: `AF-DECIDE` optional
- atomic_flow: `AF-SPECIFY` optional
- atomic_flow: `AF-QUALITY-GATE` (pre-plan)
- atomic_flow: `AF-PLAN`
- atomic_flow: `AF-DESIGN-CONTRACT`
- atomic_flow: `AF-EXECUTE`
- workflow: `WF-POST-EXEC-GATES`

### `WF-SILVER-DEVOPS`

- Slug: `silver-devops`
- Type: `precomposed`
- Final intent gate: `INTENT-GATE-DEFAULT`

- atomic_flow: `AF-BLAST-RADIUS`
- atomic_flow: `AF-DEVOPS-ROUTE`
- atomic_flow: `AF-QUALITY-GATE`
- atomic_flow: `AF-SECURE`
- atomic_flow: `AF-ORIENT`
- atomic_flow: `AF-PLAN`
- atomic_flow: `AF-VALIDATE`
- atomic_flow: `AF-EXECUTE`
- workflow: `WF-POST-EXEC-GATES`

### `WF-SILVER-BUGFIX`

- Slug: `silver-bugfix`
- Type: `precomposed`
- Final intent gate: `INTENT-GATE-DEFAULT`

- atomic_flow: `AF-ORIENT` optional
- atomic_flow: `AF-DEBUG`
- atomic_flow: `AF-PLAN`
- atomic_flow: `AF-EXECUTE`
- workflow: `WF-POST-EXEC-GATES`

### `WF-SILVER-RESEARCH`

- Slug: `silver-research`
- Type: `precomposed`
- Final intent gate: `INTENT-GATE-DEFAULT`

- atomic_flow: `AF-CLARIFY`
- atomic_flow: `AF-DECIDE`
- atomic_flow: `AF-DOCUMENT`
- atomic_flow: `AF-VALIDATE`

### `WF-SILVER-FAST`

- Slug: `silver-fast`
- Type: `precomposed`
- Final intent gate: `INTENT-GATE-DEFAULT`

- atomic_flow: `AF-FAST-PATH`
- atomic_flow: `AF-QUALITY-GATE`
- atomic_flow: `AF-PLAN`
- atomic_flow: `AF-VALIDATE`
- atomic_flow: `AF-EXECUTE`
- atomic_flow: `AF-VERIFY`

### `WF-SILVER-RELEASE`

- Slug: `silver-release`
- Type: `precomposed`
- Final intent gate: `INTENT-GATE-DEFAULT`

- atomic_flow: `AF-QUALITY-GATE`
- atomic_flow: `AF-REVIEW-REQUEST`
- atomic_flow: `AF-REVIEW`
- atomic_flow: `AF-REVIEW-TRIAGE`
- atomic_flow: `AF-VERIFY`
- atomic_flow: `AF-SECURE`
- atomic_flow: `AF-VALIDATE`
- atomic_flow: `AF-BRANCH-FINISH`
- atomic_flow: `AF-COMPLETION-AUDIT`
- atomic_flow: `AF-SHIP`
- atomic_flow: `AF-RELEASE`

### `WF-SILVER-DEPLOY`

- Slug: `silver-deploy`
- Type: `specialized`
- Final intent gate: `INTENT-GATE-DEFAULT`

- atomic_flow: `AF-BLAST-RADIUS`
- atomic_flow: `AF-VERIFY`
- atomic_flow: `AF-SECURE`
- atomic_flow: `AF-SHIP`

### `WF-SILVER-CANARY`

- Slug: `silver-canary`
- Type: `specialized`
- Final intent gate: `INTENT-GATE-DEFAULT`

- atomic_flow: `AF-BLAST-RADIUS`
- atomic_flow: `AF-VERIFY`
- atomic_flow: `AF-SHIP`

### `WF-SILVER-INCIDENT`

- Slug: `silver-incident`
- Type: `specialized`
- Final intent gate: `INTENT-GATE-DEFAULT`

- atomic_flow: `AF-BLAST-RADIUS`
- atomic_flow: `AF-DEBUG`
- atomic_flow: `AF-SECURE`
- atomic_flow: `AF-VERIFY`
- atomic_flow: `AF-DOCUMENT`

### `WF-SILVER-CONTENT`

- Slug: `silver-content`
- Type: `specialized`
- Final intent gate: `INTENT-GATE-DEFAULT`

- atomic_flow: `AF-CLARIFY`
- atomic_flow: `AF-SPECIFY`
- atomic_flow: `AF-EXECUTE`
- atomic_flow: `AF-VERIFY`
- atomic_flow: `AF-DOCUMENT`

### `WF-SILVER-RETRO`

- Slug: `silver-retro`
- Type: `specialized`
- Final intent gate: `INTENT-GATE-DEFAULT`

- atomic_flow: `AF-ORIENT`
- atomic_flow: `AF-DOCUMENT`
- atomic_flow: `AF-DECIDE`

### `WF-SILVER-BENCHMARK`

- Slug: `silver-benchmark`
- Type: `specialized`
- Final intent gate: `INTENT-GATE-DEFAULT`

- atomic_flow: `AF-ORIENT`
- atomic_flow: `AF-EXECUTE`
- atomic_flow: `AF-VERIFY`
- atomic_flow: `AF-DOCUMENT`

### `WF-SILVER-REFACTOR`

- Slug: `silver-refactor`
- Type: `specialized`
- Final intent gate: `INTENT-GATE-DEFAULT`

- atomic_flow: `AF-PLAN`
- atomic_flow: `AF-EXECUTE`
- atomic_flow: `AF-VERIFY`
- workflow: `WF-POST-EXEC-GATES`

### `WF-SILVER-TEST`

- Slug: `silver-test`
- Type: `specialized`
- Final intent gate: `INTENT-GATE-DEFAULT`

- atomic_flow: `AF-PLAN`
- atomic_flow: `AF-EXECUTE`
- atomic_flow: `AF-VERIFY`

### `WF-SILVER-FORENSICS`

- Slug: `silver-forensics`
- Type: `specialized`
- Final intent gate: `INTENT-GATE-DEFAULT`

- atomic_flow: `AF-DEBUG`
- atomic_flow: `AF-DOCUMENT`
- atomic_flow: `AF-VALIDATE`

### `WF-PROCESS-MAINTENANCE`

- Slug: `process-maintenance`
- Type: `specialized`
- Final intent gate: `INTENT-GATE-DEFAULT`

- atomic_flow: `AF-PHASE-MANAGE`
- atomic_flow: `AF-DOCUMENT`
- atomic_flow: `AF-VALIDATE`

### `WF-AGENT-DELEGATE-ENTRY`

- Slug: `agent-delegate-entry`
- Type: `specialized`
- Final intent gate: `INTENT-GATE-DEFAULT`

- atomic_flow: `AF-AGENT-DELEGATE`

## Runtime Queue Tokens

| Runtime Token | Catalog Entity |
|---------------|----------------|
| `FLOW-DESIGN-HANDOFF` | `AF-DOCUMENT` |
| `FLOW-DEVOPS-QUALITY-GATE-PRESHIP` | `AF-QUALITY-GATE` |
| `FLOW-DOCUMENT` | `AF-DOCUMENT` |
| `FLOW-QUALITY-GATE` | `AF-QUALITY-GATE` |
| `FLOW-QUALITY-GATE-PRESHIP` | `AF-QUALITY-GATE` |
| `ROUTER` | `AF-ROUTE` |
| `devops-quality-gates` | `AF-QUALITY-GATE` |
| `devops-skill-router` | `AF-DEVOPS-ROUTE` |
| `security` | `AF-SECURE` |
| `silver-blast-radius` | `AF-BLAST-RADIUS` |
| `silver-branch-finish` | `AF-BRANCH-FINISH` |
| `silver-clarify` | `AF-CLARIFY` |
| `silver-completion-audit` | `AF-COMPLETION-AUDIT` |
| `silver-context` | `AF-ORIENT` |
| `silver-create-release` | `AF-RELEASE` |
| `silver-debug` | `AF-DEBUG` |
| `silver-ensure-docs` | `AF-DOCUMENT` |
| `silver-execute` | `AF-EXECUTE` |
| `silver-handoff` | `AF-DOCUMENT` |
| `silver-plan` | `AF-PLAN` |
| `silver-quality-gates` | `AF-QUALITY-GATE` |
| `silver-research` | `AF-DECIDE` |
| `silver-review` | `AF-REVIEW` |
| `silver-review-request` | `AF-REVIEW-REQUEST` |
| `silver-review-triage` | `AF-REVIEW-TRIAGE` |
| `silver-secure` | `AF-SECURE` |
| `silver-ship` | `AF-SHIP` |
| `silver-spec` | `AF-SPECIFY` |
| `silver-ui-contract` | `AF-DESIGN-CONTRACT` |
| `silver-ui-review` | `AF-UI-QUALITY` |
| `silver-validate` | `AF-VALIDATE` |
| `silver-verify` | `AF-VERIFY` |

## Flow Step V-Loops

| Flow Step | Skill | Reusable By | Evidence |
|-----------|-------|-------------|----------|
| `FS-AI_LLM_SAFETY` | `ai-llm-safety` | `AF-SECURE` | `EV-FS-AI_LLM_SAFETY` |
| `FS-ARTIFACT_REVIEWER` | `artifact-reviewer` | `AF-REVIEW` | `EV-FS-ARTIFACT_REVIEWER` |
| `FS-ARTIFACT_REVIEW_ASSESSOR` | `artifact-review-assessor` | `AF-REVIEW` | `EV-FS-ARTIFACT_REVIEW_ASSESSOR` |
| `FS-DELEGATE-BRIEF` | `silver-agent-codex|silver-agent-cursor` | `AF-AGENT-DELEGATE` | `EV-FS-DELEGATE-BRIEF` |
| `FS-DELEGATE-CHECKPOINT` | `distribution-only` | `AF-AGENT-DELEGATE` | `EV-FS-DELEGATE-CHECKPOINT` |
| `FS-DELEGATE-CODEX-LAUNCH` | `silver-agent-codex` | `AF-AGENT-DELEGATE` | `EV-FS-DELEGATE-LAUNCH` |
| `FS-DELEGATE-CODEX-ROUTE` | `silver-agent-codex` | `AF-AGENT-DELEGATE` | `EV-FS-DELEGATE-LAUNCH` |
| `FS-DELEGATE-CURSOR-LAUNCH` | `silver-agent-cursor` | `AF-AGENT-DELEGATE` | `EV-FS-DELEGATE-LAUNCH` |
| `FS-DELEGATE-CURSOR-ROUTE` | `silver-agent-cursor` | `AF-AGENT-DELEGATE` | `EV-FS-DELEGATE-LAUNCH` |
| `FS-DELEGATE-CURSOR-SUBAGENT-POLICY` | `silver-agent-cursor` | `AF-AGENT-DELEGATE` | `EV-FS-DELEGATE-LAUNCH` |
| `FS-DELEGATE-GUARD_OFF` | `distribution-only` | `AF-AGENT-DELEGATE` | `EV-FS-DELEGATE-GUARD_OFF` |
| `FS-DELEGATE-GUARD_ON` | `distribution-only` | `AF-AGENT-DELEGATE` | `EV-FS-DELEGATE-GUARD_ON` |
| `FS-DELEGATE-LAUNCH` | `silver-agent-worker` | `AF-AGENT-DELEGATE` | `EV-FS-DELEGATE-LAUNCH` |
| `FS-DELEGATE-MENTOR` | `silver-agent-codex|silver-agent-cursor` | `AF-AGENT-DELEGATE` | `EV-FS-DELEGATE-MENTOR` |
| `FS-DELEGATE-RELAUNCH` | `silver-agent-worker` | `AF-AGENT-DELEGATE` | `EV-FS-DELEGATE-RELAUNCH` |
| `FS-DELEGATE-VERIFY` | `distribution-only` | `AF-AGENT-DELEGATE` | `EV-FS-DELEGATE-VERIFY` |
| `FS-DEVOPS_QUALITY_GATES` | `devops-quality-gates` | `AF-QUALITY-GATE` | `EV-FS-DEVOPS_QUALITY_GATES` |
| `FS-DEVOPS_SKILL_ROUTER` | `devops-skill-router` | `AF-DEVOPS-ROUTE` | `EV-FS-DEVOPS_SKILL_ROUTER` |
| `FS-EXTENSIBILITY` | `extensibility` | `AF-QUALITY-GATE` | `EV-FS-EXTENSIBILITY` |
| `FS-MODULARITY` | `modularity` | `AF-QUALITY-GATE` | `EV-FS-MODULARITY` |
| `FS-RELIABILITY` | `reliability` | `AF-QUALITY-GATE` | `EV-FS-RELIABILITY` |
| `FS-REUSABILITY` | `reusability` | `AF-QUALITY-GATE` | `EV-FS-REUSABILITY` |
| `FS-REVIEW_CONTEXT` | `review-context` | `AF-PLAN` | `EV-FS-REVIEW_CONTEXT` |
| `FS-REVIEW_CROSS_ARTIFACT` | `review-cross-artifact` | `AF-REVIEW` | `EV-FS-REVIEW_CROSS_ARTIFACT` |
| `FS-REVIEW_DESIGN` | `review-design` | `AF-DESIGN-CONTRACT` | `EV-FS-REVIEW_DESIGN` |
| `FS-REVIEW_INGESTION_MANIFEST` | `review-ingestion-manifest` | `AF-SPECIFY` | `EV-FS-REVIEW_INGESTION_MANIFEST` |
| `FS-REVIEW_PLAN` | `review-plan` | `AF-PLAN` | `EV-FS-REVIEW_PLAN` |
| `FS-REVIEW_REQUIREMENTS` | `review-requirements` | `AF-SPECIFY` | `EV-FS-REVIEW_REQUIREMENTS` |
| `FS-REVIEW_RESEARCH` | `review-research` | `AF-DECIDE` | `EV-FS-REVIEW_RESEARCH` |
| `FS-REVIEW_ROADMAP` | `review-roadmap` | `AF-REVIEW` | `EV-FS-REVIEW_ROADMAP` |
| `FS-REVIEW_SPEC` | `review-spec` | `AF-SPECIFY` | `EV-FS-REVIEW_SPEC` |
| `FS-REVIEW_UAT` | `review-uat` | `AF-REVIEW` | `EV-FS-REVIEW_UAT` |
| `FS-REVIEW_VERIFICATION` | `review-verification` | `AF-VERIFY` | `EV-FS-REVIEW_VERIFICATION` |
| `FS-SCALABILITY` | `scalability` | `AF-QUALITY-GATE` | `EV-FS-SCALABILITY` |
| `FS-SECURITY` | `security` | `AF-SECURE` | `EV-FS-SECURITY` |
| `FS-SILVER` | `silver` | `AF-ROUTE` | `EV-FS-SILVER` |
| `FS-SILVER_ADD` | `silver-add` | `AF-PHASE-MANAGE` | `EV-FS-SILVER_ADD` |
| `FS-SILVER_AGENT_CODEX` | `silver-agent-codex` | `AF-AGENT-DELEGATE` | `EV-FS-SILVER_AGENT_CODEX` |
| `FS-SILVER_AGENT_CURSOR` | `silver-agent-cursor` | `AF-AGENT-DELEGATE` | `EV-FS-SILVER_AGENT_CURSOR` |
| `FS-SILVER_BENCHMARK` | `silver-benchmark` | `AF-FAST-PATH` | `EV-FS-SILVER_BENCHMARK` |
| `FS-SILVER_BLAST_RADIUS` | `silver-blast-radius` | `AF-BLAST-RADIUS` | `EV-FS-SILVER_BLAST_RADIUS` |
| `FS-SILVER_BOOTSTRAP_MILESTONE` | `silver-bootstrap-milestone` | `AF-BOOTSTRAP` | `EV-FS-SILVER_BOOTSTRAP_MILESTONE` |
| `FS-SILVER_BOOTSTRAP_PROJECT` | `silver-bootstrap-project` | `AF-BOOTSTRAP` | `EV-FS-SILVER_BOOTSTRAP_PROJECT` |
| `FS-SILVER_BRANCH_FINISH` | `silver-branch-finish` | `AF-BRANCH-FINISH` | `EV-FS-SILVER_BRANCH_FINISH` |
| `FS-SILVER_BUGFIX` | `silver-bugfix` | `AF-DEBUG` | `EV-FS-SILVER_BUGFIX` |
| `FS-SILVER_CANARY` | `silver-canary` | `AF-SHIP` | `EV-FS-SILVER_CANARY` |
| `FS-SILVER_CLARIFY` | `silver-clarify` | `AF-CLARIFY` | `EV-FS-SILVER_CLARIFY` |
| `FS-SILVER_COMPLETION_AUDIT` | `silver-completion-audit` | `AF-COMPLETION-AUDIT` | `EV-FS-SILVER_COMPLETION_AUDIT` |
| `FS-SILVER_CONTENT` | `silver-content` | `AF-DOCUMENT` | `EV-FS-SILVER_CONTENT` |
| `FS-SILVER_CONTEXT` | `silver-context` | `AF-ORIENT` | `EV-FS-SILVER_CONTEXT` |
| `FS-SILVER_CREATE_RELEASE` | `silver-create-release` | `AF-RELEASE` | `EV-FS-SILVER_CREATE_RELEASE` |
| `FS-SILVER_DEBUG` | `silver-debug` | `AF-DEBUG` | `EV-FS-SILVER_DEBUG` |
| `FS-SILVER_DEPLOY` | `silver-deploy` | `AF-SHIP` | `EV-FS-SILVER_DEPLOY` |
| `FS-SILVER_DEVOPS` | `silver-devops` | `AF-DEVOPS-ROUTE` | `EV-FS-SILVER_DEVOPS` |
| `FS-SILVER_DOCTOR` | `silver-doctor` | `AF-PHASE-MANAGE` | `EV-FS-SILVER_DOCTOR` |
| `FS-SILVER_DOMAIN_AUDIT` | `silver-domain-audit` | `AF-REVIEW` | `EV-FS-SILVER_DOMAIN_AUDIT` |
| `FS-SILVER_ENSURE_DOCS` | `silver-ensure-docs` | `AF-DOCUMENT` | `EV-FS-SILVER_ENSURE_DOCS` |
| `FS-SILVER_EXECUTE` | `silver-execute` | `AF-EXECUTE` | `EV-FS-SILVER_EXECUTE` |
| `FS-SILVER_FAST` | `silver-fast` | `AF-FAST-PATH` | `EV-FS-SILVER_FAST` |
| `FS-SILVER_FEATURE` | `silver-feature` | `AF-FAST-PATH` | `EV-FS-SILVER_FEATURE` |
| `FS-SILVER_FORENSICS` | `silver-forensics` | `AF-DEBUG` | `EV-FS-SILVER_FORENSICS` |
| `FS-SILVER_HANDOFF` | `silver-handoff` | `AF-DOCUMENT` | `EV-FS-SILVER_HANDOFF` |
| `FS-SILVER_INCIDENT` | `silver-incident` | `AF-FAST-PATH` | `EV-FS-SILVER_INCIDENT` |
| `FS-SILVER_INGEST` | `silver-ingest` | `AF-SPECIFY` | `EV-FS-SILVER_INGEST` |
| `FS-SILVER_INIT` | `silver-init` | `AF-BOOTSTRAP` | `EV-FS-SILVER_INIT` |
| `FS-SILVER_MIGRATE` | `silver-migrate` | `AF-PHASE-MANAGE` | `EV-FS-SILVER_MIGRATE` |
| `FS-SILVER_MULTI_AI` | `silver-multi-ai` | `AF-DECIDE` | `EV-FS-SILVER_MULTI_AI` |
| `FS-SILVER_ORCHESTRATOR` | `silver-orchestrator` | `AF-ROUTE` | `EV-FS-SILVER_ORCHESTRATOR` |
| `FS-SILVER_ORIENT` | `silver-orient` | `AF-ORIENT` | `EV-FS-SILVER_ORIENT` |
| `FS-SILVER_PHASE` | `silver-phase` | `AF-PHASE-MANAGE` | `EV-FS-SILVER_PHASE` |
| `FS-SILVER_PLAN` | `silver-plan` | `AF-PLAN` | `EV-FS-SILVER_PLAN` |
| `FS-SILVER_QUALITY_GATES` | `silver-quality-gates` | `AF-QUALITY-GATE` | `EV-FS-SILVER_QUALITY_GATES` |
| `FS-SILVER_REFACTOR` | `silver-refactor` | `AF-EXECUTE` | `EV-FS-SILVER_REFACTOR` |
| `FS-SILVER_RELEASE` | `silver-release` | `AF-RELEASE` | `EV-FS-SILVER_RELEASE` |
| `FS-SILVER_REM` | `silver-rem` | `AF-PHASE-MANAGE` | `EV-FS-SILVER_REM` |
| `FS-SILVER_REMOVE` | `silver-remove` | `AF-PHASE-MANAGE` | `EV-FS-SILVER_REMOVE` |
| `FS-SILVER_RESEARCH` | `silver-research` | `AF-DECIDE` | `EV-FS-SILVER_RESEARCH` |
| `FS-SILVER_RETRO` | `silver-retro` | `AF-DOCUMENT` | `EV-FS-SILVER_RETRO` |
| `FS-SILVER_REVIEW` | `silver-review` | `AF-REVIEW` | `EV-FS-SILVER_REVIEW` |
| `FS-SILVER_REVIEW_FIX_LADDER` | `silver-review-fix-ladder` | `AF-REVIEW-TRIAGE` | `EV-FS-SILVER_REVIEW_FIX_LADDER` |
| `FS-SILVER_REVIEW_REQUEST` | `silver-review-request` | `AF-REVIEW-REQUEST` | `EV-FS-SILVER_REVIEW_REQUEST` |
| `FS-SILVER_REVIEW_STATS` | `silver-review-stats` | `AF-ORIENT` | `EV-FS-SILVER_REVIEW_STATS` |
| `FS-SILVER_REVIEW_TRIAGE` | `silver-review-triage` | `AF-REVIEW-TRIAGE` | `EV-FS-SILVER_REVIEW_TRIAGE` |
| `FS-SILVER_SCAN` | `silver-scan` | `AF-ORIENT` | `EV-FS-SILVER_SCAN` |
| `FS-SILVER_SECURE` | `silver-secure` | `AF-SECURE` | `EV-FS-SILVER_SECURE` |
| `FS-SILVER_SHIP` | `silver-ship` | `AF-SHIP` | `EV-FS-SILVER_SHIP` |
| `FS-SILVER_SPEC` | `silver-spec` | `AF-SPECIFY` | `EV-FS-SILVER_SPEC` |
| `FS-SILVER_SPIKE` | `silver-spike` | `AF-EXECUTE` | `EV-FS-SILVER_SPIKE` |
| `FS-SILVER_TEST` | `silver-test` | `AF-VERIFY` | `EV-FS-SILVER_TEST` |
| `FS-SILVER_THREAD` | `silver-thread` | `AF-PHASE-MANAGE` | `EV-FS-SILVER_THREAD` |
| `FS-SILVER_UI` | `silver-ui` | `AF-UI-QUALITY` | `EV-FS-SILVER_UI` |
| `FS-SILVER_UI_CONTRACT` | `silver-ui-contract` | `AF-DESIGN-CONTRACT` | `EV-FS-SILVER_UI_CONTRACT` |
| `FS-SILVER_UI_REVIEW` | `silver-ui-review` | `AF-UI-QUALITY` | `EV-FS-SILVER_UI_REVIEW` |
| `FS-SILVER_UNDO` | `silver-undo` | `AF-PHASE-MANAGE` | `EV-FS-SILVER_UNDO` |
| `FS-SILVER_UPDATE` | `silver-update` | `AF-PHASE-MANAGE` | `EV-FS-SILVER_UPDATE` |
| `FS-SILVER_VALIDATE` | `silver-validate` | `AF-VALIDATE` | `EV-FS-SILVER_VALIDATE` |
| `FS-SILVER_VERIFY` | `silver-verify` | `AF-VERIFY` | `EV-FS-SILVER_VERIFY` |
| `FS-SILVER_WORKTREE` | `silver-worktree` | `AF-EXECUTE` | `EV-FS-SILVER_WORKTREE` |
| `FS-TDD` | `tdd` | `AF-EXECUTE` | `EV-FS-TDD` |
| `FS-TESTABILITY` | `testability` | `AF-VERIFY` | `EV-FS-TESTABILITY` |
| `FS-USABILITY` | `usability` | `AF-UI-QUALITY` | `EV-FS-USABILITY` |
| `FS-VERIFY_TESTS` | `verify-tests` | `AF-VERIFY` | `EV-FS-VERIFY_TESTS` |

## Legacy Migration Map

| Legacy Surface | Catalog Entity |
|----------------|----------------|
| `FLOW 1` | `AF-BOOTSTRAP` |
| `FLOW 10` | `WF-REVIEW-TRIAD` |
| `FLOW 11` | `AF-SECURE` |
| `FLOW 12` | `AF-VERIFY` |
| `FLOW 13` | `AF-QUALITY-GATE` |
| `FLOW 14` | `WF-SHIP-READINESS` |
| `FLOW 15` | `AF-DEBUG` |
| `FLOW 16` | `AF-DOCUMENT` |
| `FLOW 17` | `AF-DOCUMENT` |
| `FLOW 18` | `AF-RELEASE` |
| `FLOW 2` | `AF-ORIENT` |
| `FLOW 3` | `AF-CLARIFY` |
| `FLOW 4` | `AF-DECIDE` |
| `FLOW 5` | `AF-SPECIFY` |
| `FLOW 6` | `AF-PLAN` |
| `FLOW 7` | `AF-DESIGN-CONTRACT` |
| `FLOW 8` | `AF-EXECUTE` |
| `FLOW 9` | `AF-UI-QUALITY` |
| `ai-llm-safety` | `AF-SECURE` |
| `artifact-review-assessor` | `AF-REVIEW` |
| `artifact-reviewer` | `AF-REVIEW` |
| `devops-quality-gates` | `AF-QUALITY-GATE` |
| `devops-skill-router` | `AF-DEVOPS-ROUTE` |
| `extensibility` | `AF-QUALITY-GATE` |
| `modularity` | `AF-QUALITY-GATE` |
| `reliability` | `AF-QUALITY-GATE` |
| `reusability` | `AF-QUALITY-GATE` |
| `review-context` | `AF-PLAN` |
| `review-cross-artifact` | `AF-REVIEW` |
| `review-design` | `AF-DESIGN-CONTRACT` |
| `review-ingestion-manifest` | `AF-SPECIFY` |
| `review-plan` | `AF-PLAN` |
| `review-requirements` | `AF-SPECIFY` |
| `review-research` | `AF-DECIDE` |
| `review-roadmap` | `AF-REVIEW` |
| `review-spec` | `AF-SPECIFY` |
| `review-uat` | `AF-REVIEW` |
| `review-verification` | `AF-VERIFY` |
| `scalability` | `AF-QUALITY-GATE` |
| `security` | `AF-SECURE` |
| `silver` | `AF-ROUTE` |
| `silver-add` | `AF-PHASE-MANAGE` |
| `silver-agent-codex` | `AF-AGENT-DELEGATE` |
| `silver-agent-cursor` | `AF-AGENT-DELEGATE` |
| `silver-agent-worker` | `AF-AGENT-DELEGATE` |
| `silver-benchmark` | `AF-FAST-PATH` |
| `silver-blast-radius` | `AF-BLAST-RADIUS` |
| `silver-bootstrap-milestone` | `AF-BOOTSTRAP` |
| `silver-bootstrap-project` | `AF-BOOTSTRAP` |
| `silver-branch-finish` | `AF-BRANCH-FINISH` |
| `silver-bugfix` | `AF-DEBUG` |
| `silver-canary` | `AF-SHIP` |
| `silver-clarify` | `AF-CLARIFY` |
| `silver-completion-audit` | `AF-COMPLETION-AUDIT` |
| `silver-content` | `AF-DOCUMENT` |
| `silver-context` | `AF-ORIENT` |
| `silver-create-release` | `AF-RELEASE` |
| `silver-debug` | `AF-DEBUG` |
| `silver-deploy` | `AF-SHIP` |
| `silver-devops` | `AF-DEVOPS-ROUTE` |
| `silver-doctor` | `AF-PHASE-MANAGE` |
| `silver-domain-audit` | `AF-REVIEW` |
| `silver-ensure-docs` | `AF-DOCUMENT` |
| `silver-execute` | `AF-EXECUTE` |
| `silver-fast` | `AF-FAST-PATH` |
| `silver-feature` | `AF-FAST-PATH` |
| `silver-forensics` | `AF-DEBUG` |
| `silver-handoff` | `AF-DOCUMENT` |
| `silver-incident` | `AF-FAST-PATH` |
| `silver-ingest` | `AF-SPECIFY` |
| `silver-init` | `AF-BOOTSTRAP` |
| `silver-migrate` | `AF-PHASE-MANAGE` |
| `silver-multi-ai` | `AF-DECIDE` |
| `silver-orchestrator` | `AF-ROUTE` |
| `silver-orient` | `AF-ORIENT` |
| `silver-phase` | `AF-PHASE-MANAGE` |
| `silver-plan` | `AF-PLAN` |
| `silver-quality-gates` | `AF-QUALITY-GATE` |
| `silver-refactor` | `AF-EXECUTE` |
| `silver-release` | `AF-RELEASE` |
| `silver-rem` | `AF-PHASE-MANAGE` |
| `silver-remove` | `AF-PHASE-MANAGE` |
| `silver-research` | `AF-DECIDE` |
| `silver-retro` | `AF-DOCUMENT` |
| `silver-review` | `AF-REVIEW` |
| `silver-review-fix-ladder` | `AF-REVIEW-TRIAGE` |
| `silver-review-request` | `AF-REVIEW-REQUEST` |
| `silver-review-stats` | `AF-ORIENT` |
| `silver-review-triage` | `AF-REVIEW-TRIAGE` |
| `silver-scan` | `AF-ORIENT` |
| `silver-secure` | `AF-SECURE` |
| `silver-ship` | `AF-SHIP` |
| `silver-spec` | `AF-SPECIFY` |
| `silver-spike` | `AF-EXECUTE` |
| `silver-test` | `AF-VERIFY` |
| `silver-thread` | `AF-PHASE-MANAGE` |
| `silver-ui` | `AF-UI-QUALITY` |
| `silver-ui-contract` | `AF-DESIGN-CONTRACT` |
| `silver-ui-review` | `AF-UI-QUALITY` |
| `silver-undo` | `AF-PHASE-MANAGE` |
| `silver-update` | `AF-PHASE-MANAGE` |
| `silver-validate` | `AF-VALIDATE` |
| `silver-verify` | `AF-VERIFY` |
| `silver-worktree` | `AF-EXECUTE` |
| `tdd` | `AF-EXECUTE` |
| `testability` | `AF-VERIFY` |
| `usability` | `AF-UI-QUALITY` |
| `verify-tests` | `AF-VERIFY` |
| `code-review` | `AF-REVIEW` |
| `finishing-a-development-branch` | `AF-BRANCH-FINISH` |
| `gsd-code-review` | `WF-REVIEW-TRIAD` |
| `gsd-discuss-phase` | `AF-CLARIFY` |
| `gsd-execute-phase` | `AF-EXECUTE` |
| `gsd-plan-phase` | `AF-PLAN` |
| `gsd-secure-phase` | `AF-SECURE` |
| `gsd-ship` | `AF-SHIP` |
| `gsd-validate-phase` | `AF-VALIDATE` |
| `gsd-verify-work` | `AF-VERIFY` |
| `receiving-code-review` | `AF-REVIEW-TRIAGE` |
| `requesting-code-review` | `AF-REVIEW-REQUEST` |
| `systematic-debugging` | `AF-DEBUG` |
| `test-driven-development` | `FS-TDD` |
| `verification-before-completion` | `AF-COMPLETION-AUDIT` |
| `writing-plans` | `AF-PLAN` |
