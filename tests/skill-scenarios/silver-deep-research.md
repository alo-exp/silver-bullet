# Silver Deep Research Skill Scenario

## Skill: silver-deep-research
## Context: Technology evaluation

### Scenario: Evaluate SQL vs NoSQL for Todos

**Trigger:** "Should we use SQL or NoSQL for todos?"

**Workflow:**
1. Clarify criteria, scope, reversibility, and decision risk.
2. Select AF-DECIDE research mode based on need (`standard` by default, escalating to `deep` for architecture/API/data-model risk).
3. Run `FS-SILVER_DEEP_RESEARCH` with nested phase V-loops:
   - `DR-SCOPE`
   - `DR-PLAN`
   - `DR-RETRIEVE`
   - `DR-TRIANGULATE`
   - `DR-OUTLINE`
   - `DR-SYNTHESIZE`
   - optional `DR-CRITIQUE` / `DR-REFINE`
   - `DR-PACKAGE`
4. Use search-cli first when configured; otherwise record fallback provider status in `run_manifest.json`.
5. Persist `.planning/research/<date>-<slug>/research_report.md`, `decision-record.md`, `handoff.md`, `evidence.jsonl`, `claims.jsonl`, and `vloop-rollup.json`.
6. Validate citations and claim support before handoff.
