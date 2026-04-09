# Quick Task Plan: 260409-4vd
# First-install "can't see skills" — hooks hardening + silver:init hook registration + version bump

**Task ID:** 260409-4vd
**Branch:** main (commit directly)

---

## Context

On first install, hooks may fail with a nonzero exit because environment variables or files
they depend on are not yet set up (e.g., missing jq, no git repo, missing plugin cache). A
nonzero hook exit causes Claude to reject the plugin entirely. Two complementary fixes:

1. Add `trap 'exit 0' ERR` to all hooks that use `set -e*` but lack one, so any unhandled
   failure silently exits 0 instead of surfacing a nonzero.
2. Restore `"hooks": "./hooks/hooks.json"` to plugin.json so hooks are registered from the
   marketplace plugin itself.
3. Enhance `silver:init` to also merge hook entries into `~/.claude/settings.json` (user-
   scoped global registration), giving users hooks even if marketplace hooks are stripped.
4. Bump version to 0.13.2 and document both fixes in CHANGELOG.md.

---

## Hooks audit (pre-plan)

All `.sh` files and `session-start` were inspected. Current state:

| File | set -e* | ERR trap present | Action |
|---|---|---|---|
| `session-start` | yes | NO | Add trap |
| `forbidden-skill-check.sh` | yes | YES (with message) | Already done |
| `compliance-status.sh` | yes | NO | Add trap |
| `session-log-init.sh` | yes | NO | Add trap |
| `ensure-model-routing.sh` | yes | NO | Verify: exits 0 on canary path; add trap for safety |
| `semantic-compress.sh` | yes | NO | Add trap |
| `record-skill.sh` | yes | NO | Add trap |
| `ci-status-check.sh` | yes | NO | Add trap |
| `dev-cycle-check.sh` | yes | NO | Add trap |
| `timeout-check.sh` | yes | YES (bare exit 0) | Already done |
| `prompt-reminder.sh` | yes | YES (bare exit 0) | Already done |
| `completion-audit.sh` | yes | YES (with message) | Already done |
| `stop-check.sh` | yes | YES (with message) | Already done |

Hooks needing the trap added: `session-start`, `compliance-status.sh`, `session-log-init.sh`,
`ensure-model-routing.sh`, `semantic-compress.sh`, `record-skill.sh`, `ci-status-check.sh`,
`dev-cycle-check.sh`.

---

## Task 1 — Harden hooks + restore hooks in plugin.json

**Files modified:**
- `hooks/session-start`
- `hooks/compliance-status.sh`
- `hooks/session-log-init.sh`
- `hooks/ensure-model-routing.sh`
- `hooks/semantic-compress.sh`
- `hooks/record-skill.sh`
- `hooks/ci-status-check.sh`
- `hooks/dev-cycle-check.sh`
- `.claude-plugin/plugin.json`

### 1a. Add ERR trap to `hooks/session-start`

Insert immediately after `set -euo pipefail` on line 2:

```
trap 'exit 0' ERR
```

Result (lines 1–4):
```bash
#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR
```

### 1b. Add ERR trap to `hooks/compliance-status.sh`

Insert `trap 'exit 0' ERR` immediately after the `set -euo pipefail` line (line 2).

### 1c. Add ERR trap to `hooks/session-log-init.sh`

Insert `trap 'exit 0' ERR` immediately after the `set -euo pipefail` line (line 2).

### 1d. Add ERR trap to `hooks/ensure-model-routing.sh`

Insert `trap 'exit 0' ERR` immediately after the `set -euo pipefail` line (line 15).

Note: `ensure-model-routing.sh` already exits 0 at the canary check when routing is correct.
The trap adds safety for any unexpected failure during the patching path.

### 1e. Add ERR trap to `hooks/semantic-compress.sh`

Insert `trap 'exit 0' ERR` immediately after the `set -euo pipefail` line.

### 1f. Add ERR trap to `hooks/record-skill.sh`

Insert `trap 'exit 0' ERR` immediately after the `set -euo pipefail` line.

### 1g. Add ERR trap to `hooks/ci-status-check.sh`

Insert `trap 'exit 0' ERR` immediately after the `set -euo pipefail` line.

### 1h. Add ERR trap to `hooks/dev-cycle-check.sh`

Insert `trap 'exit 0' ERR` immediately after the `set -euo pipefail` line.

### 1i. Restore `hooks` field in `.claude-plugin/plugin.json`

Add `"hooks": "./hooks/hooks.json"` as a top-level field. The `"skills"` field MUST remain
absent (it was intentionally removed and must stay out). Result:

```json
{
  "name": "silver-bullet",
  "description": "Agentic Process Orchestrator for AI-native Software Engineering & DevOps. Combines GSD, Superpowers, Engineering, and Design plugins into enforced 20-step (app) and 24-step (DevOps) workflows with 10-layer technical compliance.",
  "version": "0.13.1",
  "author": {
    "name": "Alo Labs",
    "email": "info@alolabs.dev"
  },
  "homepage": "https://github.com/alo-exp/silver-bullet",
  "repository": {
    "type": "git",
    "url": "https://github.com/alo-exp/silver-bullet.git"
  },
  "license": "MIT",
  "keywords": [
    "silver-bullet",
    "enforcement",
    "orchestrator",
    "gsd",
    "devops",
    "quality-gates",
    "deploy-gate",
    "ci-cd"
  ],
  "hooks": "./hooks/hooks.json"
}
```

### Verify Task 1

```bash
# Confirm all targeted hooks now have the trap line
grep -l 'trap.*exit 0.*ERR\|trap.*ERR.*exit 0' \
  /Users/shafqat/Documents/Projects/silver-bullet/hooks/session-start \
  /Users/shafqat/Documents/Projects/silver-bullet/hooks/compliance-status.sh \
  /Users/shafqat/Documents/Projects/silver-bullet/hooks/session-log-init.sh \
  /Users/shafqat/Documents/Projects/silver-bullet/hooks/ensure-model-routing.sh \
  /Users/shafqat/Documents/Projects/silver-bullet/hooks/semantic-compress.sh \
  /Users/shafqat/Documents/Projects/silver-bullet/hooks/record-skill.sh \
  /Users/shafqat/Documents/Projects/silver-bullet/hooks/ci-status-check.sh \
  /Users/shafqat/Documents/Projects/silver-bullet/hooks/dev-cycle-check.sh

# Confirm plugin.json now has the hooks field and no skills field
jq '{"hooks":.hooks, "has_skills":(.skills != null)}' \
  /Users/shafqat/Documents/Projects/silver-bullet/.claude-plugin/plugin.json
# Expected: {"hooks":"./hooks/hooks.json","has_skills":false}

# Smoke-test each hardened hook parses without error
for f in \
  hooks/session-start \
  hooks/compliance-status.sh \
  hooks/session-log-init.sh \
  hooks/ensure-model-routing.sh \
  hooks/semantic-compress.sh \
  hooks/record-skill.sh \
  hooks/ci-status-check.sh \
  hooks/dev-cycle-check.sh; do
  bash -n "/Users/shafqat/Documents/Projects/silver-bullet/$f" && echo "OK: $f" || echo "PARSE ERROR: $f"
done
```

### Commit Task 1

```bash
cd /Users/shafqat/Documents/Projects/silver-bullet
git add hooks/session-start \
        hooks/compliance-status.sh \
        hooks/session-log-init.sh \
        hooks/ensure-model-routing.sh \
        hooks/semantic-compress.sh \
        hooks/record-skill.sh \
        hooks/ci-status-check.sh \
        hooks/dev-cycle-check.sh \
        .claude-plugin/plugin.json
git commit -m "$(cat <<'EOF'
fix(hooks): harden all hooks against first-install failures

Add 'trap exit 0 ERR' to every hook that uses set -euo pipefail but lacked
an error trap: session-start, compliance-status.sh, session-log-init.sh,
ensure-model-routing.sh, semantic-compress.sh, record-skill.sh,
ci-status-check.sh, dev-cycle-check.sh.

Any unhandled failure now exits 0 instead of surfacing a nonzero, preventing
Claude from rejecting the plugin during first-install when the environment is
not yet fully set up.

Also restore "hooks": "./hooks/hooks.json" to .claude-plugin/plugin.json so
the marketplace registers hooks automatically on install. The "skills" field
remains absent (intentional).

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2 — Enhance silver:init to register hooks into ~/.claude/settings.json

**File modified:** `skills/silver-init/SKILL.md`

### What to add

After Phase 3, Step 3.7 ("Stage and commit") and before Step 3.8 ("Activate plugins"),
insert a new **Step 3.7.5: Register SB hooks in user settings**.

Add the following section verbatim into `skills/silver-init/SKILL.md`, between the closing
of step 3.7 and the opening of step 3.8:

---

```
#### 3.7.5 Register SB hooks in ~/.claude/settings.json

This step merges the Silver Bullet hook entries from `hooks/hooks.json` into the user's
global `~/.claude/settings.json` so hooks are active even in projects that install SB
without the marketplace (e.g. manual installs or workspace clones).

**Resolve the plugin install path:**

```bash
INSTALL_PATH=$(python3 -c "
import json, os, sys
reg = os.path.expanduser('~/.claude/plugins/installed_plugins.json')
with open(reg) as f:
    data = json.load(f)
plugins = data.get('plugins', {})
# Find the silver-bullet entry (key may be 'silver-bullet@silver-bullet' or similar)
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

If `INSTALL_PATH` is empty or the command fails, skip this step silently and continue.

**Merge hooks idempotently:**

```bash
python3 - "$INSTALL_PATH" << 'PYEOF'
import json, os, sys

install_path = sys.argv[1]
hooks_src = os.path.join(install_path, 'hooks', 'hooks.json')
settings_path = os.path.expanduser('~/.claude/settings.json')

# Load source hooks.json
with open(hooks_src) as f:
    src = json.load(f)

sb_hooks = src.get('hooks', {})

# Substitute actual install path for ${CLAUDE_PLUGIN_ROOT}
def sub_path(obj, install_path):
    if isinstance(obj, str):
        return obj.replace('${CLAUDE_PLUGIN_ROOT}', install_path)
    if isinstance(obj, list):
        return [sub_path(i, install_path) for i in obj]
    if isinstance(obj, dict):
        return {k: sub_path(v, install_path) for k, v in obj.items()}
    return obj

sb_hooks = sub_path(sb_hooks, install_path)

# Load or create settings.json
if os.path.exists(settings_path):
    with open(settings_path) as f:
        settings = json.load(f)
else:
    settings = {}

existing_hooks = settings.setdefault('hooks', {})

# Merge: for each event, append only entries whose command is not already present
for event, entries in sb_hooks.items():
    existing_event = existing_hooks.setdefault(event, [])
    for new_group in entries:
        new_hooks_list = new_group.get('hooks', [])
        for new_hook in new_hooks_list:
            new_cmd = new_hook.get('command', '')
            already_present = any(
                h.get('command', '') == new_cmd
                for group in existing_event
                for h in group.get('hooks', [])
            )
            if not already_present:
                # Find matching group by matcher or append new group
                matcher = new_group.get('matcher', '')
                matched = next(
                    (g for g in existing_event
                     if g.get('matcher', '') == matcher),
                    None
                )
                if matched:
                    matched.setdefault('hooks', []).append(new_hook)
                else:
                    existing_event.append({
                        'matcher': matcher,
                        'hooks': [new_hook]
                    })

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')

print('SB hooks registered in ~/.claude/settings.json')
PYEOF
```

If the script exits nonzero (e.g., hooks.json not readable, settings.json not writable),
display a warning but do NOT stop init:
> ⚠️  Could not auto-register hooks in ~/.claude/settings.json. Run `/silver:init` again
> after installation completes, or add hooks manually from `hooks/hooks.json`.

This step is idempotent: running `/silver:init` again will not add duplicate hook entries.
```

---

The section should be inserted between the end of step 3.7's bash block and the `#### 3.8 Activate plugins` heading.

For **update mode** (Phase 3, "Update mode" path): also add a call to step 3.7.5 between
steps 5 ("Run conflict detection") and 6 ("Output: Silver Bullet updated..."). Insert:

```
5a. Run step 3.7.5 to re-register or refresh SB hooks in `~/.claude/settings.json`.
```

### Verify Task 2

Confirm the new section appears between 3.7 and 3.8:
```bash
grep -n "3.7.5\|3.8 Activate" \
  /Users/shafqat/Documents/Projects/silver-bullet/skills/silver-init/SKILL.md
```
Expected: line for `3.7.5` appears before the line for `3.8`.

### Commit Task 2

```bash
cd /Users/shafqat/Documents/Projects/silver-bullet
git add skills/silver-init/SKILL.md
git commit -m "$(cat <<'EOF'
feat(silver:init): register SB hooks into ~/.claude/settings.json

Add Phase 3 step 3.7.5: after scaffolding, silver:init now merges the
Silver Bullet hook entries from hooks/hooks.json into the user's global
~/.claude/settings.json. Hook commands are registered with the actual
install path substituted for ${CLAUDE_PLUGIN_ROOT}. Merge is idempotent
— no duplicate entries are added on re-run.

Also adds step 5a in update mode to re-register/refresh hooks during
silver:init re-runs on existing projects.

This ensures hooks are active even when marketplace plugin auto-registration
is delayed or bypassed.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3 — Version bump + CHANGELOG entry

**Files modified:**
- `.claude-plugin/plugin.json`
- `CHANGELOG.md`

### 3a. Bump version in plugin.json

Change `"version": "0.13.1"` → `"version": "0.13.2"` in `.claude-plugin/plugin.json`.

Note: plugin.json was already modified in Task 1 (hooks field added). This edit applies
on top of that — just update the version string. The resulting file should have both
`"version": "0.13.2"` and `"hooks": "./hooks/hooks.json"`.

### 3b. Add CHANGELOG entry

Insert the following block immediately after the `## [Unreleased]` line in `CHANGELOG.md`:

```markdown
## [0.13.2] — 2026-04-09

### Fixed
- All hooks that used `set -euo pipefail` without an ERR trap now have
  `trap 'exit 0' ERR` added. Affected files: `hooks/session-start`,
  `hooks/compliance-status.sh`, `hooks/session-log-init.sh`,
  `hooks/ensure-model-routing.sh`, `hooks/semantic-compress.sh`,
  `hooks/record-skill.sh`, `hooks/ci-status-check.sh`,
  `hooks/dev-cycle-check.sh`. Prevents first-install failures from
  surfacing nonzero hook exits that cause Claude to reject the plugin.
- Restored `"hooks": "./hooks/hooks.json"` to `.claude-plugin/plugin.json`
  so the marketplace registers hooks automatically on install.

### Added
- `silver:init` Phase 3 step 3.7.5: after project scaffolding, merges SB
  hook entries from `hooks/hooks.json` into `~/.claude/settings.json` using
  `python3`. Hook commands are registered with the actual install path
  substituted for `${CLAUDE_PLUGIN_ROOT}`. Idempotent — re-running init
  does not add duplicate entries. Also runs during update mode (step 5a).

```

### Verify Task 3

```bash
# Confirm version
jq -r '.version' /Users/shafqat/Documents/Projects/silver-bullet/.claude-plugin/plugin.json
# Expected: 0.13.2

# Confirm hooks field still present
jq -r '.hooks' /Users/shafqat/Documents/Projects/silver-bullet/.claude-plugin/plugin.json
# Expected: ./hooks/hooks.json

# Confirm CHANGELOG has the new entry
grep -A 3 '0.13.2' /Users/shafqat/Documents/Projects/silver-bullet/CHANGELOG.md
```

### Commit Task 3

```bash
cd /Users/shafqat/Documents/Projects/silver-bullet
git add .claude-plugin/plugin.json CHANGELOG.md
git commit -m "$(cat <<'EOF'
chore: release v0.13.2

Bump version from 0.13.1 to 0.13.2.
Add CHANGELOG entry covering hook hardening and silver:init hook
registration enhancements.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Execution order

Tasks are sequential — each commit builds on the previous one:

1. Task 1: Hook hardening + plugin.json hooks restoration
2. Task 2: silver:init enhancement
3. Task 3: Version bump + CHANGELOG (applies version bump on top of Task 1's plugin.json edits)

**Important:** Task 3 modifies `.claude-plugin/plugin.json` again (version bump). Since
Task 1 already staged and committed that file, Task 3 opens the already-modified file and
changes only the version string. No conflict — the hooks field added in Task 1 is preserved.

---

## Success criteria

- [ ] All 8 previously unguarded hooks now have `trap 'exit 0' ERR` after their `set -euo pipefail` line
- [ ] `.claude-plugin/plugin.json` has `"hooks": "./hooks/hooks.json"` and no `"skills"` field, version `0.13.2`
- [ ] `skills/silver-init/SKILL.md` has step 3.7.5 (with python3 merge script) between steps 3.7 and 3.8
- [ ] `skills/silver-init/SKILL.md` update-mode path references step 3.7.5 as step 5a
- [ ] `CHANGELOG.md` has `[0.13.2]` entry covering both fixes and the new feature
- [ ] All hooks parse without syntax errors (`bash -n`)
- [ ] 3 atomic commits total, one per task
