# Silver Bullet Without GSD

GSD is no longer required for Silver Bullet's core software-engineering
lifecycle. SB owns routing, context, planning, execution, review, security,
verification, ship, release, docs governance, and hook enforcement.

This page remains as a compatibility note for users who previously understood
SB as an orchestration layer around GSD.

---

## Install

```text
/plugin install alo-exp/silver-bullet
```

Install `jq` if you do not have it:

```bash
brew install jq    # macOS
apt install jq     # Linux
```

Then initialize your project:

```text
/silver:init
```

No GSD, Superpowers, or Anthropic knowledge-work plugin install is required for
SB's default lifecycle.

---

## What Works In SB-Only Mode

All current SB lifecycle skills are available without GSD:

| Area | SB-owned skills |
|------|-----------------|
| Routing and setup | `/silver`, `/silver:init`, `/silver:context` |
| Clarification and specs | `/silver:clarify`, `/silver:spec`, `/silver:ingest`, `/silver:validate` |
| Planning and execution | `/silver:plan`, `/silver:execute`, `/silver:feature`, `/silver:bugfix`, `/silver:ui`, `/silver:fast` |
| Quality and security | `/silver-quality-gates`, `/security`, `/silver:secure`, `/silver:verify`, `/verify-tests` |
| Review discipline | `/silver:review-request`, `/silver:review`, `/silver:review-triage`, `/silver:completion-audit` |
| Shipping and release | `/silver:branch-finish`, `/silver:ship`, `/silver:release`, `/silver:create-release` |
| Docs and continuity | `/silver:ensure-docs`, `/silver:add`, `/silver:remove`, `/silver:rem`, `/silver:scan`, `/silver:handoff`, `/silver:forensics` |
| DevOps governance | `/silver:blast-radius`, `/devops-quality-gates`, `/silver:devops` |

Provider/tool-specific DevOps plugins remain optional enrichments. SB owns the
workflow and gates around them.

---

## Enforcement Hooks

All enforcement hooks activate after `/silver:init`:

| Hook | What it enforces |
|------|------------------|
| `session-start` | Injects SB core rules and resets branch-scoped ephemeral gate files |
| `record-skill.sh` | Records supported skill invocations to the state file |
| `dev-cycle-check.sh` | Blocks non-trivial source edits before SB planning gates complete |
| `completion-audit.sh` | Blocks final delivery when required SB gates are missing |
| `ci-status-check.sh` | Blocks unsafe push/PR/release operations when CI is failing |
| `stop-check.sh` | Blocks completion claims when required gates are missing |
| `prompt-reminder.sh` | Re-injects active workflow context and missing steps |
| `forbidden-skill-check.sh` | Blocks deprecated or forbidden execution modes |
| `roadmap-freshness.sh` | Blocks commits that desynchronize summaries and roadmap state |
| `phase-archive.sh` | Preserves phase evidence before milestone/archive operations |
| `semantic-compress.sh` | Compresses context after supported skill invocations |
| `pr-traceability.sh` | Adds spec, requirement, and deferred-item traceability to PRs |
| `spec-floor-check.sh` | Blocks spec-gated planning when minimum spec evidence is absent |
| `uat-gate.sh` | Blocks milestone release when UAT evidence is missing, failing, or stale |

---

## Legacy GSD Compatibility

SB still recognizes legacy GSD/Superpowers marker names during migration and
state normalization. These aliases exist so older projects can be resumed safely;
they are not required dependencies for new workflows.

If a user explicitly asks to run an external GSD command and GSD is installed,
the host agent may do so as an explicit external-tool request. `/silver` routes
ordinary lifecycle requests to SB-owned skills by default.

---

## When To Add Optional Plugins

Add external plugins when they extend SB into a specialized domain:

1. DevOps/provider plugins for Terraform, Kubernetes, AWS, Pulumi, or similar
   infrastructure work.
2. Data, browser, document, spreadsheet, presentation, GitHub, Gmail, or other
   tool plugins when the task needs those capabilities.
3. Second-opinion reviewers when the user asks for external review or the change
   is high-risk enough to justify extra perspectives.

Avoid installing overlapping lifecycle plugins as default SB prerequisites.
