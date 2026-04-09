# Phase 14: Validation, Traceability & UAT Gate — Research

**Researched:** 2026-04-09
**Domain:** Silver Bullet skill authorship (SKILL.md), bash hook authorship, session record integration, SPEC.md parsing
**Confidence:** HIGH — all findings based on direct source inspection of existing skills and hooks

---

## Summary

Phase 14 delivers three new components: the `silver-validate` skill (VALD-01..05), the `pr-traceability.sh` hook (TRAC-01..04), and the `uat-gate.sh` hook (UATG-01..04). It also adds a documentation pass updating `silver-bullet.md.base` with the spec lifecycle section.

All three components depend on Phase 12 (SPEC.md format and template) and Phase 13 (session structures). The hard dependency is SPEC.md existing at `.planning/SPEC.md` with canonical frontmatter (`spec-version:`, `jira-id:`, `## Acceptance Criteria`, `## Implementations`).

**Key architectural constraint confirmed from STATE.md:** "zero GSD modifications" — all three components are additive, wired into existing hook events and existing skill invocation points. No GSD file changes.

**Primary recommendation:** Build in wave order — `silver-validate` skill first (VALD-01..05), then `pr-traceability.sh` (TRAC-01..04), then `uat-gate.sh` (UATG-01..04), then documentation pass. Each wave is independently testable.

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| VALD-01 | silver-validate skill: gap analysis SPEC.md vs PLAN.md | Skill authorship pattern confirmed in silver-spec/silver-ingest; reads `.planning/SPEC.md` + current PLAN.md |
| VALD-02 | Machine-readable findings with severity BLOCK / WARN / INFO | Finding object schema must be defined and emitted consistently — no prose-only output |
| VALD-03 | BLOCK severity prevents gsd-plan-phase from proceeding | silver-validate is invoked BEFORE gsd-plan-phase in silver-feature Step 2.7; user must resolve before continuing |
| VALD-04 | WARN severity surfaced in PR description as deferred items | pr-traceability.sh reads validation findings log or SPEC.md WARNs when populating PR description |
| VALD-05 | Re-surfaces all [ASSUMPTION: ...] blocks from SPEC.md at implementation start | silver-validate reads SPEC.md, collects all ASSUMPTION blocks, prints them as awareness list |
| TRAC-01 | Session record captures spec-id, spec-version, JIRA ref at session start | New hook or extension to session-start fires at session start and reads SPEC.md frontmatter; writes to `~/.claude/.silver-bullet/spec-session` |
| TRAC-02 | pr-traceability.sh hook on gsd-ship: auto-populates PR description | PostToolUse on Bash matcher, detects gsd-ship in command, reads spec-session record + gh pr view output |
| TRAC-03 | PR traceability is machine-generated — no developer annotation | Entirely automated from session record and SPEC.md frontmatter |
| TRAC-04 | SPEC.md Implementations section updated post-merge with PR URL + commit range | pr-traceability.sh (PostToolUse) appends to `## Implementations` section after PR is created/merged |
| UATG-01 | gsd-audit-uat produces UAT checklist from SPEC.md acceptance criteria | gsd-audit-uat already invoked in silver-feature Step 17; needs to read SPEC.md ACs and produce UAT.md |
| UATG-02 | UAT.md committed to .planning/ with pass/fail per criterion + evidence notes | UAT.md format defined; committed by the agent that runs gsd-audit-uat |
| UATG-03 | uat-gate.sh on gsd-complete-milestone: blocks if UAT not run or any FAIL | PreToolUse on Bash, detects gsd-complete-milestone, checks .planning/UAT.md existence and FAIL presence |
| UATG-04 | UAT validates against pinned spec-version | uat-gate.sh reads spec-version from UAT.md frontmatter and compares to .planning/SPEC.md |
</phase_requirements>

---

## Standard Stack

### Core (all existing in project — no new installs)
| Tool | Version | Purpose | Source |
|------|---------|---------|--------|
| bash | system | Hook scripts — all existing hooks are bash | [VERIFIED: direct inspection] |
| jq | homebrew | JSON parsing in hooks (stdin protocol) | [VERIFIED: all hooks use jq] |
| gh CLI | /opt/homebrew/bin/gh | PR URL extraction, PR description update | [VERIFIED: memory + hooks] |
| git | system | Commit SPEC.md updates post-merge | [VERIFIED: direct inspection] |

### Skill Pattern (existing, extend)
| Pattern | Source | Notes |
|---------|--------|-------|
| SKILL.md step sequence | silver-spec, silver-ingest | All new skills follow identical structure: Pre-flight, Step-Skip Protocol, numbered steps, non-skippable gates |
| Pre-flight §10 load | silver-spec/SKILL.md line 15 | Every skill reads silver-bullet.md §10 before acting |
| Non-skippable gate annotation | silver-spec/SKILL.md | `**NON-SKIPPABLE GATE.**` followed by rationale |

**Installation:** No new packages. jq and gh CLI already required.

---

## Architecture Patterns

### Hook stdin/stdout Protocol (CRITICAL — follow exactly)

All hooks receive a JSON object on stdin. Field extraction:

```bash
input=$(cat)
hook_event=$(printf '%s' "$input" | jq -r '.hook_event_name // "PostToolUse"')
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
```

**PreToolUse block format (deny):**
```bash
emit_block() {
  local reason="$1"
  local json_reason
  json_reason=$(printf '%s' "$reason" | jq -Rs '.')
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}' "$json_reason"
}
```

**PostToolUse block format:**
```bash
printf '{"decision":"block","reason":%s,"hookSpecificOutput":{"message":%s}}' "$json_reason" "$json_reason"
```

**Advisory (non-blocking):**
```bash
printf '{"hookSpecificOutput":{"message":"..."}}'
```

Source: [VERIFIED: spec-floor-check.sh, completion-audit.sh]

### Command Detection Pattern

All hooks detect target commands by grepping the extracted `$cmd`:

```bash
# Detect gsd-ship
if printf '%s' "$cmd" | grep -qE '\bgsd-ship\b|\bgsd[: ]ship\b'; then
  is_ship=true
fi

# Detect gsd-complete-milestone
if printf '%s' "$cmd" | grep -qE '\bgsd-complete-milestone\b|\bgsd[: ]complete-milestone\b'; then
  is_complete_milestone=true
fi
```

Pattern confirmed in spec-floor-check.sh (lines 44-48) and completion-audit.sh. [VERIFIED: direct inspection]

### Error Handler Pattern (mandatory in all hooks)

```bash
set -euo pipefail
trap 'exit 0' ERR          # graceful: never hard-crash a hook
umask 0077                  # security: user-only file creation
```

Source: [VERIFIED: all existing hooks]

### Config Discovery Pattern

Walk up from `$PWD` to find `.silver-bullet.json`:

```bash
config_file=""
search_dir="$PWD"
while true; do
  if [[ -f "$search_dir/.silver-bullet.json" ]]; then
    config_file="$search_dir/.silver-bullet.json"
    break
  fi
  [[ -d "$search_dir/.git" ]] || [[ "$search_dir" == "/" ]] && break
  search_dir=$(dirname "$search_dir")
done
[[ -z "$config_file" ]] && exit 0  # not an SB project — silent exit
```

Source: [VERIFIED: completion-audit.sh, stop-check.sh]

### State File Pattern

```bash
SB_STATE_DIR="${HOME}/.claude/.silver-bullet"
state_file="${SB_STATE_DIR}/state"
```

New spec-session record for TRAC-01 follows the same convention:

```bash
spec_session_file="${SB_STATE_DIR}/spec-session"
```

Format (line-based, one field per line or key=value):

```
spec-id=feature-slug
spec-version=3
jira-id=PROJ-123
```

Source: [VERIFIED: session-log-init.sh, record-skill.sh pattern]

---

## Component-by-Component Design

### silver-validate SKILL.md (VALD-01..05)

**Invocation point:** silver-feature Step 2.7 (between writing-plans and quality-gates). Also invocable standalone via `/silver:validate`.

**Step sequence:**

```
Step 0: Mode detection — check .planning/SPEC.md and current PLAN.md exist
Step 1: Read SPEC.md — extract Acceptance Criteria items, Assumptions blocks
Step 2: Read PLAN.md — extract task coverage, explicit requirement mappings
Step 3: Gap analysis (Claude intrinsic reasoning)
  - For each AC item: is there a task that addresses it?
  - For each [ASSUMPTION] block: is it resolved or explicitly accepted?
  - Are there PLAN.md tasks with no SPEC.md traceability?
Step 4: Emit findings in machine-readable format (VALD-02)
Step 5: Surface all [ASSUMPTION] blocks as awareness list (VALD-05)
Step 6: User decision gate — A. Accept (BLOCK findings must be resolved), B. Return to silver-spec
Step 7: Write .planning/VALIDATION.md (machine-readable findings log)
```

**Finding object format (VALD-02):**

```
FINDING [BLOCK|WARN|INFO] {code}: {description}
  Spec ref: {section}
  Plan ref: {task or "missing"}
  Resolution: {required action}
```

Example:
```
FINDING [BLOCK] VAL-001: Acceptance criterion "system must handle concurrent requests" has no corresponding task in PLAN.md
  Spec ref: ## Acceptance Criteria item 3
  Plan ref: missing
  Resolution: Add task to PLAN.md or mark criterion as out-of-scope with justification
```

**BLOCK severity (VALD-03):** Missing required AC coverage, unresolved BLOCK-tagged assumptions. Skill must refuse to exit cleanly until user resolves or explicitly accepts risk. Non-skippable gate on the decision step.

**WARN severity (VALD-04):** Partial coverage, WARN-tagged assumptions, tasks without SPEC.md traceability. Surfaced as awareness, written to VALIDATION.md, consumed by pr-traceability.sh.

**VALIDATION.md location:** `.planning/VALIDATION.md` — machine-readable findings log that pr-traceability.sh reads to populate PR description deferred items.

### TRAC-01: Session Record (spec-session file)

**What writes it:** A new lightweight hook or extension to the `session-start` hook. The cleanest approach (confirmed by examining session-start) is a separate file `hooks/spec-session-record.sh` that runs on `SessionStart` — or alternatively, extend `session-start` itself.

**IMPORTANT constraint from session-start inspection:** The session-start hook already does branch-scoped state reset at lines 38-48. The spec-session record should survive branch resets if the SPEC.md is unchanged. Best approach: separate file `~/.claude/.silver-bullet/spec-session` that is only written (not reset) at session start.

**Logic:**

```bash
SPEC=".planning/SPEC.md"
[[ ! -f "$SPEC" ]] && exit 0  # no spec — nothing to record

spec_id=$(grep -m1 '^jira-id:' "$SPEC" | awk '{print $2}' | tr -d '"')
spec_version=$(grep -m1 '^spec-version:' "$SPEC" | awk '{print $2}')
jira_id="$spec_id"

spec_session_file="${HOME}/.claude/.silver-bullet/spec-session"
printf 'spec-version=%s\njira-id=%s\n' "$spec_version" "$jira_id" > "$spec_session_file"
```

**Two implementation options:**

| Option | Pros | Cons |
|--------|------|------|
| A. Extend session-start hook | Single hook fires | session-start is complex; harder to test in isolation |
| B. New hooks/spec-session-record.sh in SessionStart | Isolated, testable, follows SRP | Requires new hooks.json entry |

**Recommended: Option B** — new `spec-session-record.sh` registered in `SessionStart`. Follows the same pattern as `session-start`.

### TRAC-02/03: pr-traceability.sh Hook

**Event:** PostToolUse on Bash matcher.
**Trigger:** Command contains `gsd-ship`.

**Logic flow:**

```bash
# 1. Detect gsd-ship
if ! printf '%s' "$cmd" | grep -qE '\bgsd-ship\b'; then exit 0; fi

# 2. Read spec-session record
spec_session_file="${HOME}/.claude/.silver-bullet/spec-session"
[[ ! -f "$spec_session_file" ]] && exit 0  # no spec session — silent

spec_version=$(grep '^spec-version=' "$spec_session_file" | cut -d= -f2)
jira_id=$(grep '^jira-id=' "$spec_session_file" | cut -d= -f2)

# 3. Get PR URL from gh CLI
pr_url=$(/opt/homebrew/bin/gh pr view --json url --jq '.url' 2>/dev/null || true)
[[ -z "$pr_url" ]] && exit 0  # no PR yet — gsd-ship may not have created one

# 4. Read VALIDATION.md for WARN findings (VALD-04)
warn_items=""
if [[ -f ".planning/VALIDATION.md" ]]; then
  warn_items=$(grep '^\(FINDING \[WARN\]\)' .planning/VALIDATION.md || true)
fi

# 5. Update PR description
# Use gh pr edit to append spec traceability block
```

**PR description block (TRAC-02):**

```
---
## Spec Traceability (auto-generated by Silver Bullet)
- Spec: .planning/SPEC.md (v{spec-version})
- JIRA: {jira-id or "n/a"}
- Requirements covered: see SPEC.md ## Acceptance Criteria

### Deferred items (WARN findings from silver-validate)
{warn_items or "None"}
```

**TRAC-04 (Implementations update):** After getting the PR URL, append to SPEC.md `## Implementations` section:

```bash
SPEC=".planning/SPEC.md"
today=$(date '+%Y-%m-%d')
# Append after the <!-- comment --> in ## Implementations
entry="- PR: ${pr_url} | Date: ${today} | Spec-version: ${spec_version}"
# Use awk to insert after the ## Implementations comment line
```

Then commit the SPEC.md update:

```bash
git add .planning/SPEC.md
git commit -m "trace: link ${pr_url} to SPEC.md v${spec_version}"
```

**Failure mode:** If gsd-ship completes but no PR URL is found yet (PR may be created after push), the hook should emit a warning, not block. Exit 0 with advisory. The SPEC.md update can be deferred — this is PostToolUse, not PreToolUse.

### UATG-01/02: UAT.md from gsd-audit-uat

**Current state:** `gsd-audit-uat` is invoked in silver-feature Step 17 line 1. It is a GSD skill — SB cannot modify it (§8 plugin boundary). [VERIFIED: ARCHITECTURE.md anti-pattern 5]

**What SB controls:** The UATG-01/02 requirements say "gsd-audit-uat produces a UAT checklist derived from SPEC.md acceptance criteria." The production of UAT.md is something SB can instruct gsd-audit-uat to do by providing SPEC.md as context — or SB can produce UAT.md itself as a pre-step before invoking gsd-audit-uat.

**Design decision required (ASSUMED):** Since gsd-audit-uat behavior cannot be modified, SB has two options:
1. SB produces `.planning/UAT.md` from SPEC.md ACs before invoking gsd-audit-uat (SB owns the artifact)
2. SB post-processes gsd-audit-uat output into `.planning/UAT.md`

**Recommended approach:** Add a new step in silver-feature Step 17 sequence — before invoking gsd-audit-uat, SB generates `.planning/UAT.md` from SPEC.md acceptance criteria. Then gsd-audit-uat fills in pass/fail results. This keeps SB as the generator, gsd-audit-uat as the verifier.

**UAT.md format (UATG-02):**

```markdown
---
spec-version: {from .planning/SPEC.md}
spec-id: {jira-id from .planning/SPEC.md}
uat-date: YYYY-MM-DD
milestone: {milestone name}
---

# UAT Checklist — {feature name}

## Criteria

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | {AC item 1 verbatim from SPEC.md} | PASS / FAIL / NOT-RUN | {notes} |
| 2 | {AC item 2} | PASS / FAIL / NOT-RUN | |

## Summary

- Total: {N}
- PASS: {n}
- FAIL: {n}
- NOT-RUN: {n}

Overall: PASS / FAIL
```

### UATG-03/04: uat-gate.sh Hook

**Event:** PreToolUse on Bash matcher.
**Trigger:** Command contains `gsd-complete-milestone`.

**Logic flow:**

```bash
# 1. Detect gsd-complete-milestone
if ! printf '%s' "$cmd" | grep -qE '\bgsd-complete-milestone\b'; then exit 0; fi

# 2. Check UAT.md exists
UAT=".planning/UAT.md"
if [[ ! -f "$UAT" ]]; then
  emit_block "UAT GATE: .planning/UAT.md not found. Run /silver:feature Step 17 UAT generation before completing milestone."
  exit 0
fi

# 3. Check for any FAIL result (UATG-03)
if grep -qE '\| FAIL \|' "$UAT"; then
  fail_count=$(grep -cE '\| FAIL \|' "$UAT" || true)
  emit_block "UAT GATE: ${fail_count} criterion/criteria marked FAIL in .planning/UAT.md. Resolve all failures before completing milestone."
  exit 0
fi

# 4. Check NOT-RUN (warn but do not block — ASSUMED: NOT-RUN is advisory)
if grep -qE '\| NOT-RUN \|' "$UAT"; then
  not_run=$(grep -cE '\| NOT-RUN \|' "$UAT" || true)
  printf '{"hookSpecificOutput":{"message":"⚠️ UAT GATE: %s criterion/criteria NOT-RUN in .planning/UAT.md. Proceed with caution."}}'  "$not_run"
fi

# 5. Spec version check (UATG-04)
uat_spec_version=$(grep -m1 '^spec-version:' "$UAT" | awk '{print $2}')
current_spec_version=$(grep -m1 '^spec-version:' ".planning/SPEC.md" | awk '{print $2}')
if [[ -n "$uat_spec_version" && -n "$current_spec_version" && "$uat_spec_version" != "$current_spec_version" ]]; then
  emit_block "UAT GATE: UAT was run against spec v${uat_spec_version} but current SPEC.md is v${current_spec_version}. Re-run UAT against the current spec."
  exit 0
fi
```

### hooks.json Registration

**Additions required:**

```json
{
  "SessionStart": [
    {
      "matcher": "startup|clear|compact",
      "hooks": [
        {
          "type": "command",
          "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/spec-session-record.sh\"",
          "async": false
        }
      ]
    }
  ],
  "PostToolUse": [
    {
      "matcher": "Bash",
      "hooks": [
        {
          "type": "command",
          "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/pr-traceability.sh\"",
          "async": false
        }
      ]
    }
  ],
  "PreToolUse": [
    {
      "matcher": "Bash",
      "hooks": [
        {
          "type": "command",
          "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/uat-gate.sh\"",
          "async": false
        }
      ]
    }
  ]
}
```

**Note on uat-gate.sh matcher:** The ARCHITECTURE.md specifies `PreToolUse | Skill` matcher for uat-gate.sh. However, silver-feature Step 17 invokes `gsd-complete-milestone` via the Skill tool (not Bash). The matcher should be `Skill` — not `Bash`. In the Skill case, the input JSON has `.tool_input.skill` not `.tool_input.command`. [VERIFIED: record-skill.sh line 21 — Skill events use `.tool_input.skill`]

**uat-gate.sh for Skill event:**

```bash
# For Skill matcher, extract skill name
skill=$(printf '%s' "$input" | jq -r '.tool_input.skill // ""')
if ! printf '%s' "$skill" | grep -qE 'gsd-complete-milestone|gsd:complete-milestone'; then exit 0; fi
```

### silver-feature Integration (VALD-03 compliance)

The existing silver-feature Step 17 sequence is:

```
1. gsd-audit-uat
2. gsd-audit-milestone
3. gap-closure iteration
4. gsd-complete-milestone
```

For Phase 14, two changes to silver-feature SKILL.md are needed:

1. **Add Step 2.7** between Step 2.5 (writing-plans / gsd-plan-phase output) and Step 3 (quality-gates):
   - Invoke `silver:validate` via the Skill tool
   - If BLOCK findings: stop, user must resolve before proceeding

2. **Add UAT.md generation** before Step 17 item 1 (gsd-audit-uat):
   - Read SPEC.md acceptance criteria
   - Write `.planning/UAT.md` with NOT-RUN status for each criterion
   - Then invoke gsd-audit-uat to fill in results

### Documentation Pass (silver-bullet.md.base)

STATE.md decision: "Documentation pass embedded in Phase 14 — no separate docs phase."

Required additions to silver-bullet.md.base:
- **§2 Spec Lifecycle section:** When to run `/silver:spec` vs `/silver:ingest`, artifact locations (`.planning/SPEC.md`, `SPEC.main.md`, `DESIGN.md`), spec-version field, `## Implementations` section populated by hook
- **MCP prerequisites section:** Which MCP connectors are required (Atlassian, Figma, Google Drive), how to configure, what happens if unavailable
- **Validation gate documentation:** What silver-validate checks, BLOCK vs WARN vs INFO semantics, how to resolve BLOCK findings

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| PR URL extraction | Custom git log parsing | `gh pr view --json url --jq '.url'` | gh CLI already required, handles all auth cases |
| SPEC.md frontmatter parsing | Custom YAML parser | `grep -m1 '^spec-version:'` + `awk '{print $2}'` | SPEC.md uses simple line-based YAML — full parser is overkill |
| Session record storage | Custom database or JSON | Plain text key=value file in `~/.claude/.silver-bullet/` | Consistent with state file pattern in all existing hooks |
| UAT checklist from ACs | Complex extraction logic | Simple grep of `## Acceptance Criteria` section + line-by-line iteration | SPEC.md format is predictable after Phase 12 |
| JSON escaping in hooks | String concatenation | `jq -Rs '.'` pipe | Used in all existing hooks |

---

## Common Pitfalls

### Pitfall 1: gsd-ship Detection Timing

**What goes wrong:** `gsd-ship` is invoked via the Skill tool, which fires record-skill.sh PostToolUse. The Bash command that actually does `gh pr create` is a sub-call by gsd-ship's internal agent. pr-traceability.sh is registered on Bash PostToolUse — it will fire on every Bash call from gsd-ship, not just the final one.

**Why it happens:** PostToolUse fires on every Bash invocation, including internal git push, gh pr create, etc. The hook must detect the specific `gh pr create` or `gsd-ship` Bash invocation.

**How to avoid:** Two-stage detection — first check if `gsd-ship` marker is in the state file (meaning gsd-ship was invoked this session), then check if current Bash command contains `gh pr create`. This ensures the hook fires exactly when the PR is being created, not on unrelated Bash calls.

**Warning signs:** PR description updated multiple times in a session, or hook fires on git push before PR exists.

### Pitfall 2: Skill vs Bash Matcher for gsd-complete-milestone

**What goes wrong:** uat-gate.sh registered with `Bash` matcher when gsd-complete-milestone is invoked via Skill tool — hook never fires.

**Why it happens:** silver-feature Step 17 invokes `gsd-complete-milestone` as `Invoke gsd-complete-milestone via the Skill tool`. The Skill tool event does NOT produce a Bash PreToolUse event. The hook must use `Skill` matcher.

**How to avoid:** Use `Skill` matcher in hooks.json for uat-gate.sh. Extract skill name via `.tool_input.skill` not `.tool_input.command`. Test by checking what events fire during a silver-feature Step 17 run.

**Warning signs:** UAT gate never blocks even when UAT.md is missing.

### Pitfall 3: SPEC.md Not Present When Hook Fires

**What goes wrong:** spec-session-record.sh, pr-traceability.sh, and uat-gate.sh all read `.planning/SPEC.md`. On projects that don't use silver-bullet spec workflow, or where spec was created after session start, the file may not exist.

**Why it happens:** Hooks fire on every matched event regardless of project state.

**How to avoid:** Every hook must check `[[ -f ".planning/SPEC.md" ]] || exit 0` before reading. Silent exit when no SPEC.md — hook is a no-op for non-spec projects.

**Warning signs:** Hooks emit errors on projects without SPEC.md.

### Pitfall 4: PR Description Overwrite

**What goes wrong:** `gh pr edit --body` replaces the entire PR description, losing any content gsd-ship wrote.

**Why it happens:** Simple approach is destructive.

**How to avoid:** Use `gh pr view --json body --jq '.body'` to get current body, then append the traceability block. Or use `gh pr edit --body-file` with a temp file containing old body + new block. Never overwrite — always append.

### Pitfall 5: silver-validate Finding Format Inconsistency

**What goes wrong:** Silver-validate emits findings in prose format in some steps, machine-readable in others. pr-traceability.sh then can't parse VALIDATION.md.

**Why it happens:** Skill steps are written in natural language; implementor mixes formats.

**How to avoid:** Define the exact FINDING line format in the SKILL.md as a code block. Make the format the only acceptable output for the findings section. pr-traceability.sh uses `grep '^\(FINDING \[WARN\]\)'` — test this against the actual format before shipping.

### Pitfall 6: UAT.md spec-version vs SPEC.md spec-version

**What goes wrong:** UAT.md is generated before SPEC.md changes (e.g., spec augmented mid-implementation). UATG-04 version check then blocks completion even though UAT is valid.

**Why it happens:** SPEC.md spec-version increments each time silver-spec or silver-ingest is run in augment mode.

**How to avoid:** UAT.md is generated at Step 17 time (end of milestone). By then SPEC.md version should be stable. Document in SKILL.md: "Do not augment SPEC.md after UAT.md is generated without re-running UAT." Surface this as a WARN if SPEC.md spec-version has incremented since UAT was generated.

---

## Code Examples

### SPEC.md Frontmatter Reading (verified pattern)

```bash
# Source: silver-ingest/SKILL.md Step 5 + spec-floor-check.sh
spec_version=$(grep -m1 '^spec-version:' .planning/SPEC.md | awk '{print $2}')
jira_id=$(grep -m1 '^jira-id:' .planning/SPEC.md | awk '{print $2}' | tr -d '"')
```

### Acceptance Criteria Extraction

```bash
# Extract all AC items from SPEC.md ## Acceptance Criteria section
# Source: SPEC.md.template — ACs are "- [ ] " or "- [x] " prefixed lines in that section
awk '/^## Acceptance Criteria/{found=1; next} /^## /{found=0} found && /^- \[/{print}' .planning/SPEC.md
```

### Assumption Block Extraction (VALD-05)

```bash
# Extract all [ASSUMPTION: ...] blocks from SPEC.md
grep -o '\[ASSUMPTION:[^]]*\]' .planning/SPEC.md
```

### awk-based Section Insert (SPEC.md ## Implementations)

```bash
# Append PR entry to ## Implementations section
# Source: session-log-init.sh _insert_before pattern
entry="- PR: ${pr_url} | Date: $(date +%Y-%m-%d) | Spec-version: ${spec_version}"
tmp=$(mktemp)
awk -v entry="$entry" '
  /^## Implementations$/ { print; found=1; next }
  found && /^<!-- / { print; print ""; print entry; found=0; next }
  { print }
' .planning/SPEC.md > "$tmp" && mv "$tmp" .planning/SPEC.md
```

### gh PR description append

```bash
# Get current body, append traceability block
current_body=$(/opt/homebrew/bin/gh pr view --json body --jq '.body' 2>/dev/null || true)
traceability_block="---
## Spec Traceability (Silver Bullet auto-generated)
- Spec: .planning/SPEC.md (v${spec_version})
- JIRA: ${jira_id:-n/a}"
new_body="${current_body}

${traceability_block}"
/opt/homebrew/bin/gh pr edit --body "$new_body"
```

---

## Runtime State Inventory

Phase 14 is not a rename/refactor phase. No runtime state inventory applies.

New runtime state created by Phase 14:
- `~/.claude/.silver-bullet/spec-session` — written at session start, read by pr-traceability.sh
- `.planning/VALIDATION.md` — written by silver-validate, read by pr-traceability.sh
- `.planning/UAT.md` — written by silver-feature Step 17 pre-step, read by uat-gate.sh

---

## Environment Availability

| Dependency | Required By | Available | Fallback |
|------------|------------|-----------|---------|
| jq | All hooks | Yes (verified — all existing hooks require it) | None — hooks exit 0 with warning if missing |
| gh CLI at /opt/homebrew/bin/gh | pr-traceability.sh | Yes (memory note: use full path) | Exit 0 with warning — PR traceability disabled |
| git | pr-traceability.sh (SPEC.md commit) | Yes | n/a |
| .planning/SPEC.md | All 3 new hooks | Exists after Phase 12 completes | Each hook exits 0 silently if absent |

---

## Validation Architecture

Phase 14 deliverables are bash scripts and SKILL.md files. Validation is manual-run integration testing.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | bats (bash automated testing system) if present; manual otherwise |
| Quick run | Invoke each hook with mock JSON on stdin; observe stdout |
| Full run | End-to-end silver-feature Step 17 run against test-app with SPEC.md present |

### Phase Requirements Test Map

| Req ID | Test Type | How to Verify |
|--------|-----------|---------------|
| VALD-01 | Manual | Run /silver:validate on a project with SPEC.md and PLAN.md — inspect findings |
| VALD-02 | Manual | Confirm output contains `FINDING [BLOCK|WARN|INFO]` format lines |
| VALD-03 | Manual | Introduce a BLOCK finding; confirm silver-validate refuses to exit cleanly |
| VALD-04 | Manual | Run pr-traceability.sh after ship; confirm WARN items appear in PR description |
| VALD-05 | Manual | Include [ASSUMPTION: ...] blocks in SPEC.md; run validate; confirm they surface |
| TRAC-01 | Hook unit | `echo '{"hook_event_name":"SessionStart"}' \| ./hooks/spec-session-record.sh` with SPEC.md present; verify spec-session file written |
| TRAC-02 | Hook unit | `echo '{"hook_event_name":"PostToolUse","tool_input":{"command":"gsd-ship"}}' \| ./hooks/pr-traceability.sh` |
| TRAC-03 | Manual | Verify no manual annotation needed in PR description |
| TRAC-04 | Manual | After PR create, inspect .planning/SPEC.md ## Implementations |
| UATG-01 | Manual | Run silver-feature Step 17; verify UAT.md generated from SPEC.md ACs |
| UATG-02 | Manual | Inspect .planning/UAT.md for correct format |
| UATG-03 | Hook unit | `echo '{"hook_event_name":"PreToolUse","tool_input":{"skill":"gsd-complete-milestone"}}' \| ./hooks/uat-gate.sh` with no UAT.md present; verify deny |
| UATG-04 | Hook unit | UAT.md with spec-version: 1, SPEC.md with spec-version: 2 — verify version mismatch deny |

---

## Security Domain

| ASVS Category | Applies | Control |
|---------------|---------|---------|
| V5 Input Validation | Yes | All hooks validate command strings via grep -qE before acting; no eval of user input |
| V2 Authentication | No | No auth logic in these components |
| V6 Cryptography | No | No crypto operations |

**Known threat patterns:**

| Pattern | Risk | Mitigation |
|---------|------|------------|
| Path traversal in SPEC.md path | TRAC-01/pr-traceability.sh reads `.planning/SPEC.md` — if config overrides path, could escape | Validate SPEC path stays within project root (same pattern as SB-002/003 in stop-check.sh) |
| Injection via SPEC.md content | spec-version or jira-id used in git commit messages | Sanitize with `tr -d '"'` and validate alphanumeric+hyphen before embedding in commands |
| Symlink attack on spec-session file | `~/.claude/.silver-bullet/spec-session` | Reject symlinks before write (same pattern as trivial_file in completion-audit.sh line 135) |

---

## Open Questions

1. **gsd-audit-uat behavior (UATG-01)**
   - What we know: gsd-audit-uat is invoked in silver-feature Step 17; it is a GSD skill
   - What's unclear: Does gsd-audit-uat already produce any structured output that could become UAT.md? Or does SB need to fully own UAT.md generation?
   - Recommendation: [ASSUMED] SB generates UAT.md from SPEC.md ACs as a pre-step before invoking gsd-audit-uat. gsd-audit-uat is treated as a verification pass on top of SB's UAT.md scaffold. If gsd-audit-uat produces its own output, SB merges/updates the pre-generated UAT.md.

2. **NOT-RUN criteria in uat-gate.sh (UATG-03)**
   - What we know: UATG-03 says "blocks if UAT not run or any criterion marked FAIL"
   - What's unclear: Does NOT-RUN count as "UAT not run" and trigger a block?
   - Recommendation: [ASSUMED] NOT-RUN triggers a warning (not a hard block) — allowing teams to explicitly accept uncovered criteria. A FAIL always blocks. UAT.md with all NOT-RUN is advisory-only. A UAT.md with at least one PASS or FAIL is considered "UAT was run."

3. **TRAC-01 Session Record trigger timing**
   - What we know: session-start fires on `startup|clear|compact` matcher
   - What's unclear: Does SPEC.md exist at session start (it may be created mid-session by silver-spec)
   - Recommendation: spec-session-record.sh should also fire (or re-fire) when SPEC.md is first written — OR the pr-traceability.sh hook reads SPEC.md directly at ship time (not relying on the session record). The session record is for caching; direct SPEC.md read at ship time is more reliable for TRAC-02.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | NOT-RUN criteria produce WARN (not BLOCK) in uat-gate.sh | UATG-03 design | If NOT-RUN should be a block, teams with partial UAT coverage are perpetually blocked |
| A2 | SB generates UAT.md from SPEC.md ACs as a pre-step before gsd-audit-uat | UATG-01/02 design | If gsd-audit-uat already produces UAT.md, SB's pre-generation creates a conflict |
| A3 | pr-traceability.sh reads SPEC.md directly at ship time (not relying solely on spec-session record) | TRAC-02 reliability | If spec-session record is stale, traceability data is wrong |
| A4 | uat-gate.sh uses Skill matcher (not Bash) for gsd-complete-milestone | UATG-03 implementation | If gsd-complete-milestone is invoked via Bash in some workflows, hook never fires with Skill matcher |
| A5 | VALIDATION.md at .planning/VALIDATION.md is the right location for machine-readable findings | VALD-02/04 | If planner chooses a different location, pr-traceability.sh must be updated |

---

## Sources

### Primary (HIGH confidence — direct source inspection)
- `hooks/spec-floor-check.sh` — hook stdin/stdout protocol, command detection pattern, PreToolUse deny format
- `hooks/completion-audit.sh` — Bash matcher, gsd-ship detection approach, artifact existence checks
- `hooks/stop-check.sh` — config discovery, state file pattern, security path validation
- `hooks/session-start` — SessionStart hook structure, state file management, branch-scoped reset
- `hooks/session-log-init.sh` — session record pattern, SB_STATE_DIR convention
- `hooks/record-skill.sh` — Skill matcher stdin format (`.tool_input.skill`), state file appending
- `hooks/hooks.json` — current registration structure for all 5 event types
- `skills/silver-spec/SKILL.md` — SKILL.md authorship pattern, step structure, non-skippable gate annotation
- `skills/silver-ingest/SKILL.md` — SPEC.md frontmatter format, finding format patterns
- `skills/silver-feature/SKILL.md` lines 202-214 — Step 17 gsd-audit-uat invocation sequence
- `templates/specs/SPEC.md.template` — canonical SPEC.md structure, frontmatter fields, ## Implementations comment
- `.planning/STATE.md` — locked decisions (zero GSD modifications, three new hooks, three new skills)
- `.planning/research/ARCHITECTURE.md` — component responsibilities, integration points, anti-patterns

### Secondary (MEDIUM confidence)
- `.planning/research/SUMMARY.md` — pitfalls section (gate as rubber stamp, traceability as human annotation)

---

**Research date:** 2026-04-09
**Valid until:** 2026-05-09 (stable domain — SB hook protocol and SKILL.md pattern are well-established)
