# Project Research Summary

**Project:** Silver Bullet v0.25.0 — Issue Capture & Retrospective Scan
**Domain:** AI orchestrator deferred-item capture, retrospective scanning, issue lifecycle management
**Researched:** 2026-04-24
**Confidence:** HIGH

## Executive Summary

v0.25.0 adds three new skills (silver-add, silver-remove, silver-scan) plus auto-capture enforcement wired into five existing orchestration skills. The core routing primitive already exists: `issue_tracker` in `.silver-bullet.json` gates GitHub vs. local-markdown behavior, and the two-step `gh issue create` + `gh project item-add` + `gh project item-edit` sequence is the correct GitHub Projects V2 approach. The `--project` flag on `gh issue create` is unreliable for org-scoped boards and must not be used. No new tools or runtimes are required — `jq`, `gh`, `git`, and `grep` already exist in the SB environment. Project board IDs for `alo-exp/silver-bullet` are stable and known; cache them in `.silver-bullet.json` under `github_project` on first use to avoid re-querying on every invocation.

The dependency chain is strict: silver-add must be built first because every other deliverable names it or depends on its schema. The silver-forensics audit (verifying functional equivalence between silver-forensics and gsd-forensics) must complete before silver-scan is designed, because silver-scan inherits the session-log evidence model from silver-forensics. Once silver-add is done, Phases 3 (silver-remove), 4 (auto-capture enforcement), and 5 (post-release summary) are independent of each other and can be parallelized.

The two highest risks require design decisions before any instruction text is written. Auto-capture will become a noise engine unless a classification rubric with a minimum signal bar is written as part of the enforcement block — getting this wrong on first use causes users to disable the feature. Silver-scan will surface already-resolved items unless a mandatory three-check resolution gate (git log, open issues, later session logs) and a human-approval gate before filing are built into the skill spec from the start. These are not post-ship refinements; they are prerequisites.

---

## Key Findings

### Stack Additions

No new tools. All four capabilities use the existing `gh`, `git`, `jq`, and `grep` stack.

- **Two-step GitHub board placement** — `gh issue create --json url -q '.url'` captures issue URL, then `gh project item-add` + `gh project item-edit --single-select-option-id <backlog-id>`; the `--project` flag on `gh issue create` is unreliable for org-scoped boards and must not be used
- **silver-remove GitHub path** — attempt `gh issue delete` first; on permission error (no `delete_repo` scope, which most users lack), auto-fall-back to `gh issue close --reason "not planned"`; always print what action was taken
- **Session log scanning** — `docs/sessions/*.md` glob + `grep -iE "(deferred|TODO|FIXME|skipped|pending|follow-up|tech.?debt)"` plus structured section detection; no parser library needed
- **Git commit scan** — `git log --since=<date> --grep="TODO|FIXME|deferred" -i` supplements session log scan with commit-level deferral signals
- **Config routing** — `jq -r '.issue_tracker // "gsd"' .silver-bullet.json` at the start of every silver-add and silver-remove invocation; default is `"gsd"` matching the config template default

**Known project IDs for alo-exp/silver-bullet (cache in `.silver-bullet.json` under `github_project`):**

| Field | Value |
|-------|-------|
| Project number | `4` |
| Project node ID | `PVT_kwDOA5OQY84BU8tb` |
| Status field ID | `PVTSSF_lADOA5OQY84BU8tbzhMcRXE` |
| Backlog option ID | `7e62dc72` |

---

### Feature Table Stakes

**silver-add (must have):**
- Read `issue_tracker` from `.silver-bullet.json` before any filing action; default to `"gsd"` if absent
- Classify item type autonomously (bug / tech-debt / enhancement / open-question / housekeeping) using keyword heuristics; no mandatory user prompt in autonomous/auto-capture mode
- Return a stable ID the calling context can reference (`#123` for GitHub, `LOCAL-NNN` for GSD mode)
- Fuzzy-dedup against open issues before filing; warn on near-match but do not silently block
- Apply `filed-by-silver-bullet` label on every GitHub issue — this label is the mechanism silver-release Step 9b and silver-scan use to query SB-managed items; create idempotently before first issue

**silver-remove (must have):**
- Accept ID, verify item exists and is open, confirm in interactive mode, skip confirm in autonomous
- GitHub path: attempt delete, on permission error fall back to close-with-reason; never silently do something different from what the user requested; always print what action was taken
- Local path: mark row `Status = removed` (not hard-delete) for silver-scan deduplication auditability

**silver-scan (must have):**
- Glob `docs/sessions/*.md` sorted ascending; default to last 10 sessions, not all history; `--since <version>` filter available
- Detect deferred items from structured sections (`## Needs human review`, `## Autonomous decisions`, `## Outcome`) plus free-text keyword grep
- Three-check resolution gate before any candidate is presented: git log keyword search, open-issue match, later session log mention with "fixed/resolved" — any positive check = "likely resolved — skipped"
- Present candidate list for human approval BEFORE calling `silver-add`; silver-scan is reconnaissance, not an autonomous filer
- Write scan report to `docs/silver-forensics/silver-scan-YYYY-MM-DD.md`; cap candidate list at 20 items per run

**Should have (differentiators):**
- Source attribution in issue body (`<!-- filed by silver-add from docs/sessions/YYYY-MM-DD-slug.md -->`)
- Milestone tagging (`--milestone v0.25.0`) on GitHub issues when the milestone exists in GitHub
- `## Items Filed` section in session log template (populated by auto-capture at invocation time, not end-of-session batch)
- Post-release summary in `silver-release` Step 9b: aggregate filed items across milestone sessions, display table after `gsd-complete-milestone` succeeds

**Defer to v2+:**
- `--all-history` silver-scan flag (full-project-history scan; safe only after scope controls validated in production)
- silver-add as a PostToolUse hook (hooks cannot reason about semantic deferral decisions; instruction-level is correct)
- Separate issue vs. backlog classification decision at call time in local mode (all items go to Backlog status; type label carries the classification)

---

### Architecture Decisions

**New files:** `skills/silver-add/SKILL.md`, `skills/silver-remove/SKILL.md`, `skills/silver-scan/SKILL.md`. Local fallback storage (`docs/issues/ISSUES.md`, `docs/issues/BACKLOG.md`) is created on demand by silver-add, not pre-scaffolded by silver-init — mirrors the `docs/silver-forensics/` on-demand pattern.

**Modified files with atomicity constraint:** `silver-bullet.md` and `templates/silver-bullet.md.base` must be updated in the same commit when adding the auto-capture §3b block — this is a §3 NON-NEGOTIABLE requirement. Same constraint applies to `docs/workflows/` and their `templates/workflows/` mirrors.

**Key integration points:**
1. `skills/silver-release/SKILL.md` — additive Step 9b (post-release summary) after Step 9; no existing steps reordered; must be non-blocking if no items were filed
2. `silver-bullet.md §3b` + `templates/silver-bullet.md.base` — auto-capture enforcement block; same-commit atomicity required
3. Five skill files (`silver-feature`, `silver-bugfix`, `silver-ui`, `silver-devops`, `silver-fast`) + two workflow files (`docs/workflows/full-dev-cycle.md`, `docs/workflows/devops-cycle.md`) + their template mirrors — replace `gsd-add-backlog` calls with `silver-add` invocations; embed auto-capture step directly in each file (not only in `silver-bullet.md`)
4. `session-log-init.sh` template — add `## Items Filed` section; each `silver-add` call appends a line here at invocation time
5. `templates/silver-bullet.config.json.default` and `.silver-bullet.json` — add all three new skills to `skills.all_tracked`

**Critical architectural constraints:**
- Auto-capture enforcement must live in each producing skill file — sub-agents and Forge-delegated sessions do not inherit the parent's full `silver-bullet.md` context; instruction in `silver-bullet.md` alone is insufficient
- Local ID namespace (`LOCAL-NNN`) is shared across `ISSUES.md` and `BACKLOG.md`; silver-remove must scan both files to avoid ambiguity on `silver-remove LOCAL-007`
- Rate-limit resilience (2-second sleep between calls, retry on 403/429) must be in silver-add itself, not retrofitted into silver-scan later
- `filed-by-silver-bullet` label is created idempotently by silver-add; silver-release Step 9b and silver-scan deduplication depend on it being present before they run

---

### Critical Pitfalls

1. **Auto-capture becomes a noise engine** — coding agent will over-trigger on every TODO and throwaway comment if no quality bar exists. Prevention: write the classification rubric (minimum bar: distinct user-visible impact OR blocks future work) as part of the enforcement block before adding it to `silver-bullet.md`. Cap at 5 items per session phase; test in isolation on a known-noisy session before wiring into production.

2. **silver-scan false-positives on already-resolved items** — session logs record what was deferred at the time, not what was resolved later. Prevention: mandatory three-check resolution gate (git log, open-issue match, later session log) before presenting any candidate. Human-approval gate before filing is mandatory, not optional.

3. **Auto-capture not honored across all skill contexts** — instruction in `silver-bullet.md` alone is silently absent in `/silver fast`, Forge-delegated, and sub-agent contexts (fewer than 30% of multi-constraint agentic instructions are followed perfectly per AGENTIF benchmark). Prevention: embed the auto-capture step directly in each producing skill file; add soft-warn backstop in `stop-check.sh`.

4. **silver-remove silently closes instead of deleting on GitHub** — `gh issue delete` requires `delete_repo` scope most users lack. Prevention: explicit two-path behavior in skill spec from the start; attempt delete, on permission error auto-fall-back to close-with-label; always print what action was taken.

5. **GitHub secondary rate limit during silver-scan batch filing** — 80 content-creating requests/minute secondary limit; a 20-item scan batch hits it. Prevention: 2-second minimum sleep between `silver-add` calls in batch mode (4 seconds for batches of 10+); local filing-status manifest before batch starts; treat 403/429 as retry signal with backoff up to 3 retries.

---

## Implications for Roadmap

### Phase 1: silver-forensics Audit
**Rationale:** Silver-scan inherits the silver-forensics session-log evidence model. If that model has gaps, silver-scan's design must account for them before implementation. Completing the audit first prevents rework on the most complex deliverable.
**Delivers:** Audit findings document in `.planning/forensics/`; no new skill files.
**Avoids:** Rework on silver-scan if forensics model has undocumented session-log format assumptions.

### Phase 2: silver-add
**Rationale:** Every other deliverable depends on silver-add. Build local fallback path first (no external dependency, testable immediately), then GitHub path. Rate-limit resilience must land in this phase — not retrofitted into silver-scan later.
**Delivers:** `skills/silver-add/SKILL.md`; `github_project` config caching; idempotent `filed-by-silver-bullet` label creation; config template updates.
**Implements:** Two-step GitHub board placement; `LOCAL-NNN` shared-namespace IDs; source attribution in body; rate-limit resilience (2-second sleep, 403/429 retry).
**Avoids:** Pitfall 4 (rate limit) — must be in silver-add itself, not silver-scan.

### Phase 3: silver-remove
**Rationale:** Depends on Phase 2 schema only. Independent of Phases 4 and 5. Can be planned in parallel with Phases 4 and 5 once Phase 2 is committed.
**Delivers:** `skills/silver-remove/SKILL.md`; config updates.
**Implements:** GitHub two-path behavior (delete attempt → close fallback); local `Status = removed` marking.
**Avoids:** Pitfall 2 (silent close vs. delete) — GitHub permission model resolved in skill spec before any instruction text is written.

### Phase 4: Auto-Capture Enforcement
**Rationale:** Must come after Phase 2 (enforcement references `/silver-add` by name). Independent of Phases 3 and 5.
**Delivers:** §3b block in `silver-bullet.md` + atomic mirror in `templates/silver-bullet.md.base`; auto-capture step embedded in each producing skill file; `## Items Filed` section in session log template; workflow files + template mirrors updated in same commit.
**Avoids:** Pitfall 1 (noise engine) — classification rubric is written as part of this phase, not deferred. Pitfall 6 (absent in sub-agent contexts) — enforcement embedded directly in producing skill files.

### Phase 5: Post-Release Summary
**Rationale:** Depends on Phase 2 (silver-add defines data shape and label strategy). Independent of Phases 3, 4, 6.
**Delivers:** Additive Step 9b in `skills/silver-release/SKILL.md`; non-blocking.
**Constraint:** State recording mechanism (how silver-add logs each filing's ID and title) must be decided in Phase 2 because Phase 5 reads it.
**Avoids:** Pitfall 8 (post-release summary breaking stop-hook integrity) — implemented as explicit skill step, not a stop-hook concern.

### Phase 6: silver-scan
**Rationale:** Most complex deliverable. Depends on Phase 1 (forensics audit confirms evidence model), Phase 2 (silver-add must exist), and ideally Phase 4 (auto-capture active for testing). Must be last.
**Delivers:** `skills/silver-scan/SKILL.md`; scan report to `docs/silver-forensics/`; config updates.
**Implements:** Session log glob + keyword grep; structured section detection; three-check resolution gate; human-approval gate before any `silver-add` call; scope controls (default 10 sessions, 20-item cap, `--since` filter); CONTEXT.md `<deferred>` block scan; `docs/tech-debt.md` table scan.
**Avoids:** Pitfall 3 (false-positives on resolved items) and Pitfall 7 (scope creep producing unmanageable output).

### Phase Ordering Rationale

- Phases 1 and 2 are strict sequential prerequisites — no other phase starts until its dependency is committed
- Phases 3, 4, 5 are independent of each other once Phase 2 is committed; all three can be planned as a single parallel middle phase
- Phase 6 is last because it depends on Phases 1, 2, and ideally 4
- Template/live-copy atomicity is a cross-cutting constraint on every commit: `silver-bullet.md` changes must include `templates/silver-bullet.md.base` in the same commit
- The classification rubric (Phase 4) is a prerequisite for the enforcement instruction to be safe to ship — do not add the enforcement block without it

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 6 (silver-scan):** Resolution-check heuristic accuracy — three-check protocol is designed but unvalidated against real SB session history. Sample 3-5 existing session logs before finalizing the skill spec to calibrate false-positive rate.

Phases with standard patterns (skip research-phase):
- **Phase 1:** Direct source inspection of existing skill files is the only input needed.
- **Phase 2:** gh CLI commands verified against installed binary; project board IDs known and stable.
- **Phase 3:** GitHub permission model confirmed from official docs and GitHub Community references.
- **Phase 4:** Atomicity constraint and skill-file instruction placement are established SB patterns.
- **Phase 5:** Additive step in existing skill; implementation pattern mirrors silver-forensics post-mortem.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All gh CLI commands verified against installed binary (gh 2.x, `project` scope confirmed); project board IDs are stable GraphQL node IDs |
| Features | HIGH | Table-stakes behaviors derived from existing SB skill patterns and forensics report findings; external ecosystem comparison is MEDIUM but not decision-critical |
| Architecture | HIGH | All findings from direct source inspection of existing skills, hooks, templates, and config; no inference |
| Pitfalls | HIGH | GitHub API rate limits and permission model from official docs and GitHub Community; enforcement failure modes from AGENTIF benchmark and SB architecture analysis |

**Overall confidence:** HIGH

### Gaps to Address

- **Post-release summary state recording mechanism:** Whether to extend `record-skill.sh`, add `record-filing.sh`, or append to `## Items Filed` in the session log must be decided during Phase 2 — Phase 5 reads this output.
- **Resolution-check heuristic accuracy for silver-scan:** Three-check gate is designed but unvalidated against real SB session history. Sample existing session logs before finalizing the silver-scan spec.
- **Scope controls validation:** Default 10-session cap and 20-item candidate limit must be validated against a mid-size scan during Phase 6 before the skill ships.

---

## Sources

### Primary (HIGH confidence)
- Installed `gh` CLI binary (gh 2.x) — all `gh issue create`, `gh project item-add`, `gh project item-edit` flags verified against `gh help` output on this machine
- GitHub Docs: Rate limits for the REST API — 80 content-creating requests/min, 500/hour secondary limit
- GitHub Community: Issue deletion via REST — REST API does not support deletion; GraphQL `deleteIssue` requires `delete_repo` scope
- SB `skills/silver-forensics/SKILL.md` — session-log evidence model, security boundary pattern, on-demand output directory pattern
- SB `.silver-bullet.json` — `issue_tracker`, `skills.all_tracked`, confirmed field locations
- SB `templates/silver-bullet.config.json.default` — default value for `issue_tracker` (`"gsd"`); skill registration pattern
- SB `silver-bullet.md` §1, §3 — invocation-based enforcement model, NON-NEGOTIABLE atomicity rule for template/live-copy pairs

### Secondary (MEDIUM confidence)
- AGENTIF benchmark (arxiv 2505.16944) — LLMs follow fewer than 30% of multi-constraint agentic instructions; basis for enforcement placement strategy
- A Benchmark for Evaluating Outcome-Driven Constraint Violations (arxiv 2512.20798) — violation rates 11.5-66.7% across 12 LLMs; reinforces instruction-placement decision
- SB `docs/sessions/*.md` (existing session logs) — session log format and structured section names validated by direct inspection

### Tertiary (MEDIUM-LOW confidence)
- External PM tool patterns (Linear, GitHub Projects, Jira) — informed feature table stakes but SB-specific patterns take precedence

---
*Research completed: 2026-04-24*
*Ready for roadmap: yes*
