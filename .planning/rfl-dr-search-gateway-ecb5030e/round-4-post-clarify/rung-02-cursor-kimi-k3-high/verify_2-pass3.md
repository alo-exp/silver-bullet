# RFL rung 2 — verify_2 pass 3 (independent)

- **Model:** Composer 2.5 High (`composer-2.5` / `sb-composer-2-5-high`)
- **Phase:** `rung_2_verify_2` after ACCEPT-apply of Kimi pack R2P3-1–R2P3-2 / I-56–I-57
- **Plan:** `/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md`
- **Method:** Independent re-hash (`shasum -a 256`), graphify CLI orientation, ctx_execute line-range extraction from the live plan (not copied from verify_1 or review artifacts)

## SHA gate

| Field | Value |
|-------|-------|
| Expected SHA-256 | `f7cf259f122f70e28e854d28ea8f620a52640e8eb4b527369e08564fb3c92260` |
| Observed SHA-256 | `f7cf259f122f70e28e854d28ea8f620a52640e8eb4b527369e08564fb3c92260` |
| **SHA gate** | **PASS** |

## Per-ID APPLY string evidence

### R2P3-1 / I-56 — §2.2 bucket short-names include `x` and `xweb`

- **Required string:** §2.2 bucket short-names include `x` / `xweb`
- **Evidence:** Plan L120 (`§2.2 Functional — Silver Bullet`):
  - `` **`bucket` is the fork token-bucket id** from §6.4 (short names: `stackexchange`, `github`, `gitlab`, `youtube`, `serper`, `brave`, `hn`, `reddit`, `registries`, `x`, `xweb`, `discourse-<sanitized-host>`). ``
- **Cross-check:** L124 probe native list also includes `x`, `xweb`; L111 Phase 2 native providers name `x` and `xweb`.
- **Verdict:** **PASS**

### R2P3-2 / I-57 — xweb envs via `resolve_keys` (not figment `SEARCH_KEYS_XWEB_GUEST`)

- **Required string:** xweb envs via `resolve_keys` (not figment `SEARCH_KEYS_XWEB_GUEST`)
- **Evidence:** Plan L572 (`§6.8`):
  - `Env via `resolve_keys` (not figment `split("_")`): `X_GUEST_TOKEN` then `SEARCH_KEYS_XWEB_GUEST`; `XWEB_COOKIES`. Figment `SEARCH_KEYS_XWEB_GUEST` would nest to `keys.xweb.guest` and miss the flat field — do **not** rely on figment for xweb.`
- **Interpretation:** `SEARCH_KEYS_XWEB_GUEST` remains documented as a **direct-env alias** on the `resolve_keys` path (mirroring reddit at L571), not as a figment `split("_")` load. This matches review fix option (a).
- **Cross-check:** L54 / L218 still list `X_GUEST_TOKEN` / `SEARCH_KEYS_XWEB_GUEST` / `XWEB_COOKIES` for user-facing copy; L646 §6.12 Phase 2 comments reference the same env names “as in §6.8”.
- **Verdict:** **PASS**

## L85 rollup — Rung 2 Kimi pass-3 ACCEPTs

- **Required:** L85 records **Rung 2 Kimi pass-3 ACCEPTs**
- **Evidence:** Plan L85 contains:
  - `**Rung 2 Kimi pass-3 ACCEPTs:** §2.2 bucket short-names include `x`/`xweb`; xweb envs load via `resolve_keys` (not figment `SEARCH_KEYS_XWEB_GUEST`).`
- **Verdict:** **PASS**

## Product locks (unwind check)

| Lock | Evidence | Verdict |
|------|----------|---------|
| One search-cli fork gateway | L52–L56: public `alo-exp/search-cli` fork; “Fork is the gateway”; orchestrator subprocess client | **PASS** |
| X must-search = `-p x` + `-p xweb` + `-p xai` + Serper `site:x.com` | L54, L111–L113, L122, L178: union of official `-p x`, unpaid `-p xweb`, xAI `-m social -p xai`, dedicated Serper `site:x.com` | **PASS** |
| No exec `twitter`/`opencli`/`bird` | L54, L178, L218, L642: explicit rejection; port HTTP to Rust, not subprocess | **PASS** |
| No Chrome fleet | L54: rejects “user-present desktop Chrome session”; no Chrome-fleet admission path | **PASS** |
| No Nitter | L54, L178, L204: Nitter forbidden | **PASS** |
| No scrape google.com | L54, L146: `Do not scrape google.com` | **PASS** |
| Facebook `must_search: false` | L54: “Facebook stays **not** must-search”; L198: `must_search: false`; L339 test asserts `facebook must_search=false` | **PASS** |

## Leftover gaps

None. R2P3-1 (§2.2 bucket enumeration) and R2P3-2 (xweb `resolve_keys` vs figment) are encoded at the confirmed SHA; product locks are intact; L85 rollup records pass-3 ACCEPTs. No new residuals surfaced in this independent pass.

## Final verdict

**VERIFY_PASS** — SHA matches; both R2P3 APPLY strings present; L85 records Rung 2 Kimi pass-3 ACCEPTs; product locks unwound: **no**.
