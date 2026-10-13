---
spec-version: n/a (no SPEC.md — criteria from REQUIREMENTS.md)
uat-date: 2026-04-24
milestone: v0.25.0
---

# UAT Checklist — v0.25.0 Issue Capture & Retrospective Scan

**Method:** Pre-release quality gate (docs/internal/pre-release-quality-gate.md) — 4 stages, Rounds 8 and 9 both clean. Code inspection verification for all 24 requirements.

## silver-add (Phase 49)

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | `/silver-add` classifies items as issue or backlog; defaults to backlog when ambiguous | PASS | silver-add SKILL.md Step 2 — classification rubric with minimum bar |
| 2 | Files to GitHub Issues+board when `issue_tracker=github`; assigns SB-I-N or SB-B-N ID | PASS | silver-add Steps 4a–4e — gh issue create + gh project item-add + item-edit |
| 3 | Files to `docs/issues/ISSUES.md` or `docs/issues/BACKLOG.md` when no issue tracker configured | PASS | silver-add Step 5 — local path with sequential IDs |
| 4 | `_github_project` cache written atomically to `.silver-bullet.json` on first use | PASS | silver-add Step 4a — jq + tmpfile + mv |
| 5 | Rate-limit resilience: exponential backoff; session log `## Items Filed` written | PASS | silver-add Steps 4e, 6 — retry + session log append |

## silver-remove & silver-rem (Phase 50)

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 6 | `/silver-remove <ID>` closes GitHub issue as "not planned" with label | PASS | silver-remove Steps 3–4 — gh issue close + gh issue edit |
| 7 | `/silver-remove <SB-I-N>` marks entry `[REMOVED YYYY-MM-DD]` in local docs/ | PASS | silver-remove Steps 2–3 — anchored sed + post-sed verification |
| 8 | `/silver-rem` appends to `docs/knowledge/YYYY-MM.md` under correct category | PASS | silver-rem Steps 4–6 — awk ENVIRON heading-aware insert |
| 9 | `/silver-rem` appends to `docs/lessons/YYYY-MM.md` under correct namespace | PASS | silver-rem Steps 4–6 — same pattern for lessons |
| 10 | `docs/knowledge/INDEX.md` updated when new monthly file created | PASS | silver-rem Step 7 — IS_NEW_FILE=true triggers INDEX update |

## Auto-Capture Enforcement (Phase 51)

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 11 | `silver-bullet.md §3b-i` instructs coding agent to call `/silver-add` for deferred items | PASS | silver-bullet.md §3b-i + template parity |
| 12 | All 5 producing skills wired with `Skill(skill="silver-add",...)` | PASS | grep confirms pattern in silver-feature/bugfix/ui/devops/fast |
| 13 | `silver-bullet.md §3b-ii` instructs coding agent to call `/silver-rem` for insights | PASS | silver-bullet.md §3b-ii + template parity |
| 14 | `hooks/session-log-init.sh` adds `## Items Filed` section skeleton | PASS | session-log-init.sh line 225 — Items Filed + idempotency check |
| 15 | `silver-release` Step 9b presents consolidated Items Filed after milestone close | PASS | silver-release SKILL.md Step 9b — awk extractor + prefix-split |

## silver-forensics Audit (Phase 52)

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 16 | Forensics audit report covering all 6 dimensions with 13 gaps identified | PASS | .planning/052-FORENSICS-AUDIT.md — G-01 through G-13 |
| 17 | All 13 gaps fixed; Fix Log appended; 100% functional equivalence confirmed | PASS | commit 0673b3a (fixes) + commit 2754b38 (Fix Log) |

## silver-update Overhaul (Phase 53)

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 18 | `/silver-update` uses `claude mcp install silver-bullet@alo-labs` as sole mechanism | PASS | silver-update SKILL.md Step 5 — git clone path removed |
| 19 | Stale registry entry and cache directory removed atomically post-install | PASS | silver-update SKILL.md Step 6 — jq del + tmpfile+mv + rm -rf guards |

## silver-scan (Phase 54)

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 20 | `/silver-scan` globs `docs/sessions/*.md`; detects structural signals + keyword grep | PASS | silver-scan SKILL.md Steps 2–3 |
| 21 | Stale cross-reference via git log, CHANGELOG, and gh issue list before presenting | PASS | silver-scan SKILL.md Step 4 — three-source cross-reference |
| 22 | Y/n per candidate; 20-candidate cap; no bulk auto-filing | PASS | silver-scan SKILL.md Steps 5–6 — AskUserQuestion + cap |
| 23 | Knowledge/lessons scan (separate pass); Y/n before /silver-rem | PASS | silver-scan SKILL.md Steps 7–8 |
| 24 | Post-scan summary with all 8 counters | PASS | silver-scan SKILL.md Step 9 |

## Summary

| Total | Passed | Failed | Not-Run |
|-------|--------|--------|---------|
| 24 | 24 | 0 | 0 |
