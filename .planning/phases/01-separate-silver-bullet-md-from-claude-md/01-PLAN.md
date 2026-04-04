---
phase: 01-separate-silver-bullet-md-from-claude-md
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - templates/silver-bullet.md.base
  - templates/CLAUDE.md.base
  - skills/using-silver-bullet/SKILL.md
  - CLAUDE.md
  - silver-bullet.md
  - site/help/reference/index.html
  - site/help/getting-started/index.html
  - site/help/search.js
autonomous: true
requirements: [R1]

must_haves:
  truths:
    - "silver-bullet.md.base template contains all enforcement sections (0-9) from current CLAUDE.md.base"
    - "CLAUDE.md.base template is simplified to project scaffolding with mandatory silver-bullet.md reference"
    - "/using-silver-bullet skill handles fresh setup (writes silver-bullet.md + simplified CLAUDE.md), update mode (overwrites silver-bullet.md only), and conflict detection"
    - "Project's own CLAUDE.md is simplified and silver-bullet.md exists at project root with all SB content"
    - "Help site pages and search index reference silver-bullet.md where appropriate"
  artifacts:
    - path: "templates/silver-bullet.md.base"
      provides: "All Silver Bullet enforcement sections (0-9)"
      contains: "## 0. Session Startup"
    - path: "templates/CLAUDE.md.base"
      provides: "Simplified project scaffold referencing silver-bullet.md"
      contains: "silver-bullet.md"
    - path: "skills/using-silver-bullet/SKILL.md"
      provides: "Updated setup skill with fresh/update/conflict modes"
      contains: "silver-bullet.md"
    - path: "silver-bullet.md"
      provides: "Dogfooded SB enforcement file at project root"
      contains: "## 0. Session Startup"
    - path: "CLAUDE.md"
      provides: "Simplified project CLAUDE.md referencing silver-bullet.md"
      contains: "silver-bullet.md"
  key_links:
    - from: "templates/CLAUDE.md.base"
      to: "silver-bullet.md"
      via: "mandatory reference line"
      pattern: "silver-bullet\\.md"
    - from: "skills/using-silver-bullet/SKILL.md"
      to: "templates/silver-bullet.md.base"
      via: "template read during fresh setup"
      pattern: "silver-bullet\\.md\\.base"
---

<objective>
Separate Silver Bullet enforcement instructions from CLAUDE.md into a dedicated silver-bullet.md file.

Purpose: Allow Silver Bullet to update its own instructions (silver-bullet.md) without touching the user's project-specific CLAUDE.md. Clean ownership boundary: SB owns silver-bullet.md, user owns CLAUDE.md.

Output: New silver-bullet.md.base template, simplified CLAUDE.md.base template, updated /using-silver-bullet skill with fresh/update/conflict modes, dogfooded project files, updated help site.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/ROADMAP.md
@.planning/REQUIREMENTS.md
@.planning/STATE.md
@templates/CLAUDE.md.base
@templates/silver-bullet.config.json.default
@skills/using-silver-bullet/SKILL.md
@CLAUDE.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create silver-bullet.md.base template and simplify CLAUDE.md.base</name>
  <files>templates/silver-bullet.md.base, templates/CLAUDE.md.base</files>
  <action>
1. Create `templates/silver-bullet.md.base` by extracting ALL Silver Bullet sections from the current `templates/CLAUDE.md.base`. The new file must contain:
   - A preamble at the very top:
     ```
     <!-- This file is managed by Silver Bullet. Do not edit manually. -->
     <!-- To update: run /using-silver-bullet in your project. -->
     ```
   - A top-level heading: `# Silver Bullet — Enforcement Instructions for {{PROJECT_NAME}}`
   - The line: `> **Always adhere strictly to this file and CLAUDE.md — they override all defaults.**`
   - Then ALL sections from current CLAUDE.md.base: Section 0 (Session Startup), Section 1 (Automated Enforcement), Section 2 (Active Workflow), Section 3 + 3a (Non-Negotiable Rules + Review Loop), Section 4 (Session Mode), Section 5 (Model Routing), Section 6 (GSD/Superpowers Ownership), Section 7 (File Safety), Section 8 (Third-Party Plugin Boundary), Section 9 (Pre-Release Quality Gate).
   - Keep ALL placeholders: `{{PROJECT_NAME}}`, `{{TECH_STACK}}`, `{{GIT_REPO}}`, `{{ACTIVE_WORKFLOW}}`.

2. Rewrite `templates/CLAUDE.md.base` to contain ONLY:
   ```markdown
   # {{PROJECT_NAME}} — Claude Code Instructions

   > **Always adhere strictly to this file and silver-bullet.md — they override all defaults.**

   ---

   ## Project Overview

   - **Stack**: {{TECH_STACK}}
   - **Git repo**: {{GIT_REPO}}

   ---

   ## Project-Specific Rules

   <!-- Add project-specific Claude instructions here. -->
   <!-- Silver Bullet enforcement lives in silver-bullet.md (do not duplicate here). -->
   ```
   That is the entire file. No SB sections remain.
  </action>
  <verify>
    <automated>grep -c "## 0\. Session Startup" templates/silver-bullet.md.base && grep -c "## 9\. Pre-Release" templates/silver-bullet.md.base && grep -c "silver-bullet.md" templates/CLAUDE.md.base && test $(wc -l < templates/CLAUDE.md.base) -lt 25 && echo "PASS" || echo "FAIL"</automated>
  </verify>
  <done>silver-bullet.md.base contains all 10 sections (0-9). CLAUDE.md.base is under 25 lines with mandatory silver-bullet.md reference. No SB enforcement content remains in CLAUDE.md.base.</done>
</task>

<task type="auto">
  <name>Task 2: Update /using-silver-bullet skill for silver-bullet.md support</name>
  <files>skills/using-silver-bullet/SKILL.md</files>
  <action>
Update `skills/using-silver-bullet/SKILL.md` with these changes. Preserve all existing Phase -1, Phase 0, Phase 1, and Phase 2 logic unchanged. Modify Phase 3 (Scaffold) as follows:

**Fresh setup changes (Phase 3, fresh path):**

1. Replace step 3.1 "Handle existing CLAUDE.md" with:
   - Step 3.1a: Write `silver-bullet.md` from `${PLUGIN_ROOT}/templates/silver-bullet.md.base` (always safe — new file, SB-owned). Perform same placeholder replacements as before (PROJECT_NAME, TECH_STACK, GIT_REPO, ACTIVE_WORKFLOW).
   - Step 3.1b: Check if `CLAUDE.md` exists.
     - If NO existing CLAUDE.md: Write from `${PLUGIN_ROOT}/templates/CLAUDE.md.base` with placeholder replacements. No user interaction needed.
     - If existing CLAUDE.md: Add reference line at the very top of the file (before any other content): `> **Always adhere strictly to this file and silver-bullet.md — they override all defaults.**` — but ONLY if the file does not already contain the string "silver-bullet.md". Then run conflict detection (step 3.1c).
   - Step 3.1c: Conflict detection (only when existing CLAUDE.md found). Scan CLAUDE.md for patterns that conflict with silver-bullet.md rules. Check for these conflict patterns:
     - Model routing overrides: regex `claude-opus|claude-sonnet|model.*routing` (conflicts with SB Section 5)
     - Execution preferences: regex `execute-phase|subagent-driven|executing-plans` (conflicts with SB Section 6)
     - Review loop overrides: regex `review.*loop|approved.*twice|consecutive.*pass` (conflicts with SB Section 3a)
     - Workflow overrides: regex `active.*workflow|workflow.*override` (conflicts with SB Section 2)
     - Session mode overrides: regex `interactive|autonomous.*mode|session.*mode` (conflicts with SB Section 4)
     For each match found, present it to the user interactively:
     ```
     Potential conflict found in CLAUDE.md:
       Line {N}: {matched text}
       This may conflict with Silver Bullet's {section name}.
       Remove this line from CLAUDE.md? (yes / no / skip-all)
     ```
     If user says "yes", use Edit tool to remove the line. If "no", leave it. If "skip-all", stop checking further conflicts.

2. Update step 3.3 "Write CLAUDE.md": This step now only applies when NO existing CLAUDE.md was found (the "write from template" path). The append path is removed — silver-bullet.md replaces the need to append SB sections to CLAUDE.md.

3. Update step 3.7 "Stage and commit": Add `silver-bullet.md` to the git add command alongside CLAUDE.md.

**Update mode changes (Phase 3, update path):**

Replace the update mode section with:
1. Invoke `/using-superpowers` via Skill tool.
2. Overwrite `silver-bullet.md` from `${PLUGIN_ROOT}/templates/silver-bullet.md.base` with placeholder replacements. Read `.silver-bullet.json` first for project.name and other values. This is safe — SB owns this file.
3. Verify CLAUDE.md contains the reference line mentioning "silver-bullet.md". If not, add it at top.
4. Run conflict detection (same as step 3.1c above).
5. Output: "Silver Bullet updated. silver-bullet.md refreshed. All skills active."

**Template refresh section:**
Update the "Template refresh" subsection: instead of updating SB sections within CLAUDE.md, it now overwrites silver-bullet.md (SB-owned, no confirmation needed) and only touches CLAUDE.md to ensure the reference line exists.
  </action>
  <verify>
    <automated>grep -c "silver-bullet.md.base" skills/using-silver-bullet/SKILL.md && grep -c "conflict detection" skills/using-silver-bullet/SKILL.md && grep -c "3.1a" skills/using-silver-bullet/SKILL.md && echo "PASS" || echo "FAIL"</automated>
  </verify>
  <done>SKILL.md has: (1) fresh setup writes silver-bullet.md from template + simplified CLAUDE.md or adds reference line to existing, (2) update mode overwrites silver-bullet.md and verifies CLAUDE.md reference, (3) conflict detection scans CLAUDE.md for 5 conflict pattern categories and presents interactively.</done>
</task>

<task type="auto">
  <name>Task 3: Dogfood — create silver-bullet.md and simplify project CLAUDE.md</name>
  <files>silver-bullet.md, CLAUDE.md</files>
  <action>
1. Create `silver-bullet.md` at project root by copying ALL Silver Bullet enforcement content (sections 0-9) from the current `CLAUDE.md`. Replace the heading with `# Silver Bullet — Enforcement Instructions for silver-bullet`. Add the managed-file preamble comment at top (same as template). Keep all actual section content identical to current CLAUDE.md sections 0-9.

2. Simplify the project's `CLAUDE.md` to contain ONLY:
   - The heading: `# silver-bullet — Claude Code Instructions`
   - The enforcement line: `> **Always adhere strictly to this file and silver-bullet.md — they override all defaults.**`
   - The Project Overview section (Stack: Node.js, Git repo: the repo URL)
   - An empty `## Project-Specific Rules` section with a comment placeholder
   - Nothing else. All SB sections (0-9) are removed since they now live in silver-bullet.md.
  </action>
  <verify>
    <automated>grep -c "## 0\. Session Startup" silver-bullet.md && grep -c "## 9\. Pre-Release" silver-bullet.md && grep -c "silver-bullet.md" CLAUDE.md && test $(grep -c "## [0-9]\." CLAUDE.md) -eq 0 && echo "PASS" || echo "FAIL"</automated>
  </verify>
  <done>silver-bullet.md exists at project root with all 10 SB sections. CLAUDE.md is simplified with no SB sections, only project overview and silver-bullet.md reference.</done>
</task>

<task type="auto">
  <name>Task 4: Update help site — reference, getting-started, search index</name>
  <files>site/help/reference/index.html, site/help/getting-started/index.html, site/help/search.js</files>
  <action>
1. **site/help/reference/index.html**: In the "File Structure" or "Standard project file structure" section, add `silver-bullet.md` to the file listing (alongside CLAUDE.md and .silver-bullet.json). Add a brief description: "Silver Bullet enforcement instructions (managed by plugin, do not edit manually)". Update any text that says Silver Bullet writes to CLAUDE.md to say it writes to silver-bullet.md instead.

2. **site/help/getting-started/index.html**: In the "Installing Silver Bullet" section (step 3 of the /using-silver-bullet output list), change "Create CLAUDE.md with the active workflow configuration" to "Create silver-bullet.md with enforcement rules and CLAUDE.md with project config". In the "Existing Codebase" card, update the text: instead of "Choose Append when asked about your existing CLAUDE.md to preserve your current instructions", say "Silver Bullet creates silver-bullet.md for its rules and adds a reference line to your existing CLAUDE.md — your instructions are preserved automatically."

3. **site/help/search.js**: Update the IDX entries:
   - In the "Installing Silver Bullet" entry (anchor: install), update text to mention silver-bullet.md alongside CLAUDE.md.
   - In the "file-structure" entry (anchor: file-structure), add silver-bullet.md to the file list text.
   - In the "New project vs existing codebase" entry (anchor: first-project), update text to reflect silver-bullet.md approach instead of "Append for existing CLAUDE.md".
   - In the config entry (anchor: config), mention silver-bullet.md as SB-managed file.
   - Add a new entry:
     ```javascript
     { page:'Reference', url:'/help/reference/', anchor:'file-structure',
       title:'silver-bullet.md — enforcement instructions file',
       text:'silver-bullet.md is managed by Silver Bullet plugin. Contains all enforcement sections 0-9: session startup, automated enforcement, active workflow, non-negotiable rules, session mode, model routing, ownership rules, file safety, third-party boundary, pre-release gate. Updated by /using-silver-bullet. Do not edit manually.' }
     ```
  </action>
  <verify>
    <automated>grep -c "silver-bullet.md" site/help/reference/index.html && grep -c "silver-bullet.md" site/help/getting-started/index.html && grep -c "silver-bullet.md" site/help/search.js && echo "PASS" || echo "FAIL"</automated>
  </verify>
  <done>All three help site files reference silver-bullet.md. Reference page lists it in file structure. Getting-started reflects new setup flow. Search index has updated entries and a new silver-bullet.md entry.</done>
</task>

</tasks>

<verification>
1. `templates/silver-bullet.md.base` contains sections 0-9, all placeholders intact
2. `templates/CLAUDE.md.base` is minimal (under 25 lines), references silver-bullet.md
3. `skills/using-silver-bullet/SKILL.md` handles fresh setup, update mode, and conflict detection
4. `silver-bullet.md` exists at project root with all SB enforcement content
5. `CLAUDE.md` at project root has no SB sections, references silver-bullet.md
6. Help site pages mention silver-bullet.md appropriately
</verification>

<success_criteria>
- Silver Bullet enforcement content lives exclusively in silver-bullet.md (template and project root)
- CLAUDE.md is a user-owned file with only project-specific content and a silver-bullet.md reference
- /using-silver-bullet skill creates silver-bullet.md on fresh setup, overwrites it on update, and detects conflicts in CLAUDE.md
- The project itself dogfoods the new structure
- Help site accurately reflects the new file layout
</success_criteria>

<output>
After completion, create `.planning/phases/01-separate-silver-bullet-md-from-claude-md/01-01-SUMMARY.md`
</output>
