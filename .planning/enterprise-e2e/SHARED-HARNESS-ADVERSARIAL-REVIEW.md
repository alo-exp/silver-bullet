# Shared Harness — Adversarial Review (Post-Rarchitecture)

**Date:** 2026-06-30  
**Branch:** `enterprise-e2e/multi-host`  
**Reviewer lens:** Day-1 Codex/Cursor fresh sessions, wrapper/path drift after reorg, deterministic vs live honesty, prompt/harness alignment  
**Scope:** `scripts/enterprise-e2e/**`, wrappers, legacy shims, structural + outcome tests, execution prompts, Round 6 addenda

---

## Executive verdict

| Pass | Timestamp (UTC) | Verdict | P0 | P1 | Notes |
|------|-----------------|---------|----|----|-------|
| **1** | 2026-06-30T18:00Z | **NOT READY** | 2 | 3 | Runtime corruption + broken `--host` gate resolution |
| **2** | 2026-06-30T18:30Z | **READY WITH GAPS** | 0 | 0 | All P0/P1 fixed; structural 179/0; outcome 69/0 |
| **3** | 2026-06-30T18:45Z | **READY WITH GAPS** | 0 | 0 | Confirmatory re-review — no regressions |

**Final:** **READY WITH GAPS** after **2 consecutive clean** adversarial passes (pass 2 + pass 3). Session launch allowed on all three hosts; live 2× strict-clean 22-row matrix still requires operator proof (P2).

---

## Success criteria scorecard

| # | Criterion | Pass 1 | Pass 2/3 | Evidence |
|---|-----------|--------|----------|----------|
| 1 | Agent-agnostic shared core | Partial | **PASS** | `scripts/enterprise-e2e/lib/{core,host}.sh` + `config/hosts.json` + adapters |
| 2 | Tri-host ladder + 22-row + Phase C | Partial | **PASS (wired)** | Dry-run codex/cursor row 1 invokes host agent; live 22/22 not proven |
| 3 | 2 consecutive strict-clean enforceable | **FAIL** | **PASS** | `lib/deterministic/consecutive-rounds.sh --host` + structural test |
| 4 | Deterministic vs live separated | PASS | **PASS** | Structural suite + dry-run all hosts |
| 5 | Parallel track isolation | PASS | **PASS** | Per-host locks/logs/row logs/state via `hosts.json` |
| 6 | Parent orchestrator ops | PASS | **PASS** | Prompts: composer-2.5, single driver, 60–90s polls |
| 7 | Claude Round 6 backward compat | PASS | **PASS** | `legacy_paths: true` — unchanged lock/log names |
| 8 | Outcome blocking + cherry-pick + no pause | PASS | **PASS** | Matrix outcome FAIL blocks row PASS; OPERATIONAL-ADDENDUM |

---

## Harness scorecard

| Component | Pass 1 | Pass 2/3 | Notes |
|-----------|--------|----------|-------|
| `config/hosts.json` | PASS | PASS | All 3 hosts: ledger, gates, logs, lock, adapter paths |
| `lib/core.sh` | PASS | PASS | Locks, resume, code-intel, install/preflight dispatch |
| `lib/host.sh` | PASS | PASS | `enterprise_e2e_runtime_state_dir` added pass 2 |
| `lib/adapters/*` | PASS | PASS | Thin install + preflight per host |
| `live-test.sh` | **FAIL** | PASS | P0 runtime corruption fixed |
| `matrix.sh` | PASS | PASS | Host route translation; host-aware outcome state |
| Wrappers (`run-enterprise-e2e-*.sh`) | PASS | PASS | `exec` to harness entrypoints |
| Legacy shims (`scripts/lib/enterprise-e2e-*.sh`) | PASS | PASS | Symlink to harness deterministic/ |
| `monitor-enterprise-e2e-matrix.sh` | **FAIL** | PASS | Detects `enterprise-e2e/matrix.sh` batch |
| `consecutive-rounds-check.sh` | **FAIL** | PASS | Repo-root walk-up when invoked via symlink path |
| Structural suite | 177/0 | **179/0** | +monitor + consecutive `--host` tests |
| Outcome assessment | 69/0 | **69/0** | `$silver:clarify` in scorer |

---

## Prompt scorecard

| Prompt | Pass 1 | Pass 2/3 | Gaps (P2) |
|--------|--------|----------|-----------|
| [CLAUDE-ROUND6-SHARED-HARNESS-ADDENDUM.md](./CLAUDE-ROUND6-SHARED-HARNESS-ADDENDUM.md) | PASS | PASS | Legacy paths unchanged — parallel Codex/Cursor safe |
| [CODEX-ENTERPRISE-E2E-EXECUTION-PROMPT.md](./CODEX-ENTERPRISE-E2E-EXECUTION-PROMPT.md) | PASS | PASS | M7 live row CI fixture; RCS tri-host manual export |
| [CURSOR-ENTERPRISE-E2E-EXECUTION-PROMPT.md](./CURSOR-ENTERPRISE-E2E-EXECUTION-PROMPT.md) | PASS | PASS | Phase A resolver-only vs live 8/8 documented |
| [ROUND-6-OPERATIONAL-ADDENDUM.md](./ROUND-6-OPERATIONAL-ADDENDUM.md) | PASS | PASS | Claude-only; no drift |
| [OPERATIONAL-ADDENDUM.md](./OPERATIONAL-ADDENDUM.md) | PASS | PASS | Cross-host strict-clean + friction watch |
| [HOST-CONFIG.md](./HOST-CONFIG.md) | PASS | PASS | Env bundle per host |
| [SHARED-HARNESS.md](./SHARED-HARNESS.md) | PASS | PASS | Architecture matches tree |

---

## Pass 1 findings (P0 / P1)

### P0 — fixed pass 2

| ID | Finding | File:line | Impact | Fix |
|----|---------|-----------|--------|-----|
| P0-1 | **`SILVER_BULLET_RUNTIME=cursor` leaked into matrix host** — overwrote `--host codex\|claude` before `enterprise_e2e_run_install_host` | `live-test.sh:151` | Codex/Claude live-test runs wrong install + preflight | Scoped cursor runtime to subshell for session-start preflight only |
| P0-2 | **`--host` consecutive-rounds gate paths wrong** when invoked via `lib/deterministic/consecutive-rounds.sh` symlink — SB_ROOT resolved to `scripts/enterprise-e2e/` | `scripts/lib/enterprise-e2e-consecutive-rounds-check.sh:10` | Post-matrix `SB_E2E_REQUIRE_CONSECUTIVE_ROUNDS=1` always FAIL (missing gates) | Walk up to `scripts/enterprise-e2e/config/hosts.json` anchor |

### P1 — fixed pass 2

| ID | Finding | File:line | Impact | Fix |
|----|---------|-----------|--------|-----|
| P1-1 | Operator tail hints hardcoded Claude monitor/watch paths | `live-test.sh:241-242` | Codex/Cursor operators tail wrong files | Use `SB_E2E_MATRIX_MONITOR_STATUS_FILE` / `SB_E2E_TUI_FINDINGS` |
| P1-2 | Outcome assessment fallback state dir Claude-only | `matrix.sh:379-391` | False OUT-SKILL/OUT-ORCH negatives on Codex/Cursor | `enterprise_e2e_runtime_state_dir()` in `host.sh` |
| P1-3 | Monitor pgrep missed harness matrix batch (`enterprise-e2e/matrix.sh`) | `monitor-enterprise-e2e-matrix.sh:78-101` | False “batch dead” → duplicate restart during live-test driver | `matrix_runner_pgrep_pattern` matches wrapper + harness paths |

### P2 — open (non-blocking)

| ID | Finding | File:line | Notes |
|----|---------|-----------|-------|
| P2-1 | M7 — one full live row CI fixture per non-Claude host | structural suite only | Track in CODEX-CURSOR review |
| P2-2 | `enterprise-e2e-rcs.sh` defaults `SB_E2E_RCS_TRIHOST=claude-only` | `enterprise-e2e-rcs.sh:121` | Prompts document manual `=full` |
| P2-3 | Outcome companion paths not host-prefixed | `matrix.sh:378` | `row-N-outcomes.md` shared across tracks |
| P2-4 | Parallel tracks share one test-app fixture | OPERATIONAL-ADDENDUM | Serial mutation or branch-per-host for rows 21–22 |
| P2-5 | `live-test.sh` usage still mentions Claude-only install in one constraint line | `live-test.sh:48` | Cosmetic; round checklist updated |

---

## Fixes applied (pass 1 → pass 2)

| File | Change |
|------|--------|
| [`scripts/lib/enterprise-e2e-consecutive-rounds-check.sh`](../../scripts/lib/enterprise-e2e-consecutive-rounds-check.sh) | Repo-root discovery for deterministic symlink invocation |
| [`scripts/enterprise-e2e/live-test.sh`](../../scripts/enterprise-e2e/live-test.sh) | Remove global cursor runtime leak; host-isolated tail hints; dedupe TUI offset reset |
| [`scripts/enterprise-e2e/lib/host.sh`](../../scripts/enterprise-e2e/lib/host.sh) | Add `enterprise_e2e_runtime_state_dir` |
| [`scripts/enterprise-e2e/matrix.sh`](../../scripts/enterprise-e2e/matrix.sh) | Host-aware outcome state dir |
| [`scripts/monitor-enterprise-e2e-matrix.sh`](../../scripts/monitor-enterprise-e2e-matrix.sh) | Detect harness matrix + live-test entry processes |
| [`tests/enterprise-e2e-live/test-enterprise-e2e-live-suite.sh`](../../tests/enterprise-e2e-live/test-enterprise-e2e-live-suite.sh) | +3 assertions (monitor paths, consecutive `--host` SB_ROOT) |

---

## Pass 2 / Pass 3 verification

```bash
# Structural (179 assertions)
RTK_DISABLED=1 bash tests/enterprise-e2e-live/test-enterprise-e2e-live-suite.sh

# Outcome rubric (69 assertions)
RTK_DISABLED=1 bash tests/scripts/test-outcome-assessment.sh

# Dry-run matrix — all hosts
SB_E2E_MATRIX_DRY_RUN=1 SB_E2E_LIVE_RUNTIME=codex  bash scripts/run-enterprise-e2e-matrix.sh 1
SB_E2E_MATRIX_DRY_RUN=1 SB_E2E_LIVE_RUNTIME=cursor bash scripts/run-enterprise-e2e-matrix.sh 1

# Consecutive rounds — repo-root gate resolution
bash scripts/enterprise-e2e/lib/deterministic/consecutive-rounds.sh --host codex
# → .../repo/.planning/enterprise-e2e/ROUND-CODEX-1-GATES.md (not scripts/enterprise-e2e/.planning/...)
```

**Pass 3 adversarial re-scan:** No new P0/P1. Residual risk is live-only (TUI stalls, quota, fixture mutation under parallel tracks).

---

## Review run history (full)

| Pass | Verdict | Structural | Outcome | Action |
|------|---------|------------|---------|--------|
| 0 (pre-reorg) | NOT READY | — | — | Claude-only matrix; shared locks — see [CODEX-CURSOR-PROMPTS-ADVERSARIAL-REVIEW.md](./CODEX-CURSOR-PROMPTS-ADVERSARIAL-REVIEW.md) pass 0 |
| 1 (post-reorg) | NOT READY | 177/0 | 69/0 | P0-1, P0-2, P1-1–P1-3 found |
| 2 | READY WITH GAPS | 179/0 | 69/0 | Fixes committed |
| 3 | READY WITH GAPS | 179/0 | 69/0 | Confirmatory — **2 consecutive clean** |

---

## Related docs

- [SHARED-HARNESS.md](./SHARED-HARNESS.md) — architecture
- [HOST-CONFIG.md](./HOST-CONFIG.md) — per-host env
- [CODEX-CURSOR-PROMPTS-ADVERSARIAL-REVIEW.md](./CODEX-CURSOR-PROMPTS-ADVERSARIAL-REVIEW.md) — prompt-focused history
