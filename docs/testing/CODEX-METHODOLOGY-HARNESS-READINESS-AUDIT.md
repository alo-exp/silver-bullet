# Codex Methodology & Harness Readiness Audit

**Audit date:** 2026-07-04  
**SB `main` SHA audited:** [`668a2a6d`](https://github.com/alo-exp/silver-bullet/commit/668a2a6d)  
**Auditor scope:** Codex R1–R3 REAL learnings vs [ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md](./ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md); harness production-readiness for honest product rounds  
**Cross-check sources:**

| Source | Path |
|--------|------|
| Methodology (canonical) | [ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md](./ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md) @ `668a2a6d` |
| Codex-1/2 product audit (void) | [.planning/enterprise-e2e/CODEX-TEST-APP-PRODUCT-AUDIT.md](../../.planning/enterprise-e2e/CODEX-TEST-APP-PRODUCT-AUDIT.md) |
| Codex-3 REAL product audit | [.planning/enterprise-e2e/CODEX-3-TEST-APP-PRODUCT-AUDIT.md](../../.planning/enterprise-e2e/CODEX-3-TEST-APP-PRODUCT-AUDIT.md) |
| Codex-3 gate closure | [.planning/enterprise-e2e/ROUND-CODEX-3-GATES.md](../../.planning/enterprise-e2e/ROUND-CODEX-3-GATES.md) |
| Harness entrypoints | `scripts/enterprise-e2e/matrix.sh`, `scripts/enterprise-e2e/lib/core.sh`, `scripts/install-codex.sh`, `tests/e2e-live/lib/skill-prompt.sh`, `.planning/enterprise-e2e/codex-r3-*` |

---

## Part A — Methodology completeness

Each row maps a **Codex R1–R3 REAL learning** (from product audits + gate closure) to the methodology section on `main` @ `668a2a6d`.

| # | Learning (session) | Methodology section | Status | Notes |
|---|-------------------|---------------------|--------|-------|
| 1 | **Harness PASS ≠ product certification** — Codex-1/2 ledgers 22/22 but **0/22** product commits on pre-seed | §1 effectiveness verdict; §5a opening; §3 release-pair table | **PASS** | Explicit disqualifier; dual counters |
| 2 | **Honest baseline `09f8d1a`** — excludes `826cb5c`/`8482e60` matrix pre-seed | §4 baseline SHA policy; host table; Appendix E | **PASS** | Codex-3 REAL cited with 19 commits |
| 3 | **Fixture branch lock** pre/post invoke (E2E-101) | §4 rule 4; §11b E2E-101; operator rules table | **PASS** | `enterprise_e2e_fixture_assert_branch_lock` documented |
| 4 | **One-pass per install fingerprint** — no repeat rows @ same `install_fp` | §6; §6a; §11 | **PASS** | Registry JSON + skip semantics |
| 5 | **`SB_E2E_MATRIX_FORCE=1`** (brownfield) vs **`FORCE_ALL=1`** (full re-cert) | §6; §6a override table; §11b E2E-102 | **PASS** | Distinction clear |
| 6 | **§5b required evidence gates** (log floor, live invoke, product delta, outcome PASS) | §5b full section; Appendix C checklist | **PASS** | Implements rubric from R3 gates |
| 7 | **Row 3 api/currency** — planning stub alone FAIL; api/ commits required (E2E-103) | §5b row-specific table; E2E-103 in §11b | **PASS** | `matrix_row3_product_commit_clause` listed |
| 8 | **Outcome-only reruns** when product frozen (`ROW3/14/16` frozen commits) | §5b outcome-only paragraph; invoke clause table | **PASS** | Matches `codex-r3-force1416-driver.sh` env |
| 9 | **Invoke prompt clauses** (`matrix_product_commit_clause`, row3/6/11/14/15) | §5b invoke clause table | **PASS** | Implemented in `skill-prompt.sh` |
| 10 | **`SB_E2E_REVIEW_LADDER_LEDGER`** — OUT-REVIEW-01 blocks row 15 without 8/8 ladder | §5b OUT-REVIEW-01; Appendix C | **PASS** | Codex-3 unblock after ladder 8/8 documented |
| 11 | **Evidence types** (`live-committed`, `harness-rescore`, `inherited-baseline`, `install-skip`, `frozen-merge`) | §5a evidence types table | **PASS** | Aligns with Codex-1/2 audit legend |
| 12 | **Release pair dual counters** — harness consecutive vs honest product consecutive | §3 “Release pair gates — harness vs honest product” | **PASS** | Codex-3 = 1/2 product; Codex-4 required |
| 13a | **Session 0 `install-codex.sh`** before first live matrix | §8 Codex operational prerequisites | **PASS** | E2E-108 skip on REAL drivers after Session 0 |
| 13b | **`core-rules.sha256` pin** after Codex sanitize (E2E-116) | §8; §11b E2E-116 | **PASS** | Mismatch blocks session start |
| 13c | **Poll-exit `pipefail` + `SB_E2E_ENTERPRISE_MATRIX=1`** (E2E-117) | §8; §11b E2E-117 | **PARTIAL** | Documented; `monitor-enterprise-e2e-matrix.sh` uses `set -uo pipefail` (no `-e`); poll scripts live under `.planning/enterprise-e2e/`, not `scripts/` |
| 13d | **SIGTERM / duplicate-driver guard** (Codex-3 remediation) | §8 duplicate-driver guard | **PARTIAL** | Policy stated; R3 remediation steps (kill stale batch PIDs before resume) not step-by-step in methodology — drivers check `enterprise_e2e_matrix_batch_running` |
| 13e | **429 quota retry 60s** — not auth churn | §7; §8 | **PASS** | Matches R1 friction |
| 14 | **Cherry-pick to `main`; no mid-round main switch**; branch closure after merge | §5 cherry-pick policy | **PASS** | Codex-3 merge @ `56dc2374` cited; no release tag for harness merge |
| 15 | **Appendix E void Codex-1/2** — pre-seed fraud, frozen-merge, rescore-only row 16, operator snapshot `baadf87` | Appendix E | **PASS** | All disqualifying patterns from [CODEX-TEST-APP-PRODUCT-AUDIT.md](../../.planning/enterprise-e2e/CODEX-TEST-APP-PRODUCT-AUDIT.md) |
| 16 | **Frozen-merge same-round closure** (Codex-3 force1416: 19 frozen + 3 live) | §5a #7; §6 one-pass; Appendix E “Real certification” | **PASS** | Conditional credit when commits from earlier live batches |
| 17 | **Tier A → B → C staged gates** (not full 22-row first) | §3 phase ordering; Codex-1 §2 takeaway | **PASS** | Deprecates full-matrix-first debug |
| 18 | **E2E-107 bracketed-paste** (“Queued follow-up”) | §11b E2E-107 | **PASS** | In Codex/Claude fix table |
| 19 | **E2E-109 fixture root before mkdir** | §11b E2E-109 | **PASS** | Operator implication documented |
| 20 | **Pre-release validation baseline `8482e60` vs honest `09f8d1a`** | — | **MISS** | [ROUND-CODEX-3-GATES.md](../../.planning/enterprise-e2e/ROUND-CODEX-3-GATES.md) records live pre-release FAIL @ `6aebf12d` with test-app baseline `8482e60`; methodology §3 Tier A does not call out this harness/config drift |
| 21 | **Tier B smoke row set** — session used 1,3,6; post-merge §5b smoke cites 1,6,11,21,22 | §3 Tier B vs §11b post-merge sibling session | **PARTIAL** | Internal inconsistency: Tier B table = rows **1, 3, 6**; §11b re-cert smoke = **1, 6, 11, 21, 22** |
| 22 | **E2E-096 row 10 autonomy scorer** (babysitting / `SB OVERRIDE:`) | §11a E2E-096 | **PASS** | Documented; local `test-outcome-assessment.sh` now **68/68** @ `668a2a6d` (gates doc cited 67/68 at closure) |

### Part A summary

| Verdict | Count |
|---------|-------|
| **PASS** | 18 |
| **PARTIAL** | 4 |
| **MISS** | 1 |

**Methodology completeness score: ~94%** — Codex R1–R3 REAL learnings are overwhelmingly integrated. Gaps are operational drift (pre-release baseline), Tier B smoke row inconsistency, and light treatment of poll/SIGTERM runbook detail.

---

## Part B — Harness readiness score

**Score: 82 / 100** — A skilled operator **can** run an honest Codex product round (Codex-4) by following methodology + explicit env overrides, but **will hit known gaps** if they rely on defaults or stale operator prompts alone.

### What is ready (evidence @ `668a2a6d`)

| Area | Evidence | Status |
|------|----------|--------|
| Matrix core | `scripts/enterprise-e2e/matrix.sh` — fixture lock, §5b product gate, FORCE/FORCE_ALL, row3 product clause, timeouts | **Ready** |
| Product gate lib | `scripts/enterprise-e2e/lib/core.sh` — `enterprise_e2e_assert_row_product_commit_delta`, frozen/outcome-only rescore paths | **Ready** |
| Codex install | `scripts/install-codex.sh` + `scripts/lib/install-codex/cache.sh` (`core-rules.sha256`) | **Ready** |
| Invoke clauses | `tests/e2e-live/lib/skill-prompt.sh` — row3/6/11/14 product + outcome clauses | **Ready** |
| Codex adapter skip | `scripts/enterprise-e2e/lib/adapters/codex.sh` — `SB_E2E_SKIP_CODEX_INSTALL=1` | **Ready** |
| REAL drivers | `.planning/enterprise-e2e/codex-r3-real-driver.sh`, `codex-r3-force1416-driver.sh` — `09f8d1a`, `SB_E2E_PRODUCT_WORK_GATE=1`, `REVIEW_LADDER_LEDGER` | **Ready** (with caveats below) |
| Structural tests | `test-enterprise-e2e-matrix-force.sh` **7/7**; `test-outcome-assessment.sh` **68/68**; pre-release overlay dry-run **41/41** | **Ready** |
| hosts.json Codex | `fixture_branch: round-9-codex`, ledger/gates pointers updated | **Mostly ready** |

### Blockers (must fix or explicitly override before Codex-4)

| # | Blocker | Impact | Mitigation today |
|---|---------|--------|------------------|
| B1 | **Default baseline SHA `8482e60`** in `enterprise_e2e_test_app_default_baseline_sha()`, `hosts.json` (cursor), `live-test.sh` help — **not** `09f8d1a` | Operator omitting env gets pre-seeded baseline → **void product round** per §5a #1 | **Must** `export SB_E2E_TEST_APP_BASELINE_SHA=09f8d1a` (drivers do; generic matrix does not) |
| B2 | **[CODEX-ENTERPRISE-E2E-EXECUTION-PROMPT.md](../../.planning/enterprise-e2e/CODEX-ENTERPRISE-E2E-EXECUTION-PROMPT.md) stale** — still missions “2 consecutive strict-clean Codex-1/2”, branch `enterprise-e2e/codex-round1`, no §5a/§5b honest baseline | New operator follows execution prompt → **wrong round model** | Use methodology doc + `codex-r3-real-driver.sh` pattern; refresh execution prompt |
| B3 | **`codex-r3-*` drivers checkout `enterprise-e2e/codex`** — remote branch **deleted** post-closure ([ROUND-CODEX-3-GATES.md](../../.planning/enterprise-e2e/ROUND-CODEX-3-GATES.md)); harness work now on `main` | Driver `git checkout enterprise-e2e/codex` fails on fresh clone | Run from `main` @ current HEAD; create `enterprise-e2e/codex-round4` or patch drivers to `main` |
| B4 | **Pre-release live validation** failed @ closure with test-app baseline `8482e60` (5050/5057 run-all-tests) — [ROUND-CODEX-3-GATES.md](../../.planning/enterprise-e2e/ROUND-CODEX-3-GATES.md) | Phase C pre-release `--live` may fail for honest-round operators | Dry-run passes; live path needs baseline alignment (not documented in methodology) |
| B5 | **CI `validate` job FAIL** — shellcheck warnings (`completion-audit.sh`, `hook-bootstrap.sh`, `install-codex.sh`, `sb-doctor.sh`, etc.) @ run [28683318305](https://github.com/alo-exp/silver-bullet/actions/runs/28683318305) | `main` not CI-green; blocks release automation confidence | Does not block local matrix; fix shellcheck for hygiene |

### Nice-to-have (non-blocking for skilled operator)

| # | Item | Notes |
|---|------|-------|
| N1 | Promote `.planning/enterprise-e2e/.codex-r3-*-poll-exit.sh` into `scripts/enterprise-e2e/` | Discoverability; poll scripts already use `set -euo pipefail` + `SB_E2E_ENTERPRISE_MATRIX=1` |
| N2 | Align Tier B smoke row list in methodology (1,3,6 vs 1,6,11,21,22) | Operator confusion only |
| N3 | Set Codex default `test_app_git_baseline_sha: "09f8d1a"` in `hosts.json` when `SB_E2E_PRODUCT_WORK_GATE=1` | Eliminates B1 foot-gun |
| N4 | Update `gates_round2` pointer (still `ROUND-CODEX-2-GATES.md`) | Historical; Codex-2 void |
| N5 | Shellcheck green on `main` | Pre-existing; unrelated to matrix TUI |

### Documented limitations (acceptable per methodology)

| Limitation | Where documented |
|------------|------------------|
| **Codex-4 required** for 2/2 honest product release pair | §3; Appendix E; [ROUND-CODEX-3-GATES.md](../../.planning/enterprise-e2e/ROUND-CODEX-3-GATES.md) |
| **Rows 21–22** — internal inherit; no standalone §5b log floor | §5b; E2E-100 |
| **Frozen-merge closure** — rescored rows without re-invoke when commits exist same round | §5a #7; Codex-3 audit §5b caveats |
| **429 quota walls** — schedule resume, not auth rotation | §7 |
| **Program scope** — certifies harness + workflow on fixture; not marketing SLOs | §1 honest scope |
| **Rescore ≠ strict-clean** for certification credit | §6; Appendix E |

### Operator readiness checklist (Codex-4 honest product round)

Before spending live quota, a new operator should:

1. Read [ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md](./ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md) (not stale execution prompt alone).
2. `git checkout main` && `bash scripts/install-codex.sh` (Session 0).
3. `export SB_E2E_TEST_APP_BASELINE_SHA=09f8d1a` `SB_E2E_PRODUCT_WORK_GATE=1` `SB_E2E_TEST_APP_BRANCH=enterprise-e2e/round-N-codex`.
4. Tier A green → Tier B smoke → ladder 8/8 with `SB_E2E_REVIEW_LADDER_LEDGER` set.
5. Use driver pattern from `codex-r3-real-driver.sh` but **retarget SB branch to `main`** (or new host branch).
6. Run [CODEX-*-TEST-APP-PRODUCT-AUDIT.md](../../.planning/enterprise-e2e/CODEX-3-TEST-APP-PRODUCT-AUDIT.md) template before claiming product PASS.

---

## Part C — Verdict

The [ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md](./ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md) on `main` @ [`668a2a6d`](https://github.com/alo-exp/silver-bullet/commit/668a2a6d) is **substantively complete (~94%)** for Codex R1–R3 REAL learnings: harness-vs-product separation, honest `09f8d1a` baseline, §5a/§5b anti-faking, invoke clauses, dual release counters, void Codex-1/2 in Appendix E, and operational fixes E2E-101–117 are all present. Remaining methodology gaps are minor (pre-release baseline drift undocumented, Tier B smoke row inconsistency, thin SIGTERM runbook).

The **Codex harness is not 100% production-ready** for unattended real product work (**82%**). Core matrix/product-gate code on `main` is sound and Codex-3 REAL proved the path (19 commits, 22/22 matrix, Phase C green at closure), but **default harness config still biases toward `8482e60`**, the **Codex execution prompt is stale**, **R3 drivers target a deleted remote branch**, and **CI/pre-release live paths remain red or misaligned**. A disciplined operator who reads the methodology, sets honest-baseline env vars, runs from `main`, and follows the `codex-r3-*` driver pattern **can** execute Codex-4 without inventing new harness — but an operator following defaults or the old execution prompt **will** reproduce pre-seed void patterns or hit checkout failures. **Recommendation:** treat methodology as canonical; refresh execution prompt + `hosts.json` baseline default + Codex-4 driver branch target before claiming “harness ready for any operator.”

---

*Audit generated 2026-07-04 on `main` @ `668a2a6d`. Evidence: local structural tests, CI run 28683318305, cross-read of methodology + Codex product audits + gate closure + harness source.*

---

## Follow-up remediation (2026-07-04)

Post-audit harness fixes on `main` (uncommitted at write time):

| Blocker | Fix |
|---------|-----|
| B1 default `8482e60` | `hosts.json` codex `test_app_git_baseline_sha: 09f8d1a`; `enterprise_e2e_test_app_default_baseline_sha()` returns `09f8d1a` when `SB_E2E_PRODUCT_WORK_GATE=1` |
| B2 stale execution prompt | [CODEX-ENTERPRISE-E2E-EXECUTION-PROMPT.md](../../.planning/enterprise-e2e/CODEX-ENTERPRISE-E2E-EXECUTION-PROMPT.md) v3 — Codex-4 REAL mission, `main` branch, honest baseline |
| B3 deleted `enterprise-e2e/codex` | All `codex-r3-*` drivers default `SB_E2E_BRANCH=main`; new [codex-r4-real-driver.sh](../../.planning/enterprise-e2e/codex-r4-real-driver.sh) |
| MISS pre-release baseline | Methodology §3 Tier A — pre-release `--live` baseline alignment note |
| PARTIAL Tier B rows | Methodology §6 — Tier B = 1,3,6 vs resume seeding 11,21,22 clarified |

**Remaining:** B5 CI shellcheck; B4 pre-release `--live` still needs operator env at run time; Codex-4 round execution not yet run.
