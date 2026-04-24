# FORGE TASK: Port Silver Bullet to Forge

## OBJECTIVE

Build a complete Forge-native implementation of the Silver Bullet (SB) development workflow system. SB is currently a Claude Code plugin with 41 skills and 23 hooks. Your job is to port all of it into Forge's native primitives: AGENTS.md files and `.forge/skills/` SKILL.md files with YAML frontmatter trigger keywords.

Work in the current directory (silver-bullet repo). Branch: `feat/forge-sb-native-port` off `main`.

---

## CONTEXT

**What Silver Bullet is:**
A development workflow orchestration system for AI coding agents. It chains: brainstorm → specify → plan → execute → verify → secure → ship. It enforces 9 quality dimensions at design-time and pre-ship. It enforces TDD red-green-refactor. It routes feature/bugfix/UI/devops/research/release requests to the right sub-workflow.

**What Forge has (use these):**
- `~/forge/AGENTS.md` — global instructions, read at every Forge session start
- `./AGENTS.md` — project instructions, also read at start
- `.forge/skills/*/SKILL.md` — trigger-keyword-activated skills (YAML frontmatter + body)
- `docs/sessions/YYYY-MM-DD.md` — session logs (audit trail, replaces TodoWrite)
- `.forge.toml` — context management settings

**This repo structure (read before starting):**
- `skills/` — 41 existing Claude Code skills (source material — adapt, don't copy verbatim)
- `hooks/` — 23 existing hooks (map to AGENTS.md instructions)
- `silver-bullet.md` — master SB doc (read for session startup behavior)

**SKILL.md format requirements (hard constraints):**
```yaml
---
id: <kebab-case-id>
title: <Human Readable Title>
description: <One sentence describing what this skill does>
trigger:
  - "<trigger phrase 1>"
  - "<trigger phrase 2>"
---

# Title

[Imperative prose. Steps numbered. No Claude Code tool names.]
```

**Forbidden in any SKILL.md:** `TodoWrite`, `AskUserQuestion`, `Skill`, `NotebookEdit`, `Write tool`, `Bash tool`, `Read tool` (use "write file", "run command", "read file" instead). No plugin-system references.

**Body budget:** ≤ 2000 tokens per SKILL.md. AGENTS.md ≤ 200 lines.

---

## DEVELOPMENT METHODOLOGY (follow exactly — embedded so you get SB/GSD discipline without installation)

### The Phase Loop

For every implementation phase, execute in order:
```
BRAINSTORM → PLAN → EXECUTE → VERIFY → SHIP
```

**BRAINSTORM** (before each phase):
1. List what you're building and why
2. Generate 2-3 distinct approaches with trade-offs
3. State your recommendation with reasoning
4. Document key decisions in `docs/sessions/YYYY-MM-DD.md`

**PLAN** (before executing):
1. Break phase into atomic tasks (each completable in isolation)
2. State per task: what file, what content, what success looks like
3. Note dependencies between tasks
4. Document in `.planning/PLAN.md` (create `.planning/` if absent)

**EXECUTE** (implementation):
1. One task at a time — verify each before moving on
2. Commit after each logical unit
3. Commit message format: `feat(forge-sb): <description>`
4. DCO on every commit: `Signed-off-by: Shafqat Ullah <shafqat@sourcevo.com>`
5. Track progress in session log with ✅/❌ per task

**VERIFY** (after all tasks):
1. Run `tests/smoke-test.sh` — must pass before phase is done
2. Check every deliverable against success criteria
3. Write `.planning/VERIFICATION.md` with results

**SHIP** (when verified):
1. Push branch
2. Create PR: title "feat(forge-sb): Silver Bullet native port", body listing phases completed + verification evidence

---

### Quality Gates (run before PLAN and again before SHIP)

For each of the 9 dimensions, mark every item ✅ Pass / ❌ Fail / ⚠️ N/A (with justification). **Any ❌ = hard stop — redesign before proceeding.**

**1. Modularity**
- [ ] Each SKILL.md has one clear purpose (single job)
- [ ] No skill depends on another skill's internal state
- [ ] AGENTS.md sections are clearly separated by concern
- [ ] A Forge user can understand each skill independently

**2. Reusability**
- [ ] Quality dimension skills are usable standalone (not only via quality-gates master)
- [ ] GSD skills work both standalone and as steps in silver-feature workflow
- [ ] Global AGENTS.md template applies to any project (no hard-coded project paths)
- [ ] No copy-paste content > 10 lines across SKILL.md files

**3. Scalability**
- [ ] Adding a new quality dimension = 1 new SKILL.md + 1 line in quality-gates master
- [ ] Adding a new GSD sub-command = 1 new SKILL.md + 1 routing entry in silver
- [ ] AGENTS.md stays ≤ 200 lines
- [ ] Skill bodies stay ≤ 2000 tokens

**4. Security**
- [ ] No skills write to ~/.ssh, ~/.aws, ~/.gnupg, or credential stores
- [ ] forge-sb-install.sh never runs `rm -rf` on user directories it doesn't own
- [ ] Installer is idempotent (running twice = same result, no data loss)
- [ ] No API keys or secrets in any SKILL.md or AGENTS.md template

**5. Reliability**
- [ ] Every skill has a defined trigger condition (when it fires)
- [ ] Every skill has a defined exit condition (when it's done)
- [ ] Skills degrade gracefully if expected files (.planning/PLAN.md, etc.) are absent
- [ ] Silver router handles unrecognized intent (asks question, doesn't silently fail)

**6. Usability**
- [ ] A Forge user can start the SB workflow by typing "silver feature" or similar trigger
- [ ] Each skill provides progress signals (step counts, current step, done condition)
- [ ] Error messages tell the user what to do, not just what went wrong
- [ ] silver-feature proposes composition and confirms before executing

**7. Testability**
- [ ] forge-sb-install.sh has `--dry-run` flag
- [ ] smoke-test.sh verifies all skills installed and trigger keywords present
- [ ] Quality gate checklist items are binary (✅/❌), not subjective
- [ ] Tests are committed BEFORE implementation (TDD — see below)

**8. Extensibility**
- [ ] New skill = create SKILL.md + no changes to installer or AGENTS.md
- [ ] Trigger keyword system is open (any phrase can be a trigger)
- [ ] Project-specific skills (.forge/skills/) and global (~/forge/skills/) don't conflict

**9. AI/LLM Safety**
- [ ] AGENTS.md never instructs Forge to skip security reviews
- [ ] Quality-gates SKILL.md marks security items as non-N/A
- [ ] TDD skill includes the iron law verbatim
- [ ] No skill instructs Forge to use `--no-verify` or bypass DCO

---

### TDD Iron Law

```
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
```

**For this task:**
1. Write `tests/smoke-test.sh` with `exit 1` stubs first
2. Commit: `[RED] test(forge-sb): smoke tests — N skills expected`
3. Implement all skill files
4. Run smoke-test.sh — confirm it passes
5. Commit: `[GREEN] feat(forge-sb): all smoke tests pass`

**Red flags — if any of these are true, you've violated TDD:**
- Implementation committed before smoke-test.sh exists
- Smoke test passes on first run before any skill files are written
- "Tests aren't needed for config files" (SKILL.md files ARE testable — trigger keywords, YAML validity, no forbidden tool names)

---

### Anti-Stall Rules

If stuck for > 5 minutes on one file:
1. STOP — don't keep retrying same approach
2. Check: is there a simpler version that satisfies the success criteria?
3. Look at the source skill in `skills/<name>/SKILL.md` — it has the Claude Code version
4. Write a minimal version first, mark TODO for enhancement

If a dependency is missing:
1. Note it in session log
2. Build the dependency first
3. Return to original task

---

## IMPLEMENTATION PHASES

Complete each phase fully before starting the next.

---

### PHASE 1: Branch + Smoke Test Stubs (RED)

**Tasks:**
1. `git checkout -b feat/forge-sb-native-port`
2. Create `tests/smoke-test.sh` with all assertions as `exit 1` stubs — this is the RED commit
3. Create `.planning/PLAN.md` documenting all 8 phases with success criteria

**Smoke test structure** (write this first, stubs exit 1):
```bash
#!/usr/bin/env bash
set -euo pipefail
FORGE_HOME="${FORGE_HOME:-$HOME/forge}"
PASS=0; FAIL=0

check() {
  local desc="$1"; local condition="$2"
  if eval "$condition"; then echo "✅ $desc"; ((PASS++))
  else echo "❌ $desc"; ((FAIL++)); fi
}

# === SKILLS EXIST ===
for skill in silver silver-feature silver-bugfix silver-ui silver-devops silver-research \
             quality-gates modularity reusability scalability security reliability \
             usability testability extensibility ai-llm-safety \
             tdd brainstorming writing-plans requesting-code-review receiving-code-review finishing-branch \
             gsd-discuss gsd-plan gsd-execute gsd-verify gsd-ship gsd-review \
             gsd-review-fix gsd-secure gsd-validate gsd-intel gsd-progress gsd-brainstorm; do
  check "Skill exists: $skill" "[ -f 'forge/skills/$skill/SKILL.md' ]"
done

# === VALID YAML FRONTMATTER ===
for skill_md in forge/skills/*/SKILL.md; do
  sname=$(basename "$(dirname "$skill_md")")
  check "$sname: has YAML frontmatter" "grep -q '^---$' '$skill_md'"
  check "$sname: has trigger field" "grep -q '^trigger' '$skill_md'"
  check "$sname: has id field" "grep -q '^id:' '$skill_md'"
done

# === NO FORBIDDEN TOOL NAMES ===
for skill_md in forge/skills/*/SKILL.md; do
  sname=$(basename "$(dirname "$skill_md")")
  check "$sname: no Claude Code tool names" \
    "! grep -qE 'TodoWrite|AskUserQuestion|NotebookEdit' '$skill_md'"
done

# === AGENTS.MD TEMPLATES ===
check "Global AGENTS.md template exists" "[ -f 'forge/AGENTS.md.template' ]"
check "Project AGENTS.md template exists" "[ -f 'forge/AGENTS.project.template' ]"
check "AGENTS.md.template has 'On Session Start'" "grep -q 'On Session Start' forge/AGENTS.md.template"
check "AGENTS.md.template has 'Quality Gate Triggers'" "grep -q 'Quality Gate Triggers' forge/AGENTS.md.template"
check "AGENTS.md.template has 'TDD'" "grep -q 'TDD' forge/AGENTS.md.template"

# === INSTALLER ===
check "forge-sb-install.sh exists" "[ -f 'forge-sb-install.sh' ]"
check "forge-sb-install.sh is executable" "[ -x 'forge-sb-install.sh' ]"
check "forge-sb-install.sh has --dry-run" "grep -q 'dry.run' forge-sb-install.sh"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && echo "✅ All smoke tests passed!" || { echo "❌ $FAIL tests failed"; exit 1; }
```

**Commit:** `[RED] test(forge-sb): smoke tests — 33 skills + templates + installer (all stubs)`
Signed-off-by: Shafqat Ullah <shafqat@sourcevo.com>

---

### PHASE 2: Directory Structure + Architecture Docs

**Tasks:**
1. Create `forge/` directory with `forge/skills/` subdirectory
2. Write `docs/mapping-table.md` with Claude Code → Forge primitive mapping
3. Write `forge-sb-install.sh` skeleton with `--dry-run` flag

**docs/mapping-table.md content:**
```markdown
# Silver Bullet Primitive Mapping: Claude Code → Forge

| Claude Code Primitive | Forge Equivalent | Notes |
|---|---|---|
| Skill tool invocation (`Skill({skill: "tdd"})`) | Trigger phrase in prompt ("TDD", "test-driven") | Forge's skill engine detects via YAML `trigger` field |
| `TodoWrite` | Session log checkboxes in `docs/sessions/YYYY-MM-DD.md` | Manual tracking |
| `AskUserQuestion` | Inline prose question in skill body (wait for response) | Same behavior |
| `PreToolUse` hook | AGENTS.md "Before every action" section | Applied globally, not per-call |
| `PostToolUse` hook | AGENTS.md "After every action" section | Applied globally |
| `SessionStart` hook | AGENTS.md "On Session Start" section | Runs at session init |
| Plugin MANIFEST.json | `forge-sb-install.sh` bootstrap script | Manual install |
| `~/.claudeplugins.json` | `~/forge/AGENTS.md` + `~/forge/skills/` | Global user config |
| Project `.claudeplugins.json` | `.forge/skills/` + project `AGENTS.md` | Per-project config |
| `silver-bullet.md §10` preferences | AGENTS.md standing instructions | Baked in, not per-session |
| Episodic memory MCP | Session logs + AGENTS.md mentoring loop | Manual extraction |
| Multi-AI review (`multai`) | Inline "get second opinion" instruction in review skills | Simulated via prompt |
```

**forge-sb-install.sh content (write this in full):**
```bash
#!/usr/bin/env bash
set -euo pipefail

# Silver Bullet for Forge — Idempotent Installer
# Usage: ./forge-sb-install.sh [--dry-run] [--project-only]
# Installs Silver Bullet skills and AGENTS.md for use with Forge AI

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false
PROJECT_ONLY=false
FORGE_HOME="${FORGE_HOME:-$HOME/forge}"
SKILLS_SRC="$SCRIPT_DIR/forge/skills"

for arg in "$@"; do
  case $arg in
    --dry-run) DRY_RUN=true ;;
    --project-only) PROJECT_ONLY=true ;;
    -h|--help) echo "Usage: $0 [--dry-run] [--project-only]"; exit 0 ;;
  esac
done

log() { echo "[forge-sb] $*"; }

maybe_mkdir() {
  log "  mkdir -p $1"
  $DRY_RUN || mkdir -p "$1"
}

maybe_cp_skill() {
  local src="$1" dst="$2"
  if [ -f "$dst" ]; then
    log "  skip (exists): $dst"
  else
    log "  copy: $src → $dst"
    $DRY_RUN || cp "$src" "$dst"
  fi
}

maybe_cp_template() {
  local src="$1" dst="$2"
  if [ -f "$dst" ]; then
    log "  skip (exists — will NOT overwrite): $dst"
  else
    log "  create from template: $dst"
    $DRY_RUN || cp "$src" "$dst"
  fi
}

echo "Silver Bullet for Forge — Installer"
echo "====================================="
$DRY_RUN && echo "DRY RUN MODE — no files will be written"
echo ""

# Phase 1: Global skills (~/forge/)
if ! $PROJECT_ONLY; then
  log "Installing global skills to $FORGE_HOME/skills/"
  maybe_mkdir "$FORGE_HOME/skills"
  for skill_dir in "$SKILLS_SRC"/*/; do
    skill_name=$(basename "$skill_dir")
    maybe_mkdir "$FORGE_HOME/skills/$skill_name"
    maybe_cp_skill "$skill_dir/SKILL.md" "$FORGE_HOME/skills/$skill_name/SKILL.md"
  done
  log ""
  log "Installing global AGENTS.md"
  maybe_cp_template "$SCRIPT_DIR/forge/AGENTS.md.template" "$FORGE_HOME/AGENTS.md"
  log ""
fi

# Phase 2: Project-level setup
log "Installing project skills to .forge/skills/"
maybe_mkdir ".forge/skills"
for skill_dir in "$SKILLS_SRC"/gsd-*/; do
  skill_name=$(basename "$skill_dir")
  maybe_mkdir ".forge/skills/$skill_name"
  maybe_cp_skill "$skill_dir/SKILL.md" ".forge/skills/$skill_name/SKILL.md"
done
log ""
log "Installing project AGENTS.md"
maybe_cp_template "$SCRIPT_DIR/forge/AGENTS.project.template" "AGENTS.md"

echo ""
if $DRY_RUN; then
  log "DRY RUN complete — no files written. Remove --dry-run to install."
else
  log "Installation complete!"
  log "  Global skills: $FORGE_HOME/skills/"
  log "  Project skills: .forge/skills/"
  log "  Review AGENTS.md and customize for your project."
  log "  Run tests/smoke-test.sh to verify installation."
fi
```
Make executable: `chmod +x forge-sb-install.sh`

**Commit:** `feat(forge-sb): Phase 1 — directory structure, mapping table, installer skeleton`

---

### PHASE 3: GSD Workflow Skills (12 skills)

Create `forge/skills/<name>/SKILL.md` for each. Read `skills/` dir for existing Claude Code versions as reference. Adapt — do not copy verbatim (different tool names, different invocation model).

**gsd-discuss/SKILL.md:**
```yaml
---
id: gsd-discuss
title: GSD — Discuss Phase
description: Adaptive questioning to surface assumptions and lock decisions before planning
trigger:
  - "discuss phase"
  - "clarify phase"
  - "explore assumptions"
  - "gray areas"
---

# GSD — Discuss Phase

## When to Use
Before planning any phase with ambiguous requirements. Surfaces hidden assumptions before they become expensive mistakes.

## Steps

### Step 1: Read Phase Context
Read `.planning/ROADMAP.md` for the phase goal and requirements. Read `.planning/REQUIREMENTS.md` for relevant REQ-IDs. Note any ambiguous or under-specified areas.

### Step 2: Ask Clarifying Questions (one at a time)
For each ambiguous area, ask ONE question and wait for the answer before asking the next. Do not ask multiple questions in a single message.

### Step 3: Lock Decisions
After each answer, write a "Locked: <decision>" entry in `.planning/phases/<N>/CONTEXT.md`. Never reopen locked decisions.

### Step 4: Gate
Do not exit this skill until all identified gray areas have locked decisions in CONTEXT.md.

## Exit Condition
`.planning/phases/<N>/CONTEXT.md` exists with a `## Locked Decisions` section containing at least one entry per gray area identified.
```

**gsd-plan/SKILL.md:**
```yaml
---
id: gsd-plan
title: GSD — Plan Phase
description: Create PLAN.md with task breakdown, requirements mapping, and verification steps
trigger:
  - "plan phase"
  - "create plan"
  - "write plan"
  - "planning"
---

# GSD — Plan Phase

## Prerequisites
- Phase goal is clear (from ROADMAP.md)
- If phase had gray areas: CONTEXT.md with locked decisions must exist

## Steps

### Step 1: Read Inputs
Read `.planning/ROADMAP.md` (phase goal), `.planning/REQUIREMENTS.md` (REQ-IDs), and `.planning/phases/<N>/CONTEXT.md` if it exists.

### Step 2: Write PLAN.md
Write `.planning/phases/<N>/PLAN.md` with these sections:
- **Goal** (one sentence)
- **Requirements covered** (list of REQ-IDs from REQUIREMENTS.md)
- **Task breakdown** (ordered list; each task atomic and independently verifiable)
- **Per-task**: file changed, description of change, how to verify it worked
- **Verification steps** (how to know the whole phase is done)
- **Threat model** (if phase touches auth, data persistence, or external services)
- **Rollback** (how to undo this phase if needed)

### Step 3: Run Pre-Plan Quality Gates
Run all 9 quality dimensions against the plan. Fix any ❌ findings before proceeding.

### Step 4: Present for Review
Show the completed PLAN.md and ask: "Does this plan look correct? Any changes before execution?"

## Exit Condition
PLAN.md exists, passes all 9 quality gate dimensions (no ❌), and has been reviewed.
```

**gsd-execute/SKILL.md:**
```yaml
---
id: gsd-execute
title: GSD — Execute Phase
description: Execute PLAN.md with atomic commits, deviation handling, and TDD discipline
trigger:
  - "execute phase"
  - "implement"
  - "execute plan"
  - "build it"
---

# GSD — Execute Phase

## Hard Prerequisites
PLAN.md must exist. If it doesn't, say: "No PLAN.md found. Run 'plan phase <N>' first." Do not proceed without it.

## Steps

### Step 1: Read PLAN.md
Read the full plan. Note the task order and dependencies.

### Step 2: TDD Setup
For any task that creates new functions or modules: write the failing test FIRST. Commit the failing test stub before writing implementation. See the `tdd` skill.

### Step 3: Execute Tasks in Order
For each task in PLAN.md:
1. Implement the task
2. Run its verification step
3. If it passes: commit with `feat(<phase>): <task description>` + DCO sign-off
4. If it fails: fix it before moving to the next task
5. Mark ✅ in session log

### Step 4: Deviation Handling
If execution deviates from PLAN.md: document the deviation, explain why, and confirm before proceeding with the alternative approach. Never silently ignore plan deviations.

## Exit Condition
All tasks in PLAN.md marked ✅, all local tests pass, all commits have DCO sign-off.
```

**gsd-verify/SKILL.md:**
```yaml
---
id: gsd-verify
title: GSD — Verify Work
description: Execute verification steps from PLAN.md and produce VERIFICATION.md
trigger:
  - "verify work"
  - "verify phase"
  - "verification"
  - "check done"
  - "is it done"
---

# GSD — Verify Work

## Steps

### Step 1: Read Verification Steps
Read the "Verification steps" section of `.planning/phases/<N>/PLAN.md`. These are the acceptance criteria.

### Step 2: Execute Each Verification Step
For each step, run it and record the result.

### Step 3: Write VERIFICATION.md
Write `.planning/VERIFICATION.md`:
```
# Phase <N> Verification

| Step | Result | Evidence |
|------|--------|----------|
| <step 1> | ✅/❌ | <how you verified> |
...

## Status: PASSED / FAILED
```

### Step 4: Gate
If any step is ❌: do NOT mark phase complete. Fix the issue and re-run verification.

## Exit Condition
VERIFICATION.md exists with `## Status: PASSED` and no ❌ rows.
```

**gsd-ship/SKILL.md:**
```yaml
---
id: gsd-ship
title: GSD — Ship Phase (Create PR)
description: Push branch and create PR; refuses to ship without passing verification
trigger:
  - "ship"
  - "create PR"
  - "pull request"
  - "ship phase"
---

# GSD — Ship Phase

## Hard Prerequisites
VERIFICATION.md must exist with `Status: PASSED`. If it doesn't: "Cannot ship without passing verification. Run 'verify work' first." Do not create a PR without it.

## Steps

### Step 1: Final Quality Gates (pre-ship)
Run all 9 quality dimensions in pre-ship (adversarial) mode. Fix any ❌ before proceeding.

### Step 2: Push Branch
Push the current branch to origin.

### Step 3: Create PR
Create a PR with:
- **Title**: `feat(<phase>): <description>` (≤70 chars, imperative)
- **Body**:
  ```
  ## Summary
  <1-3 bullet points of what was built>

  ## Requirements Covered
  <list of REQ-IDs from PLAN.md>

  ## Verification Evidence
  <paste VERIFICATION.md Status section>

  ## Test Plan
  <checklist of what was tested>
  ```

## Exit Condition
PR URL returned. Link recorded in session log.
```

**gsd-review/SKILL.md:**
```yaml
---
id: gsd-review
title: GSD — Code Review
description: Review changed files for bugs, security issues, and code quality; produce REVIEW.md
trigger:
  - "code review"
  - "review code"
  - "review this"
  - "review changes"
---

# GSD — Code Review

## Steps

### Step 1: Identify Changed Files
List all files changed since the branch diverged from main. Group by module/concern.

### Step 2: Review Each File
For each changed file, check:
- Bugs (logic errors, off-by-one, null pointer risks)
- Security issues (input validation, injection vectors, secrets in code)
- Code quality (single responsibility, naming clarity, unnecessary complexity)
- Test coverage (does every new function have a test?)

### Step 3: Classify Findings
- **CRITICAL**: Data loss, security breach, correctness failure — must fix before merge
- **MAJOR**: Code quality, missing tests, maintainability — should fix
- **MINOR**: Style, naming, nice-to-have — low priority

### Step 4: Write REVIEW.md
Write `.planning/REVIEW.md`:
```
# Code Review

| File | Finding | Severity | Recommendation |
|------|---------|----------|----------------|
...

## Gate: PASS / BLOCK
```
Gate is BLOCK if any CRITICAL findings. PASS if only MAJOR/MINOR.

## Exit Condition
REVIEW.md exists. If gate is BLOCK, exit with instruction to run 'fix review findings'.
```

**gsd-review-fix/SKILL.md, gsd-secure/SKILL.md, gsd-validate/SKILL.md, gsd-intel/SKILL.md, gsd-progress/SKILL.md, gsd-brainstorm/SKILL.md** — write similarly (read `skills/` dir for reference content on each).

**Commit:** `feat(forge-sb): Phase 2 — GSD workflow skills (12 skills)`

---

### PHASE 4: Quality Dimension Skills (9 + master)

Each dimension as `forge/skills/<dimension>/SKILL.md`. Read the existing `skills/<dimension>/SKILL.md` files for the full checklist content — they have the authoritative items. Adapt to Forge format (imperative prose, no CC tool names).

**Key adaptation rules:**
- Replace "Mark ✅/❌/⚠️" → keep as-is (this is prose, not a tool call)
- Replace "Invoke quality-<dimension>" → "Run the <dimension> quality dimension checklist"
- Remove any `Skill({skill: "..."})` references
- Replace "STOP and invoke silver:bugfix" → "Stop immediately and fix the issue before proceeding"

**quality-gates/SKILL.md (master):**
```yaml
---
id: quality-gates
title: Quality Gates — All 9 Dimensions
description: Runs all 9 quality dimensions in sequence; design-time or pre-ship mode auto-detected
trigger:
  - "quality gates"
  - "all 9 dimensions"
  - "quality review"
  - "ilities"
  - "silver quality"
---

# Quality Gates — Consolidated Review

## Mode Detection
Check if `.planning/VERIFICATION.md` exists with `status: passed`:
- If YES → **Pre-ship mode** (adversarial audit — N/A requires strong evidence)
- If NO → **Design-time mode** (planning checklist — N/A acceptable for unimplemented items)

## Run All 9 Dimensions
For each dimension below, evaluate every checklist item and mark ✅/❌/⚠️N/A.

[Run the checklist from each of: modularity, reusability, scalability, security, reliability, usability, testability, extensibility, ai-llm-safety]

## Consolidated Report
| Dimension | Result | Notes |
|-----------|--------|-------|
| Modularity | | |
| Reusability | | |
| Scalability | | |
| Security | | |
| Reliability | | |
| Usability | | |
| Testability | | |
| Extensibility | | |
| AI/LLM Safety | | |

## Gate Enforcement
Any ❌ = **hard stop**. List each failure with specific fix required. Do not proceed until resolved and gates re-run.

## Backlog Capture
Any ⚠️N/A items with future applicability → write to `.planning/BACKLOG.md`.

## Exit Condition
All dimensions ✅ or ⚠️N/A. Output "Quality gates PASSED."
```

For the 9 individual dimension SKILL.md files: write the full checklists from the existing `skills/` versions, adapted to Forge format. The security skill explicitly marks its items as non-N/A.

**Commit:** `feat(forge-sb): Phase 3 — quality dimension skills (9 + master)`

---

### PHASE 5: Superpowers Dependencies (7 skills)

**tdd/SKILL.md:**
```yaml
---
id: tdd
title: TDD — Test-Driven Development
description: Enforces Red-Green-Refactor cycle; the iron law for all implementation work
trigger:
  - "TDD"
  - "test-driven"
  - "red green refactor"
  - "write tests first"
  - "failing test"
---

# TDD — Test-Driven Development

## The Iron Law
```
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
```
Violating this rule in letter violates it in spirit. No exceptions.

## Red-Green-Refactor

### RED — Write Failing Test
Write one minimal test for the behavior you're about to implement.
Run it. Confirm it FAILS.
Confirm it fails for the RIGHT reason — "feature missing" not "syntax error".
Commit: `[RED] test(<scope>): <behavior description> — N stubs`
DCO: `Signed-off-by: <name> <email>`

If the test passes immediately: you're testing existing behavior. The test is wrong. Fix it.

### GREEN — Write Minimal Code
Write the simplest code that makes the test pass. Nothing more.
No extra features. No refactoring. Minimum to go green.
Run ALL tests. Confirm they all pass.
Commit: `[GREEN] feat(<scope>): <description> — N tests pass`
DCO sign-off.

### REFACTOR — Clean Up
After green: improve names, extract helpers, remove duplication.
Tests must stay green throughout. If any go red: revert refactor, retry.

## Commit Pattern
1. `[RED] test(scope): describe-behavior — N stubs (todo!/unimplemented!)`
2. `[GREEN] feat(scope): describe-behavior — N tests pass`
3. `refactor(scope): clean up` (optional, only after all green)

## Red Flags — Stop and Start Over
Any of these means delete the code and start with a failing test:
- Code committed before test
- Test passed on first run without any implementation
- "I'll add tests after" / "This is too simple to test"
- "Manual testing is enough"
- "Tests slow me down on this part"

## Verification
Before marking any implementation complete:
- Every new function/method has at least one test
- You watched each test fail before implementing
- Each test failed for the expected reason (feature missing)
- Minimal code was written to pass (no gold-plating)
- All tests pass, no warnings
```

**brainstorming/SKILL.md, writing-plans/SKILL.md, requesting-code-review/SKILL.md, receiving-code-review/SKILL.md, finishing-branch/SKILL.md** — adapt from the existing `skills/` versions. Key adaption for brainstorming: replace "invoke writing-plans skill" → "proceed to the writing-plans skill by using the trigger phrase 'write implementation plan'". For finishing-branch: remove all `Skill` tool calls, replace with prose instructions.

**Commit:** `feat(forge-sb): Phase 4 — superpowers dependencies (7 skills)`

---

### PHASE 6: AGENTS.md Templates

**forge/AGENTS.md.template (write in full):**
```markdown
# Forge Global Instructions — Silver Bullet Edition
# Generated by forge-sb-install.sh | Source: https://github.com/alo-exp/silver-bullet

## On Session Start

1. Read `.planning/STATE.md` if present — note the current phase cursor
2. Read `.planning/ROADMAP.md` if present — note remaining phases and current phase goal
3. Check if a PLAN.md exists for the current phase (`ls .planning/phases/*/PLAN.md`)
4. If no PLAN.md and this is a coding session: say "No PLAN.md for the current phase. Run 'plan phase <N>' before implementing."
5. Never modify source files without a PLAN.md that authorizes the change

## Behavior Rules

**ALWAYS:**
- Run quality gates (all 9 dimensions) before executing any non-trivial implementation
- Write the failing test BEFORE writing any implementation code (TDD iron law)
- Commit after each logical unit of work (never batch multiple features in one commit)
- Include DCO sign-off on every commit: `Signed-off-by: <Name> <Email>`
- Create a PR for any branch representing ≥ 1 day of work
- Write VERIFICATION.md before creating a PR

**NEVER:**
- Skip the pre-plan quality gate — it is non-negotiable
- Skip the pre-ship quality gate — it is non-negotiable
- Write production code before a failing test exists (TDD iron law)
- Create a PR without VERIFICATION.md showing Status: PASSED
- Use `--no-verify` to bypass git hooks
- Force-push to main or master
- Merge without at least MAJOR review findings addressed

## Workflow Routing

| User says | Skill to use |
|---|---|
| "add X", "build X", "implement X", "new feature", "enhance X" | silver-feature |
| "bug", "broken", "crash", "error", "regression", "not working" | silver-bugfix |
| "UI", "frontend", "component", "screen", "design" | silver-ui |
| "infra", "CI/CD", "deploy", "pipeline", "terraform" | silver-devops |
| "how should we", "compare X vs Y", "spike", "which technology" | silver-research |
| "plan phase", "create plan", "write plan" | gsd-plan |
| "execute", "implement the plan", "build it" | gsd-execute |
| "verify", "done?", "check phase", "is it done" | gsd-verify |
| "ship", "PR", "merge", "pull request" | gsd-ship |
| "code review", "review code" | gsd-review |
| "quality gates", "ilities", "quality review" | quality-gates |
| "progress", "what's left", "status", "where are we" | gsd-progress |
| "TDD", "test first", "failing test first" | tdd |
| "brainstorm", "ideate", "explore approaches" | brainstorming |
| "discuss phase", "gray areas", "clarify" | gsd-discuss |

## Quality Gate Triggers

Run quality gates automatically when:
- Creating a PLAN.md (use design-time mode — check is `.planning/VERIFICATION.md` absent)
- Creating a PR (use pre-ship mode — check is `.planning/VERIFICATION.md` present and passed)
- User says "quality gates", "ilities", or "quality review"

A single ❌ finding = hard stop. Fix before proceeding.

## Code Style

- Prefer explicit over implicit
- Early returns over deep nesting
- Comments only when WHY is non-obvious (not WHAT — variable names handle that)
- No multi-line comment blocks
- No "added for issue #X" comments (belongs in commit message)

## Testing

**Iron law: NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST.**
- Write RED (failing test stub) before GREEN (implementation)
- Commit RED before writing any implementation
- Watch the test fail — confirm it fails for the right reason
- Write minimal GREEN — no gold-plating
- Run all tests before committing GREEN

## Git Workflow

- Branch naming: `feat/<phase>-<description>`, `fix/<description>`
- Commit format: `<type>(<scope>): <description>` + blank line + `Signed-off-by: <name> <email>`
- Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`
- Never commit directly to main
- Squash merge feature branches (clean history on main)
- Tag releases with GPG/SSH signature
```

**forge/AGENTS.project.template (write in full):**
```markdown
# Project: [PROJECT NAME — customize this]
# Generated by forge-sb-install.sh | Customize before first use

## Project Conventions

Language: [Rust / TypeScript / Python / ...]
Framework: [...]
Test runner: [cargo test / npm test / pytest / ...]
Linter: [clippy / eslint / ruff / ...]
Formatter: [rustfmt / prettier / black / ...]

## GSD Phase Cursor

Current phase: [check .planning/STATE.md and fill in]
Active plan: [path to current PLAN.md]

## Forge Output Format

After every task, provide:
```
STATUS: COMPLETE / IN_PROGRESS / BLOCKED
FILES_CHANGED: [list files modified]
ASSUMPTIONS: [assumptions made during the task]
PATTERNS_DISCOVERED: [new codebase patterns observed]
```

## Task Patterns

[Forge will populate this via the mentoring loop — leave blank initially]

## Forge Corrections

[Forge will populate this when mistakes are caught — leave blank initially]

## Project-Specific Rules

[Add project non-negotiables here. Examples:]
- Never run `cargo test` with `--no-fail-fast` (masks cascading failures)
- Always run `cargo clippy -- -D warnings` before committing
- DCO sign-off required on every commit: `Signed-off-by: <name> <email>`
```

**Commit:** `feat(forge-sb): Phase 5 — AGENTS.md global and project templates`

---

### PHASE 7: Silver Orchestrator Skills (6 skills)

**silver/SKILL.md:**
```yaml
---
id: silver
title: Silver — Smart Workflow Router
description: Routes user intent to the correct Silver Bullet sub-workflow
trigger:
  - "/silver"
  - "silver workflow"
  - "use silver"
  - "start workflow"
---

# Silver — Smart Workflow Router

Route to the correct sub-skill based on intent. First match wins.

## Routing Table

| Intent signals | Route to |
|---|---|
| "add", "build", "implement", "new feature", "enhance" | silver-feature |
| "bug", "broken", "crash", "error", "regression", "not working" | silver-bugfix |
| "UI", "frontend", "component", "screen", "interface", "design" | silver-ui |
| "infra", "CI/CD", "deploy", "pipeline", "terraform" | silver-devops |
| "how should we", "compare X vs Y", "spike", "which technology", "architecture decision" | silver-research |

## When Routing
State: "Routing to [skill] because [one sentence reason]."
Then follow that skill's procedure exactly.

## When Ambiguous
Ask: "Which workflow fits?
A. New feature or enhancement
B. Bug fix  
C. UI/frontend work
D. Infrastructure/DevOps
E. Technology decision/research
(Enter A-E)"
Wait for response before routing.
```

**silver-feature/SKILL.md:**
```yaml
---
id: silver-feature
title: Silver — Feature Development Workflow
description: Full workflow: brainstorm → specify → quality-gate → plan → execute → verify → secure → ship
trigger:
  - "silver feature"
  - "feature workflow"
  - "full feature workflow"
---

# Silver Feature — Full Workflow

## Non-Skippable Gates
These cannot be omitted: pre-plan quality gates (PATH 4), verification (PATH 8), pre-ship quality gates (PATH 10), security (PATH 9).

## Path Chain (execute in order)

**PATH 1: ORIENT**
Read `.planning/STATE.md`, `.planning/ROADMAP.md`, and any existing specs for this feature area.

**PATH 2: BRAINSTORM**
Run brainstorming procedure (trigger: "brainstorm"). Document 2-3 approaches, recommend one, get approval.

**PATH 3: SPECIFY**
Write design doc to `docs/superpowers/specs/YYYY-MM-DD-<feature>-design.md`. Ask user to review before continuing.

**PATH 4: QUALITY GATES (pre-plan) [NON-SKIPPABLE]**
Run all 9 quality dimensions (trigger: "quality gates") on the spec. Fix any ❌ before proceeding.

**PATH 5: PLAN**
Run gsd-plan procedure (trigger: "plan phase"). Write PLAN.md. Get user to review.

**PATH 6: EXECUTE**
Run gsd-execute procedure (trigger: "execute phase"). Atomic commits. TDD discipline.

**PATH 7: REVIEW**
Run gsd-review procedure (trigger: "code review"). Fix CRITICAL findings before continuing.

**PATH 8: VERIFY [NON-SKIPPABLE]**
Run gsd-verify procedure (trigger: "verify work"). VERIFICATION.md must show Status: PASSED.

**PATH 9: SECURITY [NON-SKIPPABLE]**
Run security quality dimension (trigger: "security"). Write SECURITY.md.

**PATH 10: QUALITY GATES (pre-ship) [NON-SKIPPABLE]**
Run all 9 quality dimensions in pre-ship mode. Fix any ❌.

**PATH 11: SHIP**
Run gsd-ship procedure (trigger: "ship"). Create PR.

## Supervision Between Paths
After each path: verify its exit condition was met. If not: retry or document skip reason.
Report progress: "PATH X/11: <name> ✓ | Remaining: [list]"
```

**silver-bugfix/SKILL.md, silver-ui/SKILL.md, silver-devops/SKILL.md, silver-research/SKILL.md** — write similarly, adapting from the corresponding `skills/silver-*.md` files. Key constraints: no `Skill` tool calls, no `TodoWrite`, replace with trigger phrases and prose.

**Commit:** `feat(forge-sb): Phase 6 — silver orchestrator skills (6 skills)`

---

### PHASE 8: Final Assembly + GREEN

**Tasks:**
1. Ensure all 33+ `forge/skills/*/SKILL.md` files exist with valid YAML frontmatter
2. Validate: no forbidden tool names, trigger fields present, id fields present
3. Run `tests/smoke-test.sh` — must pass
4. Write `docs/forge-sb-README.md`
5. Commit: `[GREEN] feat(forge-sb): all smoke tests pass — Silver Bullet for Forge complete`
6. Push branch and create PR

**Validation command to run before GREEN commit:**
```bash
echo "Checking all skills..."
FAIL=0
for skill_md in forge/skills/*/SKILL.md; do
  sname=$(basename "$(dirname "$skill_md")")
  grep -q '^---$' "$skill_md" || { echo "❌ $sname: missing YAML frontmatter"; FAIL=1; }
  grep -q '^trigger' "$skill_md" || { echo "❌ $sname: missing trigger field"; FAIL=1; }
  grep -q '^id:' "$skill_md" || { echo "❌ $sname: missing id field"; FAIL=1; }
  grep -qE 'TodoWrite|AskUserQuestion|NotebookEdit' "$skill_md" && { echo "❌ $sname: contains Claude Code tool names"; FAIL=1; }
done
[ "$FAIL" -eq 0 ] && echo "✅ All skills valid" || echo "❌ Fix failures above"
```

**docs/forge-sb-README.md** — write a brief guide covering: what this is, how to install (forge-sb-install.sh), how to use (trigger phrases), how to add new skills, how to update AGENTS.md.

**PR body:**
```
## Summary
- 33+ SKILL.md files covering the full Silver Bullet workflow system for Forge
- AGENTS.md templates (global + project) with session startup behavior, routing table, quality gate triggers
- forge-sb-install.sh idempotent installer with --dry-run flag
- tests/smoke-test.sh smoke test suite (all passing)

## What Was Ported
- GSD workflow (12 skills): discuss → plan → execute → verify → ship → review → secure → validate
- Quality gates (9 + master): all 9 dimensions with design-time and pre-ship modes
- Superpowers (7 skills): TDD iron law, brainstorming, writing-plans, requesting/receiving-code-review, finishing-branch
- Silver orchestrator (6 skills): router, feature, bugfix, UI, devops, research

## Primitive Mapping
See docs/mapping-table.md for full Claude Code → Forge primitive equivalence table.

## Verification
All 33+ skills pass smoke-test.sh: valid YAML frontmatter, trigger keywords present, no Claude Code tool names.
```

---

## SUCCESS CRITERIA

Before creating the PR, verify ALL of these:

- [ ] `tests/smoke-test.sh` exits 0 with "All smoke tests passed!"
- [ ] `forge-sb-install.sh --dry-run` runs without error
- [ ] All SKILL.md files have `id:`, `title:`, `description:`, `trigger:` in YAML frontmatter
- [ ] Zero occurrences of `TodoWrite`, `AskUserQuestion`, `NotebookEdit` in `forge/skills/`
- [ ] `forge/AGENTS.md.template` has all 7 sections: On Session Start, Behavior Rules, Workflow Routing, Quality Gate Triggers, Code Style, Testing, Git Workflow
- [ ] `forge/AGENTS.md.template` is ≤ 200 lines
- [ ] All commits have DCO: `Signed-off-by: Shafqat Ullah <shafqat@sourcevo.com>`
- [ ] PR created against `alo-exp/silver-bullet` repo

## SESSION LOG

Write session progress to `docs/sessions/YYYY-MM-DD-forge-sb-port.md` as you work. Track each phase with ✅/❌.
