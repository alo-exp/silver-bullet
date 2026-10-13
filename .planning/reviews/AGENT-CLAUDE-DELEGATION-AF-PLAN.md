# Agent-Claude AF-AGENT-DELEGATE Integration Plan

**Branch:** `feature/silver-agent-claude-skill`  
**Date:** 2026-07-05  
**Scope:** Tri-host extension — add `/silver:agent-claude` alongside existing Codex/Cursor delegation (do not remove Codex).

## Design (mirror Codex/Cursor on main v0.50.5)

| Surface | Claude integration |
|---------|-------------------|
| Host skill | `skills/silver-agent-claude/SKILL.md` → `AF-AGENT-DELEGATE` |
| Wrapper | `scripts/agent-claude-delegate.sh` + `scripts/agent-claude/*` harness |
| Common lib | `scripts/lib/agent-delegate-common.sh` (shared redaction, matrix clear, log floor) |
| Catalog steps | `FS-DELEGATE-CLAUDE-LAUNCH`, `FS-DELEGATE-CLAUDE-ROUTE` in `DELEGATE_FLOW_STEP_ORDER` |
| Worker | `templates/orchestrator-workers/AGENT-DELEGATE.md` — `host=claude` → `agent-claude-delegate.sh` |
| Directive seed | `sb_orchestrator_seed_delegation_directive claude ...` |
| Parent guard | `silver-agent-claude` in skill allowlist; `agent-claude-delegate.sh` / `agent-claude/invoke.sh` degraded fallback only |
| Migration map | `silver-agent-claude` → `AF-AGENT-DELEGATE` |

## Implementation checklist

- [x] Extract Claude harness from `origin/feature/silver-agent-claude-skill` (preserve Codex on main)
- [x] Extend `generate-apo-catalog.py` with Claude host steps + skill map
- [x] Update orchestrator directive/parent hooks for `host=claude`
- [x] Update `skills/silver/SKILL.md` routing row
- [x] Extend tests (common, catalog, rollback, directive, integration paths)
- [x] Regenerate catalog artifacts + sync bundles/commands
- [x] RFL closeout in `.planning/reviews/AGENT-CLAUDE-DELEGATION-RFL.md`
- [x] Live smoke: product marker PASS; harness timeout/log-floor FAIL (print mode — see RFL)

## Conflicts avoided

Uncommitted `/silver:new-workflow` work on shared files (`skills/silver/SKILL.md`, `generate-apo-catalog.py`, etc.) preserved — only additive Claude rows/steps applied.

## Validation commands

```bash
bash tests/scripts/test-agent-claude-skill.sh
bash tests/scripts/test-agent-delegate-common.sh
bash tests/scripts/test-agent-delegation-catalog-contract.sh
bash tests/scripts/test-agent-delegation-rollback.sh
bash tests/hooks/test-orchestrator-delegation-directive.sh
bash scripts/run-apo-authoring-compliance.sh
bash scripts/sync-codex-package.sh
bash scripts/sync-templates.sh
bash scripts/generate-plugin-commands.sh
```
