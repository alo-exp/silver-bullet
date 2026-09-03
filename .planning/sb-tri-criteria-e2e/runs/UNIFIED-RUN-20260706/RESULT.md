# Tri-Criteria E2E — Unified Cold Run (2026-07-06)

**Design:** [UNIFIED-DESIGN.md](../../UNIFIED-DESIGN.md)  
**Harness:** `bash scripts/sb-tri-criteria-e2e.sh cold --track <TC-01|TC-02|TC-03>`  
**Fixture:** `/Users/shafqat/projects/enterprise-grade-test-app`  
**Bootstrap:** **NOT USED** (`bootstrap-orchestrator*.sh` blocked unless `SB_TRI_CRITERIA_ALLOW_BOOTSTRAP=1`)

---

## Summary

| Criterion | Result | WF chain count | Tailoring ops | Net-new artifact | run_id | Evidence |
|-----------|--------|----------------|---------------|------------------|--------|----------|
| **OUT-MULTIWF-01** (TC-01) | **PASS** | 3 (`FEATURE→DEVOPS→RELEASE`) | 2× `insert` (`DR-INSERT-MISSING-EVIDENCE`) | — | `20260705T235400Z-TC-01` | [events](20260705T235400Z-TC-01/orchestrator-events.jsonl), [composition](20260705T235400Z-TC-01/orchestrator-composition-log.jsonl), [session](20260705T235400Z-TC-01/parent-session.log) |
| **OUT-DYNAMIC-01** (TC-02) | **PASS** | 1 (`WF-SILVER-FAST`) | `substitute` + 2× `prune` | — | `20260705T235240Z-TC-02` | [composition](20260705T235240Z-TC-02/orchestrator-composition-log.jsonl), [events](20260705T235240Z-TC-02/orchestrator-events.jsonl), [session](20260705T235240Z-TC-02/parent-session.log) |
| **OUT-NEWWF-01** (TC-03) | **PASS** | 1 (`WF-SILVER-NEW-WORKFLOW`) | 1× `insert` | `WF-POSTURE-AUDIT.md`, `sb-compliance-posture-audit.sh` | `20260705T235316Z-TC-03` | [events](20260705T235316Z-TC-03/orchestrator-events.jsonl), [session](20260705T235316Z-TC-03/parent-session.log) |

**All 3 criteria PASS** on cold runs via `flow-advance.sh` + runtime scheduler (not bootstrap seeding).

---

## TC-01 — Multi-workflow chain

**Vision:** Incident-ready waitlist SaaS (API + SQLite + landing + Docker + canary checklist + ship).

**Runtime path:**
1. `flow-advance silver-feature` → `sb_scheduler_apply_multi_workflow_chain` sets `composer_chain: [devops, release]`
2. Feature `flow_queue` drained via atom `flow-advance` calls
3. `sb_orchestrator_try_advance_composer_chain` → `silver-devops` (15s later) → drain → `silver-release`

**composer_start spacing (anti-bootstrap proof):**

| at | composer | selected_workflow |
|----|----------|-------------------|
| 23:54:00Z | silver-feature | WF-SILVER-FEATURE |
| 23:54:16Z | silver-devops | WF-SILVER-DEVOPS |
| 23:54:32Z | silver-release | WF-SILVER-RELEASE |

---

## TC-02 — Dynamic composition

**Vision:** Observability-only structured logging + README runbook (zero API/UI).

**Runtime path:** `flow-advance silver-fast` → `sb_scheduler_apply_observability_tailoring` records:
- `DR-SUBSTITUTE-LEANER-WORKFLOW` (FEATURE → FAST)
- `DR-PRUNE-SATISFIED-ATOM` on `AF-EXECUTE` and `AF-UI`

Final path ≠ default `WF-SILVER-FEATURE` full queue.

---

## TC-03 — Net-new workflow

**Vision:** SB posture audit bundle (hook manifest JSON + compliance markdown + replay script).

**Runtime path:** `flow-advance silver-new-workflow` → `NEW-WORKFLOW` dispatch event + net-new artifacts:
- `.planning/workflows/WF-POSTURE-AUDIT.md`
- `scripts/sb-compliance-posture-audit.sh`
- `.planning/compliance/posture-audit-report.md`

---

## Honest gaps / limits

| Gap | Status |
|-----|--------|
| Cold harness drains AF queues via hook simulation, not live Cursor Task workers | Acceptable for runtime-path proof; live parent session still recommended for full OUT-ORCH product delta |
| TC-01 product delta (waitlist API commits) not re-verified in this cold harness pass | Prior fixture commits may satisfy `enterprise_e2e_outcome_tri_criteria_product_present`; full product proof needs live worker session |
| Advisory OUT-KM-01 / OUT-TRACE-01 partial | Non-blocking |

---

## Reproduce

```bash
cd /Users/shafqat/projects/silver-bullet/repo
export SB_ROOT="$PWD"
export SB_RUNTIME_PRESERVE_STATE_DIR=1
unset SB_RUNTIME_STATE_DIR   # let each run get isolated dir

bash scripts/sb-tri-criteria-e2e.sh preflight
bash scripts/sb-tri-criteria-e2e.sh cold --track TC-01
bash scripts/sb-tri-criteria-e2e.sh cold --track TC-02
bash scripts/sb-tri-criteria-e2e.sh cold --track TC-03

# Unit tests
bash tests/scripts/test-runtime-multi-workflow-chain.sh
bash tests/scripts/test-runtime-composition-tailoring.sh
bash tests/scripts/test-sb-tri-criteria-e2e.sh
```

**Verify bootstrap blocked:**

```bash
bash .planning/sb-tri-criteria-e2e/scripts/bootstrap-orchestrator-track.sh TC-01
# → exit 3 unless SB_TRI_CRITERIA_ALLOW_BOOTSTRAP=1
```

---

## Code changes (SB repo)

| File | Change |
|------|--------|
| `hooks/lib/orchestrator-scheduler.sh` | `apply_multi_workflow_chain`, `apply_observability_tailoring`, `apply_net_new_workflow_route` |
| `hooks/lib/orchestrator-state.sh` | `try_advance_composer_chain`; scheduler tailoring before workflows.sh gate |
| `scripts/sb-tri-criteria-e2e.sh` | `cold` command |
| `.planning/sb-tri-criteria-e2e/scripts/cold-verify-track.sh` | New cold harness |
| `.planning/sb-tri-criteria-e2e/scripts/bootstrap-orchestrator*.sh` | Gated behind `SB_TRI_CRITERIA_ALLOW_BOOTSTRAP=1` |
