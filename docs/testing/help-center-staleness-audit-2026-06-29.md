# Help Center Staleness Audit — 2026-06-29

**Auditor:** Enterprise E2E validation overlay (automated + repo analysis)  
**Sources:** Local `site/help/**`, `docs/apo-catalog.json`, `package.json`, `site/index.html`  
**Deployed reference:** [https://sb.alolabs.dev/help/](https://sb.alolabs.dev/help/) (local repo is SOT for this audit; publish parity assumed after last site deploy)

---

## Executive summary

| Area | Status | Notes |
|------|--------|-------|
| Version sync (help vs package) | ✅ PASS | Both `0.48.6` |
| Catalog counts (22 WF / 27 AF) | ✅ PASS | Matches help meta description |
| Homepage claims registry | ✅ PASS | 15/15 texts present on `site/index.html` |
| User-facing workflow help pages | ✅ PASS | 20/20 user-facing WFs have `silver-*.html` pages |
| Internal workflow help pages | ⚠️ EXPECTED GAP | `WF-POST-EXEC-GATES`, `WF-VALIDATE-SUBSTEP` — no dedicated pages (by design) |
| Tri-host install surface | ✅ PASS | `install-claude.sh`, `install-codex.sh`, `install-cursor.sh`, `hooks/cursor-hook-bridge.sh` |
| APO catalog SOT reference in help | ✅ PASS | `site/help/index.html` cites `docs/apo-catalog.json` |
| Extra help pages (AF-only) | ℹ️ INFO | `silver-spec`, `silver-ingest`, `silver-clarify`, `silver-validate` — atomic/sub-flow docs beyond 22 matrix rows |

**Overall:** Help Center is **not stale** relative to repo product surface for version, catalog counts, and workflow documentation. Remaining gaps are **internal workflows** and **unverified marketing SLOs** (V-01 onboarding timing) — tracked in validation backlog. **V-02 “10× lower cost”** is **out of validation scope** (telemetry only; see [ENTERPRISE-E2E-VALIDATION-PLAN.md](./ENTERPRISE-E2E-VALIDATION-PLAN.md) §9).

---

## Methodology

1. Compared `package.json` version to `site/help/index.html` meta description.
2. Loaded `docs/apo-catalog.json` — counted 22 workflows, 27 atomic flows.
3. Mapped each `WF-*` ID to expected help slug (`WF-SILVER-FEATURE` → `silver-feature.html`).
4. Ran `claims-audit.sh` against homepage registry.
5. Verified tri-host install scripts and cursor hook bridge paths.
6. Ran `python3 scripts/check-apo-invariants.py site-doc-freshness` and `apo-hierarchy-integrity` (via validation overlay).

---

## Findings detail

### F1 — Version sync ✅

- `package.json`: `0.48.6`
- `site/help/index.html` meta: `Silver Bullet v0.48.6 Help Center`

### F2 — Workflow page coverage ✅ (with documented exceptions)

| Catalog ID | Help page | Status |
|------------|-----------|--------|
| WF-SILVER-ROUTER | `silver-router.html` | ✅ |
| WF-SILVER-FEATURE | `silver-feature.html` | ✅ |
| WF-REVIEW-TRIAD | `silver-review-triad.html` | ✅ |
| WF-SHIP-READINESS | `silver-ship-readiness.html` | ✅ |
| WF-SILVER-DEVOPS | `silver-devops.html` | ✅ |
| … (16 more user-facing WFs) | `silver-*.html` | ✅ |
| WF-POST-EXEC-GATES | — | ⚠️ internal — no page required |
| WF-VALIDATE-SUBSTEP | — | ⚠️ internal — `silver-validate.html` covers AF validate |

### F3 — Extra help pages (not staleness) ℹ️

Help documents atomic/sub-flow entry points not in the 22-row matrix:

- `silver-spec.html`, `silver-ingest.html`, `silver-clarify.html`, `silver-validate.html`

These align with `skill_to_entity` routes in `apo-catalog.json` migration map.

### F4 — Homepage claims vs help tri-host ✅

Both homepage and help index mention Claude Code, Codex, and Cursor. Install surface exists in repo.

### F5 — Unverified user promises (not help staleness) ⚠️ BACKLOG / TELEMETRY

| Claim | Help/home copy | Product proof | Validation scope |
|-------|----------------|---------------|------------------|
| 10× lower cost (V-02) | Homepage hero | Token telemetry JSONL only | **telemetry_only** — excluded from overlay gates |
| First unsafe PR in 30–60 min (V-01) | Homepage `#next-steps` | No timed onboarding script | **backlog** |
| 39% Veracode stat | Homepage `#cost` | External citation — not SB behavior | **external** |

---

## Recommendations

1. **No urgent help copy updates** for version or workflow catalog.
2. Add cross-link from `silver-validate.html` to internal `WF-VALIDATE-SUBSTEP` concept (P2, optional).
3. Run this audit after each `site/help/` batch publish and before validation mapping sessions.
4. Track marketing SLO gaps in [ENTERPRISE-E2E-VALIDATION-PLAN.md](./ENTERPRISE-E2E-VALIDATION-PLAN.md) §9 backlog.

---

## Re-run command

```bash
RTK_DISABLED=1 bash scripts/run-enterprise-e2e-validation-overlay.sh --dry-run
```
