# Backlog

Items tracked by Silver Bullet. IDs are sequential (SB-B-N). Do not renumber.

---

### SB-B-1 — docs: reconcile FLOW table skill names with composable contracts

**Type:** chore
**Filed:** 2026-04-25
**Source:** session
**Status:** open

FLOW summary table in silver-bullet.md and silver-bullet.md.base has abbreviated/inconsistent skill names vs composable-flows-contracts.md — e.g. FLOW 3 says "silver:brainstorm, product-brainstorming" but contract specifies "superpowers:brainstorming (Always)"; FLOW 6 missing namespace prefixes (design-system vs design:design-system); FLOW 5 missing skills (engineering:testing-strategy, gsd-analyze-dependencies). Pre-existing documentation drift; not blocking but should be reconciled in a future polish pass.

---

### SB-B-2 — docs: clarify --no-verify policy for GSD parallel worktrees

**Type:** chore
**Filed:** 2026-04-25
**Source:** session
**Status:** open

GSD execute-phase.md and git-integration.md instruct parallel executor agents to use --no-verify on git commits (to avoid pre-commit hook lock contention in parallel worktrees), but Silver Bullet's CLAUDE.md forbids --no-verify unless the user explicitly requests it. The two are not truly contradictory at runtime (GSD parallel executors run in isolated worktrees while Silver Bullet enforces in the main session), but the cross-plugin documentation creates ambiguity. Silver Bullet should explicitly document when --no-verify is permissible under its enforcement model (i.e., only in GSD-managed isolated worktrees during parallel execution, never in main working tree).

---

### SB-B-3 — refactor: split dev-cycle-check.sh to stay under 300 code-line limit

**Type:** refactor
**Filed:** 2026-04-25
**Source:** silver-quality-gates (v0.26.0 release audit)
**Status:** open

`hooks/dev-cycle-check.sh` reached ~312 code lines (hard limit 300 per modularity rules) after v0.26.0 bug fixes (I2 quote-exemption bypass veto). Single responsibility is clear (bash command safety gate) but the file is over the hard limit. Fix: extract validation helper functions into `hooks/lib/dev-cycle-validators.sh` and source it from dev-cycle-check.sh. Requires updating tests to cover the new lib file.

---

### SB-B-4 — feat: implement SDLC coverage expansion roadmap (v0.11–v0.17 milestones)

**Type:** enhancement
**Filed:** 2026-04-25
**Source:** silver-scan (.planning/todos/pending/2026-04-06-sdlc-coverage-expansion.md)
**Status:** open

Silver Bullet v0.10.0 documented a 7-milestone SDLC coverage expansion in docs/SDLC-Coverage-Roadmap.md. The milestones progressively close the gap between invocation-based enforcement (did you run the skill?) and outcome-based enforcement (did it produce the right artifact?). The 7 milestones: v0.11 test-execution gate, v0.12 coverage threshold gate, v0.13 artifact-based validation, v0.14 dependency/SBOM audit gate, v0.15 performance regression gate, v0.16 accessibility audit gate, v0.17 feedback loop from production incidents. None have been implemented.

---

### SB-B-5 — feat: Skill Gap Check / Skill Portals feature

**Type:** enhancement
**Filed:** 2026-04-25
**Source:** silver-scan (docs/TODO.md)
**Status:** open

Feature captured in docs/TODO.md: Skill Gap Check / Skill Portals. Involves detecting when required skills are absent in the installed environment and surfacing installation instructions (skill portals) to bridge the gap. Needs scoping.

---

### SB-B-6 — feat(init): interactive conflict resolution for CLAUDE.md vs silver-bullet.md

**Type:** enhancement
**Filed:** 2026-04-25
**Source:** silver-scan (episodic memory, 2026-04-04)
**Status:** open

When a project already has a CLAUDE.md during /silver:init, the current behavior is a silent override. Users who have customized their CLAUDE.md lose those customizations without warning. /silver:init should detect conflicts, diff the sections, and offer interactive conflict resolution — choosing which sections to keep from the existing CLAUDE.md vs the SB template.

---

### SB-B-7 — feat: systematically eliminate all inappropriate Stop hook false-positives

**Type:** enhancement
**Filed:** 2026-04-25
**Source:** silver-scan (episodic memory, 2026-04-24 user feedback)
**Status:** open

User feedback from 2026-04-24: the Stop hook fires inappropriately in multiple scenarios, blocking Claude without good reason. A broader audit is needed to enumerate remaining false-positive scenarios, reproduce each, and implement targeted fixes. Issue #48 (hooks in Agent SDK context) is a related but distinct tracking item. See also STOP-01 in REQUIREMENTS archive.

---

### SB-B-8 — feat: wire /verification-before-completion into SB hook enforcement

**Type:** enhancement
**Filed:** 2026-04-25
**Source:** silver-scan (episodic memory, 2026-04-08)
**Status:** open

SB should enforce invocation of /verification-before-completion after each task completed by GSD/Superpowers subskills. Currently verification-before-completion is in required_deploy but not enforced at intermediate task boundaries. Needs design and implementation.

---

### SB-B-9 — chore(docs): create GSD compatibility and alternatives comparison doc

**Type:** chore
**Filed:** 2026-04-25
**Source:** silver-scan (episodic memory, 2026-04-04)
**Status:** open

What does Silver Bullet cover as alternatives to GSD-2's Project.md, Decisions.md, Runtime.md, and State.md? No formal comparison document exists. Create a comparison doc (in docs/ or as a help center page) clarifying the boundary, overlap, and integration points between SB and GSD.

---

### SB-B-10 — chore(docs): add SB-only installation path to homepage/onboarding

**Type:** chore
**Filed:** 2026-04-25
**Source:** silver-scan (episodic memory, 2026-04-10)
**Status:** open

The homepage Installation section currently only shows a GSD + Silver Bullet path. Users who want Silver Bullet without GSD are not served. Add a clearly labeled SB-only installation variant showing what works without GSD and what is disabled.

---

### SB-B-11 — feat: PATH 9 layer parallelism in /silver composer (future optimization)

**Type:** enhancement
**Filed:** 2026-04-25
**Source:** silver-scan (.planning/forensics/report-20260416-061401.md Phase 24 context)
**Status:** open

Phase 24 CONTEXT.md (v0.20.0 composable paths) explicitly deferred: "Layer parallelism implementation in PATH 9 (sequential invocation is acceptable — true parallelism is a future optimization)." Design and implement when parallelism tooling is mature.

---
