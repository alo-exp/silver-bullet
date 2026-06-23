# Review Fix Ladder Skill Scenario

## Skill: silver-review-fix-ladder
## Context: Progressive review/fix against context-derived goals

### Scenario: Explicit Path Scope

**Trigger:** "Run silver:review-fix-ladder on `scripts/review-fix-ladder.py`"

**Workflow:**
1. Scope locks to the named file without prompting for repo-wide review
2. Derive review charter from `.planning/`, user request, and project docs
3. Resolve ladder via `python3 scripts/review-fix-ladder.py --json`
4. Execute sequential rungs with **two-pass gate** per rung:
   - audit+fix subagent → verify-only pass 1 → orchestrator charter grep → verify-only pass 2 → orchestrator charter grep → advance
   - **FORBIDDEN:** parallel rung launches, combined verify passes, advancing on subagent self-reported PASS alone
5. Close out with per-rung verify_1/verify_2 evidence table, charter coverage matrix, and residual risks

### Scenario: General Invocation Asks Scope

**Trigger:** "Run a review fix ladder on this change"

**Workflow:**
1. Orchestrator asks: whole repo, or specific artifact(s)/directory/directories?
2. Do not derive charter or start ladder until user answers
3. If user supplies paths, scope locks to those paths
4. If user confirms whole repo, scope becomes repo-wide with charter non-goals enforced

### Scenario: Repo-Wide Only After Confirmation

**Trigger:** General invocation → user replies "whole repo"

**Workflow:**
1. Charter emphasizes high-signal surfaces first (changed files, planning artifacts, tests)
2. Ladder escalates per host resolver output
3. Smallest safe fixes only; no scope expansion beyond charter non-goals
4. Report coverage matrix mapping charter goals to verification evidence

### Scenario: Two-Pass Gate Enforcement

**Trigger:** Any ladder execution

**Workflow:**
1. One `Task` per turn — never batch audit-fix and verify in one subagent call
2. Verify subagents use `readonly: true` (Cursor) or explicit verify-only directive
3. Orchestrator runs charter verification signals between verify passes
4. Stay on rung until orchestrator confirms two consecutive clean verify passes
5. State machine: `rung_N_audit_fix` → `rung_N_verify_1` → grep → `rung_N_verify_2` → grep → advance

### Scenario: Compliance Gate — Stop on Violation

**Trigger:** Orchestrator about to advance from rung N to rung N+1, or after any verify pass

**Workflow:**
1. Orchestrator self-checks: sequential states, separate verify invocations, orchestrator grep ran, scope held, no parallel rungs
2. If **any** check fails → **STOP immediately** — do not start next rung
3. Report violation, fix process/skill/prompt, re-run failed phase on **same** rung
4. Resume only after compliance gate passes on re-run
5. **No full-ladder obligation** — stop when charter satisfied at current rung or on first compliance failure

### Scenario: Early Stop — Charter Satisfied

**Trigger:** All charter goals met with orchestrator evidence at rung N

**Workflow:**
1. Run compliance gate for rung N
2. Close out with compliance log — do not escalate to rung N+1 unless findings remain
3. Report why stopped: charter satisfied at rung N

### Scenario: Smoke Demonstration (Rung 1 Only)

**Trigger:** Compliance validation or user requests process proof without full ladder

**Workflow:**
1. Lock scope, derive charter, resolve ladder
2. Execute rung 1 only: `audit_fix` → `verify_1` → orchestrator grep → `verify_2` → orchestrator grep
3. Run compliance gate before any rung 2 work
4. **STOP** — report compliance log; do not continue to higher rungs unless user explicitly requests and compliance passes
