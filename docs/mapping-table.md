# Silver Bullet Primitive Mapping: Claude Code → Forge

| Claude Code Primitive | Forge Equivalent | Notes |
|---|---|---|
| Skill tool invocation (`Skill({skill: "tdd"})`) | Trigger phrase in prompt ("TDD", "test-driven") | Forge's skill engine detects via YAML `trigger` field |
| `TodoWrite` | Session log checkboxes in `docs/sessions/YYYY-MM-DD.md` | Manual tracking |
| `AskUserQuestion` | Inline prose question in skill body (wait for response) | Same behavior |
| `PreToolUse` hook | AGENTS.md "Before every action" section | Applied globally, not per-call |
| `PostToolUse` hook | AGENTS.md "After every action" section | Applied globally |
| `SessionStart` hook | AGENTS.md "On Session Start" section | Runs at session init |
| Plugin MANIFEST.json | `forge-sb-install.sh` bootstrap script | Manual install |
| `~/.claudeplugins.json` | `~/forge/AGENTS.md` + `~/forge/skills/` | Global user config |
| Project `.claudeplugins.json` | `.forge/skills/` + project `AGENTS.md` | Per-project config |
| `silver-bullet.md §10` preferences | AGENTS.md standing instructions | Baked in, not per-session |
| Episodic memory MCP | Session logs + AGENTS.md mentoring loop | Manual extraction |
| Multi-AI review (`multai`) | Inline "get second opinion" instruction in review skills | Simulated via prompt |

## Key Concepts

### Forge Skills
Skills are `.forge/skills/<name>/SKILL.md` files with YAML frontmatter:
```yaml
---
id: <kebab-case-id>
title: <Human Readable Title>
description: <One sentence>
trigger:
  - "<trigger phrase 1>"
  - "<trigger phrase 2>"
---

# Title

Imperative prose describing the skill steps.
```

### Skill Invocation
In Claude Code: `Skill({skill: "tdd"})`
In Forge: User types "TDD" or "test-driven" → Forge detects trigger → loads SKILL.md

### Session Logging
Claude Code uses `TodoWrite` for task tracking.
Forge uses `docs/sessions/YYYY-MM-DD.md` with checkboxes.

### Workflow Routing
Claude Code: `/silver` skill routes to `/silver:feature`, etc.
Forge: User types "silver feature" → `silver` skill detects trigger → routes to `silver-feature`

## Differences from Claude Code

1. **No plugin system**: Skills are plain files, no manifest registration
2. **No hooks.json**: AGENTS.md replaces hook-based enforcement
3. **No state machine**: Session logs replace TodoWrite tracking
4. **No automatic skill recording**: Trigger detection replaces Skill tool calls
5. **No subagent tracking**: AGENTS.md responsibilities replace hooks

## Source Material

- `skills/` — 41 existing Claude Code skills (adapt, don't copy verbatim)
- `hooks/` — 23 existing hooks (map to AGENTS.md sections)
- `silver-bullet.md` — master SB doc (session startup, routing, enforcement)
