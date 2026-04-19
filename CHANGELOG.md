# Changelog

## [Unreleased]

## [0.23.0] — 2026-04-19

**plugin-dev compliance milestone.** Retroactively aligns 100% of Silver Bullet against the official Anthropic `plugin-dev` plugin standards — manifest, hooks, skills, and writing style.

### Plugin-dev Compliance (Phase 1 — Manifest & Hooks)
- **PLUGIN-01**: Added `"hooks": "./hooks/hooks.json"` field to `.claude-plugin/plugin.json` per plugin-dev `plugin-structure` standard.
- **PLUGIN-02**: Added explicit `timeout` fields to all 24 hook entries in `hooks/hooks.json` (values: 5–30s per hook criticality).
- **PLUGIN-03**: Bumped `.claude-plugin/plugin.json` version to `0.23.0`.

### plugin-dev Compliance (Phase 2 — Skill Descriptions & Versions)
- **SKILL-DESC**: Fixed 9 skill descriptions from bare "Use when..." to plugin-dev standard "This skill should be used when..." format: `ai-llm-safety`, `extensibility`, `modularity`, `reliability`, `reusability`, `scalability`, `security`, `testability`, `usability`.
- **SKILL-VER**: Added `version: 0.1.0` to YAML frontmatter of all 41 skills.

### plugin-dev Compliance (Phase 3 — Progressive Disclosure)
- **SILVER-FEATURE**: Extracted Supervision Loop detail (SL-1 → SL-6, ~400 words) to `skills/silver-feature/references/supervision-loop.md`; replaced with lean pointer. Word count: 3,049 → 2,704.
- **SILVER-INIT**: Extracted 4 heavy sections to references/scripts:
  - CI workflow YAML templates → `skills/silver-init/references/ci-templates.md` (13 stacks)
  - Doc migration procedure → `skills/silver-init/references/doc-migration.md`
  - Tech stack detection table → `skills/silver-init/references/stack-detection.md`
  - Hooks-merge Python script → `skills/silver-init/scripts/merge-hooks.py` (executable, chmod 755)
  - Word count: 6,446 → 5,419.

### plugin-dev Compliance (Phase 4 — Writing Style)
- **STYLE**: Fixed 23 second-person writing violations across 9 skills (imperative verb-first style):
  - All 7 ilities skills: `"You are NOT required to X"` → `"Not required to X"`, `"You ARE required to not make X worse"` → `"Required: do not make X worse"`, and related pronoun drops.
  - `silver-spec`: `"You MUST NOT proceed"` → `"Do NOT proceed"`.
  - `devops-skill-router`: `"You can also invoke"` → `"Also invocable"`.

### Documentation
- **CLAUDE.md**: Complete rewrite — added commands (test suite, linting, validation), full architecture reference (hook event map, two-tier enforcement, state machine, shared libraries), key invariants.

## [0.22.0] — 2026-04-18

**Backlog-resolution milestone.** Consolidates phases 34–38: security hardening,
hook-correctness fixes, consistency repairs, gitignore narrowing, and a full
public-surface refresh. Subsumes the undocumented 0.20.9 → 0.21.3 release window
into a single coherent entry. Closes issues [#14](https://github.com/alo-exp/silver-bullet/issues/14),
[#16](https://github.com/alo-exp/silver-bullet/issues/16),
[#20](https://github.com/alo-exp/silver-bullet/issues/20),
[#23](https://github.com/alo-exp/silver-bullet/issues/23).

### Security
- **SEC-01** (P34, `6cb66c5`): moved the Google Chat release-notification webhook out of `skills/silver-create-release/SKILL.md` into the `GCHAT_RELEASE_WEBHOOK` env var; added a `secret-scan` CI job that fails the build on hard-coded webhook URLs.
- **SEC-02** (P35, `e247ff3`): added `! -L` symlink guards to every hook that reads/writes state files (`stop-check.sh`, `session-start`, `completion-audit.sh`, trivial-flag touch/rm) — closes a symlink-replacement bypass on multi-user machines.
- **SEC-03** (P35, `e247ff3`): replaced hand-rolled JSON string concatenation in hook stdout with `jq -n` payloads across every hook that emits `PreToolUse`/`Stop` structured output — eliminates injection via filenames or branch names containing quotes.
- **SEC-04** (P35, `e247ff3`): batch security fixes across remaining hooks (safe `rm` patterns, `mktemp` for temp files, `set -euo pipefail` where missing).

### Fixes
- **HOOK-06** (P36, `4339060`): `stop-check.sh` no longer fails open when `.silver-bullet.json` is missing or unreadable — absent config now HARD-STOPs with a config-error message instead of silently allowing session end.
- **HOOK-07** (P36, `4339060`): closed a race in `stop-check.sh` where a concurrent `record-skill.sh` write could cause the required-skills diff to observe a stale state file; added flock around state reads on Stop.
- **HOOK-08** (P36, `4339060`): filled test coverage for the HOOK-14 trivial-session / clean-tree short-circuit paths in `stop-check.sh` (clean tree, dirty tree, trivial flag, read-only session matrix).
- **HOOK-14** carryover: `stop-check` skips enforcement for read-only sessions ([#14](https://github.com/alo-exp/silver-bullet/issues/14) via `58d98fb` / `efdaab5`).

### Consistency
- **CONS-01** (P37, `0b86dc6`): repaired broken skill references — `/gsd:silver-forensics` → `/gsd-forensics`, legacy `/silver:*` colon-form refs in SKILL.md files updated to current `/silver-*` names.
- **CONS-02** (P37, `0b86dc6`): reconciled `hooks.json` / `settings.json` schema drift; every hook entry now matches the Claude Code manifest schema and the registered hook script actually exists on disk.

### Ignore
- **IGNORE-01** (P38, this release, closes [#20](https://github.com/alo-exp/silver-bullet/issues/20)): narrowed the project `.gitignore` blanket `.claude/` rule to runtime-only subpaths (`projects/`, `local/`, `.silver-bullet/`, `settings.local.json`, `worktrees/`). Committed plugin config (`.claude/settings.json`, `.claude/commands/`) now tracked. Supersedes the interim fix in `c8b161a`.

### Docs
- **DOC-02** (P38, this release, closes [#23](https://github.com/alo-exp/silver-bullet/issues/23)): public-surface refresh across every user-visible file.
  - `README.md`: `Current version` bumped from v0.21.3 → v0.22.0 with milestone summary.
  - `site/index.html`: hero version badge v0.19.1 → v0.22.0; meta description / Twitter card skill count 39 → 41, added "18 hooks".
  - `site/help/getting-started/index.html`, `site/help/concepts/index.html`: skill count 39 → 41; version range extended to v0.22.0; added composable-flows line.
  - `docs/ARCHITECTURE.md`: design principle 2 corrected from "7 layers" → "10 layers" to match enforcement-layer count everywhere else.
  - `CHANGELOG.md`: this entry, consolidating 0.20.9–0.21.3 gap into the 0.22.0 release note.

### Tests
- Total: 1112 passed, 13 failed (2/3 suites green) — unchanged from v0.21.3 baseline. Hook coverage: 18/18.

## [0.20.8] — 2026-04-16

### Fixed
- `skills/silver-forensics/SKILL.md`: replaced 4 occurrences of non-existent `/gsd:silver-forensics` routing with correct `/gsd-forensics`. The bug caused silent agent failure when Silver Bullet tried to delegate GSD workflow issues to a command that never existed.

### Tests
- `tests/integration/test-skill-integrity.sh`: added Check 8 — regression test asserting `silver-forensics/SKILL.md` does not reference `/gsd:silver-forensics`. RED-GREEN verified.
- Total: 288 tests, 3/3 suites green.

### Docs / Planning
- Autonomous mode preference recorded in `silver-bullet.md §10e` and base template.
- `ROADMAP.md ## Backlog`: 17 deferred items (999.1–999.17) captured from forensics sweep and added for future work.
- `CHANGELOG.md`: corrected stale "972 tests" count in v0.20.6 entry to correct value (288).

## [0.20.7] — 2026-04-16

### Fixed
- `hooks/session-start`: now honours `SILVER_BULLET_STATE_FILE` env var (same pattern as `completion-audit.sh` and `stop-check.sh`), allowing tests to redirect state writes to a temp path.
- `tests/hooks/test-session-start.sh`: replaced fragile backup/restore machinery with `TMPSTATE` isolation via `SILVER_BULLET_STATE_FILE`. Running the full test suite no longer wipes the live session state file, ending the skill re-recording loop that blocked session completion after every test run.

### Tests
- Total: 288 tests, 3/3 suites green (no new tests — existing 12 session-start tests now run in full isolation)

## [0.20.6] — 2026-04-16

### Fixed
- `hooks/roadmap-freshness.sh`: new PreToolUse/Bash hook that blocks `git commit` when a phase `*-SUMMARY.md` is staged but the corresponding ROADMAP.md checkbox is not ticked (`[ ]`). Prevents autonomous execution from silently skipping the ROADMAP bookkeeping step.
- `skills/silver-feature/SKILL.md`: added explicit "TICK ROADMAP.md" step to the Per-Phase Loop so autonomous runs update the checkbox before the phase-completion commit.
- `.planning/ROADMAP.md`: ticked checkboxes for phases 23, 24, 27, 28 which were completed in the prior milestone but not updated due to the missing enforcement.

### Tests
- Total: 972 tests, 3/3 suites green (8 new tests for roadmap-freshness hook)

## [0.20.5] — 2026-04-16

### Changed
- `/silver` skill: renamed from "Smart Skill Router" to "Smart Skill Orchestrator" — better reflects its role composing and sequencing workflows rather than just dispatching
- Composable workflow building blocks renamed from "paths" to "flows" throughout: `silver-feature/SKILL.md` (20 occurrences in Composition Proposal and Supervision Loop), `silver/SKILL.md` (Composer note), `silver-bullet.md.base` §2h ("Composable Flows Catalog"), `ENFORCEMENT.md` ("composable flows mode"), `full-dev-cycle.md` both templates and docs copies

### Tests
- Total: 962 tests, 3/3 suites green

## [0.20.4] — 2026-04-16

### Changed
- All user-facing Silver Bullet skills now use the `/silver-*` naming convention: `blast-radius` → `silver-blast-radius`, `create-release` → `silver-create-release`, `forensics` → `silver-forensics`, `quality-gates` → `silver-quality-gates`. End users now see a clean `/silver-*` namespace in the Claude Code slash command menu.
- `hooks/lib/required-skills.sh`, `hooks/record-skill.sh`, `hooks/completion-audit.sh`, `hooks/stop-check.sh`, `hooks/dev-cycle-check.sh`: updated all references to use new skill names
- `.silver-bullet.json`, `templates/silver-bullet.config.json.default`: `required_planning`, `required_deploy`, and `all_tracked` arrays updated to new names
- 22 internal skills (dimension checkers, artifact reviewers, internal routing skills) marked `user-invocable: false` in SKILL.md frontmatter — hidden from Claude Code slash command menu to reduce context token overhead for end users
- README.md: all skill name references updated to new `silver-*` convention

### Tests
- Total: 962 tests, 3/3 suites green

## [0.20.3] — 2026-04-15

### Added
- `create-release` skill: Step 5 posts a Google Chat notification after publishing a release. Reads `notifications.google_chat_webhook` from `.silver-bullet.json`; silent skip if absent; warns but does not fail if `curl` errors.
- `.silver-bullet.json`: `notifications.google_chat_webhook` config key for project-local webhook URL storage.

## [0.20.2] — 2026-04-15

### Refactored
- `hooks/lib/workflow-utils.sh` (new): shared utility library — single source of truth for Flow Log row-counting regex, extracted from three hooks (TD-1)
- `completion-audit.sh`, `dev-cycle-check.sh`, `compliance-status.sh`: source shared lib with inline fallback definitions for resilience in test environments
- Fixed stale "workflow paths" terminology in `completion-audit.sh` output messages → "flows" (TD-2)

### Added
- Comprehensive skill execution path test suite: 169 tests covering sub-skill reference integrity, non-skippable gate presence, step ordering constraints, quality-gates 9-dimension completeness, and skill name consistency across all 41 orchestration skills (TD-3)

### Tests
- Total: 962 tests, 3/3 suites green (up from 793 in v0.20.0)

## [0.20.1] — 2026-04-15

### Fixed
- `compliance-status.sh` Bug-1: WORKFLOW.md flow progress (`FLOW N/M`) now shown in early-exit path (no state file) — was omitted before this fix
- `compliance-status.sh` Bug-2: Row-count regex tightened from `^\| [0-9]` to `^\| [0-9]+ \|` — Phase Iterations and Autonomous Decisions rows no longer inflate the total flow count
- Same Bug-2 regex fix applied to `completion-audit.sh` and `dev-cycle-check.sh` (same pattern, same exposure)

### Changed
- Terminology rename: "paths" → "flows" and "Composable Path Architecture" → "Composable Workflow Orchestration" project-wide (42 files)
- WORKFLOW.md sections renamed: `Path Log` → `Flow Log`, `Next Path` → `Next Flow`, `Last-path:` → `Last-flow:`
- Status output updated: `PATH N/M` → `FLOW N/M`, `PATH: N/A (legacy mode)` → `FLOW: N/A (legacy mode)`
- `dev-cycle-check.sh` stale messages updated: "All workflow paths complete" → "All flows complete", partial-progress "PATH %s/%s" → "FLOW %s/%s"

### Added
- 7-scenario integration test suite for `compliance-status.sh` WORKFLOW.md flow-progress display (S1–S7 covering early-exit, symlink, malformed, digit-row false positives, mixed counts)
- Bug-2 inflation regression tests for `completion-audit.sh` (WF3) and `dev-cycle-check.sh` (WF5)

## [0.15.3] — 2026-04-10

### Fixed — SENTINEL v2.3 Security Audit Findings
- SENTINEL-9.1: Sanitize VALIDATION.md warn_items in pr-traceability.sh — strip markdown link syntax and wrap in code fence to prevent injection into PR descriptions
- SENTINEL-3.1: Reject overly permissive src_pattern values (e.g., `.*`, `.+`, `/`) in dev-cycle-check.sh — fall back to `/src/` default
- Full SENTINEL v2.3 8-step adversarial security audit report: `SENTINEL-audit-silver-bullet-v0.15.1.md`

## [0.15.1] — 2026-04-09

### Fixed — Pre-Release QA Gate Findings
- CR-01: Resolve gh CLI at runtime in pr-traceability.sh (cross-platform, was hardcoded /opt/homebrew/bin/gh)
- CR-02: Remove --no-verify from auto-commit in pr-traceability.sh (was bypassing hook chain)
- CR-03: Validate spec_version (dotted semver) and jira_id (uppercase project key) before shell use
- WR-03: Add quote-stripping to uat-gate.sh spec-version comparison (prevents false mismatch on quoted YAML)
- WR-06: Add 'Accepted' to valid assumption status in review-spec QC-5
- WR-07: Align ingestion manifest status vocabulary (success/failed/skipped) across QC-1..5
- Idempotent awk insert in pr-traceability.sh SPEC.md Implementations (prevents duplicate entries)
- Diagnostic ERR traps in pr-traceability.sh and uat-gate.sh (was silent exit 0)
- package.json version updated to match release (was stale at 0.13.0)

## [0.15.0] — 2026-04-09

### Added — Granular Artifact Review Rounds (v0.15.0)
- Artifact reviewer framework: `skills/artifact-reviewer/SKILL.md` with
  interface contract (`reviewer-interface.md`), 2-consecutive-clean-pass
  loop (`review-loop.md`), per-artifact state tracking, and audit trail
- 8 new artifact reviewer skills: `review-spec`, `review-design`,
  `review-requirements`, `review-roadmap`, `review-context`,
  `review-research`, `review-ingestion-manifest`, `review-uat`
- Existing GSD reviewers (plan-checker, code-reviewer, verifier,
  security-auditor) formalized into the 2-pass framework via silver-bullet.md §3a
- Workflow wiring: silver-spec Steps 7a/8a/9a, silver-ingest Step 7a,
  silver-feature Step 17.0a — all NON-SKIPPABLE gates
- Post-command review gates in §3a-i for ROADMAP, REQUIREMENTS, CONTEXT, RESEARCH
- Complete artifact-reviewer mapping table in §3a (12 artifact types)

### Fixed — v0.14.0 Critical Bug Fixes
- BFIX-01: Shell injection via unvalidated owner/repo in `silver-ingest --source-url` — allowlist regex validation added
- BFIX-02: Command injection via unescaped WARN findings in `pr-traceability.sh` heredoc — replaced with `printf '%s'`
- BFIX-03: Confluence failure path now produces `[ARTIFACT MISSING: reason]` block (was buried in Assumptions)
- BFIX-04: Version mismatch block in §0/5.5 now shows content diff (was version numbers only)

## [0.14.0] — 2026-04-09

### Added — AI-Driven Spec & Multi-Repo Orchestration
- `skills/silver-spec/SKILL.md` — AI-driven Socratic elicitation skill (238 lines)
  guiding PM/BA through 9-domain requirements creation, producing SPEC.md + REQUIREMENTS.md
- `skills/silver-ingest/SKILL.md` — External artifact ingestion (428 lines) via
  JIRA (Atlassian MCP), Figma (Figma MCP), Google Docs (Workspace CLI with vision).
  Cross-repo spec fetch with version pinning. Resumable via INGESTION_MANIFEST.md
- `skills/silver-validate/SKILL.md` — Pre-build gap analysis (360 lines) with
  BLOCK/WARN/INFO findings. Hard-blocks gsd-plan-phase on BLOCK findings
- `hooks/spec-floor-check.sh` — PreToolUse hook that hard-blocks gsd-plan-phase
  without valid SPEC.md; advisory-only for gsd-fast/gsd-quick
- `hooks/spec-session-record.sh` — SessionStart hook capturing spec-id/version/JIRA ref
- `hooks/pr-traceability.sh` — PostToolUse hook auto-populating PR description with
  spec reference and updating SPEC.md Implementations section post-merge
- `hooks/uat-gate.sh` — PreToolUse hook blocking gsd-complete-milestone without UAT pass
- Canonical spec templates: `templates/specs/SPEC.md.template`, `DESIGN.md.template`,
  `REQUIREMENTS.md.template` with YAML frontmatter and standardized sections
- Multi-repo spec referencing: `silver-ingest --source-url` fetches + caches main repo
  SPEC.md with version pinning; session-start validation blocks on mismatch
- §3/§3a/§3d step non-skip enforcement: workflow steps cannot be bypassed, artifact
  existence required before phase advancement
- Spec Lifecycle section in silver-bullet.md.base
- MCP Connector Prerequisites (§2j) and Cross-Repo Conventions (§2k)

## [0.13.2] — 2026-04-09

### Fixed
- All hooks that used `set -euo pipefail` without an ERR trap now have
  `trap 'exit 0' ERR` added. Affected files: `hooks/session-start`,
  `hooks/compliance-status.sh`, `hooks/session-log-init.sh`,
  `hooks/ensure-model-routing.sh`, `hooks/semantic-compress.sh`,
  `hooks/record-skill.sh`, `hooks/ci-status-check.sh`,
  `hooks/dev-cycle-check.sh`. Prevents first-install failures from
  surfacing nonzero hook exits that cause Claude to reject the plugin.
- Restored `"hooks": "./hooks/hooks.json"` to `.claude-plugin/plugin.json`
  so the marketplace registers hooks automatically on install.

### Added
- `silver:init` Phase 3 step 3.7.5: after project scaffolding, merges SB
  hook entries from `hooks/hooks.json` into `~/.claude/settings.json` using
  `python3`. Hook commands are registered with the actual install path
  substituted for `${CLAUDE_PLUGIN_ROOT}`. Idempotent — re-running init
  does not add duplicate entries. Also runs during update mode (step 5a).

## [0.13.1] — 2026-04-09

### Changed
- Model routing overhauled: Sonnet (LOW thinking effort) is now the default for all 24 GSD agents. Opus reserved exclusively for `gsd-planner` and `gsd-security-auditor` — the only two agents where reasoning depth measurably changes outcome quality. Previous scheme asked for Opus at phase transitions; new scheme is fully automatic via agent frontmatter.
- silver-bullet.md §5 and templates/silver-bullet.md.base §5: removed interactive Opus upgrade prompts; replaced with automatic frontmatter-based routing description
- docs/workflows/full-dev-cycle.md MODEL ROUTING section updated to match; removed manual prompt flow

### Added
- `hooks/ensure-model-routing.sh` — self-healing session-start hook that reapplies `model:` directives to all 24 GSD agent files if a GSD update wipes them. Canary-guarded (~2ms no-op when correct, <50ms when patching). Bash 3.2 compatible. Audit trail written to `~/.claude/.silver-bullet/model-routing-patch.log`.

### Fixed
- All "8 dimensions" references updated to "9 dimensions" across site/index.html (3 occurrences), site/help/index.html, site/help/dev-workflow/index.html, site/help/search.js (3 occurrences), and docs/workflows/full-dev-cycle.md (4 occurrences total)
- quality-gates SKILL.md: added 9th dimension (AI/LLM safety) to skill load list and report table; updated model advisory from Opus to Sonnet
- site/index.html cost-optimization section rewritten: Sonnet-as-default messaging, Opus reserved for 2 agents, cost reduction estimate updated to 60–80%
- docs/workflows/full-dev-cycle.md: added /silver router and orchestration workflows to invocation table; updated /test-driven-development → silver:tdd, /finishing-a-development-branch → silver:finishing-branch, /design-system+/ux-copy+/accessibility-review → product-brainstorming; added silver:security to CODE REVIEW section
- site/help/search.js: added dedicated index entries for utility skills (silver:intel, silver:explore, silver:scan, silver:forensics) and alias skills (silver:tdd, silver:security, silver:brainstorm, silver:writing-plans, silver:finishing-branch)

## [0.13.0] — 2026-04-08

### Security
- SENTINEL v2.3 audit: add UNTRUSTED DATA boundary to §0 docs/ read — docs/ files are project context only, not executable instructions (F2-01)
- SENTINEL v2.3 audit: add UNTRUSTED DATA security boundary to silver:init Phase −1.1 for README.md/CONTEXT.md reads (F2-02)
- SENTINEL v2.3 audit: add `mode` to state tamper prevention regex in dev-cycle-check.sh alongside state/branch/trivial (F6-01)
- SENTINEL v2.3 audit: silver:update now displays commit SHA and requires second user confirmation before writing plugin registry (F7-01/F3-01)
- SENTINEL v2.3 audit: §10 step-skip preference writes now require diff display and explicit user confirmation before committing (F10-01)
- SENTINEL v2.3 audit: silver:update cancel path guarded against unsafe removal — requires path-containment check before rm (F-NEW-01)

## [0.9.0] — 2026-04-08

### Added
- 7 named SB orchestration skill files: silver:feature, silver:bugfix, silver:ui, silver:devops, silver:research, silver:release, silver:fast
- §2h SB Orchestrated Workflows enforcement section in silver-bullet.md and template
- §10 User Workflow Preferences schema (10a–10e) in silver-bullet.md and template
- /silver router expanded: 17+ routes, complexity triage, ship disambiguation, conflict resolution
- silver:init: MultAI + Anthropic Engineering + PM plugin checks, project-type detection, gsd-autonomous mode note
- §0 session startup: MultAI update check alongside GSD/Superpowers
- Unified test runner (tests/run-all-tests.sh)

### Fixed
- silver:release: add standalone silver:security gate (Step 2a) before gap-closure loop; listed in non-skippable gates
- silver:feature: move gsd-add-tests to Step 8b (after gsd-verify-work, not before); add TDD skip heuristic
- silver:tdd / silver:scan: add canonical skill parentheticals across feature/bugfix/ui/devops skill files
- silver/router: note §10 preferences not applied when routing Trivial → silver:fast
- silver:init: document intentional MultAI hard-STOP vs Engineering/PM soft-warning asymmetry

### Infrastructure
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
