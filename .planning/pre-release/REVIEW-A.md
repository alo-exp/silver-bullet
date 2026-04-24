# Pre-Release Code Review — Layer A (GSD Automated)
## Round 1

**Reviewed:** 2026-04-24
**Files Reviewed:** 17
**Depth:** Standard (full file read + cross-file analysis)

---

### CRITICAL findings

#### CRIT-01: Shell injection via unvalidated `$ITEM_ID` in `sed` command (`silver-remove/SKILL.md`, Step 5d, line 171)

**File:** `skills/silver-remove/SKILL.md:171`

**Issue:** The sed substitution is constructed using `${ITEM_ID}` via shell string interpolation after the `case` statement validates the format. The `case` pattern `SB-I-[0-9]*` and `SB-B-[0-9]*` uses glob matching, not strict regex — `[0-9]*` matches zero or more digits, meaning a value like `SB-I-` (no digits) would pass the `SB-I-[0-9]*` branch and be interpolated into sed. More critically, the `case` pattern allows trailing arbitrary content: `SB-I-123abc` passes `SB-I-[0-9]*` (matches because `[0-9]*` is zero-or-more) and would reach the sed command. If an attacker can influence ITEM_ID through a session log or indirect input, sed metacharacters (`&`, `\n`, `|`) within the ID could alter the sed expression.

The security boundary section correctly calls out that ITEM_ID must match `^SB-[IB]-[0-9]+$` before use in sed, but the case-statement validation used in Step 2 does NOT enforce the `+` (one-or-more digits) requirement — it uses `[0-9]*` (zero-or-more). The strict regex validation promised in the security boundary comment is not enforced by the case statement.

**Fix:** Add a strict validation step immediately before the sed command:

```bash
# Strict format guard before sed (defense-in-depth)
if ! [[ "$ITEM_ID" =~ ^SB-[IB]-[0-9]+$ ]]; then
  echo "ERROR: ID failed strict format check before sed: '${ITEM_ID}'"
  exit 1
fi
DATE=$(date +%Y-%m-%d)
sed -i '' "s|^### ${ITEM_ID} —|### [REMOVED ${DATE}] ${ITEM_ID} —|" "$TARGET_FILE"
```

---

#### CRIT-02: TOCTOU race in sentinel PID file: start-time comparison uses `ps -o lstart=` which is locale-dependent (`session-log-init.sh`, lines 73-76)

**File:** `hooks/session-log-init.sh:73-76`

**Issue:** The TOCTOU fix for PID recycling compares `ps -o lstart=` output (human-readable process start time) with a previously stored string. The `lstart` format varies by locale and macOS version (e.g., "Thu Apr 24 10:30:00 2026" vs "Thu 24 Apr 2026 10:30:00"). If the locale changes between when the sentinel is launched and when the comparison runs, `cur_start` will never equal `old_start`, causing the kill to be silently skipped — leaving a zombie sentinel running and potentially triggering a false autonomous-mode timeout later in the user's session.

Additionally, `ps -o lstart=` on macOS includes leading spaces that differ between BSD `ps` versions, making string comparison unreliable.

**Fix:** Use the process start time in epoch seconds (portable, locale-independent):

```bash
# Store epoch seconds at sentinel launch
_sent_start=$(ps -o etime= -p "$sentinel_pid" 2>/dev/null | tr -d ' ' || true)
# Or use stat-based approach if available
```

A more robust fix: use a unique token file written atomically with the sentinel PID, and delete it when the sentinel fires — then kill-check by token file existence rather than start-time string comparison.

---

#### CRIT-03: Prompt injection via session log content passed to `git log --grep` without `--fixed-strings` in scanning context (`silver-scan/SKILL.md`, Step 4-i, line 108)

**File:** `skills/silver-scan/SKILL.md:108`

**Issue:** Step 4-i explicitly documents using `--fixed-strings` with `git log --grep` and Step 4-ii uses `-F` with `grep` on CHANGELOG. The documentation is correct. However, Step 7b (cross-reference for knowledge/lessons) uses:

```bash
grep -rl "KEYWORD" docs/knowledge/ docs/lessons/ 2>/dev/null
```

without a `-F` flag. The `KEYWORD` is derived from session log content (the first 5+ meaningful words of an insight extracted from an untrusted session log). If the insight text contains grep regex metacharacters (`.`, `*`, `[`, `(`, `^`, `$`), the grep command will misbehave — either producing false matches (incorrectly marking insights as already-recorded) or failing entirely. The instruction explicitly notes `-F` for deferred-item cross-reference but omits it for the knowledge/lessons cross-reference in Step 7b.

**Fix:** Add `-F` to the knowledge/lessons cross-reference grep:

```bash
grep -rlF "$KEYWORD" docs/knowledge/ docs/lessons/ 2>/dev/null
```

---

### HIGH findings

#### HIGH-01: Version mismatch between `.silver-bullet.json` and shipped config template (`silver-bullet.config.json.default`)

**File:** `.silver-bullet.json:2` and `templates/silver-bullet.config.json.default:2-3`

**Issue:** `.silver-bullet.json` (the live repo config) contains `"version": "0.23.8"`. The template `silver-bullet.config.json.default` contains `"version": "0.11.0"` and `"config_version": "0.12.1"`. This is the config that gets stamped into new user projects when they run `/silver:init`. New users will have a `version` field of `0.11.0` in their `.silver-bullet.json`, which is far behind the actual plugin version (`0.25.0` for this release). Any version-dependent logic that reads this field from the project config (e.g., migration checks, update comparisons) will produce incorrect results.

Additionally, the live `.silver-bullet.json` is missing the `required_deploy_devops` key present in the template, and the template is missing `_notifications_comment` present in the live config. These are structural divergences between the template and the production instance.

**Fix:** Update `templates/silver-bullet.config.json.default` `version` and `config_version` to match the current release version before shipping. Add a pre-release check that diffs the live `.silver-bullet.json` structure against the template to catch structural drift.

---

#### HIGH-02: `silver-bullet.md` §10 references section numbers that don't exist in `templates/silver-bullet.md.base`

**File:** `silver-bullet.md:407` and `templates/silver-bullet.md.base:407`

**Issue:** In the live `silver-bullet.md`, §3 NON-NEGOTIABLE RULES refers to `§10 preferences` (line 407: "Override a non-skippable gate (silver:security, silver:quality-gates pre-ship, gsd-verify-work) via §10 preferences"). The section that actually contains user workflow preferences in the live file is titled `## 10. User Workflow Preferences` (present in `silver-bullet.md` at the end).

However, in `templates/silver-bullet.md.base`, the equivalent section is titled `## 9. User Workflow Preferences` and its subsections are `### 10a.`, `### 10b.`, etc. — a heading/subsection number mismatch. The rule in `silver-bullet.md.base:407` correctly says `§9 preferences`, but the subsection headings still use `10a`, `10b`, etc., which is internally contradictory (section 9 with subsections labeled 10a-10e).

Users of freshly installed Silver Bullet will have `## 9. User Workflow Preferences` with `### 10a.` subsections — a confusing numbering artifact that will be reflected in every new project.

**Fix:** In `templates/silver-bullet.md.base`, rename subsections `10a`–`10e` to `9a`–`9e` to match the parent section number `9`. Update any cross-references from `§10` to `§9` within the template.

---

#### HIGH-03: `silver-add` Step 4b label creation embeds user-controlled `OWNER_REPO` in shell without quoting validation (`silver-add/SKILL.md`, line 123)

**File:** `skills/silver-add/SKILL.md:123`

**Issue:** The label creation command in Step 4b passes `--repo "$(git remote get-url origin 2>/dev/null | sed ...)"` using command substitution. The `sed` expression transforms the remote URL, but if `origin` remote URL contains shell-special characters or newlines (which can happen with misconfigured or adversarially modified git configs), the command substitution can inject unexpected arguments into `gh label create`. The outer double-quote around the `$()` expansion is critical — but it is present. However, the sed transformation has 4 chained substitutions that do not account for SSH URLs using non-standard ports (`git@github.com:2222:owner/repo`) or HTTPS URLs with credentials embedded (`https://user:token@github.com/owner/repo`).

If credentials are embedded in the remote URL, they will appear in the `--repo` argument to `gh`, and may be logged in shell history, debug output, or gh's error messages.

**Fix:** Sanitize the remote URL more defensively:

```bash
REMOTE=$(git remote get-url origin 2>/dev/null)
# Strip credentials before processing
REMOTE=$(printf '%s' "$REMOTE" | sed 's|https://[^@]*@|https://|')
OWNER_REPO=$(printf '%s' "$REMOTE" | sed 's|https://github.com/||;s|\.git$||;s|git@github.com:||')
# Validate OWNER_REPO matches expected format
if ! [[ "$OWNER_REPO" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
  echo "ERROR: Could not derive valid owner/repo from remote URL."
  exit 1
fi
```

---

#### HIGH-04: `silver-update` Step 6b uses `rm -rf` on a path constructed from `$HOME` without validating the directory is what it claims to be (`silver-update/SKILL.md`, line 157)

**File:** `skills/silver-update/SKILL.md:157`

**Issue:** The stale cache removal in Step 6b constructs `STALE_CACHE="$HOME/.claude/plugins/cache/silver-bullet/silver-bullet"` and then runs `rm -rf "$STALE_CACHE"` if the directory exists. While the path is hardcoded (not user-input derived), there are two concerns:

1. If `$HOME` is set to an unexpected value (e.g., via environment manipulation in a compromised shell), `rm -rf` operates on a user-controlled path.
2. The `-d` check does not verify it is NOT a symlink before recursive deletion — if `$STALE_CACHE` is a symlink pointing elsewhere, `rm -rf` will follow into the symlink target on some Unix variants (though macOS `rm -rf` on a symlink removes the symlink itself, not the target, so this is lower risk on the intended platform).

The bigger concern is that there is no check that `$HOME` resolves to a reasonable path and that the target is under `$HOME`. If a user has set `HOME=/` for any reason, this would be catastrophic.

**Fix:** Add a sanity check before the rm:

```bash
STALE_CACHE="${HOME}/.claude/plugins/cache/silver-bullet/silver-bullet"
# Verify path is under $HOME and is not a symlink before removing
if [[ -d "$STALE_CACHE" && ! -L "$STALE_CACHE" ]] && \
   [[ "$STALE_CACHE" == "${HOME}/"* ]]; then
  rm -rf "$STALE_CACHE"
fi
```

---

#### HIGH-05: `silver-rem` Step 6 appends unvalidated `$INSIGHT` text to session log via `printf` — format string risk (`silver-rem/SKILL.md`, lines 272-278)

**File:** `skills/silver-rem/SKILL.md:272-278`

**Issue:** The session log append uses:

```bash
printf -- '- [%s]: %s — %s\n' "$INSIGHT_TYPE" "$CATEGORY" "${INSIGHT:0:60}" >> "$SESSION_LOG"
```

The `--` flag protects against options, and the format string is a literal — this is correct. However, `"$CATEGORY"` is derived from classification of untrusted insight content. If `$CATEGORY` contains a `%s`, `%n`, or other printf format specifier, it will be processed as part of the format string when using some shells' `printf` implementations. On bash, `printf -- 'format' args...` correctly treats only the first argument as the format string, so `$CATEGORY` in arg position 2 is safe. But the skill documentation does not explicitly validate that `$CATEGORY` must be one of the five exact heading strings before this printf call — a model that fails to enforce strict classification could pass arbitrary text as `$CATEGORY`.

This is a defense-in-depth gap: the instruction says to classify into one of five headings, but there is no explicit sanitization step that checks `$CATEGORY` against the allowlist before the printf call. In practice bash printf is safe here, but a weak classification producing `$CATEGORY="%n%s%s"` would pass through without error.

**Fix:** Add an explicit allowlist check immediately before the printf:

```bash
case "$CATEGORY" in
  "Architecture Patterns"|"Known Gotchas"|"Key Decisions"|"Recurring Patterns"|"Open Questions") ;;
  *) CATEGORY="Unknown" ;; # Sanitize unexpected values
esac
printf -- '- [%s]: %s — %s\n' "$INSIGHT_TYPE" "$CATEGORY" "${INSIGHT:0:60}" >> "$SESSION_LOG"
```

---

### MEDIUM findings

#### MED-01: Session log discovery uses `ls | sort | tail -1` which breaks on filenames with spaces or special characters (`silver-add/SKILL.md`, line 323; `silver-rem/SKILL.md`, line 264; `silver-scan/SKILL.md`, line 52)

**Files:** `skills/silver-add/SKILL.md:323`, `skills/silver-rem/SKILL.md:264`, `skills/silver-scan/SKILL.md:52`

**Issue:** All three skills discover session logs using:

```bash
SESSION_LOG=$(ls docs/sessions/*.md 2>/dev/null | sort | tail -1)
```

The `ls` command outputs filenames, and `sort | tail -1` selects the last one alphabetically. If any filename in `docs/sessions/` contains a newline (possible via certain filesystem operations or path injection), `sort` will split it across lines and `tail -1` will return only the last line of that filename — producing a truncated, non-existent path. The hook `session-log-init.sh` creates files with the predictable format `YYYY-MM-DD-HH-MM-SS.md`, but an adversarially created file with a newline in the name (or a filename sorting after legitimate session logs) could redirect session log appending.

The session-log-init.sh hook itself uses `find` with `-maxdepth 1` to avoid this, which is the correct approach.

**Fix:** Use the same `find`-based approach used in the hook:

```bash
SESSION_LOG=$(find docs/sessions/ -maxdepth 1 -name '*.md' -print 2>/dev/null | sort | tail -1)
```

And add a path validation check before use:

```bash
if [[ -n "$SESSION_LOG" ]] && ! [[ "$SESSION_LOG" =~ ^docs/sessions/[^/]+\.md$ ]]; then
  SESSION_LOG=""  # Reject invalid paths silently
fi
```

---

#### MED-02: `silver-scan` Step 9b.2 (in `silver-release/SKILL.md`) uses string comparison `[[ "$log_date" > "$MILESTONE_START" ]]` for date filtering — incorrect for date strings

**File:** `skills/silver-release/SKILL.md:254-259`

**Issue:** The milestone window filtering uses:

```bash
if [[ "$log_date" > "$MILESTONE_START" ]] || [[ "$log_date" = "$MILESTONE_START" ]]; then
```

This is lexicographic comparison of `YYYY-MM-DD` strings. This actually works correctly for ISO 8601 date strings in `YYYY-MM-DD` format — they sort lexicographically in the same order as chronologically. However, if `log_date` extraction fails (e.g., the file has a non-standard name not matching the `YYYY-MM-DD` prefix pattern), `log_date` will be empty, and `[[ "" > "2026-01-01" ]]` returns false in bash — which is the correct safe default. However if `MILESTONE_START` is also empty (git log failure path), then `[[ "" > "" ]]` is false but `[[ "" = "" ]]` is true — meaning ALL session logs would be included when both are empty strings. The fallback `MILESTONE_START="1970-01-01"` prevents this, but this edge case should be documented.

**Fix:** This is a minor robustness issue. Add a guard:

```bash
[[ -z "$log_date" ]] && continue  # Skip files whose date cannot be extracted
```

---

#### MED-03: `silver-add` Step 4a authentication check is unreliable — grepping for "project" in `gh auth status` output

**File:** `skills/silver-add/SKILL.md:107-108`

**Issue:** The project scope check runs:

```bash
gh auth status 2>&1 | grep -q "project"
```

The `gh auth status` output format is not guaranteed across gh CLI versions. Checking for the string "project" in output could match unrelated lines (e.g., error messages containing the word "project", or the repository name). Conversely, a future gh CLI version could change the output format, causing the check to always fail and permanently block GitHub filing.

A more reliable check is to use `gh auth token --scopes` or check the `project` scope via `gh api` — or use `gh auth status --json scopes` if available.

**Fix:** Use the structured scope check:

```bash
gh auth token 2>/dev/null | xargs -I{} curl -sH "Authorization: token {}" \
  https://api.github.com 2>/dev/null | jq -e '.X-OAuth-Scopes // empty' | grep -q 'project'
```

Or more robustly, simply attempt the project operation and handle the 401/403 error with a clear message rather than pre-checking.

---

#### MED-04: `silver-rem` size cap logic has a gap — the `-b` overflow file is rechecked but `IS_NEW_FILE` is set to `false` unconditionally before the new file check

**File:** `skills/silver-rem/SKILL.md:163-174`

**Issue:** In Step 5's size cap block:

```bash
TARGET="${TARGET%.md}-b.md"
IS_NEW_FILE=false            # <-- set false here
[ ! -f "$TARGET" ] && IS_NEW_FILE=true
```

The `IS_NEW_FILE=false` line is redundant (it was already set based on the original file), but more importantly the comment says "If the -b file is also new, create it with the correct header (same as above)" — but the code to actually create the -b file with a header is not present. The comment references an action that needs to happen but the shell code block only reassigns the variable without branching to header creation.

Step 6 then appends to `$TARGET` (the -b file). If the -b file is new (`IS_NEW_FILE=true` after the check), the heading structure (Step 5 creation block) runs for the ORIGINAL file's type, but there is no branching back to Step 5's creation code for the -b file. New knowledge `-b` files would receive no header, and new lessons `-b` files would receive no header — meaning the first entry would have no frontmatter and no category structure.

**Fix:** After setting `TARGET` to the `-b` file, explicitly call the header creation logic before Step 6 if `IS_NEW_FILE=true`:

```
If IS_NEW_FILE=true after the -b file check:
  Create the -b file with the correct header for INSIGHT_TYPE
  (same logic as the IS_NEW_FILE=true branches in Step 5 above)
Then proceed to Step 6.
```

---

#### MED-05: `session-log-init.sh` `_insert_before` function fails silently on awk error — inserted content may be lost

**File:** `hooks/session-log-init.sh:100-106`

**Issue:** The `_insert_before` function writes awk output to `$tmp`, then conditionally moves it back:

```bash
if awk ... "$file" > "$tmp"; then
  mv "$tmp" "$file"
else
  rm -f -- "$tmp"
fi
```

If `awk` exits zero but produces empty output (e.g., `$file` is empty or the anchor is not found), the `mv "$tmp" "$file"` will overwrite the session log with empty or partial content — silently wiping existing session log data. Awk exits 0 even when the anchor pattern is never matched; it simply outputs all lines without inserting.

The anchor not being found is actually the common case during an idempotency check (`if ! grep -q "^## Pre-answers$"`), meaning the anchor IS expected to be found — but if the session log was truncated or malformed, awk exits 0 with the original content minus the anchor insertion, and the mv replaces the file. The scenario where `awk` finds no anchor and outputs the original unchanged is safe, but the scenario where the file is empty is not.

**Fix:** Verify `$tmp` is non-empty before the mv:

```bash
if awk ... "$file" > "$tmp" && [ -s "$tmp" ]; then
  mv "$tmp" "$file"
else
  rm -f -- "$tmp"
fi
```

---

#### MED-06: `silver-release` Step 9b.2 reads session log content with `awk` and stores it in a shell variable — uncontrolled growth for long sessions

**File:** `skills/silver-release/SKILL.md:257-261`

**Issue:** The `awk` extraction in Step 9b.2 reads the `## Items Filed` section and concatenates all session content into `items_filed`:

```bash
items_filed="${items_filed}${section}"$'\n'
```

With no cap on the number of sessions or the length of the `## Items Filed` sections, `items_filed` can grow unboundedly in a long-running project with many sessions. For a project with 500 session logs and verbose filing entries, this shell variable could exhaust available memory or exceed shell variable limits (which vary by system). There is no cap or pagination mechanism.

**Fix:** Add a session count limit or truncate `items_filed` at a reasonable number of items (e.g., 200 lines):

```bash
items_filed=$(printf '%s' "$items_filed" | head -200)
```

And add a note in the output if truncation occurred.

---

#### MED-07: `.silver-bullet.json` version is `0.23.8` but this is v0.25.0 release — the config file shipping with the repo does not reflect the release version

**File:** `.silver-bullet.json:2`

**Issue:** The project's own `.silver-bullet.json` has `"version": "0.23.8"`. If this file is read at session startup (which `silver-bullet.md §0` instructs), and if any version-aware logic reads this field to determine which skill set or configuration schema applies, users or CI checks comparing this value to the release tag (`0.25.0`) will see a stale version. The `silver-update` skill reads `installed_plugins.json` (not this file) for version checks, so the direct version comparison impact is limited — but the inconsistency signals a process gap where the project's own config is not bumped as part of the release.

**Fix:** As part of release preparation, update `"version"` in `.silver-bullet.json` to match the release version being shipped.

---

### LOW/INFO findings

#### LOW-01: `silver-add` Step 4b label creation uses `||true` to suppress errors but does not distinguish between "label already exists" (expected) and auth/network failure (unexpected)

**File:** `skills/silver-add/SKILL.md:124`

**Issue:** `gh label create ... 2>/dev/null || true` silently swallows all errors. If `gh` fails due to insufficient permissions or network timeout, the label simply doesn't get created but execution continues. A subsequent step that relies on the label existing will fail with a less helpful error. The skill does correctly note this is idempotent but could be improved by distinguishing error types.

**Suggestion:** Log non-422 errors (label already exists returns 422) as warnings.

---

#### LOW-02: `silver-update` Step 2 curl uses `-s` (silent) for changelog fetch but has no timeout — update can hang indefinitely

**File:** `skills/silver-update/SKILL.md:85`

**Issue:** `curl -s https://raw.githubusercontent.com/...` has no `--max-time` flag. On slow connections or when GitHub is rate-limiting, this hangs indefinitely, blocking the skill.

**Suggestion:** Add `--max-time 30` to the changelog curl call.

---

#### LOW-03: `silver-release` Step 9b.1 `PREV_TAG` derivation assumes `tail -2 | head -1` gives the previous tag — fails for initial releases with only one tag

**File:** `skills/silver-release/SKILL.md:238-239`

**Issue:** When there is only one semver tag in the repository (the first release), `git tag --sort=version:refname | grep '^v[0-9]' | tail -2 | head -1` returns the same tag as the current one. `MILESTONE_START` is then set to the date of the current release tag, meaning NO session logs before the current tag are included — the post-release summary would show "(none)".

The fallback `MILESTONE_START="1970-01-01"` is only used when git log fails, not when only one tag exists.

**Suggestion:** Add a check: if `PREV_TAG == current release tag`, set `MILESTONE_START="1970-01-01"` to include all logs.

---

#### LOW-04: `silver-remove` Step 5d uses BSD sed (`sed -i ''`) but documents GNU sed incompatibility without providing a cross-platform fallback

**File:** `skills/silver-remove/SKILL.md:171`

**Issue:** `sed -i ''` is macOS/BSD syntax. On Linux (where some users may run Claude Code), the correct syntax is `sed -i` (no empty string argument). The skill explicitly lists BSD sed as the target but the Allowed Commands section calls this out. This is a known limitation but is not handled — on Linux, the command will produce an error or modify files with literal `''` suffixes.

**Suggestion:** Add an OS detection guard or use `awk`-based replacement (which is already used elsewhere in the hook for cross-platform compatibility, as seen in `session-log-init.sh`).

---

#### LOW-05: `silver-scan` Step 2 total session count calculation uses `grep -c` on the ls output — returns 0 when `ls` output has no `.md` suffix on last line

**File:** `skills/silver-scan/SKILL.md:53`

**Issue:** `TOTAL_SESSIONS=$(echo "$SESSION_LOGS" | grep -c '\.md$' || echo 0)` depends on `$SESSION_LOGS` being a newline-separated list. If `SESSION_LOGS` is empty (no logs), `grep -c` returns 0 but exits non-zero (no matches), and the `|| echo 0` catches this correctly. However, if the `ls` output was processed in a way that stripped trailing newlines, the count could be off by one. This is a minor edge case but could cause the "Found N session logs" message to be wrong by 1.

**Suggestion:** Use `wc -l` on the list, or count via `find -print | wc -l`.

---

#### LOW-06: `silver-forensics` slug sanitization does not strip all path separator characters

**File:** `skills/silver-forensics/SKILL.md` (Post-mortem Report, step 2)

**Issue:** The slug sanitization rule says "keep only letters, digits, hyphens, and dots; replace all other characters with hyphens; strip leading dots and hyphens; truncate to 80 characters." Backslash (`\`) is replaced with a hyphen, which is correct. However, the rule does not explicitly mention stripping null bytes or Unicode direction-override characters (U+202E RIGHT-TO-LEFT OVERRIDE), which could cause the resulting filename to appear to have a different extension when displayed in certain terminals or file managers.

This is a low-severity theoretical concern for a forensics report file (not user-execution context), but worth noting for a security-focused plugin.

**Suggestion:** Add `tr -d '\000-\037'` (strip control characters including null bytes) to the slug sanitization pipeline.

---

#### LOW-07: `templates/silver-bullet.md.base` §2d lists quality-gate-stage markers as NOT part of SB state file, but `silver-bullet.md` §2d correctly includes them — documentation divergence

**File:** `templates/silver-bullet.md.base:207-213` vs `silver-bullet.md:207-213`

**Issue:** In `silver-bullet.md`, the "SB state file is ONLY for" list includes:
- Quality gate stage markers (`quality-gate-stage-1` through `quality-gate-stage-4`)
- Skill invocation markers
- Session mode
- Session init sentinel

In `templates/silver-bullet.md.base`, the same section is missing the quality gate stage markers line entirely. This means freshly installed Silver Bullet projects will have `silver-bullet.md` without the quality gate marker clarification — users of new installs will not know these markers are state-file entries, and may be confused when the completion-audit hook references them.

**Suggestion:** Add the quality-gate-stage markers note to the template's §2d section to keep it in sync with the live file.

---

### Summary

| Severity | Count | Items |
|----------|-------|-------|
| **CRITICAL** | 3 | CRIT-01 (sed injection via case glob bypass), CRIT-02 (TOCTOU locale-sensitive PID comparison), CRIT-03 (missing -F flag on knowledge grep in silver-scan) |
| **HIGH** | 5 | HIGH-01 (config template version stale), HIGH-02 (section number mismatch in template), HIGH-03 (remote URL credential exposure), HIGH-04 (rm -rf without symlink check), HIGH-05 (printf category format-string gap) |
| **MEDIUM** | 6 | MED-01 (ls pipe for session log discovery), MED-02 (empty date string edge case), MED-03 (unreliable gh auth scope check), MED-04 (missing -b file header creation), MED-05 (awk silent overwrite on empty output), MED-06 (unbounded items_filed variable), MED-07 (project config version stale) |
| **LOW/INFO** | 7 | LOW-01 through LOW-07 |
| **Total** | **21** | |

**Total: 3 critical, 5 high, 6 medium, 7 low/info**

---

_Reviewed: 2026-04-24_
_Reviewer: Claude (gsd-code-reviewer / Layer A — GSD Automated)_
_Depth: Standard (full file read + cross-file analysis)_
