# Round Codex-1 — Gate checklist

**Host:** Codex TUI  
**Updated:** YYYY-MM-DDTHH:MMZ  
**SB HEAD:** `<sha>`  
**Test app HEAD:** `<sha>`  
**Ledger:** [ROUND-CODEX-1-LEDGER.md](./ROUND-CODEX-1-LEDGER.md)  
**Prompt:** [CODEX-ENTERPRISE-E2E-EXECUTION-PROMPT.md](./CODEX-ENTERPRISE-E2E-EXECUTION-PROMPT.md)

## Status: PENDING

**Release pair:** Round Codex-1 is **1 of 2** required consecutive strict-clean rounds. Do **not** release after Codex-1 alone.

### Baseline (strict clean)

| Metric | Value |
|--------|-------|
| Issues baseline IDs | **76** unique (E2E-001 … E2E-085) |
| New issues allowed for clean round | **0** |
| Ladder | ___ / 8 |
| Matrix | ___ / 22 |

### Round gates

| Gate | Status |
|------|--------|
| review-fix-ladder 8/8 (2× clean verify per rung) | **PENDING** |
| Matrix ledger 22/22 (zero new friction) | **PENDING** |
| Outcome assessment harness (`test-outcome-assessment.sh`) | **PENDING** |
| All outcome criteria + blocking autonomy gates | **PENDING** |
| `run-all-tests` | **PENDING** |
| Validation overlay | **PENDING** |
| Pre-release overlay | **PENDING** |
| Ledger reconcile | **PENDING** |
| RCS ≥ 85 (`SB_E2E_RCS_TRIHOST=full`) | **PENDING** |
| New issues vs baseline | **PENDING** |
| Round strict-clean | **PENDING** |
| **2 consecutive strict clean rounds** | **PENDING (1/2)** — complete Codex-2 after Codex-1 Pass |

## Release verdict

**Round Codex-1:** pending strict-clean. On Pass → start [ROUND-CODEX-2-LEDGER.md](./ROUND-CODEX-2-LEDGER.md) + [ROUND-CODEX-2-GATES.md](./ROUND-CODEX-2-GATES.md).
