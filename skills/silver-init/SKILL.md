---
name: silver:init
description: Initialize Silver Bullet enforcement for a project — checks dependencies, auto-detects project, scaffolds silver-bullet.md + CLAUDE.md + config + workflow files
---

# /silver:init — Project Setup

This skill initializes Silver Bullet enforcement for a project. Follow each phase in order. Do NOT skip phases unless explicitly instructed below.

## Non-Destructive Guarantee

**This skill MUST NOT destroy existing project content.** Rules:
- **Never overwrite existing docs** (`docs/*.md`) — only create if absent
- **Backup before overwrite** — if CLAUDE.md or workflow files must be replaced (update mode), copy the original to `*.backup` first
- **Never delete files or directories** in the project (only `~/.claude/.silver-bullet/` state files are deleted)
- **Never run `git clean`, `git checkout --`, `git reset --hard`**, or any command that discards uncommitted work
- **Config is preserved** — in update mode, `.silver-bullet.json` customizations are read first and carried forward

**Plugin root**: Determine `PLUGIN_ROOT` from this skill file's own path. This file lives at `${PLUGIN_ROOT}/skills/silver-init/SKILL.md`, so the plugin root is two directories up from this file's location.

---

## Phase −1: Session Init

Run this phase exactly once per session. Skip if the session state file `~/.claude/.silver-bullet/session-init` already exists.

```bash
test -f ~/.claude/.silver-bullet/session-init && echo "ALREADY_DONE" || echo "NEEDED"
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
touch ~/.claude/.silver-bullet/session-init
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

### 1.3 Design plugin

Use the Glob tool to search for Design plugin skills in these paths:
- `~/.claude/plugins/cache/*/design/*/skills/design-system/SKILL.md`
- `~/.claude/plugins/cache/*/knowledge-work-plugins/*/design/skills/design-system/SKILL.md`

Expand `~` to the user's home directory.

If no files found in any of those patterns, try invoking `/design:design-system` via the Skill tool as a fallback check. If that also fails, output exactly:
> ❌ Design plugin not found. Install: `/plugin install anthropics/knowledge-work-plugins/tree/main/design`

STOP. Do not proceed.

### 1.4 Engineering plugin

Use the Glob tool to search for Engineering plugin skills in these paths:
- `~/.claude/plugins/cache/*/engineering/*/skills/documentation/SKILL.md`
- `~/.claude/plugins/cache/*/knowledge-work-plugins/*/engineering/skills/documentation/SKILL.md`

Expand `~` to the user's home directory.

If no files found in any of those patterns, try invoking `/engineering:documentation` via the Skill tool as a fallback check. If that also fails, output exactly:
> ❌ Engineering plugin not found. Install: `/plugin install anthropics/knowledge-work-plugins/tree/main/engineering`

STOP. Do not proceed.

### 1.5 GSD plugin

Use the Bash tool to check if GSD commands are installed:
```bash
test -f "$HOME/.claude/commands/gsd/new-project.md" && echo "EXISTS" || echo "NOT_FOUND"
```

If `NOT_FOUND`, output exactly:
> ❌ GSD plugin not found. Install: `npx get-shit-done-cc@latest`
>
> Silver Bullet requires GSD. Install it, then re-run `/silver:init`.

**HARD STOP. Do NOT proceed under any circumstances.** Do NOT offer to install GSD yourself. Do NOT continue even if the user asks. The user must install GSD manually and re-run this skill.

### 1.6 v1 incompatibility check

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

### 2.0 Git repo check

Run via Bash tool:
```bash
git rev-parse --is-inside-work-tree 2>/dev/null && echo "GIT_REPO" || echo "NOT_GIT"
```

If `GIT_REPO` → continue to step 2.1.

If `NOT_GIT`, ask the user:
> This directory is not a git repository. Choose one:
> 1. **Clone** — provide an existing repo URL to clone here
> 2. **Create** — provide a GitHub org/repo name (e.g., `myorg/myrepo`) to create a new repo
>
> Which? (clone / create)

**If clone:**
- Ask: "Repo URL?"
- Run: `git clone <url> . 2>&1`
- If it fails, show the error and STOP.

**If create:**
- Ask: "GitHub org/repo name (e.g., `myorg/myrepo`)?"
- Run via Bash:
  ```bash
  git init && gh repo create <org/repo> --source=. --remote=origin --push 2>&1
  ```
- If `gh` is not found, output:
  > ❌ GitHub CLI (gh) is required to create a repo. Install: `brew install gh` (macOS) / see https://cli.github.com
  > Then re-run `/silver:init`.
  STOP.
- If the command fails for any other reason, show the error and STOP.

After either clone or create succeeds, continue to step 2.1.

### 2.1 Detect project name

1. Use the Read tool to check for these files in the project root (in order):
   `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `pom.xml`, `build.gradle`,
   `build.gradle.kts`, `Gemfile`, `composer.json`, `mix.exs`, `Package.swift`,
   `*.csproj`, `*.sln`, `pubspec.yaml`.
2. Extract the project name from whichever file exists first:
   - `package.json` → the `"name"` field
   - `pyproject.toml` → `[project] name` or `[tool.poetry] name`
   - `Cargo.toml` → `[package] name`
   - `go.mod` → module path (last segment)
   - `pom.xml` → `<artifactId>`
   - `build.gradle` / `build.gradle.kts` → `rootProject.name` if present
   - `Gemfile` → directory name (Ruby projects rarely name themselves in Gemfile)
   - `composer.json` → the `"name"` field (last segment after `/`)
   - `mix.exs` → `app:` value in `project/0`
   - `Package.swift` → directory name
   - `*.csproj` / `*.sln` → filename without extension
   - `pubspec.yaml` → `name:` field
3. If none of these files exist, use the current directory name as the project name. Run via Bash:
   ```
   basename "$PWD"
   ```

### 2.2 Detect tech stack

Based on which manifest file was found, set the tech stack string:
- `package.json` → Read it and check for key dependencies (e.g., "react", "next", "express", "vue", "angular", "typescript", "bun", "deno"). Compose a string like "Node.js / TypeScript / React" based on what is found.
- `pyproject.toml` → "Python" plus key dependencies (Django, Flask, FastAPI, etc.)
- `Cargo.toml` → "Rust" plus key dependencies (axum, tokio, actix-web, etc.)
- `go.mod` → "Go" plus key dependencies (gin, echo, fiber, etc.)
- `pom.xml` → "Java / Maven" plus key deps (Spring Boot, Quarkus, etc.)
- `build.gradle` → "Java / Gradle" or "Kotlin / Gradle" (check for `kotlin` plugin)
- `build.gradle.kts` → "Kotlin / Gradle" plus key deps (Ktor, Spring, etc.)
- `Gemfile` → "Ruby" plus key gems (Rails, Sinatra, Roda, etc.)
- `composer.json` → "PHP" plus key packages (Laravel, Symfony, WordPress, etc.)
- `mix.exs` → "Elixir" plus key deps (Phoenix, Ecto, etc.)
- `Package.swift` → "Swift" plus key deps
- `*.csproj` / `*.sln` → ".NET / C#" plus target framework (net8.0, net9.0, etc.)
- `pubspec.yaml` → "Dart / Flutter"
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

- If user says "yes" or equivalent → proceed to step 2.6.
- If user says "edit" → ask which fields to change, accept new values, then proceed to step 2.6.

### 2.6 Configure permission mode

Check if `.claude/settings.local.json` has a `permissions.defaultMode` set:
```bash
test -f .claude/settings.local.json && jq -r '.permissions.defaultMode // "NOT_SET"' .claude/settings.local.json 2>/dev/null || echo "NOT_SET"
```

If `NOT_SET`:
> Silver Bullet works best with auto-approve permissions. Choose:
> 1. **auto** (recommended) — auto-approves most tool calls, prompts only for protected paths
> 2. **bypassPermissions** — approves everything, only for isolated environments
> 3. **Skip** — keep current permission settings

If user chooses `bypassPermissions`:
> ⚠️ **Security confirmation required.** `bypassPermissions` disables all Claude Code permission guardrails permanently for this project.
> Is this environment **fully isolated** (container, VM, or dedicated CI runner with no access to production systems, credentials, or sensitive files)?
>
> Reply **yes** to confirm isolation and proceed, or **no** to use `auto` instead.

Only proceed to write `bypassPermissions` on explicit "yes" confirmation. If the user says "no" or is uncertain, set `auto` instead.

If user chooses `auto` or confirmed `bypassPermissions`:
- Read `.claude/settings.local.json` (create if absent with `{"permissions":{}}`)
- Use Edit/Write to set `permissions.defaultMode` to the chosen value
- This persists across sessions — no more repeated permission prompts

If already set to `auto` or `bypassPermissions` → skip silently.

---

## Phase 3: Scaffold

### Update mode (`.silver-bullet.json` already exists)

If Phase 0 determined this is an update:

1. Invoke `/using-superpowers` via the Skill tool to activate Superpowers skills.
2. Overwrite `silver-bullet.md` from `${PLUGIN_ROOT}/templates/silver-bullet.md.base` with placeholder replacements. Read `.silver-bullet.json` first for `project.name` and other values. This is safe — Silver Bullet owns this file.
   - Replace `{{PROJECT_NAME}}` with the project name from `.silver-bullet.json`
   - Replace `{{ACTIVE_WORKFLOW}}` with the active workflow name from `.silver-bullet.json` (default: `full-dev-cycle`)
3. **Strip any SB-owned sections from CLAUDE.md** (migration from pre-v0.7.0). Check for headings matching `## N. <Known SB Title>` where N is 0–9 (titles: Session Startup, Automated Enforcement, Active Workflow, NON-NEGOTIABLE, Review Loop, Session Mode, Model Routing, GSD, File Safety, Third-Party, Pre-Release). If found, remove these sections (from heading to next `## ` or EOF), preserving all non-SB content. Also remove old-style reference lines that don't mention silver-bullet.md.
4. Verify `CLAUDE.md` contains a reference line mentioning "silver-bullet.md". If not, add at the very top of the file: `> **Always adhere strictly to this file and silver-bullet.md — they override all defaults.**`
5. Run conflict detection (same as step 3.1c below).
6. Output: "Silver Bullet updated. silver-bullet.md refreshed. All skills active."

**Template refresh (only when user explicitly requests it):**

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

### Fresh setup

If this is a fresh setup:

#### 3.1a Write silver-bullet.md

Write `silver-bullet.md` from `${PLUGIN_ROOT}/templates/silver-bullet.md.base`. This is always safe — it's a new file owned by Silver Bullet.

Perform these placeholder replacements:
- `{{PROJECT_NAME}}` → the detected/confirmed project name
- `{{ACTIVE_WORKFLOW}}` → `full-dev-cycle` (default)

#### 3.1b Handle CLAUDE.md

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

#### 3.1c Conflict detection (only when existing CLAUDE.md found)

Scan `CLAUDE.md` for patterns that conflict with `silver-bullet.md` rules. Check for these conflict patterns:

1. **Model routing overrides**: regex `(always|default|prefer|use).*(claude-opus|claude-sonnet|opus|sonnet)` on directive-like lines (starting with `-`, `>`, `**`, or containing "must"/"always"/"never") (conflicts with SB Section 5)
2. **Execution preferences**: regex `(always|never|must).*(subagent-driven|executing-plans)` on directive-like lines (conflicts with SB Section 6)
3. **Review loop overrides**: regex `(skip|disable|no).*(review.*loop|code.review)|approved.*(once|single)` on directive-like lines (conflicts with SB Section 3a)
4. **Workflow overrides**: regex `(override|replace|ignore).*(workflow|silver.bullet)` on directive-like lines (conflicts with SB Section 2)
5. **Session mode overrides**: regex `(always|default|must).*(interactive|autonomous).*mode` on directive-like lines (conflicts with SB Section 4)

For each match found, present it to the user interactively:
```
Potential conflict found in CLAUDE.md:
  Line {N}: {matched text}
  This may conflict with Silver Bullet's {section name}.
  Remove this line from CLAUDE.md? (yes / no / skip-all)
```
If user says "yes", use Edit tool to remove the line. If "no", leave it. If "skip-all", stop checking further conflicts.

#### 3.2 Create directories

Run via Bash tool:
```
mkdir -p docs/specs docs/workflows
```

#### 3.2.5 CI setup

Check if a GitHub Actions CI workflow exists:
```bash
test -d .github/workflows && ls .github/workflows/*.yml 2>/dev/null | head -1
```

If no CI workflow exists, create `.github/workflows/` and generate `ci.yml` based on the detected stack from Phase 2:

**Node.js** (package.json found):
```yaml
name: CI
on: [push, pull_request]
jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20' }
      - run: npm ci
      - run: npm run lint --if-present
      - run: npm run typecheck --if-present
      - run: npm test --if-present
```

**Python** (pyproject.toml found):
```yaml
name: CI
on: [push, pull_request]
jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: '3.12' }
      - run: pip install -e ".[dev]" || pip install -e .
      - run: ruff check . || true
      - run: mypy . || true
      - run: pytest
```

**Rust** (Cargo.toml found):
```yaml
name: CI
on: [push, pull_request]
jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: cargo clippy
      - run: cargo test
```

**Go** (go.mod found):
```yaml
name: CI
on: [push, pull_request]
jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with: { go-version: stable }
      - run: go vet ./...
      - run: go test ./...
```

**Java / Maven** (pom.xml found):
```yaml
name: CI
on: [push, pull_request]
jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { java-version: '21', distribution: temurin }
      - run: ./mvnw --no-transfer-progress verify
```

**Java / Kotlin — Gradle** (build.gradle or build.gradle.kts found):
```yaml
name: CI
on: [push, pull_request]
jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { java-version: '21', distribution: temurin }
      - run: ./gradlew check
```

**Ruby** (Gemfile found):
```yaml
name: CI
on: [push, pull_request]
jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with: { bundler-cache: true }
      - run: bundle exec rubocop --parallel || true
      - run: bundle exec rspec
```

**PHP** (composer.json found):
```yaml
name: CI
on: [push, pull_request]
jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: shivammathur/setup-php@v2
        with: { php-version: '8.3', coverage: none }
      - run: composer install --no-progress --prefer-dist
      - run: composer run lint || true
      - run: composer run test
```

**.NET / C#** (*.csproj or *.sln found):
```yaml
name: CI
on: [push, pull_request]
jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with: { dotnet-version: '9.x' }
      - run: dotnet build --no-incremental
      - run: dotnet test --no-build
```

**Elixir** (mix.exs found):
```yaml
name: CI
on: [push, pull_request]
jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: erlef/setup-beam@v1
        with: { elixir-version: '1.17', otp-version: '27' }
      - run: mix deps.get
      - run: mix compile --warnings-as-errors
      - run: mix credo --strict || true
      - run: mix test
```

**Swift** (Package.swift found):
```yaml
name: CI
on: [push, pull_request]
jobs:
  ci:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - run: swift build
      - run: swift test
```

**Dart / Flutter** (pubspec.yaml found):
```yaml
name: CI
on: [push, pull_request]
jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { channel: stable }
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test
```

**Other**: prompt user to specify verify commands. Store in `.silver-bullet.json` under `"verify_commands": ["cmd1", "cmd2"]`.

#### 3.3 Write CLAUDE.md (only when no existing CLAUDE.md)

This step only applies when NO existing `CLAUDE.md` was found in step 3.1b (the "write from template" path). If an existing `CLAUDE.md` was found, it was already handled in step 3.1b (reference line added) and 3.1c (conflict detection) — skip this step.

Read the template file at `${PLUGIN_ROOT}/templates/CLAUDE.md.base` using the Read tool.

Perform these replacements in the template content:
- `{{PROJECT_NAME}}` → the detected/confirmed project name
- `{{TECH_STACK}}` → the detected/confirmed tech stack
- `{{GIT_REPO}}` → the detected/confirmed repo URL

Write the fully rendered template to `CLAUDE.md` in the project root using the Write tool.

#### 3.4 Write config

Read the template file at `${PLUGIN_ROOT}/templates/silver-bullet.config.json.default` using the Read tool.

Perform these replacements:
- `{{PROJECT_NAME}}` → the detected/confirmed project name

Also set `src_pattern` to the detected/confirmed source pattern (replacing the default `/src/` if different).

Write the result to `.silver-bullet.json` in the project root using the Write tool.

#### 3.5 Copy workflow files

Copy both workflow templates to `docs/workflows/`:

1. Read `${PLUGIN_ROOT}/templates/workflows/full-dev-cycle.md` using the Read tool.
   **Non-destructive**: If `docs/workflows/full-dev-cycle.md` already exists, back it up
   to `docs/workflows/full-dev-cycle.md.backup` before writing.
   Write the contents to `docs/workflows/full-dev-cycle.md` using the Write tool.

2. Read `${PLUGIN_ROOT}/templates/workflows/devops-cycle.md` using the Read tool.
   **Non-destructive**: If `docs/workflows/devops-cycle.md` already exists, back it up
   to `docs/workflows/devops-cycle.md.backup` before writing.
   Write the contents to `docs/workflows/devops-cycle.md` using the Write tool.

#### 3.6 Create placeholder docs (NON-DESTRUCTIVE)

**CRITICAL: Do NOT overwrite existing files.** For each file below, check if it already
exists first (`test -f <path>`). Only create the file if it does NOT exist. If it exists,
skip it silently — the user's existing content takes priority over placeholder templates.

Create the following files in `docs/` using the Write tool — **only if they do not already exist**. Each placeholder file should contain only a title and a TODO body:

**`docs/PRD-Overview.md`**:
```markdown
# Product Requirements Overview

This document captures the product vision and high-level requirements.
It is kept in sync with `.planning/REQUIREMENTS.md` — the authoritative requirements
source managed by GSD. Update during the FINALIZATION step of each phase.

## Product Vision

TODO — Describe what this product is and who it is for (2–3 sentences).

## Core Value

TODO — The ONE thing that must work above all else.

## Requirement Areas

TODO — High-level groupings of requirements (see `.planning/REQUIREMENTS.md` for details).

## Out of Scope

TODO — What this product explicitly does not do, and why.
```

**`docs/Architecture-and-Design.md`**:
```markdown
# Architecture and Design

This document captures high-level architecture and general design principles only.
Detailed phase-level designs live in `docs/specs/YYYY-MM-DD-<topic>-design.md`.

## System Overview

TODO — Describe the overall system structure and how major parts relate.

## Core Components

TODO — List major components and their responsibilities (one line each).

## Design Principles

TODO — Architectural constraints and principles that guide all implementation decisions.

## Technology Choices

TODO — Key technology decisions and rationale.
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

**`docs/KNOWLEDGE.md`** (only if it does not already exist):

Read `${PLUGIN_ROOT}/templates/KNOWLEDGE.md.base` using the Read tool. Replace `{{PROJECT_NAME}}` with the confirmed project name and `{{GIT_REPO}}` with the confirmed repo URL. Write to `docs/KNOWLEDGE.md`.

**`docs/CHANGELOG.md`** (only if it does not already exist — task log, distinct from root-level CHANGELOG.md if present):

Read `${PLUGIN_ROOT}/templates/CHANGELOG-project.md.base` using the Read tool. Write as-is to `docs/CHANGELOG.md`.

**`docs/sessions/` directory:**

```bash
mkdir -p docs/sessions && touch docs/sessions/.gitkeep
```

#### 3.7 Stage and commit

Run via Bash tool:
```bash
git add silver-bullet.md CLAUDE.md .silver-bullet.json docs/
git commit -m "$(cat <<'EOF'
feat: initialize Silver Bullet enforcement

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

If the commit fails due to a pre-commit hook, read the error output, fix the issue, re-stage, and create a new commit (do NOT use `--amend`).

#### 3.8 Activate plugins

Invoke `/using-superpowers` via the Skill tool to establish available Superpowers skills for
the session. GSD commands (`/gsd:*`) and Design plugin skills (`/design:*`) are available
immediately as slash commands — no activation step required for those.

#### 3.9 Done

Output:
> Silver Bullet initialized. Start any task and the active workflow will be enforced automatically.
