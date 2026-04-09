---
phase: 06-implement-enforcement-techniques
plan: 01
subsystem: enforcement-hooks
tags: [hooks, enforcement, stop-hook, user-prompt-submit, compact-prompt]
dependency_graph:
  requires: []
  provides: [stop-check.sh, prompt-reminder.sh, hooks-stop-entry, hooks-userpromptsubmit-entry, compactPrompt-config]
  affects: [hooks/hooks.json, templates/silver-bullet.config.json.default, templates/silver-bullet.md.base]
tech_stack:
  added: []
  patterns: [stop-hook-block-json, userpromptsubmit-additional-context, path-walk-up-config, path-security-validation]
key_files:
  created:
    - hooks/stop-check.sh
    - hooks/prompt-reminder.sh
  modified:
    - hooks/hooks.json
    - templates/silver-bullet.config.json.default
    - templates/silver-bullet.md.base
decisions:
  - Stop hook uses identical config-reading and skill-list logic as completion-audit.sh Tier 2 for consistency
  - prompt-reminder.sh does not read stdin to avoid blocking; error trap exits 0 silently for speed
  - compactPrompt added after semantic_compression in config template for logical grouping
metrics:
  duration: ~3 minutes
  completed: 2026-04-06T08:46:30Z
  tasks_completed: 3
  files_changed: 5
---

# Phase 06 Plan 01: Stop Hook and UserPromptSubmit Hook Summary

Stop hook blocks Claude from declaring task complete when required_deploy skills are missing; UserPromptSubmit hook injects compact missing-skills reminder before every user prompt; compactPrompt config key preserves rules through /compact.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create Stop hook (hooks/stop-check.sh) | 6cba586 | hooks/stop-check.sh |
| 2 | Create UserPromptSubmit hook (hooks/prompt-reminder.sh) | c091f5d | hooks/prompt-reminder.sh |
| 3 | Register hooks in hooks.json; add compactPrompt | e88f257 | hooks/hooks.json, templates/silver-bullet.config.json.default, templates/silver-bullet.md.base |

## What Was Built

### hooks/stop-check.sh (Stop event hook)

Fires when Claude outputs a final response declaring task complete. Blocks with `{"decision":"block","reason":"..."}` if any required_deploy skills are absent from the state file.

Key behaviors:
- Walks up from $PWD to find .silver-bullet.json (same pattern as completion-audit.sh)
- Single jq call reads state_file, trivial_file, required_deploy, and active_workflow
- Validates state_file path stays within ~/.claude/ (security: T-06-01)
- Trivial bypass via trivial_file (symlinks rejected)
- Removes finishing-a-development-branch from required list when on main/master branch
- Deduplicates merged required_skills list
- Outputs bullet-formatted block reason listing each missing skill
- Error trap emits warning JSON and exits 0 on unexpected failure

### hooks/prompt-reminder.sh (UserPromptSubmit hook)

Fires before every user prompt. Emits `{"hookSpecificOutput":{"additionalContext":"..."}}` with a compact status line: either all-complete confirmation or comma-separated list of missing skills with count.

Key behaviors:
- Does NOT read stdin (avoids blocking, keeps < 200ms)
- Single jq call reads all config values (speed optimization)
- Same ~/.claude/ path validation (security: T-06-02)
- Error trap exits 0 silently (never slow down user prompts: T-06-03)
- Format: "Silver Bullet -- Missing: skill-a, skill-b (N of M complete)"

### hooks/hooks.json

Added Stop and UserPromptSubmit event arrays after PostToolUse, each with a `".*"` matcher and synchronous command pointing to the new scripts via `${CLAUDE_PLUGIN_ROOT}`.

### templates/silver-bullet.config.json.default

Added `"compactPrompt"` key after `semantic_compression` with the verbatim preservation instruction text.

### templates/silver-bullet.md.base

Added `> **compactPrompt**: ...` guidance block in the Session Startup section immediately before the existing Anti-Skip note.

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Threat Flags

None - no new network endpoints, auth paths, file access patterns, or schema changes beyond what the plan's threat model described.

## Self-Check: PASSED

- hooks/stop-check.sh: FOUND, executable, syntax valid, block JSON emitted in smoke test
- hooks/prompt-reminder.sh: FOUND, executable, syntax valid, additionalContext emitted in smoke test
- hooks/hooks.json: valid JSON, Stop entry present, UserPromptSubmit entry present, both scripts referenced
- templates/silver-bullet.config.json.default: valid JSON, compactPrompt key present
- templates/silver-bullet.md.base: compactPrompt guidance block present
- Commits 6cba586, c091f5d, e88f257: all present in git log
