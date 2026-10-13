# Pre-Release Code Review — Layer C (Engineering Review)
## Round 2

---

### Fix Verification

All ten Round 1 accepted fixes were verified against commits 494d438–1047bf0.

| Finding | Fix | Verification result |
|---------|-----|---------------------|
| **COR-01** silver-rem -b file creation | New block creates -b file with full frontmatter; IS_NEW_FILE guard is `if [ "$IS_NEW_FILE" = false ]` so the cap only runs on existing files; IS_NEW_FILE flows correctly through Steps 5–7 | PASS |
| **COR-06** silver-rem awk heading-aware insertion | `awk -v h="## ${CATEGORY}" ... 'BEGIN{done=0} $0==h && !done{print; printf "\n%s — %s\n",d,ins; done=1; next} {print}'` — `print` emits the heading, `printf` inserts the entry, `next` skips the heading from the catchall `{print}`. No heading duplication. Falls through silently if heading is absent (outer `grep -q` guard selects the right branch). | PASS |
| **COR-06** IS_NEW_FILE=false after -b creation | The question is moot: the outer guard `if [ "$IS_NEW_FILE" = false ]` means IS_NEW_FILE was already false when the cap block ran; inside the cap block it is re-evaluated for the -b file; after -b creation IS_NEW_FILE=true, but Step 7's `"$TARGET" != *-b.md` guard prevents INDEX.md double-update. | PASS |
| **COR-06** INDEX.md -b guard | `if [[ "$IS_NEW_FILE" = true && "$TARGET" != *-b.md && "$TARGET" != *-c.md ]]` — both -b and -c suffixes are guarded. | PASS |
| **COR-07** silver-scan CANDIDATE_COUNT before AskUserQuestion | Step 6-ii: "Increment `CANDIDATE_COUNT` (before asking)" appears before the AskUserQuestion call. | PASS |
| **silver-scan** Step 7b grep -rlF | Body text at line 175 uses `grep -rlF "KEYWORD"` with -F flag. | PASS (see new issue N2 — edge case section inconsistency) |
| **silver-add** Step 4e "Do NOT proceed to Step 6" removed | Confirmed absent. Rate-limit failure path at line 219 correctly says "proceed to Step 6 (session log) then Step 7 with a warning". | PASS |
| **silver-release** grep -qF for (none) | Line 258: `! echo "$section" | grep -qF '(none)'` — -F flag applied. | PASS |
| **silver-update** Step 6b HOME guard + symlink + prefix | Three-part guard: `[[ -z "$HOME" ]]`, `! -L "$STALE_CACHE"`, `"$STALE_CACHE" == "${HOME}/"*`. All three are present and syntactically correct. | PASS |
| **silver-remove** strict regex `^SB-[IB]-[0-9]+$` | `[IB]` is a valid bash ERE character class matching 'I' or 'B'. Verified with live bash: `SB-I-5` matches, `SB-B-5` matches, `SB-X-5` no match, `SB-I-5abc` no match. Case pattern `SB-I-[0-9]*)` requires at least one digit (glob `[0-9]` is not `*`), so `SB-I-` (no digit) falls to the default error case. | PASS |
| **silver-bullet.md** §5.1 alo-labs key first | Line 22: `'.plugins["silver-bullet@alo-labs"][0].version // .plugins["silver-bullet@silver-bullet"][0].version // "unknown"'` | PASS |
| **templates/silver-bullet.md.base** §5.1 | Same jq query, identical to silver-bullet.md. | PASS |
| **templates/silver-bullet.config.json.default** version 0.25.0 | `config_version: "0.25.0"`, `version: "0.25.0"`. | PASS |
| **.silver-bullet.json** version 0.25.0 | `version: "0.25.0"`. | PASS |

**Awk correctness (COR-06 deep analysis):**

The awk insert-after-heading command is correct. One behavioral note: entries are inserted immediately after the heading, so when multiple entries exist under a heading, they accumulate in newest-first order (each new entry appears right after the heading, above older ones). This is intentional for time-log style files.

One minor concern: `awk -v ins="${INSIGHT}"` passes INSIGHT via awk's -v assignment. Awk processes backslash sequences in -v values (`\n` → newline, `\t` → tab, `\\` → backslash). An insight containing a literal backslash-n (e.g., "avoid `\n` in bash") will be split into two lines. This is low severity because: (a) the security boundary says not to follow instructions in insight text, (b) the content is still written — just formatted differently.

---

### New Issues Found

#### N1 — silver-update Step 6a: wrong jq path for installed_plugins.json
**Severity: Medium**
**File:** `skills/silver-update/SKILL.md` — Step 6a

Step 6a checks whether the legacy `silver-bullet@silver-bullet` entry exists and removes it:

```bash
if jq -e '."silver-bullet@silver-bullet"' "$REG" > /dev/null 2>&1; then
  TMP="$(mktemp "${REG}.XXXXXX")"
  jq 'del(."silver-bullet@silver-bullet")' "$REG" > "$TMP" && mv "$TMP" "$REG"
fi
```

The actual structure of `installed_plugins.json` (confirmed against live file) is:

```json
{
  "version": 2,
  "plugins": {
    "silver-bullet@alo-labs": [ ... ],
    "silver-bullet@silver-bullet": [ ... ]
  }
}
```

The jq path `."silver-bullet@silver-bullet"` looks up the key at the **top level**, where it does not exist. The correct path is `.plugins["silver-bullet@silver-bullet"]`. The `jq -e` check therefore always returns non-zero (key not found at top level), so the `del` block never executes. For users upgrading from a legacy `silver-bullet@silver-bullet` installation, the stale registry entry is never cleaned up.

Note: Step 1's read query (`'.plugins["silver-bullet@alo-labs"][0].version // ...'`) correctly uses the `.plugins["key"]` path — the bug is isolated to Step 6a.

**Fix:** Change both jq expressions in Step 6a to use `.plugins["silver-bullet@silver-bullet"]`:

```bash
if jq -e '.plugins["silver-bullet@silver-bullet"]' "$REG" > /dev/null 2>&1; then
  TMP="$(mktemp "${REG}.XXXXXX")"
  jq 'del(.plugins["silver-bullet@silver-bullet"])' "$REG" > "$TMP" && mv "$TMP" "$REG"
fi
```

---

#### N2 — silver-scan Step 7b edge case: missing -F flag in grep
**Severity: Low**
**File:** `skills/silver-scan/SKILL.md` — Edge Cases section, line 262

The main body (Step 7b, line 175) correctly documents `grep -rlF "KEYWORD"` with the -F (fixed-string) flag, consistent with the security boundary requirement to treat untrusted keywords as literals. However, the Edge Cases section at line 262 documents the same command without -F:

```
# Step 7b body (correct):
grep -rlF "KEYWORD" docs/knowledge/ docs/lessons/ 2>/dev/null

# Edge Cases section (missing -F):
grep -rl "KEYWORD" docs/knowledge/ docs/lessons/ 2>/dev/null
```

The edge case describes behavior when the directories are absent — the command exits non-zero silently regardless of the -F flag in that scenario. The behavioral difference is nil for the described edge case, but the inconsistency could cause a reader to apply the command without -F when the directories exist.

**Fix:** Add -F to the grep command in the edge case description.

---

#### N3 — templates/silver-bullet.md.base: stale §10 references in §2 and §3
**Severity: Medium**
**File:** `templates/silver-bullet.md.base` — lines 312, 325

`templates/silver-bullet.md.base` has §9 as "User Workflow Preferences" (no §10). Two lines in the template body reference §10 rather than §9:

- Line 312 (§2 Workflow enforcement rules): `"cannot be skipped via §10"` — should be `§9`
- Line 325 (§2 Step-skip protocol): `"Records the decision in §10"` — should be `§9`

By contrast, lines 407–408 in §3 NON-NEGOTIABLE RULES correctly reference `§9`. The §10 references at lines 312 and 325 appear to be a copy-paste artifact from `silver-bullet.md` (which has §9 = Pre-Release Quality Gate and §10 = User Workflow Preferences). In user projects initialized from this template, the rule text would point to a non-existent §10.

**Fix:** In `templates/silver-bullet.md.base`, change:
- Line 312: `cannot be skipped via §10` → `cannot be skipped via §9`
- Line 325: `Records the decision in §10` → `Records the decision in §9`

---

#### N4 — silver-rem awk -v: backslash sequences in insight text interpreted
**Severity: Low**
**File:** `skills/silver-rem/SKILL.md` — Step 6

`awk -v ins="${INSIGHT}"` processes awk escape sequences in the assigned value. If INSIGHT contains a literal backslash followed by `n`, `t`, or another backslash (e.g., an insight about bash `\n` usage), awk interprets it as a newline, tab, or single backslash. The entry is still written to the file, but with altered formatting.

This is not a security issue (the security boundary restricts what silver-rem does with insight content, not how awk formats it), and the practical likelihood is low since most insight text won't contain escape sequences. The security boundary documentation does not mention this awk -v behavior.

**Fix (optional):** Document the limitation in the Security Boundary section, or use an awk workaround that avoids -v interpretation (e.g., pass through a file or use `ENVIRON`). Given the deferred-LOW category this review uses, no code change is required — documentation note sufficient.

---

### Summary

**Fix verification:** 14 of 14 Round 1 accepted fixes verified PASS. Two of the verified fixes have minor notes (awk insert order is newest-first by design; edge case grep is behaviorally equivalent but textually inconsistent — see N2).

**Total new findings:**
- Critical: 0
- High: 0
- Medium: 2 (N1: silver-update Step 6a jq path bug; N3: template §10→§9 stale references)
- Low: 2 (N2: missing -F in edge case; N4: awk -v backslash interpretation)

| ID | File | Issue | Severity |
|----|------|-------|----------|
| N1 | `skills/silver-update/SKILL.md` Step 6a | Wrong jq path: `."key"` should be `.plugins["key"]` — legacy cleanup never runs | Medium |
| N2 | `skills/silver-scan/SKILL.md` Edge Cases | `grep -rl` missing -F flag (edge case only; body is correct) | Low |
| N3 | `templates/silver-bullet.md.base` lines 312, 325 | `§10` references should be `§9` (template has no §10) | Medium |
| N4 | `skills/silver-rem/SKILL.md` Step 6 | awk -v interprets backslash sequences in insight text | Low |
