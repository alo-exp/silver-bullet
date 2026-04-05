# Phase 1: Workflow File Rewrites - Context

**Gathered:** 2026-04-05 (autonomous — decisions locked from approved v0.9.0 plan)
**Status:** Ready for planning

<domain>
## Phase Boundary

Rewrite `docs/workflows/full-dev-cycle.md` and `docs/workflows/devops-cycle.md` from enforcement checklists into comprehensive orchestration guides. The guides must explain every GSD step with user-facing context, insert non-GSD skills at appropriate points, include error recovery, cover utility commands, and handle dev↔DevOps transitions. Template parity (templates/workflows/ must match docs/workflows/) is enforced after rewrite.

Requirements covered: ORCH-01 through ORCH-06, TRANS-01 through TRANS-03 (9 of 22 milestone requirements).

</domain>

<decisions>
## Implementation Decisions

### Structure: From Enforcement Checklist to Orchestration Guide

- **D-01:** Each workflow file transforms from a flat step list (~340 lines) into a structured orchestration guide (~600-700 lines) with sections: How This Works, Session Mode, Project Setup, Per-Phase Loop, Finalization, Deployment, Ship, Release, Transition, Utility Commands, Enforcement Rules.
- **D-02:** Every GSD step includes: (a) what it does in one sentence, (b) what the user should expect, (c) what to do if it fails. This is the "hand-holding" requirement — a user who has never seen GSD should understand every step.
- **D-03:** Enforcement rules from the current workflow files (anti-skip rules, review loop enforcement, GSD step ordering, trivial change bypass) carry forward unchanged at the bottom of the new files.

### GSD Command Coverage

- **D-04:** 20 core + select utility GSD commands are guided at appropriate workflow points:
  - **Core SDLC** (guided within per-phase loop): `/gsd:new-project`, `/gsd:new-milestone`, `/gsd:map-codebase`, `/gsd:discuss-phase`, `/gsd:plan-phase`, `/gsd:execute-phase`, `/gsd:verify-work`, `/gsd:ship`, `/gsd:complete-milestone`, `/gsd:autonomous`
  - **Select utilities** (guided in a "Utility Commands" section and referenced inline where relevant): `/gsd:debug`, `/gsd:quick`, `/gsd:fast`, `/gsd:resume-work`, `/gsd:pause-work`, `/gsd:progress`, `/gsd:next`, `/gsd:add-phase`, `/gsd:insert-phase`, `/gsd:review`, `/gsd:audit-milestone`
- **D-05:** Admin/social GSD commands (gsd-manager, gsd-settings, gsd-stats, gsd-note, gsd-add-todo, gsd-join-discord, etc.) are NOT referenced in the workflow files. They remain accessible but are outside the guided flow.

### Non-GSD Skill Insertion Points

- **D-06:** Non-GSD skills are inserted with explicit trigger conditions in the workflow:
  - DISCUSS: `/design-system` + `/ux-copy` + `/accessibility-review` — IF this phase involves UI work
  - DISCUSS: `/system-design` — IF new service or major component
  - PRE-PLAN: `/quality-gates` — ALWAYS (hard stop, 8 dimensions)
  - EXECUTE: `/test-driven-development` — ALWAYS (before implementation code)
  - POST-VERIFY (fail): `/forensics` — IF verification fails or output is suspect
  - POST-EXECUTE: `/code-review` + `/requesting-code-review` + `/receiving-code-review` — ALWAYS
  - FINALIZATION: `/testing-strategy` + `/tech-debt` + `/documentation` + `/finishing-a-development-branch` — ALWAYS
  - DEPLOYMENT: `/deploy-checklist` — ALWAYS
  - RELEASE: `/create-release` — ALWAYS
- **D-07:** DevOps-specific insertions (devops-cycle only):
  - PRE-PLAN: `/blast-radius` → `/devops-quality-gates` (ALWAYS, in that order)
  - EXECUTE: `/devops-skill-router` (enrichment only, not enforced)
  - INCIDENT FAST PATH: `/incident-response` (first step)

### Error Recovery Pattern

- **D-08:** Each per-phase step includes a "What to do if this fails" section:
  - DISCUSS fails/unclear → re-run discuss with more specific questions
  - QUALITY GATES fail → fix the specific dimension, re-run gates
  - PLAN fails → check context, re-discuss if needed, re-plan
  - EXECUTE fails → use `/gsd:debug` to diagnose, fix, re-execute
  - VERIFY fails → invoke `/forensics` first, then re-execute or re-plan based on root cause
  - CODE REVIEW finds issues → post-review plan + execute cycle

### Dev ↔ DevOps Transition

- **D-09:** Transition section added at the end of full-dev-cycle.md (after RELEASE):
  - Detect infrastructure needs: presence of IaC files (*.tf, Dockerfile, k8s manifests), /deploy-checklist flagged infra gaps, or user request
  - Offer: "Application shipped. Set up deployment infrastructure? This switches to the DevOps workflow."
  - If yes: update `active_workflow` in `.silver-bullet.json` to `devops-cycle`, preserve all context
- **D-10:** Transition section added at the end of devops-cycle.md (after RELEASE):
  - Offer: "Infrastructure deployed. Continue developing features for the next milestone?"
  - If yes: update `active_workflow` to `full-dev-cycle`, start new milestone with `/gsd:new-milestone`
- **D-11:** Both transitions preserve: `.planning/` artifacts, `.silver-bullet.json` config, state file, all committed history.

### Brownfield Detection (Project Setup)

- **D-12:** Project Setup section covers both greenfield and brownfield paths:
  - If `.planning/PROJECT.md` exists AND has a completed milestone → `/gsd:new-milestone`
  - If `.planning/PROJECT.md` exists but no milestone → resume with `/gsd:next`
  - If existing codebase but no `.planning/` → `/gsd:map-codebase` THEN `/gsd:new-project`
  - If no codebase → `/gsd:new-project`

### Autonomous Mode Handling

- **D-13:** Step 0 (Session Mode) remains unchanged from current implementation — bypass-permissions detection, interactive vs autonomous choice, pre-answers follow-up.
- **D-14:** Throughout the guide, autonomous mode behaviors are documented inline (e.g., "Autonomous mode: stay Sonnet, use defaults, poll CI every 30s").

### Claude's Discretion

- Exact wording of user-facing explanations at each step
- How much detail to include in each GSD step description (must be enough for a GSD-naive user, but not overwhelming)
- Whether to use sub-headings or bullet lists for step explanations
- Exact formatting of the Utility Commands reference section

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Current workflow files (will be rewritten)
- `docs/workflows/full-dev-cycle.md` — Current 356-line enforcement checklist, enforcement rules at bottom
- `docs/workflows/devops-cycle.md` — Current 439-line enforcement checklist, DevOps-specific additions

### GSD process reference (source of truth for GSD steps)
- `~/.claude/get-shit-done/workflows/discuss-phase.md` — How GSD discuss works
- `~/.claude/get-shit-done/workflows/plan-phase.md` — How GSD plan works
- `~/.claude/get-shit-done/workflows/execute-phase.md` — How GSD execute works
- `~/.claude/get-shit-done/workflows/verify-work.md` — How GSD verify works
- `~/.claude/get-shit-done/workflows/ship.md` — How GSD ship works
- `~/.claude/get-shit-done/workflows/new-project.md` — How GSD new-project works
- `~/.claude/get-shit-done/workflows/new-milestone.md` — How GSD new-milestone works
- `~/.claude/get-shit-done/workflows/autonomous.md` — How GSD autonomous works
- `~/.claude/get-shit-done/workflows/debug.md` — How GSD debug works

### SB enforcement (must carry forward)
- `silver-bullet.md` §3 — Non-negotiable rules (DO NOT SKIP enforcement)
- `silver-bullet.md` §3a — Review loop enforcement (2 consecutive ✅)
- `silver-bullet.md` §3b — GSD command tracking markers

### Approved plan
- `/Users/shafqat/.claude/plans/flickering-yawning-koala.md` — v0.9.0 plan with architecture decisions

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Current `full-dev-cycle.md` enforcement rules section (lines 316-337) — carries forward verbatim
- Current `devops-cycle.md` DevOps-specific sections (incident fast path, blast radius, environment promotion) — carries forward with enhanced explanations
- Step 0 session mode logic — carries forward unchanged

### Established Patterns
- Workflow files use markdown with `**REQUIRED** ← DO NOT SKIP` annotations
- Steps are numbered sequentially with ### headers
- GSD steps reference slash commands (e.g., `/gsd:discuss-phase`)
- Non-GSD skills reference Skill tool (e.g., `/quality-gates`, `/testing-strategy`)
- Autonomous mode behaviors documented inline in each step

### Integration Points
- `hooks/dev-cycle-check.sh` reads `active_workflow` from `.silver-bullet.json` — workflow file names must match
- `hooks/completion-audit.sh` checks `required_deploy` skills — skill names in workflow must match config
- `hooks/compliance-status.sh` shows progress based on state file — skill invocation tracking unchanged
- `hooks/record-skill.sh` strips namespace prefixes — skill names in workflow must be canonical

</code_context>

<specifics>
## Specific Ideas

- The user emphasized "handholding" — the workflow must be usable by someone who has never heard of GSD
- "100% of the applicable GSD steps" — every core SDLC GSD command must appear at its natural point
- Error recovery is critical — each step must explain what to do when things go wrong
- Transition between dev and DevOps should be seamless and contextual

</specifics>

<deferred>
## Deferred Ideas

- silver-bullet.md overhaul — Phase 2
- Forensics evolution — Phase 3
- Template parity verification — Phase 4
- README/site updates — Phase 5
- SB replacing GSD/Superpowers (goal #7) — v2, not v0.9.0

</deferred>

---

*Phase: 01-workflow-file-rewrites*
*Context gathered: 2026-04-05*
