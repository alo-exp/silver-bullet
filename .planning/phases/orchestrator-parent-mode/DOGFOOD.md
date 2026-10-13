# Dogfood — Orchestrator Parent Mode

**Target project:** `/Users/shafqat/projects/todo-app`  
**Date:** 2026-06-14

## Setup

```bash
cd /Users/shafqat/projects/todo-app
bash /Users/shafqat/projects/silver-bullet/repo/scripts/sb-migrate-orchestrator-parent.sh .
# or re-run /silver:init from updated SB plugin
```

Verify:

- `.silver-bullet.json` contains `"orchestrator_mode": "parent"`
- `.silver-bullet/orchestrator-workers/` contains template `.md` files
- `.cursor/rules/silver-orchestrator.mdc` present

## Procedure (one small feature)

1. Open parent session in Cursor with merged hooks (tier 2).
2. Request a trivial feature (e.g. "add completed-at timestamp to todos").
3. Confirm parent invokes `silver-orchestrator` / `/silver` — **no direct edits** in parent transcript.
4. Confirm parent spawns Task workers with `PLAN.md`, `EXECUTE.md`, etc. templates.
5. Confirm workers invoke assigned skills before edits.
6. Confirm `orchestrator-directive.json` advances between workers.
7. Confirm parent Stop blocked while `current_flow` non-empty.

## Evidence checklist

| Check | Expected |
|-------|----------|
| Parent Edit attempts | Blocked by guard (tier 2) |
| Task spawns | Worker marker written |
| Worker skill | `PostToolUse/Skill` records skill |
| Queue completion | `current_flow` empty; parent Stop allowed |
| Artifacts | PLAN/SUMMARY or equivalent from workers |

## Notes

Full live dogfood requires interactive Cursor session with Task tool — mechanical hooks verified via unit tests in SB repo.
