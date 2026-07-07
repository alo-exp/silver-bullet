# Silver Triage Skill Scenario

## Skill: silver-triage
## Context: Generic review finding triage and PM filing

### Scenario: Standalone Triage After Review

**Trigger:** "Triage these review findings on `src/auth/login.ts`"

**Workflow:**
1. Host receives raw findings from a prior review (not self-triaged).
2. Launch triage subagent at **host model** with `/silver:triage`.
3. Classify each finding: VALID-BLOCKER, VALID-NONBLOCKER, DUPLICATE, ALREADY-FIXED, FALSE-POSITIVE, or NEEDS-USER-DECISION.
4. File VALID-* items via `/silver:add`; link duplicates to existing PM ids.
5. Emit triage table in `.planning/REVIEW.md` and `silver-triage-v1` JSON.

### Scenario: Artifact Contract Input

**Trigger:** Triage after `artifact-reviewer` on `docs/specs/SPEC.md`

**Workflow:**
1. Load artifact contract from `artifact-review-assessor` Contract Sources table.
2. Map MUST-FIX → VALID-BLOCKER, NICE-TO-HAVE → VALID-NONBLOCKER, DISMISS → FALSE-POSITIVE.
3. Do not file dismissed items.

### Scenario: Custom PM Adapter Filing

**Trigger:** Project has `issue_tracker: "custom"` with configured adapter

**Workflow:**
1. Build `silver-triage-issue-v1` JSON payload with fingerprint via `scripts/silver-add.sh`.
2. Run `adapter-dedup` when `dedupe_command` is configured.
3. Run `adapter-create`; parse `id`, `url`, `status`.
4. STOP with configuration error if adapter missing — no silent fallback to local/GitHub.

### Scenario: NEEDS-USER-DECISION Escalation

**Trigger:** Finding is genuinely ambiguous against charter

**Workflow:**
1. Classify as NEEDS-USER-DECISION.
2. Stop and ask user — do not file or fix.
3. Resume triage after user decision.

### Scenario: Review-Fix Ladder Integration

**Trigger:** Orchestrator on `rung_N_triage` inside `silver:review-fix-ladder`

**Workflow:**
1. Review subagent (rung model) produced raw findings only.
2. Triage subagent (host model) runs `/silver:triage` — not the review agent.
3. Orchestrator files valid issues before `rung_N_fix_parallel`.
4. Fix agents use host model; parallel only per triage grouping.
