# OpenCode AI Coding Agent Extensibility Mechanisms — Research Report

**Date:** 2026-06-27
**Sources:** opencode.ai/docs, github.com/anomalyco/opencode

---

## 1. Plugin System (Hooks)

**Source:** https://opencode.ai/docs/plugins

OpenCode has a full **plugin system** written in JavaScript/TypeScript. Plugins are modules that export functions receiving a context object and returning a hooks object.

### Plugin Structure

```typescript
import type { Plugin } from "@opencode-ai/plugin"

export const MyPlugin: Plugin = async ({ project, client, $, directory, worktree }) => {
  return {
    // Type-safe hook implementations
  }
}
```

### Available Events

**Session Events:**
- `session.created`
- `session.compacted`
- `session.deleted`
- `session.diff`
- `session.error`
- `session.idle`
- `session.status`
- `session.updated`

**Tool Events:**
- `tool.execute.before`
- `tool.execute.after`

**File Events:**
- `file.edited`
- `file.watcher.updated`

**Server Events:**
- `server.connected`

**Command Events:**
- `command.executed`

**Todo Events:**
- `todo.updated`

**Experimental:**
- `experimental.session.compacting` — fires before LLM generates continuation summary; can inject context or replace the compaction prompt entirely.

### Event Handler Pattern

```javascript
export const NotificationPlugin = async ({ project, client, $, directory, worktree }) => {
  return {
    event: async ({ event }) => {
      if (event.type === "session.idle") {
        await $`osascript -e 'display notification "Session done!" with title "opencode"'`
      }
    },
  }
}
```

### Custom Tools via Plugins

Plugins can register new tools using the `tool` helper with Zod schema:

```typescript
import { type Plugin, tool } from "@opencode-ai/plugin"

export const CustomToolsPlugin: Plugin = async (ctx) => {
  return {
    tool: {
      mytool: tool({
        description: "This is a custom tool",
        args: {
          foo: tool.schema.string(),
        },
        async execute(args, context) {
          const { directory, worktree } = context
          return `Hello ${args.foo}`
        },
      }),
    },
  }
}
```

Plugin tools override built-in tools if they share the same name.

### Plugin Installation

**From npm:**
```json
{
  "plugin": ["opencode-helicone-session", "opencode-wakatime", "@my-org/custom-plugin"]
}
```

**From local files:** Place JS/TS files in:
- `.opencode/plugins/` — project-level
- `~/.config/opencode/plugins/` — global

### Load Order

1. Global config (`~/.config/opencode/opencode.json`)
2. Project config (`opencode.json`)
3. Global plugin directory (`~/.config/opencode/plugins/`)
4. Project plugin directory (`.opencode/plugins/`)

### Key Finding: `tool.execute.before` / `tool.execute.after`

These hooks fire before and after every tool execution, enabling **interception and modification of tool calls**. This is analogous to Claude Code's `hooks.json` pre/post tool hooks.

---

## 2. Permission System (Tool Blocking/Approval)

**Source:** https://opencode.ai/docs/permissions, https://opencode.ai/docs/agents

OpenCode has a granular **permission system** that controls whether tools run automatically, prompt for approval, or are blocked.

### Permission Values

- `"allow"` — run without approval
- `"ask"` — prompt for approval
- `"deny"` — block entirely

### Permission Keys

| Key | Tools it gates |
|-----|---------------|
| `read` | `read` |
| `edit` | `write`, `edit`, `apply_patch` |
| `glob` | `glob` |
| `grep` | `grep` |
| `list` | `list` |
| `bash` | `bash` |
| `task` | `task` (subagent spawning) |
| `external_directory` | Any tool reading/writing outside project |
| `todowrite` | `todowrite`, `todoread` |
| `webfetch` | `webfetch` |
| `websearch` | `websearch` |
| `lsp` | `lsp` |
| `skill` | `skill` |
| `question` | `question` |
| `doom_loop` | Recovery prompts when agent is stuck |

### Glob Pattern Matching

Permission keys use wildcard patterns matching tool names:

```json
{
  "permission": {
    "bash": {
      "*": "ask",
      "git *": "allow",
      "git commit *": "deny",
      "git push *": "deny",
      "grep *": "allow"
    }
  }
}
```

Wildcards: `*` matches zero or more chars, `?` matches exactly one char.

### MCP Tool Permissions

MCP tools are controlled via wildcard patterns on tool names:

```json
{
  "permission": {
    "mymcp_*": "deny",
    "mymcp_search": "ask"
  }
}
```

### Per-Agent Permission Overrides

Agent permissions merge with global config; agent rules take precedence.

```json
{
  "agent": {
    "build": {
      "permission": {
        "bash": { "*": "ask", "git *": "allow" }
      }
    }
  }
}
```

Or in markdown:

```yaml
---
description: Code review without edits
mode: subagent
permission:
  edit: deny
  bash: ask
  webfetch: deny
---
```

### Key Finding: Equivalent to Claude Code hooks.json

OpenCode's permission system is **config-driven** (not hook-script-based like Claude Code's `hooks.json`). It achieves the same outcome (blocking/allowing tool calls) but via declarative JSON config rather than executable shell scripts. There is no equivalent to Claude Code's `hook scripts` that run shell commands on tool events — OpenCode uses plugin JS/TS code for that.

---

## 3. AGENTS.md Configuration

**Source:** https://opencode.ai/docs

OpenCode uses `AGENTS.md` as a **project-level instruction file** (analogous to `CLAUDE.md` in Claude Code).

- Created via the `/init` command
- Placed in the project root
- Should be committed to Git
- Helps the agent understand project structure and coding patterns

This is a **context injection mechanism**, not a hook/extension system.

---

## 4. Agent System (Primary + Subagents)

**Source:** https://opencode.ai/docs/agents

### Built-in Agents

- **build** — Default, full-access agent for development work
- **plan** — Read-only agent; denies file edits by default, asks permission for bash

### Built-in Subagents

- **General** — Complex searches and multistep tasks
- **Explore** — Code exploration
- **Scout** — Search and discovery

### Custom Agents via JSON

```json
{
  "agent": {
    "code-reviewer": {
      "description": "Reviews code for best practices",
      "mode": "subagent",
      "model": "anthropic/claude-sonnet-4-5",
      "prompt": "You are a code reviewer.",
      "permission": { "edit": "deny" }
    }
  }
}
```

### Custom Agents via Markdown

Place `.md` files in:
- `~/.config/opencode/agents/` — global
- `.opencode/agents/` — project-level

```markdown
---
description: Reviews code for quality
mode: subagent
model: anthropic/claude-sonnet-4-20250514
temperature: 0.1
permission:
  edit: deny
  bash: deny
---
You are in code review mode.
```

### Agent Modes

- `primary` — switchable via Tab key
- `subagent` — invoked by primary agents or @ mentions
- `all` — both (default)

### Subagent Spawning (Task Tool)

Primary agents invoke subagents via the `task` tool. Task permissions control which subagents can be spawned:

```json
{
  "agent": {
    "orchestrator": {
      "mode": "primary",
      "permission": {
        "task": {
          "*": "deny",
          "orchestrator-*": "allow",
          "code-reviewer": "ask"
        }
      }
    }
  }
}
```

When set to `deny`, the subagent is removed from the Task tool description entirely.

Users can always invoke any subagent directly via `@` autocomplete, even if task permissions deny it.

### Child Session Navigation

When subagents create child sessions:
- `<Leader>+Down` — enter first child session
- `Right` — cycle to next child
- `Left` — cycle to previous child
- `Up` — return to parent

---

## 5. MCP Server Integration

**Source:** https://opencode.ai/docs/mcp-servers

### Local MCP Servers

```json
{
  "mcp": {
    "my-local-mcp-server": {
      "type": "local",
      "command": ["npx", "-y", "my-mcp-command"],
      "enabled": true,
      "environment": {
        "MY_ENV_VAR": "value"
      }
    }
  }
}
```

### Remote MCP Servers

```json
{
  "mcp": {
    "jira": {
      "type": "remote",
      "url": "https://jira.example.com/mcp",
      "enabled": true
    }
  }
}
```

### Organizational Defaults

Organizations provide default MCP servers via `.well-known/opencode` endpoint. Local config overrides remote defaults.

### MCP Tools and Permissions

MCP tools are automatically available to the LLM alongside built-in tools. Controlled via permission wildcards:

```json
{
  "permission": {
    "mymcp_*": "deny",
    "mymcp_search": "ask"
  }
}
```

---

## 6. Skills System

**Source:** https://opencode.ai/docs/skills

Skills are **reusable instruction sets** loaded on-demand via the native `skill` tool.

### SKILL.md Format

Each `SKILL.md` must have YAML frontmatter:

```yaml
---
name: my-skill
description: What this skill does
license: MIT  # optional
compatibility: ...  # optional
metadata:  # optional string-to-string map
  key: value
---
```

### Placement

- `~/.config/opencode/skills/` — global
- `.opencode/skills/` — project-level

### Loading

Skills are loaded on-demand when an agent invokes the `skill` tool. Agents see available skills and can load full content when needed.

### Troubleshooting

- `SKILL.md` must be uppercase
- Frontmatter must include `name` and `description`
- Skill names must be unique across all locations
- Skills with `deny` permission are hidden from agents

---

## 7. Config System

**Source:** https://opencode.ai/docs/config

### Format

`opencode.json` or `opencode.jsonc` (JSON with comments).

### Config Precedence (later overrides earlier)

1. Remote config (`.well-known/opencode`) — org defaults
2. Global config (`~/.config/opencode/opencode.json`) — user prefs
3. Custom config (`OPENCODE_CONFIG` env var)
4. Project config (`opencode.json` in project)
5. `.opencode` directories — agents, commands, plugins
6. Inline config (`OPENCODE_CONFIG_CONTENT` env var) — runtime overrides
7. Managed config files (`/Library/Application Support/opencode/` on macOS)
8. macOS managed preferences (`.mobileconfig` via MDM) — highest priority

### Directory Structure

`.opencode` and `~/.config/opencode` use plural subdirectory names:
- `agents/`, `commands/`, `modes/`, `plugins/`, `skills/`, `tools/`, `themes/`

---

## 8. Key GitHub Issues/PRs (Evidence of Active Development)

| Title | URL |
|-------|-----|
| Session lifecycle context hooks for persistent plugin state | https://github.com/anomalyco/opencode/issues/28695 |
| Add LLM and session observability hooks | https://github.com/anomalyco/opencode/pull/33523 |
| Plugin extensibility gaps blocking dictation/voice input plugins | https://github.com/anomalyco/opencode/issues/17425 |
| Memory compaction awareness hooks for agents | https://github.com/anomalyco/opencode/issues/30116 |
| Add expanded hook events to the plugin system | https://github.com/anomalyco/opencode/issues/21075 |
| MCP tools connected but not exposed to agent | https://github.com/anomalyco/opencode/issues/33027 |
| Inherit MCP tool allow permissions in subagent sessions | https://github.com/anomalyco/opencode/pull/30288 |
| MCP filesystem tools bypass plan mode `edit: deny` permission rule | https://github.com/anomalyco/opencode/issues/30291 |
| Built-in customize-opencode skill is outdated | https://github.com/anomalyco/opencode/issues/31982 |
| Improve plugin development support | https://github.com/anomalyco/opencode/issues/19428 |

---

## 9. Comparison: OpenCode vs Claude Code Extensibility

| Feature | Claude Code | OpenCode |
|---------|------------|---------|
| **Hook system** | `hooks.json` with shell scripts | Plugin system with JS/TS event handlers |
| **Tool interception** | Pre/post hooks via `hooks.json` | `tool.execute.before` / `tool.execute.after` plugin events |
| **Tool blocking** | Hook scripts returning non-zero exit codes | Declarative `permission` config (`allow`/`ask`/`deny`) |
| **Config injection** | `CLAUDE.md` / `AGENTS.md` | `AGENTS.md` + `opencode.json` + `.opencode/` dirs |
| **Skills** | Skill tool with SKILL.md files | Identical: skill tool with SKILL.md files |
| **Subagents** | `task` tool spawning subagents | `task` tool with permission-controlled spawning |
| **Agent definition** | JSON config + markdown | JSON config + markdown (identical pattern) |
| **MCP integration** | Native MCP support | Native MCP support (local + remote) |
| **Custom tools** | MCP servers | Plugins (JS/TS) + MCP servers |
| **Session lifecycle** | No public hook API | 8 session events + compaction hooks |
| **Permissions** | `allowedTools` / `blockedTools` arrays | Glob-pattern permission objects per tool category |

### Key Differences

1. **OpenCode's plugin system is more powerful** — full JS/TS code execution on events, not just shell scripts.
2. **OpenCode has more granular permissions** — glob patterns with `allow`/`ask`/`deny` per command pattern.
3. **OpenCode has compaction hooks** — `experimental.session.compacting` lets plugins inject context or replace the compaction prompt.
4. **OpenCode has remote MCP servers** — supports `type: "remote"` with URL-based MCP, not just stdio.
5. **Claude Code's hooks are simpler** — shell scripts in `hooks.json` are easier to write than JS/TS plugins.

---

## Summary of Findings

**Does OpenCode have hooks similar to Claude Code's hooks.json?**
Yes, but more powerful. OpenCode's plugin system provides `tool.execute.before`/`tool.execute.after` events, session lifecycle events, file events, and compaction hooks — all via JS/TS code, not shell scripts.

**Can OpenCode intercept/block tool calls?**
Yes, via two mechanisms:
1. **Permission config** — declarative `allow`/`ask`/`deny` with glob patterns
2. **Plugin hooks** — `tool.execute.before` event handler can inspect and modify tool calls

**Does OpenCode have session lifecycle events?**
Yes: `session.created`, `session.compacted`, `session.deleted`, `session.diff`, `session.error`, `session.idle`, `session.status`, `session.updated`.

**Does OpenCode support skills?**
Yes, identical to Claude Code's skill system. `SKILL.md` files with YAML frontmatter placed in `.opencode/skills/` or `~/.config/opencode/skills/`.

**Does OpenCode have subagent/agent spawning?**
Yes. Primary agents invoke subagents via the `task` tool with glob-pattern permission control. Built-in subagents: General, Explore, Scout. Custom subagents defined via JSON or markdown.

**MCP server integration?**
Full support for both local (stdio) and remote (URL-based) MCP servers. Controlled via permission wildcards.

**Config injection via AGENTS.md?**
Yes. `/init` creates `AGENTS.md` in project root. Additionally, `opencode.json`, `.opencode/` directories, and environment variables provide layered configuration.
