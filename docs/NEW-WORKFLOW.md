# `/silver:new-workflow` — Workflow Authoring Runbook

Create or promote Silver Bullet workflows with full catalog compliance.

## Invoke

```
/silver:new-workflow <intent>
/silver:new-workflow skills/my-legacy-skill/SKILL.md
```

Default target repo: current project (confirmed in session JSON).

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
bash scripts/run-apo-authoring-compliance.sh
bash tests/scripts/test-silver-new-workflow.sh
```

Meta workflow catalog id: **`WF-SILVER-NEW-WORKFLOW`**.

See [`docs/APO-AUTHORING-COMPLIANCE.md`](APO-AUTHORING-COMPLIANCE.md).
