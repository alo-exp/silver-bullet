# Silver Bullet for Forge

A complete Forge-native implementation of the Silver Bullet development workflow system.

## What is This?

Silver Bullet for Forge ports the Silver Bullet (SB) development workflow system from Claude Code plugin format to Forge's native primitives. It provides:

- **41 skills** organized into workflows (GSD, Quality Gates, Superpowers, Silver Orchestrator)
- **AGENTS.md templates** for session management and routing
- **Idempotent installer** with dry-run support

## Quick Start

```bash
# Install (dry run first to see what will be installed)
./forge-sb-install.sh --dry-run

# Install for real
./forge-sb-install.sh

# Verify installation
./tests/smoke-test.sh
```

## Skills Overview

### GSD Workflow (12 skills)
Core execution workflow following the "Get Shit Done" methodology:
- `gsd-discuss` — Clarify requirements with locked decisions
- `gsd-plan` — Create execution plans with task breakdown
- `gsd-execute` — Execute with TDD discipline
- `gsd-verify` — Verify against acceptance criteria
- `gsd-ship` — Create PR with quality gates
- `gsd-review` — Code review with severity classification
- `gsd-review-fix` — Address review findings
- `gsd-secure` — Security audit
- `gsd-validate` — Spec validation
- `gsd-intel` — Codebase intelligence
- `gsd-progress` — Progress reporting
- `gsd-brainstorm` — Approach exploration

### Quality Dimensions (9 + master)
Enforce 9 quality dimensions at design-time and pre-ship:
- `quality-gates` — Consolidated master skill
- `modularity` — Single responsibility, change locality
- `reusability` — DRY principle, abstractions
- `scalability` — Stateless design, performance
- `security` — Defense in depth, OWASP
- `reliability` — Error handling, graceful degradation
- `usability` — API design, error messages
- `testability` — DI, pure functions, coverage
- `extensibility` — Open/closed, plugin architecture
- `ai-llm-safety` — Prompt injection, model safety

### Superpowers (7 skills)
Core development skills:
- `tdd` — Red-green-refactor with iron law
- `brainstorming` — Product ideation
- `writing-plans` — Spec to implementation plan
- `requesting-code-review` — Frame review scope
- `receiving-code-review` — Handle feedback
- `finishing-branch` — Merge decisions

### Silver Orchestrator (6 skills)
Workflow routers:
- `silver` — Smart workflow router
- `silver-feature` — Full feature workflow
- `silver-bugfix` — Bug fix workflow
- `silver-ui` — UI/frontend workflow
- `silver-devops` — Infrastructure workflow
- `silver-research` — Research/spike workflow

## Usage

### Starting a Feature
```
> I want to add user authentication

Forge detects "add" → routes to silver-feature → runs full workflow
```

### Quality Review
```
> quality gates

Forge detects trigger → runs all 9 dimensions → reports pass/fail
```

### TDD
```
> TDD

Forge detects trigger → enforces red-green-refactor cycle
```

## Adding New Skills

1. Create `forge/skills/<skill-name>/SKILL.md`
2. Add YAML frontmatter:
   ```yaml
   ---
   id: <skill-name>
   title: <Human Readable Title>
   description: <One sentence>
   trigger:
     - "<trigger phrase 1>"
     - "<trigger phrase 2>"
   ---
   ```
3. Write skill body in imperative prose
4. Run `tests/smoke-test.sh` to verify

## Updating AGENTS.md

Edit `forge/AGENTS.md.template` for global changes or `forge/AGENTS.project.template` for project-specific changes.

## File Structure

```
forge/
├── skills/
│   ├── gsd-*/           # GSD workflow skills
│   ├── quality-*/       # Quality dimension skills
│   ├── silver*/         # Orchestrator skills
│   └── <superpower>*/   # Superpower skills
├── AGENTS.md.template    # Global instructions
└── AGENTS.project.template # Project template

forge-sb-install.sh       # Idempotent installer

tests/
└── smoke-test.sh         # Verification tests

docs/
├── mapping-table.md      # CC → Forge mapping
└── forge-sb-README.md    # This file
```

## Primitive Mapping

| Claude Code | Forge |
|---|---|
| Skill tool | Trigger phrase |
| TodoWrite | Session log |
| PreToolUse hook | AGENTS.md |
| SessionStart hook | AGENTS.md |
| Plugin manifest | forge-sb-install.sh |

See `docs/mapping-table.md` for full mapping.

## Verification

```bash
# Run all tests
./tests/smoke-test.sh

# Count skills
ls forge/skills/*/SKILL.md | wc -l
```

Expected: 34 skills, all tests pass.

## License

Same as Silver Bullet — see repo root.
