# RC Validation Matrix

See [`scripts/run-rc-validation-matrix.sh`](../../scripts/run-rc-validation-matrix.sh).

Six cells: cursor/codex/claude × fresh/upgrade. Markers: `${SB_RUNTIME_STATE_DIR}/rc-validation/{host}-{mode}`.

- **Gate:** `release.require_rc_matrix` (completion-audit)
- **Bypass:** `SB_SKIP_RC_MATRIX=1`
- **Five-tool:** folded into cursor cells when leanctx opted in
- **Claude:** first-class matrix host — runs fresh/upgrade + live delegate when `claude` CLI and auth are available (`ANTHROPIC_API_KEY` / `ANTHROPIC_AUTH_TOKEN` or `claude auth status`). Cells skip only when CLI or auth is genuinely missing.

```bash
bash scripts/run-rc-validation-matrix.sh
bash scripts/pre-release-gate.sh
```

CI: [`.github/workflows/rc-validation.yml`](../../.github/workflows/rc-validation.yml) installs Claude Code CLI, `expect`, and `jq`; passes `ANTHROPIC_API_KEY` alongside Cursor/Codex secrets.
