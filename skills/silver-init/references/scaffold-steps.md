# Phase 3: Scaffold — Detailed Steps

This reference expands the steps summarized in `SKILL.md` Phase 3. Follow the sub-steps in order. The top-level phase gating (update vs. fresh setup) is decided in SKILL.md; this file contains only the detailed execution.

---

## Update mode (`.silver-bullet.json` already exists)

If Phase 0 determined this is an update:

1. Invoke `superpowers:using-superpowers` via the Skill tool to activate Superpowers skills.
2. Overwrite `silver-bullet.md` from `${PLUGIN_ROOT}/templates/silver-bullet.md.base` with placeholder replacements. Read `.silver-bullet.json` first for `project.name` and other values. This is safe — Silver Bullet owns this file.
   - Replace `{{PROJECT_NAME}}` with the project name from `.silver-bullet.json`
   - Replace `{{ACTIVE_WORKFLOW}}` with the active workflow name from `.silver-bullet.json` (default: `full-dev-cycle`)
3. **Strip any SB-owned sections from CLAUDE.md** (migration from pre-v0.7.0). Check for headings matching `## N. <Known SB Title>` where N is 0–9 (titles: Session Startup, Automated Enforcement, Active Workflow, NON-NEGOTIABLE, Review Loop, Session Mode, Model Routing, GSD, File Safety, Third-Party, Pre-Release). If found, remove these sections (from heading to next `## ` or EOF), preserving all non-SB content. Also remove old-style reference lines that don't mention silver-bullet.md.
4. Verify `CLAUDE.md` contains a reference line mentioning "silver-bullet.md". If not, add at the very top of the file: `> **Always adhere strictly to this file and silver-bullet.md — they override all defaults.**`
5. Run conflict detection (same as step 3.1c below).
5a. Run step 3.7.5 to re-register or refresh SB hooks in `~/.claude/settings.json`.
6. Output: "Silver Bullet updated. silver-bullet.md refreshed. All skills active."

### Template refresh (only when user explicitly requests it)

If the user asks to refresh templates:
1. List the files that would be updated and what each change achieves, e.g.:
   > I'll update these files from the plugin templates:
   > - `silver-bullet.md` — refresh Silver Bullet enforcement rules (SB-owned, safe to overwrite)
   > - `docs/workflows/full-dev-cycle.md` — pull latest workflow steps
   > Proceed? (yes / no)
2. Only proceed on explicit "yes".
3. Overwrite `silver-bullet.md` from `${PLUGIN_ROOT}/templates/silver-bullet.md.base` with placeholder replacements (SB-owned, no confirmation needed).
4. Verify `CLAUDE.md` contains the reference line mentioning "silver-bullet.md". If not, add it at top.
5. **Backup before any overwrite of workflow files**: copy the original to `<file>.backup` first.
6. Read `.silver-bullet.json` to carry forward `project.name`, `project.src_pattern` customizations.
7. Output: "Templates refreshed. silver-bullet.md updated. Backups created at: [list]". Exit.

---

## Fresh setup

### 3.1a Write silver-bullet.md

Write `silver-bullet.md` from `${PLUGIN_ROOT}/templates/silver-bullet.md.base`. This is always safe — it's a new file owned by Silver Bullet.

Perform these placeholder replacements:
- `{{PROJECT_NAME}}` → the detected/confirmed project name
- `{{ACTIVE_WORKFLOW}}` → `full-dev-cycle` (default)

### 3.1b Handle CLAUDE.md

Check if `CLAUDE.md` exists in the project root (use Bash: `test -f CLAUDE.md`).

**If NO existing CLAUDE.md**: Write from `${PLUGIN_ROOT}/templates/CLAUDE.md.base` with placeholder replacements (`{{PROJECT_NAME}}`, `{{TECH_STACK}}`, `{{GIT_REPO}}`). No user interaction needed.

**If existing CLAUDE.md**: First, strip any existing Silver Bullet sections (migration from pre-v0.7.0). Then add the reference line and run conflict detection.

**Step 1 — Strip SB-owned sections from CLAUDE.md:**

Silver Bullet sections are identified by headings matching `## N. <Known SB Title>` where N is 0–9 (including `## 3a.`). Known titles include: Session Startup, Automated Enforcement, Active Workflow, NON-NEGOTIABLE, Review Loop, Session Mode, Model Routing, GSD, File Safety, Third-Party, Pre-Release. These sections start at the heading and end just before the next `## ` heading or end-of-file.

Use the Bash tool to detect SB sections:
```bash
grep -nE '^## [0-9]+[a-z]?\. (Session Startup|Automated Enforcement|Active Workflow|NON-NEGOTIABLE|Review Loop|Session Mode|Model Routing|GSD|File Safety|Third-Party|Pre-Release)' CLAUDE.md || echo "NO_SB_SECTIONS"
```

If `NO_SB_SECTIONS` → skip to Step 2.

If sections found:
1. Read CLAUDE.md fully
2. Identify each SB section (from `## N.` heading to just before the next `## ` heading or EOF)
3. Also remove the old-style enforcement reference line if present: `> **Always adhere strictly to this file — it overrides all defaults.**` (note: this is the pre-separation version that does NOT mention silver-bullet.md)
4. Remove these sections using the Edit tool, preserving all non-SB content (project overview, project-specific rules, user-added sections)
5. Clean up any resulting double-blank-lines to single-blank-lines

**Step 2 — Add reference line:**

Add at the very top of the file (before any other content):
```
> **Always adhere strictly to this file and silver-bullet.md — they override all defaults.**
```
But ONLY if the file does not already contain the string "silver-bullet.md".

Then run conflict detection (step 3.1c).

### 3.1c Conflict detection (only when existing CLAUDE.md found)

Scan `CLAUDE.md` for patterns that conflict with `silver-bullet.md` rules. Check for these conflict patterns:

1. **Model routing overrides**: regex `(always|default|prefer|use).*(claude-opus|claude-sonnet|opus|sonnet)` on directive-like lines (conflicts with SB Section 5)
2. **Execution preferences**: regex `(always|never|must).*(subagent-driven|executing-plans)` on directive-like lines (conflicts with SB Section 6)
3. **Review loop overrides**: regex `(skip|disable|no).*(review.*loop|code.review)|approved.*(once|single)` on directive-like lines (conflicts with SB Section 3a)
4. **Workflow overrides**: regex `(override|replace|ignore).*(workflow|silver.bullet)` on directive-like lines (conflicts with SB Section 2)
5. **Session mode overrides**: regex `(always|default|must).*(interactive|autonomous).*mode` on directive-like lines (conflicts with SB Section 4)

For each match found, present it to the user interactively using AskUserQuestion:
- Question: "Potential conflict found in CLAUDE.md:\n  Line {N}: {matched text}\n  This may conflict with Silver Bullet's {section name}. Remove this line?"
- Options:
  - "A. Yes, remove this line"
  - "B. No, keep it"
  - "C. Skip all remaining conflict checks"

If user selects A, use Edit tool to remove the line. If user selects B, leave it. If user selects C, stop checking further conflicts.

### 3.2 Create directories

```bash
mkdir -p docs/specs docs/workflows
```

### 3.2.5 CI setup

Check if a GitHub Actions CI workflow exists:
```bash
test -d .github/workflows && ls .github/workflows/*.yml 2>/dev/null | head -1
```

If no CI workflow exists, create `.github/workflows/` and generate `ci.yml` based on the detected stack from Phase 2. Select the matching template from `references/ci-templates.md` and write it to `.github/workflows/ci.yml`. For unknown stacks, prompt user to specify verify commands and store under `"verify_commands"` in `.silver-bullet.json`.

### 3.3 Write CLAUDE.md (only when no existing CLAUDE.md)

Applies only when NO existing `CLAUDE.md` was found in step 3.1b. If an existing `CLAUDE.md` was found, it was already handled in 3.1b and 3.1c — skip this step.

Read `${PLUGIN_ROOT}/templates/CLAUDE.md.base`, perform replacements, write to `CLAUDE.md`:
- `{{PROJECT_NAME}}` → the detected/confirmed project name
- `{{TECH_STACK}}` → the detected/confirmed tech stack
- `{{GIT_REPO}}` → the detected/confirmed repo URL

### 3.4 Write config

Read `${PLUGIN_ROOT}/templates/silver-bullet.config.json.default`, replace `{{PROJECT_NAME}}`, set `src_pattern` to the detected value (replacing default `/src/` if different), and write to `.silver-bullet.json`.

### 3.5 Copy workflow files

Copy both workflow templates to `docs/workflows/`, backing up any existing file first:

1. `${PLUGIN_ROOT}/templates/workflows/full-dev-cycle.md` → `docs/workflows/full-dev-cycle.md` (back up existing to `.backup`)
2. `${PLUGIN_ROOT}/templates/workflows/devops-cycle.md` → `docs/workflows/devops-cycle.md` (back up existing to `.backup`)

### 3.5.5 Documentation migration (existing projects only)

**Skip this step** if the project has no existing `docs/` directory.

If `docs/` exists, scan for documentation that can be migrated. The migration is **100% transparent** — every action requires explicit user approval; originals are preserved as `.pre-sb-backup`.

Full migration procedure is in `references/doc-migration.md` — scan commands, mapping table, KNOWLEDGE.md split logic, approval flow, summary output.

If no migration candidates found: output `✓ No documentation migration needed` and skip to 3.6.

**Step C — Present migration plan:** use AskUserQuestion with a numbered list of proposed actions (renames, splits). Options: "A. Proceed step by step", "B. Show details first", "C. Skip".

**Step D — Execute migration one step at a time:**
- Renames: `cp original original.pre-sb-backup` → `mv old new` → confirm via AskUserQuestion.
- KNOWLEDGE.md split: back up, read, partition into project-scoped intelligence (`docs/knowledge/YYYY-MM.md`) and portable lessons (`docs/lessons/YYYY-MM.md`), preview the split via AskUserQuestion, write based on user's choice, ensure `docs/knowledge/INDEX.md` exists.
- Unrecognized files: leave in place; mention them in summary.

**Step E — Summary:** list Migrated / Backups / Untouched and note that `.pre-sb-backup` files can be deleted after verification.

### 3.6 Create placeholder docs (NON-DESTRUCTIVE)

**CRITICAL: Do NOT overwrite existing files.** For each file below, check `test -f <path>` first. Only create if absent.

Placeholder files (title + TODO body only):
- `docs/PRD-Overview.md` — Product vision, core value, requirement areas, out of scope.
- `docs/ARCHITECTURE.md` — System overview, core components, design principles, technology choices.
- `docs/TESTING.md` — Testing strategy and plan.
- `docs/CICD.md` — CI/CD pipeline configuration.

Templated files (read base template, substitute placeholders, write only if absent):
- `docs/knowledge/INDEX.md` ← `${PLUGIN_ROOT}/templates/knowledge/INDEX.md.base` (replace `{{GIT_REPO}}`)
- `docs/knowledge/YYYY-MM.md` ← `${PLUGIN_ROOT}/templates/knowledge/YYYY-MM.md.base` (replace `{{PROJECT_NAME}}`, `{{YYYY-MM}}` with current year-month)
- `docs/lessons/YYYY-MM.md` ← `${PLUGIN_ROOT}/templates/lessons/YYYY-MM.md.base` (replace `{{YYYY-MM}}`)
- `docs/doc-scheme.md` ← `${PLUGIN_ROOT}/templates/doc-scheme.md.base`
- `docs/CHANGELOG.md` ← `${PLUGIN_ROOT}/templates/CHANGELOG-project.md.base` (task log; distinct from any root-level CHANGELOG.md)

Sessions dir:
```bash
mkdir -p docs/sessions && touch docs/sessions/.gitkeep
```

### 3.7 Stage and commit

```bash
git add silver-bullet.md CLAUDE.md .silver-bullet.json docs/
git commit -m "$(cat <<'EOF'
feat: initialize Silver Bullet enforcement

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

If the commit fails due to a pre-commit hook, read the error, fix the issue, re-stage, and create a new commit (do NOT use `--amend`).

### 3.7.5 Register SB hooks in ~/.claude/settings.json

Merges the SB hook entries from `hooks/hooks.json` into the user's global `~/.claude/settings.json` so hooks remain active in projects installed without the marketplace (e.g. manual installs, workspace clones).

**Resolve the plugin install path:**

```bash
INSTALL_PATH=$(python3 -c "
import json, os, sys
reg = os.path.expanduser('~/.claude/plugins/installed_plugins.json')
with open(reg) as f:
    data = json.load(f)
plugins = data.get('plugins', {})
for key, entries in plugins.items():
    if 'silver-bullet' in key:
        path = entries[0].get('installPath', '')
        if path:
            print(path)
            sys.exit(0)
sys.exit(1)
" 2>/dev/null)
echo "SB install path: ${INSTALL_PATH:-NOT FOUND}"
```

If `INSTALL_PATH` is empty, skip this step silently and continue.

**Merge hooks idempotently:**

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/skills/silver-init/scripts/merge-hooks.py" "$INSTALL_PATH"
```

`scripts/merge-hooks.py` substitutes `${CLAUDE_PLUGIN_ROOT}` with the actual install path and appends only new hook entries — never duplicates. On nonzero exit, warn but do NOT stop init:
> ⚠️  Could not auto-register hooks in ~/.claude/settings.json. Run `/silver:init` again after installation completes, or add hooks manually from `hooks/hooks.json`.

Idempotent — re-running `/silver:init` adds no duplicate entries.

### 3.8 Activate plugins

Invoke `superpowers:using-superpowers` via the Skill tool. GSD commands (`/gsd:*`) and Design plugin skills (`/design:*`) are available immediately — no activation needed.

### 3.9 Done

Output:
> Silver Bullet initialized. Start any task and the active workflow will be enforced automatically.
