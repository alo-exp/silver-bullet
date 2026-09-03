# Runtime Extensibility Comparison

Silver Bullet (SB) tier-2 enforcement depends on a **bash `hooks.json` protocol** with named lifecycle events, a **recorded skill channel** (`PostToolUse/Skill` or Codex `invoke-skill`), **Stop/SubagentStop** completion gates, **UserPromptSubmit** reminder injection, and **Task/subagent** workers for parent-only orchestration. This document compares the extensibility surfaces of **Claude Code**, **Codex**, **Cursor**, **Goose**, **OpenCode**, and **OMP** (oh-my-pi) against those needs. Capability tiers are defined in `docs/RUNTIME-COMPATIBILITY.md`.

**Recommended host for SB enforcement:** **Claude Code CLI** (full native hook + Skill + SubagentStop parity); **OpenCode** with TypeScript plugin hooks, `SKILL.md` skills, and granular permissions is the closest peer; **Cursor** with merged `~/.cursor/hooks.json` and Task/subagents follows; **Goose** has strong MCP/plugin extensibility but observe-only hooks and no SubagentStop; **Codex** is tier-2 with an `invoke-skill` adapter; **OMP** is tier 0–1 today without a ported TypeScript extension pack.

---

## Table A — Extensibility mechanism inventory

| Mechanism | Claude Code | Codex | Cursor | Goose | OpenCode | OMP |
|-----------|-------------|-------|--------|-------|----------|-----|
| Hook / event protocol | ✅ Bash `hooks.json` in settings + plugin (`hooks/hooks.json`) | ⚠️ Same SB manifest; Codex tool names (`Bash`, `apply_patch`) | ⚠️ Bash `hooks.json` + `cursor-hook-bridge.sh` event map | ⚠️ Open Plugins `hooks/hooks.json`; 11 events; **observe-only** (cannot block)[^goose-hooks] | ✅ TypeScript plugins; ~28 events including `tool.execute.before`/`after`, `session.*`, `permission.*`[^opencode-plugins] | ⚠️ TypeScript **extensions** (`pi.on`); separate legacy hooks API[^omp-hooks] |
| SessionStart | ✅ `startup` / `resume` / `clear` / `compact` matchers | ✅ Plugin-delivered; SB uses `startup\|clear\|compact` | ✅ `sessionStart` → bridge → `SessionStart` | ⚠️ `SessionStart` fires; no `startup`/`resume`/`clear`/`compact` source discriminator[^goose-session] | ✅ `session.created`; no `startup`/`resume`/`clear`/`compact` source discriminator but `session.compacted` exists[^opencode-session] | ⚠️ `session_start`; no `startup`/`resume`/`clear`/`compact` source discriminator[^omp-session-start] |
| PreToolUse — block | ✅ `permissionDecision: deny` or exit 2 | ✅ Same SB scripts; matchers include `Bash`[^codex-tool-names] | ✅ `preToolUse` + shell bridge | ⚠️ Hook fires but **cannot block**; use **Adversary mode** for ALLOW/BLOCK[^goose-adversary] | ✅ `tool.execute.before` + `permission` config with `deny` glob patterns[^opencode-permissions] | ⚠️ `tool_call` → `{ block, reason }` only[^omp-hooks] |
| PreToolUse — `updatedInput` | ✅ Documented | ✅ Codex hooks support input rewrite | ⚠️ Bridge passes through; SB hooks do not emit rewrites today | ❌ No input-rewrite on hooks; Adversary mode is block/allow only | ⚠️ Plugin can modify tool args via `tool.execute.before` handler[^opencode-plugins] | ❌ No input-rewrite contract on `tool_call`[^omp-hooks] |
| PreToolUse — `additionalContext` | ✅ Documented | ✅ Per Codex hooks reference | ⚠️ Supported in third-party Claude mapping; SB uses stderr/JSON sparingly | ❌ Not on hooks or Adversary mode | ⚠️ Plugin can inject context via event handler return[^opencode-plugins] | ❌ Not on `tool_call`[^omp-hooks] |
| PostToolUse — modify result | ✅ `updatedToolOutput` | ✅ Supported | ✅ `postToolUse` | ⚠️ `PostToolUse` fires observe-only; cannot modify result | ⚠️ `tool.execute.after` fires but documented as observe-only[^opencode-plugins] | ⚠️ `tool_result` patches `content` / `details` / `isError` only[^omp-hooks] |
| PostToolUse — block / continue | ⚠️ Cannot block (tool already ran); batch hooks can stop loop | ⚠️ Same | ⚠️ Same | ❌ Observe-only; no block/continue contract | ⚠️ `tool.execute.after` fires; no documented block/continue contract | ❌ No `decision: block` continuation contract on `tool_result`[^omp-hooks] |
| PostToolUse / **Skill** (native skill event) | ✅ `PostToolUse` matcher `Skill` → `record-skill.sh` | ✅ Native `Skill` tool + SB `invoke-skill` adapter[^codex-skills] | ✅ `PostToolUse` matcher `Skill` | ⚠️ `PostToolUse` fires but no `Skill` tool matcher; skills loaded via Summon extension[^goose-skills] | ⚠️ `skill` tool exists; `tool.execute.after` can match skill invocations[^opencode-skills] | ❌ Skills load via `skill://` / `/skill:`; **no hook-fired skill invocation event** |
| Stop (main-agent hard block / continue) | ✅ `Stop`; `decision: block` or `additionalContext`; 8-block cap | ✅ Documented main-turn `Stop` | ✅ `stop`; `followup_message` / Claude-style `decision: block` | ⚠️ `Stop` event fires; no documented `decision: block` or `additionalContext` contract[^goose-stop] | ⚠️ `session.idle` / `session.status` events; no documented `decision: block` contract[^opencode-stop] | ⚠️ `session_stop`; `{ continue, additionalContext }` or `{ decision: block, reason }`; 8-cap[^omp-session-stop] |
| SubagentStop | ✅ Separate event; SB `stop-check.sh` + worker semantics | ✅ Separate event | ✅ `subagentStop` via bridge | ❌ No `SubagentStop` event; subagent completion is lifecycle-internal[^goose-subagents] | ⚠️ No dedicated `SubagentStop`; `session.deleted` / `session.status` fire for child sessions[^opencode-subagents] | ❌ No `subagent_stop`; `session_stop` does not fire for subagent sessions[^omp-hooks] |
| UserPromptSubmit — `additionalContext` | ✅ stdout JSON / `hookSpecificOutput` | ✅ Documented | ⚠️ `beforeSubmitPrompt` → bridge; community reports of dropped `updated_input`[^cursor-prompt] | ⚠️ `UserPromptSubmit` fires observe-only; no `additionalContext` injection contract | ⚠️ `tui.prompt.append` event; can modify prompt content[^opencode-plugins] | ⚠️ `before_agent_start`; `{ message, systemPrompt }` return; not a prompt-submit context contract[^omp-hooks] |
| UserPromptSubmit — block | ✅ exit 2 / `decision: block` | ✅ Documented | ⚠️ Documented; reliability varies by version | ❌ Observe-only; no block contract | ⚠️ `permission.asked` / `permission.replied` events; no prompt-block contract | ❌ No block contract on `before_agent_start`[^omp-hooks] |
| Skill system (`SKILL.md`) | ✅ Host `Skill` tool + plugin skills dir | ✅ Native `Skill` tool + SB `invoke-skill` adapter[^codex-skills] | ✅ Skill tool + plugin cache | ⚠️ `SKILL.md` format; discovers `~/.agents/skills/`, `.agents/skills/`, plugins; compatible with Claude Desktop[^goose-skills] | ✅ `SKILL.md` format; discovers `.opencode/skills/`, `.claude/skills/`, `.agents/skills/` + global paths; native `skill` tool[^opencode-skills] | ⚠️ Skill dirs discovered but model-triggered load, not hook-recorded[^omp-hooks] |
| Custom agents / subagents | ✅ `Task` / `Subagent` / `Agent` | ✅ Subagent model via host | ✅ `Task` / `Subagent` / `Agent` (orchestrator parent mode) | ✅ Autonomous subagent spawning; parallel/sequential; configurable turns/timeouts[^goose-subagents] | ✅ Primary + subagent architecture; built-in General/Explore/Scout; custom via JSON/Markdown; `task` permission control[^opencode-subagents] | ✅ `task` tool (child `omp` processes + IRC bus) |
| Parent orchestrator tool restriction | ✅ `orchestrator-directive-guard.sh` on `Edit|Write|Bash|Task` | ✅ Same hooks | ✅ Same via bridge | ❌ No hook-based tool restriction; Adversary mode could emulate per-call[^goose-adversary] | ✅ `permission` config with `deny` patterns on `edit`/`bash`/`task`[^opencode-permissions] | ❌ Requires custom extension on `tool_call`; no SB pack shipped |
| Plugin / marketplace install | ✅ `anthropics/claude-plugins-official`[^claude-marketplace] | ✅ `alo-labs/agent-plugins` (`alo-labs-codex`) | ✅ `alo-labs/agent-plugins` (`alo-labs-cursor`) | ⚠️ Open Plugins format; `~/.agents/plugins/`; no SB marketplace | ⚠️ `.opencode/plugins/` + `~/.config/opencode/plugins/`; no SB marketplace | ❌ Extension paths in `~/.omp/agent/config.yml`; no SB marketplace[^omp-hooks] |
| MCP support | ✅ First-class | ✅ First-class | ✅ `beforeMCPExecution` / `afterMCPExecution` | ✅ First-class; any MCP server is an extension; MCP Roots for workspace sharing[^goose-mcp] | ✅ First-class; local (stdio) + remote (URL); OAuth support; org-level defaults via `.well-known/opencode`[^opencode-mcp] | ✅ In-process MCP tools |
| Config injection (project rules) | ✅ `CLAUDE.md`, `.claude/rules/` | ✅ `AGENTS.md` (optional) | ✅ `AGENTS.md`, `.cursor/rules/` | ⚠️ `config.yaml` + recipe YAML; no `silver-bullet.md` hook merge[^goose-config] | ✅ `AGENTS.md`, `CLAUDE.md`, custom instruction paths + globs, remote URLs[^opencode-config] | ⚠️ Context files + `config.yml`; no `silver-bullet.md` hook merge[^omp-config] |
| State / session persistence hooks | ✅ `session-start` → `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/` | ✅ Same | ✅ Same | ⚠️ `SessionStart` fires; state root is `~/.config/goose/`; different path | ✅ `session.created` + `session.compacted` plugin hooks; state in `~/.config/opencode/`[^opencode-session] | ⚠️ `session_start` + `appendEntry`; different state root (`~/.omp/agent/`)[^omp-hooks] |
| Permission / approval hooks | ✅ `PermissionRequest` (allow/deny/ask) | ✅ Documented | ❌ Not supported in Cursor third-party matrix[^cursor-permission] | ⚠️ 4 permission modes + per-tool granularity; no hook-level decision contract[^goose-permissions] | ✅ `permission.asked` / `permission.replied` events + per-tool `allow`/`ask`/`deny` with glob patterns[^opencode-permissions] | ⚠️ `tool_approval_requested` / `resolved` (observe only; no handler decision)[^omp-hooks] |
| Compaction — PreCompact | ✅ Event exists; **SB does not register hooks** (uses `SessionStart` `compact` matcher) | ✅ Event exists; SB same | ✅ `preCompact`; **SB not wired** | ❌ No PreCompact event in hooks spec[^goose-compaction] | ✅ `experimental.session.compacting`; inject context or replace prompt[^opencode-compaction] | ⚠️ `session_before_compact` / `session.compacting` (cancel / inject summary)[^omp-hooks] |
| Compaction — PostCompact | ✅ Event exists; SB not wired | ✅ Event exists; SB not wired | ❌ No `postCompact` in Cursor hook list | ❌ No PostCompact event in hooks spec | ✅ `session.compacted` event fires after compaction[^opencode-session] | ⚠️ `session_compact` (notification-only; handler return ignored)[^omp-hooks] |

Symbols: ✅ Full native support · ⚠️ Partial or adapter · ❌ None / not equivalent · N/A not applicable to SB today.

---

## Table B — Goose, OpenCode & OMP lackings vs SB tier-2 needs

Focused gaps where Goose, OpenCode, and OMP trail Claude/Cursor (and Codex where noted). SB has **no shipped Goose, OpenCode, or OMP integration**; workarounds are process-level unless extension ports are built.

| Gap | Claude | Codex | Cursor | Goose | OpenCode | OMP | SB workaround on Goose |
|-----|--------|-------|--------|-------|----------|-----|------------------------|
| Bash `hooks.json` + `${CLAUDE_PLUGIN_ROOT}` plugin hooks | ✅ | ✅ | ✅ (bridge) | ⚠️ Open Plugins `hooks/hooks.json`; observe-only, cannot block | ✅ TS plugins with ~28 events; `tool.execute.before`/`after` | ⚠️ Extensions with `tool_call`/`tool_result`[^omp-hooks] | Tier **1–2**: hooks fire for observability; Adversary mode for blocking; no `updatedInput`/`additionalContext` |
| `PostToolUse/Skill` → `record-skill.sh` | ✅ | ✅ Native Skill tool + SB adapter | ✅ | ⚠️ `PostToolUse` fires but no `Skill` tool matcher | ⚠️ `tool.execute.after` can match skill invocations; no native `Skill` event | ❌ | Invoke skills via Summon extension; **reading `SKILL.md` does not record state** — would need custom hook script calling SB state writer |
| `SubagentStop` worker handoff (`orchestrator-worker-active.json` clear) | ✅ | ✅ | ✅ | ❌ No `SubagentStop` event | ⚠️ `session.deleted`/`session.status` fire for child sessions | ❌ `session_stop` does not fire for subagents[^omp-hooks] | Parent cannot distinguish worker completion; orchestrator parent mode **not enforceable** |
| `UserPromptSubmit` missing-skill reminder (`prompt-reminder.sh`) | ✅ | ✅ | ✅ | ⚠️ Observe-only; no injection contract | ⚠️ `tui.prompt.append` can modify prompt | ⚠️ `before_agent_start`; no prompt-submit context contract[^omp-hooks] | Re-paste enforcement rules each turn; no hook injection |
| PreToolUse planning / dev-cycle / orchestrator guards (10+ SB hooks) | ✅ | ✅ | ⚠️ `apply_patch` matcher gaps | ⚠️ Hooks observe-only; Adversary mode blocks but LLM-based, not deterministic | ✅ `tool.execute.before` + `permission` deny patterns | ⚠️ `tool_call` can block but no input-rewrite[^omp-hooks] | Adversary mode for security blocks; deterministic planning guards **not enforceable** |
| `completion-audit.sh` on `git commit` / `gh pr create` | ✅ PostToolUse Bash | ✅ `Bash` matcher | ✅ Shell bridge | ⚠️ `PostToolUse` observe-only on shell calls | ⚠️ `tool.execute.after` on shell calls | ⚠️ `tool_result` on shell calls[^omp-hooks] | Wrap git/gh in extension policy; or run delivery only from a tier-2 host |
| `stop-check.sh` planning floor | ✅ Stop + SubagentStop | ✅ | ✅ | ⚠️ `Stop` fires; no `decision: block` contract | ⚠️ `session.idle`/`session.status`; no `decision: block` contract | ⚠️ `session_stop` (main only); no SubagentStop[^omp-hooks] | Use `Stop` hook for main session observation; workers unaudited — **partial** |
| Native SB marketplace / `install-*.sh` | ✅ | ✅ | ✅ | ⚠️ Open Plugins; no SB marketplace | ⚠️ `.opencode/plugins/`; no SB marketplace | ❌ | Manual clone + plugin path registration |
| Shared `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/state` across hosts | ✅ | ✅ | ✅ | ⚠️ `~/.config/goose/` state root | ⚠️ `~/.config/opencode/` state root | ❌ (`~/.omp/agent/`) | Separate state file unless hook script syncs markers |
| `PermissionRequest` policy hooks | ✅ | ✅ | ❌ | ❌ (permission modes only) | ✅ `permission.asked`/`permission.replied` events | ⚠️ `tool_approval_requested` (observe only)[^omp-hooks] | N/A for SB today |
| Parent-only orchestrator (`orchestrator-directive-guard`) | ✅ | ✅ | ✅ | ❌ No hook-based tool restriction | ✅ `permission` config with `deny` patterns on `edit`/`bash`/`task` | ❌ | Single-session inline work; violates SB default parent mode |

---

## Footnotes

[^omp-session-start]: OMP `session_start` fires on session load but lacks Claude/Codex `SessionStart` `source` values (`startup`, `resume`, `clear`, `compact`). SB `session-start` uses `compact` to preserve branch-scoped state across compaction; an OMP port must reconstruct that from `session_before_compact` / branch metadata. See [oh-my-pi extensions docs](https://github.com/can1357/oh-my-pi/blob/main/docs/extensions.md).

[^omp-session-stop]: OMP `session_stop` has block/continue semantics: `{ continue: true, additionalContext }` or `{ decision: "block", reason }`, capped at 8 consecutive continuations. However, `session_stop` **does not fire for task/subagent sessions** — it is main-session only. `agent_end` fires for subagents but is notification-only (handler return ignored). SB needs `session_stop` for main Stop + a separate mechanism for SubagentStop. See [oh-my-pi extensions docs](https://github.com/can1357/oh-my-pi/blob/main/docs/extensions.md).

[^cursor-prompt]: Cursor `beforeSubmitPrompt` maps to `UserPromptSubmit` via `cursor-hook-bridge.sh`, but community reports document versions where `block` or `updated_input` are unreliable; SB relies on stderr injection and exit codes from bash hooks. See [Cursor third-party hooks](https://cursor.com/docs/reference/third-party-hooks) and Cursor forum threads on `beforeSubmitPrompt`.

[^cursor-permission]: Cursor third-party hook matrix lists `PermissionRequest` as unsupported. Claude Code and Codex expose allow/deny/ask on permission dialogs; SB does not depend on this today.

[^cursor-apply-patch]: SB `hooks/hooks.json` includes `apply_patch` on planning and orchestrator guards; `hooks/cursor-hooks.json` omits `apply_patch` on several Edit/Write matchers. Codex native `apply_patch` is covered. See `.planning/reviews/SB-FLOWS-LAUNCH-AUDIT-2026-06-15.md` (F-13).

[^goose-hooks]: Goose hooks follow the [Open Plugins hooks spec](https://open-plugins.com/agent-builders/components/hooks) with 11 events (`SessionStart`, `SessionEnd`, `Stop`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `BeforeReadFile`, `AfterFileEdit`, `BeforeShellExecution`, `AfterShellExecution`). Hooks are **fire-and-forget observe-only** — they cannot block tool calls, rewrite input, or inject context. Failed/timed-out hooks are logged but do not crash the host. See [goose hooks blog](https://goose-docs.ai/blog/2026/05/14/goose-hooks).

[^goose-session]: Goose `SessionStart` fires at session load but lacks Claude/Codex `source` discriminators (`startup`, `resume`, `clear`, `compact`). SB `session-start` uses `compact` to preserve branch-scoped state; a Goose port would need to reconstruct compaction context from session metadata.

[^goose-adversary]: Goose **Adversary mode** (`~/.config/goose/adversary.md`) provides deterministic pre-tool-call ALLOW/BLOCK via an LLM reviewer. It evaluates tool calls against plain-language rules and returns ALLOW or BLOCK; blocked calls are denied and the agent cannot retry. Fail-open design — if the reviewer fails, the call proceeds. This is separate from the hooks system. See [Adversary mode docs](https://goose-docs.ai/docs/guides/security/adversary-mode).

[^goose-skills]: Goose discovers `SKILL.md` files from `~/.agents/skills/`, `.agents/skills/`, and installed plugins. Format is compatible with Claude Desktop's `SKILL.md` (YAML frontmatter with `name`, `description`). Backward compatible with `.claude/skills/` and `.goose/skills/`. Skills are loaded via the Summon extension (v1.25.0+), not via a hook-fired `PostToolUse/Skill` event. See [Goose skills docs](https://goose-docs.ai/docs/guides/context-engineering/using-skills).

[^goose-subagents]: Goose supports autonomous subagent spawning in Autonomous permission mode. Subagents can run sequentially or in parallel with configurable max turns (default 25), timeout (default 5 min), and extension access. **Subagents cannot spawn sub-subagents** (safety constraint). There is no `SubagentStop` lifecycle event — subagent completion is internal to the agent loop. See [Goose subagents docs](https://goose-docs.ai/docs/guides/context-engineering/subagents).

[^goose-stop]: Goose `Stop` event fires at session end but no documented `decision: block` or `additionalContext` contract exists. Unlike Claude Code's Stop hook which can inject additional context or block completion, Goose's Stop is observe-only.

[^goose-mcp]: Goose treats any MCP server as a native extension. Configured in `~/.config/goose/config.yaml` with `type: stdio`, `cmd`, `args`, `envs`, `timeout`. Supports MCP Roots for workspace sharing. 70+ documented integrations. See [Goose extensions docs](https://goose-docs.ai/docs/getting-started/using-extensions).

[^goose-config]: Goose uses `~/.config/goose/config.yaml` for configuration and supports recipe YAML files for workflow definitions. No equivalent to `CLAUDE.md` or `AGENTS.md` for project-level rule injection via a single markdown file. See [Goose config docs](https://goose-docs.ai/docs/guides/config-file).

[^goose-permissions]: Goose has 4 permission modes (Completely Autonomous, Manual Approval, Smart Approval, Chat Only) with per-tool granularity (`Always Allow`, `Ask Before`, `Never Allow`). No hook-level permission decision contract — mode changes are session-level, not per-call hook callbacks. See [Goose permissions docs](https://goose-docs.ai/docs/guides/managing-tools/goose-permissions).

[^goose-compaction]: Goose does not expose PreCompact or PostCompact events in its hooks spec. The Open Plugins hooks spec defines `SessionStart`, `SessionEnd`, `Stop`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `BeforeReadFile`, `AfterFileEdit`, `BeforeShellExecution`, `AfterShellExecution` — no compaction events. See [Open Plugins hooks spec](https://open-plugins.com/agent-builders/components/hooks).

[^opencode-plugins]: OpenCode plugins are TypeScript/JS modules exporting event handler functions. ~28 events across categories: Tool (`tool.execute.before`, `tool.execute.after`), Session (8 events), Permission (`permission.asked`, `permission.replied`), File (`file.edited`, `file.watcher.updated`), Shell (`shell.env`), Message (4 events), Todo (`todo.updated`), TUI (3 events), LSP (2 events), and experimental compaction hooks. Plugins receive a context object and return a hooks object. See [OpenCode plugins docs](https://opencode.ai/docs/plugins).

[^opencode-session]: OpenCode session events: `session.created`, `session.compacted`, `session.deleted`, `session.diff`, `session.error`, `session.idle`, `session.status`, `session.updated`. No `startup`/`resume`/`clear`/`compact` source discriminator like Claude Code, but `session.compacted` fires after compaction and `session.created` fires on new sessions. See [OpenCode plugins docs](https://opencode.ai/docs/plugins).

[^opencode-permissions]: OpenCode has granular per-tool permission control via `opencode.json` config. Each permission key resolves to `"allow"`, `"ask"`, or `"deny"`. Supports glob patterns: `"git commit *": "deny"`. 15 permission keys: `read`, `edit`, `glob`, `grep`, `list`, `bash`, `task`, `external_directory`, `todowrite`, `webfetch`, `websearch`, `lsp`, `skill`, `question`, `doom_loop`. Permission events: `permission.asked`, `permission.replied`. See [OpenCode permissions docs](https://opencode.ai/docs/permissions).

[^opencode-skills]: OpenCode discovers `SKILL.md` files from `.opencode/skills/`, `~/.config/opencode/skills/`, `.claude/skills/`, `~/.codex/skills/`, `.agents/skills/`, `~/.agents/skills/`. Same YAML frontmatter format as Claude Code (`name`, `description` required). Native `skill` tool loads skills on demand. Agents see available skills as `<available_skills>` XML in tool description. See [OpenCode skills docs](https://opencode.ai/docs/skills).

[^opencode-subagents]: OpenCode has primary agents and subagents. Built-in subagents: General, Explore, Scout. Custom subagents via JSON or Markdown definitions. Subagents invoked via `task` tool or @ mention. `permission.task` controls which subagents an agent can invoke using glob patterns. Child sessions created by subagents; navigation via `session_child_first` keybinding. See [OpenCode agents docs](https://opencode.ai/docs/agents).

[^opencode-stop]: OpenCode does not have a dedicated `Stop` event with `decision: block` contract. `session.idle` and `session.status` events fire during session lifecycle but no documented mechanism to block completion or inject additional context at stop time. See [OpenCode plugins docs](https://opencode.ai/docs/plugins).

[^opencode-mcp]: OpenCode supports local (stdio) and remote (URL-based) MCP servers. Remote servers support OAuth with Dynamic Client Registration (RFC 7591). Organizations can provide default MCP servers via `.well-known/opencode` endpoint. Local config overrides remote defaults. See [OpenCode MCP docs](https://opencode.ai/docs/mcp-servers).

[^opencode-config]: OpenCode config injection: `AGENTS.md` (primary), `CLAUDE.md` (compatible), custom instruction paths via `opencode.json` `instructions` array with glob patterns and remote URLs. Precedence: local files → global `~/.config/opencode/AGENTS.md` → `~/.codex/CLAUDE.md`. Remote instructions fetched with 5s timeout. See [OpenCode rules docs](https://opencode.ai/docs/rules).

[^opencode-compaction]: OpenCode has `experimental.session.compacting` hook that fires before LLM generates continuation summary. Can inject additional context via `output.context.push()` or replace the entire compaction prompt via `output.prompt`. `session.compacted` fires after compaction completes. See [OpenCode plugins docs](https://opencode.ai/docs/plugins).

[^omp-hooks]: OMP uses its own API names. Key mappings vs Claude Code: `session_start` (SessionStart), `session_stop` (Stop — has block/continue/8-cap), `tool_call` (PreToolUse), `tool_result` (PostToolUse), `tool_approval_requested` (PermissionRequest), `session_before_compact` (PreCompact), `session_compact` (PostCompact), `before_agent_start` (UserPromptSubmit). Config is `config.yml` (primary) at `~/.omp/agent/config.yml`. OMP has NO input-rewrite on `tool_call`, NO SubagentStop event (`session_stop` does not fire for subagents), and NO skill invocation event. See [oh-my-pi extensions docs](https://github.com/can1357/oh-my-pi/blob/main/docs/extensions.md).

[^omp-config]: OMP config is `config.yml` at `~/.omp/agent/config.yml` (primary) or `settings.json` (legacy). Context files and `config.yml` are used for rule injection; no `silver-bullet.md` hook merge. See [oh-my-pi docs](https://omp.sh/docs).

[^codex-tool-names]: Codex canonical tool names are `Bash` (shell) and `apply_patch` (file edits). SB's `hooks.json` uses `exec_command` in matchers, which is an SB-specific alias translated by `codex-hook-adapter.sh`, not a Codex native name. See [Codex hooks docs](https://developers.openai.com/codex/hooks).

[^codex-skills]: Codex has a **native built-in Skill tool** documented at [Codex skills](https://developers.openai.com/codex/skills). Skills use `SKILL.md` files with progressive disclosure. SB's `invoke-skill` adapter is supplementary glue for SB-specific state recording, not a replacement for a missing feature.

[^claude-marketplace]: Claude Code's official plugin marketplaces are `anthropics/claude-plugins-official` and `anthropics/claude-plugins-community`. SB uses `alo-labs/agent-plugins` (`alo-labs` marketplace ID). See [Claude Code plugins docs](https://docs.anthropic.com/en/docs/claude-code/plugins).

---

## Sources

### Silver Bullet (this repo)

- `docs/RUNTIME-COMPATIBILITY.md` — capability tiers, hook manifests, skill channels
- `docs/ORCHESTRATOR.md` — parent-only Task workers, SubagentStop semantics
- `docs/ENFORCEMENT.md` — 12 enforcement layers and two-tier Stop vs delivery
- `hooks/hooks.json` — canonical SB hook registration (SessionStart, PreToolUse, PostToolUse, Stop, SubagentStop, UserPromptSubmit)
- `hooks/cursor-hooks.json`, `hooks/cursor-hook-bridge.sh` — Cursor event mapping
- `plugins/silver-bullet/.codex-plugin/plugin.json` — Codex plugin hooks path
- `scripts/install-claude.sh`, `scripts/install-cursor.sh` — marketplace install surfaces
- `README.md` — Codex `invoke-skill` adapter description

### External — Claude Code

- [Claude Code hooks reference](https://docs.anthropic.com/en/docs/claude-code/hooks) — event catalog, PreToolUse/PostToolUse decision control, PreCompact/PostCompact, SubagentStop

### External — Cursor

- [Cursor hooks](https://cursor.com/docs/hooks) — `sessionStart`, `preToolUse`, `postToolUse`, `subagentStop`, `beforeSubmitPrompt`, `preCompact`, `stop`
- [Cursor third-party hooks](https://cursor.com/docs/reference/third-party-hooks) — Claude→Cursor name mapping, unsupported events

### External — Codex

- Codex plugin hooks via SB package (`plugins/silver-bullet/.codex-plugin/plugin.json` → `./hooks/hooks.json`)
- Parity discussion: [oh-my-pi#2834](https://github.com/can1357/oh-my-pi/issues/2834) (cexll comment on Codex/Claude turn-scoped events)

### External — OMP (oh-my-pi)

- [omp.sh docs](https://omp.sh/docs) — architecture, `task` subagents, session JSONL
- [extensions.md](https://github.com/can1357/oh-my-pi/blob/main/docs/extensions.md) — `tool_call` / `tool_result`, `session_stop`, `before_agent_start`, compaction events
- [Skills](https://omp.sh/docs/skills) — `SKILL.md` layout, `skill://` URLs, discovery paths
- [Issue #2834](https://github.com/can1357/oh-my-pi/issues/2834) — Stop-hook parity analysis; `agent_end` proposal

### External — Goose

- [Goose docs](https://goose-docs.ai/) — architecture, extensions, recipes, subagents
- [Goose hooks blog](https://goose-docs.ai/blog/2026/05/14/goose-hooks) — 11 lifecycle events, Open Plugins spec
- [Adversary mode](https://goose-docs.ai/docs/guides/security/adversary-mode) — LLM-based pre-tool-call ALLOW/BLOCK
- [Skills](https://goose-docs.ai/docs/guides/context-engineering/using-skills) — `SKILL.md` format, discovery paths, Claude Desktop compatibility
- [Plugins](https://goose-docs.ai/docs/guides/context-engineering/plugins) — Open Plugins format, plugin discovery
- [Subagents](https://goose-docs.ai/docs/guides/context-engineering/subagents) — autonomous spawning, parallel/sequential
- [Permissions](https://goose-docs.ai/docs/guides/managing-tools/goose-permissions) — 4 modes, per-tool granularity
- [Extensions](https://goose-docs.ai/docs/getting-started/using-extensions) — MCP-first architecture, 70+ integrations
- [Open Plugins hooks spec](https://open-plugins.com/agent-builders/components/hooks) — event catalog, matcher context
- [GitHub — aaif-goose/goose](https://github.com/aaif-goose/goose) — source code, moved from block/goose to Agentic AI Foundation

### External — OpenCode

- [OpenCode docs](https://opencode.ai/docs) — architecture, plugins, skills, agents, MCP, permissions
- [Plugins](https://opencode.ai/docs/plugins) — TypeScript plugin system, ~28 events, tool/session/permission hooks
- [Skills](https://opencode.ai/docs/skills) — `SKILL.md` format, multi-path discovery, Claude/Codex compatible
- [Agents](https://opencode.ai/docs/agents) — primary + subagent architecture, built-in General/Explore/Scout
- [MCP servers](https://opencode.ai/docs/mcp-servers) — local + remote MCP, OAuth, org-level defaults
- [Permissions](https://opencode.ai/docs/permissions) — per-tool `allow`/`ask`/`deny` with glob patterns
- [Rules](https://opencode.ai/docs/rules) — `AGENTS.md`, `CLAUDE.md`, custom instruction paths, remote URLs
- [Config](https://opencode.ai/docs/config) — config hierarchy, remote → global → project precedence
- [Commands](https://opencode.ai/docs/commands) — TUI `/command` shortcuts
- [Custom tools](https://opencode.ai/docs/custom-tools) — TS/JS tool definitions with Zod schema
- [GitHub — anomalyco/opencode](https://github.com/anomalyco/opencode) — source code
