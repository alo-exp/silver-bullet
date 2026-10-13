---
phase: 13-ingestion-multi-repo
verified: 2026-04-09T11:00:00Z
status: gaps_found
score: 4/5 must-haves verified
gaps:
  - truth: "Mobile repo session blocked with diff of what changed when spec-version mismatches"
    status: failed
    reason: "§0 step 5.5 in silver-bullet.md.base blocks on mismatch and shows local vs remote version numbers, but does NOT show a diff of what changed between versions. ROADMAP SC5 requires 'a diff of what changed before the user can proceed' — only version numbers are displayed, not content-level diff."
    artifacts:
      - path: "templates/silver-bullet.md.base"
        issue: "Mismatch block displays 'Local: v{local} / Remote: v{remote}' but fetches no content diff. The remote full SPEC.md is already fetched (line 74) but only spec-version is extracted via grep — the diff content is discarded."
    missing:
      - "After fetching the remote SPEC.md, diff it against the cached SPEC.main.md and display the changed sections to the user before blocking. At minimum, surface which top-level sections changed."
  - truth: "Failed Confluence fetch produces [ARTIFACT MISSING] block in SPEC.md (INGT-06)"
    status: failed
    reason: "INGT-06 requires every failed artifact to produce an [ARTIFACT MISSING: reason] block in SPEC.md. The Confluence failure path (silver-ingest/SKILL.md line 423 and Step 1 line 112-113) only says 'Skip page content; note in Assumptions' — it does not insert a named [ARTIFACT MISSING] block. All other connectors (JIRA, Figma, Google Docs) produce [ARTIFACT MISSING] blocks correctly."
    artifacts:
      - path: "skills/silver-ingest/SKILL.md"
        issue: "Failure handling table row for confluence_get_page states 'Skip page content; note in Assumptions' rather than inserting [ARTIFACT MISSING: Confluence page fetch failed — {url}: {error}] in SPEC.md."
    missing:
      - "Add explicit failure clause to Step 1: 'On confluence_get_page failure: record status: failed in-memory. Store [ARTIFACT MISSING: Confluence page fetch failed — {url}: {error}] for insertion in UX Flows or Overview section during Step 6.'"
      - "Update the failure handling table Confluence row to match."
---

# Phase 13: Ingestion & Multi-Repo Verification Report

**Phase Goal:** Users can feed external artifacts (JIRA tickets, Figma designs, Google Docs) directly into SB to produce a draft spec, and satellite repos can reference and pin to the main repo's spec as a read-only source of truth
**Verified:** 2026-04-09T11:00:00Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `silver-ingest <jira-id>` pulls ticket + linked URLs and produces draft SPEC.md + DESIGN.md | VERIFIED | Steps 1-6 of skills/silver-ingest/SKILL.md: Step 1 calls `jira_get_issue`, resolves Confluence pages, queues Figma/GDoc URLs; Steps 3-4 extract Figma/GDocs; Step 6 is a non-skippable gate that assembles SPEC.md from all collected content using templates/specs/SPEC.md.template |
| 2 | Every run produces INGESTION_MANIFEST.md; failed artifacts appear as [ARTIFACT MISSING] — no silent failures | PARTIAL | Step 7 is non-skippable, writes manifest atomically with all statuses. JIRA/Figma/GDoc failures produce [ARTIFACT MISSING] blocks correctly. GAP: Confluence failure does NOT produce [ARTIFACT MISSING] in SPEC.md — only notes in Assumptions (failure table line 423). INGT-06 invariant is violated for this connector. |
| 3 | Failed mid-ingestion resumes from manifest checkpoint on re-run | VERIFIED | Step 0 reads prior manifest, loads artifact statuses into memory. Steps 1, 3, and 4 each contain explicit resumability checks: "If the manifest shows this artifact with status: success, skip." Failed entries are retried. |
| 4 | `silver-ingest --source-url` caches SPEC.main.md as read-only with version display | VERIFIED | Step 5 parses --source-url, fetches via `gh api` (curl fallback), prepends READ-ONLY comment, extracts spec-version via grep, displays "Fetched SPEC.md (v{version}) from {owner}/{repo}." SPEC.main.md marked as read-only cache. Commit 0dec35d confirmed. |
| 5 | Mobile repo session blocked on version mismatch WITH DIFF of what changed | FAILED | §0 step 5.5 in templates/silver-bullet.md.base (line 79-87) blocks on mismatch and displays local vs remote version numbers. Does NOT show a content diff of what changed between versions. ROADMAP SC5 explicitly requires "a diff of what changed before the user can proceed" — version number display alone does not satisfy this requirement. |

**Score:** 3/5 truths fully verified (SC2 partial, SC5 failed)

### Deferred Items

None — all deferred analysis complete.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `skills/silver-ingest/SKILL.md` | 428-line ingestion orchestration skill | VERIFIED | Exists, 429 lines (confirmed). All 9 steps present (Step 0 through Step 9). Non-skippable gates on Steps 6 and 7. Commit 0dec35d. |
| `skills/silver/SKILL.md` — silver:ingest row | Routing entry with intent patterns | VERIFIED | Line 57: "ingest", "import", "jira", "figma", "pull ticket", "cross-repo", "fetch spec from" all present. Option H added to ambiguous-input menu (line 99). Commit bc032ca. |
| `templates/silver-bullet.md.base` — §0/5.5 | Multi-repo session-start version validation | VERIFIED (partial) | Section exists at line 66-89. Blocks on mismatch. Missing content diff. Commit 112284e. |
| `templates/silver-bullet.md.base` — §2j | MCP Connector Prerequisites table | VERIFIED | Lines 310-321. Atlassian/Figma/Google Drive connectors documented with configuration notes. |
| `templates/silver-bullet.md.base` — §2k | Cross-Repo Spec Workflow conventions | VERIFIED | Lines 324-329. REPO-03 (main repo first) and REPO-04 (mobile-exclusive standard SB) conventions documented. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| skills/silver/SKILL.md | skills/silver-ingest/SKILL.md | routing table signal match | WIRED | Line 57 routes "ingest"/"jira"/"figma"/"pull ticket"/"cross-repo"/"fetch spec from" to silver:ingest |
| templates/silver-bullet.md.base §0/5.5 | .planning/SPEC.main.md | file existence check + gh CLI | WIRED | Session-start check reads SPEC.main.md, fetches remote version, blocks on mismatch |
| skills/silver-ingest/SKILL.md Step 5 | templates/silver-bullet.md.base §0/5.5 | SPEC.main.md written by Step 5, read by §0/5.5 | WIRED | Step 5 writes SPEC.main.md with READ-ONLY comment; §0/5.5 reads the same file |
| INGESTION_MANIFEST.md | Step 0 resumability | manifest read in Step 0 | WIRED | Step 0 reads manifest and loads prior artifact statuses; Steps 1/3/4 check per-artifact status |

### Data-Flow Trace (Level 4)

Not applicable — all Phase 13 artifacts are SKILL.md orchestration documents (instruction files for Claude, not executable components that render dynamic data). No data flows to verify at the code level.

### Behavioral Spot-Checks

Step 7b: SKIPPED — Phase 13 produces SKILL.md instruction documents, not runnable entry points. Behavior is verified through structural inspection of the orchestration skill.

### Requirements Coverage

| Requirement | Description | Status | Evidence |
|-------------|-------------|--------|---------|
| INGT-01 | silver-ingest pulls JIRA ticket via Atlassian MCP → draft SPEC.md | SATISFIED | Step 1: jira_get_issue call, summary/description/AC extraction documented |
| INGT-02 | Resolves artifact links (GDrive, Figma, Confluence) found in JIRA ticket | SATISFIED | Step 1 parses URLs, routes to Steps 2-4; Step 2 handles direct URL arguments |
| INGT-03 | Figma extraction via MCP → DESIGN.md | SATISFIED | Step 3: get_design_context + get_variable_defs → DESIGN.md sections from templates/specs/DESIGN.md.template |
| INGT-04 | Google Docs via Drive MCP with WebFetch fallback | SATISFIED | Step 4: read_document primary, WebFetch fallback, both failure paths produce [ARTIFACT MISSING] |
| INGT-05 | Every ingestion produces INGESTION_MANIFEST.md with all statuses | SATISFIED | Step 7: non-skippable gate, atomic write, all artifact statuses committed at once |
| INGT-06 | Failed artifacts produce [ARTIFACT MISSING] blocks — no empty sections | PARTIAL | JIRA/Figma/GDoc produce [ARTIFACT MISSING] blocks. Confluence failure does NOT — only "note in Assumptions". Invariant at line 428 is violated for Confluence connector. |
| INGT-07 | Ingestion resumable from manifest checkpoint | SATISFIED | Step 0 reads prior manifest; Steps 1/3/4 check per-artifact status; failed entries retried |
| REPO-01 | --source-url fetches SPEC.md, caches as .planning/SPEC.main.md (read-only) | SATISFIED | Step 5: gh CLI primary, curl fallback, READ-ONLY comment prepended, SPEC.main.md constraint documented |
| REPO-02 | Session start validates pinned spec-version, blocks on mismatch with diff | PARTIAL | §0/5.5 blocks on mismatch. Version numbers shown but no content diff produced. |
| REPO-03 | Non-mobile requirements spec'd in main repo first | SATISFIED | §2k documents convention: "Main repo specs first" with explicit workflow guidance |
| REPO-04 | Mobile-exclusive requirements follow standard SB process in mobile repo | SATISFIED | §2k documents: "Requirements unique to the mobile/satellite repo follow the standard SB process entirely within the satellite repo" |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| skills/silver-ingest/SKILL.md | 248-254 | Shell injection: {owner}/{repo} interpolated from user-supplied URL without validation | Warning | Crafted URL with shell metacharacters could break gh api / curl commands — no input validation regex present |
| skills/silver-ingest/SKILL.md | 254 | curl fallback hardcodes `main` branch | Warning | Silent data staleness for repos with non-`main` default branch (master, trunk, develop) |
| skills/silver-ingest/SKILL.md | 291-292 | Augment-mode spec-version increment has no guard against absent/non-integer value | Warning | Missing field or "draft" string would produce incorrect version without user notification |
| templates/silver-bullet.md.base | 353-358 | Duplicate MCP prerequisite documentation (also at lines 310-321 in §2j) | Info | Maintenance drift risk — two copies of connector list must be kept in sync |

Note: The shell injection (CR-01 from REVIEW.md) is a warning-level concern rather than a blocker for verification purposes because silver-ingest/SKILL.md is an instruction document for Claude (not executable shell code). Claude's behavior when following the instruction can include appropriate validation, but the document should explicitly require it per the REVIEW finding.

### Human Verification Required

None — all verification was achievable through structural inspection of SKILL.md documents and template files.

### Gaps Summary

Two gaps block full goal achievement:

**Gap 1 — Missing content diff on version mismatch (REPO-02, SC5):**
The ROADMAP's Success Criteria 5 is explicit: the session is blocked "with a diff of what changed." The current §0/5.5 implementation fetches the remote SPEC.md version number but immediately discards the full content. Only version numbers (local v{N} / remote v{M}) are displayed. The user sees that something changed but not what — they cannot make an informed decision about whether to proceed without refreshing. Fix: after the gh CLI fetch in step 5.5 line 74, decode the full remote content, diff against the cached SPEC.main.md, and display changed sections in the block message.

**Gap 2 — Confluence failure does not produce [ARTIFACT MISSING] block (INGT-06, SC2):**
The INGT-06 invariant ("no silent partial failures; failed artifacts appear as [ARTIFACT MISSING] blocks") is violated for the Confluence connector. The failure handling table explicitly states "Skip page content; note in Assumptions" — a weaker, ambiguous signal compared to the named [ARTIFACT MISSING] format used by every other connector. The invariant at line 428 ("A connector failure never blocks ingestion of other artifacts. The INGESTION_MANIFEST.md is always written") is satisfied for the manifest, but the SPEC.md representation of Confluence failures is inconsistent with the stated requirement.

Both gaps are in the documentation/instruction layer — they require targeted edits to two files (silver-ingest/SKILL.md and templates/silver-bullet.md.base). No architectural changes needed.

---

_Verified: 2026-04-09T11:00:00Z_
_Verifier: Claude (gsd-verifier)_
