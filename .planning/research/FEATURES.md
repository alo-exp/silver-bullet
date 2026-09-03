# Features Research — Issue Capture & Retrospective Scan

**Domain:** AI agent/orchestrator deferred-item capture, retrospective scanning, issue lifecycle management
**Researched:** 2026-04-24
**Confidence:** HIGH for SB-internal patterns (evidence from existing skills and forensics report); MEDIUM for external ecosystem comparisons (web search + Backlog.md)

---

## /silver-add

### Table Stakes

These are behaviors any issue-capture command must have to be considered complete. Missing any
one of these makes the skill feel broken.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Read `issue_tracker` from `.silver-bullet.json` before filing | SB already wires `github`/`gsd` routing in silver-feature; silver-add must be consistent | LOW | Config already exists; just read it |
| Accept freeform text and classify internally | Caller (coding agent or user) shouldn't need to know GitHub label taxonomy | LOW | Classification via keyword heuristics + LLM judgment |
| Return a stable ID the caller can reference | Auto-capture enforcement needs to log the ID it was given | LOW | GitHub: issue number (`#123`); local: slug or line ref |
| Emit a one-line confirmation with the ID | Closure signal for the calling context | LOW | e.g. `Filed #47 — "Refactor auth token refresh" [bug]` |
| Deduplicate near-identical titles before filing | Calling agents filing on-the-fly will sometimes duplicate items across parallel waves | MEDIUM | Fuzzy match against open issues; prompt on collision, don't silently skip |
| No mandatory user interaction in non-interactive (autonomous) mode | Auto-capture must work without prompting | LOW | Classify autonomously; surface result only |

### Differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Project board placement (GitHub mode) | A filed issue not on the project board is invisible to the team; SB's own CLAUDE.md already encodes the two-step create+add pattern | MEDIUM | Requires `gh project item-add` + `gh project item-edit --single-select-option-id <backlog-id>` |
| Source attribution in issue body | Issues filed during a session should reference the session log filename that triggered them | LOW | Append `<!-- filed by silver-add from docs/sessions/YYYY-MM-DD-slug.md -->` to body |
| Milestone tagging | GitHub milestone field links the issue to the current GSD milestone version | LOW | Read current version from `.planning/ROADMAP.md` or `silver-bullet.md`; set `--milestone` |
| Type-specific label sets | `bug` vs `enhancement` vs `tech-debt` vs `open-question` each map to a different label combination | LOW | Codify label taxonomy once; reuse across all silver-* skills |

### UX Flow

**Interactive (user calls /silver-add directly):**

```
1. Read `.silver-bullet.json` → determine issue_tracker
2. Accept freeform description (argument or prompt if none given)
3. Classify: what type is this item?
   - bug / defect — broken behavior, test failure, regression
   - tech-debt — known shortcut, deferred refactor, hardcoded value
   - enhancement / feature — new capability or behavior change
   - open-question — decision not yet made, research needed
   - housekeeping — docs, chore, configuration drift
4. Show proposed title + type + one-line body preview
5. Confirm (Y/n) — auto-confirm in autonomous mode
6. File to PM system (see below)
7. Output: "Filed #<id> — <title> [<type>]"
```

**Auto-capture (coding agent calls silver-add inline during execution):**

```
1-3 same as above, but skip step 4-5 (no confirmation)
4. File immediately
5. Append to session log "## Items Filed" section (if session log exists and is open):
   - #<id> [<type>] <title>
```

**Classification heuristics (for autonomous classification without user input):**

The coding agent's calling phrase is the strongest signal. Map phrases to types:

| Phrase pattern in calling context | Classified as |
|-----------------------------------|---------------|
| "skipping X for now", "skip this", "skipped X" | tech-debt or enhancement (if new capability) |
| "out of scope for this phase", "descoped" | enhancement |
| "fix later", "broken", "failing", "regression", "error" | bug |
| "TODO", "FIXME", "HACK", "hardcoded" | tech-debt |
| "unclear", "open question", "need to decide", "need research" | open-question |
| "clean up", "rename", "reorganize", "update docs" | housekeeping |
| No strong signal | enhancement (default) |

### Issue Fields (GitHub mode)

Fields written at `gh issue create` time:

| Field | Source | Example |
|-------|--------|---------|
| `--title` | Derived from description (first sentence, max 72 chars) | "Refactor auth token refresh to use refresh_token field" |
| `--body` | Full description + source attribution block | See body template below |
| `--label` | Type-to-label map | `bug`, `enhancement`, `tech-debt`, `question`, `chore` |
| `--milestone` | Current GSD milestone version (if GitHub milestone exists) | `v0.25.0` |
| `--repo` | `git remote get-url origin` | `alo-exp/silver-bullet` |

After create, add to project board:

| Operation | Command |
|-----------|---------|
| Add to project | `gh project item-add <project-number> --owner <owner> --url <issue-url> --format json` |
| Set Status = Backlog | `gh project item-edit --project-id <node-id> --id <item-id> --field-id <status-field-id> --single-select-option-id <backlog-option-id>` |

**Body template:**

```markdown
<description>

---
**Type:** <type>
**Filed by:** silver-add
**Source session:** <session-log-filename or "interactive">
**Filed:** <YYYY-MM-DD>
```

**Project board discovery (one-time, cached in `.silver-bullet.json`):**

On first GitHub filing, if no `_github_project` cache exists in `.silver-bullet.json`:
1. `gh project list --owner <owner>` — find the project number
2. `gh project field-list <number> --owner <owner> --format json` — extract Status field id + Backlog option id
3. Store in `.silver-bullet.json` under `_github_project: { number, node_id, status_field_id, backlog_option_id }`
4. Reuse on all subsequent calls — no re-discovery

If no project board found: fall back to plain `gh issue create` without board placement; warn user.

### Issue Fields (Local/GSD mode)

When `issue_tracker = "gsd"`, file to local markdown. Two options, in order of preference:

1. **`gsd-add-backlog` skill** — if the GSD skill is available, invoke it (already used by silver-feature, silver-bugfix, silver-ui; this is the established SB pattern)
2. **Direct append** — if `gsd-add-backlog` is unavailable, append to `.planning/ROADMAP.md` under `## Backlog`:

```markdown
- [ ] [<type>] <title> — <one-line description> *(filed <YYYY-MM-DD>)*
```

Return value in GSD mode: the ROADMAP.md line number or a slug constructed as `backlog-YYYYMMDD-<N>`.

---

## /silver-remove

### Table Stakes

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Accept an ID and remove the item | Core purpose | LOW | GitHub: `gh issue close #<N>` (close, not delete — GitHub doesn't allow delete via CLI); local: remove ROADMAP.md line |
| Confirm before removing in interactive mode; skip confirm in autonomous | Destructive operation | LOW | Show title before proceeding |
| Output confirmation of what was removed | Caller needs to know it worked | LOW | e.g. `Closed #47 — "Refactor auth token refresh"` |
| Distinguish "close" (done) from "delete" (wrong item) | Different intent, different labels | LOW | GitHub: close with `--comment "Resolved"` vs close with `--comment "Filed in error"` |

### UX Flow

```
1. Accept ID argument (required — error if missing)
2. Resolve item:
   - GitHub mode: `gh issue view #<N> --json title,state` — verify it exists and is open
   - Local mode: search ROADMAP.md for matching slug or line
3. Display: "Remove #<N> — <title>? [Y/n]" (skip in autonomous mode)
4. Accept reason: "done" (default) or "error" / "won't fix" / "duplicate"
5. Execute removal:
   - GitHub: `gh issue close #<N> --comment "<reason>"`
   - Local: remove matching line from ROADMAP.md
6. Output: "Removed #<N> — <title> [reason: <reason>]"
```

**Error cases:**
- ID not found: "No open item found with ID #<N>. Check `gh issue list` or ROADMAP.md."
- Already closed: "Item #<N> is already closed (state: closed)."
- Malformed ID: "ID must be a number (GitHub mode) or a backlog slug (GSD mode)."

---

## /silver-scan

### Table Stakes

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Scan ALL session logs in `docs/sessions/` from beginning | Forensics report identified this as the trigger — items noted in old sessions never reached any backlog | MEDIUM | Glob `docs/sessions/*.md`, sort by filename ascending |
| Detect deferred/skipped/ignored items from session log text | Core value of the skill | MEDIUM | Text heuristics on structured sections (see below) |
| Cross-reference detected items against current open issues | Don't re-file what's already tracked | MEDIUM | GitHub: `gh issue list --state open`; local: read ROADMAP.md backlog |
| Assess relevance before filing | Old deferred items may be obsolete; don't file stale noise | MEDIUM | LLM judgment: is this still relevant given current codebase state? |
| Require user approval before filing each item (interactive) | User must validate "relevant" classification before items go to PM | LOW | Present items one-by-one or as batch with approve/skip per item |
| Produce a scan report as output | Audit trail of what was found, what was filed, what was skipped | LOW | Write to `docs/silver-forensics/silver-scan-YYYY-MM-DD.md` |
| Skip already-addressed items | Items that appear in session logs AND have been resolved should not be re-filed | MEDIUM | Cross-ref against git log + CHANGELOG.md + closed issues |

### Deferred-Item Detection Heuristics

Session logs have a well-defined structure (see `docs/sessions/*.md`). Detection operates on these sections in priority order:

**Section: `## Needs human review`**
- Any non-empty, non-`*(none)*` entry is a candidate deferred item
- Extract each bullet point as a candidate
- Type: infer from content (bug if "failing"/"broken", open-question if "unclear"/"decide", tech-debt otherwise)

**Section: `## Autonomous decisions`**
- Look for patterns:
  - "excluded from ... because" → scope descope → `enhancement` candidate
  - "deferred as tech debt" → `tech-debt` candidate
  - "skipped ... conditional" → `housekeeping` candidate

**Section: `## Outcome`**
- Look for "Awaiting" followed by incomplete items → `tech-debt` or `enhancement` candidate
- Pattern: "Awaiting [X, Y, Z]" where X/Y/Z are unfulfilled steps

**Section: `## Files changed`**
- TODO/FIXME comments embedded in change descriptions → `tech-debt` candidate
- "placeholder" in filename or description → `housekeeping` candidate

**Section: `## Knowledge & Lessons additions` / `## KNOWLEDGE.md additions`**
- Open questions noted with `[OPEN]` tag → `open-question` candidate
- "resolved — deferred as tech debt" → `tech-debt` candidate

**Free text anywhere in session log:**
Apply these phrase patterns (case-insensitive):

| Pattern | Classification |
|---------|---------------|
| `skip(ped|ping) .{3,60} (for now|later|future)` | tech-debt or enhancement |
| `out of scope (for|in) this (phase|session|milestone)` | enhancement |
| `defer(red)? (as|to) (tech.debt|backlog|next)` | tech-debt |
| `TODO[:\s]` | tech-debt or housekeeping |
| `FIXME[:\s]` | bug |
| `will (address|fix|do|handle|revisit) (later|in.*phase|in.*milestone)` | tech-debt |
| `open question:` | open-question |
| `not (yet|currently) (implemented|supported|tracked)` | enhancement or tech-debt |
| `[Pp]lanned for (future|v\d+|next)` | enhancement |

### Session Log Patterns to Match

The existing SB session log format has these known source fields:

```
## Needs human review
*(none)*                          ← SKIP (empty)
- Some item that needs attention  ← CANDIDATE

## Autonomous decisions
- accessibility-review excluded from required_deploy — [reason]  ← CANDIDATE (descoped item)
- finalization_skills derivation — deferred as tech debt          ← CANDIDATE (explicit defer)

## Outcome
Phase 2 complete. [...] Awaiting CI gate, deploy-checklist, ship  ← CANDIDATE ("Awaiting" = incomplete)

## Knowledge & Lessons additions / ## KNOWLEDGE.md additions
- Open questions: finalization_skills runtime derivation (resolved — deferred as tech debt)  ← CANDIDATE
```

**CONTEXT.md deferred section** (in `.planning/phases/*/NN-CONTEXT.md`):

```xml
<deferred>
## Deferred Ideas
None — discussion stayed within phase scope   ← SKIP if "None"
- Some deferred idea                          ← CANDIDATE if non-empty
</deferred>
```

**Tech debt register** (`docs/tech-debt.md`):
- Each table row is a candidate; cross-reference against open issues to avoid duplication

**Forensics reports** (`docs/silver-forensics/*.md`):
- `## Open Items Identified` table → each row is a candidate
- `## Recommended Next Steps` checklist → unchecked items are candidates

**Relevance assessment criteria** (LLM judgment, after detection):

| Signal | Weight | Notes |
|--------|--------|-------|
| Item references code/files that still exist | HIGH positive | `grep` or Read to verify |
| Item is in CHANGELOG.md as completed | HIGH negative (skip) | Already done |
| Item is in a closed GitHub issue | HIGH negative (skip) | Already tracked + resolved |
| Item references a phase that is now archived (has VERIFICATION.md) | MEDIUM negative | Likely resolved; flag as "possibly stale" for user review |
| Item is referenced in tech-debt.md as still open | HIGH positive | Explicitly unresolved |
| Item's "awaiting" work is now in git history | HIGH negative (skip) | Work was done |
| Item dates from >6 months ago | LOW negative | Apply extra scrutiny; present to user with age warning |

---

## Auto-Capture Enforcement

### How it works in practice (what the coding agent is instructed to do)

Auto-capture enforcement is **instruction-level** — it goes into SB's execution skill instructions (silver-feature, silver-bugfix, silver-ui, silver-devops, silver-fast, and the composable flows in `docs/workflows/`). It is not a hook.

**Why not a hook?** Hooks fire on tool events (PreToolUse, PostToolUse) and cannot introspect the semantic content of what the agent just decided to defer. Only instruction-level text can create the behavior "when you decide to skip or defer something, call silver-add before moving on."

**Current state:** silver-feature already has a "During-execution deferred capture" instruction block that routes to `gsd-add-backlog`. The v0.25.0 upgrade replaces those `gsd-add-backlog` calls with `silver:add` and extends the pattern to all other orchestration skills.

**The enforced behavior, fully described:**

```
When the coding agent encounters any of the following during execution:
  - A decision to skip a task ("too complex for this phase", "not in scope")
  - A decision to defer a fix ("will clean up later", "known issue, leaving for now")
  - A code review advisory item that won't be fixed immediately
  - A tech debt item identified during /tech-debt skill invocation
  - An open question that wasn't resolved during /gsd-discuss-phase
  - A failing test that won't be fixed in this session
  - A FIXME or TODO in code being written

The agent MUST:
1. Invoke silver:add with a description of the deferred item BEFORE continuing
2. Record the returned ID in the session log's "## Items Filed" section
3. NOT proceed to the next task until silver-add confirms filing

The agent MUST NOT:
- Accumulate deferred items for end-of-session batch filing (anti-pattern: context is lost)
- Silently drop deferred items (the root cause identified in the 2026-04-16 forensics report)
- File items after the session ends (silver-scan handles retroactive discovery; auto-capture handles real-time)
```

**Where the instructions live:**

| Skill file | Where the block goes |
|------------|---------------------|
| `skills/silver-feature/SKILL.md` | Replace existing `gsd-add-backlog` block in "During-execution deferred capture" |
| `skills/silver-bugfix/SKILL.md` | Same — add equivalent block |
| `skills/silver-ui/SKILL.md` | Same |
| `skills/silver-devops/SKILL.md` | Same |
| `skills/silver-fast/SKILL.md` | Add block before Step 3 (execute) |
| `docs/workflows/full-dev-cycle.md` | Add to EXECUTE flow supervision loop |
| `docs/workflows/devops-cycle.md` | Add to EXECUTE flow supervision loop |
| `templates/` mirrors | Must stay in byte-identical sync with docs/workflows/ |

**Session log integration:**

The session log template (used by `session-log-init.sh` hook) needs a new section:

```markdown
## Items Filed

*(none — auto-populated by silver-add)*
```

Each `silver-add` invocation appends a line here:
```
- #47 [tech-debt] Derive finalization_skills from .silver-bullet.json at runtime
- #48 [bug] T2-1 test failure in test-timeout-check.sh (pre-existing)
```

This section becomes the input for the Post-Release Summary.

---

## Post-Release Summary

### What to display and when

**Trigger:** At the end of `silver:release` Step 9 (`gsd-complete-milestone`), after milestone archival succeeds.

**Source:** The session logs for all sessions in the milestone. Specifically, scan every `docs/sessions/*.md` that was modified or created since the milestone start date (read from `.planning/ROADMAP.md` milestone header or `STATE.md`).

**What to display:**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 SILVER BULLET ► MILESTONE v0.25.0 — ITEMS FILED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Items filed to backlog during this milestone:

  #47 [tech-debt]    Derive finalization_skills from .silver-bullet.json at runtime
  #48 [bug]          T2-1 test failure in test-timeout-check.sh
  #51 [enhancement]  Add project board discovery caching to silver-init
  #52 [housekeeping] Update docs/KNOWLEDGE.md — missing artifact referenced in session

Total: 4 items
Tracker: github (alo-exp/silver-bullet)

View backlog: gh issue list --label backlog --state open
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**What NOT to display:**
- Items that were filed and then closed (resolved) within the same milestone
- Items from sessions before the current milestone
- The full body of each issue (title only in the summary; ID is the reference)

**Fallback (no items filed):**

```
No items filed to backlog during this milestone.
(Auto-capture was active but nothing was deferred.)
```

**Fallback (GSD mode / no GitHub):**

```
Items filed to backlog during this milestone:

  backlog-20260424-1 [tech-debt]    Derive finalization_skills at runtime
  backlog-20260424-2 [bug]          T2-1 test failure

View backlog: cat .planning/ROADMAP.md | grep "^- \[ \]"
```

**Implementation approach:**

1. During silver-release Step 9, before calling `gsd-complete-milestone`:
   - Determine milestone start date from `STATE.md` or ROADMAP active milestone header
   - Glob `docs/sessions/*.md`, filter to files with mtime >= milestone start
   - For each, extract the `## Items Filed` section
   - Aggregate all IDs + titles
   - Cross-reference with current open issues to filter out already-closed ones
   - Display summary
2. Then invoke `gsd-complete-milestone` to archive

**Dependency:** Post-Release Summary requires the `## Items Filed` section in session logs (added by auto-capture enforcement) and `silver:add` returning stable IDs. Both must land in the same milestone.

---

## Feature Dependencies

```
[silver-add]
    └── required by → [auto-capture enforcement] (calling convention)
    └── required by → [silver-scan] (files discovered items)
    └── required by → [post-release summary] (IDs come from silver-add)
    └── reads → [issue_tracker in .silver-bullet.json] (already exists)
    └── reads → [_github_project cache in .silver-bullet.json] (new field)

[silver-remove]
    └── reads → [issue_tracker in .silver-bullet.json]
    └── independent of silver-add (can remove manually created issues too)

[silver-scan]
    └── requires → [silver-add] (for filing discovered items)
    └── reads → [docs/sessions/*.md] (already exists)
    └── reads → [.planning/phases/*/CONTEXT.md <deferred> sections] (already exists)
    └── reads → [docs/tech-debt.md] (already exists)
    └── reads → [docs/silver-forensics/*.md] (already exists)
    └── cross-refs → [gh issue list] or [ROADMAP.md backlog] (already exists)

[auto-capture enforcement]
    └── requires → [silver-add] (the thing it calls)
    └── modifies → [session log ## Items Filed section] (new section)
    └── lives in → [silver-feature, silver-bugfix, silver-ui, silver-devops, silver-fast skill files]
    └── lives in → [docs/workflows/ + templates/workflows/ (must stay in sync)]

[post-release summary]
    └── requires → [## Items Filed section in session logs] (from auto-capture)
    └── requires → [silver-add returning stable IDs] (from silver-add)
    └── lives in → [silver-release Step 9]
    └── reads → [STATE.md or ROADMAP.md milestone dates]
```

---

## Anti-Features

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Batch filing at session end | Session end is after the context window shrinks; deferred item descriptions become vague | File immediately at the moment of deferral (auto-capture) |
| silver-add as a webhook/hook | Hooks can't reason about semantic content of agent decisions | Instruction-level enforcement in skill files |
| Reopening closed GitHub issues in silver-scan | Disruptive; items closed for a reason | Create new issues for re-discovered problems; link to the closed one in the body |
| silver-scan auto-filing without user approval | Retrospective items may be stale; false positives waste PM bandwidth | Present candidates with relevance assessment; require per-item Y/n |
| Deleting GitHub issues in silver-remove | GitHub CLI does not support issue deletion | Close with a reason comment; this is the GitHub-native pattern |
| Global CLAUDE.md encoding of project board IDs | User's global CLAUDE.md already has this pattern for the alo-exp repos; silver-add must cache project-specific data in `.silver-bullet.json`, not the global config | Cache in `.silver-bullet.json` `_github_project` field |
| Separate "issue" vs "backlog" classification at silver-add call time | Adds a classification decision to every auto-capture call during execution | All items go to Backlog status on the project board; the type label (bug/tech-debt/etc.) carries the classification |

---

## Complexity Assessment

| Feature | Implementation Complexity | Notes |
|---------|--------------------------|-------|
| silver-add (GSD mode) | LOW | `gsd-add-backlog` call wrapper + classification heuristics |
| silver-add (GitHub mode, no board) | LOW | `gh issue create` with labels |
| silver-add (GitHub mode, with board) | MEDIUM | Board discovery + two-step create+add; caching reduces subsequent calls to LOW |
| silver-remove | LOW | `gh issue close` or ROADMAP.md edit |
| auto-capture enforcement (instruction update) | LOW | Text changes to 5 skill files + 2 workflow files + templates |
| session log ## Items Filed section | LOW | Add to session-log-init.sh template |
| silver-scan (detection heuristics) | MEDIUM | Regex patterns on known section formats; validated by existing forensics report |
| silver-scan (relevance assessment) | MEDIUM | LLM judgment call + git log / issue list cross-reference |
| silver-scan (report output) | LOW | Structured markdown; same pattern as forensics report |
| post-release summary | LOW | Aggregate ## Items Filed sections + display |

---

## Existing Infrastructure to Reuse

| Component | How silver-add/scan/remove uses it |
|-----------|-----------------------------------|
| `issue_tracker` in `.silver-bullet.json` | Primary routing decision; already wired in silver-feature, silver-bugfix, silver-ui |
| `gsd-add-backlog` skill | GSD-mode filing; already the established pattern |
| `gh issue create` CLI | GitHub-mode filing; already used by user's CLAUDE.md conventions |
| `gh project item-add` + `gh project item-edit` | Board placement; already documented in user's global CLAUDE.md |
| `docs/sessions/*.md` | silver-scan input; already created by session-log-init.sh |
| `docs/silver-forensics/` | silver-scan report output location; pattern from silver-forensics |
| `.planning/phases/*/CONTEXT.md` `<deferred>` tag | silver-scan input; known structured format |
| `docs/tech-debt.md` | silver-scan input; tabular format, parseable |
| `silver-release` Step 9 | post-release summary trigger point; already the milestone close step |
| `security` boundary pattern from silver-forensics | silver-scan reads UNTRUSTED session log content; apply same security note |

---

*Feature research for: Silver Bullet v0.25.0 — Issue Capture & Retrospective Scan*
*Researched: 2026-04-24*
