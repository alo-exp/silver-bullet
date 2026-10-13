# Realistic charts + matrix pass (2026-07-21)

run_id: run-57f38dfa25d83cc50d224e283d4692f3
report: research/2026-07-20-agentic-sdlc-orchestration-landscape-multimarket-final/
evidence: research/2026-07-20-agentic-sdlc-orchestration-landscape-multimarket-final/_realistic-charts-matrix-pass/

## Decisions
- Kept `_CHART_FEAT_EQUIV = {}` (Zero-infra ≠ Managed hosting).
- features.json `supported: false` now clears chart support on merge (durable).
- Differentiated Factory/Devin/Cosmos/Tembo/Magic feature maps from SCR; cleared false Hook/Zero-infra/Free-tier clones.
- Managed hosting credited for real SaaS agents; matrix + charts regenerated.
- Notable divergences: `select_notable_divergences()` subject+Jaccard dedupe (AI-DLC×3 and Augment Cosmos dups collapsed).
- Removed phantom matrix column claude-code-expert.
- Oh My Pi differentiated from Silver Bullet (no atomic catalog / review loops).

## Verify
- file:// landscape-report.html PASS (viewer + matrix panel; SaaS y dropped off fake hook inflation; SB apo MQ y=8.8 presence=3)
- Focused tests: test_realistic_chart_scoring.py OK
- No duplicate coords; chart ⊆ listed for all markets
