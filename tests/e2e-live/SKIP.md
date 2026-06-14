# E2E Live Harness — Skip / Environmental Failures

**Purpose:** Document failures that require host runtime (Kay, Minimax, live agent) and are excluded from the in-repo release gate.

## In-repo release gate

CI job `validate` runs:

- Hook unit tests (`tests/hooks/test-*.sh`)
- Script unit tests
- Integration tests (excluding live agent)
- `tests/e2e-live/test-e2e-live-suite.sh` (sanity only)

Full `tests/run-all-tests.sh` may still report failures in categories below — **not blocking** merge/release when unit gate is green.

## Environmental failure categories

| Category | Symptom | Root cause | In-repo fix? |
|----------|---------|------------|--------------|
| Kay bridge git shim | Live E2E cannot resolve git in agent sandbox | Host Kay runtime path | No — requires Kay install |
| Codex isolation temp paths | State dir outside `${SB_RUNTIME_HOME_ROOT}/` in live wrapper | Host temp layout | Partial — tests use scoped dirs |
| Minimax live agent | Agent subprocess timeout / missing API | External LLM runtime | No |
| OpenCode Go / DeepSeek matrix | Release matrix receipt missing | Optional release gate only | Documented in completion-audit |
| NODE_MODULE_VERSION (dogfood) | Native module rebuild on host Node bump | Developer machine | `npm rebuild` documented in DOGFOOD |

## Live matrix (tier 3)

Run manually before plugin release:

```bash
bash scripts/run-release-live-matrix.sh
bash tests/e2e-live/run-e2e-live-tests.sh
```

## CI split (P7)

- **Unit gate (required):** `tests/hooks`, `tests/scripts`, `tests/integration` (non-live)
- **Live matrix (optional):** `tests/e2e-live/run-e2e-live-tests.sh` — `continue-on-error` or separate workflow

## Target

**0 failures** on unit/integration path used by `.github/workflows/ci.yml` validate job.
