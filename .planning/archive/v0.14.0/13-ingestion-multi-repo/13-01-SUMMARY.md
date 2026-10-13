---
phase: 13-ingestion-multi-repo
plan: "01"
subsystem: skills
tags: [silver-ingest, ingestion, jira, figma, google-docs, cross-repo, mcp, spec]
dependency_graph:
  requires: [templates/specs/SPEC.md.template, templates/specs/DESIGN.md.template, skills/silver-spec/SKILL.md]
  provides: [skills/silver-ingest/SKILL.md]
  affects: [.planning/SPEC.md, .planning/DESIGN.md, .planning/INGESTION_MANIFEST.md, .planning/SPEC.main.md]
tech_stack:
  added: []
  patterns: [SKILL.md-orchestration, pre-flight-load-preferences, step-skip-protocol, non-skippable-gates, ingestion-manifest-as-checkpoint, artifact-missing-blocks, cross-repo-fetch-via-gh-cli]
key_files:
  created: [skills/silver-ingest/SKILL.md]
  modified: []
decisions:
  - "INGESTION_MANIFEST.md written atomically at Step 7 only — in-memory artifact list maintained during run to avoid mid-run state corruption"
  - "Figma MCP requires user confirmation before calling get_design_context — frame selection cannot be automated"
  - "Cross-repo fetch skips Step 6 (SPEC.md assembly) — SPEC.main.md is a read-only cache, not an authored draft"
  - "Google Drive MCP is primary path; WebFetch is fallback for publicly accessible docs"
  - "Connector unavailability never blocks ingestion — produces ARTIFACT MISSING blocks and continues"
metrics:
  duration: 8min
  completed: 2026-04-09
  tasks: 1
  files: 1
---

# Phase 13 Plan 01: silver-ingest SKILL.md — Summary

**One-liner:** Multi-source ingestion orchestration skill translating JIRA/Figma/Google Docs into canonical SPEC.md + DESIGN.md with atomic manifest checkpointing and cross-repo spec fetch via gh CLI.

## What Was Built

`skills/silver-ingest/SKILL.md` — a complete 428-line orchestration skill following the silver-spec SKILL.md structural pattern. The skill covers:

- **Pre-flight + Step-Skip Protocol**: matches silver-spec pattern exactly (§10 preferences load, banner display, non-skippable gates on Steps 6 and 7)
- **Step 0**: mode detection (artifact-ingest vs cross-repo-fetch), resumability from prior manifest, augment vs greenfield SPEC.md detection, MCP connector availability check
- **Step 1**: JIRA ticket fetch via `jira_get_issue`; Confluence page resolution via `confluence_get_page` for linked pages; URL parsing for queued artifact routing
- **Step 2**: artifact link resolution — routes Google Drive URLs to Step 4, Figma URLs to Step 3; handles direct URL arguments without a JIRA ticket
- **Step 3**: Figma extraction via `get_design_context` + `get_variable_defs`; mandatory user confirmation before MCP call; populates DESIGN.md from template
- **Step 4**: Google Docs extraction via Drive MCP `read_document` with WebFetch fallback for public docs
- **Step 5**: cross-repo fetch via `gh api` (gh CLI primary, curl fallback); writes READ-ONLY annotated SPEC.main.md; extracts spec-version from frontmatter
- **Step 6**: NON-SKIPPABLE SPEC.md assembly — all sections populated from collected content with `[ARTIFACT MISSING: reason]` blocks for any failure; NEVER empty sections
- **Step 7**: NON-SKIPPABLE atomic INGESTION_MANIFEST.md write — all artifact statuses committed at once (Pitfall 6 avoidance)
- **Step 8**: git commit all produced artifacts
- **Step 9**: summary banner with artifact counts and next-step guidance

Two reference tables appended: artifact-type routing (which steps fire for each input type) and failure-handling summary (what each connector failure produces).

## Requirements Coverage

| Requirement | Coverage |
|-------------|----------|
| INGT-01 | Step 1: `jira_get_issue` call, summary/description/AC extraction |
| INGT-02 | Step 1 + Step 2: Confluence fetch + Google Drive / Figma URL queuing from JIRA body |
| INGT-03 | Step 3: `get_design_context` + `get_variable_defs` → DESIGN.md |
| INGT-04 | Step 4: `read_document` (Drive MCP) + WebFetch fallback |
| INGT-05 | Step 7: INGESTION_MANIFEST.md schema with all artifacts and statuses |
| INGT-06 | Steps 1-6: `[ARTIFACT MISSING: reason]` blocks for every failure; no empty sections |
| INGT-07 | Step 0: manifest read + skip-on-success resumability logic |
| REPO-01 | Step 5: `--source-url` mode, gh CLI fetch, READ-ONLY annotation, SPEC.main.md |

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None. The SKILL.md is an orchestration instruction document, not an executable with data stubs. All sections are fully specified with explicit content sources and failure handling.

## Threat Flags

No new threat surface beyond what is documented in the plan's threat model. The skill delegates all external data access to MCP connectors — no custom credential handling or API code.

## Self-Check

- [x] `skills/silver-ingest/SKILL.md` exists (428 lines, >= 200 required)
- [x] Commit `0dec35d` exists in git log
- [x] All 9 steps present (Step 0 through Step 9)
- [x] All acceptance criteria pass (verified via automated check: PASS)
