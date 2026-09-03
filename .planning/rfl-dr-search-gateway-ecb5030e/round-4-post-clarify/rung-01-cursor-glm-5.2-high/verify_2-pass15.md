model: composer-2.5

**Subagent:** `sb-composer-2-5-high`  
**Phase:** VERIFY-ONLY pass 2/2 (`verify_2`, independent of verify_1)  
**Artifact:** `/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md`  
**SHA-256:** `e0b487d4f815919a83c585d01d7d83f94a7122d3166487ac813b030b159f015e` (verified via `shasum -a 256`)  
**Graphify:** `graphify query "dr search gateway AD1 I-40 clear query-cache gitignore"` (200 nodes; oriented AD1 / cache-clear context)  
**Apply ref:** AD1 / I-40 (round-4 post-clarify rung 1 pass 15)

## Verdict

**VERIFY_PASS** — Independent re-read at pinned SHA confirms AD1 / I-40 APPLY items exist at cited locations: §6.12 (~L634) `clear()` preserves query-cache `.gitignore` (seed `{cache_dir}/.gitignore` with `*` / `!.gitignore` and assert it remains) alongside `{quota_dir}/buckets/` and `{quota_dir}/reddit-oauth-token.json`. L85 rollup cites `clear()` preserves query-cache `.gitignore`. Regression guards (Facebook `must_search: false`, X/xweb/search-cli gateway, AC1–AC3 text) remain intact.

## SHA gate

| Check | Status | Evidence |
|-------|--------|----------|
| Plan SHA-256 matches charter | PASS | `shasum -a 256` → `e0b487d4f815919a83c585d01d7d83f94a7122d3166487ac813b030b159f015e` |

## AD1 / I-40 — §6.12 `clear()` preserves query-cache `.gitignore` (~L634)

| Check | Status | Evidence (plan) |
|-------|--------|-----------------|
| `clear()` preserves `{quota_dir}/buckets/` | PASS | L634: `` **preserves** `{quota_dir}/buckets/` `` |
| `clear()` preserves `{quota_dir}/reddit-oauth-token.json` | PASS | L634: `` and `{quota_dir}/reddit-oauth-token.json` `` |
| `clear()` preserves query-cache `.gitignore` | PASS | L634: `` and query-cache `.gitignore` `` |
| Seeds `{cache_dir}/.gitignore` with `*` / `!.gitignore` and asserts it remains | PASS | L634: `` (seed `{cache_dir}/.gitignore` with `*` / `!.gitignore` and assert it remains) `` |
| Preserve set is after quiesce barrier | PASS | L634: `` **after** the quiesce barrier `` |

## L85 rollup

| Check | Status | Evidence (plan) |
|-------|--------|-----------------|
| `clear()` preserves query-cache `.gitignore` recorded | PASS | L85: `` `clear()` preserves query-cache `.gitignore`. `` |
| Companion AC1–AC3 rollup items still present | PASS | L85: `` `clear()` also removes orphaned `last.json.tmp.*`; held reddit lock drives `cache_clear_busy`; token-endpoint does not consume the reddit search bucket. `` |

## Regression guard (Facebook / X / gateway / AC1–AC3)

| Check | Status | Evidence (plan) |
|-------|--------|-----------------|
| Facebook `must_search: false` | PASS | L54: `` Facebook stays **not** must-search (cataloged exclude). ``; L198: `` Facebook: `must_search: false` ``; L339: `` facebook `must_search=false` `` |
| X must-search / xweb intact | PASS | L54: `` Catalog `x`: `must_search: true`, `mvp: true` ``; L54: `` new `-p xweb` ``; L339: `` xweb bucket/provider present on the **one** X row `` |
| search-cli gateway intact | PASS | L55: `` pin exact binary `search` / `SB_SEARCH_BIN` ``; L56: `` **Fork is the gateway.** No `search_gateway.py` adapters. `` |
| AC1 §6.12 `last.json.tmp.*` seed/assert removal still present | PASS | L634: `` plus orphaned `last.json.tmp.*` (seed `last.json.tmp.{pid}.{nanos}` / `{uuid}` and assert removal) `` |
| AC2 §6.12 held reddit lock → `cache_clear_busy` / absent unlockable still present | PASS | L635: `` held `reddit-oauth-token.lock` also drives `cache_clear_busy` / no-unlink; absent `reddit-oauth-token.lock` is unlockable (ENOENT; clear proceeds) `` |
| AC3 §6.12 forced refresh zero reddit search-bucket tokens still present | PASS | L643: `` forced refreshes (TTL < 60s) consume **zero** `reddit` search-bucket tokens (token-endpoint calls are not `acquire("reddit", …)`) `` |

## Leftover gaps vs AD1 / I-40 APPLY charter

None.

## Notes

- Verify is **not** a Policy F streak.
- Independent of verify_1-pass15; separate re-read at SHA `e0b487d4f815919a83c585d01d7d83f94a7122d3166487ac813b030b159f015e`.
- AC1–AC3 verifies already PASS at prior SHA `32b8f337…`; regression-checked here, not re-run as primary scope.
