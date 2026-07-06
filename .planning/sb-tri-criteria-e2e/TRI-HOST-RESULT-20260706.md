# SB Tri-Criteria — Tri-Host Result Matrix (2026-07-06)

**Harness:** `bash scripts/sb-tri-criteria-e2e.sh live --host <cursor|claude|codex> --track <TC-01|TC-02|TC-03>`  
**Fixture:** `/Users/shafqat/projects/enterprise-grade-test-app`  
**Log audit:** [LOG-AUDIT-20260706.md](LOG-AUDIT-20260706.md)  
**Cursor live rollup:** [LIVE-RESULT-20260706.md](LIVE-RESULT-20260706.md)

---

## Final matrix — **9/9 PASS**

| Host | TC-01 `OUT-MULTIWF-01` | TC-02 `OUT-DYNAMIC-01` | TC-03 `OUT-NEWWF-01` |
|------|------------------------|------------------------|----------------------|
| **cursor** | **PASS** [`20260706T003835Z-TC-01`](runs/20260706T003835Z-TC-01/ledger.json) | **PASS** [`20260706T001004Z-TC-02`](runs/20260706T001004Z-TC-02/ledger.json) | **PASS** [`20260706T001025Z-TC-03`](runs/20260706T001025Z-TC-03/ledger.json) |
| **claude** | **PASS** [`20260706T011110Z-TC-01`](runs/20260706T011110Z-TC-01/ledger.json) | **PASS** [`20260706T010542Z-TC-02`](runs/20260706T010542Z-TC-02/ledger.json) | **PASS** [`20260706T010007Z-TC-03`](runs/20260706T010007Z-TC-03/ledger.json) |
| **codex** | **PASS** [`20260706T012406Z-TC-01`](runs/20260706T012406Z-TC-01/ledger.json) | **PASS** [`20260706T011842Z-TC-02`](runs/20260706T011842Z-TC-02/ledger.json) | **PASS** [`20260706T013211Z-TC-03`](runs/20260706T013211Z-TC-03/ledger.json) |

**Verdict:** All three falsifiable criteria pass on all three hosts with live orchestrator drain + product gates + scorer exit 0.

---

## Execution model by host

| Host | Mechanism | Verify script |
|------|-----------|---------------|
| cursor | Parent orchestrator + Task workers (`composer-2.5`) | `live-verify-track.sh` |
| claude | `/silver:agent-claude` delegation (`--use-print`) + flow-advance drain | `live-verify-track-host.sh claude` |
| codex | `/silver:agent-codex` delegation (`--use-exec`) + flow-advance drain | `live-verify-track-host.sh codex` |

**Anti-bootstrap:** `bootstrap-orchestrator*.sh` NOT used on any canonical run.

---

## Fixture branches (per track)

| Track | Branch | Key artifact |
|-------|--------|--------------|
| TC-01 | `feature/tc01-waitlist-saas` | waitlist API, Docker Compose, landing (`e69f904`) |
| TC-02 | `feature/tc02-observability-runbook` | structured logging + README runbook (`d07e6a0`) |
| TC-03 | `feature/tc03-posture-audit` | `WF-POSTURE-AUDIT.md` + replay scripts (`8e2f78c`) |

---

## Honest limits

| Item | Status |
|------|--------|
| Advisory `OUT-KM-01` / `OUT-TRACE-01` | partial (non-blocking) on most runs |
| Claude/Codex multi-WF inside one WF | Host agents may chain skills internally; composer spacing from scheduler events |
| Cold harness | Regression gate only — see [UNIFIED-RUN-20260706](runs/UNIFIED-RUN-20260706/RESULT.md) |

---

## Reproduce

```bash
cd /Users/shafqat/projects/silver-bullet/repo
export SB_ROOT="$PWD"
export SB_RUNTIME_PRESERVE_STATE_DIR=1
export SB_TRI_CRITERIA_WORK_DIR=/Users/shafqat/projects/enterprise-grade-test-app

for host in cursor claude codex; do
  for track in TC-01 TC-02 TC-03; do
    bash scripts/sb-tri-criteria-e2e.sh live --host "$host" --track "$track"
  done
done
```
