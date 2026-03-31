---
name: using-silver-bullet
description: Initialize Silver Bullet enforcement for a project — checks dependencies, auto-detects project, scaffolds CLAUDE.md + config + workflow files
---

# /using-silver-bullet — Project Setup

This skill initializes Silver Bullet enforcement for a project. Follow each phase in order. Do NOT skip phases unless explicitly instructed below.

**Plugin root**: Determine `PLUGIN_ROOT` from this skill file's own path. This file lives at `${PLUGIN_ROOT}/skills/using-silver-bullet/SKILL.md`, so the plugin root is two directories up from this file's location.

---

## Phase −1: Session Init

Run this phase exactly once per session. Skip if the session state file `/tmp/.silver-bullet-session-init` already exists.

```bash
test -f /tmp/.silver-bullet-session-init && echo "ALREADY_DONE" || echo "NEEDED"
```

If `ALREADY_DONE` → skip to Phase 0.

If `NEEDED`:

### −1.1 Load project context

Use the Read tool to read each of the following files **if they exist** (check with Bash `test -f` first):

1. `README.md` — project overview and usage
2. `CONTEXT.md` — project-specific context
3. `CLAUDE.md` — Claude-specific instructions and active workflow

### −1.2 Load docs

Check if a `docs/` directory exists:
```bash
test -d docs && echo "EXISTS" || echo "NONE"
```

If it exists, use the Glob tool to find all markdown files:
```
docs/**/*.md
```

Read each file found using the Read tool.

### −1.3 Compact context

Use the Bash tool to run:
```bash
touch /tmp/.silver-bullet-session-init
```

Then invoke `/compact` via the Skill tool to compact the loaded context before proceeding.

---

## Phase 0: Update Check

1. Use the Bash tool to check if `.silver-bullet.json` exists in the current project root:
   ```
   test -f .silver-bullet.json && echo "EXISTS" || echo "NOT_FOUND"
   ```
2. If `EXISTS` → this is a **re-run/update**. Skip Phase 1 and Phase 2. Go directly to Phase 3 in **update mode**.
3. If `NOT_FOUND` → this is a **fresh setup**. Proceed to Phase 1.

---

## Phase 1: Dependency Check

Check each dependency in order. If any check fails, print the error message and **STOP immediately** — do not continue to the next check.

### 1.1 jq

Run via Bash tool:
```
command -v jq
```
If the command fails (exit code non-zero), output exactly:
> ❌ Silver Bullet requires jq. Install: `brew install jq` (macOS) / `apt install jq` (Linux)

STOP. Do not proceed.

### 1.2 Superpowers plugin

Use the Glob tool to search for:
```
~/.claude/plugins/cache/*/superpowers/*/skills/brainstorming/SKILL.md
```
Expand `~` to the user's home directory (use `$HOME` via Bash if needed).

If no files found, output exactly:
> ❌ Superpowers plugin not found. Install: `/plugin install obra/superpowers`

STOP. Do not proceed.

### 1.3 Engineering plugin

Use the Glob tool to search for Engineering plugin skills in these paths:
- `~/.claude/plugins/cache/*/engineering/*/skills/documentation/SKILL.md`
- `~/.claude/plugins/cache/*/knowledge-work-plugins/*/engineering/skills/documentation/SKILL.md`

Expand `~` to the user's home directory.

If no files found in any of those patterns, try invoking `/engineering:documentation` via the Skill tool as a fallback check. If that also fails, output exactly:
> ❌ Engineering plugin not found. Install: `/plugin install anthropics/knowledge-work-plugins/tree/main/engineering`

STOP. Do not proceed.

### 1.4 v1 incompatibility check

Use the Read tool to read `.claude/settings.json` in the project root. If the file does not exist, skip this check.

If the file exists, inspect its contents for any references to:
- `record-skill.sh`
- `dev-cycle-check.sh`
- `/tmp/.wyzr-workflow-state`

If any of these strings are found, output:
> ⚠️ Incompatible v1 Silver Bullet hooks detected in `.claude/settings.json`.
> Found references to: [list the matched strings]
>
> These must be removed before Silver Bullet v2 can be installed.
> Remove these entries? (yes / no)

Wait for user confirmation. If "yes", use the Edit tool to remove the offending hook entries from `.claude/settings.json`. If "no", STOP.

---

## Phase 2: Auto-Detect Project

Gather project metadata automatically, then confirm with the user.

### 2.1 Detect project name

1. Use the Read tool to check for these files in the project root (in order): `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `pom.xml`, `build.gradle`.
2. Extract the project name from whichever file exists first:
   - `package.json` → the `"name"` field
   - `pyproject.toml` → `[project] name` or `[tool.poetry] name`
   - `Cargo.toml` → `[package] name`
   - `go.mod` → module path (last segment)
   - `pom.xml` → `<artifactId>`
   - `build.gradle` → `rootProject.name` if present
3. If none of these files exist, use the current directory name as the project name. Run via Bash:
   ```
   basename "$PWD"
   ```

### 2.2 Detect tech stack

Based on which manifest file was found, set the tech stack string:
- `package.json` → Read it and check for key dependencies (e.g., "react", "next", "express", "vue", "angular", "typescript"). Compose a string like "Node.js / TypeScript / React" based on what is found.
- `pyproject.toml` → "Python" plus key dependencies (Django, Flask, FastAPI, etc.)
- `Cargo.toml` → "Rust" plus key dependencies
- `go.mod` → "Go" plus key dependencies
- `pom.xml` → "Java / Maven"
- `build.gradle` → "Java / Gradle" or "Kotlin / Gradle"
- If none found → "Unknown — please specify"

### 2.3 Detect repo URL

Run via Bash tool:
```
git remote get-url origin 2>/dev/null || echo "NONE"
```

### 2.4 Detect source pattern

Use the Bash tool to check which source directories exist:
```
ls -d src/ app/ lib/ 2>/dev/null | head -1
```
- If `src/` exists → source pattern is `/src/`
- If `app/` exists → source pattern is `/app/`
- If `lib/` exists → source pattern is `/lib/`
- If none exist → default to `/src/`

### 2.5 Confirm with user

Present the detected values to the user:

```
Detected:
  Project:  [name]
  Stack:    [stack]
  Repo:     [repo]
  Source:   [pattern]

Look right? (yes / edit)
```

- If user says "yes" or equivalent → proceed to Phase 3.
- If user says "edit" → ask which fields to change, accept new values, then proceed to Phase 3.

---

## Phase 3: Scaffold

### Update mode (`.silver-bullet.json` already exists)

If Phase 0 determined this is an update:

1. Ask the user:
   > Silver Bullet already configured. Refresh templates from plugin? (Your `.silver-bullet.json` customizations will be preserved.)
2. If user says "no" → output "No changes made." and exit.
3. If user says "yes":
   a. Read `.silver-bullet.json` to get the current `project.name` and `project.src_pattern` values.
   b. Read the template `${PLUGIN_ROOT}/templates/CLAUDE.md.base` using the Read tool. Replace `{{PROJECT_NAME}}` with the project name from config, replace `{{TECH_STACK}}` and `{{GIT_REPO}}` with values from config or re-detect them using Phase 2 steps.
   c. Write the rendered `CLAUDE.md` to the project root using the Write tool.
   d. Read `${PLUGIN_ROOT}/templates/workflows/full-dev-cycle.md` and write it to `docs/workflows/full-dev-cycle.md`.
   e. Output: "Templates refreshed. Config preserved."
   f. Exit. Do NOT re-run the commit or `/using-superpowers` steps.

### Fresh setup

If this is a fresh setup:

#### 3.1 Handle existing CLAUDE.md

Check if `CLAUDE.md` exists in the project root (use Bash: `test -f CLAUDE.md`).

If it exists, ask the user:
> Existing CLAUDE.md found. Choose one:
> 1. **Replace** — overwrite with Silver Bullet template (your content will be lost)
> 2. **Append** — keep your CLAUDE.md and append only the Active Workflow section
>
> Which? (replace / append)

Remember the user's choice for step 3.3.

#### 3.2 Create directories

Run via Bash tool:
```
mkdir -p docs/specs docs/workflows
```

#### 3.3 Write CLAUDE.md

Read the template file at `${PLUGIN_ROOT}/templates/CLAUDE.md.base` using the Read tool.

Perform these replacements in the template content:
- `{{PROJECT_NAME}}` → the detected/confirmed project name
- `{{TECH_STACK}}` → the detected/confirmed tech stack
- `{{GIT_REPO}}` → the detected/confirmed repo URL

If user chose **replace** (or no existing CLAUDE.md exists):
- Write the fully rendered template to `CLAUDE.md` in the project root using the Write tool.

If user chose **append**:
- Extract only the "## 2. Active Workflow" section from the rendered template.
- Use the Edit tool or Write tool to append this section to the end of the existing `CLAUDE.md`, preceded by a blank line separator.

#### 3.4 Write config

Read the template file at `${PLUGIN_ROOT}/templates/silver-bullet.config.json.default` using the Read tool.

Perform these replacements:
- `{{PROJECT_NAME}}` → the detected/confirmed project name

Also set `src_pattern` to the detected/confirmed source pattern (replacing the default `/src/` if different).

Write the result to `.silver-bullet.json` in the project root using the Write tool.

#### 3.5 Copy workflow file

Read `${PLUGIN_ROOT}/templates/workflows/full-dev-cycle.md` using the Read tool.

Write the contents to `docs/workflows/full-dev-cycle.md` using the Write tool.

#### 3.6 Create placeholder docs

Create the following files in `docs/` using the Write tool. Each file should contain only a title and a TODO body:

**`docs/Master-PRD.md`**:
```markdown
# Master PRD

TODO — Add product requirements here.
```

**`docs/Architecture-and-Design.md`**:
```markdown
# Architecture and Design

TODO — Document architecture decisions and system design here.
```

**`docs/Testing-Strategy-and-Plan.md`**:
```markdown
# Testing Strategy and Plan

TODO — Define testing strategy, coverage goals, and test plan here.
```

**`docs/CICD.md`**:
```markdown
# CI/CD

TODO — Document CI/CD pipeline configuration and deployment process here.
```

#### 3.7 Stage and commit

Run via Bash tool:
```bash
git add CLAUDE.md .silver-bullet.json docs/
git commit -m "$(cat <<'EOF'
feat: initialize Silver Bullet enforcement

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

If the commit fails due to a pre-commit hook, read the error output, fix the issue, re-stage, and create a new commit (do NOT use `--amend`).

#### 3.8 Activate Superpowers

Invoke `/using-superpowers` via the Skill tool to establish available skills for the session.

#### 3.9 Done

Output:
> Silver Bullet initialized. Start any task and the active workflow will be enforced automatically.
