# Silver Bullet Enterprise Live E2E Suite

This suite runs the real Kay-backed agent by default against an isolated copy of the
standalone sibling `enterprise-grade-test-app` repo. The **primary release gate** for
full workflow coverage is the **Claude supervised matrix** documented in
`.planning/enterprise-e2e/CLAUDE-TUI-PROTOCOL.md` and
`enterprise-grade-test-app/docs/WORKFLOW_E2E_MATRIX.md`.

The Kay path uses the MiniMax.io provider credential path with `MiniMax-M3`
and low reasoning.

It is intentionally separate from `tests/live/run-live-tests.sh`:

- `tests/live/run-live-tests.sh` proves hook/agent behavior and release gating
- `tests/e2e-live/run-e2e-live-tests.sh` proves hook delivery against the
  enterprise-grade-test-app fixture (Kay diagnostic path)

When the Kay-only matrix passes, `run-e2e-live-tests.sh` writes the
session-scoped `e2e-live-matrix` marker (`matrix=codex-only`). The legacy inline
todo-app full-surface journey is **retired** from the default scenario list; set
`SB_E2E_LIVE_INCLUDE_LEGACY_JOURNEY=1` to run the archived journey script.

Release creation requires live matrix markers in addition to the shared hook/agent
matrix marker written by `tests/live/run-live-tests.sh`. For SB plugin releases,
complete either the Kay diagnostic path here or the Claude supervised enterprise
matrix per `.planning/enterprise-e2e/`.

Current scenarios:

| Scenario | Purpose |
|----------|---------|
| `test-e2e-live-hook-failures.sh` | Verifies SB hook-trigger failures are enforced live for forbidden edits, commits, release attempts, state tampering, and plugin-boundary writes before allowing a planned edit |
| `test-e2e-live-full-surface-journey.sh` | **Legacy (opt-in)** — archived todo-app inline journey; superseded by Claude supervised matrix |

Fast preflight:

| Script | Purpose |
|--------|---------|
| `dependency-access-preflight.sh` | Verifies the live agent can see SB and the required dependency plugins before the expensive scenario run starts |
| `hook-delivery-preflight.sh` | Verifies the active runtime actually delivers SB hook denies before planning; if this fails, Codex/Claude parity is not established and the E2E runner stops before the longer scenarios |
| `recommended-tools-preflight.sh` | Verifies Graphify, agentmemory, RTK, Context Mode, and Alumnium opt-in when enabled |

`run-e2e-live-tests.sh` calls preflights automatically before the scenario matrix. A runtime must pass plugin-access preflight and hook-delivery preflight before scenarios run.

Each scenario starts from a fresh workspace copied from the standalone sibling
`enterprise-grade-test-app` repo and is cleaned up after completion.

For Kay-agent runs, the suite uses an isolated temporary `KAY_HOME` root
backed by Kay's MiniMax.io provider path before bootstrapping the SB Codex
package. That keeps live E2E installs from changing the user's real `~/.codex`
hook cache.

**Fixture path override:** `SB_TEST_ENTERPRISE_APP_ROOT=/path/to/clone`
