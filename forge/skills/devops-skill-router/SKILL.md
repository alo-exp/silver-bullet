---
name: devops-skill-router
description: This skill should be used for context-aware routing table that maps IaC toolchain, cloud provider, and DevOps context to the best available plugin skill. Used by the devops-cycle workflow at contextual trigger points. Not a workflow step — a lookup utility.
user-invocable: false
version: 0.1.0
---

# /devops-skill-router — Context-Aware DevOps Skill Routing

Maps the current DevOps context (IaC tool, cloud provider, task type) to the best
available plugin skill. Silver Bullet's devops-cycle workflow references this router
at contextual trigger points — it is NOT a required workflow step.

**When to use**: The devops-cycle workflow invokes this router automatically at
trigger points (DISCUSS, PLAN, EXECUTE, VERIFY, FINALIZATION). Also invocable
it directly to find the best skill for a specific DevOps task.

---

## Step 1: Read installed plugins from config

Read `.silver-bullet.json` and check the `devops_plugins` section:

```json
"devops_plugins": {
  "hashicorp": true/false,
  "awslabs": true/false,
  "pulumi": true/false,
  "devops-skills": true/false,
  "wshobson": true/false
}
```

If `devops_plugins` is missing or the config doesn't exist, assume all are `false`.

---

## Step 2: Identify the current context

Determine which context applies from the current task, user discussion, or file
being worked on. Multiple contexts can apply simultaneously.

---

## Step 3: Route to the best available skill

Use the routing table below. For each context, try skills in priority order.
Skip any skill whose plugin is not installed. If no plugin is available for a
context, proceed without — Silver Bullet's own quality gates still apply.

### Routing Table

#### Infrastructure as Code — Authoring

| Context | Trigger | Priority 1 | Priority 2 | Priority 3 |
|---------|---------|-----------|-----------|-----------|
| **Terraform HCL authoring** | `.tf` files, HCL code, Terraform plans | hashicorp: `terraform-code-generation` | devops-skills: `iac-terraform` | (none — proceed without) |
| **Terraform module design** | Creating reusable modules, module registry | hashicorp: `terraform-module-generation` | devops-skills: `iac-terraform` | (none) |
| **Terraform provider dev** | Writing custom TF providers | hashicorp: `terraform-provider-development` | (none) | |
| **Terragrunt** | `terragrunt.hcl`, multi-env Terraform | devops-skills: `iac-terraform` | (none) | |
| **Pulumi programs** | Pulumi TypeScript/Python/Go IaC | pulumi: `pulumi-best-practices` | pulumi: `pulumi-component` | (none) |
| **Pulumi components** | ComponentResource authoring | pulumi: `pulumi-component` | pulumi: `pulumi-best-practices` | (none) |
| **Pulumi Automation API** | Programmatic Pulumi (CI/CD integration) | pulumi: `pulumi-automation-api` | (none) | |
| **CDK / CloudFormation** | AWS CDK constructs, CF templates | awslabs: `deploy-on-aws` | (none) | |

#### Infrastructure as Code — Migration

| Context | Trigger | Priority 1 | Priority 2 |
|---------|---------|-----------|-----------|
| **Terraform → Pulumi** | Migrating from TF to Pulumi | pulumi: `pulumi-terraform-to-pulumi` | (none) |
| **CDK → Pulumi** | Migrating from AWS CDK to Pulumi | pulumi: `pulumi-cdk-to-pulumi` | (none) |
| **CloudFormation → Pulumi** | Migrating CF to Pulumi | pulumi: `cloudformation-to-pulumi` | (none) |
| **ARM/Bicep → Pulumi** | Migrating Azure ARM to Pulumi | pulumi: `pulumi-arm-to-pulumi` | (none) |
| **GCP → AWS migration** | Migrating GCP infra to AWS | awslabs: `migration-to-aws` | (none) |

#### Cloud Provider — AWS

| Context | Trigger | Priority 1 | Priority 2 |
|---------|---------|-----------|-----------|
| **AWS architecture** | Deploy to AWS, architecture decisions | awslabs: `deploy-on-aws` | devops-skills: `aws-cost-optimization` |
| **AWS serverless** | Lambda, API Gateway, Step Functions, EventBridge | awslabs: `aws-serverless` | (none) |
| **AWS databases** | RDS, DynamoDB, Aurora DSQL | awslabs: `databases-on-aws` | (none) |
| **AWS geospatial** | Maps, geocoding, routing | awslabs: `amazon-location-service` | (none) |
| **AWS Amplify** | Full-stack apps with Amplify | awslabs: `aws-amplify` | (none) |
| **AWS cost optimization** | Cloud spend, unused resources | devops-skills: `aws-cost-optimization` | awslabs: `deploy-on-aws` |

#### Kubernetes

| Context | Trigger | Priority 1 | Priority 2 |
|---------|---------|-----------|-----------|
| **K8s troubleshooting** | Pod failures, CrashLoopBackOff, OOM, cluster issues | devops-skills: `k8s-troubleshooter` | wshobson: `kubernetes-operations` |
| **K8s manifests / Helm** | Writing Deployments, Services, Helm charts | wshobson: `kubernetes-operations` | devops-skills: `k8s-troubleshooter` |
| **K8s security** | RBAC, NetworkPolicies, PodSecurityPolicies | wshobson: `kubernetes-operations` | devops-skills: `k8s-troubleshooter` |

#### CI/CD & GitOps

| Context | Trigger | Priority 1 | Priority 2 |
|---------|---------|-----------|-----------|
| **CI/CD pipelines** | GitHub Actions, Jenkins, GitLab CI, CircleCI | devops-skills: `ci-cd` | (none) |
| **GitOps** | ArgoCD, Flux CD, multi-cluster sync | devops-skills: `gitops-workflows` | wshobson: `kubernetes-operations` |

#### Monitoring & Operations

| Context | Trigger | Priority 1 | Priority 2 |
|---------|---------|-----------|-----------|
| **Monitoring / observability** | Prometheus, Grafana, Datadog, SLOs, alerts | devops-skills: `monitoring-observability` | (none) |
| **Packer images** | Machine images, AMIs, Azure images | hashicorp: `packer-builders` | hashicorp: `packer-hcp` |

#### Secrets & Configuration

| Context | Trigger | Priority 1 | Priority 2 |
|---------|---------|-----------|-----------|
| **Secrets management** | Vault, secret rotation, env config | pulumi: `pulumi-esc` | (none) |

---

## Step 4: Invoke the matched skill

For the highest-priority available skill:

1. Invoke it. The exact syntax depends on how each plugin
   registers its skills. Try these patterns in order:
   - `/<plugin-namespace>:<skill-name>` (e.g., `/hashicorp:terraform-code-generation`)
   - `/<skill-name>@<plugin-name>` (e.g., `/terraform-code-generation@hashicorp`)
   - `/<skill-name>` (e.g., `/terraform-code-generation`)
   Use whichever pattern works for the installed plugin version.
2. Feed the skill's output into the current workflow phase as additional context.
3. If the skill invocation fails (not found, error), silently fall through to the
   next priority. If all priorities fail, proceed without — log a note:
   "No DevOps plugin available for [context]. Proceeding with Silver Bullet defaults."

**Important**: Routed skills are enrichments, not gates. A failed or missing plugin
skill NEVER blocks the workflow. Only Silver Bullet's own quality gates and GSD
steps are enforcement gates.

---

## Quick Reference: Plugin → Skills Map

### hashicorp/agent-skills
- `terraform-code-generation` — Write HCL, generate Terraform configs
- `terraform-module-generation` — Create reusable Terraform modules
- `terraform-provider-development` — Develop custom Terraform providers
- `packer-builders` — Build machine images (AWS, Azure, Windows)
- `packer-hcp` — HCP Packer registry integration

### awslabs/agent-plugins
- `deploy-on-aws` — AWS architecture recommendations, IaC generation
- `aws-serverless` — Lambda, API Gateway, EventBridge, Step Functions
- `databases-on-aws` — Database design, Aurora DSQL
- `migration-to-aws` — GCP-to-AWS infrastructure migration
- `amazon-location-service` — Geospatial (maps, geocoding, routing)
- `aws-amplify` — Full-stack app development

### pulumi/agent-skills
- `pulumi-best-practices` — Pulumi program best practices
- `pulumi-component` — ComponentResource authoring
- `pulumi-automation-api` — Automation API patterns
- `pulumi-esc` — Environments, Secrets, Configuration
- `pulumi-terraform-to-pulumi` — Migrate Terraform → Pulumi
- `pulumi-cdk-to-pulumi` — Migrate AWS CDK → Pulumi
- `cloudformation-to-pulumi` — Migrate CloudFormation → Pulumi
- `pulumi-arm-to-pulumi` — Migrate Azure ARM/Bicep → Pulumi

### ahmedasmar/devops-claude-skills
- `iac-terraform` — Terraform/Terragrunt IaC management
- `k8s-troubleshooter` — Kubernetes troubleshooting and diagnostics
- `aws-cost-optimization` — AWS cost analysis and optimization
- `ci-cd` — CI/CD pipeline design and troubleshooting
- `gitops-workflows` — ArgoCD and Flux CD multi-cluster
- `monitoring-observability` — Metrics, alerts, dashboards, SLOs

### wshobson/agents
- `kubernetes-operations` — K8s manifests, Helm, GitOps, security
