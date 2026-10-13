# Phase 29: Help Center + Homepage — Context

**Gathered:** 2026-04-15
**Status:** Ready for planning
**Source:** Auto-mode (decisions from roadmap + site structure analysis)

<domain>
## Phase Boundary

Update the Silver Bullet website (site/index.html) and help center (site/help/) to reflect the composable paths architecture. Homepage needs updated messaging. Help center needs new concept pages and updated workflow pages. search.js must index new pages.

</domain>

<decisions>
## Implementation Decisions

### Homepage Updates (SITE-01)
- **D-01:** Update site/index.html meta tags (title, description, og:tags) to reference "composable paths" instead of "fixed pipeline".
- **D-02:** Update hero section text to describe composable paths architecture — dynamic composition from 18 paths, not fixed 20-step workflow.
- **D-03:** Update workflow section to show path composition concept instead of linear pipeline.
- **D-04:** Update feature cards to reflect composable architecture, WORKFLOW.md tracking, dual-mode quality gates, 3-tier silver-fast.

### Help Center Concept Pages (SITE-02)
- **D-05:** Create new concept page: `site/help/concepts/composable-paths.html` — explains the 18-path architecture, how /silver composes chains, WORKFLOW.md tracking.
- **D-06:** Create new concept page: `site/help/concepts/artifact-review-assessor.html` — explains the assessor's role in triaging reviewer findings.
- **D-07:** Update existing `site/help/concepts/routing-logic.html` to describe composable path composition instead of fixed routing.
- **D-08:** Update existing `site/help/concepts/verification.html` to mention PATH 11 VERIFY and dual-mode quality gates.
- **D-09:** Update existing `site/help/concepts/documentation.html` to mention PATH 16 DOCUMENT and WORKFLOW.md.

### Help Center Workflow Pages (SITE-03)
- **D-10:** Update `site/help/workflows/silver-feature.html` to describe composable path chain (Composition Proposal, Per-Phase Loop, Supervision Loop).
- **D-11:** Update `site/help/workflows/silver-ui.html` to describe UI-focused path composition (PATH 6 DESIGN CONTRACT, PATH 8 UI QUALITY).
- **D-12:** Update `site/help/workflows/silver-fast.html` to describe 3-tier complexity triage.
- **D-13:** Update remaining workflow pages (silver-bugfix, silver-devops, silver-release, silver-research) with composable paths context — lighter updates.

### Reference Page (SITE-04)
- **D-14:** Update `site/help/reference/index.html` to document artifact-review-assessor, WORKFLOW.md, path contracts reference.

### Search Index (SITE-05)
- **D-15:** Update `site/help/search.js` to index new concept pages (composable-paths, artifact-review-assessor) and updated content.

### Implementation Approach
- **D-16:** Follow existing HTML patterns in site/help/ — no new CSS or JS frameworks. Each page uses the same layout template.
- **D-17:** All pages use relative links to other help pages and to docs/composable-paths-contracts.md.

### Files Modified
- **D-18:** `site/index.html` — homepage updates
- **D-19:** `site/help/concepts/composable-paths.html` — NEW
- **D-20:** `site/help/concepts/artifact-review-assessor.html` — NEW  
- **D-21:** `site/help/concepts/routing-logic.html` — UPDATE
- **D-22:** `site/help/concepts/verification.html` — UPDATE
- **D-23:** `site/help/concepts/documentation.html` — UPDATE
- **D-24:** `site/help/workflows/silver-feature.html` — UPDATE
- **D-25:** `site/help/workflows/silver-ui.html` — UPDATE
- **D-26:** `site/help/workflows/silver-fast.html` — UPDATE
- **D-27:** `site/help/workflows/silver-bugfix.html` — UPDATE
- **D-28:** `site/help/workflows/silver-devops.html` — UPDATE
- **D-29:** `site/help/workflows/silver-release.html` — UPDATE
- **D-30:** `site/help/workflows/silver-research.html` — UPDATE
- **D-31:** `site/help/reference/index.html` — UPDATE
- **D-32:** `site/help/search.js` — UPDATE
- **D-33:** `site/help/concepts/index.html` — UPDATE (add links to new concept pages)
- **D-34:** `site/help/workflows/index.html` — UPDATE (may need composable paths note)

### Claude's Discretion
- Exact hero section copy and meta tag wording
- Level of detail in concept pages (should be accessible to new users)
- Whether to add composable paths diagram/visual to concept page
- How to present the 18-path catalog in help center (table vs cards vs list)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Site Files
- `site/index.html` — Homepage (1910 lines)
- `site/help/index.html` — Help center landing (310 lines)
- `site/help/concepts/routing-logic.html` — Existing routing concept page
- `site/help/concepts/verification.html` — Existing verification concept page
- `site/help/concepts/documentation.html` — Existing documentation concept page
- `site/help/workflows/silver-feature.html` — Primary workflow page
- `site/help/workflows/silver-fast.html` — Fast path workflow page
- `site/help/reference/index.html` — Reference page
- `site/help/search.js` — Search index

### Source of Truth
- `docs/composable-paths-contracts.md` — All 18 path contracts
- `silver-bullet.md` §2h — Composable paths architecture description
- `skills/silver-fast/SKILL.md` — 3-tier triage details
- `templates/workflow.md.base` — WORKFLOW.md template
- `skills/artifact-review-assessor/SKILL.md` — Assessor skill

</canonical_refs>

<code_context>
## Existing Code Insights

### Site Structure
- site/index.html: 1910-line HTML page with hero, features, workflow sections
- site/help/: 24 HTML pages organized into concepts/, workflows/, reference/, troubleshooting/
- site/help/search.js: Client-side search index
- All pages follow same HTML template pattern with consistent nav, footer

### Patterns
- Help pages use `<article>` with consistent heading hierarchy
- Concept pages explain WHY, workflow pages explain HOW
- search.js has entries like `{title, url, content, tags}` for each page

</code_context>

<specifics>
## Specific Ideas

- Homepage hero should emphasize "18 composable paths" and "dynamic composition" as key differentiators
- Concept page for composable-paths should be the most detailed — it's the primary educational resource
- Workflow pages should show which paths each workflow typically composes
- The 2 new concept pages (composable-paths, artifact-review-assessor) are the main new content; everything else is updates

</specifics>

<deferred>
## Deferred Ideas

None — scope covers all success criteria

</deferred>

---

*Phase: 29-help-center-homepage*
*Context gathered: 2026-04-15 via auto mode*
