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
/sb:init
```

No GSD, Superpowers, or Anthropic knowledge-work plugin install is required for
SB's default lifecycle.

---

## What Works In SB-Only Mode

All current SB lifecycle skills are available without GSD:

| Area | SB-owned skills |
|------|-----------------|
| Routing and setup | `/sb`, `/sb:init`, `/sb:context` |
| Clarification and specs | `/sb:clarify`, `/sb:spec`, `/sb:ingest`, `/sb:validate` |
| Planning and execution | `/sb:plan`, `/sb:execute`, `/sb:feature`, `/sb:bugfix`, `/sb:ui`, `/sb:fast` |
| Quality and security | `/silver-quality-gates`, `/security`, `/sb:secure`, `/sb:verify`, `/verify-tests` |
| Review discipline | `/sb:review-request`, `/sb:review`, `/sb:review-triage`, `/sb:completion-audit` |
| Shipping and release | `/sb:branch-finish`, `/sb:ship`, `/sb:release`, `/sb:create-release` |
| Docs and continuity | `/sb:ensure-docs`, `/sb:add`, `/sb:remove`, `/sb:rem`, `/sb:scan`, `/sb:handoff`, `/sb:forensics` |
| DevOps governance | `/sb:blast-radius`, `/devops-quality-gates`, `/sb:devops` |

Provider/tool-specific DevOps plugins remain optional enrichments. SB owns the
workflow and gates around them.

---

## Enforcement Hooks

All enforcement hooks activate after `/sb:init`:

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
the host agent may do so as an explicit external-tool request. `/sb` routes
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
