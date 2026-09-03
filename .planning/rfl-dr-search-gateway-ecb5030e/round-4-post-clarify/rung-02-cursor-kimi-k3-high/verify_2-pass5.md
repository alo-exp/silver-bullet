# RFL rung 2 — verify_2 pass 5 (independent second pass)

- **Model:** Composer 2.5 High (`composer-2.5` / `sb-composer-2-5-high`)
- **Phase:** `rung_2_verify_2` after ACCEPT-apply of Kimi pack R2P5-1…R2P5-4 (I-61…I-64)
- **Plan:** `/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md`
- **Apply ledger:** [APPLY.md](APPLY.md) Pass 5 section
- **Review input:** [review-pass-5.md](review-pass-5.md)
- **Method:** `shasum -a 256` gate; graphify CLI orientation; independent `ctx_execute` grep/section extraction on freeze plan (not copied from verify_1 or review artifact)

---

## SHA gate

| Field | Value |
|-------|-------|
| Expected SHA-256 | `f6ba43bb7d7d4d4ca394333ae5f7c15022059040edac9ec75585654630584cd6` |
| Observed SHA-256 | `f6ba43bb7d7d4d4ca394333ae5f7c15022059040edac9ec75585654630584cd6` |
| **SHA gate** | **PASS** |

---

## Per-ID APPLY verification

### R2P5-1 / I-61 (LOW) — §6.1 fleet never `--x` shorthand; xAI leg explicit `-m social -p xai`

- **Required:** Fleet never `--x` shorthand; xAI leg still explicit `-m social -p xai`; old overbroad `/ -m social` ban absent.
- **Evidence:** §6.1 L373: "Fleet never passes `--x` (the shorthand that forces `-m social -p xai`); the X union's xAI leg passes explicit `-m social -p xai` (§1.2 leg B). `-m social` is never the default mode for non-X channels."
- **Negative:** No match for ``Fleet never passes `--x` / -m social`` anywhere in plan.
- **Verdict:** **PASS**

### R2P5-2 / I-62 (NIT) — §1.2 X dedup orchestrator-only

- **Required:** X dedup orchestrator-only; phrase `or the fork if one process unions` absent.
- **Evidence:** §1.2 L54 ends with "Dedup by tweet URL/id in the orchestrator (locked; §1.4)." §1.4 L101: "Dedup lives in **`search_orchestrator.py`**, not the fork." §2.5 L178: "Dedup is the SB orchestrator contract in §1.4 (not the fork)."
- **Negative:** No match for `or the fork if one process unions`.
- **Verdict:** **PASS**

### R2P5-3 / I-63 (NIT) — §6.3 `buckets/{id}` not `<host>`

- **Required:** Quota layout uses `{id}` placeholder, not `<host>`.
- **Evidence:** §6.3 L455: `` `buckets/{id}.lock` + `buckets/{id}.json` ``. §6.4 L470: `` `{quota_dir}/buckets/{id}.lock` `` and `` `{id}.json` ``. §2.2 L120: bucket id is **not** an API hostname.
- **Negative:** No match for `buckets/<host>`.
- **Verdict:** **PASS**

### R2P5-4 / I-64 (NIT) — §7 Serper node `-d` bare-host or `-q` (X / path-scoped)

- **Required:** §7 mermaid Serper node names both `-d` bare-host and `-q` exceptions for X / path-scoped rows.
- **Evidence:** §7 L697: `serper["Serper site: via -d (bare host) or -q (X / path-scoped)"]`. Prose exceptions at §6.3 L459 and §6.9 L595 (X `site:x.com` in `-q`; path-scoped `site:host/path` in `-q`).
- **Verdict:** **PASS**

---

## L85 rollup — Rung 2 Kimi pass-5 ACCEPTs

- **Required:** L85 records **Rung 2 Kimi pass-5 ACCEPTs**.
- **Evidence:** §1.2 L85 contains: "**Rung 2 Kimi pass-5 ACCEPTs:** §6.1 fleet never `--x` shorthand (xAI leg still explicit `-m social -p xai`); §1.2 X dedup is orchestrator-only; §6.3 quota files use `{id}` not `<host>`; §7 Serper node names `-d` bare-host and `-q` X/path-scoped exceptions."
- **Verdict:** **PASS**

---

## Product locks (VERIFY_FAIL if unwound)

| Lock | Status | Evidence |
|------|--------|----------|
| One search-cli fork gateway | **INTACT** | §1.2 L56 "Fork is the gateway"; L55 "search-cli remains the only gateway"; no `search_gateway.py` adapters |
| X must-search union: `-p x` + `-p xweb` + `-p xai` + Serper `site:x.com` | **INTACT** | §1.2 L54 legs (1)–(4); dedicated `-p serper` + `site:x.com` in `-q` |
| Explicit `-m social -p xai` for xAI leg | **INTACT** | §1.2 L54 leg B; §6.1 L373 explicit argv |
| No exec `twitter`/`opencli`/`bird` | **INTACT** | §1.2 L54 reject list |
| No Chrome fleet / desktop session | **INTACT** | §1.2 L54 "user-present desktop Chrome session" rejected |
| No Nitter | **INTACT** | §1.2 L54 "No Nitter" |
| No scrape google.com | **INTACT** | §1.2 L54 "no scrape google.com" |
| Facebook `must_search: false` | **INTACT** | §1.2 L54 "Facebook stays **not** must-search (cataloged exclude)" |

**Product-lock gate:** **PASS** (no unwind detected)

---

## Leftover gaps

None. All four review-pass-5 residuals (R2P5-1…R2P5-4) are encoded at the freeze SHA; no additional defects found in this independent verify_2 pass.

---

## Final verdict

**VERIFY_PASS**

SHA matches expected freeze; all four APPLY strings (R2P5-1…I-64) present; L85 records Rung 2 Kimi pass-5 ACCEPTs; product locks intact.
