# Enterprise E2E Host Certification Methodology

> **Share this path with sibling agents (Cursor, Claude, Codex):**  
> `docs/testing/ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md`  
> Canonical on **`main`** — host tracks cherry-pick or link; do not fork per-host copies.

**Status:** Active — 2026-07-04 (Codex R1–3 REAL learnings; **single-round release candidate gate** effective)  
**Audience:** Codex, Cursor, and Claude operator sessions certifying Silver Bullet on `enterprise-grade-test-app`  
**Authority:** Supersedes ad-hoc “run 22 rows first” loops; complements [ENTERPRISE-E2E-EFFECTIVENESS-PLAN.md](./ENTERPRISE-E2E-EFFECTIVENESS-PLAN.md)

**Related docs:**

| Doc | Path |
|-----|------|
| Shared harness | [`.planning/enterprise-e2e/SHARED-HARNESS.md`](../../.planning/enterprise-e2e/SHARED-HARNESS.md) |
| Host env matrix | [`.planning/enterprise-e2e/HOST-CONFIG.md`](../../.planning/enterprise-e2e/HOST-CONFIG.md) |
| Outcome rubric | [`.planning/enterprise-e2e/OUTCOME-ASSESSMENT-RUBRIC.md`](../../.planning/enterprise-e2e/OUTCOME-ASSESSMENT-RUBRIC.md) |
| Live test runbook | [`docs/ENTERPRISE-E2E-LIVE-TEST.md`](../ENTERPRISE-E2E-LIVE-TEST.md) |
| Operator prompt | [`scripts/ENTERPRISE-E2E-OPERATOR-PROMPT.md`](../../scripts/ENTERPRISE-E2E-OPERATOR-PROMPT.md) |
| Fixture branch policy | [`.planning/enterprise-e2e/TEST-APP-BRANCH-POLICY.md`](../../.planning/enterprise-e2e/TEST-APP-BRANCH-POLICY.md) |
| Cherry-pick policy | [`docs/testing/ENTERPRISE-E2E-CHERRY-PICK.md`](./ENTERPRISE-E2E-CHERRY-PICK.md) |
| Codex product audit (R1/2 void) | [`.planning/enterprise-e2e/CODEX-TEST-APP-PRODUCT-AUDIT.md`](../../.planning/enterprise-e2e/CODEX-TEST-APP-PRODUCT-AUDIT.md) |
| Codex-3 REAL product audit | [`.planning/enterprise-e2e/CODEX-3-TEST-APP-PRODUCT-AUDIT.md`](../../.planning/enterprise-e2e/CODEX-3-TEST-APP-PRODUCT-AUDIT.md) |
| Codex-3 gate checklist | [`.planning/enterprise-e2e/ROUND-CODEX-3-GATES.md`](../../.planning/enterprise-e2e/ROUND-CODEX-3-GATES.md) |

---

## 1. Effectiveness verdict

**Full 22-row live matrix as the primary debug loop is low throughput.** Rounds 1–3 and Codex-1 demonstrated that jumping straight to Tier C wastes quota, produces ledger/monitor drift, and blocks harness fixes behind long TUI stalls.

| Approach | Verdict |
|----------|---------|
| **Staged gates (Tier A → B → C)** | **Recommended** — fast structural signal before LLM spend |
| **Full 22-row matrix as first loop** | **Deprecated** for bring-up and mid-round debug |
| **Structural / offline suite** | **Highly effective** — catches script/doc/registry drift without TUI |
| **Monitor “22/22 COMPLETE” without ledger reconcile** | **Anti-pattern** — observed Round 3 drift |
| **Single-round release candidate gate** | **Required** for host release sign-off @ a release candidate version — one strict-clean round @ `install_fp` with 22/22 live + §5b product audit + outcome PASS + Phase C green (§3) |
| **Harness 22/22 without §5b product audit** | **Disqualifying** for product-work certification — harness PASS ≠ product certification (§5a) |
| **Repeat matrix/ladder/T1 rows at same install** | **Deprecated** — one clean pass per row/criterion @ install version (see §11) |
| **Rescore / evidence-only PASS without live rerun** | **Disqualifying** for certification credit (see §5a, §6) |
| **Inherited baseline / pre-existing fixture artifacts** | **Disqualifying** without live agent authorship (see §5a) |
| **ROW_ALREADY_PASSED_SAME_INSTALL on first host certification** | **Disqualifying** — install-skip only after first strict-clean round @ install version (see §5a, §6a) |

**Honest scope:** This program certifies SB harness + workflow routing on a fixture app with operator supervision. It does **not** prove homepage marketing stats, cold-install SLOs, or statistical reliability across providers without additional claims mapping (see registries below).

---

## 2. What worked / failed (Round Codex-1)

| Worked | Failed / friction |
|--------|---------------------|
| Phase A ladder **8/8** with 2× verify per rung | Full-matrix-first debug loop — rows 2–5 stalled on quota + stop-hook |
| Harness fixes on `enterprise-e2e/codex` (scorer, hook trust, quiet timeout) | Scorer false negatives (row 2) — required post-invoke rescore |
| Host-isolated locks/logs (`.e2e-live-test-codex.lock`, codex row logs) | 429 quota — needs scheduled retry, not auth churn |
| Tier A structural suite green before live | Agent-shell TUI watchers — fragile vs durable daemon driver |
| Rows 1, 6, 7 strict-clean when batch healthy | Parallel host branch stomp without fixture isolation |

**Takeaway:** Codex-1 proved harness value but did not complete strict-clean. Resume on **staged gates**, not “force full matrix until green.”

---

## 3. Tier A / B / C gate model

Gates are **sequential**. Do not start Tier B until Tier A is green. Do not start Tier C until Tier B smoke passes.

### Phase ordering (mandatory)

Execute in this order — do not skip ahead or claim certification credit from later phases without completing earlier ones:

| Phase | Alias | What runs |
|-------|-------|-----------|
| **T0** | Tier A structural | Offline harness, outcome tests, surface validation, dry-run matrix (§3 Tier A) |
| **T1** | Tier B row 1 | Single live `silver-router` FORCE @ install version — routing smoke with outcome PASS |
| **T2** | Tier B smoke | Live rows **1, 3, 6** (router + feature parent + fast path) |
| **Phase A** | review-fix-ladder | 8/8 rungs — one live pass per rung @ install version |
| **Full matrix** | Tier C | Live rows **1–22** — one pass per row @ install version |
| **Phase C** | Release gates | Outcome harness, run-all-tests, validation/pre-release overlays, ledger reconcile, RCS ≥ 85 |

**Rescore ≠ strict-clean.** Post-invoke rescoring may flip harness evidence for debugging; only **live strict-clean invocations** count toward host certification and release candidate sign-off.

**Ship-readiness consistency:** Row 16 (`ship-readiness`) outcome must match fixture state — `NOT_MERGE_READY` (or equivalent) **cannot** be scored PASS. Audit-only triad docs (row 15) without product delta is **not** certified delivery.

### Summary table

| Tier | Layer | TUI? | Purpose |
|------|-------|------|---------|
| **A** | Offline / pre-release structural | **No** | Wiring, registries, surface isolation, outcome harness |
| **B** | Live smoke (rows **1, 3, 6**) | **Yes** | Router + feature + fast paths before full burn |
| **C** | Full matrix **22/22** + Phase C strict-clean | **Yes** | Release candidate gate (one strict-clean round @ `install_fp`) |

### Tier A — offline / pre-release (no TUI)

Run **all** green before `SB_ENTERPRISE_E2E_LIVE=1`.

| Check | Command / artifact |
|-------|-------------------|
| Structural harness | `RTK_DISABLED=1 bash tests/enterprise-e2e-live/test-enterprise-e2e-live-suite.sh` |
| Outcome harness | `RTK_DISABLED=1 bash tests/scripts/test-outcome-assessment.sh` |
| Validation overlay (dry-run) | `RTK_DISABLED=1 bash scripts/run-enterprise-e2e-validation-overlay.sh --dry-run` |
| Pre-release overlay (dry-run) | `RTK_DISABLED=1 bash scripts/run-enterprise-e2e-pre-release-overlay.sh --dry-run` |
| Validation overlay structural test | `bash tests/enterprise-e2e-live/test-enterprise-e2e-validation-overlay.sh` |
| Host install surface **D16** | `bash scripts/validate-host-install-surface.sh --repo-root "$SB_ROOT" --host <host>` |
| Surface structural test | `bash tests/scripts/test-validate-host-install-surface.sh` |
| Tri-host install smoke (per host) | `RTK_DISABLED=1 bash scripts/run-tri-host-install-smoke.sh --host <host>` |
| Hook delivery preflight | `SB_E2E_LIVE_RUNTIME=<host> bash tests/e2e-live/hook-delivery-preflight.sh` |
| Review-fix-ladder smoke | `SILVER_BULLET_RUNTIME=<host> bash tests/live/test-live-review-fix-ladder-smoke.sh` |
| Host preflight | `bash scripts/run-enterprise-e2e-live-test.sh --host <host> --preflight-only` |
| Dry-run matrix | `SB_E2E_MATRIX_DRY_RUN=1 SB_E2E_LIVE_RUNTIME=<host> bash scripts/run-enterprise-e2e-matrix.sh` |
| Test-app branch structural | `RTK_DISABLED=1 bash tests/scripts/test-enterprise-e2e-test-app-branch.sh` |
| Claims registries | `docs/testing/validation-claims-registry.json`, `docs/testing/pre-release-claims-registry.json` |

**Registries:** validation overlay = 6 outcome/telemetry gate claims; pre-release overlay = feature/install claims (tri-host, catalog, hooks). See [`scripts/ENTERPRISE-E2E-OPERATOR-PROMPT.md`](../../scripts/ENTERPRISE-E2E-OPERATOR-PROMPT.md) §Validation vs pre-release.

**Pre-release live baseline alignment:** `test-enterprise-e2e-test-app-branch.sh` and pre-release `--live` paths assert the test-app baseline SHA. For **honest product rounds**, set `SB_E2E_TEST_APP_BASELINE_SHA=09f8d1a` (or rely on codex `hosts.json` + `SB_E2E_PRODUCT_WORK_GATE=1`) **before** running pre-release `--live`. Using legacy `8482e60` causes false FAIL on honest-round fixtures ([ROUND-CODEX-3-GATES.md](../../.planning/enterprise-e2e/ROUND-CODEX-3-GATES.md) — 5050/5057 at closure). Dry-run pre-release passes without live baseline coupling.

### Tier B — live smoke (rows 1, 3, 6)

| Row | WF slug | Why smoke |
|-----|---------|-----------|
| 1 | `silver-router` | Routing-only — cheapest live signal |
| 3 | `silver-feature` | Parent for rows 21–22 — catches orchestrator + implement path |
| 6 | `silver-fast` | Fast path + hook trust — high signal / lower cost |

```bash
export SB_ENTERPRISE_E2E_LIVE=1
export SB_E2E_LIVE_RUNTIME=<host>
export SB_E2E_LEDGER_FILE=.planning/enterprise-e2e/ROUND-<HOST>-1-LEDGER.md
RTK_DISABLED=1 bash scripts/run-enterprise-e2e-matrix.sh 1 3 6
```

**After each row:** post-invoke rescore (§6). **Gate:** all three rows evidence PASS + outcome PASS before Tier C.

### Tier C — full matrix + strict-clean

1. **review-fix-ladder** 8/8 — **one live pass per rung** when already green at current install version (§11); legacy 2× verify only when install version changes or `SB_E2E_MATRIX_FORCE=1`
2. Live matrix rows **1–22** (`SB_ENTERPRISE_E2E_LIVE=1`) — **one pass per row** when ledger/registry shows Pass @ current `SB_INSTALL_VERSION_KEY`
3. **Phase C** (all green):
   - `bash tests/scripts/test-outcome-assessment.sh`
   - `bash tests/run-all-tests.sh`
   - `bash scripts/run-enterprise-e2e-validation-overlay.sh --live`
   - `bash scripts/run-enterprise-e2e-pre-release-overlay.sh --dry-run` (+ `--live` before release)
   - `bash scripts/lib/enterprise-e2e-ledger-reconcile.sh <matrix-log>`
   - `SB_E2E_RCS_TRIHOST=full bash scripts/enterprise-e2e-rcs.sh` (RCS ≥ 85)

**Strict-clean** = ladder 8/8 + matrix 22/22 + every row `enterprise_e2e_outcome_row_passes` + blocking autonomy gates + Phase C green + **0 new issues** vs baseline (`docs/issues/ENTERPRISE-E2E-SB-ISSUES.md`).

**Release:** One strict-clean round @ release candidate `install_fp` satisfies host sign-off when all gates below pass ([`ROUND-N-GATES.md`](../../.planning/enterprise-e2e/ROUND-N-GATES.md) — update gate row **release candidate sign-off**).

### Release candidate gate — harness vs honest product (Codex R1–3 lesson)

Operators track **two independent dimensions**. Do not conflate them.

| Dimension | What it measures | Release sign-off credit |
|-----------|------------------|-------------------------|
| **Harness strict-clean** | Ladder 8/8 + matrix 22/22 + Phase C @ `install_fp` | Routing/scoring only — **not** product delivery without §5b |
| **Honest product strict-clean** | Same round passes §5b product audit (committed deltas per implement row) on **honest** fixture baseline `09f8d1a` | **Required** for product certification @ release candidate version |

**Policy (effective 2026-07-04):** **One** strict-clean round @ the release candidate `install_fp` is sufficient for host **product certification sign-off** — no second confirmation round (historical 2/2 pair **deprecated**).

**Codex example:** Codex-1 + Codex-2 achieved harness 22/22 twice on pre-seeded `8482e60` / `826cb5c` baseline — **0/22** row-mapped product commits ([CODEX-TEST-APP-PRODUCT-AUDIT.md](../../.planning/enterprise-e2e/CODEX-TEST-APP-PRODUCT-AUDIT.md)). That is **void** for product certification. **Codex-3 REAL** on `09f8d1a` baseline @ SB `f9ed398f` satisfies the **new** single-round policy — [ROUND-CODEX-3-GATES.md](../../.planning/enterprise-e2e/ROUND-CODEX-3-GATES.md), [CODEX-3-TEST-APP-PRODUCT-AUDIT.md](../../.planning/enterprise-e2e/CODEX-3-TEST-APP-PRODUCT-AUDIT.md) — see **Appendix F**. Round **Codex-4** was **not executed**; it is **not required** under the current policy (optional re-cert @ a new `install_fp` only).

**Mandatory before product claim:** Run host-specific product audit (pattern: `CODEX-*-TEST-APP-PRODUCT-AUDIT.md`) and confirm §5a/§5b gates — matrix ledger 22/22 alone is insufficient.

---

## 4. Fixture branch rules

Pattern: **`enterprise-e2e/round-<N>-<host>`** @ baseline SHA (test app, not SB `main`).

### Baseline SHA policy — honest product rounds

| Baseline class | Example SHAs | Use |
|----------------|----------------|-----|
| **Pre-seeded matrix** | `826cb5c`, `8482e60` | Harness bring-up / legacy rounds only — artifacts pre-populate implement-row touch surfaces |
| **Honest minimal** | `09f8d1a` | **Required** for strict-clean **product** certification — excludes matrix pre-seed |

**Rule:** Honest product rounds **must not** use `826cb5c`/`8482e60` full-surface baselines. Reset fixture to honest minimal SHA before first live row. Pre-seeded baseline PASS without live agent authorship is **disqualifying** (§5a #1). Codex-3 REAL validated this on `enterprise-e2e/round-9-codex` @ `09f8d1a` — **19** product commits ([CODEX-3-TEST-APP-PRODUCT-AUDIT.md](../../.planning/enterprise-e2e/CODEX-3-TEST-APP-PRODUCT-AUDIT.md)).

| Host | SB harness branch | Test-app fixture branch | Baseline SHA (honest) | Legacy pre-seed |
|------|-------------------|-------------------------|----------------------|-----------------|
| Claude | `enterprise-e2e/round6` | `enterprise-e2e/round-9-claude` | `09f8d1a` | `8482e60` (R8 only) |
| Codex | `enterprise-e2e/codex` | `enterprise-e2e/round-9-codex` | `09f8d1a` | `8482e60` (R1/2 — **void**) |
| Cursor | `enterprise-e2e/cursor` | `enterprise-e2e/round-N-cursor` (worktree) | `09f8d1a` | `8482e60` (R1/2 — **void**) |

**Rules:**

1. **Day-0:** create fixture branch from **honest** baseline SHA; never target test-app `main` for live rows.
2. **No stomp:** never `checkout -B` another host's fixture branch on a shared clone.
3. **Dirty + correct branch:** OK (matrix in progress). **Dirty + wrong branch:** fail-fast — use worktree ([TEST-APP-BRANCH-POLICY.md](../../.planning/enterprise-e2e/TEST-APP-BRANCH-POLICY.md)).
4. **Fixture branch lock:** `enterprise_e2e_fixture_assert_branch_lock` runs **pre- and post-invoke** on every row (E2E-101). Fail on drift to sibling host branch or wrong SHA.
5. Env overrides: `SB_E2E_TEST_APP_BRANCH`, `SB_E2E_TEST_APP_BASELINE_SHA`, `SB_E2E_TEST_APP_ROUND`.
6. **Ledger-derived branch override:** When `SB_E2E_TEST_APP_BRANCH` and `SB_E2E_TEST_APP_ROUND` are unset, `enterprise_e2e_test_app_round_from_ledger` parses `SB_E2E_LEDGER_FILE` basename (`ROUND-CURSOR-3-REAL` → round **3**, `ROUND-CODEX-9` → round **9**) and sets `enterprise-e2e/round-N-{host}` — **overriding** stale `hosts.json` defaults. Priority: explicit env → `SB_E2E_TEST_APP_ROUND` → `hosts.json` → ledger-derived (Cursor-3 REAL lesson — [ROUND-CURSOR-3-REAL-LEDGER.md](../../.planning/enterprise-e2e/ROUND-CURSOR-3-REAL-LEDGER.md)).

---

## 5. Cherry-pick policy (no main switch for deploy)

- **Harness fixes** commit on host branch (`enterprise-e2e/codex`, `enterprise-e2e/cursor`, `enterprise-e2e/round6`).
- **Verified fixes** cherry-pick to `main` per [`ENTERPRISE-E2E-CHERRY-PICK.md`](./ENTERPRISE-E2E-CHERRY-PICK.md) — paths only when mixed with ledger noise.
- **Do not** switch live matrix driver to `main` mid-round for deploy; re-run host install (`install-codex.sh`, etc.) from pinned SB SHA on host branch.
- **Docs on `main`** (this file) are the cross-agent share surface; host prompts link here.
- **Branch closure after merge:** When host round closes, merge `enterprise-e2e/{host}` → `main` (fast-forward or cherry-pick per policy), then close fixture branch. Codex-3 example: harness landed on `main` @ `56dc2374`; fixture `round-9-codex` @ `97f0677` retained for audit. **No release tag** required for methodology/harness merge alone.

---

## 5a. Anti-faking and disqualifying evidence

### Harness PASS ≠ product certification

Matrix **22/22 harness PASS** and Phase C green are **necessary but not sufficient** for host **product-work certification**. Operators **must** complete a §5b product audit (see [CODEX-TEST-APP-PRODUCT-AUDIT.md](../../.planning/enterprise-e2e/CODEX-TEST-APP-PRODUCT-AUDIT.md) / [CODEX-3-TEST-APP-PRODUCT-AUDIT.md](../../.planning/enterprise-e2e/CODEX-3-TEST-APP-PRODUCT-AUDIT.md) pattern) **before** claiming strict-clean product delivery. Harness-only rounds with zero row-mapped product commits are **void** for product sign-off even when ledgers show 22/22.

Operators **must not** declare a row PASS for host certification unless the row satisfies **§5b required evidence gates**. The following categories are **forbidden** or **disqualifying** — if observed, mark the row **FAIL** (or void the round) and re-run live strict-clean:

| # | Category | Description | Operator action |
|---|----------|-------------|-----------------|
| 1 | **Pre-existing evidence** | Row passes on inherited baseline commits (e.g. `826cb5c`, `8482e60`) or fixture files present before the live agent session without live agent authoring that deliverable | Reset fixture branch to baseline SHA; re-run row with `SB_E2E_MATRIX_FORCE=1`; require committed delta or documented brownfield waiver |
| 2 | **Harness rescoring** | E2E-089-style log rescoring flipping FAIL→PASS without a live strict-clean rerun (evidence-only rescoring after timeout/empty logs) | Rescore is diagnostic only — **does not** grant certification credit; live rerun required |
| 3 | **Timeout / empty logs** | FORCE passes with **0–148 B** logs (timeout-only, connection noise, no captured workflow output) | FAIL row; fix harness (E2E-086 headless log streaming) or extend timeout; re-run live |
| 4 | **Audit-only sessions** | Agent ran but **zero product delta**: routing-only row 1 with no routing artifact; verify-only row 7; triad docs-only row 15; ship-readiness `NOT_MERGE_READY` still PASS | FAIL row — dirty tree with no commits = not certified product delivery |
| 5 | **Install-skip on first certification** | `ROW_ALREADY_PASSED_SAME_INSTALL` or `evidence_present` reusing prior-round evidence when certifying host for the **first** time at an install fingerprint | Install-skip allowed **only after** the first strict-clean round @ install version (§6a); first certification requires live invocations |
| 6 | **Internal gates without parent live work** | Rows 21–22 passing on parent markers when parent rows 3/4 were not live strict-clean at current install fingerprint | Re-run parent rows 3/4 live; internal rows inherit parent evidence only from live strict-clean parents |
| 7 | **Frozen-merge without round authorship** | Round closure rescored rows from prior-round logs/commits without live authorship in **this** round's session window | Frozen-merge valid **only** when product commits were authored in earlier live batches **within the same round** (one-pass policy); cross-round frozen-merge is **disqualifying** |

**Evidence types** — ledger must record which applies per row:

| Type | Description | Product certification credit |
|------|-------------|------------------------------|
| `live-committed` | Live TUI invoke + fixture commit in session window | **Yes** — primary |
| `harness-rescore` | PASS from scorer/harness fix without live re-run | **No** — diagnostic only (§5a #2) |
| `inherited-baseline` | Artifact at `826cb5c`/`8482e60` before live invoke | **No** — disqualifying (§5a #1) |
| `install-skip` | `ROW_ALREADY_PASSED_SAME_INSTALL` / `evidence_present` on first cert | **No** on first certification (§5a #5) |
| `frozen-merge` | One-pass closure: rescore merges prior live batch evidence same round | **Conditional** — only when commits exist from earlier live batches in round |

**Cross-host contamination** (E2E-090): matrix rows executed on another host's fixture branch (e.g. Claude rows on `round-8-codex`) **disqualify the round** — reset fixture, verify `enterprise_e2e_fixture_assert_branch_lock`, use per-host worktree.

**Brownfield waiver (narrow):** Pre-existing artifact may count only when operator documents **file:line** evidence that the artifact existed before the row prompt and the row's contract explicitly allows verification-without-mutation. Default: **no waiver** — live authorship required.

---

## 5b. Required evidence gates (per row)

Every row claimed **PASS** for certification must satisfy **all** gates:

| Gate | Requirement |
|------|-------------|
| **Log size floor** | Row attempt log **> 2048 bytes** substantive workflow output, **or** explicit brownfield waiver in ledger with file:line pre-existence proof |
| **Live strict-clean only** | Row invoked via live matrix driver (`SB_ENTERPRISE_E2E_LIVE=1`) at current install fingerprint — not rescore-only, not dry-run, not monitor replay |
| **Product delta** | **Committed delta** on fixture branch (`git log` shows row-session commit) **or** documented brownfield waiver — uncommitted dirty tree alone is insufficient. Harness enforces via `enterprise_e2e_assert_row_product_commit_delta` when `SB_E2E_PRODUCT_WORK_GATE=1` (E2E-103, E2E-114) |
| **Host-agent authorship** | Outcome checklist attests **host-agent** (`cursor-agent`, Codex TUI, Claude TUI) authored the deliverable — operator parent routing-only does not satisfy implement rows |
| **Outcome PASS** | `enterprise_e2e_outcome_row_passes` with no `partial` on blocking gates (`OUT-AUTO-01`, `OUT-CLARIFY-01`, `OUT-NOOP-01`, `OUT-WORLD-01`) |
| **Ship-readiness match** | Row 16 verdict aligns with merge-readiness state — `NOT_MERGE_READY` → row FAIL |

Ledger template columns must record: `log_bytes`, `live_invoke` (yes/no), `commit_sha` (or `brownfield_waiver`), `evidence_type`, `host_agent_attestation`.

### Product-commit gate — implement rows vs exempt

| Row class | Rows | Product commit required |
|-----------|------|-------------------------|
| **Implement** | 2–14, 16–20 | **Yes** — committed delta on fixture branch after live invoke |
| **Routing exempt** | 1 | Workflow evidence only (`.planning/workflows/router-session.md`) — no api/ edits |
| **Triad audit exempt** | 15 | Triad doc + instruction-ledger + ship-readiness — see row-specific paths |
| **Internal inherit** | 21–22 | Inherit from live strict-clean parents 3/4 — no standalone product commit |

**Outcome-only reruns:** When product is frozen at a prior commit (`SB_E2E_ROW3_FROZEN_COMMIT`, `SB_E2E_ROW14_FROZEN_COMMIT`), rows may re-run for outcome artifacts only — §5b satisfied without new product delta. Use `matrix_row*_outcome_only_clause` in invoke prompt.

### Row-specific product paths (§5b touch surfaces)

| Row | WF slug | Required product evidence (committed) |
|-----|---------|--------------------------------------|
| 3 | `silver-feature` | `api/` orders currency field + tests; planning chain: CLARIFY → PLAN/SPEC/QUALITY-GATES/VALIDATION → `feature-currency.md` |
| 6 | `silver-fast` | `README.md` or `docs/` install fix + `fast-readme.md` workflow evidence |
| 11 | `silver-devops` | `infra/` or `terraform/` env validation + `devops-terraform-validation.md` |
| 14 | `silver-release` | `CHANGELOG.md` v0.2.0 + `instruction-ledger.jsonl` + `.planning/ship-readiness/` |
| 15 | `review-triad` | `.planning/reviews/triad-currency.md` + instruction-ledger + ship-readiness |
| 16 | `ship-readiness` | Ship-readiness checklist state must match outcome — `NOT_MERGE_READY` → FAIL |

Docs-only or planning-stub without api/infra/product commits **FAIL** §5b for implement rows (Codex-1/2 lesson: row 3 stub-only).

### Invoke prompt clauses (product + outcome)

Matrix drivers append row-specific clauses from `tests/e2e-live/lib/skill-prompt.sh` (and host invoke scripts). Operators must verify clauses are active when `SB_E2E_PRODUCT_WORK_GATE=1`:

| Clause function | Purpose |
|-----------------|---------|
| `matrix_product_commit_clause` | Generic §5b commit-on-fixture-branch |
| `matrix_row3_product_commit_clause` | Row 3 api/currency — not planning-only |
| `matrix_row3_outcome_clause` | CLARIFY → PLAN/SPEC/QUALITY-GATES/VALIDATION ordering |
| `matrix_row3_outcome_only_clause` | Product frozen — planning artifacts only |
| `matrix_row6_product_commit_clause` | README product fix |
| `matrix_row11_product_commit_clause` | Terraform/IaC delta |
| `matrix_row14_outcome_clause` | Release trace artifacts |
| `matrix_row14_outcome_only_clause` | CHANGELOG frozen — outcome only |
| `matrix_row15_outcome_clause` | Triad + instruction-ledger + ship-readiness |

Feature rows (3+) require **both** product commits and outcome methodology artifacts in invoke prompt — not product alone.

### OUT-REVIEW-01 — review-fix-ladder ledger

Row 15 and ladder scoring require **8/8** review-fix-ladder PASS in a populated ledger. Set `SB_E2E_REVIEW_LADDER_LEDGER` to the correct ladder ledger path when matrix ledger differs. Empty or wrong ledger → `OUT-REVIEW-01` partial → row 15 blocked (Codex-3 unblocked after ladder 8/8).

---

## 6. Scorer / rescore policy

| Event | Action |
|-------|--------|
| **Default after every row invoke** | Post-invoke rescore: `enterprise_e2e_outcome_row_passes` on row attempt log — **diagnostic**; certification credit requires live strict-clean (§5a) |
| **After harness fix** | `SB_E2E_MATRIX_FORCE=1` on affected row(s), then **live rerun** — rescore alone does **not** bypass install-version registry or grant certification credit |
| **Full re-run same install** | `SB_E2E_MATRIX_FORCE_ALL=1` overrides `.row-pass-registry.json` skip |
| **One-pass per install SHA** | Do **not** re-run rows already PASS at same `install_fp` — `FORCE` for fail-rows only; frozen-merge rescore for round closure when live batches already authored commits |
| **Stale evidence skip anti-pattern** | `SKIP: evidence already present` without `SB_E2E_MATRIX_FORCE=1` on brownfield fixture — **disqualifying** on first certification |
| **Evidence PASS + outcome FAIL** | Treat as scorer/harness bug until **live rerun** passes or issue filed — rescoring FAIL→PASS without live rerun is **disqualifying** (E2E-089) |
| **Ledger vs monitor mismatch** | Ledger wins; run `enterprise-e2e-ledger-reconcile.sh` |
| **Rescore-only 22/22** | **Not strict-clean** — Cursor-1 retry2 produced rescored 21–22/22 without live agent work on several rows; void for release sign-off |

**Certification rule:** Only **live matrix invocations** at the current install fingerprint count toward strict-clean and release candidate sign-off. Rescore may reconcile harness bugs but never substitutes for a missing live session.

Read [OUTCOME-ASSESSMENT-RUBRIC.md](../../.planning/enterprise-e2e/OUTCOME-ASSESSMENT-RUBRIC.md) before scoring. All **27 criteria** + blocking gates (`OUT-AUTO-01`, `OUT-CLARIFY-01`, `OUT-NOOP-01`, `OUT-WORLD-01`).

---

## 6a. Install-version row pass registry

**Policy (effective 2026-07-01):** Do **not** repeat any matrix row that has **already passed once** (live TUI + outcome criteria) for the **same SB install fingerprint** within a round or continuation. One clean pass per row per install is sufficient.

### Install fingerprint

Derived at matrix run time as:

```text
<host>@<sb_git_sha12>+<surface_hash12>
```

| Component | Source |
|-----------|--------|
| `host` | `SB_E2E_LIVE_RUNTIME` / `enterprise_e2e_matrix_host` (`claude` \| `codex` \| `cursor`) |
| `sb_git_sha12` | `git -C $SB_ROOT rev-parse --short=12 HEAD` |
| `surface_hash12` | `sha256(hooks/hooks.json_digest[:16] \| package.json version)[:12]` |

Re-install or harness surface change (hooks version bump) produces a **new** fingerprint — rows must be re-run on the new install. Legacy TSV registry `.e2e-matrix-pass-at-version.tsv` (`package@sha`) remains for Cursor track continuity; canonical JSON registry supersedes for strict-clean.

### Registry file

Path: [`.planning/enterprise-e2e/.row-pass-registry.json`](../../.planning/enterprise-e2e/.row-pass-registry.json)

Keyed by `install_fp` → `rows` → `{passed_at, log_ref, outcome_pass, source}`.

### Harness skip behavior

Before row *N*, if registry shows `outcome_pass: true` for current `install_fp`:

| Message | Class | Counts toward 22/22? | `SB_E2E_MATRIX_FAIL_ON_SKIP=1` |
|---------|-------|----------------------|--------------------------------|
| `ROW_ALREADY_PASSED_SAME_INSTALL` | Install-version pass | **Yes** (PASS) after first strict-clean round @ `install_fp` | **Disqualifying on first host certification** @ install_fp (§5a #5) |
| `SKIP: evidence already present` | Evidence reuse | No (SKIP) | **Fails** when set — never certification credit |

| Override | Effect |
|----------|--------|
| `SB_E2E_MATRIX_FORCE=1` | Re-run fail-rows / brownfield rows despite evidence SKIP; **does not** bypass install-version registry for already-passed rows |
| `SB_E2E_MATRIX_FORCE_ALL=1` | Full re-run including registry-passed rows — use only for deliberate full re-certification |

### Tier B vs §5b smoke subsets (unified)

| Phase | Rows | When | Purpose |
|-------|------|------|---------|
| **Tier B smoke** | **1, 3, 6** | Initial live bring-up before Tier C | Router + feature parent + fast path — cheapest structural live signal |
| **§5b smoke re-cert** | **1, 6, 11** + internal **21–22** | Post-merge / new `install_fp` only | Re-verify product-commit surfaces + internal inherit chain after harness surface change |

**Rule:** Tier B = **1, 3, 6** only. Rows **11, 21, 22** are **not** Tier B — they appear in **resume seeding** (after partial matrix progress) or in **post-merge §5b re-cert** (§11b sibling session). Do not conflate the two lists.

### Driver coordination (Round 8 example)

When a live driver (e.g. PID **47290** on `claude@30558b37…`) is mid-batch:

1. **Do not kill** a healthy driver to avoid duplicate TUI spend on rows already in flight.
2. Seed registry for smoke-passed rows **before** next resume launch per table above.
3. On resume after driver exit, seeded rows emit `ROW_ALREADY_PASSED_SAME_INSTALL` — run only missing rows.

`bash scripts/enterprise-e2e/strict-clean-check.sh` requires install registry **22/22** for current `install_fp` plus ledger reconcile and outcome assessment.

---

## 7. Quota-aware scheduling

- **429 / Token Plan:** retry same row every **60s** (`SB_E2E_MATRIX_QUOTA_RETRY_INTERVAL=60`) — not auth failure.
- **Do not** rotate API keys or restart auth mid-row without evidence of auth failure.
- **Tier B before Tier C** conserves quota during bring-up.
- **Surface gate before matrix:** Tier A `validate-host-install-surface.sh` + tri-host smoke must pass before spending live rows.
- **Narrow strict-clean during host bring-up:** Tier B smoke only until harness stable; defer full strict-clean claim until Tier C.

### Live host wrapper and model policy (pre-release)

Every live host-certification test MUST be initiated through the corresponding
`/silver:agent-*` wrapper with this fixed model mapping:

| Host | Required wrapper | Required model |
|------|------------------|----------------|
| Codex | `/silver:agent-codex` | **GPT-5.6 Luna Low** |
| Claude | `/silver:agent-claude` | **Haiku 4.5** |
| Cursor | `/silver:agent-cursor` | **Composer 2.5** |

Raw host CLI runs, silent model substitutions, or transcripts without the wrapper do not
count as live certification evidence.

**Current-cycle Cursor hold:** another session is fixing the Cursor five-tool stack. Do not
launch or retry Cursor live five-tool scenarios until that session reports completion and
the repair is available in the checkout or fixture under test; then rerun from a fresh
isolated fixture.

---

## 8. Single driver / daemon

| Policy | Value |
|--------|-------|
| Drivers per host | **1** — no parallel matrix operators |
| `SB_E2E_MONITOR_AUTO_RESTART` | **0** |
| Healthy driver | Do not kill **< 45 min** unless confirmed stuck/dead |
| **Duplicate-driver guard** | Before launching new driver, SIGTERM stale batch PIDs — duplicate drivers corrupt ledger/registry (Codex-3 SIGTERM remediation). **Runbook:** see §8 step-by-step below |
| Watchers | Prefer **tmux** durable daemon (`run-enterprise-e2e-matrix.sh` / tmux batch) — **not** `nohup` background shells as primary driver |
| Parent orchestrator | One **`composer-2.5`** background worker (`Task` tool); **never** `composer-2.5-fast` for subagents; resume same worker ID |
| Poll cadence | 60–90s substantive checkpoints |
| **ENOTFOUND / network** | Exponential backoff on poll — transient DNS failures are not auth failures |
| **Stdout buffering** | Cursor headless logs may show **0 B for ~30 min** while agent is working — buffering is normal but **does not** satisfy §5b log floor; wait or fix E2E-086 streaming |
| **Cursor auth** | Keychain / interactive Cursor auth — **not** `CURSOR_API_KEY` for live matrix drivers |
| **Per-row timeouts** | Row **8** (`silver-refactor`): `SB_E2E_ROW8_TIMEOUT=3600`; row **11** (`silver-devops`): `SB_E2E_ROW11_TIMEOUT=5400` (E2E-087) |
| **TUI monitor offset reset** | **Mandatory at round start** — `enterprise_e2e_reset_tui_monitor_offsets "$SB_ROOT"` seeks `.e2e-tui-watch-{host}-offsets.json` and `.tui-monitor-agent-offset.json` to EOF of existing attempt logs so historical rows are not replayed as new issues (E2E-086+ false-positive-replay). Called by `live-test.sh`, all `*-matrix-driver.sh`, and Cursor/Codex REAL drivers — **not** mid-batch inside `matrix.sh` |

Host-isolated artifacts: see [HOST-CONFIG.md](../../.planning/enterprise-e2e/HOST-CONFIG.md).

### SIGTERM / duplicate-driver runbook (step-by-step)

When resuming after crash, quota wall, or operator interrupt — **before** launching any new matrix driver:

1. **Identify host** — `export SB_E2E_LIVE_RUNTIME=<claude|codex|cursor>`.
2. **Check batch PID file** — `${SB_ROOT}/.e2e-matrix-${host}-batch.pid` (Codex: `.e2e-matrix-codex-batch.pid`). If missing, skip to step 5.
3. **Verify process alive** — `kill -0 "$(cat .e2e-matrix-${host}-batch.pid)" 2>/dev/null` or `enterprise_e2e_matrix_batch_running` in driver preflight.
4. **If alive and log growing** (< 45 min since last substantive log line): **do not SIGTERM** — poll-only resume (§7).
5. **If dead or stuck** (no log growth ≥ 45 min, or confirmed zombie):
   - `kill -TERM "$(cat .e2e-matrix-${host}-batch.pid)" 2>/dev/null; sleep 5`
   - `kill -KILL "$(cat .e2e-matrix-${host}-batch.pid)" 2>/dev/null` only if TERM ignored
   - Remove stale PID file: `rm -f .e2e-matrix-${host}-batch.pid`
6. **Sweep orphan matrix children** — `pgrep -f "run-enterprise-e2e-matrix.sh.*${host}"` (or host-specific driver name); SIGTERM each stale PID **for this host only** — never `pkill` another host (§9).
7. **Reconcile ledger** — `bash scripts/lib/enterprise-e2e-ledger-reconcile.sh <matrix-log>` before re-launch.
8. **Reset TUI monitor offsets** — `enterprise_e2e_reset_tui_monitor_offsets "$SB_ROOT"` at round resume (not mid-batch).
9. **Launch single driver** — one tmux session or `codex-r*-real-driver.sh`; confirm `enterprise_e2e_matrix_batch_running` returns false before start.

### Poll-exit `pipefail` — monitor vs poll scripts

| Script class | Location | `pipefail` requirement | Notes |
|--------------|----------|------------------------|-------|
| **Matrix monitor** | `scripts/monitor-enterprise-e2e-matrix.sh` | `set -uo pipefail` (no `-e` by design) | Watches batch PID + ledger reconcile; pipeline errors must propagate via `pipefail` |
| **Poll-exit wrappers** | `.planning/enterprise-e2e/.codex-r*-poll-exit.sh`, `.cursor3-monitor-loop.sh` | **`set -euo pipefail`** + export `SB_E2E_ENTERPRISE_MATRIX=1` | Poll until driver exit; silent false-green if `pipefail` omitted (E2E-117) |
| **REAL drivers** | `.planning/enterprise-e2e/codex-r*-real-driver.sh`, `cursor3-real-driver.sh` | `set -euo pipefail` | Call `enterprise_e2e_matrix_batch_running` before launch |

**Operator rule:** Never wrap poll-exit in `bash -c '... | tee ...'` without `set -o pipefail` in the subshell — a failing pipeline upstream of `tee` can exit 0 otherwise.

### Codex operational prerequisites (R1–3)

| Step | Requirement |
|------|-------------|
| **Session 0** | Full `bash scripts/install-codex.sh` before first live matrix — seeds hook trust, core-rules integrity |
| **REAL drivers** | `SB_E2E_SKIP_CODEX_INSTALL=1` after Session 0 — hook-trust seed per row, not full install each launch (E2E-108) |
| **core-rules.sha256** | Regenerate after Codex sanitize in `install-codex.sh` when `core-rules.md` changes — mismatch blocks session start (`dfa364c9`) |
| **Poll-exit pipefail** | Poll-exit wrappers: `set -euo pipefail` + `SB_E2E_ENTERPRISE_MATRIX=1`. Monitor: `set -uo pipefail` — see §8 table |
| **Quota 429** | Retry same row every 60s — not auth churn; schedule resume, do not rotate keys mid-row |

---

## 9. Cross-agent isolation

When Claude Round 6, Codex, and Cursor run in parallel:

1. **Separate SB git branches** per host — never commit Codex harness to `enterprise-e2e/cursor` or Claude `round6`.
2. **Separate fixture branches** per host — see §4.
3. **Separate locks** — `.e2e-live-test.lock` (Claude), `.e2e-live-test-codex.lock`, `.e2e-live-test-cursor.lock`.
4. **Never** `pkill` another host's monitor/driver PIDs.
5. **Never** remove another host's lock unless that host's driver PID is confirmed dead.
6. **Cursor worktree** when shared clone is dirty on another branch — `enterprise-grade-test-app-cursor` @ `enterprise-e2e/round-N-cursor` ([TEST-APP-BRANCH-POLICY.md](../../.planning/enterprise-e2e/TEST-APP-BRANCH-POLICY.md)).
7. **Single workspace per host** for SB fixes — test app is matrix CWD only.
8. **Branch guard:** `enterprise_e2e_assert_host_git_branch` in `matrix.sh` / `live-test.sh` — matrix aborts on SB harness branch mismatch.
9. **Cross-host contamination** on shared clone (Codex batch on Cursor branch, wrong `test_app_git_branch`) **voids the round** — reset fixture, verify worktree isolation (E2E-090).

---

## 10. Host execution prompts (per-track)

| Host | Prompt |
|------|--------|
| Codex | [`.planning/enterprise-e2e/CODEX-ENTERPRISE-E2E-EXECUTION-PROMPT.md`](../../.planning/enterprise-e2e/CODEX-ENTERPRISE-E2E-EXECUTION-PROMPT.md) |
| Cursor | [`.planning/enterprise-e2e/CURSOR-ENTERPRISE-E2E-EXECUTION-PROMPT.md`](../../.planning/enterprise-e2e/CURSOR-ENTERPRISE-E2E-EXECUTION-PROMPT.md) |
| Claude R6 | [`.planning/enterprise-e2e/ROUND-6-OPERATIONAL-ADDENDUM.md`](../../.planning/enterprise-e2e/ROUND-6-OPERATIONAL-ADDENDUM.md) |

All tracks **must read this methodology doc** at session start.

---

## 11. Single-pass-at-install-version (Cursor E2E — effective 2026-07-01)

**Policy:** Do **not** repeat any matrix row, ladder rung, or T1 criterion that already **Pass** at the current SB install version. One clean pass per row/criterion is sufficient within and across rounds (Cursor-1 + Cursor-2) when the install version key is unchanged.

**Install version key** (`SB_INSTALL_VERSION_KEY`):

```text
<SB_CURSOR_PLUGIN_VERSION>@<git HEAD short SHA at install-cursor.sh>
```

Example: `0.48.9@e9236365`

| Artifact | Path |
|----------|------|
| Install version file | `${SB_ROOT}/.e2e-cursor-install-version.txt` |
| Row pass registry | `${SB_ROOT}/.e2e-matrix-pass-at-version.tsv` |

Written by `bash scripts/install-cursor.sh` after each install. Harness skip log line:

```text
SKIP: row N already pass @ install <version>
```

**Force overrides** (explicit re-run only):

| Env | Effect |
|-----|--------|
| `SB_E2E_MATRIX_FORCE=1` | Re-run all requested rows |
| `SB_E2E_FORCE_ROW=1` | Re-run despite pass-at-version |

**Release candidate gate:** One strict-clean round @ release candidate `install_fp` is sufficient for host sign-off. Within that round, rows already Pass @ install version are skipped — the round still must complete Phase A→C for any not-yet-passed rows/criteria.

**T1 row 1:** single FORCE run when not already Pass @ version (replaces T1 FORCE×2).

**Cross-round skip:** `matrix.sh` consults `ROUND-CURSOR-*-LEDGER.md` + pass registry; if Cursor-1 row Pass and ledger SB SHA matches current install key, Cursor-2 skips that row.

**First certification @ install_fp:** Single-pass skip applies **only after** the host has completed at least one **live strict-clean** round at that install fingerprint. Prior rescored or inherited-evidence passes do not seed the registry for first certification.

---

## 11a. Cursor E2E harness fixes (E2E-086 – E2E-100)

Operators must understand these fixes — misreading them caused false PASS claims in Cursor-1/Cursor-2 (both **void**; see Appendix D):

| ID | Issue | Fix | Operator implication |
|----|-------|-----|----------------------|
| **E2E-086** | Cursor row logs stayed 0 B — `cursor-agent --print` ignored log file | `tests/live/agents/cursor/agent.sh` headless log streaming | 0 B logs → FAIL until streaming fix verified; check log bytes in §5b |
| **E2E-087** | Rows 2/3/5/8/11 hit 900s timeout | Default 1800s; rows **8→3600s**, **11→5400s** in `matrix.sh` | Extend before declaring timeout FAIL on long workflows |
| **E2E-088** | Outcome rubric false fails (handoff, super, KM, measure) | Scorer updates @ `8feda5fc`+ | Evidence PASS + outcome FAIL → fix harness, then **live rerun** |
| **E2E-089** | Rescore flipped rows to PASS without live agent work | Log resolver + scorer fixes — **rescore ≠ strict-clean** | Rescored 22/22 without live sessions is **void** for release |
| **E2E-090** | Parallel hosts shared one test-app checkout | `hosts.json` per-host `test_app_git_branch` + worktree | Always use host worktree; wrong branch **disqualifies round** |
| **E2E-091** | Row 1 `OUT-CLARIFY-01` false fail on routing-only sessions | `enterprise_e2e_outcome_score_clarify` returns `n/a` when routing evidence present | Routing-only row 1 without clarify is **not** a blocking fail |
| **E2E-092** | Row 6 timeout @ 900s when tmux/shell inherited legacy timeout | `matrix.sh` enforces cursor ≥1800s; `cursor3-real-driver.sh` exports timeout env | Use driver or export `CLAUDE_INTERACTIVE_TIMEOUT=1800` before matrix |
| **E2E-093** | §5b log floor (<2048 B) — cursor-agent `--print` summary-only + harness truncate | `agent.sh` preserves harness prefix, `stream-json` + `stdbuf`; `enterprise_e2e_matrix_finalize_attempt_log` composite transcript when evidence present | Short summary alone does **not** PASS §5b unless composite footer appended after evidence verify |
| **E2E-094** | Row 6 `OUT-ORCH-01` false fail on silver-fast fast-path | `enterprise_e2e_outcome_score_orch` returns `n/a` when row 6 evidence + `silver-fast` state present | Fast-path rows do not require orchestrator parent/worker chain |
| **E2E-095** | Brownfield evidence SKIP without `SB_E2E_MATRIX_FORCE=1` | `cursor3-real-driver.sh` + pipeline driver export `FORCE` + `FORCE_ALL` | First live FORCE on brownfield rows requires explicit force — inherited artifact alone is **not** strict-clean |
| **E2E-096** | Row 10 autonomy scorer false-negative on negated "operator pauses" + prompt `SB OVERRIDE` instruction | Babysitting exclusion + `SB OVERRIDE:` colon-required detector in outcome scorer | Rescore on genuine live log OK; do not rerun row when product delta already committed |
| **E2E-097** | Row 14 `OUT-RELEASE-01` partial — `silver-release` lacks ship-readiness dir | Row 14 uses CHANGELOG + release phase SHIP evidence path | Release workflow ≠ ship-readiness checklist row |
| **E2E-098** | Row 14 `OUT-KM-01` partial — matrix graphify preamble without agentmemory MCP | Matrix graphify preamble + MCP-disabled env → pass | Matrix TUI often disables agentmemory MCP — graphify preamble satisfies KM gate |
| **E2E-099** | Row 15 `OUT-RELEASE-01` partial on `review-triad` | `triad-currency.md` triad evidence path | Review-triad ≠ release workflow — triad artifact chain satisfies gate |
| **E2E-100** | Rows 21–22 internal gates lack attempt logs (<2048 B) | `.cursor3-monitor-loop.sh` exempts internal harness rows | Internal rows verify via parent rows 3/4 markers — no standalone §5b log floor |

---

## 11b. Codex & Claude harness fixes (E2E-101 – E2E-115)

Post-v0.50.2 (`779464af`) fixes from Round Codex-3 REAL and Round 9 Claude gates. **All hosts** must apply these operator rules — not only Cursor.

| ID | Issue | Fix | Operator implication |
|----|-------|-----|----------------------|
| **E2E-101** | Wrong test-app branch during matrix — evidence clobber across hosts | `enterprise_e2e_fixture_assert_branch_lock` pre/post invoke @ `b3e036b3` | **Never** `git checkout` fixture to another host's branch mid-round; verify lock lines in matrix log |
| **E2E-102** | Install-pass SKIP without live rerun; batch pid EXIT trap | `SB_E2E_MATRIX_FORCE_ALL=1` + EXIT trap @ `59ec1456` | First live cert requires `FORCE=1` on brownfield rows; `FORCE_ALL` for full re-run |
| **E2E-103** | Row 3 stub-only (planning file without api/currency commits) | force3 + PLAN/GATES/TRACE invoke @ `356e87ec`, `b40f44fc` | Row 3 **must** show §5b api/currency commits — workflow stub alone is **FAIL** |
| **E2E-104** | Rows 14/15/16 outcome partial without product delta | force1416 drivers @ `968a8008`, `7f822474` | Outcome-only rescues require live drivers — not ledger hand-edit |
| **E2E-105** | Claude routing state bleed between rows | Isolated state roots @ `80438bda` | Each Claude row uses fresh `${SB_RUNTIME_STATE_DIR}` — do not share parent state across rows |
| **E2E-106** | §5b smoke rows 6/11 baseline rev / printf gaps | Matrix §5b gate @ `8219477f`, `da61d5fb` | Smoke subset rows **6, 11, 21, 22** must pass §5b before full Tier C |
| **E2E-107** | Bracketed-paste collapsed — slash prompt not submitted | Expect paste confirm @ `d3ea981a` | If row log stops at `Queued follow-up`, check paste expand — re-run with harness fix |
| **E2E-108** | Slow Codex install every driver launch | `SB_E2E_SKIP_CODEX_INSTALL=1` on REAL drivers @ `7a625546` | Codex REAL: hook-trust seed only per row after Session 0 — not full install each row |
| **E2E-109** | Row 3 pilot mkdir before fixture root set | Export fixture root @ `4815d4b4` | Drivers must `export SB_TEST_ENTERPRISE_APP_ROOT` before any fixture mkdir |
| **E2E-110** | Custom API key disclaimer blocked launch | Inherit-keys bypass @ `6935a7c0` | Claude matrix: export `ANTHROPIC_API_KEY` or inherit-keys before driver |
| **E2E-111** | Hook audit on isolated Claude state | Allow isolated roots @ `5e5590cc` | Hook-delivery preflight uses row-scoped state — not global `~/.claude` only |
| **E2E-112** | Pilot row_passed stale log slice | Latest log slice @ `ba77d1b0` | Rescore uses **latest** `.e2e-rowN-*-attempt.log` by mtime — not first match |
| **E2E-113** | Strict-clean ledger pass summary | `$LEDGER` variable @ `b20a31f7` | Gate 3 resume checks ledger path from driver env |
| **E2E-114** | Codex-3 §5a/§5b product audit | Methodology + fixture reset @ `d0a271fb` | Codex cert requires committed product delta per §5b — same anti-faking as Cursor |
| **E2E-115** | CI fixture path writability | CI-writable paths @ `f86cb6a5` | Script tests use temp dirs — not operator home paths in CI |
| **E2E-116** | `core-rules.sha256` drift after Codex sanitize | Regenerate pin in `install-codex.sh` @ `dfa364c9` | Run full `install-codex.sh` Session 0; verify pin matches `core-rules.md` before live matrix |
| **E2E-117** | Poll-exit silent false-green | `pipefail` + `SB_E2E_ENTERPRISE_MATRIX=1` on monitor exit @ `dfa364c9` | Monitor scripts must fail loudly on pipeline errors |

### Operator rules — all registered issue classes (E2E-086 – E2E-115)

| Rule | Prevents |
|------|----------|
| **Fixture branch lock** — `enterprise-e2e/round-N-{host}` worktree only; assert pre/post every row | E2E-090, E2E-101 |
| **Ledger-derived fixture branch** — set `SB_E2E_LEDGER_FILE` so `round-N-{host}` derives from ledger basename when env unset | E2E-090, E2E-101 |
| **`SB_E2E_MATRIX_FORCE=1`** on first live brownfield row; **`FORCE_ALL=1`** only for deliberate full re-run | E2E-095, E2E-102 |
| **§5b log floor >2048 B** (or composite footer) before PASS | E2E-086, E2E-093, E2E-100 |
| **TUI monitor offset reset at round start** — `enterprise_e2e_reset_tui_monitor_offsets` before first live row | E2E-086 false-positive-replay |
| **Rescore ≠ strict-clean** — live rerun required for certification credit | E2E-089 |
| **Outcome scorer harness fixes** — evidence PASS + outcome FAIL → fix scorer @ `8feda5fc`+, then **live rerun**; do not claim PASS on stale outcome files | E2E-088 |
| **Routing-only clarify n/a** — row 1 `silver-router` without CLARIFY is not `OUT-CLARIFY-01` fail | E2E-091 |
| **Cursor timeout ≥1800s** — export in driver/tmux; matrix enforces; never inherit 900s shell default | E2E-087, E2E-092 |
| **Fast-path orch n/a** — row 6 `silver-fast` does not require orchestrator parent/worker chain | E2E-094 |
| **Row 14 release evidence** — CHANGELOG + release SHIP path; not ship-readiness checklist dir | E2E-097 |
| **Row 14 KM via graphify preamble** — matrix TUI may disable agentmemory MCP; graphify preamble satisfies `OUT-KM-01` | E2E-098 |
| **Row 15 triad evidence** — `triad-currency.md` + instruction-ledger; review-triad ≠ release workflow | E2E-099 |
| **Rows 14/15/16 live drivers** — outcome partials require `force1416`/`force141619` drivers, not ledger hand-edit | E2E-104 |
| **§5b smoke before Tier C** | Rows **6, 11** (plus **21–22** internal) must pass §5b before full matrix claim — Tier B bring-up uses **1, 3, 6** only | E2E-106 |
| **Bracketed-paste confirm** — if log stops at `Queued follow-up`, re-run with paste-expand harness fix | E2E-107 |
| **Fixture root before mkdir** — `export SB_TEST_ENTERPRISE_APP_ROOT` before any pilot/fixture mkdir | E2E-109 |
| **Claude inherit-keys bypass** — export `ANTHROPIC_API_KEY` or inherit-keys before matrix launch | E2E-110 |
| **Hook audit on isolated state** — hook-delivery preflight must allow row-scoped `${SB_RUNTIME_STATE_DIR}` | E2E-111 |
| **Latest attempt log for rescore** — use newest `.e2e-rowN-*-attempt.log` by mtime, not first glob match | E2E-112 |
| **`$LEDGER` in strict-clean summary** — Gate 3 resume checks driver-exported ledger path | E2E-113 |
| **CI-writable fixture paths** — script tests use temp dirs, not operator home paths | E2E-115 |
| **Internal rows 21–22** — inherit parent rows **3/4** live strict-clean @ `install_fp`; exempt §5b log floor when parent markers present (E2E-100) | E2E-100, §5a #6 |
| **Planning-file-guard TUI hits** — matrix prompt echo is annoyance, not blocker (SB OVERRIDE instruction) | E2E-026 |
| **SessionStart stale hooks** — run `install-claude.sh` after harness merge; prune removes `gsd-*` | E2E-010, E2E-003 |
| **Stop coalesce** — first gate reason only; do not interpret downstream Stop hooks as new defects | E2E-014 |
| **`SB_E2E_LEDGER_NO_UX_APPEND=1`** — friction to findings jsonl + issues doc, not human ledger | E2E-015 |
| **0-token mode banner** — harness sends Enter; extend quiet timeout before FAIL | E2E-081, E2E-087 |
| **Agent mode only** in matrix — no Plan/Debug mid-row | E2E-013 |
| **Codex install skip** on REAL drivers after Session 0 | E2E-108 |
| **Claude isolated state** per matrix row | E2E-105 |
| **Row 3 api/currency §5b** — not docs-only stub | E2E-103 |
| **Composer 2.5 only** for Cursor subagents — never `composer-2.5-fast` in matrix drivers | Cursor-3 REAL policy |
| **Keychain Cursor auth** — `cursor-agent login`; not `CURSOR_API_KEY` for live matrix | §8 Cursor auth |
| **Post-merge re-cert** — pull `main`, re-install host, Tier A + §5b smoke on new `install_fp` | §11b post-merge sibling |
| **Codex branch lock** — never commit Codex harness to Cursor/Claude branches | §9 |
| **Claude state isolation** — fresh `${SB_RUNTIME_STATE_DIR}` per row | E2E-105 |

### Codex / Claude §5a / §5b gates (mirror Cursor)

| Gate | Codex | Claude | Cursor |
|------|-------|--------|--------|
| **§5a anti-faking** | No inherited baseline PASS; no rescore-only 22/22 | Same | Same (Appendix D void Cursor-1/2) |
| **§5b log floor** | `codex-interactive-invoke.py` transcript + attempt log | `claude-interactive-invoke.expect` + bracketed-paste | `cursor/agent.sh` stream-json |
| **§5b product delta** | `git log` on fixture branch per row | Same | Same |
| **Smoke rows** | Tier B: **1, 3, 6**; post-merge §5b: **1, 6, 11** + **21–22** | Gate 3: **1, 6, 11** sequential | Full 22 @ `install_fp` (Cursor-3 REAL canonical) |
| **FORCE / install-skip** | `SB_E2E_SKIP_CODEX_INSTALL=1` after Session 0; `FORCE_ALL` for registry override | Full `install-claude.sh` after hook fix; isolated state per row | `FORCE`+`FORCE_ALL` in cursor3 driver; install-pass skip only after first strict-clean @ install_fp |

### Post-merge sibling session — re-certification required

When harness changes land on `main` from a **sibling agent session** (Cursor, Claude, or Codex track):

1. **Pull `main`** and re-run host install (`install-{claude,codex,cursor}.sh`).
2. **Re-run Tier A** structural suite (`test-enterprise-e2e-*.sh`, `test-outcome-assessment.sh`).
3. **Re-certify §5b smoke** (rows **1, 6, 11** + verify internal **21–22** inherit) under the **new install fingerprint** — prior PASS @ old `install_fp` does **not** carry forward after harness fixes. *(Distinct from initial Tier B smoke **1, 3, 6** — see §6a table.)*
4. Update ledgers with new commit SHA; cite E2E-101+ fix IDs when closing rows.
5. **Do not** claim host certification until smoke §5b GREEN on current `main` HEAD.

---

## Appendix A — Codex-1 status (historical — void for product)

**Round:** Codex-1 on `enterprise-e2e/codex` @ pre-seeded `8482e60`  
**Ledger:** [`.planning/enterprise-e2e/ROUND-CODEX-1-LEDGER.md`](../../.planning/enterprise-e2e/ROUND-CODEX-1-LEDGER.md)  
**Product audit:** [CODEX-TEST-APP-PRODUCT-AUDIT.md](../../.planning/enterprise-e2e/CODEX-TEST-APP-PRODUCT-AUDIT.md) — **0/22** row-mapped product commits — **void for product certification** (Appendix E)

| Item | Status |
|------|--------|
| Ladder 8/8 | **Complete** (harness) |
| Matrix harness | Up to 22/22 via rescore/frozen-merge — **not** product strict-clean |
| Harness fixes landed | `959de0ea` quiet timeout + scorer; `b4f471b3` TUI-aware outcome; `d24207e3` hook trust; `ac4b9322` OUT-SKILL-01; `dfa364c9` core-rules.sha256 |
| **Canonical resume** | Do **not** re-run on `8482e60`. Use honest `09f8d1a` baseline per §4 — Codex-3 REAL is canonical (Appendix E) |

---

## Appendix B — Quick Tier A copy-paste

```bash
export SB_ROOT=/Users/shafqat/projects/silver-bullet/repo
export SB_E2E_LIVE_RUNTIME=codex   # or cursor | claude
cd "$SB_ROOT"
export RTK_DISABLED=1

bash tests/enterprise-e2e-live/test-enterprise-e2e-live-suite.sh
bash tests/scripts/test-outcome-assessment.sh
bash scripts/run-enterprise-e2e-validation-overlay.sh --dry-run
bash scripts/run-enterprise-e2e-pre-release-overlay.sh --dry-run
bash scripts/validate-host-install-surface.sh --repo-root "$SB_ROOT" --host "$SB_E2E_LIVE_RUNTIME"
bash scripts/run-tri-host-install-smoke.sh --host "$SB_E2E_LIVE_RUNTIME"
SB_E2E_LIVE_RUNTIME="$SB_E2E_LIVE_RUNTIME" bash tests/e2e-live/hook-delivery-preflight.sh
bash scripts/run-enterprise-e2e-live-test.sh --host "$SB_E2E_LIVE_RUNTIME" --preflight-only
SB_E2E_MATRIX_DRY_RUN=1 bash scripts/run-enterprise-e2e-matrix.sh
```

---

## Appendix C — Anti-faking checklist (operator paste)

Before marking any row PASS in a ledger:

- [ ] Log file **> 2048 B** (or brownfield waiver with file:line)
- [ ] Live invoke (`SB_ENTERPRISE_E2E_LIVE=1`) at current `install_fp` — not rescore-only
- [ ] Fixture **commit SHA** on host branch (or documented brownfield waiver)
- [ ] `enterprise_e2e_outcome_row_passes` — no blocking gate partial
- [ ] Row 16: ship-readiness state matches outcome (not `NOT_MERGE_READY` + PASS)
- [ ] **Internal gates 21–22:** parent rows **3** (`silver-feature`) and **4** (`silver-bugfix`) live strict-clean @ same `install_fp` — internal rows verify orchestrator parent/worker markers only; **no standalone §5b log floor** when parent evidence present (E2E-100); **FAIL** if parents were install-skip, rescore-only, or inherited-baseline
- [ ] Rows 21–22: `OUT-ORCH-01` / internal gate criteria pass via parent chain — not standalone product commits
- [ ] Test-app branch = `enterprise-e2e/round-N-{host}` via worktree — not shared clone contamination
- [ ] Host-agent authorship attested — not operator-only routing for implement rows
- [ ] **Evidence type** recorded (`live-committed`, not `inherited-baseline` / `harness-rescore-only` / `frozen-merge` without round authorship)
- [ ] **Honest baseline** — fixture excludes `826cb5c` pre-seed for product certification rounds
- [ ] **Product audit** completed before round product claim (host-specific `*-TEST-APP-PRODUCT-AUDIT.md`)
- [ ] Row 15: `OUT-REVIEW-01` — ladder ledger 8/8 or `SB_E2E_REVIEW_LADDER_LEDGER` pointed correctly

---

## Appendix D — Cursor track lessons (Rounds Cursor-1/2 — **void**; Cursor-3 REAL canonical)

**Policy (2026-07-03):** Rounds **Cursor-1** and **Cursor-2** are **void** for host certification and release sign-off. Their ledgers, rescored outcome files, install-skip rows, and inherited-evidence passes **must not** be cited as strict-clean certification. The **canonical honest Cursor certification** is **Round Cursor-3 REAL** — [`.planning/enterprise-e2e/ROUND-CURSOR-3-REAL-LEDGER.md`](../../.planning/enterprise-e2e/ROUND-CURSOR-3-REAL-LEDGER.md) — **22/22 strict-clean** under §5a/§5b anti-faking methodology with harness fixes E2E-091–E2E-100.

Documented **disqualifying patterns** from void Cursor-1/Cursor-2 sessions — do not repeat:

| Pattern | Example | Verdict |
|---------|---------|---------|
| **Cursor-1/Cursor-2 round claims** | Any 22/22 or "strict-clean YES" on Cursor-1 or Cursor-2 ledgers | **Void** — superseded by Cursor-3 REAL |
| Inherited baseline PASS | Rows passing on `8482e60` artifacts without live session | **Void** |
| Rescore-only 22/22 | E2E-089 retry2 rescored evidence without live reruns | **Not strict-clean** — **Void** for certification |
| 148 B timeout PASS | Row 4 `silver-bugfix` PASS with 148 B + timeout | **Void** — §5a #3 |
| Install-skip first cert | Cursor-2 rows 2–6, 9–14, 17–20 `evidence_present` skip on first Cursor-2 @ new install | **Void** — install-skip without prior live strict-clean @ same `install_fp` |
| Audit-only row 7 | Verify-only with no product mutation | **Not certified delivery** |
| Wrong fixture branch | R8 Claude rows on `round-8-codex` instead of `round-8-claude` | **Round disqualified** |

**Real certification** (Cursor-3+ only): reset fixture to baseline SHA on `enterprise-e2e/round-N-cursor`, T0 → T1 live row 1 → T2 smoke or one full workflow row with **committed delta**, live FORCE on brownfield rows (`SB_E2E_MATRIX_FORCE=1`), ledger per [`.planning/enterprise-e2e/ROUND-CURSOR-3-REAL-LEDGER.md`](../../.planning/enterprise-e2e/ROUND-CURSOR-3-REAL-LEDGER.md). Harness rescoring (E2E-096/097/099) is permitted **only** on genuine live logs with committed product deltas — never on inherited or rescore-only evidence.

---

## Appendix E — Codex track lessons (Rounds Codex-1/2 — **void**; Codex-3 REAL canonical)

**Policy (2026-07-04):** Rounds **Codex-1** and **Codex-2** are **void** for host **product** certification and release sign-off. Their ledgers show harness 22/22 but [CODEX-TEST-APP-PRODUCT-AUDIT.md](../../.planning/enterprise-e2e/CODEX-TEST-APP-PRODUCT-AUDIT.md) records **0/22** row-mapped product commits on pre-seeded `8482e60`/`826cb5c` baseline. The **canonical honest Codex product certification** is **Round Codex-3 REAL** — [`.planning/enterprise-e2e/ROUND-CODEX-3-LEDGER.md`](../../.planning/enterprise-e2e/ROUND-CODEX-3-LEDGER.md) + [CODEX-3-TEST-APP-PRODUCT-AUDIT.md](../../.planning/enterprise-e2e/CODEX-3-TEST-APP-PRODUCT-AUDIT.md) — **19** product commits on `09f8d1a` honest baseline.

Documented **disqualifying patterns** from void Codex-1/Codex-2 sessions — do not repeat:

| Pattern | Example | Verdict |
|---------|---------|---------|
| **Codex-1/2 harness 22/22 cited as product cert** | Ledgers PASS on pre-seeded fixture | **Void** for product — harness only |
| Pre-seeded baseline PASS | Rows passing on `826cb5c`/`8482e60` artifacts without live session | **Void** — §5a #1 |
| Frozen-merge confirmation round | Codex-2: 20/22 rows frozen from R1 rescore; only row 15 late live | **Not strict-clean product** |
| Rescore-only row 16 | R1 row 16 PASS via harness fix without live re-run (quota wall) | **Void** — §5a #2 |
| Operator snapshot commit | `baadf87` — 560 files of session artifacts, not row product | **Not product delta** |
| Row 3 stub-only | Planning file without `api/` currency commits | **FAIL** §5b — E2E-103 |

**Real certification** (Codex-3+ only): reset fixture to **`09f8d1a`** on `enterprise-e2e/round-N-codex`, T0 → Tier B smoke (**1, 3, 6**) → ladder 8/8 with `OUT-REVIEW-01` ledger → live FORCE on brownfield rows, §5b product audit before product claim. Frozen-merge round closure permitted when commits authored in earlier live batches **same round** (Codex-3 force1416 rescore). **Release candidate sign-off:** Codex-3 REAL @ `f9ed398f` satisfies the single-round policy — [Appendix F](#appendix-f--release-candidate-sign-off-status--codex-host).

---

## Appendix F — Release candidate sign-off status — Codex host

**Policy:** Single-round release candidate gate (§3) — one strict-clean round @ release candidate `install_fp` with 22/22 live + §5b product audit + outcome PASS + Phase C green.

**Round Codex-4 executed?** **NO** — no `ROUND-CODEX-4-LEDGER.md`, no `ROUND-CODEX-4*` gate artifacts, no matrix/poll logs from a Codex-4 driver run. Only a prepared driver template exists ([`codex-r4-real-driver.sh`](../../.planning/enterprise-e2e/codex-r4-real-driver.sh)); it was never launched to completion.

| Item | Codex-3 REAL @ closure | Meets new 1-round policy? |
|------|------------------------|---------------------------|
| SB closure SHA | `f9ed398f` (harness); `main` post-merge `874c4a07` | Yes — release candidate version |
| Fixture | `enterprise-e2e/round-9-codex` @ `09f8d1a` honest baseline | Yes — excludes pre-seed fraud |
| Matrix 22/22 live + §5b | **PASS** — [.codex-r3-force1416-rescore.log](../../.planning/enterprise-e2e/.codex-r3-force1416-rescore.log) | Yes |
| Product audit | **PASS** — **19** commits ([CODEX-3-TEST-APP-PRODUCT-AUDIT.md](../../.planning/enterprise-e2e/CODEX-3-TEST-APP-PRODUCT-AUDIT.md)) | Yes |
| Phase C | **PASS** — 5067/5067 run-all-tests; ledger reconcile COMPLETE; RCS ≥ 85 | Yes |
| Outcome assessment | **PASS** 79/79 @ Phase C | Yes |

**Verdict:** **Codex host product certification sign-off — PASS** @ SB `f9ed398f` / Codex-3 closure. Codex-3 REAL is the certifying round under the current policy. Codex-4 is **not required**; run Codex-4 (or any new round) only when re-certifying a **new** release candidate `install_fp` after harness surface change or post-merge sibling session (§11b).

**Historical note:** Under the deprecated 2/2 pair policy, Codex-3 counted as 1/2 and Codex-4 would have been required. That policy is superseded as of 2026-07-04.
