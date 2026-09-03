# Silver Thread Skill Scenario

## Skill: silver-thread
## Context: Lightweight cross-session context threads for tracking a named concern

### Scenario: Track and Resume an Open Investigation

**Trigger:** "Track the API gateway TCP timeout investigation across sessions"

**Workflow:**
1. Detect operation from arguments: create, `list`, `status`, `close`, or resume by slug.
2. For create: write `.planning/threads/<slug>.md` with context, open questions, and status `open`.
3. For resume: surface current context and open questions; append a dated session entry; set status `in_progress`.
4. For close: prompt for a resolution summary; mark status `resolved` and update `Last updated`.
5. File any action items surfaced in the thread via `silver:add`.
