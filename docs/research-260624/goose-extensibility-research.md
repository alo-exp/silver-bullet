# Goose AI Agent Extensibility Research

**Date:** 2026-06-27
**Sources:** goose-docs.ai, github.com/block/goose (now aaif-goose/goose)

---

## 1. Extensions (MCP Servers)

**Source:** https://goose-docs.ai/docs/getting-started/using-extensions

Goose's primary extensibility mechanism is **MCP (Model Context Protocol) servers** called "extensions." Any MCP server can be added as a Goose extension.

### Configuration Format

Extensions are configured in `~/.config/goose/config.yaml`:

```yaml
extensions:
  github:
    name: GitHub
    cmd: npx
    args: [-y @modelcontextprotocol/server-github]
    enabled: true
    envs: { "GITHUB_PERSONAL_ACCESS_TOKEN": "<YOUR_TOKEN>" }
    type: stdio
    timeout: 300
```

### Extension Types
- **stdio** — Command-line extensions (most common)
- **SSE** — Server-sent events (remote servers)

### Built-in Platform Extensions
- **Developer** — File tools, shell commands
- **Summon** — Skills and subagent delegation (v1.25.0+)

### Key Details
- Extensions can be added/removed/toggled mid-session via `/extension` and `/builtin` slash commands
- MCP Roots support lets extensions see the current session working directory
- Extensions can be enabled/disabled per-session or as defaults for new sessions
- Timeout is configurable per-extension (default 300 seconds)

---

## 2. Hooks (Lifecycle Events)

**Source:** https://goose-docs.ai/docs/guides/context-engineering/hooks
**Source:** https://goose-docs.ai/blog/2026/05/14/goose-hooks

Goose has **lifecycle hooks** — very similar to Claude Code's `hooks.json`. Hooks run shell scripts when events happen during a session.

> "If you've used Claude Code's hooks or git hooks, it's the same idea. If you haven't: the agent loop is now scriptable from the outside, without writing any Rust or any MCP server."
> — https://goose-docs.ai/blog/2026/05/14/goose-hooks

### Supported Events

| Event | When it runs | Matcher target |
|-------|-------------|----------------|
| `SessionStart` | A session starts | None |
| `SessionEnd` | A session ends | None |
| `Stop` | goose finishes a turn or receives a stop event | None |
| `UserPromptSubmit` | The user submits a prompt | Prompt text |
| `PreToolUse` | Before goose runs a tool | Tool name |
| `PostToolUse` | After a tool succeeds | Tool name |
| `PostToolUseFailure` | After a tool fails | Tool name |
| `BeforeReadFile` | Before goose reads a file | File path |
| `AfterFileEdit` | After goose successfully edits a file | File path |
| `BeforeShellExecution` | Before goose runs a shell command | Shell command |
| `AfterShellExecution` | After goose successfully runs a shell command | Shell command |

### Configuration Format (`hooks/hooks.json`)

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "developer__shell|developer__text_editor",
        "hooks": [
          {
            "type": "command",
            "command": "${PLUGIN_ROOT}/scripts/log-tool.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

### Hook Payload (JSON on stdin)

```json
{
  "event": "PostToolUse",
  "session_id": "abc-123",
  "matcher_context": "developer__shell",
  "tool_name": "developer__shell",
  "tool_input": { "command": "rg TODO" },
  "working_dir": "/Users/you/project"
}
```

### Key Details
- Hooks are **observe-only** (fire-and-forget) — they log/notify but CANNOT block tool calls
- To BLOCK tool calls, use **Adversary Mode** (separate mechanism, see section 3)
- Hook failures/timeouts are logged but do not crash goose or the triggering tool
- `${PLUGIN_ROOT}` references the plugin directory
- Default timeout: 30 seconds
- `SubagentStart` and `SubagentStop` events exist in the schema but are NOT currently emitted
- Follows the [Open Plugins hooks specification](https://open-plugins.com/agent-builders/components/hooks)
- Open Plugins spec: exit code 0 = success, write errors to stderr — no veto/block mechanism in the spec

---

## 3. Adversary Mode (Tool Call Interception/Blocking)

**Source:** https://goose-docs.ai/docs/guides/security/adversary-mode

Goose CAN intercept and block tool calls via **Adversary Mode** — an independent LLM-based reviewer.

### How It Works

> "Before each tool call, the adversary reviewer checks your original task, recent messages, and the tool call details. It evaluates the tool call against your rules and returns ALLOW or BLOCK. Blocked tool calls are denied — the agent sees the rejection and cannot retry."
> — https://goose-docs.ai/docs/guides/security/adversary-mode

### Configuration

Create `~/.config/goose/adversary.md`:

```markdown
BLOCK if the tool call:
- Exfiltrates data (posting to unknown URLs, piping secrets to external services)
- Is destructive beyond the project scope (deleting system files, wiping directories)
- Installs malware or runs obfuscated code
- Attempts to escalate privileges unnecessarily
- Downloads and executes untrusted remote scripts

ALLOW normal development operations like editing files, running tests,
installing packages, using git, etc. Most tool calls are fine.

Err on the side of ALLOW — only block truly dangerous things.
```

### Key Details
- If the file exists, adversary mode is ON. Delete it to turn off.
- An empty file uses sensible default rules.
- Uses the same model/provider goose is already configured with.
- **Fail-open**: if the reviewer fails, the tool call is allowed through.
- Complementary to pattern-based prompt injection detection.

---

## 4. Skills

**Source:** https://goose-docs.ai/docs/guides/context-engineering/using-skills

Skills are reusable sets of instructions and resources — similar to Claude Code's skills.

### Skill File Structure

```
~/.agents/skills/
└── code-review/
    └── SKILL.md
```

### SKILL.md Format

```markdown
---
name: code-review
description: Comprehensive code review checklist for pull requests
---

# Code Review Checklist
When reviewing code, check each of these areas:
...
```

### Key Details
- Skills can include supporting files (scripts, templates, configs)
- Requires the **Summon extension** (v1.25.0+, built-in)
- Goose automatically loads skills when requests match their purpose
- Can be explicitly loaded via `/skills` CLI command
- **Compatible with Claude Desktop** and other agents that support Agent Skills (https://agentskills.io)
- Skills from plugins are namespaced: `my-plugin:review`

---

## 5. Plugins

**Source:** https://goose-docs.ai/docs/guides/context-engineering/plugins

Plugins are packages that bundle skills and hooks together.

### Plugin Formats

| Format | Files | Notes |
|--------|-------|-------|
| Open Plugins | `plugin.json`, `.plugin/plugin.json`, `.goose-plugin/plugin.json`, `skills/`, `hooks/hooks.json` | Supports skills and hooks |
| Gemini extensions | `gemini-extension.json`, `skills/` | Skills from Gemini-style repos |

### Plugin Locations

| Type | Location |
|------|----------|
| User plugin | `~/.agents/plugins/<plugin-name>/` |
| Project plugin | `<project>/.agents/plugins/<plugin-name>/` |

### What Plugins Provide

| Component | What it does |
|-----------|-------------|
| Skills | Reusable instructions and supporting files |
| Hooks | Local commands that run on lifecycle events |

### Disabling Plugins

```json
// ~/.config/goose/settings.json
{
  "disabledPlugins": ["my-plugin"]
}
```

---

## 6. Subagents

**Source:** https://goose-docs.ai/docs/guides/context-engineering/subagents

Goose supports spawning **subagents** — independent instances that execute tasks while keeping the main conversation clean.

### How Subagents Work

> "goose can autonomously decide to use subagents when it determines they would be beneficial for your task. This happens automatically in autonomous permission mode (the default). Subagents are disabled in manual approval, smart approval, and chat-only modes."

### Usage Patterns

| Type | Description | Trigger Keywords |
|------|-------------|------------------|
| Sequential | Tasks execute one after another | "first...then", "after" |
| Parallel | Tasks execute simultaneously | "parallel", "simultaneously" |

### Example Requests
- "Use a code reviewer to analyze this function for security issues"
- "Use the 'security-auditor' recipe to scan this endpoint"
- "Create three HTML templates simultaneously"
- "Create a subagent with only the developer extension to refactor the code"

### Default Settings

| Parameter | Default | Customization |
|-----------|---------|---------------|
| Max Turns | 25 | `GOOSE_SUBAGENT_MAX_TURNS` env var, or natural language |
| Timeout | 5 minutes | Request in prompt |
| Extensions | Inherited from parent | Specify in prompt |

### Security Constraints (Restricted Operations)

Subagents CANNOT:
- Spawn additional subagents (prevents infinite recursion)
- Enable/disable/modify extensions
- Create/modify/delete scheduled tasks

### Customization

Edit `subagent_system.md` prompt template for custom behavior.

---

## 7. Permission Modes

**Source:** https://goose-docs.ai/docs/guides/managing-tools/goose-permissions
**Source:** https://goose-docs.ai/docs/guides/managing-tools/tool-permissions

### Global Permission Modes

| Mode | Description |
|------|-------------|
| **Completely Autonomous** | No approval required (default) |
| **Manual Approval** | Confirmation before any tool use |
| **Smart Approval** | Risk-based: auto-approve low-risk, flag high-risk |
| **Chat Only** | No extensions, no file modifications |

### Per-Tool Permission Levels

| Level | Description |
|-------|-------------|
| **Always Allow** | Runs without approval |
| **Ask Before** | Requires confirmation |
| **Never Allow** | Tool cannot be used |

### Configuration
- Via CLI: `/mode auto`, `/mode smart_approve`, `/mode approve`, `/mode chat`
- Via `goose configure` → `goose settings` → `Tool Permission`
- Per-extension, per-tool granularity in Manual or Smart mode

---

## 8. Other Configuration Mechanisms

### `.goosehints`
**Source:** https://goose-docs.ai/docs/guides/context-engineering/using-goosehints

Text file providing additional project context (like CLAUDE.md for Claude Code):
```
~/.goosehints  (global)
<project>/.goosehints  (project-level)
```

### `.gooseignore`
**Source:** https://goose-docs.ai/docs/guides/context-engineering/using-gooseignore

Patterns for files goose should not access (like .gitignore):
```
<project>/.gooseignore
```

### Persistent Instructions
**Source:** https://goose-docs.ai/docs/guides/context-engineering/using-persistent-instructions

Inject text into goose's working memory every turn — different from `.goosehints` (loaded once at session start).

### Prompt Templates
**Source:** https://goose-docs.ai/docs/guides/context-engineering/prompt-templates

Customize goose's built-in prompt templates for different situations.

### Custom Slash Commands
**Source:** https://goose-docs.ai/docs/guides/context-engineering/slash-commands

Personalized shortcuts to run recipes.

### Recipes
**Source:** https://goose-docs.ai/docs/guides/recipes/recipe-reference

Reusable configurations with instructions, parameters, extensions, and settings:

```yaml
version: "1.0.0"
title: "Code Review Assistant"
description: "Automated code review with best practices"
instructions: "You are a code reviewer..."
prompt: "Review the code in this repository"
parameters:
  - key: required_param
    input_type: string
    requirement: required
    description: "A required text parameter"
extensions:
  - type: stdio
    name: codesearch
    cmd: uvx
    args: [mcp_codesearch@latest]
    timeout: 300
settings:
  goose_provider: "anthropic"
  goose_model: "claude-sonnet-4-20250514"
  temperature: 0.7
sub_recipes:
  - name: sub-task
    recipe_path: "./sub-task.yaml"
```

### Subrecipes
**Source:** https://goose-docs.ai/docs/guides/recipes/subrecipes

Recipes that call other recipes for multi-step workflows.

### Custom Distributions
**Source:** https://goose-docs.ai/docs/guides/custom-distributions

> "goose is designed to be forked and customized. You can create your own 'distro' of goose preconfigured with specific providers, extensions, and settings."

### Prompt Injection Detection
**Source:** https://goose-docs.ai/docs/guides/security/prompt-injection-detection

Pattern-based detection for prompt injection attacks.

### Sandbox
**Source:** https://goose-docs.ai/docs/guides/sandbox

Optional macOS sandbox for stricter control over what goose Desktop can access.

---

## 9. MCP Integration Details

### MCP Roots
**Source:** https://goose-docs.ai/docs/guides/mcp-roots

Lets goose share the session working directory with roots-aware MCP extensions.

### MCP Server Directory
Goose references the Pulse MCP directory: https://www.pulsemcp.com/servers

### Extension Configuration Entry (Config File)

```yaml
extensions:
  github:
    name: GitHub
    cmd: npx
    args: [-y @modelcontextprotocol/server-github]
    enabled: true
    envs: { "GITHUB_PERSONAL_ACCESS_TOKEN": "<YOUR_TOKEN>" }
    type: stdio
    timeout: 300
```

---

## 10. Source Code Architecture

**Source:** https://github.com/block/goose/tree/main/crates/goose/src

Key modules in the Rust codebase:

| Module | Purpose |
|--------|---------|
| `agents/` | Agent implementations |
| `config/` | Configuration management (providers, extensions, permissions) |
| `context_mgmt/` | Context management |
| `hooks/` | Lifecycle hooks implementation |
| `permission/` | Permission management |
| `plugins/` | Plugin system |
| `prompts/` | Prompt templates |
| `session/` | Session management |

---

## Comparison with Claude Code

| Feature | Claude Code | Goose |
|---------|-------------|-------|
| Hooks | `hooks.json` with pre/post tool events | `hooks/hooks.json` with 11 lifecycle events (observe-only) |
| Tool blocking | Hooks can block via exit code | Adversary Mode (LLM-based) blocks tool calls; hooks cannot |
| Skills | `SKILL.md` in `~/.codex/skills/` | `SKILL.md` in `~/.agents/skills/` (compatible format) |
| Config | `CLAUDE.md`, `.claude/` | `.goosehints`, `.gooseignore`, `config.yaml` |
| Subagents | Task tool | Built-in subagent spawning (autonomous) |
| MCP | Native integration | Native integration (extensions) |
| Plugins | N/A | Open Plugins format with skills + hooks |
| Recipes | N/A | YAML/JSON reusable configurations |
| Permission modes | Ask/auto-accept per tool type | 4 global modes + per-tool granularity |
| Adversary/security | N/A | LLM-based adversary reviewer |
| Prompt templates | Not user-customizable | User-customizable prompt templates |

---

## Key Findings Summary

1. **Goose HAS hooks similar to Claude Code's hooks.json** — `hooks/hooks.json` with 11 lifecycle events including `PreToolUse`, `PostToolUse`, `SessionStart`, `SessionEnd`, etc.

2. **Goose CAN intercept/block tool calls** — Via Adversary Mode (`~/.config/goose/adversary.md`), an LLM-based reviewer that returns ALLOW/BLOCK before each tool call. Fail-open design.

3. **Goose HAS session lifecycle events** — `SessionStart`, `SessionEnd`, `Stop`, `UserPromptSubmit`, plus file/shell-specific events.

4. **Goose supports skills** — Compatible with Claude Desktop's `SKILL.md` format. Skills live in `~/.agents/skills/`. Loaded via the Summon extension.

5. **Goose HAS subagent spawning** — Autonomous subagent creation with configurable turns, timeout, and extension access. Subagents cannot spawn subagents (safety constraint).

6. **MCP server integration** — First-class support. Any MCP server can be an extension. Configured via `config.yaml` or `goose configure` CLI.

7. **Plugin system** — Open Plugins format bundles skills + hooks. Discovered from `~/.agents/plugins/` and `<project>/.agents/plugins/`.

8. **Rich configuration** — `.goosehints`, `.gooseignore`, persistent instructions, prompt templates, custom slash commands, recipes, subrecipes, custom distributions.
