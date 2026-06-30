---
name: "silver:thread"
title: "Thread"
description: >
  Lightweight cross-session context threads for tracking a specific topic,
  decision chain, or concern across multiple sessions without a full project
  handoff.
argument-hint: "<thread name or description> [list] [status <name>] [close <name>]"
version: 0.1.0
---

# /silver:thread — Cross-Session Context Threads

SB-owned lightweight thread store. Use when you need to track a specific
topic — an open question, a recurring concern, a cross-cutting decision, or
a blocking dependency — across sessions without the overhead of a full
`silver:handoff`.

A thread is NOT a task (use `silver:add`), NOT a full project handoff (use
`silver:handoff`), and NOT a phase plan (use `silver:plan`). A thread is a
persistent, resumable context anchor for a named concern.

## Output

Threads are stored as Markdown files at `.planning/threads/<slug>.md`.

Each thread file:

```markdown
# Thread: <title>

Status: open | in_progress | resolved
Created: YYYY-MM-DD
Last updated: YYYY-MM-DD

## Context

<What is this about? What decision or concern is being tracked?>

## Sessions

### Session YYYY-MM-DD

<What happened in this session related to this thread?>
<Decisions made, progress, new questions>

## Open Questions

- <unanswered questions that block resolution>

## Resolution

<when status = resolved: what was decided or done>
```

## Operations

### Create (default)

Providing a description creates a new thread.

```
/silver:thread "Investigate TCP timeout in the API gateway"
```

### List

Show all threads with their status and last-updated date.

```
/silver:thread list
/silver:thread list --open
/silver:thread list --resolved
```

### Status

Show the full content of a specific thread.

```
/silver:thread status api-gateway-timeout
```

### Resume

Resume work on an existing thread (updates the Sessions log for today).

```
/silver:thread api-gateway-timeout
```

When resuming, the skill:
1. Reads the thread file and surfaces the current context and open questions.
2. Appends a new session entry with today's date.
3. After work completes, asks if any open questions were resolved and updates
   the thread.

### Close

Mark a thread as resolved.

```
/silver:thread close api-gateway-timeout
```

Prompts for a one-sentence resolution summary before marking resolved.

## Process

1. Display `SILVER BULLET > THREAD`.
2. Detect operation from arguments:
   - First arg is `list` → list operation
   - First arg is `status` → status operation
   - First arg is `close` → close operation
   - First arg matches an existing thread slug → resume operation
   - Otherwise → create operation
3. For **create**: prompt for context if not supplied in arguments; generate
   a kebab-case slug from the title; write the thread file.
4. For **resume**: read the thread, surface open questions, append new session
   entry, update after work.
5. For **close**: prompt for resolution text; mark status `resolved`; update
   `Last updated`.
6. **At session start** (via `silver:handoff` or `silver` router): if any
   threads with status `open` or `in_progress` exist, surface them briefly:
   > "Active threads: api-gateway-timeout (open, 3d), auth-token-refresh
   >  (in_progress, 1d). Resume a thread with `/silver:thread <name>`."

## Integration with `silver:handoff`

`silver:handoff` includes the active thread list in the generated handoff
prompt so threads survive project-level context transitions. When a new
session resumes from a handoff, `silver` router checks `.planning/threads/`
and surfaces open threads before routing the first user message.

## Lifecycle Rules

- A thread is `open` when created.
- A thread becomes `in_progress` when a session appends an entry.
- A thread becomes `resolved` when explicitly closed with a resolution.
- Threads are never deleted; they are archived by setting status `resolved`.
- File any action items surfaced in a thread via `silver:add`.

## Exit Gate

Create: thread file written and slug confirmed.
Resume: session entry appended and open questions updated.
Close: resolution recorded and status set to `resolved`.
