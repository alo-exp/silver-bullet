# SB Tri-Criteria — Live Validation Plan

**Date:** 2026-07-06  
**Authority:** Supersedes cold-only [UNIFIED-RUN-20260706/RESULT.md](runs/UNIFIED-RUN-20260706/RESULT.md) for confidence claims  
**Harness:** `bash scripts/sb-tri-criteria-e2e.sh live --track <TC-01|TC-02|TC-03>`  
**Fixture:** `/Users/shafqat/projects/enterprise-grade-test-app`

---

## What "100% confidence" means

Silver Bullet can autonomously **chain**, **tailor**, and **author** workflows when **all** of the following hold in a **single live Cursor session** per track:

| Gate | Requirement |
|------|-------------|
| **Live orchestrator** | Parent reads `orchestrator-directive.json`; spawns **Task workers** (`model: composer-2.5`); **no** parent inline Edit/Write on product source |
| **Runtime path** | `flow-advance.sh` + `orchestrator-scheduler.sh` record composition/events — **not** `bootstrap-orchestrator*.sh` unless documenting failure |
| **Product delta** | Substantive commit on fixture branch with verifiable artifact (API, runbook, compliance bundle) |
| **Scorer green** | `sb-tri-criteria-e2e.sh score` exits 0 on blocking outcomes |
| **Anti-bootstrap** | ≥3 `composer_start` events spaced ≥5s apart (TC-01); not 3 in <5s |
| **Tests** | Targeted orchestrator + tri-criteria tests pass after runtime changes |

Cold harness (`cold --track`) remains a **regression gate** only — it does **not** satisfy live confidence alone.

---

## Per-criterion pass/fail gates

### TC-01 — Multi-workflow chain (`OUT-MULTIWF-01`)

| Check | Pass | Fail |
|-------|------|------|
| Distinct `WF-SILVER-*` | ≥3 in composition log / events | Single workflow or AF-only chain |
| `composer_start` spacing | ≥5s between first and third event | 3 events in <5s (bootstrap seed) |
| Queue drain | `flow_queue` empty at end of each composer | Stalled queue |
| Product | `api/src/*waitlist*`, Docker Compose, landing page, canary checklist | Health-check only |
| Branch | `feature/tc01-waitlist-saas` commit SHA recorded | No commit |

### TC-02 — Dynamic composition (`OUT-DYNAMIC-01`)

| Check | Pass | Fail |
|-------|------|------|
| Composition ops | ≥2 distinct ops with valid `catalog_rule_ref` | Default FEATURE queue unchanged |
| Tailoring | `substitute` + `prune` recorded (`DR-SUBSTITUTE-LEANER-WORKFLOW`, `DR-PRUNE-SATISFIED-ATOM`) | Operator manually `/silver:fast` |
| Product | Structured JSON logging + `correlation_id` + README runbook section | Badge-only or no doc change |
| Path | Final queue ≠ full `WF-SILVER-FEATURE` | Full feature pipeline executed |

### TC-03 — Net-new workflow (`OUT-NEWWF-01`)

| Check | Pass | Fail |
|-------|------|------|
| Dispatch | `NEW-WORKFLOW` in `orchestrator-events.jsonl` | Tailoring existing WF only |
| Artifact | `.planning/workflows/WF-POSTURE-AUDIT.md` + replay script + compliance report | Stub jq-only script |
| Product | `scripts/sb-compliance-posture-audit.sh` emits hook manifest JSON | Empty placeholder |
| Verify | `scripts/sb-verify-posture-audit.sh` passes cold replay | No verification path |

---

## Execution model (required)

```
Parent (Cursor, orchestrator_mode=parent)
  └─ read orchestrator-directive.json
  └─ Task worker (composer-2.5) per atomic flow
       └─ implement product delta in fixture work_dir
  └─ flow-advance advances queue / composer_chain
  └─ capture orchestrator-events.jsonl + composition log
  └─ score → ledger verdict PASS + live_session_run: true
```

**Environment:**

```bash
export SB_ROOT=/Users/shafqat/projects/silver-bullet/repo
export SB_RUNTIME_PRESERVE_STATE_DIR=1
export SB_TRI_CRITERIA_WORK_DIR=/Users/shafqat/projects/enterprise-grade-test-app
```

**Per track:**

```bash
bash scripts/sb-tri-criteria-e2e.sh preflight --track TC-01
bash scripts/sb-tri-criteria-e2e.sh live --track TC-01
# repeat TC-02, TC-03
bash tests/scripts/test-runtime-multi-workflow-chain.sh
bash tests/scripts/test-runtime-composition-tailoring.sh
bash tests/scripts/test-sb-tri-criteria-e2e.sh
```

---

## Anti-patterns (automatic FAIL)

| Anti-pattern | Detection |
|--------------|-----------|
| Bootstrap seeding 3 `composer_start` in <5s | `jq` timestamp delta on events file |
| Single WF labeled "multi-workflow" | `distinct_workflow_ids < 3` |
| Cold-only proof, no product commits | `live_session_run: false` or missing fixture SHA |
| Parent inline product edits | Session log lacks `Task worker`; parent Edit on `api/` |
| Fabricated composition log | `catalog_rule_ref` not in `docs/apo-catalog.json` |
| TC-01 without waitlist delta | No `*waitlist*` files on branch |

---

## Evidence package (per track)

| Artifact | Path |
|----------|------|
| Run ledger | `.planning/sb-tri-criteria-e2e/runs/<run_id>/ledger.json` |
| Session log | `runs/<run_id>/parent-session.log` |
| Events | `runs/<run_id>/orchestrator-events.jsonl` |
| Composition | `runs/<run_id>/orchestrator-composition-log.jsonl` |
| Product SHA | fixture `git rev-parse HEAD` on feature branch |
| Summary | `.planning/sb-tri-criteria-e2e/LIVE-RESULT-20260706.md` |

---

## Related

- [UNIFIED-DESIGN.md](UNIFIED-DESIGN.md) — vision paragraphs
- [DESIGN.md](DESIGN.md) — falsifiable definitions
- [CURSOR-MULTIWF-CRITERIA.md](CURSOR-MULTIWF-CRITERIA.md) — multi-WF bar
