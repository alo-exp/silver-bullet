# Roadmap: Silver Bullet v0.9.0 -- GSD-Mainstay Retrofitting

## Overview

Transform Silver Bullet from an enforcement layer on top of GSD into a complete orchestration layer that owns the user experience. Workflow files become comprehensive guides covering 100% of the GSD process with user-facing explanations. silver-bullet.md gains GSD process knowledge so Claude can guide users without reading GSD docs. Forensics evolves to be GSD-aware. Templates and documentation reflect the new approach throughout.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Workflow File Rewrites** - Rewrite both workflow files as comprehensive orchestration guides covering all 20 guided GSD commands with error recovery, utility guidance, and dev-to-DevOps transition logic
- [x] **Phase 2: silver-bullet.md Overhaul** - Add GSD process knowledge, hand-holding instructions, and utility command awareness to silver-bullet.md while preserving all enforcement rules
- [x] **Phase 3: Skill Evolution** - Evolve SB forensics to route GSD-workflow issues to /gsd:forensics while retaining session-level capabilities; verify zero redundancy across all SB skills
- [x] **Phase 4: Template Parity & Hook Verification** - Sync templates with updated workflow files and silver-bullet.md; verify all enforcement hooks fire correctly with restructured files
- [x] **Phase 5: Documentation & Public-Facing** - Update README and site pages to reflect the new orchestration-first approach
- [x] **Phase 6: Implement Enforcement Techniques** - Add 4 missing enforcement mechanisms and create comprehensive enforcement reference
- [x] **Phase 7: Close All Enforcement Audit Gaps** - Close all 16 actionable enforcement gaps from adversarial audit
- [x] **Phase 8: Comprehensive SB Enforcement Test Harness** - Automated integration test suite for multi-hook enforcement scenarios
- [x] **Phase 9: Silver Bullet Core Improvements** - silver:init initializes all dependencies, GSD state delegation, guided UX, lettered options
- [x] **Phase 10: SB Orchestration Skill Files** - Create 7 named orchestration skills: silver-feature/bugfix/ui/devops/research/release/fast
- [x] **Phase 11: Website Content Refresh** - v0.13.0 site update
- [ ] **Phase 12: Spec Foundation** - Canonical SPEC.md format, AI-guided elicitation skill, and spec floor enforcement — the linchpin that unblocks all downstream spec capabilities
- [ ] **Phase 13: Ingestion & Multi-Repo** - External artifact ingestion via MCP connectors (JIRA, Figma, Google Docs) and cross-repo spec referencing with version pinning
- [ ] **Phase 14: Validation, Traceability & UAT Gate** - Pre-build validation gate, PR-to-spec traceability automation, and UAT as a formal pipeline gate

## Phase Details

### Phase 1: Workflow File Rewrites
**Goal**: Users are guided through the entire SDLC by workflow files that explain every GSD step, handle errors, suggest utilities, integrate non-GSD skills, and manage dev-to-DevOps transitions
**Depends on**: Nothing (first phase)
**Requirements**: ORCH-01, ORCH-02, ORCH-03, ORCH-04, ORCH-05, ORCH-06, TRANS-01, TRANS-02, TRANS-03
**Success Criteria** (what must be TRUE):
  1. User reading full-dev-cycle.md understands what each GSD step does, what to expect during execution, and what to do if it fails -- without consulting any GSD documentation
  2. User reading devops-cycle.md gets the same comprehensive treatment for infrastructure workflows
  3. All 20 guided GSD commands appear at their appropriate workflow points with context; utility commands (/gsd:debug, /gsd:quick, /gsd:resume-work, etc.) appear with "when to use" guidance
  4. After completing a release step, the workflow detects infrastructure needs and offers to switch between dev and DevOps cycles while preserving all planning artifacts
  5. Non-GSD skills (design-system, ux-copy, accessibility-review, etc.) are triggered at specific workflow points with clear conditions
**Plans**: TBD

Plans:
- [x] 01-01: Rewrite full-dev-cycle.md as orchestration guide (commit 8a58d33)
- [x] 01-02: Rewrite devops-cycle.md as orchestration guide (commit ada025a)

### Phase 2: silver-bullet.md Overhaul
**Goal**: Claude has internalized GSD process knowledge within silver-bullet.md so it can guide users through workflow transitions, suggest appropriate utility commands, and explain what is happening -- all without reading GSD plugin files
**Depends on**: Phase 1
**Requirements**: INST-01, INST-02, INST-03, INST-04
**Success Criteria** (what must be TRUE):
  1. Claude can explain what any GSD workflow step does and why it matters, using only silver-bullet.md as reference (no dependency on GSD's own docs at runtime)
  2. At each workflow transition (e.g., DISCUSS to PLAN, EXECUTE to VERIFY), Claude proactively tells the user what just completed, what comes next, and what to watch for
  3. Claude suggests utility commands based on context -- /gsd:debug when execution fails, /gsd:quick for trivial changes, /gsd:resume-work after session breaks
  4. All existing enforcement rules (sections 0 through 9) remain intact and functional in the restructured file
**Plans**: 1 plan

Plans:
- [x] 02-01-PLAN.md -- GSD process knowledge, hand-holding, utility awareness, workflow transitions (commit e6bc842)

### Phase 3: Skill Evolution
**Goal**: SB forensics becomes GSD-aware, routing workflow-level issues to GSD while retaining its unique session-level capabilities, with zero skill redundancy across the entire SB plugin
**Depends on**: Phase 2
**Requirements**: DEDUP-01, DEDUP-02, DEDUP-03
**Success Criteria** (what must be TRUE):
  1. When a user reports a workflow-level issue (plan drift, execution anomaly, stuck loop), SB forensics routes to /gsd:forensics with appropriate context
  2. SB forensics still handles session-level issues (timeout, stall, SB enforcement failures) that GSD forensics does not cover
  3. An audit of all SB skills confirms zero reimplementation of any GSD capability -- each SB skill either complements or orchestrates, never duplicates
**Plans**: TBD

Plans:
- [x] 03-01: SB forensics GSD-awareness routing, zero-dedup audit (commit 206ef79)

### Phase 4: Template Parity & Hook Verification
**Goal**: All templates are synchronized with the rewritten source files, and every enforcement hook fires correctly with the restructured workflow files
**Depends on**: Phase 3
**Requirements**: TMPL-01, TMPL-02, TMPL-03, DOC-03
**Success Criteria** (what must be TRUE):
  1. docs/workflows/full-dev-cycle.md and templates/workflows/full-dev-cycle.md are byte-identical (verified by diff)
  2. docs/workflows/devops-cycle.md and templates/workflows/devops-cycle.md are byte-identical (verified by diff)
  3. silver-bullet.md structure matches templates/silver-bullet.md.base with only placeholder substitutions differing
  4. All 7 enforcement hooks fire correctly when tested against the restructured workflow files -- no hook fails due to changed section headers or reorganized content
**Plans**: TBD

Plans:
- [x] 04-01: Template parity (byte-identical diffs pass), hooks verified via Phase 8 harness

### Phase 5: Documentation & Public-Facing
**Goal**: README and site pages communicate the new orchestration-first approach so users understand SB guides them through GSD without needing any GSD knowledge
**Depends on**: Phase 4
**Requirements**: DOC-01, DOC-02
**Success Criteria** (what must be TRUE):
  1. A new user reading README.md understands that Silver Bullet provides complete SDLC guidance through GSD orchestration -- they do not need to learn GSD separately
  2. Site pages (index.html, help pages, search.js) reflect the updated workflow descriptions and orchestration terminology
**Plans**: TBD
**UI hint**: yes

Plans:
- [x] 05-01: README updated for orchestration-first approach (commit 7832f05)

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Workflow File Rewrites | 2/2 | ✓ Complete | 2026-04-05 |
| 2. silver-bullet.md Overhaul | 1/1 | ✓ Complete | 2026-04-05 |
| 3. Skill Evolution | 1/1 | ✓ Complete | 2026-04-05 |
| 4. Template Parity & Hook Verification | 1/1 | ✓ Complete | 2026-04-05 |
| 5. Documentation & Public-Facing | 1/1 | ✓ Complete | 2026-04-05 |
| 6. Enforcement Techniques | 2/2 | ✓ Complete | 2026-04-05 |
| 7. Close Enforcement Audit Gaps | 4/4 | ✓ Complete | 2026-04-05 |
| 8. Enforcement Test Harness | 2/2 | ✓ Complete | 2026-04-08 |
| 9. Silver Bullet Core Improvements | 2/2 | ✓ Complete | 2026-04-08 |
| 10. SB Orchestration Skill Files | 7/7 | ✓ Complete | 2026-04-08 |
| 11. Website Content Refresh | 1/1 | ✓ Complete | 2026-04-09 |
| 12. Spec Foundation | 0/3 | Planning complete | - |
| 13. Ingestion & Multi-Repo | 0/? | Not started | - |
| 14. Validation, Traceability & UAT Gate | 0/? | Not started | - |

### Phase 6: Implement Enforcement Techniques from AI-Native SDLC Playbook

**Goal:** Add the 4 missing enforcement mechanisms identified in the gap analysis (Stop hook, UserPromptSubmit hook, compactPrompt override, hook self-protection) and create a comprehensive reference document for all enforcement mechanisms in Silver Bullet
**Requirements**: ENF-01, ENF-02, ENF-03, ENF-04, ENF-05, ENF-06
**Depends on:** Phase 5
**Plans:** 2 plans

Plans:
- [x] 06-01-PLAN.md -- Create Stop hook, UserPromptSubmit hook, register in hooks.json, add compactPrompt to config template
- [x] 06-02-PLAN.md -- Extend dev-cycle-check.sh hook self-protection, add tests for new hooks, create enforcement techniques reference doc

### Phase 7: Close All Enforcement Audit Gaps

**Goal:** Close all 16 actionable enforcement gaps (F-01, F-03 through F-20 excluding F-02/F-10/F-12/F-14) from the adversarial audit. Convert bypass paths to hard or soft enforcement with tests for all new hook scripts.
**Requirements**: ENF-F01, ENF-F03, ENF-F04, ENF-F05, ENF-F06, ENF-F07, ENF-F08, ENF-F09, ENF-F11, ENF-F13, ENF-F15, ENF-F16, ENF-F17, ENF-F18, ENF-F19, ENF-F20, ENF-TESTS
**Depends on:** Phase 6
**Plans:** 4 plans

Plans:
- [x] 07-01-PLAN.md -- New forbidden-skill-check.sh hook, SubagentStop registration, stop-check.sh quality-gate-stage check, completion-audit.sh gh pr merge, ci-status-check.sh extended patterns
- [x] 07-02-PLAN.md -- dev-cycle-check.sh hardening: plugin cache Bash check, scripting language bypass, branch mismatch warning, generalized tamper regex, destructive command warning
- [x] 07-03-PLAN.md -- Stage falsification prevention, stage-after-workflow ordering, compliance-status.sh mtime cache, session-log-init.sh mode fix, src_pattern update
- [x] 07-04-PLAN.md -- Review loop proxy enforcement (F-01), test suites for all new enforcement code

### Phase 8: Comprehensive SB enforcement test harness

**Goal:** Automated integration test suite that validates multi-hook enforcement scenarios (planning gates, workflow completion, skill tracking, session management) replacing manual e2e-smoke-test enforcement checks with deterministic JSON-pipe tests
**Requirements**: ENF-HARNESS-01, ENF-HARNESS-02, ENF-HARNESS-03, ENF-HARNESS-04, ENF-HARNESS-05, ENF-HARNESS-06, ENF-HARNESS-07, ENF-HARNESS-08, ENF-HARNESS-10
**Depends on:** Phase 7
**Plans:** 1/2 plans executed

Plans:
- [x] 08-01-PLAN.md -- Integration test helpers, planning gate scenarios, workflow completion scenarios
- [x] 08-02-PLAN.md -- Skill tracking scenarios, session scenarios, unified test runner, smoke test doc update

### Phase 9: Silver Bullet core improvements: init with GSD+Superpowers, GSD state delegation, guided UX, lettered option bullets

**Goal:** silver:init initializes and updates all dependencies (SB, GSD, Superpowers), SB derives position from GSD STATE.md, users get rich progress narration at every step, and all option prompts use lettered A/B/C format
**Requirements**: REQ-1, REQ-2, REQ-3, REQ-4
**Depends on:** Phase 8
**Plans:** 2/2 plans complete

Plans:
- [x] 09-01-PLAN.md — Version freshness check in silver:init + lettered options across all SB skills
- [x] 09-02-PLAN.md — GSD state delegation, progress banners, autonomous commentary, lettered options in silver-bullet.md

### Phase 10: Create 7 named SB orchestration skill files: silver-feature, silver-bugfix, silver-ui, silver-devops, silver-research, silver-release, and silver-fast

**Goal:** [To be planned]
**Requirements**: TBD
**Depends on:** Phase 9
**Plans:** 7/7 plans complete

Plans:
- [x] TBD (run /gsd-plan-phase 10 to break down) (completed 2026-04-08)

### Phase 11: Silver Bullet website content refresh — v0.13.0 site update

**Goal:** [To be planned]
**Requirements**: TBD
**Depends on:** Phase 10
**Plans:** 0 plans

Plans:
- [ ] TBD (run /gsd-plan-phase 11 to break down)

### Phase 12: Spec Foundation

**Goal:** Users can create, elicit, and store standardized specs — SB produces canonical SPEC.md and DESIGN.md artifacts, guides PM/BA through Socratic elicitation, and hard-blocks any implementation attempt that lacks a minimum viable spec
**Depends on:** Phase 11
**Requirements**: SPEC-01, SPEC-02, SPEC-03, SPEC-04, SPEC-05, ELIC-01, ELIC-02, ELIC-03, ELIC-04, ELIC-05, ELIC-06, FLOR-01, FLOR-02, FLOR-03
**Success Criteria** (what must be TRUE):
  1. User runs `silver-spec` and SB guides them through Socratic dialogue — asking about user stories, edge cases, UX flows, and data model implications — producing a completed SPEC.md and REQUIREMENTS.md without the user ever filling a template manually
  2. User can provide a Google Doc, PPT, or Figma URL during elicitation and SB incorporates its content into the evolving spec without restarting the session
  3. Every unresolvable gap during elicitation produces a visible `[ASSUMPTION: ...]` block in SPEC.md — the block count reflects spec maturity, not optional decoration
  4. Running `gsd-plan-phase` without a `.planning/SPEC.md` that contains Overview and Acceptance Criteria sections results in a hard block with a clear error message; running `gsd-fast` without a 3-field minimal spec produces a warning but does not block
  5. SPEC.md and DESIGN.md are generated from templates in `templates/specs/` — a new spec is never created from scratch
**Plans**: 3 plans

Plans:
- [ ] 12-01-PLAN.md -- Spec templates + spec-floor-check.sh hook
- [ ] 12-02-PLAN.md -- silver-spec SKILL.md (Socratic elicitation)
- [ ] 12-03-PLAN.md -- Router wiring + hooks.json registration + silver-bullet.md docs

### Phase 13: Ingestion & Multi-Repo

**Goal:** Users can feed external artifacts (JIRA tickets, Figma designs, Google Docs) directly into SB to produce a draft spec, and satellite repos can reference and pin to the main repo's spec as a read-only source of truth
**Depends on:** Phase 12
**Requirements**: INGT-01, INGT-02, INGT-03, INGT-04, INGT-05, INGT-06, INGT-07, REPO-01, REPO-02, REPO-03, REPO-04
**Success Criteria** (what must be TRUE):
  1. User runs `silver-ingest <jira-ticket-id>` and SB pulls ticket summary, description, acceptance criteria, and resolves linked Google Drive and Figma URLs — producing a draft SPEC.md and DESIGN.md without manual copy-paste
  2. Every ingestion run produces an `INGESTION_MANIFEST.md` that lists each artifact with status (succeeded / failed / missing) — no silent partial failures; failed artifacts appear as `[ARTIFACT MISSING: reason]` blocks in SPEC.md
  3. If a connector fails mid-ingestion, re-running `silver-ingest` resumes from the last successful artifact in the manifest rather than starting over
  4. User runs `silver-ingest --source-url <repo-url>` in a mobile repo and SB fetches the main repo's SPEC.md, caches it as `.planning/SPEC.main.md` (read-only), and displays the pinned spec-version
  5. When a mobile repo SB session starts and the pinned spec-version does not match the main repo's current version, the session is blocked with a diff of what changed before the user can proceed
**Plans**: TBD

### Phase 14: Validation, Traceability & UAT Gate

**Goal:** Every implementation session is anchored to a verified spec — pre-build validation surfaces gaps before a line of code is written, PRs are machine-linked to the spec that drove them, and milestone completion is blocked until UAT is formally signed off
**Depends on:** Phase 13
**Requirements**: VALD-01, VALD-02, VALD-03, VALD-04, VALD-05, TRAC-01, TRAC-02, TRAC-03, TRAC-04, UATG-01, UATG-02, UATG-03, UATG-04
**Success Criteria** (what must be TRUE):
  1. Running `silver-validate` before implementation produces machine-readable findings with severity (BLOCK / WARN / INFO) — BLOCK findings prevent `gsd-plan-phase` from proceeding; WARN findings appear in PR descriptions as deferred items
  2. All `[ASSUMPTION: ...]` blocks from SPEC.md are re-surfaced at implementation start so the developer cannot proceed without consciously acknowledging them
  3. After `gsd-ship`, the PR description contains auto-generated spec reference, requirement IDs covered, and a link to SPEC.md — with no developer annotation required
  4. SPEC.md's Implementations section is updated post-merge with the PR URL and commit range — the spec remains the living record of what was built against it
  5. Running `gsd-complete-milestone` when UAT has not been run, or when any UAT criterion is marked FAIL, results in a hard block — the UAT artifact (UAT.md) committed to `.planning/` with pass/fail per criterion is the only way to unblock
**Plans**: TBD
