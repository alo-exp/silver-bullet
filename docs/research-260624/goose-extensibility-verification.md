# Goose AI Agent Extensibility — Technical Claims Verification

**Date:** 2026-06-27  
**Sources:** goose-docs.ai (official docs), GitHub repo (block/goose → aaif-goose/goose), open-plugins.com, blog posts

---

## 1. Goose Hooks System

### ✅ VERIFIED: hooks/hooks.json system exists

**Source:** https://goose-docs.ai/docs/guides/context-engineering/hooks  
**Source:** https://goose-docs.ai/blog/2026/05/14/goose-hooks

> "Hooks are discovered from plugins on disk and run as shell commands when matching lifecycle events fire."
>
> "Each plugin that defines hooks must include a hooks/hooks.json file"

**Configuration format:**
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

**Plugin locations:**
- User: `~/.agents/plugins/<plugin-name>/`
- Project: `<project>/.agents/plugins/<plugin-name>/`

**Events supported (11 events):**

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

### ⚠️ Hooks are observe-only, NOT blocking

**Source:** https://goose-docs.ai/blog/2026/05/14/goose-hooks

> "Hooks that fail or time out are logged but won't crash the host tool, so your scripts can be as scrappy as you want."

Hooks run shell commands and receive JSON payloads on stdin. They **cannot block or veto tool calls** — they are purely observational/reactive. This is fundamentally different from Claude Code's hooks which can block via exit codes.

### Open Plugins Specification

**Source:** https://goose-docs.ai/docs/guides/context-engineering/hooks

> "goose follows the Open Plugins hooks specification"

The hooks system follows the open-plugins.com standard for cross-agent compatibility.

---

## 2. Goose Adversary Mode

### ✅ VERIFIED: Adversary mode exists (NOT adversary.md for hooks)

**Source:** https://goose-docs.ai/docs/guides/security/adversary-mode

> "Adversary mode adds a silent, independent agent reviewer that watches tool calls before they execute. It acts as a second pair of eyes — protecting you in case the main agent is compromised, manipulated by a prompt injection, or simply doing something that doesn't match what you asked for."

**Configuration:** `~/.config/goose/adversary.md`

**How it works:**
> "Before each tool call, the adversary reviewer checks your original task, recent messages, and the tool call details. It evaluates the tool call against your rules and returns ALLOW or BLOCK. Blocked tool calls are denied — the agent sees the rejection and cannot retry. If the reviewer fails for any reason, the tool call is allowed through (fail-open)."

**Key characteristics:**
- Uses the **same model and provider** goose is already configured with
- **No additional API keys** needed
- Rules are written in **plain language** in adversary.md
- **Fail-open** design: if reviewer fails, tool call proceeds
- **Can block tool calls** (unlike hooks)

**Example rules from docs:**
```markdown
BLOCK if the tool call:
- Exfiltrates data (posting to unknown URLs, piping secrets to external services)
- Is destructive beyond the project scope (deleting system files, wiping directories)
- Installs malware or runs obfuscated code
- Attempts to escalate privileges unnecessarily
- Downloads and executes untrusted remote scripts

ALLOW normal development operations like editing files, running tests, installing packages, using git, etc.
```

**What gets reviewed:**
> "By default, the adversary reviews shell and computercontroller__aut..." (truncated in source)

### ⚠️ Clarification: adversary.md is NOT a hooks file

The adversary.md file is a **security policy file**, not part of the hooks/hooks.json system. It's a separate mechanism specifically for tool call blocking via an LLM reviewer.

---

## 3. Goose Lifecycle Events

### ✅ VERIFIED: Full lifecycle events list

**Source:** https://goose-docs.ai/docs/guides/context-engineering/hooks  
**Source:** https://goose-docs.ai/blog/2026/05/14/goose-hooks

The supported events are:

```
SessionStart, SessionEnd, Stop
UserPromptSubmit
PreToolUse, PostToolUse, PostToolUseFailure
BeforeReadFile, AfterFileEdit
BeforeShellExecution, AfterShellExecution
```

**From the blog post:**
> "Drop a plugin into a directory on disk and goose will run your shell scripts when things happen during a session: a tool is about to fire, a tool just finished, the user submitted a prompt, the session started, the session ended."

**Payload format (example):**
```json
{
  "event": "PostToolUse",
  "session_id": "abc-123",
  "tool_name": "developer__shell",
  "tool_input": {
    "command": "rg TODO"
  },
  "working_dir": "/Users/you/project"
}
```

**Important note from docs:**
> "AfterFileEdit and AfterShellExecution only run after successful tool calls. To react to failed edits, failed shell commands, or other failed tool calls, use PostToolUseFailure."

---

## 4. Goose Skills Compatibility

### ✅ VERIFIED: Skills use SKILL.md format, compatible with Claude

**Source:** https://goose-docs.ai/docs/guides/context-engineering/using-skills

> "Claude Compatibility: goose skills are compatible with Claude Desktop and other agents that support Agent Skills."

**SKILL.md format:**
```markdown
---
name: code-review
description: Comprehensive code review checklist for pull requests
---

# Code Review Checklist
When reviewing code, check each of these areas:
...
```

**Skill locations:**
- `~/.agents/skills/` — Global skills
- `.agents/skills/` — Project-level skills
- `~/.agents/plugins/<plugin-name>/` — Plugin-provided skills

**Backward compatibility:**
> "goose also discovers skills from .goose/skills/, .claude/skills/, ~/.codex/skills/, and platform-specific config directories, but agents/skills/ is the recommended standard."

**Skills Marketplace:** https://goose-docs.ai/skills/

> "Browse community-contributed skills that teach goose how to perform specific tasks. Skills are reusable instruction sets with optional supporting files."

### ⚠️ agentskills.io NOT found as official integration

The agentskills.io site appears to be a Mintlify-hosted documentation site but didn't return meaningful goose-specific content. The official skills marketplace is at goose-docs.ai/skills/.

---

## 5. Goose ACP Protocol

### ✅ VERIFIED: ACP = Agent Client Protocol

**Source:** https://goose-docs.ai/docs/guides/acp-providers

> "goose supports Agent Client Protocol (ACP) agents as providers. ACP is a standard protocol for communicating with coding agents, and there's a growing registry of agents that implement it."

**Key details:**
> "ACP providers pass goose extensions through to the agent as MCP servers, so the agent can call your extensions directly."

**Use case:**
> "ACP providers let you use goose with your existing Claude Code or ChatGPT Plus/Pro subscriptions — no per-token API costs. They are the recommended replacement for the deprecated CLI providers."

**Limitations:**
> "No session fork or resume: You can start new sessions, but goose session resume and goose session fork are not supported"

**Source:** https://goose-docs.ai/README (from GitHub)

> "Works with 15+ providers — Anthropic, OpenAI, Google, Ollama, OpenRouter, Azure, Bedrock, and more. Use API keys or your existing Claude, ChatGPT, or Gemini subscriptions via ACP."

**Repo note:** The repo has moved from `block/goose` to `aaif-goose/goose` under the Agentic AI Foundation (AAIF) at the Linux Foundation. The `test_acp_client.py` file exists in the repo root.

---

## Summary Table

| Claim | Status | Notes |
|-------|--------|-------|
| hooks/hooks.json system | ✅ VERIFIED | 11 lifecycle events, Open Plugins spec |
| Hooks can block tool calls | ❌ NOT VERIFIED | Hooks are observe-only; fail/timeout = logged, not blocked |
| adversary.md for blocking | ✅ VERIFIED | Separate from hooks; LLM-based reviewer |
| Adversary can block tool calls | ✅ VERIFIED | Returns ALLOW/BLOCK; fail-open design |
| PreToolUse/PostToolUse events | ✅ VERIFIED | Both supported, plus 9 more events |
| Skills use SKILL.md format | ✅ VERIFIED | Compatible with Claude Desktop/Agent Skills |
| agentskills.io integration | ⚠️ NOT CONFIRMED | Official marketplace at goose-docs.ai/skills/ |
| ACP = Agent Client Protocol | ✅ VERIFIED | Standard for coding agent communication |
| ACP enables subscription reuse | ✅ VERIFIED | Claude Code, ChatGPT Plus/Pro supported |

---

## Key Architectural Insight

Goose has **two separate extensibility mechanisms** for tool call control:

1. **Hooks** (`hooks/hooks.json`) — Observe-only, run shell scripts on events, cannot block
2. **Adversary Mode** (`adversary.md`) — LLM-based reviewer that CAN block tool calls

This is architecturally different from Claude Code's hooks system where hooks themselves can block via exit codes.
