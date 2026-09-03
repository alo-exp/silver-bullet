# Enterprise E2E Outcome Assessment Rubric

**Purpose:** Score Silver Bullet behavior beyond binary pass/fail for each **workflow** (matrix row) and each **session** (live TUI / ladder rung). Criteria are derived from [sb.alolabs.dev](https://sb.alolabs.dev) hero capabilities, README mechanism claims, and enterprise E2E effectiveness plan gaps.

**Authority:** Machine-readable registry at [`docs/testing/outcome-criteria-registry.json`](../../docs/testing/outcome-criteria-registry.json). Harness scoring: [`scripts/lib/enterprise-e2e-outcome-assessment.sh`](../../scripts/lib/enterprise-e2e-outcome-assessment.sh).

**Scoring:** `pass` | `partial` | `fail` | `n/a` (criterion not applicable to row/session class).

| Scope | Applies to |
|-------|------------|
| **workflow** | One matrix row (22 rows) or internal row 21–22 via parent |
| **session** | One live TUI invocation, ladder rung, or bootstrap step |
| **round** | Full Round N ledger + monitor reconciliation |

---

## Blocking autonomy criteria

These four criteria are **mandatory** for matrix row PASS and strict-clean round verdict. **`partial` scores as row FAIL** — evidence file alone is insufficient.

| ID | Blocking |
|----|----------|
| **OUT-AUTO-01** | Yes — autonomous end-to-end delivery |
| **OUT-CLARIFY-01** | Yes — ambiguous input routes to `/silver:clarify` before wrong execution |
| **OUT-NOOP-01** | Yes — no operator pause when automation path exists |
| **OUT-WORLD-01** | Yes — composite: all applicable workflow + session criteria pass |

---

## Criteria (31)

### OUT-TAILOR-01 — Dynamic workflow tailoring

| Field | Value |
|-------|-------|
| **Scope** | workflow (row 1 primary); session |
| **Definition** | `/silver` router composes the smallest safe chain for the stated intent — not a generic fallback workflow. |
| **Pass signals** | `state` file lists `silver-context` or composed downstream skill; orchestrator `current_flow` matches task class; row 1 evidence or routing delta in `orchestrator-directive.json`. |
| **Partial** | Routing markers in TUI output only; queue seeded but not drained. |
| **Fail** | Wrong workflow slug invoked; parent implements without routing; `silver:feature` on router-only prompt. |
| **Artifacts** | `${SB_RUNTIME_STATE_DIR}/state`, `.planning/workflows/router-session.md`, `.e2e-row1-attempt.log` |

### OUT-VLOOP-01 — Verification & validation loops

| Field | Value |
|-------|-------|
| **Scope** | workflow |
| **Definition** | Flow-step V-loops ran with BLOCK/WARN/INFO evidence — not skipped validation. |
| **Pass signals** | `.planning/VALIDATION*.md`, `validate-evidence-findings`, or workflow Flow Log CSV contains `VALIDATE` / `VERIFY` step with timestamp. |
| **Partial** | Validation mentioned in workflow md without findings file. |
| **Fail** | Feature/bugfix/ship row completes with zero validation artifacts. |
| **Artifacts** | `.planning/VALIDATION*.md`, `.planning/workflows/*.md` Flow Log |

### OUT-GATES-01 — Quality gates engaged

| Field | Value |
|-------|-------|
| **Scope** | workflow |
| **Definition** | Planning floor and post-exec gates (`quality-gates`, `review`, `secure`, `validate`) engaged per workflow class. |
| **Pass signals** | `QUALITY-GATES*.md` or `post-exec-gates` in parent workflow; `state` includes `silver-quality-gates` for full-cycle rows. |
| **Partial** | Fast row (6) correctly skips full gates — scored pass for appropriate omission. |
| **Fail** | Row 3 feature without post-exec-gates note; row 16 without ship-readiness checklist. |
| **Artifacts** | `.planning/QUALITY-GATES*.md`, `.planning/ship-readiness/`, workflow md |

### OUT-TRACE-01 — Spec-to-release traceability

| Field | Value |
|-------|-------|
| **Scope** | workflow |
| **Definition** | SPEC → PLAN → VALIDATION → SHIP chain linked; PR/release rows show traceability block. |
| **Pass signals** | `.planning/*SPEC*` or `PLAN*.md` cross-reference; `docs/instruction-ledger.jsonl` entry; row 14–16 changelog/version linkage. |
| **Partial** | PLAN without SPEC reference. |
| **Fail** | Code/docs shipped with no planning artifact chain. |
| **Artifacts** | `.planning/`, `docs/instruction-ledger.jsonl`, `CHANGELOG.md` |

### OUT-INTENT-01 — Intent-aligned results

| Field | Value |
|-------|-------|
| **Scope** | workflow + session |
| **Definition** | Delivered artifacts match the matrix user prompt card — environment blocked unsafe shortcuts. |
| **Pass signals** | Evidence path from matrix exists and content addresses prompt keywords; row log lacks premature "done" before evidence. |
| **Partial** | Artifact exists but off-topic (e.g. wrong file touched). |
| **Fail** | Empty evidence; parent declared complete without user intent met. |
| **Artifacts** | Matrix evidence path, `.e2e-row{N}-attempt.log` |

### OUT-KM-01 — Knowledge management (Graphify + agentmemory)

| Field | Value |
|-------|-------|
| **Scope** | session + round |
| **Definition** | Decisions recorded and retrievable via Graphify query + agentmemory export — not transcript-only memory. |
| **Pass signals** | Ledger `graphify_query_ref` and `agentmemory_export_ref` non-empty on PASS rows; `graphify query` in row log; Session 0 opt-in. |
| **Partial** | Only Graphify ref or only agentmemory ref. |
| **Fail** | PASS row with empty refs; no `graphify update` after SB edits in round. |
| **Artifacts** | Ledger columns, `graphify-out/`, agentmemory export dir, preflight log |

### OUT-ORCH-01 — Orchestrator parent/worker routing

| Field | Value |
|-------|-------|
| **Scope** | session |
| **Definition** | Parent orchestrator spawns workers for implementation; parent does not edit `src_pattern` inline. |
| **Pass signals** | `orchestrator-directive.json` with `next_worker_template`; no parent `Edit`/`Write` on `api/` or `ui/` in parent transcript when workers expected. |
| **Partial** | Orchestrator queue advanced but worker evidence missing. |
| **Fail** | Parent implements feature code; `orchestrator-directive-guard` block ignored. |
| **Artifacts** | `orchestrator-directive.json`, TUI log, `.silver-bullet/state` |

### OUT-PLAN-01 — Planning floor enforcement

| Field | Value |
|-------|-------|
| **Scope** | workflow + session |
| **Definition** | Source edits blocked until planning floor (`silver:plan`, `silver:context`, `silver:quality-gates`) satisfied. |
| **Pass signals** | PLAN.md timestamp before first src edit in Flow Log; `dev-cycle-check` BLOCK absent after plan recorded. |
| **Partial** | Plan artifact exists but after first edit attempt in log. |
| **Fail** | Src committed with no plan; hook bypass without documented override. |
| **Artifacts** | `.planning/PLAN*.md`, Flow Log CSV, hook audit |

### OUT-SKILL-01 — Skill invocation tracking

| Field | Value |
|-------|-------|
| **Scope** | session |
| **Definition** | `record-skill.sh` / `record-requested-skill.sh` captured required skills for the workflow route. |
| **Pass signals** | `${SB_RUNTIME_STATE_DIR}/state` contains workflow slug skill and required chain skills. |
| **Partial** | Router skill only on multi-step workflow row. |
| **Fail** | Empty state after completed workflow row. |
| **Artifacts** | `state`, `record-skill` hook output in log |

### OUT-REVIEW-01 — Review loop (2 consecutive clean verify)

| Field | Value |
|-------|-------|
| **Scope** | round |
| **Definition** | `review-fix-ladder` rungs complete with audit_fix + verify_1 + verify_2 Pass (2× clean verify per rung). |
| **Pass signals** | ROUND-N-LEDGER ladder table: 8/8 rungs with verify_2 Pass; ≤2 model substitutions documented. |
| **Partial** | Ladder complete with >2 substitutions or missing verify_2 on any rung. |
| **Fail** | Ladder incomplete; verify failures open. |
| **Artifacts** | `.planning/enterprise-e2e/ROUND-N-LEDGER.md` ladder section |

### OUT-BLAST-01 — Blast-radius / domain safety

| Field | Value |
|-------|-------|
| **Scope** | workflow (row 11 devops primary) |
| **Definition** | High-risk work includes blast-radius or security review before infra edits ship. |
| **Pass signals** | `SECURITY*.md`, blast-radius note in devops workflow, or `silver:secure` in state for devops row. |
| **Partial** | Terraform touched without explicit blast-radius section. |
| **n/a** | Rows 6, 10, 18 — low blast-radius class. |
| **Artifacts** | `infra/terraform/`, `.planning/workflows/`, `SECURITY*.md` |

### OUT-HOOK-01 — Hook-enforced process

| Field | Value |
|-------|-------|
| **Scope** | session |
| **Definition** | Twelve hook layers fire appropriately — legitimate actions pass; unsafe actions BLOCK. |
| **Pass signals** | No false BLOCK in `.e2e-tui-watch-findings.jsonl`; hook-delivery preflight 3/3; `sb-diagnostics` tier recorded. |
| **Partial** | WARN-level hook only; recovered in session. |
| **Fail** | False positive BLOCK stopped matrix; or unsafe action proceeded without hook. |
| **Artifacts** | TUI watch findings, preflight log, `sb-diagnostics` output |

### OUT-COMPLETE-01 — Completion audit / stop-check

| Field | Value |
|-------|-------|
| **Scope** | workflow (rows 14–16) |
| **Definition** | `completion-audit.sh` / `stop-check.sh` prevent premature PR/deploy/release claims. |
| **Pass signals** | Ship-readiness checklist; release row has version + changelog; no Stop hook error in log for premature done. |
| **Partial** | Checklist exists but CI evidence missing. |
| **Fail** | Declared ship-ready without `.planning/ship-readiness/` artifacts. |
| **Artifacts** | `.planning/ship-readiness/`, row 14–16 evidence |

### OUT-HANDOFF-01 — Subagent / worker handoff

| Field | Value |
|-------|-------|
| **Scope** | session |
| **Definition** | Orchestrator hands off to worker template with skill invocation before edits. |
| **Pass signals** | `orchestrator-worker-active.json` or worker completion in composition log; `next_skill` in directive consumed. |
| **Partial** | Directive present but queue stall before worker. |
| **Fail** | Parent session ended with pending `current_flow` steps. |
| **Artifacts** | `orchestrator-directive.json`, `.planning/orchestrator-composition-log.jsonl` |

### OUT-CODEINT-01 — Context-mode / RTK / Graphify gates

| Field | Value |
|-------|-------|
| **Scope** | session + round |
| **Definition** | Code-intelligence stack engaged when opted in — not raw Read/Grep dumps on large files. |
| **Pass signals** | `enterprise_e2e_code_intel_preflight` pass; `graphify query` before row; RTK verbatim mode in harness only. |
| **Partial** | Graphify stale warn; preflight skip with documented `SB_E2E_SESSION0_SKIP`. |
| **Fail** | Opted-in project with zero graphify queries across round. |
| **Artifacts** | Preflight log, row logs, `.silver-bullet.json` recommended_tools |

### OUT-FLOW-01 — Workflow archival / flow log advancement

| Field | Value |
|-------|-------|
| **Scope** | workflow |
| **Definition** | Active workflow files advance Flow Log CSV and archive on complete — no stale queue. |
| **Pass signals** | `202*.md` workflow with Flow Log rows; quiesce archives on row boundary; internal rows 21–22 notes in parent md. |
| **Partial** | Evidence file without Flow Log CSV. |
| **Fail** | Stale active workflow blocks next row; orchestrator queue not quiesced. |
| **Artifacts** | `.planning/workflows/`, quiesce archive |

### OUT-MEASURE-01 — Measurement integrity (ledger↔monitor)

| Field | Value |
|-------|-------|
| **Scope** | round |
| **Definition** | Monitor COMPLETE only when ledger shows 22 PASS with refs; failure_class taxonomy applied. |
| **Pass signals** | `enterprise_e2e_ledger_reconcile_ok` exit 0; monitor `LEDGER_MISMATCH` absent; pass rows have graphify + agentmemory refs. |
| **Partial** | <22 rows scored; reconcile STALE during in-progress round. |
| **Fail** | Monitor COMPLETE with ledger incomplete (Round 3 anti-pattern). |
| **Artifacts** | ROUND-N-LEDGER.md, `.e2e-matrix-monitor-status.txt`, reconcile lib |

### OUT-DECIDE-01 — Locked decisions (decision_class)

| Field | Value |
|-------|-------|
| **Scope** | session |
| **Definition** | `decision_class` outcomes and CLARIFY locked decisions recorded — not re-litigated silently. |
| **Pass signals** | `outcomes-check` hook pass; `.planning/CLARIFY.md` with locked items; orchestrator outcomes JSON. |
| **Partial** | Decision in workflow md without locked marker. |
| **Fail** | Operator re-asked for locked routing decision mid-session. |
| **Artifacts** | `.planning/CLARIFY.md`, outcomes hook state |

### OUT-FORENS-01 — Forensics / session recovery

| Field | Value |
|-------|-------|
| **Scope** | workflow (row 19) |
| **Definition** | Forensics workflow reconstructs failed/stalled session with root cause and actions. |
| **Pass signals** | `docs/forensics/*.md` with root cause + timeline sections. |
| **Partial** | Forensics doc without actionable next steps. |
| **n/a** | Non-forensics rows. |
| **Artifacts** | `docs/forensics/CI-001.md`, row 19 log |

### OUT-AUTO-01 — Autonomous end-to-end delivery *(blocking)*

| Field | Value |
|-------|-------|
| **Scope** | workflow + session |
| **Definition** | SB drives vague or partial prompts to a shipped outcome without operator babysitting; uses clarify loop when needed instead of stalling. |
| **Pass signals** | Evidence artifact exists; row log shows `autonomous` / orchestrator queue drained; no babysitting markers; parent completes worker chain. |
| **Partial** | Evidence exists but log shows non-locked operator prompts or stalled queue before recovery. |
| **Fail** | Session ended needing operator to advance; parent declared done without outcome; autonomy breakdown in row log. |
| **Artifacts** | Matrix evidence path, `.e2e-row{N}-attempt.log`, `orchestrator-directive.json` |

### OUT-CLARIFY-01 — Clarify gate *(blocking)*

| Field | Value |
|-------|-------|
| **Scope** | workflow + session |
| **Definition** | Ambiguous or fuzzy intent routes to `/silver:clarify` before wrong workflow execution — not silent mis-routing. |
| **Pass signals** | `state` contains `silver-clarify`; `.planning/CLARIFY.md` with locked decisions; row log shows `/silver:clarify` before first src edit. |
| **Partial** | Clarify artifact exists but after wrong-route attempt in log. |
| **Fail** | Vague prompt (row 1–3 class) executed wrong workflow with zero clarify markers. |
| **n/a** | Rows with fully specified prompt cards and no ambiguity signals. |
| **Artifacts** | `.planning/CLARIFY.md`, `state`, row log |

### OUT-NOOP-01 — No operator pause *(blocking)*

| Field | Value |
|-------|-------|
| **Scope** | session |
| **Definition** | No locked `decision_class` outcomes left for human when an automation path exists — matrix runs without operator babysitting. |
| **Pass signals** | Row log lacks operator pause markers; locked decisions in CLARIFY/outcomes JSON; `outcomes-check` pass. |
| **Partial** | Single recoverable pause with documented `SB OVERRIDE`. |
| **Fail** | Repeated operator prompts for automatable decisions; ledger notes manual intervention mid-row. |
| **Artifacts** | Row log, `.planning/CLARIFY.md`, outcomes hook state |

### OUT-MULTIWF-01 — Autonomous multi-workflow chaining *(blocking, TC-01)*

| Field | Value |
|-------|-------|
| **Scope** | session |
| **Definition** | Parent orchestrator chains ≥3 distinct `workflow_id` values without operator manual routing between composers. |
| **Pass signals** | Composition log and/or orchestrator events show ≥3 unique `workflow_id`; `composer_chain` advance events. |
| **Partial** | Two workflow ids with advance events only. |
| **Fail** | Single-workflow-only run; parent implements inline; operator manual routing between composers. |
| **Artifacts** | `.planning/orchestrator-composition-log.jsonl`, `orchestrator-events.jsonl` |

### OUT-DYNAMIC-01 — Dynamic workflow composition *(blocking, TC-02)*

| Field | Value |
|-------|-------|
| **Scope** | session |
| **Definition** | Runtime scheduler records ≥2 dynamic composition ops with valid `catalog_rule_ref` ids from `docs/apo-catalog.json`. |
| **Pass signals** | Composition log `scheduler_decisions` or dynamic ops with matching `DR-*` rule refs; queue differs from default composer template. |
| **Partial** | Single dynamic op recorded. |
| **Fail** | Default queue unchanged; missing or fake `catalog_rule_ref`. |
| **Artifacts** | `.planning/orchestrator-composition-log.jsonl`, `docs/apo-catalog.json` |

### OUT-NEWWF-01 — Net-new workflow creation *(blocking, TC-03)*

| Field | Value |
|-------|-------|
| **Scope** | session |
| **Definition** | `silver-new-workflow` / `NEW-WORKFLOW` worker dispatches and produces a net-new workflow spec artifact — not force-fit to pre-existing workflow. |
| **Pass signals** | `NEW-WORKFLOW` in orchestrator queue/events; new workflow markdown/spec under `.planning/workflows/`. |
| **Partial** | Worker dispatch OR artifact only (not both). |
| **Fail** | Pre-existing workflow reused; no `silver-new-workflow` dispatch. |
| **Artifacts** | `orchestrator-events.jsonl`, `.planning/workflows/*.md`, parent session log |

### OUT-WORLD-01 — World-class composite gate *(blocking)*

| Field | Value |
|-------|-------|
| **Scope** | workflow (per row) |
| **Definition** | Composite gate: **all applicable** workflow + session criteria for the row score `pass` (not `partial` or `fail`). Evidence file existence alone is insufficient. |
| **Pass signals** | `enterprise_e2e_outcome_row_passes` returns 0; checklist has zero non-pass applicable scores. |
| **Partial** | *(not used — partial on any applicable criterion fails this gate)* |
| **Fail** | Any applicable criterion `partial` or `fail`. |
| **Artifacts** | `.planning/enterprise-e2e/outcomes/row-N-outcomes.md` |

### OUT-DRIFT-01 — Intent drift course correction

| Field | Value |
|-------|-------|
| **Scope** | workflow + session |
| **Definition** | When implementation drifts from plan or matrix prompt, SB proactively course-corrects — logs deviation and realigns. |
| **Pass signals** | Flow Log deviation row; forensics/drift note in workflow md; log shows course correction. |
| **Partial** | Drift mentioned without corrective action. |
| **n/a** | Simple single-artifact rows (6, 10) with no drift signals. |
| **Artifacts** | `.planning/workflows/*.md` Flow Log, row log |

### OUT-SUPER-01 — WBS meta-supervision to completion

| Field | Value |
|-------|-------|
| **Scope** | session |
| **Definition** | WBS meta-supervisor tracks parent/worker loop to completion — no parent exit with pending subagent work. |
| **Pass signals** | `wbs-supervisor` in log; worker handoff snapshot; `current_flow` empty at row end. |
| **Partial** | Supervisor stub without worker completion evidence. |
| **Fail** | Parent session ended with pending `current_flow`; open WBS items at row boundary. |
| **Artifacts** | `hooks/lib/wbs-supervisor.sh` output, `orchestrator-directive.json`, composition log |

### OUT-HEAL-01 — Self-healing on hook friction

| Field | Value |
|-------|-------|
| **Scope** | session |
| **Definition** | Hook BLOCK/WARN friction triggers autonomous retry or fix in-session — not user babysitting. |
| **Pass signals** | Log shows hook block followed by retry/recovery in same session; TUI watch finding resolved. |
| **Partial** | WARN-level hook only; recovered without operator. |
| **Fail** | Session ended on hook block; false-positive BLOCK with no SB fix attempt. |
| **n/a** | Sessions with zero hook friction events. |
| **Artifacts** | `.e2e-tui-watch-findings.jsonl`, row log, hook audit |

### OUT-RELEASE-01 — Release-ready artifact chain

| Field | Value |
|-------|-------|
| **Scope** | workflow (rows 14–16) |
| **Definition** | SPEC → PLAN → VALIDATION → SHIP → ledger refs form a complete chain without manual ledger patching. |
| **Pass signals** | `docs/instruction-ledger.jsonl` entry; ship-readiness checklist; ledger row refs match automated telemetry. |
| **Partial** | Artifacts exist but ledger manually patched mid-round. |
| **Fail** | Release/ship row without instruction-ledger or ship-readiness chain. |
| **Artifacts** | `docs/instruction-ledger.jsonl`, `.planning/ship-readiness/`, ROUND-N-LEDGER.md |

### OUT-SURFACE-01 — Install surface host isolation and token budget

| Field | Value |
|-------|-------|
| **Scope** | round (Phase C pre-matrix + post-install) |
| **Definition** | Post-install user-facing surface audit: Claude Agents Library must not expose Codex/Cursor namespaces; Claude agent description aggregate ≤ 14k tokens (buffer under 15k host warning). |
| **Pass signals** | `validate-host-install-surface.sh` exit 0; `agents/` contains only `claude/`; no `silver-bullet:codex:` / `silver-bullet:cursor:` in Claude bundle; `validate-claude-agent-token-budget.sh` pass. |
| **Partial** | Surface check skipped with documented `SB_E2E_SURFACE_SKIP`. |
| **Fail** | `agents/codex` or `agents/cursor` present; foreign namespace refs in Claude manifests; token budget exceeded (e.g. 17.8k warning). |
| **Artifacts** | `scripts/validate-host-install-surface.sh`, `tests/scripts/test-claude-agent-surface-isolation.sh`, `sb-doctor` D15/D16 |

---

## Per-workflow applicability matrix

| Row | WF slug | Primary criteria (must pass for world-class) |
|-----|---------|-----------------------------------------------|
| 1 | silver-router | TAILOR, ORCH, SKILL, HOOK, CODEINT |
| 2 | silver-research | KM, TRACE, INTENT, SKILL, VLOOP |
| 3 | silver-feature | GATES, VLOOP, PLAN, TRACE, ORCH, FLOW, INTENT |
| 4 | silver-bugfix | VLOOP, PLAN, INTENT, FLOW (+ validate-substep) |
| 5 | silver-ui | GATES, INTENT, TRACE, SKILL |
| 6 | silver-fast | TAILOR, INTENT (fast-path omission of full gates = pass) |
| 7–13 | test…canary | INTENT, SKILL, PLAN, TRACE as applicable |
| 14 | silver-release | COMPLETE, TRACE, GATES |
| 15 | review-triad | REVIEW, VLOOP, GATES |
| 16 | ship-readiness | COMPLETE, GATES, TRACE, MEASURE |
| 17 | silver-incident | INTENT, TRACE, KM |
| 18 | silver-retro | KM, INTENT |
| 19 | silver-forensics | FORENS, KM, INTENT |
| 20 | process-maintenance | TRACE, FLOW |
| 21 | post-exec-gates | GATES, VLOOP (parent row 3) |
| 22 | validate-substep | VLOOP (parent row 4) |

---

## Harness usage

```bash
# Structural + fixture scoring (CI-safe)
bash tests/scripts/test-outcome-assessment.sh

# Score one workflow row from artifacts
source scripts/lib/enterprise-e2e-outcome-assessment.sh
enterprise_e2e_outcome_assess_workflow_row 3 "$WORK_DIR" "$STATE_DIR" "$ROW_LOG"

# Write checklist markdown for ledger companion
enterprise_e2e_outcome_write_workflow_checklist 3 "$OUT_DIR/row-3-outcomes.md"

# Round-level scoring from ledger
enterprise_e2e_outcome_assess_round "$SB_ROOT/.planning/enterprise-e2e/ROUND-6-LEDGER.md"
```

Round companion template: [`ROUND-N-OUTCOMES.md`](ROUND-N-OUTCOMES.md).
