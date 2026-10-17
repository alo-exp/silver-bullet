# Configuration Reference (`.silver-bullet.json`)

Every Silver Bullet project has a `.silver-bullet.json` at its root. `/sb:init` creates it from [`templates/silver-bullet.config.json.default`](../templates/silver-bullet.config.json.default), and `/sb:update` or `bash scripts/sb-migrate-config.sh [PROJECT_ROOT]` merges an existing file forward (keeping project values and unioning skill lists). Hooks stay inert until both `.silver-bullet.json` and `silver-bullet.md` exist at the project root.

This page lists every key in the template, which code reads it, and the keys the code reads that the template does not contain. "Reader" names the main consumer; search the tree for the key to find every use.

## Versions and activation

| Key | Template value | Meaning | Reader |
|-----|----------------|---------|--------|
| `config_version` | current release (for example `0.53.0`) | The Silver Bullet release whose config schema this file matches. A project value older than the template's marks the config as legacy (`sb-doctor.sh` check D6 fails; `hooks/lib/required-skills.sh` treats it as legacy). Kept equal to `package.json` in the template by `tests/scripts/test-release-version-alignment.sh` | `required-skills.sh`, `sb-doctor.sh` |
| `version` | `0.46.0` | Legacy predecessor of `config_version`, read only as a fallback when `config_version` is absent. `sb-migrate-config.sh` sets both to the plugin version | same |
| `sb_initiated` | `false` | `true` once `/sb:init` (or `scripts/sb-migrate-initiated.sh`) has run; several gates (jq-missing blocks, prerequisite probes) apply only to initiated projects | `hooks/lib/project-active.sh`, `session-start` |
| `sb_enforcement_tier` | `null` | Persisted capability tier (0–3) of the host; probed and written by the hooks. Delivery is blocked when the effective tier says hooks are inactive | `hooks/lib/enforcement-tier-gate.sh` |
| `orchestrator_mode` | `"parent"` | Orchestration mode; `parent` (the parent session delegates each atomic flow to Task workers) is the only supported value | `hooks/lib/orchestrator-parent.sh` |

## `project`

| Key | Template value | Meaning |
|-----|----------------|---------|
| `project.name` | `{{PROJECT_NAME}}` (filled by `/sb:init`) | Project display name, used by skills such as `sb:rem` |
| `project.src_pattern` | `/src/` | Path pattern for files that count as source and trigger the planning-floor gate. Must look like a path segment pattern (`^/[a-zA-Z0-9/_.\|()-]*/?$`); unsafe or match-everything values fall back to `/src/` |
| `project.src_exclude_pattern` | `__tests__\|\.test\.` | Regex for source-like files to exempt (tests). Limited to 200 safe characters, otherwise the default is used |
| `project.active_workflow` | `full-dev-cycle` | `full-dev-cycle` or `devops-cycle`; selects the workflow doc and the `_devops` skill lists. In `devops-cycle`, `.yml`, `.yaml`, `.json` and `.toml` files count as infrastructure code |

`dev-cycle-check.sh` reads the patterns; `completion-audit.sh` uses them to classify a change set.

## `skills`

| Key | Meaning | Enforced by |
|-----|---------|-------------|
| `skills.required_planning` | Planning floor: skills that must be recorded before source edits, commits and pushes, and before a task can end. Default `silver-quality-gates`, `silver-context`, `silver-plan` | `dev-cycle-check.sh`, `completion-audit.sh`, `stop-check.sh` |
| `skills.required_planning_devops` | Planning floor in `devops-cycle` (adds `silver-blast-radius`, `devops-quality-gates`) | same |
| `skills.required_deploy` | Final delivery floor for `gh pr create/merge`, deploy and `gh release create` | `completion-audit.sh` |
| `skills.required_deploy_devops` | Delivery floor in `devops-cycle` | `completion-audit.sh` |
| `skills.required_release`, `skills.required_release_devops` | Extra skills for `gh release create` (default `silver-create-release`) | `completion-audit.sh` |
| `skills.all_tracked` | Skills `record-skill.sh` records in the state file. Project entries are added to the packaged defaults, not substituted | `record-skill.sh` |
| `skills.forbidden` | Extra skills to block, on top of the built-in `executing-plans` and `subagent-driven-development` | `forbidden-skill-check.sh` |

Project lists replace the template defaults (`hooks/lib/required-skills.sh` supplies the defaults when a list is missing). Adding a skill to `required_deploy` is a breaking change for users; see [CICD.md](CICD.md#breaking-change-policy-for-required-skills).

## `state`

| Key | Default | Meaning |
|-----|---------|---------|
| `state.state_file` | `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/state` | Skill-marker state file. Paths outside the runtime home are rejected and the default is used |
| `state.trivial_file` | `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/trivial` | Legacy trivial-session marker; `session-start` deletes it and agents cannot create it |

Tests override these with `SILVER_BULLET_STATE_FILE`, `SILVER_BULLET_BRANCH_FILE`, `SILVER_BULLET_QUALITY_GATE_STATE_FILE` and `SILVER_BULLET_VERIFY_TESTS_STATE_FILE` ([ENFORCEMENT.md](ENFORCEMENT.md#environment-variables)).

## `release`

Read by `completion-audit.sh` on `gh release create` ([ENFORCEMENT.md](ENFORCEMENT.md#release-gates), [RELEASE.md](RELEASE.md)).

| Key | Template value | Meaning |
|-----|----------------|---------|
| `release.profile` | `"generic"` | Release profile label; carried forward by migration, not read by the hooks |
| `release.require_plugin_runtime_matrix` | `true` | Require the live runtime matrix markers (`release-live-matrix`, `e2e-live-matrix`, `inline-e2e-matrix`) |
| `release.require_pre_release_quality_gate` | `true` | Require the quality-gate markers `adversarial-review-clean`, `sentinel-skills-clean`, `quality-gate-stage-3`, `full-test-suite-rerun` |
| `release.require_rc_matrix` | `true` | Require the six operator-local RC validation markers |
| `release.quality_gate_state_file` | `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/quality-gate-state` | Where the quality-gate markers are read; cleared at session start |
| `release._comment_quality_gate_markers` | — | Comment only |

These gates were built for multi-host plugin releases. A downstream project that does not run live matrices sets the `require_*` flags it does not need to `false`.

## `hooks`

| Key | Template value | Meaning |
|-----|----------------|---------|
| `hooks.evidence_schema.strict` | `true` | When true (also the default when absent), malformed finding tables in quality artifacts block delivery instead of only warning (`hooks/lib/evidence-schema-gate.sh`, [evidence-schema.md](evidence-schema.md)) |
| `hooks.industry_tooling.enabled` | `false` | Turn on `industry-tooling-hint.sh` reminders (for example `npm audit`, `terraform validate`) |
| `hooks.stop_check.transient_path_ignore_patterns` | *(not in template)* | Extra extended-regex patterns for uncommitted paths `stop-check.sh` should treat as transient; overly broad patterns are ignored |

## `recommended_tools`

One object per optional tool: `graphify`, `agentmemory`, `alumnium`, `rtk`, `context_mode`, `leanctx`, `search_cli`. Each tool's gate hook enforces it only when the user opted in and enforcement is not suspended ([HOOKS.md](HOOKS.md)).

Common fields:

| Field | Meaning |
|-------|---------|
| `enabled_by_user` | `null` = consent pending (advisory), `true` = opted in (gates enforce), `false` = opted out |
| `enforcement_suspended` | `true` after a failed install, so the gate stays advisory |
| `install_status`, `install_failure_reason` | Written by the installers and reconciler |
| `required_when_enabled` | Whether an opted-in tool is mandatory (all but `search_cli`) |
| `install_commands`, `platform_install_commands.<host>.pre_index` / `post_index` | Install steps per host (`claude`, `codex`, `cursor`, `opencode`, `pi`, `goose`, `hermes`) |
| `benefits_summary` | Text shown when asking for consent |

Tool-specific fields:

| Tool | Fields |
|------|--------|
| `graphify` | `graph_path` (`graphify-out/graph.json`), `query_ttl_seconds` (how long a query counts as fresh), `query_budget`, `query_state_file`, `optimization` (profile and last apply/verify timestamps) |
| `agentmemory` | `health_url`, `usage_ttl_seconds`, `usage_state_file`, `export_root` (`.agentmemory`), `optimization` |
| `alumnium` | `mcp_server_name` |
| `rtk` | `min_version`, `optimize_on_init`, `optimize_script` |
| `context_mode` | `read_deny_bytes` (Read/Grep above this size are denied when enforced), `read_deny_bypass_env`, `min_node_version`, `optimize_on_init`, `optimize_script`, `license_note` |
| `leanctx` | `min_version`, `cli_command`, `usage_ttl_seconds`, `usage_state_file`, `stack_mode`, `optimization_profile`, `primary_fts`, `mcp_server_name`, `mcp_tool_prefix`, `exclusive_surfaces` |
| `search_cli` | `binary`, `provider_classes` (used by `sb:deep-research` when configured) |

A legacy top-level `graphify.required` boolean is migrated into `recommended_tools.graphify.enabled_by_user` by `hooks/lib/recommended-tools.sh`.

## `optimization_profiles`

Named settings bundles for the five-tool stack, read by `hooks/lib/stack-optimizer.sh`, `hooks/lib/stack-compression-coordinator.sh` and `scripts/optimize-five-tool-stack.sh`: `synergy_max` (Graphify + agentmemory defaults), `cost_minimized` (marked future, not applied yet) and `five_tool_routed` (extends `synergy_max` and routes each surface — reads, grep, shell, web fetch, memory — to one tool).

## Other sections

| Key | Meaning | Reader |
|-----|---------|--------|
| `devops_plugins.*` | Which optional DevOps plugin families (`hashicorp`, `awslabs`, `pulumi`, `devops-skills`, `wshobson`) were detected at init | `devops-skill-router` skill |
| `issue_tracker` | `local` (default; `docs/issues/`), `github`, or `custom` | `sb:add`, `scripts/silver-add.sh` |
| `issue_tracker_adapter.type`, `.create_issue_command`, `.dedupe_command`, `.payload_schema` | Command adapter used when `issue_tracker` is `custom` | `scripts/silver-add.sh` |
| `compactPrompt` | Instruction text for context compaction: preserve `silver-bullet.md` rules verbatim. Carried forward by migration; no hook reads it | — |
| `semantic_compression.enabled`, `.context_budget_kb`, `.min_file_size_bytes`, `.chunk_size_bytes`, `.top_chunks_per_file`, `.debug` | Context assembly after phase skills (budget, files considered, chunking, ranking) | `scripts/semantic-compress.sh` |
| `multi_agent.identity_tags`, `.stale_lock_ttl_seconds` | Runtime identities allowed to hold phase locks, and when a lock is stale | `.planning/scripts/phase-lock.sh` (phase-lock hooks) |
| `multi_agent.delegation_timeout_seconds` | Child delegation timeout described in [multi-agent-coordination.md](multi-agent-coordination.md); no script reads it at present | — |
| `cursor_sb_agents.*` | Which SB-managed Cursor subagents to install (models, effort levels, name prefix, install status) | `scripts/install-cursor-sb-agents.sh`, `sb-doctor.sh` |

### `enterprise_policy`

`enterprise_policy.active_profile` selects one of `enterprise_policy.profiles` (`supervised`, `autonomous_safe`, `regulated`, `internal_dogfood`). Profile fields:

| Field | Effect |
|-------|--------|
| `session_mode_default` | `interactive` or `autonomous`; `session-start` applies it as the default session mode (`autonomous` only on hook-enforced hosts, and never over an existing choice) |
| `clarify_auto` | Allow bounded `sb:clarify --auto` |
| `production_deploy_requires_human` | When true, `gh pr create/merge`, `gh release create` and deploy commands are blocked until a human creates `${SB_RUNTIME_STATE_DIR}/enterprise-human-deploy-approved` ([ENFORCEMENT.md](ENFORCEMENT.md#enterprise-policy-delivery-block)). It is true in every shipped profile and is the default when no profile is configured |
| `non_production_deploy_autonomy` | Exempt delivery commands that name a non-production target (`internal_dogfood` only) |
| `evidence_schema_strict` | Force strict evidence-schema validation |
| `orchestrator_mode`, `label`, `description` | Informational |

The template's `_comment` calls the profiles "advisory scaffolding"; the human-approval delivery block above is enforced today.

## Keys the template does not contain

| Key | Meaning | Reader |
|-----|---------|--------|
| `verify_commands` | Array of shell commands `/verify-tests` runs instead of the stack defaults (`bash tests/run-all-tests.sh`, `npm test --if-present`, `pytest`, `cargo test`, `go test ./...`) | `scripts/verify-tests.sh` |
| `hooks.stop_check.transient_path_ignore_patterns` | See `hooks` above | `stop-check.sh` |
| `project.tech_stack` | Stack label stamped into `.planning/interface/STATE.md` | `scripts/stamp-interface-state.sh` |
| `graphify.required` | Legacy; migrated to `recommended_tools.graphify.enabled_by_user` | `hooks/lib/recommended-tools.sh` |

Example:

```json
{
  "verify_commands": ["bash tests/run-all-tests.sh --jobs 4", "shellcheck hooks/*.sh"],
  "hooks": { "stop_check": { "transient_path_ignore_patterns": ["^\\?\\? tmp/"] } }
}
```
