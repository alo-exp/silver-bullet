# Milestones

## v0.25.0 Issue Capture & Retrospective Scan (Shipped: 2026-04-24)

**Type:** Feature milestone (6 phases, 11 plans, 24 requirements)

**Key accomplishments:**

- `/silver-add` skill: classify item as issue/backlog, file to GitHub Issues+project board or local `docs/issues/`, cache board IDs, exponential backoff rate-limit resilience, session log `## Items Filed` recording
- `/silver-remove` skill: close GitHub issue as "not planned" with `removed-by-silver-bullet` label, or inline-mark `[REMOVED YYYY-MM-DD]` in local docs/
- `/silver-rem` skill: classify and append knowledge/lessons insights to monthly `docs/knowledge/YYYY-MM.md` or `docs/lessons/YYYY-MM.md`; `docs/knowledge/INDEX.md` auto-managed on new monthly file creation
- Auto-capture enforcement: `silver-bullet.md §3b-i` and `§3b-ii` mandatory capture instructions; all 5 producing skills wired (`silver-feature`, `silver-bugfix`, `silver-ui`, `silver-devops`, `silver-fast`); session logs gain `## Items Filed` skeleton; `silver-release` Step 9b presents consolidated Items Filed after milestone close
- `silver-forensics` audit: 13 gaps identified and fixed across all 6 functional dimensions; 100% functional equivalence with gsd-forensics confirmed (commit 0673b3a)
- `/silver-update` overhaul: marketplace install via `claude mcp install silver-bullet@alo-labs` replaces git clone; stale legacy `silver-bullet@silver-bullet` registry key and cache directory removed atomically post-install
- `/silver-scan` skill: retrospective session scan — globs `docs/sessions/*.md`, detects deferred items via structural signals + keyword grep, cross-references git log/CHANGELOG/GitHub for stale exclusion, Y/n human gate per item (20-candidate cap), files via `/silver-add` and `/silver-rem`; also scans for unrecorded knowledge/lessons insights

**Release:** https://github.com/alo-exp/silver-bullet/releases/tag/v0.25.0

---

## v0.20.11 Trivial-Session Bypass (Shipped: 2026-04-16)

**Type:** Patch release (2 hook entries, 1 CI fix, version bump)

**Key accomplishments:**

- Added SessionStart hook to create `~/.claude/.silver-bullet/trivial` — every session starts trivial (skill gate bypassed)
- Added PostToolUse Write|Edit|MultiEdit hook to remove trivial file — gate re-arms automatically when files are modified
- Fixed CI `verify-references` step to skip inline shell commands (non-plugin-path commands like mkdir/touch/rm)
- Stop-check and ci-status-check skill gates now only fire in sessions where files were actually changed

**Release:** https://github.com/alo-exp/silver-bullet/releases/tag/v0.20.11

---

## v0.16.0 Advanced Review Intelligence (Shipped: 2026-04-09)

**Phases completed:** 3 phases, 4 plans, 2 tasks

**Key accomplishments:**

- config.json schema:
- One-liner:
- One-liner:
- Cross-artifact reviewer with 3 QC checks detecting unmapped ACs, orphaned requirements, and phantom phase entries — registered in artifact-reviewer framework for auto-dispatch

---
