# Requirements: Silver Bullet v0.28.0

**Milestone:** v0.28.0 — Complete Forge Port — Silver Bullet + All Dependencies
**Defined:** 2026-04-27
**Core Value:** Forge coding agent users get 100% of Silver Bullet's structured workflow outcomes — same end results as Claude Desktop SB, achieved via skills alone (Forge has no hooks or subagents).

---

## Strategic Approach

Forge has **no hook system**, but **does support custom agents** (per `forgecode.dev/docs/creating-agents/`). Custom agents live in `.forge/agents/` (project) or `~/forge/agents/` (global) as markdown files with YAML frontmatter (`id` required; `description` + `tool_supported: true` enable agent-as-tool invocation). The Forge SKILL.md format is **identical to Claude Code** — skills copy directly with no conversion.

The port therefore has three concrete buckets:

1. **Skills (~108)** — Bulk copy of SB + Superpowers + Anthropic knowledge-work skills. No format conversion needed.
2. **Hooks → Custom Agents (~10)** — SB's 18 hooks fire automatically. In Forge, each blocking hook becomes a **custom agent** (e.g., `forge-pre-commit-audit`) that the main agent invokes as a tool at the right moment, driven by AGENTS.md guidance.
3. **Subagents → Custom Agents (~30)** — SB/GSD's specialized subagents become **Forge custom agents** (e.g., `gsd-roadmapper`, `gsd-planner`) with proper context isolation, tool restrictions, and `tool_supported: true`. Parent skills reference them by id; the main agent invokes them as tools.

The AGENTS.md template (Forge's CLAUDE.md equivalent) is the central enforcement layer — it tells the main agent *when* to invoke each hook-agent and *which* GSD agent to delegate to, replacing the automatic firing of hooks and Task-spawning of subagents in Claude Code.

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

### Phase 66 — Hook → Custom Agent Conversion (~10 agents)

Each hook gate becomes a Forge custom agent in `forge/agents/<id>/AGENT.md` (or single .md file). Agents have `tool_supported: true`, restricted `tools[]`, and a focused system prompt. The main agent invokes them as tools before the gated action.

- [ ] **HOOK-01**: `forge-pre-commit-audit` agent — invoked as tool before any `git commit`; replicates `completion-audit.sh` intermediate-commit logic (verifies `required_planning` skills completed, returns BLOCK/ALLOW)
- [ ] **HOOK-02**: `forge-pre-pr-audit` agent — invoked before `gh pr create` / `gh release create` / `deploy`; replicates `completion-audit.sh` final-delivery logic (verifies full `required_deploy` skill list)
- [ ] **HOOK-03**: `forge-task-complete-check` agent — invoked before declaring "done" / closing a task; replicates `stop-check.sh`
- [ ] **HOOK-04**: `forge-roadmap-freshness` agent — invoked before commit when phase SUMMARY.md is staged; replicates `roadmap-freshness.sh`
- [ ] **HOOK-05**: `forge-spec-floor-check` agent — invoked before any production build; replicates `spec-floor-check.sh` (SPEC.md required)
- [ ] **HOOK-06**: `forge-uat-gate` agent — invoked before PR for UAT-eligible phases; replicates `uat-gate.sh`
- [ ] **HOOK-07**: `forge-pr-traceability` agent — invoked when creating PR; replicates `pr-traceability.sh`
- [ ] **HOOK-08**: `forge-ci-status-check` agent — invoked after push, before next commit; replicates `ci-status-check.sh`
- [ ] **HOOK-09**: `forge-forbidden-skill-check` agent — verifies skill is not deprecated before invocation
- [ ] **HOOK-10**: `forge-session-init` agent — invoked at session start; replicates `session-start` + `session-log-init.sh` + `spec-session-record.sh`

### Phase 67 — Subagent → Custom Agent Conversion (~30 agents)

Each GSD subagent becomes a Forge custom agent in `forge/agents/<id>/AGENT.md` (or single .md file). Frontmatter includes `id`, `title`, `description` (mandatory for tool invocation), `tools[]` (restricted to what the subagent needs), `tool_supported: true`, `model`, `temperature`, `max_tokens`, optional `user_prompt` Handlebars template. Body contains the original subagent prompt.

- [ ] **SUB-01**: GSD planning-stage agents (`gsd-roadmapper`, `gsd-planner`, `gsd-plan-checker`, `gsd-phase-researcher`, `gsd-pattern-mapper`, `gsd-project-researcher`, `gsd-research-synthesizer`) exist as Forge custom agents
- [ ] **SUB-02**: GSD execution-stage agents (`gsd-executor`, `gsd-verifier`, `gsd-integration-checker`, `gsd-nyquist-auditor`) exist as Forge custom agents
- [ ] **SUB-03**: GSD review-stage agents (`gsd-code-reviewer`, `gsd-code-fixer`, `gsd-security-auditor`, `gsd-doc-writer`, `gsd-doc-verifier`) exist as Forge custom agents
- [ ] **SUB-04**: GSD specialized agents (`gsd-debugger`, `gsd-codebase-mapper`, `gsd-intel-updater`, `gsd-pr-creator`, `gsd-session-report-creator`, `gsd-user-profiler`) exist as Forge custom agents
- [ ] **SUB-05**: GSD AI-integration agents (`gsd-eval-auditor`, `gsd-eval-planner`, `gsd-domain-researcher`, `gsd-ai-researcher`, `gsd-framework-selector`) exist as Forge custom agents
- [ ] **SUB-06**: GSD UI agents (`gsd-ui-auditor`, `gsd-ui-checker`, `gsd-ui-researcher`) exist as Forge custom agents
- [ ] **SUB-07**: All parent skills (silver-feature, silver-bugfix, silver-ui, silver-devops, silver-release, silver-spec, gsd-plan-phase, gsd-execute-phase, etc.) updated so `Task(subagent_type="X")` calls become "invoke the `X` agent as a tool" — referencing the Forge custom agent by id

### Phase 68 — Installer + AGENTS.md Glue Layer

- [ ] **INST-01**: `forge-sb-install.sh` rewritten as copy-based installer; copies `forge/skills/` → `~/forge/skills/` (~108 skills) AND `forge/agents/` → `~/forge/agents/` (~40 custom agents = 10 hook + 30 subagent), with project-level `.forge/skills/` and `.forge/agents/` mirrors
- [ ] **INST-02**: Installer fetches Anthropic knowledge-work-plugin skills from GitHub at install time (or vendors a snapshot in `forge/skills/`)
- [ ] **INST-03**: Global `AGENTS.md` template rewritten as Forge-adapted silver-bullet.md — includes workflow routing, mandatory hook-agent invocations at gating moments (before commit, PR, build, task-complete), subagent-as-tool delegation guidance, and enforcement prose
- [ ] **INST-04**: Project `AGENTS.project.template` updated with project-specific skill/agent references and SB workflow conventions
- [ ] **INST-05**: Installer runs cleanly via `bash forge-sb-install.sh` (local) and `curl -sL ... | bash` (remote); installs both skills AND agents
- [ ] **INST-06**: README + docs site documents the Forge installation path with parity matrix (SB hook → Forge agent, SB subagent → Forge agent, SB skill → Forge skill)

### Phase 69 — End-to-End Forge Verification

- [ ] **VERIF-01**: A Forge test app copy is created (cloned from existing SB test app) with `forge-sb-install.sh` applied — AGENTS.md + all ~108 skills + all ~40 custom agents present in correct directories
- [ ] **VERIF-02**: Feature workflow (silver-feature path) runs end-to-end in Forge — discuss, plan, execute, verify, secure, ship — produces same artifacts (CONTEXT.md, RESEARCH.md, PLAN.md, VERIFICATION.md, SECURITY.md, SUMMARY.md) as SB on Claude Desktop
- [ ] **VERIF-03**: Bug fix workflow (silver-bugfix path) runs end-to-end in Forge with same artifacts as SB
- [ ] **VERIF-04**: DevOps workflow (silver-devops path) runs end-to-end in Forge with same artifacts as SB
- [ ] **VERIF-05**: Release workflow (silver-release path) runs end-to-end in Forge with same artifacts as SB
- [ ] **VERIF-06**: Hook-equivalent agents (forge-pre-commit-audit, forge-task-complete-check, forge-roadmap-freshness, etc.) demonstrably block at correct workflow points when conditions fail and allow when conditions pass — same blocking/allow outcomes as SB hooks
- [ ] **VERIF-07**: Subagent-as-tool delegation (gsd-planner, gsd-verifier, etc.) produces equivalent artifact quality and structure to spawned subagents in SB
- [ ] **VERIF-08**: A `forge/PARITY-REPORT.md` documents end-to-end test outcomes, any unavoidable behavioural gaps with mitigations, and confirms feature parity for the 5 production workflow scenarios

## Out of Scope

| Feature | Reason |
|---------|--------|
| Bash hook scripts in `hooks/` directory | Forge has no hook system; replaced by Forge custom agents the main agent invokes as tools |
| Claude Code `Task(subagent_type=…)` syntax | Replaced by Forge custom agents (per `forgecode.dev/docs/creating-agents/`) — same delegation semantics |
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
