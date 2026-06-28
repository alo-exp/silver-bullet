# Validation Overlay Results — 2026-06-29

**Run:** Enterprise E2E validation overlay (dry-run + live ledger overlay)  
**SB repo:** `/Users/shafqat/projects/silver-bullet/repo` @ `main` (pre-commit)  
**Matrix driver:** Not disturbed — overlay ran alongside active matrix (no pkill)

---

## Summary

| Mode | Pass | Fail | Skip | Exit |
|------|------|------|------|------|
| `--dry-run` (structural + contract) | 40 | 0 | 0 | 0 |
| `--live` + `ROUND-3-LEDGER.md` | 43 | 0 | 4 | 0 |
| Structural test suite | 14 | 0 | 0 | 0 |

**Verdict:** Validation overlay **GREEN** for structural/contract tier. Matrix-linked claims **partially satisfied** per Round 3 ledger (rows 11, 14–16 not Pass).

---

## Dry-run checks (40 pass)

- Validation registry: 15 claims, 2 backlog items documented
- APO catalog: 22 workflows, 27 atomic flows
- Help version sync: `0.48.6` == `package.json`
- Help workflow coverage: all user-facing WFs have pages; internal WFs (`WF-POST-EXEC-GATES`, `WF-VALIDATE-SUBSTEP`) correctly optional
- Help SOT + tri-host mentions
- Tri-host install scripts + `hooks/cursor-hook-bridge.sh`
- Hook surface: 57 top-level hook scripts
- `sb-diagnostics.sh` executable
- `claims-audit.sh` green
- `check-apo-invariants.py site-doc-freshness` green
- `check-apo-invariants.py apo-hierarchy-integrity` green

---

## Live overlay (Round 3 ledger)

| Matrix row | Linked claims | Ledger status | Overlay |
|------------|---------------|---------------|---------|
| 1 | router / APO | Pass | PASS |
| 3 | evidence gates | Pass | PASS |
| 6 | fast path | Pass | PASS |
| 11 | devops | Not Pass | SKIP |
| 14 | release gates | Not Pass | SKIP |
| 15 | review triad | Not Pass | SKIP |
| 16 | ship-readiness | Not Pass | SKIP |

---

## Top gaps (backlog — not overlay failures)

| ID | Gap | Severity | Owner |
|----|-----|----------|-------|
| V-01 | First-hour unsafe PR block — no timed onboarding SLO | P1 | E2E / onboarding fixture |
| V-02 | 10× lower cost — **excluded from validation gates**; token telemetry only | — | Telemetry JSONL (§10 validation plan) |
| V-03 | Codex/Cursor 5-row smoke — Claude-only matrix | P1 | Tri-host E2E |
| V-04 | Round 3 rows 11, 14–16 incomplete — outcome claims deferred | P0 matrix | Operator / harness |
| V-05 | Monitor↔ledger drift (Round 3) | P0 measurement | Harness P0-1 |

---

## Commands used

```bash
RTK_DISABLED=1 bash scripts/run-enterprise-e2e-validation-overlay.sh --dry-run
SB_E2E_LEDGER_FILE=.planning/enterprise-e2e/ROUND-3-LEDGER.md \
  RTK_DISABLED=1 bash scripts/run-enterprise-e2e-validation-overlay.sh --live
bash tests/enterprise-e2e-live/test-enterprise-e2e-validation-overlay.sh
```

---

## Recommended next steps (parent orchestrator)

1. **Complete Round 3 matrix** rows 11, 14–16; re-run `--live` overlay.
2. **Wire overlay into round gate** — require dry-run green before matrix resume; `--live` after round.
3. **Set `SB_E2E_RCS_VALIDATION_OVERLAY=pass`** when overlay dry-run green for RCS advisory boost.
4. **Schedule V-01/V-03** as separate epics; do not block matrix on marketing SLO gaps. **V-02** is telemetry-only (excluded from overlay gates).
5. **Fix P0-1 ledger↔monitor** from effectiveness plan — independent of validation copy checks.
