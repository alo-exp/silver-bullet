# Enterprise E2E Host Configuration Matrix

Canonical source: [`scripts/enterprise-e2e/config/hosts.json`](../../scripts/enterprise-e2e/config/hosts.json)

Set **`SB_E2E_LIVE_RUNTIME`** (or `--host` on live-test) to select a track. Artifact paths below apply when env overrides are unset.

---

## Environment matrix

| Variable | Claude (R6 legacy) | Codex | Cursor |
|----------|-------------------|-------|--------|
| `SB_E2E_LIVE_RUNTIME` | `claude` (default) | `codex` | `cursor` |
| Lock file | `.e2e-live-test.lock` | `.e2e-live-test-codex.lock` | `.e2e-live-test-cursor.lock` |
| Matrix log | `.e2e-matrix-live.log` | `.e2e-matrix-codex-live.log` | `.e2e-matrix-cursor-live.log` |
| Row attempt log | `.e2e-row{N}-attempt.log` | `.e2e-row{N}-codex-attempt.log` | `.e2e-row{N}-cursor-attempt.log` |
| Ledger | `ROUND-1-LEDGER.md` (R6 uses project ledger) | `ROUND-CODEX-1-LEDGER.md` | `ROUND-CURSOR-1-LEDGER.md` |
| SB git branch | `enterprise-e2e/round6` | `enterprise-e2e/codex` | **`enterprise-e2e/cursor`** |
| Test-app git branch | `enterprise-e2e/round-6-claude` | `enterprise-e2e/round-1-codex` | **`enterprise-e2e/round-1-cursor`** |
| Gates pair | `ROUND-5/6-GATES.md` | `ROUND-CODEX-1/2-GATES.md` | `ROUND-CURSOR-1/2-GATES.md` |
| Install | `scripts/install-claude.sh` | `scripts/install-codex.sh --purge-legacy-skills` | `scripts/install-cursor.sh` |
| Agent adapter | `tests/live/agents/claude/agent.sh` | `tests/live/agents/codex/agent.sh` | `tests/live/agents/cursor/agent.sh` |
| Route syntax | `/silver`, `/silver:feature` | `$silver`, `$silver:feature` | `/silver`, `feature` (strip prefix) |
| TUI protocol | [CLAUDE-TUI-PROTOCOL.md](./CLAUDE-TUI-PROTOCOL.md) | [CODEX-TUI-PROTOCOL.md](./CODEX-TUI-PROTOCOL.md) | [CURSOR-TUI-PROTOCOL.md](./CURSOR-TUI-PROTOCOL.md) |

---

## Shared entrypoints (all hosts)

```bash
# Preflight only (deterministic)
bash scripts/run-enterprise-e2e-live-test.sh --host codex --preflight-only

# Dry-run matrix row (deterministic — no LLM)
SB_E2E_MATRIX_DRY_RUN=1 SB_E2E_LIVE_RUNTIME=cursor bash scripts/run-enterprise-e2e-matrix.sh 1

# Live matrix (LLM — requires SB_ENTERPRISE_E2E_LIVE=1)
SB_ENTERPRISE_E2E_LIVE=1 bash scripts/run-enterprise-e2e-live-test.sh --host codex --resume
```

Wrappers delegate to [`scripts/enterprise-e2e/`](../../scripts/enterprise-e2e/).

---

## Cross-host isolation (when Claude Round 6 active)

- Each host uses an isolated test-app branch (`test_app_git_branch` in `hosts.json`) — see [TEST-APP-BRANCH-POLICY.md](./TEST-APP-BRANCH-POLICY.md).
- Never remove `.e2e-live-test.lock` unless Claude driver PID is dead.
- Codex/Cursor use host-suffixed locks — do not steal Claude's lock.
- Never `pkill` another host's monitor/driver children.
- Contribute fixes to `scripts/enterprise-e2e/lib/` — not host-only forks.

See [OPERATIONAL-ADDENDUM.md](./OPERATIONAL-ADDENDUM.md) and [SHARED-HARNESS.md](./SHARED-HARNESS.md).
