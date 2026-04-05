<!-- This file is managed by Silver Bullet. Do not edit manually. -->
<!-- To update: run /using-silver-bullet in your project. -->

# Silver Bullet — Enforcement Instructions for silver-bullet

> **Always adhere strictly to this file and CLAUDE.md — they override all defaults.**

---

## 0. Session Startup (Automatic)

At the very start of any new session, perform these steps automatically:

1. **Switch to Opus 4.6 (1M context)** if not already selected.
2. **Read all project docs** — this file and 100% of docs/.
3. **Compact the context** — run /compact to free context for the task.
4. **Switch back to original model** if it was changed in step 1.

> **Anti-Skip:** you are violating this rule if you begin work without reading docs/ or skip /compact. Evidence: no Read tool calls for docs/ files in session start.

---

## 1. Automated Enforcement

Six technical layers plus one documentation layer enforce compliance:

1. **Skill tracker** (PostToolUse/Skill) — Records every Silver Bullet skill invocation to the state file
2. **Stage enforcer** (Pre+PostToolUse/Edit|Write|Bash) — HARD STOP if planning skills incomplete before source edits
3. **Compliance status** (PostToolUse/all) — Shows workflow progress on every tool use (informational)
4. **Completion audit** (Pre+PostToolUse/Bash) — Blocks intermediate commits until planning is done; blocks PR/deploy/release until full workflow is done
5. **CI status check** (Pre+PostToolUse/Bash) — Blocks further commits and actions when CI is failing
6. **Session management** (PostToolUse/Bash) — Session logging, autonomous mode timeout detection, branch-scoped state reset
7. **Redundant instructions + anti-rationalization** — Workflow file + CLAUDE.md both enforce;
   explicit rules against skipping, combining, or implicitly covering steps

**Enforcement model**: Hooks are **invocation-based**, not outcome-based.
`record-skill.sh` records that a skill was *called*; it cannot verify
the skill produced a meaningful result. You are responsible for actually
doing the work each skill requires — not just invoking it. Vacuous
invocation (calling a skill and dismissing its output) satisfies the
hook technically but violates the workflow intent and will be caught
during code review or verification.

**GSD command visibility**: GSD commands (`/gsd:discuss-phase`, etc.)
are tracked via their Skill tool invocations and recorded as `gsd-*`
markers in the state file. The compliance status shows `GSD N/5` for
the 5 core phases. However, recording only proves invocation — it does
not verify GSD phases completed successfully.

**Trivial changes** (typos, copy fixes, config tweaks): Automatically
detected by hooks. Small edits (<100 chars) and non-logic files (.md,
.txt, .css, .svg, etc.) skip enforcement per-edit. No action needed.
**Note**: In the `devops-cycle` workflow, `.yml`, `.yaml`, `.json`, and
`.toml` files are infrastructure code and are NOT auto-exempted.

**Subagent commits**: Every git commit MUST use HEREDOC format and end with:
Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>

---

## 2. Active Workflow

The active workflow is loaded from `docs/workflows/`. Claude MUST read
the active workflow file before starting any non-trivial task.

**Active**: `docs/workflows/full-dev-cycle.md`

**Skill not found rule**: If a skill listed in the workflow cannot be
invoked, STOP and notify the user immediately. Do NOT silently skip.

> **Anti-Skip:** You are violating this rule if you start a non-trivial task without a Read call to the active workflow file. The compliance-status hook will show your progress — if it shows 0 steps, you have not read the workflow.

### Hand-Holding at Transitions

At each workflow transition, proactively narrate to the user:

| Transition | What to say |
|------------|-------------|
| Session start -> DISCUSS | "Starting the planning phase. I'll ask questions to understand what you want to build before any code is written." |
| DISCUSS -> QUALITY GATES | "Discussion complete -- CONTEXT.md captured your decisions. Running quality gates next to validate the approach before planning." |
| QUALITY GATES -> PLAN | "Quality gates passed. Now creating execution plans -- these break your phase into concrete tasks with verification criteria." |
| PLAN -> EXECUTE | "Plans created. Executing now -- each task produces atomic commits. You'll see progress as files are created/modified." |
| EXECUTE -> VERIFY | "Execution complete. Running verification to confirm everything works end-to-end against the phase requirements." |
| VERIFY -> REVIEW | "Verification passed. Running code review -- security, performance, correctness checks before we finalize." |
| Last phase VERIFY -> FINALIZE | "All phases complete. Moving to finalization -- testing strategy, tech debt, documentation, and branch cleanup." |
| FINALIZE -> SHIP | "Finalization complete. Shipping now -- CI verification, deploy checklist, then PR creation." |

### 2a. Workflow Transitions

Two workflows exist: `full-dev-cycle` (application development) and `devops-cycle`
(infrastructure). Transitions happen after RELEASE:

**Dev -> DevOps:** After shipping an application release, if IaC files are present,
deploy checklist flagged gaps, or user requests it -- offer to switch `active_workflow`
in `.silver-bullet.json` to `devops-cycle`.

**DevOps -> Dev:** After deploying infrastructure, offer to switch back to
`full-dev-cycle` for the next milestone of feature development.

**What is preserved:** Everything -- `.planning/` artifacts, `.silver-bullet.json`
config, state, git history. Only `active_workflow` changes.

### 2b. GSD Process Knowledge

Claude reads this once at session start and can explain any step to the user
without consulting GSD workflow files.

**Core Workflow Commands (per-phase loop):**

| Command | What it does | Produces |
|---------|-------------|----------|
| `/gsd:new-project` | Deep questioning about vision, optional research, requirements scoping, roadmap generation | PROJECT.md, REQUIREMENTS.md, ROADMAP.md |
| `/gsd:new-milestone` | Loads previous context, gathers goals for new milestone, defines scoped requirements | Fresh ROADMAP.md carrying forward accumulated context |
| `/gsd:discuss-phase` | Conversational requirements gathering for current phase -- asks questions, captures decisions | CONTEXT.md with locked decisions (D-01, D-02...) |
| `/gsd:plan-phase` | Decomposes phase into parallel-optimized plans with 2-3 tasks each, dependency graphs, verification criteria | PLAN.md files with wave structure |
| `/gsd:execute-phase` | Wave-based execution -- spawns subagents per plan, atomic commits per task, auto-resumes incomplete plans | Committed code + SUMMARY.md per plan |
| `/gsd:verify-work` | Checks must-haves, runs automated tests, validates artifacts exist and connect correctly | VERIFICATION.md with pass/fail per truth |
| `/gsd:ship` | Runs deployment checklist, pushes to remote, confirms CI green, creates PR with auto-generated body | Deployed, CI-green codebase + pull request |

**Project Lifecycle Commands:**

| Command | What it does | When to use |
|---------|-------------|-------------|
| `/gsd:map-codebase` | Analyzes existing codebase into 7 structured docs (stack, architecture, patterns, etc.) | Brownfield projects before /gsd:new-project |
| `/gsd:autonomous` | Drives remaining phases end-to-end (discuss, plan, execute per phase) | Multi-phase autonomous execution |
| `/gsd:audit-milestone` | Aggregates phase verifications, checks cross-phase integration, requirements coverage | End of milestone before completing |
| `/gsd:complete-milestone` | Marks milestone done, creates MILESTONES.md record, archives artifacts, tags release | After all phases verified and shipped |
| `/gsd:add-phase` | Appends new phase to end of current milestone roadmap | Discovered work not in original roadmap |
| `/gsd:insert-phase` | Inserts decimal phase between existing (e.g., 3.1 between 3 and 4) | Urgent fix before next planned phase |
| `/gsd:review` | Cross-AI peer review -- invokes Gemini, Codex, CodeRabbit independently | Adversarial review before execution |
| `/gsd:next` | Detects current state, auto-advances to next logical step | Unsure what comes next |

### 2c. Utility Command Awareness

Suggest these commands based on context -- do not wait for the user to ask.

| Context trigger | Suggest | Why |
|----------------|---------|-----|
| Execution fails, tests break, unexpected error | `/gsd:debug` | Spawns parallel agents to diagnose root cause |
| User mentions a small change outside the current phase | `/gsd:quick` | Handles ad-hoc tasks with atomic commits + state tracking |
| Change is truly trivial (typo, config value, 3 files max) | `/gsd:fast` | Inline execution, no subagent overhead |
| New session on existing project | `/gsd:resume-work` | Restores full context from STATE.md + HANDOFF.json |
| User wants to stop mid-work | `/gsd:pause-work` | Creates handoff files for clean session resume |
| User asks "where are we?" or "what's left?" | `/gsd:progress` | Rich progress report with next actions |
| User seems unsure what step is next | `/gsd:next` | Auto-advances to the next logical step |

---

## 3. NON-NEGOTIABLE RULES

These rules apply to EVERY non-trivial change. There are NO exceptions.

You MUST NOT:
- Skip a REQUIRED step because "it's simple enough"
- Combine or implicitly cover steps ("I did code review while writing")
- Claim a step is "not applicable" without explicit user approval
- Proceed to the next phase before completing the current phase
- Claim work is complete without running `/gsd:verify-work`

If you believe a step is genuinely not applicable, you MUST:
1. State which step you want to skip
2. State why
3. Wait for explicit user approval before proceeding

"I already covered this" is NOT valid. Each Silver Bullet skill MUST be
explicitly invoked via the Skill tool — implicit coverage does not count
because the enforcement hooks track Skill tool invocations, not your judgment.
GSD steps MUST be invoked as slash commands in the correct phase order.

**Rules**:
- Do NOT stop until the final outcome is achieved
- Always use `/gsd:debug` for ANY bug encountered during execution
- Always use `/forensics` for root-cause investigation when the cause is **unknown** and must be reconstructed from evidence (completed sessions, abandoned sessions, unexplained verification failures). If the cause IS known (e.g., specific test failure, clear error message), use `/gsd:debug` instead.
- CI must be green before deployment. When the CI status hook reports failure after a push, STOP all other work immediately and invoke `/gsd:debug` to investigate. Do NOT proceed to any other step until CI is green.
- `README.md` MUST be updated to reflect current version, features, and changes before release. `/create-release` will block if README is stale.
- Always strictly adhere to this file and CLAUDE.md 100%

> **Anti-Skip:** You are violating this rule if:
> - You produce source code without a skill invocation recorded in the state file (dev-cycle-check.sh will block you)
> - You claim "I already covered X" instead of invoking the skill (record-skill.sh tracks invocations, not claims)
> - You skip /gsd:verify-work at the end (completion-audit.sh will block your commit/push)
> - You proceed past a review loop with fewer than 2 consecutive approvals

## 3a. Review Loop Enforcement

Every review loop (spec review, plan review, code review, verification) **MUST iterate until the reviewer returns ✅ Approved TWICE IN A ROW**. A single clean pass is not sufficient — the reviewer must find no issues on two consecutive passes. There are NO exceptions.

You MUST NOT:
- Stop a review loop because "issues are minor"
- Stop because "it's close enough"
- Accept a partial fix and move on without re-dispatching
- Count a loop as done unless the reviewer explicitly outputs `✅ Approved` on two consecutive passes
- Count a single clean pass as done

The loop is self-limiting: it ends when two consecutive clean passes are produced. Surface to the user only if the reviewer raises an issue it cannot resolve (e.g. requires a decision, a missing dependency, or an external constraint).

## 3b. GSD Command Tracking

After completing each GSD command, record a marker in the state file:

```bash
echo "gsd-discuss" >> ~/.claude/.silver-bullet/state    # after /gsd:discuss-phase
echo "gsd-plan" >> ~/.claude/.silver-bullet/state       # after /gsd:plan-phase
echo "gsd-execute" >> ~/.claude/.silver-bullet/state    # after /gsd:execute-phase
echo "gsd-verify" >> ~/.claude/.silver-bullet/state     # after /gsd:verify-work
```

These markers enable dev-cycle-check.sh and completion-audit.sh to verify
GSD commands were actually invoked, not just claimed. The same accepted
fragility as quality-gate-stage-N markers applies: markers depend on
Claude compliance, which is reinforced by the anti-skip text throughout
this file.

> **Anti-Skip:** You are violating this rule if you complete a GSD command without writing its marker. Future enforcement hooks will check for these markers.

---

## 4. Session Mode

**Bypass-permissions detection:** If the session is running with Claude Code's
"Bypass permissions" toggle enabled (i.e., all tool calls are auto-accepted without
user confirmation prompts), skip the interactive/autonomous question entirely.
Auto-set autonomous mode immediately:
```bash
echo "autonomous" > ~/.claude/.silver-bullet/mode
```
Log: "Autonomous mode auto-set: bypass-permissions detected".
Also suppress ALL other confirmation-asking behaviors for the remainder of the session
(e.g., "Proceed? yes/no", phase gate approvals, model routing questions in section 5).
Use defaults for any skipped questions. Log each suppressed question under
"Autonomous decisions" with note "(bypass-permissions)".

**Persistent permission mode**: If the user reports that Claude Code keeps asking
for permissions despite setting bypass-permissions, the issue is that the UI toggle
only applies to the current session. To persist it, add to `.claude/settings.local.json`:

> ⚠️ **CAUTION — bypassPermissions:** Only use this setting in a **fully isolated environment** (container, VM, or dedicated CI runner with no access to production systems, credentials, or sensitive files). Verify isolation **before** applying this setting. Misuse in non-isolated environments permanently disables all Claude Code permission guardrails.

```json
{"permissions":{"defaultMode":"bypassPermissions"}}
```
Or for safer auto-approval (recommended for non-isolated environments):
```json
{"permissions":{"defaultMode":"auto"}}
```
This is a Claude Code platform setting, not a Silver Bullet setting.

At the start of every session, before any work begins, ask:

> Run this session **interactively** or **autonomously**?
> - **Interactive** (default) — I pause at decision points and phase gates
> - **Autonomous** — I drive start to finish and surface blockers at the end

Write the choice:
```bash
echo "interactive" > ~/.claude/.silver-bullet/mode
# or
echo "autonomous" > ~/.claude/.silver-bullet/mode
```

**Fallback**: if `~/.claude/.silver-bullet/mode` is unreadable at any point, default to interactive
and log "Mode fallback: defaulted to interactive" in the session log.

**In autonomous mode:**
- Phase gates removed — proceed without approval pauses
- Clarifying questions suppressed — make best-judgment calls, log each as "Autonomous decision"
- **Genuine blockers first** (missing credentials, ambiguous destructive operations): these take
  precedence over all other rules — queue under "Needs human review", skip, surface in summary
- **Anti-stall** (non-blocker stalls only): a stall = any of these three conditions:
  1. Same tool call with identical args producing the same result 2+ times consecutively
  2. 3+ tool calls in one step with no new state change (no file written, no decision, no new info)
  3. Per-step budget: >10 tool calls in one step AND no file written (Write/Edit resets counter)
     AND no autonomous decision logged since step began. Counter resets on Write/Edit, on any
     decision log event, and when a new `/gsd:` command or skill is invoked (new step boundary).
  On any stall: make best-judgment decision, move on, log under "Autonomous decisions".
- All Agent Team dispatches use `run_in_background: true`
- On completion: output structured summary (phases done, autonomous decisions, blockers queued,
  agents dispatched, commits made, virtual cost)

> **Anti-Skip:** You are violating this rule if the mode file (~/.claude/.silver-bullet/mode) does not exist when you begin work. The compliance-status hook displays mode on every tool call — if it shows "unknown", you skipped this step.

---

## 5. Model Routing

Default model: **claude-sonnet-4-6** (latest Sonnet). No user friction for standard work.

Ask about Opus at two phase transitions only:

1. **Before Planning begins (before DISCUSS step):**
   > Entering Planning phase. Use Opus (claude-opus-4-6) for deeper reasoning, or stay on Sonnet?

2. **Before Design sub-steps apply (design-system / ux-copy / architecture / system-design):**
   > Entering Design phase. Use Opus, or stay on Sonnet?

If Opus permitted: switch to `claude-opus-4-6` for that phase, return to Sonnet afterward.

**Autonomous mode**: stay Sonnet. Escalate silently to Opus only if a planning step produces
measurably incomplete output: fewer than 5 lines, contains `TBD`/`[TODO]`/`...` placeholders,
or a step expected to produce a file produces none. Log escalation as an autonomous decision.

> **Anti-Skip:** You are violating this rule if you enter Planning or Design phases without offering the Opus upgrade. Evidence: no model switch prompt in conversation before /gsd:discuss-phase or design skill invocation.

---

## 6. GSD / Superpowers Ownership Rules

GSD is the authoritative execution orchestrator. Superpowers provides design and review
capabilities only. Where both tools could apply, **GSD wins**.

Silver Bullet orchestrates the user experience and delegates execution to GSD. Silver
Bullet owns what to do and when; GSD owns how.

**Hard rules — no exceptions:**

- **Execution**: Always use `/gsd:execute-phase` (wave-based). NEVER use
  `superpowers:subagent-driven-development` or `superpowers:executing-plans` for project work.
  "Project work" means implementation and planning. Code review, design review, and security
  audit are NOT execution — Superpowers review skills are used for those per the workflow.
- **Planning**: Always use `/gsd:plan-phase`. When Superpowers' `brainstorming` skill offers
  to hand off to `writing-plans`, **redirect to `/gsd:plan-phase` instead**.
- **Requirements**: `.planning/REQUIREMENTS.md` is the single source of truth (owned by GSD).
  Superpowers must NOT create or maintain a separate requirements list.
- **Design specs**: Save to `docs/specs/YYYY-MM-DD-<topic>-design.md`.
  Superpowers' default path (`docs/superpowers/specs/`) is overridden — use `docs/specs/`.
- **Code review**: Engineering's `/code-review` and Superpowers' review skills (`/requesting-code-review`,
  `/receiving-code-review`, `superpowers:code-reviewer`) are used for review only.

> **Anti-Skip:** You are violating this rule if you use superpowers:executing-plans or superpowers:subagent-driven-development for project execution. The compliance-status hook shows "GSD owns execution" as a constant reminder.

---

## 7. File Safety Rules

These rules apply to ALL file operations, in every context and session mode.

- **Never overwrite, rename, move, or delete** any existing project file without first
  communicating the objective to the user and obtaining explicit permission.
- Permission may be requested for a logical group of files in one prompt (e.g., "I need to
  update these 3 template files to apply the new workflow — proceed?"), but the intent and
  scope must be clear before any file is touched.
- **When in doubt: skip and inform**, never act and apologize.
- This applies to Silver Bullet setup, template refresh, and all agent/subagent operations.

---

## 8. Third-Party Plugin Boundary

Silver Bullet orchestrates four external plugins (GSD, Superpowers, Engineering, Design)
but **NEVER modifies their skill files**. All behavioral changes MUST be implemented in
Silver Bullet's own orchestrator layer — CLAUDE.md, workflows, hooks, or Silver Bullet skills.

You MUST NOT:
- Edit any file under `~/.claude/plugins/cache/` (third-party plugin caches)
- Modify a Superpowers, Engineering, Design, or GSD skill file to change behavior
- Fork or patch an upstream skill — wrap it in a Silver Bullet hook or workflow step instead

If a third-party skill's behavior needs adjustment, implement the change as:
1. A workflow instruction (in `templates/workflows/*.md`) that runs before/after the skill
2. A hook (in `hooks/`) that intercepts or augments the skill's output
3. A Silver Bullet skill (in `skills/`) that wraps the third-party skill with additional logic

---

## 9. Pre-Release Quality Gate

Before ANY release (`/create-release`), the following four-stage quality gate MUST
be completed in order. Each stage has its own completion criteria. Skipping a stage
or declaring it complete without meeting the criteria violates Section 3.

**IMPORTANT**: This gate runs AFTER the normal workflow finalization steps (testing,
documentation, branch cleanup, deploy checklist) and BEFORE `/create-release`.
The `/create-release` skill will not be invoked until all four stages pass.

### Stage 1 — Code Review Triad

Run all three review skills in sequence, then fix all issues. Repeat until clean.

1. Invoke `/code-review` (Engineering) — structured quality review: security, performance, correctness, maintainability
2. Invoke `/requesting-code-review` — dispatches `superpowers:code-reviewer` automated reviewer
3. Invoke `/receiving-code-review` — triage combined feedback from steps 1-2
4. Fix all accepted issues
5. **Loop**: repeat steps 1-4 until `/receiving-code-review` produces zero accepted items
6. **MANDATORY — invoke `/superpowers:verification-before-completion`** via the Skill tool.
   Running verification commands manually is NOT a substitute for invoking this skill.
   You need BOTH: (a) run the actual verification commands, AND (b) invoke the skill so
   `record-skill.sh` tracks it. If you ran tests/CI/checks but did not invoke the skill,
   you have NOT completed this step. Do NOT record the stage marker until BOTH are done.
7. Record stage completion: `echo "quality-gate-stage-1" >> ~/.claude/.silver-bullet/state`

### Stage 2 — Big-Picture Consistency Audit

Review the entire plugin for cross-file inconsistencies, redundancies, and contradictions.

1. Dispatch parallel Explore agents across five dimensions:
   - Workflows (full-dev-cycle.md vs devops-cycle.md vs CLAUDE.md vs silver-bullet.md)
   - Skills (all SKILL.md files — obsolete references, redundant work, contradictions)
   - Hooks + config (.sh files, hooks.json, .silver-bullet.json, templates)
   - Help site + README (HTML pages, search.js, README.md — step counts, paths, versions)
   - Cross-plugin consistency (read 100% of skill content from all 4 dependency plugins — GSD: ~/.claude/get-shit-done/ workflows/references/templates; Superpowers: ~/.claude/plugins/cache/*/superpowers/*/skills/*/SKILL.md; Engineering: ~/.claude/plugins/cache/*/knowledge-work-plugins/*/engineering/skills/*/SKILL.md; Design: ~/.claude/plugins/cache/*/knowledge-work-plugins/*/design/skills/*/SKILL.md — check for contradictions, conflicts, inconsistencies, or redundancies between Silver Bullet instructions and upstream plugin skills)
2. Fix all genuine issues found
3. **Loop**: repeat until two consecutive audit passes find zero issues
4. **MANDATORY — invoke `/superpowers:verification-before-completion`** via the Skill tool.
   Do NOT record the stage marker without invoking this skill first.
5. Record stage completion: `echo "quality-gate-stage-2" >> ~/.claude/.silver-bullet/state`

### Stage 3 — Public-Facing Content Refresh

Verify and update all user-visible surfaces to reflect the current state.

1. Audit for factual accuracy:
   - GitHub repo description and topics (`gh repo edit`)
   - README.md (version, step counts, enforcement layers, state paths, architecture)
   - Landing page (`site/index.html`)
   - All help pages (`site/help/*/index.html`)
   - Search index (`site/help/search.js`)
   - Compare page (`site/compare/index.html`) if it exists
2. Fix all discrepancies
3. **MANDATORY — invoke `/superpowers:verification-before-completion`** via the Skill tool.
   Do NOT record the stage marker without invoking this skill first.
4. Push and confirm CI green
5. Record stage completion: `echo "quality-gate-stage-3" >> ~/.claude/.silver-bullet/state`

### Stage 4 — Security Audit (SENTINEL)

Run the SENTINEL v2.3 adversarial security audit against the full plugin.

1. Invoke `/anthropic-skills:audit-security-of-skill` targeting the plugin root
2. Fix all findings (Critical, High, Medium; Low at discretion)
3. Re-run the audit
4. **Loop**: repeat until two consecutive audit passes find zero issues
5. **MANDATORY — invoke `/superpowers:verification-before-completion`** via the Skill tool.
   Do NOT record the stage marker without invoking this skill first.
6. Record stage completion: `echo "quality-gate-stage-4" >> ~/.claude/.silver-bullet/state`

### Pre-Release Gate Enforcement

The completion audit hook (`hooks/completion-audit.sh`) blocks `gh release create`
until all required workflow skills AND quality gate stage markers are recorded in
the state file (`~/.claude/.silver-bullet/state`). Required markers:
- Stage 1: `quality-gate-stage-1` (recorded per instructions above)
- Stage 2: `quality-gate-stage-2` (recorded per instructions above)
- Stage 3: `quality-gate-stage-3` (recorded per instructions above)
- Stage 4: `quality-gate-stage-4` (recorded per instructions above)

**Session reset:** The `session-start` hook clears all quality-gate-stage-* and
gsd-* markers from the state file at the beginning of every session. This ensures
each release cycle must earn its own quality gate pass — stale markers from a
previous release cannot satisfy the gate for a new release.

> **Anti-Skip:** You are violating this rule if you release without running all 4 stages
> in the CURRENT session. Stale markers from a prior session are automatically cleared.

If any stage surfaces a blocker that cannot be resolved (e.g., upstream dependency
issue, ambiguous design decision), log it under "Needs human review" and surface
to the user before proceeding to the next stage.

> **Anti-Skip:** You are violating this rule if you attempt /create-release without all four quality-gate-stage-N markers in the state file. completion-audit.sh will block the release. Each stage requires explicit /superpowers:verification-before-completion invocation — the marker alone is insufficient.
