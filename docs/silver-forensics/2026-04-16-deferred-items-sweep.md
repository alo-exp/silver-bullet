# Forensics Report — deferred-items-sweep

**Date:** 2026-04-16
**Session log:** docs/sessions/2026-04-05-add-skill-enforcement.md (only log; predates v0.20.0 work)
**Path taken:** general
**Confidence:** high

---

## Symptom

Open-ended sweep to identify all tasks left unfinished, deferred, or ignored since the
last forensics run — including low-priority/minor items from post-step reviews, tech debt
not yet tracked, and any items mentioned as "will do later."

---

## Evidence Gathered

### Session log
Only one session log exists (`2026-04-05-add-skill-enforcement.md`) and predates all
v0.20.0 composable paths work. No session logs for the April 15–16 execution sessions.

The April 2026-04-05 log lists one open question explicitly deferred as tech debt:
> "finalization_skills runtime derivation (resolved — deferred as tech debt)"

### Git history (since v0.20.0 work began)
- Phases 23–29 executed autonomously (no session logs created)
- roadmap-freshness hook added (`06109a1`) — addresses the checkbox drift prevention item
- Code review of roadmap-freshness (`aeda816`) — reviewed and fixed
- test-session-start.sh isolation fix (`ee3901a`) — addressed the loop bug
- silver-forensics routing fix (`2d64003`) — addresses /gsd:silver-forensics bug

### Tech debt register (docs/tech-debt.md — Phase 2 items)
| # | Item | Status |
|---|------|--------|
| 1 | `jq` CI assertions for `required_deploy`/`all_tracked` correctness | **Still open** — no CI step exists |
| 2 | `diff` CI step for `docs/workflows/` vs `templates/workflows/` parity | **Still open** — CI has placeholder checks but no parity diff |
| 3 | `tests/hooks/test-dev-cycle-check.sh` | **Done** — file exists |
| 4 | Derive `finalization_skills` from `.silver-bullet.json` at runtime | **Still open** — still hardcoded at line 371 of `hooks/dev-cycle-check.sh` |

### Pre-existing test failure
- `test-timeout-check.sh` T2-1 "expected 'Check-in', got: " — **pre-existing**, not a regression from recent work. Root cause not yet investigated.

### Missing artifacts
- `docs/KNOWLEDGE.md` — missing (referenced in session log as created, but file does not exist; possibly at a different path)
- `docs/LESSONS.md` — missing; no equivalent found anywhere in the project
- `.planning/KNOWLEDGE.md` — missing

### Planning artifacts
- Phase 25 CONTEXT.md `<deferred>` section explicitly says "None — discussion stayed within phase scope"
- No deferred items found in phases 23, 24, 26, 27, 28, 29 CONTEXT or SUMMARY files

### Items from review passes (bypassed because verdict was 'Approve')
- `aeda816` code review of roadmap-freshness hook surfaced 3 items: (1) no test for missing ROADMAP.md path; (2) regex convention drift silent pass; (3) PostToolUse annotation. The commit message says "address code review findings" but the engineering:tech-debt skill re-record pass listed items (1) and (2) as still open tech debt at session end. Item (3) was resolved in `aeda816`.

### Sentinel/timeout flags
- No sentinel file present
- No timeout flags detected

---

## Root Cause

No single failure — this is a sweep revealing 6 open items across tech debt, missing artifacts, and a pre-existing test failure that were not tracked in any backlog.

ROOT CAUSE: Systematic absence of post-work capture — deferred items were noted in session logs and tech-debt register entries but never added to the GSD backlog for scheduling — general path — confidence: high

---

## Contributing Factors

- No mechanism exists to add deferred items to the GSD backlog during or after execution
- Tech debt register (docs/tech-debt.md) exists but is disconnected from the GSD planning system (ROADMAP.md backlog section)
- Session logs capture "Needs human review" but not "Needs scheduling"
- The stop-check hook enforces skill invocations but not deferred-item capture
- Review verdicts of "Approve" with minor/suggestion items cause those items to be silently dropped

---

## Open Items Identified

| # | Item | Source | Relevance |
|---|------|--------|-----------|
| 1 | `jq` CI assertions for `required_deploy`/`all_tracked` | docs/tech-debt.md Phase 2 | Still relevant — silent drift risk |
| 2 | `diff` CI step for docs/workflows/ vs templates/workflows/ parity | docs/tech-debt.md Phase 2 | Still relevant — template drift has caused bugs |
| 3 | Derive `finalization_skills` from `.silver-bullet.json` at runtime | docs/tech-debt.md Phase 2 | Still relevant — hardcoded at hook line 371 |
| 4 | Investigate and fix T2-1 test failure in test-timeout-check.sh | pre-existing test | Still relevant — 1 test failing in suite |
| 5 | `docs/KNOWLEDGE.md` and `docs/LESSONS.md` missing | session log ref + item 9 | Still relevant — knowledge capture not working |
| 6 | No test for roadmap-freshness hook: missing ROADMAP.md path (review finding #1) | code review of aeda816 | Still relevant — edge case untested |
| 7 | Regex convention drift in roadmap-freshness.sh causes silent pass (review finding #2) | code review of aeda816 | Still relevant — false passes possible |

---

## Recommended Next Steps

- [ ] Add items 1–7 to GSD backlog (ROADMAP.md ## Backlog section)
- [ ] Add a post-work deferred-item capture step to SB composable flows
- [ ] Add a during-work mechanism to capture deferred items to backlog
- [ ] Enforce that review low-priority/minor items are backlogged even when verdict is Approve

## Prevention

Add explicit deferred-item capture as a mandatory step in every SB composable flow's
supervision loop, so items never fall through the gap between "noted" and "scheduled."
