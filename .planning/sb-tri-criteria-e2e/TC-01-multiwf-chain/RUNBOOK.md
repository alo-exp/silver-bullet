# TC-01 — Runbook (Multi-Workflow Chain)

## Preflight

```bash
cd /Users/shafqat/projects/silver-bullet/repo
export SB_ROOT="$PWD"
bash scripts/sb-tri-criteria-e2e.sh preflight --track TC-01
```

## Start

```bash
export SB_MINIMAL_INTENT_WORK_DIR=/Users/shafqat/projects/enterprise-grade-test-app
bash scripts/sb-tri-criteria-e2e.sh start --track TC-01 --dry-run
bash scripts/sb-tri-criteria-e2e.sh start --track TC-01
```

Operator: open Cursor **parent orchestrator** in `work_dir`, paste vision from `runs/<id>/vision.md` only.

## Score

```bash
# Cold verify (recommended — no bootstrap)
bash scripts/sb-tri-criteria-e2e.sh cold --track TC-01

# Or manual live session + score
bash scripts/sb-tri-criteria-e2e.sh score --run <run-id> --track TC-01
```

Capture `orchestrator-events.jsonl` from `$SB_RUNTIME_STATE_DIR` before scoring if session state may reset.

## Pass bar

`OUT-MULTIWF-01` + shared blocking outcomes → `VERDICT: PASS`
