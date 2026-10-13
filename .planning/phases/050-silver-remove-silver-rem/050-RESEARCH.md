---
phase: 50
name: silver-remove & silver-rem
researched: 2026-04-24
domain: Skill authoring — GitHub issue removal, local markdown mutation, monthly knowledge/lessons file management
confidence: HIGH
---

# Phase 50: silver-remove & silver-rem — Research

**Researched:** 2026-04-24
**Domain:** Skill authoring — GitHub issue removal via `gh` CLI, local markdown inline mutation, monthly knowledge/lessons append with INDEX.md management
**Confidence:** HIGH — all findings verified from the existing silver-add SKILL.md (Phase 49 output), doc-scheme.md, live docs/knowledge/ and docs/lessons/ directory inspection, and STACK.md/ARCHITECTURE.md milestone research.

---

## Summary

Phase 50 delivers two new skills: `silver-remove` (REM-01, REM-02) and `silver-rem` (MEM-01, MEM-02, MEM-03). Both are SKILL.md-only deliverables — no new hooks, no new shell scripts. Both follow the exact same SKILL.md structure established by silver-add and silver-forensics.

**silver-remove** removes a tracked work item by ID. It must handle two ID spaces and two backends: GitHub issue numbers (close with "not planned" + label) and local SB-I-N / SB-B-N IDs (inline `[REMOVED YYYY-MM-DD]` marker in `docs/issues/ISSUES.md` or `docs/issues/BACKLOG.md`). GitHub does not support issue deletion via REST/GraphQL without `delete_repo` scope — silver-remove must close, not delete, and must print clearly what action was taken.

**silver-rem** captures knowledge and lessons insights into monthly append-only files. Classification determines the destination: `docs/knowledge/YYYY-MM.md` for project-scoped knowledge or `docs/lessons/YYYY-MM.md` for portable lessons. The classification rubric must mirror the doc-scheme.md category taxonomy. When a new monthly knowledge file is created for the first time, `docs/knowledge/INDEX.md` must be updated and the new file created with a correct monthly header.

Both skills must be added to `skills.all_tracked` in both `.silver-bullet.json` and `templates/silver-bullet.config.json.default` (same atomic-commit pattern as Phase 49 Task 2).

**Primary recommendation:** Write silver-remove first (depends only on silver-add's locked schema), then silver-rem (depends only on doc-scheme.md taxonomy). Both are self-contained SKILL.md files with no cross-dependency on each other.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| GitHub issue removal | Skill (SKILL.md instructions) | `gh` CLI | gh CLI wraps GitHub REST/GraphQL API; skill orchestrates the two-step close+label sequence |
| Local markdown mutation | Skill (SKILL.md instructions) | bash (`sed`/`awk`/`grep`) | SKILL.md instructs the coding agent which bash commands to run for inline replacement |
| Knowledge/lessons classification | Skill (SKILL.md instructions) | — | Classification rubric lives in SKILL.md; no external tool |
| Monthly file append | Skill (SKILL.md instructions) | filesystem | Append-only write; no external dependency |
| INDEX.md update | Skill (SKILL.md instructions) | filesystem | Conditional on new monthly file creation; reads and rewrites INDEX.md |
| `issue_tracker` routing | `.silver-bullet.json` config walk | `jq` | Same pattern as silver-add Step 1-2; walks up from $PWD |

---

## Standard Stack

### Core

| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| `gh` CLI | 2.x (confirmed present) | GitHub issue close + label add | Same tool used by silver-add; no new dependency |
| `jq` | any (confirmed present) | Config reads, JSON construction | Required by all SB skills; already established |
| `grep`, `sed`, `awk` | posix (confirmed present) | Local markdown ID matching and inline replacement | Established by STACK.md local fallback pattern |
| `date` | posix (confirmed present) | Generate YYYY-MM-DD and YYYY-MM timestamps | Trivial shell built-in |
| `mkdir -p` | posix (confirmed present) | Create docs/knowledge/ and docs/lessons/ on first write | Same pattern as silver-add's `mkdir -p docs/issues/` |

[VERIFIED: silver-add SKILL.md — all of the above commands appear in the `## Allowed Commands` section]
[VERIFIED: STACK.md — "No new tools or runtimes required. jq, gh, git, and grep are already available in the SB environment."]

### No New Dependencies

No additional packages, libraries, or runtimes are required for Phase 50. The complete tool set is already present in the SB environment.

---

## Architecture Patterns

### System Architecture Diagram

```
User invokes /silver-remove <id>
        |
        +-- Walk up to .silver-bullet.json
        |   jq -r '.issue_tracker // "gsd"'
        |
        +-- Parse ID type
        |   "#N" or plain integer     --> GitHub path
        |   "SB-I-N" or "SB-B-N"    --> local docs/ path
        |
        +-- [GitHub path]
        |     gh issue close <N> --reason "not planned"
        |     gh issue edit <N> --add-label "removed-by-silver-bullet"
        |     Print: "Closed GitHub Issue #N as not-planned"
        |
        +-- [Local path]
              Detect ID prefix: SB-I -> docs/issues/ISSUES.md
                                SB-B -> docs/issues/BACKLOG.md
              Match heading line: ### SB-I-N — ...
              Inline replacement: prepend [REMOVED YYYY-MM-DD] to heading
              Print: "Marked SB-I-N as [REMOVED YYYY-MM-DD] in docs/issues/ISSUES.md"

User invokes /silver-rem <insight>
        |
        +-- Walk up to .silver-bullet.json (for project root only)
        |
        +-- Classify insight: knowledge or lessons?
        |   Knowledge: project-scoped — references this codebase
        |   Lessons:   portable — no project-specific paths or names
        |
        +-- [Knowledge path]
        |     Classify category: Architecture Patterns | Known Gotchas |
        |                        Key Decisions | Recurring Patterns | Open Questions
        |     Target: docs/knowledge/YYYY-MM.md
        |     If file does not exist:
        |       Create with monthly header
        |       Update docs/knowledge/INDEX.md
        |     Append formatted entry under matching category heading
        |
        +-- [Lessons path]
              Classify category tag: domain: | stack: | practice: | devops: | design:
              Target: docs/lessons/YYYY-MM.md
              If file does not exist: create with monthly header
              Append formatted entry under matching category heading
```

### Recommended Project Structure

No new directories introduced. Both skills write to existing paths:

```
docs/
  issues/
    ISSUES.md       # silver-remove target for SB-I-N IDs (already exists)
    BACKLOG.md      # silver-remove target for SB-B-N IDs (already exists)
  knowledge/
    INDEX.md        # silver-rem updates when new monthly file created
    YYYY-MM.md      # silver-rem appends knowledge entries
  lessons/
    YYYY-MM.md      # silver-rem appends lessons entries
skills/
  silver-remove/
    SKILL.md        # NEW — Phase 50 deliverable
  silver-rem/
    SKILL.md        # NEW — Phase 50 deliverable
```

### Pattern 1: SKILL.md Structure (from silver-add and silver-forensics)

All SB skills follow this exact frontmatter + section structure:

```yaml
---
name: silver-remove
description: <one sentence — what, when, why>
version: 0.1.0
---

# /silver-remove — <headline>

<when to use paragraph>

## Security Boundary

<what is untrusted data, what commands are allowed>

## Allowed Commands

<exhaustive list of permitted shell commands>

## Step 1 — Locate the project root
## Step 2 — Read configuration
## Step N — ...

## Edge Cases

<bullet list of failure modes and their handling>
```

[VERIFIED: silver-add/SKILL.md lines 1-15 — frontmatter schema]
[VERIFIED: silver-forensics/SKILL.md lines 1-30 — identical structure pattern]

### Pattern 2: GitHub Issue Close + Label (silver-remove GitHub path)

```bash
# Step 1: Close with reason
gh issue close <N> \
  --repo "$OWNER_REPO" \
  --reason "not planned" \
  --comment "Removed via /silver-remove."

# Step 2: Add removal label (separate call — gh issue close does not accept --add-label)
gh issue edit <N> \
  --repo "$OWNER_REPO" \
  --add-label "removed-by-silver-bullet"
```

The label `removed-by-silver-bullet` must be created idempotently before use (same pattern as `filed-by-silver-bullet` in silver-add Step 4b):

```bash
gh label create "removed-by-silver-bullet" \
  --color "#B60205" \
  --description "Removed via Silver Bullet /silver-remove" \
  --repo "$OWNER_REPO" \
  2>/dev/null || true
```

[VERIFIED: STACK.md — "gh issue close <number> --reason 'not planned'" and "gh issue edit <number> --add-label 'removed-by-silver-bullet'" documented explicitly]
[VERIFIED: silver-add SKILL.md Step 4b — idempotent label creation pattern]

### Pattern 3: Local Markdown Inline Removal (silver-remove local path)

The requirement is to MARK the entry, not delete it. The heading line is mutated in place:

```bash
# Before: ### SB-I-3 — Short title of the issue
# After:  ### [REMOVED 2026-04-24] SB-I-3 — Short title of the issue

# Using sed for in-place heading replacement (macOS-compatible):
DATE=$(date +%Y-%m-%d)
sed -i '' "s|^### SB-I-3 —|### [REMOVED ${DATE}] SB-I-3 —|" docs/issues/ISSUES.md
```

Key constraints:
- Match ONLY the heading line (`^### SB-I-3 —`), not body text containing the ID
- Use `''` with `sed -i` for macOS compatibility (BSD sed)
- Entry body remains intact — only the heading is prepended with `[REMOVED YYYY-MM-DD]`
- File must be checked to confirm the match before running sed (avoid silent no-op)

[VERIFIED: REQUIREMENTS.md REM-02 — "marks the item as [REMOVED YYYY-MM-DD] inline... by matching the SB-I-N or SB-B-N ID"]
[VERIFIED: silver-add SKILL.md Step 5e — the heading format is `### FILED_ID — ITEM_TITLE`, confirming the exact pattern to match]

### Pattern 4: silver-rem Knowledge Entry Format

From the existing `docs/knowledge/2026-04.md` (live file, confirmed structure):

```markdown
## Architecture Patterns

2026-04-24 — <insight text>

## Known Gotchas

2026-04-24 — <insight text>

## Key Decisions

2026-04-24 — <insight text>

## Recurring Patterns

2026-04-24 — <insight text>

## Open Questions

2026-04-24 — <insight text>
[RESOLVED YYYY-MM-DD]: <resolution>  (if later resolved)
```

The date-prefixed prose line format is the live standard. No ID, no label, no structured metadata — just date + insight.

[VERIFIED: docs/knowledge/2026-04.md — all five categories present with date-prefixed entries]

### Pattern 5: silver-rem Lessons Entry Format

From the existing `docs/lessons/2026-04.md` (live file, confirmed structure):

```markdown
## stack:bash

2026-04-24 — <insight text>

## practice:enforcement

2026-04-24 — <insight text>

## practice:config-management

2026-04-24 — <insight text>
```

Category headings use `## category:subcategory` format. Multiple subcategories per top-level category are allowed (e.g., `## practice:enforcement` and `## practice:config-management` both under the `practice:` namespace).

[VERIFIED: docs/lessons/2026-04.md — live file confirms heading format and date-prefixed entry format]

### Pattern 6: Monthly File Header and INDEX.md Update (MEM-03)

When a new monthly file is created for the first time, two writes happen:

**New monthly file header (knowledge):**
```markdown
---
project: Silver Bullet
period: YYYY-MM
type: knowledge
---

# Project Knowledge — YYYY-MM

## Architecture Patterns

## Known Gotchas

## Key Decisions

## Recurring Patterns

## Open Questions

```

[VERIFIED: docs/knowledge/2026-04.md lines 1-8 — live frontmatter and heading structure]

**New monthly file header (lessons):**
```markdown
---
period: YYYY-MM
type: lessons
categories: []
---

# Lessons Learned — YYYY-MM

```

[VERIFIED: docs/lessons/2026-04.md lines 1-8 — live frontmatter structure]

**INDEX.md update pattern:**
The existing `docs/knowledge/INDEX.md` has a final line:
```
Latest knowledge: `docs/knowledge/2026-04.md`
Latest lessons: `docs/lessons/2026-04.md`
```

When a new monthly knowledge file is created, this line must be updated to reflect the new month. The INDEX.md also needs a new row added to the table pointing to the new monthly file.

[VERIFIED: docs/knowledge/INDEX.md lines 28-29 — "Latest knowledge:" and "Latest lessons:" pointer lines confirmed]

### Pattern 7: ID Routing for silver-remove

The skill must distinguish three ID input formats:

| Input format | Examples | Route to |
|-------------|----------|----------|
| Plain integer | `42` | GitHub — check issue_tracker first |
| Hash + integer | `#42` | GitHub — explicit |
| `SB-I-N` | `SB-I-3` | Local `docs/issues/ISSUES.md` |
| `SB-B-N` | `SB-B-5` | Local `docs/issues/BACKLOG.md` |

For plain integer input: if `issue_tracker = "github"`, treat as GitHub issue number. If `issue_tracker = "gsd"`, output an error ("No GitHub integration configured — use SB-I-N or SB-B-N ID format").

[VERIFIED: REQUIREMENTS.md REM-01 — "GitHub issue numbers (e.g., #42 or just 42)"]
[VERIFIED: additional_context — "silver-remove must handle two ID formats: GitHub issue numbers (#42 or just 42) and local IDs (SB-I-N or SB-B-N)"]

### Anti-Patterns to Avoid

- **Deleting the local entry instead of marking it:** REM-02 explicitly requires inline marking, not deletion. The `awk` delete-block pattern from STACK.md is out-of-scope for this phase; mark only.
- **Using `gh issue delete`:** This requires `delete_repo` scope and will fail for most users. Always use `gh issue close --reason "not planned"` as the primary action.
- **Silent fallback on GitHub path:** If the close or label add fails, report the error. Never silently succeed without confirming both steps completed.
- **Creating a counter file for silver-rem:** Monthly files need no counter — the month is derived from `date +%Y-%m`. No ID allocation needed.
- **Overwriting an existing category heading:** Append entries under the existing heading. If a category heading is absent from the monthly file, add it before appending the entry.
- **Updating INDEX.md on every silver-rem call:** Only update INDEX.md when a NEW monthly knowledge file is first created. Repeated calls in the same month must not re-update the index.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| GitHub issue close | Custom REST API call via curl | `gh issue close --reason "not planned"` | gh CLI handles auth, retries, and JSON parsing natively |
| Label creation | Custom REST API call | `gh label create ... 2>/dev/null \|\| true` | Idempotent by design; existing silver-add pattern |
| Project root discovery | Custom walk logic | Mirror silver-add Step 1 exactly | Identical problem; reuse the established pattern verbatim |
| YAML frontmatter parsing | Custom parser | None needed — write frontmatter as literal string on file creation | Files are created once; no parse needed |
| Category classification | ML/NLP model | Classification rubric in SKILL.md instructions | Agent applies the rubric; no external tool needed |

---

## Runtime State Inventory

Phase 50 is a greenfield skill authoring phase (new SKILL.md files + config appends). It does not rename, refactor, or migrate anything. No runtime state inventory applies.

---

## Common Pitfalls

### Pitfall 1: GitHub Close Succeeds but Label Add Fails Silently

**What goes wrong:** `gh issue close` returns exit 0, but `gh issue edit --add-label` fails because the label does not exist yet and idempotent label creation was skipped. The issue is closed without the `removed-by-silver-bullet` label. Silver-scan's deduplication step (Phase 54) will not recognize this issue as SB-removed.

**Why it happens:** The two-step sequence (close, then label) is not atomic. If label creation is omitted or fails, the second step has nothing to add.

**How to avoid:** Create the label idempotently (Step: `gh label create ... 2>/dev/null || true`) BEFORE the close+label sequence. Mirror the `filed-by-silver-bullet` idempotent creation pattern from silver-add Step 4b exactly.

**Warning signs:** `gh issue edit` exits non-zero with "label not found" error.

### Pitfall 2: Sed Match Hits Body Text, Not Just the Heading Line

**What goes wrong:** `sed -i '' "s|SB-I-3|[REMOVED] SB-I-3|g"` matches every occurrence of `SB-I-3` in the file — including body text of other entries that mention this ID, or the `**Source:**` field if it was ever edited to reference the ID.

**Why it happens:** A global replace without anchoring to the heading line format.

**How to avoid:** The sed pattern MUST be anchored to match only the heading line:
`s|^### SB-I-3 —|### [REMOVED YYYY-MM-DD] SB-I-3 —|`
The `^###` anchor and ` —` suffix after the ID ensure only the exact heading line is matched.

**Warning signs:** Running `grep "REMOVED" docs/issues/ISSUES.md` after the operation shows more than one match per ID.

### Pitfall 3: silver-rem Adds a New Category Heading Every Call

**What goes wrong:** Each `/silver-rem` invocation for a "Known Gotchas" entry appends `## Known Gotchas` followed by the entry, even though the section already exists. The monthly file accumulates duplicate category headings.

**Why it happens:** The skill checks only "does this file exist?" not "does this category heading exist in the file?"

**How to avoid:** Before appending, check whether the target category heading already exists:
```bash
grep -q "^## Known Gotchas$" docs/knowledge/2026-04.md
```
If present: append the dated entry directly after the last line of that section (or at the end of the file if the section is the last one). If absent: append the heading and then the entry.

**Warning signs:** `grep -c "^## Known Gotchas$" docs/knowledge/2026-04.md` returns > 1.

### Pitfall 4: INDEX.md Updated on Every Call to an Existing Month

**What goes wrong:** MEM-03 says "updates `docs/knowledge/INDEX.md` when a new monthly knowledge file is first created." But if the skill does not check whether the file already existed before writing, it updates INDEX.md on every call.

**Why it happens:** The check for "is this a new file?" is skipped or mis-ordered.

**How to avoid:** Use a flag pattern: before attempting the file write, check existence. If the file did NOT exist before this call, update INDEX.md. If it already existed, skip the INDEX.md update entirely.

```bash
FILE="docs/knowledge/$(date +%Y-%m).md"
IS_NEW_FILE=false
[ ! -f "$FILE" ] && IS_NEW_FILE=true
# ... write to file ...
if [ "$IS_NEW_FILE" = true ]; then
  # update INDEX.md
fi
```

**Warning signs:** INDEX.md's "Latest knowledge:" line is updated in git history on every session, not just once per new month.

### Pitfall 5: silver-rem Appends to Wrong File When Month Rolls Over

**What goes wrong:** A user runs `/silver-rem` in April after the April file already has content. The next month (May), if the skill hardcodes the current file path from an earlier lookup, it appends the May entry to the April file.

**Why it happens:** Month is computed once and cached, or the skill reads "latest file" by grepping INDEX.md rather than deriving from the current date.

**How to avoid:** Always derive the target file path from `date +%Y-%m` at runtime:
```bash
MONTH=$(date +%Y-%m)
KNOWLEDGE_FILE="docs/knowledge/${MONTH}.md"
LESSONS_FILE="docs/lessons/${MONTH}.md"
```
Never read the target from INDEX.md or from the most-recently-modified file.

**Warning signs:** Entries for May 2026 appear in `docs/knowledge/2026-04.md`.

### Pitfall 6: knowledge/INDEX.md Update Does Not Add Table Row

**What goes wrong:** The skill updates the "Latest knowledge:" pointer line in INDEX.md but does not add a new row to the `| Doc | Path | Purpose |` table at the top of INDEX.md, so the monthly archive is not queryable via the table.

**Why it happens:** The INDEX.md update logic only handles the last-line pointer, not the table.

**How to avoid:** When creating a new monthly knowledge file, the skill must perform TWO updates to INDEX.md: (1) add a new row to the table, (2) update the "Latest knowledge:" pointer at the bottom. Both in a single atomic write (read the file, mutate both sections, write back with a tmpfile+mv pattern).

**Warning signs:** The INDEX.md table has entries only through 2026-04 while "Latest knowledge:" shows 2026-05.

### Pitfall 7: silver-remove Succeeds for SB-I-N but Fails Silently for SB-B-N

**What goes wrong:** The skill only checks `docs/issues/ISSUES.md` for all SB-N IDs regardless of prefix. `SB-B-5` is in BACKLOG.md, so the grep match fails, the sed is a no-op, and the skill prints success.

**Why it happens:** ID routing is not implemented — the skill treats both prefixes identically.

**How to avoid:** The ID prefix determines the target file:
- `SB-I-*` → `docs/issues/ISSUES.md`
- `SB-B-*` → `docs/issues/BACKLOG.md`

Check that the match exists before running sed:
```bash
if ! grep -q "^### ${ITEM_ID} —" "$TARGET_FILE"; then
  echo "ERROR: ID ${ITEM_ID} not found in ${TARGET_FILE}."
  exit 1
fi
```

---

## Code Examples

Verified patterns from live codebase and confirmed requirements:

### Owner/Repo derivation (from silver-add — reuse verbatim)

```bash
# Source: silver-add SKILL.md Step 4c
REMOTE=$(git remote get-url origin 2>/dev/null)
OWNER_REPO=$(echo "$REMOTE" | sed 's|https://github.com/||;s|.git$||;s|git@github.com:||;s|:|/|')
```

### Local ID prefix detection and file routing

```bash
# Source: derived from silver-add SKILL.md Step 5b pattern
case "$ITEM_ID" in
  SB-I-*)
    TARGET_FILE="docs/issues/ISSUES.md"
    ;;
  SB-B-*)
    TARGET_FILE="docs/issues/BACKLOG.md"
    ;;
  \#*|[0-9]*)
    # GitHub issue number — strip leading # if present
    ISSUE_NUM="${ITEM_ID#\#}"
    # handle in GitHub path
    ;;
  *)
    echo "ERROR: Unrecognized ID format '${ITEM_ID}'. Expected: SB-I-N, SB-B-N, #N, or N."
    exit 1
    ;;
esac
```

### Inline heading replacement for local removal

```bash
# Source: derived from REQUIREMENTS.md REM-02 and silver-add SKILL.md Step 5e heading format
DATE=$(date +%Y-%m-%d)
# Verify match exists before running sed
if ! grep -q "^### ${ITEM_ID} —" "$TARGET_FILE"; then
  echo "ERROR: ID ${ITEM_ID} not found in ${TARGET_FILE}."
  exit 1
fi
# BSD sed (macOS) requires '' after -i
sed -i '' "s|^### ${ITEM_ID} —|### [REMOVED ${DATE}] ${ITEM_ID} —|" "$TARGET_FILE"
echo "Marked ${ITEM_ID} as [REMOVED ${DATE}] in ${TARGET_FILE}."
```

### Monthly file path derivation

```bash
# Source: doc-scheme.md — "Both use monthly files (YYYY-MM.md)"
MONTH=$(date +%Y-%m)
KNOWLEDGE_FILE="docs/knowledge/${MONTH}.md"
LESSONS_FILE="docs/lessons/${MONTH}.md"
```

### Category heading existence check before append

```bash
# Source: derived from docs/knowledge/2026-04.md live structure
HEADING="## Architecture Patterns"
TARGET="docs/knowledge/$(date +%Y-%m).md"
if grep -q "^${HEADING}$" "$TARGET"; then
  # Append entry after the section — use awk or printf >> to append at end of file
  printf "\n%s — %s\n" "$(date +%Y-%m-%d)" "$INSIGHT" >> "$TARGET"
else
  # Section does not exist — add heading then entry
  printf "\n%s\n\n%s — %s\n" "$HEADING" "$(date +%Y-%m-%d)" "$INSIGHT" >> "$TARGET"
fi
```

### New monthly knowledge file creation with correct header

```bash
# Source: docs/knowledge/2026-04.md frontmatter (verified)
MONTH=$(date +%Y-%m)
cat > "docs/knowledge/${MONTH}.md" << EOF
---
project: Silver Bullet
period: ${MONTH}
type: knowledge
---

# Project Knowledge — ${MONTH}

## Architecture Patterns

## Known Gotchas

## Key Decisions

## Recurring Patterns

## Open Questions

EOF
```

### New monthly lessons file creation with correct header

```bash
# Source: docs/lessons/2026-04.md frontmatter (verified)
MONTH=$(date +%Y-%m)
cat > "docs/lessons/${MONTH}.md" << EOF
---
period: ${MONTH}
type: lessons
categories: []
---

# Lessons Learned — ${MONTH}

EOF
```

### Config update pattern (add to skills.all_tracked) — from Phase 49 Task 2

```bash
# Source: Phase 49 plan pattern — atomic jq + tmpfile + mv
TMP=$(mktemp)
jq '.skills.all_tracked += ["silver-remove", "silver-rem"]' \
  .silver-bullet.json > "$TMP" && mv "$TMP" .silver-bullet.json
```

Same pattern applied to `templates/silver-bullet.config.json.default` in the same commit.

---

## State of the Art

| Old Pattern | Current Pattern | Notes |
|------------|-----------------|-------|
| `awk` delete-block (STACK.md draft) | `sed` inline heading replace | STACK.md described full deletion; REM-02 requires marking only — inline replace is correct |
| `gh issue delete` | `gh issue close --reason "not planned"` | Delete requires delete_repo scope; close is the correct primitive |
| Shared ID namespace (STACK.md draft: SB-001, SB-002) | Separate namespaces (SB-I-N, SB-B-N) | Phase 49 locked this — silver-add uses separate ID sequences per file |

**Deprecated approaches from early STACK.md/ARCHITECTURE.md drafts:**
- STACK.md (line 207) describes `awk` delete-block removal: not applicable for Phase 50 — REM-02 requires marking, not deletion. Do not implement the awk delete pattern.
- ARCHITECTURE.md (line 254) describes "Marks Status as removed" in a table row format: Phase 49 used a heading-based markdown block (not a table), so silver-remove targets the heading line, not a table cell.

---

## Locked Decisions from Phase 49 (Non-negotiable)

These decisions are established facts from silver-add SKILL.md. Silver-remove MUST use them identically:

| Decision | Value | Source |
|----------|-------|--------|
| Issues file path | `docs/issues/ISSUES.md` | silver-add Step 5b |
| Backlog file path | `docs/issues/BACKLOG.md` | silver-add Step 5b |
| Issue ID prefix | `SB-I-N` | silver-add Step 5b, 5c |
| Backlog ID prefix | `SB-B-N` | silver-add Step 5b, 5c |
| Heading format | `### SB-I-3 — Short title of the issue` | silver-add Step 5e |
| GitHub ID format | raw issue number from URL | silver-add Step 4c |
| `issue_tracker` read | `jq -r '.issue_tracker // "gsd"' .silver-bullet.json` | silver-add Step 2 |
| Config cache key | `._github_project` | silver-add Step 4d |
| Project root walk | Walk up from $PWD until .silver-bullet.json found | silver-add Step 1 |

[VERIFIED: silver-add/SKILL.md — all of the above confirmed in the live skill file]

---

## Phase Deliverables Summary

| Deliverable | Requirements | Files to Create/Modify |
|------------|-------------|----------------------|
| `skills/silver-remove/SKILL.md` | REM-01, REM-02 | NEW |
| `skills/silver-rem/SKILL.md` | MEM-01, MEM-02, MEM-03 | NEW |
| `.silver-bullet.json` skills.all_tracked | Both skills | MODIFY — append `"silver-remove"`, `"silver-rem"` |
| `templates/silver-bullet.config.json.default` skills.all_tracked | Both skills | MODIFY — same append, same commit |

**No other files are modified.** This phase does not touch hooks, templates (beyond config), session logs, workflow docs, or existing skill files.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `gh issue close` and `gh issue edit` accept `--repo` in the same format as `gh issue create` (owner/repo) | Code Examples | Command may fail if flag format differs — verify with `gh issue close --help` at execution time |
| A2 | BSD `sed -i ''` works for in-place replacement on macOS (the project's development platform) | Code Examples | GNU sed uses `sed -i` without the empty string — if CI runs on Linux, the sed command needs adjustment |
| A3 | New monthly files should include all five category headings as empty sections | Code Examples — monthly header | If categories are added lazily (only when first entry is made), the header format should be stub-free — verify against doc-scheme.md intention |

**A2 note:** STACK.md confirms "Unix-only, no CI coverage" and "no Windows compatibility." macOS BSD sed is the correct target. The empty-string `''` form is the right pattern.

**A3 clarification:** Looking at the live `docs/knowledge/2026-04.md`, all five category headings ARE present from the start. Creating the file with all five empty headings is confirmed correct.

---

## Open Questions

1. **Should silver-remove attempt `gh issue delete` first with fallback, or go directly to close?**
   - What we know: `delete_repo` scope is rarely granted; PITFALLS.md (Pitfall 2) recommends attempting delete first then falling back
   - What's unclear: Whether the additional complexity of a try-fallback is worth it vs. just always closing
   - Recommendation: Go directly to close with "not planned" — simpler, more predictable, clearer user communication. Document that deletion is not supported without `delete_repo` scope. The REQUIREMENTS.md says "closes... (GitHub does not support issue deletion via REST/GraphQL API without delete_repo scope)" — this is the mandated behavior, not an option.

2. **Should silver-rem update `docs/lessons/INDEX.md` when a new lessons monthly file is created?**
   - What we know: MEM-03 explicitly names only `docs/knowledge/INDEX.md` — no mention of a lessons index
   - What's unclear: Is the omission intentional (lessons has no index) or an oversight?
   - Recommendation: Follow MEM-03 exactly — update only `docs/knowledge/INDEX.md`. The live `docs/knowledge/INDEX.md` shows a "Latest lessons:" pointer line, so the knowledge INDEX tracks both. Silver-rem should update that pointer line for both new knowledge AND new lessons monthly files.

3. **What happens when silver-remove is called with a GitHub issue number but `issue_tracker = "gsd"`?**
   - What we know: The ID is ambiguous — an integer could be a GitHub issue or a misfiled ID
   - What's unclear: Should silver-remove attempt GitHub anyway, or error out?
   - Recommendation: Error with a clear message: "No GitHub integration configured (issue_tracker=gsd). For local items, use SB-I-N or SB-B-N format."

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `gh` CLI | silver-remove GitHub path (REM-01) | Confirmed present | 2.x | N/A — local path (REM-02) works without gh |
| `jq` | Both skills | Confirmed present | any | None needed |
| `git` | Owner/repo derivation | Confirmed present | any | Hardcode owner/repo fallback |
| `sed` (BSD) | silver-remove local path | Confirmed present (macOS) | POSIX | GNU sed on Linux needs `sed -i` without `''` |
| `grep` | ID matching, category heading check | Confirmed present | POSIX | None needed |
| `date` | Timestamp generation | Confirmed present | POSIX | None needed |

[VERIFIED: STACK.md — "jq, gh, git, and grep are already available in the SB environment"]

**Missing dependencies with no fallback:** None.

---

## Validation Architecture

No automated tests are required for SKILL.md files. Skills are prose instructions consumed by the coding agent — they have no executable test surface. Validation is manual:

- For silver-remove: invoke `/silver-remove SB-I-1` on a test ISSUES.md entry; verify heading is prefixed with `[REMOVED YYYY-MM-DD]` and file is otherwise unmodified.
- For silver-remove (GitHub): invoke `/silver-remove #<test-issue-number>`; verify issue is closed as "not planned" and `removed-by-silver-bullet` label is applied.
- For silver-rem (knowledge): invoke `/silver-rem` with a knowledge insight; verify entry appears in `docs/knowledge/YYYY-MM.md` under the correct category heading.
- For silver-rem (lessons): invoke `/silver-rem` with a lessons insight; verify entry appears in `docs/lessons/YYYY-MM.md` under the correct category heading.
- For MEM-03: delete `docs/knowledge/YYYY-MM.md` (or test with a new month), invoke `/silver-rem`; verify file is created with correct header and INDEX.md is updated.

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | N/A — gh CLI auth is pre-established |
| V3 Session Management | No | N/A |
| V4 Access Control | No | N/A — reads/writes are local filesystem only |
| V5 Input Validation | Yes | User-supplied ID and insight text must not be passed via shell interpolation into sed patterns or gh commands |
| V6 Cryptography | No | N/A |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Shell injection via malicious ID string | Tampering | Quote the `$ITEM_ID` variable in sed pattern; validate format matches `^SB-[IB]-[0-9]+$` or `^#?[0-9]+$` before use |
| Session log content acting as instructions | Spoofing | Security Boundary section in SKILL.md — session logs are UNTRUSTED DATA |
| JSON injection via insight text into INDEX.md | Tampering | INDEX.md is markdown, not JSON — standard quoting applies; no jq involved |
| Overwriting wrong file via path traversal in ID | Tampering | Derive file path only from the ID prefix (SB-I vs SB-B), never from user input directly |

---

## Sources

### Primary (HIGH confidence)

- `skills/silver-add/SKILL.md` (Phase 49 output, live) — ID schema, heading format, routing pattern, allowed commands, security boundary, config read pattern
- `docs/knowledge/2026-04.md` (live file) — confirmed category structure, date-prefixed entry format, frontmatter schema
- `docs/lessons/2026-04.md` (live file) — confirmed category tag format, heading structure, frontmatter schema
- `docs/knowledge/INDEX.md` (live file) — confirmed table structure, "Latest knowledge/lessons:" pointer format
- `docs/doc-scheme.md` — canonical source for knowledge categories, lessons category tags, size caps, monthly file policy
- `.planning/REQUIREMENTS.md` — REM-01, REM-02, MEM-01, MEM-02, MEM-03 canonical requirement text
- `.silver-bullet.json` (live) — confirmed `silver-add` is in `all_tracked`; `silver-remove` and `silver-rem` are absent (to be added)
- `templates/silver-bullet.config.json.default` (live) — confirmed `silver-add` in `all_tracked`

### Secondary (MEDIUM confidence)

- `.planning/research/STACK.md` — gh CLI commands for issue close, label add, GitHub API scope constraints
- `.planning/research/ARCHITECTURE.md` — build order, file structure, silver-remove integration point
- `.planning/research/PITFALLS.md` — Pitfall 2 (silver-remove GitHub permission model) and Pitfall 1 (noise prevention context for silver-rem classification)
- `skills/silver-forensics/SKILL.md` — SKILL.md structural pattern, Security Boundary section format, Allowed Commands section format

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new tools; all are confirmed present in existing SB environment
- Architecture: HIGH — live files inspected; silver-add schema is locked and confirmed
- Pitfalls: HIGH — derived from live file inspection, confirmed requirement text, and prior pitfalls research
- ID formats: HIGH — locked by Phase 49 (silver-add SKILL.md is the authoritative source)
- Knowledge/lessons format: HIGH — live files directly inspected, not assumed

**Research date:** 2026-04-24
**Valid until:** 2026-05-24 (stable domain — no external API changes expected; gh CLI major version change would invalidate GitHub path commands)
