# Phase 12: Spec Foundation — Research

**Researched:** 2026-04-09
**Domain:** AI-driven Socratic elicitation, canonical spec artifact design, bash hook enforcement gating
**Confidence:** HIGH (all findings based on direct inspection of existing SB source files and prior milestone research documents)

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SPEC-01 | SPEC.md with YAML frontmatter (spec-version, status, jira-id, figma-url, source-artifacts) and standardized sections (Overview, User Stories, UX Flows, Acceptance Criteria, Assumptions, Open Questions) | Template design — section list and frontmatter schema documented in Architecture Patterns |
| SPEC-02 | DESIGN.md with screen/component/behavior/state definitions extracted from design inputs | Template design — DESIGN.md section structure documented; ingestion from Phase 13 |
| SPEC-03 | `templates/specs/` directory with SPEC.md.template, DESIGN.md.template, REQUIREMENTS.md.template | File creation task — templates derived from section schemas here |
| SPEC-04 | Every unresolvable ambiguity produces `[ASSUMPTION: ...]` block in SPEC.md | Elicitation flow — assumption-first questioning pattern documented |
| SPEC-05 | `spec-version:` field in frontmatter that increments on each substantive change | Frontmatter schema — integer counter; increment rules documented |
| ELIC-01 | `silver-spec` skill guides PM/BA through Socratic elicitation — asks clarifying questions, surfaces gaps, produces SPEC.md + REQUIREMENTS.md | silver-spec SKILL.md design — full step sequence documented |
| ELIC-02 | Elicitation covers: user stories, acceptance criteria, UX flow definition, edge cases, error states, data model implications — through interactive dialogue | Questioning pattern table documented; turn-by-turn flow |
| ELIC-03 | At any point, user can provide Google Doc, PPT, or Figma link — SB extracts content and incorporates | Artifact injection pattern documented; limited to text extraction in Phase 12 |
| ELIC-04 | Elicitation produces assumption blocks for every gap the PM/BA cannot resolve on the spot | Assumption elicitation pattern — "I don't know yet" trigger documented |
| ELIC-05 | `silver-spec` can be invoked standalone (greenfield) or to augment an ingested draft (post-JIRA-ingestion refinement) | Mode selection pattern at skill entry; SPEC.md existence check documented |
| ELIC-06 | Elicitation orchestrates existing plugin skills (product-management:write-spec, design:user-research, design:design-critique) rather than reimplementing | Skill delegation via Skill tool — which skills and when documented |
| FLOR-01 | `spec-floor-check.sh` hook on `gsd-plan-phase` hard-blocks if `.planning/SPEC.md` missing or lacks required sections | Hook implementation pattern documented; PreToolUse/Bash matcher; exit code semantics |
| FLOR-02 | `gsd-fast` and `gsd-quick` use separate 3-field minimal spec format checked as warning, not hard block | Fast-path context detection pattern documented; 3-field schema defined |
| FLOR-03 | Spec floor check completes in under 10 seconds | Hook is file-existence + grep only; no network calls; <100ms demonstrated by existing hooks |
</phase_requirements>

---

## Summary

Phase 12 builds the canonical spec artifact layer that all of v0.14.0 depends on. Three deliverables: (1) template files in `templates/specs/`, (2) a `silver-spec` orchestration skill (SKILL.md only — no code), and (3) a `spec-floor-check.sh` bash hook registered in `hooks.json`.

The silver-spec skill follows the exact same orchestration-only pattern as silver-feature and silver-fast: it never implements anything, it only invokes other skills via the Skill tool and guides dialogue. The hook follows the exact same pattern as dev-cycle-check.sh and forbidden-skill-check.sh: stdin JSON parsing, jq for extraction, permissionDecision:deny output format for PreToolUse hard blocks.

**Primary recommendation:** Build in order — templates first (other tasks reference them), then silver-spec SKILL.md, then spec-floor-check.sh, then register in hooks.json, then update silver-bullet.md §2 and /silver router. Treat SPEC.md format as locked before writing any other deliverable.

---

## Project Constraints (from CLAUDE.md)

- **Stack**: Node.js
- **Git repo**: https://github.com/alo-exp/silver-bullet.git
- **silver-bullet.md overrides all defaults** — all enforcement lives there, CLAUDE.md is a thin scaffold
- **§8 Plugin Boundary**: SB NEVER modifies GSD plugin files. New hooks intercept at tool layer; spec-floor-check.sh must not touch GSD internals. [VERIFIED: hooks/dev-cycle-check.sh §8 enforcement section]
- **Hooks directory is self-protected**: dev-cycle-check.sh blocks writes to its own hooks directory. New hooks must be added as new files, never by editing existing hooks. [VERIFIED: hooks/dev-cycle-check.sh lines 80-103]
- **Three new skills, zero GSD modifications** — locked decision from STATE.md. [VERIFIED: .planning/STATE.md Decisions section]

---

## Standard Stack

### Core (No New Dependencies)

Phase 12 introduces no new language runtimes, npm packages, or external services. All deliverables are:
- SKILL.md files (markdown, no code)
- Bash shell scripts (hooks)
- Markdown template files

[VERIFIED: Inspection of all existing hooks — they are pure bash using only `jq`, `grep`, `cat`, standard POSIX tools]

| Tool | Version | Purpose | Source |
|------|---------|---------|--------|
| bash | system | Hook scripts | [VERIFIED: all existing hooks use `#!/usr/bin/env bash`] |
| jq | any (brew install) | JSON parsing of hook stdin | [VERIFIED: every hook checks `command -v jq` and fails gracefully] |
| grep | POSIX | Section presence check in spec-floor-check | [VERIFIED: Architecture research pattern example] |

### Supporting (Existing SB Infrastructure)

| Component | Type | Used By Phase 12 |
|-----------|------|------------------|
| hooks.json | Config | Register spec-floor-check.sh under PreToolUse |
| silver-bullet.md.base | Template | Add spec lifecycle to §2 |
| skills/silver/SKILL.md | Routing table | Add silver-spec intent signals |
| skills/silver-feature/SKILL.md | Orchestration skill | Add spec pre-flight step reference |

[VERIFIED: Direct file inspection of all four components]

---

## Architecture Patterns

### Recommended Project Structure (Phase 12 Changes Only)

```
silver-bullet/
├── skills/
│   └── silver-spec/              # NEW
│       └── SKILL.md              # Orchestration-only skill
├── hooks/
│   └── spec-floor-check.sh       # NEW: hard-blocks gsd-plan-phase without SPEC.md
├── templates/
│   └── specs/                    # NEW directory
│       ├── SPEC.md.template
│       ├── DESIGN.md.template
│       └── REQUIREMENTS.md.template
├── silver-bullet.md              # MODIFIED: §2 spec lifecycle section added
└── skills/
    └── silver/
        └── SKILL.md              # MODIFIED: new routing signals for silver-spec
```

### Pattern 1: Skill as Orchestration-Only (SKILL.md)

**What:** A SKILL.md file defines a step-by-step workflow. Each step invokes another skill via the Skill tool, asks the user a question, or reads/writes a file. The skill itself never implements logic — it sequences work.

**When to use:** All silver-* skills follow this pattern. silver-spec is identical in structure to silver-feature and silver-fast.

**Established conventions from existing skills:**
- YAML frontmatter: `name`, `description`, `argument-hint`
- Banner display using `━` box art
- Step-Skip Protocol block (non-skippable gates listed explicitly)
- Pre-flight §10 preferences read (except silver-fast which explicitly skips)
- Mode detection: standalone vs augment (check if `.planning/SPEC.md` exists at skill start)

[VERIFIED: skills/silver-feature/SKILL.md, skills/silver-fast/SKILL.md]

**silver-spec SKILL.md step sequence (design):**

```
Step 0: Mode detection
  — If .planning/SPEC.md exists → augment mode (refine existing)
  — Else → greenfield mode (create from scratch)

Step 1: Context Gathering
  — Ask: feature name, feature description, JIRA ticket (optional), Figma URL (optional)
  — If JIRA/Figma/Google Doc URL provided → note for artifact injection (ELIC-03)

Step 2: Invoke product-management:write-spec (ELIC-06)
  — Via Skill tool
  — Provides formal PM structure as scaffold

Step 3: Socratic Elicitation Dialogue
  — Run questioning turns in order: Problem → Who → What → Why → Constraints →
    Acceptance Criteria → Edge Cases → Error States → Data Model
  — After each answer: extract assumptions using assumption trigger (ELIC-04)
  — After each section: ask "Anything else, or move to next topic?"

Step 4: Artifact Injection (if URL provided in Step 1)
  — Display URL, show 3-bullet extraction summary
  — Ask: "Incorporate this into the spec? A. Yes  B. Skip"
  — If Figma URL: invoke design:user-research via Skill tool (ELIC-06)
  — If Google Doc/PPT: extract text content via Read tool or MCP (Phase 12 scope: text only)

Step 5: Assumption Consolidation
  — Collect all [ASSUMPTION: ...] blocks surfaced during dialogue
  — Ask PM/BA to confirm: resolve, accept, or tag each for follow-up (ELIC-04)

Step 6: Invoke design:design-critique (if design artifact provided) (ELIC-06)

Step 7: Write .planning/SPEC.md
  — From SPEC.md.template, populate all sections from elicitation answers
  — Increment spec-version: (1 for new, +1 for augment)
  — Set status: Draft

Step 8: Write .planning/REQUIREMENTS.md
  — Derive requirement IDs from acceptance criteria

Step 9: Commit artifacts
  — git add .planning/SPEC.md .planning/REQUIREMENTS.md
  — git commit "spec: [feature-slug] v{spec-version} initial draft"

Step 10: Summary
  — Show spec-version, section counts, assumption count, open questions count
  — "Next: run /silver:feature to begin implementation planning"
```

### Pattern 2: Hook as Hard Gate (PreToolUse Bash)

**What:** A bash script reads hook JSON from stdin, extracts the Bash command being attempted, detects if it matches a blocked pattern, and emits a deny response. Registered in hooks.json PreToolUse.

**Existing pattern (verbatim from dev-cycle-check.sh):**

```bash
#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR
umask 0077

if ! command -v jq >/dev/null 2>&1; then
  printf '{"hookSpecificOutput":{"message":"⚠️ ..."}}'
  exit 0
fi

input=$(cat)
hook_event=$(printf '%s' "$input" | jq -r '.hook_event_name // "PostToolUse"')

emit_block() {
  local reason="$1"
  local json_reason
  json_reason=$(printf '%s' "$reason" | jq -Rs '.')
  if [[ "$hook_event" == "PreToolUse" ]]; then
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}' "$json_reason"
  else
    printf '{"decision":"block","reason":%s,"hookSpecificOutput":{"message":%s}}' "$json_reason" "$json_reason"
  fi
}

cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
[[ -z "$cmd" ]] && exit 0
```

[VERIFIED: hooks/dev-cycle-check.sh lines 1-44, hooks/completion-audit.sh lines 1-44]

**spec-floor-check.sh logic design:**

```bash
# After boilerplate above:

# Detect command type — is this gsd-plan-phase or gsd-fast?
is_plan_phase=false
is_fast=false

if printf '%s' "$cmd" | grep -qE '\bgsd-plan-phase\b|\bgsd[- ]plan[- ]phase\b'; then
  is_plan_phase=true
elif printf '%s' "$cmd" | grep -qE '\bgsd-fast\b|\bgsd[- ]fast\b|\bgsd[- ]quick\b'; then
  is_fast=true
fi

# Exit early if neither
[[ "$is_plan_phase" == false && "$is_fast" == false ]] && exit 0

SPEC=".planning/SPEC.md"
FAST_SPEC=".planning/SPEC.fast.md"  # 3-field minimal format

if [[ "$is_plan_phase" == true ]]; then
  # HARD BLOCK: SPEC.md must exist with required sections
  if [[ ! -f "$SPEC" ]]; then
    emit_block "SPEC FLOOR VIOLATION: .planning/SPEC.md is missing.
Run /silver:spec before planning. gsd-plan-phase requires a minimum viable spec."
    exit 0
  fi
  for section in "## Overview" "## Acceptance Criteria"; do
    if ! grep -q "^${section}" "$SPEC"; then
      emit_block "SPEC FLOOR VIOLATION: .planning/SPEC.md is missing required section: ${section}
Run /silver:spec to complete the spec before planning."
      exit 0
    fi
  done
fi

if [[ "$is_fast" == true ]]; then
  # WARNING ONLY: emit advisory, do not block
  if [[ ! -f "$SPEC" && ! -f "$FAST_SPEC" ]]; then
    printf '{"hookSpecificOutput":{"message":"⚠️  SPEC FLOOR ADVISORY: No .planning/SPEC.md found. Fast path proceeding without spec floor. For tracked work, run /silver:spec first."}}'
  fi
fi

exit 0
```

**Key implementation notes:**
- `trap 'exit 0' ERR` is REQUIRED — any unexpected failure must not block the tool call
- `umask 0077` is REQUIRED — matches all existing hooks
- jq absence must degrade gracefully (emit advisory, exit 0)
- Check must complete in <100ms — file existence + grep on a small file is well under 10ms
- The hook fires on ALL Bash calls matching the pattern, not just the exact gsd-plan-phase invocation. The command string detection must be robust (slash-command style and direct command style)

[VERIFIED: Pattern from hooks/dev-cycle-check.sh and hooks/forbidden-skill-check.sh]

### Pattern 3: hooks.json Registration

**Existing structure (from hooks/hooks.json):**
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/spec-floor-check.sh\"",
            "async": false
          }
        ]
      }
    ]
  }
}
```

New hooks are appended to existing arrays, not replacing them. spec-floor-check.sh matches "Bash" (same as ci-status-check.sh and completion-audit.sh).

[VERIFIED: hooks/hooks.json full inspection]

**CRITICAL CONSTRAINT:** hooks/hooks.json is self-protected by dev-cycle-check.sh (lines 83-88). It cannot be edited via Claude's Edit/Write tools. The plan must instruct Claude to use Bash to write a new hooks.json using `node -e` or `jq` to merge the new hook entry — or use a safe path that avoids the self-protection trigger. [VERIFIED: hooks/dev-cycle-check.sh lines 80-103]

**Resolution:** The hook self-protection checks for write commands targeting the hooks directory. Using `jq` to transform and redirect hooks.json will trigger the guard. The plan must instruct the executor to disable the guard temporarily via a specific whitelisted approach, OR the plan must instruct the user to make this specific edit manually after reviewing the diff. This is the one edit that cannot be automated by Claude.

[ASSUMED: The self-protection bypass approach needs to be decided — option A: manual user edit, option B: a dedicated `silver:init` step that handles hooks.json writes without triggering the guard. This is a planning decision, not a research gap. Risk if wrong: executor gets blocked mid-plan trying to update hooks.json.]

### Pattern 4: Socratic Elicitation — Questioning Flow

**What:** A structured turn-by-turn dialogue where each turn elicits one domain from the PM/BA. After each answer, the AI surfaces implicit assumptions using specific triggers.

**Domain sequence (industry-standard requirements elicitation):**
[ASSUMED: Based on training knowledge of requirements engineering practice — Gause & Weinberg, IEEE 29148. Not verified against specific external source in this session. Risk: alternative ordering may be preferred by specific teams.]

| Turn | Domain | Question Pattern | Assumption Trigger |
|------|--------|-----------------|-------------------|
| 1 | Problem | "What problem does this solve? For whom?" | "I'm assuming the user is [X] — is that right?" |
| 2 | User goal | "When a user reaches this feature, what do they want to accomplish?" | "I'm assuming success means [X]" |
| 3 | Scope boundary | "What is explicitly OUT of scope for this feature?" | "I'm assuming [related thing] is not included" |
| 4 | User stories | "Walk me through the main thing a user does with this feature, step by step" | After each step: "I'm assuming [step detail]" |
| 5 | Acceptance criteria | "How do we know this works correctly? List one criterion at a time" | "I'm noting [criterion] as testable — does it have a measurable threshold?" |
| 6 | Edge cases | "What happens when [common failure scenario]?" | "I'm assuming [edge case] is handled by [default behavior]" |
| 7 | Error states | "What should the user see when something goes wrong?" | "I'm assuming error messages are in [language/tone]" |
| 8 | Data model | "What data does this feature create, read, update, or delete?" | "I'm assuming [data entity] already exists in the system" |
| 9 | Open questions | "What do you not know yet that would affect the spec?" | These are direct open questions — no assumption needed |

**"I don't know yet" trigger:** When PM/BA says they cannot resolve an ambiguity on the spot, the skill emits: `[ASSUMPTION: {what SB is assuming} | Tagged: follow-up-required]` — this satisfies ELIC-04.

**Readiness signal:** The spec is "ready" when:
- All 9 turn domains have at least one answer (even partial)
- All `[ASSUMPTION]` blocks are tagged (resolved OR follow-up-required)
- Overview and Acceptance Criteria sections are non-empty
This matches the spec-floor-check.sh minimum viable definition.

### Pattern 5: SPEC.md Template Structure (SPEC-01)

```markdown
---
spec-version: 1
status: Draft
jira-id: ""
figma-url: ""
source-artifacts: []
created: YYYY-MM-DD
last-updated: YYYY-MM-DD
---

# [Feature Name] — Spec

## Overview

[2-3 sentence problem statement. Who has the problem. What the problem is.]

## User Stories

- As a [persona], I want to [action] so that [outcome].

## UX Flows

[Step-by-step user journey for the primary use case.]

1. User [action]
2. System [response]
3. ...

## Acceptance Criteria

- [ ] [Measurable, testable criterion]
- [ ] [Criterion with explicit pass/fail threshold]

## Assumptions

<!-- Every unresolvable ambiguity during elicitation produces an entry here. -->

- [ASSUMPTION: {what is assumed} | Status: {Resolved / Follow-up-required} | Owner: {name or TBD}]

## Open Questions

<!-- Questions that must be answered before implementation begins. -->

- [ ] [Question] — Owner: {name or TBD}

## Out of Scope

- [Explicit exclusion]

## Implementations

<!-- Populated automatically by pr-traceability.sh hook post-merge. -->
```

[ASSUMED: Section names are canonical for this project — no prior SPEC.md file exists to inspect. Risk: PM/BA team may request different section names. This can be overridden by config later.]

### Pattern 6: DESIGN.md Template Structure (SPEC-02)

```markdown
---
spec-version: 1
linked-spec: .planning/SPEC.md
figma-url: ""
last-updated: YYYY-MM-DD
---

# [Feature Name] — Design

## Screens

### [Screen Name]
**Purpose:** [what the user sees and does here]
**Entry point:** [how user reaches this screen]
**Exit points:** [navigation options from this screen]

## Components

### [Component Name]
**Type:** [button / modal / form / list / card / etc.]
**State variants:** [default / loading / error / empty / success]
**Behavior:** [what happens on interaction]

## Behavior Specifications

| Trigger | Condition | System Response |
|---------|-----------|-----------------|
| [user action] | [state] | [what the system does] |

## State Definitions

| State | Description | Visual Indicator |
|-------|-------------|-----------------|
| [state name] | [what it means] | [how it looks] |

## Design Tokens (from Figma)

<!-- Populated by silver-ingest (Phase 13) from Figma MCP. Empty until then. -->
```

[ASSUMED: Section structure derived from standard UX documentation practice and requirements in SPEC-02. No prior DESIGN.md to inspect. Risk: LOW — structure is additive and won't break any downstream consumers in Phase 12.]

### Pattern 7: REQUIREMENTS.md Template Structure

```markdown
# Requirements: [Feature Name]

**Derived from:** .planning/SPEC.md v{spec-version}
**Generated:** YYYY-MM-DD

## Functional Requirements

| ID | Requirement | Acceptance Criterion | Priority |
|----|-------------|----------------------|---------|
| REQ-01 | [derived from User Story] | [from Acceptance Criteria section] | P1 |

## Non-Functional Requirements

| ID | Requirement | Metric | Priority |
|----|-------------|--------|---------|
| NFR-01 | [performance, security, accessibility concern] | [measurable target] | P1 |

## Out of Scope

[Mirror from SPEC.md Out of Scope]

## Open Items

[Mirror from SPEC.md Open Questions]
```

### Pattern 8: Fast-Path Minimal Spec (FLOR-02)

The 3-field minimal spec for gsd-fast and gsd-quick lives at `.planning/SPEC.fast.md`:

```markdown
---
spec-type: fast
what: ""
why: ""
acceptance-criteria: ""
---
```

spec-floor-check.sh checks for this file OR the full SPEC.md when triggered by gsd-fast. If neither exists, emits advisory (not hard block).

The minimal spec is created by the PM/BA as a one-liner before invoking silver-fast. silver-fast SKILL.md should add a note prompting for this. It is NOT generated by silver-spec (that produces the full SPEC.md).

### Anti-Patterns to Avoid

- **Hard-blocking gsd-fast with spec-floor check**: defeats the fast-path purpose; trains users to bypass the hook. spec-floor-check must detect fast-path context and downgrade to warning. [VERIFIED: ARCHITECTURE.md Anti-Pattern 3]
- **Storing SPEC.md outside .planning/**: spec-floor-check.sh and future Phase 13/14 hooks all hardcode `.planning/SPEC.md`. Do not put it in docs/ or project root.
- **Implementing elicitation logic in the hook**: hooks must be <10 seconds; they check for artifact existence/minimum sections only. All dialogue logic lives in silver-spec SKILL.md.
- **Modifying GSD files to enforce spec floor**: the PreToolUse Bash hook fires before any Bash command including those within GSD. No GSD file changes needed. [VERIFIED: ARCHITECTURE.md Anti-Pattern 5]
- **Editing hooks.json via Claude Edit/Write tool**: self-protected by dev-cycle-check.sh. Plan must account for this.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Spec document structure | Custom spec format | SPEC.md.template with fixed sections | Downstream hooks (Phase 13/14) parse fixed section names; custom format breaks them |
| Requirements elicitation questions | Novel question set | Turn-based domain sequence (table in Pattern 4) | Industry-validated; covers ELIC-02's required domains exactly |
| Plugin skill capabilities | Re-implement write-spec / user-research / design-critique | Invoke via Skill tool (ELIC-06) | §8 plugin boundary; reimplementation duplicates drift-prone logic |
| Hook JSON parsing | Custom parser | jq (as all existing hooks do) | Consistent, proven, error-handled same way across all hooks |
| Spec version management | Custom versioning scheme | Integer counter in YAML frontmatter | git history is the full audit log; frontmatter counter enables downstream pinning (Phase 13) |

---

## Common Pitfalls

### Pitfall 1: Assumption Avoidance During Elicitation

**What goes wrong:** silver-spec generates answers from context without surfacing implicit assumptions as `[ASSUMPTION: ...]` blocks. Spec looks complete but hides gaps.
**Why it happens:** AI tendency to produce plausible-sounding complete answers rather than flagging uncertainty.
**How to avoid:** silver-spec SKILL.md must include explicit instruction: "After every elicitation answer, ask yourself: What am I assuming the PM/BA meant? State it. If they cannot confirm, produce an [ASSUMPTION] block." The SKILL.md step instructions must be prescriptive on this.
**Warning signs:** SPEC.md with zero or one [ASSUMPTION] blocks is suspicious for any non-trivial feature.

### Pitfall 2: hooks.json Self-Protection Lock

**What goes wrong:** Executor tries to Edit or Write hooks.json to add spec-floor-check.sh registration, and dev-cycle-check.sh blocks it.
**Why it happens:** SB's own hook self-protection prevents writes to the hooks directory and hooks.json.
**How to avoid:** Plan must explicitly address this. Options:
  - A. Instruct executor to make this specific edit via `node -e` JSON transformation piped to redirect — but this may also trigger the Bash write guard.
  - B. (RECOMMENDED) Plan includes a manual step: "Review and apply the diff to hooks.json shown below — make this edit in your terminal outside Claude." The plan shows the exact JSON block to add.
  - C. silver:init handles hooks.json writes specially (future; not in Phase 12 scope).
**Warning signs:** Plan tries to automate hooks.json addition without addressing the guard.

### Pitfall 3: Context Detection in spec-floor-check.sh

**What goes wrong:** Hook fires on unrelated Bash commands that happen to mention "plan" or "fast" in arguments, producing false positives.
**Why it happens:** Overly broad grep pattern.
**How to avoid:** Pattern should match the explicit gsd-plan-phase command invocation style. Use word-boundary anchors (`\b`). Test pattern against representative commands before writing the hook.

### Pitfall 4: Elicitation Producing Natural-Language-Only Output

**What goes wrong:** silver-spec outputs a prose summary of the conversation instead of a structured .md file with fixed sections.
**Why it happens:** AI defaults to conversational output.
**How to avoid:** Step 7 in silver-spec SKILL.md must explicitly write to file using the Write tool from the SPEC.md.template. The template enforces structure; the elicitation provides content.

### Pitfall 5: spec-version Not Incrementing on Augment

**What goes wrong:** User runs silver-spec in augment mode (SPEC.md already exists), makes substantial changes, but spec-version stays at 1.
**Why it happens:** Step 7 overwrites frontmatter without checking existing version.
**How to avoid:** Step 7 in silver-spec SKILL.md must: (a) read existing spec-version if SPEC.md exists, (b) increment by 1, (c) write updated value. The skill instructions must spell this out.

---

## Artifact Injection Mid-Elicitation (ELIC-03 — Phase 12 Scope)

**Phase 12 scope limit:** Phase 13 handles full MCP connector ingestion. Phase 12 handles the case where a user provides a URL during elicitation.

**What silver-spec does in Phase 12 when a URL is provided:**
1. If Google Doc URL: attempt text extraction via WebFetch tool. If accessible, show 3-bullet summary, ask to incorporate.
2. If Figma URL: record URL in `figma-url:` frontmatter field; invoke design:user-research via Skill tool for design context (ELIC-06). Full Figma MCP extraction deferred to Phase 13.
3. If any URL: show extraction attempt result, ask PM/BA to confirm incorporation.

This approach satisfies ELIC-03's requirement that users CAN provide URLs mid-elicitation while honestly representing that deep extraction depends on Phase 13 MCP connectors.

[ASSUMED: WebFetch tool is available within silver-spec skill context. Risk: LOW — WebFetch is a standard Claude tool.]

---

## Skill Delegation Map (ELIC-06)

Which existing plugin skills silver-spec delegates to, and when:

| Existing Skill | Invoked Via | When | Purpose |
|----------------|-------------|------|---------|
| `product-management:write-spec` | Skill tool | Step 2 (after context gathering) | Generate formal PM spec scaffold |
| `design:user-research` | Skill tool | Step 4 (if Figma URL provided) | Extract design intent from Figma context |
| `design:design-critique` | Skill tool | Step 6 (if design artifact exists) | Validate design decisions in spec |

[ASSUMED: These skills exist in the installed plugin set. The existing skill inventory was not enumerated in this session — only that ELIC-06 requires them. Risk: MEDIUM — if a skill name differs from expectation, invocation fails. Executor should verify skill names against installed plugins before writing the SKILL.md.]

---

## Environment Availability

Phase 12 has no new external dependencies. All deliverables are markdown files and bash scripts.

| Dependency | Required By | Available | Notes |
|------------|------------|-----------|-------|
| bash | spec-floor-check.sh | ✓ | All existing hooks use bash |
| jq | spec-floor-check.sh | ✓ (expected) | All existing hooks depend on jq; if missing they degrade gracefully |
| grep | spec-floor-check.sh | ✓ | POSIX standard |

No network dependencies, no npm packages, no new runtimes.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | SPEC.md section names are canonical for this project — no prior format exists | Pattern 5 (SPEC.md template) | PM/BA team may want different section names; templates would need revision |
| A2 | DESIGN.md section structure matches standard UX doc practice | Pattern 6 (DESIGN.md template) | Structure may not match team expectations; low impact since it is populated by elicitation |
| A3 | Socratic questioning sequence follows industry-standard elicitation order | Pattern 4 (questioning flow) | Teams may prefer different sequencing; SKILL.md steps can be reordered with no structural impact |
| A4 | product-management:write-spec, design:user-research, design:design-critique skill names match installed plugins | Skill Delegation Map | If skill name differs, Skill tool invocation fails; executor must verify before writing silver-spec |
| A5 | WebFetch tool is available within silver-spec skill context for Google Doc text extraction | Artifact Injection section | If unavailable, ELIC-03 degrades to "record URL only until Phase 13" — acceptable fallback |
| A6 | hooks.json self-protection prevents automated hooks.json update from Claude | Pitfall 2 | If the guard is more nuanced than inspected, a safe automated path may exist; manual edit recommendation is conservative but safe |

---

## Open Questions

1. **hooks.json update approach**
   - What we know: dev-cycle-check.sh blocks writes to hooks directory and hooks.json via Edit/Write tools and Bash write commands
   - What's unclear: whether a `jq` + redirect command in Bash would bypass the guard (the guard checks for write commands including `tee`, `>`, `>>`; a `jq . hooks.json > hooks.json.new && mv hooks.json.new hooks.json` pattern may also trigger)
   - Recommendation: Plan conservatively — show the exact JSON diff and instruct user to apply manually in terminal. Mark as a manual step in PLAN.md.

2. **Plugin skill name verification**
   - What we know: ELIC-06 requires orchestrating product-management:write-spec, design:user-research, design:design-critique
   - What's unclear: exact namespace:skill-name format for these skills in the installed plugin
   - Recommendation: First task in Plan Wave 1 should be `ls ~/.claude/plugins/cache/` and read plugin SKILL index to confirm exact names before writing silver-spec SKILL.md.

3. **gsd-quick existence**
   - What we know: FLOR-02 references "gsd-fast and gsd-quick" — but only silver-fast was found in the SB skills directory. gsd-quick may be a GSD command not a SB skill.
   - What's unclear: whether spec-floor-check.sh needs to detect gsd-quick as a separate command pattern
   - Recommendation: spec-floor-check.sh should match both `gsd-fast` and `gsd-quick` command patterns; add both to the fast-path detection regex.

---

## Sources

### Primary (HIGH confidence — direct file inspection)
- `/Users/shafqat/Documents/Projects/silver-bullet/hooks/hooks.json` — hook registration format, event types, matcher patterns
- `/Users/shafqat/Documents/Projects/silver-bullet/hooks/dev-cycle-check.sh` — emit_block pattern, self-protection logic, stdin JSON parsing
- `/Users/shafqat/Documents/Projects/silver-bullet/hooks/forbidden-skill-check.sh` — PreToolUse deny pattern, jq-absent graceful degradation
- `/Users/shafqat/Documents/Projects/silver-bullet/hooks/completion-audit.sh` — hook boilerplate structure
- `/Users/shafqat/Documents/Projects/silver-bullet/skills/silver-feature/SKILL.md` — orchestration skill structure, step-skip protocol, non-skippable gates
- `/Users/shafqat/Documents/Projects/silver-bullet/skills/silver-fast/SKILL.md` — fast-path pattern, complexity triage
- `/Users/shafqat/Documents/Projects/silver-bullet/skills/silver/SKILL.md` — routing table format, intent signals
- `/Users/shafqat/Documents/Projects/silver-bullet/.planning/STATE.md` — locked architectural decisions for v0.14.0
- `/Users/shafqat/Documents/Projects/silver-bullet/.planning/REQUIREMENTS.md` — SPEC/ELIC/FLOR requirement definitions
- `/Users/shafqat/Documents/Projects/silver-bullet/.planning/research/ARCHITECTURE.md` — component responsibilities, anti-patterns, data flow
- `/Users/shafqat/Documents/Projects/silver-bullet/.planning/research/FEATURES.md` — capability area analysis, existing skills to reuse
- `/Users/shafqat/Documents/Projects/silver-bullet/.planning/research/SUMMARY.md` — v0.14.0 executive summary, critical pitfalls

### Tertiary (LOW confidence — training knowledge tagged ASSUMED)
- Socratic elicitation domain sequence (Gause & Weinberg requirements engineering pattern) — A3
- UX documentation section conventions — A2

---

## Metadata

**Confidence breakdown:**
- Template structure (SPEC.md/DESIGN.md/REQUIREMENTS.md): MEDIUM — schemas designed from requirements + industry conventions; no prior artifact to inspect
- silver-spec SKILL.md step sequence: HIGH — directly modeled on silver-feature which was fully inspected
- spec-floor-check.sh implementation: HIGH — directly modeled on dev-cycle-check.sh which was fully inspected
- hooks.json registration: HIGH — format directly inspected
- Artifact injection scope: HIGH — Phase 12 limit clearly documented; Phase 13 dependency explicit
- Plugin skill names (ELIC-06): MEDIUM — skills referenced by requirements but not confirmed by inventory

**Research date:** 2026-04-09
**Valid until:** 2026-05-09 (stable — no external API dependencies in Phase 12)
