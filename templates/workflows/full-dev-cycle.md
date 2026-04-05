# Full Dev Cycle Workflow

> **ENFORCED** -- Silver Bullet hooks track Skill tool invocations for quality gates
> and gap-filling skills. GSD's own hooks (workflow guard, context monitor) enforce
> GSD step compliance independently. Both enforcement layers run in parallel.
>
> Completion audit BLOCKS git commit/push/deploy if required skills are missing.
> Context monitor warns at <=35% remaining tokens, escalates at <=25%.

## Invocation Methods

| What | How to invoke |
|------|---------------|
| GSD workflow steps (`/gsd:*`) | Slash command -- type `/gsd:new-project`, `/gsd:discuss-phase`, etc. |
| Silver Bullet skills | Skill tool -- `/quality-gates`, `/blast-radius`, etc. |
| Gap-filling skills | Skill tool -- `/testing-strategy`, `/documentation`, etc. |

Use `/gsd:next` at any point to auto-advance to the next GSD step if unsure of current state.

---

## How This Works

Silver Bullet orchestrates your entire software development lifecycle by guiding you through
a structured series of steps. Each step uses a GSD (Get Shit Done) command or a Silver Bullet
skill that handles the heavy lifting -- you provide direction, Claude executes.

This guide covers the full journey from project setup through release. Every section tells you:

1. **What it does** -- a one-sentence summary of the step
2. **What to expect** -- what artifacts are produced, what you will see, and roughly how long it takes
3. **If it fails** -- specific recovery actions so you are never stuck

You do not need to know GSD internals. Follow this guide top to bottom and you will have a
fully planned, implemented, tested, reviewed, documented, and deployed project. Each step
builds on the previous one, and the system tracks your progress so you can pause and resume
at any point.

The workflow repeats a core loop (Discuss, Quality Gates, Plan, Execute, Verify, Review) for
each phase in your roadmap. After all phases complete, finalization, deployment, and release
wrap everything up.

---

## STEP 0: SESSION MODE

> Run once at the very start of the session, before any project work.

**What it does:** Configures whether Claude pauses at decision points or drives autonomously
through the entire workflow.

**Bypass-permissions detection:** If bypass-permissions is detected (all tool calls
auto-accepted), skip the mode question AND the pre-answers follow-up. Auto-set
autonomous mode, use all defaults (Sonnet, main, isolated). Log:
"Step 0 skipped: bypass-permissions detected, autonomous mode with defaults".

Ask:
> Run this session **interactively** or **autonomously**?
> - **Interactive** (default) -- I pause at decision points and phase gates
> - **Autonomous** -- I drive start to finish, surface blockers at the end

Write choice to `~/.claude/.silver-bullet/mode`:
```bash
echo "interactive" > ~/.claude/.silver-bullet/mode   # or "autonomous"
```

**If autonomous was chosen**, ask one follow-up before proceeding:

> Any decision points you want to pre-answer? Common ones:
> - Model routing -- Planning phase: Sonnet or Opus?
> - Model routing -- Design phase: Sonnet or Opus?
> - Worktree: use one for this task, or work on main?
> - Agent Teams: use worktree isolation, or main worktree throughout?
> Leave blank to use defaults (Sonnet for both phases, main, isolated).

Write answers into the `## Pre-answers` section of the session log immediately. Format each answer as:
`- Model routing -- Planning: <value>`
`- Model routing -- Design: <value>`
`- Worktree: <value>`
`- Agent Teams: <value>`

Omit any key the user left blank (default applies). Read pre-answers mid-session from the log
at `~/.claude/.silver-bullet/session-log-path`, stripping the leading `- ` before splitting on `:`.
Log each applied pre-answer under "Autonomous decisions" with note `(pre-answered at Step 0)`.

**Fallback**: if the session log or `## Pre-answers` section is unreadable at any point,
use defaults: Sonnet for both phases, main, isolated.

---

## STEP 1: PROJECT SETUP

> Determines your starting point and runs the appropriate initialization workflow.

**What it does:** Detects whether this is a brand-new project, an existing project ready for
a new milestone, or a session that should resume where it left off -- then routes you to the
correct GSD command.

**What to expect:** After this step you will have `.planning/PROJECT.md`,
`.planning/REQUIREMENTS.md`, and `.planning/ROADMAP.md` (or you will resume an existing session).
Initialization typically takes 10-30 minutes depending on project complexity and whether
research is included.

### Brownfield Detection

Evaluate your project state and follow the matching path:

| Condition | Action | What happens |
|-----------|--------|--------------|
| No codebase at all | `/gsd:new-project` | Deep questioning about your vision, optional ecosystem research (4 parallel agents), requirements scoping with REQ-IDs, roadmap generation. Produces `PROJECT.md`, `REQUIREMENTS.md`, `ROADMAP.md`. |
| Existing codebase but no `.planning/` directory | `/gsd:map-codebase` then `/gsd:new-project` | Maps your codebase structure into `.planning/codebase/` (7 structured documents covering stack, architecture, patterns, dependencies, etc.), then initializes the project with full context of what already exists. |
| `.planning/PROJECT.md` exists but no completed milestone | Resume with `/gsd:next` | Detects your current position (which phase, which step) and auto-advances to the next logical action -- no setup needed. |
| `.planning/PROJECT.md` exists AND has a completed milestone | `/gsd:new-milestone` | Loads previous context, gathers goals for the new milestone through questioning, optionally runs research, defines scoped requirements, and creates a fresh roadmap. Carries forward accumulated context. |

**If it fails:**
- `/gsd:new-project` errors on init: check that `node` is available and `~/.claude/get-shit-done/` is installed.
- `/gsd:map-codebase` produces incomplete output: re-run; mapper agents are idempotent.
- `/gsd:next` cannot detect state: check `.planning/STATE.md` exists. If missing, `/gsd:resume-work` can reconstruct it from existing artifacts.

### Worktree Decision

Before proceeding, decide whether to use a git worktree for this work. If yes, create one
before any planning begins. Worktrees keep development isolated from your main branch.

---

## STEP 2: PER-PHASE LOOP

> Repeat these steps for each phase listed in `.planning/ROADMAP.md`.
> Use `/gsd:next` to confirm which phase is current.

This is the core of the development cycle. Each phase goes through: Model Routing, Skill
Discovery, Discuss, Quality Gates, Plan, Execute, Verify, Code Review, and Post-Review
Execution. The entire loop enforces a strict order -- you cannot skip ahead.

---

### MODEL ROUTING (once per session)

**What it does:** Selects which AI model to use for the planning-heavy steps of this phase.

**What to expect:** A prompt asking whether to use Opus (deeper reasoning, higher cost) or
stay on Sonnet (faster, lower cost). This affects discuss and plan quality. The choice
applies for the duration of the session.

Before DISCUSS begins, ask:
> Entering Planning phase. Use Opus (claude-opus-4-6) for deeper reasoning, or stay on Sonnet?

**Autonomous mode:** Stay Sonnet; escalate silently only on measurably incomplete planning output.

---

### SKILL DISCOVERY (once per task, before DISCUSS)

**What it does:** Scans installed skills and surfaces candidates that may apply to this
phase's work -- without invoking any of them yet.

**What to expect:** A list of applicable skills (e.g., `/security` for auth changes,
`/system-design` for new services) logged to the session log under
`## Skills flagged at discovery`. This is informational only; skills are invoked at their
designated points later in the workflow.

Scan installed skills from two sources:
1. `~/.claude/skills/` -- flat `.md` files
2. `~/.claude/plugins/cache/` -- glob `*/*/*/skills/*/SKILL.md` (layout: publisher/plugin/version/skills/skill-name)

Cross-reference the combined list against `all_tracked` in `.silver-bullet.json` and the
current task description. Surface candidates:
> Skills that may apply to this task: `/security` -- auth changes; `/system-design` -- new service

If no matches or both directories absent/empty: log "Skill discovery: no candidates surfaced."
Write results to `## Skills flagged at discovery` in the session log. **Do not invoke yet.**

---

### DISCUSS

**What it does:** Captures implementation decisions, gray areas, and user preferences for
this phase before any planning begins -- so downstream agents (researcher, planner) can act
on your vision without guessing.

**Command:** `/gsd:discuss-phase`                                                **REQUIRED** -- DO NOT SKIP

**What to expect:** Claude identifies phase-specific gray areas (concrete decisions like
"session handling" or "duplicate detection", not generic categories like "UX") and asks you
about each one. Your answers become locked decisions. Claude acts as a thinking partner --
you provide vision, Claude captures decisions for the builder agents downstream. Expect 5-15
minutes of focused discussion depending on phase complexity.

Produces: `.planning/phases/{phase}/{phase_num}-CONTEXT.md`

**Conditional sub-steps** (invoke via Skill tool if applicable):

- If this phase introduces an **architectural decision**: write an ADR inline
  (structure: title, status, context, decision, consequences) before moving to PLAN.
- If this phase introduces a **new service or major component**: `/system-design`
- If this phase involves **UI work**: `/design-system` + `/ux-copy` + `/accessibility-review`
  (WCAG 2.1 AA audit against the phase's UI deliverables)   **REQUIRED when UI work** -- DO NOT SKIP

**Model routing for Design**: if any design sub-steps apply (design-system, ux-copy,
architecture, system-design), ask once before beginning them:
> Entering Design phase. Use Opus, or stay on Sonnet?

**If it fails:** Re-run `/gsd:discuss-phase` with more specific questions. If Claude
identifies the wrong gray areas, provide your own list. The discuss step is idempotent --
re-running overwrites the CONTEXT.md with fresh decisions.

**Autonomous mode:** Use defaults for all gray areas, apply Claude's discretion throughout,
log all auto-decisions to the session log.

---

### QUALITY GATES

**What it does:** Evaluates the current design against all 8 Silver Bullet quality dimensions
and produces a consolidated pass/fail report. A failure is a hard stop, not a warning.

**Command:** `/quality-gates`                                                    **REQUIRED** -- DO NOT SKIP

**What to expect:** All 8 dimensions (modularity, reusability, scalability, security,
reliability, usability, testability, extensibility) are evaluated in parallel -- one agent per
dimension. Results are synthesized into a single report. Every dimension must pass. Expect 2-5
minutes.

**Agent Team dispatch**: Dispatch all 8 quality dimensions as a single parallel Agent Team
wave -- one agent per dimension, `isolation: "worktree"`. Claude synthesizes results.
Conflict resolution: more conservative/restrictive finding wins; resolution rationale logged
in session log. **Autonomous mode:** All dispatches use `run_in_background: true`.

**If it fails:** Read the report to identify which dimension(s) failed. Fix the specific
design issue in your CONTEXT.md or design artifacts, then re-run `/quality-gates`. Do not
proceed to PLAN until all 8 dimensions pass. Phase order is a hard constraint: do NOT start
PLAN before `/quality-gates` completes.

---

### PLAN

**What it does:** Researches technical approaches, creates detailed executable plans (PLAN.md
files) with task breakdowns and wave assignments, then verifies plan quality through a checker
agent with a revision loop.

**Command:** `/gsd:plan-phase`                                                   **REQUIRED** -- DO NOT SKIP

**What to expect:** The pipeline runs in three stages: (1) parallel research agents investigate
technical approaches and library options, (2) a planner agent creates structured PLAN.md files
with tasks, waves, dependencies, and verification criteria, and (3) a plan-checker agent
validates quality. If the checker finds issues, a revision loop runs (max 3 iterations).
Quality gate results from the previous step feed into the plan as hard requirements. Expect
5-15 minutes.

Produces: `.planning/phases/{phase}/{phase_num}-RESEARCH.md`,
`.planning/phases/{phase}/{phase_num}-{N}-PLAN.md`

**Skill gap check (post-plan):** After the plan is written, cross-reference all installed
skills against the plan content. Flag any skill covering a concern not explicitly in the plan.
- Interactive: ask whether to add the flagged skill
- Autonomous: add to plan or log omission as autonomous decision
Write results to `## Skill gap check (post-plan)` in the session log.

**If it fails:** Check that CONTEXT.md exists and has clear decisions. If the plan is
incomplete or misaligned, re-run `/gsd:discuss-phase` to clarify, then re-plan. If the
plan-checker loop exhausts 3 iterations, review the specific issues and provide guidance.

---

### EXECUTE

**What it does:** Runs wave-based parallel execution of all plans in the phase, with each
task producing an atomic git commit and each plan producing a SUMMARY.md.

**Command:** `/gsd:execute-phase`                                                **REQUIRED** -- DO NOT SKIP

**Pre-execution requirement:**
`/test-driven-development` -- Before writing any implementation code: establish              **REQUIRED** -- DO NOT SKIP
red-green-refactor discipline. Write the failing test first, make it pass,
then refactor. TDD applies per task within each GSD wave.

**What to expect:** Executor agents are dispatched per plan -- one agent per plan within each
wave (using worktree isolation for parallel execution). After each wave completes, a merge
gate runs before the next wave begins. Each task produces one atomic commit. Each plan produces
a SUMMARY.md documenting what was built. Duration varies from minutes (simple phases) to
hours (complex multi-plan phases).

Produces: atomic git commits (one per task),
`.planning/phases/{phase}/{phase_num}-{N}-SUMMARY.md`

Each GSD wave dispatches Agent Teams for independent implementation units
(`isolation: "worktree"` per agent). Merge gate after each wave before the next begins.
**Autonomous mode:** All agents use `run_in_background: true`.

**If it fails:** Use `/gsd:debug` to diagnose the issue. Debug spawns parallel agents to
investigate root causes, produces a structured diagnosis, and suggests fixes. After fixing,
re-run `/gsd:execute-phase` -- it picks up from incomplete plans automatically (plans with
existing SUMMARY.md files are skipped).

---

### VERIFY

**What it does:** Validates built features through goal-backward verification against
requirements, then runs user acceptance testing (UAT) with persistent state tracking.

**Command:** `/gsd:verify-work`                                                  **REQUIRED** -- DO NOT SKIP

**What to expect:** Claude presents what SHOULD happen for each testable deliverable and
asks you to confirm reality matches. Tests are presented one at a time. Your responses
("yes", descriptions of issues, "skip", "blocked") are recorded in a UAT.md file that
survives session breaks. Severity is inferred automatically from your descriptions -- Claude
never asks "how severe is this?". If issues are found, parallel debug agents diagnose root
causes and a planner creates fix plans automatically. Expect 10-30 minutes depending on how
many deliverables need verification.

Produces: `.planning/phases/{phase}/{phase_num}-VERIFICATION.md`,
`.planning/phases/{phase}/{phase_num}-UAT.md`

**If verification fails or output is suspect:** Invoke `/forensics` before retrying.
Identify root cause first. Then:
- If root cause is implementation: re-run EXECUTE + VERIFY only.
- If root cause is design/plan: return to DISCUSS for the same phase.
Do not advance to Code Review until verification passes. Blind retries compound failures.

**Agent Team scope for Code Review steps:** The review steps below may use parallel agents
(security, performance, correctness) with `isolation: "worktree"`.
`/requesting-code-review` is human-facing and runs sequentially after agent review resolves.
**Autonomous mode:** Agent dispatches use `run_in_background: true`.

---

### CODE REVIEW

**What it does:** Runs peer code quality review (security, performance, correctness,
readability -- distinct from GSD's goal verification), then requests and processes external
review feedback.

**Commands (all required, in order):**

1. `/code-review`                                                                **REQUIRED** -- DO NOT SKIP
   Structured peer code quality review (security, performance, correctness, readability).
   Covers SQL injection, XSS, N+1 queries, race conditions, edge cases, and maintainability.
   Run this before dispatching the automated reviewer.

2. `/requesting-code-review`                                                     **REQUIRED** -- DO NOT SKIP
   Dispatches `superpowers:code-reviewer` via the Agent tool to perform peer code quality
   review (security, performance, correctness, readability).
   **Review loop rule**: re-dispatch reviewer until it returns Approved TWICE IN A ROW.
   A single clean pass is not sufficient. The loop is self-limiting -- it ends naturally
   when two consecutive passes are clean. Never stop early on "minor" issues.

3. `/receiving-code-review`                                                      **REQUIRED** -- DO NOT SKIP
   Triage and accept/reject all items from the review above.

**What to expect:** A thorough multi-pass review process. The automated reviewer runs at
least twice (requiring two consecutive approvals). External review is requested and all
feedback is triaged. Accepted items become inputs for the Post-Review Execution step below.

**If review finds issues:** Accepted items flow into the Post-Review Execution step.
Rejected items are documented with rationale. If the review loop does not converge after
several iterations, check whether issues are genuine or stylistic disagreements.

---

### POST-REVIEW EXECUTION (only if items were accepted in Code Review)

**What it does:** Creates and executes a focused plan to address accepted review items, using
the same plan-execute pipeline with full quality guarantees.

**Commands:**
1. `/gsd:plan-phase` -- Create a plan to address accepted review items.
2. `/gsd:execute-phase` -- Implement the review-driven plan with atomic commits.

**What to expect:** A targeted plan addressing only the accepted review items, followed by
execution with atomic commits and SUMMARY.md. Same quality guarantees as the main cycle.

**If it fails:** Same recovery as the main PLAN and EXECUTE steps above.

---

> **End of per-phase loop.** Return to DISCUSS for the next phase in ROADMAP.md.
> All phases must complete before moving to FINALIZATION.

---

## STEP 3: FINALIZATION

> Run once after all phases are complete.

**What it does:** Wraps up the milestone by defining test strategy, cataloging tech debt,
updating all documentation, and preparing the branch for merge. These four skills are always
required regardless of project type.

---

### Testing Strategy

**Command:** `/testing-strategy`                                                 **REQUIRED** -- DO NOT SKIP

**What it does:** Defines the test strategy for the project: test pyramid structure, coverage
goals, test classification, and tooling decisions.

**What to expect:** A structured test strategy document covering unit, integration, and E2E
layers with concrete coverage targets and tool recommendations tailored to your stack.

**If it fails:** Re-run with more specific guidance about your testing preferences and
infrastructure constraints.

---

### Tech Debt

**Command:** `/tech-debt`                                                        **REQUIRED** -- DO NOT SKIP

**What it does:** Identifies, categorizes, and prioritizes technical debt introduced or
surfaced during this milestone.

**What to expect:** Structured items appended to `docs/tech-debt.md` in the format:
`| Item | Severity | Effort | Phase introduced |`. The file is created if it does not exist.

**If it fails:** Review the tech debt items manually. Ensure `docs/tech-debt.md` is writable.

---

### Documentation

**Command:** `/documentation`                                                    **REQUIRED** -- DO NOT SKIP

**What it does:** Updates or creates all project documentation to reflect the current state
of the project after this milestone's work.

**What to expect:** The following files are updated or created:
- `README.md` -- MUST reflect current version, features, and changes before release
- `docs/PRD-Overview.md` -- sync high-level areas from `.planning/REQUIREMENTS.md`
- `docs/Architecture-and-Design.md` -- high-level architecture and principles only;
  detailed phase designs live in `docs/specs/`
- `docs/Testing-Strategy-and-Plan.md`
- `docs/CICD.md`

**Additional required updates at this step:**
- Update `docs/KNOWLEDGE.md` Part 2: append dated entries to Architecture patterns,
  Known gotchas, Key decisions, Recurring patterns, Open questions as applicable.
  Resolved questions: append `[RESOLVED YYYY-MM-DD]: <resolution>` below original.
- Update `docs/CHANGELOG.md`: prepend a new entry (newest first):
  ```
  ## YYYY-MM-DD -- <task-slug>
  **What**: one sentence
  **Commits**: <hashes>
  **Skills run**: <list>
  **Virtual cost**: ~$X.XX (Model, complexity)
  **KNOWLEDGE.md**: updated (<sections>) | no changes
  ```
  Virtual cost complexity tiers: simple < 5 files / < 300 lines changed;
  medium 5-15 files or 300-1000 lines; complex > 15 files or architectural.
  Sonnet base rate; Opus is approximately 3x multiplier.
- Complete the session log: read path from `~/.claude/.silver-bullet/session-log-path`,
  edit that file to fill in Task, Approach, Files changed, Skills invoked,
  Agent Teams dispatched, Autonomous decisions, Outcome, KNOWLEDGE.md additions,
  Model, Virtual cost. If `~/.claude/.silver-bullet/session-log-path` is missing,
  create `docs/sessions/<today>-manual.md` from the session log template.
- Documentation agents writing to `docs/` run in the **main worktree only**
  (no `isolation: "worktree"`). Only implementation-touching agents use worktree isolation.

**If it fails:** Check file permissions on the `docs/` directory. Re-run targeting specific
files that need updating.

---

### Branch Cleanup

**Command:** `/finishing-a-development-branch`                                   **REQUIRED** -- DO NOT SKIP

**What it does:** Performs branch rebase, cleanup, and merge preparation so the branch is
ready for PR creation.

**What to expect:** The development branch is rebased onto the base branch, cleaned up
(squash fixups, remove WIP commits), and prepared for merge. Any conflicts are surfaced for
resolution.

**If it fails:** Resolve merge conflicts manually, then re-run. If conflicts are complex,
consider using `/gsd:debug` to diagnose.

---

## STEP 4: DEPLOYMENT

> Run after finalization is complete.

**What it does:** Ensures CI passes and runs pre-deployment verification before the work
can be shipped. Both steps are required.

---

### CI/CD Pipeline

**REQUIRED** -- DO NOT SKIP

Use existing pipeline or set one up before deploying. GitHub repos: use GitHub Actions.

**CI verification gate:**
- Run local verify commands first (from `.silver-bullet.json` `verify_commands`,
  or stack defaults: `npm test` / `pytest` / `cargo test` / `go test ./...`)
- Check CI: `gh run list --limit 1 --json status,conclusion`
- **Autonomous mode**: poll every 30 seconds, up to 20 retries (10 min max).
  On timeout: log blocker under "Needs human review", surface to user, **STOP
  deployment steps**. Do NOT proceed to `/deploy-checklist` while CI status is unknown.
- **Interactive mode**: show status. If `in_progress`: inform user, wait for
  confirmation to re-check or proceed.
- **CI MUST be green.** If CI is red: invoke `/gsd:debug`, fix the issue, re-push,
  and re-check CI. Do NOT proceed to `/deploy-checklist` while CI is failing.
  Repeat fix-push-check until CI passes.
- **Missing ci.yml rule**: if `.github/workflows/ci.yml` is absent at this step,
  Claude must NOT invoke `/deploy-checklist`. Log as blocker under "Needs human review",
  surface missing file to user, stop deployment steps.
- Race condition: the post-commit hook (ci-status-check.sh) reflects the last
  *completed* run, not necessarily this push. This polling loop is the authoritative gate.

**If CI fails:** Use `/gsd:debug` to diagnose the failure. Fix the issue, re-push, and
re-check. Do not proceed until CI is green. Repeat the fix-push-check loop as needed.

---

### Deploy Checklist

**Command:** `/deploy-checklist`                                                 **REQUIRED** -- DO NOT SKIP

**What it does:** Runs a pre-deployment verification gate covering environment config,
secrets, database migrations, rollback plan, and monitoring readiness.

**What to expect:** A structured checklist that must be fully satisfied before deployment
proceeds. Any unchecked items are blockers that must be resolved first.

**If it fails:** Address each failing checklist item individually. Re-run after fixes.

---

## STEP 5: SHIP

**Command:** `/gsd:ship`                                                         **REQUIRED** -- DO NOT SKIP

**What it does:** Creates a pull request from verified, deployed work by auto-generating a
rich PR body from your planning artifacts.

**What to expect:** Preflight checks run first (verification passed, clean working tree,
correct branch, remote configured, `gh` CLI available and authenticated). The branch is
pushed to remote and a PR is created with auto-generated sections: Summary (phase goal and
what was built), Changes (per-plan breakdown with key files), Requirements Addressed
(REQ-IDs linked to descriptions), Verification (pass/fail status), and Key Decisions.

Produces: pull request with phase summaries and requirement coverage.

**If it fails:**
- Preflight check fails: fix the specific issue (commit uncommitted changes, switch to feature branch, configure remote).
- `gh` CLI not authenticated: run `gh auth login`.
- Push fails: set upstream with `git push --set-upstream origin <branch>`.
- No verification: go back to VERIFY step.

---

## STEP 6: RELEASE

**Command:** `/create-release`                                                   **REQUIRED** -- DO NOT SKIP

**What it does:** Generates structured release notes and creates a GitHub Release with a
git tag.

**What to expect:** Release notes are generated from the milestone's work with sections for
features, fixes, and breaking changes. For GitHub repos, uses `gh release create`. For
non-GitHub repos, outputs formatted notes for manual publishing. README must have been
updated in STEP 3 (Documentation) before this step can proceed.

Produces: git tag, GitHub Release with structured notes.

**If it fails:**
- README not updated: go back to STEP 3 Documentation and update README first.
- `gh` CLI errors: check authentication with `gh auth status`.
- Tag already exists: bump the version or delete the stale tag if it was created in error.

**Autonomous completion cleanup** (run after outputting structured summary):
```bash
rm -f ~/.claude/.silver-bullet/timeout ~/.claude/.silver-bullet/sentinel-pid \
      ~/.claude/.silver-bullet/session-start-time ~/.claude/.silver-bullet/timeout-warn-count
```
This clears the timeout sentinel so `timeout-check.sh` stops warning.

---

## STEP 7: TRANSITION TO DEVOPS

> After RELEASE, Silver Bullet detects whether your project needs deployment infrastructure
> and offers to transition to the DevOps workflow.

**What it does:** Evaluates infrastructure indicators and offers to switch from the
development workflow to the DevOps workflow for setting up deployment, monitoring, and
infrastructure as code.

### Detection Triggers

The transition is offered when ANY of the following are true:
- **IaC files present**: `*.tf` (Terraform), `Dockerfile`, `docker-compose.yml`, Kubernetes manifests (`k8s/`, `kubernetes/`)
- **Deploy checklist flagged gaps**: `/deploy-checklist` in STEP 4 identified infrastructure gaps that need addressing
- **User request**: You explicitly ask to set up deployment infrastructure

### What Happens

1. Claude offers: "Application shipped. Set up deployment infrastructure? This switches to the DevOps workflow."
2. If you accept: `active_workflow` in `.silver-bullet.json` is updated from `full-dev-cycle` to `devops-cycle`
3. The DevOps workflow (`docs/workflows/devops-cycle.md`) takes over with infrastructure-specific steps including blast radius analysis, environment promotion, and incident response

### What Is Preserved During Transition

Everything carries forward -- nothing is lost:
- `.planning/` directory and all artifacts (PROJECT.md, REQUIREMENTS.md, ROADMAP.md, STATE.md, all phase artifacts)
- `.silver-bullet.json` configuration (only `active_workflow` field changes)
- All committed git history
- Session state, handoff files, and accumulated decisions

### If You Decline

No changes are made. The dev cycle is complete. Start the next round of feature development
with `/gsd:new-milestone` when ready.

---

## UTILITY COMMANDS REFERENCE

These commands are available throughout the workflow. Use them whenever the situation calls
for it -- they are not tied to a specific step.

| Command | What it does | When to use |
|---------|-------------|-------------|
| `/gsd:debug` | Spawns parallel debug agents to diagnose root causes, produces structured diagnosis with fix suggestions. | When execution fails, tests break, or unexpected behavior occurs during any step. |
| `/gsd:quick` | Plans and executes small, self-contained tasks with atomic commits and STATE.md tracking. Supports `--full`, `--validate`, `--discuss`, `--research` flags. | For well-defined changes outside the main phase cycle (add a feature flag, fix a specific bug, small enhancements). |
| `/gsd:fast` | Executes trivial tasks inline -- no PLAN.md, no subagent spawning. Understand, do, commit, log. | For truly trivial changes only: fix a typo, update a config value, add a missing import (3 files or fewer). |
| `/gsd:resume-work` | Restores full project context from STATE.md and HANDOFF.json, detects incomplete work, and presents next actions. | When starting a new session on an existing project -- "where were we?" |
| `/gsd:pause-work` | Creates `.planning/HANDOFF.json` and `.continue-here.md` preserving complete work state for clean resume. | Before ending a session -- saves exact position, decisions, blockers, and mental context. |
| `/gsd:progress` | Shows rich progress report with progress bar, recent work, current position, blockers, and routes to next action. | To check milestone progress at any time -- where you are, what is done, what is next. |
| `/gsd:next` | Detects current project state and auto-advances to the next logical GSD step without asking. | When unsure what to do next -- zero-friction advancement through the workflow. |
| `/gsd:add-phase` | Adds a new integer phase to the end of the current milestone in the roadmap. | When you discover new work needed that was not in the original roadmap. |
| `/gsd:insert-phase` | Inserts a decimal phase between existing phases (e.g., 3.1 between 3 and 4). | For urgent fixes or discoveries that must happen before the next planned phase. |
| `/gsd:review` | Cross-AI peer review -- invokes external AI CLIs (Gemini, Codex, CodeRabbit) to independently review plans. | For adversarial review before execution -- different AI models catch different blind spots. |
| `/gsd:audit-milestone` | Aggregates phase verifications, checks cross-phase integration, and assesses overall requirements coverage. | At end of milestone before completing -- ensures everything works together across phases. |
| `/gsd:autonomous` | Drives all remaining phases autonomously (discuss, plan, execute per phase). Supports `--from N`, `--to N`, `--only N`, `--interactive`. | When you want Claude to drive multiple phases end-to-end without manual intervention. |
| `/gsd:complete-milestone` | Marks milestone complete, creates MILESTONES.md record, archives artifacts, and tags the release in git. | After all phases are verified and shipped -- wraps up the milestone cleanly. |
| `/gsd:map-codebase` | Orchestrates parallel agents to analyze codebase, producing 7 structured documents in `.planning/codebase/`. | For brownfield projects before `/gsd:new-project` -- gives Claude full codebase understanding. |

---

## Review Loop Enforcement

Every review loop in this workflow (spec review, plan review, code review, verification) **MUST iterate until the reviewer returns Approved TWICE IN A ROW**. A single clean pass is not sufficient. No exceptions.

- Never stop because "issues are minor" or "close enough"
- Never accept a partial fix and move on without re-dispatching
- Never count a loop as done unless the reviewer outputs Approved on two consecutive passes
- The loop is self-limiting -- it ends naturally when two consecutive passes are clean
- Surface to the user only if the reviewer raises an issue it cannot resolve

---

## Enforcement Rules

- **GSD steps** are enforced by instruction (this file + CLAUDE.md) and GSD's own hooks.
  GSD steps MUST follow DISCUSS -> QUALITY GATES -> PLAN -> EXECUTE -> VERIFY -> CODE REVIEW -> POST-REVIEW EXECUTION order per phase.
- **Silver Bullet skills** (quality gates + gap-fillers) are enforced by PostToolUse hooks
  that track Skill tool invocations. "I already covered this" is NOT valid.
- Phase order is a hard constraint: do NOT start PLAN before `/quality-gates` completes.
- For ANY bug encountered during execution: use `/gsd:debug`.
- For root-cause investigation after a completed, failed, or abandoned session: use `/forensics`.
- For trivial changes (typos, copy fixes, config tweaks): `touch ~/.claude/.silver-bullet/trivial`

---

## GSD / Superpowers Ownership Rules

GSD is the authoritative execution orchestrator. Superpowers provides design and review
capabilities only. Where both tools could apply, GSD wins.

| Concern | Owner | Rule |
|---------|-------|------|
| Requirements | GSD | `.planning/REQUIREMENTS.md` is the single source of truth. Superpowers must NOT maintain a separate requirements list. |
| Planning | GSD | Use `/gsd:plan-phase` for all plans. When Superpowers' `brainstorming` skill offers to hand off to `writing-plans`, **redirect to `/gsd:plan-phase` instead**. |
| Execution | GSD | Always use `/gsd:execute-phase` (wave-based). **NEVER** use `superpowers:subagent-driven-development` or `superpowers:executing-plans` for project work. |
| Design specs | Superpowers | Save to `docs/specs/YYYY-MM-DD-<topic>-design.md`. Superpowers' default path (`docs/superpowers/specs/`) is NOT used -- always override it. |
| Code review | Superpowers | `/requesting-code-review`, `/receiving-code-review`, `superpowers:code-reviewer` are used for review only, never for execution. |

**Override Superpowers defaults in every session:**
- Spec save path: `docs/specs/` (not `docs/superpowers/specs/`)
- After brainstorming completes: invoke `/gsd:plan-phase` (not `writing-plans`)
- For execution: `/gsd:execute-phase` (not `subagent-driven-development`)
