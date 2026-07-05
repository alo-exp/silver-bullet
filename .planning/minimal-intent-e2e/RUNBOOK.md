# Minimal-Intent E2E — Runbook

## Prerequisites

| Requirement | Check |
|-------------|-------|
| Cursor with parent orchestrator | `orchestrator_mode: parent` in config |
| SB checkout | `SB_ROOT` → silver-bullet repo |
| Test fixture | `enterprise-grade-test-app` clone |
| Structural harness | `bash scripts/minimal-intent-autonomous-e2e.sh preflight` |

## Phase 0 — Orientation

```bash
cd /Users/shafqat/projects/silver-bullet/repo
graphify query "minimal intent orchestrator parent autonomous development lifecycle"
```

## Phase 1 — Preflight (structural only)

```bash
export SB_ROOT=/Users/shafqat/projects/silver-bullet/repo
bash scripts/minimal-intent-autonomous-e2e.sh preflight
```

Verifies: matrix JSON, driver executable, fixture vision/prefs, structural tests, orchestrator hooks on PATH.

**Preflight PASS does not mean the live test has been run.**

## Phase 2 — Start (live — operator)

```bash
export SB_ROOT=/Users/shafqat/projects/silver-bullet/repo
export SB_MINIMAL_INTENT_WORK_DIR=/Users/shafqat/projects/enterprise-grade-test-app

# Prepare run dir (dry-run)
bash scripts/minimal-intent-autonomous-e2e.sh start --row MI-01 --dry-run

# Live: operator opens Cursor parent session in work_dir with vision only
bash scripts/minimal-intent-autonomous-e2e.sh start --row MI-01
```

Harness actions:

1. Creates `runs/<run-id>/` with `vision.md`, `prefs.json` copy, `ledger.json`
2. Writes `INTENT-SEED.txt` for operator to paste or symlink into `orchestrator-intent.txt`
3. Prints session checklist — **operator** starts `/silver` or `/silver:feature` in parent mode

### Operator session rules

- Provide **only** the vision paragraph (+ prefs if any) at start
- Do not micro-manage worker prompts
- Intervene only on `decision_class: blocking` (credentials, irreversible forks)
- Capture parent session log to `runs/<run-id>/parent-session.log` when complete

## Phase 3 — Score

```bash
bash scripts/minimal-intent-autonomous-e2e.sh score --run <run-id>
```

Requires `parent-session.log` (or `--log PATH`). Reuses enterprise outcome scorer where applicable.

## Phase 4 — Evidence

1. Fill `runs/<run-id>/result.md`
2. agentmemory: vision, verdict, install_fp, orchestrator queue snapshot
3. `graphify update .` in SB repo and fixture if modified
