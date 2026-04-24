---
id: silver-devops
title: Silver — DevOps/Infrastructure Workflow
description: Infrastructure, CI/CD, and deployment workflow
trigger:
  - "silver devops"
  - "devops workflow"
  - "infrastructure"
  - "CI/CD"
  - "deploy"
---

# Silver DevOps — Infrastructure Workflow

## When to Use
For infrastructure, CI/CD, deployment, pipeline, terraform, IaC, or cloud work.

## Steps

### Step 1: ORIENT
Understand current infrastructure:
- Read existing IaC files
- Check CI/CD configuration
- Note deployment processes
- Understand environments

### Step 2: BLAST RADIUS
Before changes:
- Assess change impact
- Identify dependencies
- Plan rollback strategy
- Document risk

### Step 3: QUALITY GATES (pre-plan)
Run quality gates (trigger: "quality gates") on the infrastructure plan.

### Step 4: PLAN
Plan infrastructure changes (trigger: "plan phase"). Include:
- Terraform/IaC changes
- CI/CD modifications
- Deployment procedures
- Rollback procedures

### Step 5: IMPLEMENT
Execute the plan (trigger: "execute phase"). Follow:
- Infrastructure as Code
- Immutable deployments
- Security best practices
- Compliance requirements

### Step 6: VALIDATE
Validate infrastructure:
- Lint IaC (terraform validate, etc.)
- Dry run in staging
- Security scan
- Compliance check

### Step 7: VERIFY
Run verification (trigger: "verify work"). Include:
- Infrastructure tests
- Deployment tests
- Smoke tests post-deploy

### Step 8: REVIEW
Run code review (trigger: "code review"). Focus on:
- Security
- Compliance
- Disaster recovery
- Cost implications

### Step 9: QUALITY GATES (pre-ship)
Run quality gates (trigger: "quality gates").

### Step 9b: Doc-Scheme Compliance (conditional)
If `docs/doc-scheme.md` exists: verify CHANGELOG entry, ARCHITECTURE currency (infra topology changes), knowledge/lessons entries before deploying. Skip if absent.

### Step 10: DEPLOY
Deploy infrastructure:
- Apply to staging first
- Validate staging
- Apply to production
- Monitor deployment

### Step 11: SHIP
Create PR with infrastructure changes (trigger: "ship").

## Session Logging
Document infrastructure decisions and changes in `docs/sessions/YYYY-MM-DD.md`.

## Exit Condition
Infrastructure implemented, verified, deployed, and PR created.
