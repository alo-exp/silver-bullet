---
adapter: skillsmp
registry: SkillsMP
tier: 2
status: active
auth_required: false
timeout_ms: 8000
max_retries: 3
---

# SkillsMP Adapter

Searches the SkillsMP registry for skills. Confirmed returning 200 with valid JSON results as of 2026-04-26.

## Status

The endpoint `https://skillsmp.com/api/v1/skills/search` previously returned 403, but confirmed
returning 200 with valid JSON results on 2026-04-26. This adapter is now fully active.

## Request

```
GET https://skillsmp.com/api/v1/skills/search?q={query}
```

Auth status unknown — no API key available.

### Step 1 — Build request URL

```
https://skillsmp.com/api/v1/skills/search?q={url_encode(query)}
```

### Step 2 — WebFetch with timeout

Perform a WebFetch GET to the constructed URL.

- Timeout: **8 seconds**
- On timeout: return unavailable (see Return Value)

## Timeout + Retry

### Retry on 429

If the response status is `429 Too Many Requests`:

| Attempt | Wait before retry |
|---------|-------------------|
| 1st retry | 1 second |
| 2nd retry | 2 seconds |
| 3rd retry | 4 seconds |

After 3 retries with no success, return unavailable result.

### Handle non-200 and errors

On 403, 4xx, 5xx, timeout, or network error:

```json
{
  "status": "unavailable",
  "reason": "SkillsMP API returned {status_code} or timed out",
  "results": [],
  "registry": "skillsmp",
  "latency_ms": {elapsed_ms}
}
```

## Response Parsing

If the API returns 200, map results to unified schema:

| response field | unified field | notes |
|---------------|---------------|-------|
| `name` or `title` | `name` | use whichever is present |
| `description` (truncate to 500 chars, strip markdown/HTML tags before storing) | `description` | |
| `"skillsmp"` | `source_registry` | hardcoded |
| `downloads` or `installs` | `install_count` | null if absent |
| `stars` or `rating` | `stars` | null if absent |
| `null` | `security_score` | computed by SecureSkills |
| `updated_at` or `last_updated` | `last_updated` | ISO-8601 if available |
| `null` | `content_sha` | computed by SecureSkills |
| `install_url` or constructed | `install_url` | construct from identifier if needed |
| full response item | `raw_metadata` | preserve entire object |

## Return Value

```json
{
  "status": "ok",
  "reason": null,
  "results": [ /* mapped array */ ],
  "registry": "skillsmp",
  "latency_ms": {elapsed_ms}
}
```

## Threat Mitigations

- **T-02-05 (Spoofing):** All raw response data is stored in `raw_metadata`. The topgun-finder orchestrator applies structural envelope before downstream processing.
- **T-02-06 (DoS):** Non-200 returns immediately without retry. 8-second timeout + exponential backoff on 429 prevents stalling.

## Notes

- Confirmed returning 200 with valid JSON on 2026-04-26. Previously returned 403 during initial research (Phase 1).
- If an API key becomes available, add it as `Authorization: Bearer {key}` and retrieve it via `$CODEX_PLUGIN_ROOT/bin/topgun-tools.cjs keychain-get skillsmp_api_key`.
