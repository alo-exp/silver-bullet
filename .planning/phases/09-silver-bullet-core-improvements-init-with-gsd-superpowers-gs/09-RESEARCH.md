# Phase 9: Silver Bullet Core Improvements — Research

**Researched:** 2026-04-08
**Domain:** Silver Bullet skill authoring, GSD state integration, UX patterns, Claude Code AskUserQuestion API
**Confidence:** HIGH (all findings from direct codebase inspection)

---

## Summary

Phase 9 adds four focused improvements to Silver Bullet's core: (1) `silver:init` must initialize GSD and Superpowers alongside SB and auto-update any outdated dependencies, (2) SB must stop duplicating state that GSD already owns and instead read GSD's `.planning/STATE.md` to drive step-by-step guidance, (3) SB must provide rich narration at every transition (interactive) and commentary (autonomous) so users always know where they are in the workflow, and (4) every multi-option user choice must be presented as lettered bullets (A, B, C, …) so users can respond with a single letter.

All four requirements are changes to existing Silver Bullet skill files and `silver-bullet.md`. No third-party plugin files may be touched (§8 boundary). No new hooks are needed — this is purely content and logic updates inside SB's own layer.

**Primary recommendation:** Implement all four requirements as targeted edits to `skills/silver-init/SKILL.md`, `silver-bullet.md`, and where relevant other skills. The GSD state delegation requirement is mostly documentation/instruction — SB's enforcement hooks already defer to GSD; the gap is in the human-facing guidance script inside `silver-bullet.md`.

---

## Project Constraints (from CLAUDE.md)

- Stack: Node.js
- Git repo: https://github.com/alo-exp/silver-bullet.git
- Always follow `silver-bullet.md` and `CLAUDE.md` — they override all defaults
- **§8 Third-Party Plugin Boundary**: NEVER edit files under `~/.claude/plugins/cache/` or any GSD/Superpowers/Engineering/Design skill file

---

## Research Findings by Requirement

### REQ-1: silver:init must initialize GSD and Superpowers, and auto-update if outdated

**Current behavior** [VERIFIED: skills/silver-init/SKILL.md]:

- Phase 1 (Dependency Check) confirms GSD and Superpowers are *installed* — it checks for presence of `~/.claude/commands/gsd/new-project.md` (GSD) and `~/.claude/plugins/cache/*/superpowers/*/skills/brainstorming/SKILL.md` (Superpowers).
- If either is absent, init prints an install error and HARD STOPs.
- `silver:init` does NOT check whether the installed versions are current.
- `silver:init` does NOT invoke any update for GSD, Superpowers, or SB itself.
- Phase 3.8 invokes `/using-superpowers` to activate Superpowers for the session — this is the only post-install initialization step.
- GSD has no initialization skill; GSD is ready to use once installed — no "gsd:init" exists. [VERIFIED: ~/.claude/skills/ listing]

**What is needed:**
1. After the presence check for GSD (§1.5) and Superpowers (§1.2), add a version-freshness check.
2. For GSD: `silver:update` equivalent is `/gsd-update` skill — it checks npm for the latest version and offers a clean install. [VERIFIED: ~/.claude/skills/gsd-update/SKILL.md]
3. For Superpowers (and Design/Engineering plugins): there is no equivalent `superpowers:update` skill visible in the installed skills. The install mechanism is `/plugin install obra/superpowers`. [VERIFIED: skills listing — no superpowers-update or plugin-update skill found]
4. For SB itself: `/silver:update` (exists) checks GitHub for latest and offers a git-clone update. [VERIFIED: skills/silver-update/SKILL.md]

**Version detection approaches:**
- **GSD**: Read `~/.claude/get-shit-done/VERSION` (GSD stores its version here — confirmed by gsd-update workflow which reads it) vs latest npm `get-shit-done-cc` version via `npm view get-shit-done-cc version`.
- **Superpowers/Design/Engineering plugins**: Read `~/.claude/plugins/installed_plugins.json` for installed version. To check latest, would need to query GitHub API (no npm package). Pattern exists in `silver:update` for SB itself.
- **SB itself**: Read `~/.claude/plugins/installed_plugins.json` for `silver-bullet@silver-bullet` entry — exactly what `silver:update` does.

**Key constraint**: Because `silver:init` must HARD STOP when GSD is missing (§8 boundary — never modify third-party plugins), the init skill can invoke `/gsd-update` and `/silver:update` but cannot install GSD from scratch. The existing HARD STOP on GSD absence is correct. The new behavior adds: if GSD is present but outdated, offer to run `/gsd-update`.

**Superpowers update gap**: There is no `/superpowers:update` or `/plugin:update` skill. For Superpowers, Design, and Engineering plugins, the only update path is to re-run `/plugin install <path>`. This is an [ASSUMED] install mechanism unless verified with Claude Code plugin docs, but is consistent with how `silver:init` Phase 1 tells users to install (`/plugin install obra/superpowers`).

**Design decision needed**: Should init auto-invoke update skills, or just detect staleness and prompt? Given the "interactive mode" context, the recommended pattern is: detect staleness → present lettered option (A: update now, B: skip) → invoke update skill only on explicit confirmation.

---

### REQ-2: SB must delegate state to GSD — not duplicate it

**Current SB state tracking** [VERIFIED: silver-bullet.md, hooks/]:

SB maintains its own state in `~/.claude/.silver-bullet/state`. This file contains:
- Skill invocation markers (`gsd-discuss-phase`, `gsd-plan-phase`, etc.) written by `record-skill.sh`
- Quality gate stage markers (`quality-gate-stage-1` through `quality-gate-stage-4`)
- Session mode (`interactive` / `autonomous`) in `~/.claude/.silver-bullet/mode`
- `session-init` sentinel file

**GSD state** [VERIFIED: .planning/STATE.md schema]:

GSD owns `.planning/STATE.md` with:
- `current_plan`, `status`, `stopped_at`, `last_updated`, `last_activity`
- `progress.total_phases`, `completed_phases`, `total_plans`, `completed_plans`, `percent`
- `milestone`, `milestone_name`

**Gap analysis**:

SB's state file duplicates GSD's progression tracking in a weaker way: SB records *which GSD commands were invoked* but not *whether they succeeded* or *what phase/plan the user is currently on*. GSD's `.planning/STATE.md` has authoritative data on current phase, completion status, and progress.

What SB should NOT do: maintain its own phase-progress counter or "current step" tracker that can drift from GSD's actual state.

What SB SHOULD do: at guidance/narration points, read `.planning/STATE.md` to determine where the user is, then narrate appropriately.

**Concrete SB-owned state that is NOT in GSD** (must stay in SB):
- `quality-gate-stage-N` markers — pre-release gate tracking (SB-specific, no GSD equivalent)
- Session mode (interactive/autonomous) — SB-specific UX setting
- `session-init` sentinel — SB session startup once-per-session guard

**Conclusion**: SB does not need to delete or dramatically restructure its state. The requirement is about *guidance logic*: when SB narrates the current step, it should derive position from GSD's STATE.md rather than from the SB state file. The SB state file legitimately tracks SB-specific markers. The fix is in how `silver-bullet.md` Section 2 instructs Claude to determine "where we are."

---

### REQ-3: Guided UX — step-by-step in interactive, commentary in autonomous

**Current state** [VERIFIED: silver-bullet.md §2 Hand-Holding at Transitions]:

`silver-bullet.md` already has a "Hand-Holding at Transitions" table with 8 transition narrations:
- Session start → DISCUSS
- DISCUSS → QUALITY GATES
- QUALITY GATES → PLAN
- PLAN → EXECUTE
- EXECUTE → VERIFY
- VERIFY → REVIEW
- Last phase VERIFY → FINALIZE
- FINALIZE → SHIP

**Gaps identified**:

1. The table covers high-level workflow transitions but not the *within-step* guidance (e.g., "You are now in Phase 3, Plan 2 of 3. This plan handles the authentication module.").
2. There is no GSD state read instruction telling Claude to check `.planning/STATE.md` and `ROADMAP.md` to contextualize where in the "big picture" the user is.
3. Autonomous mode guidance (§4) suppresses clarifying questions but does not prescribe commentary output format — there's no autonomous narration template.
4. There is no "big picture" progress display instruction — showing the user "Phase 3 of 8, Plan 2 of 3" at each step boundary.
5. The Section 2c utility command awareness table exists but Claude is told to "suggest based on context" — no explicit trigger to narrate the suggestion in guided mode.

**What needs to be added to `silver-bullet.md`**:
- An instruction to read `.planning/STATE.md` and `.planning/ROADMAP.md` at step boundaries to derive current position.
- A big-picture progress banner template for interactive mode.
- An autonomous commentary template so Claude narrates what it's doing and why, without waiting for input.
- Within-phase guidance: when inside a phase, narrate which plan is running, what it produces, and what comes next.

---

### REQ-4: Lettered option bullets (A, B, C) for all user choices

**Current state of options in SB skills** [VERIFIED: direct search]:

- `silver:update` SKILL.md uses `AskUserQuestion` with options listed as strings ("Yes, update now", "No, cancel") — no letters.
- `silver/SKILL.md` (router) presents options with numbered format ("1. /quality-gates", "2. /blast-radius") in freeform text — not AskUserQuestion.
- `silver:init` SKILL.md presents options as freeform prose ("yes / edit", "yes / no / skip-all", "clone / create", "yes / no") — not AskUserQuestion, not lettered.
- `silver-bullet.md` §4 presents mode options as "- **Interactive**", "- **Autonomous**" — bulleted but not lettered.
- `silver-bullet.md` §2.6 presents permission mode options numbered 1-3.

**AskUserQuestion API behavior** [ASSUMED: based on how it's used throughout GSD and SB skills]:
- `AskUserQuestion` takes a `question` string and an `options` array of strings.
- The Claude Code UI renders these as clickable buttons. The user can click a button or type.
- The API does NOT natively prepend A/B/C labels — the option strings themselves must include the letter prefix.
- GSD uses this pattern: options are plain strings without letters (e.g., "Yes, update now").
- To implement lettered bullets, the option strings must be written as "A. Yes, update now", "B. No, cancel", etc.

**Scope of changes needed**:
Every place in SB skills where options are presented to the user needs to:
1. Use `AskUserQuestion` (not freeform prose).
2. Prefix each option string with a letter: "A. ...", "B. ...", "C. ...".

Files to update:
- `skills/silver-update/SKILL.md` — already uses AskUserQuestion, add letter prefixes
- `skills/silver/SKILL.md` — uses numbered list in prose, convert to AskUserQuestion with lettered options
- `skills/silver-init/SKILL.md` — uses prose "yes/no/skip-all" patterns, convert to AskUserQuestion with lettered options
- `silver-bullet.md` §4 mode selection — uses prose, convert to AskUserQuestion with lettered options
- `silver-bullet.md` §2.6 permission mode — numbered 1-3, convert to lettered A/B/C

**Note**: GSD's own skills use AskUserQuestion without letters. SB should add letters only in SB-owned files. We must NOT change GSD skill files (§8 boundary).

---

## Standard Patterns

### AskUserQuestion with lettered options
```
Use AskUserQuestion:
- Question: "Proceed with update to vA.B.C?"
- Options:
  - "A. Yes, update now"
  - "B. No, cancel"
```
[VERIFIED: extrapolated from existing silver:update pattern — add letter prefix to each option string]

### Reading GSD state in a skill
```bash
cat .planning/STATE.md 2>/dev/null | head -20
```
Then parse YAML front matter for `current_plan`, `status`, `stopped_at`, `progress.*`. [VERIFIED: STATE.md schema observed in .planning/STATE.md]

### Checking GSD version
```bash
cat "$HOME/.claude/get-shit-done/VERSION" 2>/dev/null
npm view get-shit-done-cc version 2>/dev/null
```
[VERIFIED: gsd-update workflow reads VERSION file; npm view is standard]

### Checking SB version
```bash
cat "$HOME/.claude/plugins/installed_plugins.json" | jq -r '.["silver-bullet@silver-bullet"].version'
```
[VERIFIED: silver:update SKILL.md reads installed_plugins.json]

---

## Architecture Patterns

### Where each requirement lives

| Requirement | Files to Edit | Pattern |
|-------------|--------------|---------|
| REQ-1: init GSD+SP+update | `skills/silver-init/SKILL.md` | Add version check after Phase 1 presence checks; invoke update skills if stale |
| REQ-2: GSD state delegation | `silver-bullet.md` §2 | Add instruction to read STATE.md + ROADMAP.md at step boundaries; remove any SB-side phase-progress duplication |
| REQ-3: guided UX | `silver-bullet.md` §2, §4 | Expand Hand-Holding table; add big-picture progress template; add autonomous commentary format |
| REQ-4: lettered bullets | All SB skills + silver-bullet.md §4 | Convert prose options to AskUserQuestion with "A. ...", "B. ...", "C. ..." prefixes |

### Phase 1.5-bis: Version freshness check (new step in silver:init)

After Phase 1 confirms presence of each dependency, add Phase 1.5 that checks version currency:

```
Phase 1.5: Version Freshness Check

For each dependency found in Phase 1:
  1. Read installed version
  2. Query latest available version
  3. If outdated: present lettered option (A: update now / B: skip)
  4. If user selects A: invoke update skill; wait for completion; continue
  5. If user selects B: continue with warning

Order: SB first, then GSD, then Superpowers (and Design/Engineering).
```

This follows the same pattern as `silver:update` but embedded in `silver:init`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead |
|---------|-------------|-------------|
| GSD version check | Custom npm query logic | Re-use gsd:update approach (`cat VERSION` + `npm view`) |
| SB version check | Custom GitHub API | Re-use silver:update approach (already proven) |
| Plugin update for Superpowers | Custom clone logic | Instruct user: `/plugin install obra/superpowers` (no update skill exists) |
| State reading | Custom STATE.md parser | Simple `cat .planning/STATE.md` + YAML front matter reading |

---

## Common Pitfalls

### Pitfall 1: Editing GSD or Superpowers skill files
**What goes wrong:** Phase 4 options narration or guided UX bleeds into GSD skill files.
**Why it happens:** Requirement 3 (guided UX) could be misread as needing changes inside GSD.
**How to avoid:** All UX guidance changes go into `silver-bullet.md` (SB's orchestration file). GSD skill files are off-limits per §8.

### Pitfall 2: Removing SB state file markers
**What goes wrong:** Thinking REQ-2 means deleting the SB state file or removing quality-gate markers.
**Why it happens:** "delegate state to GSD" sounds like "remove SB state."
**How to avoid:** SB state file legitimately tracks SB-specific markers (quality-gate-stage-N, session mode) that GSD has no equivalent for. The fix is guidance logic: read GSD STATE.md at decision points instead of reading SB state for position information.

### Pitfall 3: Making AskUserQuestion mandatory for all prompts
**What goes wrong:** Over-converting prose narrations to AskUserQuestion, causing every sentence to require a button click.
**Why it happens:** REQ-4 says "whenever options are presented."
**How to avoid:** AskUserQuestion is only for user *choice* points. Narration (step summaries, progress banners) stays as plain text output. Only use AskUserQuestion when the user must pick between alternatives.

### Pitfall 4: Assuming a Superpowers update skill exists
**What goes wrong:** Writing init code that tries to invoke `/superpowers:update`.
**Why it happens:** Analogy with GSD having `/gsd-update`.
**How to avoid:** No such skill was found in the installed skills listing. Use the `/plugin install obra/superpowers` reinstall path, or simply report the installed version and direct the user to the Claude Desktop plugin manager.

### Pitfall 5: Breaking the HARD STOP on missing GSD
**What goes wrong:** Adding update-check logic before the presence check, so init tries to update a non-existent GSD.
**Why it happens:** Logical ordering of "update" vs "check presence."
**How to avoid:** Presence check MUST precede version check. The HARD STOP on missing GSD stays unchanged.

---

## Open Questions

1. **Superpowers/Design/Engineering update mechanism**
   - What we know: no update skill found; install is `/plugin install obra/superpowers`
   - What's unclear: whether the Claude Code plugin manager has an API/command for updating installed plugins without a full reinstall
   - Recommendation: for Phase 9, report installed version and tell user how to update manually (same pattern as SB's "Restart Claude Desktop" message). Document this as a known limitation.

2. **Autonomous commentary format**
   - What we know: §4 says suppress questions in autonomous mode, log decisions
   - What's unclear: exact format for "commentary" — is it a banner per step, inline narration, or a structured log?
   - Recommendation: define a simple format in silver-bullet.md: one-line banner before each major step ("— Now running: execute-phase for Phase 3, Plan 2 of 3 —") and a structured summary at the end.

3. **AskUserQuestion letter limit**
   - What we know: AskUserQuestion renders options as buttons
   - What's unclear: whether long option lists (A through G+) work well in the UI
   - Recommendation: cap lettered options at 6 (A–F) for readability; if more options needed, group them.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | AskUserQuestion option strings must include the letter prefix manually (e.g., "A. Yes") — the API does not auto-add labels | REQ-4 | If API auto-adds labels, our option strings will have double prefixes like "A. A. Yes" |
| A2 | No `/superpowers:update` or `/plugin:update` skill exists | REQ-1 | If it exists, init can invoke it directly rather than directing user to reinstall |
| A3 | GSD version is readable from `~/.claude/get-shit-done/VERSION` | REQ-1 | If file doesn't exist (custom install), version check will fail silently |

---

## Sources

### Primary (HIGH confidence)
- `/Users/shafqat/Documents/Projects/silver-bullet/skills/silver-init/SKILL.md` — full silver:init implementation
- `/Users/shafqat/Documents/Projects/silver-bullet/skills/silver-update/SKILL.md` — update pattern reference
- `/Users/shafqat/Documents/Projects/silver-bullet/skills/silver/SKILL.md` — router and AskUserQuestion usage
- `/Users/shafqat/Documents/Projects/silver-bullet/silver-bullet.md` — full orchestration file, §2 Hand-Holding table, §4 session mode, §6 GSD ownership, §8 third-party boundary
- `/Users/shafqat/.claude/skills/gsd-update/SKILL.md` — GSD update skill pattern (VERSION file + npm view)
- `/Users/shafqat/Documents/Projects/silver-bullet/.planning/STATE.md` — GSD state schema
- `/Users/shafqat/.claude/skills/` listing — confirmed no superpowers:update skill exists

### Secondary (MEDIUM confidence)
- `/Users/shafqat/.claude/get-shit-done/references/questioning.md` — AskUserQuestion usage patterns

---

## Metadata

**Confidence breakdown:**
- REQ-1 (init + update): HIGH — full skill code read; version check patterns confirmed in gsd-update
- REQ-2 (GSD state delegation): HIGH — STATE.md schema verified; SB state file markers catalogued
- REQ-3 (guided UX): HIGH — current Hand-Holding table verified; gaps clearly identified
- REQ-4 (lettered bullets): MEDIUM-HIGH — AskUserQuestion API behavior inferred from usage patterns; letter-prefix approach is assumption A1

**Research date:** 2026-04-08
**Valid until:** 2026-05-08 (stable codebase, not a fast-moving external dependency)
