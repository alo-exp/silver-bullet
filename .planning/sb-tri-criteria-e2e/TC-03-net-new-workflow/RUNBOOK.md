# TC-03 — Runbook (Net-New Workflow)

## Preflight

```bash
export SB_ROOT=/Users/shafqat/projects/silver-bullet/repo
bash scripts/sb-tri-criteria-e2e.sh preflight --track TC-03
```

## Start (Cursor parent — default)

```bash
export SB_MINIMAL_INTENT_WORK_DIR=/Users/shafqat/projects/enterprise-grade-test-app
bash scripts/sb-tri-criteria-e2e.sh start --track TC-03
```

## Start (agent-claude alternate)

```bash
export SB_TRI_CRITERIA_HOST=agent-claude
bash scripts/sb-tri-criteria-e2e.sh start --track TC-03
# Then: bash scripts/agent-claude-autonomous-test.sh start --row <delegated>
```

## Score

```bash
bash scripts/sb-tri-criteria-e2e.sh score --run <run-id> --track TC-03
```

Check NEW-WORKFLOW dispatch:

```bash
jq -s '[.[] | select(.type=="dispatch" and (.payload.worker_template=="NEW-WORKFLOW" or .payload.skill=="silver-new-workflow"))]' \
  "$SB_RUNTIME_STATE_DIR/orchestrator-events.jsonl"
```

## Pass bar

`OUT-NEWWF-01` + shared blocking → `VERDICT: PASS`
