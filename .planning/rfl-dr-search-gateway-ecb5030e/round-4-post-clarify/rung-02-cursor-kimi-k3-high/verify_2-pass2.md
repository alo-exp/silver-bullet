# RFL rung 2 — verify_2 pass 2 (independent)

- **Model:** Composer 2.5 High (`composer-2.5` / `sb-composer-2-5-high`)
- **Phase:** `rung_2_verify_2` after ACCEPT-apply of Kimi pack K7–K11 / I-51–I-55
- **Plan:** `/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md`
- **Method:** Independent re-hash (`shasum -a 256`), graphify CLI orientation, ctx_execute line-range extraction from the live plan (not copied from verify_1 or review artifacts)

## SHA gate

| Field | Value |
|-------|-------|
| Expected SHA-256 | `0f3258bc4a2b9ed937504c65a8c4a1259d92f5dd1e7f55cff4a370e401f3a79f` |
| Observed SHA-256 | `0f3258bc4a2b9ed937504c65a8c4a1259d92f5dd1e7f55cff4a370e401f3a79f` |
| **SHA gate** | **PASS** |

## Per-ID APPLY string evidence

### K7 / I-51 — §7 mermaid quota: `tok["reddit-oauth-token.json + .lock"]`

- **Required string:** `tok["reddit-oauth-token.json + .lock"]`
- **Evidence:** Plan L693 inside `subgraph quota ["SEARCH_QUOTA_DIR"]`:
  - `tok["reddit-oauth-token.json + .lock"]`
- **Verdict:** **PASS**

### K8 / I-52 — §6.12 `config.example.toml` Phase 1 locked key set; Phase 2 `SEARCH_KEYS_X` / `SEARCH_KEYS_XWEB_GUEST` gated

- **Required:** Phase 1 locked set separate from Phase 2 X-key assertions
- **Evidence:** Plan L646:
  - `config.example.toml` **Phase 1:** comments name `SEARCH_KEYS_BRAVE` / `SEARCH_KEYS_SERPER` **and** `SEARCH_KEYS_GITHUB` / `SEARCH_KEYS_GITLAB` / `SEARCH_KEYS_STACKEXCHANGE` / `SEARCH_KEYS_YOUTUBE` / `SEARCH_KEYS_REDDIT` / `SEARCH_KEYS_REDDITSECRET`; `SEARCH_BRAVE_KEY` / `SEARCH_SERPER_KEY` absent.
  - **Phase 2:** comments also name `SEARCH_KEYS_X` / `SEARCH_KEYS_XWEB_GUEST` (and `X_BEARER_TOKEN` / `X_GUEST_TOKEN` / `XWEB_COOKIES` as in §6.8)
- **Cross-check:** L575 Phase 1 regression test lists the same Phase 1-only key set; L572 labels X keys as Phase 2.
- **Verdict:** **PASS**

### K9 / I-53 — §2.3 fingerprint includes `--allow-private`

- **Required:** Fingerprint summary includes `--allow-private`
- **Evidence:** Plan L139:
  - `Cache fingerprint: provider + mode + normalized query (lowercase, stable site: order) + domains/filters + --allow-private boolean.`
- **Verdict:** **PASS**

### K10 / I-54 — researched-project (not SB-only) root `.gitignore`

- **Required:** Gitignore targets researched project root, not SB-only phrasing
- **Evidence:**
  - Plan L125: `Phase 3 adds .planning/research/_search-cache/ to the researched project's root .gitignore when one exists (and to the SB repo's own .gitignore for SB self-runs); the orchestrator-written inner {SEARCH_CACHE_DIR}/.gitignore remains the primary guard.`
  - Plan L353: `researched-project root .gitignore (when one exists) lists .planning/research/_search-cache/ (and the SB repo .gitignore for SB self-runs); inner {SEARCH_CACHE_DIR}/.gitignore remains the primary guard.`
- **Verdict:** **PASS**

### K11 / I-55 — §7 mermaid providers include `x` `xweb`

- **Required:** Provider subgraph includes `x` and `xweb`
- **Evidence:** Plan L696:
  - `official[github gitlab se hn discourse youtube registries reddit x xweb]`
- **Verdict:** **PASS**

## L85 rollup — Rung 2 Kimi pass-2 ACCEPTs

- **Required:** L85 records **Rung 2 Kimi pass-2 ACCEPTs**
- **Evidence:** Plan L85 contains:
  - `**Rung 2 Kimi pass-2 ACCEPTs:** §7 mermaid quota includes reddit-oauth-token.json+.lock; §6.12 config.example.toml X keys are Phase-2-gated; §2.3 fingerprint includes --allow-private; researched-project (not SB-only) root .gitignore; §7 mermaid providers include x/xweb.`
- **Verdict:** **PASS**

## Product locks (unwind check)

| Lock | Evidence | Verdict |
|------|----------|---------|
| One search-cli fork gateway | L52–L56: public `alo-exp/search-cli` fork; "Fork is the gateway"; orchestrator subprocess client; no `search_gateway.py` adapters | **PASS** |
| X must-search = `-p x` + `-p xweb` + `-p xai` + Serper `site:x.com` | L54, L122, L178: union of official `-p x`, unpaid `-p xweb`, xAI `-m social -p xai`, dedicated Serper `site:x.com` | **PASS** |
| No exec `twitter`/`opencli`/`bird` | L54–L55, L178, L642: explicit rejection; port to Rust, not subprocess | **PASS** |
| No Chrome fleet | L54: rejects "user-present desktop Chrome session"; no Chrome-fleet admission path | **PASS** |
| No Nitter | L54, L178, L204: Nitter forbidden | **PASS** |
| No scrape google.com | L54, L146: `Do not scrape google.com` | **PASS** |
| Facebook `must_search: false` | L54: "Facebook stays **not** must-search"; L198: `must_search: false`; L339 test asserts `facebook must_search=false` | **PASS** |

## Leftover gaps

None. All five K7–K11 APPLY encodings are present at the confirmed SHA; product locks are intact; L85 rollup records pass-2 ACCEPTs.

## Final verdict

**VERIFY_PASS**

- SHA matches expected freeze
- All five APPLY strings confirmed in the live plan
- L85 records Rung 2 Kimi pass-2 ACCEPTs
- No product-lock unwind detected
