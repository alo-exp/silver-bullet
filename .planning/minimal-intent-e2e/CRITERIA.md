# Minimal-Intent E2E — Criteria

Aligned with [`docs/PRODUCT-VISION-AUTONOMOUS-ENTERPRISE.md`](../../docs/PRODUCT-VISION-AUTONOMOUS-ENTERPRISE.md) inverted human/agent roles.

## Complexity policy (mandatory)

**Autonomous proof requires complex multi-workflow goals only** — not smoke (`npm test` only), not single-file tweaks, not health-check or install-only verification. See auto-e2e [CURSOR-MULTIWF-CRITERIA.md](https://github.com/alo-exp/auto-e2e/blob/main/.planning/auto-e2e-note-app/CURSOR-MULTIWF-CRITERIA.md) for the canonical bar. MI-01 and all future agent-* tracks must meet: multi-workflow DAG (clarify/spec → plan → execute → verify+), one vision paragraph input, multiple `.planning/` artifacts, substantive commits.

## Entry contract

| Input | Required | Description |
|-------|----------|-------------|
| `vision.md` | **Yes** | One paragraph user intent — no harness step list |
| `prefs.json` | No | Optional: branch prefix, test level, ship policy, blocking decision seeds |
| Operator | Minimal | Start session, answer **only** `decision_class: blocking` prompts |

Harness copies fixture vision into `runs/<run-id>/vision.md` and seeds `orchestrator-intent.txt` — it does **not** expand intent into a workflow script.

## Lifecycle expectation (MI-01)

Parent orchestrator (`orchestrator_mode: parent`) must compose and drive:

1. **Clarify/spec** — `AF-CLARIFY` / `AF-SPECIFY` when intent is fuzzy
2. **Plan** — `AF-PLAN` after pre-plan quality gate
3. **Implement** — `AF-EXECUTE` via worker (parent never edits source)
4. **Verify** — `AF-VERIFY` + review triad markers
5. **Review** — `AF-REVIEW` evidence in session
6. **Ship** — `AF-SHIP` or documented subset waiver in prefs (e.g. `ship: pr_only`)

Subset justified when `prefs.json` declares `session_scope` (e.g. `no_deploy`).

## Success criteria (row PASS)

All must hold:

1. Parent session used **Task workers only** for implementation — **OUT-ORCH-01** pass
2. **OUT-AUTO-01** — no operator babysitting; autonomous mode markers present
3. **OUT-NOOP-01** — no pause for automatable decisions
4. **OUT-CLARIFY-01** — if vision is fuzzy, clarify before wrong route
5. **OUT-WORLD-01** — composite pass on session transcript + artifacts
6. **Product delta** — committed on target branch per vision acceptance
7. **Orchestrator queue** — `orchestrator.json` shows flows advanced to completion or prefs-declared subset
8. Evidence: `result.md`, agentmemory capture, `graphify update .` when tools enabled

## Blocking vs advisory

| Outcome | Blocking |
|---------|----------|
| OUT-ORCH-01 | **Yes** — parent must not implement |
| OUT-AUTO-01 | **Yes** |
| OUT-NOOP-01 | **Yes** |
| OUT-CLARIFY-01 | **Yes** when intent fuzzy |
| OUT-WORLD-01 | **Yes** |
| OUT-KM-01 | Advisory |
| OUT-VLOOP-01 | Advisory |
| OUT-TRACE-01 | Advisory |

## Honest non-claims

- Scaffold PASS (structural tests) ≠ live E2E proven
- MI-01 PASS ≠ 22-row matrix certification
- Does not prove production deploy without user approval
