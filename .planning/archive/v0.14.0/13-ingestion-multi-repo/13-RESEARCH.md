# Phase 13: Ingestion & Multi-Repo — Research

**Researched:** 2026-04-09
**Domain:** External artifact ingestion via MCP connectors (JIRA, Figma, Google Docs) + cross-repo spec referencing
**Confidence:** MEDIUM — MCP tool schemas and behavior verified via prior project research in STACK.md; hook/skill patterns verified by direct codebase inspection

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| INGT-01 | `silver-ingest` skill pulls JIRA ticket content via Atlassian MCP and produces draft SPEC.md | Atlassian MCP tool names and field inventory documented; SPEC.md template exists in Phase 12 output |
| INGT-02 | `silver-ingest` resolves artifact links in JIRA ticket (Google Drive, Figma, Confluence URLs) | MCP connector capabilities for each source type documented; link-resolution flow defined |
| INGT-03 | Figma design context extracted via Figma MCP and written to DESIGN.md | Figma MCP tool names and data shape documented; DESIGN.md template exists in Phase 12 output |
| INGT-04 | Google Docs/Slides extracted via Google Workspace CLI with vision support | Google Docs path documented as LOW confidence — two viable options; community MCP vs Workspace CLI |
| INGT-05 | Every ingestion produces INGESTION_MANIFEST.md listing all artifacts attempted, succeeded, failed, missing | Manifest schema designed; resumability pattern defined |
| INGT-06 | Missing/failed artifact ingestion produces `[ARTIFACT MISSING: reason]` blocks in SPEC.md | Failure-mode propagation pattern defined for each connector |
| INGT-07 | Ingestion is resumable — re-running `silver-ingest` picks up from manifest state | Manifest-as-checkpoint pattern documented |
| REPO-01 | `silver-ingest --source-url <repo-url>` fetches main repo SPEC.md to `.planning/SPEC.main.md` | gh CLI fetch pattern documented; read-only cache convention defined |
| REPO-02 | Mobile repo validates pinned spec-version against main repo at session start | SPEC.md frontmatter `spec-version:` field exists; validation logic designed as silver-bullet.md instruction |
| REPO-03 | Non-mobile requirements spec'd in main repo first, then referenced as mobile repo SB input | Cross-repo workflow convention documented; no new tooling needed |
| REPO-04 | Mobile-exclusive requirements follow standard SB process within mobile repo | Standard silver-feature workflow applies; no special handling needed |
</phase_requirements>

---

## Summary

Phase 13 builds `silver-ingest` — a new SB orchestration skill that adapts three external data sources (JIRA via Atlassian MCP, Figma via Figma remote MCP, Google Docs via community Drive MCP or Workspace CLI) into the canonical `.planning/SPEC.md` + `DESIGN.md` format established in Phase 12. It also handles cross-repo spec fetching via `gh` CLI for multi-repo workflows.

The skill is **orchestration-only**: it never calls APIs directly. It invokes MCP tools via natural-language instructions, normalizes their outputs into the Phase 12 spec templates, and records everything in an `INGESTION_MANIFEST.md` that enables resumable runs. No custom Node.js code is required — the entire implementation is a single `SKILL.md` file plus a session-start instruction extension for REPO-02 version validation.

**Primary recommendation:** Build silver-ingest as a multi-step SKILL.md following the exact structural patterns of silver-spec (pre-flight, step-skip protocol, numbered steps, non-skippable gates). Each connector (JIRA, Figma, Google Docs) is an independent branch inside a single skill, not three separate skills. The INGESTION_MANIFEST.md is the idempotency key — read it at the start of each run to skip already-completed steps.

---

## Standard Stack

### Core
| Component | Version/Source | Purpose | Why Standard |
|-----------|---------------|---------|--------------|
| Atlassian MCP (sooperset/mcp-atlassian) | Community, 72 tools | JIRA ticket + Confluence page fetch | Official Atlassian remote MCP has fewer tools; community implementation covers all needed tool names [VERIFIED: STACK.md direct citation] |
| Figma remote MCP (official) | Beta, free | Design context + token extraction | Official Figma MCP; supported client list includes Claude Code [VERIFIED: STACK.md] |
| Community Google Drive MCP | Community (piotr-agier/google-drive-mcp) | Google Docs/Slides text extraction | No official Google MCP exists; community option or Workspace CLI are the two paths [ASSUMED — LOW confidence; official Google MCP landscape may change] |
| `gh` CLI | Already installed (existing SB dep) | Cross-repo raw file fetch for REPO-01 | Used by existing SB hooks; no new dependency [VERIFIED: codebase inspection] |

### Supporting
| Component | Purpose | When to Use |
|-----------|---------|-------------|
| `confluence_get_page` (Atlassian MCP) | Fetch Confluence pages linked from JIRA ticket body | When JIRA description contains Confluence URLs (INGT-02) |
| Google Workspace CLI (Google-published) | Google Docs markdown extraction via shell subprocess | When user is in Claude Code (not Claude Desktop) and Drive MCP is unavailable [ASSUMED — MEDIUM] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| sooperset/mcp-atlassian | Official atlassian/atlassian-mcp-server | Official has fewer tools, SSE transport deprecated 2026-06-30; community has richer tool set |
| Official Figma remote MCP | Third-party arinspunk/claude-talk-to-figma-mcp | Third-party requires WebSocket relay server; official is maintained by Figma directly |
| Community Google Drive MCP | Hardcoded Google Drive REST API | Custom API code is explicitly out of scope per STATE.md locked decision |

---

## Architecture Patterns

### Recommended Project Structure (Phase 13 additions)

```
silver-bullet/
├── skills/
│   └── silver-ingest/          # NEW: primary Phase 13 deliverable
│       └── SKILL.md
├── hooks/
│   ├── pr-traceability.sh      # NEW: PostToolUse on gsd-ship
│   ├── uat-gate.sh             # NEW: PreToolUse on gsd-complete-milestone
│   └── hooks.json              # MODIFIED: register pr-traceability + uat-gate
└── (per-project, not in plugin):
    .planning/
    ├── SPEC.md                 # Input: must exist (Phase 12) or is created by silver-ingest
    ├── SPEC.main.md            # NEW: read-only cross-repo spec cache (REPO-01)
    ├── DESIGN.md               # Created/extended by silver-ingest Figma branch
    └── INGESTION_MANIFEST.md   # NEW: resumability state file (INGT-05, INGT-07)
```

### Pattern 1: silver-ingest SKILL.md Structure

**What:** silver-ingest follows the same SKILL.md authoring pattern as silver-spec — pre-flight, step-skip protocol, numbered steps with non-skippable gates. Each connector is a conditional branch, not a separate skill.

**Structural skeleton:**

```markdown
## Pre-flight: Mode Detection
Read .planning/INGESTION_MANIFEST.md if it exists — load prior state.
Determine run mode: --source-url (cross-repo fetch) vs artifact ingestion.

## Step 0: Prerequisite Check
Verify required MCP connectors are available. Emit [ARTIFACT MISSING] for unavailable connectors.

## Step 1: JIRA Fetch (conditional — if JIRA ticket key provided)
Call jira_get_issue with the provided key.
Extract: summary, description, AC field, linked issues, attachment metadata.
For each Confluence URL in description: call confluence_get_page.
Record: JIRA entry in INGESTION_MANIFEST.md (status: success | failed).

## Step 2: Artifact Link Resolution (conditional — INGT-02)
Parse JIRA description for Google Drive URLs, Figma URLs, Confluence URLs.
For each URL found: dispatch to appropriate Step (Step 3 for Figma, Step 4 for Google Docs).

## Step 3: Figma Extraction (conditional — if Figma URL present)
Prompt user: "Open Figma and select the target frame(s), then confirm."
Call get_design_context and get_variable_defs.
Write extracted data to .planning/DESIGN.md using DESIGN.md.template structure.
Record: Figma entry in INGESTION_MANIFEST.md.

## Step 4: Google Docs Extraction (conditional — if Google Doc URL present)
Attempt extraction via Drive MCP read_document (or Workspace CLI fallback).
Record: Google Doc entry in INGESTION_MANIFEST.md.

## Step 5: Cross-Repo Fetch (--source-url mode only)
gh api or GitHub raw URL fetch of main repo SPEC.md.
Write to .planning/SPEC.main.md as read-only (add "# READ-ONLY" header).
Record: cross-repo fetch in INGESTION_MANIFEST.md.

## Step 6: Assemble SPEC.md Draft [NON-SKIPPABLE]
Populate SPEC.md template sections from JIRA + Confluence content.
For every failed artifact: insert [ARTIFACT MISSING: {reason}] in relevant section.
Write .planning/SPEC.md (greenfield) or augment existing spec (augment mode).
Increment spec-version if augmenting.

## Step 7: Write INGESTION_MANIFEST.md [NON-SKIPPABLE]
Final state — all artifacts, statuses, timestamps, errors.

## Step 8: Commit all artifacts
```

### Pattern 2: INGESTION_MANIFEST.md as Checkpoint File

**What:** The manifest is both the run record (INGT-05) and the resumability key (INGT-07). On re-run, silver-ingest reads the manifest and skips any artifact with `status: success`.

**Manifest schema:**

```markdown
---
run-id: {YYYY-MM-DD-HHmm}
jira-ticket: {key or null}
source-url: {url or null}
last-updated: {ISO timestamp}
---

# Ingestion Manifest

## Artifacts

| Artifact | Type | Status | Error |
|----------|------|--------|-------|
| PROJ-123 | jira | success | — |
| https://figma.com/... | figma | failed | "Figma MCP not configured" |
| https://docs.google.com/... | google-doc | skipped | "resuming from prior run" |
| https://confluence.../page | confluence | success | — |
```

**Resumability logic:** At the start of each silver-ingest run, read this file. Any artifact with `status: success` is skipped. Any artifact with `status: failed` is retried. The run-id is updated on each run.

### Pattern 3: REPO-01 Cross-Repo Fetch via gh CLI

**What:** `silver-ingest --source-url <github-repo-url>` fetches the main repo's SPEC.md using `gh` CLI and caches it as `.planning/SPEC.main.md` (read-only).

**Exact gh CLI command pattern:**

```bash
# Convert repo URL to raw content fetch
# Input: https://github.com/org/repo
# Target file: .planning/SPEC.md
gh api repos/org/repo/contents/.planning/SPEC.md --jq '.content' | base64 -d > .planning/SPEC.main.md

# Alternative — GitHub raw URL (if gh auth not required)
curl -sL "https://raw.githubusercontent.com/org/repo/main/.planning/SPEC.md" > .planning/SPEC.main.md
```

**Read-only convention:** Prepend `<!-- READ-ONLY: fetched from {source-url} on {date}. Do not edit. -->` to the file. silver-ingest must NOT write to this file after initial fetch except on explicit re-run with --source-url.

### Pattern 4: REPO-02 Version Validation at Session Start

**What:** When a mobile repo has `.planning/SPEC.main.md`, validate that its `spec-version:` matches the version currently in the main repo. Block with diff shown on mismatch.

**Implementation approach:** Add a validation step to silver-bullet.md §0 (Session Start) or to the session-start hook that:

1. Checks if `.planning/SPEC.main.md` exists
2. Reads `spec-version:` from its frontmatter
3. Fetches the current main repo SPEC.md (same `gh api` call)
4. Compares versions — if mismatch: display diff, block with message "Spec version mismatch. Run `/silver:ingest --source-url <url>` to refresh before proceeding."

**Implementation in silver-bullet.md §0 (not a hook):** This is better placed as a silver-bullet.md instruction at §0 session start, checked by the AI during session setup. Adding a bash hook would require gh CLI auth to be pre-configured, which is fragile in CI environments. The AI-driven check in §0 handles the interactive case where the developer runs a session.

### Anti-Patterns to Avoid

- **Separate skills per connector:** Don't create silver-ingest-jira, silver-ingest-figma, silver-ingest-gdocs as separate skills. All three connectors are branches inside silver-ingest. Standalone invocability with a single `$ARGUMENTS` input is the goal.
- **Storing INGESTION_MANIFEST.md outside .planning/:** All spec artifacts live in `.planning/`. Manifest must be co-located.
- **Blocking on MCP unavailability:** If a connector is missing, emit `[ARTIFACT MISSING: MCP not configured]` and continue. Never hard-block ingestion for a single failed connector.
- **Skipping the manifest write on failure:** The manifest must be written even on partial failure — that is the resumability guarantee.
- **Modifying SPEC.main.md locally:** The cross-repo cache is read-only. Version validation logic must fetch fresh from the remote for comparison, not diff against the local cache.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JIRA API client | Custom Node.js REST wrapper | Atlassian MCP `jira_get_issue` | Out of scope per STATE.md locked decision; MCP handles auth, rate limits, schema |
| Figma REST export | PNG/SVG export pipeline | Figma remote MCP `get_design_context` | MCP is read-only during beta; write/export is deferred; MCP provides structured data, not raster output |
| Google Drive OAuth flow | Custom OAuth2 implementation | Community Google Drive MCP or Workspace CLI | Same constraint as JIRA; MCP handles auth lifecycle |
| Git submodule for spec sharing | Main repo as submodule in mobile repo | `gh api` raw file fetch | Submodule boundaries block Claude Code's Glob/Grep/Read tools per ARCHITECTURE.md |
| Version diff algorithm | Custom frontmatter parser | `grep -m1 'spec-version:' file` | The comparison is a simple integer check; no library needed |

**Key insight:** silver-ingest is a translation layer (external format → .planning/ markdown), not an integration layer. All actual data retrieval is delegated to MCP connectors the user configures independently.

---

## Common Pitfalls

### Pitfall 1: Silent Partial Failure
**What goes wrong:** A JIRA ticket is fetched, but the linked Figma URL returns no data from the MCP (e.g., user has not opened the file). silver-ingest writes DESIGN.md with empty sections.
**Why it happens:** Skills don't fail loudly by default — they proceed to the next step.
**How to avoid:** Every connector attempt must produce a manifest entry. If the data is empty or the call fails, write `[ARTIFACT MISSING: {reason}]` into the relevant SPEC.md/DESIGN.md section. Never write an empty section.
**Warning signs:** DESIGN.md exists but all sections contain only template placeholder text.

### Pitfall 2: Figma Requires User Interaction
**What goes wrong:** silver-ingest calls `get_design_context` but no frame is selected in Figma, so the MCP returns generic or empty context.
**Why it happens:** Figma MCP operates on the currently selected frame, not a URL. The skill cannot select a frame programmatically.
**How to avoid:** Step 3 (Figma extraction) must include an explicit user prompt: "Open Figma, select the frame(s) to extract, then confirm with Y." Do not call `get_design_context` until confirmed. This step cannot be automated away.
**Warning signs:** DESIGN.md Screens section shows top-level page structure rather than specific component layout.

### Pitfall 3: Spec-Version Mismatch Between Ingested Draft and Existing SPEC.md
**What goes wrong:** User runs silver-ingest on a JIRA ticket but .planning/SPEC.md already exists from a prior silver-spec session. Ingestion overwrites with a draft that has `spec-version: 1`, losing the existing version history.
**Why it happens:** Augment mode detection (same as silver-spec) must be replicated in silver-ingest.
**How to avoid:** Step 0 must check `test -f .planning/SPEC.md`. If it exists: read existing `spec-version:`, increment by 1, write augmented spec (not overwrite). Surface to user: "Existing SPEC.md found (v{N}). Ingestion will augment to v{N+1}."

### Pitfall 4: SPEC.main.md Treated as Editable
**What goes wrong:** Mobile repo developer edits `.planning/SPEC.main.md` locally to resolve a mismatch, defeating the version pinning system.
**Why it happens:** No file-level write protection in markdown repos.
**How to avoid:** (1) Add `<!-- READ-ONLY -->` header in the file. (2) Include in silver-bullet.md §0 mobile-repo checklist: "Do not edit SPEC.main.md directly — it is a read-only cache of the main repo spec." (3) Document in INGESTION_MANIFEST.md that the file was fetched from a remote source.

### Pitfall 5: Atlassian SSE Deprecation
**What goes wrong:** User configures Atlassian MCP with SSE transport; it stops working 2026-06-30.
**Why it happens:** Atlassian deprecated SSE transport; streamable HTTP (`/v1/mcp` endpoint) is the replacement.
**How to avoid:** Document in silver-bullet.md MCP prerequisite section: "Use `/v1/mcp` streamable HTTP endpoint with API token auth. SSE transport is deprecated after 2026-06-30." [VERIFIED: STACK.md]

### Pitfall 6: Resumability State Corruption
**What goes wrong:** The INGESTION_MANIFEST.md is written mid-run then the process is interrupted. On re-run, the manifest shows some artifacts as `success` but SPEC.md was not yet written with their content.
**How to avoid:** Write INGESTION_MANIFEST.md ONLY at Step 7 (after SPEC.md is written). During the run, maintain an in-memory list of completed artifacts. Final manifest write is atomic — all-or-nothing at the end of each completed step sequence.

---

## Code Examples

Verified patterns from direct codebase inspection:

### SKILL.md Pre-flight Pattern (from silver-spec inspection)
```markdown
## Pre-flight: Load Preferences

Read `silver-bullet.md §10` to load user workflow preferences before any other step.

```bash
grep -A 50 "^## 10\. User Workflow Preferences" silver-bullet.md | head -60
```

Display banner:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 SILVER BULLET ► INGEST
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Ticket:  {$ARGUMENTS or "(not specified)"}
Mode:    {artifact-ingest | cross-repo-fetch — detected in Step 0}
```
```

### Hook Registration Pattern (from hooks.json inspection)
```json
{
  "matcher": "Bash",
  "hooks": [
    {
      "type": "command",
      "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/pr-traceability.sh\"",
      "async": false
    }
  ]
}
```
PostToolUse hooks on Bash use `async: false` to ensure the hook completes before Claude proceeds. [VERIFIED: hooks.json direct inspection]

### spec-floor-check.sh Exit Pattern (from hook inspection)
```bash
# Hard block format for PreToolUse hooks
printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}' "$json_reason"
exit 0   # Note: exit 0 always — the deny decision is in the JSON, not the exit code

# Warning-only format (for gsd-fast context)
printf '{"hookSpecificOutput":{"message":"⚠️  WARNING: ..."}}'
exit 0
```
[VERIFIED: spec-floor-check.sh direct inspection]

### gh CLI Cross-Repo Fetch
```bash
# Fetch SPEC.md from main repo using gh API (returns base64-encoded content)
gh api repos/{owner}/{repo}/contents/.planning/SPEC.md --jq '.content' | base64 -d > .planning/SPEC.main.md

# Alternative using GitHub raw URL (no auth required for public repos)
curl -sL "https://raw.githubusercontent.com/{owner}/{repo}/main/.planning/SPEC.md" > .planning/SPEC.main.md
```
[ASSUMED — standard gh CLI usage, not tested in this project]

### Spec-Version Extraction for REPO-02 Validation
```bash
# Extract spec-version from SPEC.main.md frontmatter
pinned_version=$(grep -m1 '^spec-version:' .planning/SPEC.main.md | awk '{print $2}')
```
[VERIFIED: SPEC.md.template frontmatter structure; bash command is standard pattern]

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Atlassian SSE transport | Streamable HTTP `/v1/mcp` endpoint | Deprecated 2026-06-30 | Users must reconfigure before June 2026 |
| Custom API integrations for JIRA/Figma | MCP connectors (user-configured) | v0.14.0 design decision | Zero custom API code in SB |
| Manual spec drafting from external sources | silver-ingest orchestration | Phase 13 (this phase) | Draft SPEC.md from JIRA ticket in one step |

**Deprecated/outdated:**
- SSE transport for Atlassian MCP: deprecated, use streamable HTTP
- Git submodules for spec sharing: blocked by Claude Code tool boundaries, use gh CLI fetch

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Google Drive MCP (community) is the right path for Google Docs extraction | Standard Stack | If Google releases official MCP before Phase 13 ships, community option is unnecessary complexity |
| A2 | Google Workspace CLI provides adequate text extraction for Slides/Docs | Standard Stack | If Workspace CLI auth is more complex than MCP, the fallback path adds setup friction |
| A3 | gh CLI `repos/{owner}/{repo}/contents/` API returns base64 content that can be decoded with `base64 -d` | Code Examples | CLI behavior may vary by platform; macOS uses `base64 -D` on some versions |
| A4 | REPO-02 version validation is better implemented as a silver-bullet.md §0 instruction than a bash hook | Architecture | If teams want automated enforcement (not AI-driven), a hook would be needed |
| A5 | Figma MCP beta remains free through Phase 13 ship date | Standard Stack | If Figma moves to paid before ship, teams need a Figma plan to use INGT-03 |

---

## Open Questions

1. **Google Docs path: MCP vs Workspace CLI**
   - What we know: No official Google MCP exists. Two community options are available.
   - What's unclear: Which option is easier to configure for most teams (Claude Desktop vs Claude Code environments).
   - Recommendation: Default to community Google Drive MCP as primary; document Workspace CLI as alternative. Detect which is available in the prerequisite check step (Step 0).

2. **REPO-02 validation trigger: AI-driven vs hook**
   - What we know: Session-start hooks exist but require bash + gh auth. silver-bullet.md §0 instructions are AI-driven.
   - What's unclear: Teams may want automated enforcement, not relying on AI to read §0 instructions.
   - Recommendation: Implement as §0 silver-bullet.md instruction for Phase 13. Elevate to session-start hook in v2 if teams report skipping.

3. **INGESTION_MANIFEST.md commit behavior**
   - What we know: Other spec artifacts (SPEC.md, DESIGN.md) are committed by the skill.
   - What's unclear: Whether INGESTION_MANIFEST.md should be git-committed or gitignored (it's operational state, not spec content).
   - Recommendation: Commit it. It is part of the audit trail for INGT-05 and must survive across sessions for INGT-07 resumability.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| gh CLI | REPO-01, REPO-02 | Assumed available (existing SB dep) | Existing install | curl + GitHub raw URL |
| Atlassian MCP (user-configured) | INGT-01, INGT-02 | User-configured; not verifiable here | — | [ARTIFACT MISSING] block |
| Figma remote MCP (user-configured) | INGT-03 | User-configured; not verifiable here | Beta | [ARTIFACT MISSING] block |
| Google Drive MCP or Workspace CLI (user-configured) | INGT-04 | User-configured; not verifiable here | — | [ARTIFACT MISSING] block |
| jq | spec-floor-check.sh (already used) | Assumed available (used by existing hooks) | Existing install | — |

**Missing dependencies with no fallback:**
- None that block Phase 13 implementation. All external connectors are user-configured prerequisites, not SB code dependencies.

**Missing dependencies with fallback:**
- All three MCP connectors: if unavailable, ingestion continues with `[ARTIFACT MISSING]` blocks per INGT-06.

---

## Validation Architecture

No automated tests needed for SKILL.md files (they are markdown instructions, not executable code). Shell hooks (pr-traceability.sh, uat-gate.sh) follow the same pattern as existing hooks which have no test suite in this project.

**Manual validation approach for Phase 13:**
- Run silver-ingest with a real JIRA ticket key; verify SPEC.md draft is produced
- Run silver-ingest twice; verify second run skips already-succeeded artifacts
- Introduce a deliberate MCP failure; verify [ARTIFACT MISSING] block appears in SPEC.md
- Run silver-ingest --source-url; verify SPEC.main.md appears with READ-ONLY header
- Run pr-traceability.sh hook; verify SPEC.md Implementations section is populated

---

## Security Domain

Phase 13 adds no new code that handles sensitive data beyond the existing hook pattern. MCP connectors handle authentication independently.

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No — delegated to MCP connectors | User-configured MCP auth |
| V5 Input Validation | Yes — JIRA ticket key, source URLs parsed in bash | `grep -qE` pattern matching; no eval on external input |
| V6 Cryptography | No | — |

**Specific risk:** The `gh api` call in REPO-01 uses whatever auth `gh` has configured (OAuth or token). The skill must not echo credentials in log output. Standard `gh` auth handling is sufficient — no custom credential code.

---

## Sources

### Primary (HIGH confidence)
- Direct inspection: `/Users/shafqat/Documents/Projects/silver-bullet/.planning/research/STACK.md` — MCP connector capabilities, tool names, limitations
- Direct inspection: `/Users/shafqat/Documents/Projects/silver-bullet/.planning/research/ARCHITECTURE.md` — component responsibilities, hook patterns, data flows
- Direct inspection: `/Users/shafqat/Documents/Projects/silver-bullet/hooks/spec-floor-check.sh` — hook implementation pattern, exit code conventions
- Direct inspection: `/Users/shafqat/Documents/Projects/silver-bullet/hooks/hooks.json` — hook registration format, event matchers
- Direct inspection: `/Users/shafqat/Documents/Projects/silver-bullet/skills/silver-spec/SKILL.md` — SKILL.md authoring pattern, step structure, non-skippable gates
- Direct inspection: `/Users/shafqat/Documents/Projects/silver-bullet/templates/specs/SPEC.md.template` — SPEC.md frontmatter fields, section structure
- Direct inspection: `/Users/shafqat/Documents/Projects/silver-bullet/templates/specs/DESIGN.md.template` — DESIGN.md section structure

### Secondary (MEDIUM confidence)
- `.planning/research/SUMMARY.md` — executive summary, research flags, build order
- `.planning/STATE.md` — locked decisions for v0.14.0

### Tertiary (LOW confidence — training knowledge)
- gh CLI `repos/{owner}/{repo}/contents/` API behavior — [ASSUMED]
- Google Workspace CLI vs Drive MCP ease-of-configuration — [ASSUMED]

---

## Metadata

**Confidence breakdown:**
- silver-ingest SKILL.md structure: HIGH — direct pattern inspection from silver-spec
- Hook registration and patterns: HIGH — direct inspection of existing hooks
- JIRA MCP tool names and field inventory: MEDIUM — confirmed from project research, community sources
- Figma MCP tool names: MEDIUM — official docs light on schema per STACK.md
- Google Docs ingestion path: LOW — community options only; no official Google MCP
- Cross-repo fetch via gh CLI: MEDIUM — standard gh CLI behavior, not tested in this project

**Research date:** 2026-04-09
**Valid until:** 2026-05-09 (stable domain except Figma MCP beta status — recheck if Figma announces pricing changes)
