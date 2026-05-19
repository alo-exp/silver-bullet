# SB Orchestrated Dev Workflows — Implementation Plan

> **For agentic workers:** This plan is implemented via GSD quick tasks (Phase A) and a GSD phase (Phase B). Each task maps to one `/gsd-quick` invocation. Do NOT use superpowers:subagent-driven-development — GSD governs execution per SB enforcement rules.

**Goal:** Implement the six named SB orchestration workflows (silver:feature/bugfix/ui/devops/research/release/fast), expand the /silver router, add §10 preference system, update silver:init, and create Phase B skill files.

**Architecture:** Phase A edits existing SB enforcement docs (silver-bullet.md, templates/silver-bullet.md.base, skills/silver/SKILL.md, skills/silver-init/SKILL.md) to define all workflows as enforcement rules. Phase B creates six new named skill files that serve as thin orchestration wrappers over the Phase A definitions. Both files in the live/template pair must always be kept in sync.

**Tech Stack:** Markdown skill files, silver-bullet.md enforcement doc, GSD quick tasks for atomic commits.

**Spec:** `docs/superpowers/specs/2026-04-08-sb-orchestrated-dev-workflows-design.md`

---

## PHASE A — Workflow Definitions in Enforcement Docs

> Execute each task as a `/gsd-quick` invocation. Commit after each task. Both `silver-bullet.md` and `templates/silver-bullet.md.base` must be updated identically in each task that touches them.

---

> **§ numbering note:** The spec document uses `§5` for User Workflow Preferences. Because `silver-bullet.md` already has sections 0–9, this plan appends it as **`§10`** to avoid renumbering existing sections. All `§5` references in the spec map to `§10` in this plan. Every occurrence of `§10` below is correct — do not change it to `§5`.

### Task A1: Add §2h SB Orchestrated Workflows to silver-bullet.md + template

**Files:**
- Modify: `silver-bullet.md` — insert new §2h section after §2g (line ~283)
- Modify: `templates/silver-bullet.md.base` — insert identical §2h section after §2g (or after §2c if §2d–2g not present in template)

**What to add — §2h content:**

```markdown
### 2h. SB Orchestrated Workflows

SB provides six pre-designed orchestration workflows for all common development tasks.
When a bare instruction is intercepted (§2g) or the user invokes `/silver`, the router
classifies intent and dispatches to the appropriate workflow.

**The six workflows:**

| Workflow | Entry triggers | First step |
|----------|---------------|------------|
| `silver:feature` | "add X", "build X", "implement X", "new feature", "enhance X", "extend X" | silver:intel → product-brainstorming → silver:brainstorm |
| `silver:bugfix` | "bug", "broken", "crash", "error", "regression", "failing test" | SB triage → systematic-debugging → gsd-debug |
| `silver:ui` | "UI", "frontend", "component", "screen", "design", "interface" | silver:intel → product-brainstorming → silver:brainstorm → gsd-ui-phase |
| `silver:devops` | "infra", "CI/CD", "deploy", "pipeline", "terraform", "IaC", "cloud" | silver:intel → silver:blast-radius → silver:devops-skill-router |
| `silver:research` | "how should we", "which technology", "compare X vs Y", "spike" | silver:explore → MultAI research → silver:brainstorm |
| `silver:release` | "release", "publish", "version", "go live", "cut a release", "tag v" | silver:quality-gates → gsd-audit-uat → gsd-audit-milestone |

**Workflow enforcement rules:**
- Quality gates run twice per workflow: pre-planning (full 9 dimensions) and pre-ship (full 9 dimensions)
- `security` is always mandatory — cannot be skipped via §5
- `silver:devops` uses 7 IaC-adapted dimensions (silver:devops-quality-gates) instead of the standard 9
- TDD enforcement (`tdd`) applies to implementation plans only; config/infra/doc plans skip TDD
- `/testing-strategy` runs after spec approval and before `silver:writing-plans` so test requirements are baked into the plan
- Code review always uses the Superpowers framing pair: `requesting-code-review` before and `receiving-code-review` after
- Cross-AI review (`gsd-review`) triggers automatically for architecturally significant changes
- `gsd-ship` inside any workflow = phase-level merge (push → PR). `silver:release` = milestone-level publish. These are different levels — SB disambiguates at routing time.
- When user selects Autonomous mode at session start, `gsd-autonomous` drives all remaining phases

**Step-skip protocol:**
When the user requests skipping a workflow step, SB:
1. Explains why the step exists (one sentence)
2. Offers lettered options: A. Accept skip  B. Lightweight alternative  C. Show me what you have
3. Records the decision in §10 if user chooses A permanently

Non-skippable gates: `security`, `silver:quality-gates` pre-ship, `gsd-verify-work`.

**Step-by-step workflow tables (canonical — skill files implement these):**

*silver:feature (canonical step order per spec §4.1):*

> **Step numbering note:** The plan adds two preamble steps (0=session orient, 0b=complexity triage) before the spec's step 0 (codebase intel). This shifts spec's 1a/1b/1c/1d to plan's 1a/1b/1c/1d respectively. All downstream steps map 1:1 to the spec. Step 1d (silver:multai pre-spec) is distinct from step 9c (gsd-review post-execution) — both can fire independently.

| Step | Action | Tool/Skill |
|------|--------|-----------|
| 0 | Session orient: load §10 prefs, check mode (plan preamble) | Read silver-bullet.md §10 |
| 0b | Complexity triage (plan preamble) | Trivial→silver:fast; fuzzy→continue with 1b; complex→continue |
| 1a | Codebase intel (spec step 0) | gsd-intel |
| 1b | Fuzzy scope clarification if needed (spec step 1a) | gsd-explore |
| 1c | Brainstorm (spec steps 1b+1c) | /product-brainstorming → silver:brainstorm |
| 1d | MultAI pre-spec review — arch-sig or auto-trigger (spec step 1d) | multai:orchestrator |
| 2 | Testing strategy | /testing-strategy |
| 2.5 | Writing plans | silver:writing-plans |
| 3 | Pre-plan quality gates (9 dimensions) | silver:quality-gates |
| 4 | Discuss phase | gsd-discuss-phase |
| 5 | Plan phase | gsd-plan-phase |
| 6 | Execute phase | gsd-execute-phase (Interactive) or gsd-autonomous (Autonomous mode) |
| 7 | TDD gate (impl plans only; skip for config/infra/doc) | silver:tdd |
| 7a | Test gap-fill | gsd-add-tests |
| 8 | Verify work | gsd-verify-work |
| 9a | Request code review | silver:request-review |
| 9b | Run review | gsd-review (Superpowers reviewer) |
| 9c | Cross-AI review (arch-sig only) | gsd-review --multi-ai |
| 9d | Receive review | silver:receive-review |
| 10 | Security review | silver:security |
| 11 | Secure phase | gsd-secure-phase |
| 12 | Validate phase | gsd-validate-phase |
| 13 | Pre-ship quality gates (9 dimensions) | silver:quality-gates |
| 14 | Finishing branch | silver:finishing-branch |
| 15a | PR branch (ask user) | gsd-pr-branch |
| 15b | Ship phase | gsd-ship |
| 16 | Episodic memory | episodic-memory |
| 17 | Last phase? Milestone audit | gsd-audit-uat → gsd-audit-milestone → gsd-plan-milestone-gaps |

*silver:bugfix (triage → 3 paths per spec §4.2):*
| Step | Action | Tool/Skill |
|------|--------|-----------|
| 0 | Triage: classify symptom type | AskUserQuestion: A. Known symptom  B. Unknown cause  C. Failed GSD workflow |
| 1A | Known symptom, unknown fix → investigation | superpowers:systematic-debugging → gsd-debug → write fix plan |
| 1B | Unknown cause → reconstruction | silver:forensics → reconstruct session → then path 1A |
| 1C | Failed GSD workflow → GSD-specific forensics | gsd-forensics → reconstruct → then path 1A |
| 2 | TDD for fix (all paths) | silver:tdd |
| 3 | Execute fix plan | gsd-execute-phase |
| 4 | Verify work | gsd-verify-work |
| 5 | Security review | silver:security |
| 6 | Pre-ship quality gates | silver:quality-gates |
| 7 | Ship | gsd-ship |

> **Canonical step definitions:** The `silver:feature` and `silver:bugfix` tables above are fully expanded because they are the primary reference templates. The remaining 5 workflows (ui/devops/research/release/fast) are summarized here as orientation — the **Phase B skill files are the canonical, executable step definitions** for those workflows. Engineers implementing Phase B tasks must read spec §4.3–§4.7 directly for full step details.

*silver:ui (15 steps — same as feature but gsd-ui-phase replaces standard execute + adds gsd-ui-review):*
Includes: product-brainstorming → gsd-ui-phase → writing-plans (frontend-design) → execute → gsd-ui-review → silver:security → ship

*silver:devops (no brainstorm — 12 steps):*
Includes: gsd-intel → silver:blast-radius → silver:devops-skill-router → silver:devops-quality-gates (7 IaC dimensions) → gsd-discuss-phase → plan → execute (no TDD) → gsd-review → silver:security → devops-quality-gates pre-ship → ship

*silver:research (5 steps):*
Includes: gsd-explore → MultAI path (landscape/tech-selection/competitive) → artifact at .planning/research/ → silver:brainstorm → hand off to silver:feature or silver:devops

*silver:release (10 steps — milestone-level):*
Includes: silver:quality-gates (9 dim) → gsd-audit-uat → gsd-audit-milestone → [gap loop max 2x: gsd-plan-milestone-gaps → silver:feature] → /documentation + gsd-docs-update → gsd-milestone-summary → silver:create-release → [ask] gsd-pr-branch → gsd-ship → gsd-complete-milestone

*silver:fast (trivial path):*
Includes: complexity triage confirms ≤3 files → gsd-fast (no workflow overhead) → verify → commit
```

- [ ] **Step 1: Read both files to confirm current state**

```bash
grep -n "2g\. Bare\|## 3\. NON" silver-bullet.md | head -5
grep -n "2g\. Bare\|## 3\. NON" templates/silver-bullet.md.base | head -5
```

Expected: §2g exists in both files; § 3 follows it.

- [ ] **Step 2: Insert §2h into silver-bullet.md** after the `---` separator that closes §2g (before `## 3. NON-NEGOTIABLE RULES`)

Use the Edit tool. The insertion point is the `---` line just before `## 3. NON-NEGOTIABLE RULES`.

- [ ] **Step 3: Insert identical §2h into templates/silver-bullet.md.base** at the same logical position

- [ ] **Step 4: Verify both files have §2h**

```bash
grep -c "2h\. SB Orchestrated Workflows" silver-bullet.md templates/silver-bullet.md.base
```

Expected: `silver-bullet.md:1` and `templates/silver-bullet.md.base:1`

- [ ] **Step 5: Commit**

```bash
git add silver-bullet.md templates/silver-bullet.md.base
git commit -m "feat: add §2h SB Orchestrated Workflows to enforcement doc and template"
```

---

### Task A2: Add §10 User Workflow Preferences to silver-bullet.md + template

**Files:**
- Modify: `silver-bullet.md` — insert new §5 section. Current §5 is "Model Routing" — new preference section inserts before it, renumbering §5→§6, §6→§7, etc. OR appended as the final section. Check current highest section number first.
- Modify: `templates/silver-bullet.md.base` — identical §5 section

**Note:** `silver-bullet.md` currently has sections 0–9. The new §5 User Workflow Preferences should be appended after the existing highest section (§9 Pre-Release Quality Gate) to avoid renumbering disruption.

- [ ] **Step 1: Check current last section**

```bash
grep "^## [0-9]" silver-bullet.md | tail -3
```

Expected: `## 9. Pre-Release Quality Gate` is the last numbered section.

- [ ] **Step 2: Insert §10 User Workflow Preferences at end of silver-bullet.md**

Append after §9 content:

```markdown
## 10. User Workflow Preferences

This section is written and committed by SB whenever the user expresses a workflow preference.
Initially empty — all workflow defaults apply. Read at every relevant decision point.

Last updated: (not yet set)

### 10a. Routing Preferences
| Work type | Override route | Since |
|-----------|---------------|-------|

### 10b. Step Skip Preferences
| Workflow | Step skipped | Condition | Since |
|----------|-------------|-----------|-------|

### 10c. Tool Preferences
| Decision point | Preferred tool | Since |
|----------------|---------------|-------|

### 10d. MultAI Preferences
| Trigger | Disposition | Since |
|---------|-------------|-------|

### 10e. Mode Preferences
| Setting | Value | Since |
|---------|-------|-------|
| Default session mode | interactive | (set at init) |
| PR branch | ask | (set at first use) |
| TDD enforcement | per-plan-type | (default) |
```

- [ ] **Step 3: Insert identical section into templates/silver-bullet.md.base**

- [ ] **Step 4: Verify**

```bash
grep -c "10\. User Workflow Preferences" silver-bullet.md templates/silver-bullet.md.base
```

Expected: both return `1`

- [ ] **Step 5: Update §3 MUST NOT list in both files** — add two rules:

Add to the MUST NOT bullets in §3 of **both** `silver-bullet.md` and `templates/silver-bullet.md.base`:
```
- Override a non-skippable gate (silver:security, silver:quality-gates pre-ship, gsd-verify-work) via §10 preferences — these gates are permanent
- Write runtime preference updates to §10 without updating both silver-bullet.md AND templates/silver-bullet.md.base atomically
```

Verify both files receive identical additions:
```bash
grep -c "non-skippable gate" silver-bullet.md templates/silver-bullet.md.base
```
Expected: `silver-bullet.md:1` and `templates/silver-bullet.md.base:1`

- [ ] **Step 6: Commit**

```bash
git add silver-bullet.md templates/silver-bullet.md.base
git commit -m "feat: add §10 User Workflow Preferences to enforcement doc and template"
```

---

### Task A3: Expand /silver router with new classification table, disambiguation, and conflict rules

**Files:**
- Modify: `skills/silver/SKILL.md` — replace Step 2 routing table and add disambiguation + conflict resolution sections

**Current state:** `skills/silver/SKILL.md` has a 7-row SB routing table and a GSD fallback. The new design intentionally expands this to 17+ routes (adding silver:feature/bugfix/ui/devops/research/release/fast/explore/fast/progress/resume rows that didn't exist before) plus disambiguation rules + conflict resolution + complexity triage. This is additive by design — not a mistake.

- [ ] **Step 1: Read current routing table**

```bash
cat skills/silver/SKILL.md
```

- [ ] **Step 2: Replace Step 2 content** with expanded routing

Replace the existing "Step 2: Match intent against routing table" section with:

```markdown
### Step 2: Classify intent and complexity

**Complexity triage (run first):**

| Classification | Signals | Action |
|----------------|---------|--------|
| Trivial | Typo, config, rename, ≤3 files | Route to `silver:fast` (gsd-fast) — bypass workflow |
| Simple | Clear scope, ≤1 phase | Route to workflow, skip silver:explore |
| Complex | Multi-phase, cross-cutting | Full workflow including silver:explore + brainstorm |
| Fuzzy | Vague intent, unclear scope | Route to `silver:explore` first, then re-classify |

**Full routing table (first match wins after complexity triage):**

| User intent signals | Route to | Notes |
|---------------------|----------|-------|
| "what if", "I'm thinking about", "not sure how to", "help me think" | `silver:explore` (gsd-explore) | Fuzzy — clarify first |
| "add X", "build X", "implement X", "new feature", "enhance X", "extend X" | `silver:feature` | Core dev path |
| "bug", "broken", "crash", "error", "regression", "failing test", "not working" | `silver:bugfix` | Triage internally |
| "UI", "frontend", "component", "screen", "design", "interface", "page", "layout", "animation", "responsive" | `silver:ui` | Includes mobile, web, design systems |
| "infra", "CI/CD", "deploy", "pipeline", "terraform", "IaC", "kubernetes", "container", "cloud", "ops" | `silver:devops` | Includes containers, networking, monitoring |
| "how should we", "which technology", "compare X vs Y", "spike", "investigate", "architecture decision", "should we use", "what's the best approach for" | `silver:research` | Tech decisions, architecture choices |
| "release", "publish", "version", "go live", "cut a release", "tag v", "ship to users", "deploy to prod" | `silver:release` | Milestone-level only — see disambiguation below |
| "merge this", "push this PR", "ship this feature" [active phase context] | `gsd-ship` (in-workflow) | Phase-level only |
| "trivial", "quick fix", "typo", "one-liner", "config value", ≤3 files | `silver:fast` (gsd-fast) | No planning overhead |
| "where are we", "what's left", "show progress", "current status" | `gsd-progress` | Status only |
| "pick up", "resume", "continue where" | `gsd-resume-work` | Session restore |
| "set up", "initialize", "install Silver Bullet", "configure project" | `silver:init` | First-time setup |
| "quality review", "ilities", "architecture review", "quality dimensions" | `silver:quality-gates` | Ad-hoc quality audit |
| "blast radius", "change impact", "rollback plan" | `silver:blast-radius` | Ad-hoc risk assessment |
| "IaC quality", "devops quality", "terraform quality" | `devops-quality-gates` | Ad-hoc DevOps quality |
| "root cause", "session failed", "what broke", "reconstruct" | `silver:forensics` | Post-mortem investigation |
| "release notes", "github release", "cut release", "tag release" | `silver:create-release` | Release artifact creation |
| "which IaC tool", "terraform vs pulumi", "which cloud skill" | `devops-skill-router` | IaC tool routing |

**"Ship" disambiguation:**

| Signal | Route |
|--------|-------|
| Contains version number (v2.0, 1.4.0…) | `silver:release` |
| Contains "changelog" or "release notes" | `silver:release` |
| Contains "go live", "to production", "to users", "publicly" | `silver:release` |
| Active phase in progress, no version signal | `gsd-ship` (phase-merge within workflow) |
| No active phase, end of milestone | `silver:release` |

**Multi-signal conflict resolution:**

| Conflict | Winner | Rationale |
|----------|--------|-----------|
| `silver:bugfix` + any other | `silver:bugfix` | Broken things block everything |
| `silver:ui` + `silver:feature` | `silver:ui` | UI is more specific |
| `silver:devops` + `silver:feature` | Ask user (A/B) | Both equally valid |
| `silver:research` + any | `silver:research` first | Research informs implementation |
| `silver:fast` + domain workflow | Check scope: if truly ≤3 files → `silver:fast`; if domain signals strong → domain workflow; if ambiguous → ask user "A. Treat as trivial  B. Route to [domain]" |

**MultAI auto-offer:** Proactively offer MultAI research before brainstorming when:
- Choosing between 2+ architectures
- Selecting a technology stack from scratch
- Domain is novel (no prior intel in .planning/)
- Change affects public API or data model fundamentally
```

- [ ] **Step 3: Replace Step 3 (ambiguous input) content** with the following:

```markdown
### Step 3: Handle ambiguous input

If input matches two or more destinations with similar confidence, use AskUserQuestion:

> I'm not sure which workflow to use. Which of these best matches what you want to do?
>
> A. `silver:feature` — build or extend a feature
> B. `silver:bugfix` — fix something that's broken
> C. `silver:ui` — UI, frontend, or design work
> D. `silver:devops` — infrastructure, CI/CD, or deployment
> E. `silver:research` — technology decision or spike
> F. `silver:release` — publish a milestone release
> G. `silver:fast` — trivial one-liner or config change
> H. Something else — describe it
>
> (Enter the letter)

Wait for selection, then route accordingly using Step 5.
```

- [ ] **Step 4: Update Routing Priority** at bottom:

```markdown
### Routing Priority

1. Complexity triage (trivial → silver:fast; fuzzy → silver:explore)
2. "Ship" disambiguation (phase-level vs milestone-level)
3. Multi-signal conflict resolution table
4. SB workflow routing table (specific domain matches)
5. Ad-hoc SB skill routing table
6. GSD triggers → /gsd:do
7. Ask for clarification (if still ambiguous)
```

- [ ] **Step 5: Verify**

```bash
grep -c "silver:feature\|silver:bugfix\|silver:ui\|silver:devops\|silver:research\|silver:release" skills/silver/SKILL.md
```

Expected: ≥6

- [ ] **Step 6: Commit**

```bash
git add skills/silver/SKILL.md
git commit -m "feat: expand /silver router with 6-workflow table, disambiguation, conflict rules"
```

---

### Task A4: Update silver:init — add gsd-new-project/gsd-map-codebase, MultAI dependency check, MultAI version freshness

**Files:**
- Modify: `skills/silver-init/SKILL.md`

**Five additions:**

**A4.1 — Add MultAI to Phase 1 dependency check** (after §1.5 GSD check, as new §1.6):

```markdown
### 1.6 MultAI plugin

Use the Glob tool to search for:
```
${SB_RUNTIME_HOME_ROOT}/plugins/cache/multai/skills/orchestrator/SKILL.md
```

If no file found, output exactly:
> ❌ MultAI plugin not found. Required for silver:research and multi-AI perspectives.
> Install: `/plugin install` from the MultAI marketplace

STOP. Do not proceed.
```

**A4.2 — Add MultAI to Phase 1.5 version freshness** (as new §1.5.4 after existing §1.5.3):

```markdown
### 1.5.4 Check MultAI version

Read installed version:
```bash
cat "${SB_RUNTIME_HOME_ROOT}/plugins/installed_plugins.json" | jq -r '.plugins["multai@multai"][0].version // "unknown"'
```

Check latest: visit MultAI marketplace or check local CHANGELOG.md:
```bash
cat "${SB_RUNTIME_HOME_ROOT}/plugins/cache/multai/CHANGELOG.md" 2>/dev/null | grep "^## \[" | head -1
```

If installed version appears outdated compared to CHANGELOG, display:
> MultAI v{installed} may not be the latest. To update: `/multai:update`

No AskUserQuestion needed — MultAI update is user-initiated only. Just display the notice and continue.
```

**A4.3 — Add Anthropic Engineering plugin check** (as new §1.7 after §1.6 MultAI check):

```markdown
### 1.7 Anthropic Engineering plugin

Use the Glob tool to search for:
```
${SB_RUNTIME_HOME_ROOT}/plugins/cache/engineering/skills/
```

If no directory found, display:
> ⚠️  Anthropic Engineering plugin not found. Recommended for silver:ui (/frontend-design, /testing-strategy) and silver:release (/documentation).
> Install via the Anthropic Engineering plugin in the marketplace. (Optional — workflows degrade gracefully.)

Continue without stopping.
```

**A4.4 — Add Anthropic Product Management plugin check** (as new §1.8 after §1.7):

```markdown
### 1.8 Anthropic Product Management plugin

Use the Glob tool to search for:
```
${SB_RUNTIME_HOME_ROOT}/plugins/cache/product-management/skills/
```

If no directory found, display:
> ⚠️  Anthropic Product Management plugin not found. Recommended for silver:feature and silver:ui (/product-brainstorming).
> Install via the Anthropic Product Management plugin in the marketplace. (Optional — workflows degrade gracefully.)

Continue without stopping.
```

**A4.5 — Add gsd-autonomous note to mode selection in Phase 2** (insert after the Interactive/Autonomous AskUserQuestion):

```markdown
> **Note on Autonomous mode:** If the user selects Autonomous, SB will invoke `gsd-autonomous` at workflow execution steps rather than `gsd-execute-phase`. `gsd-autonomous` handles full phase execution without checkpoints. This preference is stored in §10e.
```

**A4.6 — Add new/existing project detection in Phase 2** (after Phase 2.0 git repo check):

```markdown
### 2.1 Project type detection

Check whether this is a new project or an existing one:
```bash
test -d ".planning" && echo "EXISTING" || echo "NEW"
```

**If NEW project:**
Use AskUserQuestion:
- Question: "No .planning/ directory found. How would you like to initialize this project?"
- Options:
  - "A. New project — scaffold with GSD (creates ROADMAP.md, STATE.md, project structure)"
  - "B. Existing codebase — map it first before scaffolding"
  - "C. Skip project initialization — I'll handle it manually"

If A: invoke `/gsd-new-project` via the Skill tool. After it completes, continue with Silver Bullet init.
If B: invoke `/gsd-map-codebase` via the Skill tool, then invoke `/gsd-scan` via the Skill tool. After both complete, offer to run `/gsd-new-project` to scaffold. Then continue.
If C: continue without project initialization.

**If EXISTING project:**
Check if codebase intelligence exists:
```bash
test -d ".planning/codebase" && echo "INTEL_EXISTS" || echo "NO_INTEL"
```

If NO_INTEL and project appears brownfield (has source files but no .planning/codebase/):
Display: "No codebase intelligence found. Running gsd-scan to orient planning..."
Invoke `/gsd-scan` via the Skill tool. After it completes, continue.
```

- [ ] **Step 1: Read current Phase 1, 1.5, and Phase 2 sections**

```bash
grep -n "^## Phase 1\|^### 1\.\|^## Phase 2\|^### 2\." skills/silver-init/SKILL.md | head -30
```

- [ ] **Step 2: Add §1.6 MultAI dependency check** after §1.5 GSD check in Phase 1

- [ ] **Step 3: Add §1.7 Anthropic Engineering plugin check** after §1.6

- [ ] **Step 4: Add §1.8 Anthropic Product Management plugin check** after §1.7

- [ ] **Step 5: Add §1.5.4 MultAI version freshness** after existing §1.5.3 Superpowers/Design/Engineering block

- [ ] **Step 6: Add gsd-autonomous note** after the Interactive/Autonomous mode AskUserQuestion in Phase 2

- [ ] **Step 7: Add §2.1 project type detection** after existing §2.0 git repo check

- [ ] **Step 8: Verify**

```bash
grep -c "MultAI\|gsd-new-project\|gsd-map-codebase\|Anthropic Engineering\|Anthropic Product Management\|gsd-autonomous" skills/silver-init/SKILL.md
```

Expected: ≥6 (one match minimum per pattern)

Also verify gsd-autonomous is in the mode-selection context:
```bash
grep -A3 "Autonomous" skills/silver-init/SKILL.md | grep -i "gsd-autonomous"
```
Expected: at least one line output

- [ ] **Step 9: Commit**

```bash
git add skills/silver-init/SKILL.md
git commit -m "feat: add MultAI/Engineering/PM dep checks, version freshness, gsd-autonomous note, and project-type detection to silver:init"
```

---

### Task A5: Update silver-bullet.md §0 session start — add MultAI update check

**Files:**
- Modify: `silver-bullet.md` — §0 Session Startup, update check step
- Modify: `templates/silver-bullet.md.base` — identical change

- [ ] **Step 1: Read §0 current content in both files**

```bash
grep -n "^## 0\.\|update\|MultAI\|GSD\|Superpowers" silver-bullet.md | head -20
grep -n "^## 0\.\|update\|MultAI\|GSD\|Superpowers" templates/silver-bullet.md.base | head -20
```

Confirm: identify the exact line containing the auto-update or version check bullet in §0 for both files before editing either one.

- [ ] **Step 2: Locate the update check step in §0** and add MultAI alongside existing GSD/Superpowers checks:

Find the line that references auto-update or version check in §0. Add:
```
- Check if MultAI has updates available: read `${SB_RUNTIME_HOME_ROOT}/plugins/installed_plugins.json` for `multai@multai` version; compare to CHANGELOG. If outdated, offer to run `/multai:update` before starting session.
```

- [ ] **Step 3: Apply same change to templates/silver-bullet.md.base**

- [ ] **Step 4: Verify**

```bash
grep -c "MultAI" silver-bullet.md templates/silver-bullet.md.base
```

Expected: both ≥1

- [ ] **Step 5: Commit**

```bash
git add silver-bullet.md templates/silver-bullet.md.base
git commit -m "feat: add MultAI update check to §0 session startup"
```

---

## PHASE B — Named Orchestration Skill Files

> Phase B requires Phase A to be complete and verified. Each skill file maps `skills/silver-<name>/SKILL.md` → slash command `/silver:<name>`. These are thin orchestrators — they reference the step definitions from §2h of silver-bullet.md and chain the appropriate skills.
>
> Execute Phase B as a single GSD phase (not quick tasks) due to the volume of new files.

---

### Task B1: Create skills/silver-feature/SKILL.md

**Files:**
- Create: `skills/silver-feature/SKILL.md`

The skill orchestrates steps 0–17 from spec Section 4.1. It:
1. Displays a `SILVER BULLET ► FEATURE WORKFLOW` banner
2. Runs each step in order, invoking skills via the Skill tool
3. Presents AskUserQuestion at conditional branch points (fuzzy? → explore; arch-sig? → multai)
4. Records any step-skip decisions to §10 of silver-bullet.md

```markdown
---
name: silver-feature
description: "Full SB-orchestrated feature development workflow: intel → product-brainstorm → brainstorm → quality-gates → GSD plan/execute/verify → ship"
argument-hint: "<feature description>"
---

# /silver:feature — Feature Development Workflow

[Full step orchestration per spec Section 4.1]
```

- [ ] **Step 1: Write skills/silver-feature/SKILL.md** with full step orchestration following spec Section 4.1 exactly, including all conditional branches and AskUserQuestion points

- [ ] **Step 2: Verify file exists and covers all major step groups**

```bash
grep -c "silver:brainstorm\|silver:writing-plans\|silver:quality-gates\|gsd-discuss-phase\|gsd-plan-phase\|gsd-execute-phase\|silver:tdd\|gsd-verify-work\|silver:request-review\|gsd-review\|silver:receive-review\|silver:security\|gsd-secure-phase\|gsd-validate-phase\|gsd-ship\|gsd-audit-milestone" skills/silver-feature/SKILL.md
```

Expected: ≥16 (each of the 16 grep terms represents a distinct step group; all must appear at least once)

- [ ] **Step 3: Commit**

```bash
git add skills/silver-feature/SKILL.md
git commit -m "feat: add silver:feature orchestration skill"
```

---

### Task B2: Create skills/silver-bugfix/SKILL.md

**Files:**
- Create: `skills/silver-bugfix/SKILL.md`

Orchestrates spec Section 4.2: triage → path A/B/C → tdd → plan → execute → review → verify → ship.

- [ ] **Step 1: Write skills/silver-bugfix/SKILL.md** with triage classification logic and three investigation paths

- [ ] **Step 2: Verify**

```bash
grep -c "triage\|systematic-debugging\|gsd-debug\|silver:forensics\|gsd-forensics\|silver:tdd" skills/silver-bugfix/SKILL.md
```

Expected: ≥6 (triage + 3 path labels + tdd + forensics references)

- [ ] **Step 3: Commit**

```bash
git add skills/silver-bugfix/SKILL.md
git commit -m "feat: add silver:bugfix orchestration skill"
```

---

### Task B3: Create skills/silver-ui/SKILL.md

**Files:**
- Create: `skills/silver-ui/SKILL.md`

Orchestrates spec Section 4.3: intel → product-brainstorm → brainstorm → testing-strategy → writing-plans → quality-gates → discuss → ui-phase → plan → execute+tdd → review → ui-review → secure → verify → ship.

- [ ] **Step 1: Write skills/silver-ui/SKILL.md**

- [ ] **Step 2: Verify**

```bash
grep -c "gsd-ui-phase\|gsd-ui-review\|silver:tdd\|silver:request-review\|silver:brainstorm" skills/silver-ui/SKILL.md
```

Expected: ≥5 (each of the 5 grep terms should appear at least once)

- [ ] **Step 3: Commit**

```bash
git add skills/silver-ui/SKILL.md
git commit -m "feat: add silver:ui orchestration skill"
```

---

### Task B4: Create skills/silver-devops/SKILL.md

**Files:**
- Create: `skills/silver-devops/SKILL.md`

Orchestrates spec Section 4.4: intel → blast-radius → devops-skill-router → devops-quality-gates → discuss → plan → execute (no TDD) → review → secure-phase → verify → devops-quality-gates pre-ship → ship.

- [ ] **Step 1: Write skills/silver-devops/SKILL.md** — note: no brainstorming phase; uses 7-dimension devops-quality-gates at both pre-plan and pre-ship

- [ ] **Step 2: Verify**

```bash
grep -c "silver:blast-radius\|silver:devops-skill-router\|silver:devops-quality-gates\|gsd-secure-phase" skills/silver-devops/SKILL.md
```

Expected: ≥4 (each of the 4 grep terms should appear at least once)

- [ ] **Step 3: Commit**

```bash
git add skills/silver-devops/SKILL.md
git commit -m "feat: add silver:devops orchestration skill"
```

---

### Task B5: Create skills/silver-research/SKILL.md

**Files:**
- Create: `skills/silver-research/SKILL.md`

Orchestrates spec Section 4.5: explore → MultAI research (3 paths: landscape / tech-selection / competitive) → brainstorm → hand off to silver:feature or silver:devops with artifacts at `.planning/research/<date>-<topic>/`.

- [ ] **Step 1: Write skills/silver-research/SKILL.md** with three MultAI research path branches and artifact handoff protocol

- [ ] **Step 2: Verify**

```bash
grep -c "multai:landscape-researcher\|multai:orchestrator\|multai:comparator\|multai:solution-researcher\|\.planning/research" skills/silver-research/SKILL.md
```

Expected: ≥5 (each of the 5 grep terms should appear at least once)

- [ ] **Step 3: Commit**

```bash
git add skills/silver-research/SKILL.md
git commit -m "feat: add silver:research orchestration skill"
```

---

### Task B6: Create skills/silver-release/SKILL.md

**Files:**
- Create: `skills/silver-release/SKILL.md`

Orchestrates spec Section 4.6: quality-gates → audit-uat → audit-milestone → [gaps: plan-milestone-gaps → silver:feature, max 2 iterations] → docs-update + /documentation → milestone-summary → create-release → [ask] pr-branch → gsd-ship → gsd-complete-milestone.

- [ ] **Step 1: Write skills/silver-release/SKILL.md** with gap-closure loop (max 2 iterations, 3 user options on limit), gsd-ship before gsd-complete-milestone

- [ ] **Step 2: Verify**

```bash
grep -c "gsd-audit-uat\|gsd-audit-milestone\|gsd-plan-milestone-gaps\|silver:create-release\|gsd-complete-milestone\|gsd-ship" skills/silver-release/SKILL.md
```

Expected: ≥6 (each of the 6 grep terms should appear at least once)

- [ ] **Step 3: Commit**

```bash
git add skills/silver-release/SKILL.md
git commit -m "feat: add silver:release orchestration skill"
```

---

### Task B7: Create skills/silver-fast/SKILL.md

**Files:**
- Create: `skills/silver-fast/SKILL.md`

Orchestrates spec Section 4.7: trivial path — complexity triage confirms ≤3 files → gsd-fast (no planning overhead) → verify → commit. No quality gates, no brainstorming, no review cycle. The router routes here only when all signals confirm trivial scope.

> **Note:** `silver:fast` is not listed in spec §10 Phase B (which lists only 6 files: feature/bugfix/ui/devops/research/release), but it is required to implement spec §4.7. Added here as B7 for completeness — it is essential to the router's complexity triage path.

```markdown
---
name: silver-fast
description: "Trivial change fast-path: complexity triage → gsd-fast → verify → commit. No planning overhead."
argument-hint: "<description of trivial change>"
---

# /silver:fast — Trivial Change Fast Path

[Full step orchestration per spec Section 4.7]
```

- [ ] **Step 1: Write skills/silver-fast/SKILL.md** with complexity triage gate, gsd-fast invocation, and verify/commit steps. Include a clear STOP condition: if scope expands beyond 3 files during execution, escalate to the appropriate named workflow.

- [ ] **Step 2: Verify**

```bash
grep -c "gsd-fast\|complexity triage\|trivial\|≤3 files\|escalate" skills/silver-fast/SKILL.md
```

Expected: ≥5

- [ ] **Step 3: Commit**

```bash
git add skills/silver-fast/SKILL.md
git commit -m "feat: add silver:fast trivial change fast-path skill"
```

---

## Verification Checklist (run after all tasks complete)

- [ ] `grep -c "2h\. SB Orchestrated Workflows" silver-bullet.md` → 1
- [ ] `grep -c "2h\. SB Orchestrated Workflows" templates/silver-bullet.md.base` → 1
- [ ] `grep -c "10\. User Workflow Preferences" silver-bullet.md` → 1
- [ ] `grep -c "10\. User Workflow Preferences" templates/silver-bullet.md.base` → 1
- [ ] `grep -c "silver:feature\|silver:bugfix\|silver:ui\|silver:devops\|silver:research\|silver:release" skills/silver/SKILL.md` → ≥6
- [ ] `grep -c "MultAI\|gsd-new-project\|gsd-map-codebase" skills/silver-init/SKILL.md` → ≥3
- [ ] `ls skills/silver-feature skills/silver-bugfix skills/silver-ui skills/silver-devops skills/silver-research skills/silver-release skills/silver-fast` → 7 directories exist
- [ ] Each Phase B skill file contains ≥5 skill references — run:

```bash
for f in skills/silver-feature skills/silver-bugfix skills/silver-ui skills/silver-devops skills/silver-research skills/silver-release skills/silver-fast; do
  echo "$f: $(grep -c "silver:\|gsd-\|multai:" $f/SKILL.md) skill references"
done
```

Expected: each line shows ≥5

---

## Execution Notes

- **Phase A** executes as individual `/gsd-quick` tasks — one per A1–A5
- **Phase B** executes as a GSD phase (`/gsd-plan-phase` then `/gsd-execute-phase`) since it creates 7 new files and benefits from wave parallelism
- Both `silver-bullet.md` and `templates/silver-bullet.md.base` must be updated identically in every task that touches either — never update one without the other
- Section number for User Workflow Preferences: if §5 through §9 already exist in silver-bullet.md, append as §10 (confirmed: current last section is §9)
