---
name: devops-quality-gates
description: Apply 7 IaC-adapted quality dimensions against infrastructure and DevOps changes. Use after /silver-blast-radius and before /gsd:plan-phase in the devops-cycle workflow. Skips usability (no user-facing interface in IaC). All dimensions must pass — any ❌ is a hard stop.
user-invocable: false
version: 0.1.0
---

# /devops-quality-gates — IaC Quality Review

Applies 7 quality dimensions adapted for infrastructure-as-code, CI/CD pipelines,
and DevOps workflows. Every dimension must pass before the current IaC change
proceeds to `/gsd:plan-phase`. A ❌ is a hard stop — redesign before continuing.

**Plugin root**: Determine `PLUGIN_ROOT` from this file's path. This file lives at
`${PLUGIN_ROOT}/skills/devops-quality-gates/SKILL.md`, so the plugin root is two
directories up.

---

## Step 1: Load quality dimension skills

Use the Read tool to read each of the following files:

1. `${PLUGIN_ROOT}/skills/modularity/SKILL.md`
2. `${PLUGIN_ROOT}/skills/reusability/SKILL.md`
3. `${PLUGIN_ROOT}/skills/scalability/SKILL.md`
4. `${PLUGIN_ROOT}/skills/security/SKILL.md`
5. `${PLUGIN_ROOT}/skills/reliability/SKILL.md`
6. `${PLUGIN_ROOT}/skills/testability/SKILL.md`
7. `${PLUGIN_ROOT}/skills/extensibility/SKILL.md`

> **Note**: Usability is intentionally excluded — infrastructure has no direct user-facing interface. If this change introduces a developer-facing CLI, dashboard, or runbook that humans interact with, include usability.

---

## Step 2: IaC interpretation guide

Apply each dimension through an infrastructure-as-code lens:

### Modularity (IaC)
- Terraform modules / Helm charts are the unit of modularity
- Each module has a single responsibility (networking, compute, storage, monitoring)
- No monolithic root modules that provision unrelated resources
- Variable inputs and output values are the module API — keep them minimal and stable

### Reusability (IaC)
- Modules are parameterized — no hardcoded environment names, region strings, or account IDs
- Shared modules live in a registry or `modules/` directory, not copy-pasted
- Naming conventions are consistent so modules compose predictably

### Scalability (IaC)
- Resources are sized with auto-scaling where the service supports it
- No hardcoded replica counts that become the ceiling
- State backends support concurrent access (remote state with locking)
- Pipeline parallelism: independent stages run in parallel, not serialized

### Security (IaC)
- IAM roles follow least privilege — no `*` actions or resources in production policies
- Secrets are stored in a secrets manager — never in `.tf` files, `.env` committed to git, or pipeline env vars as plaintext
- Network security groups are restrictive by default — no `0.0.0.0/0` ingress without explicit justification
- Encryption at rest and in transit enabled for all data stores
- Pipeline jobs that handle secrets use masked/protected variables

### Reliability (IaC)
- Resources have health checks, auto-restart, and liveness probes
- Multi-AZ or multi-region where required by SLA
- Runbook exists for failure scenarios identified in blast radius assessment
- Drift detection is enabled (e.g., Terraform state checks, k8s reconciliation)
- Change is idempotent — running it twice produces the same result

### Testability (IaC)
- Modules are parameterized inputs/outputs — this IS dependency injection for IaC
- Module versions are pinned — this IS determinism for IaC
- Modules are independently plannable/applyable — these ARE seams for isolated testing
- `terraform plan` / `helm diff` / `kubectl dry-run` IS the test execution layer
- New IaC modules have a corresponding test (Terratest, conftest, BATS, or similar)
- Plan output is reviewed as part of the PR, not just apply logs

### Extensibility (IaC)
- New environments can be added by adding a new tfvars file, not by duplicating modules
- Module interfaces don't need to change to add a new resource of the same type
- Tags/labels are applied consistently so new tooling can be layered without module changes

---

## Step 3: Apply each dimension

For each dimension, run its planning checklist against the current IaC change using
the IaC interpretation guide above. Mark each item:

- ✅ Pass — requirement is satisfied
- ❌ Fail — requirement is violated; note the specific gap
- ⚠️ N/A — genuinely not applicable to this change (one-sentence justification required)

---

## Step 4: Produce consolidated report

Output a report in this format:

```
## DevOps Quality Gates Report

| Dimension     | Result | Notes |
|---------------|--------|-------|
| Modularity    | ✅/❌  | ...   |
| Reusability   | ✅/❌  | ...   |
| Scalability   | ✅/❌  | ...   |
| Security      | ✅/❌  | ...   |
| Reliability   | ✅/❌  | ...   |
| Testability   | ✅/❌  | ...   |
| Extensibility | ✅/❌  | ...   |
| Usability     | ⚠️ N/A | No user-facing interface in this IaC change |

### Failures requiring redesign
[List each ❌ item with the specific rule violated and required fix]

### Overall: PASS / FAIL
```

---

## Step 5: Gate enforcement

- If **all applicable dimensions pass** → output "DevOps quality gates passed. Proceed to `/gsd:plan-phase`."
- If **any dimension fails** → output "DevOps quality gates FAILED. Redesign required before planning."
  List each failure with the specific rule and required corrective action.
  Do NOT proceed to `/gsd:plan-phase` until all failures are resolved and this skill is re-run.

**There are no exceptions.** A ❌ is a hard stop, not a warning.
