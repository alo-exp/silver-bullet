# `/silver:new-workflow` — Workflow Authoring Runbook

Create, convert, or audit Silver Bullet workflows with full catalog compliance.

## Invoke

### Create

```
/silver:new-workflow <intent>
```

### Convert

```
/silver:new-workflow skills/my-legacy-skill/SKILL.md
```

### Audit (read-only)

```
/silver:new-workflow --audit WF-SILVER-FEATURE
/silver:new-workflow --audit silver-feature
/silver:new-workflow --audit feature
/silver:new-workflow --validate skills/silver-new-workflow/SKILL.md
/silver:new-workflow audit WF-SILVER-NEW-WORKFLOW
```

Audit mode resolves the target workflow, runs `scripts/audit-workflow-compliance.sh`, and writes a compliance report under `.planning/`. No catalog edits, plan, RFL, or implement steps.

Default target repo: current project (confirmed in session JSON for Create/Convert only).

## Checklist (SB source repo)

| Surface | Action |
|---------|--------|
| `skills/silver-<slug>/SKILL.md` | Composer spec |
| `scripts/generate-apo-catalog.py` | Mapping + `build_workflows()` |
| `hooks/lib/orchestrator-state.sh` | Composer + queue |
| `hooks/workflow-chain-guard.sh` | Pre-exec markers |
| `skills/silver/SKILL.md` | Router row |

Regenerate:

```bash
python3 scripts/generate-apo-catalog.py
python3 scripts/generate-apo-artifacts.py
bash scripts/sync-codex-package.sh
bash scripts/sync-templates.sh
bash scripts/generate-plugin-commands.sh
graphify update .
```

Validate:

```bash
bash scripts/validate-workflow-authoring.sh --slug new-workflow
bash scripts/audit-workflow-compliance.sh --slug new-workflow
bash scripts/run-apo-authoring-compliance.sh
bash tests/scripts/test-silver-new-workflow.sh
bash tests/scripts/test-silver-new-workflow-audit.sh
```

Audit any existing workflow:

```bash
bash scripts/audit-workflow-compliance.sh --target WF-SILVER-FEATURE
bash scripts/validate-workflow-authoring.sh --audit --target silver-feature
```

Meta workflow catalog id: **`WF-SILVER-NEW-WORKFLOW`**.

See [`docs/APO-AUTHORING-COMPLIANCE.md`](APO-AUTHORING-COMPLIANCE.md).
