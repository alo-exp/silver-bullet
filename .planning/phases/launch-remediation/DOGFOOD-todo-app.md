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
