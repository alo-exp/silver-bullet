# DevOps Cycle Workflow

> **ENFORCED** -- Silver Bullet hooks track Skill tool invocations for quality gates
> and gap-filling skills. GSD's own hooks (workflow guard, context monitor) enforce
> GSD step compliance independently. Both enforcement layers run in parallel.
>
> Completion audit BLOCKS git commit/push/deploy if required skills are missing.
> Context monitor warns at <=35% remaining tokens, escalates at <=25%.
>
> **IMPORTANT -- .yml/.yaml/.json/.toml files are NOT exempt from enforcement in this workflow.**
> GitHub Actions, Kubernetes manifests, Helm charts, and CI/CD pipeline definitions
> are infrastructure code. They MUST follow this workflow regardless of file extension.
> The trivial-change exemption in CLAUDE.md does NOT apply to declarative infra files.

## Invocation Methods

| What | How to invoke |
|------|---------------|
| GSD workflow steps (`/gsd:*`) | Slash command -- type `/gsd:new-project`, `/gsd:discuss-phase`, etc. |
| Silver Bullet skills | Skill tool -- `/blast-radius`, `/devops-quality-gates`, `/forensics`, etc. |

Use `/gsd:next` at any point to auto-advance to the next GSD step if unsure of current state.

---

## How This Works

Silver Bullet orchestrates infrastructure and DevOps work by guiding you through GSD
steps adapted for Infrastructure-as-Code (IaC). This file is the complete reference --
you do not need to read GSD documentation separately.

Each section below tells you:
- **What it does** -- one sentence summary of the step
- **What to expect** -- artifacts produced, typical duration, what you will see
- **If it fails** -- specific recovery steps so you are never stuck

The workflow includes DevOps-specific additions that have no equivalent in the
development cycle: an **Incident Fast Path** for production emergencies, **Blast Radius
Analysis** before every change, **Environment Promotion** for safe rollouts from dev
through production, and **DevOps Quality Gates** with 7 IaC-adapted dimensions.

No GSD knowledge is required. Follow this file top-to-bottom for the full
infrastructure lifecycle: setup, discuss, analyze, plan, execute, verify, promote,
ship, and release.

---

## STEP 0: SESSION MODE

> Run once at the very start of the session, before any project work.

**What it does:** Establishes whether you are working interactively (pausing at decision
points) or autonomously (driving start-to-finish with blockers surfaced at the end).

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
> - Worktree: use one for this task, or work on main?
> - Agent Teams: use worktree isolation, or main worktree throughout?
> Leave blank to use defaults (Sonnet, main, isolated).

Write answers into the `## Pre-answers` section of the session log immediately. Format each answer as:
`- Model routing -- Planning: <value>`
`- Worktree: <value>`
`- Agent Teams: <value>`

Omit any key the user left blank (default applies). Read pre-answers mid-session from the log
at `~/.claude/.silver-bullet/session-log-path`, stripping the leading `- ` before splitting on `:`.
Log each applied pre-answer under "Autonomous decisions" with note `(pre-answered at Step 0)`.

**Fallback**: if the session log or `## Pre-answers` section is unreadable at any point,
use defaults: Sonnet, main, isolated.

---

## Incident Fast Path

> Use ONLY when responding to an active production incident requiring an emergency change.
> Skip this section entirely for planned DevOps work.

**What it does:** Provides an abbreviated change process for active production incidents
where the standard full cycle would extend an outage.

**When to use:** Active incident with confirmed production impact AND the change cannot
wait for the full cycle without extending downtime.

**What to expect:** Severity classification, a minimal scoped change, verification in the
lowest affected environment first, and a post-incident review task queued for full-cycle
treatment after the incident resolves.

**Fast path steps:**

1. `/incident-response` -- Invoke immediately. Establish severity classification,         **REQUIRED** -- DO NOT SKIP
   owner assignment, comms channel, and timeline tracking before any change is made.
   This is always the FIRST step in any incident response.
2. **Document the incident** -- Record what is broken, the proposed change, and the
   expected outcome. Even under time pressure, a one-paragraph description prevents
   misaligned fixes.
3. `/blast-radius` -- Required even in incidents. A rushed unreviewed change can make     **REQUIRED** -- DO NOT SKIP
   incidents worse. If CRITICAL blast radius, escalate to CAB before proceeding.
4. **Apply minimal change** -- Apply in the lowest affected environment first. Verify
   health checks pass. Then promote to the next environment.
5. **Create post-incident review task** -- After the incident resolves, queue a full
   cycle review of the emergency change, including `/devops-quality-gates` retroactively.
6. **Commit with `[HOTFIX]` prefix** -- Reference the incident ticket in the commit
   message for audit trail.

**If it fails:** If the minimal change does not resolve the incident, STOP and escalate.
Do not apply additional untested changes. Roll back to the last known good state and
re-assess the root cause before attempting a different fix.

---

## STEP 1: PROJECT SETUP

> Run once per project. Determines the correct starting point based on what already exists.

**What it does:** Detects whether this is a new project or an existing one and routes to
the appropriate GSD command. For DevOps projects, roadmap phases typically map to
infrastructure layers: networking -> storage -> compute -> monitoring -> CI/CD.

**Brownfield detection -- four paths:**

| Condition | Action |
|-----------|--------|
| `.planning/PROJECT.md` exists AND has a completed milestone | `/gsd:new-milestone` -- Start the next milestone |
| `.planning/PROJECT.md` exists but no completed milestone | `/gsd:next` -- Resume where you left off |
| Existing codebase but no `.planning/` directory | `/gsd:map-codebase` THEN `/gsd:new-project` -- Map first, then initialize |
| No codebase at all | `/gsd:new-project` -- Full greenfield initialization |

### `/gsd:new-project`

**What it does:** Initializes a brand-new project through questioning, optional ecosystem
research, requirements scoping, and roadmap generation.

**What to expect:** Interactive questioning about what you are building. Optionally spawns
parallel research agents to investigate stack choices, features, architecture, and pitfalls.
Generates scoped requirements with REQ-IDs grouped by category, then produces a phased
roadmap. Typical duration: 5-15 minutes depending on research.

**Produces:** `.planning/PROJECT.md`, `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`

**If it fails:** Check that `.planning/` does not already exist (it will error if it does).
If research agents fail, re-run with `--skip-research` and handle research manually.

### `/gsd:new-milestone`

**What it does:** Starts a new milestone cycle for an existing project. Loads project
context, gathers milestone goals, updates PROJECT.md and STATE.md, optionally runs
research, defines new scoped requirements, and creates a phased roadmap.

**What to expect:** Summary of what shipped in the last milestone, questions about what
to build next, requirement scoping, and roadmap generation. Previous milestone artifacts
are archived automatically.

**Produces:** Updated `.planning/PROJECT.md`, `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`

**If it fails:** Verify that the previous milestone was completed with `/gsd:complete-milestone`
before starting a new one.

### `/gsd:map-codebase`

**What it does:** Spawns parallel agents to analyze the existing codebase and produce
structured documents covering architecture, dependencies, patterns, and conventions.

**What to expect:** Parallel mapper agents explore different dimensions of the codebase.
Each writes a document directly to `.planning/codebase/`. Typical duration: 2-5 minutes.

**Produces:** `.planning/codebase/` folder with structured analysis documents.

**If it fails:** Ensure the repository is not empty and that source files exist.

**Worktree recommendation:** Strongly recommended for changes touching production resources.
Ask: "Should I use a git worktree for this infrastructure change?" If yes, create one
before proceeding.

---

## STEP 2: PER-PHASE LOOP

> Repeat the steps below for each phase listed in `.planning/ROADMAP.md`.
> Recommended phase order for new infra: networking -> storage -> compute -> monitoring -> CI/CD.
> Use `/gsd:next` to confirm which phase is current.

---

### MODEL ROUTING (once per session)

Before DISCUSS begins, ask:
> Entering Planning phase. Use Opus (claude-opus-4-6) for deeper reasoning, or stay on Sonnet?

Autonomous mode: stay Sonnet; escalate silently only on measurably incomplete planning output.

---

### SKILL DISCOVERY (once per task, before DISCUSS)

**What it does:** Scans installed skills and cross-references them against the current
task to surface relevant capabilities before work begins.

Scan installed skills from two sources:
1. `~/.claude/skills/` -- flat `.md` files
2. `~/.claude/plugins/cache/` -- glob `*/*/*/skills/*/SKILL.md` (layout: publisher/plugin/version/skills/skill-name)

Cross-reference the combined list against `all_tracked` in `.silver-bullet.json` and the
current task description. Surface candidates:
> Skills that may apply to this task: `/blast-radius` -- infra change; `/devops-skill-router` -- IaC toolchain

If no matches or both directories absent/empty: log "Skill discovery: no candidates surfaced."
Write results to `## Skills flagged at discovery` in the session log. **Do not invoke yet.**

---

### DISCUSS

**What it does:** Captures implementation decisions, gray areas, and user preferences for
this specific infrastructure phase before any planning begins. This is a thinking-partner
conversation -- you are the visionary, Claude is the builder capturing decisions so
downstream agents (researchers, planners) can act without re-asking you.

`/gsd:discuss-phase`                                                                     **REQUIRED** -- DO NOT SKIP

For DevOps phases, the discussion must include:
- Target environments (dev / staging / prod) and promotion strategy
- IaC toolchain (Terraform, Pulumi, CDK, Helm, raw manifests, etc.)
- State backend and locking strategy
- Naming conventions and tagging strategy

**What to expect:** An interactive conversation where Claude identifies gray areas specific
to your infrastructure phase, asks focused questions, and captures your decisions. Each
decision is recorded as either locked (your explicit choice) or left to Claude's discretion.
Typical duration: 5-10 minutes.

**Produces:** `.planning/phases/{phase}-CONTEXT.md`

**Conditional sub-steps** (invoke via Skill tool if applicable):
- If this phase introduces a **new service or major component**: `/system-design`
- If this phase introduces an **architectural decision**: write an ADR inline
  (structure: title, status, context, decision, consequences) before moving to blast radius.

**Contextual enrichment** (optional -- uses `/devops-skill-router` if DevOps plugins installed):
After capturing decisions, check if a matching DevOps plugin skill exists for the
IaC toolchain and cloud provider discussed. If available, invoke it for best-practice
guidance that feeds into quality gates. E.g., Terraform work -> HashiCorp's
`terraform-code-generation`; AWS deploy -> `deploy-on-aws`; k8s -> `kubernetes-operations`.
If no plugin is available, proceed without -- this is an enrichment, not a gate.

**If it fails:** Re-run `/gsd:discuss-phase` with more specific questions about
infrastructure requirements. If the discussion produces unclear or incomplete decisions,
focus on the specific gray areas that are blocking progress.

---

### BLAST RADIUS

**What it does:** Maps the change scope, downstream dependencies, failure scenarios,
rollback plan, and change window risk for this phase. This analysis determines how
cautiously the change must be applied.

`/blast-radius`                                                                          **REQUIRED** -- DO NOT SKIP

This step is ALWAYS required and comes BEFORE quality gates. Infrastructure changes can
have cascading effects -- a networking change can break compute, a security group change
can isolate services. Blast radius analysis catches these risks before planning begins.

**What to expect:** A structured report with a blast radius rating (LOW, MEDIUM, HIGH,
or CRITICAL), affected resources, downstream dependencies, rollback procedure, and
recommended change window. Typical duration: 2-5 minutes.

**Rating gate:**
- LOW / MEDIUM -> proceed to quality gates
- HIGH -> explicit user approval + runbook required before proceeding
- CRITICAL -> HARD STOP -- CAB (Change Advisory Board) review required

**If it fails:** Verify that the discuss phase produced sufficient context about the
infrastructure being changed. If the blast radius analysis cannot determine impact,
return to `/gsd:discuss-phase` and clarify the scope of changes.

---

### DEVOPS QUALITY GATES

**What it does:** Applies 7 IaC-adapted quality dimensions against the current
infrastructure design. This is a hard stop -- all dimensions must pass before planning.

`/devops-quality-gates`                                                                  **REQUIRED** -- DO NOT SKIP

The 7 dimensions (no usability dimension -- this is infrastructure, not UI):
1. **Modularity** -- Are resources properly modularized? No monolithic configs?
2. **Reusability** -- Can modules be reused across environments and projects?
3. **Scalability** -- Will the design handle growth without rewrites?
4. **Security** -- Are permissions least-privilege? Secrets managed? Encryption enabled?
5. **Reliability** -- Are there health checks, redundancy, and failure recovery?
6. **Testability** -- Can changes be validated before apply? Are tests defined?
7. **Extensibility** -- Can new resources be added without modifying existing ones?

All dimensions must pass. A fail on any dimension is a hard stop, not a warning.

**What to expect:** A consolidated pass/fail report for each dimension with specific
findings. Typical duration: 2-5 minutes.

**If it fails:** Fix the specific dimension that failed. Common fixes: extract hardcoded
values into variables (modularity), add tags and outputs (reusability), add encryption
configuration (security). Then re-run `/devops-quality-gates`.

---

### PLAN

**What it does:** Creates executable phase plans (PLAN.md files) through integrated
research and verification. Both the blast radius report and quality gate report feed
into the plan as hard requirements.

`/gsd:plan-phase`                                                                        **REQUIRED** -- DO NOT SKIP

For IaC phases, wave order follows dependency direction:
- Wave 1: networking and IAM (no dependencies on other new resources)
- Wave 2: storage and data (depends on networking/IAM)
- Wave 3: compute and services (depends on networking + storage)
- Wave 4: monitoring and alerting (depends on compute)
- Wave 5: CI/CD pipeline updates (depends on all above)

**What to expect:** Optional research phase (spawns parallel agents to investigate
technical approaches), then a planner agent creates PLAN.md files, followed by a plan
checker that verifies quality. If the checker finds issues, a revision loop runs
(up to 3 iterations). Typical duration: 5-15 minutes.

**Produces:** `.planning/phases/{phase}-RESEARCH.md`, `.planning/phases/{phase}-{N}-PLAN.md`

**Skill gap check (post-plan):** After the plan is written, cross-reference all installed
skills against the plan content. Flag any skill covering a concern not explicitly in the plan.
- Interactive: ask whether to add the flagged skill
- Autonomous: add to plan or log omission as autonomous decision
Write results to `## Skill gap check (post-plan)` in the session log.

**Contextual enrichment** (optional -- uses `/devops-skill-router`):
For AWS deployments, invoke `deploy-on-aws` for architecture recommendations.
For k8s work, invoke `kubernetes-operations` for manifest best practices.
These feed into the GSD plan as additional constraints, not replacements.

**If it fails:** Check that the discuss phase captured sufficient context. If the planner
lacks information, return to `/gsd:discuss-phase` to gather missing details, then re-run
`/gsd:plan-phase`. If the plan checker fails repeatedly, review the blast radius and
quality gate reports for conflicting requirements.

---

### EXECUTE

**What it does:** Runs wave-based parallel execution of plan tasks, applying IaC changes
to the lowest environment only. Each task produces an atomic git commit.

`/gsd:execute-phase`                                                                     **REQUIRED** -- DO NOT SKIP

Each wave applies to the **lowest environment only** (dev or equivalent). Higher environments
(staging, prod) are promoted in the ENVIRONMENT PROMOTION section after all phases complete.
Never apply to prod before verifying in staging.

`/test-driven-development` -- Before writing IaC implementation: establish                **REQUIRED** -- DO NOT SKIP
test-first discipline. For Terraform: Terratest / conftest / OPA.
For Helm: helm test / BATS. TDD applies per task within each GSD wave.

For each resource change within a wave:
- Run plan/dry-run output and confirm before apply
- Verify resource health after apply
- Commit atomically per task

**What to expect:** Subagent executors process each plan task. You will see plan/dry-run
output before any apply. After each apply, health checks confirm the resource is working.
Atomic commits are created per task. Typical duration: varies by infrastructure complexity.

**Produces:** Atomic git commits (one per task), `.planning/phases/{phase}-{N}-SUMMARY.md`

**Contextual enrichment** (optional -- uses `/devops-skill-router`):
When generating IaC code within GSD tasks, prefer the vendor-specific skill:
HashiCorp skills for `.tf` files, Pulumi skills for Pulumi programs,
awslabs skills for CDK/CloudFormation. The skill router determines which
plugin to use based on the file type and toolchain.

Autonomous mode: all executor agents use `run_in_background: true`. Merge gate after
each wave before the next begins.

**If it fails:** Use `/gsd:debug` to diagnose the failure. Common IaC failures: state
lock contention (check state backend), resource conflicts (check for naming collisions),
permission errors (check IAM policies). Fix the issue and re-run the failed wave.
Do not proceed to verify until execution completes successfully.

---

### VERIFY

**What it does:** Goal-backward verification against requirements. For DevOps phases,
this is infrastructure verification, NOT UAT.

`/gsd:verify-work`                                                                       **REQUIRED** -- DO NOT SKIP

For DevOps phases, verify:
- Health checks passing on all new/modified resources
- No configuration drift (plan shows no changes after apply)
- Monitoring and alerting firing correctly
- Rollback procedure tested in lower environment
- Runbook updated to reflect actual applied state

**What to expect:** Verification tests run against the deployed infrastructure. A
VERIFICATION.md file is produced with pass/fail status. If issues are found, gaps
are diagnosed and fix plans are created automatically. Typical duration: 5-10 minutes.

**Produces:** `.planning/phases/{phase}-VERIFICATION.md`

**If verification fails:** Invoke `/forensics` FIRST -- identify root cause before
retrying. Then:
- If root cause is implementation: re-run execute + verify only.
- If root cause is design/plan: return to discuss for the same phase.
Do not advance to code review until verification passes. Blind retries compound failures.

**Contextual enrichment** (optional -- uses `/devops-skill-router`):
For k8s deployments, use `k8s-troubleshooter` for pod/cluster diagnostics.
For monitoring setup, use `monitoring-observability` for SLO validation.
For AWS, use `aws-cost-optimization` to flag wasteful resources.

---

### CODE REVIEW

**What it does:** Peer IaC code quality review focused on infrastructure-specific concerns.

**Commands (all required, in order):**

1. `/code-review`                                                                **REQUIRED** -- DO NOT SKIP
   Structured peer code quality review (security, performance, correctness, readability).
   For IaC: covers hardcoded values, overly permissive security groups, missing encryption,
   unencrypted storage, missing tags, and resource-level access control gaps.
   Run this before dispatching the automated reviewer.

2. `/requesting-code-review`                                                     **REQUIRED** -- DO NOT SKIP
   Dispatches `superpowers:code-reviewer` via the Agent tool for IaC peer code quality review.

   **Review loop rule**: re-dispatch reviewer until it returns Approved TWICE IN A ROW.
   A single clean pass is not sufficient. The loop is self-limiting.

   IaC-specific review focus:
   - Hardcoded values that should be variables
   - Missing tags/labels
   - Security group rules that are too permissive
   - Resources missing encryption, backups, or monitoring
   - Plan output reviewed, not just source files

3. `/receiving-code-review`                                                      **REQUIRED** -- DO NOT SKIP
   Triage and accept/reject all items from review.

**What to expect:** The code reviewer examines all IaC changes with infrastructure-specific
lenses. It runs at least twice (requiring two consecutive approvals). Common findings:
hardcoded AMI IDs, missing Name tags, overly permissive `0.0.0.0/0` ingress rules,
unencrypted storage. Typical duration: 3-8 minutes per review pass.

**If it fails:** Address each finding individually. For disagreements on review findings,
document the rationale for accepting or rejecting. The review loop continues until two
consecutive clean passes -- do not shortcut this.

---

### POST-REVIEW EXECUTION (only if items were accepted in Code Review)

**What it does:** Creates and executes a plan to address accepted review items.

`/gsd:plan-phase` -- Create a plan to address accepted review items.
`/gsd:execute-phase` -- Implement the review-driven plan with atomic commits.

**What to expect:** A focused mini-cycle addressing only the accepted review items.
Same plan/execute discipline as the main cycle but scoped to review findings.

---

> **End of per-phase loop.** Return to Discuss for the next phase in ROADMAP.md.
> All phases must complete before moving to ENVIRONMENT PROMOTION.

---

## STEP 3: ENVIRONMENT PROMOTION

> Run after all phases complete in the lowest environment.
> Repeat this section for each environment tier (e.g., dev -> staging -> prod).

**What it does:** Promotes verified infrastructure changes from lower to higher environments.
The key principle: **never rewrite infrastructure definitions -- only the inputs change.**
Environment-specific `tfvars`, `values.yaml`, or parameter files control what differs
between environments.

**What to expect:** For each environment tier, the execute and verify steps are re-run
with environment-specific inputs. The infrastructure code stays identical -- only variables
change. This ensures that what was tested in dev is exactly what runs in staging and prod.

**Promote to next environment:**
Re-run `/gsd:execute-phase` targeting the next environment using environment-specific
tfvars or values files. Never rewrite infrastructure definitions -- only the inputs change.

**Verify promoted environment:**
Re-run `/gsd:verify-work` for the promoted environment. Health checks, drift detection,
and monitoring verification are mandatory before promoting to production.

**If it fails:** Roll back the promotion in the failed environment. Diagnose the issue in
the lower environment first -- if the change worked in dev but fails in staging, the
difference is almost always in the environment-specific inputs (different VPC IDs,
different instance sizes, different DNS zones). Fix the inputs, re-verify in the lower
environment, then re-promote.

---

## STEP 4: FINALIZATION

> Run once after all phases are complete in all environments.

**What it does:** Ensures test strategy, technical debt, documentation, and branch
cleanup are all addressed before the work ships. Each skill below is ALWAYS required.

### Testing Strategy

`/testing-strategy`                                                                      **REQUIRED** -- DO NOT SKIP

**What it does:** Establishes the testing approach for infrastructure code.

- Unit tests (module validation, policy-as-code: conftest/OPA)
- Integration tests (Terratest, BATS, Helm test)
- End-to-end tests (smoke tests against deployed environments)
- Drift detection schedule

**What to expect:** A structured test strategy document covering all test layers.

**Contextual enrichment** (optional -- uses `/devops-skill-router`):
Use `ci-cd` skill for pipeline-specific test integration.
Use `gitops-workflows` if the project uses ArgoCD/Flux.

**If it fails:** Review the IaC toolchain from discuss and ensure the test strategy
covers each tool in use (e.g., Terratest for Terraform, BATS for shell scripts).

### Technical Debt

`/tech-debt`                                                                             **REQUIRED** -- DO NOT SKIP

**What it does:** Surfaces technical debt introduced or discovered during this work.

**What to expect:** Structured items appended to `docs/tech-debt.md` with severity,
effort, and phase introduced. Format: `| Item | Severity | Effort | Phase introduced |`.

**If it fails:** Create `docs/tech-debt.md` if it does not exist, then re-run.

### Documentation

`/documentation`                                                                         **REQUIRED** -- DO NOT SKIP

**What it does:** Ensures all project documentation reflects the current state.

Minimum required files:
- `README.md` -- MUST reflect current version, features, and changes before release
- `docs/Master-PRD.md` (or `docs/Infra-PRD.md` for pure infra projects)
- `docs/Architecture-and-Design.md`
- `docs/Testing-Strategy-and-Plan.md`
- `docs/Runbooks.md` (DevOps-specific: one section per phase/component)
- `docs/CICD.md`

**Additional required at this step:**
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
  Sonnet base rate; Opus ~ 3x multiplier.
- Complete the session log: read path from `~/.claude/.silver-bullet/session-log-path`,
  edit that file to fill in Task, Approach, Files changed, Skills invoked,
  Agent Teams dispatched, Autonomous decisions, Outcome, KNOWLEDGE.md additions,
  Model, Virtual cost. If `~/.claude/.silver-bullet/session-log-path` is missing,
  create `docs/sessions/<today>-manual.md` from the session log template.
- Documentation agents writing to `docs/` run in the **main worktree only**
  (no `isolation: "worktree"`). Only implementation-touching agents use worktree isolation.

**What to expect:** All documentation files created or updated. Runbooks include a section
per infrastructure component with operational procedures.

**If it fails:** Check which specific files are missing or incomplete. Create missing
files from templates and re-run.

### Branch Cleanup

`/finishing-a-development-branch`                                                        **REQUIRED** -- DO NOT SKIP

**What it does:** Prepares the branch for merge -- rebases on the base branch, squashes
if appropriate, and ensures a clean diff.

**What to expect:** Branch is rebased and ready for PR creation.

**If it fails:** Resolve merge conflicts manually, then re-run.

---

## STEP 5: DEPLOYMENT

> Production deploy gate. Apply only after staging verification is complete.

**What it does:** Validates CI status, runs pre-deployment checks, and applies the
change to production with appropriate safeguards.

### CI/CD Pipeline

**CI/CD pipeline** -- Use existing pipeline or set one up before deploying.               **REQUIRED** -- DO NOT SKIP

Infrastructure pipelines MUST enforce: plan -> review -> apply (never auto-apply to prod).
Plan output MUST be stored as a pipeline artifact for audit.

**CI verification gate:**
- **CI MUST be green.** Check: `gh run list --limit 1 --json status,conclusion`
- Autonomous mode: poll every 30 seconds, up to 20 retries (10 min max).
  On timeout: log blocker, surface to user, **STOP deployment steps**.
- If CI is red: invoke `/gsd:debug`, fix the issue, re-push, re-check.
  Do NOT proceed to `/deploy-checklist` while CI is failing.

### Deploy Checklist

`/deploy-checklist`                                                                      **REQUIRED** -- DO NOT SKIP

DevOps additions to standard checklist:
- [ ] Blast radius assessment reviewed and approved
- [ ] Rollback procedure tested in staging
- [ ] On-call engineer notified and available
- [ ] Change window confirmed (off-peak unless incident)
- [ ] Monitoring dashboards open and baselining

**What to expect:** A checklist of pre-deployment items that must all be confirmed before
production apply. Any unchecked item blocks deployment.

### Production Apply

**Production apply** -- Execute plan in production.

One resource group at a time if blast radius is HIGH. Monitor dashboards during and
for 15 minutes after each apply. Verify resource health between groups.

**If deployment fails:** Roll back the affected resource group immediately. Use `/gsd:debug`
to diagnose. Do not proceed with remaining resource groups until the failure is resolved.
Escalate to on-call if rollback fails.

---

## STEP 6: SHIP

**What it does:** Creates a pull request from the verified, deployed work with a rich
auto-generated body including phase summaries and requirement coverage.

`/gsd:ship`                                                                              **REQUIRED** -- DO NOT SKIP

**What to expect:** A pull request is created with structured sections: summary, changes
per plan, requirements addressed, verification status, and key decisions. For DevOps work,
the PR also includes blast radius ratings and post-apply drift detection results.

**Produces:** Pull request with phase summaries, blast radius ratings, and requirement
coverage.

**If it fails:** Verify that the branch has been pushed to the remote, that `gh` CLI is
authenticated, and that verification passed. Use `/gsd:debug` for specific errors.

---

## STEP 7: RELEASE

**What it does:** Generates release notes and creates a GitHub Release with a git tag.

`/create-release`                                                                        **REQUIRED** -- DO NOT SKIP

**What to expect:** A git tag and GitHub Release with structured notes covering features,
fixes, and breaking changes. README must have been updated in the documentation step
before this step can proceed.

**Produces:** Git tag, GitHub Release with structured notes.

**If it fails:** Verify README.md is up to date (the release will block on a stale README).
Check that `gh` CLI is authenticated and the PR has been merged.

**Autonomous completion cleanup** (run after outputting structured summary):
```bash
rm -f ~/.claude/.silver-bullet/timeout ~/.claude/.silver-bullet/sentinel-pid \
      ~/.claude/.silver-bullet/session-start-time ~/.claude/.silver-bullet/timeout-warn-count
```
This clears the timeout sentinel so `timeout-check.sh` stops warning.

---

## STEP 8: TRANSITION TO DEVELOPMENT

> After RELEASE, offer to transition from infrastructure to application development.

**What it does:** After infrastructure is deployed and released, offers to switch the
active workflow from DevOps to the full development cycle for building application
features on top of the newly deployed infrastructure.

**Offer:**
> Infrastructure deployed. Continue developing features for the next milestone?

**If yes:**
1. Update `active_workflow` in `.silver-bullet.json` to `full-dev-cycle`
2. Start new milestone with `/gsd:new-milestone`

**What is preserved during transition:**
- `.planning/` artifacts -- all phase directories, summaries, and context files
- `.silver-bullet.json` config -- all settings, tracked skills, and configuration
- State file -- accumulated context, decisions, and performance metrics
- All committed history -- every atomic commit from infrastructure work

**If no:** The session ends. Infrastructure is deployed and released. The user can start
a new DevOps milestone later with `/gsd:new-milestone`.

---

## UTILITY COMMANDS REFERENCE

These GSD commands are available at any point during the workflow. They are not part of
the main guided flow but provide essential support for common situations.

| Command | What it does | When to use (DevOps context) |
|---------|-------------|------------------------------|
| `/gsd:debug` | Spawns parallel debug agents to diagnose issues and find root causes | For IaC: diagnose Terraform state drift, failed applies, resource conflicts, permission errors |
| `/gsd:quick` | Executes small ad-hoc tasks with GSD guarantees (atomic commits, state tracking) | For quick infra fixes: security group rule updates, tag corrections, variable changes |
| `/gsd:fast` | Executes trivial tasks inline without subagent overhead | Fix a typo in a Terraform variable description, update a tag value, correct a comment |
| `/gsd:resume-work` | Restores full project context from STATE.md and planning artifacts | Starting a new session on an existing infrastructure project |
| `/gsd:pause-work` | Creates structured handoff files preserving complete work state | Stopping mid-phase and need to resume in a new session |
| `/gsd:progress` | Summarizes recent work and routes to the next action | Check overall milestone progress and what phase is next |
| `/gsd:next` | Detects current state and auto-advances to the next logical step | Unsure what step comes next -- let GSD figure it out |
| `/gsd:add-phase` | Adds a new phase to the end of the current milestone | Discovered a new infrastructure layer needed after roadmap was created |
| `/gsd:insert-phase` | Inserts an urgent phase between existing phases using decimal numbering | Critical security fix needed between Phase 2 and Phase 3 (becomes Phase 2.1) |
| `/gsd:review` | Cross-AI peer review -- spawns external AI CLIs to independently review plans | Get adversarial review of infrastructure plans from multiple AI models |
| `/gsd:audit-milestone` | Verifies milestone achieved its definition of done | After all phases complete -- aggregates verifications, checks cross-phase integration |
| `/gsd:autonomous` | Drives remaining phases autonomously from discuss through execute | Run all remaining infrastructure phases without pausing at each decision point |
| `/gsd:complete-milestone` | Marks a milestone as complete, archives artifacts, tags the release | After ship + release -- archives the milestone and prepares for the next one |
| `/gsd:map-codebase` | Generates 7 structured analysis docs from existing codebase | Brownfield infrastructure projects -- understand existing IaC before planning |

---

## Review Loop Enforcement

Every review loop in this workflow (spec review, plan review, code review, verification) **MUST iterate until the reviewer returns Approved TWICE IN A ROW**. A single clean pass is not sufficient. No exceptions.

- Never stop because "issues are minor" or "close enough"
- Never accept a partial fix and move on without re-dispatching
- Never count a loop as done unless the reviewer outputs Approved on two consecutive passes
- The loop is self-limiting -- it ends naturally when two consecutive passes are clean
- Surface to the user only if the reviewer raises an issue it cannot resolve

---

## ENFORCEMENT RULES

- **GSD steps** are enforced by instruction (this file + CLAUDE.md) and GSD's own hooks.
  GSD steps MUST follow DISCUSS -> BLAST RADIUS -> QUALITY GATES -> PLAN -> EXECUTE -> VERIFY -> CODE REVIEW -> POST-REVIEW EXECUTION order per phase.
- **Silver Bullet skills** (blast-radius, devops-quality-gates, requesting-code-review, etc.) are enforced
  by PostToolUse hooks that track Skill tool invocations. "I already covered this" is NOT valid.
- Phase order is a hard constraint: do NOT start PLAN before `/devops-quality-gates` completes.
- **.yml/.yaml files are infrastructure code** -- they are NOT exempt from this workflow.
- For ANY bug or unexpected state encountered: use `/gsd:debug`.
- For trivial changes (typos, comment fixes in non-logic files): `touch ~/.claude/.silver-bullet/trivial`.
  This does NOT apply to YAML/JSON files in this workflow.
- For root-cause investigation after a completed, failed, or abandoned session: use `/forensics`.

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
