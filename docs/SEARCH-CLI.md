# search-cli — Optional Deep Research Provider

Silver Bullet can use [`search-cli`](https://github.com/199-biotechnologies/search-cli)
as the primary retrieval tool for `/silver:deep-research`.

## Role

`search-cli` is optional. `silver:deep-research` works without it, but when it is
configured the deep research engine uses it first for multi-provider retrieval
before falling back to host search/fetch tools.

## Install

```bash
brew tap 199-biotechnologies/tap && brew install search-cli
```

Configure at least one provider key:

```bash
search config set keys.brave YOUR_KEY
```

Provider classes:

| Class | Providers | Best for |
|-------|-----------|----------|
| Web breadth | Brave, Serper | General web recency and broad coverage |
| Semantic | Exa | Neural/semantic discovery and related work |
| Extraction | Jina, Firecrawl | Page extraction and scraping |

## SB Behavior

- `quick` and ordinary `standard` research degrade to host search/fetch when
  search-cli is absent.
- `deep` and `ultradeep` research record missing providers in
  `run_manifest.json`.
- The agent recommends provider signup/setup only when the selected research
  depth cannot meet evidence thresholds with available fallbacks.
- A missing provider is not a blanket blocker. It blocks only when the user asked
  for maximum rigor and the available sources are insufficient.

## Evidence

Every run records:

```json
{
  "search_cli": {
    "status": "available | partial | unavailable",
    "providers_available": [],
    "providers_missing": [],
    "fallback_reason": null
  }
}
```

The manifest lives under `.planning/research/<date>-<slug>/run_manifest.json`.
