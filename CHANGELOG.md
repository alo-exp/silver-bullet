# Changelog

## [Unreleased]

## [0.9.0] — 2026-04-08

### Added
- 7 named SB orchestration skill files: silver:feature, silver:bugfix, silver:ui, silver:devops, silver:research, silver:release, silver:fast
- §2h SB Orchestrated Workflows enforcement section in silver-bullet.md and template
- §10 User Workflow Preferences schema (10a–10e) in silver-bullet.md and template
- /silver router expanded: 17+ routes, complexity triage, ship disambiguation, conflict resolution
- silver:init: MultAI + Anthropic Engineering + PM plugin checks, project-type detection, gsd-autonomous mode note
- §0 session startup: MultAI update check alongside GSD/Superpowers
- Comprehensive enforcement test harness: 191 tests, 12/12 hooks covered, 3 test suites
- Phase 9: silver:init initializes GSD+Superpowers with version freshness, lettered option prompts throughout
- Unified test runner (tests/run-all-tests.sh) + hook coverage matrix

### Fixed
- All 16 enforcement audit gaps from adversarial audit (F-01 through F-20)
- PreToolUse blocking with permissionDecision:deny for enforcement hooks
- Stage falsification prevention and quality gate stage ordering
- Review loop pass markers for Tier 2 delivery enforcement

### Infrastructure
- 191 automated integration tests across 6 test files
- Hook coverage matrix verifying all hooks have test coverage
- GSD state delegation: SB reads .planning/STATE.md instead of maintaining own state

## 0.12.1 (2026-04-07)

### Added
- `/silver:update` skill — one-command plugin updater: checks GitHub for latest release, shows changelog diff, confirms, clones new version into cache, and updates plugin registry

### Fixed
- `/silver` skill: removed unsupported `allowed-tools` frontmatter field that prevented the skill from loading in Claude Desktop
- Architecture section: 10th enforcement layer card now flows in 2-column grid (removed erroneous `grid-column:1/-1`)

## 0.12.0 (2026-04-07)

### Added
- `/silver` router skill — freeform dispatcher that routes natural language to the right Silver Bullet or GSD skill; delegates GSD intent to `/gsd:do` automatically
- Ten-layer enforcement model now fully documented in `silver-bullet.md` section 1 (Stop hook, UserPromptSubmit reminder, and Forbidden skill gate layers were previously undocumented)

### Changed
- Renamed `/using-silver-bullet` skill to `/silver:init` — shorter namespaced name consistent with the `/silver:*` namespace; project-wide update across all docs, site, help center, README, and hooks

### Fixed
- `record-skill.sh`: greedy namespace stripping loop (mirrors `forbidden-skill-check.sh`) — double-namespaced invocations (e.g., `outer:inner:quality-gates`) were silently untracked (SENTINEL S6-001)
- `silver-bullet.md` section 1: enforcement layer count corrected from 7 to 10; Stop hook, UserPromptSubmit reminder, and Forbidden skill gate now listed explicitly
- `site/index.html`: all enforcement layer count references corrected from 7 to 10; architecture section updated with three missing layer cards
- `site/compare/index.html`: enforcement layer count corrected from 7 to 10

### Tech Debt
- `hooks/lib/required-skills.sh`: extracted `DEFAULT_REQUIRED` as single source of truth; sourced by `stop-check.sh`, `completion-audit.sh`, `prompt-reminder.sh` with inline fallback (TD-01)
- `stop-check.sh`: extracted `check_quality_gate_stages()` as testable pure function (TD-04)
- `templates/silver-bullet.config.json.default`: added `config_version` field (TD-07)
- Added 4 new tests: double-namespace bypass (forbidden-skill), main-branch filter (prompt-reminder), path traversal defense (prompt-reminder), double-namespace record (record-skill)

## 0.11.0 (2026-04-06)

### Added
- Stop hook (`stop-check.sh`) — blocks Claude from declaring task complete when required skills are missing; fires on `Stop` and `SubagentStop` events, survives compaction
- UserPromptSubmit hook (`prompt-reminder.sh`) — re-injects missing-skill list and core enforcement rules before every user message
- Forbidden skill gate (`forbidden-skill-check.sh`) — PreToolUse hook blocks deprecated/forbidden skills before they execute; configurable via `skills.forbidden` in `.silver-bullet.json`
- Review-loop proxy enforcement — `review-loop-pass-1`/`review-loop-pass-2` markers tracked in stop-check and completion-audit as proxy for F-01 compliance
- Stage ordering validation — prevents falsifying stage sequence (e.g. recording stage-3 before stage-2)
- Automatic model switching — agent definitions route to optimal Claude model tier (Sonnet/Haiku/Opus) based on task type
- 183-test comprehensive E2E harness (`tests/run-all-tests.sh`) — 129 unit tests + 54 integration scenario tests with 100% hook coverage

### Fixed
- 16 enforcement gaps closed from post-v0.10.0 audit: branch mismatch warning, plugin cache write blocking, scripting language bypass prevention, generalized tamper regex, destructive command warning, `gh pr merge` delivery gate, completion-audit missing `exit 0` (double-JSON bug), state JSON injection via stored branch name
- `DEFAULT_REQUIRED` skill list synchronized across `stop-check.sh`, `completion-audit.sh`, and `prompt-reminder.sh`
- `forbidden` key documented in `silver-bullet.config.json.default`

### Changed
- Enforcement layer count: 7 → 10 (Stop hook, UserPromptSubmit reminder, forbidden-skill gate added)

## 0.6.2 (2026-04-04)

### Fixed
- Enforcement layer count aligned to 7 across all surfaces (README, landing page, concepts page, compare page, search index, SENTINEL audit)
- Step counts 19/23 → 20/24 on landing page hero pills, workflow tabs, and compare page
- Landing page workflow tables completed: added missing step 20 (/create-release) for dev cycle and steps 22-24 for DevOps cycle
- Landing page layer cards now match CLAUDE.md canonical 7-layer list (was missing Skill Tracker, had Stage Enforcer split into two)
- Layer ordering aligned to CLAUDE.md canonical sequence across concepts page, search index, and README
- PreToolUse → PostToolUse in landing page HARD STOP gate description
- Broken relative link in compare page footer (help/ → ../help/)
- Stale /tmp/ references in help reference page, search index, and silver:init skill
- Test files updated from /tmp/.silver-bullet-* to ~/.claude/.silver-bullet/ paths
- session-log-init sentinel subshell fully detached from pipeline (fixes test hangs)
- session-log-init grep pattern updated to match new mode file path
- SENTINEL audit doc updated: 8→7 layers, post-remediation note added
- context.md updated: stale step counts, version, and branding
- Missing Required badge on step 9 (/requesting-code-review) in dev cycle table
- Stale worktree .claude/worktrees/agent-ad2bff3d removed
- mkdir -p defense-in-depth added to completion-audit.sh
- Plugin boundary check changed from substring grep to prefix match

## 0.6.1 (2026-04-03)

### Fix: Comprehensive cross-file consistency audit
- Regenerated `.silver-bullet.json` from v0.2.0 template (was stuck at v0.1.0 with 13 obsolete skill names)
- Synced `CLAUDE.md` with `templates/CLAUDE.md.base` (7 enforcement layers, GSD/Superpowers ownership rules, file safety rules)
- Updated all 8 quality dimension skills (`modularity`, `reusability`, `scalability`, `security`, `reliability`, `usability`, `testability`, `extensibility`) from Superpowers-era references to GSD terminology
- Updated `forensics` skill reference from `superpowers:systematic-debugging` to `/gsd:debug`

### Enhanced: DevOps workflow parity
- Added Step 0 (SESSION MODE) to `devops-cycle.md` with pre-answer template
- Added SKILL DISCOVERY section with DevOps-specific examples
- Added MODEL ROUTING section before DISCUSS phase
- Added post-plan skill gap check to Step 6
- Added forensics failure protocol to Step 8 verification
- Added KNOWLEDGE.md, CHANGELOG.md, and session log to Step 18 finalization
- Added worktree isolation rule for docs agents to Step 18
- Added autonomous completion cleanup after Step 24

### Fix: Help site completeness
- Added DevOps Step 0, code review, and skill discovery sections to help page
- Added dev-workflow init (Steps 1–2) and post-review (Steps 11–12) to search index
- Added DevOps Step 0 and code review search entries
- Fixed duplicate `hooks` anchor for trivial-changes section in concepts page
- Added `whats-next` search entry for getting-started page

### Fix: Hook and config alignment
- Reordered `finalization_skills` in `dev-cycle-check.sh` to match `compliance-status.sh` and `completion-audit.sh`
- Bumped `plugin.json` and `package.json` descriptions to "20-step (app) and 24-step (DevOps)"
- Fixed `CHANGELOG.md` DevOps step count from 23 to 24

## 0.6.0 (2026-04-03)

### Fix: `/create-release` skill rename (critical)
- Renamed `skills/release-notes/` → `skills/create-release/` to fix naming collision with Claude Code 2.1.3's built-in `/release-notes` command, which was hijacking invocations and showing Claude Code's own changelog instead of Silver Bullet's release skill
- Updated 16+ references across hooks, workflows, templates, config files, README, CLAUDE.md, and all help site pages

### Enhanced: Review loop enforcement — double approval required
- Review loops (spec review, plan review, code review, verification) must now iterate until the reviewer returns ✅ Approved **twice in a row** — a single clean pass is no longer sufficient
- Completely self-limiting: loop ends naturally on two consecutive clean passes; maximum iteration cap removed
- Updated `CLAUDE.md`, `templates/CLAUDE.md.base`, `docs/workflows/full-dev-cycle.md`, `templates/workflows/*.md`, and help site

### Enhanced: CI gate hook is now blocking
- `hooks/ci-status-check.sh` now emits `blockToolUse: true` on CI failure — Claude must stop all other work immediately and invoke `/gsd:debug`
- Previously emitted only an advisory warning that could be ignored

### Enhanced: Expanded CI stack detection in `/silver:init`
- Detects and generates CI workflow templates for 8 additional stacks: Java/Maven, Java/Gradle, Ruby/RSpec, PHP/Composer, .NET/C#, Elixir/Mix, Swift, Dart/Flutter
- Go template updated to use `go-version: stable`

## 0.5.0 (2026-04-03)

### New: Semantic context compression
- New PostToolUse hook (`hooks/semantic-compress.sh`) that fires on GSD phase transitions and injects ranked context into the next prompt via `hookSpecificOutput.additionalContext`
- TF-IDF ranking of source and doc file chunks against the active phase goal — highest-relevance chunks are injected, lowest are dropped, keeping context tight
- Pure shell implementation (awk + sort) — no external dependencies beyond standard POSIX tools
- Cache-backed: MD5 hash of file mtimes + phase goal used as cache key; repeated calls within the same phase are instant
- Source files prioritised over doc files in ranking; configurable score weighting
- Configurable via `.silver-bullet.json` `semantic_compression` block (enable/disable, chunk size, max chunks injected, min score threshold, include/exclude globs)
- New scripts: `scripts/extract-phase-goal.sh`, `scripts/tfidf-rank.sh`, `scripts/semantic-compress.sh`
- 31 tests across 5 test suites covering TF-IDF scoring, caching, phase-goal extraction, hook wiring, and end-to-end integration

### New: Help site
- Full documentation site at sb.alolabs.dev — Getting Started, Core Concepts, Dev Workflow, DevOps Workflow, Command Reference
- Full-text search across all help content (TF-IDF JS index, ~50 entries)
- Nav search on all sub-pages
- Dark mode support

### Fixes
- Enforcement count corrected: 8 total enforcement points (Silver Bullet installs 6, GSD adds 2) — was described as 7
- DevOps quality gates dimension count: 7 IaC-adapted (usability excluded) — was incorrectly described as 8 in some places
- GSD install command updated to `npx get-shit-done-cc@^1.30.0` in all documentation
- README: hooks architecture updated to document all 9 hooks (4 enforcement + 4 support + session-start)
- README: Built-in skills table now lists all 7 Silver Bullet skills (was 3)
- Help reference: clarified which skills are Silver Bullet's own vs. from Superpowers/Engineering plugins

## 0.2.0 (2026-04-01)

### Major: GSD integration as primary execution engine
- GSD (get-shit-done) is now the primary skill set — fresh 200K-token context per agent, wave-based parallel execution, dependency graphs, atomic per-task commits
- Workflows restructured: GSD commands drive DISCUSS → PLAN → EXECUTE → VERIFY; Silver Bullet skills fill gaps (quality gates, code review, testing, docs, deploy)
- 8 individual quality gate skills collapsed into `/quality-gates` aggregate (individual files kept for modularity)

### New: DevOps workflow
- `devops-cycle.md` — 24-step workflow for infrastructure/DevOps work
- `/blast-radius` skill — pre-change risk analysis with LOW/MEDIUM/HIGH/CRITICAL gate
- `/devops-quality-gates` skill — 7 IaC-adapted quality dimensions (usability excluded)
- Incident fast path for emergency production changes
- Environment promotion section (dev → staging → prod)
- `.yml`/`.yaml` files enforced as infrastructure code in devops-cycle

### New: Design plugin dependency
- Design plugin (anthropics/knowledge-work-plugins/design) added as required dependency
- Session-start hook injects Design plugin context alongside Superpowers

### New: Project type detection
- `/silver:init` Phase 2.6 asks application vs DevOps/infrastructure
- Sets `active_workflow` in config to `full-dev-cycle` or `devops-cycle`

### New: DevOps plugin integration
- `/devops-skill-router` skill — context-aware routing table mapping IaC toolchain + cloud provider to the best available plugin skill with fallback chains
- 5 optional DevOps plugins supported: hashicorp/agent-skills, awslabs/agent-plugins, pulumi/agent-skills, ahmedasmar/devops-claude-skills, wshobson/agents
- `/silver:init` Phase 2.7 auto-detects which DevOps plugins are installed
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
- `/silver:init` setup skill
- Superpowers + Engineering plugin dependency management
