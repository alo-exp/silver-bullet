---
name: "silver:quality-gates"
title: "Quality Gates"
description: >
  This skill should be used for dual-mode: design-time checklist (pre-plan) or adversarial audit (pre-ship). Mode auto-detected from artifact state.
version: 0.1.0
---

> **Recommended model:** Use the active host default. Quality gates are structured checklist evaluation, and Silver Bullet does not switch models automatically.

# /silver:quality-gates — Consolidated Quality Review

Applies Silver Bullet's quality dimensions in sequence. Operates in **dual-mode**: design-time checklist when run pre-plan, or adversarial audit when run pre-ship. Mode is auto-detected from artifact state — no manual configuration required.

The standard product sweep is **8 core dimensions**. `ai-llm-safety` is included conditionally when the phase includes AI/LLM behavior, model calls, prompts, evals, agents, retrieval, or automated decisioning.

**Plugin root**: Determine `PLUGIN_ROOT` from this file's path. This file lives at
`${PLUGIN_ROOT}/skills/silver-quality-gates/SKILL.md`, so the plugin root is two directories up.

**Dimension skills root**: Set `DIMENSION_SKILLS_ROOT="${PLUGIN_ROOT}/skills"` by default. Dimension helpers are hidden implementation dependencies, so their packaged files may be named `SILVER_SOURCE` instead of `SKILL.md`.

If this skill is running from a Codex native mirror such as `$HOME/.codex/skills/silver-quality-gates/SKILL.md` and `${PLUGIN_ROOT}/skills/modularity/SKILL.md` does not exist, resolve the hidden packaged Codex source root in this order:

```bash
for candidate in \
  "$HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet/current/skill-source" \
  "$(find "$HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet" -mindepth 2 -maxdepth 2 -type d -path '*/skill-source' 2>/dev/null | sort -V | tail -n 1)"; do
  if [[ -n "$candidate" && -f "$candidate/modularity/SILVER_SOURCE" ]]; then
    DIMENSION_SKILLS_ROOT="$candidate"
    break
  fi
done
```

Do not require dimension helper skills to appear in the Codex skill picker. They are implementation dependencies of `silver:quality-gates`, not user-facing routes.

If any required dimension source is unavailable, first repair the missing dependency from its marketplace source before any fallback:

1. Reinstall or update Silver Bullet from the active host marketplace source (`/plugin install alo-exp/silver-bullet` or the host-specific marketplace equivalent; Codex package key: `silver-bullet@alo-labs-codex`).
2. Re-run the dimension source lookup.
3. Only if installation/repair fails or the user explicitly declines, stop or mark the quality-gates run degraded. Do not silently replace missing dimension skills with ad hoc reasoning.

---

## Step 0: Mode Detection

Detect operating mode from artifact state before loading dimension skills.

Run these detection commands:

```bash
PLAN_EXISTS=$(ls .planning/phases/*/**-PLAN.md 2>/dev/null | head -1)
VERIFY_PASSED=$(grep -l "status: passed" .planning/VERIFICATION.md 2>/dev/null)
```

Use the disambiguation table to determine mode:

| PLAN.md exists? | VERIFICATION.md with `status: passed`? | Mode |
|-----------------|----------------------------------------|------|
| No | No | **design-time** (pre-plan quality gate) |
| No | Yes | **Invalid state** — STOP with error: "VERIFICATION.md shows passed but no PLAN.md found. Cannot determine quality gate context." |
| Yes | No | **design-time** (mid-execution, treat as pre-plan) |
| Yes | Yes | **adversarial** (pre-ship quality gate) |

**Record the detected mode.** It controls Step 2 behavior for all applicable dimensions.

---

## Step 1: Load quality dimension skills

Use the active runtime file-reading mechanism to read each of the following files. For every dimension path, read the first file that exists in this order: `SILVER_SOURCE`, `SILVER_SOURCE.md`, `SILVER_SKILL.md`, `SKILL.md`.

1. `${DIMENSION_SKILLS_ROOT}/modularity/{SILVER_SOURCE,SILVER_SOURCE.md,SILVER_SKILL.md,SKILL.md}`
2. `${DIMENSION_SKILLS_ROOT}/reusability/{SILVER_SOURCE,SILVER_SOURCE.md,SILVER_SKILL.md,SKILL.md}`
3. `${DIMENSION_SKILLS_ROOT}/scalability/{SILVER_SOURCE,SILVER_SOURCE.md,SILVER_SKILL.md,SKILL.md}`
4. `${DIMENSION_SKILLS_ROOT}/security/{SILVER_SOURCE,SILVER_SOURCE.md,SILVER_SKILL.md,SKILL.md}`
5. `${DIMENSION_SKILLS_ROOT}/reliability/{SILVER_SOURCE,SILVER_SOURCE.md,SILVER_SKILL.md,SKILL.md}`
6. `${DIMENSION_SKILLS_ROOT}/usability/{SILVER_SOURCE,SILVER_SOURCE.md,SILVER_SKILL.md,SKILL.md}`
7. `${DIMENSION_SKILLS_ROOT}/testability/{SILVER_SOURCE,SILVER_SOURCE.md,SILVER_SKILL.md,SKILL.md}`
8. `${DIMENSION_SKILLS_ROOT}/extensibility/{SILVER_SOURCE,SILVER_SOURCE.md,SILVER_SKILL.md,SKILL.md}`
9. `${DIMENSION_SKILLS_ROOT}/ai-llm-safety/{SILVER_SOURCE,SILVER_SOURCE.md,SILVER_SKILL.md,SKILL.md}` only when the phase includes AI/LLM behavior

---

## Step 2: Apply each dimension

For each dimension, run its **Planning Checklist (design-time mode) or Full Audit (adversarial mode) as determined in Step 0** against the current design or plan.

- **design-time mode:** Run the **Planning Checklist** for each dimension. Focus on design decisions, architectural alignment, and upfront risk identification. N/A is acceptable for implementation-specific items that cannot yet be evaluated.
- **adversarial mode:** Run the **Full Audit** for each dimension. Focus on implementation quality, edge cases, security gaps, and production readiness. N/A requires strong justification — assume the worst case unless evidence proves otherwise.

Work through all items. For each checklist item mark it:

- ✅ Pass — requirement is satisfied
- ❌ Fail — requirement is violated; note the specific gap
- ⚠️ N/A — dimension does not apply to this phase (provide one-sentence justification)

---

## Step 2b: Conditional Domain Packs

After the 8 core dimensions, determine whether specialized domain packs apply.
When any trigger matches, invoke or apply `silver:domain-audit` for the selected
pack set and include its pack results as conditional rows in the quality report.

| Trigger | Domain packs |
|---|---|
| API routes, controllers, SDKs, webhooks, OpenAPI, or auth boundary | `api-contract`, `test-health`, `security` dimension cross-check |
| Schema, migrations, ORM, SQL, persistence, caches, or backfills | `data-contract`, `performance-resource`, `test-health` |
| Package manifests, lockfiles, new imports, generated clients, toolchains | `dependency-supply` |
| Bundle size, latency, memory, queue/job throughput, caching, hot paths | `performance-resource` |
| Module moves, repo structure, layering, architecture drift | `structure-maintainability`, `architecture-adr` |
| CI workflows, build scripts, release automation, Docker, deploy scripts | `ci-workflow`, `environment-secrets` |
| Env vars, config files, secrets, deployment manifests | `environment-secrets`, `runtime-release` |
| Public site pages, help content, metadata, redirects, docs migration | `content-search`, `accessibility` when user-facing |
| UI components, layout, forms, keyboard/focus behavior | `ui-system`, `accessibility` |
| Release/deploy/canary/rollback/incident/retro/benchmark scope | `runtime-release`, `incident-retro`, `benchmark-eval` as applicable |

Domain pack findings use the normalized schema from `docs/evidence-schema.md`
and `silver:domain-audit`.
Unresolved `BLOCK` findings are hard-stop quality-gate failures. Deferred
`WARN` findings must be filed through `silver:add` before this gate can pass.

---

## Step 3: Produce consolidated report

Output a report in this format:

```
## Quality Gates Report

| Dimension     | Result | Notes |
|---------------|--------|-------|
| Modularity    | ✅/❌  | ...   |
| Reusability   | ✅/❌  | ...   |
| Scalability   | ✅/❌  | ...   |
| Security      | ✅/❌  | ...   |
| Reliability   | ✅/❌  | ...   |
| Usability     | ✅/❌  | ...   |
| Testability   | ✅/❌  | ...   |
| Extensibility | ✅/❌  | ...   |
| AI/LLM Safety | ✅/❌/N/A | included only when applicable |
| Domain Packs  | ✅/❌/N/A | selected `silver:domain-audit` packs and result |

### Failures requiring redesign
[List each ❌ item with the specific rule violated and required fix]

### Overall: PASS / FAIL
```

---

## Step 4: Gate enforcement

- If **all dimensions pass:**
  - design-time mode → output "Quality gates passed (design-time). Proceed to planning."
  - adversarial mode → output "Quality gates passed (pre-ship). Proceed to shipping."
- If **any dimension fails** → output "Quality gates FAILED. Redesign required before proceeding."
  List each failure with the specific rule and required corrective action.
  Do NOT proceed until all failures are resolved and this skill is re-run.

**There are no exceptions.** A ❌ is a hard stop, not a warning.

---

## Step 5: Backlog capture (mandatory)

After gate enforcement, scan the report for any items that:
- Were marked ⚠️ N/A but may apply in a future phase
- Were advisory suggestions noted during evaluation (not hard failures)
- Were deferred "nice-to-have" improvements

For each such item, **immediately capture it in the configured SB backlog**
instead of silently dropping it. Read `.silver-bullet.json`:

- `issue_tracker: "github"` -> create a GitHub Issue with `gh issue create`
  when the CLI is authenticated.
- `issue_tracker: "gsd"` or missing -> append the item to
  `.planning/ROADMAP.md` under a Backlog section, creating the section if
  needed.

If no items were deferred or suggested, output: "No backlog items to capture from this quality review."
