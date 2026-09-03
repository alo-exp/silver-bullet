# Validation Overlay Results — 2026-06-29 (outcome-only registry)

**Run:** Enterprise E2E validation overlay (outcome claims) + pre-release overlay (feature claims)  
**SB repo:** `/Users/shafqat/projects/silver-bullet/repo` @ `main`  
**Matrix driver:** Not disturbed — overlay ran alongside active matrix (no pkill)

---

## Summary

| Mode | Pass | Fail | Skip | Exit |
|------|------|------|------|------|
| Validation `--dry-run` (outcome only) | 6 | 0 | 0 | 0 |
| Pre-release `--dry-run` (feature claims) | 40+ | 0 | 0 | 0 |
| Tri-host smoke (Codex + Cursor CI) | 9 structural | 0 | 0 | 0 |
| Structural test suite | 21 | 0 | 0 | 0 |

**Verdict:** Validation overlay **GREEN** for outcome tier (5 gate claims + V-02 telemetry). Feature claims moved to pre-release registry and overlay.

---

## Validation outcome claims (6 total, 5 gate)

| claim_id | text (abbrev) | tier |
|----------|---------------|------|
| `hero-evidence-gates` | blocks unsafe commits, PRs, and releases | matrix_overlay |
| `hero-capabilities` | Engineering Best Practices | matrix_overlay |
| `hero-free-no-telemetry` | 100% Free Forever | contract |
| `help-ship-readiness` | ship-readiness evidence gates | matrix_overlay |
| `first-hour-block-pr` | first session blocks unsafe PR | live/backlog V-01 |
| `hero-reliability-cost` | at 10x Lower Cost | telemetry_only V-02 |

**Removed from validation:** `hero-apo-title`, `hero-tri-host`, `help-tri-host`, `help-router-workflow` + 9 demoted feature claims → `pre-release-claims-registry.json`.

---

## Validation dry-run checks (6 pass)

- Validation registry: 5 outcome gate claims, 1 backlog, V-02 telemetry_only
- Homepage evidence-gates outcome copy present
- Help ship-readiness page exists
- `claims-audit.sh` green

---

## Pre-release feature overlay (representative)

- Pre-release registry: 13 feature claims + tri-host smoke wiring
- APO catalog: 22 workflows, 27 atomic flows
- Help version sync, workflow coverage, catalog SOT, tri-host mentions
- Tri-host install scripts + cursor-hook-bridge
- Hook surface, sb-diagnostics, apo invariants
- Router help page exists

---

## Tri-host install smoke

| Host | Script | CI |
|------|--------|-----|
| Codex | `scripts/run-tri-host-install-smoke.sh --host codex` | ✅ |
| Cursor | `scripts/run-tri-host-install-smoke.sh --host cursor` | ✅ |
| Claude | `scripts/run-tri-host-install-smoke.sh --host claude` | SKIP when CLI absent |

Per host: install → `sb-diagnostics.sh` → `claims-audit.sh` + `check-apo-invariants.py`.

---

## Commands used

```bash
RTK_DISABLED=1 bash scripts/run-enterprise-e2e-validation-overlay.sh --dry-run
RTK_DISABLED=1 bash scripts/run-enterprise-e2e-pre-release-overlay.sh --dry-run
bash tests/enterprise-e2e-live/test-enterprise-e2e-validation-overlay.sh
bash tests/scripts/test-tri-host-install-smoke.sh
```

---

## Recommended next steps

1. Run tri-host smoke with Claude CLI before major tag (`--host claude` or full `run-tri-host-install-smoke.sh`).
2. Complete Round 3 matrix rows 11, 14–16; re-run validation `--live` overlay for outcome claims.
3. Pre-release gate Stage 4b now includes pre-release overlay + tri-host smoke per `docs/internal/pre-release-quality-gate.md`.
