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

### Step 2: Match intent against routing table

Check the SB routing table first (exact domain match). If no SB match, check GSD triggers. If neither matches clearly, present top 2-3 options.

**SB Routing Table (check first):**

| If text describes... | Route to | Trigger keywords |
|---------------------|----------|-----------------|
| Setup, initialize, onboard, install, scaffold Silver Bullet, configure project | `/silver:init` | setup, initialize, onboarding, install, scaffold, "silver bullet init", configure project, first time |
| Quality review, ilities, architecture review, code quality, design quality, quality dimensions | `/quality-gates` | quality review, ilities, architecture review, quality dimensions, code quality check, quality gates |
| Risk, blast radius, infrastructure change impact, rollback plan, change scope | `/blast-radius` | risk assessment, infrastructure change impact, blast radius, change scope, rollback plan |
| IaC quality, DevOps quality, infrastructure quality, terraform quality, DevOps review | `/devops-quality-gates` | IaC quality, DevOps quality review, infrastructure quality, terraform quality, devops gates |
| Debugging, incident, root cause investigation, session failed, stalled, wrong output | `/forensics` | debugging, incident investigation, root cause, session failed, stalled, wrong output, what broke |
| Release, publish, version, changelog, ship it, cut release, tag, github release | `/create-release` | release, publish, changelog, version bump, tag, ship release, github release |
| Which DevOps tool, IaC routing, Terraform vs Pulumi, which cloud skill, infrastructure tool | `/devops-skill-router` | DevOps toolchain, which IaC skill, terraform vs pulumi, infrastructure tool, which cloud |

**GSD Trigger Keywords (fallback):**

plan, execute, discuss, debug, new project, ship, verify, next, research, status, roadmap, phase, milestone, implement, build, code, develop, fix bug, refactor, test, deploy, PR, pull request, commit, start project, new feature

For any GSD-related input, delegate to `/gsd:do` passing the original text as arguments.

### Step 3: Handle ambiguous input

If input could match two or more destinations with similar confidence, use AskUserQuestion to present the top 2-3 options:

Use AskUserQuestion:
- Question: "I'm not sure which skill to use. Which of these best matches what you want to do?"
- Options (use the top 2-3 matches from the routing table, lettered):
  - "A. /quality-gates — review all 8 quality dimensions before planning"
  - "B. /blast-radius — assess risk and change scope for an infrastructure change"
  - "C. /gsd:do — plan and execute work with GSD"

Wait for selection, then route accordingly.

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

1. SB routing table (specific domain matches take precedence)
2. GSD triggers (general project execution / planning)
3. Ask for clarification (if still ambiguous)
