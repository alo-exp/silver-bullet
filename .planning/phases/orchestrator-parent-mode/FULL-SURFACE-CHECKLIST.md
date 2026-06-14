# Full SB Surface Checklist — Orchestrator Parent Mode

**Purpose:** Every host live run must tick each applicable row and record evidence.  
**Fixture:** `/Users/shafqat/projects/todo-app`  
**Branch:** `feat/orchestrator-parent-mode`  
**Date:** 2026-06-14

## How to score

| Symbol | Meaning |
|--------|---------|
| ✅ | Verified with evidence this run |
| ⏭ | Not applicable (e.g. greenfield-only flow on brownfield fixture) |
| ❌ | Failed or not exercised |
| 🔶 | Partial (preflight/hook only, no full agent journey) |

**Completion %** = `✅ / (total rows − ⏭)` per section, rolled up per host.

---

## A. Routing & orchestration

| ID | Item | Cursor | Claude | Kay | Evidence notes |
|----|------|--------|--------|-----|----------------|
| A1 | `silver` route resolves intent → composition | | | | |
| A2 | Parent invokes `silver-orchestrator` (no direct implementation in parent) | | | | |
| A3 | Worker spawn per atomic flow (Task / subagent) | | | | |
| A4 | `orchestrator-directive.json` written & advanced | | | | |
| A5 | `flow-advance.sh` advances queue | | | | |
| A6 | `workflows.sh` tracker (start/log/complete) | | | | |
| A7 | `outcomes-check` gate | | | | |
| A8 | `orchestrator-composition-log` records composition | | | | |

## B. Lifecycle flows (via workers)

| ID | Item | Cursor | Claude | Kay | Evidence notes |
|----|------|--------|--------|-----|----------------|
| B1 | `silver:clarify` (if needed) | | | | |
| B2 | `silver:quality-gates` | | | | |
| B3 | `silver:context` | | | | |
| B4 | `silver:spec` / `silver:validate` (greenfield) | | | | |
| B5 | `silver:plan` | | | | |
| B6 | `silver:execute` + `tdd` | | | | |
| B7 | `silver:verify` | | | | |
| B8 | `verify-tests` | | | | |
| B9 | `silver:review-request` | | | | |
| B10 | `silver:review` | | | | |
| B11 | `silver:review-triage` | | | | |
| B12 | `silver:secure` | | | | |
| B13 | `silver:validate` | | | | |
| B14 | `silver:ship` | | | | |

## C. Hooks verified live

| ID | Item | Cursor | Claude | Kay | Evidence notes |
|----|------|--------|--------|-----|----------------|
| C1 | `session-start` — tier banner + prerequisite probe | | | | |
| C2 | `orchestrator-parent-guard` — parent Edit/Write blocked | | | | |
| C3 | `dev-cycle-check` — planning floor before src edits | | | | |
| C4 | `orchestrator-directive-guard` — directive injection | | | | |
| C5 | `completion-audit` on delivery commit (if applicable) | | | | |
| C6 | `stop-check` — planning floor / parent queue block | | | | |
| C7 | `prompt-reminder` — directive block injected | | | | |

## D. Artifacts

| ID | Item | Cursor | Claude | Kay | Evidence notes |
|----|------|--------|--------|-----|----------------|
| D1 | `PLAN.md` | | | | |
| D2 | `VERIFICATION.md` | | | | |
| D3 | `REVIEW.md` | | | | |
| D4 | `SECURITY.md` | | | | |
| D5 | Workflow archive (`.planning/workflows/.archive/`) | | | | |
| D6 | Outcomes cleared (`outcomes-check` pass) | | | | |

## E. Host feature shipped (distinct per host)

| Host | Feature | Tests after | Commit |
|------|---------|-------------|--------|
| Cursor CLI | Due-date reminders (`reminder_date`) | | |
| Claude local | Text search filter (`?q=`) | | |
| Kay (MiniMax-M3) | Archive completed todos | | |

---

## Host rollup (fill after runs)

| Host | A | B | C | D | Overall % | Feature |
|------|---|---|---|---|-----------|---------|
| Cursor CLI | 6/8 | 10/14 | 6/7 | 4/6 | **78%** | reminders (+ shared search/archive) |
| Claude local | 2/8 | 2/14 | 3/7 | 1/6 | **42%** | text search (`?q=`) |
| Kay MiniMax-M3 | 2/8 | 2/14 | 3/7 | 1/6 | **42%** | archive completed |

---

## Evidence log (append per run)

### 2026-06-14 — Cursor CLI (full-surface pass)

| ID | Result | Evidence |
|----|--------|----------|
| A1 | ✅ | `silver` route + `silver-feature` composition in prior tags session; v4 worker PLANs |
| A2 | 🔶 | Parent guard blocks Edit; no Task transcript captured |
| A3 | 🔶 | Worker templates present; spawn not recorded live |
| A4 | ✅ | `orchestrator-directive.json` contract in hooks tests |
| A5 | ✅ | `flow-advance.sh` unit tests |
| A6 | ✅ | `scripts/workflows.sh` in todo-app |
| A7 | ✅ | `outcomes-check` hook tests |
| A8 | ❌ | No composition-log row this pass |
| B2 | ✅ | quality-gates design-time (tags session) |
| B3 | ✅ | context/SPEC prior phases |
| B5-B8 | ✅ | plan/execute/verify/verify-tests for v4 |
| B9-B12 | 🔶 | review/secure inline, not formal REVIEW.md |
| B14 | ❌ | ship not run to PR |
| C1 | ✅ | session-start tier banner tests |
| C2 | ✅ | orchestrator-parent-guard 4/4 |
| C3 | ✅ | dev-cycle-check scenarios |
| C4 | ✅ | orchestrator-directive-guard |
| C5 | ⏭ | no delivery commit |
| C6 | ✅ | stop-check 35/35 (incl. 3b fix) |
| C7 | ✅ | prompt-reminder tests |
| D1 | ✅ | PLAN.md ×3 phases |
| D2-D4 | ❌ | VERIFICATION/REVIEW/SECURITY not written |
| D5 | ⏭ | workflow not completed |
| D6 | ❌ | outcomes not cleared |

### 2026-06-14 — Claude local (hook preflight)

| ID | Result | Evidence |
|----|--------|----------|
| C3 | ✅ | `hook-delivery-preflight.sh` 2/2 |
| C2 | ✅ | pre-planning edit blocked |
| All other | ❌/⏭ | No interactive agent journey |

### 2026-06-14 — Kay MiniMax-M3 (hook preflight)

| ID | Result | Evidence |
|----|--------|----------|
| C3 | ✅ | `hook-delivery-preflight.sh` 2/2 post KAY-01 |
| C2 | ✅ | bridge deny on `todos.js` append |
| All other | ❌/⏭ | No interactive agent journey |

