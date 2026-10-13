# Phase 94.01 Validation Evidence

## Focused Tests Passed

- `bash tests/scripts/test-sync-codex-package.sh` — 33 passed, 0 failed
- `bash tests/scripts/test-silver-router-flow-contracts.sh` — 76 passed, 0 failed
- `bash tests/hooks/test-planning-file-guard.sh` — 29 passed, 0 failed
- `bash tests/hooks/test-stop-check.sh` — 34 passed, 0 failed
- `bash tests/integration/test-skill-execution-paths.sh` — 299 passed, 0 failed
- `bash tests/hooks/test-completion-audit.sh` — 64 passed, 0 failed
- `bash tests/hooks/test-compliance-status.sh` — 18 passed, 0 failed
- `bash tests/hooks/test-verify-tests.sh` — 13 passed, 0 failed
- `shellcheck --exclude=SC2317,SC1091,SC2329 hooks/*.sh hooks/lib/*.sh scripts/*.sh` — passed
- `git diff --check` — passed

## Full Suite

Initial full-suite run before final release-surface updates:

- `bash tests/run-all-tests.sh` — 2010 passed, 0 failed

Final full-suite rerun after all four quality-gate stages:

- `bash scripts/verify-tests.sh` — ran `bash tests/run-all-tests.sh`; 2010 passed, 0 failed

Final full-suite rerun after Codex package/live-E2E harness fixes:

- `bash scripts/verify-tests.sh` — ran `bash tests/run-all-tests.sh`; 2011 passed, 0 failed

## Live Runtime Gates

- `SB_LIVE_RUNTIMES=codex bash tests/live/run-live-tests.sh` — Codex hook live matrix passed; marker `matrix=codex-only`
- `SB_E2E_LIVE_RUNTIMES=codex SB_ALLOW_CODEX_ONLY_LIVE_RELEASE=1 bash tests/e2e-live/run-e2e-live-tests.sh` — full-surface Codex E2E live journey passed; 56 passed, 0 failed; markers `matrix=codex-only` and `matrix=inline-full-surface`
- Full Claude+Codex live execution was blocked by local Claude CLI authentication (`401 Invalid authentication credentials`). Under AFK release autonomy, the configured Codex-only fallback was used and recorded.
