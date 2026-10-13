---
phase: 13-ingestion-multi-repo
reviewed: 2026-04-09T00:00:00Z
depth: standard
files_reviewed: 3
files_reviewed_list:
  - skills/silver-ingest/SKILL.md
  - skills/silver/SKILL.md
  - templates/silver-bullet.md.base
findings:
  critical: 1
  warning: 4
  info: 3
  total: 8
status: issues_found
---

# Phase 13: Code Review Report

**Reviewed:** 2026-04-09
**Depth:** standard
**Files Reviewed:** 3
**Status:** issues_found

## Summary

Phase 13 delivers three artifacts: the new `skills/silver-ingest/SKILL.md` orchestration skill (428 lines), routing additions to `skills/silver/SKILL.md`, and session-start additions to `templates/silver-bullet.md.base`. The overall structure is sound — all 11 requirements are covered, the manifest checkpoint pattern is correctly enforced, and the step-skip / non-skippable-gate conventions match the silver-spec pattern. However, several issues require attention before the phase is declared complete.

The most serious issue is a shell injection vector in the cross-repo fetch step (Step 5 and the §0/5.5 version validation): the `{owner}` and `{repo}` values extracted from an untrusted URL string are interpolated directly into shell commands without validation. A crafted URL with shell metacharacters or path-traversal sequences can break out of the intended command.

Four warning-level issues cover: the curl fallback in Step 5 using the hardcoded `main` branch (silently fetching stale data from non-main-default repos), the augment-mode `spec-version` increment having no guard against a non-integer or missing value, the `[ARTIFACT MISSING]` block format being inconsistently specified (square-brackets in prose but angle-brackets never mentioned — purely cosmetic but creates agent ambiguity), and the §0/5.5 source-URL extraction depending on a regex parse of a comment line which is fragile.

Three info-level items are noted: duplicate MCP prerequisite documentation in two places in silver-bullet.md.base, a missing `INGT-09` through `INGT-11` requirements mapping (the summary claims 11 requirements but only 8 are mapped), and a minor routing-table signal collision between "jira" in the ingest row and the existing spec row.

---

## Critical Issues

### CR-01: Shell Injection via Unvalidated Owner/Repo Extracted from User-Supplied URL

**File:** `skills/silver-ingest/SKILL.md:248-254`

**Issue:** Step 5 instructs the agent to extract `{owner}` and `{repo}` directly from `$ARGUMENTS` and interpolate them into a `gh api` command and a `curl` command with no validation. The argument value is entirely user-controlled. A crafted value such as `--source-url https://github.com/a/b$(rm -rf .planning)` or a path like `a/b/../../etc` would execute arbitrary shell commands or traverse paths outside the intended target when the agent runs the Bash tool.

The same vulnerability is replicated in `templates/silver-bullet.md.base:74` where the version-check command is constructed from the `{owner}/{repo}` parsed out of the read-only comment header of `SPEC.main.md` — that comment was written by a previous ingest run which itself accepted user input.

**Fix:** Add an explicit validation step immediately after URL parsing in Step 5, before any shell command is constructed:

```bash
# Validate owner and repo contain only safe characters
if ! echo "${owner}/${repo}" | grep -qE '^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$'; then
  echo "ERROR: Invalid owner/repo format in --source-url. Expected https://github.com/{owner}/{repo} with alphanumeric characters, hyphens, dots, and underscores only."
  exit 1
fi
```

Apply the same guard in silver-bullet.md.base §0/5.5 before the `gh api` call. Add a note in the SKILL.md URL-parsing prose: "owner and repo must match `[a-zA-Z0-9._-]+` — reject any value containing shell metacharacters, slashes beyond the single separator, or whitespace."

---

## Warnings

### WR-01: curl Fallback Hardcodes `main` Branch — Silent Data Staleness on Non-Default-Branch Repos

**File:** `skills/silver-ingest/SKILL.md:254`

**Issue:** The curl fallback path fetches from `https://raw.githubusercontent.com/{owner}/{repo}/main/.planning/SPEC.md`. This silently fetches stale or wrong content if the remote repo's default branch is not named `main` (e.g. `master`, `trunk`, `develop`). The `gh api` primary path uses the GitHub API which respects the repo's default branch, so the fallback introduces a behavioral inconsistency that is not surfaced to the user.

**Fix:** Change the fallback to use the GitHub API endpoint via curl with auth (or at minimum document the limitation prominently):

```bash
# Preferred: use gh CLI with explicit default-branch detection
DEFAULT_BRANCH=$(/opt/homebrew/bin/gh api repos/{owner}/{repo} --jq '.default_branch' 2>/dev/null || echo "main")
curl -sL "https://raw.githubusercontent.com/{owner}/{repo}/${DEFAULT_BRANCH}/.planning/SPEC.md" > .planning/SPEC.main.md
```

If keeping the simple `main` fallback, add a visible warning to the user: "Note: curl fallback assumes `main` branch. If this repo uses a different default branch, the fetched spec may be outdated."

---

### WR-02: Augment-Mode spec-version Increment Has No Guard Against Missing or Non-Integer Value

**File:** `skills/silver-ingest/SKILL.md:291-292`

**Issue:** Step 6 instructs the agent to read `spec-version:` from `.planning/SPEC.md` frontmatter and increment it by 1. There is no instruction for what to do if the field is absent, malformed (e.g. `spec-version: draft`), or zero. An agent following the instructions literally would either produce `spec-version: 1` (restarting from 1), concatenate a string ("draft1"), or error out — all silently wrong outcomes with no user notification.

**Fix:** Add explicit handling:

```
Read spec-version from existing SPEC.md frontmatter.
- If the field is absent or not a positive integer: warn the user and default to spec-version: 1 (treat as greenfield).
- If present and a positive integer N: use N+1.
```

The same gap exists in silver-bullet.md.base §0/5.5 line 70 when reading spec-version from SPEC.main.md.

---

### WR-03: §0/5.5 Source-URL Extraction Depends on Fragile Comment-Line Parse

**File:** `templates/silver-bullet.md.base:71`

**Issue:** Step 5.5 instructs the agent to "Read the `<!-- READ-ONLY: fetched from {source-url} -->` header to get the source repo URL." This relies on a human-readable comment in the file, not a structured field. If the file was hand-edited, partially corrupted, or the comment format slightly differs (extra spaces, newline after `<!--`), the regex parse will fail silently and the version check will be skipped or run against the wrong repo. There is no explicit error path documented for when the source URL cannot be extracted from the comment.

**Fix:** Add a structured `source-url:` field to the `INGESTION_MANIFEST.md` (already written atomically in Step 7) and read the URL from there, which is machine-written and has a defined schema. Alternatively, document the explicit failure path: "If the source URL cannot be extracted from the comment header, display 'Could not determine source repo — skipping version check.' and continue."

---

### WR-04: Confluence Failure Mode Does Not Produce [ARTIFACT MISSING] Block in SPEC.md

**File:** `skills/silver-ingest/SKILL.md:112-113` and Failure Handling Table at line 422

**Issue:** The failure handling summary table (line 422) states that Confluence `confluence_get_page` failure produces "Skip page content; note in Assumptions." However, the INGT-06 requirement states that `[ARTIFACT MISSING: reason]` blocks must be inserted for every failure. The Confluence failure path does not produce a named `[ARTIFACT MISSING]` block — it only notes something in Assumptions, which is a weaker signal and inconsistent with the invariant stated at line 428.

The Step 1 prose (line 112-113) also only says "Add the fetched content to the in-memory context" without specifying a failure action for Confluence beyond the summary table.

**Fix:** Add an explicit failure clause in Step 1 for Confluence:

```
On confluence_get_page failure: record status: failed in-memory.
Store [ARTIFACT MISSING: Confluence page fetch failed — {url}: {error}]
to be inserted in the UX Flows or Overview section of SPEC.md during Step 6.
```

Update the failure handling table row for Confluence to match.

---

## Info

### IN-01: Duplicate MCP Prerequisite Documentation in silver-bullet.md.base

**File:** `templates/silver-bullet.md.base:310-320` and `353-358`

**Issue:** MCP connector prerequisites for silver-ingest are documented twice: once in §2j (the new dedicated section added in Phase 13) and again in the existing "Spec Lifecycle" section near line 353. The two descriptions are nearly identical but not word-for-word identical. This creates maintenance overhead — future connector changes must be updated in two places, and they will drift.

**Fix:** In the "Spec Lifecycle" section, replace the duplicated MCP prerequisites block with a cross-reference: "See §2j for MCP connector prerequisites."

---

### IN-02: Requirements Coverage Table Claims 11 Requirements But Maps Only 8

**File:** `.planning/phases/13-ingestion-multi-repo/13-01-SUMMARY.md:55-63`

**Issue:** The phase prompt states "all 11 requirements" but the SUMMARY.md requirements coverage table maps 8 entries (INGT-01 through INGT-07 and REPO-01). The remaining 3 requirements (presumably INGT-08 through INGT-11 or REPO-02 through REPO-04) are either not tracked or were absorbed into REPO-02/03/04 which appear in the Plan 02 summary but are not in the coverage table. This creates an audit gap — it is not clear whether the missing requirement IDs are fully covered, partially covered, or were simply omitted from the table.

**Fix:** Add the missing rows to the coverage table in 13-01-SUMMARY.md, or add a note confirming that REPO-02, REPO-03, REPO-04 are tracked in 13-02-SUMMARY.md with an explicit cross-reference.

---

### IN-03: Routing Signal "jira" Could Collide with spec Intent in Edge Cases

**File:** `skills/silver/SKILL.md:57`

**Issue:** The ingest routing row includes "jira" as a standalone signal. A user who says "create a jira-aligned spec" or "write a spec from the jira requirements" would hit the ingest route before the spec route, even though their intent is spec elicitation using existing JIRA content as context rather than automated ingestion. The conflict resolution table does not have an entry for `silver:ingest` vs `silver:spec`.

**Fix:** Add a conflict resolution entry:

```
| silver:ingest + silver:spec | Ask user: "A. Ingest JIRA ticket into SPEC.md automatically  B. Use JIRA as context for spec elicitation" |
```

Or tighten the ingest signal from "jira" to "ingest jira" / "pull jira ticket" to avoid the single-word false match.

---

_Reviewed: 2026-04-09_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
