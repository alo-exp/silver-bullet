# GSD vs. Silver Bullet — When To Use What

Silver Bullet (SB) and Get Shit Done (GSD) are complementary, not competing, plugins. This doc explains how they relate, what each provides, and what works without the other.

> **Status:** First-pass written 2026-04-28 closing #73. Treat as living documentation; corrections welcome.

## TL;DR

| Question | Answer |
|---|---|
| Is GSD a hard dependency of SB? | **No.** Most SB features work standalone. Flow skills (`silver:feature`, `silver:bugfix`, `silver:ui`, `silver:devops`) call into GSD internally and require it; ad-hoc enforcement (hooks, `silver:init`, `silver:add`, `silver:rem`, `silver:scan`) does not. |
| Can you use GSD without SB? | **Yes.** GSD is a complete planning/execution toolkit on its own. SB adds enforcement on top. |
| Recommended combo? | **GSD + SB + Superpowers**, all installed. This is what `silver:init` assumes and what every flow skill is composed against. |

## What Each Provides

### Get Shit Done (GSD)

GSD is a planning- and execution-discipline toolkit. It owns:

- The `.planning/` directory and its artifact structure (PROJECT.md, ROADMAP.md, REQUIREMENTS.md, STATE.md, MILESTONES.md, phases, plans)
- The phase / plan model (numbered phases, atomic-commit plans, dependency tracking)
- Subagents that produce specific artifacts (`gsd-roadmapper`, `gsd-planner`, `gsd-executor`, `gsd-verifier`, `gsd-doc-writer`, etc.)
- Slash commands (`/gsd-new-project`, `/gsd-new-milestone`, `/gsd-plan-phase`, `/gsd-execute-phase`, …)

GSD is the **what / how / when** layer. It tracks what to build, how to break it down, and the order to do it in.

### Silver Bullet (SB)

SB is an enforcement and orchestration layer that sits on top of GSD. It owns:

- The Claude Code **hook layer**: PostToolUse / PreToolUse / SessionStart / Stop hooks that gate commits, releases, and conversation-end on required-skill discipline
- **Composed-workflow tracking**: per-instance `.planning/workflows/<id>.md` files plus the `SB_WORKFLOW_ID` strict gate that refuses delivery until every flow row is `complete`
- **Flow skills** (`silver:feature`, `silver:bugfix`, `silver:ui`, `silver:devops`, `silver:research`, `silver:release`, `silver:fast`) — orchestrators that sequence GSD commands, Superpowers skills, and quality skills into a single named workflow
- **Item-capture skills** (`silver:add`, `silver:remove`, `silver:rem`, `silver:scan`) for tracking deferred items, knowledge, and lessons across sessions
- **Quality skills** (`silver:quality-gates`, `silver:blast-radius`, `silver:devops-quality-gates`)
- **Pre-release quality gate** (4 stages: code review → TDD → quality gates → final verify)

SB is the **make sure it actually happens** layer. It doesn't generate the plan or run the work — it ensures the plan was followed.

## Artifact Mapping (GSD → SB equivalent)

| GSD artifact | SB equivalent / interaction |
|---|---|
| `.planning/PROJECT.md` | Read, not written by SB. SB's `silver:init` does NOT clobber. |
| `.planning/ROADMAP.md` | Read, not written by SB. Used by `silver:release` to scope what's shipping. |
| `.planning/REQUIREMENTS.md` | Read, not written by SB. |
| `.planning/STATE.md` | Read, not written by SB. SB's own state is at `~/.claude/.silver-bullet/state` — it is per-user, branch-scoped, and ephemeral, not a replacement for STATE.md. |
| `.planning/MILESTONES.md` | Updated by GSD; SB's `silver:release` cross-checks the latest entry against the release-tag version. |
| `.planning/phases/<N>/PLAN.md` | Read, not written by SB. |
| `.planning/phases/<N>/REVIEW.md` | Used by `gsd-code-review-fix` and SB's `silver:release` Stage 1. |
| (none in GSD) | `.planning/workflows/<id>.md` — SB-owned, per-instance composed-workflow tracker. Gitignored. |
| (none in GSD) | `.planning/seeds/SEED-NNN-*.md` — SB-owned planted-seed files for deferred ideas. |

GSD owns persistent project memory; SB owns runtime enforcement and ephemeral session memory.

## State Overlap

There are **two** state files involved when you run a GSD-driven SB-enforced workflow:

1. **`.planning/STATE.md`** — written by GSD. Project-scoped, persistent, committed to the repo. Tracks current phase, plan progress, milestone status. Survives `/clear`, `/compact`, and machine restarts.
2. **`~/.claude/.silver-bullet/state`** — written by SB hooks. User-scoped (lives outside the repo), branch-scoped, ephemeral. Tracks which skills have been invoked in the current session for enforcement-gate purposes. Reset on branch change, on `/clear`, and on `startup` events. Never commits to a repo.

These two files do not duplicate each other. GSD's STATE.md says "Phase 76 in progress, Plan 76.3 next." SB's state says "the user invoked `silver-quality-gates` and `code-review` in this session." Both pieces of information are needed; neither replaces the other.

## What Works Without Each Component

### SB without GSD

Mostly works. Available skills:
- `silver:init`, `silver:fast`, `silver:add`, `silver:remove`, `silver:rem`, `silver:scan`
- All hooks (state file gating, plugin-boundary blocks, trivial bypass, etc.)
- Pre-release quality gate stages (you provide a phase plan some other way)

Disabled / error-on-invoke:
- `silver:feature`, `silver:bugfix`, `silver:ui`, `silver:devops`, `silver:research` — these compose `gsd-discuss-phase` / `gsd-plan-phase` / `gsd-execute-phase` and require GSD installed.
- `silver:release` — requires `.planning/MILESTONES.md` and the GSD planning artifacts.

### GSD without SB

Fully works. You lose:
- Hook-level enforcement of required skills before commits / releases
- The `silver:*` flow skills that orchestrate multi-step workflows
- Composed-workflow tracking and the strict `SB_WORKFLOW_ID` delivery gate
- Pre-release quality gate as a structured 4-stage process

You can still run GSD's own `/gsd-new-project`, `/gsd-plan-phase`, `/gsd-execute-phase` etc. as standalone commands.

## Migration Paths

### From GSD-only to GSD + SB

```bash
# Install the SB plugin
claude plugin install silver-bullet@alo-labs

# Initialize SB enforcement in your project
/silver:init
```

`silver:init` detects existing GSD artifacts and adds SB enforcement on top — it does NOT rewrite or overwrite the GSD artifact files.

### From SB-only to GSD + SB

```bash
# Install GSD
npx get-shit-done-cc@latest

# Bootstrap GSD planning artifacts
/gsd-new-project   # if no .planning/ exists yet
# OR
/gsd-resume-work   # if .planning/ exists from a prior GSD checkout
```

After GSD is installed, the previously-disabled `silver:*` flow skills become available without further configuration.

## See Also

- `silver-bullet.md` — runtime contract and §10 user preferences
- `docs/composable-flows-contracts.md` — flow definitions used by the flow skills
- GitHub issue #73 (this doc closes it)
- GitHub issue #74 (companion: SB-only install path on the homepage and README)
