# Decision: Parent role → Orchestrator (plan-doc only)

- Date: 2026-08-14
- Branch: `main` (no commit, no git switch)
- Locked: architectural role **Parent → Orchestrator**

## Outcome

Both plan files updated and kept byte-identical:

- `.planning/router_subagent_surfaces_85bf9f09.plan.md`
- `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md`

## Role rename

- Architectural roles: Orchestrator, Advisor, Executor, Authorizer, Verifier, Validator
- `model-preferences.json` keys: Orchestrator, Advisor, Executor, Verifier, Validator (still no Authorizer key)
- One-way planning: Orchestrator → Advisor → Executor
- Orchestrator never implements; WBS ownership stays with Orchestrator
- Authorizer/Verifier split, effort High/Executor Max, silver→sb, `{agent,model,effort}` preserved

## Kept as English/git/process “parent”

Workflow parent, parent worktree/branch, return to parent, parent AF, parent work-spec, `sb-migrate-orchestrator-parent.sh`, stale-parent-evidence, WBS-tree “Parents own the composed view”.

Remaining capitalized role token `Parent` (excluding WBS-tree `Parents`): none.
