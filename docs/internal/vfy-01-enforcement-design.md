# VFY-01 — Intermediate Verification Enforcement: Design Spec

**Status:** Design only (implementation deferred)
**Phase:** 64 — Verification & Init Improvements
**Requirement:** VFY-01
**GitHub issue:** https://github.com/alo-exp/silver-bullet/issues/72

---

## Problem Statement

The current enforcement model has two tiers:

- **Tier 1 (intermediate commits):** requires only `required_planning` skills (default: `silver-quality-gates`). Allows GSD execute-phase subagents to make atomic commits during development.
- **Tier 2 (final delivery):** requires the full `required_deploy` skill list (e.g., `verification-before-completion`, `code-review`, `testing-strategy`, etc.).

`verification-before-completion` is currently enforced only at the final delivery gate (`gh pr create`, `gh release create`, `deploy`). There is no enforcement at intermediate task boundaries — Claude can execute all plans in a phase without triggering verification at any sub-milestone. A user could complete 10 plans across 2 phases and not run `verification-before-completion` until the last git push before shipping.

The gap: individual plan completions (each of which represents a deliverable unit of work) are not verified before proceeding to the next plan. This allows verification debt to compound undetected until the final gate fires.

---

## Design: Intermediate Task Boundary Verification

### Hook Event

**`PreToolUse/Bash`** is the natural insertion point. `completion-audit.sh` already fires on this event for `git commit` and `git push` commands and implements the two-tier model. A new verification check can extend `completion-audit.sh`'s Tier 1 path (or a dedicated plan-boundary hook) that fires when a plan-completion boundary signal is detected.

Hook event mapping in `hooks.json`:
```json
{
  "matcher": "Bash",
  "hooks": [
    { "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/completion-audit.sh\"" }
  ]
}
```

`PostToolUse/Skill` is a secondary candidate: when the executor runs `/gsd:verify-work`, that PostToolUse event could trigger a plan-boundary check. However, `PostToolUse/Skill` fires after the skill runs, not before — this makes it unsuitable for blocking the _start_ of the next plan.

**Recommended hook event:** `PreToolUse/Bash` (already wired, already implements the two-tier model).

### Task Boundary Signals

The following command patterns indicate that a task or plan is being declared complete:

| Signal | Pattern | Practicality |
|--------|---------|-------------|
| **git commit** | `git commit ...` | ★★★★★ Already intercepted by completion-audit.sh; natural task boundary in GSD's atomic-commit model |
| **SUMMARY.md write** | Write/Edit tool targeting `*-SUMMARY.md` | ★★★☆☆ PostToolUse/Write event — reliable but requires a new hook matcher entry |
| **Explicit verify invocation** | `/gsd:verify-work` Skill call | ★★☆☆☆ PostToolUse/Skill — fires too late to block the action |
| **Plan finalization commit** | commit message matching `docs(0XX-0Y):` | ★★★★☆ Already present as the final commit per plan — detectable via commit message pattern |

The most practical signal is `git commit` (already intercepted by `completion-audit.sh`). In GSD's execution model, each completed task produces an atomic commit. The plan-completion boundary is naturally marked by the final task commit followed by the SUMMARY.md commit (`docs(0XX-0Y): complete ... plan`).

### What Would Block Completion at a Task Boundary

For the intermediate verification gate to be meaningful without being disruptive, the recommended design avoids blocking every individual task commit (which would break GSD's atomic-commit model). Instead:

**Recommended approach — Plan-boundary check:**
- When a `git commit` message matches the SUMMARY.md commit pattern (`docs({phase}-{plan}): complete`), check whether `verification-before-completion` was invoked since the last plan-boundary commit.
- If not: block the SUMMARY.md commit. The executor must invoke `/verification-before-completion` before the plan can be sealed.

This check fires at plan completion (not mid-execution), so it does not disrupt intra-plan task commits.

**Alternative approach — Tiered intermediate check:**
- Add `verification-before-completion` to Tier 1 (`required_planning`) only for plans whose metadata indicates they are "verification plans" (e.g., plans named `*-verify*` or with `type: verify` in frontmatter).
- This is narrower and easier to implement — modifies only `completion-audit.sh` Tier 1 logic with a commit-message pattern check.

**Not recommended:**
- Blocking every `git commit` regardless of context — this breaks GSD subagent execution.
- Requiring verification before every intermediate push — pushes to feature branches are deliberately Tier 1 only.

---

## Recommended Implementation Path (Deferred)

The following is the target implementation. All items are deferred to a future phase.

### Step 1: WORKFLOW.md current-flow detection

The `workflow-utils.sh` library parses flow counts (`count_flow_log_rows`, `count_complete_flow_rows`) but does not extract the _current active flow name_. Adding a `current_flow_name()` helper that reads the `| N |` row where the status column is `in-progress` (or the last non-complete row) would enable hooks to know which flow is active.

This is the foundational piece — without it, hooks cannot distinguish "we are in the EXECUTE flow" from "we are in the VERIFY flow."

### Step 2: New config key `required_verification`

Add to `templates/silver-bullet.config.json.default`:
```json
{
  "skills": {
    "required_verification": ["verification-before-completion"]
  }
}
```

This allows per-project customization of what "verified" means at a plan boundary.

### Step 3: Extend `completion-audit.sh` Tier 1 path

When `is_intermediate=true` AND the commit message indicates a plan seal (matches `docs\([0-9]+-[0-9]+\): complete`):
1. Read `required_verification` from config (default: `["verification-before-completion"]`).
2. Check the state file for the presence of each required verification skill.
3. If any are missing: emit `permissionDecision:"deny"` with message: `PLAN SEAL BLOCKED — run /verification-before-completion before completing this plan.`

Estimated lines changed: ~25 lines in `completion-audit.sh`.

### Step 4: WORKFLOW.md-gated firing

To avoid false positives in non-verification contexts, gate the new check on the active WORKFLOW.md flow:

```bash
# Only fire verification check when in EXECUTE or VERIFY flow
active_flow=$(current_flow_name "$workflow_file")
if [[ "$active_flow" == "EXECUTE" || "$active_flow" == "VERIFY" ]]; then
  # run required_verification check
fi
```

This prevents the check from firing in DISCUSS/PLAN flows where no code has been written yet.

---

## Implementation Complexity

**Size:** Medium  
**Files affected:** `completion-audit.sh`, `hooks/lib/workflow-utils.sh`, `templates/silver-bullet.config.json.default`  
**Risk:** Low — the new check is additive (new code path in Tier 1); existing Tier 2 behavior is unchanged  
**Prerequisite:** WORKFLOW.md current-flow parser in `workflow-utils.sh` (not yet built)

---

## Why Implementation Is Deferred

The plan-boundary check requires reliable detection of the current active FLOW from `WORKFLOW.md`. The current `workflow-utils.sh` parser counts completed flows but does not extract the active flow name. Implementing that parser is a self-contained task with its own testing requirements. This design doc specifies the target state; the parser work and the Tier 1 extension are tracked separately.

---

## References

- `hooks/completion-audit.sh` — Tier 1/Tier 2 logic; `emit_block()` pattern
- `hooks/stop-check.sh` — final delivery gate (Stop event, `decision:block` format)
- `hooks/lib/workflow-utils.sh` — flow log parsing utilities (`count_flow_log_rows`, `count_complete_flow_rows`)
- `hooks/hooks.json` — full hook event/script mapping
- GitHub issue #72 — VFY-01 tracking issue
