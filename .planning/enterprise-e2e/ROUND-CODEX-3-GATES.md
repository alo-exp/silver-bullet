# Round Codex-3 REAL — Gate checklist

**Host:** Codex TUI — **honest product certification** (voids Codex-1/2 harness-only 22/22)  
**Updated:** 2026-07-02  
**SB HEAD:** `25d373a6`  
**Test app:** `enterprise-e2e/round-9-codex` @ `09f8d1a`  
**Ledger:** [ROUND-CODEX-3-LEDGER.md](./ROUND-CODEX-3-LEDGER.md)  
**Prior rounds:** Codex-1/2 harness PASS — **void for product work** per [CODEX-TEST-APP-PRODUCT-AUDIT.md](./CODEX-TEST-APP-PRODUCT-AUDIT.md)

## Status: **OPEN — in progress**

### §5b product-work required gate (Codex-3 REAL)

Every implement row (2–14, 16–20) **must** satisfy **all** of:

| Gate | Requirement |
|------|-------------|
| Log size floor | Row attempt log **> 2048 B** |
| Live strict-clean | `SB_ENTERPRISE_E2E_LIVE=1` + live TUI invoke (not rescore-only, not frozen-merge) |
| **Product delta** | **Committed** change on `enterprise-e2e/round-9-codex` after row invoke — harness enforces via `enterprise_e2e_assert_row_product_commit_delta` |
| Host-agent authorship | Codex TUI authored deliverable (not operator parent) |
| Outcome PASS | All applicable criteria + blocking autonomy gates |
| No pre-seed pass | Fixture excludes `826cb5c` matrix pre-population |

**Exempt from product commit gate:** row 1 (routing), row 15 (triad audit), rows 21–22 (internal inherit from live parents 3/4).

**Disqualifying (§5a):** inherited baseline pass, harness-rescore-only, empty-log PASS, audit-only with zero commit, install-skip on first certification.

### Staged gates

| Gate | Status |
|------|--------|
| Fixture `round-9-codex` @ `09f8d1a` (no `826cb5c`) | **PASS** |
| Harness product-commit gate landed | **PASS** |
| Tier A offline (all structural) | **PASS** @ `25d373a6` |
| Tier B smoke rows 1, 3, 6 | **RUNNING** (batch PID 60854) |
| review-fix-ladder 8/8 | *pending* |
| Matrix 22/22 live + §5b per row | *pending* |
| Phase C (run-all-tests, overlays, reconcile, RCS) | *pending* |
| [CODEX-3-TEST-APP-PRODUCT-AUDIT.md](./CODEX-3-TEST-APP-PRODUCT-AUDIT.md) | *pending* — target **>0** product commits |

### Release verdict

**Not applicable** — Codex-3 REAL is a **product honesty reset**, not a consecutive-pair release round. Codex-1/2 harness pair remains documented separately; product certification requires Codex-3 REAL completion.
