---
name: devops-quality-gates
title: "Silver: DevOps Quality Gates"
description: "This skill should be used to apply 7 IaC-adapted quality dimensions against infrastructure and DevOps changes. Use after /silver:blast-radius and before /silver:plan in the devops-cycle workflow. Skips usability because IaC has no direct user interface. All dimensions must pass — any ❌ is a hard stop."
user-invocable: false
version: 0.1.0
---

# /devops-quality-gates — IaC Quality Review

Applies 7 quality dimensions adapted for infrastructure-as-code, CI/CD pipelines,
and DevOps workflows. Every dimension must pass before the current IaC change
proceeds to `silver:plan`. A ❌ is a hard stop — redesign before continuing.

**Plugin root**: Determine `PLUGIN_ROOT` from this file's path. This file lives at
`${PLUGIN_ROOT}/skills/devops-quality-gates/SKILL.md`, so the plugin root is two
directories up.

**Dimension skills root**: Set `DIMENSION_SKILLS_ROOT="${PLUGIN_ROOT}/skills"` by default. If this skill is running from a Codex native mirror such as `$HOME/.codex/skills/devops-quality-gates/SKILL.md` and `${PLUGIN_ROOT}/skills/modularity/SKILL.md` does not exist, use the hidden packaged Codex source root instead:

```bash
DIMENSION_SKILLS_ROOT="$HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet/current/skill-source"
```

Do not require dimension helper skills to appear in the Codex skill picker. They are implementation dependencies of `devops-quality-gates`, not user-facing routes.

---

## Step 0: Mode detection (dual invocation)

`devops-quality-gates` runs **twice** in a full devops-cycle flow: pre-plan (design-time) and pre-ship (adversarial). Use the same canonical detector as product quality gates: `hooks/lib/quality-gates-mode.sh` (`sb_qg_detect_mode`).

`record-skill` writes distinguishable markers: `devops-quality-gates-design` (pre-plan) or `devops-quality-gates-adversarial` (pre-ship when PLAN.md + passed VERIFICATION.md exist). Delivery gates require the adversarial marker on devops-cycle ship paths.

---

## Step 1: Load quality dimension skills

Use the active runtime file-reading mechanism to read each of the following core dimension files:

1. `${DIMENSION_SKILLS_ROOT}/modularity/SKILL.md`
2. `${DIMENSION_SKILLS_ROOT}/scalability/SKILL.md`
3. `${DIMENSION_SKILLS_ROOT}/security/SKILL.md`
4. `${DIMENSION_SKILLS_ROOT}/reliability/SKILL.md`
5. `${DIMENSION_SKILLS_ROOT}/testability/SKILL.md`

Then apply the built-in observability and change-safety checks below. Together these form the 7 IaC dimensions.

> **Note**: Usability is intentionally excluded — infrastructure has no direct user-facing interface. If this change introduces a developer-facing CLI, dashboard, or runbook that humans interact with, include usability.

---

## Step 2: IaC interpretation guide

Apply each dimension through an infrastructure-as-code lens:

### Modularity (IaC)
- Terraform modules / Helm charts are the unit of modularity
- Each module has a single responsibility (networking, compute, storage, monitoring)
- No monolithic root modules that provision unrelated resources
- Variable inputs and output values are the module API — keep them minimal and stable

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

### Observability (IaC)
- Metrics, logs, traces, dashboards, or alerts are provisioned with the resource where applicable
- Alert thresholds and ownership are explicit, not tribal knowledge
- Pipeline failures expose actionable diagnostics
- Runbooks link to the relevant monitoring surfaces

### Change-Safety (IaC)
- Rollback path is documented and realistic
- Plan/diff output is reviewed before apply/deploy
- State migrations, destructive changes, and replacement resources are called out
- Changes are staged or canaryable when blast radius is non-trivial

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
| Scalability   | ✅/❌  | ...   |
| Security      | ✅/❌  | ...   |
| Reliability   | ✅/❌  | ...   |
| Testability   | ✅/❌  | ...   |
| Observability | ✅/❌  | ...   |
| Change-Safety | ✅/❌  | ...   |
| Usability     | ⚠️ N/A | No user-facing interface in this IaC change |

### Failures requiring redesign
[List each ❌ item with the specific rule violated and required fix]

### Overall: PASS / FAIL
```

---

## Step 5: Gate enforcement

- If **all applicable dimensions pass** → output "DevOps quality gates passed. Proceed to `silver:plan`."
- If **any dimension fails** → output "DevOps quality gates FAILED. Redesign required before planning."
  List each failure with the specific rule and required corrective action.
  Do NOT proceed to `silver:plan` until all failures are resolved and this skill is re-run.

**There are no exceptions.** A ❌ is a hard stop, not a warning.
