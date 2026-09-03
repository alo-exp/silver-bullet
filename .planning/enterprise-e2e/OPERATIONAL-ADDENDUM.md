# Enterprise E2E Operational Addendum (all hosts)

**Generalizes:** [ROUND-6-OPERATIONAL-ADDENDUM.md](./ROUND-6-OPERATIONAL-ADDENDUM.md) (Claude R6 keeps that file for backward compat)

**Architecture:** [SHARED-HARNESS.md](./SHARED-HARNESS.md) · **Host paths:** [HOST-CONFIG.md](./HOST-CONFIG.md)

**Execution prompts:**

- Claude R6: [ROUND-6-OPERATIONAL-ADDENDUM.md](./ROUND-6-OPERATIONAL-ADDENDUM.md) + [CLAUDE-ROUND6-SHARED-HARNESS-ADDENDUM.md](./CLAUDE-ROUND6-SHARED-HARNESS-ADDENDUM.md)
- Codex: [CODEX-ENTERPRISE-E2E-EXECUTION-PROMPT.md](./CODEX-ENTERPRISE-E2E-EXECUTION-PROMPT.md)
- Cursor: [CURSOR-ENTERPRISE-E2E-EXECUTION-PROMPT.md](./CURSOR-ENTERPRISE-E2E-EXECUTION-PROMPT.md)

---

## A. Mission & workspace (host-agnostic)

| Role | Path |
|------|------|
| SB workspace (fixes, harness, ledger) | `/Users/shafqat/projects/silver-bullet/repo` |
| Matrix CWD (test app) | `/Users/shafqat/projects/enterprise-grade-test-app` |

**Goal:** **2 consecutive strict-clean rounds** per host track before release.

**Strict-clean** = ALL of:

1. review-fix-ladder **8/8** with **2 consecutive clean verify passes** per rung, **0 new issues** (`python3 scripts/review-fix-ladder.py --host <host>`)
2. Live matrix **22/22** evidence PASS, **0 new friction/issues** vs baseline
3. Every row passes `enterprise_e2e_outcome_row_passes` (no `partial`)
4. Blocking autonomy gates: `OUT-AUTO-01`, `OUT-CLARIFY-01`, `OUT-NOOP-01`, `OUT-WORLD-01`
5. Phase C green: `test-outcome-assessment.sh`, `run-all-tests.sh`, validation/pre-release overlays, ledger reconcile, RCS ≥ 85

Evidence-only PASS or SKIP rows **do not** count strict-clean.

---

## B. Deterministic vs live phases

| Phase | Deterministic? | Command |
|-------|----------------|---------|
| Structural harness | Yes | `RTK_DISABLED=1 bash tests/enterprise-e2e-live/test-enterprise-e2e-live-suite.sh` |
| Outcome harness | Yes | `RTK_DISABLED=1 bash tests/scripts/test-outcome-assessment.sh` |
| Preflight | Yes | `bash scripts/run-enterprise-e2e-live-test.sh --host <host> --preflight-only` |
| Dry-run matrix | Yes | `SB_E2E_MATRIX_DRY_RUN=1 bash scripts/run-enterprise-e2e-matrix.sh` |
| Live matrix rows | **No (LLM)** | `SB_ENTERPRISE_E2E_LIVE=1 bash scripts/run-enterprise-e2e-live-test.sh --host <host>` |

---

## C. Parent orchestrator behavior

- One long-lived background worker per host track (`Task`, `model: composer-2.5` only).
- Resume same worker ID; no parallel matrix operators on one host.
- Poll relay every **60–90s** with substantive checkpoints.
- Never pause for operator on blockers — diagnose, fix in SB, re-run row.
- Fix harness in `scripts/enterprise-e2e/lib/` — shared across all three operator sessions.

---

## D. Policies (non-negotiable)

- Single driver per host; `SB_E2E_MONITOR_AUTO_RESTART=0`
- `RTK_DISABLED=1` for harness/preflight
- No `claude auth login/logout` on Claude track
- 429 → retry every **60s**
- Re-run host install after SB hook fixes (`enterprise_e2e_run_install_host`)
- Graphify + agentmemory + RTK + Context Mode opted-in when enforced
- Compaction on context full — not `/clear`

---

## E. Cross-host isolation

When Claude Round 6 runs in parallel with Codex/Cursor:

- Claude legacy paths unchanged (see [HOST-CONFIG.md](./HOST-CONFIG.md))
- Do not kill or lock-steal across hosts
- Cherry-pick harness fixes per [CHERRY-PICK.md](./CHERRY-PICK.md)

---

## F. Consecutive rounds gate

```bash
RTK_DISABLED=1 bash scripts/enterprise-e2e/lib/deterministic/consecutive-rounds.sh --host codex
```

Or set `SB_E2E_REQUIRE_CONSECUTIVE_ROUNDS=1` on live-test exit.
