---
seed_id: SEED-004
title: Investigate Bypass Permissions re-prompt on every session
github_issue: 64
priority: medium
planted_during: v0.30.0 Open-Issue Sweep
planted_at: 2026-04-28
trigger_when:
  - User reports the re-prompt happens reproducibly with a captured trace
  - Claude Code releases a fix or surfaces the persistence mechanism for `bypassPermissions`
  - SessionStart hook is observed to mutate `.claude/settings.json` (which today it does NOT)
---

# SEED-004: Bypass Permissions re-prompt on every session

## Idea

The reporter's session shows Claude Code re-prompting for permissions every session even after Bypass Permissions is selected. Possible causes:

1. Claude Code platform issue with how `permissions.defaultMode` persists in `~/.claude/settings.json` (most likely, per current evidence)
2. SB's SessionStart hook clobbering the `permissions` block — but a code audit shows `hooks/session-start` only writes to `~/.claude/.silver-bullet/` paths, never to `~/.claude/settings.json`
3. A stale per-project `.claude/settings.local.json` overriding the user-level setting

## Why This Matters

If SB is the cause, this is a P0 UX bug. Current evidence points to upstream Claude Code, not SB — but the issue stayed open without a definitive trace.

## When to Surface

- A reproducible repro is captured (settings.json before/after, exact prompt sequence).
- Claude Code documents the persistence mechanism for `permissions.defaultMode`.
- A code change in SB hooks could plausibly affect user-level settings.

## Implementation Sketch (when triggered)

1. Capture the user's `~/.claude/settings.json` and `<project>/.claude/settings.local.json` before and after a fresh Claude Code launch with Bypass Permissions selected.
2. Run `hooks/session-start` and verify it does not mutate either file (already audited, expected to confirm).
3. If SB is innocent: file upstream against Claude Code with the captured trace.
4. If SB is the cause: write a regression test that asserts SB never writes to `~/.claude/settings.json`.

## Why Deferred

The issue lacks a captured trace. Without one, the investigation devolves to "watch for it next time it happens." A SB code audit (hooks/session-start writes only to `~/.claude/.silver-bullet/`) suggests this is an upstream platform issue, not a SB bug. Deferring until either a trace lands or upstream documents the persistence semantics.

## References

- GitHub issue: https://github.com/alo-exp/silver-bullet/issues/64
