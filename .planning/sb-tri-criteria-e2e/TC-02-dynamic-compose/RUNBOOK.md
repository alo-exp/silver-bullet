# TC-02 — Runbook (Dynamic Composition)

## Preflight

```bash
export SB_ROOT=/Users/shafqat/projects/silver-bullet/repo
bash scripts/sb-tri-criteria-e2e.sh preflight --track TC-02
```

## Start

```bash
export SB_MINIMAL_INTENT_WORK_DIR=/Users/shafqat/projects/enterprise-grade-test-app
bash scripts/sb-tri-criteria-e2e.sh start --track TC-02
```

**Trap:** Vision sounds like "add feature" — scorer expects **substitute/prune**, not full `WF-SILVER-FEATURE`.

## Score

```bash
bash scripts/sb-tri-criteria-e2e.sh score --run <run-id> --track TC-02
```

Verify composition log before state dir cleanup:

```bash
jq -s '.[] | .operations[]? | {op, catalog_rule_ref, rationale}' \
  "$SB_MINIMAL_INTENT_WORK_DIR/.planning/orchestrator-composition-log.jsonl"
```

## Pass bar

`OUT-DYNAMIC-01` + shared blocking → `VERDICT: PASS`
