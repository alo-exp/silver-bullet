# Full Autonomous End-to-End — Assessment Methodology (Honest)

**Date:** 2026-07-06  
**Authority:** [`docs/PRODUCT-VISION-AUTONOMOUS-ENTERPRISE.md`](../../docs/PRODUCT-VISION-AUTONOMOUS-ENTERPRISE.md) §6.2  
**Track evidence:** [`.planning/agent-claude-autonomous/`](.)  
**Proof baseline:** [`docs/testing/autonomous-enterprise-proof-baseline.json`](../../docs/testing/autonomous-enterprise-proof-baseline.json)

---

## Executive summary

Silver Bullet **did** run a fresh, scoped live E2E assessment of autonomous delivery — but only on a **3-row agent-claude matrix** (`AUTO-C01` / `AUTO-C02` / `AUTO-C03`) via `/silver:agent-claude` on the current `install_fp`. That proves inverted human/agent roles for **bounded Claude-delegated sessions** on the enterprise test fixture.

Silver Bullet **did not** prove full enterprise-scale autonomous E2E. The legacy **22-row enterprise matrix**, full **composer workflow DAG** driven by the **Cursor parent orchestrator** without operator babysitting, and **production deploy** remain unproven at claims grade. `public_autonomous_enterprise_claim_ready` stays **false**.

---

## What was tested

| Dimension | Detail |
|-----------|--------|
| **Mechanism** | [`/silver:agent-claude`](../../skills/silver-agent-claude/SKILL.md) — Claude TUI in `enterprise-grade-test-app` via `agent-claude-delegate.sh` |
| **Harness** | [`scripts/agent-claude-autonomous-test.sh`](../../scripts/agent-claude-autonomous-test.sh) — `preflight` / `start` / `score` |
| **Matrix** | Fresh 3-row track in [MATRIX.json](MATRIX.json) — **not** legacy Round 9 22-row routing |
| **Install** | `install_fp` recorded in [MATRIX-LEDGER.json](MATRIX-LEDGER.json) (`claude@609ee0a1812c+2717f916398e`) |
| **Verdict** | **3/3 PASS** per ledger (AUTO-C01 router+bounded delivery, AUTO-C02 doc tailor slice, AUTO-C03 composite gate) |
| **Role model** | Human = harness supervisor; Claude executor drives SB workflows autonomously inside delegated session |
| **Fixture** | `enterprise-grade-test-app` work tree on feature branches per row brief |

### Per-row scope

| Row | Proves | Blocking outcomes |
|-----|--------|-------------------|
| AUTO-C01 | Vague-to-bounded intent → routed autonomous feature path → committed API delta | OUT-AUTO-01, OUT-CLARIFY-01, OUT-NOOP-01 |
| AUTO-C02 | Standalone workflow (doc tailor) without matrix env bleed | OUT-AUTO-01, OUT-TAILOR-01, OUT-NOOP-01 |
| AUTO-C03 | Composite autonomy gate across C01+C02 artifacts | OUT-WORLD-01 |

---

## What was not tested

| Gap | Why it matters |
|-----|----------------|
| **Legacy 22-row enterprise matrix** | Canonical tri-host certification bar; Claude remains **6/22 smoke** per [CERTIFICATION-STATUS.json](../enterprise-e2e/CERTIFICATION-STATUS.json) |
| **Full composer workflow DAG** | Parent orchestrator spawning all `AF-*` workers through clarify → plan → execute → verify → review → ship without user steering |
| **Cursor parent orchestrator end-to-end** | Agent-claude track delegates to **Claude TUI**, not Cursor parent `Task` worker loop |
| **Cold-start vague prompt → shipped app** | Rows use harness-written briefs; operator still seeds intent and monitors delegation |
| **Production deploy / release** | Policy keeps tags, releases, and destructive ops user-triggered ([`AGENTS.md`](../../AGENTS.md)) |
| **Tri-host parity** | Only Claude host on this track; Cursor/Codex `live_e2e_proven` (22/22) are separate ledgers |
| **2 consecutive strict-clean rounds** | Release bar per [OPERATIONAL-ADDENDUM.md](../enterprise-e2e/OPERATIONAL-ADDENDUM.md) — not attempted on this track |
| **Statistical flake budget** | Single pass wave per row; no consecutive-round rigor |

---

## Scoring methodology

### Blocking outcomes (fail-closed)

Reuses [`scripts/lib/enterprise-e2e-outcome-assessment.sh`](../../scripts/lib/enterprise-e2e-outcome-assessment.sh) via `enterprise_e2e_outcome_score_criterion`:

| Outcome | Meaning |
|---------|---------|
| **OUT-AUTO-01** | SB drives completion; no operator babysitting markers in session log |
| **OUT-NOOP-01** | No pause for automatable decisions |
| **OUT-CLARIFY-01** | Fuzzy intent clarified before wrong-route execution (C01) |
| **OUT-TAILOR-01** | Dynamic composition justified when catalog rules allow (C02) |
| **OUT-WORLD-01** | Composite — all applicable blocking criteria pass (C03) |

Row **PASS** requires: delegate exit 0, log floor met, all row blocking outcomes `pass`, product delta committed when brief requires it, evidence template filled. See [CRITERIA.md](CRITERIA.md).

### Evidence artifacts

Per run under `runs/<run-id>/`:

- `brief.md` — harness delegation brief (not operator freeform mid-run)
- `claude-run.log` — scored session transcript
- `ledger.json` — install_fp, status, blocking outcome map
- `result.md` — operator/harness fill from [EVIDENCE-TEMPLATE.md](EVIDENCE-TEMPLATE.md)
- `SCORE-TRIAGE.md` — when scorer needed false-negative investigation

Ledger rollup: [MATRIX-LEDGER.json](MATRIX-LEDGER.json).

### False-negative fixes applied

Scorer tuning during the track (documented in run triage notes):

- Distinguish **harness supervisor** checkpoints from **babysitting** (OUT-AUTO-01)
- Clear `SB_E2E_ENTERPRISE_MATRIX` env so agent-claude does not bleed into 22-row routing
- Log-floor waiver only when brownfield brief explicitly allows
- OUT-TAILOR-01: accept `composition_log` or flow-trace markers, not full DAG replay

---

## Proof levels (honest)

| Claim | Level | Notes |
|-------|-------|-------|
| `agent-claude-autonomous-vision-matrix` | **`live_e2e_proven`** | Scoped to **3-row track only** — see proof baseline |
| Claude tri-host 22/22 | `live_e2e_partial` (6/22) | Unchanged by this track |
| `public_autonomous_enterprise_claim_ready` | **`false`** | Requires 3/3 hosts `live_e2e_proven` on canonical matrix |
| Homepage autonomous delivery hero | `live_e2e_partial` | Fixture rows only; not cold-start enterprise |

Registry: [`docs/testing/autonomous-enterprise-proof-baseline.json`](../../docs/testing/autonomous-enterprise-proof-baseline.json), [`.planning/enterprise-e2e/CERTIFICATION-STATUS.json`](../enterprise-e2e/CERTIFICATION-STATUS.json).

---

## Limitations

1. **Supervised delegation ≠ parent orchestrator autonomy** — parent monitors Claude; autonomy is scored on Claude session log, not parent silence.
2. **Brief-assisted intent** — harness supplies bounded briefs; not a single vague user paragraph without scaffolding.
3. **Single wave** — no consecutive strict-clean rounds or flake budget.
4. **Fixture app only** — not customer brownfield repos or multi-service deploy topologies.
5. **Measurement debt** — legacy enterprise rounds had monitor/ledger drift; this track uses fresh ledger but does not retroactively certify 22-row history.

---

## What "full autonomous E2E" would require

To honestly claim enterprise-scale autonomous delivery:

1. **New test track** — minimal user intent only (see [`.planning/minimal-intent-e2e/`](../minimal-intent-e2e/)) with Cursor **parent orchestrator** driving the full lifecycle DAG.
2. **22/22 strict-clean** per host with blocking autonomy gates and §5b product audit.
3. **2 consecutive** strict-clean rounds per [OPERATIONAL-ADDENDUM.md](../enterprise-e2e/OPERATIONAL-ADDENDUM.md).
4. **Tri-host parity** — Claude, Codex, Cursor at same enforcement tier.
5. **Cold-start path** — vague paragraph + optional prefs → shipped artifact without operator workflow driving.
6. **Durable orchestration** — session replay, saga retries (future substrate).
7. **Claims reconciliation** — `public_autonomous_enterprise_claim_ready: true` only after conservative summary passes all three hosts.

Until then: **`live_e2e_proven` is valid only for the scoped 3-row agent-claude track**; broader autonomous enterprise claims remain partial or planned.
