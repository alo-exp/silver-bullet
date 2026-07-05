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
