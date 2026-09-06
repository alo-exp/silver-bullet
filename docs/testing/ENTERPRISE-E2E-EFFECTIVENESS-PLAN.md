# Enterprise E2E Effectiveness Plan

**Status:** Draft — 2026-06-28  
**Audience:** SB maintainers, enterprise E2E operators, release gate owners  
**Scope:** Silver Bullet validation against `enterprise-grade-test-app` and homepage/marketing claims at [sb.alolabs.dev](https://sb.alolabs.dev)

---

## 1. Executive summary

### Is the current approach effective?

**Partially — strong for wiring and regression, weak for end-user guarantees and claim proof.**

The enterprise E2E program has delivered real value across three rounds:

| Layer | Evidence | Verdict |
|-------|----------|---------|
| **Structural / CI-safe suite** | `tests/enterprise-e2e-live/test-enterprise-e2e-live-suite.sh` — ~69 assertions on scripts, runbook, matrix wiring, auth policy, monitor/watch | ✅ Effective — catches doc/script drift before anyone opens Claude |
| **Unit + hook integration** | `bash tests/run-all-tests.sh` — 4260–4695 passed / 0 failed across rounds | ✅ Effective — hook behavior, orchestrator guards, ladder scripts are well covered |
| **Review-fix-ladder** | 8 rungs × 2 consecutive clean verify passes per round | ✅ Effective for scoped SB-repo regressions; ⚠️ model substitution (gpt-5.5 → composer-2.5-fast) weakens “ladder on intended models” claim |
| **Live matrix 22/22** | Rounds 1–2 ledgers claim 22/22; Round 3 paused at 8/22 with monitor/ledger drift | ⚠️ **Unreliable as a release oracle** without harness hardening and claims traceability |
| **Website claim fulfillment** | No automated claims→test mapping in CI | ❌ **Not tested** — marketing promises exceed what E2E proves today |

### Honest assessment from Rounds 1–3

**Round 1** ([`.planning/enterprise-e2e/ROUND-1-LEDGER.md`](../../.planning/enterprise-e2e/ROUND-1-LEDGER.md)):

- Achieved ledger 22/22 with heavy operator intervention, Cursor-native SB fallback for some rows, 429 retries, provider restarts, and partial Session 0 (`Skill tool unavailable in --print`).
- `run-all-tests` green (4345–4610) after multiple SB fixes mid-round.
- Open MUST-FIX: interactive TUI skill invocation not fully validated vs `--print` path.

**Round 2** ([`.planning/enterprise-e2e/ROUND-2-LEDGER.md`](../../.planning/enterprise-e2e/ROUND-2-LEDGER.md)):

- Cleaner 22/22 on haiku with provider-change restart mid-batch (rows 5–22 after proxy switch to `127.0.0.1:15721`).
- Demonstrated dual-role monitoring works when operator follows protocol.
- Post-round friction batch (`aaae7b6e`) caused separate test failures — shows **round gate SHA pinning** matters.

**Round 3** ([`.planning/enterprise-e2e/ROUND-3-SESSION-HANDOFF.md`](../../.planning/enterprise-e2e/ROUND-3-SESSION-HANDOFF.md), [`.planning/enterprise-e2e/ROUND-3-LEDGER.md`](../../.planning/enterprise-e2e/ROUND-3-LEDGER.md)):

- Preflight, ladder (8/8), and `run-all-tests` (4695/0) passed **before** matrix completion.
- Matrix stalled: row 1 blocked on API 429 + Bypass Permissions expect fragility (ANSI `[3G`, `[5G2.`).
- Monitor reported **COMPLETE 22/22** while ledger showed **8 PASS, 4 FAIL, 10 unclear** — **ledger drift is a P0 defect in the measurement system itself**.
- Session 0 completed programmatically (tools opted in via `.silver-bullet.json`); TUI `/sb:init` path still a manual gap for “first hour” claims.

### Gap: “matrix 22/22” vs “world-class reliability”

| What 22/22 actually proves | What it does **not** prove |
|----------------------------|----------------------------|
| 22 workflow routes can complete once on a fixture app with operator babysitting | Same outcomes on cold install without operator |
| Harness + monitor can drive Claude TUI with API key auth | Codex/Cursor parity at same enforcement tier |
| Evidence files exist at expected paths after sessions | Evidence quality (correct route, real gates, not parent inline code) |
| SB hooks did not hard-block legitimate matrix actions | Homepage stats (39% Veracode, 7× rework, ~30% token reclaim) |
| Plugin install + slash commands resolve | “10x lower cost”, “ships like best senior engineer”, “first blocked PR in 60 minutes” |
| One round on one machine with one model profile | Statistical reliability across providers, quotas, and UI churn |

**Conclusion:** The current program is an excellent **integration smoke test** and **regression harness** for SB maintainers. It is **not** yet a **claims-verification program** or **release SLO**. Treating monitor “22/22 COMPLETE” as release confidence without ledger reconciliation is an anti-pattern (observed in Round 3).

---

## 2. What we're testing today

### Components

```
┌─────────────────────────────────────────────────────────────────┐
│  Layer 0: run-all-tests.sh (~4700 tests)                        │
│  hooks, orchestrator, ladder scripts, e2e-live helpers          │
└────────────────────────────┬────────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────────┐
│  Layer 1: Structural enterprise suite (default CI)                │
│  tests/enterprise-e2e-live/test-enterprise-e2e-live-suite.sh    │
└────────────────────────────┬────────────────────────────────────┘
                             │ SB_ENTERPRISE_E2E_LIVE=1
┌────────────────────────────▼────────────────────────────────────┐
│  Layer 2: Review-fix-ladder (8 rungs × 2 verify)                │
│  /sb:review-fix-ladder in SB repo                           │
└────────────────────────────┬────────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────────┐
│  Layer 3: Live matrix (22 rows + Session 0)                     │
│  scripts/run-enterprise-e2e-live-test.sh                        │
│  + monitor-enterprise-e2e-matrix.sh                             │
│  + watch-enterprise-e2e-tui.sh                                  │
│  Fixture: enterprise-grade-test-app                             │
│  Matrix spec: test-app docs/WORKFLOW_E2E_MATRIX.md              │
└─────────────────────────────────────────────────────────────────┘
```

### Review-fix-ladder

- **Purpose:** Progressive multi-model audit of enterprise E2E scope (routes, hooks, skills, orchestrator, live wiring).
- **Gate:** 8 rungs, each requiring audit_fix + verify_1 + orchestrator grep + verify_2 (where applicable).
- **Strength:** Finds real gaps (e.g. Round 3 `probe_dev_cycle_bash_command` fallback in `tests/e2e-live/helpers.sh` @ `2ae7ca6e`).
- **Blind spot:** Cursor host substitutes `gpt-5.5-medium/high/xhigh` → `gpt-5.5-extra-high` or `composer-2.5-fast` when API limits or slug rejection occur — ladder documents substitutions but **does not fail the round** when intended model never ran.

### Structural suite

- **Purpose:** Validate scripts, runbook needles, matrix row count, ledger template, auth policy strings, RTK coexistence docs — **no interactive Claude**.
- **Strength:** Fast, deterministic, runs in default CI.
- **Blind spot:** Proves documentation and file existence, not runtime hook delivery in real TUI (that’s `hook-delivery-preflight.sh` + live matrix).

### Live matrix (22 rows)

| Row class | Count | Notes |
|-----------|-------|-------|
| Routing | 1 | Row 1 — `/sb` only; highest harness fragility |
| Standalone workflows | 19 | Rows 2–20 |
| Internal (parent-triggered) | 2 | Rows 21–22 inside rows 3 and 4 |

**Pass criteria** (from matrix): correct route; orchestrator parent does not implement inline; skills recorded in state; flow log CSV advances; artifacts at evidence paths; no false hook blocks.

**Dual-role monitoring:**

| Shell | Script | Role |
|-------|--------|------|
| A | `run-enterprise-e2e-live-test.sh --resume` | Drive matrix |
| B | `monitor-enterprise-e2e-matrix.sh` | 429/network/stall recovery |
| C | `watch-enterprise-e2e-tui.sh` | Turn-level findings; restarts monitor |

### Strengths

1. **End-to-end path coverage** — all 22 catalog workflows exercised on a realistic fixture.
2. **Operational learnings encoded** — API-key-only auth, 60s quota retry, `--resume`, provider restart, RTK verbatim mode for harnesses.
3. **Evidence discipline** — ledger schema with `graphify_query_ref`, `agentmemory_export_ref`, SB fix commits.
4. **Preflight stack** — hook-delivery, code-intel (Graphify, agentmemory, RTK, Context Mode) when opted in.
5. **Regression feedback loop** — matrix failures → SB fixes → `install-claude.sh` → re-run failed rows only.

### Blind spots

1. **No Codex/Cursor matrix** — Claude TUI only; homepage claims tri-host.
2. **Harness > product** — Round 3 row 1 failures were expect/ANSI/disclaimer, not router logic.
3. **Evidence existence ≠ evidence validity** — file at path does not prove gates actually blocked/allowed correctly.
4. **Monitor ≠ ledger** — completion signal can diverge from human-auditable truth.
5. **Session 0 manual gap** — programmatic tool opt-in bypasses real `/sb:init` UX.
6. **No claims traceability** — homepage not in CI gate.
7. **Environmental noise** — 429, proxy, provider changes consume days; misdiagnosed as SB bugs.
8. **Single fixture** — one Node API + UI stub; DevOps blast-radius claims under-tested.
9. **Model/config drift** — frozen model in ledger often blank or substituted.
10. **No flake budget** — “2 consecutive clean rounds” has no statistical definition.

---

## 3. Website claims inventory

**Primary source:** [`site/index.html`](../../site/index.html) (local homepage, deployed at [sb.alolabs.dev](https://sb.alolabs.dev))  
**Secondary:** [`README.md`](../../README.md), [`docs/pm/research/gaps/SB-PROBLEM-MAP.md`](../pm/research/gaps/SB-PROBLEM-MAP.md)

### Hero & positioning

| Claim | Source | Current test coverage | Gap | Proposed verification |
|-------|--------|----------------------|-----|----------------------|
| Agentic Process Orchestrator for AI-native SDLC & DevOps | `site/index.html` title, `#hero-main` | Catalog contract tests (`apo-catalog.json`); composable-flows parity | No E2E “APO behavior” score | Contract test: catalog counts match site + README; E2E row 1 proves router |
| THE PROCESS LAYER OF AI-DRIVEN DEV | Hero tagline | None specific | Marketing only | Map to mechanism claims below |
| Maximize Dev Process Reliability at 10x Lower Cost | `#hero-main` h2 | RTK/Context Mode opt-in in preflight only | **No cost measurement** | Benchmark harness: tokens/session with vs without SB+RTK+CM on fixed tasks; publish distribution not point claim |
| 100% Free Forever · No Telemetry | Hero CTA note, `#install` | Privacy/terms docs; no telemetry in hook audit grep | No automated telemetry scan | CI: grep/install manifest audit for outbound analytics; `sb-diagnostics` documents tier |
| Runs inside Claude Code, Codex, Cursor | Hero intro, `#guide` | Claude live matrix; Codex/Cursor install scripts in structural suite | **Codex/Cursor E2E absent** | Host matrix: same 5-row smoke per host (init, router, feature, fast, ship-readiness) |
| Blocks unsafe commits, PRs, releases until evidence is real | Hero intro | Hook unit tests; completion-audit e2e-live; matrix rows 14–16 | Not proven in live PR create path | Simulated TUI: `gh pr create` blocked without evidence fixtures |
| Eight hero capabilities (best practices, tailored workflows, V&V, gates, traceability, cost, intent, knowledge) | Hero feature list | Partial via matrix rows 1–20 | No per-capability scorecard | Claims traceability matrix (§6 P0) |

### Problem → solution (PAIN 01–09)

| Claim | Source | Current test coverage | Gap | Proposed verification |
|-------|--------|----------------------|-----|----------------------|
| PAIN 01: Agent skips planning | `#problem` | `dev-cycle-check.sh` tests; matrix row 3 feature | Live proof intermittent | Adversarial: agent attempts Edit before plan → hook BLOCK recorded |
| PAIN 02: Spec/PR drift | `#problem` | `pr-traceability.sh`, session-start tests | No matrix row for traceability block | Dedicated row: PR description contains traceability block |
| PAIN 03: Done without evidence | `#problem` | `stop-check`, `completion-audit` tests | Matrix doesn't assert stop hook fired | Row 16 ship-readiness + simulated premature done |
| PAIN 04: Context rot | `#problem` | Context Mode docs; opt-in preflight | Opt-in not enforced in matrix | Session with compaction injection + prompt-reminder assertion |
| PAIN 05: Infra without blast radius | `#problem` | Row 11 devops | Fixture Terraform is stub | Expand fixture or blast-radius gate unit + devops row criteria |
| PAIN 06: Frontier spend / cheaper models blind | `#problem` | RTK/Graphify preflight | No cost A/B | Token budget fixture runs |
| PAIN 07: Knowledge evaporates | `#problem` | agentmemory opt-in; row 2 research ADR | No cross-session recall test | Two-session test: session 2 retrieves ADR via Graphify/agentmemory |
| PAIN 08: Security after merge | `#problem` | `sb:secure` in ladder scope | No live security gate row | Row: `sb:secure` produces BLOCK finding on injected vuln |
| PAIN 09: Backlog graveyard | `#problem` | `/sb:add` scripts tested | No matrix row | Add row or sub-criterion in feature row |

### Cost of inaction stats

| Claim | Source | Current test coverage | Gap | Proposed verification |
|-------|--------|----------------------|-----|----------------------|
| 39% AI code vulnerabilities (Veracode 2025) | `#cost` | Cited on site only | **Third-party stat — not SB claim** | Label as external citation in claims checker; do not assert in E2E |
| $14K–$28K outage cost | `#cost` | None | Anecdotal aggregate | Footnote + “illustrative” tag; no automated test |
| 7× rework without spec coverage | `#cost` | None | **Internal benchmark — unverified in CI** | Reproduce benchmark fixture or soften homepage wording |
| ~30% tokens re-discovering decisions | `#cost` | None | **Unverified** | Measure with RTK+CM+agentmemory on fixture; publish methodology |

### Mechanism & catalog

| Claim | Source | Current test coverage | Gap | Proposed verification |
|-------|--------|----------------------|-----|----------------------|
| 27 atomic flows, 22 workflows, 85 V-loops | `#mechanism`, `#proof`, meta description | `apo-catalog.json` contract; structural suite | Count drift possible | CI: `scripts/validate-apo-catalog.sh` vs site constants |
| Twelve hook layers — enforcing, not decorative | `#mechanism` | Per-hook test files; hook-delivery preflight 3/3 | Not all 12 in one live session | `sb-diagnostics.sh` tier report in preflight artifact |
| Two-tier delivery discipline | `#mechanism` | `dev-cycle-check`, `completion-audit` tests | Live fast vs feature not compared | Rows 6 vs 3: fast touches only README; feature requires full chain |
| Dynamic `/sb` composition | `#mechanism` | Row 1 | Harness fragility | PTY contract tests for row 1 (§6 P0) |
| V-loop BLOCK/WARN/INFO; validate-evidence-findings | `#mechanism` | Evidence schema tests | Live validator not in matrix | Ship-readiness row asserts findings file |
| Spec-to-release traceability | `#mechanism` | Hook tests | Weak live proof | New matrix sub-check or row 15 extension |
| Graphify + agentmemory + RTK + Context Mode | `#code-intelligence` | Preflight when opted in | Opt-in; not validated for retrieval quality | Code-intel smoke: `graphify query` returns nodes; agentmemory health |
| sb-bootstrap.sh / sb-diagnostics.sh proof | `#proof` | Structural references | Not run in enterprise gate | Add to `--preflight-only` artifact capture |
| Enforcement tier 4–5 highest | `#proof` | `RUNTIME-COMPATIBILITY.md` | Per-host live tier not recorded | Ledger field: `sb_diagnostics_tier` per host |
| Instruction-following doesn't work (76.2% failure) | Session audit | Meta-audit exists | Irony: homepage session had 76% instruction failure | Use as rationale for hook-first testing, not as passing claim |

### FAQ & competitive

| Claim | Source | Current test coverage | Gap | Proposed verification |
|-------|--------|----------------------|-----|----------------------|
| Two-tier won't slow every commit | `#faq` | Row 6 fast | Single pass | Re-run fast row under time budget |
| No vendor lock-in; switch hosts | `#faq` | Install docs | No cross-host matrix | Tri-host smoke suite |
| Doesn't replace CI/CD | `#faq` | `ci-status-check` tests | — | Document + test: hook blocks when CI red |
| Enterprise-grade / support available | `#faq` | This E2E program | Alpha disclaimer vs “enterprise-grade” | Align wording: “enterprise validation program” vs product maturity |
| Breadth + hook accountability vs plugins | `#parity` | Qualitative | No competitor regression | Out of scope for SB CI; manual competitive audit |

### First hour / onboarding

| Claim | Source | Current test coverage | Gap | Proposed verification |
|-------|--------|----------------------|-----|----------------------|
| First unsafe PR blocked in 30–60 min | `#next-steps` | None automated | **High-risk homepage promise** | Timed onboarding script: init → feature → attempted PR → expect BLOCK |
| Minutes 0–10 install + probe | `#next-steps` | `install-claude.sh` in preflight | No timing SLO | `sb-bootstrap.sh` + diagnostics &lt; 10 min gate on CI runner |
| Session stops losing context | `#next-steps` | agentmemory opt-in | Not tested | Two-session recall test |

### Brooks / silver bullet thesis

| Claim | Source | Current test coverage | Gap | Proposed verification |
|-------|--------|----------------------|-----|----------------------|
| Process layer closes delivery gap | `#brooks-closing` | Philosophy | Not falsifiable in E2E | Outcome metrics: defect escape rate on fixture |
| Evidence schema agent cannot forge | `#brooks-closing` | Schema tests | Adversarial forgery not tested | Negative test: tampered evidence → validator BLOCK |

---

## 4. Failure modes observed in this session (Rounds 1–3)

### 4.1 429 / proxy vs quota confusion

| Symptom | Root cause | Misdiagnosis | Correct action |
|---------|------------|--------------|----------------|
| Row stuck 600s+ | API 429, Token Plan, OpenCode weekly limit | “Auth failure”, “hung claude” | Wait `SB_E2E_MATRIX_QUOTA_RETRY_INTERVAL=60` (retry environmental); retry same row |
| ConnectionRefused | Proxy down (`127.0.0.1:15721`) | SB hook bug | Fix proxy; provider restart procedure |
| Monitor restart loop | Network blip | Matrix logic error | 120–300s backoff per runbook |

**Round 3:** Row 1 runner alive in 429 retry — retry every 60s; do not treat proxy weekly-reset messaging as block. Preflight hook probe hardening (`1aa7fb4c`, `2ae7ca6e`) addressed **probe timeout**, not quota.

### 4.2 Bypass Permissions expect / TUI fragility

- Claude shows **Bypass Permissions** menu on startup.
- `scripts/claude-interactive-invoke.expect` matched ANSI sequences (`[3G`, `[5G2.`) unreliably.
- Fixes: `bd157508` … `398209d3` (ANSI disclaimer bypass).
- **Lesson:** Matrix row 1 is a **harness contract test**, not router test. Flakes here block entire round.

### 4.3 Operator pause points

- Round 2: 3hr quota → provider change → manual restart rows 5–22.
- Round 3: Cursor restart; operator handoff doc required.
- Policy says “never pause for operator” but **provider change** and **Cursor restart** still need human.

### 4.4 gpt-5.5 API limits / model substitution in ladder

- Round 1: `gpt-5.5` → `gpt-5.5-extra-high` slug rejected; rungs 6–8 → `composer-2.5-fast`.
- Round 3: rungs 5–6 substituted to `composer-2.5-fast`; 7–8 used `gpt-5.5-extra-high`.
- **Lesson:** Ladder “clean” ≠ “ran on advertised model ladder.”

### 4.5 Ledger drift

- Round 3 monitor: `COMPLETE 22/22` @ 19:22:28.
- Ledger: 8 PASS, 4 FAIL, 10 unclear; row 1 in progress.
- **P0:** Monitor completion must require ledger reconciliation or shared state machine.

### 4.6 Session 0 manual gap

- Round 3: programmatic `recommended_tools.*.enabled_by_user` + `graphify update .`
- Skips real `/sb:init` TUI flow tested by “first hour” claims.
- Round 1: `--print` path lacks Skill tool — init partial.

### 4.7 Graphify overwrite refused

- Rounds 1–2: `graphify update .` refused (node count mismatch).
- Marked Warn, round continued — graph staleness risk for `graphify query` refs.

### 4.8 RTK vs harness verbatim

- Agent sessions benefit from RTK; harnesses need `SB_RTK_COMPAT_MODE=verbatim` / `RTK_DISABLED=1`.
- Fixed in docs; conftest drift breaks grep-based assertions if forgotten.

### 4.9 Internal rows 21–22

- Depend on parent rows 3 and 4 completing with gate evidence in ledger notes.
- Round 3: FAIL when parents incomplete — correct dependency, easy to miss in monitor aggregate.

### 4.10 Instruction-following irony

- [SESSION-AUDIT-2026-06-28.md](../instruction-following/SESSION-AUDIT-2026-06-28.md): **76.2%** actionable instruction failure rate on homepage work.
- SB’s thesis: hooks compensate for instruction-following failure — **E2E should demonstrate that**, not replicate the failure mode.

---

## 5. Proposed testing architecture (target state)

### 5.1 Layer model

```
┌──────────────────────────────────────────────────────────────────────────┐
│ L6  Release gates — 2× confidence score + claims audit green            │
├──────────────────────────────────────────────────────────────────────────┤
│ L5  Claims verification — 100% homepage fulfillment program             │
├──────────────────────────────────────────────────────────────────────────┤
│ L4  Supervised live — 22-row matrix (Claude) + 5-row smoke (Codex/Cursor)│
├──────────────────────────────────────────────────────────────────────────┤
│ L3  Simulated TUI — PTY fixtures, golden transcripts, menu contracts      │
├──────────────────────────────────────────────────────────────────────────┤
│ L2  Contract — apo-catalog, evidence schema, site↔repo constant parity  │
├──────────────────────────────────────────────────────────────────────────┤
│ L1  Unit/structural — run-all-tests + enterprise-e2e-live-suite         │
└──────────────────────────────────────────────────────────────────────────┘
```

**Dependency rule:** Higher layers run less frequently; lower layers must be green first.

### 5.2 Claims verification program (100% website fulfillment)

1. **Extract** — Machine-readable `docs/testing/claims-registry.json` from `site/index.html` + README (owner: docs tooling).
2. **Map** — Each claim → test_id(s) + evidence artifact schema.
3. **Enforce** — CI job `claims-audit` fails on unmapped new homepage text.
4. **Soften or prove** — Unprovable stats (7×, 30%, 10x) either get benchmark fixtures or homepage qualifier text.
5. **Report** — Per-release `CLAIMS-REPORT.md` with ✅/⚠️/❌ per claim.

### 5.3 Non-flaky harness requirements

| Requirement | Implementation |
|-------------|----------------|
| PTY contract tests | `tests/tui-contract/` — disclaimer, bypass menu, queue conflict, ANSI tolerance |
| Golden transcripts | Recorded byte streams for row 1 startup; expect matches normalized stream |
| Single source of truth | Monitor reads/writes same ledger API as human (`SB_E2E_LEDGER_FILE`) |
| Quota classification | `matrix-quota.sh` unit tests with fixture stderr samples |
| No stdout parsing for git | `RTK_DISABLED=1` on all harness scripts (already documented) |
| Timeout budgets | Row-class timeouts in runbook + CI simulated caps for contract tests |
| Retry limits | Max N quota retries per row before FAIL with `environmental` label |

### 5.4 Proxy/auth test matrix (API key only)

| Config | Purpose |
|--------|---------|
| Direct Anthropic API key | Primary live matrix |
| Local proxy (`ANTHROPIC_BASE_URL`) | Round 2 path — must be explicit in ledger |
| `SB_E2E_MATRIX_CLEAN_ENV=0` | Default inherit auth |
| `SB_E2E_MATRIX_DRY_RUN=1` | CI wiring only — never counts as live pass |

**Never in live runs:** `claude auth login/logout`, `setup-token`.

### 5.5 Cross-host coverage

| Host | Minimum E2E smoke (target) |
|------|----------------------------|
| Claude Code | Full 22-row matrix (current) |
| Codex | 5 rows: init, router, feature, fast, ship-readiness |
| Cursor | 5 rows: same + cursor-hook-bridge session-start |

Record `sb-diagnostics.sh` output per host in ledger.

### 5.6 Performance / reliability SLOs (proposed)

| Metric | SLO | Measurement |
|--------|-----|-------------|
| Structural suite | &lt; 2 min, 0 failures | CI every push |
| run-all-tests | &lt; 30 min, 0 failures | Pre-matrix gate |
| Row 1 contract tests | &lt; 5 min, 0 failures | CI every push |
| Matrix row (median) | &lt; 45 min active (excl. quota wait) | Ledger timestamps |
| Round completion | ≤ 5 business days operator calendar | Program metric |
| Ledger↔monitor agreement | 100% | Automated reconcile |
| Flake rate | &lt; 5% row retries due to harness | Label `harness` vs `product` vs `environmental` |

### 5.7 Adversarial / orchestrator regression suite

| Scenario | Expected |
|----------|----------|
| Parent implements feature inline | orchestrator-directive-guard BLOCK |
| Edit before plan | dev-cycle-check BLOCK |
| PR without completion audit | completion-audit BLOCK |
| Tampered evidence JSON | validate-evidence-findings BLOCK |
| Deprecated skill route | forbidden-skill-check BLOCK |
| Orchestrator queue stall | watch script emits stall finding |

Existing tests cover many; **live matrix should include at least one adversarial row** or dedicated `tests/adversarial-orchestrator/` e2e-live scenarios.

---

## 6. Improvements (prioritized roadmap)

### P0 — Measurement integrity (before next release tag)

| ID | Deliverable | Owner | Acceptance criteria |
|----|-------------|-------|---------------------|
| P0-1 | Ledger↔monitor reconciliation | E2E harness | Monitor cannot emit COMPLETE unless ledger shows 22 PASS with required refs |
| P0-2 | PTY contract tests for row 1 | Harness | `tests/tui-contract/test-bypass-disclaimer.sh` passes on CI without live API |
| P0-3 | Claims registry + CI audit | Docs/CI | `claims-audit` fails if site/index.html adds unmapped claim |
| P0-4 | Environmental failure taxonomy | Operator docs | Ledger `failure_class`: harness \| product \| environmental |
| P0-5 | Session 0 gate | Matrix | Row 0 checklist: TUI init OR explicit `SB_E2E_SESSION0_SKIP=1` with reason |

### P1 — Reduce live-TUI dependency

| ID | Deliverable | Owner | Acceptance criteria |
|----|-------------|-------|---------------------|
| P1-1 | Golden transcript fixtures | Harness | Row 1 driven from fixture 95% of CI runs |
| P1-2 | Simulated workflow runner | E2E | 5 workflows run via `claude --print` + skill injection for gate checks |
| P1-3 | Tri-host 5-row smoke | E2E | Codex + Cursor smoke in opt-in nightly |
| P1-4 | Ladder model-lock enforcement | Ladder | Round fails if &gt;2 rungs substitute models without waiver |
| P1-5 | Website claim checker skill | Agent | `/sb:claims-audit` or skill in repo |

### P2 — World-class reliability

| ID | Deliverable | Owner | Acceptance criteria |
|----|-------------|-------|---------------------|
| P2-1 | Token/cost benchmark fixture | Research | Publish median token delta RTK+CM on fixture |
| P2-2 | Two-session knowledge recall | E2E | Session B retrieves ADR from session A via Graphify |
| P2-3 | Timed onboarding SLO | E2E | 60-min script: init → block PR |
| P2-4 | Expand fixture for blast-radius | Test app | DevOps row validates Terraform policy + rollback doc |
| P2-5 | Statistical release gate | Release | See §7 — confidence score replaces raw 2×22/22 |

---

## 7. Round gate evolution

### What replaces or augments “2 consecutive clean rounds”

**Current gate** (from [ENTERPRISE-E2E-LIVE-TEST.md](../ENTERPRISE-E2E-LIVE-TEST.md)):

1. 22/22 PASS in ledger (graphify + agentmemory refs)
2. `/sb:review-fix-ladder` — 8 rungs, 2× clean verify each
3. `bash tests/run-all-tests.sh` → 0 failures
4. `graphify update .` in SB repo
5. No open MUST-FIX

**Problems:** Binary, flake-sensitive, no host coverage, monitor drift, environmental noise counts equally with product bugs.

### Proposed: Release Confidence Score (RCS)

| Component | Weight | Pass threshold |
|-----------|--------|----------------|
| `run-all-tests` green @ pinned SHA | 20% | Required |
| Structural + contract + tui-contract green | 15% | Required |
| Ladder 8/8 with ≤2 model substitutions | 15% | ≥ 12/15 |
| Matrix 22/22 ledger @ pinned SHA | 25% | ≥ 20/22 for minor release; 22/22 for major |
| Claims audit | 15% | ≥ 90% claims mapped and green |
| Tri-host smoke (Claude full + Codex/Cursor 5-row) | 10% | Claude required; others warn until P1-3 |

**Consecutive requirement:** **2 rounds with RCS ≥ 85** AND **no P0 product failures** AND **ledger↔monitor 100% agreement** on matrix rounds.

### Definition of “absolutely sure” / release confidence

Release owners can tag `enterprise-e2e-matrix` + `claude-supervised` when:

1. **RCS ≥ 90** on two consecutive rounds at **frozen SHAs** (SB + test app + plugin version).
2. **Zero open `enterprise-test-app` defects** with severity ≥ P1.
3. **Claims audit** has no ❌ on hook-enforcement or catalog-count claims.
4. **One human spot-check** — 3 random matrix rows reviewed for evidence *quality* (not just file existence).
5. **Environmental waiver** documented if any row passed via quota retry &gt; 3 times.

“Absolutely sure” is **not** “matrix ran once without looking.” It is **statistical + evidentiary + claims-aligned**.

---

## 8. Metrics & artifacts

### Per-round metrics (record in ledger)

| Metric | Location |
|--------|----------|
| SB SHA, test app SHA, plugin version | Round metadata |
| Per-row: start, end, active duration, retry count | Row table + log |
| `failure_class` per fail | Row Issues column |
| `graphify_query_ref` | Required on PASS |
| `agentmemory_export_ref` | Required on PASS |
| `sb_diagnostics_tier` per host | New metadata block |
| Quota wait total | Round summary |
| Model substitutions (ladder) | Ladder table |
| Harness vs product fix commits | Defects table |

### Artifacts

| Artifact | Path |
|----------|------|
| Matrix log | `.e2e-matrix-live.log` |
| Monitor status | `.e2e-matrix-monitor-status.txt` |
| TUI watch findings | `.e2e-tui-watch-findings.jsonl` |
| Row debug | `.e2e-row{N}-attempt.log` |
| Round ledger | `.planning/enterprise-e2e/ROUND-N-LEDGER.md` |
| run-all-tests log | `.run-all-tests-roundN-gate.log` |
| Claims report | `docs/testing/CLAIMS-REPORT-ROUND-N.md` (target) |

### agentmemory / Graphify refs

- **Graphify:** `graphify query "<slug> routes hooks skills orchestrator"` before each row; `graphify update .` after SB edits.
- **agentmemory:** MCP capture per session; retrieve via Graphify indexed exports, not raw transcript dumps.
- **Ledger improvement:** require `graphify_node_ids` or search snippet hash for auditability.

### Ledger schema improvements (proposed)

```markdown
| # | WF slug | Pass/Fail | failure_class | active_s | retries | evidence_validated | graphify_ref | agentmemory_ref |
```

Add **Round confidence** footer: `RCS: 87/100`, `ledger_monitor_agree: yes/no`, `claims_audit: 94%`.

---

## 9. Anti-patterns to avoid

| Anti-pattern | Why it fails | Do instead |
|--------------|--------------|------------|
| Treating 429 as SB bug | Wastes days; wrong fixes | `failure_class=environmental`; wait 60s |
| Trusting monitor without ledger | Round 3 false complete | Reconcile before resume |
| Restarting matrix at row 1 | Burns quota | `--resume` incomplete rows only |
| `claude auth login` during live | Breaks API-key-only policy | Export settings env via `claude-matrix-auth.sh` |
| Counting dry-run as live pass | False confidence | Unset `SB_E2E_MATRIX_DRY_RUN` |
| Parent implements product code | Defeats orchestrator test | Enforce worker spawn in row criteria |
| Skipping `install-claude.sh` after SB fix | Stale plugin in TUI | Reinstall before failed row retry |
| Model substitution without waiver | Ladder false negative | Document in ladder table; fail if excessive |
| Evidence path exists = pass | Wrong route still writes files | Spot-check route + skill state |
| Homepage stat as CI gate | Unproven external/internal numbers | Cite or benchmark |
| Over-reliance on interactive sessions | Flaky, expensive | PTY contracts + golden transcripts in CI |
| Committing test-app init artifacts | Pollutes fixture | Programmatic opt-in only in test app |
| Ignoring Graphify stale warn | Wrong query context | Force update or pin graph SHA in ledger |

---

## 10. Appendix

### A. Reference documents & scripts

| Resource | Path |
|----------|------|
| Live test runbook | [docs/ENTERPRISE-E2E-LIVE-TEST.md](../ENTERPRISE-E2E-LIVE-TEST.md) |
| Operator prompt | [scripts/ENTERPRISE-E2E-OPERATOR-PROMPT.md](../../scripts/ENTERPRISE-E2E-OPERATOR-PROMPT.md) |
| Workflow matrix (fixture) | `enterprise-grade-test-app/docs/WORKFLOW_E2E_MATRIX.md` |
| TUI protocol | [.planning/enterprise-e2e/CLAUDE-TUI-PROTOCOL.md](../../.planning/enterprise-e2e/CLAUDE-TUI-PROTOCOL.md) |
| Round ledgers | [.planning/enterprise-e2e/ROUND-N-LEDGER.md](../../.planning/enterprise-e2e/ROUND-N-LEDGER.md) |
| Round 3 handoff | [.planning/enterprise-e2e/ROUND-3-SESSION-HANDOFF.md](../../.planning/enterprise-e2e/ROUND-3-SESSION-HANDOFF.md) |
| Homepage | [site/index.html](../../site/index.html) → [sb.alolabs.dev](https://sb.alolabs.dev) |
| Problem map | [docs/pm/research/gaps/SB-PROBLEM-MAP.md](../pm/research/gaps/SB-PROBLEM-MAP.md) |
| APO catalog | [docs/apo-catalog.json](../apo-catalog.json) |
| Session audit | [docs/instruction-following/SESSION-AUDIT-2026-06-28.md](../instruction-following/SESSION-AUDIT-2026-06-28.md) |
| Live entrypoint | `scripts/run-enterprise-e2e-live-test.sh` |
| Matrix runner | `scripts/run-enterprise-e2e-matrix.sh` |
| Monitor | `scripts/monitor-enterprise-e2e-matrix.sh` |
| Watch | `scripts/watch-enterprise-e2e-tui.sh` |
| Structural suite | `tests/enterprise-e2e-live/test-enterprise-e2e-live-suite.sh` |
| Expect invoke | `scripts/claude-interactive-invoke.expect` |
| Quota helper | `scripts/lib/matrix-quota.sh` |
| Auth export | `scripts/lib/claude-matrix-auth.sh` |

### B. Sample claims → test mapping (top 10 homepage promises)

| # | Homepage promise | Test ID | Verification method |
|---|------------------|---------|---------------------|
| 1 | `/sb` composes smallest safe chain | `E2E-ROW-01` | Live matrix row 1: route invoked; `router-session.md`; skill state has router |
| 2 | 22 workflows pre-composed | `CONTRACT-APO-022` | `apo-catalog.json` WF count = 22; site constant check |
| 3 | Twelve hook layers enforce | `HOOK-LAYERS-012` | `run-all-tests` hook suite + `hook-delivery-preflight` 3/3 + diagnostics tier |
| 4 | Blocks PR without evidence | `E2E-SHIP-016` | Row 16 ship-readiness; completion-audit e2e-live scenario |
| 5 | Two-tier: fast vs full | `E2E-FAST-006` + `E2E-FEAT-003` | Row 6 touches README only; row 3 full feature + post-exec-gates |
| 6 | Works on Claude/Codex/Cursor | `HOST-SMOKE-003` | Claude 22-row; Codex/Cursor 5-row smoke (target P1-3) |
| 7 | Graphify orients in large repos | `CI-GRAPHIFY-001` | Preflight: graph exists; `graphify query` returns &gt;0 nodes |
| 8 | agentmemory persists decisions | `CI-MEM-001` | Health check; export dir; row 2 ADR artifact |
| 9 | No telemetry | `PRIV-001` | CI grep plugin manifests for analytics endpoints |
| 10 | First blocked delivery in first hour | `ONBOARD-060` | Timed script: init → feature → premature PR → BLOCK (target P2-3) |

### C. Round history summary

| Round | Matrix | run-all-tests | Ladder | Notable issues |
|-------|--------|---------------|--------|----------------|
| 1 | 22/22 (ledger) | 4345–4610/0 | Pass | Cursor fallback, 429, partial Session 0 |
| 2 | 22/22 | 4345/0 @ gate SHA | Pass | Provider change mid-batch |
| 3 | 8/22 (paused) | 4695/0 | Pass | Monitor/ledger drift, row 1 expect+429 |

### D. Glossary

| Term | Meaning |
|------|---------|
| **Clean round** | All five current gates pass at pinned SHAs |
| **RCS** | Release Confidence Score (proposed) |
| **Structural suite** | Non-interactive enterprise wiring tests |
| **failure_class** | harness \| product \| environmental |
| **Session 0** | `/sb:init` bootstrap — not in 22 rows |

---

*This plan is intentionally honest: the enterprise E2E program is among the stronger agent-plugin validation efforts in the ecosystem, but it does not yet prove what the homepage promises. Close that gap with claims traceability, harness contracts, and tri-host smoke — not more manual TUI hours alone.*
