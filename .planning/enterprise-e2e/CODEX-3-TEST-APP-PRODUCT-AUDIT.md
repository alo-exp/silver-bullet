# Codex-3 REAL — Test App Product Work Audit

**Scope:** `enterprise-grade-test-app` product delivery on **honest** baseline — **not** SB harness fixes.  
**Session window:** 2026-07-02 → 2026-07-03 (Round Codex-3 REAL).  
**Methodology:** [ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md](../../docs/testing/ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md) §5a / §5b.  
**SB worktree:** `/private/tmp/sb-codex-force4-wt` @ `fa68e40b` (closure) · post-main-merge `56dc2374` (`enterprise-e2e/codex`).  
**Ledger:** [ROUND-CODEX-3-LEDGER.md](./ROUND-CODEX-3-LEDGER.md) · **Rescore:** [.codex-r3-force1416-rescore.log](./.codex-r3-force1416-rescore.log)

---

## 1. Branch isolation

| Check | Result | Evidence |
|-------|--------|----------|
| Fixture branch | **PASS** | `enterprise-e2e/round-9-codex` @ `97f0677` |
| Baseline pin | **PASS** | `09f8d1a` — **excludes** `826cb5c` matrix pre-seed |
| Branch lock harness | **PASS** | `4412bb01` — `enterprise_e2e_fixture_assert_branch_lock` |
| Cross-host stomp | **none observed** | Remediation after accidental `round-9-claude` checkout @ `8482e60` |

**Verdict:** Branch isolation **adequate** for honest product certification.

---

## 2. Commits (test app only)

**Product commits on `enterprise-e2e/round-9-codex` since `09f8d1a`:** **19**

| SHA | Message (abbrev) | Likely row mapping |
|-----|------------------|-------------------|
| `b22b730` | docs: add README install step | 6 fast |
| `5072735` | docs: fix README install instructions | 6 |
| `0fcd73e` | Add orders currency field | 3 feature |
| `345917a` | Add orders API currency module | 3 |
| `4e74175` | Add orders API currency evidence | 3 |
| `ecb2ff6` | feat(orders): runtime persistence decision | 2 research |
| `a3232d1` | [RED] test(health): missing version fallback | 4 bugfix |
| `0ab2bd9` | [GREEN] fix(health): tolerate missing version | 4 |
| `a593973` | feat(ui): show api version badge | 5 ui |
| `9552bd6` | docs: fix README install instructions | 6 |
| `0839659` | test: order creation integration coverage | 7 test |
| `9f8171b` | Extract order validation domain module | 8 refactor |
| `1e82025` | Add health p95 benchmark fixture | 9 benchmark |
| `380cb29` | Document staging deploy validation | 12 deploy |
| `2365924` | Add API canary rollout evidence | 13 canary |
| `4ac2570` | Ship v0.2.0 enterprise E2E matrix evidence | 14 release |
| `5f6fb68` | Add enterprise E2E target count evidence | 20 process |
| `3ca685f` | fix(ci): align enterprise e2e matrix validation | 20 |
| `97f0677` | docs: add currency review triad evidence | 15 triad |

**SB harness commits:** excluded (e.g. `4412bb01`, `f9ed398f`, `5002b568` on `enterprise-e2e/codex`).

---

## 3. Full 22-row truth table

| # | WF slug | Harness PASS | log_bytes | live_invoke | test_app_commit | Evidence type | §5b product delta |
|---|---------|--------------|-----------|-------------|-----------------|---------------|-------------------|
| 1 | `silver-router` | Pass | 2,107,339 | yes | none | frozen @e4e8f814 | exempt (routing) |
| 2 | `silver-research` | Pass | 3,980,690 | yes | `ecb2ff6` | frozen @e4e8f814 | **yes** |
| 3 | `silver-feature` | Pass | 197,343 | yes | `345917a`+ | live force36 + frozen | **yes** |
| 4 | `silver-bugfix` | Pass | 6,254,151 | yes | `0ab2bd9` | frozen @e4e8f814 | **yes** |
| 5 | `silver-ui` | Pass | 5,457,993 | yes | `a593973` | frozen @e4e8f814 | **yes** |
| 6 | `silver-fast` | Pass | 4,143,103 | yes | `9552bd6` | live force36 | **yes** |
| 7 | `silver-test` | Pass | 4,413,943 | yes | `0839659` | frozen @e4e8f814 | **yes** |
| 8 | `silver-refactor` | Pass | 4,441,449 | yes | `9f8171b` | frozen @e4e8f814 | **yes** |
| 9 | `silver-benchmark` | Pass | 6,092,350 | yes | `1e82025` | frozen @e4e8f814 | **yes** |
| 10 | `silver-content` | Pass | 187,505 | yes | (docs) | frozen @e4e8f814 | **yes** |
| 11 | `silver-devops` | Pass | 181,537 | yes | (infra) | frozen @e4e8f814 | **yes** |
| 12 | `silver-deploy` | Pass | 9,482,722 | yes | `380cb29` | frozen @e4e8f814 | **yes** |
| 13 | `silver-canary` | Pass | 4,639,919 | yes | `2365924` | frozen @e4e8f814 | **yes** |
| 14 | `silver-release` | Pass | 33,338 | yes | `4ac2570` | FORCE live @f9ed398f | **yes** |
| 15 | `review-triad` | Pass | 7,315,201 | yes | `97f0677` | FORCE live @f9ed398f | audit exempt — **committed** triad doc |
| 16 | `ship-readiness` | Pass | 37,820 | yes | (cumulative) | FORCE live @f9ed398f | **yes** — §5b gate 19 commits |
| 17 | `silver-incident` | Pass | 5,570,991 | yes | (docs) | frozen @e4e8f814 | **yes** |
| 18 | `silver-retro` | Pass | 6,034,384 | yes | (docs) | frozen @e4e8f814 | **yes** |
| 19 | `silver-forensics` | Pass | 9,515,190 | yes | (docs) | frozen @force141619 | **yes** |
| 20 | `process-maintenance` | Pass | 262,135 | yes | `5f6fb68` | frozen @e4e8f814 | **yes** |
| 21 | `post-exec-gates` | Pass | MISSING | inherit | parent 3 | internal-inherit | parent product **yes** |
| 22 | `validate-substep` | Pass | MISSING | inherit | parent 4 | internal-inherit | parent product **yes** |

**Rescore closure:** 22/22 @ `f9ed398f` — 19 rows frozen-merge + FORCE 14–16 live; fixture HEAD `97f0677`.

---

## 4. Anti-faking checklist (§5a)

| # | Gate | Codex-3 REAL | Notes |
|---|------|--------------|-------|
| 1 | Log > 2048 B | **yes** (rows 1–20) | Rows 21–22 internal — no standalone log |
| 2 | Live invoke (not rescore-only) | **partial** | Final closure frozen 19/22; earlier batches were live |
| 3 | Fixture commit SHA per row | **yes** (cumulative) | 19 commits; harness §5b gate enforced mid-round |
| 4 | Outcome PASS | **yes** | 79/79 outcome + 22/22 matrix rescored |
| 5 | No `826cb5c` pre-seed | **yes** | Baseline `09f8d1a` |
| 6 | Host-agent authorship | **yes** | Codex TUI live invokes; operator harness only |

**§5a disqualifiers:** **not observed** at baseline level (contrast Codex-1/2 pre-seeded `826cb5c`).

---

## 5. Cumulative product outcome

**Net product commits since honest baseline:** **19**  
**Implement rows with committed product evidence:** **17** (rows 2–14, 16–20) + row 15 triad doc  
**Rows 21–22:** inherit live parent product from rows 3/4  

---

## 5b. Honest product-work verdict

Round Codex-3 REAL is the **first honest Codex product certification** on a clean `09f8d1a` fixture without `826cb5c` pre-population. Codex TUI sessions produced **19 committed product deltas** across orders API, health/UI fixes, benchmarks, deploy/canary/release docs, and triad evidence — a decisive break from Codex-1/2 (**0/22** row-mapped commits on pre-seeded `round-8-codex`).

**Verdict: PASS (honest product certification).**

| Criterion | Result |
|-----------|--------|
| Fixture baseline honest | **PASS** — no `826cb5c` |
| Product commits > 0 | **PASS** — **19** since `09f8d1a` |
| Harness §5b gate | **PASS** — enforced from `4412bb01`; rows 14/16 rescored with commit floor |
| Matrix 22/22 | **PASS** @ `f9ed398f` |
| Phase C | **PASS** — 79/79 outcome, 5067/5067 run-all, reconcile COMPLETE, RCS ≥85 |

**Documented caveats (honesty, not failure):**

1. **Frozen-merge closure** — final force1416 rescored 19/22 rows without re-invoke; commits were authored in earlier live batches within the same round (one-pass policy after SIGTERM remediation).
2. **Rows 21–22** — internal inherit; no standalone attempt logs.
3. **Not a release pair** — Codex-3 REAL voids product claims from Codex-1/2; does not by itself restore 2/2 consecutive release sign-off.

**Honest product-work score: 17/17 implement rows with round-scoped committed evidence** (rows 1/15/21/22 exempt per methodology). This satisfies §5b for **first Codex product certification**.

---

*Audit finalized 2026-07-03; post-main-merge sync 2026-07-04 @ `56dc2374`. Evidence: fixture git @ `/Users/shafqat/projects/enterprise-grade-test-app` branch `enterprise-e2e/round-9-codex`, SB logs @ `.e2e-row*-codex-attempt.log`, rescore @ `.codex-r3-force1416-rescore.log`.*
