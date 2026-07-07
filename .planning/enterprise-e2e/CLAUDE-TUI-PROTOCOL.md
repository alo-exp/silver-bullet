# Claude TUI Supervised Protocol — Enterprise E2E Matrix

Operator protocol for executing 22 supervised Claude TUI workflow sessions against `alo-exp/enterprise-grade-test-app`. Evidence lands in round ledgers under this directory.

**Working directory for SB fixes:** `/Users/shafqat/projects/silver-bullet/repo`  
**Working directory for Claude TUI:** `/Users/shafqat/projects/enterprise-grade-test-app`

---

## Prerequisites (each round)

1. SB repo on intended release commit; `bash tests/run-all-tests.sh` green.
2. `bash scripts/install-claude.sh` from SB repo checkout (local marketplace).
3. Test app cloned at `/Users/shafqat/projects/enterprise-grade-test-app`; pin baseline SHA in ledger header.
4. **Graphify** (SB repo): `graphify update .` after SB code edits; graph current before round start.
5. **agentmemory:** server healthy (`curl -sf http://localhost:3111/agentmemory/health`); MCP connected for Claude.

---

## Preflight (before Session 0)

```bash
cd /Users/shafqat/projects/silver-bullet/repo
bash tests/e2e-live/hook-delivery-preflight.sh   # SB_LIVE_AGENT=claude when set
```

Confirm hook delivery path for Claude host. Enable debug dump if needed:

```bash
export SB_LIVE_DEBUG_DUMP=1
```

---

## Graphify — mandatory per session

Before opening Claude TUI for each workflow row:

```bash
cd /Users/shafqat/projects/silver-bullet/repo
graphify query "<workflow slug> routes hooks skills orchestrator"
```

Record the query scope string in the ledger `graphify_query_ref` column (e.g. `graphify query "silver-feature currency field hooks"`).

After SB code fixes during the round: `graphify update .`

At test-app init (Session 0): after `/silver:init`, in test app CWD run `graphify update .` when Graphify opted in.

---

## agentmemory — mandatory per session

1. Start server if needed: `nohup agentmemory > ~/.agentmemory/server.log 2>&1 &`
2. Confirm MCP wired for Claude (`agentmemory connect claude-code`).
3. After each workflow session, export session summary via agentmemory MCP.
4. Record export path or session ID in ledger `agentmemory_export_ref` column.

**Retrieve prior context via Graphify**, not by re-reading raw agentmemory dumps.

---

## Session 0 — Bootstrap (`/silver:init`)

```bash
cd /Users/shafqat/projects/enterprise-grade-test-app
claude   # TUI, CWD = test app
```

In Claude TUI:

1. Run `/silver:init` — verify **independent** SB bootstrap (no SB-repo dogfood files copied).
2. Opt in **Graphify** and **agentmemory** (`enabled_by_user: true` in `.silver-bullet.json`).
3. Confirm `silver-bullet.md` and `.silver-bullet.json` created locally; **do not** commit SB init artifacts to GitHub.
4. `graphify update .` in test app when Graphify enabled.

**Pass:** init completes; hooks active; recommended tools opted in per operator choice; no pre-seeded SB config from plugin repo.

---

## Sessions 1–22 — Workflow matrix

One Claude TUI session (or logical segment) per row in `enterprise-grade-test-app/docs/WORKFLOW_E2E_MATRIX.md`.

### Per-session checklist

1. `graphify query` for the row's routes, hooks, and skills (SB repo).
2. Open Claude TUI with CWD = test app directory.
3. Paste the **prompt card** from the matrix (natural user language — not test jargon).
4. Monitor in parallel terminal:
   - Claude hook delivery (`~/.codex/...`; use debug-dump when `SB_LIVE_DEBUG_DUMP=1`)
   - `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/state` — required skills recorded
   - `.planning/workflows/*.md` — Flow Log CSV advancement
   - `.planning/orchestrator-composition-log.jsonl` — queue progression
5. Adjudicate pass/fail against criteria below.
6. Log row in `ROUND-N-LEDGER.md`; agentmemory export; graphify query ref.

### Internal workflows (rows 21–22)

`post-exec-gates` and `validate-substep` are **not** standalone sessions. Exercise them inside parent sessions (feature row 3, bugfix row 4). Ledger notes which parent session triggered them and where gate/substep evidence appears.

---

## Pass criteria (per workflow)

- Correct route/skill invoked for the prompt
- Orchestrator **parent** does not implement product code inline
- Required skills recorded in state file
- Flow Log atoms advance in workflow markdown
- Expected artifacts created at matrix evidence paths
- No hook blocks on legitimate operator/agent actions
- CI-relevant changes keep `npm test` green when applicable

---

## Fail criteria

- Wrong route or skill for stated intent
- Skipped mandatory skills (stop-check / completion-audit would block delivery)
- Parent agent implements code instead of delegating to orchestrator/workers
- Hook false-positive (blocks legitimate action) or false-negative (allows bypass)
- Orchestrator queue stall or composition log gap
- Autonomy breakdown (worker never spawned, flow log stuck)

On fail: file defect via `/silver:add` with label **`enterprise-test-app`**; fix SB in plugin repo; commit; re-install Claude plugin; re-run failed row only after fix is installed.

---

## Round structure

### Round start

1. `graphify query` repo-wide enterprise E2E scope
2. Full review-fix-ladder (8 rungs, 2 consecutive clean verify passes each)
3. `bash tests/run-all-tests.sh`
4. `bash scripts/install-claude.sh`
5. Execute Sessions 0 + 1–22

### Round end — clean definition

A round is **clean** only when:

1. Ladder: all 8 rungs complete with 2 consecutive clean verify passes each
2. Unit/integration: `bash tests/run-all-tests.sh` → 0 failures
3. Live matrix: all 22 workflow rows **Pass** in ledger (each with `graphify_query_ref` + `agentmemory_export_ref`)
4. Graphify: `graphify-out/graph.json` current for SB repo post-fixes
5. No open MUST-FIX issues from the round

Minimum **2 consecutive clean rounds** before release tag.

---

## Evidence artifacts

| Artifact | Location |
|----------|----------|
| Round ledger | `.planning/enterprise-e2e/ROUND-N-LEDGER.md` |
| Matrix (prompt cards) | `enterprise-grade-test-app/docs/WORKFLOW_E2E_MATRIX.md` |
| Hook state | `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/state` |
| Flow logs | `enterprise-grade-test-app/.planning/workflows/*.md` |
| Orchestrator log | `enterprise-grade-test-app/.planning/orchestrator-composition-log.jsonl` |

---

## Model freeze

Record Claude model ID per row in ledger. Keep model constant within a round unless a failure requires model change (note in Issues column).
