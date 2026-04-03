# DevOps Cycle Workflow

> **ENFORCED** — Silver Bullet hooks track Skill tool invocations for quality gates
> and gap-filling skills. GSD's own hooks (workflow guard, context monitor) enforce
> GSD step compliance independently. Both enforcement layers run in parallel.
>
> Completion audit BLOCKS git commit/push/deploy if required skills are missing.
> Context monitor warns at ≤35% remaining tokens, escalates at ≤25%.
>
> **IMPORTANT — .yml/.yaml files are NOT exempt from enforcement in this workflow.**
> GitHub Actions, Kubernetes manifests, Helm charts, and CI/CD pipeline definitions
> are infrastructure code. They MUST follow this workflow regardless of file extension.
> The trivial-change exemption in CLAUDE.md does NOT apply to declarative infra files.

## Invocation Methods

| What | How to invoke |
|------|---------------|
| GSD workflow steps (`/gsd:*`) | Slash command — type `/gsd:new-project`, `/gsd:discuss-phase`, etc. |
| Silver Bullet skills | Skill tool — `/blast-radius`, `/devops-quality-gates`, `/code-review`, etc. |

Use `/gsd:next` at any point to auto-advance to the next GSD step if unsure of current state.

---

## INCIDENT FAST PATH

> Use ONLY when responding to an active production incident requiring an emergency change.
> Skip this section entirely for planned DevOps work.

**Criteria for fast path**: Active incident with confirmed production impact AND change
cannot wait for full cycle without extending outage.

**Fast path steps**:

1. Document the incident: what is broken, what the proposed change is, expected outcome.
2. `/blast-radius` — Required even in incidents. A rushed unreviewed change can make
   incidents worse. If CRITICAL blast radius, escalate to CAB before proceeding.
3. Apply the minimal change in the lowest affected environment first, verify, then promote.
4. Create a post-incident review task: full cycle review of the emergency change after
   the incident resolves, including `/devops-quality-gates` retroactively.
5. Commit with `[HOTFIX]` prefix and reference the incident ticket.

---

## PROJECT INITIALIZATION

> Run once per project. Skip entirely if `.planning/PROJECT.md` already exists.

1. **Worktree** (inline decision) — Ask user: "Should I use a git worktree for this
   infrastructure change?" Strongly recommended for changes touching production resources.
   If yes, create one before proceeding.

2. `/gsd:new-project` — Kick off with questions, ecosystem research, requirements
   scoping, and roadmap generation. For DevOps projects, roadmap phases typically map
   to infrastructure layers: networking → storage → compute → monitoring → CI/CD.
   → Produces: `.planning/PROJECT.md`, `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`

---

## PER-PHASE LOOP

> Repeat steps 3–13 for each phase listed in `.planning/ROADMAP.md`.
> Recommended phase order for new infra: networking → storage → compute → monitoring → CI/CD.
> Use `/gsd:next` to confirm which phase is current.

---

### DISCUSS

3. `/gsd:discuss-phase` — Capture implementation decisions, gray areas, and           **REQUIRED** ← DO NOT SKIP
   user preferences for this specific infra phase before any planning begins.
   For DevOps phases, include:
   - Target environments (dev / staging / prod) and promotion strategy
   - IaC toolchain (Terraform, Pulumi, CDK, Helm, raw manifests, etc.)
   - State backend and locking strategy
   - Naming conventions and tagging strategy
   → Produces: `.planning/{phase}-CONTEXT.md`

   **Conditional sub-steps** (invoke via Skill tool if applicable):
   - If this phase introduces a **new service or major component**: `/system-design`
   - If this phase introduces an **architectural decision**: write an ADR inline
     (structure: title, status, context, decision, consequences) before moving to blast radius.

   **Contextual enrichment** (optional — uses `/devops-skill-router` if DevOps plugins installed):
   After capturing decisions, check if a matching DevOps plugin skill exists for the
   IaC toolchain and cloud provider discussed. If available, invoke it for best-practice
   guidance that feeds into quality gates. E.g., Terraform work → HashiCorp's
   `terraform-code-generation`; AWS deploy → `deploy-on-aws`; k8s → `kubernetes-operations`.
   If no plugin is available, proceed without — this is an enrichment, not a gate.

---

### BLAST RADIUS

4. `/blast-radius` — Map change scope, downstream dependencies, failure scenarios,    **REQUIRED** ← DO NOT SKIP
   rollback plan, and change window risk for this phase.
   Rating gate:
   - 🟢 LOW / 🟡 MEDIUM → proceed
   - 🟠 HIGH → explicit user approval + runbook required before proceeding
   - 🔴 CRITICAL → HARD STOP — CAB review required

---

### DEVOPS QUALITY GATES

5. `/devops-quality-gates` — Apply 7 IaC-adapted quality dimensions                  **REQUIRED** ← DO NOT SKIP
   (modularity, reusability, scalability, security, reliability, testability,
   extensibility) against the current IaC design. All dimensions must pass.
   ❌ is a hard stop, not a warning.

---

### PLAN

6. `/gsd:plan-phase` — Research → plan → verify plan. Blast radius report and         **REQUIRED** ← DO NOT SKIP
   quality gate report both feed into the plan as hard requirements.
   For IaC phases, wave order follows dependency direction:
   - Wave 1: networking and IAM (no dependencies on other new resources)
   - Wave 2: storage and data (depends on networking/IAM)
   - Wave 3: compute and services (depends on networking + storage)
   - Wave 4: monitoring and alerting (depends on compute)
   - Wave 5: CI/CD pipeline updates (depends on all above)
   → Produces: `.planning/{phase}-RESEARCH.md`, `.planning/{phase}-{N}-PLAN.md`

   **Contextual enrichment** (optional — uses `/devops-skill-router`):
   For AWS deployments, invoke `deploy-on-aws` for architecture recommendations.
   For k8s work, invoke `kubernetes-operations` for manifest best practices.
   These feed into the GSD plan as additional constraints, not replacements.

---

### EXECUTE

7. `/gsd:execute-phase` — Wave-based parallel execution. Each wave applies to the     **REQUIRED** ← DO NOT SKIP
   **lowest environment only** (dev or equivalent). Higher environments (staging, prod)
   are promoted in the ENVIRONMENT PROMOTION section (steps 14–15) after all phases
   complete. Never apply to prod before verifying in staging.
   For each resource change within a wave:
   - Run plan/dry-run output and confirm before apply
   - Verify resource health after apply
   - Commit atomically per task
   → Produces: atomic git commits (one per task), `.planning/{phase}-{N}-SUMMARY.md`

   **Contextual enrichment** (optional — uses `/devops-skill-router`):
   When generating IaC code within GSD tasks, prefer the vendor-specific skill:
   HashiCorp skills for `.tf` files, Pulumi skills for Pulumi programs,
   awslabs skills for CDK/CloudFormation. The skill router determines which
   plugin to use based on the file type and toolchain.

---

### VERIFY

8. `/gsd:verify-work` — Infrastructure verification (NOT UAT). Goal-backward          **REQUIRED** ← DO NOT SKIP
   verification against requirements. For DevOps phases, verify:
   - Health checks passing on all new/modified resources
   - No configuration drift (plan shows no changes after apply)
   - Monitoring and alerting firing correctly
   - Rollback procedure tested in lower environment
   - Runbook updated to reflect actual applied state
   → Produces: `.planning/{phase}-VERIFICATION.md`

   **Contextual enrichment** (optional — uses `/devops-skill-router`):
   For k8s deployments, use `k8s-troubleshooter` for pod/cluster diagnostics.
   For monitoring setup, use `monitoring-observability` for SLO validation.
   For AWS, use `aws-cost-optimization` to flag wasteful resources.

9. `/code-review` — Peer IaC code quality review.                                     **REQUIRED** ← DO NOT SKIP
   `superpowers:code-reviewer` — Run code-reviewer subagent immediately after.
   **Review loop rule**: re-dispatch reviewer until it returns ✅ Approved TWICE IN A ROW.
   A single clean pass is not sufficient. The loop is self-limiting.
   IaC-specific review focus:
   - Hardcoded values that should be variables
   - Missing tags/labels
   - Security group rules that are too permissive
   - Resources missing encryption, backups, or monitoring
   - Plan output reviewed, not just source files

10. `/requesting-code-review` — Request external or peer review.                     **REQUIRED** ← DO NOT SKIP

11. `/receiving-code-review` — Triage and accept/reject all items from 9–10.          **REQUIRED** ← DO NOT SKIP

---

### POST-REVIEW EXECUTION (only if items were accepted in step 11)

12. `/gsd:plan-phase` — Create a plan to address accepted review items.
13. `/gsd:execute-phase` — Implement the review-driven plan with atomic commits.

---

> **End of per-phase loop.** Return to step 3 for the next phase in ROADMAP.md.
> All phases must complete before moving to ENVIRONMENT PROMOTION.

---

## ENVIRONMENT PROMOTION

> Run after all phases complete in the lowest environment.
> Repeat this section for each environment tier (e.g., dev → staging → prod).

14. **Promote to next environment** — Re-run `/gsd:execute-phase` targeting the next
    environment using environment-specific tfvars or values files. Never rewrite
    infrastructure definitions — only the inputs change.

15. **Verify promoted environment** — Re-run `/gsd:verify-work` for the promoted
    environment. Health checks, drift detection, and monitoring verification are
    mandatory before promoting to production.

---

## FINALIZATION

> Run once after all phases are complete in all environments.

16. `/testing-strategy` — Define IaC test strategy:                                   **REQUIRED** ← DO NOT SKIP
    - Unit tests (module validation, policy-as-code: conftest/OPA)
    - Integration tests (Terratest, BATS, Helm test)
    - End-to-end tests (smoke tests against deployed environments)
    - Drift detection schedule

    **Contextual enrichment** (optional — uses `/devops-skill-router`):
    Use `ci-cd` skill for pipeline-specific test integration.
    Use `gitops-workflows` if the project uses ArgoCD/Flux.

17. **Tech-debt notes** (inline) — Append identified debt to `docs/tech-debt.md`.
    Format: `| Item | Severity | Effort | Phase introduced |`. Create file if needed.

18. `/documentation` — Update or create all project documentation.                    **REQUIRED** ← DO NOT SKIP
    Minimum required files:
    - `README.md` — MUST reflect current version, features, and changes before release
    - `docs/Master-PRD.md` (or `docs/Infra-PRD.md` for pure infra projects)
    - `docs/Architecture-and-Design.md`
    - `docs/Testing-Strategy-and-Plan.md`
    - `docs/Runbooks.md` (DevOps-specific: one section per phase/component)
    - `docs/CICD.md`

19. `/finishing-a-development-branch` — Branch rebase, cleanup, and merge prep.       **REQUIRED** ← DO NOT SKIP

---

## DEPLOYMENT

> Production deploy gate. Apply only after staging verification is complete.

20. **CI/CD pipeline** — Use existing pipeline or set one up before deploying.        **REQUIRED** ← DO NOT SKIP
    - Infrastructure pipelines MUST enforce: plan → review → apply (never auto-apply to prod)
    - Plan output MUST be stored as a pipeline artifact for audit
    - **CI MUST be green.** Check: `gh run list --limit 1 --json status,conclusion`
    - Autonomous mode: poll every 30 seconds, up to 20 retries (10 min max).
      On timeout: log blocker, surface to user, **STOP deployment steps**.
    - If CI is red: invoke `/gsd:debug`, fix the issue, re-push, re-check.
      Do NOT proceed to `/deploy-checklist` while CI is failing.

21. `/deploy-checklist` — Pre-deployment verification gate.                           **REQUIRED** ← DO NOT SKIP
    DevOps additions to standard checklist:
    - [ ] Blast radius assessment reviewed and approved
    - [ ] Rollback procedure tested in staging
    - [ ] On-call engineer notified and available
    - [ ] Change window confirmed (off-peak unless incident)
    - [ ] Monitoring dashboards open and baselining

22. **Production apply** — Execute plan in production. One resource group at a time
    if blast radius is HIGH. Monitor dashboards during and for 15 minutes after.

---

## SHIP

23. `/gsd:ship` — Create PR from verified, deployed work.                             **REQUIRED** ← DO NOT SKIP
    → Produces: pull request with phase summaries, blast radius ratings, and
    requirement coverage. Include post-apply drift detection results.

---

## RELEASE

24. `/create-release` — Generate release notes and create GitHub Release.             **REQUIRED** ← DO NOT SKIP
    → Produces: git tag, GitHub Release with structured notes. README must have
    been updated in step 18 before this step can proceed.

---

## Review Loop Enforcement

Every review loop in this workflow (spec review, plan review, code review, verification) **MUST iterate until the reviewer returns ✅ Approved TWICE IN A ROW**. A single clean pass is not sufficient. No exceptions.

- Never stop because "issues are minor" or "close enough"
- Never count a loop as done unless the reviewer outputs `✅ Approved` on two consecutive passes
- The loop is self-limiting — it ends naturally when two consecutive passes are clean
- Surface to the user only if the reviewer raises an issue it cannot resolve

---

## Enforcement Rules

- **GSD steps** are enforced by instruction (this file + CLAUDE.md) and GSD's own hooks.
  GSD steps MUST follow DISCUSS → BLAST RADIUS → QUALITY GATES → PLAN → EXECUTE → VERIFY order per phase.
- **Silver Bullet skills** (blast-radius, devops-quality-gates, code-review, etc.) are enforced
  by PostToolUse hooks that track Skill tool invocations. "I already covered this" is NOT valid.
- Phase order is a hard constraint: do NOT start PLAN before `/devops-quality-gates` completes.
- **.yml/.yaml files are infrastructure code** — they are NOT exempt from this workflow.
- For ANY bug or unexpected state encountered: use `/gsd:debug`.
- For trivial changes (typos, comment fixes in non-logic files): `touch /tmp/.silver-bullet-trivial`.
  This does NOT apply to YAML/JSON files in this workflow.
