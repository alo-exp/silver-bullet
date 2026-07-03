---
name: "silver:migrate"
title: "Migrate"
description: "This skill should be used when the user runs `/silver:migrate` or asks to migrate an older Silver Bullet project from retired workflow/doc conventions to current per-instance workflow tracking, Learnings documentation terminology, agent-neutral templates, runtime parity artifacts, and current `.silver-bullet.json` defaults."
version: 0.5.0
---

# silver:migrate

Migrates an older mid-milestone project to the current Silver Bullet contract:

- per-instance workflow tracking (replaces legacy `.planning/WORKFLOW.md`)
- `docs/learnings/` terminology (replaces `docs/lessons/`)
- agent-neutral `silver-bullet.md` and project instruction files
- current `.silver-bullet.json` defaults from `templates/silver-bullet.config.json.default`
- orchestrator parent mode (`orchestrator_mode: parent`, worker templates, task host rule)
- `scripts/workflows.sh` and `docs/workflows/*.md` when absent (parity with `/silver:init`)
- `.gitignore` entry for `.planning/workflows/` (local runtime state)
- runtime parity awareness (evidence schema, diagnostics, bootstrap probes)
- doc-scheme / task checklist alignment
- optional UI interface state (`.planning/interface/STATE.md`)

The legacy `.planning/WORKFLOW.md` file is retired. Do not create or update it.
The legacy `docs/lessons/` path and "Lessons" terminology are retired. Use `docs/learnings/` and "Learnings" instead.

Per-host install paths, hook manifests, and skill invocation channels are documented in `docs/RUNTIME-COMPATIBILITY.md`. Use the active runtime's supported file-reading, file-editing, and skill invocation mechanisms throughout this skill.

## When to Use

- `.planning/` exists with older lifecycle state artifacts.
- The project was started before per-instance workflow tracking or before v0.39.x runtime parity.
- `silver-bullet.md` still references host-specific skill channels or pre-058 wording.
- `.silver-bullet.json` lacks current `config_version`, `release`, `required_release`, `hooks`, or `multi_agent` defaults.
- `orchestrator_mode` is absent or not `parent`.
- `scripts/workflows.sh` is missing (workflow tracker / `flow-advance` will fail).
- The user explicitly runs `/silver:migrate` or asks to migrate workflow tracking or SB version surface.

## Prerequisites

- `.planning/STATE.md` must exist.
- `scripts/workflows.sh` must be available from the project root or plugin install.
- Resolve `PLUGIN_ROOT` from this skill file's location (`skills/silver-migrate/SKILL.md` → two directories up from the skill directory, or the installed plugin root).
- If `.planning/workflows/*.md` already contains an active workflow, report the active id and skip only the workflow-tracker migration (Step 5). Still run Steps 0–4.

## Steps

### Step 0: Migrate Documentation Terminology

Run this step before workflow-tracker checks so projects with current workflow files still receive the doc migration.

1. If `docs/lessons/` exists and `docs/learnings/` does not exist, move the directory:

   ```bash
   mv docs/lessons docs/learnings
   ```

2. If both directories exist, merge files conservatively:
   - For each file that exists only in `docs/lessons/`, move it to `docs/learnings/`.
   - For each file that exists in both, append the old `docs/lessons/` content under a `## Migrated from docs/lessons/` heading in the matching `docs/learnings/` file, then remove the old file only after confirming the content is preserved.
   - Remove `docs/lessons/` only when empty.

3. Update documentation scheme files and checklist keys:
   - `docs/doc-scheme.md`
   - `docs/doc-scheme.json`
   - `docs/task-doc-checklist.json`
   - `docs/knowledge/INDEX.md`
   - project docs that reference `docs/lessons/`, `lessons/YYYY-MM.md`, "Lessons", or "lessons"

   Required replacements:
   - `docs/lessons/` -> `docs/learnings/`
   - `lessons/YYYY-MM.md` -> `learnings/YYYY-MM.md`
   - `type: lessons` -> `type: learnings`
   - "Lessons" -> "Learnings"
   - "lessons" -> "learnings"
   - "lesson" -> "learning" only when it refers to the documentation category, not normal prose unrelated to SB docs

4. Update monthly learnings files:
   - Frontmatter must use `type: learnings`.
   - Title should be `# Learnings - YYYY-MM` or `# Learnings — YYYY-MM`.
   - Category headings remain `domain:{area}`, `stack:{technology}`, `practice:{area}`, `devops:{area}`, and `design:{area}`.

5. Report the documentation terminology migration separately:
   - files moved
   - files updated
   - any `docs/lessons/` files left for manual review

### Step 1: Refresh Agent-Neutral `silver-bullet.md`

Re-stamp from the bundled template without host-specific leaks. Silver Bullet owns this file.

1. Read `.silver-bullet.json` for `project.name` and `project.active_workflow` (default `full-dev-cycle`).
2. Back up the existing file when present:

   ```bash
   test -f silver-bullet.md && cp silver-bullet.md silver-bullet.md.backup
   ```

3. Copy `${PLUGIN_ROOT}/templates/silver-bullet.md.base` to `silver-bullet.md` and substitute:
   - `{{PROJECT_NAME}}` → project name from config or directory basename
   - `{{ACTIVE_WORKFLOW}}` → active workflow from config

4. Scan the refreshed file for stale host-specific literals (for example hardcoded host skill channel names, host home paths, or primary host model names). If any remain in the stamped output, report a plugin packaging defect — the canonical template should be host-neutral per phase 058.

### Step 2: Upgrade `.silver-bullet.json` to Current Defaults

Merge forward from `templates/silver-bullet.config.json.default` without discarding project customizations.

Run the mechanical merge when the script is available:

```bash
bash "${PLUGIN_ROOT}/scripts/sb-migrate-config.sh" 2>/dev/null || \
  bash scripts/sb-migrate-config.sh
```

If neither script is available, merge manually:

1. Read the template defaults and the existing `.silver-bullet.json` (create from template if absent).
2. Preserve all project-specific values: `project.name`, `project.src_pattern`, `project.src_exclude_pattern`, custom `verify_commands`, and user-chosen `issue_tracker`.
3. Add or refresh top-level fields when missing or older than the template:
   - `config_version` and `version` (target: current plugin release from `package.json` `version` field)
   - `orchestrator_mode` → `"parent"` (only supported mode)
   - `release.profile`, `release.require_plugin_runtime_matrix`, `release.require_pre_release_quality_gate`, `release.quality_gate_state_file`
   - `hooks.evidence_schema`, `hooks.industry_tooling`
   - `devops_plugins` block
   - `semantic_compression` block
   - `multi_agent` block
   - `compactPrompt`
   - any new entries in `skills.required_planning`, `skills.required_deploy`, `skills.required_release`, `skills.required_*_devops`, or `skills.all_tracked` — union with existing lists; do not remove user-added skill names
4. Normalize legacy local-tracker `issue_tracker` values to `"local"` (filing skills treat pre-SB local markdown tracking the same as explicit `local`).
5. Set **`sb_initiated: true`** so enforcement hooks activate after migrate.
6. Write the merged config and report fields added or bumped.

### Step 2.5: Install Project Surface Parity (Init-Equivalent)

Bring mechanical bootstrap artifacts to parity with `/silver:init` without overwriting user docs.

```bash
bash "${PLUGIN_ROOT}/scripts/sb-migrate-project.sh" 2>/dev/null || \
  bash scripts/sb-migrate-project.sh
```

This script (idempotent) runs `sb-migrate-config.sh`, `sb-migrate-orchestrator-parent.sh`, copies `scripts/workflows.sh` when absent, creates `.planning/workflows/.archive/`, seeds missing `docs/workflows/{full-dev-cycle,devops-cycle}.md` from templates, and ensures `.gitignore` contains `.planning/workflows/`.

If the script is unavailable, perform the same steps manually:

1. Set `orchestrator_mode: parent` and copy `${PLUGIN_ROOT}/templates/orchestrator-workers/` → `.silver-bullet/orchestrator-workers/`.
2. When the active host supports orchestrator parent mode or `host rules path (see install guide) ` exists, refresh `host rules path (see install guide) silver-orchestrator.mdc` from `${PLUGIN_ROOT}/scripts/lib/install-task host/templates/task host-rules/silver-orchestrator.mdc`. (other hosts: skip — orchestrator uses hook directive injection.)
3. Copy `${PLUGIN_ROOT}/scripts/workflows.sh` → `scripts/workflows.sh` (`chmod +x`) when absent.
4. `mkdir -p .planning/workflows/.archive docs/workflows`.
5. Copy workflow docs from `${PLUGIN_ROOT}/templates/workflows/` only when the destination file is absent (back up before any explicit user-requested refresh).
6. Append `.planning/workflows/` to `.gitignore` when missing.

Report what was installed vs already present.

### Step 3: Reconcile Project Instruction File (Host-Appropriate)

Regenerate stale host instruction files from the init contract when they predate agent-neutral separation.

1. Detect the active host instruction file per `docs/RUNTIME-COMPATIBILITY.md`:
   - the active host agent → `primary host.md` when present
   - Codex / task host → `AGENTS.md` when present
   - If neither exists, skip this step (SB does not require creating one during migrate).

2. Determine staleness — refresh when any of:
   - file contains SB-owned numbered sections (`## N. Session Startup`, `## 3a.`, etc.)
   - file lacks a top reference line mentioning `silver-bullet.md`
   - file contains pre-v0.7.0 enforcement line without `silver-bullet.md`
   - file embeds host-specific skill/tool names that belong only in rendered agent bundles

3. Before overwrite, back up: `cp <file> <file>.backup`

4. Strip SB-owned sections from the existing file (headings `## N.` through next `## ` or EOF). Preserve all user-owned sections.

5. Merge in missing neutral sections from `${PLUGIN_ROOT}/scripts/lib/install-primary host/templates/primary host.md.base`:
   - **User-owned** sections (heading exists only in project file): keep unchanged
   - **New from template** (heading exists only in template): append
   - **SB-owned overlap**: prefer template neutral wording; ask the user directly when content conflicts materially

6. Ensure the reference line at top:
   `> **Always adhere strictly to this file and silver-bullet.md — they override all defaults.**`

7. Do not create `primary host.md` on Codex-only projects or `AGENTS.md` on primary host-only projects unless the user explicitly requests it.

### Step 4: Runtime Support, task host Hooks, and Parity Artifacts

Surface runtime parity expectations and refresh host hook delivery when applicable.

#### 4.1 Diagnostics and bootstrap (all hosts)

Run when scripts are available:

```bash
bash "${PLUGIN_ROOT}/scripts/sb-diagnostics.sh" 2>/dev/null || \
  bash scripts/sb-diagnostics.sh 2>/dev/null || true

bash "${PLUGIN_ROOT}/scripts/sb-bootstrap.sh" 2>/dev/null || \
  bash scripts/sb-bootstrap.sh 2>/dev/null || true
```

Report capability tier and any WARN/FAIL lines. Point the user to `docs/RUNTIME-COMPATIBILITY.md` for tier definitions and install surfaces.

#### 4.2 Host hook merge (all hosts)

Re-register SB hooks in the active host settings file (same contract as `/silver:init` update mode §3.7.5). Resolve `INSTALL_PATH` from `$HOME/.codex/plugins/installed_plugins.json` when possible; fall back to `PLUGIN_ROOT`.

Per-host merge scripts live under `scripts/lib/install-<runtime>/` — see `docs/RUNTIME-COMPATIBILITY.md` (`merge-hooks.py`, `merge-cursor-hooks.py`).

```bash
INSTALL_PATH="${INSTALL_PATH:-${PLUGIN_ROOT}}"
if [[ -f "${PLUGIN_ROOT}/scripts/lib/install-cursor/merge-cursor-hooks.py" ]]; then
  python3 "${PLUGIN_ROOT}/scripts/lib/install-cursor/merge-cursor-hooks.py" "$INSTALL_PATH" 2>/dev/null || true
else
  python3 "${PLUGIN_ROOT}/scripts/lib/install-primary host/merge-hooks.py" "$INSTALL_PATH" 2>/dev/null || true
fi
```

Confirm merged entries in the host hooks manifest. If merge fails, advise the host-specific install path from `docs/RUNTIME-COMPATIBILITY.md` (`install-<runtime>.sh`).

#### 4.2a v1 hook incompatibility check

When a project-scoped host settings file exists (see `docs/RUNTIME-COMPATIBILITY.md`), scan for retired v1 hook references: `record-skill.sh`, `dev-cycle-check.sh`, `/tmp/.wyzr-workflow-state`. If found, ask the user to remove them before relying on v2 enforcement (same rule as `/silver:init` §1.7).

#### 4.3 Phase 056 runtime parity checklist (project docs awareness)

Ensure the project doc surface acknowledges parity artifacts when missing. Do not overwrite existing substantive docs — add checklist items or stub pointers only when absent:

| Artifact | Purpose | Action when missing |
|----------|---------|---------------------|
| `docs/evidence-schema.md` | Normalized finding/evidence tables for reviews and gates | Note in migration report; invoke `silver:ensure-docs --bootstrap` if user wants full doc scaffold |
| `scripts/sb-diagnostics.sh` (via plugin) | Capability tier probe | Covered by Step 4.1 run |
| `scripts/sb-bootstrap.sh` (via plugin) | Onboarding orientation | Covered by Step 4.1 run |
| `docs/RUNTIME-COMPATIBILITY.md` (plugin-dev only) | Host parity matrix | Skip in downstream projects unless copied during init |

For downstream projects, record in the migration report which parity scripts ran and whether evidence-schema doc keys exist in `docs/doc-scheme.json`.

#### 4.4 Doc-scheme and task checklist refresh

When `docs/doc-scheme.json` exists:

1. Invoke `silver:ensure-docs` through the active runtime's SB-recognized skill invocation channel with `--bootstrap` or reconciliation mode so `doc-scheme.md`, `doc-scheme.json`, and `task-doc-checklist.json` stay synchronized.
2. Add or refresh checklist keys for:
   - `docs/learnings/` (not `docs/lessons/`)
   - `docs/evidence-schema.md` when the project uses SB review/release gates
   - `docs/RUNTIME-COMPATIBILITY.md` for plugin-dev repos only
3. Report keys added, preserved mappings, and any BLOCK findings from ensure-docs.

If `docs/doc-scheme.json` is absent, recommend `/silver:init` update mode or `silver:ensure-docs --bootstrap` rather than inventing a partial scheme.

#### 4.5 UI interface state (UI projects only)

When the project has UI surface signals (for example `silver-ui` workflow, frontend stack in manifests, or `.planning/DESIGN.md`):

1. If `.planning/interface/STATE.md` is absent, stamp from template:

   ```bash
   bash "${PLUGIN_ROOT}/scripts/stamp-interface-state.sh" 2>/dev/null || \
     bash scripts/stamp-interface-state.sh 2>/dev/null || true
   ```

2. If the stamp script is unavailable, copy `${PLUGIN_ROOT}/templates/interface/STATE.md.base` to `.planning/interface/STATE.md` (create `.planning/interface/` first).

3. Report whether interface state was created, already present, or skipped (non-UI project).

### Step 5: Scan Existing Artifacts

If an active `.planning/workflows/*.md` file exists, report the active id and skip to Step 8 after Steps 0–4. Workflow migration is unnecessary, but surface upgrades remain valid.

Read `.planning/STATE.md` to identify the current milestone, phase, and status.

Then scan for artifacts that indicate flow completion:

| Flow | Artifacts to Check | Inference Rule |
|------|--------------------|----------------|
| BOOTSTRAP | `.planning/PROJECT.md`, `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, `.planning/STATE.md` | Complete if all four exist |
| ORIENT | `.planning/intel/*.md`, `.planning/codebase/*.md` | Complete if any exists |
| CLARIFY | `.planning/CONTEXT.md`, `.planning/phases/*/CONTEXT.md`, `.planning/phases/*/*-CONTEXT.md` | Complete if context exists; otherwise pending or skipped based on current phase |
| DECIDE | `.planning/research/*.md`, `.planning/ADR-*.md`, legacy `docs/superpowers/specs/*.md` | Complete if any exists |
| SPECIFY | `.planning/SPEC.md` | Complete if exists |
| PLAN | `.planning/phases/*/*-PLAN.md`, `.planning/phases/*/PLAN.md` | Complete if current phase has a plan |
| EXECUTE | `.planning/phases/*/*-SUMMARY.md`, `.planning/phases/*/SUMMARY.md` | Complete if current phase has a summary |
| REVIEW | `.planning/phases/*/*-REVIEW.md`, `.planning/phases/*/REVIEW.md`, `.planning/REVIEW.md` | Complete if any exists |
| SECURE | `.planning/phases/*/*-SECURITY.md`, `.planning/phases/*/SECURITY.md`, `.planning/SECURITY.md` | Complete if any exists |
| VERIFY | `.planning/UAT.md`, `.planning/phases/*/*-UAT.md`, `.planning/phases/*/*-VERIFICATION.md`, `.planning/phases/*/VERIFICATION.md` | Complete if any exists |
| QUALITY GATE | SB state marker `silver-quality-gates` | Complete if marker exists |
| SHIP | SB state markers `silver-completion-audit` and `silver-ship` | Complete when both completion-audit and ship markers exist |
| DOCUMENT | `silver-ensure-docs` marker, or docs modified for current phase | Complete if evidence exists |
| RELEASE | `silver-create-release` marker or current version tag exists | Complete if evidence exists |

### Step 6: Compose Current Flow List

Include only flows that are relevant to the current project state. Always include the next unfinished SB lifecycle flow needed to resume safely.

Use phase artifacts for lifecycle position. Treat legacy lifecycle markers as
historical evidence only; do not generate workflows that depend on external
lifecycle plugins.

### Step 7: Start Per-Instance Workflow Tracking

Resolve the workflow helper, then run its start subcommand:

```bash
SB_FLOWS="<comma-separated inferred flow list>"
if [[ -x scripts/workflows.sh ]]; then
  SB_WORKFLOWS_BIN="scripts/workflows.sh"
else
  SB_WORKFLOWS_BIN="$(
    for root in \
      "$HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet/current" \
      "$HOME/.codex/plugins/cache/alo-labs/silver-bullet/current" \
      "$HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet"/* \
      "$HOME/.codex/plugins/cache/alo-labs/silver-bullet"/*; do
      if [[ -x "$root/scripts/workflows.sh" ]]; then
        printf "%s\n" "$root/scripts/workflows.sh"
        break
      fi
    done
  )"
fi
if [[ -z "${SB_WORKFLOWS_BIN:-}" ]]; then
  echo "Silver Bullet workflow tracker not found. Run /silver:update or reinstall Silver Bullet, then retry." >&2
  exit 1
fi

SB_WORKFLOW_ID=$("$SB_WORKFLOWS_BIN" start /silver:migrate "migrated legacy project state" "$SB_FLOWS")
export SB_WORKFLOW_ID
```

For each inferred-complete flow, mark it complete:

```bash
"$SB_WORKFLOWS_BIN" complete-flow "$SB_WORKFLOW_ID" "<flow-name>"
```

Leave the first uncertain or unfinished flow pending. Do not mark execution, review, security, verification, or ship complete unless the corresponding SB artifact or legacy migration evidence exists.

### Step 8: Report Migration

Report in sections:

1. **Documentation terminology** — files moved/updated; leftover `docs/lessons/`
2. **Surface refresh** — `silver-bullet.md`, `.silver-bullet.json` fields bumped, orchestrator parent surface, `workflows.sh` / workflow docs / gitignore, instruction file reconciliation
3. **Runtime parity** — diagnostics tier, host hook merge, doc-scheme keys, interface STATE
4. **Workflow tracker** — workflow id (or "skipped — active workflow exists")
5. **Inferred complete flows** with evidence
6. **Pending next flow**
7. **Manual review** — any ambiguity or conflicts deferred to the user

Recommend `/silver:init` in update mode when hook registration or full doc bootstrap still needs a dedicated pass after migrate.

## Produces

- `.planning/workflows/<id>.md` — active per-instance workflow tracker (when Step 7 runs)
- refreshed `silver-bullet.md` from agent-neutral template
- merged `.silver-bullet.json` with current default fields (`sb_initiated: true`, `orchestrator_mode: parent`)
- `scripts/workflows.sh` and missing `docs/workflows/*.md` when absent
- `.silver-bullet/orchestrator-workers/` and `host rules path (see install guide) silver-orchestrator.mdc` when applicable
- `.gitignore` entry for `.planning/workflows/` when missing
- reconciled `primary host.md` or `AGENTS.md` when stale
- `docs/learnings/` — current portable learnings path
- updated `docs/doc-scheme.md`, `docs/doc-scheme.json`, and `docs/task-doc-checklist.json` when present
- `.planning/interface/STATE.md` for UI projects when absent

## Notes

- Do not create `.planning/WORKFLOW.md`.
- If a legacy `.planning/WORKFLOW.md` exists, leave it untouched and treat it as historical evidence only.
- If inferred state is ambiguous, choose the safer pending status and let SB resume from `.planning/STATE.md`.
- Do not leave new writes pointed at `docs/lessons/`. Read legacy `docs/lessons/` only as migration input.
- Canonical skill text stays host-neutral; run `python3 scripts/render-agent-bundle.py render --agent {primary host,Codex,task host} --source-root skills --dest-root agents/<agent>` and `bash scripts/sync-Codex-package.sh` after editing this file in the SB source repo.
