# Silver Bullet Enterprise Live E2E Suite

This suite runs the real agent (Claude by default, `SB_E2E_LIVE_RUNTIMES` selects `claude`, `codex`
or `kay`) against an isolated copy of the standalone sibling `enterprise-grade-test-app` repo. The
full workflow coverage matrix is the **Claude supervised matrix** documented in
`.planning/enterprise-e2e/CLAUDE-TUI-PROTOCOL.md` and
`enterprise-grade-test-app/docs/WORKFLOW_E2E_MATRIX.md`; it is run separately and does **not** write
any release marker.

The Kay path uses the MiniMax.io provider credential path with `MiniMax-M3`
and low reasoning.

It is intentionally separate from `tests/live/run-live-tests.sh`:

- `tests/live/run-live-tests.sh` proves hook/agent behavior and release gating
- `tests/e2e-live/run-e2e-live-tests.sh` proves hook delivery against the
  enterprise-grade-test-app fixture

Release evidence is written by the runner only, never by a scenario, and only after every scenario
of every requested runtime passed (a missing scenario file or an empty run is a failure and writes
nothing). With the default `claude` runtime a pass writes `matrix=claude-only` to the host's
`e2e-live-matrix`; `codex`/`kay` alone write `matrix=codex-only`; both families write
`matrix=full-claude-codex`. The runner snapshots the other release evidence (`release-live-matrix`,
`quality-gate-state`, `verify-tests-state`) before the run and restores it on every exit, because a
live agent session's SessionStart hook resets branch-scoped state. It also tears down any isolated
Codex/Kay home on every exit.

Release creation requires live matrix markers in addition to the shared hook/agent matrix marker
written by `tests/live/run-live-tests.sh`. The gate (`hooks/lib/completion-audit/deploy-tier.sh`)
also requires `inline-e2e-matrix=matrix=inline-full-surface`, which only the inline full-surface
journey writes (`SB_E2E_LIVE_INCLUDE_LEGACY_JOURNEY=1`). The Claude supervised matrix (`scripts/run-enterprise-e2e-matrix.sh`, all 22 rows, no skips) writes the same marker
after a full real pass; both writers stamp `commit=`; the gate requires the released tree to differ from that commit only in release-surface files (docs/RELEASE.md; the round ledger is the one allowed harness output), and the supervised writer refuses a dirty tree.

Current scenarios:

| Scenario | Purpose |
|----------|---------|
| `test-e2e-live-hook-failures.sh` | Verifies SB hook-trigger failures are enforced live for forbidden edits, commits, release attempts, state tampering, and plugin-boundary writes before allowing a planned edit |
| `test-e2e-live-full-surface-journey.sh` | Opt-in (`SB_E2E_LIVE_INCLUDE_LEGACY_JOURNEY=1`) — the todo-app inline journey that the release gate's `inline-e2e-matrix` marker certifies; a timed-out turn or a tool-error transcript fails it, and it never records surfaces into state itself |

Fast preflight:

| Script | Purpose |
|--------|---------|
| `dependency-access-preflight.sh` | Verifies the live agent can see SB and the required dependency plugins before the expensive scenario run starts |
| `hook-delivery-preflight.sh` | Runs one live agent turn and requires the hook audit entry that turn produced (a deny from `dev-cycle-check`) and an unchanged source file; piping a payload into the hook proves nothing about delivery and is not accepted. If it fails, parity is not established and the runner stops before the longer scenarios |
| `recommended-tools-preflight.sh` | Verifies Graphify, agentmemory, RTK, Context Mode, and Alumnium opt-in when enabled |

`run-e2e-live-tests.sh` calls preflights automatically before the scenario matrix. A runtime must pass plugin-access preflight and hook-delivery preflight before scenarios run.

Each scenario starts from a fresh workspace copied from the standalone sibling
`enterprise-grade-test-app` repo and is cleaned up after completion.

For Kay-agent runs, the suite uses an isolated temporary `KAY_HOME` root
backed by Kay's MiniMax.io provider path before bootstrapping the SB Codex
package. That keeps live E2E installs from changing the user's real `~/.codex`
hook cache.

**Fixture path override:** `SB_TEST_ENTERPRISE_APP_ROOT=/path/to/clone`
