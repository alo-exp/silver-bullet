---
name: "silver:ensure-docs"
title: "Ensure Docs"
description: This skill should be used to bootstrap, reconcile, and semantically audit complete task-level documentation updates from docs/doc-scheme.md + docs/doc-scheme.json
argument-hint: "[--bootstrap | --reconcile-brownfield | --from-hook --task <id> --gaps <path> | --recover-scheme]"
version: 0.1.0
---

# /silver:ensure-docs — Documentation Authority

Single source of docs governance in Silver Bullet:
- Human policy: `docs/doc-scheme.md`
- Runtime contract: `docs/doc-scheme.json`

This skill is the only doc orchestrator for:
1. init-time bootstrap (`--bootstrap`)
2. brownfield reconciliation (`--reconcile-brownfield`)
3. hook-gap remediation (`--from-hook --task ... --gaps ...`)
4. contract recovery (`--recover-scheme`)
5. semantic freshness audits against the current project state

## Safety Rules

1. Never delete user docs.
2. Never silently overwrite user docs.
3. When user switches to SB alternatives, move replaced artifacts to `docs/archive/<timestamp>/...` with a manifest record.
4. Every move must be traceable: source, destination, reason, task id, timestamp.
5. Keep `docs/doc-scheme.md` and `docs/doc-scheme.json` synchronized.

## Semantic Audit Expectations

`silver:ensure-docs` is not satisfied by structural validation alone. It must:
- read every governed doc that claims to describe current project state
- compare those claims to the current codebase, hooks, commands, workflows, and runtime behavior
- distinguish live/reference docs from archival or historical snapshots
- flag stale, misleading, or contradictory prose instead of treating it as current
- keep brownfield checklist scaffolding aligned to the actual governed-doc inventory, not placeholder keys

## Mode: `--bootstrap`

Use during `/silver:init` for both greenfield and brownfield repos.

### Greenfield

1. Create minimal doc skeletons (non-destructive if files already exist).
2. Create `docs/doc-scheme.md` and `docs/doc-scheme.json`.
3. Seed `required_docs` inventory, `mandatory_updated_docs`, and `enforcement.granularity_levels=[2,3]`.
4. Seed `docs/task-doc-checklist.json` scaffold aligned to contract keys using real governed doc keys only.

### Brownfield

1. Discover existing docs by:
   - filename similarity
   - title/topic semantics
   - section-anchor matches
2. For each required SB doc, ask user:
   - Preserve existing structure
   - Switch to SB default structure
3. Preserve path:
   - Record mapping in `doc-scheme.json` (`preserved_mappings`)
   - Update `doc-scheme.md` to reflect mapping decision
4. Switch path:
   - Move prior user-preferred artifact to `docs/archive/<timestamp>/...`
   - Create/update SB canonical doc
   - Copy relevant content forward into canonical doc
   - Record move in `archive_moves` and archive manifest
5. Run a semantic freshness audit over the governed docs that remain live.

## Mode: `--from-hook --task <id> --gaps <path>`

This is the zero-miss remediation path after stop/completion hooks find gaps.

1. Load the hook gap report JSON at `--gaps`.
2. Read task evidence and impact:
   - task metadata
   - git diff and changed files
   - changed APIs, schemas, config, behavior
   - affected tests and operational impact
3. Build a required-doc coverage matrix from `doc-scheme.json.required_docs`.
4. Update all docs that should change based on the completed work and downstream effects.
5. Ensure checklist coverage includes every required doc and required section.
6. Re-run gate checks mentally and do not finish until the checklist is fully compliant.
7. Audit the resulting live docs semantically against the current repo state and mark archival docs explicitly as historical when they are not meant to track current behavior.

Important:
- Incomplete task context is not a stopping condition.
- Infer missing context from code + diffs + gap report and continue.
- Escalate only for true product-intent ambiguity that cannot be derived from repo/work.

## Mode: `--recover-scheme`

If `docs/doc-scheme.json` is missing/invalid:

1. Try git-history restore of last valid scheme.
2. Validate JSON shape and required fields.
3. If restore fails, reconstruct deterministically from:
   - current `docs/doc-scheme.md`
   - current docs inventory
   - SB default template
4. Write recovered scheme and a short recovery note in docs history/changelog.

## Contract Requirements (`docs/doc-scheme.json`)

At minimum:
1. `enforcement.granularity_levels` with `[2,3]`
2. `required_docs[]` with canonical keys and optional `required_sections[]`
3. `mandatory_updated_docs[]`
4. `preserved_mappings[]` for brownfield preserve decisions
5. `archive_moves[]` for switch-to-SB move operations
6. `sync` pointers for `doc-scheme.md` and `task-doc-checklist.json`

## Best-Practice Absorption (from `gsd:docs-update`)

Adopt:
1. verify-only capability
2. preserve/supplement behavior for hand-written docs
3. explicit operation manifesting
4. bounded verify-fix loops
5. regression-halt discipline

Delegation rule:
- Default: operate as standalone `silver:ensure-docs`.
- Delegate to a legacy docs workflow only when the session/repo is explicitly
  operating in that legacy docs mode.
