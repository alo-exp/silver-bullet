# silver-content Scenario

## Purpose

Validate SB-owned content, migration, search-readiness, optimization, and article-writing workflow.

## Expected Behavior

- Writes `.planning/CONTENT.md`.
- Applies `sb:domain-audit --pack content-search`.
- Classifies edits into safe, moderate, and high-risk tiers.
- Runs available build, link, metadata, or browser checks.
- Routes governed docs changes through `sb:ensure-docs`.
