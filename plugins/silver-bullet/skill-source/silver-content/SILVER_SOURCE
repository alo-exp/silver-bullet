---
name: "silver:content"
title: "Content"
description: >
  This skill should be used for SB-owned public content, documentation,
  search-readiness, migration, optimization, and article-writing workflows.
argument-hint: "<content scope> [--mode audit|fix|migrate|optimize|write]"
version: 0.1.0
---

# /silver:content - Content And Search Workflow

SB-owned content workflow for public docs, marketing/site copy, help centers,
blog/article drafts, search metadata, AI-citation readiness, and content
migrations. It works with `silver:ensure-docs` for governed project docs and
`silver:domain-audit --pack content-search` for public-facing quality.

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
3. Invoke or apply `silver:domain-audit --pack content-search`; add
   `accessibility`, `performance-resource`, or `ui-system` for rendered pages.
4. Classify edits into safety tiers:
   - safe: encoding, typo, markdown syntax, obvious link/metadata fixes;
   - moderate: headings, summaries, redirects, frontmatter, internal links;
   - high-risk: factual claims, legal/compliance text, brand positioning,
     destructive migrations, or broad generated prose.
5. Apply only safe or approved moderate edits automatically.
6. Run available build, link, search metadata, or browser checks.
7. Route governed docs changes through `silver:ensure-docs`.

## Exit Gate

Content work passes only when edited claims are sourced, rendered output is
verified where applicable, and high-risk changes are approved or tracked.
