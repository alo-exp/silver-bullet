# Silver Bullet Full Development Cycle

Silver Bullet owns the normal software-engineering lifecycle. This workflow is
the canonical full-dev-cycle procedure for feature work, bugfixes, UI work,
research-to-build work, and release-adjacent changes that are not primarily
infrastructure changes.

Legacy GSD, Superpowers, and Anthropic knowledge-work markers may still satisfy
hooks during migration, but new workflow execution must use SB-owned commands.

## HOST MODEL BOUNDARY

Silver Bullet does not select models or route host subagents. Use the model and
execution primitives provided by the active host session. If an optional external
tool has its own model preferences, configure that tool outside SB workflow
instructions.

## Entry Points

| Intent | Command |
|---|---|
| Let SB classify the task | `/silver <request>` |
| Clarify vague work | `/silver:clarify` |
| Produce or augment specs | `/silver:spec` or `/silver:ingest` |
| Build feature work | `/silver:feature` |
| Fix a bug | `/silver:bugfix` |
| Build UI work | `/silver:ui` |
| Run bounded fast-path work | `/silver:fast` |
| Publish a milestone release | `/silver:release` |

If unsure, invoke `/silver` with the user request. SB routes to the correct
workflow and composes only the required paths.

## Required Lifecycle

### 0. Pre-flight

- Read `silver-bullet.md`, `.silver-bullet.json`, and the current planning state.
- Confirm Graphify and core SB hooks are available when the project requires them.
- Determine whether the request is trivial, simple, fuzzy, complex, UI-focused,
  bugfix-focused, or release-focused.

### 1. Spec and clarification

- Use `/silver:clarify` when scope, tradeoffs, or user intent are unclear.
- Use `/silver:spec` when requirements need a canonical `SPEC.md` and
  `REQUIREMENTS.md` before implementation.
- Use `/silver:ingest` when source artifacts need to be pulled into the spec.
- Resolve `silver:validate` BLOCK findings before implementation proceeds.

### 2. Context

Run `/silver:context`.

Context captures locked decisions, assumptions, constraints, available source
artifacts, and implementation boundaries. It produces the context the planner
uses; do not edit protected `.planning/` lifecycle artifacts directly.

### 3. Pre-plan quality gates

Run `/silver:quality-gates` before planning. All applicable dimensions must pass:
modularity, reusability, scalability, security, reliability, usability,
testability, extensibility, and conditional AI/LLM safety.

### 4. Plan

Run `/silver:plan`.

The plan must include task waves, acceptance criteria, test strategy, dependency
ordering, rollback considerations, review expectations, and verification steps.
If the plan exposes unresolved assumptions, return to `/silver:context`.

### 5. Execute

Run `/silver:execute`.

For behavior-changing code, the SB TDD gate runs before implementation. Use
`silver:execute --tdd` when the plan requires red/green/refactor discipline.
Use ordinary `silver:execute` for docs-only, config-only, or pure layout tasks
where TDD does not apply.

Execution must produce atomic commits or clearly grouped changes and update the
relevant summary artifacts.

### 6. Review

Run the SB review sequence:

1. `/silver:review-request`
2. `/silver:review`
3. `/silver:review-triage`

Review loops must continue until two consecutive clean passes or an explicit
deferred item is captured with `/silver:add`. Do not silently drop accepted
findings.

### 7. Verify

Run `/silver:verify`.

Verification is non-skippable. It checks tests, acceptance criteria, artifacts,
UAT evidence, and regression risk. Run `/verify-tests` after the last source
change and before PR creation, deployment, or release.

If verification identifies test coverage gaps, add the missing tests through the
SB test-gap path and re-run verification.

### 8. Security and validation

- Run `security` for an independent security review when the change has security
  surface, auth surface, data handling, dependency, or deployment impact.
- Run `/silver:secure` for threat mitigation verification.
- Run `/silver:validate` when spec/plan/UAT coverage needs another consistency
  pass.

### 9. Pre-ship quality gates

Run `/silver:quality-gates` again after execution, verification, review, and
security-sensitive checks. This pass is non-skippable for non-trivial work.

### 10. Documentation

Run `/silver:ensure-docs` when code, behavior, operations, public docs, or
release surfaces changed.

At minimum, keep the changelog, durable docs, monthly knowledge/learnings files,
and task doc checklist current where the project doc scheme requires them.
Record durable project facts in `docs/knowledge/YYYY-MM.md` and reusable lessons
in `docs/learnings/YYYY-MM.md`.

### 11. Branch finish

Run `/silver:branch-finish` on feature branches. This step is skipped on
`main`/`master` because there is no feature branch to finish.

### 11b. Completion audit

Run `/silver:completion-audit` before ship. This gate independently verifies
required skills, artifact substance, and delivery readiness markers.

### 12. CI and ship

- Run `/verify-tests`.
- Check CI. If CI is red, run `/silver:debug`, fix, re-run tests, and re-check CI.
- Run `/silver:ship` for phase-level PR/merge preparation.

`silver:ship` is a phase-level action. It is not a milestone release.

### 13. Release when requested

Run `/silver:release` only for milestone-level publish/release intent. The
release workflow owns UAT audit, milestone audit, security hard gate, docs
readiness, fresh tests, `silver:ship`, milestone archival, and
`/silver:create-release`.

## Non-Skippable Gates

- `/silver:completion-audit` immediately before ship
- `/silver:quality-gates` before planning and before ship
- `/silver:verify`
- `/verify-tests` before PR, deploy, or release
- `/silver:review` and `/silver:review-triage`
- `/silver:secure` when security-sensitive behavior exists
- `/silver:release` gates before milestone publication

## Optional Extension Plugins

Optional plugins may extend SB when they add domain capability, such as provider
DevOps checks, browser verification, GitHub operations, docs/spreadsheet/deck
generation, or explicit multi-agent research. They do not replace SB context,
plan, execute, verify, review, ship, or release ownership.

## Legacy Compatibility

Old GSD/Superpowers/Anthropic marker names may appear in existing project state
or migration tools. Hooks may count those markers as aliases for SB-owned
markers, but new workflow instructions must not invoke the old lifecycle
commands unless the user explicitly asks to run an external legacy plugin.
