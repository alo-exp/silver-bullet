# RC Validation Matrix

See [`scripts/run-rc-validation-matrix.sh`](../../scripts/run-rc-validation-matrix.sh).

Four cells: codex/claude × fresh/upgrade. Markers: `${SB_RUNTIME_STATE_DIR}/rc-validation/{host}-{mode}`.

## Policy

| Context | Scope |
|---------|-------|
| **Operator pre-release** (macOS/dev machine with host CLIs + user keys) | All four cells — live TUI delegate when CLI + auth available |
| **GitHub CI** ([`rc-validation.yml`](../../.github/workflows/rc-validation.yml)) | Optional/non-blocking diagnostic; codex/claude structural install only (`skip` marker `ci-no-first-party-keys`) |
| **Release gate** (`release.require_rc_matrix`) | Requires four operator-local live `pass` markers written at the commit being released. `--dry-run` markers (`dry-run`), skipped cells and markers for another commit do not count; a human can accept skips for one commit with `rc-validation/skip-waiver` (`commit=<sha>`). **Not** satisfied by the CI workflow alone |

Codex and Claude live RC cells are **operator-local pre-release** requirements until first-party or approved proxy API keys exist in CI. Third-party key proxy is explicitly out of scope.

## Live wrapper and model policy (mandatory)

Every live RC cell MUST be initiated through the host-specific `/sb:agent-*` wrapper
with this fixed model mapping:

| Host | Required wrapper | Required model |
|------|------------------|----------------|
| Codex | `/sb:agent-codex` | **GPT-5.6 Luna Low** |
| Claude | `/sb:agent-claude` | **Haiku 4.5** |

Raw host CLI runs, unrecorded model substitutions, and transcripts without the wrapper do
not satisfy a live RC cell.

## Controls

- **Gate:** `release.require_rc_matrix` (completion-audit / deploy-tier)
- **Bypass:** `SB_SKIP_RC_MATRIX=1` (logged to `release-bypass-log.jsonl`; it writes no markers, so it does not satisfy the gate)
- **CI mode:** `SB_RC_CI_MODE=1` or `GITHUB_ACTIONS=true` (auto-detected)

## Operator pre-release

```bash
bash scripts/run-rc-validation-matrix.sh
bash scripts/pre-release-gate.sh
```

Claude: `claude` CLI + `ANTHROPIC_API_KEY` or OAuth (`claude auth status`).
Codex: `codex` CLI + user API key.

## CI diagnostic

```bash
# workflow_dispatch only — continue-on-error; does not block merge or release
gh workflow run rc-validation.yml
```

CI sets `SB_RC_CI_MODE=1`; does **not** require `ANTHROPIC_API_KEY` or Codex API keys.
