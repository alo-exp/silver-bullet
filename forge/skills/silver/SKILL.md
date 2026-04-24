---
id: silver
title: Silver — Smart Workflow Router
description: Routes user intent to the correct Silver Bullet sub-workflow
trigger:
  - "/silver"
  - "silver workflow"
  - "use silver"
  - "start workflow"
---

# Silver — Smart Workflow Router

Route to the correct sub-skill based on intent. First match wins.

## Routing Table

| Intent signals | Route to |
|---|---|
| "add", "build", "implement", "new feature", "enhance" | silver-feature |
| "bug", "broken", "crash", "error", "regression", "not working" | silver-bugfix |
| "UI", "frontend", "component", "screen", "interface", "design" | silver-ui |
| "infra", "CI/CD", "deploy", "pipeline", "terraform" | silver-devops |
| "how should we", "compare X vs Y", "spike", "which technology", "architecture decision" | silver-research |

## When Routing
State: "Routing to [skill] because [one sentence reason]."
Then follow that skill's procedure exactly.

## When Ambiguous
Ask: "Which workflow fits?
A. New feature or enhancement
B. Bug fix
C. UI/frontend work
D. Infrastructure/DevOps
E. Technology decision/research
(Enter A-E)"
Wait for response before routing.

## Complexity Triage

Before routing, check if the request is trivial:

| Classification | Signals | Action |
|---|---|---|
| Trivial | Typo, config, rename, ≤3 files | Handle inline with atomic commit |
| Simple | Clear scope, ≤1 phase | Route to workflow |
| Complex | Multi-phase, cross-cutting | Route to workflow with full chain |

## Session Log
Record routing decision in `docs/sessions/YYYY-MM-DD.md`.
