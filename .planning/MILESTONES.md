# Milestones

## v0.39.3 Zuvo Runtime Parity Enforcement (Shipped: 2026-06-14)

**Type:** Patch release milestone (runtime-enforced AS1/Zuvo parity)

**Goal:** Close the gap between documented structural parity (v0.39.2) and hook-enforced runtime parity for evidence schema, backlog fingerprinting, interface STATE, and install onboarding.

**Status:** complete; release published.

**Completed work:**

- `scripts/lib/evidence_common.py` shared fingerprints
- `scripts/validate-evidence-findings.py` + `hooks/lib/evidence-schema-gate.sh` delivery integration
- `scripts/silver-add.sh` fingerprint, dedup, prioritize CLI
- `scripts/stamp-interface-state.sh` + `silver:init` step 3.2.1
- `scripts/sb-bootstrap.sh` onboarding probe
- Claude agent bundle `silver:*` name rewrite on render

## v0.39.2 AS1 Structural Parity Closure (Shipped: 2026-06-14)

**Type:** Patch release milestone (AS1 parity ledger closure)

**Goal:** Close remaining AS1 structural parity gaps documented in `docs/sb-vs-as1.md` and `GOAL.md`.

**Status:** complete; release published.

**Completed work:**

- Cross-domain evidence schema (`docs/evidence-schema.md`)
- Code-intelligence contract and runtime capability tiers
- External-review policy
- Backlog fingerprinting in `silver:add`
- `scripts/sb-diagnostics.sh` install/runtime diagnostics
- `templates/interface/STATE.md.base` for UI contract continuity
- `run-all-tests.sh` stdin redirect to prevent hook hang

## v0.39.1 Receipt Persistence And Scan Discovery Patch (Shipped: 2026-06-14)

**Type:** Patch release milestone (cross-runtime receipt lookup, scan discovery, issue closure)

**Goal:** Close HANDOFF_v2 `#221` receipt-persistence investigation, ship `ab12e86` scan discovery, and publish `v0.39.1` with issues `#212`–`#221` closed.

**Phases planned:** 055

**Status:** complete; release published at `7365e18`.

**Release:** https://github.com/alo-exp/silver-bullet/releases/tag/v0.39.1

**Completed work:**

- Cross-runtime adapter receipt lookup in `record-skill.sh` / `runtime-paths.sh`.
- `silver:scan` agent-session discovery shipped.
- Kay MiniMax exec fix upstream (`992ac6bbf7` on `alo-labs/kay` `main`).

## v0.37.0 SDLC Interception And Workflow Enforcement (Shipped: 2026-05-19)

**Type:** Orchestration milestone (clarify/front-end enforcement, intent retention, autonomous progress)

**Goal:** Implement the full Silver Bullet vision as a handholding orchestrator and process enforcer that intercepts non-trivial SDLC intent, composes the right workflow, and keeps Claude and Codex aligned under the same flow contract.

**Phases planned:** 100-105

**Target issue clusters:**

- SDLC interception and routing: `ORCH-01`, `ORCH-02`
- Clarify composition stack: `ORCH-03`, `ORCH-04`, `ORCH-05`
- SB-owned milestone bootstrap: `ORCH-06`
- Long-running context and intent retention: `ORCH-08`
- Completion verification and redispatch: `ORCH-09`
- AUI / master loop / autonomous progress: `ORCH-10`, `ORCH-11`, `ORCH-12`

**Status:** complete; release line is live and planning state synchronized.

**Shipped:** all 11 requirements satisfied across 6 phases (100-105).

**Release:** https://github.com/alo-exp/silver-bullet/releases/tag/v0.37.0

**Completed work:**

- `silver:clarify` now acts as the merged PM + Superpowers clarification front-end.
- SB owns the clarification-to-`gsd:new-milestone` handoff.
- The session log now carries a live `Active Intent Ledger`, including backfill for resumed sessions.
- The release-prep path now aligns package/version surfaces, docs, tests, and marketplace metadata with `v0.37.0`.

## v0.35.4 Agents Directory Reorg (Shipped: 2026-05-16)

**Type:** Patch release milestone (agent-bundle layout reorg, compatibility aliases, installer/surface sync, docs/tests refresh).

**Goal:** Reorganize generated agent-specific skill bundles under `agents/<agent-name>/...`, keep `skills/` as the canonical source tree, and make Claude and Codex consume the appropriate runtime bundle without drifting apart.

**Phases planned:** 95-99

**Target issue clusters:**

- Agent bundle generation and naming consistency: `agents/claude`, `agents/codex`, `silver:*` frontmatter normalization
- Codex/Claude installer and package surface wiring: `skills/`, `agents/`, `.generated-skills` compatibility aliases
- Docs/template refresh: bundle layout docs, installer references, runtime notes
- Verification: package sync/install tests, live e2e smoke, release prep for `v0.35.4`

**Status:** complete; bundle renderer, generated agent layouts, installer wiring, docs, tests, and live e2e verification all landed for v0.35.4.

## v0.33.1 Open Issue Burn-down (Planned: 2026-05-13)

**Type:** Patch release milestone (init/runtime fixes, docs semantic audit, hook ergonomics, backlog reconciliation, release prep).

**Goal:** Close the remaining 22 open issues in the Silver Bullet repo by fixing the init/runtime and docs/hook gaps, reconciling already-shipped backlog items, burning down the todo-app clear-completed duplicate cluster, and then shipping `v0.33.1`.

**Phases planned:** 86-92

**Target issue clusters:**

- Runtime-aware bootstrap and brownfield inference: #144, #145, #146, #147, #148, #150
- Docs semantic audit and enforcement ergonomics: #149, #151
- Backlog reconciliation: #98
- Todo-app clear-completed duplicate cluster: #106, #107, #111, #112, #122, #127, #135, #137, #138, #140, #141, #142, #143
- Router/composer contract drift: Phase 92 local architecture alignment, including local backlog item SB-B-1
- Release prep: v0.33.1 versioning, CI, pre-release gate, GitHub Release

**Status:** superseded by v0.35.4; retained as historical context for the older issue burn-down and release prep stream.

## v0.31.1 Docs & State Sync (Shipped: 2026-05-06)

**Type:** Patch release (docs/state refresh, no inventory changes).

**Goal:** Align live docs, planning state, version fields, and parity notes with the `v0.31.1` tag.

**Shipped:** Version fields, README badge/snippet, site badge, config templates, `silver-bullet.md`, `STATE.md`, `PROJECT.md`, `ROADMAP.md`, `REQUIREMENTS.md`, and parity notes updated; inventory unchanged.

**Final inventory:** 107 skills + 47 agents + 49 slash commands + 11 template entries.

**Release:** https://github.com/alo-exp/silver-bullet/releases/tag/v0.31.1

**Carried forward:** None.

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

- Added SessionStart hook to create `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/trivial` — every session starts trivial (skill gate bypassed)
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
