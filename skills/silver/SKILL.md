---
name: silver
description: "Route freeform text to the right Silver Bullet or GSD skill automatically"
argument-hint: "<description of what you want to do>"
---

# /silver — Smart Skill Router

Smart dispatcher for Silver Bullet skills. Accepts freeform natural language and routes to the most appropriate SB skill — or delegates to /gsd:do for GSD commands.

Never does the work itself. Match intent, show routing decision, invoke the chosen skill.

## Process

### Step 1: Capture input

If `$ARGUMENTS` is empty, ask:

> What would you like to do?

Wait for response, then proceed.

### Step 2: Classify intent and complexity

**Complexity triage (run first):**

| Classification | Signals | Action |
|----------------|---------|--------|
| Trivial | Typo, config, rename, ≤3 files | Route to `silver:fast` (gsd-fast) — bypass workflow. Note: §10 routing preferences are NOT applied; silver:fast skips preference loading by design. |
| Simple | Clear scope, ≤1 phase | Route to workflow, skip silver:explore |
| Complex | Multi-phase, cross-cutting | Full workflow including silver:explore + brainstorm |
| Fuzzy | Vague intent, unclear scope | Route to `silver:explore` first, then re-classify |

**Full routing table (first match wins after complexity triage):**

| User intent signals | Route to | Notes |
|---------------------|----------|-------|
| "what if", "I'm thinking about", "not sure how to", "help me think" | `silver:explore` (gsd-explore) | Fuzzy — clarify first |
| "add X", "build X", "implement X", "new feature", "enhance X", "extend X" | `silver:feature` | Core dev path |
| "bug", "broken", "crash", "error", "regression", "failing test", "not working" | `silver:bugfix` | Triage internally |
| "UI", "frontend", "component", "screen", "design", "interface", "page", "layout", "animation", "responsive" | `silver:ui` | Includes mobile, web, design systems |
| "infra", "CI/CD", "deploy", "pipeline", "terraform", "IaC", "kubernetes", "container", "cloud", "ops" | `silver:devops` | Includes containers, networking, monitoring |
| "spec", "requirements", "elicit", "write a spec", "create spec", "define requirements", "what should we build" | `silver:spec` | AI-guided spec elicitation |
| "how should we", "which technology", "compare X vs Y", "spike", "investigate", "architecture decision", "should we use", "what's the best approach for" | `silver:research` | Tech decisions, architecture choices |
| "release", "publish", "version", "go live", "cut a release", "tag v", "ship to users", "deploy to prod" | `silver:release` | Milestone-level only — see disambiguation below |
| "merge this", "push this PR", "ship this feature" [active phase context] | `gsd-ship` (in-workflow) | Phase-level only |
| "trivial", "quick fix", "typo", "one-liner", "config value", ≤3 files | `silver:fast` (gsd-fast) | No planning overhead |
| "where are we", "what's left", "show progress", "current status" | `gsd-progress` | Status only |
| "pick up", "resume", "continue where" | `gsd-resume-work` | Session restore |
| "set up", "initialize", "install Silver Bullet", "configure project" | `silver:init` | First-time setup |
| "quality review", "ilities", "architecture review", "quality dimensions" | `silver:quality-gates` | Ad-hoc quality audit |
| "blast radius", "change impact", "rollback plan" | `silver:blast-radius` | Ad-hoc risk assessment |
| "IaC quality", "devops quality", "terraform quality" | `silver:devops-quality-gates` | Ad-hoc DevOps quality |
| "root cause", "session failed", "what broke", "reconstruct" | `silver:forensics` | Post-mortem investigation |
| "release notes", "github release", "cut release", "tag release" | `silver:create-release` | Release artifact creation |
| "which IaC tool", "terraform vs pulumi", "which cloud skill" | `silver:devops-skill-router` | IaC tool routing |
| "ingest", "import", "jira", "figma", "pull ticket", "cross-repo", "fetch spec from" | `silver:ingest` | Ingest external artifacts (JIRA, Figma, Google Docs) into SPEC.md + DESIGN.md, or fetch cross-repo spec |

**"Ship" disambiguation:**

| Signal | Route |
|--------|-------|
| Contains version number (v2.0, 1.4.0…) | `silver:release` |
| Contains "changelog" or "release notes" | `silver:release` |
| Contains "go live", "to production", "to users", "publicly" | `silver:release` |
| Active phase in progress, no version signal | `gsd-ship` (phase-merge within workflow) |
| No active phase, end of milestone | `silver:release` |

**Multi-signal conflict resolution:**

| Conflict | Winner | Rationale |
|----------|--------|-----------|
| `silver:bugfix` + any other | `silver:bugfix` | Broken things block everything |
| `silver:ui` + `silver:feature` | `silver:ui` | UI is more specific |
| `silver:devops` + `silver:feature` | Ask user (A/B) | Both equally valid |
| `silver:research` + any | `silver:research` first | Research informs implementation |
| `silver:spec` + `silver:feature` | `silver:spec` first | Spec before implementation |
| `silver:fast` + domain workflow | Check scope: if truly ≤3 files → `silver:fast`; if domain signals strong → domain workflow; if ambiguous → ask user "A. Treat as trivial  B. Route to [domain]" |

**MultAI auto-offer:** Proactively offer MultAI research before brainstorming when:
- Choosing between 2+ architectures
- Selecting a technology stack from scratch
- Domain is novel (no prior intel in .planning/)
- Change affects public API or data model fundamentally

### Step 3: Handle ambiguous input

If input matches two or more destinations with similar confidence, use AskUserQuestion:

> I'm not sure which workflow to use. Which of these best matches what you want to do?
>
> A. `silver:feature` — build or extend a feature
> B. `silver:bugfix` — fix something that's broken
> C. `silver:ui` — UI, frontend, or design work
> D. `silver:devops` — infrastructure, CI/CD, or deployment
> E. `silver:research` — technology decision or spike
> F. `silver:release` — publish a milestone release
> G. `silver:fast` — trivial one-liner or config change
> H. `silver:ingest` — ingest JIRA, Figma, Google Docs, or fetch cross-repo spec
> I. Something else — describe it
>
> (Enter the letter)

Wait for selection, then route accordingly using Step 5.

### Step 4: Show routing banner

Before invoking the chosen skill, always display:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 SILVER BULLET ► ROUTING
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Input:      {first 80 chars of user input}
Routing to: {chosen skill}
Reason:     {one sentence explaining the match}
```

### Step 5: Invoke chosen skill

**For SB skills** — invoke the chosen skill via the Skill tool, passing `$ARGUMENTS` as arguments.

**For GSD delegation** — invoke `/gsd:do` via the Skill tool, passing the original `$ARGUMENTS` as arguments. Do NOT attempt to route to individual GSD commands — let `/gsd:do` handle that.

**Security note:** `/silver` only routes to the skills explicitly listed in the routing table above. It never routes to forbidden skills — the forbidden-skill gate (`forbidden-skill-check.sh`) enforces this at the tool layer independently of this routing logic.

### Routing Priority

1. Complexity triage (trivial → silver:fast; fuzzy → silver:explore)
2. "Ship" disambiguation (phase-level vs milestone-level)
3. Multi-signal conflict resolution table
4. SB workflow routing table (specific domain matches)
5. Ad-hoc SB skill routing table
6. GSD triggers → /gsd:do
7. Ask for clarification (if still ambiguous)
