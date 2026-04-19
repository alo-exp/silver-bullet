---
name: silver-ingest
description: "External artifact ingestion: JIRA/Figma/Google Docs to SPEC.md + DESIGN.md via MCP connectors, plus cross-repo spec fetch with version pinning"
argument-hint: "<JIRA ticket key, --source-url <repo-url>, or artifact URL>"
version: 0.1.0
---

# /silver:ingest — External Artifact Ingestion Workflow

SB orchestrator for external artifact ingestion. Pulls JIRA tickets, Figma designs, Google Docs, and Confluence pages into canonical `.planning/SPEC.md` + `.planning/DESIGN.md` format. Also handles cross-repo spec fetching for multi-repo workflows.

Never calls APIs directly — delegates all data retrieval to MCP connectors the user configures independently.

## Pre-flight: Load Preferences

Read `silver-bullet.md §10` to load user workflow preferences before any other step. Silently apply any stored routing, skip, tool, or mode preferences throughout this workflow.

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

## Step-Skip Protocol

When the user requests skipping any step:
1. Explain why the step exists (one sentence)
2. Offer: A. Accept skip  B. Lightweight alternative  C. Show me what you have
3. If user chooses A permanently: record in silver-bullet.md §10b and templates/silver-bullet.md.base §10b, then commit both files.

**Non-skippable gates:** `Step 6: Assemble SPEC.md Draft`, `Step 7: Write INGESTION_MANIFEST.md`, `Step 7a: Review INGESTION_MANIFEST.md`. Refuse skip requests for these regardless of §10.

## Step 0: Mode Detection + Prerequisite Check

**Parse $ARGUMENTS:**
- If $ARGUMENTS starts with `--source-url`: set mode = `cross-repo-fetch`. Extract repo URL from the argument (format: `--source-url https://github.com/{owner}/{repo}`). Jump to Step 5 after completing prerequisite checks below.
- Otherwise: set mode = `artifact-ingest`. The remaining argument is either a JIRA ticket key (e.g. `PROJ-123`) or a direct artifact URL (Figma or Google Doc).

**Resumability check — read prior manifest if present:**

```bash
test -f .planning/INGESTION_MANIFEST.md && echo "manifest exists" || echo "fresh run"
```

If `.planning/INGESTION_MANIFEST.md` exists: read it and load prior artifact statuses into memory. Display:

```
Resuming from prior run: {N} artifacts already succeeded — will skip those.
```

**Augment vs greenfield detection:**

```bash
test -f .planning/SPEC.md && echo "augment" || echo "greenfield"
```

- If `.planning/SPEC.md` exists: augment mode. Read the existing `spec-version:` from frontmatter. Display: "Existing SPEC.md found (v{N}). Ingestion will augment to v{N+1}."
- If `.planning/SPEC.md` does not exist: greenfield mode. SPEC.md will be created with `spec-version: 1`.

**MCP connector availability check:**

Attempt to list available MCP tools. For each expected connector, note its status:
- Atlassian MCP (for `jira_get_issue`, `confluence_get_page`)
- Figma remote MCP (for `get_design_context`, `get_variable_defs`)
- Google Drive MCP (for `read_document`)

Display availability table:

```
Connector check:
  Atlassian MCP   {available | [CONNECTOR UNAVAILABLE]}
  Figma MCP       {available | [CONNECTOR UNAVAILABLE]}
  Google Drive MCP{available | [CONNECTOR UNAVAILABLE] — will try WebFetch fallback}
```

Do NOT hard-block if any connector is unavailable. Ingestion continues; unavailable connectors produce `[ARTIFACT MISSING]` blocks in the output. Each connector failure is independent.

**Note on Atlassian MCP transport:** If configuring the Atlassian MCP, use the `/v1/mcp` streamable HTTP endpoint with API token auth. SSE transport is deprecated after 2026-06-30.

Update the Mode field in the banner before proceeding.

## Step 1: JIRA Fetch

**Conditional — only if a JIRA ticket key is present in $ARGUMENTS (artifact-ingest mode).**

A JIRA ticket key matches the pattern `[A-Z]+-[0-9]+` (e.g. `PROJ-123`, `CORE-456`).

**Resumability:** If the manifest from Step 0 shows this ticket key with `status: success`, skip with:
```
JIRA ticket {key} already ingested (from prior run). Skipping.
```

**Fetch via Atlassian MCP:**

Call `jira_get_issue` with the provided key. Extract the following fields:
- `summary` — ticket title
- `description` — full ticket body (Atlassian Document Format or plain text)
- Acceptance criteria field (commonly `customfield_10016` or dedicated AC field — check the response for fields containing "criteria" or "acceptance")
- `issuelinks` — linked JIRA issues
- `attachment` metadata (filenames, URLs — do not download binary attachments)

**Confluence page resolution:**

For each Confluence URL found in the JIRA description body: call `confluence_get_page` to fetch the page content. Add the fetched content to the in-memory context alongside the JIRA content.

**On Confluence page fetch failure:**

Record `status: failed` for this Confluence page in the in-memory artifact list. Insert `[ARTIFACT MISSING: Confluence page fetch failed — {error}]` in the SPEC.md section that references this Confluence page (typically Overview or UX Flows). Do NOT bury the failure in the Assumptions section — it must appear inline at the point where the content was expected.

**URL parsing from JIRA description:**

Scan the description body and linked fields for these URL patterns:
- Google Drive URLs (`docs.google.com`, `drive.google.com`) → queue for Step 4
- Figma URLs (`figma.com/file/`, `figma.com/design/`) → queue for Step 3
- Confluence URLs (`atlassian.net/wiki/`, `.confluence.com/`) → already fetched above

Store all queued URLs in-memory for use in Steps 2-4.

**On MCP call failure:**

Record `status: failed` with the error reason in-memory. Store the placeholder `[ARTIFACT MISSING: JIRA fetch failed — {error}]` to be inserted in the Overview section of SPEC.md during Step 6.

Record the JIRA entry in the in-memory artifact list. Do NOT write the manifest yet (per Pitfall 6 — manifest is written atomically at Step 7 only).

## Step 2: Artifact Link Resolution

**Conditional — only if URLs were found during Step 1, or if $ARGUMENTS contains a direct Figma or Google Doc URL (no JIRA ticket provided).**

For each queued URL from Step 1 (or from $ARGUMENTS directly):
- Google Drive URLs → queue for Step 4 (Google Docs Extraction)
- Figma URLs → queue for Step 3 (Figma Extraction)
- Confluence URLs → already resolved in Step 1

If no JIRA ticket was provided but $ARGUMENTS contains a direct Figma URL or Google Doc URL:
- Queue the URL for the appropriate step (Step 3 or Step 4)
- There will be no JIRA content for Step 6; SPEC.md Overview will contain `[ARTIFACT MISSING: no JIRA ticket provided — populate Overview manually]`

Display a summary of queued artifacts before proceeding:

```
Artifacts queued for extraction:
  JIRA:        {key or none}
  Figma:       {URL or none}
  Google Docs: {URL or none}
  Confluence:  {count} pages (already fetched in Step 1)
```

## Step 3: Figma Extraction

**Conditional — only if a Figma URL is queued from Steps 1-2.**

**Resumability:** If the manifest shows this Figma URL with `status: success`, skip with:
```
Figma URL {url} already extracted (from prior run). Skipping.
```

**User confirmation required — do NOT call MCP tools before this step:**

Display to user:
```
Figma extraction ready.
Open Figma and select the target frame(s) you want to extract.
Once the frame(s) are selected in Figma, confirm with Y to proceed.
```

Wait for user confirmation. Do not call `get_design_context` until the user confirms. This step cannot be automated — Figma MCP operates on the currently selected frame, not a URL.

**Extract design context:**

Call `get_design_context` via the Figma MCP. This returns a structured design representation of the selected frame(s):
- Component hierarchy
- Layout information
- Component names and variants

**Extract design tokens:**

Call `get_variable_defs` via the Figma MCP. This returns variable definitions:
- Colors (fills, strokes, backgrounds)
- Spacing values
- Typography (font family, size, weight, line height)

**Write `.planning/DESIGN.md`:**

Read `templates/specs/DESIGN.md.template` for canonical structure. Populate sections:
- `## Screens` — from design context component hierarchy and layout; include one sub-section per major screen/frame extracted
- `## Components` — from component names and state variants found in design context
- `## Behavior Specifications` — from interaction patterns if available in design context (triggers, conditions, responses)
- `## State Definitions` — from component state variants (default, loading, error, empty, success)
- `## Design Tokens (from Figma)` — from variable definitions (colors, spacing, typography)

Set frontmatter:
- `figma-url:` — the Figma URL
- `linked-spec: .planning/SPEC.md`
- `last-updated:` — today's date

**On MCP call failure or empty response:**

Record `status: failed` in-memory. Write `[ARTIFACT MISSING: Figma extraction failed — {error}]` in the relevant DESIGN.md sections instead of empty sections. Never write empty sections.

Record the Figma entry in the in-memory artifact list.

## Step 4: Google Docs Extraction

**Conditional — only if a Google Doc or Google Drive URL is queued from Steps 1-2.**

**Resumability:** If the manifest shows this URL with `status: success`, skip with:
```
Google Doc {url} already extracted (from prior run). Skipping.
```

**Primary extraction path — Google Drive MCP:**

Attempt extraction via Google Drive MCP `read_document` tool. Pass the document URL or file ID.

**Fallback extraction path — WebFetch:**

If the Google Drive MCP is unavailable or returns an error, attempt via the WebFetch tool (for publicly accessible documents). WebFetch can retrieve plain-text content from public Google Docs.

**Content handling:**

Extract text content from the document. For documents with embedded images:
- Note each image location: "Image at [position] — manual review recommended"
- Vision extraction from Google Docs images is best-effort; complex visual content requires manual review

Store the extracted text content in-memory for use in Step 6 (SPEC.md assembly). The Google Doc content supplements JIRA data — it is merged into the relevant SPEC.md sections.

**On extraction failure (both primary and fallback paths):**

Record `status: failed` in-memory. Store `[ARTIFACT MISSING: Google Doc extraction failed — {error}]` for insertion in Step 6. Do not block the run.

Record the Google Doc entry in the in-memory artifact list.

## Step 5: Cross-Repo Fetch

**Only active when mode = `cross-repo-fetch` (i.e. $ARGUMENTS starts with `--source-url`).**

**Parse repo URL** from $ARGUMENTS. Expected format: `https://github.com/{owner}/{repo}`

Extract `{owner}` and `{repo}` from the URL.

**Input validation (BFIX-01 — shell injection prevention):**

After extracting `{owner}/{repo}` from the URL, validate the combined string against:
```bash
if ! printf '%s' "{owner}/{repo}" | grep -qE '^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$'; then
  echo "ERROR: Invalid repository identifier. Must match owner/repo with alphanumeric characters, dots, hyphens, underscores only."
  # Record failed status and skip to Step 7
fi
```

Do NOT pass `{owner}` or `{repo}` to any shell command (`gh api`, `curl`) until this validation passes. If validation fails, record `status: failed` with error "Invalid repository identifier" in the in-memory artifact list and skip to Step 7 (manifest write).

**Fetch SPEC.md via gh CLI (primary path):**

```bash
/opt/homebrew/bin/gh api repos/{owner}/{repo}/contents/.planning/SPEC.md --jq '.content' | base64 -d > .planning/SPEC.main.md
```

**Fallback — GitHub raw URL (if gh CLI auth fails):**

Detect the default branch first, then fetch:

```bash
DEFAULT_BRANCH=$(/opt/homebrew/bin/gh api "repos/{owner}/{repo}" --jq '.default_branch' 2>/dev/null || echo "main")
curl -sfL "https://raw.githubusercontent.com/{owner}/{repo}/${DEFAULT_BRANCH}/.planning/SPEC.md" > .planning/SPEC.main.md
if [[ ! -s .planning/SPEC.main.md ]]; then
  # Try master as last resort
  curl -sfL "https://raw.githubusercontent.com/{owner}/{repo}/master/.planning/SPEC.md" > .planning/SPEC.main.md
fi
```

**Annotate as read-only:**

Prepend the following comment to the file immediately after writing:

```
<!-- READ-ONLY: fetched from {source-url} on {date}. Do not edit. Refresh by re-running /silver:ingest --source-url {source-url} -->
```

**Version extraction:**

Read the `spec-version:` field from the fetched file's frontmatter:

```bash
grep -m1 '^spec-version:' .planning/SPEC.main.md | awk '{print $2}'
```

Display: "Fetched SPEC.md (v{version}) from {owner}/{repo}."

**Version mismatch diff:**

When the fetched spec version differs from the local `.planning/SPEC.md` version, show a
content diff summary so the user can assess what changed — not just version numbers:

```bash
LOCAL_VER=$(grep -m1 '^spec-version:' .planning/SPEC.md 2>/dev/null | awk '{print $2}')
REMOTE_VER=$(grep -m1 '^spec-version:' .planning/SPEC.main.md | awk '{print $2}')
if [[ "$LOCAL_VER" != "$REMOTE_VER" ]]; then
  echo ""
  echo "--- SPEC VERSION MISMATCH ---"
  echo "Local:  v${LOCAL_VER:-unknown}"
  echo "Remote: v${REMOTE_VER:-unknown}"
  echo ""
  echo "Changes in remote spec:"
  diff --unified=1 .planning/SPEC.md .planning/SPEC.main.md | head -60 || true
  echo "--- END DIFF ---"
  echo ""
  echo "Review the diff above. To accept remote changes, copy SPEC.main.md over SPEC.md."
fi
```

**Important constraint:** Do NOT modify `.planning/SPEC.main.md` after the initial fetch except on explicit re-run with `--source-url`. It is a read-only cache of the remote spec.

Record the cross-repo fetch entry in the in-memory artifact list.

**Skip to Step 7** (no SPEC.md assembly needed for cross-repo mode — the fetched file is the read-only cache, not a draft to be authored).

## Step 6: Assemble SPEC.md Draft

**NON-SKIPPABLE GATE.**

**This step is skipped in cross-repo-fetch mode** (Step 5 jumps directly to Step 7).

Read `templates/specs/SPEC.md.template` for canonical structure.

**Determine spec-version:**
- Greenfield mode: `spec-version: 1`
- Augment mode: read existing `spec-version:` from `.planning/SPEC.md` frontmatter, increment by 1

**Populate sections from all collected content (JIRA + Confluence + Google Docs):**

| Section | Source | On Failure |
|---------|--------|-----------|
| `## Overview` | JIRA `summary` + `description` first paragraph | `[ARTIFACT MISSING: no JIRA ticket provided — populate Overview manually]` |
| `## User Stories` | JIRA acceptance criteria field (if present), else derived from description | `[ARTIFACT MISSING: no acceptance criteria in JIRA ticket — add user stories manually]` |
| `## UX Flows` | Flow references in JIRA description or Confluence pages | `[ARTIFACT MISSING: no UX flow found in ticket — populate manually]` |
| `## Acceptance Criteria` | JIRA AC field directly | `[ARTIFACT MISSING: no acceptance criteria in JIRA ticket]` |
| `## Assumptions` | One `[ASSUMPTION: ...]` block for every gap or ambiguity found during ingestion | At minimum one assumption block per incomplete section |
| `## Open Questions` | Linked JIRA issues, unresolved references, TBD items in description | Leave as template placeholder if nothing identified |
| `## Out of Scope` | JIRA scope statements if explicitly present | Leave as template placeholder — do not fabricate scope |
| `## Implementations` | Leave as template comment (populated by pr-traceability.sh post-merge) | — |

**Assumption block format:**

```
[ASSUMPTION: {what SB is assuming about missing or ambiguous content} | Status: Follow-up-required | Owner: TBD]
```

**For every failed artifact:** Insert `[ARTIFACT MISSING: {reason}]` in the relevant section. NEVER write an empty section. An empty section is a silent failure — it must always surface the missing artifact explicitly.

**Set SPEC.md frontmatter:**

```yaml
spec-version: {calculated above}
status: Draft
jira-id: {ticket key if provided, else ""}
figma-url: {Figma URL if present, else ""}
source-artifacts: [{list of all URLs processed in this run}]
created: {today's date — greenfield only; preserve existing value in augment mode}
last-updated: {today's date}
```

**Write to `.planning/SPEC.md`** using the Write tool.

Display:

```
Draft SPEC.md written (v{version}).
  {N} sections populated
  {M} artifact(s) missing — see [ARTIFACT MISSING] blocks

Next step: run /silver:spec to refine this draft through Socratic elicitation.
```

## Step 7: Write INGESTION_MANIFEST.md

**NON-SKIPPABLE GATE.**

**This step runs in ALL modes** (artifact-ingest and cross-repo-fetch).

Write `.planning/INGESTION_MANIFEST.md` with all artifact statuses. This is the atomic final write — all statuses are committed to the manifest at this point only (per Pitfall 6: do not write partial manifest mid-run).

**Manifest format:**

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
| {artifact identifier} | {jira | figma | google-doc | confluence | cross-repo} | {success | failed | skipped} | {error message or --} |
```

Include ALL artifacts from this run, including:
- Artifacts that succeeded (`status: success`)
- Artifacts that failed (`status: failed`) with the error reason
- Artifacts skipped from a prior run's manifest (`status: skipped`, Error: "resuming from prior run")

On subsequent runs, silver-ingest reads this manifest in Step 0 and skips any `status: success` entries. `status: failed` entries are retried.

### Step 7a: Review INGESTION_MANIFEST.md

**NON-SKIPPABLE GATE.**

Invoke `/artifact-reviewer .planning/INGESTION_MANIFEST.md --reviewer review-ingestion-manifest` via the Skill tool.

Do NOT proceed to Step 8 until /artifact-reviewer reports 2 consecutive clean passes. If issues are found, /artifact-reviewer will apply fixes and re-review automatically. If /artifact-reviewer surfaces an unresolvable issue after 5 rounds, STOP and present it to the user.

## Step 8: Commit All Artifacts

Stage and commit all artifacts written during this run:

```bash
git add .planning/SPEC.md .planning/DESIGN.md .planning/INGESTION_MANIFEST.md .planning/SPEC.main.md 2>/dev/null || true
git commit -m "spec(ingest): {jira-key or 'cross-repo' or 'manual'} ingestion v{spec-version}"
```

If in cross-repo-fetch mode, only `.planning/SPEC.main.md` and `.planning/INGESTION_MANIFEST.md` will be present — the `2>/dev/null || true` handles absent files gracefully.

## Step 9: Summary

Display closing banner:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 INGESTION COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Source:       {JIRA key / source-url / manual}
Artifacts:    {N} attempted, {S} succeeded, {F} failed
Spec version: {spec-version or "n/a" for cross-repo mode}
DESIGN.md:    {created | updated | skipped}

Next step: run /silver:spec to refine the draft spec through elicitation.
```

If any artifacts failed, append:

```
{F} artifact(s) failed ingestion. Re-run /silver:ingest to retry failed artifacts.
Review .planning/INGESTION_MANIFEST.md for error details.
```

---

## Reference: Artifact Type Routing

| $ARGUMENTS pattern | Mode | Steps executed |
|-------------------|------|---------------|
| `PROJ-123` (JIRA key) | artifact-ingest | 0 → 1 → 2 → 3 (if Figma) → 4 (if GDoc) → 6 → 7 → 8 → 9 |
| `https://figma.com/...` | artifact-ingest | 0 → 2 → 3 → 6 → 7 → 8 → 9 |
| `https://docs.google.com/...` | artifact-ingest | 0 → 2 → 4 → 6 → 7 → 8 → 9 |
| `--source-url https://github.com/org/repo` | cross-repo-fetch | 0 → 5 → 7 → 8 → 9 |

## Reference: Failure Handling Summary

| Connector | On Failure | Output |
|-----------|-----------|--------|
| Atlassian MCP / `jira_get_issue` | Continue | `[ARTIFACT MISSING: JIRA fetch failed — {error}]` in SPEC.md Overview |
| Atlassian MCP / `confluence_get_page` | Continue per page | `[ARTIFACT MISSING: Confluence page fetch failed — {error}]` in relevant SPEC.md section |
| Figma MCP / `get_design_context` | Continue | `[ARTIFACT MISSING: Figma extraction failed — {error}]` in DESIGN.md sections |
| Google Drive MCP / `read_document` | Try WebFetch fallback | `[ARTIFACT MISSING: Google Doc extraction failed — {error}]` if both fail |
| gh CLI (cross-repo fetch) | Try curl fallback | Surface error to user if both fail; do not write partial SPEC.main.md |

**Invariant:** A connector failure never blocks ingestion of other artifacts. The INGESTION_MANIFEST.md is always written (Step 7) even if all connectors fail.
