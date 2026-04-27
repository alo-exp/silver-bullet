# Requirements: Silver Bullet v0.28.0

**Milestone:** v0.28.0 — Complete Forge Port — Silver Bullet + All Dependencies
**Defined:** 2026-04-27
**Core Value:** Forge coding agent users get 100% of Silver Bullet's structured workflow outcomes — same end results as Claude Desktop SB, achieved via skills alone (Forge has no hooks or subagents).

---

## Strategic Approach

The Forge SKILL.md format is **identical to Claude Code** (`name`/`description` frontmatter; auto-applied by Forge AI). Skills can be copied directly with no format conversion. The real porting work is to recreate **two SB systems that don't exist in Forge**:

1. **Hooks → Skills** — SB's 18 hooks enforce workflow gates automatically. In Forge, each blocking hook becomes a skill the main agent invokes at the appropriate moment (driven by AGENTS.md guidance).
2. **Subagents → Skills** — SB/GSD's ~30 specialized subagents run as separate Task processes. In Forge, each becomes a skill containing the subagent's prompt content; the main agent applies it inline.

The AGENTS.md template (Forge's CLAUDE.md equivalent) is the central enforcement layer — it tells the agent *when* to invoke each gate-skill and procedure-skill, replacing the automatic firing that hooks provide in Claude Code.

---

## v1 Requirements

### Phase 65 — Skill Foundation Copy (~108 skills)

- [ ] **COPY-SB-01**: All 61 Silver Bullet skills exist in `forge/skills/<name>/SKILL.md` with original Claude Code SKILL.md format (`name`/`description` frontmatter), replacing the 34 wrong-format files currently there
- [ ] **COPY-SB-02**: Skills with explicit Claude Code-only references (silver-update, silver-init, silver-migrate) have their content adapted for Forge runtime (no `/plugin install`, no Claude Code plugin paths)
- [ ] **COPY-SP-01**: All 14 Superpowers skills exist in `forge/skills/` (brainstorming, dispatching-parallel-agents, executing-plans, finishing-a-development-branch, receiving-code-review, requesting-code-review, subagent-driven-development, systematic-debugging, test-driven-development, using-git-worktrees, using-superpowers, verification-before-completion, writing-plans, writing-skills) — copied from `~/.claude/plugins/cache/superpowers-marketplace/superpowers/<v>/skills/`
- [ ] **COPY-KW-01**: All 10 Anthropic engineering/* skills exist in `forge/skills/` — fetched from `https://github.com/anthropics/knowledge-work-plugins/tree/main/engineering/skills`
- [ ] **COPY-KW-02**: All 7 Anthropic design/* skills exist in `forge/skills/` — fetched from same repo
- [ ] **COPY-KW-03**: All 8 Anthropic product-management/* skills exist in `forge/skills/` — fetched from same repo
- [ ] **COPY-KW-04**: All 8 Anthropic marketing/* skills exist in `forge/skills/` — fetched from same repo
- [ ] **COPY-01**: All 27 missing SB skills (artifact-review-*, devops-*, review-*, silver-add, silver-blast-radius, silver-create-release, silver-fast, silver-forensics, silver-ingest, silver-init, silver-migrate, silver-quality-gates, silver-release, silver-rem, silver-remove, silver-review-stats, silver-scan, silver-spec, silver-update, silver-validate) are present after the bulk copy

### Phase 66 — Hook-to-Skill Conversion (~10 skills)

- [ ] **HOOK-01**: `forge-pre-commit-audit` skill — invoked before any `git commit`; replicates `completion-audit.sh` intermediate-commit logic (verifies `required_planning` skills completed)
- [ ] **HOOK-02**: `forge-pre-pr-audit` skill — invoked before `gh pr create` / `gh release create` / `deploy`; replicates `completion-audit.sh` final-delivery logic (verifies full `required_deploy` skill list)
- [ ] **HOOK-03**: `forge-task-complete-check` skill — invoked before declaring "done" / closing a task; replicates `stop-check.sh` (blocks completion if required skills missing)
- [ ] **HOOK-04**: `forge-roadmap-freshness` skill — invoked before commit with phase SUMMARY.md; replicates `roadmap-freshness.sh` (ROADMAP checkbox must be ticked)
- [ ] **HOOK-05**: `forge-spec-floor-check` skill — invoked before any `npm run build` / production build; replicates `spec-floor-check.sh` (SPEC.md required)
- [ ] **HOOK-06**: `forge-uat-gate` skill — invoked before PR for UAT-eligible phases; replicates `uat-gate.sh`
- [ ] **HOOK-07**: `forge-pr-traceability` skill — invoked when creating PR; replicates `pr-traceability.sh` (PR description must reference REQ-IDs/SPEC.md sections)
- [ ] **HOOK-08**: `forge-ci-status-check` skill — invoked after push, before next commit; replicates `ci-status-check.sh` (CI must be green)
- [ ] **HOOK-09**: `forge-forbidden-skill-check` skill — documented list of deprecated skills; agent must consult before applying any skill
- [ ] **HOOK-10**: `forge-session-init` skill — invoked at session start; replicates `session-start` + `session-log-init.sh` + `spec-session-record.sh` (loads STATE.md, ROADMAP.md, sets up session log)

### Phase 67 — Subagent-to-Skill Conversion (~30 procedure skills)

- [ ] **SUB-01**: GSD planning-stage subagent procedures exist as skills (`gsd-roadmapper-procedure`, `gsd-planner-procedure`, `gsd-plan-checker-procedure`, `gsd-phase-researcher-procedure`, `gsd-pattern-mapper-procedure`, `gsd-project-researcher-procedure`, `gsd-research-synthesizer-procedure`)
- [ ] **SUB-02**: GSD execution-stage subagent procedures exist as skills (`gsd-executor-procedure`, `gsd-verifier-procedure`, `gsd-integration-checker-procedure`, `gsd-nyquist-auditor-procedure`)
- [ ] **SUB-03**: GSD review-stage subagent procedures exist as skills (`gsd-code-reviewer-procedure`, `gsd-code-fixer-procedure`, `gsd-security-auditor-procedure`, `gsd-doc-writer-procedure`, `gsd-doc-verifier-procedure`)
- [ ] **SUB-04**: GSD specialized subagent procedures exist as skills (`gsd-debugger-procedure`, `gsd-codebase-mapper-procedure`, `gsd-intel-updater-procedure`, `gsd-pr-creator-procedure`, `gsd-session-report-creator-procedure`, `gsd-user-profiler-procedure`)
- [ ] **SUB-05**: GSD AI-integration subagent procedures exist as skills (`gsd-eval-auditor-procedure`, `gsd-eval-planner-procedure`, `gsd-domain-researcher-procedure`, `gsd-ai-researcher-procedure`, `gsd-framework-selector-procedure`)
- [ ] **SUB-06**: GSD UI subagent procedures exist as skills (`gsd-ui-auditor-procedure`, `gsd-ui-checker-procedure`, `gsd-ui-researcher-procedure`)
- [ ] **SUB-07**: All parent skills (silver-feature, silver-bugfix, silver-ui, silver-devops, silver-release, silver-spec, etc.) updated so subagent-spawn references become "apply the X-procedure skill" instead of "spawn X agent"

### Phase 68 — Installer + AGENTS.md Glue Layer

- [ ] **INST-01**: `forge-sb-install.sh` rewritten as copy-based installer for all ~148 skills (~108 ported + ~10 hook-equivalents + ~30 subagent-procedures); installs to `~/forge/skills/` (global) and `.forge/skills/` (project)
- [ ] **INST-02**: Installer fetches Anthropic knowledge-work-plugin skills from GitHub at install time (or vendors a snapshot in `forge/skills/`)
- [ ] **INST-03**: Global `AGENTS.md` template rewritten as Forge-adapted silver-bullet.md — includes workflow routing, mandatory pre-commit/pre-PR/task-complete skill invocations (replacing hooks), subagent-procedure invocation guidance (replacing subagents), enforcement prose
- [ ] **INST-04**: Project `AGENTS.project.template` updated with project-specific skill references and SB workflow conventions
- [ ] **INST-05**: Installer runs cleanly via `bash forge-sb-install.sh` (local) and `curl -sL ... | bash` (remote)
- [ ] **INST-06**: README + docs site documents the Forge installation path with parity matrix (SB feature → Forge skill mapping)

### Phase 69 — End-to-End Forge Verification

- [ ] **VERIF-01**: A Forge test app copy is created (cloned from existing SB test app) with `forge-sb-install.sh` applied — AGENTS.md + all ~148 skills present
- [ ] **VERIF-02**: Feature workflow (silver-feature path) runs end-to-end in Forge — discuss, plan, execute, verify, secure, ship — produces same artifacts (CONTEXT.md, RESEARCH.md, PLAN.md, VERIFICATION.md, SECURITY.md, SUMMARY.md) as SB on Claude Desktop
- [ ] **VERIF-03**: Bug fix workflow (silver-bugfix path) runs end-to-end in Forge with same artifacts as SB
- [ ] **VERIF-04**: DevOps workflow (silver-devops path) runs end-to-end in Forge with same artifacts as SB
- [ ] **VERIF-05**: Release workflow (silver-release path) runs end-to-end in Forge with same artifacts as SB
- [ ] **VERIF-06**: Hook-equivalent skills (forge-pre-commit-audit, forge-task-complete-check, forge-roadmap-freshness, etc.) demonstrably fire at correct workflow points and produce same blocking/passing outcomes as SB hooks
- [ ] **VERIF-07**: Subagent-procedure skills (gsd-planner-procedure, gsd-verifier-procedure, etc.) produce equivalent artifact quality to spawned subagents in SB
- [ ] **VERIF-08**: A `forge/PARITY-REPORT.md` documents end-to-end test outcomes, lists any unavoidable behavioural gaps with mitigations, and confirms feature parity for the 5 production workflow scenarios

## Out of Scope

| Feature | Reason |
|---------|--------|
| Bash hook scripts in `hooks/` directory | Forge has no hook system; replaced by skill-based gates with AGENTS.md driving invocation |
| Claude Code subagent spawning (`Task(subagent_type=…)`) | Forge has no subagent system; replaced by inline skill application |
| `/silver:init` Claude Code-specific plugin checks | Replaced by Forge-native install path that manages skills directly |
| Automatic SessionStart hook firing | Replaced by `forge-session-init` skill that AGENTS.md instructs the agent to invoke at session start |
| Forge-specific MCP tooling beyond what SB needs | SB's existing MCP integration is preserved; no Forge-only MCP additions |
| Marketing skills auto-routing in dev workflow | Marketing skills are available but not part of dev workflow paths |
| anthropic-skills:* admin/utility skills (schedule, xlsx, pdf, etc.) | Out of scope — not part of SB's core development workflow |
| Parity for all 11 enforcement layers (only blocking-layer parity) | Informational layers (compliance-status, prompt-reminder) are best-effort in Forge; not blocked on parity |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| COPY-SB-01, COPY-SB-02, COPY-SP-01, COPY-KW-01, COPY-KW-02, COPY-KW-03, COPY-KW-04, COPY-01 | Phase 65 | Pending |
| HOOK-01 through HOOK-10 | Phase 66 | Pending |
| SUB-01 through SUB-07 | Phase 67 | Pending |
| INST-01 through INST-06 | Phase 68 | Pending |
| VERIF-01 through VERIF-08 | Phase 69 | Pending |

**Coverage:** 39 v1 requirements, all mapped to phases.

---
*Requirements defined: 2026-04-27*
*Last updated: 2026-04-27 — restructured after Forge docs research; approach changed from skill-format-conversion to skill-copy + hook/subagent-to-skill conversion*
