# Agent-Claude Autonomous Test — Criteria

Aligned with [`docs/PRODUCT-VISION-AUTONOMOUS-ENTERPRISE.md`](../../docs/PRODUCT-VISION-AUTONOMOUS-ENTERPRISE.md) §6.2 and [OUTCOME-ASSESSMENT-RUBRIC.md](../enterprise-e2e/OUTCOME-ASSESSMENT-RUBRIC.md).

## North-star goal

Prove **inverted human/agent roles** on current SB `install_fp`: Claude (via agent-claude) drives SB workflows autonomously; human intervenes only on **blocking** decisions (auth, credentials, locked forks).

## Complexity policy (mandatory)

**Autonomous proof requires complex multi-workflow goals only** — not smoke (`npm test` only), not single API/file tweaks, not install verification without workflow execution. Prior Codex/Cursor smoke runs under auto-e2e are **weak proof** and flagged for re-run. Canonical bar: auto-e2e `.planning/auto-e2e-note-app/CURSOR-MULTIWF-CRITERIA.md`. All agent-claude matrix rows must meet: multi-workflow DAG, one vision paragraph, `.planning/` artifacts, substantive commits.

## Entry intent (session)

Operator supplies a **single vague-to-bounded intent** per matrix row. Harness writes the delegation brief; parent does not implement product code.

Example (AUTO-C01):

> Add a `GET /api/health` endpoint returning `{status:"ok"}` to the test app. Use Silver Bullet autonomous mode and workflows — route via `/silver` or `/silver:feature`. Commit on branch `feature/agent-claude-auto-c01`. Do not ask the operator except for blocking credentials.

## Minimal fresh matrix (3 rows)

See [MATRIX.json](MATRIX.json). **Not** the legacy 22-row enterprise matrix unless agent-claude explicitly routes there (it does not — skill excludes matrix env).

| Row ID | Class | Analog | Blocking outcomes |
|--------|-------|--------|-------------------|
| AUTO-C01 | Router + bounded delivery | E2E row 1 + 3 subset | OUT-AUTO-01, OUT-CLARIFY-01, OUT-NOOP-01 |
| AUTO-C02 | Standalone workflow | E2E row 6 (tailor) | OUT-AUTO-01, OUT-TAILOR-01, OUT-NOOP-01 |
| AUTO-C03 | Evidence + autonomy score | Meta | OUT-AUTO-01, OUT-WORLD-01 (composite on C01+C02 logs) |

**Session scope:** One row per delegation wave is the default; full 3-row pass requires 3 successful waves on the same `install_fp`.

## Success criteria (row PASS)

A row is **PASS** only when **all** hold:

1. `agent-claude-delegate.sh` exit 0, no harness `ERROR:` in log.
2. Log size ≥ `SB_AGENT_CLAUDE_LOG_FLOOR` (default 512 B) or documented brownfield waiver.
3. **Blocking outcomes** score `pass` via `enterprise_e2e_outcome_score_criterion` (reused scorer).
4. **Committed product delta** on target branch when brief requires code change.
5. `result.md` filled from [EVIDENCE-TEMPLATE.md](EVIDENCE-TEMPLATE.md).
6. agentmemory capture + `graphify update .` in modified repos (when enabled).

## Blocking vs advisory

| Outcome | Blocking | Notes |
|---------|----------|-------|
| OUT-AUTO-01 | **Yes** | Autonomous delivery — no babysitting |
| OUT-NOOP-01 | **Yes** | No operator pause for automatable decisions |
| OUT-CLARIFY-01 | **Yes** (C01) | Vague intent must clarify before wrong route |
| OUT-ORCH-01 | **Yes** (C02) | Parent must not implement inline in Claude session |
| OUT-WORLD-01 | **Yes** (C03) | Composite — all applicable criteria pass |
| OUT-KM-01 | Advisory | graphify + agentmemory evidence |
| OUT-VLOOP-01 | Advisory | Verification markers in log |
| OUT-TRACE-01 | Advisory | Composition / flow log trace |

## FAIL classes

`failure_class`: `stuck` | `quota` | `auth` | `harness` | `product` | `log-floor` | `0-token` | `outcome`

## Honest non-claims

- PASS on AUTO-C01 does **not** imply 22/22 enterprise matrix certification.
- PASS does **not** imply strict-clean round eligibility.
- Supervised delegation (parent checkpoints) is expected; autonomy is scored on **Claude session log**, not parent silence.
