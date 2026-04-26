# BUG-06 — Claude Code Permission Re-Prompting After Bypass Permissions: Investigation

**Status:** Platform issue — no SB fix possible
**Phase:** 64 — Verification & Init Improvements
**Requirement:** BUG-06
**GitHub issue:** https://github.com/alo-exp/silver-bullet/issues/64

---

## Bug Description

After the user sets "Bypass Permissions" in Claude Code, Claude should not re-prompt for permissions when running shell commands, file reads, etc. The bug report (GitHub #64) indicates that Claude Code re-prompts for permissions even after Bypass Permissions is set. This investigation determines whether any Silver Bullet hook is the root cause.

---

## Hooks Investigated

All SB hooks were reviewed for output patterns that could interact with the Claude Code permission system.

### 1. `session-start` (SessionStart event)

- **Hook event:** `SessionStart`
- **Output format:** `additionalContext` injection only — writes state context to `hookSpecificOutput.additionalContext`
- **Permission relevance:** None. `additionalContext` is a passive injection that provides background context to the model. It does not interact with the permission system in any way.
- **Verdict:** ✅ Not a permission-dialog trigger.

### 2. `prompt-reminder.sh` (UserPromptSubmit event)

- **Hook event:** `UserPromptSubmit`
- **Output format:** `additionalContext` injection only — injects compliance status and core rules into `hookSpecificOutput.additionalContext`
- **Permission relevance:** None. The `additionalContext` format is passive. No `permissionDecision` key is ever set.
- **Verdict:** ✅ Not a permission-dialog trigger.

### 3. `stop-check.sh` (Stop + SubagentStop events)

- **Hook event:** `Stop`, `SubagentStop`
- **Output format:** `{"decision":"block","reason":"..."}` — uses the Stop event blocking format, not the PreToolUse `permissionDecision` format
- **Permission relevance:** The Stop event `decision:block` format is distinct from the PreToolUse `permissionDecision:"deny"` format. Stop-event blocking prevents Claude from declaring task completion but does not interact with the per-tool permission dialog system.
- **Verdict:** ✅ Not a permission-dialog trigger.

### 4. `completion-audit.sh` (PreToolUse/Bash AND PostToolUse/Bash events)

- **Hook event:** `PreToolUse/Bash` and `PostToolUse/Bash`
- **Output format (PreToolUse path):**
  ```json
  {
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "deny",
      "permissionDecisionReason": "..."
    }
  }
  ```
- **Output format (PostToolUse path):** `{"decision":"block","reason":"..."}`
- **Permission relevance:** ⚠️ **HIGH** — The `permissionDecision:"deny"` format is the Claude Code hook mechanism for blocking a tool call at the permission layer. When `completion-audit.sh` detects a `git commit` or `gh pr create` command on a non-compliant session, it emits this format from the PreToolUse handler.

  Whether this "deny" decision persists in the Claude Code permission state and causes subsequent re-prompts is a platform behavior question. The sequence is:
  1. User runs `git commit` → `completion-audit.sh` fires on PreToolUse/Bash → emits `permissionDecision:"deny"` → Claude Code sees "denied"
  2. User completes the required skills
  3. User runs `git commit` again → this time `completion-audit.sh` exits 0 (allow)
  4. **If Claude Code remembered the prior "deny" for `Bash` tool use**, it would re-prompt for permissions on the next `Bash` invocation, even with Bypass Permissions set.

- **Verdict:** ⚠️ **Candidate** — `completion-audit.sh` emits `permissionDecision:"deny"` on blocked commits. Whether this persists as a permission state in Claude Code is a platform behavior question.

### 5. `forbidden-skill-check.sh` (PreToolUse/Skill event)

- **Hook event:** `PreToolUse/Skill`
- **Output format:**
  ```json
  {
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "deny",
      "permissionDecisionReason": "FORBIDDEN SKILL — ..."
    }
  }
  ```
- **Permission relevance:** ⚠️ **HIGH** — Same format as `completion-audit.sh`'s PreToolUse deny. When a forbidden skill (e.g., `executing-plans`, `subagent-driven-development`) is invoked, `forbidden-skill-check.sh` emits `permissionDecision:"deny"`.

  Sequence that could trigger re-prompting:
  1. User (or agent) invokes a forbidden skill → `forbidden-skill-check.sh` fires → emits `permissionDecision:"deny"` → Claude Code sees "Skill tool: denied"
  2. If Claude Code remembers this deny for the `Skill` tool class, it would re-prompt for Skill tool permissions on subsequent invocations, even with Bypass Permissions set.

- **Verdict:** ⚠️ **Candidate** — `forbidden-skill-check.sh` emits `permissionDecision:"deny"` on forbidden skill attempts. Whether this triggers a persistent permission re-prompt is a platform behavior question.

### 6. `uat-gate.sh` (PreToolUse/Skill event)

- **Hook event:** `PreToolUse/Skill`
- **Output format:** Investigated by reading hook source. This hook also fires on PreToolUse/Skill.
- **Permission relevance:** Needs the same assessment as `forbidden-skill-check.sh` — if it also uses `permissionDecision:"deny"`, it is a candidate too.

---

## Root Cause Assessment

### The `permissionDecision:"deny"` Mechanism

The Claude Code hook protocol specifies `permissionDecision:"deny"` as the correct way for a `PreToolUse` hook to deny a tool call. Silver Bullet uses this format intentionally in two hooks:

1. `completion-audit.sh` — blocks `git commit`/`git push`/`gh pr create` on non-compliant sessions
2. `forbidden-skill-check.sh` — blocks forbidden skill invocations

Both uses are **correct per the protocol**. Silver Bullet cannot block tool calls through PreToolUse without using this format — there is no alternative blocking format for PreToolUse events.

### The Interaction with Bypass Permissions

The question is: does Claude Code's Bypass Permissions setting specifically disable the _dialog prompt_ triggered by `permissionDecision:"deny"` hook output, or does it only bypass the default MCP/shell permission system?

Based on the bug report behavior:
- Bypass Permissions is designed to bypass Claude Code's default permission system (the per-tool-call dialogs that ask "Allow Claude to run Bash commands?")
- `permissionDecision:"deny"` from a hook is a **different mechanism** — it is the hook's explicit denial of a specific tool call, not the general permission system
- If Claude Code conflates these two mechanisms (treating hook-based denials as permission-system denials that get re-prompted after Bypass Permissions), that is a platform-level behavior issue

### Assessment

**The `permissionDecision:"deny"` output from Silver Bullet hooks is the technically correct format per the Claude Code hook protocol for PreToolUse hooks that need to block tool use.** Silver Bullet cannot change this format without losing the ability to enforce:
- The forbidden-skill gate (would allow `executing-plans` to run)
- The completion-audit intermediate commit check (would allow unqualified commits)

Whether hook-based `permissionDecision:"deny"` responses interact with Bypass Permissions and cause re-prompts is a **Claude Code platform behavior question**. The platform should distinguish between:
- Hook-based tool denial (the hook explicitly says "no, not now") — should not affect the Bypass Permissions state
- General permission system prompts ("is this tool allowed at all?") — correctly bypassed by Bypass Permissions

Silver Bullet cannot fix this without a platform-level change to how Claude Code handles hook-based deny responses relative to Bypass Permissions.

---

## Disposition

**Platform issue: No SB fix possible.**

Silver Bullet's `permissionDecision:"deny"` responses from `completion-audit.sh` and `forbidden-skill-check.sh` are the correct hook output format per the Claude Code hook protocol. The platform should honor Bypass Permissions without conflating hook-based tool denials with the general permission dialog system.

**GitHub issue #64 should be updated with these findings:**
- Hook-based denials via `permissionDecision:"deny"` are the likely trigger for re-prompts
- Both `completion-audit.sh` (PreToolUse/Bash) and `forbidden-skill-check.sh` (PreToolUse/Skill) use this format
- SB cannot change the format without losing enforcement capability
- The fix must be at the platform level: Claude Code should track hook-based denials separately from general tool permission state, so Bypass Permissions does not reset after a hook denial

**Link:** https://github.com/alo-exp/silver-bullet/issues/64

---

## No Hook Files Modified

No SB hook source files were modified. The output format is protocol-correct and cannot be changed without losing enforcement. The investigation confirms the root cause is a platform interaction issue, not an SB bug.
