# Pre-Release Code Review — Layer C (Engineering Review)
## Round 1

**Reviewer:** Claude Sonnet 4.6 (engineering agent)
**Date:** 2026-04-24
**Scope:** Silver Bullet v0.25.0 — all new and modified skills, supporting files, hook, and config

---

### Security findings

---

**SEC-01 — HIGH — silver-add/SKILL.md: Step 4a project-scope check is unreliable**

`gh auth status 2>&1 | grep -q "project"` checks whether the word "project" appears anywhere in the auth status output. This is far too broad — the word "project" appears in normal status output (e.g., "Logged in to github.com as user (...)") regardless of OAuth scope. The check will silently pass without the `project` scope granted, meaning board-placement operations will then fail at Step 4e with a confusing error rather than a clear scope-missing message.

Correct check:
```bash
gh auth status 2>&1 | grep -q "oauth_scopes.*project"
# or more robustly:
gh auth status --show-token 2>&1 | grep project
```

**File:** `skills/silver-add/SKILL.md` — Step 4a

---

**SEC-02 — HIGH — silver-remove/SKILL.md: sed pattern for ID validation is not anchored tightly enough**

Step 5d uses:
```bash
sed -i '' "s|^### ${ITEM_ID} —|### [REMOVED ${DATE}] ${ITEM_ID} —|" "$TARGET_FILE"
```

`ITEM_ID` has been validated by the `case` statement to match `SB-I-[0-9]*` or `SB-B-[0-9]*`. However, the `[0-9]*` glob in bash `case` accepts zero digits — `SB-I-` alone matches. A user-supplied ID of `SB-I-` would produce a sed pattern of `s|^### SB-I- —|...|` which, while benign in this case, shows that the ID validation does not enforce that at least one digit follows the prefix.

The Step 5c `grep -q "^### ${ITEM_ID} —"` inherits the same weak validation — if the ID is `SB-I-` (no trailing digit) the grep is still valid but the heading will never match in a real file, so the shell will exit 1 with a confusing "not found" message rather than "invalid ID format."

Fix: tighten the `case` pattern to `SB-I-[0-9][0-9]*)` and `SB-B-[0-9][0-9]*)` (require at least one digit), or add an explicit numeric-suffix check.

**File:** `skills/silver-remove/SKILL.md` — Step 2 and Step 5c

---

**SEC-03 — HIGH — silver-scan/SKILL.md: git log --grep path allows regex injection from extracted item titles**

Step 4-i runs:
```bash
git log --oneline --fixed-strings --grep="ITEM_TITLE_KEYWORD"
```

The `--fixed-strings` flag is specified and is the correct mitigation — this is documented explicitly in the skill. However, Step 4-ii uses:
```bash
grep -i -F "ITEM_TITLE_KEYWORD" CHANGELOG.md
```
with the `-F` (fixed-string) flag, which is also correct.

**Risk mitigated correctly.** No injection is possible given the `-F`/`--fixed-strings` guards. This is flagged as informational (no finding) — the guards are appropriate and the rationale is explicitly documented.

**Finding: NONE — guards are correct and documented.**

---

**SEC-04 — MEDIUM — silver-rem/SKILL.md: insight text appended via printf without sanitization of format specifiers**

Step 6 uses:
```bash
printf "\n%s — %s\n" "$(date +%Y-%m-%d)" "$INSIGHT" >> "$TARGET"
```

`$INSIGHT` is passed as a format argument to `printf`. If `$INSIGHT` contains printf format specifiers (e.g., `%s`, `%n`), they will be interpreted. `%n` in particular writes the number of characters output so far to a memory address, which is a security concern in C implementations. While bash's `printf` builtin does not support `%n`, this remains a poor practice.

Fix: always pass user-controlled strings as data arguments with an explicit format string that does not contain format specifiers derived from input. The current pattern `printf "%s" "$INSIGHT"` or `printf -- '%s\n' "$INSIGHT"` is safe. The current `printf "\n%s — %s\n" "$(date)" "$INSIGHT"` is safe in bash, but the approach should be documented as intentional.

**File:** `skills/silver-rem/SKILL.md` — Step 6 (both knowledge and lessons branches), Step 8

**Severity rationale:** Low real-world risk in bash, but the pattern should be consistent with the security boundary documented in the skill itself.

---

**SEC-05 — MEDIUM — silver-add/SKILL.md: session log discovery uses unquoted glob in backtick-style expansion**

Step 6:
```bash
SESSION_LOG=$(ls docs/sessions/*.md 2>/dev/null | sort | tail -1)
```

`ls` with a glob is subject to word splitting and path injection if session log filenames contain special characters. A filename containing a newline or embedded space will produce incorrect results. The `sort | tail -1` pipeline sorts lexicographically, which works for ISO-date filenames but is fragile.

Better pattern (consistent with silver-scan which uses the same approach):
```bash
SESSION_LOG=$(find docs/sessions -maxdepth 1 -name '*.md' -print0 2>/dev/null \
  | sort -z | tail -z -n1 | tr -d '\0')
```
Or equivalently, the `glob` tool if available. The same pattern appears in `silver-rem/SKILL.md` Step 8 and `silver-scan/SKILL.md` Step 2.

**Files:** `skills/silver-add/SKILL.md` §6, `skills/silver-rem/SKILL.md` §8, `skills/silver-scan/SKILL.md` §2

---

**SEC-06 — MEDIUM — silver-release/SKILL.md Step 9b.2: unquoted loop variable and shell glob over session logs**

```bash
for log in docs/sessions/*.md; do
  [ -f "$log" ] || continue
  log_date=$(basename "$log" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}')
  if [[ "$log_date" > "$MILESTONE_START" ]] || [[ "$log_date" = "$MILESTONE_START" ]]; then
```

The comparison `[[ "$log_date" > "$MILESTONE_START" ]]` uses the `>` operator, which in `[[ ]]` performs lexicographic string comparison, not date comparison. For ISO dates (YYYY-MM-DD) this is coincidentally correct, but:

1. If `log_date` is empty (filename doesn't match the expected format), the comparison `"" > "2026-01-01"` evaluates false — the log is silently skipped rather than producing an error.
2. If `MILESTONE_START` is empty (git tag missing) it falls back to `"1970-01-01"`, which is correct.

Fix: add a guard: `[[ -z "$log_date" ]] && continue` after the `grep -oE` line to skip non-conforming filenames explicitly.

**File:** `skills/silver-release/SKILL.md` — Step 9b.2

---

**SEC-07 — LOW — session-log-init.sh: mode file read is race-prone (TOCTOU)**

Lines 155–164:
```bash
if [[ -f "$mode_file" && ! -L "$mode_file" ]]; then
  mode=$(cat "$mode_file" 2>/dev/null || echo "interactive")
```

The `-f "$mode_file"` check and the subsequent `cat` are two separate operations. Between the check and the read, another process could replace the file with a symlink. The `! -L` check mitigates this partially, but both checks must be atomic to be effective.

This is low severity because the hook already has `sb_guard_nofollow` for writes, and mode is validated against an allowlist immediately after reading. The existing validation (`case "$mode" in interactive|autonomous)`) means the worst outcome of a tampered mode file is defaulting to `interactive` — not a safety issue. Flagged for completeness.

**File:** `hooks/session-log-init.sh` — line 155

---

**SEC-08 — LOW — silver-update/SKILL.md: rm -rf on unvalidated path**

Step 6b:
```bash
STALE_CACHE="$HOME/.claude/plugins/cache/silver-bullet/silver-bullet"
if [[ -d "$STALE_CACHE" ]]; then
  rm -rf "$STALE_CACHE"
fi
```

`$STALE_CACHE` is constructed from a hardcoded template with no user-supplied components, and is prefixed with `$HOME` which is not user-controllable at this level. The path is additionally checked with `-d` before deletion. The risk is low.

However, if `$HOME` is unset (unlikely but possible in some environments), `STALE_CACHE` becomes `//.claude/...` which would operate on `/`. The skill should guard against an empty `$HOME`:

```bash
[[ -z "$HOME" ]] && { echo "ERROR: HOME is unset — aborting cleanup."; exit 1; }
```

**File:** `skills/silver-update/SKILL.md` — Step 6b

---

**SEC-09 — LOW — silver-add/SKILL.md: OWNER_REPO derived from git remote is unsanitized before use in gh CLI**

```bash
OWNER_REPO=$(echo "$REMOTE" | sed 's|https://github.com/||;s|.git$||;s|git@github.com:||;s|:|/|')
```

`OWNER_REPO` is passed to `gh issue create --repo "$OWNER_REPO"`. The `gh` CLI accepts the repo argument and validates it internally. However, if `$REMOTE` contains shell-special characters, they could be expanded in `echo "$REMOTE"`. Use `printf '%s' "$REMOTE"` instead of `echo "$REMOTE"` for robustness.

Same pattern in `silver-remove/SKILL.md` Step 4b.

**Files:** `skills/silver-add/SKILL.md` §4c, `skills/silver-remove/SKILL.md` §4b

---

### Correctness findings

---

**COR-01 — HIGH — silver-rem/SKILL.md: size cap check has an IS_NEW_FILE logic error**

Step 5, size cap block:
```bash
if [ "$IS_NEW_FILE" = false ]; then
  LINE_COUNT=$(wc -l < "$TARGET")
  if [ "$LINE_COUNT" -ge 300 ]; then
    TARGET="${TARGET%.md}-b.md"
    IS_NEW_FILE=false           # ← ERROR
    [ ! -f "$TARGET" ] && IS_NEW_FILE=true
```

When the -b file does not exist, `IS_NEW_FILE` is set to `true`. But the header-creation block in Step 5 (which runs based on `IS_NEW_FILE`) has already executed for the original file. The -b file's header creation depends on `IS_NEW_FILE=true` after the suffix update — but the Step 5 header-creation block is only described as running "in Step 5" before this check. The instruction says: "If the -b file is also new, create it with the correct header (same as above)" — but this is described only in a comment, not as explicit executable instructions with the actual content.

**Risk:** If the -b file does not exist, Step 6 appends to an uncreated file (relying on `>>` to create it), but the file will lack the correct YAML frontmatter and heading structure defined in Step 5. The entry will be appended to an empty file with no header.

**Fix:** Make Step 5's "create -b file with header" a concrete, executable instruction block (not a comment), placed after the suffix update logic, with the full template content for both knowledge and lessons types.

**File:** `skills/silver-rem/SKILL.md` — Step 5

---

**COR-02 — HIGH — silver-rem/SKILL.md: INDEX.md update does not cover -b file creation**

Step 7 runs ONLY when `IS_NEW_FILE=true`. But when the -b file is created (capacity overflow), `IS_NEW_FILE` is reset to `true` for the -b file. This means Step 7 will attempt to update `docs/knowledge/INDEX.md` again with the -b file's name (e.g., `2026-04-b.md`) — adding a second row for the same month but with the wrong filename.

Alternatively, if the -b file creation doesn't trigger Step 7 (depending on control flow), the INDEX.md won't be updated at all for the new -b file. Either outcome is wrong.

**Fix:** Step 7 should be skipped when the target is a -b (or later suffix) file. Only the first file creation for a month triggers INDEX.md update. Add an explicit guard: `if [ "$IS_NEW_FILE" = true ] && [[ "$TARGET" != *-b.md ]] && [[ "$TARGET" != *-c.md ]]`.

**File:** `skills/silver-rem/SKILL.md` — Step 7

---

**COR-03 — HIGH — silver-add/SKILL.md: knowledge cache write uses --argjson for PROJ_NUM but the field is read as a string elsewhere**

Step 4d cache write:
```bash
jq \
  --arg owner "$OWNER" \
  --argjson num "$PROJ_NUM" \   # ← writes number type
  ...
  '._github_project = {owner:$owner, number:$num, ...}'
```

But the cache read in Step 4d reads back `PROJ_NUM` via:
```bash
PROJ_NUM=$(jq -r '._github_project.number' .silver-bullet.json)
```

`jq -r` on a JSON number produces a string (e.g., `"3"`), which is then passed to `gh project item-add "$PROJ_NUM"`. This is fine for CLI use. However, if `$PROJ_NUM` from discovery is empty or non-numeric (e.g., the API returned null), `--argjson num ""` will fail with a jq parse error, crashing the cache write.

**Fix:** Add a numeric validation check before the cache write: `[[ "$PROJ_NUM" =~ ^[0-9]+$ ]]` or use `--arg` instead of `--argjson` (strings work equally well for `gh project item-add`).

**File:** `skills/silver-add/SKILL.md` — Step 4d

---

**COR-04 — HIGH — silver-scan/SKILL.md: ITEMS_REJECTED counter is never incremented in Step 6**

Step 2 initializes `ITEMS_REJECTED=0`. Step 6-iv says "Increment `ITEMS_REJECTED`" but the summary in Step 9 uses `ITEMS_REJECTED`. However, the skill instructions do not provide the actual increment command in Step 6-iv — only "Increment ITEMS_REJECTED" as prose. Since Claude executes these as instructions, the increment will happen conceptually but there's no explicit shell command shown. This creates inconsistency with the other counters (ITEMS_FILED, ITEMS_STALE) which also have only prose instructions. This is borderline between a style issue and a correctness issue.

More critically: `CANDIDATE_COUNT` is incremented in Step 6-iii (user answers Y), but the Step 9 summary calls it "Presented to you" — which should be the count of all candidates presented (Y + n), not just those filed. The counter semantics are wrong: `CANDIDATE_COUNT` should be incremented regardless of user choice, not only on Y.

**File:** `skills/silver-scan/SKILL.md` — Steps 6 and 9

---

**COR-05 — MEDIUM — silver-release/SKILL.md Step 9b.2: awk section extractor does not handle files with no `## Items Filed` section**

```bash
section=$(awk '/^## Items Filed$/{found=1; next} found && /^## /{exit} found{print}' "$log")
```

If the log file has no `## Items Filed` section, `found` never becomes 1, and `section` is empty — correct behavior. But if `## Items Filed` is the last section in the file (no subsequent `## ` heading), `awk` will print all remaining lines until EOF, which is correct. This edge case is handled implicitly.

However, the check `! echo "$section" | grep -q "^(none)$"` uses a parenthesized pattern, which is an extended regex, but `grep` default mode treats `(` as a literal character. The intended check is to skip sections that contain only the placeholder `(none)`. The correct pattern would be `grep -qE '^\(none\)$'` (with `-E` for extended regex and escaped parens) or `grep -qF '(none)'`.

**Fix:** Change to `grep -qF '(none)'` or `grep -qE '^\(none\)$'`.

**File:** `skills/silver-release/SKILL.md` — Step 9b.2

---

**COR-06 — MEDIUM — silver-rem/SKILL.md: heading-append logic doesn't place entry under the correct category heading**

Step 6, knowledge entry path:
```bash
if grep -q "^## ${CATEGORY}$" "$TARGET"; then
  printf "\n%s — %s\n" "$(date +%Y-%m-%d)" "$INSIGHT" >> "$TARGET"
```

When the heading exists, the entry is appended to the **end of the file** — not immediately after the category heading. A knowledge file with multiple headings (`## Architecture Patterns`, `## Known Gotchas`, etc.) will have all entries from every session appended at the bottom, not grouped under their respective headings.

This creates a structurally incorrect file where entries are not sorted by category. When a reader (or silver-scan) looks at `## Known Gotchas`, the section appears empty, but the actual entries are at the end of the file.

**Fix:** Use `awk` or `sed` to insert the entry immediately after the category heading, not `>>` to append to end of file.

**File:** `skills/silver-rem/SKILL.md` — Step 6

---

**COR-07 — MEDIUM — silver-scan/SKILL.md: path validation regex may not work as a bash case pattern**

Step 3a specifies:
> each path must match the pattern `docs/sessions/[^/]+\.md` relative to project root; reject any path containing `..` or absolute path components

The validation is described as a string-match check but is not given as executable bash. The `ls docs/sessions/*.md` glob in Step 2 naturally prevents `..` and absolute paths from appearing in output (globs don't produce `..` entries), but the skill does not show the actual validation code — only describes it. Since this is an agentic instruction file (Claude follows the instructions), the absence of executable code means Claude must infer the implementation, which may be inconsistent.

**File:** `skills/silver-scan/SKILL.md` — Step 3a

---

**COR-08 — MEDIUM — silver-add/SKILL.md: local filing does not validate that ITEM_TITLE is ≤72 chars before appending**

Step 3 says `ITEM_TITLE` must not exceed 72 characters, but Step 5e appends the title without any truncation or validation check. If `ITEM_TITLE` exceeds 72 characters, it is written to the file as-is. While this is not data-corrupting, it violates the stated invariant.

For GitHub filings, the GitHub API will reject titles over 256 characters (returns 422), which would surface as a `gh` CLI error. But for local filings, there is no enforcement.

**File:** `skills/silver-add/SKILL.md` — Step 5e

---

**COR-09 — LOW — silver-remove/SKILL.md: `gh issue close --reason "not planned"` may fail on older gh CLI versions**

The `--reason` flag for `gh issue close` was added in `gh` CLI v2.20.0 (2023). Older installations (still common on Linux systems) will fail with "unknown flag: --reason". The skill does not document the minimum required `gh` version or provide a fallback.

**File:** `skills/silver-remove/SKILL.md` — Step 4d

---

**COR-10 — LOW — silver-release/SKILL.md Step 9b.1: PREV_TAG derivation is fragile for first-ever release**

```bash
PREV_TAG=$(git tag --sort=version:refname | grep '^v[0-9]' | tail -2 | head -1)
```

On the very first release (only one tag exists), `tail -2 | head -1` returns the only tag — not the "second-to-last" tag. `git log "$PREV_TAG" -1` would then return the commit for the current release, not the previous one, making `MILESTONE_START` equal to the current release date. Session logs from the entire milestone would be excluded if they preceded the tag date.

The edge-case instructions say "use `MILESTONE_START="1970-01-01"`" when `PREV_TAG` is empty, but this case (exactly one tag) is not handled — `PREV_TAG` will be non-empty but wrong.

**File:** `skills/silver-release/SKILL.md` — Step 9b.1

---

### Performance findings

---

**PERF-01 — MEDIUM — silver-add/SKILL.md: project board discovery runs up to 3 separate gh CLI calls per invocation when cache is cold**

Steps 4d-4e make at minimum 3 sequential `gh` API calls when the cache is cold: `gh project list`, `gh project field-list`, then `gh project item-add` + `gh project item-edit`. Each call opens a new HTTPS connection to api.github.com. For projects with large numbers of projects on the owner's account, `gh project list` returns paginated results, potentially requiring multiple calls.

The cache mitigates this for subsequent invocations. The first-run cold-cache scenario is acceptable. However, the skill should note the expected call count and latency for user expectation setting.

**Severity:** Low for correctness, medium for user experience on first use.

**File:** `skills/silver-add/SKILL.md` — Step 4d

---

**PERF-02 — MEDIUM — silver-scan/SKILL.md: re-scans all session logs twice (Steps 3 and 7 are separate passes)**

Steps 3 and 7 both iterate over the full `SESSION_LOGS` list — once for deferred items and once for knowledge/lessons. For projects with many session logs, this doubles the file I/O. A single-pass approach would read each file once, collecting both deferred-item signals and K/L signals simultaneously.

This is a design simplification that improves readability at the cost of efficiency. At current expected session log counts (<100 files, each <50KB), the impact is negligible. Noted for completeness.

**File:** `skills/silver-scan/SKILL.md` — Steps 3 and 7

---

**PERF-03 — LOW — session-log-init.sh: _insert_before function creates a tmpfile for every missing section**

Lines 97–107 define `_insert_before` which creates a tmpfile with `mktemp`, runs `awk`, and does `mv`. For a session log missing all three optional sections (`## Pre-answers`, `## Skills flagged at discovery`, `## Skill gap check`), this function is called 3 times sequentially, each creating and deleting a tmpfile. At the scale of a daily session startup, this is negligible.

**File:** `hooks/session-log-init.sh` — `_insert_before` function

---

### Maintainability findings

---

**MAINT-01 — HIGH — silver-add/SKILL.md and silver-rem/SKILL.md: session log discovery code is duplicated verbatim across three skills**

The session log discovery pattern:
```bash
SESSION_LOG=$(ls docs/sessions/*.md 2>/dev/null | sort | tail -1)
```
appears identically in `silver-add` Step 6, `silver-rem` Step 8, and is described (not shown) in `silver-scan` Step 2. The dedup logic and edge-case handling (empty result → skip silently) is also duplicated.

If the session log naming convention changes (e.g., to a different directory or timestamp format), all three skills must be updated in sync. A shared reference or factored "locate session log" step would reduce this risk.

**Files:** `skills/silver-add/SKILL.md` §6, `skills/silver-rem/SKILL.md` §8, `skills/silver-scan/SKILL.md` §2

---

**MAINT-02 — HIGH — silver-feature/SKILL.md and silver-ui/SKILL.md: deferred-item capture blocks are near-identical**

The "Deferred-Item Capture (mandatory)" block added to silver-feature (Step 7), silver-bugfix (Step 7a), silver-ui (Step 12b), silver-devops (Step 8), and silver-fast (Step 2) is structurally identical across all five files — same Skill invocation, same classification rubric, same minimum bar, same wording.

Any policy change to the deferred-item classification rubric (e.g., adding a new label type) requires updating five separate SKILL.md files. This creates a maintenance hazard.

**Files:** `skills/silver-feature/SKILL.md`, `skills/silver-bugfix/SKILL.md`, `skills/silver-ui/SKILL.md`, `skills/silver-devops/SKILL.md`, `skills/silver-fast/SKILL.md`

---

**MAINT-03 — MEDIUM — silver-add/SKILL.md: classification rubric is duplicated from silver-bullet.md §3b-i**

The classification rubric in `silver-add` Step 3 (issue vs. backlog definitions) is nearly word-for-word identical to the rubric in `silver-bullet.md` §3b-i and the deferred-item capture blocks in all orchestrator skills. The rubric definition exists in at least 7 places. Divergence over time is likely.

**Files:** `skills/silver-add/SKILL.md` §3, `silver-bullet.md` §3b-i, orchestrator skills

---

**MAINT-04 — MEDIUM — silver-rem/SKILL.md: Step 7 INDEX.md mutation described in prose without executable code**

Step 7 describes the INDEX.md mutations ("Find the last row of the markdown table and insert a new row after it", "Replace the line starting with `Latest knowledge:`") entirely in prose, with only a minimal bash stub:
```bash
TMP=$(mktemp)
# Read INDEX.md, perform both mutations, write to TMP
mv "$TMP" docs/knowledge/INDEX.md
```

The comment `# Read INDEX.md, perform both mutations, write to TMP` is not executable. Claude must infer the awk/sed implementation at runtime. This is an instruction gap — the two mutations are non-trivial (table row insertion and pointer-line replacement) and could be implemented inconsistently across invocations.

**Fix:** Provide explicit awk/sed commands for both mutations, as was done for the heading-insertion in Step 6.

**File:** `skills/silver-rem/SKILL.md` — Step 7

---

**MAINT-05 — MEDIUM — silver-scan/SKILL.md: keyword grep list is hardcoded with no extensibility mechanism**

Step 3b-ii scans for: `deferred`, `TODO`, `FIXME`, `tech-debt`, `out of scope`, `unfinished`, `skip`, `later` (case-insensitive). This list is hardcoded in the skill instructions. Users who use project-specific conventions (e.g., `DEFER:`, `BLOCKED:`, `WONTFIX`) have no way to add keywords without modifying the SKILL.md.

**Suggestion:** Add a note that the keyword list can be extended via a `.silver-bullet.json` field (e.g., `"scan_keywords": [...]`), even if not implemented in v0.25.0, to signal the intended extensibility path.

**File:** `skills/silver-scan/SKILL.md` — Step 3b-ii

---

**MAINT-06 — MEDIUM — .silver-bullet.json: version field is 0.23.8 but release is 0.25.0**

The `version` field in `.silver-bullet.json` reads `"0.23.8"` — two minor versions behind the release being prepared. This is likely a missed update rather than intentional.

Also: the `templates/silver-bullet.config.json.default` has `"version": "0.11.0"` and `"config_version": "0.12.1"` — these are the template defaults for user projects, not the plugin version, so they have different semantics. But this is potentially confusing.

**File:** `.silver-bullet.json` — top-level `"version"` field

---

**MAINT-07 — MEDIUM — silver-release/SKILL.md: Step 9b is self-contained but references `docs/sessions/*.md` without using the shared session-log pattern**

Step 9b.2 implements its own session log scanning loop inline, rather than delegating to silver-scan or using the shared discovery pattern. This means three separate implementations of session-log discovery now exist (silver-add, silver-rem, silver-release). Any change to the session log format or directory requires updating all three independently.

**File:** `skills/silver-release/SKILL.md` — Step 9b.2

---

**MAINT-08 — LOW — silver-forensics/SKILL.md: FLOW numbering reference in Recommended Next Steps table is inconsistent with the flow catalog in silver-bullet.md**

The "Recommended Next Steps" table in the post-mortem report template references `/gsd:discuss-phase`, `/gsd:debug`, `/gsd:resume-work`, `/gsd:execute-phase`, `/gsd:verify-work` — these are direct GSD commands. The broader silver-bullet.md ecosystem has migrated to FLOW-numbered references (FLOW 5, FLOW 7, FLOW 11, etc.) and `/silver-feature` orchestration. The forensics output table still uses legacy direct GSD command references, which may confuse users on whether to invoke the GSD command directly or go through silver orchestration.

**File:** `skills/silver-forensics/SKILL.md` — Post-mortem Report, Recommended Next Steps table

---

**MAINT-09 — LOW — silver-add/SKILL.md: rate-limit retry strategy (Step 4e) uses hardcoded sleep durations (60s/120s/240s)**

The exponential-ish backoff (60s → 120s → 240s) is hardcoded in the instructions. GitHub's secondary rate limit documentation recommends starting at 60s and is not prescriptive about subsequent intervals. If GitHub's guidance changes, the skill must be manually updated.

No actionable fix beyond documentation — hardcoded retry durations are acceptable for this use case.

**File:** `skills/silver-add/SKILL.md` — Step 4e

---

**MAINT-10 — LOW — silver-bullet.md: §5.1 version check uses legacy registry key `silver-bullet@silver-bullet`**

Section 5.1:
```bash
cat "$HOME/.claude/plugins/installed_plugins.json" | jq -r '.plugins["silver-bullet@silver-bullet"][0].version // "unknown"'
```

`silver-update` Step 1 reads the `silver-bullet@alo-labs` key first and falls back to `silver-bullet@silver-bullet`. But `silver-bullet.md` §5.1 only checks the legacy key. After a marketplace update (via `silver-update`), the legacy key is deleted — `§5.1` would then always report `"unknown"` version and prompt an update loop.

**Fix:** Mirror the two-key fallback from `silver-update` Step 1 into `silver-bullet.md` §5.1:
```bash
jq -r '.plugins["silver-bullet@alo-labs"][0].version // .plugins["silver-bullet@silver-bullet"][0].version // "unknown"'
```

**File:** `silver-bullet.md` — §5.1

---

**MAINT-11 — LOW — templates/silver-bullet.config.json.default: missing `_notifications_comment` from live config**

The live `.silver-bullet.json` includes:
```json
"_notifications_comment": "Google Chat webhook is now read from the $SB_GCHAT_WEBHOOK env var..."
```

This comment-field is absent from `templates/silver-bullet.config.json.default`. New projects initialized from the template will not get this helpful reminder, and may inadvertently commit webhook URLs to their `.silver-bullet.json`.

**File:** `templates/silver-bullet.config.json.default`

---

### Summary

| Severity | Count | Items |
|----------|-------|-------|
| Critical | 0 | — |
| High | 5 | SEC-01, SEC-02, COR-01, COR-02, COR-03 |
| Medium | 12 | SEC-04, SEC-05, SEC-06, COR-04, COR-05, COR-06, COR-07, COR-08, PERF-01, PERF-02, MAINT-01, MAINT-02, MAINT-03, MAINT-04, MAINT-05, MAINT-06, MAINT-07 |
| Low | 10 | SEC-07, SEC-08, SEC-09, COR-09, COR-10, PERF-03, MAINT-08, MAINT-09, MAINT-10, MAINT-11 |

**Total: 0 critical, 5 high, 14 medium, 10 low — 29 findings**

### Priority fix list before release

1. **SEC-01** — Fix the project-scope OAuth check in silver-add Step 4a (will silently pass without `project` scope today)
2. **COR-01** — Provide executable header-creation instructions for -b overflow files in silver-rem Step 5
3. **COR-02** — Guard Step 7 INDEX.md update against -b suffix files in silver-rem
4. **COR-06** — Fix entry-placement in silver-rem Step 6 to insert under the correct category heading rather than appending to EOF
5. **MAINT-10** — Update silver-bullet.md §5.1 to check both registry keys (prevents infinite update-prompt loop after marketplace install)
6. **SEC-02** — Tighten ID digit-validation in silver-remove to require at least one digit after the prefix
7. **COR-03** — Add numeric validation before `--argjson num` cache write in silver-add Step 4d
8. **COR-05** — Fix `grep -q "^(none)$"` to use `-F` or `-E` in silver-release Step 9b.2

### Items suitable for backlog (not pre-release blocking)

- MAINT-01/02/03: Session log discovery and deferred-capture block deduplication — refactoring work, no user-facing defect
- MAINT-04: Executable awk/sed for INDEX.md mutations — current prose is functional but brittle
- MAINT-05: Scan keyword extensibility via config — enhancement
- MAINT-06: `.silver-bullet.json` version field sync — cosmetic
- SEC-04/05/09: printf format-specifier and echo/printf robustness hardening — defense-in-depth, no known exploit path
- PERF-01/02/03: Performance observations — acceptable at current scale
