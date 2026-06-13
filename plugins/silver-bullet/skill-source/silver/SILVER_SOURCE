---
name: silver
title: "Router"
description: This skill should be used to route most non-trivial freeform user intent to the right Silver Bullet workflow or optional external enrichment skill automatically
argument-hint: "<description of what you want to do>"
version: 0.2.0
---

# /silver — Smart Skill Orchestrator

Smart orchestrator for Silver Bullet. Accepts freeform natural language and routes to:

- an SB workflow skill that composes atomic flows;
- an SB ad-hoc utility skill;
- an optional external plugin only when the user explicitly asks for that plugin or the selected SB workflow marks it optional.

Never does implementation itself. Match intent, show the routing decision, then invoke the chosen skill.

## Core Positioning

SB is the lifecycle and quality orchestration engine for software-engineering work. It owns routing, composition, context, plans, execution gates, reviews, safety checks, verification, and ship/release decisions.

The useful lifecycle and knowledge-work behaviors SB explicitly depends on are owned by SB skills:

- `silver:context`, `silver:plan`, `silver:execute`, `silver:verify`, and `silver:ship`;
- `silver:review-request`, `silver:review`, and `silver:review-triage`;
- `silver:secure`, `silver:validate`, `silver:debug`, `silver:ui-contract`, and `silver:ui-review`;
- `silver:domain-audit` for specialized code, test, API, data, dependency, performance, structure, CI, environment, accessibility, content/search, UI, architecture, runtime, incident, retro, and benchmark quality contracts;
- `silver:test`, `silver:refactor`, `silver:worktree`, `silver:deploy`, `silver:canary`, `silver:incident`, `silver:retro`, `silver:benchmark`, and `silver:content` for SB-owned specialized workflows that remain attached to the lifecycle evidence chain;
- `tdd`, `silver:completion-audit`, and `silver:branch-finish`.

If user intent implies a semver-relevant codebase change, route through an SB workflow. Do not edit version, ROADMAP, STATE, MILESTONES, or phase artifacts directly except through the owning SB workflow and documented override gates.

## Skill Namespace Rules

Use logical route names in decisions (`silver:feature`, `silver:plan`, `tdd`). At invocation time, use the skill name exposed by the current host:

- Claude-style slash/skill aliases may expose `silver:feature`.
- Codex exposes SB skills through the native `/Silver:` picker surface, with logical names such as `silver:feature`.
- Source repos may show authoring names such as `silver-feature`.

When a workflow says to invoke another SB skill, use the active runtime's
SB-recognized skill invocation channel. In Claude Code this may be a host skill
event. In Codex this may be the native skill picker or the SB
`silver-bullet invoke-skill <name>` adapter when an invocation receipt is
required. If the host has no callable skill tool, load the target skill's
instructions and follow them directly, then record degraded invocation evidence
only when the workflow gate cannot observe a receipt.

If the exact logical skill is unavailable, choose the host-equivalent skill with the same semantic name.

If no equivalent exists, follow the missing SB skill protocol before any fallback:

1. Identify the missing SB skill and whether it should be packaged in the current SB installation.
2. Use the current host's SB update/install mechanism when available.
3. If automatic repair is not available, show the exact SB installer/update command and pause until the user confirms it has run.
4. Re-run discovery and retry the original skill invocation.
5. Continue without the skill only when the workflow marks it optional, the repair attempt failed, or the user explicitly declines repair; record that degraded path in the work notes or generated artifact.

Do not silently replace a missing SB lifecycle skill with shell work, direct edits, or a weaker workflow.

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
| Status-only | "what branch?", "where are we?", "what changed?" | Answer from local state; route to an SB status/progress workflow when persistent project status is needed |
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
| "add", "build", "implement", "new feature", "enhance", "extend" | `silver:feature` | Core dev path; SB owns context/plan/execute/verify |
| "bug", "broken", "crash", "error", "regression", "failing test", "not working" | `silver:bugfix` | Bugfix path; SB debug/plan/execute/verify plus TDD |
| "write tests", "add tests", "generate tests", "E2E", "Playwright", "fix tests", "test audit", "mutation", "slow tests", "test performance" | `silver:test` | SB-owned test engineering; feeds `test-health`, `verify-tests`, and `silver:verify` |
| "refactor", "rename", "split", "extract", "move files", "simplify", "untangle" | `silver:refactor` | Behavior-preserving change path with baseline proof |
| "worktree", "isolated branch", "branch workspace", "finish worktree", "cleanup worktree" | `silver:worktree` | Git isolation and structured finish path |
| "UI", "frontend", "component", "screen", "design", "interface", "page", "layout", "animation", "responsive" | `silver:ui` | UI-specific composition |
| "infra", "CI/CD", "pipeline", "terraform", "IaC", "kubernetes", "container", "cloud", "ops" | `silver:devops` | Infra/DevOps composition |
| "deploy", "deployment", "roll out", "production deploy", "staging deploy" | `silver:deploy` | Deployment orchestration; invokes DevOps/release gates as needed |
| "canary", "post-deploy", "production watch", "health watch", "runtime watch" | `silver:canary` | Post-deploy runtime confidence gate |
| "incident", "outage", "production regression", "postmortem", "customer-impacting failure" | `silver:incident` | Incident response and corrective action path |
| "retro", "retrospective", "release metrics", "delivery metrics", "process review" | `silver:retro` | Engineering retrospective path |
| "benchmark", "compare agents", "compare models", "provider comparison", "agent quality" | `silver:benchmark` | Repeatable evaluation and adversarial benchmark path |
| "content", "SEO", "GEO", "AI search", "article", "blog", "migration", "metadata", "link health" | `silver:content` | Public content/search workflow; docs governance still uses `silver:ensure-docs` |
| "I want to build", "I have an idea", "here's my concept", multi-sentence idea with no SPEC.md | `silver:clarify` | Shape before implementation; merged PM framing and structured brainstorming |
| "spec", "requirements", "elicit", "write a spec", "create spec", "define requirements", "what should we build" | `silver:spec` | Requirements/spec elicitation |
| "how should we", "which technology", "compare", "spike", "investigate", "architecture decision", "should we use", "best approach" | `silver:research` | Research/decision artifact, then handoff |
| "release", "publish", "version", "go live", "cut a release", "tag v", "ship to users" | `silver:release` | Milestone-level only |
| "merge this", "push this PR", "ship this feature" with active phase context and no version signal | `silver:ship` | Phase-level ship |
| "where are we", "what's left", "show progress", "current status" | SB status/progress path | Read SB planning state and workflow trackers |
| "pick up", "resume", "continue where", "next step" | `silver:handoff` or active SB workflow | Resume from SB state and handoff artifacts |
| "handoff", "wrap up session", "continue later", "session summary" | `silver:handoff` | SB project-level continuation prompt |
| "set up", "initialize", "install Silver Bullet", "configure project" | `silver:init` | First-time setup/update |
| "doc scheme", "ensure docs", "docs checklist", "docs gate failed", "reconcile docs", "recover doc scheme" | `silver:ensure-docs` | Doc governance authority |
| "quality review", "ilities", "architecture review", "quality dimensions" | `silver:quality-gates` | Ad-hoc quality audit |
| "API audit", "database audit", "dependency audit", "performance audit", "structure audit", "CI audit", "environment audit", "SEO", "AI search", "content audit", "accessibility audit", "canary", "incident", "retro", "benchmark", "domain audit" | `silver:domain-audit` | Specialized quality contract packs; feeds findings back into the owning SB workflow |
| "blast radius", "change impact", "rollback plan" | `silver:blast-radius` | Ad-hoc risk assessment |
| "IaC quality", "devops quality", "terraform quality" | `devops-quality-gates` | DevOps quality audit |
| "root cause", "session failed", "what broke", "reconstruct" | `silver:forensics` | Evidence-based post-mortem |
| "release notes", "github release", "cut release", "tag release" | `silver:create-release` | Release artifact creation inside release flow |
| "run tests", "verify tests", "test suite", "rerun tests", "fresh tests" | `verify-tests` | Fresh test gate |
| "which IaC tool", "terraform vs pulumi", "which cloud skill" | `devops-skill-router` | IaC routing |
| "ingest", "import", "jira", "figma", "pull ticket", "cross-repo", "fetch spec from" | `silver:ingest` | External artifact ingestion |
| Any explicit legacy lifecycle request | SB equivalent unless the user explicitly requires an external plugin | Examples: plan phase -> `silver:plan`, execute phase -> `silver:execute`, verify -> `silver:verify`, ship -> `silver:ship` |

### Step 5: Apply ship/release disambiguation

| Signal | Route |
|--------|-------|
| Contains semantic version (`v2.0`, `1.4.0`, `major`, `minor`, `patch`) | `silver:release` or SB milestone setup |
| Contains "changelog" or "release notes" | `silver:release` |
| Contains "go live", "to production", "to users", "publicly" | `silver:release` |
| Active phase in progress, no version signal | `silver:ship` for phase-level ship |
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
| Legacy lifecycle signal + SB domain signal | SB workflow | SB owns the lifecycle; legacy names are compatibility aliases |

### Step 7: Compose or delegate

Each `silver:*` workflow is a composition template over the canonical atomic flow catalog in `docs/composable-flows-contracts.md`:

`BOOTSTRAP -> ORIENT -> CLARIFY -> DECIDE -> SPECIFY -> PLAN -> DESIGN CONTRACT -> EXECUTE -> UI QUALITY -> REVIEW -> SECURE -> VERIFY -> QUALITY GATE -> SHIP -> DEBUG -> DESIGN HANDOFF -> DOCUMENT -> RELEASE`

Composition rules:

- Include only flows whose prerequisites and triggers apply.
- Prefer smaller atomic flows over large bundled steps.
- Keep PLAN, EXECUTE, VERIFY, SHIP, milestone audit, and semver work inside SB-owned skills.
- Insert DEBUG dynamically on execution, test, CI, or verification failure.
- Insert UI QUALITY only when UI artifacts or UI scope exists.
- Insert DOCUMENT and RELEASE only for milestone/release work, not every phase.
- Record composed workflow state with the resolved `workflows.sh` helper from the project or installed plugin.

### Step 8: Handle ambiguity

If two or more destinations have similar confidence and the consequence is material, ask the user to choose:

> I can route this two ways. Which best matches your intent?
>
> A. `silver:feature` — compose SB quality/review gates around SB implementation
> B. SB lifecycle step — route directly to `silver:context`, `silver:plan`, `silver:execute`, `silver:verify`, or `silver:ship`
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
SB role:    {lifecycle authority / optional external enrichment / not applicable}
```

### Step 10: Invoke chosen skill

- For SB workflow or utility skills: invoke the chosen SB skill with `$ARGUMENTS`.
- For explicit legacy lifecycle requests: route to the SB equivalent by default. Invoke an external plugin only when the user explicitly requires it and it is available.
- For optional dependency-plugin skills inside a composed flow: invoke them only when available and relevant; otherwise continue only if the flow contract marks them optional.

Security note: `/silver` only routes to the skills explicitly listed in this router or in the canonical flow contracts. The forbidden-skill gate enforces tool-layer deny lists independently.
