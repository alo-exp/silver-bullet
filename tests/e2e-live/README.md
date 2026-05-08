# Silver Bullet Live Todo-App E2E Suite

This suite runs the real Claude and Codex CLIs against an isolated copy of
`tests/test-app/` and drives realistic development episodes against the todo
app fixture. It now starts with an install-UX scenario so the end-user plugin
installation flow is exercised before feature work begins.

It is intentionally separate from `tests/live/run-live-tests.sh`:

- `tests/live/run-live-tests.sh` proves hook/runtime behavior and release gating
- `tests/e2e-live/run-e2e-live-tests.sh` proves end-to-end development work on
  the todo app fixture itself

When the full Claude+Codex matrix passes, `run-e2e-live-tests.sh` writes the
session-scoped `e2e-live-matrix` marker (`matrix=full-claude-codex`). Release
creation requires that marker in addition to the shared hook/runtime matrix
marker written by `tests/live/run-live-tests.sh`.

Current scenarios:

| Scenario | Purpose |
|----------|---------|
| `test-e2e-live-install-ux.sh` | Fresh plugin install UX, install-state verification, and initial scaffold |
| `test-e2e-live-init-and-feature.sh` | Fresh SB init plus a feature build that adds a clear-completed action |
| `test-e2e-live-regression-repair.sh` | Injected regression repair through the bugfix workflow |
| `test-e2e-live-release-prep.sh` | Release prep, changelog creation, and local tag creation |

Each scenario starts from a fresh workspace copied from `tests/test-app/` and is
cleaned up after completion.
