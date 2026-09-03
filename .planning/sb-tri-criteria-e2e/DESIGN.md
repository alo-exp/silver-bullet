# SB Tri-Criteria E2E — Design

**Author:** SB tri-criteria scaffold (2026-07-06)  
**Research:** `graphify query "orchestrator scheduler dynamic composition NEW-WORKFLOW composition_log apo-catalog dynamic_rules"`  
**Harness:** [`scripts/sb-tri-criteria-e2e.sh`](../../scripts/sb-tri-criteria-e2e.sh)

---

## Research summary (graphify + codebase)

| Mechanism | Location | E2E relevance |
|-----------|----------|---------------|
| Parent orchestrator loop | `skills/silver-orchestrator/SKILL.md`, `hooks/lib/orchestrator-parent.sh` | TC-01/02 primary executor; spawns Task workers only |
| Scheduler + composition log | `hooks/lib/orchestrator-scheduler.sh`, `sb_orchestrator_composition_log` | TC-02 evidence: `prune\|insert\|substitute\|parallelize\|loop` + `catalog_rule_ref` |
| APO `dynamic_rules` | `docs/apo-catalog.json` (`DR-PRUNE-*`, `DR-INSERT-*`, etc.) | TC-02 scorer matches rule refs to catalog |
| `orchestrator-events.jsonl` | `hooks/lib/orchestrator-event-log.sh` | TC-01/02: `dispatch`, `advance`, `join` event chain |
| `silver-fast` vs `silver-feature` | `hooks/lib/orchestrator-state.sh` default queues | TC-02: default `silver-feature` queue is wrong; must substitute/prune |
| `NEW-WORKFLOW` worker | `orchestrator-parent.sh` maps `silver-new-workflow` → `NEW-WORKFLOW` | TC-03: queue must contain `NEW-WORKFLOW` template |
| Supervision loop | orchestrator directive + stop-check + event log resume hints | All tracks: parent advances queue without operator micro-prompts |
| Existing scorers | `scripts/lib/enterprise-e2e-outcome-assessment.sh` | Extended with `OUT-MULTIWF-01`, `OUT-DYNAMIC-01`, `OUT-NEWWF-01` |

---

## Criterion 1 — Autonomous multi-workflow chaining

### Falsifiable success definition

**PASS** when a single session, from one vision paragraph, autonomously executes **≥3 distinct catalog `workflow_id`s** (e.g. `WF-SILVER-FEATURE`, `WF-SILVER-DEVOPS`, `WF-SILVER-RELEASE`) without operator workflow selection, and drains the orchestrator queue (or prefs-declared subset) with substantive product delta.

Measurable assertions:

1. `OUT-MULTIWF-01: pass` — ≥3 unique `workflow_id` values in composition log and/or orchestrator events
2. `OUT-ORCH-01: pass` — parent used Task workers; no inline implementation
3. `OUT-AUTO-01: pass` — no babysitting markers in session log
4. `orchestrator-events.jsonl` contains ≥2 `advance` events with different `next_flow` / workflow bindings
5. Committed product delta on target branch per vision acceptance

### Forbidden shortcuts

| Shortcut | Why invalid |
|----------|-------------|
| Single `WF-SILVER-FEATURE` queue only | One workflow ≠ chaining |
| Operator pastes step-by-step harness script | Violates minimal-intent contract |
| `npm test` / health-check only | Not multi-workflow delivery |
| Manual `/silver:fast` after parent stalls | Operator routing ≠ autonomous chain |
| Three AF-* atoms within one workflow | AF count ≠ workflow_id count |

### Evidence artifacts

| Artifact | Path | Assertion |
|----------|------|-----------|
| Vision seed | `runs/<id>/vision.md` | Single paragraph; no step list |
| Session log | `runs/<id>/parent-session.log` | Task spawns, no parent Edit on source |
| Composition log | `<work_dir>/.planning/orchestrator-composition-log.jsonl` | ≥3 `selected_workflow` values |
| Event log | `$SB_RUNTIME_STATE_DIR/orchestrator-events.jsonl` | `dispatch` + `advance` chain |
| Orchestrator state | `$SB_RUNTIME_STATE_DIR/orchestrator.json` | `current_flow` empty at end |
| Ledger | `runs/<id>/ledger.json` | `verdict: PASS`, `live_session_run: true` |
| Product delta | git log on fixture branch | ≥1 substantive commit |

### High-level goal prompt (TC-01)

> Build a **greenfield micro-SaaS slice** in the fixture app: a tenant-scoped **waitlist API** (`POST /waitlist`, `GET /waitlist/stats`) with **SQLite persistence**, a **minimal landing page** that submits to the API, **containerized local run** via Docker Compose, and **ship readiness** (branch finish + PR or documented deploy waiver). Use Silver Bullet autonomous parent orchestrator mode — compose and chain the workflows needed (product feature, DevOps/runtime, release/ship) without asking me to pick workflows. Commit on `feature/tc01-waitlist-saas`. Intervene only on blocking credentials.

**Why this forces chaining:** Requires clarify/spec → feature implementation → DevOps (Docker/compose) → release/ship — each maps to distinct catalog workflows; cannot complete in one `silver-feature` pass.

### Host path

**Cursor parent orchestrator** (`orchestrator_mode: parent`) in fixture `work_dir`. Same model as minimal-intent E2E but with stricter `OUT-MULTIWF-01` gate.

---

## Criterion 2 — Dynamic workflow composition

### Falsifiable success definition

**PASS** when SB selects a base composer route then **tailors** it via catalog-backed dynamic operations recorded in `composition_log` with valid `catalog_rule_ref` and `rationale` — at minimum **two distinct ops** from `{prune, insert, substitute, parallelize, loop}` — and the final executed path is **not** the default `WF-SILVER-FEATURE` full queue.

Measurable assertions:

1. `OUT-DYNAMIC-01: pass` — composition log entries with ≥2 ops, each with non-empty `catalog_rule_ref` matching `docs/apo-catalog.json` `dynamic_rules[].id`
2. `OUT-TAILOR-01: pass` — evidence of route tailoring (not raw default queue)
3. Default queue avoided: log or composition log shows `substitute` (e.g. `DR-SUBSTITUTE-LEANER-WORKFLOW`) or `prune` of feature-chain atoms
4. `scheduler_decisions` present in at least one composition log entry

### Forbidden shortcuts

| Shortcut | Why invalid |
|----------|-------------|
| Run default `silver-feature` unchanged | No dynamic composition |
| Operator manually `/silver:fast` | External substitution |
| Fabricate composition log without scheduler | Must be runtime-recorded |
| `catalog_rule_ref` empty or fake IDs | Fails `OUT-DYNAMIC-01` |
| Single `prune` only with no situational rationale | Below minimum op diversity |

### Evidence artifacts

| Artifact | Path | Assertion |
|----------|------|-----------|
| Composition log | `.planning/orchestrator-composition-log.jsonl` | `operations[].op`, `catalog_rule_ref`, `rationale` |
| Scheduler plan entry | same log | `scheduler_decisions`, `dispatch_records` |
| Session log | `parent-session.log` | Mentions tailoring / fast / router / prune context |
| APO cross-check | scorer jq vs `docs/apo-catalog.json` | All refs resolve |

### High-level goal prompt (TC-02)

> Add a **single static README badge** (build status shield via shields.io) to the fixture app root `README.md` — **documentation-only change**, no new API routes, no database migrations, no UI work, no Docker changes. The acceptance criterion is: badge visible in rendered README, link target valid, committed on `feature/tc02-readme-badge`. Use Silver Bullet autonomous mode. **Do not** run the full feature development pipeline; tailor the workflow to the smallest correct catalog path.

**Why this forces dynamic composition:** Ambiguous phrasing ("add feature") would route to `silver-feature`; correct behavior is **substitute** to `silver-fast` or **prune** feature-chain atoms (plan, execute gates, UI) per `DR-SUBSTITUTE-LEANER-WORKFLOW` / `DR-PRUNE-SATISFIED-ATOM`.

### Host path

**Cursor parent orchestrator** — dynamic composition is orchestrator-scheduler responsibility at queue build time.

---

## Criterion 3 — Net-new workflow creation

### Falsifiable success definition

**PASS** when no existing catalog workflow fully fits the workload and SB invokes **`NEW-WORKFLOW`** (worker template from `silver-new-workflow` skill) to author a **net-new** workflow definition (composer spec + catalog fragment or `.planning/workflows/` artifact), then executes it — not merely tailoring `WF-SILVER-FEATURE`.

Measurable assertions:

1. `OUT-NEWWF-01: pass` — `NEW-WORKFLOW` in orchestrator queue, events, or session log
2. Net-new artifact exists: `.planning/workflows/<new>.md` or `docs/apo-catalog.d/` fragment with new `workflow_id` not in default router list
3. `OUT-ORCH-01: pass` when using parent mode
4. Executed atoms from the new workflow appear in `orchestrator-events.jsonl`

### Forbidden shortcuts

| Shortcut | Why invalid |
|----------|-------------|
| Force-fit `silver-deep-research` or `silver-benchmark` | Pre-existing workflows |
| Operator writes workflow markdown manually | Not SB-created |
| Rename existing WF-* in log only | ID must be novel vs catalog at session start |
| Skip NEW-WORKFLOW worker; inline improvise | Must use catalog authoring path |

### Evidence artifacts

| Artifact | Path | Assertion |
|----------|------|-----------|
| NEW-WORKFLOW dispatch | `orchestrator-events.jsonl` or log | `worker_template: NEW-WORKFLOW` or `silver-new-workflow` |
| New workflow spec | `.planning/workflows/*.md` | Contains Flow Log + atoms not mapping 1:1 to existing WF-* |
| Catalog delta (optional) | `docs/apo-catalog.d/*.json` | New `workflow_id` registered |
| Session log | `parent-session.log` | `silver-new-workflow` skill invocation |
| Product/output delta | fixture tree | Workload-specific deliverable per vision |

### High-level goal prompt (TC-03)

> Create an **automated SB compliance snapshot** for this repo: a script under `scripts/` that emits JSON listing installed hook versions, `recommended_tools` opt-in state from `.silver-bullet.json`, and last `graphify update` timestamp — plus a **one-page markdown report** in `.planning/compliance/` summarizing pass/fail against SB invariants. **No existing Silver Bullet workflow** covers this exact compliance-bundle deliverable; compose a **new reusable workflow** for "compliance snapshot audits" and execute it once. Commit on `feature/tc03-compliance-snapshot`. Autonomous mode; blocking credentials only.

**Why this forces net-new:** No `WF-SILVER-*` entry matches "compliance snapshot bundle"; requires `silver-new-workflow` → catalog authoring → execute custom AF chain.

### Host path

**Primary:** Cursor parent orchestrator (can spawn NEW-WORKFLOW worker).  
**Alternate:** Agent-claude delegation for Claude-native proof — set `host: agent-claude` in TC-03 MATRIX row when validating cross-host.

---

## Scoring outcomes

### New blocking outcomes (tri-criteria)

| Outcome | Track | Scorer function | Pass condition |
|---------|-------|-----------------|----------------|
| `OUT-MULTIWF-01` | TC-01 | `enterprise_e2e_outcome_score_multiwf` | ≥3 distinct `workflow_id` in composition log + events |
| `OUT-DYNAMIC-01` | TC-02 | `enterprise_e2e_outcome_score_dynamic` | ≥2 dynamic ops with valid `catalog_rule_ref` |
| `OUT-NEWWF-01` | TC-03 | `enterprise_e2e_outcome_score_newwf` | `NEW-WORKFLOW` dispatched + net-new workflow artifact |

### Shared blocking (all tracks)

`OUT-ORCH-01`, `OUT-AUTO-01`, `OUT-NOOP-01`, `OUT-WORLD-01` (composite)

### Advisory

`OUT-KM-01`, `OUT-VLOOP-01`, `OUT-TRACE-01`, `OUT-FLOW-01`

### composition_log assertions (jq)

```bash
# Dynamic ops with catalog refs (TC-02)
jq -s '[.[] | .operations[]? | select(.catalog_rule_ref != "")] | length' \
  "$WORK_DIR/.planning/orchestrator-composition-log.jsonl"

# Distinct workflow_ids (TC-01)
jq -s '[.[] | .selected_workflow] | unique | length' \
  "$WORK_DIR/.planning/orchestrator-composition-log.jsonl"
```

### orchestrator-events.jsonl assertions

```bash
# Advance chain (TC-01)
jq -s '[.[] | select(.type=="advance")] | length' \
  "$SB_RUNTIME_STATE_DIR/orchestrator-events.jsonl"

# NEW-WORKFLOW dispatch (TC-03)
jq -s '[.[] | select(.type=="dispatch" and (.payload.worker_template=="NEW-WORKFLOW" or .payload.skill=="silver-new-workflow"))] | length' \
  "$SB_RUNTIME_STATE_DIR/orchestrator-events.jsonl"
```

---

## Evidence checklist (operator)

### TC-01

- [ ] Vision paragraph only at session start
- [ ] ≥3 distinct `workflow_id` in composition log
- [ ] `orchestrator-events.jsonl` advance chain captured
- [ ] `parent-session.log` saved
- [ ] `bash scripts/sb-tri-criteria-e2e.sh score --run <id> --track TC-01` → VERDICT: PASS
- [ ] agentmemory + `graphify update .` in modified repos

### TC-02

- [ ] Composition log shows ≥2 dynamic ops with `catalog_rule_ref`
- [ ] Final path ≠ default full `silver-feature` queue
- [ ] README badge committed (product delta)
- [ ] Score PASS on `OUT-DYNAMIC-01`

### TC-03

- [ ] `NEW-WORKFLOW` in queue or event log
- [ ] New workflow markdown/spec artifact exists
- [ ] Compliance script + report committed
- [ ] Score PASS on `OUT-NEWWF-01`

---

## Honest non-claims

- Structural preflight PASS ≠ any criterion proven
- TC-01 PASS ≠ 22/22 enterprise matrix
- TC-02 PASS with fixture replay ≠ production catalog drift immunity
- TC-03 catalog fragment may remain repo-local until promoted to `docs/apo-catalog.json`

---

## Related documents

- [CURSOR-MULTIWF-CRITERIA.md](CURSOR-MULTIWF-CRITERIA.md)
- [`.planning/minimal-intent-e2e/`](../minimal-intent-e2e/)
- [`.planning/agent-claude-autonomous/`](../agent-claude-autonomous/)
- [`docs/ORCHESTRATOR.md`](../../docs/ORCHESTRATOR.md)
- [`tests/scripts/test-dynamic-composition-audit.sh`](../../tests/scripts/test-dynamic-composition-audit.sh)
