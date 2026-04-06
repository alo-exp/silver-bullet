# Phase 7: Close All Enforcement Audit Gaps — Context

**Gathered:** 2026-04-06
**Status:** Ready for planning
**Source:** ENFORCEMENT-AUDIT.md (adversarial audit of all 20 findings)

<domain>
## Phase Boundary

Close every actionable finding from the enforcement audit. The audit identified 20 gaps and 9 complete bypass paths in Silver Bullet's enforcement system. This phase implements fixes for all findings rated Easy or Medium, and the best available proxy for the one Hard finding (F-01 review loop).

Does NOT change workflow logic, skills, or documentation structure — purely enforcement infrastructure hardening.

</domain>

<decisions>
## Implementation Decisions by Finding

### Wave 1 — New hooks + easy completion-audit/CI fixes

**F-03 (CRITICAL): Forbidden Skill Invocation — new `hooks/forbidden-skill-check.sh`**
- New PreToolUse hook on `Skill` matcher
- Reads `.tool_input.skill` from stdin JSON
- Blocks if skill name (after namespace strip) matches forbidden list: `executing-plans`, `subagent-driven-development`
- Also configurable via `.silver-bullet.json` `skills.forbidden` array
- Register as PreToolUse/Skill in hooks.json
- Output: `permissionDecision: deny` with clear message

**F-06 (HIGH): SubagentStop not registered — new `hooks/subagent-stop-check.sh`**
- Lighter gate than stop-check.sh — subagents are not expected to complete the full workflow
- Checks only: (a) did the subagent attempt `gh pr create` or `gh release create`? (if so, apply full gate) (b) is CI green if subagent pushed?
- Actually: simplest correct approach — register stop-check.sh for SubagentStop too, but set a flag so it knows it's a subagent context. OR: register a dedicated subagent-stop-check.sh that only gates CI and the PR/release delivery actions
- Decision: register stop-check.sh for BOTH Stop and SubagentStop. The required_deploy check on SubagentStop is acceptable — subagents doing full-workflow work should satisfy it; subagents doing partial work will be blocked, which is correct (the outer session orchestrates resumption)

**F-16 (HIGH): stop-check.sh missing §9 quality-gate-stage check**
- Add quality-gate-stage-1..4 check to stop-check.sh, mirroring completion-audit.sh lines 283-291
- Only apply if `create-release` is in the required_deploy list OR if any quality-gate-stage marker is already present in state (indicating a release is in progress)

**F-19 (HIGH): `gh pr merge` not in Tier 2**
- Add `\bgh pr merge\b` pattern to completion-audit.sh Tier 2 classifier (alongside `gh pr create`)
- Same required skills gate applies

**F-13 (HIGH): CI not checked on `gh pr create` / `gh release create`**
- Extend ci-status-check.sh trigger pattern from `\bgit (commit|push)\b` to also match `\bgh pr (create|merge)\b` and `\bgh release create\b`

### Wave 2 — dev-cycle-check.sh extensions

**F-07 (HIGH): Plugin cache Bash commands not blocked**
- After existing `file_path` check for plugin cache (lines 48-59), add parallel `command_str` check
- Pattern: command contains plugin_cache path AND one of the write operators
- Same emit_block call and message

**F-08 (MEDIUM): Hook self-protection scripting language bypass**
- Extend the hook self-protection write-operator regex to also match: `\bpython3?\b`, `\bnode\b`, `\bruby\b`, `\bperl\b`, `\binstall\b`
- Same check: path in hooks dir AND scripting language write pattern in same command

**F-09 (MEDIUM): Mid-session branch switch warning**
- After computing `current_branch` in dev-cycle-check.sh, read `stored_branch` from branch file
- If they differ: emit warning (not a hard block — would disrupt in-progress work) via hookSpecificOutput message
- Message: "⚠️ Branch mismatch — state recorded for [stored] but current branch is [current]. Run /compact to reset."

**F-20 (EASY): Custom trivial path tamper regex generalization**
- Change Bash tamper detection pattern from `\.silver-bullet/(state|branch|trivial)` to `\.claude/[^/]+/(state|branch|trivial)` to cover custom paths within ~/.claude/

**F-04 (MEDIUM): File safety rules — destructive command warning**
- Add Bash PreToolUse check for `\brm\b`, `\bmv\b` targeting paths that are NOT in plugin cache, state dir, or tmp
- Emit informational warning (not hard block — too disruptive) requiring acknowledgment
- Only in non-trivial mode (check trivial file)

### Wave 3 — Ordering checks, stage falsification, misc fixes

**F-05 (HIGH): Quality gate stage markers falsifiable**
- Update silver-bullet.md.base §9 stage recording instructions: each stage now requires TWO writes:
  1. `echo "verification-before-completion-stage-N" >> ~/.claude/.silver-bullet/state`
  2. `echo "quality-gate-stage-N" >> ~/.claude/.silver-bullet/state`
- Add `verification-before-completion-stage-N` patterns to the dev-cycle-check.sh tamper whitelist
- Update completion-audit.sh: check that `verification-before-completion-stage-N` precedes `quality-gate-stage-N` for each N (using existing skill_line ordering logic)

**F-11 (MEDIUM): §9 stage ordering vs workflow skills**
- In completion-audit.sh, after confirming all stage markers present, verify min(stage marker lines) > max(required_deploy skill lines)
- Emit warning (not hard block) if stages precede workflow completion

**F-15 (EASY): compliance-status.sh config cache stale after update**
- Store config file mtime alongside path in cache
- On read: if mtime differs, invalidate cache and re-walk

**F-17 (EASY): session-log-init.sh mode detection fragile**
- Replace `printf '%s' "$cmd" | grep -q "autonomous"` with reading the actual mode file after the trigger fires
- `mode_check=$(cat "$SB_DIR/mode" 2>/dev/null || echo "interactive")`

**F-18 (EASY): src_pattern doesn't cover SB's own source dirs**
- Update `.silver-bullet.json` `src_pattern` from `"/src/"` to `"/hooks/|/skills/|/templates/"`

### Wave 4 — Review loop proxy (F-01, Hard)

**F-01 (CRITICAL, best available proxy): Review loop "two consecutive approvals"**
- Add `review-loop-pass-1` and `review-loop-pass-2` to the state tracking system
- silver-bullet.md.base §3a: after each clean review pass, write the marker: `echo "review-loop-pass-N" >> ~/.claude/.silver-bullet/state` (N increments: 1 for first clean pass, 2 for second consecutive clean pass)
- Add `review-loop-pass-1` and `review-loop-pass-2` to completion-audit.sh required_deploy for release delivery (optional: make configurable)
- Add both marker names to the dev-cycle-check.sh tamper whitelist
- This is an imperfect proxy (Claude could write the markers without actually doing two passes) but converts a purely documentation-only rule to a partially mechanical one with friction

### Claude's Discretion
- F-02 (Session startup mechanical enforcement) — skip, hooks can't observe Read tool calls
- F-10 (Model routing enforcement) — skip, hooks can't observe model selection
- F-12 (Compact timing bypass) — skip, SessionStart payload doesn't distinguish trigger reason
- F-14 (Namespace stripping allowlist) — skip, requires custom plugin to exploit

</decisions>

<canonical_refs>
## Canonical References

- `.planning/phases/06-implement-enforcement-techniques-from-ai-native-sdlc-playboo/ENFORCEMENT-AUDIT.md` — full audit findings
- `hooks/hooks.json` — hook registry
- `hooks/dev-cycle-check.sh` — stage enforcer + boundaries (most changes here)
- `hooks/completion-audit.sh` — commit/PR/release gate (ordering + gh pr merge + stage checks)
- `hooks/ci-status-check.sh` — CI gate (extend patterns)
- `hooks/stop-check.sh` — Stop gate (add stage check)
- `hooks/compliance-status.sh` — mtime cache fix
- `hooks/session-log-init.sh` — mode detection fix
- `templates/silver-bullet.md.base` — §9 stage recording instructions update
- `.silver-bullet.json` — src_pattern update

</canonical_refs>

<specifics>
## Key Technical Details

**F-03 forbidden-skill-check.sh input format:**
PreToolUse/Skill hook receives: `{"tool_name":"Skill","tool_input":{"skill":"superpowers:executing-plans",...}}`
Extract: `jq -r '.tool_input.skill // ""'`
Block condition: strip namespace prefix, check against forbidden list

**F-05 ordering check logic (reuse existing skill_line function):**
```bash
# Find minimum line of any quality-gate-stage-* marker
min_stage_line=99999
for n in 1 2 3 4; do
  line=$(skill_line "quality-gate-stage-$n")
  [[ "$line" -gt 0 && "$line" -lt "$min_stage_line" ]] && min_stage_line=$line
done
# Find maximum line of any required_deploy skill
max_skill_line=0
for skill in $required_skills; do
  line=$(skill_line "$skill")
  [[ "$line" -gt "$max_skill_line" ]] && max_skill_line=$line
done
# Warn if stages recorded before workflow complete
[[ "$min_stage_line" -lt "$max_skill_line" ]] && emit ordering warning
```

**F-07 plugin cache Bash check (add after file_path check, lines 48-59):**
```bash
elif [[ -n "$command_str" ]]; then
  if printf '%s' "$command_str" | grep -qE "$plugin_cache" && \
     printf '%s' "$command_str" | grep -qE '(>>|\s>[^>&=]|\btee\b|\bcp\b|\bmv\b|\brm\b|\bchmod\b|\bsed\b|\bpython3?\b|\bnode\b|\bruby\b|\bperl\b|\binstall\b)'; then
    emit_block "PLUGIN BOUNDARY VIOLATION via Bash command"
  fi
fi
```

**SubagentStop registration in hooks.json:**
```json
"SubagentStop": [{"matcher":".*","hooks":[{"type":"command","command":"\"${CLAUDE_PLUGIN_ROOT}/hooks/stop-check.sh\"","async":false}]}]
```

</specifics>

<deferred>
## Deferred

- F-02: Session startup mechanical enforcement (hooks can't observe Read tool calls)
- F-10: Model routing enforcement (hooks can't observe model selection)
- F-12: Compact timing enforcement (SessionStart payload ambiguity)
- F-14: Namespace stripping allowlist (low severity, requires custom plugin exploit)

</deferred>

---
*Phase: 07-close-enforcement-audit-gaps*
*Context gathered: 2026-04-06 from ENFORCEMENT-AUDIT.md*
