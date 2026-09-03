# Pre-Release Code Review — Layer B (Peer Review)
## Round 1

**Reviewed:** 2026-04-24
**Reviewer:** Peer (Claude Sonnet 4.6)
**Files Reviewed:** 11
**Depth:** Full file read + cross-file consistency analysis

---

### CRITICAL findings

#### CRIT-B-01: `silver-bullet.md §5.1` reads from stale registry key after `silver-update` runs — will trigger false update prompt every session

**Files:** `silver-bullet.md:22`, `templates/silver-bullet.md.base:22`, `skills/silver-update/SKILL.md:15,144`

**Issue:** There is a structural mismatch in how the two components access `installed_plugins.json`:

- `silver-bullet.md §5.1` (and the identical template line) reads: `.plugins["silver-bullet@silver-bullet"][0].version`
- `silver-update` Step 6a cleanup uses: `."silver-bullet@silver-bullet"` (top-level key, no `.plugins` prefix)

These two jq paths reference different JSON structures. After `silver-update` runs successfully and removes the legacy `silver-bullet@silver-bullet` key (Step 6a), it installs under `silver-bullet@alo-labs`. But §5.1 only reads from the old key (`.plugins["silver-bullet@silver-bullet"]`). On every subsequent session startup, the §5.1 jq query will return `"unknown"`, which the instructions say means "skip update" — so it does not trigger an endless update loop, but the installed version will always display as `"unknown"` even on a freshly updated installation.

Additionally, `silver-update` Step 1 says to try the `alo-labs` key first (new install path) and fall back to the `silver-bullet` key (legacy), but provides no explicit jq command for this read. Meanwhile, §5.1 reads only from the legacy key. Post-update, the version check is broken.

**Fix:** Align §5.1's jq path with how `silver-update` Step 6a accesses the registry — either both use `.plugins["key"][0].version` or both use `."key".version`. If the actual registry structure uses the `.plugins` nesting, then Step 6a's cleanup jq must also use `.plugins` prefix.

---

#### CRIT-B-02: `silver-rem` hardcodes "Silver Bullet" as the project name in generated knowledge file YAML front matter

**File:** `skills/silver-rem/SKILL.md:121`

**Issue:** Step 5 creates new knowledge monthly files with this hardcoded header:

```yaml
---
project: Silver Bullet
period: ${MONTH}
type: knowledge
---
```

This SKILL.md is a general-purpose SB skill installed in user projects via the plugin. Any project that calls `/silver-rem` will have its knowledge files tagged `project: Silver Bullet` regardless of the actual project name. When multiple projects use this skill, all knowledge files will carry the same wrong project label.

**Fix:** Read the project name from `.silver-bullet.json` (`jq -r '.project.name // "unknown"' .silver-bullet.json`) and use that value instead of the hardcoded string. Since Step 1 already locates the project root, the config file is available.

---

### HIGH findings

#### HIGH-B-01: `silver-add` Step 4e on rate-limit exhaustion says "proceed to Step 7" — skips the session log step

**File:** `skills/silver-add/SKILL.md:219`

**Issue:** The rate-limit retry failure message instructs: "proceed to Step 7 with a warning. Do NOT proceed to Step 6." Step 6 is the session log append step, Step 7 is the output confirmation. Intentionally skipping Step 6 means that when rate limiting causes board placement to fail, the filing is not recorded in the session log. This creates a silent gap: the user sees a terminal warning but the session log has no record of the filed item.

The companion message in Step 4d (board not found) says "proceed to Step 6" (the correct path), making Step 4e's "skip Step 6" instruction an inconsistency — both are partial success cases where the issue was created but board placement failed.

**Fix:** Remove the "Do NOT proceed to Step 6" instruction from the rate-limit failure path. Both partial-success paths (board not found, and rate limit exhausted) should proceed to Step 6 (log the filing) and then Step 7 (output confirmation with warning). The session log should always capture what was filed.

---

#### HIGH-B-02: `silver-rem` size-cap block creates the `-b` file's header implicitly — actual creation code is absent

**File:** `skills/silver-rem/SKILL.md:163-175`

**Issue:** The size-cap logic (Step 5, end) updates `TARGET` to the `-b` suffix file and updates `IS_NEW_FILE` appropriately, but includes only a comment `# If the -b file is also new, create it with the correct header (same as above)` with no actual code. When execution proceeds to Step 6, if the `-b` file is new and this branch was taken, the append happens without a header having been created. The resulting file will start mid-content without YAML front matter or category headings.

The Step 5 IS_NEW_FILE=true creation blocks at the top of Step 5 are already past when the size-cap code runs. The spec states "If the -b file is also new, create it with the correct header" but leaves the implementation to inference.

**Fix:** The size-cap block should either: (a) call the same header-creation code as the top of Step 5 when `IS_NEW_FILE=true` after the suffix update, or (b) explicitly duplicate the `cat > "$TARGET" << EOF` block for the `-b` case within the size-cap code.

---

#### HIGH-B-03: `silver-remove` Step 2's `case` validation fires before Step 3's config read — reads config twice for GitHub IDs

**File:** `skills/silver-remove/SKILL.md:55-67`

**Issue:** Step 2 validates the ID format and, for `github`/`github-raw` IDs, states "read `TRACKER` from config" to validate that GitHub integration is configured. But `TRACKER` is formally set in Step 3. For local (`SB-I-*`/`SB-B-*`) IDs, TRACKER is set in Step 3 and read once. For GitHub IDs, TRACKER is read in Step 2 (inline, undocumented as a command) and then read again in Step 3.

While not a crash, the double-read is confusing and inconsistent. More importantly, the Step 2 inline config read is implied but not specified — it gives no jq command, no error handling if `.silver-bullet.json` is absent at that point, and no reference to whether Step 1 (root location) has already run. The sequencing leaves an execution gap: what if Step 2 runs before the agent walks up to find the project root (Step 1)?

The steps as written imply: "Step 1 → Step 2 → Step 3", but Step 2 needs config data that Step 3 is supposed to provide.

**Fix:** Move the "if GitHub ID, check TRACKER" validation logic into Step 3, which already reads TRACKER. Step 2 should only validate the format and set `ID_TYPE` and `ISSUE_NUM` — all config-dependent decisions belong in Step 3.

---

#### HIGH-B-04: `silver-scan` does not cross-reference `docs/issues/ISSUES.md` or `docs/issues/BACKLOG.md` for already-filed local deferred items

**File:** `skills/silver-scan/SKILL.md:104-114`

**Issue:** Step 4's stale check uses only git log and CHANGELOG.md (and optionally GitHub issues API). For projects using `issue_tracker=gsd` (or absent), filed items live in `docs/issues/ISSUES.md` and `docs/issues/BACKLOG.md`. Silver-scan has no step that reads these local files to exclude already-filed candidates.

This means: if a deferred item was previously filed via `/silver-add` to a local docs/issues file but was not committed to git (or the commit message doesn't contain the item title), silver-scan will re-present it to the user as a new candidate. The user has to manually remember or recognize duplicates.

**Fix:** Add a Step 4-iv (local docs check): when `issue_tracker != "github"`, run `grep -F "ITEM_TITLE_KEYWORD" docs/issues/ISSUES.md docs/issues/BACKLOG.md 2>/dev/null`. If a match is found, mark item as TRACKED (already filed locally) and skip presentation.

---

### MEDIUM findings

#### MED-B-01: `silver-bullet.md §2d` lists quality-gate-stage markers in the SB state file, but `templates/silver-bullet.md.base §2d` does not — template diverges from live doc

**Files:** `silver-bullet.md:208`, `templates/silver-bullet.md.base` (§2d, no equivalent bullet)

**Issue:** `silver-bullet.md §2d` lists four uses of the SB state file, including "Quality gate stage markers (`quality-gate-stage-1` through `quality-gate-stage-4`)". The corresponding `templates/silver-bullet.md.base §2d` lists only three uses (skill invocation markers, session mode, session init sentinel) — omitting the quality gate stage markers.

This is partially intentional (the Pre-Release Quality Gate section is SB-project-only and not templated), but §2d is the authoritative inventory of state file usage. A mismatch here creates confusion about what the state file contains, particularly for developers working across both files.

**Recommendation:** If the Pre-Release Quality Gate section is intentionally omitted from the template (confirmed by §9 absence), §2d in the template should also explicitly note "quality-gate-stage markers are not used in end-user projects" or simply omit the marker type entirely from the template's §2d.

---

#### MED-B-02: `templates/silver-bullet.md.base §9` heading says "User Workflow Preferences" but its subsections are labeled `10a` through `10e` — numbering mismatch

**Files:** `templates/silver-bullet.md.base:771,778,782,786,790,794`

**Issue:** The template's final section is `## 9. User Workflow Preferences` (line 771), but all subsections within it are labeled `### 10a.`, `### 10b.`, through `### 10e.` (lines 778-794). This is inconsistent: a `§9` section should have `### 9a.`, `### 9b.`, etc.

The live `silver-bullet.md` correctly has `## 10. User Workflow Preferences` with `### 10a.`-`### 10e.` subsections because it has `§9 Pre-Release Quality Gate` before it. The template skips §9 (no Pre-Release Quality Gate) but inherited the `10a`-`10e` subsection labels without renumbering them.

**Fix:** Either (a) rename the template subsections to `9a`-`9e` to match the template's `§9` heading, or (b) add a placeholder `§9 Pre-Release Quality Gate` section to the template so the numbering is consistent with the live doc.

---

#### MED-B-03: `templates/silver-bullet.md.base §9` Mode Preferences table contains project-specific live data

**File:** `templates/silver-bullet.md.base:794-799`

**Issue:** The template's Mode Preferences table (`### 10e. Mode Preferences`) contains:

```
| Default session mode | autonomous | 2026-04-16 |
| PR branch | ask | (set at first use) |
| TDD enforcement | per-plan-type | (default) |
```

These are the Silver Bullet project's specific runtime preferences, not defaults that every new project should inherit. A user running `/silver:init` to initialize a new project gets a `silver-bullet.md` seeded with these non-default preferences. Specifically, "Default session mode: autonomous" would auto-set autonomous mode on day 1 for new projects — potentially surprising.

**Fix:** The template's preference tables should ship empty (header rows only) or with clearly neutral defaults. Remove the three data rows from the Mode Preferences table in the template, or reset them to: `| Default session mode | interactive | (not set) |`.

---

#### MED-B-04: `silver-add §3 → §2` flow inconsistency — Step 2 routing says "proceed to Step 4 after classification" but classification happens in Step 3

**File:** `skills/silver-add/SKILL.md:58-59`

**Issue:** Step 2 (Read configuration) says:

> "If `TRACKER` = `"github"` → proceed to Step 4 after classification."
> "If `TRACKER` = `"gsd"` or absent → proceed to Step 5 after classification."

The phrase "after classification" refers to Step 3, which correctly follows Step 2. However, the wording implies the routing decision should be made now (in Step 2) and then classification runs (Step 3), then the pre-decided route is taken. This is awkward: the decision about which step to take after Step 3 is stated in Step 2, before the user even reads Step 3.

A reader following the instructions linearly could interpret this as: "skip Step 3 and go to Step 4/5 directly." The parenthetical "after classification" prevents this misreading, but it is easy to miss.

**Fix:** Move the routing decision statement to the end of Step 3 (after the classification rubric), where it is contextually obvious that the next step depends on the result of both TRACKER and ITEM_TYPE.

---

#### MED-B-05: `silver-rem` Step 6 knowledge entry format is a plain date-prefixed line — no bullet marker — but `silver-scan` Step 7a-i expects "bullet points" from `## Knowledge & Lessons additions` section

**Files:** `skills/silver-rem/SKILL.md:190,193`, `skills/silver-scan/SKILL.md:165`

**Issue:** `silver-rem` Step 6 appends entries in this format:

```
YYYY-MM-DD — INSIGHT_TEXT
```

No bullet marker (`-`). Meanwhile, `silver-scan` Step 7a-i says it looks for "Each bullet point is a candidate insight" in the `## Knowledge & Lessons additions` section of session logs.

The inconsistency is that `silver-rem` writes to `## Items Filed` (not to `## Knowledge & Lessons additions`) using `printf -- '- [%s]: %s — %s\n'` (with bullet marker). The `## Knowledge & Lessons additions` section in session logs is described as "legacy format (session logs before Phase 51)" — its bullet or non-bullet format is not defined anywhere in these files.

This ambiguity means silver-scan's legacy extraction behavior (7a-i) is underspecified for the current session log format. If `## Knowledge & Lessons additions` was populated by documentation steps rather than silver-rem, its format may or may not use bullets.

**Recommendation:** Add a note in silver-scan Step 7a-i specifying exactly what format `## Knowledge & Lessons additions` entries use (bulleted or plain lines), so the grep/extraction approach is well-defined.

---

#### MED-B-06: `silver-remove` Step 5d uses `sed -i ''` (BSD sed, macOS-only) — will fail on Linux

**File:** `skills/silver-remove/SKILL.md:34,171`

**Issue:** The Allowed Commands section explicitly labels `sed -i ''` as "BSD sed, macOS — inline heading replacement." The command `sed -i ''` with an empty-string backup suffix is a macOS/BSD-specific syntax. On GNU/Linux, in-place edit uses `sed -i` (no empty string argument). The two forms are not compatible — macOS `sed -i 'suffix'` where suffix is empty is the equivalent of GNU `sed -i`.

If Silver Bullet is used on Linux (e.g., in a Docker container, CI runner, or WSL environment), Step 5d will fail with: `sed: 1: "s|...": extra characters at the end of s command` or similar.

**Fix:** Use a tmpfile+mv approach (already listed in Allowed Commands) instead of `sed -i`:

```bash
TMP=$(mktemp)
sed "s|^### ${ITEM_ID} —|### [REMOVED ${DATE}] ${ITEM_ID} —|" "$TARGET_FILE" > "$TMP" && mv "$TMP" "$TARGET_FILE"
```

This is portable across BSD and GNU sed and is consistent with the atomic-write pattern used elsewhere in the skill suite.

---

### LOW/INFO findings

#### LOW-B-01: `silver-add` Step 4a scope check may produce false positive — "project" matches in non-scope parts of `gh auth status` output

**File:** `skills/silver-add/SKILL.md:107-112`

**Issue:** The check `gh auth status 2>&1 | grep -q "project"` looks for the literal string "project" anywhere in the output. The `gh auth status` output includes lines like "Logged in to github.com as user (..." and "Token scopes: ...". If the user's GitHub username, organization name, or an account description contains the word "project" (e.g., username `myproject-bot`), the grep would match even without the `project` OAuth scope being present. This would silently skip the scope warning and proceed to a Step 4d discovery attempt that then fails because the scope is actually absent.

**Recommendation:** Use a more targeted pattern: `grep -qE '^\s*(Token scopes|Scopes):.*\bproject\b'` to match only in the scopes line.

---

#### LOW-B-02: `silver-scan` Step 4-iii "TRACKED" state for open GitHub issues is introduced but has no summary counter

**File:** `skills/silver-scan/SKILL.md:112-113`

**Issue:** Step 4-iii introduces a TRACKED status for open GitHub issues (already filed, so skip presentation). However, the Step 9 summary block has no counter for TRACKED items — only `ITEMS_STALE` and `ITEMS_REJECTED` are tracked. A user cannot tell from the summary how many open GitHub issues were silently suppressed as already-tracked.

**Recommendation:** Add a `ITEMS_TRACKED` counter initialized to 0 in Step 2, incremented in Step 4-iii, and shown in the Step 9 summary alongside `ITEMS_STALE`.

---

#### LOW-B-03: `silver-rem` Step 8's `printf` for session log uses `${INSIGHT:0:60}` bash substring — not portable to `sh`

**File:** `skills/silver-rem/SKILL.md:272,277`

**Issue:** `${INSIGHT:0:60}` is bash-specific substring syntax. The skill's shebang is not shown, and silver-rem does not declare itself as requiring bash. The Allowed Commands section lists `printf` and `cat` but doesn't restrict the shell. If an environment uses `sh` or `dash`, this would fail silently (the variable would expand to its full value or fail).

**Recommendation:** Add a note that the skill requires bash (or that the agent should ensure a bash context), or replace the bash-specific substring with a POSIX-compatible alternative: `echo "$INSIGHT" | cut -c1-60`.

---

#### LOW-B-04: `silver-forensics` Path 1 step 4 references `.planning/ROADMAP.md` but the artifact lives at `.planning/ROADMAP.md` only in old GSD layouts — newer projects use `.planning/phases/` structure

**File:** `skills/silver-forensics/SKILL.md:139`

**Issue:** Path 1 step 4 says: "Read `.planning/ROADMAP.md` to enumerate planned phases." This is correct for GSD projects, but the verification of phase completion uses a legacy path: "check whether `.planning/{phase}-VERIFICATION.md` exists." In newer GSD layouts, VERIFICATION.md lives at `.planning/phases/{phase}/VERIFICATION.md`, not directly under `.planning/`.

The `§3d` table in `silver-bullet.md` confirms the artifact location as `.planning/phases/{phase}/` — so silver-forensics Path 1 step 4's path reference is stale.

**Recommendation:** Update Path 1 step 4 to check `.planning/phases/*/VERIFICATION.md` rather than `.planning/{phase}-VERIFICATION.md`.

---

#### LOW-B-05: `.silver-bullet.json` (project config) is missing `config_version`, `issue_tracker`, `compactPrompt`, `required_deploy_devops`, and `forbidden` keys present in the template

**Files:** `.silver-bullet.json`, `templates/silver-bullet.config.json.default`

**Issue:** The SB project's own config (`.silver-bullet.json`) is missing several keys that exist in the template default:
- `config_version` (schema version tracking)
- `issue_tracker` (the template defaults to `"gsd"`)
- `compactPrompt` (compact instruction preservation hint)
- `skills.required_deploy_devops` (devops deploy gate list)
- `skills.forbidden` (forbidden skill enforcement)

While some omissions may be intentional (the SB project uses a custom `issue_tracker` absent, `forbidden` is empty), the missing `config_version` means the SB project's own config doesn't track the schema version, and `required_deploy_devops` means devops workflow skill gating is undefined for SB itself.

**Recommendation:** Either add the missing keys with appropriate values to `.silver-bullet.json`, or document in `.silver-bullet.json` (via a comment key like `_omissions_comment`) why they are intentionally absent.

---

#### LOW-B-06: `silver-scan` Step 3's keyword grep list includes "skip" — high false-positive rate for common developer notes

**File:** `skills/silver-scan/SKILL.md:89`

**Issue:** Step 3b-ii scans for `skip` (case-insensitive) as a keyword signal. This is an extremely common word in session logs in contexts that are not deferrable items: "skipped formatting check", "CI skipped", "skipping review due to trivial change", "step N skipped per §10", etc. Each such match becomes a LOW-signal candidate that must be presented to the user for Y/n approval.

With the 20-candidate cap, a high-noise keyword like "skip" could fill the candidate list with non-actionable items, crowding out genuinely important HIGH and MEDIUM signal candidates.

**Recommendation:** Either remove "skip" from the keyword list (it produces too many false positives), or require "skip" only in specific section contexts (e.g., only under `## Approach` or `## Task`, not in `## Autonomous decisions` or structured section headers).

---

### Summary

**Total findings: 17** (2 CRITICAL, 4 HIGH, 6 MEDIUM, 5 LOW/INFO)

**Key themes:**

1. **Registry key mismatch (CRIT-B-01):** `silver-bullet.md §5.1` and `silver-update` use different JSON paths to read from `installed_plugins.json`. After a marketplace update, the §5.1 version check will read from the legacy key that was deleted, showing "unknown" indefinitely. This is a functional correctness bug that affects every session startup post-update.

2. **Hardcoded project name (CRIT-B-02):** `silver-rem` stamps "Silver Bullet" into the YAML front matter of knowledge files created for any project. User projects will have wrong project names in all generated knowledge docs.

3. **Template divergence (MED-B-02, MED-B-03):** The template's `§9` section heading doesn't match its `10a`-`10e` subsection labels (numbering mismatch), and the template ships with live Silver Bullet project preferences in the Mode Preferences table that will be applied to all new user projects.

4. **Platform portability (MED-B-06):** `silver-remove` uses `sed -i ''` (BSD/macOS only). Projects running on Linux CI or WSL environments will see failures in the local removal path.

5. **Session log coverage gap (HIGH-B-01):** The rate-limit failure path in `silver-add` intentionally skips the session log step, creating an untracked filing. Both partial-success paths should log to the session.

6. **All-tracked parity:** `all_tracked` arrays in `.silver-bullet.json` and `templates/silver-bullet.config.json.default` are identical — no parity issues found here.

7. **Template/live doc structural parity:** The template intentionally omits §9 Pre-Release Quality Gate (SB-project-only content) — this is by design. However, the subsection numbering and preference table data in the template are actual bugs that need fixing before release.
