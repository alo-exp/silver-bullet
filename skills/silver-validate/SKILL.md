---
name: silver-validate
description: "Pre-build gap analysis: validates SPEC.md coverage in PLAN.md, surfaces assumptions, emits machine-readable findings with BLOCK/WARN/INFO severity"
argument-hint: ""
version: 0.1.0
---

# /silver:validate — Pre-Build Gap Analysis

Pre-build validation skill. Reads `.planning/SPEC.md` and `.planning/phases/` PLAN.md files, performs gap analysis between acceptance criteria and implementation plans, surfaces all assumptions, and emits machine-readable FINDING lines. BLOCK findings must be resolved before implementation begins.

Never modifies SPEC.md or PLAN.md files. Read-only analysis, write-only to `.planning/VALIDATION.md`.

## Pre-flight: Load Preferences

Read `silver-bullet.md §10` to load user workflow preferences before any other step.

```bash
grep -A 50 "^## 10\. User Workflow Preferences" silver-bullet.md | head -60
```

Display banner:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 SILVER BULLET ► VALIDATE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Step-Skip Protocol

When the user requests skipping any step:
1. Explain why the step exists (one sentence)
2. Offer: A. Accept skip  B. Lightweight alternative  C. Show me what you have
3. If user chooses A permanently: record in silver-bullet.md §10b and templates/silver-bullet.md.base §10b, commit both.

**Non-skippable gates:** Step 1 (Read SPEC.md), Step 3 (Gap Analysis), Step 5 (User Decision Gate). These cannot be skipped under any circumstances — they are the core validation contract.

## Step 0: Pre-flight Checks

Check required files:

1. Verify `.planning/SPEC.md` exists:
   ```bash
   ls .planning/SPEC.md
   ```
   If missing: emit the following and exit immediately (do not proceed to Step 1):
   ```
   FINDING [BLOCK] VAL-000: SPEC.md not found at .planning/SPEC.md
     Spec ref: pre-flight
     Plan ref: missing
     Resolution: Run /silver:spec to create SPEC.md before validating
   ```

2. Check for PLAN.md files in `.planning/phases/`:
   ```bash
   find .planning/phases/ -name "*PLAN.md" 2>/dev/null
   ```
   If none found: emit the following (INFO only — validation can still run for pre-planning awareness):
   ```
   FINDING [INFO] VAL-001: No PLAN.md files found in .planning/phases/
     Spec ref: pre-flight
     Plan ref: missing
     Resolution: Validation is running in pre-planning mode — gap analysis will show all AC items as uncovered
   ```

## Step 1: Read SPEC.md (NON-SKIPPABLE GATE)

**This step cannot be skipped. Do not proceed until SPEC.md is fully parsed.**

Read `.planning/SPEC.md` and extract:

**1a. Acceptance Criteria**
Parse the `## Acceptance Criteria` section. Extract each checklist item (lines starting with `- [ ]` or `- [x]`). Number them sequentially: AC-01, AC-02, etc.

**1b. Assumptions**
Parse all `[ASSUMPTION: ... | Status: ... | Owner: ...]` blocks from SPEC.md. Extract:
- Assumption text
- Status field value (Accepted / Follow-up-required / Blocking)
- Owner field value

**1c. Open Questions**
Parse the `## Open Questions` section if present. Extract each open item.

**1d. Spec metadata**
Read frontmatter fields: `spec-version`, `jira-id` (if present).

After parsing, display summary:
```
SPEC.md parsed:
  Acceptance Criteria: {N} items (AC-01 through AC-NN)
  Assumptions: {N} total ({A} Accepted, {F} Follow-up-required, {B} Blocking)
  Open Questions: {N} items
  Spec version: {spec-version or "not set"}
```

## Step 2: Read PLAN.md Files

Scan `.planning/phases/` for PLAN.md files in the current phase:

```bash
find .planning/phases/ -name "*PLAN.md" | sort
```

For each PLAN.md found, extract:
- Plan name and phase
- Task names (from `<name>` elements or `## Task N:` headings)
- `files_modified` list (from frontmatter)
- `requirements` list (from frontmatter) — these are spec traceability links

Build a coverage map:
- For each task: record which requirement IDs it claims to address
- Map requirement IDs back to AC items where possible (by ID pattern match or keyword)

Display summary:
```
PLAN.md files scanned: {N}
  Tasks found: {T} across {N} plans
  Tasks with requirement IDs: {R}
  Tasks without requirement IDs (orphan candidates): {O}
```

## Step 3: Gap Analysis (NON-SKIPPABLE GATE)

**This step cannot be skipped. All checks must run.**

**3a. AC Coverage Check (BLOCK severity)**

For each AC item (AC-01 through AC-NN): check whether any PLAN.md task:
- References the AC's requirement ID in its `requirements` frontmatter, OR
- Contains the AC item text (or key noun phrases) in its task name or description

If NO task addresses an AC item:
```
FINDING [BLOCK] VAL-{NNN}: Acceptance criterion AC-{NN} has no coverage in any PLAN.md
  Spec ref: ## Acceptance Criteria, item {AC-NN}: "{criterion text}"
  Plan ref: missing
  Resolution: Add a PLAN.md task that implements this criterion, or remove it from SPEC.md if out of scope
```

**3b. Assumption Status Check (WARN/INFO severity)**

For each assumption parsed in Step 1b:

If Status is `Follow-up-required`:
```
FINDING [WARN] VAL-{NNN}: Assumption requires follow-up before implementation
  Spec ref: [ASSUMPTION: {assumption text}] Status: Follow-up-required, Owner: {owner}
  Plan ref: {task if referenced, else "not addressed in any task"}
  Resolution: Resolve assumption status with {owner} before beginning implementation
```

If Status is `Blocking`:
```
FINDING [BLOCK] VAL-{NNN}: Blocking assumption not resolved
  Spec ref: [ASSUMPTION: {assumption text}] Status: Blocking, Owner: {owner}
  Plan ref: {task if referenced, else "not addressed in any task"}
  Resolution: This assumption must be resolved before any implementation begins — contact {owner}
```

If Status is `Accepted`:
```
FINDING [INFO] VAL-{NNN}: Assumption accepted — surfaced for developer awareness
  Spec ref: [ASSUMPTION: {assumption text}] Status: Accepted, Owner: {owner}
  Plan ref: awareness only
  Resolution: No action required — assumption is accepted
```

**3c. Orphan Task Check (WARN severity)**

For each PLAN.md task that has NO requirement IDs in frontmatter AND no detectable link to any AC item:
```
FINDING [WARN] VAL-{NNN}: Orphan task — no traceability to SPEC.md
  Spec ref: missing
  Plan ref: "{task name}" in {plan file}
  Resolution: Add a requirements: [AC-NN, ...] field to this task's PLAN.md frontmatter, or confirm the task is infrastructure/chore (not feature work)
```

**3d. Open Question Check (WARN severity)**

For each open question from Step 1c that is not marked resolved:
```
FINDING [WARN] VAL-{NNN}: Open question unresolved
  Spec ref: ## Open Questions, item: "{question text}"
  Plan ref: missing
  Resolution: Answer or defer this question before implementation to avoid mid-build scope changes
```

After all checks complete, tally findings:
```
Gap analysis complete:
  BLOCK: {B} findings
  WARN:  {W} findings
  INFO:  {I} findings
```

## Step 4: Surface Assumptions (VALD-05)

Print ALL [ASSUMPTION] blocks from SPEC.md as a numbered awareness list regardless of their status. This is mandatory — developers must see all assumptions before implementation begins.

```
## Assumptions Awareness (VALD-05)

The following assumptions underpin this spec. Review before implementing.

{N}. [ASSUMPTION: {text}]
     Status: {status} | Owner: {owner}

{N+1}. [ASSUMPTION: {text}]
     Status: {status} | Owner: {owner}

... (all assumptions listed)
```

If SPEC.md contains zero assumptions, display:
```
## Assumptions Awareness (VALD-05)

No [ASSUMPTION: ...] blocks found in SPEC.md.
Consider whether implicit assumptions exist that should be made explicit.
```

## Step 5: User Decision Gate (NON-SKIPPABLE GATE)

**This step cannot be skipped. User must acknowledge findings before proceeding.**

**If any BLOCK findings exist:**

Display all BLOCK findings prominently:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 VALIDATION BLOCKED — {B} BLOCK FINDING(S)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

{list all BLOCK findings with full FINDING format}
```

Then ask:

> BLOCK findings must be resolved before implementation begins. What would you like to do?
>
> A. Return to /silver:spec to resolve the gaps in SPEC.md
> B. Show me the BLOCK findings again
> C. I have resolved the issues — re-run /silver:validate

Do NOT allow proceeding to Step 6 while BLOCK findings exist. If user selects C, restart from Step 0.

**If only WARN/INFO findings (zero BLOCKs):**

Display findings summary:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 VALIDATION ADVISORY — {W} WARN, {I} INFO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

{list WARN findings}
{list INFO findings}
```

Then ask:

> WARN findings will be recorded in .planning/VALIDATION.md and will appear in the PR description.
>
> A. Accept and proceed — write VALIDATION.md and continue
> B. Return to /silver:spec to address WARN findings first
> C. Show me all findings again

Only proceed to Step 6 when user selects A.

**If zero findings of any severity:**

Display:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 VALIDATION CLEAN — ZERO FINDINGS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

All acceptance criteria are covered. No unresolved assumptions or open questions.
```

Automatically proceed to Step 6.

## Step 6: Write .planning/VALIDATION.md

Write `.planning/VALIDATION.md` using the Write tool with ALL findings in machine-readable format.

This file is consumed by `pr-traceability.sh` (Plan 02) to populate PR description deferred items.

```markdown
---
spec-version: {spec-version from SPEC.md frontmatter, or "unknown"}
validation-date: {today's date in YYYY-MM-DD}
finding-counts:
  block: {B}
  warn: {W}
  info: {I}
---

# Validation Findings

Generated by /silver:validate on {date}. Consumed by pr-traceability.sh for PR description.

## BLOCK Findings

{Each BLOCK finding in exact format:}
FINDING [BLOCK] VAL-{NNN}: {description}
  Spec ref: {section and item}
  Plan ref: {task or "missing"}
  Resolution: {required action}

## WARN Findings

{Each WARN finding in exact format:}
FINDING [WARN] VAL-{NNN}: {description}
  Spec ref: {section and item}
  Plan ref: {task or "missing"}
  Resolution: {required action}

## INFO Findings

{Each INFO finding in exact format:}
FINDING [INFO] VAL-{NNN}: {description}
  Spec ref: {section and item}
  Plan ref: awareness only
  Resolution: {action or "No action required"}
```

If zero findings, write an empty findings file:
```markdown
---
spec-version: {spec-version}
validation-date: {date}
finding-counts:
  block: 0
  warn: 0
  info: 0
---

# Validation Findings

No findings — all acceptance criteria covered, no unresolved assumptions or open questions.
```

## Step 7: Summary Banner

Display final summary:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 VALIDATION COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Findings: {B} BLOCK, {W} WARN, {I} INFO
  Assumptions surfaced: {N}
  Status: {PASS (no BLOCK findings) | BLOCKED (has BLOCK findings)}

  Findings written to: .planning/VALIDATION.md
```

If Status is PASS, the workflow may proceed to implementation.
If Status is BLOCKED, implementation is gated until BLOCK findings are resolved.
