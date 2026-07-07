# RC Validation Matrix

See [`scripts/run-rc-validation-matrix.sh`](../../scripts/run-rc-validation-matrix.sh).

Six cells: cursor/codex/claude × fresh/upgrade. Markers: `${SB_RUNTIME_STATE_DIR}/rc-validation/{host}-{mode}`.

## Policy

| Context | Scope |
|---------|-------|
| **Operator pre-release** (macOS/dev machine with host CLIs + user keys) | All six cells — live TUI delegate when CLI + auth available |
| **GitHub CI** ([`rc-validation.yml`](../../.github/workflows/rc-validation.yml)) | Optional/non-blocking diagnostic; cursor live when `CURSOR_API_KEY` present; codex/claude structural install only (`skip` marker `ci-no-first-party-keys`) |
| **Release gate** (`release.require_rc_matrix`) | Requires six operator-local markers (`pass` or audited `skip`) — **not** satisfied by CI workflow alone |

Codex and Claude live RC cells are **operator-local pre-release** requirements until first-party or approved proxy API keys exist in CI. Third-party key proxy is explicitly out of scope.

## Controls

- **Gate:** `release.require_rc_matrix` (completion-audit / deploy-tier)
- **Bypass:** `SB_SKIP_RC_MATRIX=1`
- **CI mode:** `SB_RC_CI_MODE=1` or `GITHUB_ACTIONS=true` (auto-detected)
- **Five-tool:** folded into cursor cells when leanctx opted in

## Operator pre-release

```bash
bash scripts/run-rc-validation-matrix.sh
bash scripts/pre-release-gate.sh
```

Claude: `claude` CLI + `ANTHROPIC_API_KEY` or OAuth (`claude auth status`).
Codex: `codex` CLI + user API key.
Cursor: `cursor-agent` CLI + `CURSOR_API_KEY` or OAuth.

## CI diagnostic

```bash
# workflow_dispatch only — continue-on-error; does not block merge or release
gh workflow run rc-validation.yml
```

CI sets `SB_RC_CI_MODE=1`; does **not** require `ANTHROPIC_API_KEY` or Codex API keys.
