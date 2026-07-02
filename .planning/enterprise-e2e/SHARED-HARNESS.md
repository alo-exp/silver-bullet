# Enterprise E2E Shared Harness

**Branch:** `enterprise-e2e/multi-host` (extends to `enterprise-e2e/harness-shared`)  
**Canonical code:** [`scripts/enterprise-e2e/`](../../scripts/enterprise-e2e/)

All three operator sessions (Claude Round 6, Codex, Cursor) share one harness. Host differences live in **config + adapters + prompts only**.

---

## Architecture

```
scripts/enterprise-e2e/
  live-test.sh              # live entry (wrapper: scripts/run-enterprise-e2e-live-test.sh)
  matrix.sh                 # matrix runner (wrapper: scripts/run-enterprise-e2e-matrix.sh)
  config/hosts.json         # lock paths, logs, ledger, install, adapter per host
  lib/
    core.sh                 # shared orchestration (resume, locks, code-intel preflight)
    host.sh                 # SB_E2E_LIVE_RUNTIME resolution + artifact paths
    deterministic/          # no LLM — structural gates only
      consecutive-rounds.sh
      ledger-reconcile.sh
      outcome-assessment.sh
      matrix-quiesce.sh
    adapters/
      claude.sh | codex.sh | cursor.sh   # install + preflight + agent path
```

Backward-compat shims:

- [`scripts/lib/enterprise-e2e-live-common.sh`](../../scripts/lib/enterprise-e2e-live-common.sh) → sources `lib/core.sh`
- [`scripts/lib/enterprise-e2e-*.sh`](../../scripts/lib/) — unchanged paths; deterministic copies symlinked under `lib/deterministic/`

---

## Deterministic vs live (LLM) layers

| Layer | Deterministic? | Entry | Host-specific? |
|-------|----------------|-------|----------------|
| Structural suite | **Yes** | `tests/enterprise-e2e-live/test-enterprise-e2e-live-suite.sh` | Parameterized via `SB_E2E_LIVE_RUNTIME` |
| Outcome scoring | **Yes** | `lib/deterministic/outcome-assessment.sh` | Shared rubric; host only affects log paths |
| Consecutive rounds | **Yes** | `lib/deterministic/consecutive-rounds.sh` | `--host claude\|codex\|cursor` gate file pairs |
| Ledger reconcile | **Yes** | `lib/deterministic/ledger-reconcile.sh` | Ledger path from `hosts.json` |
| Preflight / install smoke | **Yes** | `live-test.sh --preflight-only` | Adapter install + host preflight |
| Dry-run matrix | **Yes** | `SB_E2E_MATRIX_DRY_RUN=1 matrix.sh [rows]` | Route translation via `host.sh` |
| Validation / pre-release overlay | **Yes** | `run-enterprise-e2e-validation-overlay.sh` | Shared |
| Grep / orchestrator / claims checks | **Yes** | `claims-audit.sh`, monitor, watch | Shared |
| **Live matrix rows 1–20** | **No (LLM)** | `SB_ENTERPRISE_E2E_LIVE=1 live-test.sh` | TUI invoke via `tests/live/agents/{host}/agent.sh` |
| TUI monitor agent loop | **No (LLM)** | `.planning/enterprise-e2e/tui-monitor-agent-loop.sh` | Host prompts differ |

**Rule:** Fix harness bugs in `scripts/enterprise-e2e/lib/` — never fork per-host copies of deterministic logic.

---

## Host selection

```bash
export SB_E2E_LIVE_RUNTIME=codex   # or claude | cursor
# or
bash scripts/run-enterprise-e2e-live-test.sh --host cursor
```

Defaults and artifact paths: [`config/hosts.json`](../../scripts/enterprise-e2e/config/hosts.json) and [HOST-CONFIG.md](./HOST-CONFIG.md).

**Claude Round 6:** `legacy_paths: true` — unchanged `.e2e-live-test.lock`, `.e2e-matrix-live.log`, `.e2e-row{N}-attempt.log`.

---

## Operator docs

| Doc | Audience |
|-----|----------|
| [HOST-CONFIG.md](./HOST-CONFIG.md) | Env matrix all hosts |
| [OPERATIONAL-ADDENDUM.md](./OPERATIONAL-ADDENDUM.md) | Cross-host ops (strict-clean, friction) |
| [CLAUDE-ROUND6-SHARED-HARNESS-ADDENDUM.md](./CLAUDE-ROUND6-SHARED-HARNESS-ADDENDUM.md) | Active Claude R6 session only |
| [CODEX-ENTERPRISE-E2E-EXECUTION-PROMPT.md](./CODEX-ENTERPRISE-E2E-EXECUTION-PROMPT.md) | Codex fresh session |
| [CURSOR-ENTERPRISE-E2E-EXECUTION-PROMPT.md](./CURSOR-ENTERPRISE-E2E-EXECUTION-PROMPT.md) | Cursor fresh session |
| [ROUND-6-OPERATIONAL-ADDENDUM.md](./ROUND-6-OPERATIONAL-ADDENDUM.md) | Claude R6 legacy (unchanged paths) |

Per-host TUI prompts: `hosts/{claude,codex,cursor}/prompt.md` (symlinks to `*-TUI-PROTOCOL.md`).

---

## Verification (deterministic)

```bash
RTK_DISABLED=1 bash tests/enterprise-e2e-live/test-enterprise-e2e-live-suite.sh
RTK_DISABLED=1 bash tests/scripts/test-outcome-assessment.sh
SB_E2E_MATRIX_DRY_RUN=1 SB_E2E_LIVE_RUNTIME=codex bash scripts/run-enterprise-e2e-matrix.sh 1
```

---

## Contributing across operator sessions

1. Pull `enterprise-e2e/multi-host` (or cherry-pick harness commits per [CHERRY-PICK.md](./CHERRY-PICK.md)).
2. Change shared logic under `scripts/enterprise-e2e/lib/`.
3. Change host-only invoke patterns in `lib/adapters/{host}.sh` or `hosts/{host}/prompt.md`.
4. Run both structural suites before push.
5. Do **not** rename Claude legacy lock/log paths while Round 6 is active.
