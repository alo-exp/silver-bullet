# Launch Dogfood — todo-app (2026-06-14)

**Workspace:** `/Users/shafqat/projects/todo-app` (sibling repo; not under `projects/todo-app` in SB source tree)

## Setup

| Step | Result |
|------|--------|
| Archive stale `.planning/` | Moved to `.planning.archive-20260614` |
| Replace `silver-bullet.md` | Stamped from `templates/silver-bullet.md.base` (v0.40.0 contract) |
| Replace `.silver-bullet.json` | From template; `sb_initiated: true`, `config_version: 0.40.0` |
| Copy `docs/workflows/*.md` | full-dev-cycle + devops-cycle |
| Copy `scripts/workflows.sh` | Required for `flow-advance.sh` auto workflow tracker |
| Host plugin cache | Untouched (per constraint) |

## Simulated intent

> Add filter to show only active todos with persistence

Routed as **silver:feature** (brownfield Node/Express todo app; checkbox persistence already exists).

## Orchestration evidence

| Surface | Worked? | Evidence |
|---------|---------|----------|
| `sb_initiated` gate | Yes | Hooks active only after bootstrap set `true` |
| `outcomes-check.sh` | Yes | UserPromptSubmit injected "Outstanding per-prompt outcomes" |
| `flow-advance.sh` | Yes | `orchestrator.json` seeded; workflow `20260614T095753Z-40136a-silver-feature` created |
| Auto `workflows.sh start` | Yes | `.planning/workflows/<id>.md` created without user composition approval |
| Flow queue | Yes | `FLOW-QUALITY-GATE` → … → `silver-ship` queued |
| User decision gates | None | No blocking clarify prompts in hook-only simulation |

## Gaps observed

1. **Init does not copy `scripts/workflows.sh` to downstream projects** — flow-advance silently no-ops without it; init scaffold should bundle or document dependency.
2. **Dogfood workspace path** — E2E helpers use sibling `../todo-app`, not `repo/projects/todo-app`.
3. **Host agent still required** — hooks chain and record; they do not invoke skills (vision gap unchanged).
4. **Tier-2 hooks** — Cursor dogfood depends on host hooks merged; not verified in this session.

## Fixes filed in source repo

- `runtime-paths.sh`: `SB_RUNTIME_PRESERVE_STATE_DIR=1` for test/dogfood state pinning
- L-02 `core-rules.sha256` + integrity lib
- L-03 centralized `legacy-gsd-alias.sh`
- Test fixes: `sb_initiated` in outcomes test, PLAN-only override in planning-file-guard test

---

## E2E dogfood session — 2026-06-14 (full feature delivery)

**Intent:** Add active (incomplete) todos filter with localStorage persistence  
**Route:** `silver:feature` → full-dev-cycle (autonomous)  
**Workflow ID:** `20260614T100342Z-2cdc16-silver-feature` (archived)

### Feature shipped: YES

| Layer | Change |
|-------|--------|
| API | `GET /api/todos?active=true` → `WHERE completed = 0` |
| UI | "Show Active" filter button; mutually exclusive with overdue |
| Persistence | `todo-app-filter` localStorage key (`all` \| `active` \| `overdue`) |
| Tests | 51/51 Jest green (4 new tests) |

**todo-app commits:** `e6775a8` (RED), `12eea3a` (GREEN)

### SB flows invoked (state file evidence)

```
silver-feature → silver-quality-gates → silver-context → silver-plan
→ silver-execute → silver-verify → verify-tests
→ silver-review-request → silver-review → silver-review-triage
→ silver-secure → silver-validate → silver-branch-finish
→ silver-completion-audit → tdd → silver-ship
```

### Hooks observed

| Hook | Result | Notes |
|------|--------|-------|
| `record-skill.sh` | Pass | All skills recorded to `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/state` |
| `flow-advance.sh` | Pass | Composer started workflow; atoms chained "Next flow" messages |
| `outcomes-check.sh` | Pass | UserPromptSubmit seeded outcomes; Stop exited 0 after verify-tests |
| `stop-check.sh` | Pass | No block after full `required_deploy` set recorded |
| `planning-file-guard.sh` | Not triggered | Phase artifacts under `.planning/phases/` (not guarded ROADMAP/STATE) |

### Workflow tracker

| Flow row | Status |
|----------|--------|
| QUALITY GATE | complete (after fix; was stuck pending pre-fix) |
| CONTEXT → VALIDATE | complete |
| Archived | `.planning/workflows/.archive/20260614T100342Z-2cdc16-silver-feature.md` |

### Vision gaps (still open)

1. **Init does not bundle `scripts/workflows.sh`** — manual copy required for flow-advance
2. **Hooks record skills; host agent must invoke them** — no autonomous skill execution
3. **Stale workflow** `20260614T095753Z-40136a-silver-feature.md` left from hook-only sim (orphan)

### Bug fixed this session (silver-bullet repo)

**QUALITY GATE / QUALITYGATE mismatch** — `workflows.sh start` stripped spaces from flow names (`QUALITY GATE` → `QUALITYGATE`) but `flow-advance` completed with spaced name → row stuck `pending`.

- **Fix:** `scripts/workflows.sh` — trim-only on start; space-normalized match in `complete-flow`
- **Test:** `tests/hooks/test-flow-advance.sh` — asserts quality gate row completes
- **Commit:** `9d4d35e9`

### Locked decisions

None — feature scope inferred from codebase + prior dogfood intent; no user checkpoint required.

### Environment note

`npm rebuild better-sqlite3` required on host Node 22+ (NODE_MODULE_VERSION mismatch) before tests could run.

---

## Multi-session dogfood — todo-app v2 intent (2026-06-14)

**Intent (orchestrator-intent.txt):** Build todo app v2 — filters, persistence, milestone ship  
**Route:** `silver:spec` → `silver:feature` (full-software queue)

### Session simulation design

| Session | Simulated work | Expected persisted state |
|---------|----------------|------------------------|
| 1 | User prompt seeds intent; `silver:spec` + `silver:plan` recorded | `orchestrator.json` queue, `orchestrator-directive.json` → next skill |
| 2 | New SessionStart (branch unchanged) | State + directive survive; `flow-advance` continues queue |

### Mechanism verified (in-repo)

- `orchestrator.json` + `orchestrator-directive.json` under `${SB_RUNTIME_STATE_DIR}/` persist across SessionStart when branch unchanged (session-start preserves state on same branch).
- `prompt-reminder.sh` re-injects directive each turn.
- `orchestrator-directive-guard.sh` blocks Edit until directive skill recorded.

### Live todo-app run

**Status:** Procedure ready; execute on `/Users/shafqat/projects/todo-app` with `SB_RUNTIME_PRESERVE_STATE_DIR=1` between simulated sessions. Append session logs when run completes.

### Init note (P5)

`silver:init` scaffold (`skills/silver-init/references/scaffold-steps.md`) copies `scripts/workflows.sh` — required for `flow-advance` auto tracker.
