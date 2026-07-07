# Adapter: GitLab

**Registry:** GitLab  
**Method:** WebFetch GET (GitLab REST API v4)  
**Timeout:** 8 seconds

---

## Authentication (Optional)

Retrieve a GitLab token for higher rate limits:

```bash
node "$CODEX_PLUGIN_ROOT/bin/topgun-tools.cjs" keychain-get gitlab_token
```

- If a token is returned, add header: `PRIVATE-TOKEN: {token}`.
- If not found, proceed without the header (unauthenticated requests allowed).
- **Never log or write the token to any file.**

---

## Request

```
GET https://gitlab.com/api/v4/projects?search={query}+claude-skill&order_by=star_count&per_page=20
```

- URL-encode the query before inserting it (do not encode the `+claude-skill` suffix separately — append it after encoding the query).
- Include `PRIVATE-TOKEN: {token}` header if token was retrieved.

---

## Timeout + Retry

- Set fetch timeout to 8 seconds.
- On HTTP 429: wait 1s, retry; wait 2s, retry; wait 4s, retry. After 3 retries
  return `status: "unavailable"`, `reason: "rate limited by GitLab"`.
- On timeout or HTTP 5xx: return `status: "unavailable"`, `reason: "<error detail>"`.

---

## Response Parsing

Parse the JSON response body. The response is a top-level array of project objects.
Extract the following fields from each entry (use `null` if absent):

| Response field | Unified schema field |
|----------------|----------------------|
| `path_with_namespace` | `name` |
| `description` (truncate to 500 chars, strip markdown/HTML tags before storing) | `description` |
| `web_url` | `install_url` |
| `star_count` | `stars` |
| `last_activity_at` | `last_updated` |
| *(whole object)* | `raw_metadata` |

Set `source_registry: "gitlab"` on every result.  
Set `content_sha: null` (not available from this registry).

---

## Return Value

```json
{
  "registry": "gitlab",
  "status": "ok",
  "reason": null,
  "results": [ /* unified schema objects */ ],
  "latency_ms": 0
}
```

On failure:

```json
{
  "registry": "gitlab",
  "status": "unavailable",
  "reason": "<reason string>",
  "results": [],
  "latency_ms": 0
}
```
