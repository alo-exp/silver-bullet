---
name: silver-init
description: Initialize Silver Bullet workflow for a project on Forge — sets up AGENTS.md, .planning/ scaffold, project conventions, and verifies the SB skill+agent set is installed.
---

# Silver Init — Forge Edition

Initializes the Silver Bullet structured workflow for a Forge project. Confirms the global skill+agent set is installed, then bootstraps the project-level files (`AGENTS.md`, `.planning/`, `.forge/skills/`, `.forge/agents/`).

## When to Use

- The user runs `silver:init` or asks "set up silver bullet" or "initialize silver bullet for this project"
- A project has no `.planning/PROJECT.md` and the user wants to start using SB workflows

## Prerequisites

This skill expects the SB skill+agent set to already be installed globally at `~/forge/skills/` and `~/forge/agents/`. If not present, instruct the user:

```bash
curl -fsSL https://raw.githubusercontent.com/alo-exp/silver-bullet/main/forge-sb-install.sh | bash
```

Verify after install:

```bash
test -d "$HOME/forge/skills" && find "$HOME/forge/skills" -name SKILL.md | wc -l
test -d "$HOME/forge/agents" && find "$HOME/forge/agents" -name "*.md" | wc -l
```

If counts are <100 skills or <30 agents, the install is incomplete — re-run.

## Procedure

### Step 1 — Detect Project Stack

Inspect the repo to detect language, framework, and test runner:

- Language: presence of `package.json` (JS/TS), `pyproject.toml`/`requirements.txt` (Python), `Cargo.toml` (Rust), `go.mod` (Go), `pom.xml`/`build.gradle` (JVM), etc.
- Test runner: parse the package file or look for `pytest.ini`, `jest.config.*`, `vitest.config.*`, etc.
- Linter/formatter: `.eslintrc.*`, `prettier.config.*`, `ruff.toml`, `rustfmt.toml`, etc.

Capture stack info for inclusion in the project AGENTS.md.

### Step 2 — Detect Existing Setup

Check whether SB is already initialized in this project:

```bash
test -f AGENTS.md && echo "AGENTS.md exists"
test -d .planning && echo ".planning/ exists"
test -d .forge/skills && echo ".forge/skills/ exists"
test -d .forge/agents && echo ".forge/agents/ exists"
```

If any of these exist, ask the user before overwriting:

> "Silver Bullet appears to be partially or fully set up. Choose: 1) **Keep existing** (skip already-present files), 2) **Replace** (overwrite everything), 3) **Merge** (interactive per-file)."

Default: Keep existing.

### Step 3 — Create `.planning/` Scaffold

If `.planning/` does not exist, create:

```
.planning/
├── PROJECT.md     — project context (template stamped here)
├── STATE.md       — current execution state
├── ROADMAP.md     — phase roadmap (initially empty)
├── MILESTONES.md  — completed milestones (initially empty)
├── REQUIREMENTS.md — milestone requirements (initially empty)
├── config.json    — required-skill lists, paths, options
└── phases/        — per-phase directories created on demand
```

Use the templates available in the global SB skill set under `~/forge/silver-bullet/templates/` (or fetch from `https://raw.githubusercontent.com/alo-exp/silver-bullet/main/templates/`).

### Step 4 — Create Project AGENTS.md

Create or update `./AGENTS.md` (Forge's CLAUDE.md equivalent) with:

1. Project conventions (language, framework, test runner, linter, formatter — from Step 1)
2. SB workflow routing (when to use silver-feature, silver-bugfix, silver-ui, silver-devops, silver-release, etc.)
3. Mandatory hook-agent invocations:
   - Before any `git commit` → invoke `forge-pre-commit-audit` agent as a tool
   - Before any `gh pr create` or `gh release create` or production deploy → invoke `forge-pre-pr-audit` agent
   - Before declaring a task complete → invoke `forge-task-complete-check` agent
   - Before any production build → invoke `forge-spec-floor-check` agent
   - When committing a phase SUMMARY.md → invoke `forge-roadmap-freshness` agent
   - At session start → invoke `forge-session-init` agent
4. GSD subagent-as-tool delegation — list common subagents and when to invoke them (gsd-planner during planning, gsd-verifier after execution, gsd-code-reviewer for review, etc.)

Use the global template at `~/forge/silver-bullet/templates/AGENTS.md.template` if present, falling back to fetching from the SB repo.

### Step 5 — Create Project `.forge/skills/` and `.forge/agents/` (Optional)

Project-level skill/agent overrides live here. By default `silver:init` does NOT copy global skills to the project — Forge already loads them from `~/forge/skills/`. Only create `.forge/skills/` and `.forge/agents/` if the user wants to override or extend specific skills for this project.

If the user opts in, create empty directories with a README:

```bash
mkdir -p .forge/skills .forge/agents
echo "# Project-specific Forge skills (override globals by id)" > .forge/skills/README.md
echo "# Project-specific Forge agents (override globals by id)" > .forge/agents/README.md
```

### Step 6 — Initial PROJECT.md

If `.planning/PROJECT.md` does not exist, create one with:

- Project name (derived from repo directory)
- "What This Is" — leave placeholder for user to fill
- "Core Value" — leave placeholder
- Validated requirements: empty
- Active requirements: empty
- Stack info from Step 1
- Constraints: derived from stack (e.g., "Tech stack: TypeScript / Node.js / Vitest")

Inform the user: "Created PROJECT.md skeleton. Edit `.planning/PROJECT.md` to fill in 'What This Is' and 'Core Value' before starting your first milestone."

### Step 7 — Verify Skills and Agents Are Loadable

Run a smoke test to confirm Forge can pick up the skills:

```bash
test -d "$HOME/forge/skills/silver-feature" && echo "silver-feature skill OK"
test -f "$HOME/forge/agents/gsd-planner.md" && echo "gsd-planner agent OK"
```

If either fails, instruct the user to re-run `forge-sb-install.sh`.

### Step 8 — Final Confirmation

Report:

```
✓ Silver Bullet initialized for {project_name}
  - AGENTS.md         created/preserved
  - .planning/        scaffolded
  - .forge/skills/    {present or skipped}
  - .forge/agents/    {present or skipped}

Global skill set: {N} skills at ~/forge/skills/
Global agent set: {M} agents at ~/forge/agents/

Next steps:
  1. Edit .planning/PROJECT.md to define your project
  2. Use `silver:feature`, `silver:bugfix`, `silver:ui`, etc., to start work
  3. Use `silver:research` for technology decisions
```

## Notes

- Forge has no hook system — workflow gates are enforced via custom agents the main agent invokes at gating moments. AGENTS.md is the central enforcement layer.
- The global skill+agent set is shared across all projects. Project-level overrides (in `.forge/skills/` and `.forge/agents/`) take precedence by id when present.
- This skill does NOT install Claude Code plugins — that workflow only applies to Claude Desktop. Forge users get all SB capability via `forge-sb-install.sh`.
