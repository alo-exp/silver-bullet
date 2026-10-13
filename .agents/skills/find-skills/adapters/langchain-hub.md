# Adapter: LangChain Hub

**Registry:** LangChain Hub (LangSmith)  
**Method:** WebFetch GET  
**Timeout:** 8 seconds

---

## Request

```
GET https://api.smith.langchain.com/api/v1/repos?q={query}&is_public=true&limit=20
```

- URL-encode the query string.
- No auth required for public repos.

## Authentication (optional)

Retrieve API key:

```bash
node "$CODEX_PLUGIN_ROOT/bin/topgun-tools.cjs" keychain-get langsmith_api_key
```

If found, include `X-API-Key: {key}` header. Never log the key.

## Timeout + Retry

- On HTTP 429: wait 1s, retry; wait 2s, retry; wait 4s, retry.
- On timeout or 5xx: return `status: "unavailable"`.

## Response Parsing

Expected shape: `{ repos: [...], total }`.

| Response field | Unified schema field |
|----------------|----------------------|
| `repo_handle` or `full_name` | `name` |
| `description` (truncate to 500 chars, strip markdown/HTML tags before storing) | `description` |
| `html_url` or `https://smith.langchain.com/hub/{full_name}` | `install_url` |
| `num_likes` | `stars` |
| `last_commit_at` or `updated_at` | `last_updated` |
| `latest_commit_hash` | `content_sha` |
| `num_downloads` | `install_count` |
| *(whole object)* | `raw_metadata` |

Set `source_registry: "langchain-hub"` on every result.

## Return Value

```json
{
  "registry": "langchain-hub",
  "status": "ok",
  "reason": null,
  "results": [ /* unified schema objects */ ],
  "latency_ms": 0
}
```
