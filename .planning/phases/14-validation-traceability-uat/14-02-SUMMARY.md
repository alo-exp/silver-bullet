---
phase: 14-validation-traceability-uat
plan: "02"
subsystem: hooks
tags: [traceability, spec, hooks, pr, session]
dependency_graph:
  requires: []
  provides: [spec-session-record.sh, pr-traceability.sh, hooks.json-registration]
  affects: [PR descriptions, SPEC.md Implementations section]
tech_stack:
  added: []
  patterns: [SessionStart hook, PostToolUse Bash hook, spec-session file, gh pr edit append]
key_files:
  created:
    - hooks/spec-session-record.sh
    - hooks/pr-traceability.sh
  modified:
    - hooks/hooks.json
decisions:
  - "pr-traceability.sh triggers on actual `gh pr create` Bash command (not gsd-ship itself) to avoid double-firing"
  - "Append-only PR body update via --body-file to prevent overwrite (T-14-05 mitigation)"
  - "umask 0077 on spec-session file for user-only permissions (T-14-03 mitigation)"
  - "git commit uses --no-verify inside hook to avoid recursive hook invocation"
metrics:
  duration: 8min
  completed: "2026-04-09"
  tasks: 2
  files: 3
---

# Phase 14 Plan 02: Spec Traceability Hooks Summary

## One-liner

Machine-generated PR-to-spec traceability via SessionStart hook capturing SPEC.md context and PostToolUse hook auto-appending traceability block to PR descriptions.

## What Was Built

**hooks/spec-session-record.sh** (SessionStart):
- Fires on session startup/clear/compact
- Reads `spec-version` and `jira-id` from `.planning/SPEC.md` frontmatter
- Writes `~/.claude/.silver-bullet/spec-session` with key=value pairs
- Exits silently if SPEC.md absent — no blocking
- Emits advisory: "Spec session: SPEC.md v{version}, JIRA: {id}"

**hooks/pr-traceability.sh** (PostToolUse/Bash):
- Triggers only on `gh pr create` commands (exact word-boundary match)
- Reads spec-session file for spec-version and jira-id
- Reads WARN findings from `.planning/VALIDATION.md` for deferred items section
- Appends traceability block to existing PR body via `gh pr edit --body-file` (never overwrites)
- Updates SPEC.md `## Implementations` section with PR URL, date, spec-version
- Commits SPEC.md update with `trace: link PR to SPEC.md v{version}` message

**hooks/hooks.json** updated:
- `spec-session-record.sh` added to SessionStart array
- `pr-traceability.sh` added to PostToolUse Bash matcher (after completion-audit.sh)

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Threat Flags

None — all T-14-03 and T-14-05 mitigations from the threat model are implemented (umask 0077, append-only PR body).

## Self-Check: PASSED

- hooks/spec-session-record.sh: exists, executable, valid bash syntax
- hooks/pr-traceability.sh: exists, executable, valid bash syntax
- hooks/hooks.json: valid JSON, both hooks registered
- Commits: a4a0a76 (hook scripts), 2827485 (hooks.json registration)
