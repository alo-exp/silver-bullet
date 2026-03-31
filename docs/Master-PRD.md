# Dev Workflows — Product Requirements Document

## Problem

Claude Code skips required workflow steps (brainstorming, code review, verification) even when CLAUDE.md explicitly requires them. Documentation-level instructions alone are insufficient — Claude rationalizes its way past them ("this is simple enough", "I already covered this implicitly").

Teams new to AI-driven software engineering have no guardrails to ensure quality.

## Solution

A Claude Code plugin that enforces a structured 23-step development cycle through six layers of automated compliance enforcement. The plugin tracks skill invocations via hooks and blocks progress when required steps are missing.

## Target Users

- Teams with little or no AI-driven software engineering experience
- Individual developers wanting structured AI workflows
- Organizations requiring auditable development processes

## Core Requirements

### Must Have (v1.0)

1. **Single-command setup**: `/using-dev-workflows` initializes any project
2. **HARD STOP gate**: Block source code edits until planning is complete
3. **Completion audit**: Block git commit/push/deploy when workflow is incomplete
4. **Compliance status**: Show progress on every tool use
5. **Skill tracking**: Record every skill invocation to a state file
6. **Phase enforcement**: PLANNING -> EXECUTION -> REVIEW -> FINALIZATION -> DEPLOYMENT
7. **Trivial change bypass**: `touch /tmp/.dev-workflows-trivial` for minor fixes
8. **Per-project config**: `.dev-workflows.json` with customizable skill lists and patterns
9. **Dependency detection**: Check for Superpowers, Engineering plugins, and jq at setup
10. **Anti-rationalization**: Explicit language preventing Claude from skipping steps

### Nice to Have (v1.1+)

11. Test suite for all hooks
12. Configurable REVIEW/FINALIZATION skill lists
13. Shared config resolution library
14. Per-worktree state scoping
15. Config schema validation

## Dependencies

- [Superpowers](https://github.com/obra/superpowers) plugin (planning, execution, review skills)
- [Engineering](https://github.com/anthropics/knowledge-work-plugins/tree/main/engineering) plugin (code review, debugging, documentation skills)
- `jq` system binary

## Success Criteria

- Claude follows 100% of required workflow steps without user intervention
- HARD STOP fires reliably when planning is incomplete
- Completion audit blocks premature commits/deploys
- Setup completes in under 2 minutes for any project
- Hooks degrade gracefully (never block the user on hook failure)
