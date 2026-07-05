# Handoff — Context Mode vs Lean Context DECIDE

## Decision summary

Retain **Context Mode** as SB default tier-1c recommended tool. Route teams to **Lean Context** when Apache-2.0, read/wire compression, PathJail governance, or signed savings ledger are decisive requirements.

## Implementation routes

| Follow-up | SB route | Owner hint |
|-----------|----------|------------|
| Publish adjacent-tools doc pointer | `/silver:ensure-docs` | Docs |
| LeanCTX integration spike (hooks + consent) | `/silver:feature` | Platform |
| Token benchmark harness | `/silver:deep-research` (standard) | Research |
| No catalog change in this run | — | — |

## Artifacts for downstream agents

- [decision-record.md](decision-record.md) — AF-DECIDE rollup
- [research_report.md](research_report.md) — full analysis with [1]–[12] bibliography
- [claims.jsonl](claims.jsonl) — extracted claims for verification
- [triangulation.md](triangulation.md) — cross-source matrix
- [run_manifest.json](run_manifest.json) — live retrieval manifest (`ctx_fetch_and_index` fallback)

## Verification evidence

Validation logs under `validation/` from `validate_report.py`, `verify_citations.py`, `verify_claim_support.py`, and `test-silver-deep-research-integration.sh`.

## Do not

- Commit this artifact directory unless explicitly requested (user constraint for this run).
- Replace Context Mode in `.silver-bullet.json` recommended_tools without a separate ADR and hook implementation.
