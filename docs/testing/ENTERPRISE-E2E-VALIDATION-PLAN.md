# Enterprise E2E Validation Plan

**Status:** Active — 2026-06-29  
**Audience:** SB maintainers, enterprise E2E operators, release gate owners  
**Companion:** [ENTERPRISE-E2E-EFFECTIVENESS-PLAN.md](./ENTERPRISE-E2E-EFFECTIVENESS-PLAN.md) (testing/wiring focus)  
**Scope:** User outcomes and marketing/docs claims at [sb.alolabs.dev](https://sb.alolabs.dev) and [Help Center](https://sb.alolabs.dev/help/)

---

## 1. Definitions

| Term | Meaning | Primary artifacts |
|------|---------|-------------------|
| **Testing** | Proves SB **wiring** — 22 workflow routes, AF coverage, hooks, harness scripts, ladder rungs | `run-enterprise-e2e-matrix.sh`, `test-enterprise-e2e-live-suite.sh`, Round ledgers |
| **Verification** | Proves **structural contracts** — catalog counts, site↔registry parity, generated views fresh | `claims-audit.sh`, `check-apo-invariants.py`, `apo-catalog.json` |
| **Pre-release** | Proves **feature-level** homepage/help claims before tag — install surfaces, catalog counts, hooks, tri-host smoke | `pre-release-claims-registry.json`, `run-enterprise-e2e-pre-release-overlay.sh`, `run-tri-host-install-smoke.sh` |
| **Validation** | Proves **user outcomes/capabilities** — ship readiness, evidence gates, onboarding SLO, cost telemetry philosophy | This plan, `validation-claims-registry.json`, `run-enterprise-e2e-validation-overlay.sh` |

**Taxonomy rule:** If a claim can be tested in pre-release (overlay dry-run structural checks, claims-audit, matrix rows, install scripts, tri-host smoke), it does **not** belong in `validation-claims-registry.json`.

**Rule:** Testing can be 22/22 while validation fails (e.g. ship-readiness outcome undocumented). Validation overlays testing; it does not replace it. Pre-release overlays both for feature claims.

---

## 2. Feature vs validation vs pre-release

| Layer | Question | Registry | Overlay script |
|-------|----------|----------|----------------|
| **Pre-release** | Do feature claims hold? (catalog counts, hooks, install scripts, router doc, tri-host) | [`pre-release-claims-registry.json`](./pre-release-claims-registry.json) | `run-enterprise-e2e-pre-release-overlay.sh` |
| **Validation** | Do outcome/capability promises hold? (evidence gates, ship readiness, free forever, onboarding SLO) | [`validation-claims-registry.json`](./validation-claims-registry.json) | `run-enterprise-e2e-validation-overlay.sh` |
| **Testing** | Does the 22-row matrix pass? | Matrix ledgers | `run-enterprise-e2e-live-test.sh` |

**Removed from validation (always):**

| claim_id | Reason | Where now |
|----------|--------|-----------|
| `hero-apo-title` | Product title — always true, not an outcome | Dropped |
| `hero-tri-host` / `help-tri-host` | Host portability — install smoke, not validation | Pre-release + tri-host smoke |
| `help-router-workflow` | Router composition — matrix row 1 / pre-release | Pre-release |

Demoted feature claims (catalog counts, twelve hooks, code intel, sb-diagnostics, help version/coverage/SOT) live in [`pre-release-claims-registry.json`](./pre-release-claims-registry.json).

### Pre-release tri-host smoke

Before release, each host must install SB locally and pass a few SB script invocations:

```bash
# Operator — all hosts (Claude skipped when CLI absent)
RTK_DISABLED=1 bash scripts/run-tri-host-install-smoke.sh

# CI structural — Codex + Cursor only
bash tests/scripts/test-tri-host-install-smoke.sh

# Wired into pre-release overlay
RTK_DISABLED=1 bash scripts/run-enterprise-e2e-pre-release-overlay.sh --with-tri-host-smoke
```

Per host: `install-{claude,codex,cursor}.sh` → `sb-diagnostics.sh` → `claims-audit.sh` + `check-apo-invariants.py site-doc-freshness`.

Document in operator prompt: run tri-host smoke after pre-release overlay dry-run green and before `gh release create`.

---

## 3. Validation vs effectiveness plan

| Layer | Effectiveness plan | Validation plan (this doc) |
|-------|-------------------|----------------------------|
| Question | Is the harness reliable? | Does SB deliver what users expect from marketing/docs? |
| Primary source | Matrix ledgers, runbook, scripts | `site/index.html`, `site/help/**`, README |
| Pass signal | 22/22 ledger, RCS ≥ 85 | Validation overlay green + mapped gate claims ✅ |
| Failure example | Monitor/ledger drift | Help Center version stale; V-01 onboarding SLO unmeasured |

---

## 4. Homepage claim inventory methodology

1. **Extract** — Outcome claims in [`validation-claims-registry.json`](./validation-claims-registry.json); feature claims in [`pre-release-claims-registry.json`](./pre-release-claims-registry.json); homepage selectors in [`claims-registry.json`](./claims-registry.json).
2. **Anchor** — Each claim has `source_selector` or `surface` + verbatim `text` from live HTML.
3. **Map** — Assign `check_id`, `verification_tier`, and `test_ids` (structural, contract, matrix row, or live backlog).
4. **Enforce** — `claims-audit.sh` fails if registry text disappears from homepage or unregistered `data-claim` appears.
5. **Report** — Overlay run writes [`validation-overlay-results-YYYY-MM-DD.md`](./validation-overlay-results-2026-06-29.md).

**Tier definitions:**

| Tier | When it runs | Examples |
|------|--------------|----------|
| `structural` | Every overlay dry-run | install scripts exist, help pages exist, version sync |
| `contract` | Every overlay dry-run | 22 WF / 27 AF counts, apo invariants, claims-audit |
| `matrix_overlay` | `--live` + ledger | Row Pass → linked outcome claims satisfied |
| `live` | Manual / future SLO scripts | 60-min onboarding block-PR (V-01) |
| `telemetry_only` | Append-only capture — **no pass/fail** | V-02 token/cost data for later 10×/60× analysis |

---

## 5. Help Center staleness re-verification process

**Run before every validation mapping session** (or when site/help changes):

1. **Version sync** — `package.json` version vs `site/help/index.html` meta (see [staleness audit](./help-center-staleness-audit-2026-06-29.md)).
2. **Catalog SOT** — Help index references `docs/apo-catalog.json`; counts match (22 workflows, 27 atomic flows).
3. **Workflow page coverage** — Map `WF-*` catalog IDs → `site/help/workflows/silver-*.html` slugs; internal workflows (`WF-POST-EXEC-GATES`, `WF-VALIDATE-SUBSTEP`) are documented exceptions.
4. **Tri-host surface** — Help mentions Claude, Codex, Cursor; repo has `install-*.sh` + `hooks/cursor-hook-bridge.sh`.
5. **Invariant checks** — `python3 scripts/check-apo-invariants.py site-doc-freshness` and `apo-hierarchy-integrity`.
6. **Optional live fetch** — Compare deployed `https://sb.alolabs.dev/help/` to local `site/help/` after publish (not required for overlay dry-run).

**Staleness severity:**

| Severity | Condition | Action |
|----------|-----------|--------|
| P0 | Version mismatch help vs package | Fix help meta before release |
| P1 | User-facing WF missing help page | Add page or document exception |
| P2 | Help copy contradicts catalog/hooks | Fix copy or product; log in backlog |
| P3 | Extra help pages for AF-only flows | OK — document as AF docs |

---

## 6. Claim → behavior mapping matrix

### Validation outcomes (validation-claims-registry.json)

| claim_id | User expectation | Verification | Matrix / test link |
|----------|------------------|--------------|-------------------|
| `hero-evidence-gates` | Unsafe PR/release blocked until evidence real | `evidence-gates-outcome` + claims-audit | E2E rows 14–16 |
| `hero-capabilities` | Engineering best practices enforced | `capabilities-outcome` | E2E matrix |
| `hero-free-no-telemetry` | Free forever, no telemetry | `free-forever-outcome` | claims-audit |
| `help-ship-readiness` | Ship gates documented and enforced | help page + E2E row 16 | rows 14–16 |
| `first-hour-block-pr` | First session blocks unsafe PR | **backlog** (`live`) | planned-onboarding-slo |
| `hero-reliability-cost` | 10× lower cost | **telemetry only** (V-02) | token-telemetry-jsonl |

### Pre-release features (pre-release-claims-registry.json)

| claim_id | User expectation | Verification |
|----------|------------------|--------------|
| `hero-tri-host` | Works in Claude, Codex, Cursor | `run-tri-host-install-smoke.sh` |
| `mechanism-catalog-counts` | 27 AF, 22 WF | `apo-catalog-counts` |
| `mechanism-twelve-hooks` | Hooks physically block progress | `hook-scripts-present` |
| `help-router-workflow` | Router doc matches `/silver` behavior | help page + E2E row 1 |
| `help-catalog-version` | Docs match shipped version | `help-version-sync` |

Full machine-readable map: [`validation-claims-registry.json`](./validation-claims-registry.json).

---

## 7. Overlay integration with 22-row live matrix

The validation overlay **does not start, stop, or signal** matrix drivers. Safe alongside active batch PID (e.g. 7484).

```
┌─────────────────────────────────────────────────────────────────┐
│ Layer 3: Live matrix (22 rows) — UNCHANGED                      │
│   SB_ENTERPRISE_E2E_LIVE=1 run-enterprise-e2e-live-test.sh      │
└────────────────────────────┬────────────────────────────────────┘
                             │ optional parallel
┌────────────────────────────▼────────────────────────────────────┐
│ Validation overlay (this plan)                                  │
│   SB_E2E_VALIDATION_OVERLAY=1                                   │
│   run-enterprise-e2e-validation-overlay.sh [--dry-run|--live]   │
└─────────────────────────────────────────────────────────────────┘
```

| Mode | Env | Behavior |
|------|-----|----------|
| Dry-run (default) | `SB_E2E_VALIDATION_OVERLAY_DRY_RUN=1` | Structural + contract checks only |
| Live overlay | `--live` | Above + ledger row→claim cross-check via `SB_E2E_LEDGER_FILE` |

**When to run:**

| Trigger | Command |
|---------|---------|
| Pre-matrix gate | `RTK_DISABLED=1 bash scripts/run-enterprise-e2e-validation-overlay.sh --dry-run` |
| Post-row / post-round | `SB_E2E_LEDGER_FILE=.planning/enterprise-e2e/ROUND-N-LEDGER.md bash scripts/run-enterprise-e2e-validation-overlay.sh --live` |
| CI structural | `bash tests/enterprise-e2e-live/test-enterprise-e2e-validation-overlay.sh` |

**Matrix criteria extension (operator):** When a row passes, confirm linked claims in `matrix_row_claim_map` — e.g. row 16 Pass implies ship-readiness outcome documented *and* evidenced.

---

## 8. Gap remediation workflow

1. **Overlay fails** → classify: `copy` | `product` | `harness` | `backlog`
2. **Small fix (≤ ~30 min)** — fix in SB repo, re-run overlay, commit on `main` with `fix(validation):` or `docs(help):`
3. **Large product gap** — add `status: backlog` in `validation-claims-registry.json`; document in §9 backlog; do **not** block matrix
4. **Marketing-only stats** (Veracode 39%, 7× rework) — label external/unverified in registry; no E2E assertion
5. **Cost claim (V-02)** — **excluded from validation gates**; capture token telemetry only (§10)
6. **Re-verify** — overlay dry-run green + update `validation-overlay-results-YYYY-MM-DD.md`

---

## 9. RCS / scoring integration

[enterprise-e2e-rcs.sh](../../scripts/enterprise-e2e-rcs.sh) computes Release Confidence Score. Validation extends it:

| Component | Weight (RCS) | Validation overlay contribution |
|-----------|--------------|--------------------------------|
| claims audit | 15% | Unchanged — homepage registry |
| **validation overlay** | *advisory* | Set `SB_E2E_RCS_VALIDATION_OVERLAY=pass` when overlay dry-run green |

**Advisory rule:** RCS ≥ 85 still allowed if overlay has only `backlog` live-tier gaps; RCS ≥ 90 for major tag requires overlay pass **and** no P0/P1 validation failures.

```bash
# Example gate bundle
RTK_DISABLED=1 bash scripts/run-enterprise-e2e-validation-overlay.sh --dry-run \
  && SB_E2E_RCS_VALIDATION_OVERLAY=pass RTK_DISABLED=1 bash scripts/enterprise-e2e-rcs.sh
```

---

## 9. Auth policy (Enterprise E2E)

| Rule | Detail |
|------|--------|
| **Never login/logout** | No `claude auth login`, `claude auth logout`, `claude /logout`, `setup-token`, or agent `/login` during matrix runs |
| **Token gateway is valid** | MiniMax M3 / custom API gateway via `~/.codex/settings.json` (`ANTHROPIC_BASE_URL` + `ANTHROPIC_API_KEY`) |
| **"Not logged in" banner** | Cosmetic OAuth UI state when token gateway is active — harness ignores it; not a failure |
| **Settings export default** | `SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT=0` — matrix exports settings env before interactive TUI spawn |
| **API key disclaimer** | `CLAUDE_INTERACTIVE_CUSTOM_API_KEY_STRATEGY=keys` — harness accepts custom key prompt |
| **Monitor restarts** | `monitor-enterprise-e2e-matrix.sh` forces `SKIP_SETTINGS_EXPORT=0` on FORCE batch restarts |

---

## 9. Auth policy (Enterprise E2E)

| Rule | Detail |
|------|--------|
| **Never login/logout** | No `claude auth login`, `claude auth logout`, `claude /logout`, `setup-token`, or agent `/login` during matrix runs |
| **Token gateway is valid** | MiniMax M3 / custom API gateway via `~/.codex/settings.json` (`ANTHROPIC_BASE_URL` + `ANTHROPIC_API_KEY`) |
| **"Not logged in" banner** | Cosmetic OAuth UI state when token gateway is active — harness ignores it; not a failure |
| **Settings export default** | `SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT=0` — matrix exports settings env before interactive TUI spawn |
| **API key disclaimer** | `CLAUDE_INTERACTIVE_CUSTOM_API_KEY_STRATEGY=keys` — harness accepts custom key prompt |
| **Monitor restarts** | `monitor-enterprise-e2e-matrix.sh` forces `SKIP_SETTINGS_EXPORT=0` on FORCE batch restarts |

---

## 10. Backlog (large gaps — do not block matrix)

| ID | Claim | Gap | Proposed work |
|----|-------|-----|---------------|
| V-01 | `first-hour-block-pr` | No timed onboarding SLO script | `tests/onboarding/` timed fixture |
| V-03 | Tri-host install smoke | Codex/Cursor in CI; Claude operator-local | `run-tri-host-install-smoke.sh` |
| V-04 | `WF-POST-EXEC-GATES` help | Internal WF — no dedicated page | Optional concept page or cross-link from validate |
| V-05 | Matrix monitor↔ledger | Measurement drift (Round 3) | P0-1 effectiveness plan — independent of validation |

### V-02 — `hero-reliability-cost` (“10× lower cost”) — **excluded from validation gates**

**Status:** `validation_scope: telemetry_only` — **not** a pass/fail gate in the validation overlay suite.

**User rationale (verbatim):**

- With SB in place, models ~60× cheaper than premium (e.g. Composer 2.5 vs Opus/GPT-5.5) can produce artifacts reliable enough for top-tier quality
- Net savings is ~10× not 60× because: (1) SB overhead causes ~3× more work overall, (2) verification/validation loops ideally run on GPT-5.5/Opus
- Marketing “10× lower cost” will **NOT** be validated as part of the validation overlay suite
- **Do** keep tracking token counts as data for later cost/analysis (telemetry only, not pass/fail gate)

**Telemetry policy:** Overlay and matrix harness append JSONL records (§10). Operators may analyze later; overlay dry-run/live exit codes ignore V-02.

---

## 11. Artifacts

| Artifact | Path |
|----------|------|
| Validation plan | `docs/testing/ENTERPRISE-E2E-VALIDATION-PLAN.md` |
| Staleness audit | `docs/testing/help-center-staleness-audit-2026-06-29.md` |
| Outcome claims registry | `docs/testing/validation-claims-registry.json` |
| Feature claims registry | `docs/testing/pre-release-claims-registry.json` |
| Validation overlay script | `scripts/run-enterprise-e2e-validation-overlay.sh` |
| Pre-release overlay script | `scripts/run-enterprise-e2e-pre-release-overlay.sh` |
| Tri-host install smoke | `scripts/run-tri-host-install-smoke.sh` |
| Tri-host smoke test | `tests/scripts/test-tri-host-install-smoke.sh` |
| Overlay lib | `scripts/lib/enterprise-e2e-validation-overlay.sh` |
| Pre-release overlay lib | `scripts/lib/enterprise-e2e-pre-release-overlay.sh` |
| Token telemetry lib | `scripts/lib/enterprise-e2e-token-telemetry.sh` |
| Structural tests | `tests/enterprise-e2e-live/test-enterprise-e2e-validation-overlay.sh` |
| Results | `docs/testing/validation-overlay-results-2026-06-29.md` |
| Round 3 ledger | `.planning/enterprise-e2e/ROUND-3-LEDGER.md` |
| **Token telemetry (primary)** | `.planning/enterprise-e2e/token-telemetry.jsonl` |
| **Token telemetry (mirror)** | `docs/testing/telemetry/token-telemetry.jsonl` |

### Token telemetry format (V-02 — telemetry only)

Append-only JSONL. **No pass/fail gate** on token counts. One object per overlay run or matrix row event.

| Field | Purpose |
|-------|---------|
| `ts` | UTC ISO8601 timestamp |
| `event_source` | `validation_overlay`, `matrix_row`, `matrix_row_skip`, etc. |
| `claim_ref` | `V-02` |
| `validation_scope` | `telemetry_only` |
| `gate` | Always `none` |
| `row` | Matrix row `{num, slug, result, log}` when applicable |
| `model` | `CLAUDE_MODEL` / host model when known |
| `tokens.tui_max` | Max TUI footer token count parsed from row log (when present) |
| `tokens.input` / `output` / `total` | Reserved for usage-API fields (null until wired) |
| `rtk_stats` | RTK `stats` snapshot when available |
| `overlay` | Overlay pass/fail/skip counts when event is overlay |
| `matrix_driver_pid` | Observed matrix PID (read-only; never signalled) |

---

## 12. Operator quick start

```bash
cd /path/to/silver-bullet/repo

# 1. Pre-release feature checks (safe during live matrix)
RTK_DISABLED=1 bash scripts/run-enterprise-e2e-pre-release-overlay.sh --dry-run

# 2. Tri-host install smoke (Codex + Cursor in CI; Claude when CLI present)
RTK_DISABLED=1 bash scripts/run-tri-host-install-smoke.sh

# 3. Outcome validation overlay (structural + claims-audit)
RTK_DISABLED=1 bash scripts/run-enterprise-e2e-validation-overlay.sh --dry-run

# 4. Include ledger-linked outcome claims (after rows complete)
SB_E2E_LEDGER_FILE=.planning/enterprise-e2e/ROUND-3-LEDGER.md \
  RTK_DISABLED=1 bash scripts/run-enterprise-e2e-validation-overlay.sh --live

# 5. Structural CI tests
bash tests/enterprise-e2e-live/test-enterprise-e2e-validation-overlay.sh
bash tests/scripts/test-tri-host-install-smoke.sh
```

**Constraints:** composer-2.5 for delegated work; **never** `claude auth login/logout` or `/login`/`/logout`; MiniMax/custom API gateway (`ANTHROPIC_BASE_URL` + key in `~/.codex/settings.json`) is valid auth — the TUI "Not logged in" OAuth banner is cosmetic; do not `pkill` matrix drivers.
