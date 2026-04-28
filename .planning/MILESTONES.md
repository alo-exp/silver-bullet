# Milestones

## v0.31.0 Forge Port Completion (Shipped: 2026-04-28)

**Type:** Port-completion milestone (5 phases, 7 requirement categories, ~50 file ports + docs).

**Goal:** Close every dependency-port gap identified by the comprehensive Forge port audit (2026-04-28), aligned with `forgecode.dev/docs/` spec.

**Phases shipped:**

- **Phase 81 — SB Templates & Installer Bootstrap (FORGE-TPL-01..08):** ported `templates/*` → `forge/templates/`; installer wires `~/forge/silver-bullet/templates/`.
- **Phase 82 — Forge Commands surface + GSD ports (FORGE-CMD-01..02):** created `forge/commands/`; ported 43 GSD slash commands.
- **Phase 83 — SP/KW commands + missing agents (FORGE-CMD-03..05, FORGE-AGT-01..03):** 3 Superpowers commands, 1 KW PM command, 2 missing GSD subagents (`gsd-doc-classifier`, `gsd-doc-synthesizer`), Superpowers `code-reviewer` agent.
- **Phase 84 — Skill name reconciliation (FORGE-NAM-01):** 8 short→long-form skill renames.
- **Phase 85 — Docs, smoke test, version bump, install verification (FORGE-DOC-01..07):** PARITY docs corrected, smoke test extended (6→8 sections), version v0.30.0→v0.31.0 across 8 files.

**Pre-release quality gate (4 stages):** All passed with 2 consecutive clean rounds each. Post-gate fixes: smoke-test section numbering, secondary `version` field bumps, skill body cross-reference rewrite, 2 additional GSD command ports (`gsd-analyze-dependencies`, `gsd-plan-milestone-gaps`), README Path C Forge install section, site/index.html badge.

**Final inventory:** 107 skills + 47 agents + 49 slash commands + 11 template entries; smoke test 31/31 PASS, 0 failures.

**Audit alignment:** Verified against `forgecode.dev/docs/` (skills, custom agents, slash commands). Forge spec confirmed: skills auto-load by description-context match (no chain-resolve); slash commands are separate primitive at `.forge/commands/<name>.md` invoked with `:`; agents identified by `id` field with `tool_supported: true` for inter-agent calls.

**Release:** https://github.com/alo-exp/silver-bullet/releases/tag/v0.31.0

**Carried forward:** None. Pre-existing shellcheck advisories (SC2294, SC2010) on untouched code paths noted for future cleanup.

---

## v0.30.0 Open-Issue Sweep (Shipped: 2026-04-28)

**Type:** Bug-fix + chore milestone (5 phases, 17 issues from open backlog)

**Goal:** Address every open GitHub issue against `alo-exp/silver-bullet` as of 2026-04-28. Bias toward closure: fix where mechanical, file as planted seed where design is required, document where the underlying limitation is in an upstream runtime.

**Issues in scope:**

- **Phase 76 — Hook bug-fix bundle (shipped):** #85, #86, #87, #88
- **Phase 77 — Release/SDK gating audit:** #48, #50, #71
- **Phase 78 — silver:init UX & boundary verification:** #64, #69, #72
- **Phase 79 — Plant seeds for design-only items:** #67, #68, #75
- **Phase 80 — Documentation sweep:** #59, #70, #73, #74

**Pre-closure:** 6 issues closed as already-implemented in main (#62, #76, #79, #80, #81, #83).

**Artifacts:** `.planning/milestones/v0.30.0-{REQUIREMENTS,ROADMAP}.md`. Composed workflow tracker: `.planning/workflows/20260427T220600Z-02a397-silver-feature.md`.

**Release:** https://github.com/alo-exp/silver-bullet/releases/tag/v0.30.0

**Tests:** 1189 total (140 hook unit + 1049 integration), 0 failed. CI green.

**Pre-release quality gate:** 4 stages passed. SENTINEL deployment recommendation: Deploy freely.

**Carried forward:** issue #90 (LOW — regex-shape validation for `transient_path_ignore_patterns`) → v0.31.0 backlog.

---

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
