# Runtime Extensibility Comparison

Silver Bullet (SB) tier-2 enforcement depends on a **bash `hooks.json` protocol** with named lifecycle events, a **recorded skill channel** (`PostToolUse/Skill` or Codex `invoke-skill`), **Stop/SubagentStop** completion gates, **UserPromptSubmit** reminder injection, and **Task/subagent** workers for parent-only orchestration. This document compares the extensibility surfaces of **Claude Code**, **Codex**, **Cursor**, and **OMP** (oh-my-pi) against those needs. Capability tiers are defined in `docs/RUNTIME-COMPATIBILITY.md`.

**Recommended host for SB enforcement:** **Claude Code CLI** (full native hook + Skill + SubagentStop parity); **Cursor** with merged `~/.cursor/hooks.json` and Task/subagents is the closest peer; **Codex** is tier-2 with an `invoke-skill` adapter; **OMP** is tier 0–1 today without a ported TypeScript extension pack.

---

## Table A — Extensibility mechanism inventory

| Mechanism | Claude Code | Codex | Cursor | OMP |
|-----------|-------------|-------|--------|-----|
| Hook / event protocol | ✅ Bash `hooks.json` in settings + plugin (`hooks/hooks.json`) | ⚠️ Same SB manifest; Codex tool names (`exec_command`, `apply_patch`) | ⚠️ Bash `hooks.json` + `cursor-hook-bridge.sh` event map | ❌ TypeScript **extensions** (`pi.on`); separate legacy hooks API |
| SessionStart | ✅ `startup` / `resume` / `clear` / `compact` matchers | ✅ Plugin-delivered; SB uses `startup\|clear\|compact` | ✅ `sessionStart` → bridge → `SessionStart` | ⚠️ `session_start`; no `startup`/`resume`/`clear`/`compact` source discriminator[^omp-session-start] |
| PreToolUse — block | ✅ `permissionDecision: deny` or exit 2 | ✅ Same SB scripts; matchers include `exec_command` | ✅ `preToolUse` + shell bridge | ⚠️ `tool_call` → `{ block, reason }` only |
| PreToolUse — `updatedInput` | ✅ Documented | ✅ Codex hooks support input rewrite | ⚠️ Bridge passes through; SB hooks do not emit rewrites today | ❌ No input-rewrite contract on `tool_call` |
| PreToolUse — `additionalContext` | ✅ Documented | ✅ Per Codex hooks reference | ⚠️ Supported in third-party Claude mapping; SB uses stderr/JSON sparingly | ❌ Not on `tool_call` |
| PostToolUse — modify result | ✅ `updatedToolOutput` | ✅ Supported | ✅ `postToolUse` | ⚠️ `tool_result` patches `content` / `details` / `isError` only |
| PostToolUse — block / continue | ⚠️ Cannot block (tool already ran); batch hooks can stop loop | ⚠️ Same | ⚠️ Same | ❌ No `decision: block` continuation contract |
| PostToolUse / **Skill** (native skill event) | ✅ `PostToolUse` matcher `Skill` → `record-skill.sh` | ⚠️ No `Skill` tool; `silver-bullet invoke-skill` via `exec_command` + receipt | ✅ `PostToolUse` matcher `Skill` | ❌ Skills load via `skill://` / `/skill:`; **no hook-fired skill invocation event** |
| Stop (main-agent hard block / continue) | ✅ `Stop`; `decision: block` or `additionalContext`; 8-block cap | ✅ Documented main-turn `Stop` | ✅ `stop`; `followup_message` / Claude-style `decision: block` | ⚠️ `session_stop` (OMP v16+, PR #2845): main-session only; `{ continue, additionalContext }` or `{ decision: block, reason }`; 8-cap[^omp-session-stop] |
| SubagentStop | ✅ Separate event; SB `stop-check.sh` + worker semantics | ✅ Separate event | ✅ `subagentStop` via bridge | ❌ No `subagent_stop`; subagents use generic `agent_end` (notification-only) |
| UserPromptSubmit — `additionalContext` | ✅ stdout JSON / `hookSpecificOutput` | ✅ Documented | ⚠️ `beforeSubmitPrompt` → bridge; community reports of dropped `updated_input`[^cursor-prompt] | ⚠️ `input` / `before_agent_start`; not a prompt-submit context contract |
| UserPromptSubmit — block | ✅ exit 2 / `decision: block` | ✅ Documented | ⚠️ Documented; reliability varies by version | ❌ No equivalent block contract |
| Skill system (`SKILL.md`) | ✅ Host `Skill` tool + plugin skills dir | ✅ Packaged skills + **`invoke-skill` adapter** | ✅ Skill tool + plugin cache | ⚠️ `~/.omp/agent/skills/`, `.omp/skills/`; also discovers Claude/Codex skill dirs; model-triggered load, not hook-recorded |
| Custom agents / subagents | ✅ `Task` / `Subagent` / `Agent` | ✅ Subagent model via host | ✅ `Task` / `Subagent` / `Agent` (orchestrator parent mode) | ✅ `task` tool (child `omp` processes + IRC bus) |
| Parent orchestrator tool restriction | ✅ `orchestrator-directive-guard.sh` on `Edit\|Write\|Bash\|Task` | ✅ Same hooks | ✅ Same via bridge | ❌ Requires custom extension on `tool_call`; no SB pack shipped |
| Plugin / marketplace install | ✅ `alo-labs/claude-plugins` | ✅ `alo-labs/codex-plugins` | ✅ `alo-labs-cursor-marketplace` | ❌ Extension paths in `~/.omp/agent/config.yml`; no SB marketplace |
| MCP support | ✅ First-class | ✅ First-class | ✅ `beforeMCPExecution` / `afterMCPExecution` | ✅ In-process MCP tools |
| Config injection (project rules) | ✅ `CLAUDE.md`, `.claude/rules/` | ✅ `AGENTS.md` (optional) | ✅ `AGENTS.md`, `.cursor/rules/` | ⚠️ Context files + `config.yml`; no `silver-bullet.md` hook merge |
| State / session persistence hooks | ✅ `session-start` → `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/` | ✅ Same | ✅ Same | ⚠️ `session_start` + `appendEntry`; different state root (`~/.omp/agent/`) |
| Permission / approval hooks | ✅ `PermissionRequest` (allow/deny/ask) | ✅ Documented | ❌ Not supported in Cursor third-party matrix[^cursor-permission] | ⚠️ `tool_approval_requested` / `resolved` (observe only; no handler decision) |
| Compaction — PreCompact | ✅ Event exists; **SB does not register hooks** (uses `SessionStart` `compact` matcher) | ✅ Event exists; SB same | ✅ `preCompact`; **SB not wired** | ⚠️ `session_before_compact` / `session.compacting` (cancel / inject summary) |
| Compaction — PostCompact | ✅ Event exists; SB not wired | ✅ Event exists; SB not wired | ❌ No `postCompact` in Cursor hook list | ⚠️ `session_compact` (notification-only; handler return ignored) |

Symbols: ✅ Full native support · ⚠️ Partial or adapter · ❌ None / not equivalent · N/A not applicable to SB today.

---

## Table B — OMP lackings vs SB tier-2 needs

Focused gaps where OMP trails Claude/Cursor (and Codex where noted). SB has **no shipped OMP integration**; workarounds are process-level unless an OMP extension port is built.

| Gap | Claude | Codex | Cursor | OMP | SB workaround on OMP |
|-----|--------|-------|--------|-----|----------------------|
| Bash `hooks.json` + `${CLAUDE_PLUGIN_ROOT}` plugin hooks | ✅ | ✅ | ✅ (bridge) | ❌ Extensions only | Tier **0–1**: manual skill order per `docs/RUNTIME-COMPATIBILITY.md` §Tier 0–1 playbook; no mechanical gates |
| `PostToolUse/Skill` → `record-skill.sh` | ✅ | ⚠️ `invoke-skill` | ✅ | ❌ | Invoke skills via `/skill:`; **reading `SKILL.md` does not record state** — would need custom extension calling SB state writer |
| `SubagentStop` worker handoff (`orchestrator-worker-active.json` clear) | ✅ | ✅ | ✅ | ❌ | Parent cannot distinguish worker completion; orchestrator parent mode **not enforceable** |
| `UserPromptSubmit` missing-skill reminder (`prompt-reminder.sh`) | ✅ | ✅ | ✅ | ❌ | Re-paste enforcement rules each turn; no hook injection |
| PreToolUse planning / dev-cycle / orchestrator guards (10+ SB hooks) | ✅ | ✅ | ⚠️ `apply_patch` matcher gaps on some guards[^cursor-apply-patch] | ❌ | Honor skill order voluntarily; no edit/bash blocks |
| `completion-audit.sh` on `git commit` / `gh pr create` | ✅ PostToolUse Bash | ✅ `exec_command` | ✅ Shell bridge | ⚠️ `tool_call` on `bash` only | Wrap git/gh in extension policy; or run delivery only from a tier-2 host |
| `stop-check.sh` planning floor | ✅ Stop + SubagentStop | ✅ | ✅ | ⚠️ `session_stop` only (main); no SubagentStop | Use `session_stop` extension for main session; workers unaudited — **partial** |
| Native SB marketplace / `install-*.sh` | ✅ | ✅ | ✅ | ❌ | Manual clone + extension path registration |
| Shared `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/state` across hosts | ✅ | ✅ | ✅ | ❌ (`~/.omp/agent/`) | Separate state file unless extension syncs markers |
| `PermissionRequest` policy hooks | ✅ | ✅ | ❌ | ❌ (observe only) | N/A for SB today |
| Parent-only orchestrator (`orchestrator-directive-guard`) | ✅ | ✅ | ✅ | ❌ | Single-session inline work; violates SB default parent mode |

---

## Footnotes

[^omp-session-start]: OMP `session_start` fires on session load but lacks Claude/Codex `SessionStart` `source` values (`startup`, `resume`, `clear`, `compact`). SB `session-start` uses `compact` to preserve branch-scoped state across compaction; an OMP port must reconstruct that from `session_before_compact` / branch metadata. See [oh-my-pi#3073](https://github.com/can1357/oh-my-pi/issues/3073).

[^omp-session-stop]: `session_stop` landed in [oh-my-pi#2845](https://github.com/can1357/oh-my-pi/pull/2845) (merged 2026-06-17). It covers **main-session Stop** semantics only; it explicitly does **not** fire for task/subagent sessions. SB still needs a separate **SubagentStop** equivalent for orchestrator worker lifecycle.

[^cursor-prompt]: Cursor `beforeSubmitPrompt` maps to `UserPromptSubmit` via `cursor-hook-bridge.sh`, but community reports document versions where `block` or `updated_input` are unreliable; SB relies on stderr injection and exit codes from bash hooks. See [Cursor third-party hooks](https://cursor.com/docs/reference/third-party-hooks) and Cursor forum threads on `beforeSubmitPrompt`.

[^cursor-permission]: Cursor third-party hook matrix lists `PermissionRequest` as unsupported. Claude Code and Codex expose allow/deny/ask on permission dialogs; SB does not depend on this today.

[^cursor-apply-patch]: SB `hooks/hooks.json` includes `apply_patch` on planning and orchestrator guards; `hooks/cursor-hooks.json` omits `apply_patch` on several Edit/Write matchers. Codex native `apply_patch` is covered. See `.planning/reviews/SB-FLOWS-LAUNCH-AUDIT-2026-06-15.md` (F-13).

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
- [extensions.md](https://github.com/can1357/oh-my-pi/blob/main/docs/extensions.md) — `tool_call` / `tool_result`, `session_stop`, compaction events
- [Skills](https://omp.sh/docs/skills) — `SKILL.md` layout, `skill://` URLs, discovery paths
- [Issue #2834](https://github.com/can1357/oh-my-pi/issues/2834) — Stop-hook parity analysis; `session_stop` proposal
- [PR #2845](https://github.com/can1357/oh-my-pi/pull/2845) — merged `session_stop` implementation
