## Task

Add a `GET /api/health` endpoint to the test app that returns JSON `{"status":"ok"}`.

Use **Silver Bullet autonomous mode** on this project. Route via `/silver` or `/silver:feature` as appropriate. Work autonomously — use `/silver:clarify` only if intent is genuinely ambiguous; do not ask the operator except for blocking credentials or locked product decisions.

## Acceptance criteria

- [ ] `GET /api/health` returns `{"status":"ok"}` (or equivalent documented contract)
- [ ] Tests run and pass (or new test added for the endpoint)
- [ ] Commit on branch `feature/agent-claude-auto-c01` with conventional message
- [ ] Session log shows autonomous / orchestrator markers without babysitting

## Constraints

- Work directory: enterprise-grade-test-app root
- Do not modify silver-bullet repo unless fixing a blocking harness issue in SB_ROOT
- Do not set `SB_E2E_ENTERPRISE_MATRIX` or matrix ledger env vars
- SB routes: use `/silver:*` or `[$silver]` picker syntax in Claude

## Evidence required

- Commit SHA
- Test command + result
- Files touched (paths)
