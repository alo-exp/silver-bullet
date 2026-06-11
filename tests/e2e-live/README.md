# Silver Bullet Live Todo-App E2E Suite

This suite runs the real Kay-backed agent by default
against an isolated copy of the
standalone sibling `todo-app` repo and drives one inline full-surface development journey
against the todo app fixture. The journey starts with install UX, moves through
discovery, feature delivery, defect repair, cleanup, and release prep, and
captures any real dissatisfaction through `silver:add` with `todo-app` tagging.

The Kay path uses the MiniMax.io provider credential path with `MiniMax-M3`
and low reasoning.

It is intentionally separate from `tests/live/run-live-tests.sh`:

- `tests/live/run-live-tests.sh` proves hook/agent behavior and release gating
- `tests/e2e-live/run-e2e-live-tests.sh` proves end-to-end development work on
  the todo app fixture itself

When the Kay-only matrix passes, `run-e2e-live-tests.sh` writes the
session-scoped `e2e-live-matrix` marker (`matrix=codex-only`). The
single inline journey also writes an `inline-e2e-matrix` marker
(`matrix=inline-full-surface`). Release creation requires both markers in
addition to the shared hook/agent matrix marker written by
`tests/live/run-live-tests.sh`.

Current scenario:

| Scenario | Purpose |
|----------|---------|
| `test-e2e-live-hook-failures.sh` | Verifies SB hook-trigger failures are enforced live for forbidden edits, commits, release attempts, state tampering, and plugin-boundary writes before allowing a planned edit |
| `test-e2e-live-full-surface-journey.sh` | Fresh plugin install UX, discovery, feature delivery, bug repair, cleanup, and release prep in one live journey |

Fast preflight:

| Script | Purpose |
|--------|---------|
| `dependency-access-preflight.sh` | Verifies the live agent can see SB and the required dependency plugins before the expensive scenario run starts |
| `hook-delivery-preflight.sh` | Verifies the active runtime actually delivers SB hook denies before planning; if this fails, Codex/Claude parity is not established and the E2E runner stops before the longer scenarios |

`run-e2e-live-tests.sh` calls both preflights automatically before the scenario matrix. A runtime must pass plugin-access preflight and hook-delivery preflight before the longer journeys are allowed to run.

Each scenario starts from a fresh workspace copied from the standalone sibling `todo-app` repo and is
cleaned up after completion.

For Kay-agent runs, the suite uses an isolated temporary `KAY_HOME` root
backed by Kay's MiniMax.io provider path before bootstrapping the SB Codex
package. That keeps live E2E installs from changing the user's real `~/.codex`
hook cache.
