# SB Tri-Criteria E2E — Unified Design (creative complex goals)

**Date:** 2026-07-06  
**Harness:** [`scripts/sb-tri-criteria-e2e.sh`](../../scripts/sb-tri-criteria-e2e.sh)  
**Cold verify:** [`.planning/sb-tri-criteria-e2e/scripts/cold-verify-track.sh`](scripts/cold-verify-track.sh)

---

## Success bar (all three)

| Criterion | Outcome | Cold proof path |
|-----------|---------|-----------------|
| Multi-workflow chain | `OUT-MULTIWF-01` | ≥3 distinct `WF-SILVER-*` via `flow-advance` + `composer_chain` advance |
| Dynamic composition | `OUT-DYNAMIC-01` | Runtime `substitute`/`prune` with valid `catalog_rule_ref` |
| Net-new workflow | `OUT-NEWWF-01` | `NEW-WORKFLOW` dispatch + custom workflow artifact |

**Forbidden:** `bootstrap-orchestrator*.sh` seeding 3 `composer_start` events in seconds. Bootstrap is fixture-prep only (`SB_TRI_CRITERIA_ALLOW_BOOTSTRAP=1`).

---

## TC-01 — Multi-workflow chain (`OUT-MULTIWF-01`)

### Vision paragraph (creative complex goal)

> Deliver an **incident-ready waitlist SaaS slice** in the fixture app: tenant-scoped **waitlist API** (`POST /waitlist`, `GET /waitlist/stats`) with **SQLite persistence**, a **minimal landing page** wired to the API, **Docker Compose** for local runtime, a **canary deploy checklist** in `.planning/`, and **ship readiness** (branch + PR or documented waiver). Use Silver Bullet autonomous parent orchestrator mode — chain the catalog workflows required (product feature, DevOps/runtime, release/ship) without asking me to pick workflows.

**Why it forces ≥3 workflows:** API + landing = `WF-SILVER-FEATURE`; Docker/canary = `WF-SILVER-DEVOPS`; ship/PR = `WF-SILVER-RELEASE`. Cannot complete in one composer pass.

**Runtime mechanism:** `sb_scheduler_detect_multi_capability_intent` → `sb_scheduler_apply_multi_workflow_chain` sets `composer_chain` → `sb_orchestrator_try_advance_composer_chain` on queue drain.

**Evidence:** `orchestrator-events.jsonl` with ≥3 `composer_start` events spaced by workflow drain; composition log `DR-INSERT-MISSING-EVIDENCE` insert ops.

---

## TC-02 — Dynamic composition (`OUT-DYNAMIC-01`)

### Vision paragraph (creative complex goal)

> Harden **observability-only** for the fixture API: add **structured JSON logging** with request `correlation_id`, propagate it through existing middleware, and author a **README runbook** section documenting log shape, local tail commands, and on-call triage — **zero API routes, zero UI, no database migrations, no Docker changes**. **Do not** run the full feature development pipeline; tailor to the smallest correct catalog path.

**Why it forces tailoring:** Ambiguous "harden API" routes to `WF-SILVER-FEATURE`; correct path is **substitute** to `WF-SILVER-FAST` and **prune** `AF-EXECUTE` / `AF-UI` per observability-only constraints.

**Runtime mechanism:** `sb_scheduler_apply_observability_tailoring` on `silver-fast` composer_start via `flow-advance.sh`.

**Evidence:** `orchestrator-composition-log.jsonl` with ≥2 ops (`substitute` + `prune`), valid `DR-SUBSTITUTE-LEANER-WORKFLOW` + `DR-PRUNE-SATISFIED-ATOM`.

---

## TC-03 — Net-new workflow (`OUT-NEWWF-01`)

### Vision paragraph (creative complex goal)

> Produce an **SB posture audit bundle** for this fixture repo: a `scripts/` replay script that emits **hook manifest JSON** (installed hook versions, `recommended_tools` opt-in from `.silver-bullet.json`, last `graphify update` timestamp), a **one-page compliance markdown** under `.planning/compliance/`, and a **replay verification script** operators can re-run cold. **No existing Silver Bullet workflow** covers this exact posture-audit deliverable; compose a **new reusable workflow** and execute it once.

**Why it forces net-new:** No `WF-SILVER-*` matches posture-audit bundle authoring; requires `silver-new-workflow` → `NEW-WORKFLOW` worker → `.planning/workflows/WF-POSTURE-AUDIT.md`.

**Runtime mechanism:** `sb_scheduler_apply_net_new_workflow_route` + `flow-advance silver-new-workflow`.

**Evidence:** `orchestrator-events.jsonl` `dispatch` with `worker_template: NEW-WORKFLOW`; `scripts/sb-compliance-posture-audit.sh` + `.planning/compliance/posture-audit-report.md`.

---

## Cold reproduction

```bash
cd /Users/shafqat/projects/silver-bullet/repo
export SB_ROOT="$PWD"
export SB_RUNTIME_PRESERVE_STATE_DIR=1

# Preflight
bash scripts/sb-tri-criteria-e2e.sh preflight

# Per track
bash scripts/sb-tri-criteria-e2e.sh cold --track TC-01
bash scripts/sb-tri-criteria-e2e.sh cold --track TC-02
bash scripts/sb-tri-criteria-e2e.sh cold --track TC-03
```

---

## Related

- [DESIGN.md](DESIGN.md) — detailed falsifiable definitions
- [CURSOR-MULTIWF-CRITERIA.md](CURSOR-MULTIWF-CRITERIA.md)
- [TC-01 RUNBOOK](TC-01-multiwf-chain/RUNBOOK.md)
