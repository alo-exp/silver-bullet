# Upstream Provenance

The initial `silver-deep-research` engine was absorbed from:

- Repository: https://github.com/199-biotechnologies/claude-deep-research-skill
- Upstream commit: `f2f2c0fa4e7617ca84c86b63f4bb40f77a746933`
- Checked: 2026-07-05

Silver Bullet adaptations:

- frontmatter and invocation route are `silver-deep-research`
- outputs are constrained to `.planning/research/<date>-<slug>/`
- `~/Documents` output is forbidden
- AF-DECIDE and `FS-SILVER_DEEP_RESEARCH` metadata are recorded in
  `run_manifest.json`
- phase-level evidence and V-loop rollups are required in `vloop-rollup.json`
- `search-cli` is optional with host search/fetch fallback
- `phases.yaml` / `phases.json` is the phase SSoT (9 DR-* phases)
- NATO Admiralty-style source grading in `source_evaluator.py` (idea-derived from hashbulla/deep-research)
- SB-owned retrieval catalogs — **no TopGun dependency**

## v2 external idea sources (not copied verbatim)

See [reference/provenance.md](reference/provenance.md) for the full ledger.

| Inspiration | SB artifact | Type |
|-------------|-------------|------|
| Socialpranker phases.yaml | `phases.yaml`, report blocks | Idea-derived |
| hashbulla NATO grading | `source_evaluator.py`, `source-grading.md` | Idea-derived |
| lingzhi227 file gates | `phase_gate.py` | Idea-derived |
| blessonism openclaw | `search_orchestrator.py`, catalogs | Idea-derived |
| hoolulu chapter factory | `report_profiles.yaml`, validate_report | Idea-derived |
| Socialpranker eval | `eval/rubric.md`, `capability_score.py` | Idea-derived |
