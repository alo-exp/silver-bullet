# Requirements: Silver Bullet v0.25.0 Issue Capture & Retrospective Scan

**Milestone:** v0.25.0
**Status:** Active
**Last updated:** 2026-04-24

Scope: closed-loop deferred-item capture system — automatic filing to user's PM/issue tracker, knowledge/lessons capture, retrospective session scan, silver-update marketplace migration, and forensics audit.

**Foundation:** FEAT-01 (v0.24.0) already completed — `issue_tracker` field written to `.silver-bullet.json` by `/silver:init`. All new skills route via this field.

**Process constraint:** Right before CI and releasing, execute the 4-stage `docs/internal/pre-release-quality-gate.md`.

---

## v1 Requirements

### Primitive Skills — Issue & Backlog (ADD)

- [ ] **ADD-01**: User can invoke `/silver-add` with a description; the skill classifies the item as **issue** (bug, defect, open question, unfinished work, verification failure) or **backlog** (feature request, tech debt, housekeeping, low-priority, deferred enhancement) based on the description, using a clear classification rubric
- [ ] **ADD-02**: When `issue_tracker = "github"`, silver-add files a GitHub Issue with title, full labeled body, and `filed-by-silver-bullet` label, then adds it to the project board Backlog column via the two-step `gh project item-add` + `gh project item-edit --single-select-option-id` pattern
- [ ] **ADD-03**: When no PM system is configured (`issue_tracker` absent or `"gsd"`), silver-add appends a full industry-standard entry to `docs/issues/ISSUES.md` (for issues) or `docs/issues/BACKLOG.md` (for backlog items) with a sequential `SB-I-N` or `SB-B-N` ID; directory created on first write with `mkdir -p docs/issues/`
- [ ] **ADD-04**: silver-add caches GitHub project board node ID, Status field ID, and Backlog option ID in `.silver-bullet.json` under `_github_project` on first discovery via `gh project list` + `gh project field-list` — no re-discovery on subsequent calls
- [ ] **ADD-05**: silver-add handles GitHub secondary rate limits (retry with exponential backoff), records the filing in the current session's `## Items Filed` section, and always returns the assigned ID (GitHub issue number or local SB-N) after filing

### Primitive Skills — Remove (REM)

- [x] **REM-01**: User can invoke `/silver-remove <id>`; when `issue_tracker = "github"`, closes the GitHub Issue with `"not planned"` reason and `removed-by-silver-bullet` label (GitHub does not support issue deletion via REST/GraphQL API without `delete_repo` scope)
- [x] **REM-02**: When no PM system is configured, silver-remove marks the item as `[REMOVED YYYY-MM-DD]` inline in `docs/issues/ISSUES.md` or `docs/issues/BACKLOG.md` by matching the `SB-I-N` or `SB-B-N` ID

### Primitive Skills — Knowledge & Lessons (MEM)

- [x] **MEM-01**: User can invoke `/silver-rem` with a knowledge insight; the skill appends a formatted entry to `docs/knowledge/YYYY-MM.md` under the appropriate doc-scheme.md category (Architecture Patterns, Known Gotchas, Key Decisions, Recurring Patterns, Open Questions)
- [x] **MEM-02**: User can invoke `/silver-rem` with a lessons-learned insight; the skill appends a formatted entry to `docs/lessons/YYYY-MM.md` under the appropriate doc-scheme.md category tag (`domain:`, `stack:`, `practice:`, `devops:`, `design:`)
- [x] **MEM-03**: silver-rem updates `docs/knowledge/INDEX.md` when a new monthly knowledge file (`YYYY-MM.md`) is first created, and creates the file with the correct monthly header if it does not yet exist

### Auto-Capture Enforcement (CAPT)

- [ ] **CAPT-01**: `silver-bullet.md` §3b and `templates/silver-bullet.md.base` §3b (updated in the same commit, non-negotiable) instruct the coding agent to call `/silver-add` for every deferred, skipped, or identified work item during execution — with an explicit classification rubric distinguishing issue from backlog
- [ ] **CAPT-02**: `silver-feature`, `silver-bugfix`, `silver-ui`, `silver-devops`, and `silver-fast` skill files each contain a per-skill explicit deferred-capture instruction calling `/silver-add` (replacing existing `gsd-add-backlog` calls where present)
- [ ] **CAPT-03**: `silver-bullet.md` §3b and `templates/silver-bullet.md.base` §3b (same commit as CAPT-01) also instruct the coding agent to call `/silver-rem` for every knowledge insight or lesson learned observed during execution
- [ ] **CAPT-04**: `session-log-init.sh` (or equivalent session log template hook) gains an `## Items Filed` section so silver-add and silver-rem calls are recorded per session with item ID and title
- [ ] **CAPT-05**: `silver-release` gains a Step 9b that reads all `## Items Filed` entries from session logs within the milestone window (using milestone start date from `STATE.md` frontmatter) and presents a consolidated post-release summary of all items filed and knowledge/lessons recorded

### Forensics Audit (FORN)

- [ ] **FORN-01**: `silver-forensics` is audited against `gsd-forensics` across all functional dimensions: session classification paths (session-level, task-level, general), evidence-gathering steps (four parallel quick-scan sources), GSD-awareness routing table, root-cause statement format, post-mortem report schema, and security boundary (UNTRUSTED DATA handling)
- [ ] **FORN-02**: Any gaps or divergences found in FORN-01 are fixed in `skills/silver-forensics/SKILL.md` before silver-scan is implemented — the audit report is written to `.planning/` as evidence

### Retrospective Scan (SCAN)

- [ ] **SCAN-01**: silver-scan globs `docs/sessions/*.md` from the project beginning and reads each for deferred-item signals — `## Needs human review`, `## Autonomous decisions`, `<deferred>` XML tags, and keyword grep (`deferred`, `TODO`, `FIXME`, `tech-debt`, `out of scope`, `unfinished`, `skip`, `later`)
- [ ] **SCAN-02**: For each found item, silver-scan cross-references git history (`git log --oneline --grep`), `CHANGELOG.md`, and open GitHub issues to determine whether it was later addressed; items where referenced work is confirmed in history are marked stale and excluded from candidates
- [ ] **SCAN-03**: silver-scan presents unresolved relevant items one at a time with Y/n per item before calling `/silver-add` — no bulk auto-filing; a cap of 20 candidates per run prevents context overload
- [ ] **SCAN-04**: silver-scan also scans session logs for knowledge/lessons insights not yet recorded in `docs/knowledge/` or `docs/lessons/` (matching knowledge/lessons section patterns in session logs), presents candidates with Y/n, and calls `/silver-rem` for approved ones
- [ ] **SCAN-05**: After completing the scan, silver-scan presents a summary: total sessions scanned, items found, items filed (with IDs), knowledge/lessons entries recorded, and items skipped as stale or rejected by user

### Plugin Self-Update (UPD)

- [ ] **UPD-01**: `/silver-update` installs the update strictly via the Claude CLI marketplace method (`silver-bullet@alo-labs`) — no manual git clone; the marketplace install handles proper plugin registration, hooks activation, and registry entry under the correct `silver-bullet@alo-labs` key; version check and changelog display are retained from the current skill before the install step
- [ ] **UPD-02**: After a successful update, `/silver-update` scans `~/.claude/plugins/cache/` and `~/.claude/plugins/installed_plugins.json` for any stale silver-bullet installations from previous versions (including those registered under the legacy `silver-bullet@silver-bullet` key) and removes them, keeping only the newly installed version

---

## Future Requirements

- Review round analytics — track review round counts, common finding patterns (ARVW-10)
- Configurable review depth (quick/standard/deep) per artifact type (ARVW-11)
- Linear/Jira issue tracker support (follow-on to FEAT-01; Phase 1 is GitHub Issues only)
- silver-scan batch size tuning against real session history (scope control values need validation)
- Deduplication threshold for silver-add (collision warning when titles are similar)

---

## Out of Scope

- Replacing GSD's execution engine — GSD owns execution, SB orchestrates
- Webhooks or real-time event streaming from GitHub — pull-based only
- Windows compatibility — Unix-only, no CI coverage
- Jira/Linear/Notion integrations in v0.25.0 — GitHub + local only
- Auto-resolving silver-scan candidates without user approval — human gate is mandatory

---

## Traceability

| REQ-ID | Phase | Status |
|--------|-------|--------|
| ADD-01 | Phase 49 | Pending |
| ADD-02 | Phase 49 | Pending |
| ADD-03 | Phase 49 | Pending |
| ADD-04 | Phase 49 | Pending |
| ADD-05 | Phase 49 | Pending |
| REM-01 | Phase 50 | Pending |
| REM-02 | Phase 50 | Pending |
| MEM-01 | Phase 50 | Pending |
| MEM-02 | Phase 50 | Pending |
| MEM-03 | Phase 50 | Pending |
| CAPT-01 | Phase 51 | Pending |
| CAPT-02 | Phase 51 | Pending |
| CAPT-03 | Phase 51 | Pending |
| CAPT-04 | Phase 51 | Pending |
| CAPT-05 | Phase 51 | Pending |
| FORN-01 | Phase 52 | Pending |
| FORN-02 | Phase 52 | Pending |
| UPD-01 | Phase 53 | Pending |
| UPD-02 | Phase 53 | Pending |
| SCAN-01 | Phase 54 | Pending |
| SCAN-02 | Phase 54 | Pending |
| SCAN-03 | Phase 54 | Pending |
| SCAN-04 | Phase 54 | Pending |
| SCAN-05 | Phase 54 | Pending |
