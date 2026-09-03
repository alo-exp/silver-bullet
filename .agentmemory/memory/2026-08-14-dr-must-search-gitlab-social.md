# 2026-08-14 — DR must-search: GitLab, YouTube, LinkedIn, X, Facebook

type: decision
concepts: gitlab, youtube, linkedin, twitter, x-api, facebook, must-search, search-cli, search-gateway

## Decisions

- GitLab.com Search API (`GET /api/v4/search`, PAT required, 10 req/min search cap) is **first-class must-search**, not a weak secondary `site:` domain. Adapter belongs in **SB gateway**, not search-cli first.
- YouTube Data API v3 `search.list` is **MVP-adjacent**. Live quota (2026-08-14): **100 search.list/day at 1 unit**, plus 10k other-endpoint units — not the old “100 units × 10k pool” folklore.
- LinkedIn: no self-serve global post search. Legal path = Marketing/CM **partner** (page-admin) + `site:linkedin.com` via `-p brave,serper`. RapidAPI scrapers = ToS risk. Sales Nav is not our API.
- X: **pay-per-usage credits** (no Basic/Pro monthly SKUs on live pricing). `search/recent` (7d) + `search/all` (archive). Buy credits. Nitter unofficial / session-token required — not a gateway path.
- Facebook: **EXCLUDE from must-search**. Graph public post search docs 404; CrowdTangle DNS dead; Content Library academic-only.

## search-cli

- Use existing `-p brave,serper` + `site:`. Do not invent `--providers` / `--no-fanout`.
- Remaining gaps: `--cache-dir` + native SE/HN/Discourse.
- `-m social` (xAI) and `-m people` (Exa) exist; not 10-agent default.

## Artifacts

- research/2026-08-14-dr-must-search-channels/SEARCH-CHANNELS.md
- research/2026-08-14-dr-must-search-channels/SOCIAL-AND-GITLAB.md
- skills/silver-deep-research/reference/catalogs/source_channels.json
- skills/silver-deep-research/reference/catalogs/authority_domains.json (gitlab.com code tier secondary → primary)
