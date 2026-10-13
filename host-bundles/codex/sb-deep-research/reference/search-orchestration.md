# Search Orchestration (SB-owned)

Retrieval routing for `silver-deep-research`. **No TopGun dependency.**

## Flow

```text
classify intent → route channel → probe search-cli → portal dispatch (landscape only)
  → relevance_gate → record in run_manifest.json → sources.jsonl
```

## Intent classification

Load `reference/catalogs/intent_classes.json`. Map research question + `research_type`
from `run_manifest.json`:

| research_type | Default intent class |
|---------------|---------------------|
| (default) | factual |
| comparison | comparative |
| landscape | landscape |
| market | market |
| technical | technical |

## Provider routing

1. **search-cli** (optional): `search "query" --json -c 10`
2. **Host fallback**: WebSearch / ctx_fetch when search-cli absent
3. **Portals** (landscape only): dispatch per `skill_portals.json`

## Relevance gate

Discard results when:

- Title/snippet empty
- Duplicate canonical_locator already in `sources.jsonl`
- Below mode source budget (see `phases.yaml` budgets)

## Manifest recording

`run_manifest.json` must include:

```json
{
  "search_cli": {"status": "available|partial|unavailable", "providers_available": []},
  "retrieval": {
    "intent_class": "landscape",
    "portals_attempted": ["skills_sh", "github"],
    "portals_succeeded": ["skills_sh"],
    "fallback_reason": null
  }
}
```

## Non-landscape rule

Portal descriptors **must not** run unless `research_type` is `landscape` or
`skill-comparison`.

## Deep / ultradeep degradation

When optional providers missing, set `fallback_reason` and continue if evidence
thresholds can pass; otherwise record user-action recommendation in `handoff.md`.
