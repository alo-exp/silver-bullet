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

Never does implementation itself. Match intent, show the routing decision, then **spawn a Task worker** (parent mode) or invoke the composer skill to seed the queue.

## Parent orchestrator mode (default)

When `orchestrator_mode` is `parent` in `.silver-bullet.json` (the only supported mode):

1. Invoke **`silver-orchestrator`** at session start or for `/silver` routing — do not execute flow atoms inline.
2. Composer skills (`silver-feature`, `silver-ui`, …) are **queue builders**; the parent spawns workers per `orchestrator-directive.json`.
3. Read `next_worker_template` + `next_skill` from the directive; load `.silver-bullet/orchestrator-workers/<TEMPLATE>.md` for each Task prompt.

Cooperative single-agent execution (parent invokes `silver:plan` / `silver:execute` directly) is **disabled**.

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
| Pure Q&A (no implementation) | "what is SB?", "explain this file", "do you agree?" | Answer directly or inspect/read as needed |
| Status-only | "what branch?", "where are we?", "what changed?" | Answer from local state; route to an SB status/progress workflow when persistent project status is needed |
| Truly trivial local request | typo, comment, formatting, config value, <=3 files, no logic | Route to `silver:fast` |

**Narrowing (H-05):** If the user asks how to fix, debug, or change behavior ("why does X fail?", "how do I fix Y?"), route to `silver:bugfix` or `silver:clarify` — not the Q&A exception. Only pure explanation with no expected code change qualifies as Q&A.

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
| "visual mockup", "browser mockup", "show in browser", "visual companion", "compare UI options", "sketch UI" | `silver:clarify` (+ browser evidence per §8.1) | Visual brainstorming; Alumnium preferred, host browser MCP fallback; see `silver-bullet.md §8.1` |
| "add", "build", "implement", "new feature", "enhance", "extend" | `silver:feature` | Core dev path; SB owns context/plan/execute/review/verify/secure |
| "bug", "broken", "crash", "error", "regression", "failing test", "not working" | `silver:bugfix` | Bugfix path; SB debug/plan/execute/review/verify/secure plus TDD |
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
| "content", "SEO", "GEO", "AI search", "article", "blog", "site content", "metadata", "link health" | `silver:content` | Public content/search workflow; **not** SB project upgrade (use `silver:migrate`) |
| "site/", "help center", "help-center", "homepage", "sb.alolabs.dev", "github pages", "site/help", "chrome.css", "help page", "OG card", "publish site", "site publish" | `silver:content --mode fix` | **Default route** for public site/help work — use site batch protocol (Composer 2.5 workers) |
| "I want to build", "I have an idea", "here's my concept", multi-sentence idea with no SPEC.md | `silver:clarify` | Shape before implementation; merged PM framing and structured brainstorming |
| "spec", "requirements", "elicit", "write a spec", "create spec", "define requirements", "what should we build" | `silver:spec` | Requirements/spec elicitation |
| "how should we", "which technology", "compare", "spike", "investigate", "architecture decision", "should we use", "best approach" | `silver:research` | Research/decision artifact, then handoff |
| "release", "publish", "version", "go live", "cut a release", "tag v", "ship to users" | `silver:release` | Milestone-level only |
| "merge this", "push this PR", "ship this feature" with active phase context and no version signal | `silver:ship` | Phase-level ship |
| "where are we", "what's left", "show progress", "current status" | SB status/progress path | Read SB planning state and workflow trackers |
| "pick up", "resume", "continue where", "next step" | `silver:handoff` or active SB workflow | Resume from SB state and handoff artifacts |
| "handoff", "wrap up session", "continue later", "session summary" | `silver:handoff` | SB project-level continuation prompt |
| "set up", "initialize", "install Silver Bullet", "configure project" | `silver:init` | First-time setup/update |
| "migrate", "upgrade SB", "upgrade Silver Bullet", "adopt Silver Bullet", "switch to Silver Bullet" | `silver:migrate` | Brownfield contract upgrade — not content/site migration |
| "update Silver Bullet", "check for updates", "SB version" | `silver:update` | Plugin/version update check |
| "scan codebase", "map codebase", "codebase intel" | `silver:scan` | Codebase orientation |
| "doc scheme", "ensure docs", "docs checklist", "docs gate failed", "reconcile docs", "recover doc scheme" | `silver:ensure-docs` | Doc governance authority |
| "quality review", "ilities", "architecture review", "quality dimensions" | `silver:quality-gates` | Ad-hoc quality audit |
| "API audit", "audit my API", "check API contracts", "audit endpoints" | `silver:domain-audit --pack api-contract` | API integrity: status codes, input validation, pagination, auth, rate limiting |
| "database audit", "DB audit", "schema safety", "migration safety", "query audit" | `silver:domain-audit --pack data-contract` | Data layer: migration safety, rollback, indexes, concurrency |
| "dependency audit", "supply chain", "package vulnerabilities", "outdated packages", "license check" | `silver:domain-audit --pack dependency-supply` | Dependency health, CVEs, freshness, bundle weight |
| "performance audit", "performance review", "slow app", "latency audit", "bundle size" | `silver:domain-audit --pack performance-resource` | Full-stack performance: rendering, API, algorithms, memory |
| "accessibility audit", "a11y", "WCAG", "keyboard navigation", "screen reader", "color contrast" | `silver:domain-audit --pack accessibility` | WCAG 2.2 accessibility: keyboard, ARIA, contrast, forms |
| "CI audit", "GitHub Actions audit", "pipeline review", "slow CI" | `silver:domain-audit --pack ci-workflow` | CI/CD: caching, parallelism, secret use, action pinning |
| "env audit", "environment check", "secrets audit", "config parity" | `silver:domain-audit --pack environment-secrets` | Env completeness, secret exposure, parity, type safety |
| "structure audit", "codebase organization", "dead code", "duplication" | `silver:domain-audit --pack structure-maintainability` | Directory structure, naming, complexity, duplication |
| "architecture review", "ADR", "architecture decision", "design decision record" | `silver:domain-audit --pack architecture-adr` | ADR creation/review, alternatives, reversibility, coupling |
| "domain audit", "specialized audit" (no specific domain) | `silver:domain-audit` | Let pack selection happen interactively |
| "blast radius", "change impact", "rollback plan" | `silver:blast-radius` | Ad-hoc risk assessment |
| "IaC quality", "devops quality", "terraform quality" | `devops-quality-gates` | DevOps quality audit |
| "root cause", "session failed", "what broke", "reconstruct" | `silver:forensics` | Evidence-based post-mortem |
| "release notes", "github release", "cut release", "tag release" | `silver:create-release` | Release artifact creation inside release flow |
| "run tests", "verify tests", "test suite", "rerun tests", "fresh tests" | `verify-tests` | Fresh test gate |
| "which IaC tool", "terraform vs pulumi", "which cloud skill" | `devops-skill-router` | IaC routing |
| "ingest", "import", "jira", "figma", "pull ticket", "cross-repo", "fetch spec from" | `silver:ingest` | External artifact ingestion |
| "spike", "feasibility experiment", "try this approach", "prove it works before building", "is X possible before we commit" | `silver:spike` | Executable feasibility experiments with Given/When/Then and verdicts |
| "add phase", "insert phase", "remove phase", "edit phase", "phase list", "add to roadmap", "new phase in roadmap" | `silver:phase` | Phase CRUD in ROADMAP.md — sanctioned path to mutate the phase list |
| "undo phase", "revert phase", "roll back phase", "undo plan", "revert commits for phase" | `silver:undo` | Safe phase/plan git revert with dependency checks and artifact cleanup |
| "thread", "track this topic across sessions", "cross-session note", "track this concern" | `silver:thread` | Lightweight cross-session context threads for topic-specific tracking |
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

Each `silver:*` workflow is a composition template over the canonical atomic flow catalog in `docs/composable-flows-contracts.md`.

**Catalog flow order (not runtime gate order):**

`BOOTSTRAP → ORIENT → CLARIFY → DECIDE → SPECIFY → PLAN → DESIGN CONTRACT → EXECUTE → UI QUALITY → REVIEW → VERIFY → SECURE → VALIDATE → QUALITY GATE → SHIP → DEBUG → DESIGN HANDOFF → DOCUMENT → RELEASE`

**Runtime post-execution gate order (authoritative for delivery):** see `docs/composable-flows-contracts.md` §Post-execution sequencing — review triad → verify → security + secure → validate → pre-ship quality gate → branch-finish → completion-audit → ship.

**Full-software intent (Wave 0.7):** When the user wants an entire app/product built,
seed the orchestrator queue `silver-spec → silver-feature → silver-ship → silver-release`
(persisted in `$HOME/.codex/.silver-bullet/orchestrator.json`). Store the user prompt in
`$HOME/.codex/.silver-bullet/orchestrator-intent.txt` for hook consumption.

Composition rules:

- Include only flows whose prerequisites and triggers apply.
- Prefer smaller atomic flows over large bundled steps.
- Keep PLAN, EXECUTE, VERIFY, SHIP, milestone audit, and semver work inside SB-owned skills.
- Insert DEBUG dynamically on execution, test, CI, or verification failure.
- Insert UI QUALITY only when UI artifacts or UI scope exists.
- Insert DOCUMENT and RELEASE only for milestone/release work, not every phase.
- Record composed workflow state with the resolved `workflows.sh` helper from the project or installed plugin.

### Step 8: Handle ambiguity

**Decision taxonomy (Wave 0.5):** classify each ambiguity as:

| Class | When | Action |
|-------|------|--------|
| `blocking` | Material fork (app vs infra, ship vs release, irreversible choice) | Ask user (one question) |
| `autonomous_default` | Safe to assume higher rigor or first router match | Choose without prompt; log assumption |

Only ask the user when `decision_class: blocking`. Otherwise choose the safer higher-rigor route and state the assumption in one line.

If two or more destinations have similar confidence and the consequence is **blocking**, ask:

> I can route this two ways. Which best matches your intent?
>
> A. `silver:feature` — compose SB quality/review gates around SB implementation
> B. SB lifecycle step — route directly to `silver:context`, `silver:plan`, `silver:execute`, `silver:verify`, or `silver:ship`
> C. `silver:research` — produce a decision artifact before implementation
> D. Something else — describe the target

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
