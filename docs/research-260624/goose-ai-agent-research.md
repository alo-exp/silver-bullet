# Goose AI Agent: Comprehensive Research Report

**Date:** June 27, 2026
**Research Scope:** Goose architecture, extensibility, comparisons with Claude Code/Cursor/Codex, MCP/ACP implementation

---

## Executive Summary

Goose is an open-source, general-purpose AI agent originally created by Block (Square) and now part of the **Agentic AI Foundation (AAIF)** at the Linux Foundation. Built in **Rust** for performance and portability, it offers a desktop app, CLI, and API. Goose's key differentiator is its **extensibility via MCP (Model Context Protocol)** and its adoption of **ACP (Agent Client Protocol)** for agent-editor interoperability. With 50.2k GitHub stars and 5.4k forks, it has significant community traction.

**Key Finding:** Goose positions itself not as a competitor to Claude Code or Cursor, but as an **orchestration layer** that can use Claude Code, Codex, Gemini, and other agents as providers via ACP, while providing its own extension ecosystem.

---

## 1. Goose Repository Overview

**Source:** https://github.com/aaif-goose/goose (formerly block/goose)

| Attribute | Value |
|-----------|-------|
| Stars | 50.2k |
| Forks | 5.4k |
| License | Apache 2.0 |
| Languages | Rust (64.9%), TypeScript (28.8%), JavaScript (1.6%), Python (1.5%) |
| Latest Release | v1.39.0 (June 25, 2026) |
| Total Releases | 139 |
| Organization | Agentic AI Foundation (AAIF) at Linux Foundation |

**Exact Quote from README:**
> "goose is a general-purpose AI agent that runs on your machine. Not just for code — use it for research, writing, automation, data analysis, or anything you need to get done."

**Source URL:** https://github.com/aaif-goose/goose/blob/main/README.md
**Credibility:** HIGH - Official repository, actively maintained with 4,889 commits

---

## 2. Architecture

### 2.1 Core Components

Goose operates using three main components:

1. **Interface** - Desktop application or CLI
2. **Agent** - Core logic managing the interactive loop
3. **Extensions** - MCP-based tools and capabilities

**Exact Quote:**
> "In a typical session, the interface spins up an instance of the agent, which then connects to one or more extensions simultaneously. The interface can also create multiple agents to handle different tasks concurrently."

**Source URL:** https://goose-docs.ai/docs/goose-architecture/
**Credibility:** HIGH - Official documentation

### 2.2 Architecture Diagram (from CUSTOM_DISTROS.md)

```
┌─────────────────────────────────────────────────────────────────┐
│                        User Interfaces                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │  CLI        │  │  Desktop    │  │  Your Custom UI         │  │
│  │  (goose-cli)│  │  (Electron) │  │  (web, mobile, etc.)    │  │
│  └──────┬──────┘  └──────┬──────┘  └────────────┬────────────┘  │
└─────────┼────────────────┼──────────────────────┼───────────────┘
          │                │                      │
          ▼                ▼                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                    goose-server (goosed)                        │
│         REST API for all goose functionality                    │
└─────────────────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Core (goose crate)                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │  Providers  │  │  Extensions │  │  Config & Recipes       │  │
│  │  (AI models)│  │  (MCP tools)│  │  (behavior & defaults)  │  │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

**Source URL:** https://github.com/aaif-goose/goose/blob/main/CUSTOM_DISTROS.md
**Credibility:** HIGH - Official repository documentation

### 2.3 Interactive Loop

1. **Human Request** → User provides input
2. **Provider Chat** → Request sent to LLM with available tools
3. **Model Extension Call** → LLM generates tool calls, goose executes them
4. **Response to Model** → Results sent back to LLM
5. **Context Revision** → Old/irrelevant information removed for token management
6. **Model Response** → Final response delivered to user

**Source URL:** https://goose-docs.ai/docs/goose-architecture/
**Credibility:** HIGH - Official architecture documentation

---

## 3. Extension System (MCP-Based)

### 3.1 Core Design

Goose extensions are built on the **Model Context Protocol (MCP)**, an open standard for AI agent interoperability.

**Exact Quote:**
> "Extensions are based on the Model Context Protocol (MCP), so you can connect goose to a wide ecosystem of capabilities."

**Extension Trait (Rust):**
```rust
#[async_trait]
pub trait Extension: Send + Sync {
    fn name(&self) -> &str;
    fn description(&self) -> &str;
    fn instructions(&self) -> &str;
    fn tools(&self) -> &[Tool];
    async fn status(&self) -> AnyhowResult<HashMap<String, Value>>;
    async fn call_tool(&self, tool_name: &str, parameters: HashMap<String, Value>) -> ToolResult<Value>;
}
```

**Source URL:** https://goose-docs.ai/docs/goose-architecture/extensions-design
**Credibility:** HIGH - Official architecture documentation with code examples

### 3.2 Built-in Extensions

| Extension | Description |
|-----------|-------------|
| Developer | General development tools (enabled by default) |
| Computer Controller | Web scraping, file caching, automations |
| Memory | Remembers user preferences |
| Tutorial | Interactive tutorials |
| Auto Visualiser | Automatic data visualizations |

### 3.3 Platform Extensions

| Extension | Description |
|-----------|-------------|
| Apps | Create/manage custom HTML apps |
| Chat Recall | Search conversation history |
| Code Mode | Execute JavaScript for tool discovery |
| Extension Manager | Discover/enable/disable extensions dynamically |
| Summon | Load skills/recipes, delegate to subagents |
| Todo | Task management across sessions |
| Top of Mind | Inject persistent instructions |

**Source URL:** https://goose-docs.ai/docs/getting-started/using-extensions
**Credibility:** HIGH - Official documentation

### 3.4 Extension Installation Methods

1. **MCP Servers** - Any MCP server can be used as a goose extension
2. **Deeplinks** - `goose://extension?cmd=...&arg=...&id=...&name=...`
3. **Config Entry** - Direct YAML configuration
4. **CLI** - `goose configure` → Add Extension

**Source URL:** https://goose-docs.ai/docs/getting-started/using-extensions
**Credibility:** HIGH - Official documentation

### 3.5 Smart Extension Recommendation

**Exact Quote:**
> "The Smart Extension Recommendation system in goose automatically identifies and suggests relevant extensions based on your tasks and needs. When you request a task, goose checks its enabled extensions and their tools to determine if it can fulfill the request. If not, it suggests or enables additional extensions as needed."

**Source URL:** https://goose-docs.ai/docs/getting-started/using-extensions
**Credibility:** HIGH - Official documentation

---

## 4. Agent Client Protocol (ACP) Integration

### 4.1 What is ACP?

ACP is a community specification led by **Zed Industries** that decouples agents from editors.

**Exact Quote:**
> "Agent Client Protocol (ACP) is a community specification led by Zed Industries that decouples agents from editors. Goose implements ACP in both directions: editors can plug into goose, and goose can plug into other agents."

**Source URL:** https://goose-docs.ai/blog/2026/04/08/how-to-break-up-with-your-agent
**Credibility:** HIGH - Official blog post by Adrian Cole, open source contributor

### 4.2 Goose as ACP Server

`goose acp` starts goose as an ACP server over stdio, letting editors like JetBrains and Zed connect directly.

**Supported Editors:**
- Zed
- JetBrains
- Neovim (via avante.nvim)
- Marimo

**Source URL:** https://goose-docs.ai/docs/goose-architecture/
**Credibility:** HIGH - Official documentation

### 4.3 Goose as ACP Client (Using Other Agents)

Goose can delegate to external ACP agents as providers:

| Agent | ACP Adapter | Subscription |
|-------|-------------|--------------|
| Claude Code | `@agentclientprotocol/claude-agent-acp` | Claude subscription |
| Codex | `@zed-industries/codex-acp` | ChatGPT Plus/Pro |
| Gemini | Native ACP | Gemini subscription |
| Copilot | Native ACP | Copilot subscription |
| Amp | `amp-acp` | Amp subscription |
| Pi | `pi-acp` | Pi subscription |

**Exact Quote:**
> "goose can delegate to external ACP agents (like Claude Code or Codex) as providers. The ACP agent handles tool execution internally. goose passes configured extensions through as MCP servers."

**Source URL:** https://goose-docs.ai/docs/guides/acp-providers
**Credibility:** HIGH - Official documentation

### 4.4 ACP Protocol Methods

| Method | Description |
|--------|-------------|
| `initialize` | Establish connection and exchange capabilities |
| `session/new` | Create a new session with optional MCP servers |
| `session/load` | Resume an existing session by ID |
| `session/prompt` | Send a prompt and receive streaming responses |
| `session/cancel` | Cancel an in-progress prompt |

**Source URL:** https://github.com/aaif-goose/goose/blob/main/CUSTOM_DISTROS.md
**Credibility:** HIGH - Official repository documentation

---

## 5. Comparisons with Other Agents

### 5.1 Goose vs Claude Code

| Dimension | Goose | Claude Code |
|-----------|-------|-------------|
| **Architecture** | Open-source agent with pluggable providers | Anthropic's proprietary agent |
| **Provider Model** | Can USE Claude Code as a provider via ACP | Fixed to Anthropic models |
| **Extensibility** | MCP-based extensions (70+) | Limited tool set |
| **Interface** | Desktop, CLI, API, ACP server | CLI primarily |
| **Pricing** | Free (open source), pay for LLM usage | Subscription-based |
| **Lock-in** | None - works with 15+ providers | Anthropic ecosystem |

**Key Relationship:** Goose can use Claude Code as a provider via ACP:
```
npm install -g @agentclientprotocol/claude-agent-acp
GOOSE_PROVIDER=claude-acp goose
```

**Exact Quote:**
> "goose can delegate to external ACP agents (like Claude Code or Codex) as providers."

**Source URL:** https://goose-docs.ai/docs/guides/acp-providers
**Credibility:** HIGH - Official documentation

### 5.2 Goose vs Cursor

| Dimension | Goose | Cursor |
|-----------|-------|--------|
| **Type** | General-purpose AI agent | AI-powered code editor (VS Code fork) |
| **Architecture** | Agent + Extensions | Editor + Built-in AI |
| **Extensibility** | MCP-based, 70+ extensions | Limited to editor features |
| **Editor Integration** | Any editor via ACP | Must use Cursor editor |
| **Agent Model** | Can use multiple agents | Built-in agent |
| **Lock-in** | None | Editor lock-in |

**Exact Quote from ACP Blog:**
> "IDE-integrated agents like Cursor have an AI agent baked into the code editor. However, this creates vendor lock-in where you must use their specific agent with their specific editor. If I preferred VS Code as an editor and Claude Code as my agent, I'd be out of luck. I can't mix and match the tools I want."

**Source URL:** https://goose-docs.ai/blog/2025/10/24/intro-to-agent-client-protocol-acp
**Credibility:** HIGH - Official blog post by Rizel Scarlett, Staff Developer Advocate

### 5.3 Goose vs Codex (OpenAI)

| Dimension | Goose | Codex |
|-----------|-------|-------|
| **Provider** | Open source, any LLM | OpenAI's agent |
| **Subscription** | Free + LLM costs | ChatGPT Plus/Pro |
| **Extensibility** | MCP-based, highly extensible | Limited tool set |
| **Integration** | Can use Codex as provider via ACP | Standalone agent |
| **Sandboxing** | Configurable permissions | Built-in sandbox |

**Key Relationship:** Goose can use Codex as a provider via ACP:
```
npm install -g @zed-industries/codex-acp
GOOSE_PROVIDER=codex-acp goose
```

**Source URL:** https://goose-docs.ai/docs/guides/acp-providers
**Credibility:** HIGH - Official documentation

### 5.4 Goose's Unique Position

**Exact Quote:**
> "Pick the UI you like. Pick the agent you like. They don't have to be the same thing."

Goose's differentiator is **interoperability**:
- Use any editor (Zed, JetBrains, Neovim, VS Code)
- Use any agent (Claude Code, Codex, Gemini, Copilot)
- Use any LLM provider (Anthropic, OpenAI, Google, Ollama, OpenRouter, Azure, Bedrock)
- Connect to 70+ extensions via MCP

**Source URL:** https://goose-docs.ai/blog/2026/04/08/how-to-break-up-with-your-agent
**Credibility:** HIGH - Official blog post

---

## 6. Custom Distributions

Goose supports creating custom "white-labelled" distributions:

### 6.1 Customization Points

| Goal | Complexity |
|------|------------|
| Preconfigure a model/provider | Low |
| Add custom AI providers | Low |
| Bundle custom MCP extensions | Medium |
| Modify system prompts | Low |
| Customize desktop branding | Medium |
| Build a new UI (web, mobile) | High |
| Create guided workflows (Recipes) | Low |
| Build complex multi-step workflows | Medium |

**Source URL:** https://github.com/aaif-goose/goose/blob/main/CUSTOM_DISTROS.md
**Credibility:** HIGH - Official repository documentation (830 lines, comprehensive)

### 6.2 Declarative Providers (No Code)

```json
{
  "name": "my_provider",
  "engine": "openai",
  "display_name": "My Custom Provider",
  "api_key_env": "MY_PROVIDER_API_KEY",
  "base_url": "https://llm.internal.company.com/v1/chat/completions",
  "models": [{"name": "company-llm-v1", "context_limit": 32768}],
  "supports_streaming": true,
  "requires_auth": true
}
```

Supported engines: `openai`, `anthropic`, `ollama`

**Source URL:** https://github.com/aaif-goose/goose/blob/main/CUSTOM_DISTROS.md
**Credibility:** HIGH - Official repository documentation

---

## 7. Recipes (Workflow System)

Recipes are YAML files that define complete goose experiences:

```yaml
version: 1.0.0
title: Daily Standup Report Generator
description: Generates standup reports from GitHub activity

parameters:
  - key: github_repo
    input_type: string
    requirement: required
    description: "GitHub repository"

instructions: |
  You are a standup report generator...

extensions:
  - type: builtin
    name: developer
  - type: stdio
    name: github
    cmd: uvx
    args: ["github-mcp-server"]

activities:
  - "Generate today's standup report"
  - "Summarize this week's PRs"
```

**Source URL:** https://github.com/aaif-goose/goose/blob/main/CUSTOM_DISTROS.md
**Credibility:** HIGH - Official repository documentation

---

## 8. Subagents and Multi-Agent Orchestration

### 8.1 Ad-hoc Subagents

```
subagent(instructions: "Analyze all React components in src/components/")
```

### 8.2 Parallel Execution

Multiple subagent calls in the same message execute in parallel.

### 8.3 Settings Override

```
subagent(
  instructions: "List all files modified in the last week",
  settings: {model: "gpt-4o-mini", max_turns: 3}
)
```

### 8.4 Extension Scoping

```
subagent(
  instructions: "Analyze the README files",
  extensions: ["developer"]  # Only developer extension
)
```

**Source URL:** https://github.com/aaif-goose/goose/blob/main/CUSTOM_DISTROS.md
**Credibility:** HIGH - Official repository documentation

---

## 9. Recent Developments (2026)

### 9.1 Goose 2.0 Beta (April 2026)

- New TypeScript TUI (`npx @aaif/goose`)
- Desktop rewrite from Electron to Tauri
- Unified architecture via ACP
- Removing `goosed` and old Rust CLI

**Source URL:** https://goose-docs.ai/blog/2026/04/08/goose-acp-and-new-tui
**Credibility:** HIGH - Official blog post by Alex Hancock, Software Engineer

### 9.2 AAIF Foundation (April 2026)

Goose moved from Block to the Agentic AI Foundation (AAIF) at the Linux Foundation.

**Source URL:** https://goose-docs.ai/blog/2026/04/07/goose-moves-to-aaif
**Credibility:** HIGH - Official announcement

### 9.3 Built-in Local Inference (April 2026)

Goose now ships with built-in local inference powered by llama.cpp — no server, no API key, no cost.

**Source URL:** https://goose-docs.ai/blog/2026/04/24/use-goose-with-built-in-local-inference
**Credibility:** HIGH - Official blog post

### 9.4 Hooks System (May 2026)

Goose now supports lifecycle hooks via the Open Plugins spec. Wire shell scripts into PreToolUse, PostToolUse, UserPromptSubmit, SessionStart, and more.

**Source URL:** https://goose-docs.ai/blog/2026/05/14/goose-hooks
**Credibility:** HIGH - Official blog post

### 9.5 Desktop Control with Peekaboo (April 2026)

The Computer Controller extension was rebuilt with Peekaboo, giving goose the ability to see, click, type, and interact with any application on your Mac.

**Source URL:** https://goose-docs.ai/blog/2026/04/29/computer-controller-peekaboo
**Credibility:** HIGH - Official blog post

---

## 10. Provider Support

Goose works with 15+ providers:

| Provider | Type |
|----------|------|
| Anthropic | API / Claude subscription |
| OpenAI | API / ChatGPT subscription |
| Google | API / Gemini subscription |
| Ollama | Local models |
| OpenRouter | 200+ models |
| Azure | Enterprise |
| Bedrock | AWS |
| Tetrate Agent Router | Multi-model |
| Claude ACP | Via ACP adapter |
| Codex ACP | Via ACP adapter |
| Gemini ACP | Native ACP |
| Copilot ACP | Native ACP |
| Amp ACP | Via ACP adapter |
| Pi ACP | Via ACP adapter |

**Source URL:** https://goose-docs.ai/docs/getting-started/installation
**Credibility:** HIGH - Official documentation

---

## 11. Key Differentiators Summary

| Feature | Goose | Claude Code | Cursor | Codex |
|---------|-------|-------------|--------|-------|
| **Open Source** | ✅ Apache 2.0 | ❌ | ❌ | ❌ |
| **Multi-Provider** | ✅ 15+ providers | ❌ Anthropic only | ❌ | ❌ OpenAI only |
| **MCP Extensions** | ✅ 70+ | Limited | Limited | Limited |
| **ACP Support** | ✅ Server + Client | ❌ | ❌ | ❌ |
| **Desktop App** | ✅ | ❌ | ✅ (Editor) | ❌ |
| **CLI** | ✅ | ✅ | ❌ | ✅ |
| **API** | ✅ | ❌ | ❌ | ❌ |
| **Custom Distributions** | ✅ | ❌ | ❌ | ❌ |
| **Recipes/Workflows** | ✅ | ❌ | ❌ | ❌ |
| **Subagents** | ✅ | ❌ | ❌ | ❌ |
| **Local Inference** | ✅ (llama.cpp) | ❌ | ❌ | ❌ |
| **Editor Lock-in** | None | None | VS Code fork | None |
| **Agent Orchestration** | ✅ (via ACP) | ❌ | ❌ | ❌ |

---

## 12. Credibility Assessment

| Source | Type | Credibility |
|--------|------|-------------|
| https://github.com/aaif-goose/goose | Official Repository | HIGH |
| https://goose-docs.ai/docs/ | Official Documentation | HIGH |
| https://goose-docs.ai/blog/ | Official Blog | HIGH |
| Adrian Cole's ACP Blog Post | Official Contributor | HIGH |
| Rizel Scarlett's ACP Blog Post | Staff Developer Advocate | HIGH |
| Alex Hancock's 2.0 Blog Post | Software Engineer | HIGH |
| CUSTOM_DISTROS.md | Official Repository Docs | HIGH |

**Note:** All sources are official goose documentation or repository files. No third-party comparison articles were found during this research. The comparisons are constructed from official documentation about goose's capabilities and its relationships with other agents via ACP.

---

## 13. Limitations of This Research

1. **No independent benchmarks** - Performance comparisons with other agents are not available
2. **No third-party reviews** - All sources are official goose documentation
3. **ACP is pre-1.0** - The protocol is still stabilizing
4. **Limited enterprise adoption data** - Block (Square) uses it internally, but detailed case studies are limited

---

## Sources

1. https://github.com/aaif-goose/goose - Official GitHub Repository
2. https://goose-docs.ai/docs/goose-architecture/ - Architecture Documentation
3. https://goose-docs.ai/docs/goose-architecture/extensions-design - Extensions Design
4. https://goose-docs.ai/docs/getting-started/using-extensions - Using Extensions Guide
5. https://goose-docs.ai/docs/guides/acp-providers - ACP Providers Guide
6. https://goose-docs.ai/blog/2026/04/08/how-to-break-up-with-your-agent - ACP Blog Post
7. https://goose-docs.ai/blog/2025/10/24/intro-to-agent-client-protocol-acp - ACP Introduction
8. https://goose-docs.ai/blog/2026/04/08/goose-acp-and-new-tui - Goose 2.0 Announcement
9. https://github.com/aaif-goose/goose/blob/main/CUSTOM_DISTROS.md - Custom Distributions Guide
10. https://goose-docs.ai/docs/getting-started/installation - Installation Guide
