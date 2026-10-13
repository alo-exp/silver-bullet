# Stack Research — Issue Capture & Retrospective Scan

**Milestone:** v0.25.0 — Issue Capture & Retrospective Scan
**Researched:** 2026-04-24
**Confidence:** HIGH — all gh CLI commands verified against the installed binary (gh 2.x with `project` scope confirmed active on this machine)

---

## Scope

Stack additions needed for four new capabilities:
1. `/silver-add` — classify and file item to GitHub Issues + project board, or local markdown
2. `/silver-remove` — remove item by ID from GitHub or local markdown
3. `/silver-scan` — glob session logs + git log, extract deferred items
4. Auto-capture enforcement — SB instructs coding agent to call silver-add on the fly

The existing SB stack (shell hooks, markdown skills, `jq`, `gh` CLI, `git`) is already present and validated. No new tools or runtimes are required.

---

## GitHub Integration (gh CLI)

### Prerequisite: `project` scope

GitHub Projects V2 operations require the `project` OAuth scope. This scope is confirmed present on the development machine. The silver-add skill must check for it and instruct the user to re-auth if missing:

```bash
# Verify project scope is present
gh auth status 2>&1 | grep -q "project" || echo "MISSING_SCOPE"

# If missing, user runs:
# gh auth refresh -s project
```

### Creating a GitHub Issue

```bash
# Basic — issue only
ISSUE_URL=$(gh issue create \
  --repo <owner>/<repo> \
  --title "<title>" \
  --body "<body>" \
  --label "<label>" \
  --json url -q '.url')

# Extract issue number from URL for ID assignment
ISSUE_NUM=$(echo "$ISSUE_URL" | grep -o '[0-9]*$')
```

**Flag notes (verified):**
- `--title` and `--body` are non-interactive when both provided
- `--label` accepts comma-separated values or multiple `--label` flags
- `--json url -q '.url'` returns only the URL, suitable for capture and downstream use
- `--repo` not needed when running inside the project repo (uses `origin` remote automatically)
- `--project title` flag exists but is unreliable for project board placement — use the two-step approach below instead

**Labels to standardise for silver-add:**
- `bug` — defect or broken behaviour
- `tech-debt` — code quality / architectural debt
- `enhancement` — deferred feature or improvement
- `question` — open question needing resolution
- `housekeeping` — cleanup, docs, configuration drift

### Adding Issue to Project Board (two-step)

`gh issue create --project` is unreliable when the project is org-scoped (it matches by title and can miss). Use the explicit two-step instead:

```bash
# Step 1: Add to project, capture item ID
ITEM_ID=$(gh project item-add <project-number> \
  --owner <org-or-user> \
  --url "$ISSUE_URL" \
  --format json | jq -r '.id')

# Step 2: Set Status field to "Backlog"
gh project item-edit \
  --project-id <project-node-id> \
  --id "$ITEM_ID" \
  --field-id <status-field-id> \
  --single-select-option-id <backlog-option-id>
```

**Known IDs for alo-exp/silver-bullet project (Silver Bullet, project #4):**

| Item | Value |
|------|-------|
| Project number | `4` |
| Project node ID | `PVT_kwDOA5OQY84BU8tb` |
| Status field ID | `PVTSSF_lADOA5OQY84BU8tbzhMcRXE` |
| Backlog option ID | `7e62dc72` |
| Todo option ID | `01205c50` |
| In Progress option ID | `8a08e86b` |
| Done option ID | `57588370` |

These IDs are stable (GraphQL node IDs do not change). Cache them in `.silver-bullet.json` under a `github_project` key during `silver-init` or first `silver-add` run, so skills do not need to re-query `gh project field-list` every invocation.

**Proposed `.silver-bullet.json` addition:**
```json
"issue_tracker": "github",
"github_project": {
  "owner": "alo-exp",
  "number": 4,
  "node_id": "PVT_kwDOA5OQY84BU8tb",
  "status_field_id": "PVTSSF_lADOA5OQY84BU8tbzhMcRXE",
  "backlog_option_id": "7e62dc72"
}
```

The `silver-add` skill reads these fields; if absent, falls back to `gh project list` + `gh project field-list` discovery and writes the result back.

### Discovering Project IDs (first-time / missing config)

```bash
# 1. Find project number and node ID
gh project list --owner <owner> --format json | jq '.projects[] | select(.title=="<project-title>") | {number, id}'

# 2. Find Status field ID and option IDs
gh project field-list <number> --owner <owner> --format json \
  | jq '.fields[] | select(.name=="Status") | {id, options}'
```

### Closing vs Deleting a GitHub Issue

`silver-remove` should **close** by default, not delete. Deletion is permanent and loses history. Use delete only when the item was filed by mistake (e.g., duplicate, test noise).

```bash
# Close with reason (preferred for silver-remove)
gh issue close <number> --reason "not planned" --comment "Removed via /silver-remove: <reason>"

# Delete permanently (only when --force flag passed to silver-remove)
gh issue delete <number> --yes
```

### Listing Issues by Label (for silver-scan dedup)

```bash
# Check if a similar issue already exists before filing
gh issue list \
  --label "tech-debt" \
  --state open \
  --json number,title,url \
  --search "<keywords>"
```

Use this in `silver-add` to surface potential duplicates before creating a new issue. Output a warning to the agent; do not block filing automatically.

---

## Local Fallback (no PM system — `issue_tracker: "gsd"`)

When `issue_tracker` is `"gsd"` or absent, `silver-add` writes to local markdown files. This is the default for projects not using GitHub Issues.

### File Structure

```
docs/
  ISSUES.md    — bugs, defects, broken behaviour (type: issue)
  BACKLOG.md   — enhancements, tech debt, housekeeping, questions (type: backlog)
```

### ID Assignment

Use a sequential integer scoped to the file. Each file maintains its own counter, independent of the other. ID format: `SB-<type>-<number>` where type is `I` (issue) or `B` (backlog).

```
SB-I-1, SB-I-2, ...   (docs/ISSUES.md)
SB-B-1, SB-B-2, ...   (docs/BACKLOG.md)
```

**ID generation approach:** Read the file, grep for existing IDs, take max + 1. No external counter file needed.

```bash
# Get next issue ID
NEXT=$(grep -oP 'SB-I-\K[0-9]+' docs/ISSUES.md 2>/dev/null | sort -n | tail -1)
NEXT_ID="SB-I-$((${NEXT:-0} + 1))"

# Get next backlog ID
NEXT=$(grep -oP 'SB-B-\K[0-9]+' docs/BACKLOG.md 2>/dev/null | sort -n | tail -1)
NEXT_ID="SB-B-$((${NEXT:-0} + 1))"
```

### Entry Format

Each entry is a level-3 heading followed by metadata and description. This makes entries parseable by grep/awk and human-readable.

```markdown
### SB-I-3 — Short title of the issue

**Type:** bug | tech-debt | enhancement | question | housekeeping
**Filed:** 2026-04-24
**Source:** session | scan | manual
**Status:** open

Description of the issue, what is broken or needed, and relevant context.

---
```

### Removal (silver-remove for local files)

Identify the entry by ID, then delete from heading to the next `---` separator.

```bash
# Delete entry block by ID (SB-I-3) using awk
awk '/^### SB-I-3 —/{found=1} found && /^---$/{print; found=0; next} !found{print}' \
  docs/ISSUES.md > docs/ISSUES.md.tmp && mv docs/ISSUES.md.tmp docs/ISSUES.md
```

The skill should print the deleted entry text before removing it, so the agent can confirm.

### Initialization

If `docs/ISSUES.md` or `docs/BACKLOG.md` do not exist, create them with a standard header on first `silver-add` call. Do not create them during `silver-init` — only on demand.

```markdown
# Issues

Bugs and defects filed via /silver-add. Managed by Silver Bullet.
Remove entries with /silver-remove <id>.

---
```

---

## Session Log Parsing

### Glob Pattern

Session logs follow the naming convention `docs/sessions/*.md`. This is established by `silver-init` Phase 3.6 which creates `docs/sessions/.gitkeep`.

```bash
# All session logs, sorted by filename (chronological by date-prefix)
ls docs/sessions/*.md 2>/dev/null | sort

# Or via find for more control
find docs/sessions -name "*.md" -type f | sort
```

The two confirmed log files follow `YYYY-MM-DD-<description>.md` and `YYYY-MM-DD-HH-MM-SS.md` naming — both are just `*.md` under `docs/sessions/`, so the glob catches both.

### Deferred Item Signals in Session Logs

Scan each session log for these textual signals, which indicate items that were deferred or not completed:

**Section-level signals** (look in these sections):
- `## Needs human review` — items flagged for human attention
- `## Autonomous decisions` — decisions made without user input that may need revisiting
- `## Outcome` — incomplete outcomes (look for "pending", "awaiting", "not yet", "deferred")

**Inline signals** (grep within body text):
```bash
# Patterns indicating deferred work
grep -iE "(deferred|skipped|TODO|FIXME|out of scope|not addressed|pending|future|follow-up|tech.?debt|open question)" \
  docs/sessions/*.md
```

**Structured grep for silver-scan:**
```bash
# Per-file scan with filename context
for f in docs/sessions/*.md; do
  echo "=== $f ==="
  grep -n -iE "(deferred|skipped|TODO|FIXME|not addressed|pending|follow.?up|tech.?debt|open question|out of scope)" "$f"
done
```

### Git History Parsing

Use `git log` to surface commits that mention deferrals or known-issue markers:

```bash
# Commits mentioning deferrals (last 200 commits, or since a given date)
git log --oneline --since="<milestone-start-date>" \
  --grep="TODO\|FIXME\|deferred\|skip\|workaround\|tech.debt" -i

# Full commit messages for candidate commits
git log --format="%H %s%n%b" --since="<milestone-start-date>" \
  | grep -A5 -iE "(TODO|FIXME|deferred|tech.?debt)"
```

For `/silver-scan`, the skill should:
1. Prompt the user for a date range (or default to since last release tag)
2. Glob all `docs/sessions/*.md` files in that range by filename date prefix
3. Run the grep patterns above across session logs
4. Run git log grep across commit history
5. Deduplicate findings (same text appearing in both session log and commit)
6. Present findings with relevance context; ask which to file via `silver-add`

### Existing Issue Dedup

Before prompting the user to file a found item, check against open GitHub issues (if `issue_tracker: "github"`) or grep local markdown files (if local):

```bash
# GitHub dedup
gh issue list --state open --json number,title | jq '.[] | .title'

# Local dedup
grep "^### SB-" docs/ISSUES.md docs/BACKLOG.md 2>/dev/null
```

---

## Auto-Capture Enforcement

Auto-capture means the skills that orchestrate work (silver-feature, silver-bugfix, silver-devops, silver-ui) instruct the coding agent to call `/silver:add` whenever it defers, descopes, or skips an item. This is a skill-level instruction change, not a hook.

The routing logic already partially exists in `silver-feature` SKILL.md (Step 7 and Step 18). The v0.25.0 change replaces the inline `gsd-add-backlog` calls with `silver-add` skill invocations:

**Before (current):**
```
Skill(skill="gsd-add-backlog", args="<description>")
```

**After (v0.25.0):**
```
Skill(skill="silver-add", args="<description>")
```

The `silver-add` skill handles routing to GitHub or local based on `issue_tracker` — the orchestrating skills no longer need to know about routing. This is the correct abstraction boundary.

---

## Verdict

**Use gh CLI for all GitHub operations.** No GraphQL API calls directly — `gh project item-add` and `gh project item-edit` expose the GitHub Projects V2 GraphQL API through a verified CLI interface. The `project` scope is already granted on this machine.

**Two-step issue + board placement** is the correct pattern. The `--project` flag on `gh issue create` is unreliable for org-scoped projects; explicit `item-add` + `item-edit` is deterministic.

**Cache project IDs in `.silver-bullet.json`** under a `github_project` key. One-time discovery via `gh project list` + `gh project field-list`, then read from config on every subsequent call. This avoids one extra API round-trip per `silver-add` invocation.

**Local fallback uses `SB-I-N` / `SB-B-N` IDs** in `docs/ISSUES.md` and `docs/BACKLOG.md`. Sequential integer, grep-derived, no counter file. Markdown heading structure makes entries grep-parseable for dedup and removal.

**Session log scanning uses `docs/sessions/*.md` glob + keyword grep.** No parser library needed — the session log format is unstructured markdown, and keyword matching with `grep -iE` is sufficient. Git log `--grep` supplements with commit-level signals.

**No new tools or runtimes required.** `jq`, `gh`, `git`, and `grep` are already available in the SB environment. The four new skills are SKILL.md files only — no new shell scripts or Node.js modules needed beyond what already exists.

---

*Stack research for: Silver Bullet v0.25.0 — Issue Capture & Retrospective Scan*
*Researched: 2026-04-24*
