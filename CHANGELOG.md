# Changelog

## [Unreleased]

### New: Semantic context compression

- New PostToolUse hook (`hooks/semantic-compress.sh`) that fires on GSD phase transitions and injects ranked context into the next prompt via `hookSpecificOutput.additionalContext`
- TF-IDF ranking of source and doc file chunks against the active phase goal — highest-relevance chunks are injected, lowest are dropped, keeping context tight
- Pure shell implementation (awk + sort) — no external dependencies beyond standard POSIX tools
- Cache-backed: MD5 hash of file mtimes + phase goal used as cache key; repeated calls within the same phase are instant
- Source files prioritised over doc files in ranking; configurable score weighting
- Configurable via `.silver-bullet.json` `semantic_compression` block (enable/disable, chunk size, max chunks injected, min score threshold, include/exclude globs)
- New scripts: `scripts/extract-phase-goal.sh`, `scripts/tfidf-rank.sh`, `scripts/semantic-compress.sh`
- 31 tests across 5 test suites covering TF-IDF scoring, caching, phase-goal extraction, hook wiring, and end-to-end integration

## 0.2.0 (2026-04-01)

### Major: GSD integration as primary execution engine
- GSD (get-shit-done) is now the primary skill set — fresh 200K-token context per agent, wave-based parallel execution, dependency graphs, atomic per-task commits
- Workflows restructured: GSD commands drive DISCUSS → PLAN → EXECUTE → VERIFY; Silver Bullet skills fill gaps (quality gates, code review, testing, docs, deploy)
- 8 individual quality gate skills collapsed into `/quality-gates` aggregate (individual files kept for modularity)

### New: DevOps workflow
- `devops-cycle.md` — 23-step workflow for infrastructure/DevOps work
- `/blast-radius` skill — pre-change risk analysis with LOW/MEDIUM/HIGH/CRITICAL gate
- `/devops-quality-gates` skill — 7 IaC-adapted quality dimensions (usability excluded)
- Incident fast path for emergency production changes
- Environment promotion section (dev → staging → prod)
- `.yml`/`.yaml` files enforced as infrastructure code in devops-cycle

### New: Design plugin dependency
- Design plugin (anthropics/knowledge-work-plugins/design) added as required dependency
- Session-start hook injects Design plugin context alongside Superpowers

### New: Project type detection
- `/using-silver-bullet` Phase 2.6 asks application vs DevOps/infrastructure
- Sets `active_workflow` in config to `full-dev-cycle` or `devops-cycle`

### New: DevOps plugin integration
- `/devops-skill-router` skill — context-aware routing table mapping IaC toolchain + cloud provider to the best available plugin skill with fallback chains
- 5 optional DevOps plugins supported: hashicorp/agent-skills, awslabs/agent-plugins, pulumi/agent-skills, ahmedasmar/devops-claude-skills, wshobson/agents
- `/using-silver-bullet` Phase 2.7 auto-detects which DevOps plugins are installed
- `devops-cycle.md` contextual enrichment trigger points at DISCUSS, PLAN, EXECUTE, VERIFY, FINALIZATION
- `devops_plugins` section added to config for tracking installed plugins

### Hook updates
- All hooks updated to align with GSD-integrated workflow
- `record-skill.sh` — tracked skills list updated (removed GSD-replaced skills, added new skills)
- `dev-cycle-check.sh` — reads `active_workflow` from config; YAML files not auto-exempted in devops-cycle
- `compliance-status.sh` — phases updated: removed EXECUTION (now GSD), updated REVIEW and FINALIZATION skill lists
- `completion-audit.sh` — required deploy skills updated to match new workflow
- `deploy-gate-snippet.sh` — default required deploy skills updated

### Updated
- `full-dev-cycle.md` rewritten as 19-step GSD-primary workflow (down from 31)
- `CLAUDE.md.base` updated: 7 enforcement layers, trivial-change note clarifies DevOps YAML exception
- `silver-bullet.config.json.default` updated to v0.2.0 with new skill lists
- README rewritten for four-plugin ecosystem, two workflows, seven enforcement layers
- `plugin.json` updated to v0.2.0

## 0.1.0 (2026-03-31)

- Initial release
- Full dev cycle workflow (31-step enforced process)
- 8 quality-ility skills enforced during planning:
  - `/modularity` — file size limits, single responsibility, change locality
  - `/reusability` — DRY, composable components, Rule of Three
  - `/scalability` — stateless design, efficient data access, async processing
  - `/security` — OWASP top 10, input validation, secrets management, defense in depth
  - `/reliability` — fault tolerance, retries with backoff, circuit breakers, graceful degradation
  - `/usability` — intuitive APIs, actionable errors, progressive disclosure, accessibility
  - `/testability` — dependency injection, pure functions, test seams, deterministic behavior
  - `/extensibility` — open-closed principle, plugin architecture, versioned interfaces
- Six-layer compliance enforcement system
- `/using-silver-bullet` setup skill
- Superpowers + Engineering plugin dependency management
