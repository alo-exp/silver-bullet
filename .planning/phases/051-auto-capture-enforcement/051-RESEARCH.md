# Phase 51: Auto-Capture Enforcement — Research

**Researched:** 2026-04-24
**Domain:** Markdown prose editing — silver-bullet.md, template, skill files, session log hook, silver-release skill
**Confidence:** HIGH

---

## Summary

Phase 51 is a pure-prose editing phase. Every artifact is a markdown skill or instruction file — no new executable code, no new skills, no config schema changes. The work is additive text insertion into existing sections of five skill files, two §3b sections (silver-bullet.md and its template), one session log creation hook (session-log-init.sh), and one orchestration skill (silver-release).

The key structural facts: §3b in both files is currently titled "GSD Command Tracking" and covers only the automatic recording of GSD command markers. It contains no instructions for deferred-item capture or knowledge/lessons capture. The five producing skills (silver-feature, silver-bugfix, silver-ui, silver-devops, silver-fast) have varying coverage of deferred-item capture — silver-feature is the most complete but routes to `gsd-add-backlog` instead of `/silver-add`, silver-bugfix and silver-ui only mention `gsd-add-backlog` in a `/tech-debt` reference, silver-devops has no backlog filing instructions at all, and silver-fast has none. The session log skeleton created by `session-log-init.sh` does not include an `## Items Filed` section. The silver-release skill ends at Step 9 (gsd-complete-milestone) with no post-release summary step.

**Primary recommendation:** Plan this as two commits (CAPT-01+CAPT-03 together as mandated; then CAPT-02, CAPT-04, CAPT-05 separately or together). The §3b rewrite is the atomic unit that must ship in one commit across both silver-bullet.md and templates/silver-bullet.md.base.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Deferred-item capture instruction | silver-bullet.md §3b | Each producing skill file | §3b is the master enforcement layer; per-skill instructions provide redundancy at the point of execution |
| Knowledge/lessons capture instruction | silver-bullet.md §3b | Per-skill doc-scheme step | §3b is where global behavioral rules live; existing doc-scheme steps in skills cover manual invocation |
| Session log `## Items Filed` section | session-log-init.sh (hook) | — | The hook creates session log skeletons; the section must be in the skeleton, not added post-hoc |
| Post-release summary | silver-release SKILL.md Step 9b | — | silver-release orchestrates the entire milestone close sequence; Step 9 is gsd-complete-milestone, Step 9b follows |
| Classification rubric | silver-bullet.md §3b | silver-add SKILL.md Step 3 | silver-add owns the authoritative rubric; §3b should reference or restate the key distinction |

---

## File-by-File Findings

### silver-bullet.md §3b — Current State

[VERIFIED: Read tool] §3b is titled "GSD Command Tracking" (line 509). Its content is:
- A table mapping Skill invocations to recorded markers (gsd-discuss-phase, gsd-plan-phase, etc.)
- An Anti-Skip note about invoking GSD commands only via the Skill tool
- Zero instructions about deferred-item capture or knowledge/lessons capture

The section ends at line 529. The next section is `## 3c. Completion Claim Verification`.

**What must be added:** Two new instruction blocks inserted into §3b (keeping the existing GSD marker table and Anti-Skip note intact):
1. A deferred-item capture instruction block (CAPT-01) calling `/silver-add` with a classification rubric
2. A knowledge/lessons capture instruction block (CAPT-03) calling `/silver-rem`

**Same-commit constraint:** silver-bullet.md §3b and templates/silver-bullet.md.base §3b must be updated identically in the same git commit. This is a NON-NEGOTIABLE project rule documented in CAPT-01, CAPT-03, and reinforced by §3 of silver-bullet.md itself ("Write runtime preference updates to §10 without updating both silver-bullet.md AND templates/silver-bullet.md.base atomically" is listed as a MUST NOT violation).

### templates/silver-bullet.md.base §3b — Current State

[VERIFIED: Read tool] Identical structure to silver-bullet.md §3b. The template uses `{{PROJECT_NAME}}` and `{{ACTIVE_WORKFLOW}}` placeholders in §0 and §2, but §3b has no placeholders — its content is verbatim identical to silver-bullet.md. This means the §3b additions can be identical in both files.

One structural difference: silver-bullet.md §3 refers to "§10 preferences" and "§9" in the template (the template has §9 while the live file has §10 because the live file gained a section). The §3b section itself is unchanged between the two files.

### silver-feature/SKILL.md — gsd-add-backlog Occurrences

[VERIFIED: Read tool + Grep] Four `gsd-add-backlog` occurrences:

1. **Step 7** (line 271-276): "During-execution deferred capture" paragraph. Routes to `gsd-add-backlog` for issue_tracker=gsd. The routing block says:
   ```
   Skill(skill="gsd-add-backlog", args="<description of deferred item>")
   ```
   This entire routing block needs replacing with a call to `/silver-add`.

2. **Step 9e** (line 326): "Backlog capture from review" step. Calls:
   ```
   Skill(skill="gsd-add-backlog", args="<finding description from REVIEW.md>")
   ```
   Replace with `/silver-add` invocation.

3. **Step 12b** (line 345): `/tech-debt` step says "Items that cannot be addressed now MUST be captured in the GSD backlog via `gsd-add-backlog`." Replace with `/silver-add` reference.

4. **Step 18** (line 443): "Post-work backlog capture" step. Routes to `gsd-add-backlog`. Replace with `/silver-add` invocation.

Additionally, Step 7 already has a "During-execution deferred capture" paragraph and Step 18 has a "Post-work backlog capture" step. These are the closest things to a per-skill deferred-capture instruction, but they use the old routing. CAPT-02 requires a dedicated per-skill capture instruction — the approach should be to update the existing steps (replace `gsd-add-backlog` with `/silver-add`) AND add a concise per-skill capture step at the most natural location.

### silver-bugfix/SKILL.md — gsd-add-backlog Occurrences

[VERIFIED: Read tool + Grep] One `gsd-add-backlog` occurrence:

1. **Step 7a** (line 183): "Invoke `/tech-debt` via the Skill tool... Items not addressed now MUST be captured via `gsd-add-backlog`." Replace reference with `/silver-add`.

No explicit deferred-capture step exists in silver-bugfix. CAPT-02 requires adding one. The natural location is after Step 4 (Execute Fix) or after Step 5 (Code Review), capturing items deferred during the fix — similar to silver-feature's Step 9e pattern.

### silver-ui/SKILL.md — gsd-add-backlog Occurrences

[VERIFIED: Read tool + Grep] One `gsd-add-backlog` occurrence:

1. **Step 12b** (line 229): "Items not addressed now MUST be captured via `gsd-add-backlog`." Replace with `/silver-add` reference.

No explicit deferred-capture step exists in silver-ui. CAPT-02 requires adding one. Natural location: after the existing Step 12b (tech-debt review), a dedicated deferred-capture instruction for items scoped out during UI execution.

### silver-devops/SKILL.md — gsd-add-backlog Occurrences

[VERIFIED: Read tool + Grep] Zero `gsd-add-backlog` occurrences. The skill has no backlog filing instructions at all — only a brief mention in the doc-scheme step (Step 10b) about appending to knowledge/lessons files manually. CAPT-02 requires adding a per-skill deferred-capture step. Natural location: after Step 7 (Code Review) or after Step 8 (IaC Security + Secrets Verification), for deferred items found during IaC review.

### silver-fast/SKILL.md — gsd-add-backlog Occurrences

[VERIFIED: Read tool + Grep] Zero `gsd-add-backlog` occurrences. The skill is a router — Tier 1 routes to gsd-fast, Tier 2 to gsd-quick, Tier 3 escalates to silver-feature. Given that Tier 3 immediately invokes silver-feature (which handles its own capture) and Tier 1 is truly trivial, the most appropriate capture point is after Tier 2 completion (Step 2) — if any items were scoped out during medium complexity execution. Add a brief capture note at Step 4 (Scope Expansion Check) or as a new Step 5 post-execution.

### session-log-init.sh — Current Session Log Skeleton

[VERIFIED: Read tool] The session log skeleton created by `session-log-init.sh` (lines 167-224) contains these sections:
- Pre-answers
- Task
- Approach
- Files changed
- Skills invoked
- Skills flagged at discovery
- Skill gap check (post-plan)
- Agent Teams dispatched
- Autonomous decisions
- Needs human review
- Outcome
- Knowledge & Lessons additions

**Not present:** `## Items Filed` section. CAPT-04 requires adding it.

The hook has idempotency logic (lines 109-121): when a session log already exists for the day, it inserts missing sections before the anchor line. This means CAPT-04 needs TWO changes:
1. Add `## Items Filed` to the skeleton template (lines 167-224) for new session logs
2. Add an idempotency `_insert_before` call in the existing-log branch (line 95-121) so pre-existing session logs gain the section on re-trigger

**Section placement:** The natural position is after `## Outcome` and before `## Knowledge & Lessons additions` — or at the end. Given that silver-add and silver-rem calls record per-item entries, placing `## Items Filed` just before the final `## Knowledge & Lessons additions` section makes the sequence: what was done → what was filed → what was learned.

The idempotency insertion pattern used by the hook is:
```bash
_insert_before "$existing" "## SomeAnchor" "## New Section" "(placeholder text)"
```
For `## Items Filed`, the anchor would be `## Knowledge & Lessons additions`.

### silver-release/SKILL.md — Current Step Structure

[VERIFIED: Read tool] Steps in order:
- Step 0: Pre-Release Quality Gates
- Step 1: Cross-Phase UAT
- Step 2: Milestone Completion Audit
- Step 2a: Security Hard Gate
- FLOW DESIGN HANDOFF (conditional)
- Step 2b: Gap-Closure Loop (conditional)
- Step 3a: Verify Existing Documentation
- Step 3b: Generate/Update Documentation
- Step 4: Milestone Summary
- Step 5: Create Release
- Step 6: PR Branch
- Step 7: Cross-Artifact Consistency Review
- Step 7b: Pre-Ship Deployment Checklist
- Step 8: Ship
- **Step 9: Complete Milestone** (final step — ends here)

CAPT-05 requires adding **Step 9b** after Step 9. Step 9 already says "this is the final step — milestone is officially closed after this." Step 9b runs AFTER gsd-complete-milestone succeeds and generates the summary.

**Step 9b specification from CAPT-05:**
- Reads all `## Items Filed` entries from session logs within the milestone window
- Uses milestone start date from `STATE.md` frontmatter
- Presents a consolidated post-release summary

**STATE.md frontmatter fields relevant to CAPT-05:**
- `milestone: v0.25.0`
- `last_activity: 2026-04-24` (current, not start)
- `last_updated: "2026-04-24T10:11:43Z"`

The milestone start date is NOT explicitly in the STATE.md frontmatter — there is no `milestone_start` field. The closest field is `last_activity`. Step 9b will need to derive the window by reading session log filenames (dates embedded in filename like `2026-04-24-08-48-48.md`) and comparing to the milestone's first activity date. Alternatively, it can glob all session logs and filter those that were modified after the milestone's git tag was created.

**Practical approach for Step 9b:** The skill should:
1. Read `milestone: v0.25.0` from STATE.md frontmatter
2. Get the previous milestone tag date: `git log --format="%ai" v0.24.1 -1 2>/dev/null || echo "1970-01-01"`
3. Filter `docs/sessions/*.md` to those created (by filename date) on or after the previous release date
4. Extract all `## Items Filed` section content from those logs
5. Present a consolidated table

### silver-add/SKILL.md — Step 6 Session Log Recording (Existing)

[VERIFIED: Read tool] silver-add already records to the session log at Step 6. The logic:
- If the session log has `## Items Filed`: append `- FILED_ID: ITEM_TITLE`
- If not: append the full `## Items Filed` section with the first entry

This means once CAPT-04 adds the section to the skeleton, silver-add will always find it and use the first branch (append under existing section). The current fallback (add section if missing) remains correct for logs created before CAPT-04 ships.

### silver-rem/SKILL.md — Session Log Recording

[VERIFIED: Read tool] silver-rem has NO session log recording step. It only outputs "Recorded [knowledge|lessons] insight..." (Step 8). CAPT-04 implies that `/silver-rem` calls should also be recorded in the `## Items Filed` section (the requirement says "silver-add and silver-rem calls are recorded per session with item ID and title").

This is an important finding: silver-rem does not currently record to the session log. Either:
- silver-rem needs a new step added (similar to silver-add Step 6) for session log recording, OR
- The `## Items Filed` section records only silver-add filings and silver-rem entries appear in the existing `## Knowledge & Lessons additions` section

Reading CAPT-04 literally: "silver-add and silver-rem calls are recorded per session with item ID and title" — this implies both are tracked in `## Items Filed`. However, silver-rem does not produce a stable ID (it says "Recorded [knowledge|lessons]..." not a numbered ID). The most practical interpretation: silver-rem entries use the format `- [knowledge|lessons]: {CATEGORY} — {first 60 chars of insight}` in the session log.

**Decision needed:** Does silver-rem need a Step 9 added for session log recording? Based on CAPT-04's wording ("silver-add and silver-rem calls are recorded per session with item ID and title"), yes — but since silver-rem is owned by Phase 50 and Phase 51 is about enforcement, the minimal approach is to add session log recording to silver-rem as part of Phase 51 (it's a missing capability gap discovered during enforcement wiring).

---

## Classification Rubric to Add to §3b

The rubric already exists in silver-add/SKILL.md Step 3. §3b should reference or restate the key distinction concisely:

**Issue** (call `/silver-add`):
- Broken behavior, crash, regression, verification failure, blocking open question, unfinished work in a broken/incomplete state

**Backlog** (call `/silver-add`):
- Feature deferred to future milestone, tech debt, housekeeping, informational open question, advisory review finding not addressed now

**Default when ambiguous:** classify as backlog (do not over-alarm with issues).

**Minimum bar:** Must have distinct user-visible impact OR block future work OR represent a conscious deferred decision. Do not file transient TODOs or items already addressed.

---

## Common Pitfalls

### Pitfall 1: Editing §3b in silver-bullet.md Without Updating the Template
**What goes wrong:** The template drifts from the live file. Future `/silver:init` runs install the outdated template, losing enforcement instructions.
**Why it happens:** Developers edit only the live file for speed.
**How to avoid:** The same-commit constraint (CAPT-01 + CAPT-03 spec) must be honored. One atomic commit touches both files. Never split them across separate commits.
**Warning signs:** `git diff HEAD -- silver-bullet.md templates/silver-bullet.md.base` shows different §3b content.

### Pitfall 2: Replacing gsd-add-backlog Without Updating All Occurrences in a Skill File
**What goes wrong:** Mixed routing — some deferred items go to `/silver-add` (routed correctly) and some go to `gsd-add-backlog` (old routing). Items may be double-filed or lost depending on issue_tracker config.
**Why it happens:** A skill file is edited at one occurrence but others are missed.
**How to avoid:** Use Grep to confirm zero `gsd-add-backlog` occurrences in a skill file after each edit. The Grep results above show the count per file — verify each reaches zero.

### Pitfall 3: Session Log Skeleton Change Without Idempotency Update
**What goes wrong:** Existing session logs (already created today) never gain `## Items Filed` because the idempotency path (line 95-121 in session-log-init.sh) doesn't insert the new section.
**Why it happens:** Adding only to the skeleton template (lines 167-224) without updating the `_insert_before` idempotency block.
**How to avoid:** Two edits in session-log-init.sh — skeleton AND idempotency block.

### Pitfall 4: Step 9b Milestone Date Filter is Wrong
**What goes wrong:** The summary includes session logs from prior milestones (too broad) or excludes logs from the current milestone (too narrow).
**Why it happens:** STATE.md frontmatter doesn't have an explicit `milestone_start` field. Deriving the window from `last_activity` alone would include only recent sessions.
**How to avoid:** Use the previous release's git tag date as the lower bound. The command `git log --format="%ai" v0.24.1 -1` gives the tag timestamp. Sessions created after that date are in the current milestone window.

### Pitfall 5: silver-rem Records No Session Log Entry
**What goes wrong:** `## Items Filed` only ever gets entries from `/silver-add`, not from `/silver-rem`. CAPT-05 Step 9b summary would be incomplete — only issues/backlog items, no knowledge/lessons.
**Why it happens:** silver-rem doesn't have a session log recording step (confirmed by reading the skill — Step 8 only outputs a confirmation string).
**How to avoid:** Add a session log recording step to silver-rem as part of Phase 51. The format should match silver-add's pattern but use a knowledge/lessons prefix instead of a stable numeric ID.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Deferred item classification rubric | Custom classification logic | Reference silver-add's Step 3 rubric | Single authoritative rubric in silver-add/SKILL.md |
| Session log path discovery | Custom path logic | `ls docs/sessions/*.md \| sort \| tail -1` | Already established in silver-add Step 6 |
| Milestone window boundary | Custom date calculation | `git log --format="%ai" <prev_tag> -1` | Git history is the authoritative source |

---

## Code Examples

### Pattern 1: Per-Skill Deferred-Capture Instruction (new addition)

This is the pattern to add to each producing skill. Customize the trigger context per skill.

```markdown
## Deferred-Item Capture (mandatory)

During and after execution, any item that is skipped, descoped, out of scope, explicitly deferred, or identified for future work MUST be filed immediately via `/silver-add` — do not accumulate silently.

```
Skill(skill="silver-add", args="<description of deferred item>")
```

**Classification quick-reference:**
- Bug, regression, broken behavior, blocking question, unfinished work → files as **issue**
- Feature request, tech debt, advisory finding, informational question, housekeeping → files as **backlog**
- When ambiguous → files as **backlog** (do not over-alarm with issues)

**Minimum bar:** Only file items with distinct impact OR that block future work OR represent a conscious deferred decision. Do not file transient notes or items already addressed this session.
```

### Pattern 2: §3b New Content for silver-bullet.md

The existing §3b "GSD Command Tracking" section keeps its table and Anti-Skip note. Two new blocks are appended within the section:

```markdown
### 3b-i. Deferred-Item Capture (mandatory, all sessions)

During execution, any item that is skipped, descoped, deferred, or identified for future work MUST be filed via `/silver-add` **immediately** — not at session end:

```
Skill(skill="silver-add", args="<description of deferred item>")
```

**Classification rubric:**
- **Issue** — broken behavior, crash, regression, test failure, blocking open question, unfinished work left in broken/incomplete state, verification failure
- **Backlog** — feature request deferred to future milestone, tech debt (known shortcut, hardcoded value, missing abstraction), housekeeping, informational open question, advisory review finding not addressed now

**Default when ambiguous:** classify as backlog — do not over-alarm with issues.
**Minimum bar:** item must have distinct user-visible impact OR block future work OR represent a conscious deferred decision. Do not file transient exploration notes or items already addressed in this session.

> **Anti-Skip:** You are violating this rule if you identify a deferred item and do not invoke `/silver-add` before moving to the next task.

### 3b-ii. Knowledge and Lessons Capture (mandatory, all sessions)

During execution, any architectural insight, key decision, project-local gotcha, recurring pattern, or portable lesson observed MUST be captured via `/silver-rem`:

```
Skill(skill="silver-rem", args="<insight or lesson text>")
```

**Route:**
- Insight references THIS project (architectural decision, project-local gotcha, key decision, recurring pattern, open question for this project) → **knowledge**
- Insight is portable across projects (stack behavior, good practice, anti-pattern, process insight) → **lessons**

**Default when ambiguous:** classify as knowledge.

> **Anti-Skip:** You are violating this rule if you observe a valuable insight during execution and do not invoke `/silver-rem` before the session ends.
```

### Pattern 3: session-log-init.sh — Adding ## Items Filed to Skeleton

Insert between `## Outcome` and `## Knowledge & Lessons additions` in the heredoc (lines 220-222 of session-log-init.sh):

```bash
## Outcome

(filled at documentation step)

## Items Filed

(none)

## Knowledge & Lessons additions

(filled at documentation step)
```

### Pattern 4: session-log-init.sh — Idempotency Insert

Add to the existing-log idempotency block (after the existing `_insert_before` calls, anchoring on `## Knowledge & Lessons additions`):

```bash
if ! grep -q "^## Items Filed$" "$existing" 2>/dev/null; then
  _insert_before "$existing" "## Knowledge & Lessons additions" \
    "## Items Filed" "(none)"
fi
```

### Pattern 5: silver-release Step 9b

```markdown
## Step 9b: Post-Release Items Summary

**Only after Step 9 (gsd-complete-milestone) confirms success:**

Generate a consolidated summary of all items filed and knowledge/lessons recorded during this milestone.

### Step 9b.1: Determine milestone window

```bash
# Read milestone and previous tag from STATE.md
MILESTONE=$(grep '^milestone:' .planning/STATE.md | awk '{print $2}')

# Get the previous milestone release date (lower bound for session log filter)
# Use the tag immediately preceding the current milestone
PREV_TAG=$(git tag --sort=version:refname | grep '^v' | tail -2 | head -1)
MILESTONE_START=$(git log --format="%ai" "$PREV_TAG" -1 2>/dev/null | cut -d' ' -f1 || echo "1970-01-01")
```

### Step 9b.2: Collect Items Filed from session logs

```bash
# Find session logs within the milestone window (filename-based date filter)
# Session logs are named docs/sessions/YYYY-MM-DD-HH-MM-SS.md
for log in docs/sessions/*.md; do
  log_date=$(basename "$log" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}')
  if [[ "$log_date" > "$MILESTONE_START" ]] || [[ "$log_date" = "$MILESTONE_START" ]]; then
    # Extract ## Items Filed section content
    awk '/^## Items Filed$/,/^## /' "$log" | grep '^- '
  fi
done
```

### Step 9b.3: Present consolidated summary

Present a formatted table:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 MILESTONE {MILESTONE} — ITEMS FILED SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Session logs scanned: {N} (from {MILESTONE_START} to today)

Issues & Backlog filed via /silver-add:
| ID | Title |
|----|-------|
| {ID} | {Title} |

Knowledge & Lessons recorded via /silver-rem:
| Category | Entry |
|----------|-------|
| {category} | {entry description} |

Total: {N} items filed, {M} knowledge/lessons recorded
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

If no `## Items Filed` sections exist in any milestone session log: output "No items were recorded during this milestone via /silver-add or /silver-rem."
```

### Pattern 6: silver-rem Step 6 (new — session log recording)

Add after the existing Step 7 (Update INDEX.md) — or as a new Step 7.5 — in silver-rem/SKILL.md:

```markdown
## Step 8 (revised) — Record in session log

Locate the current session log:
```bash
SESSION_LOG=$(ls docs/sessions/*.md 2>/dev/null | sort | tail -1)
```

If `SESSION_LOG` is empty: skip silently with no error.

If `SESSION_LOG` exists:
- If the file contains a `## Items Filed` section: append a new line:
  `- [INSIGHT_TYPE]: CATEGORY — {first 60 characters of insight}`
- If the file does NOT contain `## Items Filed`: append the section:

```markdown

## Items Filed

- [INSIGHT_TYPE]: CATEGORY — {first 60 characters of insight}
```
```

---

## Environment Availability

Step 2.6: SKIPPED — Phase 51 is purely prose editing of markdown files. No external tools, services, runtimes, or CLI utilities are required beyond what is used by existing hook code (bash, jq, git). These are already present and validated in prior phases.

---

## Runtime State Inventory

Step 2.5: SKIPPED — This is not a rename/refactor/migration phase. No runtime state (stored data, service config, OS-registered state, secrets/env vars, or build artifacts) is affected by prose additions to markdown files.

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CAPT-01 | silver-bullet.md §3b and templates/silver-bullet.md.base §3b instruct the coding agent to call `/silver-add` for every deferred, skipped, or identified work item with an explicit classification rubric | §3b currently has zero deferred-capture instructions; Pattern 2 above provides the exact prose to insert; the same-commit atomic update is mandatory |
| CAPT-02 | silver-feature, silver-bugfix, silver-ui, silver-devops, and silver-fast each contain a per-skill explicit deferred-capture instruction calling `/silver-add` (replacing existing `gsd-add-backlog` calls) | gsd-add-backlog occurrences fully catalogued above: silver-feature has 4, silver-bugfix has 1, silver-ui has 1, silver-devops has 0, silver-fast has 0; Pattern 1 provides the per-skill instruction template |
| CAPT-03 | silver-bullet.md §3b and templates/silver-bullet.md.base §3b (same commit as CAPT-01) instruct the coding agent to call `/silver-rem` for every knowledge insight or lesson learned | Same §3b location; Pattern 2 includes 3b-ii block; must be atomic with CAPT-01 |
| CAPT-04 | session-log-init.sh (or equivalent) gains an `## Items Filed` section so silver-add and silver-rem calls are recorded per session | session-log-init.sh confirmed as the hook; skeleton template at lines 167-224 needs `## Items Filed`; idempotency block at lines 109-121 needs `_insert_before` for existing logs; silver-rem also needs session log recording step (currently absent) |
| CAPT-05 | silver-release gains a Step 9b that reads all `## Items Filed` entries from session logs within the milestone window and presents a consolidated post-release summary | silver-release currently ends at Step 9; milestone window derived from previous git tag date; Pattern 5 provides full Step 9b implementation |
</phase_requirements>

---

## Open Questions (RESOLVED)

1. **Does silver-rem need a session log recording step?**
   - What we know: silver-rem Step 8 only outputs a confirmation string — no session log write
   - What's unclear: CAPT-04 says "silver-add and silver-rem calls are recorded" — does this mean silver-rem needs its own recording logic, or is this satisfied by the doc-scheme Knowledge & Lessons additions section?
   - Recommendation: Add session log recording to silver-rem (Pattern 6 above). The `## Items Filed` section should capture both silver-add and silver-rem calls so CAPT-05 Step 9b can scan one section per log. This is the most consistent interpretation of CAPT-04.
   - **RESOLVED:** Yes — silver-rem needs a session log recording step. Plan 051-03 Task 2 adds this step to skills/silver-rem/SKILL.md using the printf pattern from Pattern 6.

2. **Milestone start date for Step 9b: git tag vs STATE.md**
   - What we know: STATE.md frontmatter has `milestone: v0.25.0` but no explicit `milestone_start` field; previous tag was v0.24.1
   - What's unclear: Is using `git log --format="%ai" v0.24.1 -1` always reliable? (Requires the previous tag to exist in the local repo)
   - Recommendation: Use `git tag --sort=version:refname | grep '^v' | tail -2 | head -1` to dynamically find the previous tag, then get its date. Fall back to `last_activity` from STATE.md if tag is unavailable.
   - **RESOLVED:** Use dynamic previous-tag derivation (`git tag --sort=version:refname | grep '^v[0-9]' | tail -2 | head -1`) with `MILESTONE_START="1970-01-01"` fallback. Plan 051-04 Step 9b.1 implements this.

---

## Validation Architecture

No test framework applicable — this phase edits markdown prose files. Verification is structural:
- §3b in silver-bullet.md contains 3b-i and 3b-ii subsections after the edit
- §3b in templates/silver-bullet.md.base is identical to silver-bullet.md §3b
- Each of the 5 producing skill files has zero `gsd-add-backlog` occurrences
- Each of the 5 producing skill files has at least one `/silver-add` call or reference
- session-log-init.sh skeleton contains `## Items Filed` section
- session-log-init.sh idempotency block has `_insert_before` for `## Items Filed`
- silver-release SKILL.md contains Step 9b after Step 9
- silver-rem SKILL.md contains session log recording step (if CAPT-04 interpretation is that silver-rem records to session log)

---

## Sources

### Primary (HIGH confidence)
- [VERIFIED: Read tool] `/Users/shafqat/Documents/Projects/silver-bullet/silver-bullet.md` — §3b full content (lines 509-529), §3 rules, §10
- [VERIFIED: Read tool] `/Users/shafqat/Documents/Projects/silver-bullet/templates/silver-bullet.md.base` — §3b identical structure confirmed
- [VERIFIED: Read tool] `/Users/shafqat/Documents/Projects/silver-bullet/hooks/session-log-init.sh` — skeleton template (lines 167-224), idempotency block (lines 95-147)
- [VERIFIED: Read tool] `/Users/shafqat/Documents/Projects/silver-bullet/skills/silver-feature/SKILL.md` — all gsd-add-backlog occurrences
- [VERIFIED: Read tool] `/Users/shafqat/Documents/Projects/silver-bullet/skills/silver-bugfix/SKILL.md` — gsd-add-backlog occurrence, no deferred-capture step
- [VERIFIED: Read tool] `/Users/shafqat/Documents/Projects/silver-bullet/skills/silver-ui/SKILL.md` — gsd-add-backlog occurrence, no deferred-capture step
- [VERIFIED: Read tool] `/Users/shafqat/Documents/Projects/silver-bullet/skills/silver-devops/SKILL.md` — zero gsd-add-backlog occurrences confirmed
- [VERIFIED: Read tool] `/Users/shafqat/Documents/Projects/silver-bullet/skills/silver-fast/SKILL.md` — zero gsd-add-backlog occurrences confirmed
- [VERIFIED: Read tool] `/Users/shafqat/Documents/Projects/silver-bullet/skills/silver-release/SKILL.md` — step structure through Step 9
- [VERIFIED: Read tool] `/Users/shafqat/Documents/Projects/silver-bullet/skills/silver-add/SKILL.md` — Step 6 session log recording, Step 3 classification rubric
- [VERIFIED: Read tool] `/Users/shafqat/Documents/Projects/silver-bullet/skills/silver-rem/SKILL.md` — confirmed absence of session log recording step
- [VERIFIED: Read tool] `.planning/STATE.md` — frontmatter fields (milestone, last_activity), no milestone_start field
- [VERIFIED: Read tool] `.planning/REQUIREMENTS.md` — CAPT-01 through CAPT-05 full text
- [VERIFIED: Grep tool] `gsd-add-backlog` occurrences across all skill files — exhaustive count per file

### Secondary (MEDIUM confidence)
- [VERIFIED: Bash] `ls skills/silver-ui/` — silver-ui/SKILL.md exists, confirmed as producing skill in CAPT-02 scope
- [VERIFIED: Bash] `find hooks/` — session-log-init.sh confirmed as the session log creation mechanism

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | silver-rem should add a session log recording step (Phase 51 scope) | CAPT-04 interpretation, Pattern 6 | If wrong: CAPT-04 is satisfied by `## Knowledge & Lessons additions` section; no new step needed in silver-rem — reduces Phase 51 scope slightly |
| A2 | `git log --format="%ai" <prev_tag> -1` reliably gives milestone start for Step 9b | Pattern 5, Step 9b.1 | If wrong: milestone window filter might include too many or too few session logs; fallback to scanning all logs is safe |
| A3 | The `## Items Filed` section in session logs should be placed before `## Knowledge & Lessons additions` | Pattern 3, Pitfall 3 | If wrong: placement is cosmetic; any position in the log skeleton is functionally equivalent for silver-add's grep check |

**Confidence for non-assumed claims:** HIGH — all structural facts about current files were read directly.

---

## Metadata

**Confidence breakdown:**
- Current file structure: HIGH — all files read directly, content confirmed line-by-line
- gsd-add-backlog occurrences: HIGH — Grep tool confirmed exhaustive results
- session-log-init.sh mechanism: HIGH — file read in full, idempotency logic understood
- Step 9b milestone window approach: MEDIUM — git tag pattern is sound but STATE.md lacks explicit start date field (A2 above)
- silver-rem session log recording requirement: MEDIUM — depends on CAPT-04 interpretation (A1 above)

**Research date:** 2026-04-24
**Valid until:** 2026-06-01 (stable prose files; no external dependencies)
