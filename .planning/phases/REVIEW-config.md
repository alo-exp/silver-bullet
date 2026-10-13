---
phase: config-review
reviewed: 2026-04-20T00:00:00Z
depth: deep
files_reviewed: 12
files_reviewed_list:
  - .silver-bullet.json
  - .claude-plugin/plugin.json
  - .claude-plugin/marketplace.json
  - .github/workflows/ci.yml
  - .github/workflows/secret-scan.yml
  - .github/workflows/pages.yml
  - .github/workflows/announce-release.yml
  - templates/silver-bullet.config.json.default
  - templates/silver-bullet.md.base
  - templates/CLAUDE.md.base
  - templates/workflow.md.base
  - silver-bullet.md
findings:
  critical: 1
  warning: 5
  info: 3
  total: 9
status: issues_found
---

# Config, Workflow, and Template Code Review

**Reviewed:** 2026-04-20
**Depth:** deep
**Files Reviewed:** 12
**Status:** issues_found

## Summary

Reviewed all config, workflow, template, and GitHub Actions files at deep depth with cross-file analysis. JSON validity is clean across all four JSON files. GitHub Actions `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24` is correctly placed at the job level in all four workflows. `plugin.json` and `marketplace.json` both report `0.23.6` — version parity confirmed.

The most significant issues are: (1) `review-loop-pass-1`/`review-loop-pass-2` were removed from `silver-bullet.md` and `templates/silver-bullet.md.base` at the instruction level but remain enforced in `hooks/completion-audit.sh`, `hooks/stop-check.sh`, `hooks/prompt-reminder.sh`, and `hooks/core-rules.md` — a hook-to-documentation split that will confuse users and cause unexplained hook blocks; (2) the pre-release quality gate (§9 in `silver-bullet.md`) is intentionally Alo Labs-only per memory, but the template `§9/10` subsection labels and section cross-references are misaligned; and (3) `required_deploy` diverges materially between `.silver-bullet.json` and `templates/silver-bullet.config.json.default` in ways that create different enforcement for repo maintainers vs. end users.

---

## Critical Issues

### CR-01: `review-loop-pass-1`/`review-loop-pass-2` removed from instructions but still enforced by hooks

**File:** `hooks/completion-audit.sh:255-256`, `hooks/stop-check.sh:200-201`, `hooks/prompt-reminder.sh:97`, `hooks/core-rules.md:35-38`

**Issue:** `silver-bullet.md` §3a "Recording Review Loop Progress" now reads "No state-file markers are required or written" — the two markers were removed as part of v0.23.x. The same text appears identically in `templates/silver-bullet.md.base` (both files are clean on this). However, the hooks have NOT been updated. `hooks/completion-audit.sh` line 255 still hardcodes `review-loop-pass-1` and `review-loop-pass-2` in `DEFAULT_REQUIRED`. `hooks/stop-check.sh` line 200 does likewise. `hooks/prompt-reminder.sh` line 97 does likewise. `hooks/core-rules.md` lines 35-38 still instruct writing these markers.

The net effect: the hooks will block every PR/deploy/release because these two markers can never be written (instructions say not to write them), but the hooks still require them. This is a runtime blocker for any project running the current plugin without a custom `.silver-bullet.json` that overrides `required_deploy`.

**Fix:** Update `hooks/completion-audit.sh:255-256`, `hooks/stop-check.sh:200-201`, and `hooks/prompt-reminder.sh:97` to remove `review-loop-pass-1` and `review-loop-pass-2` from their `DEFAULT_REQUIRED` and `DEVOPS_DEFAULT_REQUIRED` strings. Update `hooks/core-rules.md:35-38` to remove or replace the marker-write instructions. Also update `templates/silver-bullet.config.json.default` to remove these from any list they appear in (they are not in the template config currently, which is correct). The CI test at `tests/hooks/test-completion-audit.sh:333-334` that passes these markers should also be updated to reflect the new behavior.

---

## Warnings

### WR-01: `required_deploy` diverges between `.silver-bullet.json` and `templates/silver-bullet.config.json.default`

**File:** `.silver-bullet.json:14-21` and `templates/silver-bullet.config.json.default:15-22`

**Issue:** The two `required_deploy` lists differ in meaningful ways:

- `.silver-bullet.json` includes `security` but NOT `code-review`
- `templates/silver-bullet.config.json.default` includes `code-review` but NOT `security`

This means the Alo Labs repo itself enforces a different gate than what ships to end users. `security` is a required deploy skill for the repo but not for any project that installs the plugin. Conversely, end-user projects require `code-review` but the repo does not. The CLAUDE.md invariant says "Config is authoritative — when `.silver-bullet.json` has `required_deploy`, it overrides the default." This means the repo is intentionally using a stronger/different gate, but the divergence is undocumented and asymmetric.

**Fix:** Either (a) document this intentional divergence with a comment in `.silver-bullet.json`, or (b) sync the lists if the divergence is accidental. The `security` skill should be considered for addition to the template's `required_deploy` given that `silver:security` is called out as non-skippable in §3. If intentional, add a `_required_deploy_comment` key to `.silver-bullet.json` explaining why it differs from the template.

### WR-02: `.silver-bullet.json` missing `required_deploy_devops` — template has it, repo does not

**File:** `.silver-bullet.json` (entire file)

**Issue:** `templates/silver-bullet.config.json.default` defines a `required_deploy_devops` array (lines 23-31) for the devops workflow gate. `.silver-bullet.json` does not define this field at all. Per the CLAUDE.md invariant "hooks never append extra mandatory skills on top," when `.silver-bullet.json` has an explicit `required_deploy`, the hook uses it and ignores the default. But `required_deploy_devops` is entirely absent, which means `hooks/completion-audit.sh` and `hooks/stop-check.sh` will fall back to their hardcoded `DEVOPS_DEFAULT_REQUIRED` strings (which include `review-loop-pass-1/2` — see CR-01). This repo cannot run a clean devops workflow.

**Fix:** Add `required_deploy_devops` to `.silver-bullet.json` matching or supersetting the template's definition, then ensure hooks read this field when `active_workflow` is `devops-cycle`.

### WR-03: Template `§9` subsection labels read `10a`–`10e` but section is `9`

**File:** `templates/silver-bullet.md.base:738-766`

**Issue:** The template's `## 9. User Workflow Preferences` section contains subsections labeled `### 10a. Routing Preferences` through `### 10e. Mode Preferences`. The `10x` numbering is borrowed from `silver-bullet.md` where the Alo Labs-only §9 Pre-Release Quality Gate shifts User Workflow Preferences to §10. End-user projects instantiated from this template get a `§9` section with `10a`–`10e` subsections — an internal numbering contradiction. The `§10` cross-references in lines 312 and 325 of the template also correctly say `§10`, but the section itself is `§9`. This means the cross-references are broken for end users.

**Fix:** Rename the template's subsections from `10a`–`10e` to `9a`–`9e`, and update the three `§10` cross-references in the template (lines 312, 325) to `§9`. In `silver-bullet.md`, the `10a`–`10e` labels and `§10` references are correct and should remain unchanged.

### WR-04: `.silver-bullet.json` `"version"` field is `0.19.0` while plugin is `0.23.6`

**File:** `.silver-bullet.json:2`

**Issue:** `.silver-bullet.json` has `"version": "0.19.0"` while `plugin.json` and `marketplace.json` are both at `0.23.6`. The template default (`templates/silver-bullet.config.json.default`) has `"version": "0.11.0"` with a separate `"config_version": "0.12.1"`. No hook currently reads the `version` field from `.silver-bullet.json`, so there is no runtime impact today. However, the stale version number is misleading for maintainers and may be read by future tooling. The template's version (`0.11.0`) represents the config schema version, not the plugin version, which is a separate semantic.

**Fix:** Either (a) remove the `version` field from `.silver-bullet.json` if it has no semantic meaning, or (b) update it to `0.23.6` to match the plugin version, or (c) add a comment clarifying what this field tracks. Align the template's versioning strategy with the same decision.

### WR-05: `silver-bullet.md` §2d lists `quality-gate-stage-1` through `-4` in SB state file; template §2d does not

**File:** `silver-bullet.md:208` vs `templates/silver-bullet.md.base:207-210`

**Issue:** `silver-bullet.md` §2d enumerates four items under "SB state file is ONLY for:" including "Quality gate stage markers (`quality-gate-stage-1` through `quality-gate-stage-4`)". The template's §2d lists only three items (skill invocation markers, session mode, session init sentinel) — the quality-gate-stage bullet is absent. This is the expected split per the memory note ("Gate stays in silver-bullet.md §9 but NOT in silver-bullet.md.base"), but the §2d description of what the state file is used for is also enforcement-facing and should be consistent. A user debugging why their state file contains unexpected markers will find the template unhelpful. This is a lower-severity documentation gap but affects developer experience.

**Fix:** Either add a `- Release quality gate markers (quality-gate-stage-1 through quality-gate-stage-4) — Alo Labs internal only` note to the template §2d (annotated as internal), or leave it as-is and document the intentional omission. No enforcement impact since hooks don't rely on this list for behavior.

---

## Info

### IN-01: `marketplace.json` has two `"version"` fields with different values

**File:** `.claude-plugin/marketplace.json:9` and `.claude-plugin/marketplace.json:17`

**Issue:** `marketplace.json` contains `"metadata": { "version": "1.0.0" }` (line 9) AND `"plugins": [{ "version": "0.23.6" }]` (line 17). The CI check correctly reads the plugin-array version for comparison against `plugin.json`. The `metadata.version: "1.0.0"` appears to be a marketplace schema version (not the plugin version), but it creates a confusing dual-version structure with no comment explaining the distinction.

**Fix:** Add a comment or rename the field to `"schema_version": "1.0.0"` to make the distinction clear. No functional impact since CI reads the correct field.

### IN-02: `all_tracked` in `.silver-bullet.json` includes `silver-brainstorm-idea` but template does not

**File:** `.silver-bullet.json:38` vs `templates/silver-bullet.config.json.default:48`

**Issue:** `.silver-bullet.json`'s `all_tracked` array includes `silver-brainstorm-idea` while the template does not. Since `all_tracked` drives compliance reporting (not enforcement), this difference means end-user projects will not track this skill invocation in their compliance status output. This is likely an oversight — the skill exists in the skills catalog referenced in §2h.

**Fix:** Add `silver-brainstorm-idea` to `templates/silver-bullet.config.json.default`'s `all_tracked` array to keep the tracking list consistent.

### IN-03: CI `Assert required_deploy is subset of all_tracked` only validates `.silver-bullet.json`, not the template config

**File:** `.github/workflows/ci.yml:96`

**Issue:** The CI assertion hardcodes `config=".silver-bullet.json"` and validates only the repo's own config. `templates/silver-bullet.config.json.default` ships to every user project and has its own `required_deploy` and `all_tracked` arrays. If a template update introduces a skill into `required_deploy` that is missing from `all_tracked`, the CI will not catch it. Currently both template arrays are consistent (no missing skills), but the gap in CI coverage means future template edits are unguarded.

**Fix:** Add a second validation block to the CI assertion step that runs the same `jq` subset check against `templates/silver-bullet.config.json.default`. This is a low-risk 3-line addition alongside the existing check.

---

_Reviewed: 2026-04-20_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: deep_
