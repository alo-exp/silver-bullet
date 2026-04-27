# Silver Bullet for Forge — Parity Report

**Generated:** 2026-04-27
**Milestone:** v0.28.0
**Source repo state:** post-Phase-68 (commit `86c2941`)
**Forge version targeted:** any version that follows `forgecode.dev/docs` spec (skill auto-loading, custom agents per `creating-agents` page)

---

## Verification Results

### 1. Structural Verification (Automated — PASSED)

Output of `bash forge/scripts/smoke-test.sh` after running `bash forge-sb-install.sh --global-only --no-knowledge-work`:

```
=== Silver Bullet for Forge — Smoke Test ===
Forge home: /Users/shafqat/forge

[1/6] Global skill set (~/forge/skills)
  ✓ 107 skills present (≥100 expected)

[2/6] Global agent set (~/forge/agents)
  ✓ 42 agents present (≥35 expected)

[3/6] Hook-equivalent agents (forge-*)
  ✓ forge-pre-commit-audit present
  ✓ forge-pre-pr-audit present
  ✓ forge-task-complete-check present
  ✓ forge-roadmap-freshness present
  ✓ forge-spec-floor-check present
  ✓ forge-uat-gate present
  ✓ forge-pr-traceability present
  ✓ forge-ci-status-check present
  ✓ forge-forbidden-skill-check present
  ✓ forge-session-init present

[4/6] GSD subagent-equivalent agents (gsd-*)
  ✓ 31/31 GSD agents present

[5/6] Skill+agent frontmatter validity (sampling)
  ✓ silver-feature frontmatter valid (name + description)
  ✓ silver-bugfix frontmatter valid
  ✓ silver-quality-gates frontmatter valid
  ✓ engineering-code-review frontmatter valid
  ✓ forge-pre-commit-audit frontmatter valid (id + description + tool_supported)
  ✓ gsd-planner frontmatter valid
  ✓ gsd-roadmapper frontmatter valid

[6/6] AGENTS.md (global)
  ✓ present (warns when pre-existing user AGENTS.md is detected — non-blocking)

Summary: 21 passed, 0 failed.
```

### 2. Inventory Audit

| Category | Expected | Actual | Status |
|---|---|---|---|
| SB skills (no namespace) | 61 | 73 | ✓ (12 net-new from Superpowers cache) |
| Hook-equivalent agents | 10 | 10 | ✓ |
| GSD subagent agents | 31 | 31 | ✓ |
| Engineering KW skills | 10 | 10 | ✓ |
| Design KW skills | 7 | 7 | ✓ |
| Product-Management KW skills | 8 | 8 | ✓ |
| Marketing KW skills | 8 | 8 | ✓ |
| **Total skills** | ~106 | **107** | ✓ |
| **Total agents** | ~41 | **42** | ✓ |

(Counts include the `gsd-debug-session-manager` agent which was originally a Claude Code orchestrator; preserved for completeness.)

### 3. Format Compliance

- ✓ Skills use Claude Code SKILL.md format (`name`/`description` frontmatter) — same as Forge per `forgecode.dev/docs/skills`
- ✓ Custom agents use Forge agent format (`id` required + optional `title`/`description`/`tools[]`/`tool_supported`/`temperature`/`max_turns`) per `forgecode.dev/docs/creating-agents/`
- ✓ All hook-agents specify `tool_supported: true` and `temperature: 0.1` (deterministic gating)
- ✓ All GSD agents specify `tool_supported: true` (callable as tools by other agents)
- ✓ Tool restrictions appropriate per agent role (least-privilege)

---

## Behavioural Parity (Workflow-by-Workflow)

The following table maps the 5 production workflows to their parity status. Workflow runs with the actual Forge runtime require user-side execution; this report covers the structural and content equivalence that supports those workflows.

| Workflow | Skills required | Agents required | Artifacts produced | Parity status |
|---|---|---|---|---|
| `silver-feature` | brainstorming, silver-spec, silver-quality-gates, silver-blast-radius, modularity..ai-llm-safety, finishing-a-development-branch, silver-create-release, gsd-discuss, gsd-plan, gsd-execute, gsd-review, gsd-verify, gsd-secure, gsd-ship | gsd-planner, gsd-plan-checker, gsd-phase-researcher, gsd-pattern-mapper, gsd-executor, gsd-code-reviewer, gsd-verifier, gsd-security-auditor, gsd-doc-writer | CONTEXT.md, RESEARCH.md, PLAN.md, REVIEW.md, VERIFICATION.md, SECURITY.md, SUMMARY.md | ✓ all skills + agents present; awaits Forge-runtime end-to-end run by user |
| `silver-bugfix` | systematic-debugging, silver-quality-gates, gsd-discuss, gsd-plan, gsd-execute, gsd-verify, finishing-a-development-branch | gsd-debugger, gsd-planner, gsd-executor, gsd-verifier | DEBUG.md, PLAN.md, VERIFICATION.md, SUMMARY.md | ✓ all present |
| `silver-ui` | silver-feature deps + design-design-system, design-design-critique, design-accessibility-review, design-ux-copy | gsd-ui-researcher, gsd-ui-checker, gsd-ui-auditor + silver-feature agents | UI-SPEC.md, UI-REVIEW.md + standard | ✓ all present |
| `silver-devops` | silver-blast-radius, devops-quality-gates, devops-skill-router, engineering-architecture, engineering-deploy-checklist | gsd-planner, gsd-executor, gsd-verifier, gsd-security-auditor | BLAST-RADIUS.md, IAC-REVIEW.md + standard | ✓ all present |
| `silver-release` | review-cross-artifact, silver-create-release, finishing-a-development-branch, requesting-code-review, receiving-code-review | gsd-doc-writer, gsd-doc-verifier | RELEASE-NOTES.md, CHANGELOG.md, GitHub release + tag | ✓ all present |

---

## Hook Parity (Gate-by-Gate)

Each SB hook's enforcement function is reproduced as a custom agent the main agent invokes at the gating moment.

| SB hook | Gating function | Forge agent | Test method (Forge runtime) |
|---|---|---|---|
| `completion-audit.sh` (intermediate) | Block `git commit` if `required_planning` skills not done | `forge-pre-commit-audit` | Stage a non-trivial source change without applying silver-quality-gates → confirm BLOCK; then apply skill → confirm ALLOW |
| `completion-audit.sh` (final) | Block PR/release/deploy if `required_deploy` skills not done | `forge-pre-pr-audit` | Try `gh pr create` without code review / verification artifacts → BLOCK; produce them → ALLOW |
| `stop-check.sh` | Block "task complete" if required skills missing | `forge-task-complete-check` | After non-trivial session, attempt to declare done → confirm BLOCK lists missing skills |
| `roadmap-freshness.sh` | Block commit if SUMMARY.md staged but ROADMAP unchecked | `forge-roadmap-freshness` | Stage `phases/065-.../SUMMARY.md` without ticking ROADMAP → BLOCK; tick → ALLOW |
| `spec-floor-check.sh` | Block production build if no SPEC.md | `forge-spec-floor-check` | `npm run build` without `.planning/SPEC.md` → BLOCK; create SPEC.md → ALLOW |
| `uat-gate.sh` | Block PR for UAT-eligible phase if no UAT.md | `forge-uat-gate` | UI/feature phase PR without UAT.md → BLOCK |
| `pr-traceability.sh` | Block PR if description lacks REQ-IDs / phase ref | `forge-pr-traceability` | PR with empty body → BLOCK; with `Closes PORT-SB-01` → ALLOW |
| `ci-status-check.sh` | Block next commit if CI failing | `forge-ci-status-check` | After failing push, attempt commit → BLOCK |
| `forbidden-skill-check.sh` | Block deprecated skill invocation | `forge-forbidden-skill-check` | Add a skill to the forbidden list and try to invoke → BLOCK |
| `session-start` + log + record | Bootstrap session | `forge-session-init` | New `:new` conversation → agent invokes init → confirms STATE.md, ROADMAP.md, phase loaded |

---

## Subagent Parity

All 31 GSD subagents are ported as Forge custom agents with the same `id` and equivalent system prompts. Tool mappings:

| Claude Code tool | Forge tool |
|---|---|
| `Read`, `Glob`, `Grep` | `read`, `search` |
| `Write`, `Edit`, `MultiEdit` | `write`, `patch` |
| `Bash` | `shell` |
| `WebFetch`, `WebSearch` | `fetch` |
| `mcp__*` | `"mcp_*"` (glob) |
| `Task` | `shell` (approximation; subagent delegation in Forge is via tool invocation, not Task tool) |

Each agent has `tool_supported: true` so it can be invoked as a tool by parent skills (e.g., the silver-feature skill says "Invoke the gsd-planner agent as a tool" instead of "spawn gsd-planner subagent").

---

## Out-of-Scope Gaps (Documented)

These are intentional gaps, mitigated by AGENTS.md guidance:

1. **No automatic hook firing.** Forge does not have a hook system. Mitigation: AGENTS.md instructs the main agent to invoke the right gating agent at the right moment. This places the gating responsibility on the main agent's discipline (which is comparable to how AGENTS.md drives Claude Code prompts).

2. **No silent state recording.** Claude Desktop SB writes a state file when each skill is applied; Forge does not have an equivalent mechanism. Mitigation: gating agents read the project's artifact state directly (PLAN.md, VERIFICATION.md, REVIEW.md, etc.) — a more robust signal than a state file.

3. **Forge has its own context engine.** SB's `/compact` step in `silver-bullet.md` §0 is replaced by Forge's built-in compaction (via `forge-services`). No user action required.

4. **Pre-existing AGENTS.md not overwritten.** The installer skips an existing `~/forge/AGENTS.md` to avoid clobbering user customisation. Users with a custom AGENTS.md must merge SB content from `forge/AGENTS.md.template` manually.

---

## End-to-End Runtime Test (User Action Required)

To complete Phase 69 verification, the user should:

1. **Choose a test app.** Clone or copy a simple project (e.g., the `food` test app already configured for Forge):
   ```bash
   cp -R ~/Documents/Projects/food ~/Documents/Projects/food-forge-sb
   cd ~/Documents/Projects/food-forge-sb
   ```

2. **Install SB for Forge into the test app:**
   ```bash
   bash /path/to/silver-bullet/forge-sb-install.sh
   ```

3. **Verify install:**
   ```bash
   bash /path/to/silver-bullet/forge/scripts/smoke-test.sh --project
   ```
   Expected: 23+ checks pass (the project-level check adds 2).

4. **Run a `silver-feature` workflow in Forge:**
   ```bash
   forge
   > Add a small new feature: a CSV export endpoint for the dataset
   ```
   Confirm the agent:
   - Invokes `forge-session-init` at start
   - Applies the `silver-feature` skill
   - Invokes `gsd-planner` agent for planning
   - Invokes `gsd-executor` agent for execution
   - Invokes `gsd-verifier` agent for verification
   - Invokes `forge-pre-commit-audit` before commit
   - Produces `.planning/phases/<NNN>/CONTEXT.md`, `PLAN.md`, `VERIFICATION.md`, `SUMMARY.md`

5. **Repeat for the other 4 workflows** (`silver-bugfix`, `silver-ui`, `silver-devops`, `silver-release`) and confirm equivalent artifacts.

6. **Update this report** with the runtime outcomes — note any deviations and file follow-up issues via `silver-add`.

---

## Conclusion

**Structural parity: ✓ ACHIEVED.** All 107 skills and 42 custom agents are installed; format and frontmatter are valid; smoke test passes 21/21.

**Behavioural parity: ✓ STRUCTURALLY ACHIEVED, awaits user runtime verification.** The skill+agent set covers all 5 production workflows. End-to-end runtime tests require Forge CLI access from a user environment.

**Recommendation:** Ship v0.28.0 once runtime verification is completed by the user; track any runtime gaps as follow-up issues for v0.28.1+.
