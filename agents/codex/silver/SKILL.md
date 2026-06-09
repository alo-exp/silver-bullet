---
name: silver
title: "Router"
description: This skill should be used to route most non-trivial freeform user intent to the right Silver Bullet workflow or GSD skill automatically
argument-hint: "<description of what you want to do>"
version: 0.2.0
---

# /silver — Smart Skill Orchestrator

Smart orchestrator for Silver Bullet. Accepts freeform natural language and routes to:

- an SB workflow skill that composes atomic flows;
- an SB ad-hoc utility skill;
- `gsd:do` for GSD-owned lifecycle operations.

Never does implementation itself. Match intent, show the routing decision, then invoke the chosen skill.

## Core Positioning

SB enhances GSD peripherally. It adds routing, composition, contracts, quality gates, reviews, safety checks, and cross-plugin orchestration. It does not replace GSD's core lifecycle.

GSD remains the lifecycle authority for:

- semver, milestone, and phase management;
- requirements, roadmap, state, plans, execution summaries, verification, and shipping artifacts;
- bug fixing, testing, validation, code review, and release readiness when those activities touch project work;
- any change that can lead to a major, minor, or patch release.

If user intent implies a semver-relevant codebase change, route through an SB workflow that invokes GSD phases, or delegate directly to `gsd:do`. Do not edit version, ROADMAP, STATE, MILESTONES, or phase artifacts directly except through the owning GSD workflow and documented override gates.

## Skill Namespace Rules

Use logical route names in decisions (`silver:feature`, `gsd:do`, `tdd`, `product-management:write-spec`). At invocation time, use the skill name exposed by the current host:

- Claude-style slash/skill aliases may expose `silver:feature` and `gsd:do`.
- Codex exposes SB skills through the native `/Silver:` picker surface, with logical names such as `silver:feature`.
- Source repos may show authoring names such as `silver-feature`.

If the exact logical skill is unavailable, choose the host-equivalent skill with the same semantic name.

If no equivalent exists, follow the missing dependency protocol before any fallback:

1. Identify the missing skill and its owning plugin or marketplace source.
2. Use the current host's plugin installation/update mechanism when available.
3. If automatic install is not available, show the exact install command or SB installer/update command and pause until the user confirms it has run.
4. Re-run discovery and retry the original skill invocation.
5. Continue without the skill only when the workflow marks it optional, the install/repair attempt failed, or the user explicitly declines installation; record that degraded path in the work notes or generated artifact.

Do not silently replace a missing dependency with shell work, direct edits, or a weaker workflow.

## Process

### Step 1: Capture input

If `$ARGUMENTS` is empty, ask:

> What would you like to do?

Wait for response, then proceed.

### Step 2: Identify direct-answer exceptions

Do not force workflow routing for:

| Exception | Examples | Action |
|-----------|----------|--------|
| Q&A | "what is SB?", "explain this file", "do you agree?" | Answer directly or inspect/read as needed |
| Status-only | "what branch?", "where are we?", "what changed?" | Route to `gsd:do` only if persistent project status is needed |
| Truly trivial local request | typo, comment, formatting, config value, <=3 files, no logic | Route to `silver:fast` |

For almost every other bare user message, route through this skill. In other words, most non-trivial bare user intent belongs in `/silver`. Bias toward SB composition when the user asks to build, fix, improve, audit, release, research, ingest, document, validate, or continue project work.

### Step 3: Classify complexity

Run complexity triage before domain routing:

| Classification | Signals | Action |
|----------------|---------|--------|
| Trivial | typo, comment, rename, config value, <=3 files, no logic/schema/API change | `silver:fast` |
| Simple | clear scope, one phase, known implementation path | domain workflow without mandatory CLARIFY unless the workflow requires it |
| Complex | multi-phase, cross-cutting, schema/API/public behavior, release impact | domain workflow with CLARIFY and DECIDE flows |
| Fuzzy | vague goal, uncertain outcome, "help me think", unclear scope | `silver:clarify`, then re-classify |

### Step 4: Route by intent

First strong match wins after complexity triage and conflict resolution.

| User intent signals | Route to | Notes |
|---------------------|----------|-------|
| "what if", "I'm thinking about", "not sure how to", "help me think", unclear goal | `silver:clarify` | Fuzzy intent first |
| "add", "build", "implement", "new feature", "enhance", "extend" | `silver:feature` | Core dev path; GSD owns plan/execute/verify |
| "bug", "broken", "crash", "error", "regression", "failing test", "not working" | `silver:bugfix` | Bugfix path; GSD debug/plan/execute/verify plus TDD |
| "UI", "frontend", "component", "screen", "design", "interface", "page", "layout", "animation", "responsive" | `silver:ui` | UI-specific composition |
| "infra", "CI/CD", "deploy", "pipeline", "terraform", "IaC", "kubernetes", "container", "cloud", "ops" | `silver:devops` | Infra/DevOps composition |
| "I want to build", "I have an idea", "here's my concept", multi-sentence idea with no SPEC.md | `silver:clarify` | Shape before implementation; merged PM framing + Superpowers brainstorming |
| "spec", "requirements", "elicit", "write a spec", "create spec", "define requirements", "what should we build" | `silver:spec` | Requirements/spec elicitation |
| "how should we", "which technology", "compare", "spike", "investigate", "architecture decision", "should we use", "best approach" | `silver:research` | Research/decision artifact, then handoff |
| "release", "publish", "version", "go live", "cut a release", "tag v", "ship to users", "deploy to prod" | `silver:release` | Milestone-level only |
| "merge this", "push this PR", "ship this feature" with active phase context and no version signal | `gsd:do` | Let GSD choose `gsd:ship` |
| "where are we", "what's left", "show progress", "current status" | `gsd:do` | Let GSD choose progress/resume/next |
| "pick up", "resume", "continue where", "next step" | `gsd:do` | Let GSD choose resume/next |
| "handoff", "wrap up session", "continue later", "session summary" | `silver:handoff` | SB project-level continuation prompt |
| "set up", "initialize", "install Silver Bullet", "configure project" | `silver:init` | First-time setup/update |
| "doc scheme", "ensure docs", "docs checklist", "docs gate failed", "reconcile docs", "recover doc scheme" | `silver:ensure-docs` | Doc governance authority |
| "quality review", "ilities", "architecture review", "quality dimensions" | `silver:quality-gates` | Ad-hoc quality audit |
| "blast radius", "change impact", "rollback plan" | `silver:blast-radius` | Ad-hoc risk assessment |
| "IaC quality", "devops quality", "terraform quality" | `devops-quality-gates` | DevOps quality audit |
| "root cause", "session failed", "what broke", "reconstruct" | `silver:forensics` | Evidence-based post-mortem |
| "release notes", "github release", "cut release", "tag release" | `silver:create-release` | Release artifact creation inside release flow |
| "run tests", "verify tests", "test suite", "rerun tests", "fresh tests" | `verify-tests` | Fresh test gate |
| "which IaC tool", "terraform vs pulumi", "which cloud skill" | `devops-skill-router` | IaC routing |
| "ingest", "import", "jira", "figma", "pull ticket", "cross-repo", "fetch spec from" | `silver:ingest` | External artifact ingestion |
| Any explicit GSD lifecycle request | `gsd:do` | Examples: add phase, plan phase, execute phase, verify, validate, debug, quick, semver, milestone |

### Step 5: Apply ship/release disambiguation

| Signal | Route |
|--------|-------|
| Contains semantic version (`v2.0`, `1.4.0`, `major`, `minor`, `patch`) | `silver:release` or `gsd:do` for milestone setup |
| Contains "changelog" or "release notes" | `silver:release` |
| Contains "go live", "to production", "to users", "publicly" | `silver:release` |
| Active phase in progress, no version signal | `gsd:do` for phase-level ship |
| No active phase and milestone appears complete | `silver:release` |

### Step 6: Resolve conflicts

| Conflict | Winner | Rationale |
|----------|--------|-----------|
| `silver:bugfix` + any other | `silver:bugfix` | Broken things block everything |
| `silver:research` + implementation | `silver:research` first | Research informs implementation |
| `silver:spec` + `silver:feature` | `silver:spec` first | Spec before implementation |
| `silver:ui` + `silver:feature` | `silver:ui` | UI is more specific |
| `silver:devops` + `silver:feature` | Ask user | App vs infra boundary is material |
| `silver:fast` + domain workflow | Prefer higher rigor if logic/schema/API/public behavior is involved | Avoid under-scoping |
| GSD lifecycle signal + SB domain signal | SB workflow if orchestration is needed; otherwise `gsd:do` | SB composes, GSD executes lifecycle |

### Step 7: Compose or delegate

Each `silver:*` workflow is a composition template over the canonical atomic flow catalog in `docs/composable-flows-contracts.md`:

`BOOTSTRAP -> ORIENT -> CLARIFY -> DECIDE -> SPECIFY -> PLAN -> DESIGN CONTRACT -> EXECUTE -> UI QUALITY -> REVIEW -> SECURE -> VERIFY -> QUALITY GATE -> SHIP -> DEBUG -> DESIGN HANDOFF -> DOCUMENT -> RELEASE`

Composition rules:

- Include only flows whose prerequisites and triggers apply.
- Prefer smaller atomic flows over large bundled steps.
- Keep PLAN, EXECUTE, VERIFY, SHIP, milestone audit, and semver work inside GSD-owned skills.
- Insert DEBUG dynamically on execution, test, CI, or verification failure.
- Insert UI QUALITY only when UI artifacts or UI scope exists.
- Insert DOCUMENT and RELEASE only for milestone/release work, not every phase.
- Record composed workflow state with the resolved `workflows.sh` helper from the project or installed plugin.

### Step 8: Handle ambiguity

If two or more destinations have similar confidence and the consequence is material, ask the user to choose:

> I can route this two ways. Which best matches your intent?
>
> A. `silver:feature` — compose SB quality/review gates around GSD implementation
> B. `gsd:do` — let GSD choose the exact lifecycle command
> C. `silver:research` — produce a decision artifact before implementation
> D. Something else — describe the target

If the consequence is not material, choose the safer higher-rigor route and state the assumption.

### Step 9: Show routing banner

Before invoking the chosen skill, always display:

```text
SILVER BULLET ► ROUTING

Input:      {first 80 chars of user input}
Routing to: {chosen skill}
Reason:     {one sentence explaining the match}
GSD role:   {lifecycle authority / delegated / not applicable}
```

### Step 10: Invoke chosen skill

- For SB workflow or utility skills: invoke the chosen SB skill with `$ARGUMENTS`.
- For GSD delegation: invoke `gsd:do` with the original `$ARGUMENTS`; do not hand-route to individual GSD commands unless the user explicitly named the exact GSD skill.
- For optional dependency-plugin skills inside a composed flow: invoke them only when available and relevant; otherwise continue only if the flow contract marks them optional.

Security note: `/silver` only routes to the skills explicitly listed in this router or in the canonical flow contracts. The forbidden-skill gate enforces tool-layer deny lists independently.
