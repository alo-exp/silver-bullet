---
phase: REVIEW-round2
reviewed: 2026-04-20T00:00:00Z
depth: standard
files_reviewed: 37
files_reviewed_list:
  - hooks/ci-status-check.sh
  - hooks/completion-audit.sh
  - hooks/compliance-status.sh
  - hooks/dev-cycle-check.sh
  - hooks/forbidden-skill-check.sh
  - hooks/phase-archive.sh
  - hooks/pr-traceability.sh
  - hooks/prompt-reminder.sh
  - hooks/record-skill.sh
  - hooks/roadmap-freshness.sh
  - hooks/semantic-compress.sh
  - hooks/session-log-init.sh
  - hooks/session-start
  - hooks/spec-floor-check.sh
  - hooks/spec-session-record.sh
  - hooks/stop-check.sh
  - hooks/timeout-check.sh
  - hooks/uat-gate.sh
  - hooks/lib/nofollow-guard.sh
  - hooks/lib/required-skills.sh
  - hooks/lib/trivial-bypass.sh
  - hooks/lib/workflow-utils.sh
  - scripts/deploy-gate-snippet.sh
  - scripts/semantic-compress.sh
  - skills/silver-create-release/SKILL.md
  - skills/silver-devops/SKILL.md
  - skills/silver-init/SKILL.md
  - templates/silver-bullet.config.json.default
  - templates/silver-bullet.md.base
  - templates/CLAUDE.md.base
  - .github/workflows/ci.yml
  - .github/workflows/announce-release.yml
  - .github/workflows/secret-scan.yml
  - tests/hooks/test-required-skills-consistency.sh
  - tests/hooks/test-stop-check.sh
  - tests/hooks/test-timeout-check.sh
  - .silver-bullet.json
  - hooks/hooks.json
findings:
  critical: 0
  warning: 3
  info: 3
  total: 6
status: issues_found
---

# Round 2 Code Review Report

**Reviewed:** 2026-04-20
**Depth:** standard
**Files Reviewed:** 37
**Status:** issues_found — 0 ISSUE, 3 WARNING, 3 NOTE

---

## Executive Summary

Round 1 fixes are all correctly applied and introduce no new bugs:

- `compliance-status.sh` — atomic cache write via mktemp+mv is correct (lines 87-88)
- `session-log-init.sh` — `sb_safe_write "$log_file"` appears before log creation (line 157)
- `scripts/deploy-gate-snippet.sh` — `trap 'exit 0' ERR` present (line 3)
- `dev-cycle-check.sh` — both `grep -qE "$src_pattern"` occurrences confirmed (lines 255, 264)
- `pr-traceability.sh` — dead `sb_guard_nofollow "$tmpfile"` on mktemp output is gone; trap-based cleanup is correct
- `silver-create-release/SKILL.md` — `git tag -s` present in Allowed Commands
- `silver-init/SKILL.md` — §1.6/1.7/1.8/1.9 numbering is correct; no duplicate Scripts section
- `silver-devops/SKILL.md` — 7 dimensions listed as `reusability, extensibility` matching `devops-quality-gates`
- `test-timeout-check.sh` — standard Results format and PASS/FAIL counters present
- `test-required-skills-consistency.sh` — cross-list validation (required_deploy ⊆ all_tracked) present
- `test-stop-check.sh` — 12-skill required_deploy set present in test config

Three quality/consistency problems remain that should be addressed before declaring clean.

---

## Warnings

### WR-01: `.silver-bullet.json` required_deploy diverges from template — `code-review` missing, `security` added

**File:** `.silver-bullet.json:13-21`

**Issue:** The project's own `.silver-bullet.json` `required_deploy` list differs from `templates/silver-bullet.config.json.default` in two ways:

1. `"code-review"` is present in the template's `required_deploy` but **absent** from `.silver-bullet.json`'s `required_deploy` (it is only in `all_tracked`).
2. `"security"` is listed in `.silver-bullet.json`'s `required_deploy` but **absent** from the template's `required_deploy`.

This means the enforcement gates (`completion-audit.sh`, `stop-check.sh`) for this repo — which read `.silver-bullet.json` — do not require `code-review` but do require `security` before a PR or release. The template ships a different contract to downstream projects. The `test-stop-check.sh` uses a config with `code-review` (matching the template), so the test does not catch what the live project actually enforces.

**Fix:** Decide which is canonical and align both. The template is the intended default; the most likely intent is:

```json
// .silver-bullet.json — align required_deploy with template:
"required_deploy": [
  "silver-quality-gates",
  "code-review", "requesting-code-review", "receiving-code-review",
  "testing-strategy", "documentation",
  "finishing-a-development-branch", "deploy-checklist",
  "silver-create-release",
  "verification-before-completion",
  "test-driven-development", "tech-debt"
]
```

If `security` is intentionally required for this repo but not for downstream projects, add a comment explaining the deliberate divergence.

---

### WR-02: `test-stop-check.sh` and `test-timeout-check.sh` are not in the CI workflow

**File:** `.github/workflows/ci.yml:79-85`

**Issue:** Both tests were updated in Round 1 (`test-stop-check.sh` now has the full 12-skill set; `test-timeout-check.sh` now has the standard Results format) but neither is included in the CI workflow's "Run hook unit tests" step. Regressions in `stop-check.sh` and `timeout-check.sh` will not be caught automatically.

The CI runs only:
- `test-record-skill.sh`
- `test-completion-audit.sh`
- `test-dev-cycle-check.sh`
- `test-required-skills-consistency.sh`

**Fix:** Add both tests to the CI workflow:

```yaml
- name: Run hook unit tests
  run: |
    sudo apt-get install -y jq git
    bash tests/hooks/test-record-skill.sh
    bash tests/hooks/test-completion-audit.sh
    bash tests/hooks/test-dev-cycle-check.sh
    bash tests/hooks/test-required-skills-consistency.sh
    bash tests/hooks/test-stop-check.sh
    bash tests/hooks/test-timeout-check.sh
```

---

### WR-03: `deploy-gate-snippet.sh` hardcoded fallback `REQUIRED_DEPLOY` is significantly shorter than the canonical list

**File:** `scripts/deploy-gate-snippet.sh:45`

**Issue:** The hardcoded fallback (used when jq is absent or no config is found) is:

```bash
REQUIRED_DEPLOY="code-review receiving-code-review testing-strategy documentation finishing-a-development-branch deploy-checklist"
```

The canonical list in `templates/silver-bullet.config.json.default` has 12 skills, including `silver-quality-gates`, `requesting-code-review`, `silver-create-release`, `verification-before-completion`, `test-driven-development`, and `tech-debt`. In environments without jq the deploy gate silently enforces only 6 of 12 required skills.

**Fix:** Update the fallback to match the canonical list, or at minimum document the deliberate scope reduction:

```bash
# Fallback when jq unavailable — matches templates/silver-bullet.config.json.default required_deploy
REQUIRED_DEPLOY="silver-quality-gates code-review requesting-code-review receiving-code-review testing-strategy documentation finishing-a-development-branch deploy-checklist silver-create-release verification-before-completion test-driven-development tech-debt"
```

---

## Notes

### IN-01: `timeout-check.sh` — indentation inconsistency on lines with `sb_guard_nofollow` inserts

**File:** `hooks/timeout-check.sh:76,108,110,128`

**Issue:** Four `echo "$value" > "$file"` lines that write state files have no leading indentation, while the surrounding `sb_guard_nofollow` calls and conditional blocks are indented 2 spaces. This is cosmetic but makes the guarded pairs visually non-obvious:

```bash
  sb_guard_nofollow "$call_count_file"
echo "$call_count" > "$call_count_file"   # line 76 — missing indent
```

**Fix:** Add 2-space indent to lines 76, 108, 110, and 128 to match the surrounding block.

---

### IN-02: `ci-status-check.sh` — `sb_trivial_bypass` called without config-sourced trivial file path

**File:** `hooks/ci-status-check.sh:78`

**Issue:** `sb_trivial_bypass` is called with no argument, so it uses the hardcoded default path `~/.claude/.silver-bullet/trivial`. The script resolves the config-file–driven trivial path in `_trivial_file` (line 60) and checks it for the deprecation warning, but the `sb_trivial_bypass` call at line 78 ignores that resolved path. If a project configures a custom `state.trivial_file` in `.silver-bullet.json`, the CI gate would not honor it via the shared helper. This is consistent with all other SB hooks that also default the bypass, but it is a latent inconsistency.

**Fix (low priority):** Pass the resolved trivial path explicitly:

```bash
sb_trivial_bypass "$_trivial_file"
```

---

### IN-03: `templates/silver-bullet.config.json.default` `all_tracked` does not include `silver-brainstorm-idea`

**File:** `templates/silver-bullet.config.json.default:33-49`

**Issue:** `.silver-bullet.json`'s `all_tracked` includes `"silver-brainstorm-idea"` (last entry, line 38) but the template's `all_tracked` does not contain it. New projects initialized with `/silver:init` will have the template's shorter list; they cannot track or record the `silver-brainstorm-idea` skill by default. This is a minor divergence between the dogfood config and the template.

**Fix:** Add `"silver-brainstorm-idea"` to `templates/silver-bullet.config.json.default`'s `all_tracked` array if the skill is meant to be universally trackable.

---

## Round 1 Fix Verification

All 11 Round 1 fixes confirmed correct:

| # | Fix | File | Verified |
|---|-----|------|----------|
| 1 | version bumped to 0.23.6 | `.silver-bullet.json` | ok |
| 2 | atomic cache write mktemp+mv | `compliance-status.sh:87-88` | ok |
| 3 | `sb_safe_write "$log_file"` before log creation | `session-log-init.sh:157` | ok |
| 4 | `trap 'exit 0' ERR` added | `scripts/deploy-gate-snippet.sh:3` | ok |
| 5 | `grep -qE "$src_pattern"` (2× occurrences) | `dev-cycle-check.sh:255,264` | ok |
| 6 | dead `sb_guard_nofollow "$tmpfile"` removed from mktemp output | `pr-traceability.sh` | ok |
| 7 | `git tag -s` in Allowed Commands | `silver-create-release/SKILL.md` | ok |
| 8 | §1.6/1.7/1.8/1.9 numbering, duplicate Scripts section removed | `silver-init/SKILL.md` | ok |
| 9 | 7 dimensions match devops-quality-gates (reusability+extensibility) | `silver-devops/SKILL.md:128` | ok |
| 10 | Results: N passed, M failed format + PASS/FAIL counters | `test-timeout-check.sh` | ok |
| 11 | Cross-list validation (required_deploy ⊆ all_tracked) | `test-required-skills-consistency.sh:72-100` | ok |

---

## Verdict

**FINDINGS** — Round 2 is not yet clean. Three warnings must be addressed:

1. **WR-01** (`.silver-bullet.json` required_deploy diverges from template) — alignment needed; the live enforcement contract for this repo does not match what the test suite assumes.
2. **WR-02** (updated tests not in CI) — automated regression coverage gap for two hooks.
3. **WR-03** (`deploy-gate-snippet.sh` short fallback list) — silent under-enforcement when jq is absent.

A Round 3 pass should be short (all three issues are one-line or one-block fixes). If WR-01 and WR-02 are fixed and WR-03 is accepted as a documented limitation, the round-3 pass should come back clean.

---

_Reviewed: 2026-04-20_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
