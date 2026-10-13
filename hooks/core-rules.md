# Silver Bullet — Core Enforcement Rules

> **Motto: Process is non-negotiable. Hooks enforce. Vacuous invocation is a violation.**

## Non-Negotiable Rules (Section 3)

You MUST NOT:
- Invoke helper/plugin skills on your own before Silver Bullet routing or active workflow guidance has selected them
- Skip a required skill because "it's simple" or "already covered"
- Combine steps or claim implicit coverage — each Silver Bullet skill MUST be explicitly invoked through the active runtime's SB-recognized skill invocation channel
- Claim a step is not applicable without explicit user approval
- Proceed to the next phase before completing the current phase's required skills
- Declare work complete (Stop) without the required_planning floor recorded in the state file
- Run a final-delivery command (gh pr create / gh release create / deploy) without all required_deploy skills recorded in the state file

## Enforcement Model (Section 1)

Sixteen enforcement layers are active. Hooks are invocation-based — the hooks track supported skill invocation events/receipts, not your judgment:

1. **Skill tracker** (PostToolUse/Skill or Codex `silver-bullet invoke-skill`) — records every supported skill invocation to state file
2. **Stage enforcer** (Pre+PostToolUse/Edit|Write|Bash) — HARD STOP if planning incomplete before code edits
3. **Compliance status** (PostToolUse/all) — shows workflow progress on every tool use
4. **Planning file guard** (PreToolUse/Edit|Write|MultiEdit) — blocks direct edits to SB-managed planning artifacts (ROADMAP.md, STATE.md, etc.); use the owning SB skill or workflow instead
5. **Completion audit** (Pre+PostToolUse/Bash) — blocks commits until planning done; blocks PR/deploy/release until full workflow done
6. **CI status check** (Pre+PostToolUse/Bash) — blocks all actions when CI is failing
7. **Session management** (PostToolUse/Bash + SessionStart) — timeout detection, branch-scoped state reset; SessionStart hook checks installed SB version vs GitHub latest and injects the §0.5.1 A/B update prompt when an update is available (fail-soft offline)
8. **Stop hook** (Stop/SubagentStop) — blocks task-complete declaration if the required_planning floor is incomplete (two-tier model: the full required_deploy list is enforced separately at delivery commands by the completion audit, layer 5)
9. **UserPromptSubmit recorder + reminder** (UserPromptSubmit) — records requested SB and optional extension routes and re-injects missing skills before every message
10. **Forbidden skill gate** (PreToolUse/Skill) — blocks deprecated/forbidden skill invocations
11. **ROADMAP freshness gate** (PreToolUse/Bash) — blocks git commit if SUMMARY.md staged but ROADMAP.md checkbox not ticked
12. **Redundant instructions** (project instruction file + workflow file) — same rules enforced across multiple surfaces
13. **Graphify retrieval gate** (PreToolUse/Edit|Write|Bash + PostToolUse/Bash recorder) — when the user opted in via `recommended_tools.graphify.enabled_by_user: true` and enforcement is not suspended, blocks substantive edits and delivery commands until `graphify-out/graph.json` exists and a fresh `graphify query` is recorded; native search is not an acceptable substitute. When opted out, consent pending, or enforcement suspended (install failed), Graphify is advisory only.
14. **agentmemory capture gate** (PreToolUse/Edit|Write|Bash + PostToolUse/Bash recorder) — when the user opted in via `recommended_tools.agentmemory.enabled_by_user: true` and enforcement is not suspended, blocks substantive edits until CLI, server health, MCP wiring, and `.agentmemory/` export root are ready; when Graphify is also enforced with a fresh query, agentmemory defers usage gate to Graphify retrieval (save via agentmemory, retrieve via Graphify). When opted out, consent pending, or suspended, agentmemory is advisory only.
15. **RTK install gate** (PreToolUse/Edit|Write|Bash) — when the user opted in via `recommended_tools.rtk.enabled_by_user: true` and enforcement is not suspended, blocks substantive edits and delivery commands until rtk-ai/rtk CLI (v0.4x, `rtk gain --help` succeeds) and host PreToolUse hook wiring are present. Shell compression is automatic via upstream RTK hooks once wired — SB does not rewrite Bash. When opted out, consent pending, or suspended, RTK is advisory only.
16. **Context Mode install gate** (PreToolUse/Edit|Write|Bash) — when the user opted in via `recommended_tools.context_mode.enabled_by_user: true` and enforcement is not suspended, blocks substantive edits until Node >= 22.5, context-mode CLI/plugin, MCP/hooks wiring, and the instruction fragment in project docs are present. Usage (`ctx_*` vs `Read`) is mandatory via silver-bullet.md §2g-ii; **`context-mode-read-deny.sh`** denies PreToolUse `Read|Grep` above `read_deny_bytes` (default 5120) when enforced. When opted out, consent pending, or suspended (including Windows native — use WSL), Context Mode is advisory only.

## Active Workflow (Section 2)

Read `docs/workflows/full-dev-cycle.md` before starting any non-trivial task. If a required skill cannot be invoked, STOP and notify the user — do NOT silently skip.

Silver Bullet owns the agentic loop in SB-activated projects. On every non-trivial user goal, wait for SB route/workflow guidance first, then invoke only the SB-owned or optional extension skills that guidance selects. When an SB-launched workflow step completes, return control to the active SB workflow and let it choose the next step until the user goal is achieved or user feedback is required.

Before planning, editing, debugging, reviewing, or shipping, read the relevant project knowledge and learnings that could affect the action. When Graphify is **opted in** (`recommended_tools.graphify.enabled_by_user: true`) and **not suspended**, run `graphify query "<task context with concrete files/features>" --graph graphify-out/graph.json --budget 2000` from the project root; inspect returned nodes before acting. If the graph is missing, run `graphify update . --no-cluster` first — hooks block substantive work until the index exists and a fresh query is recorded. After CLI install, follow upstream platform order: pre-index skill (`graphify install --project` on Claude, `graphify install --project --platform codex` on Codex), build index, then post-index always-on (`graphify claude install --project`, `graphify codex install --project`, or `graphify cursor install` on Cursor). When **agentmemory** is opted in and not suspended, ensure the server is running, MCP is wired, and `.agentmemory/` exists — see `docs/AGENTMEMORY.md`. When both are enabled, capture via agentmemory and retrieve via Graphify. When Graphify is **opted out**, consent is **pending**, or **enforcement is suspended** (install failed), prefer Graphify when already installed but fall back to `docs/knowledge/INDEX.md`, current `docs/knowledge/YYYY-MM.md`, current `docs/learnings/YYYY-MM.md`, and referenced docs without hook enforcement.

## Review Loop (Section 3a)

Review loop must produce two consecutive clean passes. Run the audit skill twice in sequence:

1. Invoke the audit skill (e.g. `sb:quality-gates`, `sb:review`, or the applicable review skill)
2. If issues found: fix them, then re-run
3. If clean pass: run the audit again immediately (second pass)
4. If second pass is also clean: two consecutive clean passes confirmed — proceed

**Do NOT write to state files directly.** The tamper-detection hook blocks any Bash command
that writes to the host runtime state root or adjacent files. State is recorded automatically
when skills are invoked through a supported runtime channel:

See `docs/RUNTIME-COMPATIBILITY.md` for per-host channels (including the Codex `silver-bullet invoke-skill <name>` adapter).

Reading `SKILL.md`, editing state files, or manually appending markers never counts.

The two-consecutive-pass requirement is a workflow discipline, not a state file marker.
No hook checks for `review-loop-pass-*` tokens — verification is evidence-based (audit output).

## Anti-Rationalization

These are invalid excuses:
- "I did code review while writing" — implicit coverage does not count
- "This step is not applicable" — requires explicit user approval
- "It's a simple change" — the hooks decide what's trivial, not you
- "I've already covered this" — a supported skill invocation is required, not just the work
- "I'll use grep instead of Graphify" — when Graphify is opted in and installed, hooks require a fresh `graphify query` before substantive edits
