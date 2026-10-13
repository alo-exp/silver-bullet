---
adapter: npm
registry: npm
tier: 2
status: active
auth_required: false
timeout_ms: 8000
max_retries: 3
---

# npm Registry Adapter

Searches the npm registry for Claude skills and MCP-compatible packages.

## Request

```
GET https://registry.npmjs.org/-/v1/search?text=claude-skill+{query}&size=20
```

No authentication required.

### Step 1 — Build request URL

Construct the URL by URL-encoding the `{query}` parameter and appending it to the base search text:

```
https://registry.npmjs.org/-/v1/search?text=claude-skill+{url_encode(query)}&size=20
```

### Step 2 — WebFetch with timeout

Perform a WebFetch GET to the constructed URL.

- Timeout: **8 seconds**
- On timeout: return unavailable result (see Return Value)

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

On any `5xx` status, timeout, or network error:

```json
{
  "status": "unavailable",
  "reason": "npm registry returned {status_code} or timed out",
  "results": [],
  "registry": "npm",
  "latency_ms": {elapsed_ms}
}
```

## Response Parsing

The npm search API returns:

```json
{
  "objects": [
    {
      "package": {
        "name": "...",
        "description": "...",
        "date": "2024-01-15T10:00:00.000Z",
        "links": {
          "npm": "https://www.npmjs.com/package/..."
        },
        "publisher": { "username": "..." },
        "keywords": [...]
      },
      "score": { "final": 0.85 }
    }
  ],
  "total": 42,
  "time": "..."
}
```

Map each `objects[].package` to the unified schema:

| npm field | unified field | notes |
|-----------|---------------|-------|
| `package.name` | `name` | direct |
| `package.description` (truncate to 500 chars, strip markdown/HTML tags before storing) | `description` | |
| `"npm"` | `source_registry` | hardcoded |
| `null` | `install_count` | not available from npm search |
| `null` | `stars` | not available from npm search |
| `null` | `security_score` | computed later by SecureSkills |
| `package.date` | `last_updated` | ISO-8601 string |
| `null` | `content_sha` | not exposed by npm search; computed during SecureSkills |
| `"npm install " + package.name` | `install_url` | constructed — validate `package.name` matches `/^(?:@[a-z0-9-~][a-z0-9-._~]*\/)?[a-z0-9-~][a-z0-9-._~]*$/` and is ≤ 214 chars before constructing; set `install_url: null` if validation fails |
| full `package` object | `raw_metadata` | preserve for downstream use |

## Return Value

```json
{
  "status": "ok",
  "reason": null,
  "results": [ /* mapped array */ ],
  "registry": "npm",
  "latency_ms": {elapsed_ms}
}
```

## Threat Mitigations

- **T-02-05 (Spoofing):** All raw npm response data is stored in `raw_metadata` only. Mapped fields use only trusted schema keys. The topgun-finder orchestrator applies the structural envelope before downstream processing.
- **T-02-06 (DoS):** 8-second hard timeout + exponential backoff on 429 prevents stalling the pipeline. On any failure, return `status: "unavailable"` immediately.

## Notes

- npm does not expose download counts in the `/v1/search` endpoint. `install_count` will remain `null` until a secondary lookup is performed.
- The `content_sha` field is intentionally `null` here. It will be populated by the SecureSkills phase when package integrity is verified.
- This adapter uses `$CODEX_PLUGIN_ROOT` base paths when writing cache files (if caching is enabled in a future phase).
