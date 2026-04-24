# Requirements: Silver Bullet v0.24.0 Stability · Security · Quality

**Milestone:** v0.24.0
**Status:** Active
**Last updated:** 2026-04-24

---

## v1 Requirements

### Session Stability (BUG)

- [ ] **BUG-01**: Fix trivial bypass SessionStart ordering so `~/.claude/.silver-bullet/trivial` survives all hook firings (#42)
- [ ] **BUG-02**: Fix branch file written without trailing newline causing `mainmain` corruption and spurious state wipes (#44)
- [ ] **BUG-03**: Scope `dev-cycle-check.sh` tamper guard to the state file only — not branch or trivial files (#45)
- [ ] **BUG-04**: Fix `completion-audit.sh` pattern matching against full expanded heredoc body, causing false-positive `COMMIT BLOCKED` (#46)
- [ ] **BUG-05**: `stop-check.sh` exits 0 for sessions with no `Write`/`Edit` calls and no `git diff` output — purely administrative sessions bypass enforcement (#41)
- [ ] **BUG-06**: Quality-gates design-time Modularity dimension passes when current milestone plan explicitly addresses the violation (#43)

### Security Hardening (SEC)

- [ ] **SEC-01**: Symlink hardening on all `~/.claude/.silver-bullet/` state-file writes via `sb_safe_write()` helper in `hooks/lib/nofollow-guard.sh` (#25)
- [ ] **SEC-02**: Replace hand-rolled sanitizers in `pr-traceability.sh` and `silver-create-release/SKILL.md` with jq-based JSON/body construction (#26)
- [ ] **SEC-03**: Apply medium/low hardening batch: TOCTOU kill fix, phase-archive slug filter, ReDoS regex, M8 core-rules tamper conflict, plugin cache integrity check, tmpfile trap cleanup (#27)
- [ ] **SEC-04**: `silver-update/SKILL.md` validates `$LATEST` as semver before using it in paths or git refs (#29)

### HOOK-14 Closure (HOOK)

- [ ] **HOOK-01**: Close fail-open edge cases in `stop-check.sh`: rev-list failure, gitignored untracked files, stale upstream ref, local-main fallback, detached HEAD, `--git-dir` guard (#17)
- [ ] **HOOK-02**: Add test coverage gaps in `test-stop-check.sh`: Test 7b (real upstream zero-ahead), setup error swallowing, Tests 1-2-4-5-6 baseline audit, Test 3 decoupling, non-git-dir path (#18)
- [ ] **HOOK-03**: Code polish in `stop-check.sh` HOOK-14 block: variable naming, comment trim, arithmetic comparison, HOOK-NN convention, `--is-inside-work-tree` guard (#19)

### Consistency & Quality (QA)

- [ ] **QA-01**: Narrow `.gitignore` `.claude/` rule to runtime-only subpaths: `.claude/.silver-bullet/`, `.claude/.forge-delegation-active`, `.claude/worktrees/` (#20)
- [ ] **QA-02**: Fix broken upstream skill references: replace `--multi-ai` with `--all`, resolve `/tech-debt`+`/deploy-checklist` plugin dependency, normalize gsd-* invocation syntax (#21)
- [ ] **QA-03**: Eliminate hooks+config duplication: extract config-walk to `hooks/lib/find-config.sh`, apply trivial-bypass consistently across all blocking hooks, generate template from required-skills.sh (#22)
- [ ] **QA-04**: Enforce doc-scheme compliance at finalization in `superpowers:executing-plans` (step 15) and `silver-feature` PATH 13, and add doc-scheme reminder to `superpowers:writing-plans` (#33)
- [ ] **QA-05**: Tighten tamper-detection regex in `dev-cycle-check.sh` to match only leading command tokens — not heredoc bodies or commit message content (#36)
- [ ] **QA-06**: Port doc-scheme compliance gate (Step 13b / PATH 10b) to `silver-devops/SKILL.md` and `silver-bugfix/SKILL.md` where applicable (#39)

### Content Refresh (DOC)

- [ ] **DOC-01**: Refresh all stale public-facing content: site version badge, README compliance-layer count, site meta skill/workflow counts, search index entries, CHANGELOG gap for v0.21–v0.23 releases (#23)

### Feature (FEAT)

- [ ] **FEAT-01**: `/silver:init` prompts for project management system and writes `issue_tracker` field to `.silver-bullet.json`; skills that file backlog items honor this config (#40)

### Merge Open PRs (PR)

- [ ] **PR-01**: Merge PR #37 — forward-port doc-scheme compliance gate to `forge/skills/` variants
- [ ] **PR-02**: Merge PR #38 — add doc-scheme compliance gate to both `silver-ui` variants

---

## Future Requirements

- Review round analytics — track review round counts, common finding patterns (ARVW-10)
- Configurable review depth (quick/standard/deep) per artifact type (ARVW-11)
- Linear/Jira issue tracker support in `/silver:init` (follow-on to FEAT-01, Phase 1 is GitHub Issues only)

---

## Out of Scope

- Replacing GSD's execution engine — GSD owns execution, SB orchestrates
- Windows compatibility (`run-hook.cmd`) — Unix-only, no CI coverage
- Full git history purge for issue #24 — webhook rotated and deleted; accepted residual

---

## Traceability

*(Filled by roadmapper)*

| REQ-ID | Phase | Status |
|--------|-------|--------|
| BUG-01 | — | — |
| BUG-02 | — | — |
| BUG-03 | — | — |
| BUG-04 | — | — |
| BUG-05 | — | — |
| BUG-06 | — | — |
| SEC-01 | — | — |
| SEC-02 | — | — |
| SEC-03 | — | — |
| SEC-04 | — | — |
| HOOK-01 | — | — |
| HOOK-02 | — | — |
| HOOK-03 | — | — |
| QA-01 | — | — |
| QA-02 | — | — |
| QA-03 | — | — |
| QA-04 | — | — |
| QA-05 | — | — |
| QA-06 | — | — |
| DOC-01 | — | — |
| FEAT-01 | — | — |
| PR-01 | — | — |
| PR-02 | — | — |
