# scripts/

Every executable in `scripts/`, grouped by purpose. Each file's header comment has the details and usage. Installed hooks and skills call many of these by path through the plugin root (`${CLAUDE_PLUGIN_ROOT}/scripts/...`), so do not move or rename a script without updating every caller; `tests/docs/test-doc-facts.sh` checks that this page lists every top-level script and no missing ones.

## Runtime CLI and workflow helpers

Called by skills and hooks while Silver Bullet runs in a project.

| Script | Purpose |
|--------|---------|
| `silver-bullet` | Runtime CLI; `silver-bullet invoke-skill <name>` records a skill invocation on hosts without a recordable Skill tool (Codex) |
| `workflows.sh` | Composed-workflow lifecycle helper for `.planning/workflows/<id>.md` |
| `verify-tests.sh` | The `verify-tests` gate: runs `verify_commands` or stack defaults, then writes the freshness marker |
| `semantic-compress.sh`, `tfidf-rank.sh` | Assemble a ranked context summary for the current phase goal (TF-IDF chunk ranking) |
| `extract-phase-goal.sh` | Print the current phase goal from `.planning/` |
| `stamp-interface-state.sh` | Create `.planning/interface/STATE.md` from its template |
| `silver-add.sh` | Fingerprint, dedupe and file findings for `sb:add` (local, GitHub or custom tracker) |
| `silver-scan.sh`, `silver-scan.py` | `sb:scan` engine: scan, file, record and reject deferred items |
| `resolve-instruction-ledger.sh` | Sanctioned writer for instruction-ledger leaf status (direct edits are blocked) |
| `review-fix-ladder.py`, `_review_fix_ladder_impl.py` | Resolve host-aware model/reasoning rungs for `sb:review-fix-ladder` |
| `rfl-assert-advance.sh` | Fail closed when the active review-fix-ladder run lacks Policy C or sibling artifacts |
| `deploy-gate-snippet.sh` | Deploy gate snippet for project CI/deploy scripts; keeps a fallback `REQUIRED_DEPLOY` list CI compares with the template |

## Install, setup and tool stack

| Script | Purpose |
|--------|---------|
| `install-claude.sh`, `install-codex.sh`, `install-cursor.sh` | Install or refresh Silver Bullet for one host (from this checkout, or `--public-release` from the marketplace) |
| `install-cursor-sb-agents.sh` | Install SB-managed Cursor subagents (`sb-*`) for review and verify ladders |
| `install-global-toolstack.sh` | Install host-global Cursor toolstack hooks, rules and MCP config |
| `install-recommended-tools-cursor.sh`, `install-recommended-tools-global.sh` | Always-on rules / instruction artifacts for the recommended tools |
| `reconcile-recommended-tools.sh` | Canonical five-tool reconciliation engine (Graphify, agentmemory, Context Mode, LeanCTX, RTK) |
| `install-leanctx-sb.sh` | Host-aware LeanCTX install in library mode |
| `optimize-five-tool-stack.sh`, `optimize-rtk-context-mode.sh` | Apply the five-tool routed profile, or the RTK + Context Mode host optimization |
| `enable-alumnium.sh`, `enable-rtk-context-mode.sh` | Verify Alumnium, RTK and Context Mode install and wiring |
| `graphify-am-global-setup.sh`, `sb-optimize-stack.sh`, `sb-verify-synergy.sh` | Graphify + agentmemory global setup, optimization and synergy audit (`--write-setup-report` writes `SETUP_REPORT.md`) |
| `install-omniroute-launchagent.sh` | macOS LaunchAgent for the OmniRoute proxy |
| `start-minimax-openai-proxy.sh`, `minimax-openai-proxy.mjs` | Local proxy that fixes MiniMax responses for Alumnium |
| `prune-stale-claude-user-hooks.sh` | Remove user-level Claude hooks that point at missing scripts |

## Diagnostics and migration

| Script | Purpose |
|--------|---------|
| `sb-bootstrap.sh` | Onboarding probe with next steps |
| `sb-diagnostics.sh` | Capability tier, hook config, jq, Graphify, package version (`SB_DIAG_FORMAT=json`) |
| `sb-doctor.sh` | Install and project-activation audit behind `/sb:doctor` (`--deep`, `--dry-run`, `--fix=...`) |
| `sb-prerequisite-repair.sh` | Automatic prerequisite repair, called from `session-start` |
| `sb-migrate-config.sh`, `sb-migrate-initiated.sh`, `sb-migrate-orchestrator-parent.sh`, `sb-migrate-project.sh` | Merge `.silver-bullet.json` forward and migrate legacy projects |
| `diagnose-cursor-picker-duplicates.sh`, `enumerate-cursor-slash-picker.sh` | Inspect what Cursor's slash picker would register |

## Sync, render and generate

| Script | Purpose |
|--------|---------|
| `sync-codex-package.sh` | Render `skills/` into `agents/claude/`, `host-bundles/{codex,cursor}/` and `plugins/silver-bullet/skill-source/`, refresh the package symlinks and template mirror |
| `render-agent-bundle.py` | The per-host skill renderer used by the sync scripts |
| `sync-cursor-package.sh` | Refresh the Cursor package surface (`cursor-hooks.json`, commands, manifest) |
| `sync-templates.sh`, `codex-sanitize-package.sh` | Mirror `templates/` into `plugins/silver-bullet/templates/` and expand runtime placeholders |
| `sync-runtime-mirrors.sh` | Mirror listed runtime scripts and hooks into the plugin package (`--check` for drift) |
| `generate-plugin-commands.sh` | Generate `plugins/silver-bullet/commands/` stubs from composer skill frontmatter |
| `generate-cursor-hooks.py` | Generate `hooks/cursor-hooks.json` from `hooks/hooks.json` |
| `generate-hook-reference.py` | Generate `docs/HOOKS.md` from `hooks/hooks.json` (`--check` for freshness) |
| `generate-apo-artifacts.py`, `generate-apo-catalog.py` | Generate the catalog views from `docs/apo-catalog.json`, and catalog data |
| `generate-sentinel-skills-manifest.sh` | Scaffold the SENTINEL per-skill audit manifest |
| `apply-site-chrome.py` | Rewrite every site page's nav and footer from `site/_chrome/` (edits files in place; no options) |
| `regenerate-site-certification-status.sh` | Regenerate the certification JSON mirrored on the site |

## Validate and audit

| Script | Purpose |
|--------|---------|
| `lint-shell.sh` | ShellCheck over all first-party Bash (`--all`, `--list`); used by `make lint` and CI |
| `validate-plugin-mirror.sh` | The plugin package mirrors source hooks and skills |
| `validate-host-agnostic-core.sh`, `validate-host-install-surface.sh`, `validate-host-skill-surface.sh` | Host-neutral core, per-host install layout, namespaced skill surfaces |
| `validate-claude-agent-token-budget.sh` | Claude agent descriptions stay under the host token budget |
| `validate-workflow-authoring.sh`, `audit-workflow-compliance.sh`, `audit-atomic-flow-compliance.sh`, `run-apo-authoring-compliance.sh`, `check-apo-invariants.py` | Catalog and workflow authoring compliance |
| `validate-evidence-findings.sh`, `validate-evidence-findings.py` | Normalized finding tables in quality artifacts |
| `validate-graphify-artifacts.sh` | Committed Graphify artifacts are present and valid |
| `validate-launch-review.sh`, `validate-sentinel-skills-manifest.sh` | Release-gate exit criteria for the adversarial review and SENTINEL stages |
| `validate-github-release-notes.sh` | A GitHub Release body meets the release-notes rules |
| `claims-audit.sh` | Homepage claims are registered in `docs/testing/claims-registry.json` |

## Release

| Script | Purpose |
|--------|---------|
| `pre-release-gate.sh` | Local pre-release gate: site freshness, five-tool Cursor check, full suite, RC matrix |
| `pre-release-cursor-cli-smoke.sh`, `run-pre-release-host-smoke.sh`, `run-tri-host-install-smoke.sh` | Isolated per-host install and routing smoke tests |
| `run-rc-validation-matrix.sh` | RC validation matrix (cursor, codex, claude × fresh/upgrade) |
| `run-release-live-matrix.sh`, `release-live-matrix-cursor-smoke.sh` | Release live matrix and its Cursor smoke cell |
| `sync-release-marketplace-versions.sh`, `sync-marketplace-version.sh`, `sync-codex-marketplace-version.sh`, `sync-cursor-marketplace-version.sh` | Align marketplace manifests with the release version |
| `verify-release-commit-ci.sh`, `verify-release-announcement-ci.sh` | Wait for CI on the release commit before tagging / announcing |
| `post-release-host-verify.sh`, `post-release-refresh.sh` | Post-release uninstall, reinstall and smoke on each host |

See [docs/RELEASE.md](../docs/RELEASE.md) for the order.

## Live tests

| Script | Purpose |
|--------|---------|
| `run-sb-live-tests-claude.sh`, `run-sb-live-tests-codex.sh`, `run-sb-live-tests-kay.sh` | Run the live and E2E-live suites pinned to one runtime |
| `claude-interactive-invoke.expect`, `codex-interactive-invoke.expect`, `codex-interactive-invoke.py` | Drive interactive host TUIs for live tests |
| `agent-claude-autonomous-test.sh`, `minimal-intent-autonomous-e2e.sh`, `sb-tri-criteria-e2e.sh`, `dogfood-orchestrator-parent-surface.sh` | Autonomous and orchestrator end-to-end drivers |
| `run-visual-qa-pipeline.sh` | Visual QA pipeline for the site |

## Enterprise E2E

| Script | Purpose |
|--------|---------|
| `run-enterprise-e2e-live-test.sh`, `run-enterprise-e2e-matrix.sh` | Entry points for the enterprise live test and matrix (wrappers over `enterprise-e2e/`) |
| `run-enterprise-e2e-pre-release-overlay.sh`, `run-enterprise-e2e-validation-overlay.sh` | Feature-claim and outcome overlays on top of the matrix |
| `enterprise-e2e-certification-status.sh`, `enterprise-e2e-rcs.sh`, `export-enterprise-evidence.sh` | Certification status, release confidence score, evidence export |
| `monitor-enterprise-e2e-matrix.sh`, `monitor-enterprise-e2e-supervisor.sh`, `watch-enterprise-e2e-tui.sh` | Monitor and supervise matrix batches |
| `ENTERPRISE-E2E-OPERATOR-PROMPT.md` | Canonical operator prompt for the live test |

Runbook: [docs/ENTERPRISE-E2E-LIVE-TEST.md](../docs/ENTERPRISE-E2E-LIVE-TEST.md).

## Agent delegation

| Script | Purpose |
|--------|---------|
| `agent-claude-delegate.sh`, `agent-codex-delegate.sh`, `agent-cursor-delegate.sh`, `agent-opencode-delegate.sh`, `agent-pi-delegate.sh` | On-demand delegation wrappers behind `/sb:agent-<host>` |
| `agent-delegation-cleanup.sh` | Clear stale delegation state after a crash or cancel |

## Subdirectories

| Directory | Contents |
|-----------|----------|
| `agent-claude/`, `agent-codex/`, `agent-opencode/`, `agent-pi/` | Per-host delegation pieces: `preflight.sh`, `invoke.sh`, `monitor.sh`, `env.sh`, `lib.sh` |
| `agent-mode/` | Agent-mode control script and a mock interactive host for tests |
| `enterprise-e2e/` | The enterprise E2E harness (matrix, live test, preflight, smoke, checkpoints, config) |
| `lib/` | Sourced helpers: per-host installer libraries (`install-claude/`, `install-codex/`, `install-cursor/`), recommended-tools and global-toolstack libraries, the five-tool runtime (`five_tool_runtime/`), Cursor subagent tooling, host install guides, enterprise E2E and delegation helpers, review-fix-ladder Python modules |
