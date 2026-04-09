# Phase 6: Enforcement Techniques — Context

**Gathered:** 2026-04-06
**Status:** Ready for planning
**Source:** Live gap analysis against AI-Native Software Eng SDLC Playbook

<domain>
## Phase Boundary

Implement all enforcement techniques from the AI-Native SDLC Playbook that Silver Bullet does not yet have, and create a comprehensive reference document for all enforcement mechanisms (both existing and new).

Does NOT change any workflow files, skills, or SB feature logic — purely enforcement infrastructure.

</domain>

<decisions>
## Implementation Decisions

### Stop Hook
- Add a `Stop` hook to `hooks.json` that fires when Claude tries to declare task complete
- Hook checks state file for required skills; blocks with `decision: block` if incomplete
- Should use same required_deploy skill list as completion-audit.sh
- Exit format: `{"decision":"block","reason":"..."}` for Stop hooks

### UserPromptSubmit Hook
- Add a `UserPromptSubmit` hook that re-injects a compact compliance reminder on every user message
- Reminder should include: current required skills, which ones are recorded, how many are missing
- Must be very fast (< 200ms) — reads state file and emits 2-3 line summary
- Should be a new script: `hooks/prompt-reminder.sh`

### compactPrompt Override
- Add `compactPrompt` key to `templates/silver-bullet.config.json.default` (the project config template)
- Value: instructs compaction LLM to preserve silver-bullet.md rules verbatim, especially skill names, ordering constraints, and anti-skip rules
- Also add `compactPrompt` guidance to `templates/silver-bullet.md.base` session startup section as a recommendation

### Hook Self-Protection
- Extend `dev-cycle-check.sh` to block edits to SB's own hook files (files under `${CLAUDE_PLUGIN_ROOT}/hooks/`)
- Already blocks edits to plugin cache; extend same pattern to SB hooks
- Also block edits to `hooks.json` itself
- Message should explain: "Use /using-silver-bullet to reconfigure, do not edit hooks directly"

### Documentation
- Create `docs/enforcement-techniques/claude.md` — comprehensive reference for ALL enforcement mechanisms in SB
- Document: existing mechanisms (7 hooks, silver-bullet.md, CLAUDE.md.base, state file, trivial bypass, branch-scoped state) + new mechanisms being added
- Include the Tier 1–11 playbook taxonomy and where SB sits
- Include "what doesn't work" section from playbook

### Claude's Discretion
- Scoped .claude/rules/ files — low priority, skip for now
- Recursive rule echo (self-reinforcing CLAUDE.md) — skip, hooks compensate
- Plan Mode enforcement — skip, GSD phases compensate
- CLAUDE.local.md — skip, silver-bullet.md achieves separation already

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Existing Hooks
- `hooks/hooks.json` — Current hook configuration
- `hooks/session-start` — SessionStart hook (branch state, superpowers injection)
- `hooks/completion-audit.sh` — Pre+PostToolUse/Bash — two-tier commit/PR/release gate
- `hooks/dev-cycle-check.sh` — Pre+PostToolUse/Edit|Write|Bash — stage enforcer + plugin boundary

### Templates
- `templates/silver-bullet.config.json.default` — Project config template (add compactPrompt here)
- `templates/silver-bullet.md.base` — Instructions template

### Architecture
- `silver-bullet.md` — Section 1 (enforcement model) describes all 7 current enforcement layers
- `docs/Architecture-and-Design.md` — Full architecture reference

</canonical_refs>

<specifics>
## Specific Requirements

From gap analysis session (2026-04-06):

1. **Stop hook** — highest priority gap. Fires when Claude outputs final response without tool call. Must check same required_deploy list as completion-audit.sh. Block message should list missing skills.

2. **UserPromptSubmit hook** — fires before every user prompt is processed. Injects compact reminder: "Silver Bullet active. Missing skills: X, Y, Z." or "✅ All required skills complete." Must survive compaction (hook fires regardless of context state).

3. **compactPrompt** — add to config template AND mention in silver-bullet.md.base startup section. Value: "When compacting, preserve all rules and workflow steps from silver-bullet.md verbatim. Do not summarize skill names, ordering constraints, or anti-skip rules."

4. **Hook self-protection** — extend dev-cycle-check.sh §8 boundary. Currently protects `~/.claude/plugins/cache/`. Also protect `${CLAUDE_PLUGIN_ROOT}/hooks/` and `${CLAUDE_PLUGIN_ROOT}/hooks.json`. Error message: "Silver Bullet NEVER modifies its own enforcement hooks. This would disable process compliance. If you need to reconfigure, use /using-silver-bullet."

5. **Documentation** — `docs/enforcement-techniques/claude.md`. Must cover: (a) full taxonomy from playbook Tier 1–11, (b) SB's implementation status per tier, (c) all existing SB mechanisms in detail, (d) new mechanisms added in this phase, (e) "what doesn't work" section, (f) the defense-in-depth stack diagram.

</specifics>

<deferred>
## Deferred

- Scoped `.claude/rules/` files (Tier 3) — low ROI for SB's flat structure
- Recursive rule echo in CLAUDE.md (Tier 4) — hooks compensate adequately
- Plan Mode enforcement (Tier 9) — GSD planning phases compensate
- CLAUDE.local.md migration (Tier 6) — silver-bullet.md already achieves the separation
- `chmod 444` at install time — complex, could break updates; hook self-protection covers the practical case

</deferred>

---

*Phase: 06-implement-enforcement-techniques*
*Context gathered: 2026-04-06 via live gap analysis*
