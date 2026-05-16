# Silver Bullet Live Todo-App E2E Suite

This suite runs the real Claude CLI and the Kay-backed agent
against an isolated copy of the
standalone sibling `test-todo-app` repo and drives one inline full-surface development journey
against the todo app fixture. The journey starts with install UX, moves through
discovery, feature delivery, defect repair, cleanup, and release prep, and
captures any real dissatisfaction through `silver:add` with `todo-app` tagging.

The Kay path is pinned to MiniMax M2.7.

It is intentionally separate from `tests/live/run-live-tests.sh`:

- `tests/live/run-live-tests.sh` proves hook/agent behavior and release gating
- `tests/e2e-live/run-e2e-live-tests.sh` proves end-to-end development work on
  the todo app fixture itself

When the full Claude+Codex matrix passes, `run-e2e-live-tests.sh` writes the
session-scoped `e2e-live-matrix` marker (`matrix=full-claude-codex`). The
single inline journey also writes an `inline-e2e-matrix` marker
(`matrix=inline-full-surface`). Release creation requires both markers in
addition to the shared hook/agent matrix marker written by
`tests/live/run-live-tests.sh`.

Current scenario:

| Scenario | Purpose |
|----------|---------|
| `test-e2e-live-full-surface-journey.sh` | Fresh plugin install UX, discovery, feature delivery, bug repair, cleanup, and release prep in one live journey |

Fast preflight:

| Script | Purpose |
|--------|---------|
| `dependency-access-preflight.sh` | Verifies the live agent can see SB and the required dependency plugins before the expensive scenario run starts |

`run-e2e-live-tests.sh` calls the preflight automatically before each agent/scenario run, so you can also run the preflight script directly when you just want the cheap plugin-access check.

Each scenario starts from a fresh workspace copied from the standalone sibling `test-todo-app` repo and is
cleaned up after completion.

For Kay-agent runs, the suite uses an isolated temporary `KAY_HOME` root
before bootstrapping the SB Codex package. That keeps live E2E installs from
changing the user's real `~/.codex` hook cache.
