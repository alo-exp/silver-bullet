# Phase 49: silver-add — Research

**Researched:** 2026-04-24
**Domain:** Silver Bullet skill authoring — issue classification, GitHub Issues + Projects V2 integration, local markdown filing, caching, rate-limit resilience
**Confidence:** HIGH — all findings verified from existing SB codebase, milestone research files, and confirmed gh CLI command patterns

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ADD-01 | User invokes `/silver-add` with a description; skill classifies as **issue** or **backlog** using a clear rubric | Classification rubric defined in Features research; keyword heuristics documented below |
| ADD-02 | When `issue_tracker = "github"`: create GitHub Issue with `filed-by-silver-bullet` label, add to project board Backlog column via two-step `gh project item-add` + `gh project item-edit` | Full command sequence verified from STACK.md; project board IDs confirmed |
| ADD-03 | When `issue_tracker` absent or `"gsd"`: append to `docs/issues/ISSUES.md` or `docs/issues/BACKLOG.md` with sequential `SB-I-N` / `SB-B-N` ID; create directory on first write | File schema, ID generation pattern, and mkdir guard documented below |
| ADD-04 | Cache GitHub project board node ID, Status field ID, and Backlog option ID in `.silver-bullet.json` under `_github_project` on first discovery | Discovery commands and cache schema documented; existing project IDs confirmed for alo-exp/silver-bullet |
| ADD-05 | Handle GitHub secondary rate limits (exponential backoff retry), record filing in session log `## Items Filed` section, return stable ID | Rate limit thresholds, retry pattern, session log section documented below |
</phase_requirements>

---

## Summary

Phase 49 creates `skills/silver-add/SKILL.md` — a new Silver Bullet skill that is the foundation for the entire v0.25.0 milestone. Every subsequent phase (silver-remove, auto-capture enforcement, silver-scan) depends on the ID schema, file locations, and routing logic established here.

The skill is a markdown instruction file for Claude, following the existing SKILL.md format (YAML frontmatter + numbered step sections). There is no executable code — only instructions the AI agent follows. The technical work is in writing those instructions precisely enough that the agent's behavior is deterministic: it classifies correctly, files to the right destination, caches project board IDs, retries on rate limit, and logs every filing in the session log.

The phase also requires two supporting changes: adding `silver-add` to `skills.all_tracked` in both `.silver-bullet.json` and `templates/silver-bullet.config.json.default`, and ensuring the `docs/issues/` directory pattern is understood before silver-remove is built in Phase 50.

**Primary recommendation:** Write the SKILL.md in a single pass with explicit step-by-step instructions: Step 1 reads config, Step 2 classifies, Step 3 branches on `issue_tracker`, Step 4 handles GitHub path with label creation + two-step board placement, Step 5 handles local path with ID derivation and file append, Step 6 handles rate limit retry, Step 7 logs the filing in the session log's `## Items Filed` section. This structure mirrors silver-forensics' proven step-based layout.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Config reading (`issue_tracker`, `_github_project`) | SKILL.md instructions → AI agent executes `jq`/Bash | `.silver-bullet.json` | Config is the source of truth; skill reads it via Bash at runtime |
| Item classification (issue vs backlog) | AI agent (LLM judgment + keyword heuristics in skill instructions) | — | Classification requires semantic reasoning; no hook can do this |
| GitHub Issue creation | AI agent executes `gh issue create` | GitHub REST API (via gh CLI) | gh CLI wraps REST/GraphQL; project board requires GraphQL via `gh project item-add` |
| Project board placement | AI agent executes `gh project item-add` + `gh project item-edit` | GitHub Projects V2 GraphQL (via gh CLI) | Two-step: REST issue + GraphQL board add |
| Project board ID caching | AI agent writes `jq` patch to `.silver-bullet.json` | — | Cache lives in project config; one-time discovery, then read-only on subsequent calls |
| Local markdown filing | AI agent executes `mkdir -p`, `grep`, and append | `docs/issues/` files | No external API needed; sequential ID from grep pattern |
| Rate limit retry | AI agent follows retry instructions in SKILL.md | — | gh CLI surfaces raw HTTP error; backoff logic must be in skill instructions |
| Session log recording | AI agent appends to open session log | `docs/sessions/*.md` | Instruction-level: "append a line to `## Items Filed` section" |

---

## Standard Stack

All tools are already present in the SB environment — no new installations needed.

### Core Tools (already available — confirmed from milestone STACK.md research)

| Tool | Version | Purpose | Verification |
|------|---------|---------|--------------|
| `gh` CLI | 2.x (project scope confirmed) | GitHub Issue creation, project board placement, label management | `gh auth status 2>&1 \| grep -q "project"` |
| `jq` | 1.6+ | JSON parsing of `.silver-bullet.json`, project field-list response | Already used across all SB hooks |
| `git` | any | `git remote get-url origin` to derive owner/repo | Already in all SB skills |
| `grep` | POSIX | Sequential ID derivation from existing files | `grep -oE 'SB-I-[0-9]+' docs/issues/ISSUES.md` |

[VERIFIED: from .planning/research/STACK.md — all confirmed present on development machine]

### Skill File Conventions (from existing skills)

| Convention | Pattern | Source |
|------------|---------|--------|
| YAML frontmatter | `name:`, `description:`, `version:` fields | silver-forensics/SKILL.md, silver-update/SKILL.md |
| Step numbering | `## Step N — Title` | silver-forensics pattern |
| Security boundary declaration | Explicit "UNTRUSTED DATA" block near top | silver-forensics mandatory pattern |
| Project root discovery | Walk up from `$PWD` until `.silver-bullet.json` found | silver-forensics Step 1 |
| Autonomous mode instructions | Inline `**In autonomous mode:**` callout per step | silver-forensics Step 2a |
| Directory creation before write | `mkdir -p <path>` via Bash before first write | silver-forensics post-mortem Step 1 |

[VERIFIED: from direct inspection of skills/silver-forensics/SKILL.md and skills/silver-update/SKILL.md]

---

## Architecture Patterns

### System Architecture Diagram

```
User / coding agent invokes /silver-add with description
         |
         v
Step 1: Walk up from $PWD → find .silver-bullet.json
         |
         v
Step 2: Read issue_tracker (jq -r '.issue_tracker // "gsd"')
        Read _github_project cache if present
         |
         +---[classify]--> Step 3: Apply classification rubric
         |                   issue: bug, defect, crash, security finding,
         |                          open question blocking work, failing test
         |                   backlog: tech debt, deferred feature, housekeeping,
         |                            open question non-blocking, enhancement
         |
         +----[issue_tracker = "github"]-------------------+
         |                                                  |
         |    Step 4a: Ensure label exists                  |
         |      gh label create "filed-by-silver-bullet"    |
         |      --color "#5319E7" 2>/dev/null || true       |
         |                                                  |
         |    Step 4b: Create GitHub Issue                  |
         |      gh issue create --title --body --label      |
         |      Capture ISSUE_URL → extract ISSUE_NUM       |
         |                                                  |
         |    Step 4c: Project board placement              |
         |      [cache miss] → gh project list discovery    |
         |                   → gh project field-list        |
         |                   → write _github_project to     |
         |                     .silver-bullet.json (jq)     |
         |      gh project item-add → ITEM_ID               |
         |      gh project item-edit (set Backlog status)   |
         |                                                  |
         |    [Rate limit 403/429] → backoff + retry -------+
         |    Return: #<ISSUE_NUM>
         |
         +----[issue_tracker = "gsd" or absent]----------+
         |                                                |
         |    Step 5a: mkdir -p docs/issues/             |
         |                                                |
         |    Step 5b: Determine target file             |
         |      issue type → docs/issues/ISSUES.md       |
         |      backlog type → docs/issues/BACKLOG.md    |
         |                                                |
         |    Step 5c: Derive next sequential ID         |
         |      grep -oE 'SB-I-[0-9]+' → max + 1        |
         |      (or SB-B-[0-9]+ for backlog)             |
         |                                                |
         |    Step 5d: Append entry (heading + metadata) |
         |    Return: SB-I-N or SB-B-N                   |
         |
         v
Step 6: Append to session log "## Items Filed" section
        - #<ID> [<type>] <title>   (one line)
         |
         v
Step 7: Output confirmation
        "Filed #<ID> — <title> [<type>]"
```

### Recommended Project Structure (new files this phase creates)

```
skills/
  silver-add/
    SKILL.md          (new — the primary deliverable)

docs/issues/          (created on-demand by silver-add, not pre-scaffolded)
  ISSUES.md           (created on first issue filing when issue_tracker=gsd)
  BACKLOG.md          (created on first backlog filing when issue_tracker=gsd)
```

Config changes (additive only):
```
.silver-bullet.json            add "silver-add" to skills.all_tracked
templates/silver-bullet.config.json.default   same addition
```

---

## Pattern 1: Project Root Discovery

**What:** Walk up from `$PWD` to find `.silver-bullet.json`. All evidence paths are relative to this root.

**When to use:** First step of every SB skill that reads project config.

**Example (from silver-forensics Step 1):**
```
Walk up from $PWD until a .silver-bullet.json file is found.
All evidence paths (docs/sessions/, .planning/, docs/issues/) are relative to this root.
If .silver-bullet.json is not found after walking to the filesystem root (/),
use $PWD as the project root and note "Project root not confirmed."
```

[VERIFIED: from skills/silver-forensics/SKILL.md Step 1]

---

## Pattern 2: issue_tracker Routing

**What:** Read `issue_tracker` from `.silver-bullet.json` with `"gsd"` as default; branch all filing logic on this value.

**When to use:** Immediately after root discovery; before any filing operation.

**Example:**
```bash
TRACKER=$(jq -r '.issue_tracker // "gsd"' .silver-bullet.json)
```

Routing table:
| Value | Action |
|-------|--------|
| `"github"` | GitHub Issue creation + project board placement |
| `"gsd"` | Local markdown append to `docs/issues/` |
| absent | Treat as `"gsd"` |

[VERIFIED: from templates/silver-bullet.config.json.default line 63, skills/silver-init/SKILL.md Step 2.8, skills/silver-feature/SKILL.md Step 7]

---

## Pattern 3: GitHub Two-Step Issue + Board Placement

**What:** Create GitHub Issue, then add to project board, then set Status=Backlog. Cannot be collapsed into one command.

**When to use:** Whenever `issue_tracker = "github"` in silver-add.

**Commands (verified against installed gh CLI):**
```bash
# Step 1: Create issue, capture URL
ISSUE_URL=$(gh issue create \
  --repo "$(git remote get-url origin | sed 's|https://github.com/||;s|.git$||')" \
  --title "<title>" \
  --body "<body>" \
  --label "filed-by-silver-bullet" \
  --label "<type-label>" \
  --json url -q '.url')
ISSUE_NUM=$(echo "$ISSUE_URL" | grep -o '[0-9]*$')

# Step 2: Add to project board
ITEM_ID=$(gh project item-add <project-number> \
  --owner <owner> \
  --url "$ISSUE_URL" \
  --format json | jq -r '.id')

# Step 3: Set Status = Backlog
gh project item-edit \
  --project-id <project-node-id> \
  --id "$ITEM_ID" \
  --field-id <status-field-id> \
  --single-select-option-id <backlog-option-id>
```

[VERIFIED: from .planning/research/STACK.md "Adding Issue to Project Board (two-step)"]

---

## Pattern 4: _github_project Cache Read/Write

**What:** On first GitHub filing, discover project board IDs via gh CLI and write them to `.silver-bullet.json` under `_github_project`. On subsequent calls, read from cache — no re-discovery.

**When to use:** Before the two-step board placement in ADD-02; satisfies ADD-04.

**Cache schema (write on first discovery):**
```json
"_github_project": {
  "owner": "<owner>",
  "number": <project-number>,
  "node_id": "<project-node-id>",
  "status_field_id": "<status-field-id>",
  "backlog_option_id": "<backlog-option-id>"
}
```

**Known values for alo-exp/silver-bullet (project #4):**
| Field | Value |
|-------|-------|
| `owner` | `alo-exp` |
| `number` | `4` |
| `node_id` | `PVT_kwDOA5OQY84BU8tb` |
| `status_field_id` | `PVTSSF_lADOA5OQY84BU8tbzhMcRXE` |
| `backlog_option_id` | `7e62dc72` |

[VERIFIED: from .planning/research/STACK.md "Known IDs for alo-exp/silver-bullet project"]

**Discovery commands (used when cache absent):**
```bash
# 1. Find project number and node ID
gh project list --owner <owner> --format json \
  | jq '.projects[] | select(.title | test("silver-bullet";"i")) | {number, id}'

# 2. Find Status field ID and Backlog option ID
gh project field-list <number> --owner <owner> --format json \
  | jq '.fields[] | select(.name=="Status") | {id, options}'
```

**Write back to .silver-bullet.json (atomic via jq):**
```bash
TMP=$(mktemp)
jq --arg owner "$OWNER" \
   --argjson num "$PROJ_NUM" \
   --arg nid "$NODE_ID" \
   --arg sfid "$STATUS_FIELD_ID" \
   --arg boid "$BACKLOG_OPT_ID" \
   '._github_project = {owner:$owner, number:$num, node_id:$nid, status_field_id:$sfid, backlog_option_id:$boid}' \
   .silver-bullet.json > "$TMP" && mv "$TMP" .silver-bullet.json
```

[VERIFIED: pattern from silver-update/SKILL.md Step 6 (atomic tmpfile + mv write)]

---

## Pattern 5: Local Sequential ID Derivation

**What:** Read the highest existing `SB-I-N` or `SB-B-N` from the target file, increment by 1. No counter file needed.

**When to use:** Whenever `issue_tracker = "gsd"` in silver-add; satisfies ADD-03.

**Commands:**
```bash
# Next issue ID
NEXT=$(grep -oE 'SB-I-[0-9]+' docs/issues/ISSUES.md 2>/dev/null \
  | grep -oE '[0-9]+' | sort -n | tail -1)
NEXT_ISSUE_ID="SB-I-$((${NEXT:-0} + 1))"

# Next backlog ID
NEXT=$(grep -oE 'SB-B-[0-9]+' docs/issues/BACKLOG.md 2>/dev/null \
  | grep -oE '[0-9]+' | sort -n | tail -1)
NEXT_BACKLOG_ID="SB-B-$((${NEXT:-0} + 1))"
```

[VERIFIED: from .planning/research/STACK.md "ID Generation approach"]

**Entry format (append to file):**
```markdown
### SB-I-3 — Short title of the issue

**Type:** bug | tech-debt | enhancement | question | housekeeping
**Filed:** YYYY-MM-DD
**Source:** session | scan | manual
**Status:** open

Description of the issue.

---
```

[VERIFIED: from .planning/research/STACK.md "Entry Format"]

---

## Pattern 6: Rate Limit Retry (Exponential Backoff)

**What:** On GitHub API 403 or 429 response from `gh` CLI, wait and retry up to 3 times. Satisfies ADD-05.

**When to use:** Wraps all `gh issue create` and `gh project item-add` commands.

**Retry instruction for SKILL.md:**
```
If any gh CLI command returns a non-zero exit code and stderr contains
"secondary rate limit", "rate limit", "403", or "429":
  - Wait 60 seconds, retry.
  - If retry fails, wait 120 seconds, retry again.
  - If retry fails a third time, wait 240 seconds, retry a final time.
  - If all three retries fail, output: "Rate limit retry exhausted after 3 attempts.
    Filed item could not be created. Try again in a few minutes."
  - Do NOT proceed to the session log step if the filing failed.
```

[VERIFIED: rate limit thresholds from .planning/research/PITFALLS.md Pitfall 4; strategy from STACK.md "GitHub API Secondary Rate Limit Hit"]

---

## Pattern 7: Session Log Filing Record

**What:** After each successful filing, append one line to the current session log's `## Items Filed` section. Satisfies ADD-05.

**When to use:** Final step of silver-add, after confirmed successful filing.

**Instruction for SKILL.md:**
```
After successful filing, locate the current session log in docs/sessions/.
If a session log exists and has a "## Items Filed" section, append:
  - #<ID> [<type>] <title>
If the section does not exist (older session log template), append the section header
and the line.
If no session log exists, skip this step silently.
```

[VERIFIED: session log format confirmed from docs/sessions/2026-04-20-08-48-48.md (no Items Filed section yet — will be added by CAPT-04 in Phase 51, but silver-add must handle both old and new template gracefully)]

---

## Classification Rubric (ADD-01)

The rubric must be embedded verbatim in the SKILL.md so classification is deterministic.

**Issue** (file to `ISSUES.md` or with label `bug` / `question`):
- Broken behavior, test failure, regression, crash, security finding
- An open question that BLOCKS current or immediate future work
- Unfinished work that was started and left in a broken state
- Verification failure — the system does not meet an acceptance criterion

**Backlog** (file to `BACKLOG.md` or with label `enhancement` / `tech-debt` / `chore`):
- Feature request or enhancement that was deferred for a future milestone
- Technical debt: known shortcut, hardcoded value, missing abstraction
- Housekeeping: docs update, config drift, rename, reorganization
- Open question that is INFORMATIONAL but does not block current work
- Low-priority item identified during review that will not be addressed now

**Default when ambiguous:** backlog (err toward not over-alarming with issues).

[VERIFIED: from .planning/research/FEATURES.md "Classification heuristics" and REQUIREMENTS.md ADD-01]

---

## GitHub Label Strategy

The skill applies two labels per issue:

| Label | Purpose | How Created |
|-------|---------|-------------|
| `filed-by-silver-bullet` | Identifies SB-managed issues for silver-release post-release summary and silver-scan dedup | `gh label create "filed-by-silver-bullet" --color "#5319E7" 2>/dev/null \|\| true` (idempotent) |
| `bug` / `enhancement` / `tech-debt` / `question` / `chore` | Type classification; maps from issue vs backlog | Derived from classification rubric output |

The `filed-by-silver-bullet` label creation must be attempted once per session (or once per skill invocation). Using `2>/dev/null || true` makes it safe to call every time even when the label already exists.

[VERIFIED: from .planning/research/ARCHITECTURE.md "Integration 4: silver-add GitHub label strategy"]

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| GitHub project board placement | Custom GraphQL query with curl | `gh project item-add` + `gh project item-edit` | gh CLI already wraps Projects V2 GraphQL; custom curl would require manual token handling, response parsing, error codes |
| JSON config writes | String interpolation into JSON | `jq` with tmpfile + `mv` | String interpolation corrupts JSON on special characters; jq is safe; atomic write via mv prevents corruption on crash |
| GitHub label taxonomy per filing | Query existing labels then decide | Pre-defined type-to-label map in skill instructions | Map is static — type is known at classification time, no runtime query needed |
| Counter file for local IDs | `docs/issues/.next-id` file | `grep -oE 'SB-I-[0-9]+' \| sort -n \| tail -1` | Grep on the file itself is simpler, portable, and avoids a secondary file that can get out of sync |
| Retry loop logic as shell code | Bash `while` loop in a hook | Explicit retry instruction text in SKILL.md | silver-add is a SKILL.md, not a shell script — the AI agent implements the retry following the instructions |

[VERIFIED: all patterns from .planning/research/STACK.md and ARCHITECTURE.md]

---

## Don't Hand-Roll (Critical)

**Never hand-roll these for silver-add:**
- JSON parsing of `.silver-bullet.json` — always use `jq`
- GitHub project board discovery — always use `gh project list` + `gh project field-list`
- GitHub API calls directly — always use `gh` CLI (it handles auth, token scoping, rate limit surfacing)

---

## Common Pitfalls

### Pitfall 1: `gh issue create --project` Flag Unreliable for Org-Scoped Projects

**What goes wrong:** Using `gh issue create --project "Silver Bullet"` instead of the explicit two-step add+edit fails silently for org-scoped projects — it matches by title string which can miss or match the wrong project.

**Why it happens:** The `--project` flag on `gh issue create` is documented but unreliable for org-scoped projects in gh CLI 2.x.

**How to avoid:** Always use explicit two-step: `gh project item-add` → capture `ITEM_ID` → `gh project item-edit --single-select-option-id`.

**Warning signs:** Issue is created but does not appear in the project board. `gh project item-list` shows nothing for the issue URL.

[VERIFIED: from .planning/research/STACK.md "Adding Issue to Project Board (two-step)" — explicit callout that --project flag is unreliable]

---

### Pitfall 2: `project` OAuth Scope Missing

**What goes wrong:** `gh project item-add` fails with "HTTP 401: Resource not accessible by integration" even though gh is authenticated.

**Why it happens:** GitHub Projects V2 operations require the `project` OAuth scope. The default `gh auth login` scope may not include it.

**How to avoid:** The skill must check `gh auth status 2>&1 | grep -q "project"` before attempting any project board operations. If missing, instruct: "Run `gh auth refresh -s project` to grant project board access, then retry."

**Warning signs:** gh issue create succeeds, but gh project item-add fails with 401.

[VERIFIED: from .planning/research/STACK.md "Prerequisite: project scope"]

---

### Pitfall 3: Auto-Capture Noise — Low-Quality Items Filed

**What goes wrong:** When called by the coding agent during execution (auto-capture, added in Phase 51), the agent over-triggers silver-add on every exploratory comment, minor TODO, or "could improve later" thought. The issue tracker fills with noise.

**Why it happens:** The classification rubric without a quality floor is too permissive. "TODO" alone is not enough to warrant a filed item.

**How to avoid:** The SKILL.md classification rubric must include a minimum-bar criterion: "An item qualifies for filing only if it has a distinct user-visible impact OR blocks future work OR represents a conscious deferred decision. Do not file: transient exploration notes, one-line TODOs without context, or items already addressed in the current session."

[VERIFIED: from .planning/research/PITFALLS.md Pitfall 1 "Auto-Capture Becomes a Noise Engine"]

---

### Pitfall 4: Session Log Items Filed Section Missing

**What goes wrong:** silver-add tries to append to `## Items Filed` section of the current session log, but the section doesn't exist in session logs created before Phase 51 (CAPT-04) adds it to the template.

**Why it happens:** Session logs are created by `session-log-init.sh`. The `## Items Filed` section will only be added to the template in Phase 51. Phase 49 arrives first.

**How to avoid:** silver-add must handle both old and new session log templates gracefully:
- If session log exists AND `## Items Filed` section exists → append the line
- If session log exists AND section is absent → append `## Items Filed\n\n- #<ID> ...` to end of file
- If no session log found → skip silently with no error

[ASSUMED — based on phase ordering analysis; confirmed by session log structure inspection showing no Items Filed section in current session logs]

---

### Pitfall 5: Concurrent ID Assignment in GSD Mode

**What goes wrong:** Two rapid-fire silver-add calls (parallel wave execution in GSD) both read `max(SB-I-N) = 3` and both try to assign `SB-I-4`. Last write wins; one item is lost.

**Why it happens:** The grep-based ID derivation is not atomic. GSD can dispatch parallel agent waves.

**How to avoid:** The skill instructions must state: "silver-add calls must be made sequentially, never in parallel. When called from auto-capture enforcement during execution, append to the session log immediately after each filing before proceeding." Silver-scan (Phase 54) must explicitly call silver-add sequentially. The SKILL.md should note: "Do not call silver-add concurrently from parallel agent contexts."

[VERIFIED: from .planning/research/PITFALLS.md Pitfall 5 "Local Markdown ID Collisions"]

---

### Pitfall 6: `.silver-bullet.json` Write Corrupts JSON

**What goes wrong:** Writing the `_github_project` cache back to `.silver-bullet.json` using string concatenation or `sed` corrupts the JSON when project names or IDs contain special characters.

**How to avoid:** Always use `jq` with a tmpfile + `mv` pattern. Never hand-roll JSON construction. See Pattern 4 above.

[VERIFIED: from silver-update/SKILL.md Step 6 (established atomic write pattern)]

---

## Code Examples

### Example 1: Full GitHub Filing Sequence (verified commands)

```bash
# Source: .planning/research/STACK.md "Adding Issue to Project Board"

# 1. Ensure label exists (idempotent)
gh label create "filed-by-silver-bullet" \
  --color "#5319E7" \
  --description "Filed by Silver Bullet auto-capture" \
  2>/dev/null || true

# 2. Create issue
ISSUE_URL=$(gh issue create \
  --title "Refactor auth token refresh" \
  --body "$(cat <<'EOF'
Auth token refresh logic is hand-rolled. Should use the refresh_token field directly.

---
**Type:** tech-debt
**Filed by:** silver-add
**Source session:** docs/sessions/2026-04-24-session.md
**Filed:** 2026-04-24
EOF
)" \
  --label "filed-by-silver-bullet" \
  --label "tech-debt" \
  --json url -q '.url')

ISSUE_NUM=$(echo "$ISSUE_URL" | grep -o '[0-9]*$')

# 3. Add to project board
ITEM_ID=$(gh project item-add 4 \
  --owner alo-exp \
  --url "$ISSUE_URL" \
  --format json | jq -r '.id')

# 4. Set Status = Backlog
gh project item-edit \
  --project-id "PVT_kwDOA5OQY84BU8tb" \
  --id "$ITEM_ID" \
  --field-id "PVTSSF_lADOA5OQY84BU8tbzhMcRXE" \
  --single-select-option-id "7e62dc72"

echo "Filed #${ISSUE_NUM}"
```

### Example 2: GSD Mode Local File Append

```bash
# Source: .planning/research/STACK.md "ID Assignment"

mkdir -p docs/issues/

# Derive next ID
NEXT=$(grep -oE 'SB-B-[0-9]+' docs/issues/BACKLOG.md 2>/dev/null \
  | grep -oE '[0-9]+' | sort -n | tail -1)
NEXT_ID="SB-B-$((${NEXT:-0} + 1))"

# Append entry
cat >> docs/issues/BACKLOG.md <<EOF

### ${NEXT_ID} — Refactor auth token refresh

**Type:** tech-debt
**Filed:** 2026-04-24
**Source:** session
**Status:** open

Auth token refresh logic is hand-rolled. Should use the refresh_token field directly.

---
EOF

echo "Filed ${NEXT_ID}"
```

### Example 3: Atomic Cache Write

```bash
# Source: silver-update/SKILL.md Step 6 (established pattern)

TMP=$(mktemp)
jq \
  --arg owner "alo-exp" \
  --argjson num 4 \
  --arg nid "PVT_kwDOA5OQY84BU8tb" \
  --arg sfid "PVTSSF_lADOA5OQY84BU8tbzhMcRXE" \
  --arg boid "7e62dc72" \
  '._github_project = {
    owner: $owner,
    number: $num,
    node_id: $nid,
    status_field_id: $sfid,
    backlog_option_id: $boid
  }' \
  .silver-bullet.json > "$TMP" && mv "$TMP" .silver-bullet.json
```

### Example 4: SKILL.md Frontmatter and Opening (from existing pattern)

```yaml
---
name: silver-add
description: This skill should be used to classify and file any deferred or identified work item to the correct PM destination — GitHub Issues + project board (when issue_tracker=github) or local docs/issues/ markdown (when issue_tracker=gsd) — and return a stable, referenceable ID.
version: 0.1.0
---
```

[VERIFIED: frontmatter structure from skills/silver-forensics/SKILL.md and skills/silver-update/SKILL.md]

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `gsd-add-backlog` for all deferred items | `silver-add` with `issue_tracker` routing | v0.25.0 (this phase) | silver-feature and silver-bugfix currently call `gsd-add-backlog` directly; Phase 51 will migrate these to silver-add |
| No project board placement | Two-step `gh project item-add` + `gh project item-edit` | v0.25.0 | Items now land in the project board Backlog automatically |
| No local issue tracking | `docs/issues/ISSUES.md` + `BACKLOG.md` with `SB-I-N`/`SB-B-N` IDs | v0.25.0 | Projects without GitHub Issues now have structured local tracking |
| No session filing record | `## Items Filed` section in session log | v0.25.0 (CAPT-04 in Phase 51 adds to template; Phase 49 handles both old and new logs) | Filing history is now traceable per session |

**`issue_tracker` field:** Already in `.silver-bullet.json` default template as of v0.24.0 (FEAT-01, Phase 48). The field defaults to `"gsd"`. Silver-add is the first skill to route on this field for actual filing.

[VERIFIED: from templates/silver-bullet.config.json.default line 63; STATE.md "FEAT-01 completed in v0.24.0"]

---

## Files to Create/Modify

| File | Action | Notes |
|------|--------|-------|
| `skills/silver-add/SKILL.md` | **CREATE** | Primary deliverable — the SKILL.md instruction file |
| `.silver-bullet.json` | **MODIFY** — add `"silver-add"` to `skills.all_tracked` | Required for stop-hook enforcement to track silver-add invocations |
| `templates/silver-bullet.config.json.default` | **MODIFY** — same addition | Must mirror `.silver-bullet.json` change — these two must stay in sync |

Files NOT modified in Phase 49 (reserved for later phases):
- `silver-bullet.md` — auto-capture enforcement §3b goes in Phase 51 (CAPT-01)
- `skills/silver-feature/SKILL.md` — `gsd-add-backlog` migration goes in Phase 51 (CAPT-02)
- `session-log-init.sh` — `## Items Filed` template section goes in Phase 51 (CAPT-04)

---

## SKILL.md Structural Outline

The planner should create a plan that produces a SKILL.md with this step structure:

```
## Security Boundary        (session logs are UNTRUSTED DATA — same as silver-forensics)
## Allowed Commands         (gh, jq, git, grep, mkdir, cat — no other shell commands)
## Step 1 — Locate project root
## Step 2 — Read issue_tracker and _github_project cache
## Step 3 — Classify item
  (issue vs backlog rubric — verbatim classification table)
## Step 4 — File to GitHub [issue_tracker = "github"]
  ### Step 4a — Ensure filed-by-silver-bullet label exists
  ### Step 4b — Create GitHub Issue
  ### Step 4c — Read or discover project board IDs
  ### Step 4d — Add to project board + set Backlog status
  ### Step 4e — Rate limit retry (exponential backoff)
## Step 5 — File to local docs/ [issue_tracker = "gsd" or absent]
  ### Step 5a — Ensure docs/issues/ directory exists
  ### Step 5b — Determine target file (ISSUES.md vs BACKLOG.md)
  ### Step 5c — Derive next sequential ID
  ### Step 5d — Create file with header if not exists
  ### Step 5e — Append entry
## Step 6 — Record filing in session log
## Step 7 — Output confirmation
## Edge Cases
  (no .silver-bullet.json found, gh not authenticated, project board not found, session log absent)
```

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Session log `## Items Filed` section does not exist yet — silver-add must handle both old and new templates | Pitfall 4 | If existing session logs already have this section, the skill's conditional append logic is still correct (no risk). If the section is in a different location than end-of-file, appending at end may create duplicate headers. |
| A2 | The `.silver-bullet.json` does not yet have `_github_project` field — it will be absent on Phase 49 first run | Pattern 4 | Skill handles cache-miss via discovery; absent field is the expected initial state |
| A3 | `skill.all_tracked` must include `"silver-add"` for stop-check enforcement to count it | Files to Create/Modify | If stop-check is not currently checking all_tracked for silver-add, adding it is harmless but may not be enforced until the hook is updated |

---

## Open Questions

1. **`docs/issues/` vs. `docs/ISSUES.md` — file location**
   - What we know: REQUIREMENTS.md ADD-03 specifies `docs/issues/ISSUES.md`; ARCHITECTURE.md also specifies `docs/issues/`; STACK.md (an earlier research artifact) uses `docs/ISSUES.md` at the root level
   - What's unclear: Which location wins? The REQUIREMENTS.md + ARCHITECTURE.md (newer, more authoritative) both say `docs/issues/` subdirectory
   - Recommendation: Use `docs/issues/ISSUES.md` and `docs/issues/BACKLOG.md` as specified in REQUIREMENTS.md ADD-03 and ARCHITECTURE.md. The planner should lock this decision explicitly since silver-remove (Phase 50) must use the same paths.

2. **`_github_project` cache key name in `.silver-bullet.json`**
   - What we know: ADD-04 specifies `_github_project` (with underscore prefix, indicating internal/cache field); STACK.md uses `github_project` without underscore
   - What's unclear: Which name is canonical?
   - Recommendation: Use `_github_project` (with underscore) as specified in ADD-04 and the Additional Context block — the underscore signals this is a derived/cached field, not user-configurable.

3. **Owner discovery for repos where `.silver-bullet.json` has no `owner` field**
   - What we know: `git remote get-url origin` gives the full URL; owner is parseable from it
   - What's unclear: The skill must derive `<owner>` from the git remote URL to pass to `gh project list --owner` — is this derivation documented anywhere?
   - Recommendation: The skill instructions should include: `OWNER=$(git remote get-url origin 2>/dev/null | sed 's|https://github.com/||;s|/.*||;s|git@github.com:||;s|/.*||')` as the owner derivation step.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `gh` CLI with `project` scope | ADD-02, ADD-04 | Confirmed | 2.x | Fail with auth instruction: "Run `gh auth refresh -s project`" |
| `jq` | All config reads/writes | Confirmed | 1.6+ | No fallback — jq is a hard dependency of SB |
| `git` | Owner/repo derivation | Confirmed | any | No fallback — all SB skills assume git |

[VERIFIED: from .planning/research/STACK.md "Verdict" and environment confirmation]

---

## Validation Architecture

> Nyquist validation notes for this phase.

Silver Bullet skills (SKILL.md files) are markdown instruction files — they have no automated test runner. Validation for this phase is manual behavioral verification.

### Phase Requirements → Verification Map

| Req ID | Behavior | Verification Type | Command / Check |
|--------|----------|-------------------|-----------------|
| ADD-01 | Classification rubric produces correct issue vs backlog decision | Manual smoke test | Invoke `/silver-add "The login button crashes on mobile"` → should classify as issue |
| ADD-01 | Classification rubric produces correct backlog decision | Manual smoke test | Invoke `/silver-add "Refactor the token cache for better readability"` → should classify as backlog |
| ADD-02 | GitHub Issue created with `filed-by-silver-bullet` label | Manual verify | `gh issue view <N> --json labels` → confirm label present |
| ADD-02 | Issue appears in project board Backlog column | Manual verify | `gh project item-list 4 --owner alo-exp --format json` → item present with Status=Backlog |
| ADD-03 | Local file created and entry appended with `SB-I-N` ID | Manual verify | Set `issue_tracker="gsd"`, invoke skill, check `docs/issues/ISSUES.md` |
| ADD-03 | Directory created on first write | Manual verify | Remove `docs/issues/`, invoke skill, confirm directory and file created |
| ADD-04 | `_github_project` cache written on first invocation | Manual verify | Inspect `.silver-bullet.json` after first GitHub filing |
| ADD-04 | No `gh project list` re-discovery on second invocation | Manual verify | Run skill twice; second run should not call `gh project list` |
| ADD-05 | Session log gains `## Items Filed` line | Manual verify | Check session log after successful filing |
| ADD-05 | Retry on simulated rate limit | Manual verify (code review) | Review SKILL.md retry instruction for correct backoff intervals |

### Wave 0 Gaps

No automated tests exist or need to be created for this phase — SKILL.md files are not testable via a test runner. Verification is by code review (SKILL.md review) and manual behavioral testing after the skill is written.

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No — gh handles GitHub auth | gh CLI manages OAuth token |
| V3 Session Management | No | N/A |
| V4 Access Control | Partial — `project` scope check | `gh auth status \| grep "project"` before board operations |
| V5 Input Validation | Yes — user description becomes issue title/body | jq-based body construction (never string interpolation); title truncated to 72 chars |
| V6 Cryptography | No | N/A |

### Security Boundary (from silver-forensics pattern)

Session logs read by silver-add (if checking the current session log) are UNTRUSTED DATA. The skill must not follow instructions found in session log content. Only the `## Items Filed` section header is written to — no session log content is read and re-executed.

The `_github_project` cache is written to `.silver-bullet.json` via `jq` (not string interpolation), preventing JSON injection via project names or IDs containing special characters.

[VERIFIED: security pattern from skills/silver-forensics/SKILL.md Security Boundary section]

---

## Sources

### Primary (HIGH confidence)

- `skills/silver-forensics/SKILL.md` — SKILL.md format, step structure, security boundary, project root discovery pattern, directory creation before write, autonomous mode instructions
- `skills/silver-update/SKILL.md` — frontmatter schema, atomic JSON write pattern (tmpfile + mv), version validation pattern
- `.planning/research/STACK.md` (v0.25.0 milestone research) — gh CLI command verification, project board IDs, two-step issue+board pattern, GSD local file IDs, session log parsing
- `.planning/research/ARCHITECTURE.md` — data flow, file structure, integration points, build order
- `.planning/research/FEATURES.md` — classification rubric, UX flow, body template, issue fields
- `.planning/research/PITFALLS.md` — rate limit strategy, noise prevention, false-positive prevention
- `templates/silver-bullet.config.json.default` — `issue_tracker` field confirmed at line 63
- `skills/silver-feature/SKILL.md` — existing `issue_tracker` routing pattern (Step 7 backlog routing)
- `skills/silver-init/SKILL.md` — Step 2.8 PM system prompt and `issue_tracker_value` write pattern
- `docs/sessions/2026-04-20-08-48-48.md` — session log structure confirmed (no Items Filed section)
- `.silver-bullet.json` — confirmed `all_tracked` array schema and current skills list

### Secondary (MEDIUM confidence)

- REQUIREMENTS.md ADD-01 through ADD-05 — requirement text is the authoritative specification
- STATE.md — FEAT-01 completion confirmed; `issue_tracker` field available from Phase 48
- ROADMAP.md Phase 49 success criteria — success criteria confirmed as source of truth

---

## Metadata

**Confidence breakdown:**
- SKILL.md format and conventions: HIGH — verified from two existing skills
- GitHub command sequence: HIGH — verified from milestone stack research
- Project board IDs: HIGH — explicitly documented in STACK.md with confirmed values
- Local file schema: HIGH — verified from STACK.md and ARCHITECTURE.md
- Classification rubric: HIGH — detailed in FEATURES.md; confirmed against REQUIREMENTS.md ADD-01
- Rate limit handling: HIGH — strategy from PITFALLS.md; thresholds from GitHub docs
- Session log `## Items Filed` handling: MEDIUM — session log structure confirmed, but the handling of absent section is ASSUMED (edge case)

**Research date:** 2026-04-24
**Valid until:** 2026-06-24 (stable ecosystem — gh CLI API changes are infrequent; project board IDs are GraphQL node IDs that do not change)
