# Cursor Methodology & Harness Readiness Audit

**Audit date:** 2026-07-04  
**SB `main` SHA audited:** post-gap-fill (methodology + cursor3 driver TUI offset reset)  
**Auditor scope:** E2E-086–E2E-115 + Cursor-3 REAL session arc vs [ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md](./ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md); Cursor harness production-readiness for honest `cursor-agent` work  
**Cross-check sources:**

| Source | Path |
|--------|------|
| Methodology (canonical) | [ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md](./ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md) |
| Issue registry E2E-086–115 | [ENTERPRISE-E2E-SB-ISSUES.md](../issues/ENTERPRISE-E2E-SB-ISSUES.md) |
| Cursor-3 REAL ledger (canonical) | [.planning/enterprise-e2e/ROUND-CURSOR-3-REAL-LEDGER.md](../../.planning/enterprise-e2e/ROUND-CURSOR-3-REAL-LEDGER.md) |
| Void Cursor-1/2 | Appendix D methodology; ledger void policy |
| Harness entrypoints | `tests/live/agents/cursor/agent.sh`, `scripts/enterprise-e2e/matrix.sh`, `scripts/enterprise-e2e/lib/core.sh`, `.planning/enterprise-e2e/cursor3-real-*.sh`, `.cursor3-monitor-loop.sh` |

---

## Part A — E2E-086–115 methodology coverage

Each issue ID must map to **§11a/§11b row** + **operator prevention rule**.

| ID | §11a/§11b | Operator rule | Status |
|----|-----------|---------------|--------|
| E2E-086 | §11a | §5b log floor; TUI offset reset at round start | **PASS** |
| E2E-087 | §11a | Cursor timeout ≥1800s; row 8/11 extended timeouts | **PASS** |
| E2E-088 | §11a | Outcome scorer fixes → live rerun after harness fix | **PASS** |
| E2E-089 | §11a | Rescore ≠ strict-clean | **PASS** |
| E2E-090 | §11a | Fixture branch lock + worktree | **PASS** |
| E2E-091 | §11a | Routing-only clarify n/a | **PASS** |
| E2E-092 | §11a | Cursor timeout ≥1800s in driver/tmux | **PASS** |
| E2E-093 | §11a | stream-json + composite transcript log floor | **PASS** |
| E2E-094 | §11a | Fast-path orch n/a row 6 | **PASS** |
| E2E-095 | §11a | FORCE on brownfield first live | **PASS** |
| E2E-096 | §11a | Babysitting / `SB OVERRIDE:` scorer | **PASS** |
| E2E-097 | §11a | Row 14 release evidence path | **PASS** |
| E2E-098 | §11a | Row 14 KM graphify preamble | **PASS** |
| E2E-099 | §11a | Row 15 triad evidence path | **PASS** |
| E2E-100 | §11a | Internal rows 21–22 parent inherit + log floor exempt | **PASS** |
| E2E-101 | §11b | Fixture branch lock pre/post | **PASS** |
| E2E-102 | §11b | FORCE / FORCE_ALL distinction | **PASS** |
| E2E-103 | §11b | Row 3 api/currency §5b | **PASS** |
| E2E-104 | §11b | Rows 14/15/16 live drivers | **PASS** |
| E2E-105 | §11b | Claude isolated state per row | **PASS** |
| E2E-106 | §11b | §5b smoke rows 6/11 + internal 21–22 | **PASS** |
| E2E-107 | §11b | Bracketed-paste confirm | **PASS** |
| E2E-108 | §11b | Codex install skip on REAL drivers | **PASS** |
| E2E-109 | §11b | Fixture root before mkdir | **PASS** |
| E2E-110 | §11b | Claude inherit-keys bypass | **PASS** |
| E2E-111 | §11b | Hook audit on isolated state | **PASS** |
| E2E-112 | §11b | Latest attempt log for rescore | **PASS** |
| E2E-113 | §11b | `$LEDGER` in strict-clean summary | **PASS** |
| E2E-114 | §11b | §5a/§5b product audit (Codex mirror) | **PASS** |
| E2E-115 | §11b | CI-writable fixture paths | **PASS** |

**E2E-086–115 coverage: 30/30 PASS**

---

## Part B — Session lesson coverage

| Lesson | Methodology cite | Status |
|--------|------------------|--------|
| Inherited evidence disqualifying | §5a #1; Appendix D | **PASS** |
| Rescoring ≠ strict-clean | §5a #2; §6; E2E-089 | **PASS** |
| Install-skip on first cert void | §5a #5; §6a | **PASS** |
| Empty / stub logs (<2048 B) | §5a #3; §5b log floor | **PASS** |
| Audit-only sessions | §5a #4 | **PASS** |
| Worktree isolation | §4; §9; E2E-090 | **PASS** |
| Branch guard (`assert_host_git_branch`) | §9 #8 | **PASS** |
| tmux durable drivers | §8 | **PASS** |
| Keychain Cursor auth (not API key) | §8 Cursor auth | **PASS** |
| Composer 2.5 only | §8; operator rules | **PASS** |
| stream-json headless capture | §11a E2E-093; §5b Cursor column | **PASS** |
| Composite transcript footer | §11a E2E-093; `finalize_attempt_log` | **PASS** |
| Brownfield FORCE | §5a; E2E-095; drivers | **PASS** |
| Ship-readiness consistency row 16 | §5b; §5a #4 | **PASS** |
| Post-merge re-cert | §11b post-merge sibling | **PASS** |
| Codex branch lock | §9; operator rules | **PASS** |
| Claude state isolation | §11b E2E-105 | **PASS** |
| Internal gates 21–22 | §5a #6; Appendix C; E2E-100 | **PASS** |
| Void Cursor-1/2 | Appendix D | **PASS** |
| TUI monitor offset reset | §8; operator rules; issues doc | **PASS** (driver fix applied) |
| Ledger-derived `round-N-{host}` | §4 rule 6 | **PASS** |
| Anti-faking §5a/§5b | §5a–§5b full | **PASS** |

**Session lessons: 22/22 PASS**

---

## Part C — Gaps found and fixes applied

| Gap | Fix |
|-----|-----|
| Operator rules table missing E2E-088, 091–094, 097–099, 104, 106–107, 109–113, 115 | Expanded operator-rules table in methodology |
| TUI monitor offset reset undocumented in methodology | §8 + operator rules; issues cross-ref |
| `cursor3-real-driver.sh` / `cursor3-real-pipeline-driver.sh` omitted offset reset | Added `enterprise_e2e_reset_tui_monitor_offsets` at driver start |
| Ledger-derived branch override undocumented | §4 rule 6 + priority chain |
| Appendix C internal gates 21–22 thin | Expanded checklist with parent-chain + log-floor exempt |
| ROUND-CODEX-3-GATES.md merge conflict | **None present** @ audit time |

---

## Part D — Cursor harness readiness (§5b)

**Verdict: READY** for honest `cursor-agent` REAL work @ v0.50.2+ with operator supervision.

**Evidence:** Cursor-3 REAL **22/22 strict-clean** under §5a/§5b — [ROUND-CURSOR-3-REAL-LEDGER.md](../../.planning/enterprise-e2e/ROUND-CURSOR-3-REAL-LEDGER.md).

### Ready components

| Component | Evidence |
|-----------|----------|
| `agent.sh` stream-json + stdbuf + log preservation | `--output-format stream-json`, `--stream-partial-output`, harness prefix preserved |
| `matrix.sh` cursor timeouts | ≥1800s default; row 8→3600s; row 11→5400s |
| `core.sh` composite transcript | `enterprise_e2e_matrix_finalize_attempt_log` E2E-093 |
| REAL drivers | `cursor3-real-driver.sh`, `cursor3-real-pipeline-driver.sh` — FORCE, composer-2.5, worktree, TUI offset reset |
| Monitor loop | `.cursor3-monitor-loop.sh` — §5b scoring, internal 21–22 exempt, Phase C trigger |
| Outcome assessment | E2E-088/091/094/096–099 scorer fixes |
| Branch isolation | `test-app-branch.sh` ledger-derived round; fixture lock |

### Residual caveats (non-blocking)

| Caveat | Mitigation |
|--------|------------|
| Stdout buffering ~30 min with 0 B logs | Wait or verify stream-json path; §5b composite footer |
| Release pair 1/2 for Cursor | Cursor-4 needed for 2/2 consecutive strict-clean |
| Honest baseline `09f8d1a` vs Cursor-3 ledger `8482e60` metadata | New rounds must reset fixture to `09f8d1a` per §4 |
| `CURSOR_API_KEY` bypasses Keychain check in preflight | Drivers use Keychain login per §8 — do not set API key for cert rounds |

### Blockers

**None** — prior blocker (cursor3 drivers missing TUI offset reset) **fixed** in this session.

---

## Summary

| Metric | Result |
|--------|--------|
| E2E-086–115 methodology + prevention rules | **30/30 PASS** |
| Session lessons cited | **22/22 PASS** |
| Cursor harness REAL-work readiness | **READY** |
| 100% ready for real Cursor agent work? | **Yes** — with documented caveats above; evidence = Cursor-3 REAL 22/22 @ v0.50.2 harness |
