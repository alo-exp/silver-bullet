# Adapter: GitHub

**Registry:** GitHub  
**Method:** WebFetch GET (GitHub REST API)  
**Timeout:** 8 seconds

---

## Authentication (Optional)

Retrieve a GitHub token for higher rate limits:

```bash
node "$CODEX_PLUGIN_ROOT/bin/topgun-tools.cjs" keychain-get github_token
```

- If a token is returned, add header: `Authorization: Bearer {token}`.
- If not found, proceed without the header (unauthenticated, 60 req/hr limit).
- **Never log or write the token to any file.**

---

## Request

```
GET https://api.github.com/search/repositories?q={query}+topic:claude-skill&sort=stars&per_page=20
```

- URL-encode the query portion before inserting it (do not encode the `+topic:claude-skill` suffix separately — append it after encoding the query).
- Include header: `Accept: application/vnd.github+json`
- Include header: `X-GitHub-Api-Version: 2022-11-28`
- Include `Authorization: Bearer {token}` if token was retrieved.

---

## Timeout + Retry

- Set fetch timeout to 8 seconds.
- On HTTP 429 or HTTP 403 with `X-RateLimit-Remaining: 0`: wait 1s, retry;
  wait 2s, retry; wait 4s, retry. After 3 retries return `status: "unavailable"`,
  `reason: "rate limited by GitHub"`.
- On timeout or HTTP 5xx: return `status: "unavailable"`, `reason: "<error detail>"`.

---

## Response Parsing

Parse the JSON response body. The `items` array contains repository objects.
Extract the following fields from each entry (use `null` if absent):

| Response field | Unified schema field |
|----------------|----------------------|
| `full_name` | `name` |
| `description` (truncate to 500 chars, strip markdown/HTML tags before storing) | `description` |
| `html_url` | `install_url` |
| `stargazers_count` | `stars` |
| `pushed_at` | `last_updated` |
| *(whole object)* | `raw_metadata` |

Set `source_registry: "github"` on every result.  
Set `content_sha: null` (not available from this registry).

---

## Return Value

```json
{
  "registry": "github",
  "status": "ok",
  "reason": null,
  "results": [ /* unified schema objects */ ],
  "latency_ms": 0
}
```

On failure:

```json
{
  "registry": "github",
  "status": "unavailable",
  "reason": "<reason string>",
  "results": [],
  "latency_ms": 0
}
```
