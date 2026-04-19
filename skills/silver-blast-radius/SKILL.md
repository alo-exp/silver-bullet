---
name: silver-blast-radius
description: Assess the blast radius of a proposed infrastructure or DevOps change before planning. Maps change scope, downstream dependencies, failure scenarios, rollback plan, and change window risk. Required before /devops-quality-gates in the devops-cycle workflow.
version: 0.1.0
---

# /silver-blast-radius — Blast Radius Assessment

Performs a structured pre-change risk analysis before any infrastructure or
DevOps change proceeds to quality gates or planning. Every field must be filled.
Vague answers ("unknown", "TBD") are not acceptable — investigate until concrete.

---

## Step 1: Map the change scope

List every resource this change will touch:

| Resource | Action | Environment |
|----------|--------|-------------|
| (e.g. `k8s/deployment/api`) | CREATE / MODIFY / DELETE | dev / staging / prod |

Include:
- IaC resources (Terraform state entries, Helm releases, k8s manifests)
- CI/CD pipeline definitions (GitHub Actions workflows, Jenkinsfiles)
- Secrets and config maps
- DNS, load balancer, and networking rules
- IAM roles and policies
- Monitoring, alerting, and logging configuration

---

## Step 2: Map downstream dependencies

For each resource being modified or deleted, list what depends on it:

| Resource changed | Downstream dependents | Coupling type |
|------------------|-----------------------|---------------|
| (resource name) | (services/systems that use it) | Hard / Soft / None |

**Coupling types**:
- **Hard** — dependent fails or degrades immediately if this resource changes
- **Soft** — dependent degrades gracefully or eventually (retry logic, cache, fallback)
- **None** — no runtime dependency

---

## Step 3: Enumerate failure scenarios

For each resource with Hard or Soft coupling, describe what breaks:

| Resource | Failure mode | Impact | Affected users/systems |
|----------|-------------|--------|------------------------|
| (resource) | (what breaks) | (severity: P1/P2/P3) | (who is affected) |

---

## Step 4: Define rollback plan

| Step | Action | Time estimate | Data loss risk |
|------|--------|---------------|----------------|
| 1 | (first rollback action) | (e.g. 2 min) | None / Low / Medium / High |
| 2 | ... | ... | ... |

**Rollback must be**:
- Fully executable without the original engineer present
- Achievable within the change window's rollback budget
- Tested in a lower environment if the change is HIGH or CRITICAL

---

## Step 5: Assess change window

Answer each question:

1. **Timing risk**: Is this change during peak traffic hours? (yes/no + reasoning)
2. **Concurrent changes**: Are other changes deploying in the same window? (yes/no + list)
3. **Rollback window**: How long is available for rollback before SLA breach?
4. **On-call coverage**: Is an on-call engineer available for the full window? (yes/no)
5. **Runbook exists**: Is there a runbook for this change type? (yes/no + link or "must create")

---

## Step 6: Assign blast radius rating

Rate the overall change using this rubric:

| Rating | Criteria |
|--------|----------|
| 🟢 LOW | Single resource, no hard dependents, instant rollback, off-peak |
| 🟡 MEDIUM | ≤3 resources, soft dependents only, rollback <10 min, low traffic |
| 🟠 HIGH | Multiple resources OR any hard dependent OR rollback >10 min OR peak hours |
| 🔴 CRITICAL | Prod data mutation, IAM/secret rotation, DNS cutover, >5 hard dependents, no tested rollback |

---

## Step 7: Gate enforcement

Output the completed assessment, then apply the gate:

- **🟢 LOW** → Proceed to `/devops-quality-gates`.
- **🟡 MEDIUM** → Proceed to `/devops-quality-gates`. Note: ensure rollback is documented.
- **🟠 HIGH** → **STOP**. Present the assessment to the user. Require explicit approval before proceeding. If approved, require a runbook before execution.
- **🔴 CRITICAL** → **HARD STOP**. Output:
  > ❌ CRITICAL blast radius. This change requires Change Advisory Board (CAB) review and an approved change request before proceeding. Do NOT continue until CAB approval is confirmed by the user.

  Do not proceed to quality gates or planning until the user explicitly confirms CAB approval.
