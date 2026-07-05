# Pre-Release Code Review — Round 4 (Final Pass)

**Date:** 2026-04-24
**Scope:** All 18 changed files since v0.24.1
**Gate requirement:** Second consecutive clean pass (Round 3 was clean)

---

## Cross-file consistency check

### 1. Section-numbering gap between silver-bullet.md and templates/silver-bullet.md.base

**Status: Known structural difference — not a regression, but confirmed documented.**

`silver-bullet.md` (the live project file) has **10 numbered sections** (§0–§10), with:
- §9 = Pre-Release Quality Gate (4-stage gate with quality-gate-stage markers, SENTINEL, etc.)
- §10 = User Workflow Preferences (10a–10e)

`templates/silver-bullet.md.base` (the template used for new projects) has **9 numbered sections** (§0–§9), with:
- §9 = User Workflow Preferences (subsections still labeled 10a–10e — mismatch between parent heading and sub-headings)
- No §9 Pre-Release Quality Gate section

**Sub-issue confirmed:** The template's `## 9. User Workflow Preferences` section contains sub-headings labeled `### 10a.` through `### 10e.` — the sub-heading numbers do not match the parent section number. This is a pre-existing inconsistency (the Pre-Release Quality Gate section lives in the live project file and is intentionally absent from the template because new projects do not manage Silver Bullet's own release process). However, the `10a`–`10e` sub-labels under `## 9.` in the template are confusing.

**Consistency of §-references in skill files:** All five orchestrator skills (silver-feature, silver-bugfix, silver-ui, silver-devops, silver-release) reference `§10b` and `§10e` — which are correct for the live `silver-bullet.md` file but technically incorrect for new-project installs that use the template (where the section is §9). This is a pre-existing design asymmetry, not introduced in v0.25.0.

**Cross-reference in §3 NON-NEGOTIABLE RULES:** `silver-bullet.md` §3 says "via §10 preferences" and "update §10"; the template says "via §9 preferences" and "update §9". These are self-consistent within each file. No new regression here.

**Verdict:** No new inconsistency introduced in v0.25.0. Pre-existing asymmetry between live file and template is by design (template is for new projects, not SB development). Already filed as potential future improvement (#54 scope). No action required for this release.

---

### 2. `.silver-bullet.json` vs `templates/silver-bullet.config.json.default` — schema drift

**Status: Minor schema gap — not a blocker.**

The live `.silver-bullet.json` is missing several keys present in the template default:

| Key | In template default | In live `.silver-bullet.json` |
|-----|--------------------|---------------------------------|
| `config_version` | `"0.25.0"` | absent |
| `required_deploy_devops` | present (devops deploy list) | absent |
| `skills.forbidden` | `[]` | absent |
| `issue_tracker` | `"gsd"` | absent |
| `compactPrompt` | present | absent |

The live `.silver-bullet.json` is Silver Bullet's own project config (not a consumer project config), and its `version` field serves the same purpose as `config_version`. The missing keys (`required_deploy_devops`, `forbidden`, `issue_tracker`, `compactPrompt`) are consumer-project features that don't apply to the SB development project. This is consistent with prior releases — the live config is intentionally leaner than the full template.

**Verdict:** No regression introduced in v0.25.0. The CHANGELOG correctly notes `config_version` and `version` were bumped in the template. No action required.

---

### 3. `silver-scan` edge-case doc — missing `-F` flag in one Edge Cases example

**Status: Documentation inconsistency — low severity.**

In `skills/silver-scan/SKILL.md`, Step 7b instructs:
```
Run `grep -rlF "KEYWORD" docs/knowledge/ docs/lessons/ 2>/dev/null`
```
(correctly uses `-F`)

But the Edge Cases section at line 262 shows the same command without the `-F` flag:
```
`grep -rl "KEYWORD" docs/knowledge/ docs/lessons/ 2>/dev/null`
```

The operational step (Step 7b) is correct. The Edge Cases section's example is inconsistent — it describes a scenario where directories are absent, so the command would exit non-zero silently regardless, but the `-F` flag omission in the documentation example is misleading and inconsistent with the stated rationale ("The -F flag treats KEYWORD as a fixed string since it comes from untrusted session log content").

This is a new finding not caught in Rounds 1–3.

**Verdict:** Documentation-level inconsistency. Does not affect runtime behavior for the described edge case (absent directory → non-zero exit regardless of flag). Low severity. Recommend fixing before release or filing as a known minor issue.

---

### 4. `silver-release` SKILL.md — "Step 7.5" reference in both silver-bullet.md and template

**Status: Stale step label — low severity.**

Both `silver-bullet.md` and `templates/silver-bullet.md.base` reference `silver:release Step 7.5` in the artifact reviewer table:
```
| Cross-artifact set | ... | /silver:feature Step 17.0b, /silver:release Step 7.5 |
```

In `skills/silver-release/SKILL.md`, the cross-artifact review step is labeled **Step 7** (not Step 7.5). Step 7b is the Pre-Ship Deployment Checklist. There is no "Step 7.5" in the skill file.

This reference is pre-existing (not introduced in v0.25.0) but was not caught in prior rounds. It creates a mismatch between the table in the enforcement docs and the actual step label in the skill file.

**Verdict:** Pre-existing stale label. Not a behavioral defect — the behavior is correct, only the step number in the table is wrong. Low severity. Recommend correcting `Step 7.5` → `Step 7` in the artifact reviewer table.

---

### 5. All new skills — security boundary, sequencing, and deferred capture consistency

**Status: Clean.**

Verified across all four new skills:
- `silver-add`: Security boundary documented; jq-only JSON construction; session log append; rate-limit retry with session log proceed-on-failure. Consistent.
- `silver-remove`: ID validation with strict regex guard (`^SB-[IB]-[0-9]+$`); sed pattern anchored at `^###`; verification step after replacement. Consistent.
- `silver-rem`: Atomic tmpfile+mv for INDEX.md; awk-based heading-aware insert (not EOF append). The `awk -v ins="${INSIGHT}"` pattern passes the insight via `-v` variable — this is consistent with the known #57 backlog item (awk backslash interpretation) which is already filed and deferred. No new issue.
- `silver-scan`: Sequencing constraint documented (never parallel). `--fixed-strings`/`-F` flag present on git log grep and CHANGELOG grep. `CANDIDATE_COUNT` increments before user answer. Consistent.

---

### 6. Deferred-item capture consistency across all five orchestrator skills

**Status: Clean.**

All five orchestrator skills that received Deferred-Item Capture blocks (silver-feature, silver-bugfix, silver-ui, silver-devops, silver-fast) include:
- Classification rubric (issue vs backlog)
- Minimum bar statement
- `Skill(skill="silver-add", args=...)` invocation pattern

silver-fast correctly notes Tier 1 (trivial) skips capture; Tier 3 escalates to silver-feature which handles its own capture. This is correct and consistent.

---

### 7. `session-log-init.sh` — sentinel PID format and awk rewrite consistency

**Status: Clean.**

The `pid:lstart` format for sentinel-pid is consistently applied in both the new-log path (Step 8) and the existing-log re-trigger path (dedup guard block). The awk-based insertion for the "Timeout sentinel restarted" note uses the tmpfile+mv pattern (not `sed -i ''`), consistent with the SC2015 fixes from prior releases. The `## Items Filed` section injection uses `_insert_before` (awk-based), matching the established helper pattern.

---

### 8. CHANGELOG.md — version and content accuracy

**Status: Clean.**

CHANGELOG `[0.25.0]` entry accurately describes all new skills (FEAT-ADD, FEAT-REMOVE, FEAT-REM, FEAT-SCAN), enforcement additions (CAPT-01/02/03), forensics fixes (FORN-01/02), update overhaul (UPD-01/02), and the full list of pre-release bug fixes. All 13 listed bug fixes match the actual changes visible in the skill files. Version `0.25.0` is consistent across `.silver-bullet.json`, `templates/silver-bullet.config.json.default`, and CHANGELOG.

---

### 9. `silver-update` SKILL.md — stale cache directory guard completeness

**Status: Clean.**

Step 6b guard checks: `$HOME` not unset, not a symlink (`! -L`), path prefix match (`"$STALE_CACHE" == "${HOME}/"*`). These three guards match the CHANGELOG fix description (UPD-SEC guard for `rm -rf`). Consistent.

---

### 10. `all_tracked` list parity between live config and template

**Status: Clean.**

Both `.silver-bullet.json` and `templates/silver-bullet.config.json.default` include all four new skills in `all_tracked`: `silver-remove`, `silver-rem`, `silver-scan`, `silver-add`. The template additionally has `required_deploy_devops` and `forbidden: []` arrays not present in the live config, but this is expected (see finding #2).

---

## New issues found

### ISSUE-R4-01 (Low): `silver-scan` Edge Cases — missing `-F` flag on `grep -rl` example

**File:** `skills/silver-scan/SKILL.md` line 262
**Description:** The Edge Cases section example for "docs/knowledge/ or docs/lessons/ directories absent" uses `grep -rl "KEYWORD"` (without `-F`) while the operational Step 7b instruction and the stated security rationale both require `-F`. The operational step is correct; only the Edge Cases documentation example is inconsistent.
**Impact:** Documentation only — no behavioral defect for this specific edge case (absent directory → non-zero exit regardless).
**Recommendation:** Add `-F` to the Edge Cases example to match Step 7b and the stated rationale.

### ISSUE-R4-02 (Low): Stale "Step 7.5" label in artifact reviewer table

**Files:** `silver-bullet.md` line 458, `templates/silver-bullet.md.base` line 457
**Description:** The artifact reviewer mapping table references `/silver:release Step 7.5` but the silver-release skill has no Step 7.5 — cross-artifact review is at Step 7.
**Impact:** Documentation only — does not affect skill execution.
**Recommendation:** Change `Step 7.5` → `Step 7` in both files.

### ISSUE-R4-03 (Low): Template `## 9. User Workflow Preferences` sub-headings labeled `### 10a`–`### 10e`

**File:** `templates/silver-bullet.md.base` lines 778–794
**Description:** The parent section is `## 9.` but all sub-headings are `### 10a.`–`### 10e.`, creating an internal numbering inconsistency within the template. Orchestrator skills reference `§10b`/`§10e` which are correct for the live file but mismatch the template's section number.
**Impact:** Documentation / template clarity. Consumer projects using the template will see `§9` as the preferences section but skills will refer to `§10b`.
**Recommendation:** Either renumber the sub-headings to `### 9a.`–`### 9e.` in the template, or align orchestrator skill references to be section-label-agnostic.

---

## Summary

Three new low-severity documentation findings were identified in Round 4, all pre-existing or introduced as minor oversights. None affect runtime behavior. The two operational paths in question (silver-scan Step 7b with `-F`, and silver-release cross-artifact review at Step 7) are correct — only their corresponding documentation references are imprecise.

All behavioral changes introduced in v0.25.0 are internally consistent:
- New skills (silver-add, silver-remove, silver-rem, silver-scan) are internally consistent and cross-consistent with each other
- Deferred-item capture enforcement is consistent across all five orchestrator skills
- Config version fields are consistent between live config and template
- Session log hook changes are consistent with the established awk/tmpfile+mv pattern
- CHANGELOG accurately reflects all changes

**Clean round: NO**

Three new low-severity findings (ISSUE-R4-01, R4-02, R4-03). All are documentation-level; none affect skill execution behavior. Recommend fixing ISSUE-R4-01 and R4-02 before release (one-line changes each), and filing R4-03 as a backlog item.
