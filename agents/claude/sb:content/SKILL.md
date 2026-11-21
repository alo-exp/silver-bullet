---
name: sb:content
description: >
  This skill should be used for SB-owned public content, documentation,
  search-readiness, migration, optimization, and article-writing workflows.
argument-hint: "<content scope> [--mode audit|fix|migrate|optimize|write]"
version: 0.1.0
---

# /sb:content - Content And Search Workflow

SB-owned content workflow for public docs, marketing/site copy, help centers,
blog/article drafts, search metadata, AI-citation readiness, and content
migrations. It works with `sb:ensure-docs` for governed project docs and
`sb:domain-audit --pack content-search` for public-facing quality.

**Pre-execution** (blocks content edits until recorded):

`sb:clarify` → `sb:plan`

**Post-execution:** `sb:execute` → `sb:verify` → `sb:ensure-docs`

Queue source: `hooks/lib/orchestrator-state.sh` (`silver-content` composer).

## Output

Write or update `.planning/CONTENT.md`.

The artifact must include:

- content scope and selected mode;
- source inventory and migration/optimization constraints;
- safe edits applied, risky edits deferred, and verification evidence;
- metadata/search findings;
- link/build/render checks where applicable.

## Modes

| Mode | Purpose | Required evidence |
|---|---|---|
| `audit` | Review content quality, encoding, metadata, links, and migration artifacts | file/line findings and content-search result |
| `fix` | Apply safe content repairs | safety tier, diff, build/link verification |
| `migrate` | Move content between formats/CMS/docs structures | source-to-target inventory, redirects/slugs, parity check |
| `optimize` | Improve headings, summaries, snippets, readability, and internal links | before/after rationale and search-readiness evidence |
| `write` | Draft article/help content from approved source material | source citations, frontmatter, audience, review gate |

## Process

1. Display `SILVER BULLET > CONTENT`.
2. Determine whether the content is governed docs, public site copy, help
   center content, search metadata, migration output, or article content.
3. Invoke or apply `sb:domain-audit --pack content-search`; add
   `accessibility`, `performance-resource`, or `ui-system` for rendered pages.
4. Classify edits into safety tiers:
   - safe: encoding, typo, markdown syntax, obvious link/metadata fixes;
   - moderate: headings, summaries, redirects, frontmatter, internal links;
   - high-risk: factual claims, legal/compliance text, brand positioning,
     destructive migrations, or broad generated prose.
5. Apply only safe or approved moderate edits automatically.
6. Run available build, link, search metadata, or browser checks.
7. Route governed docs changes through `sb:ensure-docs`.

## Exit Gate

Content work passes only when edited claims are sourced, rendered output is
verified where applicable, and high-risk changes are approved or tracked.

## Site and help batch protocol (`site/**`)

Use this lightweight V-loop for iterative site/help work. It applies to a project that opts in with `site_profile.enabled` in its `.silver-bullet.json` (see `silver-bullet.md` §8.2); hooks then enforce regression, visual and publish evidence at Stop and before a real push.

### Preconditions

1. Route via `/sb` → `sb:content --mode fix` (or `audit` for read-only review).
2. Under the parent orchestrator, site edits are made by Task workers like all other implementation work; the parent verifies the worker's claims via `/sb:completion-audit`. No hook blocks a parent edit of the site, so this is a rule you follow, not one the hooks check.
3. `graphify query` before exploration; `agentmemory` save after each batch.

### Batch steps (per turn)

| Step | Action | Evidence |
|------|--------|----------|
| 1 Preflight | Run the profile's regression scripts if the last edit is newer than the last pass | script output; `site-regression-gate` pass |
| 2 Implement | Worker edits the site directory only | diff + worker summary |
| 3 Regression | The profile's `regression_scripts` (commit them first: the gate runs only scripts that are committed as they stand) | `site-regression-gate` pass |
| 4 Visual | Screenshots (Alumnium or host browser MCP, e.g. `browser_take_screenshot` at 1280px, light and dark) taken after the last edit; the hook records the screenshot file by itself | `site-visual-evidence.json`, written by the hook only |
| 5 Publish | push the default branch, wait for the deploy, then run `bash <plugin>/scripts/site-live-evidence.sh --marker '<text only the new page contains>'` | `live-publish-evidence.json` for the current HEAD, written by that script only: LIVE or NOT LIVE |

The state directory is protected: never write `site-visual-evidence.json` or `live-publish-evidence.json` yourself.

### Stop gates (runtime)

- `instruction-ledger-gate` — multi-bullet prompts need per-item resolution.
- `site-regression-gate` — blocks Stop and a real `git push` when the site was edited without a passing regression run of committed scripts.
- `site-visual-evidence-gate` and `v-loop-rollup-gate` — block Stop until a screenshot taken after the last edit is recorded.
- `live-publish-evidence-gate` — blocks Stop after a site push or a LIVE claim until fresh evidence for the current HEAD exists.
- `subagent-stop-enforcement` — parent Stop requires `silver-completion-audit` after Task workers.

A Stop gate that already told you once releases on `stop_hook_active` and logs the release to `stop-loop-release.log`.

See `silver-bullet.md` §8.2 and `AGENTS.md` publish policy.
